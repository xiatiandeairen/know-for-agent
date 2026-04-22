#!/bin/bash
# know-ctl.sh — CLI for know knowledge base (project + user levels)
# Usage: bash know-ctl.sh <command> [--level project|user] [args]
set -euo pipefail

# ─── Paths ────────────────────────────────────────────────────────────
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
KNOW_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/know"
PROJECT_ID=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
PROJECT_KNOW_DIR="$KNOW_HOME/projects/$PROJECT_ID"
USER_KNOW_DIR="$KNOW_HOME/user"
DOCS_DIR="$PROJECT_DIR/docs"
LEGACY_KNOW_DIR="$PROJECT_DIR/.know"

level_to_dir() {
    case "$1" in
        project) echo "$PROJECT_KNOW_DIR" ;;
        user)    echo "$USER_KNOW_DIR" ;;
        *)       echo "Error: invalid level '$1' (expected: project|user)" >&2; exit 1 ;;
    esac
}

index_file_for()   { echo "$(level_to_dir "$1")/index.jsonl"; }
entries_dir_for()  { echo "$(level_to_dir "$1")/entries"; }
metrics_file_for() { echo "$(level_to_dir "$1")/metrics.json"; }
events_file_for()  { echo "$(level_to_dir "$1")/events.jsonl"; }

# ─── Argument parsing ────────────────────────────────────────────────

# Extract --level from args; leaves remaining args in REMAINING_ARGS.
# If not passed, LEVEL_ARG is empty string.
parse_level() {
    LEVEL_ARG=""
    REMAINING_ARGS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --level) LEVEL_ARG="$2"; shift 2 ;;
            *) REMAINING_ARGS+=("$1"); shift ;;
        esac
    done
}

# Resolve which levels to operate on.
# No --level → default_mode ("both" or "project")
# --level X → only that level
levels_to_use() {
    local default_mode="$1"
    if [ -n "$LEVEL_ARG" ]; then
        # Validate
        level_to_dir "$LEVEL_ARG" >/dev/null
        echo "$LEVEL_ARG"
    elif [ "$default_mode" = "both" ]; then
        echo "project"
        echo "user"
    else
        echo "$default_mode"
    fi
}

# ─── Low-level helpers (per level) ───────────────────────────────────

ensure_metrics() {
    local level="$1"
    local metrics_file index_file initial_created=0
    metrics_file=$(metrics_file_for "$level")
    [ -f "$metrics_file" ] && return
    index_file=$(index_file_for "$level")
    [ -f "$index_file" ] && initial_created=$(wc -l < "$index_file" | tr -d ' ')
    mkdir -p "$(dirname "$metrics_file")"
    echo "{\"total_created\":$initial_created,\"total_decayed\":0,\"queried_scopes\":[]}" | jq '.' > "$metrics_file"
}

metrics_inc() {
    local level="$1" field="$2" amount="${3:-1}"
    ensure_metrics "$level"
    local metrics_file tmp
    metrics_file=$(metrics_file_for "$level")
    tmp="$metrics_file.tmp"
    jq ".$field += $amount" "$metrics_file" > "$tmp" && mv "$tmp" "$metrics_file"
}

metrics_add_scope() {
    local level="$1" scope="$2"
    ensure_metrics "$level"
    local metrics_file tmp
    metrics_file=$(metrics_file_for "$level")
    tmp="$metrics_file.tmp"
    jq --arg s "$scope" 'if (.queried_scopes | index($s)) then . else .queried_scopes += [$s] end' "$metrics_file" > "$tmp" && mv "$tmp" "$metrics_file"
}

emit_event() {
    local level="$1" event="$2" summary="$3"
    local events_file ts
    events_file=$(events_file_for "$level")
    mkdir -p "$(dirname "$events_file")"
    ts=$(date +%Y-%m-%d)
    printf '%s' "$summary" | jq -Rc --arg ts "$ts" --arg ev "$event" '{ts:$ts,event:$ev,summary:.}' >> "$events_file"
}

ensure_dirs() {
    local level="$1"
    local entries_dir index_file
    entries_dir=$(entries_dir_for "$level")
    index_file=$(index_file_for "$level")
    mkdir -p "$entries_dir"/{insight,rule,trap}
    [ -f "$index_file" ] || touch "$index_file"
}

# ─── Commands ────────────────────────────────────────────────────────

cmd_query() {
    # query <scope> [--level L] [--tag t] [--tier n] [--tm m]
    parse_level "$@"
    set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
    local scope="${1:?Usage: query <scope> [--level L] [--tag tag] [--tier n] [--tm mode]}"
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

    while IFS= read -r level; do
        local index_file
        index_file=$(index_file_for "$level")
        [ -f "$index_file" ] || continue
        jq -c --arg lv "$level" "select($filter) | . + {_level: \$lv}" "$index_file" 2>/dev/null || true
        metrics_add_scope "$level" "$scope" 2>/dev/null || true
    done < <(levels_to_use both)
}

cmd_search() {
    # search <pattern> [--level L] — regex match against summary
    parse_level "$@"
    set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
    local pattern="${1:?Usage: search <pattern> [--level L]}"
    while IFS= read -r level; do
        local index_file
        index_file=$(index_file_for "$level")
        [ -f "$index_file" ] || continue
        jq -c --arg lv "$level" "select(.summary | test(\"$pattern\"; \"i\")) | . + {_level: \$lv}" "$index_file" 2>/dev/null || true
    done < <(levels_to_use both)
}

cmd_append() {
    # append <json> [--level L] — default level: project
    parse_level "$@"
    set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
    local json="${1:?Usage: append '<json>' [--level L]}"
    local level
    level=$(levels_to_use project)
    ensure_dirs "$level"
    ensure_metrics "$level"

    echo "$json" | jq -e '.tag and .tier and .scope and .summary and .updated' > /dev/null 2>&1 \
        || { echo "Error: missing required fields (tag, tier, scope, summary, updated)"; exit 1; }

    local index_file
    index_file=$(index_file_for "$level")
    echo "$json" >> "$index_file"
    metrics_inc "$level" total_created
    local summary
    summary=$(echo "$json" | jq -r '.summary')
    emit_event "$level" "created" "$summary"
    echo "Appended [$level]: $summary"
}

cmd_hit() {
    # hit <path-or-keyword> [--level L] — default: project
    parse_level "$@"
    set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
    local target="${1:?Usage: hit <path-or-summary> [--level L]}"
    local level
    level=$(levels_to_use project)
    local index_file today tmpfile match_filter
    index_file=$(index_file_for "$level")
    [ -f "$index_file" ] || { echo "No index for level '$level'"; exit 0; }
    today=$(date +%Y-%m-%d)
    tmpfile="$index_file.tmp"

    if [[ "$target" == entries/* ]]; then
        match_filter=".path == \"$target\""
    else
        match_filter="(.summary | test(\"$target\"; \"i\"))"
    fi
    jq -c "if $match_filter then .hits += 1 | .updated = \"$today\" else . end" "$index_file" > "$tmpfile"
    mv "$tmpfile" "$index_file"
    jq -r "select($match_filter) | .summary" "$index_file" 2>/dev/null | while IFS= read -r s; do
        emit_event "$level" "hit" "$s"
    done
}

cmd_delete() {
    # delete <keyword> [--level L] — default: project
    parse_level "$@"
    set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
    local keyword="${1:?Usage: delete <keyword> [--level L]}"
    local level
    level=$(levels_to_use project)
    local index_file level_dir tmpfile deleted=0
    index_file=$(index_file_for "$level")
    level_dir=$(level_to_dir "$level")
    [ -f "$index_file" ] || { echo "No index for level '$level'"; exit 0; }
    tmpfile="$index_file.tmp"
    > "$tmpfile"

    while IFS= read -r line; do
        if echo "$line" | jq -e "select(.summary | test(\"$keyword\"; \"i\"))" > /dev/null 2>&1; then
            local summary path
            summary=$(echo "$line" | jq -r '.summary')
            path=$(echo "$line" | jq -r '.path // empty')
            [ -n "$path" ] && [ -f "$level_dir/$path" ] && rm "$level_dir/$path"
            emit_event "$level" "deleted" "$summary"
            deleted=$((deleted + 1))
        else
            echo "$line" >> "$tmpfile"
        fi
    done < "$index_file"

    if [ "$deleted" -eq 0 ]; then
        rm -f "$tmpfile"
        echo "Error: no entry matching '$keyword' in [$level]"
        exit 1
    fi

    mv "$tmpfile" "$index_file"
    echo "Deleted $deleted entry [$level]"
}

cmd_update() {
    # update <keyword> <json-patch> [--level L] — default: project
    parse_level "$@"
    set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
    local keyword="${1:?Usage: update <keyword> '<json-patch>' [--level L]}"
    local patch="${2:?Usage: update <keyword> '<json-patch>' [--level L]}"
    local level
    level=$(levels_to_use project)
    local index_file today tmpfile matched=0
    index_file=$(index_file_for "$level")
    [ -f "$index_file" ] || { echo "No index for level '$level'"; exit 0; }
    today=$(date +%Y-%m-%d)
    tmpfile="$index_file.tmp"
    > "$tmpfile"

    while IFS= read -r line; do
        if echo "$line" | jq -e "select(.summary | test(\"$keyword\"; \"i\"))" > /dev/null 2>&1; then
            local summary
            summary=$(echo "$line" | jq -r '.summary')
            line=$(echo "$line" | jq -c ". * $patch | .revs = (.revs // 0) + 1 | .updated = \"$today\"")
            emit_event "$level" "updated" "$summary"
            matched=$((matched + 1))
        fi
        echo "$line" >> "$tmpfile"
    done < "$index_file"

    if [ "$matched" -eq 0 ]; then
        rm -f "$tmpfile"
        echo "Error: no entry matching '$keyword' in [$level]"
        exit 1
    fi

    mv "$tmpfile" "$index_file"
    echo "Updated $matched entry [$level] (revs incremented)"
}

cmd_decay() {
    # decay [--level L] — default: both
    parse_level "$@"
    local today_ts
    today_ts=$(date +%s)

    while IFS= read -r level; do
        local index_file level_dir tmpfile deleted=0 demoted=0
        index_file=$(index_file_for "$level")
        level_dir=$(level_to_dir "$level")
        [ -f "$index_file" ] || continue
        tmpfile="$index_file.tmp"
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

            if [ "$tier" -eq 2 ] && [ "$hits" -eq 0 ] && [ "$age_days" -gt 30 ]; then
                local path
                path=$(echo "$line" | jq -r '.path // empty')
                [ -n "$path" ] && [ -f "$level_dir/$path" ] && rm "$level_dir/$path"
                emit_event "$level" "deleted" "$summary"
                deleted=$((deleted + 1))
                continue
            fi

            if [ "$tier" -eq 1 ] && [ "$hits" -eq 0 ] && [ "$age_days" -gt 180 ]; then
                line=$(echo "$line" | jq -c '.tier = 2')
                emit_event "$level" "demoted" "$summary"
                demoted=$((demoted + 1))
            fi

            echo "$line" >> "$tmpfile"
        done < "$index_file"

        mv "$tmpfile" "$index_file"
        local total_decayed=$((deleted + demoted))
        [ "$total_decayed" -gt 0 ] && metrics_inc "$level" total_decayed "$total_decayed"
        echo "Decay [$level]: $deleted deleted, $demoted demoted"
    done < <(levels_to_use both)
}

cmd_stats() {
    # stats [--level L] — default: both (sectioned)
    parse_level "$@"
    while IFS= read -r level; do
        local index_file
        index_file=$(index_file_for "$level")
        echo "=== [$level] ==="
        if [ ! -f "$index_file" ]; then
            echo "No index file"
            echo ""
            continue
        fi
        local total
        total=$(wc -l < "$index_file" | tr -d ' ')
        echo "Total: $total entries"
        if [ "$total" -gt 0 ]; then
            echo ""
            echo "By tier:"
            jq -r '.tier' "$index_file" | sort | uniq -c | sort -rn
            echo ""
            echo "By tag:"
            jq -r '.tag' "$index_file" | sort | uniq -c | sort -rn
            echo ""
            echo "By scope:"
            jq -r 'if .scope | type == "array" then .scope[] else .scope end' "$index_file" | sort | uniq -c | sort -rn
        fi
        echo ""
    done < <(levels_to_use both)
}

cmd_metrics() {
    # metrics [--level L] — default: project
    parse_level "$@"
    local level
    level=$(levels_to_use project)
    ensure_metrics "$level"

    local index_file metrics_file events_file level_dir
    index_file=$(index_file_for "$level")
    metrics_file=$(metrics_file_for "$level")
    events_file=$(events_file_for "$level")
    level_dir=$(level_to_dir "$level")

    local total=0 hit_count=0
    if [ -f "$index_file" ] && [ -s "$index_file" ]; then
        total=$(wc -l < "$index_file" | tr -d ' ')
        hit_count=$(jq -s '[.[] | select(.hits > 0)] | length' "$index_file")
    fi
    local hit_pct=0
    [ "$total" -gt 0 ] && hit_pct=$((hit_count * 100 / total))

    local total_created total_decayed
    total_created=$(jq -r '.total_created' "$metrics_file")
    total_decayed=$(jq -r '.total_decayed' "$metrics_file")
    local decay_pct=0
    [ "$total_created" -gt 0 ] && decay_pct=$((total_decayed * 100 / total_created))

    local defensive_hits=0
    if [ -f "$index_file" ] && [ -s "$index_file" ]; then
        defensive_hits=$(jq -s '[.[] | select(.tm == "guard") | .hits] | add // 0' "$index_file")
    fi

    local queried_count total_scopes scope_pct=0
    queried_count=$(jq -r '.queried_scopes | length' "$metrics_file")
    if [ -f "$index_file" ] && [ -s "$index_file" ]; then
        total_scopes=$(jq -sr '[.[].scope] | flatten | unique | length' "$index_file")
    else
        total_scopes=0
    fi
    [ "$total_scopes" -gt 0 ] && scope_pct=$((queried_count * 100 / total_scopes))

    # Document coverage only makes sense for project level
    local prd_count=0 milestone_count=0 doc_pct=0
    if [ "$level" = "project" ]; then
        prd_count=$(find "$DOCS_DIR/requirements" -name "prd.md" 2>/dev/null | wc -l | tr -d ' ')
        local roadmap_file="$DOCS_DIR/roadmap.md"
        if [ -f "$roadmap_file" ]; then
            milestone_count=$(grep -cE '^\| M[0-9]' "$roadmap_file" 2>/dev/null) || milestone_count=0
        fi
        if [ "$milestone_count" -gt 0 ]; then
            doc_pct=$((prd_count * 100 / milestone_count))
            [ "$doc_pct" -gt 100 ] && doc_pct=100
        fi
    fi

    cat <<EOF
=== know metrics [$level] ===

Learn — 存的有用吗？
  命中率:    $hit_count/$total ($hit_pct%)
  衰减率:    $total_decayed/$total_created ($decay_pct%)

Recall — 帮我避错了吗？
  防御次数:  $defensive_hits
  覆盖率:    $queried_count/$total_scopes ($scope_pct%)

Write — 文档跟上了吗？
  文档覆盖:  $prd_count/$milestone_count ($doc_pct%)
EOF

    if [ -f "$events_file" ] && grep -q '"recall_query"' "$events_file" 2>/dev/null; then
        local rq_total=0 rq_hit=0 rq_empty=0 rq_hit_pct=0 rq_empty_pct=0 rq_scopes=0
        rq_total=$(grep -c '"recall_query"' "$events_file" 2>/dev/null || echo 0)
        rq_hit=$(jq -s '[.[] | select(.event=="recall_query" and .matched>0)] | length' "$events_file" 2>/dev/null || echo 0)
        rq_empty=$((rq_total - rq_hit))
        rq_hit_pct=$((rq_hit * 100 / rq_total))
        rq_empty_pct=$((rq_empty * 100 / rq_total))
        rq_scopes=$(jq -s '[.[] | select(.event=="recall_query") | .scope] | unique | length' "$events_file" 2>/dev/null || echo 0)
        printf '\nRecall Run\n'
        printf '  queries:   %s (hit %s/%s%%, empty %s/%s%%)\n' "$rq_total" "$rq_hit" "$rq_hit_pct" "$rq_empty" "$rq_empty_pct"
        printf '  scopes:    %s queried\n' "$rq_scopes"
    fi

    local suggestions=()
    if [ "$total" -gt 0 ] && [ "$hit_pct" -lt 50 ]; then
        local nohit=$((total - hit_count))
        suggestions+=("命中率 ${hit_pct}%: ${nohit} 条知识从未命中，运行 /know review 清理 → 预计命中率 100%")
    fi
    if [ "$total_created" -gt 0 ] && [ "$decay_pct" -gt 30 ]; then
        suggestions+=("衰减率 ${decay_pct}%: 存入质量需关注，检查 learn filter 规则")
    fi
    if [ "$total" -gt 0 ] && [ "$defensive_hits" -eq 0 ]; then
        suggestions+=("防御次数 0: 无 guard 命中，检查 rule 类知识或 scope 推断")
    fi
    if [ "$total_scopes" -gt 0 ] && [ "$scope_pct" -lt 50 ]; then
        suggestions+=("覆盖率 ${scope_pct}%: 多数 scope 未被查询，检查 recall scope 推断规则")
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

cmd_recall_log() {
    # recall-log <scope> <matched> — records to project level events.jsonl (fixed)
    local scope="${1:?Usage: recall-log <scope> <matched_count>}"
    local matched="${2:?Usage: recall-log <scope> <matched_count>}"
    local events_file
    events_file=$(events_file_for project)
    mkdir -p "$(dirname "$events_file")"
    [ -f "$events_file" ] || touch "$events_file"
    local ts
    ts=$(date +%Y-%m-%d)
    printf '{"ts":"%s","event":"recall_query","scope":"%s","matched":%s}\n' "$ts" "$scope" "$matched" >> "$events_file"
}

cmd_history() {
    # history <keyword> [--level L] — default: both
    parse_level "$@"
    set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
    local keyword="${1:?Usage: history <keyword> [--level L]}"
    local found=0
    while IFS= read -r level; do
        local events_file
        events_file=$(events_file_for "$level")
        [ -f "$events_file" ] || continue
        local results
        results=$(jq -r --arg lv "$level" "select(.summary | test(\"$keyword\"; \"i\")) | \"\(.ts)  [\(\$lv)] \(.event)\t\(.summary)\"" "$events_file" 2>/dev/null)
        if [ -n "$results" ]; then
            echo "$results"
            found=1
        fi
    done < <(levels_to_use both)
    if [ "$found" -eq 0 ]; then
        echo "No matching events found"
    fi
}

cmd_init() {
    # init [--level L] — default: both
    parse_level "$@"
    while IFS= read -r level; do
        ensure_dirs "$level"
        local level_dir index_file entries_dir
        level_dir=$(level_to_dir "$level")
        index_file=$(index_file_for "$level")
        entries_dir=$(entries_dir_for "$level")
        echo "Initialized [$level]: $level_dir"
        echo "  index:   $index_file"
        echo "  entries: $entries_dir/{insight,rule,trap}"
    done < <(levels_to_use both)

    # Legacy detection
    if [ -d "$LEGACY_KNOW_DIR" ] && [ -z "${KNOW_CTL_SKIP_LEGACY_CHECK:-}" ]; then
        if [ -f "$LEGACY_KNOW_DIR/index.jsonl" ] || [ -d "$LEGACY_KNOW_DIR/entries" ] || [ -d "$LEGACY_KNOW_DIR/docs" ]; then
            cat >&2 <<EOF

⚠️  Detected legacy .know/ directory at:
    $LEGACY_KNOW_DIR

Migrate manually:
    mv "$LEGACY_KNOW_DIR/docs" "$DOCS_DIR"  # if you want docs/ at project root
    mv "$LEGACY_KNOW_DIR/index.jsonl" "$LEGACY_KNOW_DIR/entries" "$LEGACY_KNOW_DIR/events.jsonl" "$LEGACY_KNOW_DIR/metrics.json" "$PROJECT_KNOW_DIR/"
    rmdir "$LEGACY_KNOW_DIR"

know-ctl will not read the legacy location.
EOF
        fi
    fi
}

cmd_self_test() {
    # self-test — run all core command tests in isolated XDG_DATA_HOME
    local ORIG_XDG_DATA_HOME="${XDG_DATA_HOME:-}"
    local ORIG_HOME="$HOME"
    local ORIG_CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
    local TMPDIR_TEST
    TMPDIR_TEST=$(mktemp -d)

    export XDG_DATA_HOME="$TMPDIR_TEST/share"
    export HOME="$TMPDIR_TEST/home"
    export CLAUDE_PROJECT_DIR="$TMPDIR_TEST/project"
    mkdir -p "$CLAUDE_PROJECT_DIR"
    export KNOW_CTL_SKIP_LEGACY_CHECK=1

    # Re-derive paths under new env
    PROJECT_DIR="$CLAUDE_PROJECT_DIR"
    KNOW_HOME="$XDG_DATA_HOME/know"
    PROJECT_ID=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
    PROJECT_KNOW_DIR="$KNOW_HOME/projects/$PROJECT_ID"
    USER_KNOW_DIR="$KNOW_HOME/user"
    DOCS_DIR="$PROJECT_DIR/docs"
    LEGACY_KNOW_DIR="$PROJECT_DIR/.know"

    local PASS=0 FAIL=0
    _assert() {
        local name="$1" cmd="$2"
        if eval "$cmd" > /dev/null 2>&1; then
            echo "  ✓ $name"; PASS=$((PASS + 1))
        else
            echo "  ✗ $name"; FAIL=$((FAIL + 1))
        fi
    }

    echo "=== know-ctl self-test ==="
    echo ""

    # 1. init (both levels)
    echo "init:"
    cmd_init > /dev/null 2>&1
    _assert "project dir created" '[ -d "$PROJECT_KNOW_DIR/entries/insight" ]'
    _assert "user dir created" '[ -d "$USER_KNOW_DIR/entries/insight" ]'
    _assert "project index exists" '[ -f "$PROJECT_KNOW_DIR/index.jsonl" ]'
    _assert "user index exists" '[ -f "$USER_KNOW_DIR/index.jsonl" ]'

    # 2. append — default project
    echo "append (default level=project):"
    cmd_append '{"tag":"rule","tier":1,"scope":"Test.mod","tm":"guard","summary":"project entry","path":null,"hits":0,"revs":0,"source":"learn","created":"2026-01-01","updated":"2026-01-01"}' > /dev/null
    _assert "written to project index" '[ "$(wc -l < "$PROJECT_KNOW_DIR/index.jsonl" | tr -d " ")" -eq 1 ]'
    _assert "user index still empty" '[ "$(wc -l < "$USER_KNOW_DIR/index.jsonl" | tr -d " ")" -eq 0 ]'

    # 3. append --level user
    echo "append --level user:"
    cmd_append --level user '{"tag":"insight","tier":2,"scope":"methodology.general","tm":"info","summary":"user entry","path":null,"hits":0,"revs":0,"source":"learn","created":"2026-01-01","updated":"2026-01-01"}' > /dev/null
    _assert "written to user index" '[ "$(wc -l < "$USER_KNOW_DIR/index.jsonl" | tr -d " ")" -eq 1 ]'
    _assert "project index unchanged" '[ "$(wc -l < "$PROJECT_KNOW_DIR/index.jsonl" | tr -d " ")" -eq 1 ]'

    # 4. query (no --level) → both levels
    echo "query (default both):"
    local out
    out=$(cmd_query "Test.mod")
    _assert "matches project entry" 'echo "$out" | grep -q "\"_level\":\"project\""'
    out=$(cmd_query "methodology")
    _assert "matches user entry" 'echo "$out" | grep -q "\"_level\":\"user\""'

    # 5. query --level project
    echo "query --level project:"
    out=$(cmd_query --level project "methodology")
    _assert "excludes user entry" '[ -z "$out" ]'

    # 6. query --level user
    echo "query --level user:"
    out=$(cmd_query --level user "Test.mod")
    _assert "excludes project entry" '[ -z "$out" ]'

    # 7. search
    echo "search:"
    _assert "project match" 'cmd_search "project entry" | grep -q "_level.*project"'
    _assert "user match" 'cmd_search "user entry" | grep -q "_level.*user"'

    # 8. hit (default project)
    echo "hit:"
    cmd_hit "project entry" > /dev/null
    _assert "project hits incremented" '[ "$(jq -r ".hits" "$PROJECT_KNOW_DIR/index.jsonl")" -eq 1 ]'
    _assert "user hits unchanged" '[ "$(jq -r ".hits" "$USER_KNOW_DIR/index.jsonl")" -eq 0 ]'

    # 9. hit --level user
    cmd_hit --level user "user entry" > /dev/null
    _assert "user hits incremented" '[ "$(jq -r ".hits" "$USER_KNOW_DIR/index.jsonl")" -eq 1 ]'

    # 10. update
    echo "update:"
    cmd_update "project entry" '{"summary":"project entry updated"}' > /dev/null
    _assert "project summary updated" 'grep -q "project entry updated" "$PROJECT_KNOW_DIR/index.jsonl"'
    _assert "user entry unchanged" 'grep -q "user entry" "$USER_KNOW_DIR/index.jsonl"'

    # 11. stats (both sectioned)
    echo "stats:"
    local stats_out
    stats_out=$(cmd_stats 2>&1)
    _assert "contains project section" 'echo "$stats_out" | grep -q "\[project\]"'
    _assert "contains user section" 'echo "$stats_out" | grep -q "\[user\]"'

    # 12. metrics (default project)
    echo "metrics:"
    local metrics_out
    metrics_out=$(cmd_metrics 2>&1)
    _assert "contains 命中率" 'echo "$metrics_out" | grep -q "命中率"'
    _assert "marked as [project]" 'echo "$metrics_out" | grep -q "\[project\]"'

    # 13. history
    echo "history:"
    local hist_out
    hist_out=$(cmd_history "entry")
    _assert "shows project events" 'echo "$hist_out" | grep -q "\[project\]"'
    _assert "shows user events" 'echo "$hist_out" | grep -q "\[user\]"'

    # 14. decay (construct expired user-level memo)
    echo "decay:"
    cmd_append --level user '{"tag":"insight","tier":2,"scope":"Test.decay","tm":"info","summary":"decay test memo","path":null,"hits":0,"revs":0,"source":"learn","created":"2025-01-01","updated":"2025-01-01"}' > /dev/null
    local before_user
    before_user=$(wc -l < "$USER_KNOW_DIR/index.jsonl" | tr -d ' ')
    cmd_decay > /dev/null 2>&1
    local after_user
    after_user=$(wc -l < "$USER_KNOW_DIR/index.jsonl" | tr -d ' ')
    _assert "user expired memo deleted" '[ "$after_user" -lt "$before_user" ]'

    # 15. delete (project)
    echo "delete:"
    cmd_delete "project entry updated" > /dev/null
    _assert "project entry removed" '[ "$(wc -l < "$PROJECT_KNOW_DIR/index.jsonl" | tr -d " ")" -eq 0 ]'
    _assert "user entry remains" '[ "$(wc -l < "$USER_KNOW_DIR/index.jsonl" | tr -d " ")" -eq 1 ]'

    # 16. delete --level user
    cmd_delete --level user "user entry" > /dev/null
    _assert "user entry removed" '[ "$(wc -l < "$USER_KNOW_DIR/index.jsonl" | tr -d " ")" -eq 0 ]'

    # Cleanup
    rm -rf "$TMPDIR_TEST"
    if [ -n "$ORIG_XDG_DATA_HOME" ]; then
        export XDG_DATA_HOME="$ORIG_XDG_DATA_HOME"
    else
        unset XDG_DATA_HOME
    fi
    export HOME="$ORIG_HOME"
    if [ -n "$ORIG_CLAUDE_PROJECT_DIR" ]; then
        export CLAUDE_PROJECT_DIR="$ORIG_CLAUDE_PROJECT_DIR"
    else
        unset CLAUDE_PROJECT_DIR
    fi
    unset KNOW_CTL_SKIP_LEGACY_CHECK

    echo ""
    local total=$((PASS + FAIL))
    if [ "$FAIL" -eq 0 ]; then
        echo "✓ All $total tests passed"
        return 0
    else
        echo "✗ $FAIL/$total tests failed"
        return 1
    fi
}

cmd_check() {
    # check — verify template-document consistency (docs at project root)
    local TEMPLATES_DIR="$PROJECT_DIR/workflows/templates"
    local deviations=0 consistent=0

    echo "=== know check ==="
    echo ""

    _sections() {
        grep -E '^## [0-9]+\.' "$1" 2>/dev/null | sed -E 's/^## [0-9]+\. //' | sort
    }

    _template_for() {
        local doc="$1"
        local basename
        basename=$(basename "$doc" .md)
        local tpl="$TEMPLATES_DIR/${basename}.md"
        [ -f "$tpl" ] && echo "$tpl" || echo ""
    }

    [ -d "$DOCS_DIR" ] || { echo "No docs/ directory at $DOCS_DIR"; return 0; }

    while IFS= read -r doc; do
        local tpl
        tpl=$(_template_for "$doc")
        if [ -z "$tpl" ]; then
            continue
        fi

        local tpl_sections doc_sections tpl_count doc_count
        tpl_sections=$(_sections "$tpl")
        doc_sections=$(_sections "$doc")
        tpl_count=$(echo "$tpl_sections" | grep -c . 2>/dev/null || echo 0)
        doc_count=$(echo "$doc_sections" | grep -c . 2>/dev/null || echo 0)

        local missing extra
        missing=$(comm -23 <(echo "$tpl_sections") <(echo "$doc_sections") | tr '\n' ', ' | sed 's/, $//')
        extra=$(comm -13 <(echo "$tpl_sections") <(echo "$doc_sections") | tr '\n' ', ' | sed 's/, $//')

        local rel_doc="${doc#$PROJECT_DIR/}"
        local rel_tpl
        rel_tpl=$(basename "$tpl")

        if [ -n "$missing" ] || [ -n "$extra" ]; then
            echo "✗ $rel_doc"
            echo "  模版 $rel_tpl 有 $tpl_count sections，文档有 $doc_count sections"
            [ -n "$missing" ] && echo "  缺少: $missing"
            [ -n "$extra" ] && echo "  多出: $extra"
            echo ""
            deviations=$((deviations + 1))
        else
            echo "✓ $rel_doc — 一致"
            consistent=$((consistent + 1))
        fi
    done < <(find "$DOCS_DIR" -name "*.md" 2>/dev/null)

    echo ""
    if [ "$deviations" -eq 0 ]; then
        echo "✓ 所有文档与模版一致"
        return 0
    else
        echo "=== $deviations 个偏差，$consistent 个一致 ==="
        return 1
    fi
}

# ─── Dispatch ────────────────────────────────────────────────────────

CMD="${1:-help}"
shift || true

case "$CMD" in
    query)      cmd_query "$@" ;;
    search)     cmd_search "$@" ;;
    append)     cmd_append "$@" ;;
    hit)        cmd_hit "$@" ;;
    delete)     cmd_delete "$@" ;;
    update)     cmd_update "$@" ;;
    decay)      cmd_decay "$@" ;;
    stats)      cmd_stats "$@" ;;
    metrics)    cmd_metrics "$@" ;;
    history)    cmd_history "$@" ;;
    init)       cmd_init "$@" ;;
    self-test)  cmd_self_test ;;
    check)      cmd_check ;;
    recall-log) cmd_recall_log "$@" ;;
    help|*)
        cat <<'EOF'
know-ctl.sh — CLI for know knowledge base (project + user levels)

Levels:
  project  Data at $XDG_DATA_HOME/know/projects/{id}/ (default for writes)
  user     Data at $XDG_DATA_HOME/know/user/ (shared across projects)

Pass --level {project|user} to constrain. Read commands (query/search/stats/
history/decay) default to both levels when --level is omitted; write commands
(append/update/delete/hit) default to project.

Commands:
  init [--level L]                          Create directory structure
  query <scope> [--level L] [--tag t] [--tier n] [--tm m]
                                            Filter index by scope prefix
  search <pattern> [--level L]              Regex search against summary
  append '<json>' [--level L]               Append entry to index.jsonl
  hit <path-or-keyword> [--level L]         Increment hits counter
  delete <keyword> [--level L]              Delete matching entry + detail file
  update <keyword> '<patch>' [--level L]    Update matching entry fields
  decay [--level L]                         Apply decay policy
  stats [--level L]                         Show index summary
  metrics [--level L]                       Show 6 quality indicators
  history <keyword> [--level L]             Show lifecycle events
  self-test                                 Run automated tests in temp dir
  check                                     Check template-document consistency
  recall-log <scope> <matched>              Record recall query event (project)
EOF
        ;;
esac
