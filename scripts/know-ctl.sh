#!/bin/bash
# know-ctl.sh — CLI for .know/ index operations
# Usage: bash know-ctl.sh <command> [args]
set -euo pipefail

# Resolve paths relative to project root
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
KNOW_DIR="$PROJECT_DIR/.know"
INDEX_FILE="$KNOW_DIR/index.jsonl"
ENTRIES_DIR="$KNOW_DIR/entries"
METRICS_FILE="$KNOW_DIR/metrics.json"
EVENTS_FILE="$KNOW_DIR/events.jsonl"
CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"

# Ensure metrics.json exists, initialize if needed
ensure_metrics() {
    if [ ! -f "$METRICS_FILE" ]; then
        local initial_created=0
        [ -f "$INDEX_FILE" ] && initial_created=$(wc -l < "$INDEX_FILE" | tr -d ' ')
        echo "{\"total_created\":$initial_created,\"total_decayed\":0,\"queried_scopes\":[]}" | jq '.' > "$METRICS_FILE"
    fi
}

# Increment a numeric field in metrics.json
metrics_inc() {
    local field="$1" amount="${2:-1}"
    ensure_metrics
    local tmp="$METRICS_FILE.tmp"
    jq ".$field += $amount" "$METRICS_FILE" > "$tmp" && mv "$tmp" "$METRICS_FILE"
}

# Add scope to queried_scopes (deduplicated)
metrics_add_scope() {
    local scope="$1"
    ensure_metrics
    local tmp="$METRICS_FILE.tmp"
    jq --arg s "$scope" 'if (.queried_scopes | index($s)) then . else .queried_scopes += [$s] end' "$METRICS_FILE" > "$tmp" && mv "$tmp" "$METRICS_FILE"
}

# Emit lifecycle event to events.jsonl
emit_event() {
    local event="$1" summary="$2"
    local ts
    ts=$(date +%Y-%m-%d)
    printf '%s' "$summary" | jq -Rc --arg ts "$ts" --arg ev "$event" '{ts:$ts,event:$ev,summary:.}' >> "$EVENTS_FILE"
}

# Ensure .know/ structure exists
ensure_dirs() {
    mkdir -p "$ENTRIES_DIR"/{rationale,constraint,pitfall,concept,reference}
    [ -f "$INDEX_FILE" ] || touch "$INDEX_FILE"
}

# ─── Commands ───────────────────────────────────────────────

cmd_query() {
    # query <scope> [--tag <tag>] [--tier <n>] [--tm <mode>]
    local scope="${1:?Usage: query <scope> [--tag tag] [--tier n] [--tm mode]}"
    shift
    local tag="" tier="" tm=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tag)  tag="$2"; shift 2 ;;
            --tier) tier="$2"; shift 2 ;;
            --tm)   tm="$2"; shift 2 ;;
            *)      shift ;;
        esac
    done

    local filter
    if [ "$scope" = "project" ]; then
        filter='true'
    else
        # Prefix match: scope starts with query, or scope is "project", or array scope contains prefix match
        filter="(
            if .scope | type == \"array\"
            then any(.[]; startswith(\"$scope\")) or any(.[]; . == \"project\")
            else (.scope | startswith(\"$scope\")) or .scope == \"project\"
            end
        )"
    fi

    [ -n "$tag" ]  && filter="$filter and .tag == \"$tag\""
    [ -n "$tier" ] && filter="$filter and .tier == $tier"
    [ -n "$tm" ]   && filter="$filter and .tm == \"$tm\""

    jq -c "select($filter)" "$INDEX_FILE" 2>/dev/null || true
    metrics_add_scope "$scope" 2>/dev/null || true
}

cmd_search() {
    # search <pattern> — regex match against summary
    local pattern="${1:?Usage: search <pattern>}"
    jq -c "select(.summary | test(\"$pattern\"; \"i\"))" "$INDEX_FILE" 2>/dev/null || true
}

cmd_append() {
    # append <json> — add entry to index
    local json="${1:?Usage: append '<json>'}"
    ensure_dirs

    # Validate required fields
    echo "$json" | jq -e '.tag and .tier and .scope and .summary and .updated' > /dev/null 2>&1 \
        || { echo "Error: missing required fields (tag, tier, scope, summary, updated)"; exit 1; }

    echo "$json" >> "$INDEX_FILE"
    metrics_inc total_created
    local summary
    summary=$(echo "$json" | jq -r '.summary')
    emit_event "created" "$summary"
    echo "Appended: $summary"
}

cmd_hit() {
    # hit <path-or-index> — increment hits, update timestamp
    local target="${1:?Usage: hit <path-or-summary>}"
    local today
    today=$(date +%Y-%m-%d)
    local tmpfile="$INDEX_FILE.tmp"

    local match_filter
    if [[ "$target" == entries/* ]]; then
        match_filter=".path == \"$target\""
    else
        match_filter="(.summary | test(\"$target\"; \"i\"))"
    fi
    jq -c "if $match_filter then .hits += 1 | .updated = \"$today\" | .last_hit = \"$today\" else . end" "$INDEX_FILE" > "$tmpfile"
    mv "$tmpfile" "$INDEX_FILE"
    # Emit hit event for matched entries
    jq -r "select($match_filter) | .summary" "$INDEX_FILE" 2>/dev/null | while IFS= read -r s; do
        emit_event "hit" "$s"
    done
}

cmd_delete() {
    # delete <keyword> — remove entry matching keyword from index + detail file
    local keyword="${1:?Usage: delete <keyword>}"
    local tmpfile="$INDEX_FILE.tmp"
    local deleted=0

    while IFS= read -r line; do
        if echo "$line" | jq -e "select(.summary | test(\"$keyword\"; \"i\"))" > /dev/null 2>&1; then
            local summary path
            summary=$(echo "$line" | jq -r '.summary')
            path=$(echo "$line" | jq -r '.path // empty')
            [ -n "$path" ] && [ -f "$KNOW_DIR/$path" ] && rm "$KNOW_DIR/$path"
            emit_event "deleted" "$summary"
            deleted=$((deleted + 1))
        else
            echo "$line" >> "$tmpfile"
        fi
    done < "$INDEX_FILE"

    if [ "$deleted" -eq 0 ]; then
        rm -f "$tmpfile"
        echo "Error: no entry matching '$keyword'"
        exit 1
    fi

    mv "$tmpfile" "$INDEX_FILE"
    echo "Deleted $deleted entry"
}

cmd_update() {
    # update <keyword> <json-patch> — update entry matching keyword, increment revs
    local keyword="${1:?Usage: update <keyword> '<json-patch>'}"
    local patch="${2:?Usage: update <keyword> '<json-patch>'}"
    local today
    today=$(date +%Y-%m-%d)
    local tmpfile="$INDEX_FILE.tmp"
    local matched=0

    while IFS= read -r line; do
        if echo "$line" | jq -e "select(.summary | test(\"$keyword\"; \"i\"))" > /dev/null 2>&1; then
            local summary
            summary=$(echo "$line" | jq -r '.summary')
            line=$(echo "$line" | jq -c ". * $patch | .revs = (.revs // 0) + 1 | .updated = \"$today\"")
            emit_event "updated" "$summary"
            matched=$((matched + 1))
        fi
        echo "$line" >> "$tmpfile"
    done < "$INDEX_FILE"

    if [ "$matched" -eq 0 ]; then
        rm -f "$tmpfile"
        echo "Error: no entry matching '$keyword'"
        exit 1
    fi

    mv "$tmpfile" "$INDEX_FILE"
    echo "Updated $matched entry (revs incremented)"
}

cmd_decay() {
    # decay — apply decay policy, output actions taken
    local today_ts
    today_ts=$(date +%s)
    local tmpfile="$INDEX_FILE.tmp"
    local deleted=0 demoted=0

    > "$tmpfile"
    while IFS= read -r line; do
        local tier created hits revs summary
        tier=$(echo "$line" | jq -r '.tier')
        created=$(echo "$line" | jq -r '.created')
        hits=$(echo "$line" | jq -r '.hits')
        revs=$(echo "$line" | jq -r '.revs // 0')
        summary=$(echo "$line" | jq -r '.summary')

        local created_ts age_days
        created_ts=$(date -j -f "%Y-%m-%d" "$created" +%s 2>/dev/null || date -d "$created" +%s 2>/dev/null || echo 0)
        age_days=$(( (today_ts - created_ts) / 86400 ))

        # 备忘 (tier 2) + hits=0 + >30d → delete
        if [ "$tier" -eq 2 ] && [ "$hits" -eq 0 ] && [ "$age_days" -gt 30 ]; then
            local path
            path=$(echo "$line" | jq -r '.path // empty')
            [ -n "$path" ] && [ -f "$KNOW_DIR/$path" ] && rm "$KNOW_DIR/$path"
            emit_event "deleted" "$summary"
            deleted=$((deleted + 1))
            continue
        fi

        # 重要 (tier 1) + hits=0 + >180d → demote to 备忘
        if [ "$tier" -eq 1 ] && [ "$hits" -eq 0 ] && [ "$age_days" -gt 180 ]; then
            line=$(echo "$line" | jq -c '.tier = 2')
            emit_event "demoted" "$summary"
            demoted=$((demoted + 1))
        fi

        # revs > 3 + 重要 (tier 1) → demote to 备忘 (unstable)
        if [ "$tier" -eq 1 ] && [ "$revs" -gt 3 ]; then
            line=$(echo "$line" | jq -c '.tier = 2')
            emit_event "demoted" "$summary"
            demoted=$((demoted + 1))
        fi

        echo "$line" >> "$tmpfile"
    done < "$INDEX_FILE"

    mv "$tmpfile" "$INDEX_FILE"
    local total_decayed=$((deleted + demoted))
    [ "$total_decayed" -gt 0 ] && metrics_inc total_decayed "$total_decayed"
    echo "Decay complete: $deleted deleted, $demoted demoted"
}

cmd_stats() {
    # stats — index summary
    [ -f "$INDEX_FILE" ] || { echo "No index file"; exit 0; }
    local total
    total=$(wc -l < "$INDEX_FILE" | tr -d ' ')
    echo "Total: $total entries"
    echo ""
    echo "By tier:"
    jq -r '.tier' "$INDEX_FILE" | sort | uniq -c | sort -rn
    echo ""
    echo "By tag:"
    jq -r '.tag' "$INDEX_FILE" | sort | uniq -c | sort -rn
    echo ""
    echo "By scope:"
    jq -r 'if .scope | type == "array" then .scope[] else .scope end' "$INDEX_FILE" | sort | uniq -c | sort -rn
}

cmd_metrics() {
    # metrics — show 6 quality indicators across learn/recall/write
    ensure_metrics

    # --- Learn ---
    local total=0 hit_count=0
    if [ -f "$INDEX_FILE" ] && [ -s "$INDEX_FILE" ]; then
        total=$(wc -l < "$INDEX_FILE" | tr -d ' ')
        hit_count=$(jq -s '[.[] | select(.hits > 0)] | length' "$INDEX_FILE")
    fi
    local hit_pct=0
    [ "$total" -gt 0 ] && hit_pct=$((hit_count * 100 / total))

    local total_created total_decayed
    total_created=$(jq -r '.total_created' "$METRICS_FILE")
    total_decayed=$(jq -r '.total_decayed' "$METRICS_FILE")
    local decay_pct=0
    [ "$total_created" -gt 0 ] && decay_pct=$((total_decayed * 100 / total_created))

    # --- Recall ---
    local defensive_hits=0
    if [ -f "$INDEX_FILE" ] && [ -s "$INDEX_FILE" ]; then
        defensive_hits=$(jq -s '[.[] | select(.tm == "active:defensive") | .hits] | add // 0' "$INDEX_FILE")
    fi

    local queried_count total_scopes scope_pct=0
    queried_count=$(jq -r '.queried_scopes | length' "$METRICS_FILE")
    if [ -f "$INDEX_FILE" ] && [ -s "$INDEX_FILE" ]; then
        total_scopes=$(jq -sr '[.[].scope] | flatten | unique | length' "$INDEX_FILE")
    else
        total_scopes=0
    fi
    [ "$total_scopes" -gt 0 ] && scope_pct=$((queried_count * 100 / total_scopes))

    # --- Write ---
    local stale_count=0
    if [ -f "$CLAUDE_MD" ]; then
        stale_count=$(grep -c "⚠ needs update" "$CLAUDE_MD" 2>/dev/null) || stale_count=0
    fi

    local prd_count=0 milestone_count=0 doc_pct=0
    prd_count=$(find "$KNOW_DIR/docs/requirements" -name "prd.md" 2>/dev/null | wc -l | tr -d ' ')
    local latest_roadmap
    latest_roadmap=$(ls -d "$KNOW_DIR/docs/v"*/ 2>/dev/null | sort -V | tail -1)
    if [ -n "$latest_roadmap" ] && [ -f "${latest_roadmap}roadmap.md" ]; then
        milestone_count=$(grep -cE '^\| M[0-9]' "${latest_roadmap}roadmap.md" 2>/dev/null) || milestone_count=0
    fi
    if [ "$milestone_count" -gt 0 ]; then
        doc_pct=$((prd_count * 100 / milestone_count))
        [ "$doc_pct" -gt 100 ] && doc_pct=100
    fi

    # --- Output ---
    cat <<EOF
=== know metrics ===

Learn — 存的有用吗？
  命中率:    $hit_count/$total ($hit_pct%)
  衰减率:    $total_decayed/$total_created ($decay_pct%)

Recall — 帮我避错了吗？
  防御次数:  $defensive_hits
  覆盖率:    $queried_count/$total_scopes ($scope_pct%)

Write — 文档跟上了吗？
  过期文档:  $stale_count
  文档覆盖:  $prd_count/$milestone_count ($doc_pct%)
EOF

    # --- Suggestions ---
    local suggestions=()
    if [ "$total" -gt 0 ] && [ "$hit_pct" -lt 50 ]; then
        local nohit=$((total - hit_count))
        suggestions+=("命中率 ${hit_pct}%: ${nohit} 条知识从未命中，运行 /know review 清理 → 预计命中率 100%")
    fi
    if [ "$total_created" -gt 0 ] && [ "$decay_pct" -gt 30 ]; then
        suggestions+=("衰减率 ${decay_pct}%: 存入质量需关注，检查 learn filter 规则")
    fi
    if [ "$total" -gt 0 ] && [ "$defensive_hits" -eq 0 ]; then
        suggestions+=("防御次数 0: 无 active:defensive 命中，检查 constraint 类知识或 scope 推断")
    fi
    if [ "$total_scopes" -gt 0 ] && [ "$scope_pct" -lt 50 ]; then
        suggestions+=("覆盖率 ${scope_pct}%: 多数 scope 未被查询，检查 recall scope 推断规则")
    fi
    if [ "$stale_count" -gt 0 ]; then
        suggestions+=("过期文档 ${stale_count} 个: 运行 /know write 更新标记的文档")
    fi
    if [ "$milestone_count" -gt 0 ] && [ "$doc_pct" -lt 100 ]; then
        local uncovered=$((milestone_count - prd_count))
        suggestions+=("文档覆盖 ${doc_pct}%: ${uncovered} 个里程碑缺 PRD")
    fi

    echo ""
    if [ ${#suggestions[@]} -eq 0 ]; then
        echo "✅ 所有指标健康，无需操作"
    else
        echo "--- 建议 ---"
        for s in "${suggestions[@]}"; do
            echo "• $s"
        done
    fi
}

cmd_history() {
    # history <keyword> — show lifecycle events for matching entry
    local keyword="${1:?Usage: history <keyword>}"
    [ -f "$EVENTS_FILE" ] || { echo "No event log"; exit 0; }
    local results
    results=$(jq -r "select(.summary | test(\"$keyword\"; \"i\")) | \"\(.ts)  \(.event)\t\(.summary)\"" "$EVENTS_FILE" 2>/dev/null)
    if [ -z "$results" ]; then
        echo "No matching events found"
    else
        echo "$results"
    fi
}

cmd_init() {
    # init — create .know/ directory structure
    ensure_dirs
    echo "Initialized: $KNOW_DIR"
    echo "  index:   $INDEX_FILE"
    echo "  entries: $ENTRIES_DIR/{rationale,constraint,pitfall,concept,reference}"
}

# ─── Dispatch ───────────────────────────────────────────────

CMD="${1:-help}"
shift || true

case "$CMD" in
    query)   cmd_query "$@" ;;
    search)  cmd_search "$@" ;;
    append)  cmd_append "$@" ;;
    hit)     cmd_hit "$@" ;;
    delete)  cmd_delete "$@" ;;
    update)  cmd_update "$@" ;;
    decay)   cmd_decay ;;
    stats)   cmd_stats ;;
    metrics) cmd_metrics ;;
    history) cmd_history "$@" ;;
    init)    cmd_init ;;
    help|*)
        cat <<'EOF'
know-ctl.sh — CLI for .know/ index operations

Commands:
  init                              Create .know/ directory structure
  query <scope> [--tag t] [--tier n] [--tm m]
                                    Filter index by scope prefix + optional filters
  search <pattern>                  Regex search against summary field
  append '<json>'                   Append entry to index.jsonl
  hit <path-or-keyword>             Increment hits counter, update timestamp
  delete <keyword>                  Delete matching entry + detail file
  update <keyword> '<json-patch>'   Update matching entry fields, increment revs
  decay                             Apply decay policy (delete/demote expired entries)
  stats                             Show index summary (by tier, tag, scope)
  metrics                           Show 6 quality indicators (learn/recall/write)
  history <keyword>                  Show lifecycle events for matching entry
EOF
        ;;
esac
