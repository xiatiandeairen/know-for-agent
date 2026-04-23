#!/bin/bash
# know-ctl.sh — CLI for know knowledge base (v7: 3 JSONL files)
# Usage: bash know-ctl.sh <command> [--level project|user] [args]
set -euo pipefail

# ─── Paths ────────────────────────────────────────────────────────────
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
PROJECT_ID=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
PROJECT_TRIGGERS="$PROJECT_DIR/docs/triggers.jsonl"
USER_TRIGGERS="${XDG_CONFIG_HOME:-$HOME/.config}/know/triggers.jsonl"
EVENTS_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/know/events.jsonl"
DOCS_DIR="$PROJECT_DIR/docs"
LEGACY_XDG_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/know"

level_to_triggers() {
    case "$1" in
        project) echo "$PROJECT_TRIGGERS" ;;
        user)    echo "$USER_TRIGGERS" ;;
        *)       echo "Error: invalid level '$1' (expected: project|user)" >&2; exit 1 ;;
    esac
}

ensure_triggers_file() {
    local level="$1"
    local tf
    tf=$(level_to_triggers "$level")
    mkdir -p "$(dirname "$tf")"
    [ -f "$tf" ] || touch "$tf"
}

ensure_events_file() {
    mkdir -p "$(dirname "$EVENTS_FILE")"
    [ -f "$EVENTS_FILE" ] || touch "$EVENTS_FILE"
}

# ─── Argument parsing ────────────────────────────────────────────────

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

levels_to_use() {
    local default_mode="$1"
    if [ -n "$LEVEL_ARG" ]; then
        level_to_triggers "$LEVEL_ARG" >/dev/null
        echo "$LEVEL_ARG"
    elif [ "$default_mode" = "both" ]; then
        echo "project"
        echo "user"
    else
        echo "$default_mode"
    fi
}

# ─── Schema validation ───────────────────────────────────────────────

validate_entry() {
    # validate JSON: 8 fields + strict rules + ref type + source enum + keywords format
    local json="$1"
    # structural
    echo "$json" | jq -e '
        (.tag and .scope and .summary and .source and .created and .updated) and
        (.tag == "rule" or .tag == "insight" or .tag == "trap") and
        (if .tag == "rule" then ((.strict | type) == "boolean")
         else (.strict == null) end) and
        (.ref == null or (.ref | type) == "string") and
        (.source == "learn" or .source == "extract") and
        (.keywords == null or (.keywords | type) == "array")
    ' > /dev/null 2>&1 || return 1
    # keywords each must match regex (hard contract)
    local kw
    while IFS= read -r kw; do
        [ -z "$kw" ] && continue
        validate_keyword "$kw" || return 1
    done < <(echo "$json" | jq -r '.keywords[]? // empty')
    return 0
}

validate_keyword() {
    # Hard rule: keyword must be lowercase kebab-case, 2-40 chars
    local kw="$1"
    [[ "$kw" =~ ^[a-z0-9-]+$ ]] || return 1
    [ "${#kw}" -ge 2 ] || return 1
    [ "${#kw}" -le 40 ] || return 1
    return 0
}

# ─── Event emit (single file, all runtime) ───────────────────────────

emit_event() {
    # emit_event <level> <event> <summary> [<scope> <matched>]
    local level="$1" event="$2" summary="$3"
    local scope="${4:-}" matched="${5:-}"
    ensure_events_file
    local ts
    ts=$(date +%Y-%m-%d)
    if [ -n "$scope" ]; then
        jq -cn --arg ts "$ts" --arg pid "$PROJECT_ID" --arg lvl "$level" \
               --arg ev "$event" --arg sum "$summary" --arg sc "$scope" \
               --argjson m "${matched:-0}" \
               '{ts:$ts, project_id:$pid, level:$lvl, event:$ev, summary:$sum, scope:$sc, matched:$m}' \
            >> "$EVENTS_FILE"
    else
        jq -cn --arg ts "$ts" --arg pid "$PROJECT_ID" --arg lvl "$level" \
               --arg ev "$event" --arg sum "$summary" \
               '{ts:$ts, project_id:$pid, level:$lvl, event:$ev, summary:$sum}' \
            >> "$EVENTS_FILE"
    fi
}

# ─── Commands ────────────────────────────────────────────────────────

cmd_init() {
    parse_level "$@"
    while IFS= read -r level; do
        ensure_triggers_file "$level"
        local tf
        tf=$(level_to_triggers "$level")
        echo "Initialized [$level]: $tf"
    done < <(levels_to_use both)

    ensure_events_file
    echo "Events:  $EVENTS_FILE"

    # Legacy v6 detection
    if [ -z "${KNOW_CTL_SKIP_LEGACY_CHECK:-}" ]; then
        if [ -d "$LEGACY_XDG_DATA/projects" ] || [ -d "$LEGACY_XDG_DATA/user" ]; then
            cat >&2 <<EOF

⚠️  Detected v6-style layout at:
    $LEGACY_XDG_DATA/projects/{id}/...
    $LEGACY_XDG_DATA/user/...

Run to migrate to v7:
    bash scripts/know-ctl.sh migrate-v7 --dry-run   # preview
    bash scripts/know-ctl.sh migrate-v7             # execute
EOF
        fi
    fi
}

cmd_append() {
    parse_level "$@"
    set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
    local json="${1:?Usage: append '<json>' [--level L]}"
    local level
    level=$(levels_to_use project)

    validate_entry "$json" || {
        echo "Error: schema invalid. Required: tag/scope/summary/source/created/updated." >&2
        echo "       strict: tag=rule → bool; tag∈{insight,trap} → null." >&2
        exit 1
    }

    ensure_triggers_file "$level"
    local tf
    tf=$(level_to_triggers "$level")
    echo "$json" >> "$tf"
    local summary
    summary=$(echo "$json" | jq -r '.summary')
    emit_event "$level" "created" "$summary"
    echo "Appended [$level]: $summary"
}

cmd_query() {
    parse_level "$@"
    set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
    local scope="${1:?Usage: query <scope> [--level L] [--tag t] [--keywords k1,k2,k3]}"
    shift
    local tag="" keywords_csv=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tag)      tag="$2"; shift 2 ;;
            --keywords) keywords_csv="$2"; shift 2 ;;
            *)          shift ;;
        esac
    done

    # Build keywords JSON array for jq (may be empty)
    local kw_json="[]"
    if [ -n "$keywords_csv" ]; then
        kw_json=$(echo "$keywords_csv" | tr ',' '\n' | awk 'NF>0' | jq -R . | jq -s -c)
    fi

    # Combined filter: scope bidirectional prefix OR keyword intersection OR (if tag set) match tag
    local combined_filter='
        . as $e |
        (
            (
                ($e.scope | type) == "string" and
                (($e.scope | startswith($scope)) or ($scope | startswith($e.scope) and ($e.scope | length) > 0))
            )
            or
            (
                ($e.scope | type) == "array" and
                ($e.scope | any(. as $s | ($s | startswith($scope)) or ($scope | startswith($s) and ($s | length) > 0)))
            )
            or
            (
                (($query_kw | length) > 0) and (($e.keywords // []) | any(. as $k | $query_kw | index($k)))
            )
        )
    '
    [ -n "$tag" ] && combined_filter="$combined_filter and (\$e.tag == \"$tag\")"

    while IFS= read -r level; do
        local tf
        tf=$(level_to_triggers "$level")
        [ -f "$tf" ] || continue
        jq -c --arg lv "$level" --arg scope "$scope" --argjson query_kw "$kw_json" "
            select($combined_filter) |
            . + {_level: \$lv, _kw_hits: ((.keywords // []) | map(select(. as \$k | \$query_kw | index(\$k))) | length)}
        " "$tf" 2>/dev/null || true
    done < <(levels_to_use both) | sort_by_kw_hits
}

# Sort query output by _kw_hits descending (portable, uses jq).
sort_by_kw_hits() {
    # Slurp all JSONL lines; sort by _kw_hits desc; emit JSONL.
    jq -sc 'sort_by(-(._kw_hits // 0)) | .[]'
}

cmd_search() {
    parse_level "$@"
    set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
    local pattern="${1:?Usage: search <pattern> [--level L]}"
    while IFS= read -r level; do
        local tf
        tf=$(level_to_triggers "$level")
        [ -f "$tf" ] || continue
        jq -c --arg lv "$level" "select(.summary | test(\"$pattern\"; \"i\")) | . + {_level: \$lv}" "$tf" 2>/dev/null || true
    done < <(levels_to_use both)
}

cmd_hit() {
    parse_level "$@"
    set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
    local target="${1:?Usage: hit <keyword> [--level L]}"
    local level
    level=$(levels_to_use project)
    local tf
    tf=$(level_to_triggers "$level")
    [ -f "$tf" ] || { echo "No triggers for level '$level'"; exit 0; }

    local matched
    matched=$(jq -r "select(.summary | test(\"$target\"; \"i\")) | .summary" "$tf" 2>/dev/null || echo "")
    if [ -z "$matched" ]; then
        echo "Error: no entry matching '$target' in [$level]"
        exit 1
    fi
    while IFS= read -r s; do
        emit_event "$level" "hit" "$s"
    done <<< "$matched"
}

cmd_delete() {
    parse_level "$@"
    set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
    local keyword="${1:?Usage: delete <keyword> [--level L]}"
    local level
    level=$(levels_to_use project)
    local tf
    tf=$(level_to_triggers "$level")
    [ -f "$tf" ] || { echo "No triggers for level '$level'"; exit 0; }
    local tmp="$tf.tmp"
    local deleted=0
    > "$tmp"
    while IFS= read -r line; do
        if echo "$line" | jq -e "select(.summary | test(\"$keyword\"; \"i\"))" > /dev/null 2>&1; then
            local s
            s=$(echo "$line" | jq -r '.summary')
            emit_event "$level" "deleted" "$s"
            deleted=$((deleted + 1))
        else
            echo "$line" >> "$tmp"
        fi
    done < "$tf"
    if [ "$deleted" -eq 0 ]; then
        rm -f "$tmp"
        echo "Error: no entry matching '$keyword' in [$level]"
        exit 1
    fi
    mv "$tmp" "$tf"
    echo "Deleted $deleted entry [$level]"
}

cmd_update() {
    parse_level "$@"
    set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
    local keyword="${1:?Usage: update <keyword> '<json-patch>' [--level L]}"
    local patch="${2:?Usage: update <keyword> '<json-patch>' [--level L]}"
    local level
    level=$(levels_to_use project)
    local tf
    tf=$(level_to_triggers "$level")
    [ -f "$tf" ] || { echo "No triggers for level '$level'"; exit 0; }
    local today tmp matched=0
    today=$(date +%Y-%m-%d)
    tmp="$tf.tmp"
    > "$tmp"
    while IFS= read -r line; do
        if echo "$line" | jq -e "select(.summary | test(\"$keyword\"; \"i\"))" > /dev/null 2>&1; then
            local s new_line
            s=$(echo "$line" | jq -r '.summary')
            new_line=$(echo "$line" | jq -c ". * $patch | .updated = \"$today\"")
            # Re-validate: patch might violate strict rule (rule + strict=null, etc.)
            if ! validate_entry "$new_line"; then
                rm -f "$tmp"
                echo "Error: patch breaks schema (e.g. tag=rule requires strict bool)" >&2
                exit 1
            fi
            line="$new_line"
            emit_event "$level" "updated" "$s"
            matched=$((matched + 1))
        fi
        echo "$line" >> "$tmp"
    done < "$tf"
    if [ "$matched" -eq 0 ]; then
        rm -f "$tmp"
        echo "Error: no entry matching '$keyword' in [$level]"
        exit 1
    fi
    mv "$tmp" "$tf"
    echo "Updated $matched entry [$level]"
}

cmd_decay() {
    # v7: no-op; decay policy redesign deferred to next sprint
    echo "[decay] 已推延到下个 sprint（v7 schema 简化完成，衰减策略将在 v7.x 重做）"
}

cmd_stats() {
    parse_level "$@"
    while IFS= read -r level; do
        local tf
        tf=$(level_to_triggers "$level")
        echo "=== [$level] ==="
        if [ ! -f "$tf" ]; then echo "No triggers file"; echo ""; continue; fi
        local total
        total=$(wc -l < "$tf" | tr -d ' ')
        echo "Total: $total entries"
        if [ "$total" -gt 0 ]; then
            echo ""
            echo "By tag:"
            jq -r '.tag' "$tf" | sort | uniq -c | sort -rn
            echo ""
            echo "By scope:"
            jq -r 'if (.scope | type) == "array" then .scope[] else .scope end' "$tf" | sort | uniq -c | sort -rn
            echo ""
            echo "By strict (rule only):"
            jq -r 'select(.tag == "rule") | (if .strict then "hard" else "soft" end)' "$tf" | sort | uniq -c | sort -rn
        fi
        echo ""
    done < <(levels_to_use both)
}

cmd_metrics() {
    parse_level "$@"
    local level
    level=$(levels_to_use project)
    local tf
    tf=$(level_to_triggers "$level")

    local total=0
    [ -f "$tf" ] && total=$(wc -l < "$tf" | tr -d ' ')

    local hit_count=0 defensive_hits=0 rq_total=0 rq_hit=0 rq_empty=0
    local rq_with_kw=0 avg_kw_hits="0.0" top_kw=""
    if [ -f "$EVENTS_FILE" ] && [ -s "$EVENTS_FILE" ]; then
        hit_count=$(jq -s --arg lv "$level" \
            '[.[] | select(.level==$lv and .event=="hit") | .summary] | unique | length' \
            "$EVENTS_FILE")

        # defensive: hits on rule + strict=true summaries
        if [ -f "$tf" ] && [ -s "$tf" ]; then
            local strict_list
            strict_list=$(jq -s -c '[.[] | select(.tag=="rule" and .strict==true) | .summary]' "$tf" 2>/dev/null || echo "[]")
            defensive_hits=$(jq -s --arg lv "$level" --argjson ss "$strict_list" \
                '[.[] | select(.level==$lv and .event=="hit" and (.summary | IN($ss[])))] | length' \
                "$EVENTS_FILE")
        fi

        rq_total=$(jq -s --arg lv "$level" \
            '[.[] | select(.level==$lv and .event=="recall_query")] | length' \
            "$EVENTS_FILE")
        rq_hit=$(jq -s --arg lv "$level" \
            '[.[] | select(.level==$lv and .event=="recall_query" and .matched>0)] | length' \
            "$EVENTS_FILE")
        rq_empty=$((rq_total - rq_hit))
        rq_with_kw=$(jq -s --arg lv "$level" \
            '[.[] | select(.level==$lv and .event=="recall_query" and (.keywords // null) != null and ((.keywords|length) > 0))] | length' \
            "$EVENTS_FILE")
        avg_kw_hits=$(jq -s -r --arg lv "$level" \
            '[.[] | select(.level==$lv and .event=="recall_query") | (.kw_hits // 0)] as $xs
             | if ($xs|length) == 0 then "0.0"
               else (([$xs[]] | add) / ($xs|length) | . * 10 | round / 10 | tostring)
               end' \
            "$EVENTS_FILE")
        top_kw=$(jq -s -r --arg lv "$level" \
            '[.[] | select(.level==$lv and .event=="recall_query") | (.keywords // [])[] ]
             | group_by(.) | map({k:.[0], n:length}) | sort_by(-.n) | .[0:5]
             | map("\(.k)(\(.n))") | join(", ")' \
            "$EVENTS_FILE")
    fi

    local hit_pct=0 rq_hit_pct=0 rq_empty_pct=0
    [ "$total" -gt 0 ] && hit_pct=$((hit_count * 100 / total))
    [ "$rq_total" -gt 0 ] && rq_hit_pct=$((rq_hit * 100 / rq_total))
    [ "$rq_total" -gt 0 ] && rq_empty_pct=$((rq_empty * 100 / rq_total))

    cat <<EOF
=== know metrics [$level] ===

Learn — 存的有用吗？
  命中率:    $hit_count/$total ($hit_pct%)

Recall — 帮我避错了吗？
  防御次数:  $defensive_hits
EOF

    if [ "$rq_total" -gt 0 ]; then
        printf '\nRecall Run\n'
        printf '  queries:   %s (hit %s/%s%%, empty %s/%s%%)\n' "$rq_total" "$rq_hit" "$rq_hit_pct" "$rq_empty" "$rq_empty_pct"
        printf '  with kw:   %s queries carry keywords\n' "$rq_with_kw"
        printf '  avg kw_hits: %s\n' "$avg_kw_hits"
        if [ -n "$top_kw" ] && [ "$top_kw" != "null" ]; then
            printf '  top keywords: %s\n' "$top_kw"
        fi
    fi

    # M4 利用率 + M5 深度分布（近 30 天，从 events.jsonl 派生）
    if [ -f "$EVENTS_FILE" ] && [ -s "$EVENTS_FILE" ]; then
        local since
        since=$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d)
        local tf_scopes total_scopes recalled_scopes m4_pct
        local filter_30d="select(.ts>=\"$since\" and .level==\"$level\")"
        if [ -f "$tf" ] && [ -s "$tf" ]; then
            total_scopes=$(jq -sr '[.[] | .scope] | unique | length' "$tf")
        else
            total_scopes=0
        fi
        recalled_scopes=$(jq -s --arg since "$since" --arg lv "$level" \
            '[.[] | select(.event=="recall_query" and .level==$lv and .ts>=$since and .matched>0) | .scope] | unique | length' \
            "$EVENTS_FILE")
        if [ "$total_scopes" -gt 0 ]; then
            m4_pct=$((recalled_scopes * 100 / total_scopes))
        else
            m4_pct=0
        fi

        # M5 matched 分布
        local med mean b0 b1 b2 b3
        med=$(jq -sr --arg since "$since" --arg lv "$level" \
            '[.[] | select(.event=="recall_query" and .level==$lv and .ts>=$since) | .matched] as $xs
             | if ($xs|length)==0 then "—" else ($xs|sort) as $s | $s[($s|length/2|floor)] | tostring end' \
            "$EVENTS_FILE")
        mean=$(jq -sr --arg since "$since" --arg lv "$level" \
            '[.[] | select(.event=="recall_query" and .level==$lv and .ts>=$since) | .matched] as $xs
             | if ($xs|length)==0 then "—" else (([$xs[]]|add)/($xs|length) | .*10|round/10|tostring) end' \
            "$EVENTS_FILE")
        b0=$(jq -s --arg since "$since" --arg lv "$level" \
            '[.[] | select(.event=="recall_query" and .level==$lv and .ts>=$since and .matched==0)] | length' "$EVENTS_FILE")
        b1=$(jq -s --arg since "$since" --arg lv "$level" \
            '[.[] | select(.event=="recall_query" and .level==$lv and .ts>=$since and .matched>=1 and .matched<=2)] | length' "$EVENTS_FILE")
        b2=$(jq -s --arg since "$since" --arg lv "$level" \
            '[.[] | select(.event=="recall_query" and .level==$lv and .ts>=$since and .matched>=3 and .matched<=5)] | length' "$EVENTS_FILE")
        b3=$(jq -s --arg since "$since" --arg lv "$level" \
            '[.[] | select(.event=="recall_query" and .level==$lv and .ts>=$since and .matched>=6)] | length' "$EVENTS_FILE")

        printf '\n真指标（events.jsonl 派生，近 30 天）\n'
        printf '  M4 利用率:    %s/%s scopes (%s%%) 被召回过 (estimated)\n' "$recalled_scopes" "$total_scopes" "$m4_pct"
        printf '  M5 深度分布: median=%s mean=%s | 0条=%s 1-2=%s 3-5=%s 6+=%s\n' \
            "$med" "$mean" "$b0" "$b1" "$b2" "$b3"
    fi

    echo ""
    local suggestions=()
    if [ "$total" -gt 0 ] && [ "$hit_pct" -lt 50 ]; then
        local nohit=$((total - hit_count))
        suggestions+=("命中率 ${hit_pct}%: ${nohit} 条知识从未命中，运行 /know review 清理")
    fi
    if [ "$total" -gt 0 ] && [ "$defensive_hits" -eq 0 ]; then
        suggestions+=("防御次数 0: 无 strict=true rule 命中；检查 rule 的 scope 推断")
    fi

    if [ ${#suggestions[@]} -eq 0 ]; then
        echo "✅ 所有指标健康"
    else
        echo "--- 建议 ---"
        for s in "${suggestions[@]}"; do echo "• $s"; done
    fi
}

cmd_history() {
    parse_level "$@"
    set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
    local keyword="${1:-}"
    [ -f "$EVENTS_FILE" ] || { echo "No events file"; exit 0; }

    local filter='true'
    [ -n "$keyword" ] && filter="(.summary | test(\"$keyword\"; \"i\"))"
    if [ -n "$LEVEL_ARG" ]; then
        filter="$filter and .level == \"$LEVEL_ARG\""
    fi

    local results
    results=$(jq -r "select($filter) | \"\(.ts)  [\(.level)] \(.event)\t\(.summary)\"" "$EVENTS_FILE" 2>/dev/null)
    if [ -z "$results" ]; then
        echo "No matching events"
    else
        echo "$results"
    fi
}

cmd_recall_log() {
    # recall-log <scope> <matched> [--level L] [--keywords k1,k2,k3] [--kw-hits N]
    parse_level "$@"
    set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
    local scope="" matched="" keywords_csv="" kw_hits=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --keywords) keywords_csv="$2"; shift 2 ;;
            --kw-hits)  kw_hits="$2"; shift 2 ;;
            *)
                if [ -z "$scope" ]; then scope="$1"; shift
                elif [ -z "$matched" ]; then matched="$1"; shift
                else shift
                fi
                ;;
        esac
    done
    [ -z "$scope" ] && { echo "Usage: recall-log <scope> <matched> [--level L] [--keywords k1,k2,k3] [--kw-hits N]" >&2; exit 1; }
    [ -z "$matched" ] && { echo "Usage: recall-log <scope> <matched> [--level L] [--keywords k1,k2,k3] [--kw-hits N]" >&2; exit 1; }

    local level="${LEVEL_ARG:-project}"
    ensure_events_file
    local ts
    ts=$(date +%Y-%m-%d)

    # Build keywords JSON array (null if not provided)
    local kw_json="null"
    if [ -n "$keywords_csv" ]; then
        kw_json=$(echo "$keywords_csv" | tr ',' '\n' | awk 'NF>0' | jq -R . | jq -s -c)
    fi

    # kw_hits default 0 if not provided
    local kh="${kw_hits:-0}"

    jq -cn --arg ts "$ts" --arg pid "$PROJECT_ID" --arg lvl "$level" \
           --arg sc "$scope" --argjson m "$matched" \
           --argjson kws "$kw_json" --argjson kh "$kh" \
           '{ts:$ts, project_id:$pid, level:$lvl, event:"recall_query", scope:$sc, matched:$m, keywords:$kws, kw_hits:$kh}' \
        >> "$EVENTS_FILE"
}

cmd_report_recall() {
    parse_level "$@"
    set -- "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"
    local days=7
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --days) days="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    [ -f "$EVENTS_FILE" ] && [ -s "$EVENTS_FILE" ] || { echo "[report-recall] no events"; return 0; }

    local since
    since=$(date -v-"${days}"d +%Y-%m-%d 2>/dev/null || date -d "${days} days ago" +%Y-%m-%d)
    local level="${LEVEL_ARG:-project}"

    local filter
    filter="select(.event==\"recall_query\" and .level==\"$level\" and .project_id==\"$PROJECT_ID\" and .ts>=\"$since\")"

    local total hit empty with_kw avg_kh top_kw top_scope
    total=$(jq -s "[.[] | $filter] | length" "$EVENTS_FILE")
    [ "$total" -eq 0 ] && { echo "# Recall Report (last ${days}d)"; echo ""; echo "No recall_query events in window."; return 0; }

    hit=$(jq -s "[.[] | $filter | select(.matched>0)] | length" "$EVENTS_FILE")
    empty=$((total - hit))
    with_kw=$(jq -s "[.[] | $filter | select((.keywords // null) != null and ((.keywords|length)>0))] | length" "$EVENTS_FILE")
    avg_kh=$(jq -s -r "[.[] | $filter | (.kw_hits // 0)] as \$xs | if (\$xs|length)==0 then \"0.0\" else (([\$xs[]]|add)/(\$xs|length) | .*10|round/10|tostring) end" "$EVENTS_FILE")
    top_kw=$(jq -s -r "[.[] | $filter | (.keywords // [])[]] | group_by(.) | map({k:.[0],n:length}) | sort_by(-.n) | .[0:5] | map(\"- \(.k) (\(.n))\") | join(\"\n\")" "$EVENTS_FILE")
    top_scope=$(jq -s -r "[.[] | $filter | .scope] | group_by(.) | map({s:.[0],n:length}) | sort_by(-.n) | .[0:5] | map(\"- \(.s) (\(.n))\") | join(\"\n\")" "$EVENTS_FILE")

    local hit_pct=0 empty_pct=0
    [ "$total" -gt 0 ] && hit_pct=$((hit * 100 / total)) && empty_pct=$((empty * 100 / total))

    cat <<EOF
# Recall Report (last ${days}d, level=${level})

## Summary

| Metric | Value |
|---|---|
| Total queries | $total |
| Hit | $hit ($hit_pct%) |
| Empty | $empty ($empty_pct%) |
| With keywords | $with_kw |
| Avg kw_hits | $avg_kh |

## Top scopes

${top_scope:-_none_}

## Top keywords

${top_kw:-_none_}
EOF
}

cmd_check() {
    local TEMPLATES_DIR="$PROJECT_DIR/workflows/templates"
    local deviations=0 consistent=0

    echo "=== know check ==="
    echo ""

    _sections() { grep -E '^## [0-9]+\.' "$1" 2>/dev/null | sed -E 's/^## [0-9]+\. //' | sort; }
    _template_for() {
        local doc="$1" basename
        basename=$(basename "$doc" .md)
        local tpl="$TEMPLATES_DIR/${basename}.md"
        [ -f "$tpl" ] && echo "$tpl" || echo ""
    }

    [ -d "$DOCS_DIR" ] || { echo "No docs/ at $DOCS_DIR"; return 0; }

    while IFS= read -r doc; do
        local tpl
        tpl=$(_template_for "$doc")
        [ -z "$tpl" ] && continue
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
            echo "  模版 $rel_tpl 有 $tpl_count sections，文档有 $doc_count"
            [ -n "$missing" ] && echo "  缺少: $missing"
            [ -n "$extra" ] && echo "  多出: $extra"
            echo ""
            deviations=$((deviations + 1))
        else
            echo "✓ $rel_doc"
            consistent=$((consistent + 1))
        fi
    done < <(find "$DOCS_DIR" -name "*.md" 2>/dev/null)

    echo ""
    if [ "$deviations" -eq 0 ]; then
        echo "✓ 所有文档与模版一致"
        return 0
    else
        echo "=== $deviations 偏差 / $consistent 一致 ==="
        return 1
    fi
}

_convert_v6_entry_to_v7() {
    # $1 = v6 JSON line  $2 = old dir (for reading detail md)  $3 = legacy md out path
    local old_line="$1" old_dir="$2" legacy_md="$3"

    local tag summary source created updated old_tm old_path
    tag=$(echo "$old_line" | jq -r '.tag')
    summary=$(echo "$old_line" | jq -r '.summary')
    source=$(echo "$old_line" | jq -r '.source // "learn"')
    created=$(echo "$old_line" | jq -r '.created')
    updated=$(echo "$old_line" | jq -r '.updated')
    old_tm=$(echo "$old_line" | jq -r '.tm // empty')
    old_path=$(echo "$old_line" | jq -r '.path // empty')
    local scope_json
    scope_json=$(echo "$old_line" | jq -c '.scope')

    # strict: rule + guard → true; rule + other → false; non-rule → null
    local strict_json
    if [ "$tag" = "rule" ]; then
        if [ "$old_tm" = "guard" ]; then strict_json=true; else strict_json=false; fi
    else
        strict_json=null
    fi

    # ref: migrate detail md to legacy file, set ref to anchor
    local ref_json=null
    if [ -n "$old_path" ] && [ -f "$old_dir/$old_path" ]; then
        local anchor
        anchor=$(basename "$old_path" .md)
        mkdir -p "$(dirname "$legacy_md")"
        if [ ! -f "$legacy_md" ]; then
            cat > "$legacy_md" <<'HEADER'
# 遗留详情（v6 迁移）

本文件由 `bash scripts/know-ctl.sh migrate-v7` 自动生成。每节对应一条原 v6 critical entry 的详情。请 review 后手工搬迁到对应 `docs/decision/` 或 `docs/arch/` 位置，然后用 `know-ctl update` 改 trigger 的 `ref` 字段指向新位置。
HEADER
        fi
        {
            echo ""
            echo "## $anchor"
            echo ""
            cat "$old_dir/$old_path"
            echo ""
        } >> "$legacy_md"
        local rel_legacy
        rel_legacy="docs/$(basename "$legacy_md")"
        ref_json="\"$rel_legacy#$anchor\""
    fi

    jq -cn --arg tag "$tag" \
           --argjson scope "$scope_json" \
           --arg summary "$summary" \
           --argjson strict "$strict_json" \
           --argjson ref "$ref_json" \
           --arg source "$source" \
           --arg created "$created" \
           --arg updated "$updated" \
           '{tag:$tag, scope:$scope, summary:$summary, strict:$strict, ref:$ref, source:$source, created:$created, updated:$updated}'
}

cmd_migrate_v7() {
    local DRY_RUN=0
    if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=1; fi

    echo "=== migrate-v7${DRY_RUN:+ (dry-run)} ==="
    echo ""

    # Idempotency guard: refuse if target triggers.jsonl is non-empty
    # (re-running would duplicate entries). Skip in dry-run.
    if [ "$DRY_RUN" = 0 ]; then
        for tf in "$PROJECT_TRIGGERS" "$USER_TRIGGERS"; do
            if [ -f "$tf" ] && [ -s "$tf" ]; then
                echo "Error: $tf already has data. Re-running would duplicate." >&2
                echo "       If you intend to re-migrate, remove or back up the file first:" >&2
                echo "           mv \"$tf\" \"$tf.bak\"" >&2
                exit 1
            fi
        done
    fi

    local old_projects="$LEGACY_XDG_DATA/projects"
    local old_user="$LEGACY_XDG_DATA/user"
    local old_project_dir="$old_projects/$PROJECT_ID"

    # ─── project level ───
    if [ -d "$old_project_dir" ] && [ -f "$old_project_dir/index.jsonl" ]; then
        local idx="$old_project_dir/index.jsonl"
        local legacy_md="$DOCS_DIR/legacy-v6-details.md"
        local n_entries n_details
        n_entries=$(wc -l < "$idx" | tr -d ' ')
        n_details=$(find "$old_project_dir/entries" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        echo "[project] $idx"
        echo "  entries: $n_entries (detail files: $n_details)"
        if [ "$DRY_RUN" = 1 ]; then
            echo "  → would write $PROJECT_TRIGGERS"
            [ "$n_details" -gt 0 ] && echo "  → would generate $legacy_md with detail sections"
        else
            ensure_triggers_file project
            local count=0
            while IFS= read -r line; do
                local new_entry
                new_entry=$(_convert_v6_entry_to_v7 "$line" "$old_project_dir" "$legacy_md")
                echo "$new_entry" >> "$PROJECT_TRIGGERS"
                count=$((count + 1))
            done < "$idx"
            echo "  ✓ migrated $count entries → $PROJECT_TRIGGERS"
            [ "$n_details" -gt 0 ] && echo "  ✓ detail sections → $legacy_md"
        fi
    else
        echo "[project] no v6 data at $old_project_dir (skip)"
    fi

    # project events merge
    if [ -f "$old_project_dir/events.jsonl" ]; then
        local n_events
        n_events=$(wc -l < "$old_project_dir/events.jsonl" | tr -d ' ')
        echo "  events: $n_events"
        if [ "$DRY_RUN" = 1 ]; then
            echo "  → would merge into $EVENTS_FILE (with project_id + level)"
        else
            ensure_events_file
            jq -c --arg pid "$PROJECT_ID" --arg lvl "project" \
                '. + {project_id: $pid, level: $lvl}' \
                "$old_project_dir/events.jsonl" >> "$EVENTS_FILE"
            echo "  ✓ events merged"
        fi
    fi

    echo ""

    # ─── user level ───
    if [ -d "$old_user" ] && [ -f "$old_user/index.jsonl" ]; then
        local idx="$old_user/index.jsonl"
        local legacy_md_user="${XDG_CONFIG_HOME:-$HOME/.config}/know/legacy-v6-details.md"
        local n_entries
        n_entries=$(wc -l < "$idx" | tr -d ' ')
        echo "[user] $idx"
        echo "  entries: $n_entries"
        if [ "$DRY_RUN" = 1 ]; then
            echo "  → would write $USER_TRIGGERS"
        else
            ensure_triggers_file user
            local count=0
            while IFS= read -r line; do
                local new_entry
                new_entry=$(_convert_v6_entry_to_v7 "$line" "$old_user" "$legacy_md_user")
                echo "$new_entry" >> "$USER_TRIGGERS"
                count=$((count + 1))
            done < "$idx"
            echo "  ✓ migrated $count entries → $USER_TRIGGERS"
        fi
    else
        echo "[user] no v6 data at $old_user (skip)"
    fi

    if [ -f "$old_user/events.jsonl" ]; then
        local n_events
        n_events=$(wc -l < "$old_user/events.jsonl" | tr -d ' ')
        echo "  events: $n_events"
        if [ "$DRY_RUN" = 1 ]; then
            echo "  → would merge user events"
        else
            ensure_events_file
            jq -c --arg lvl "user" \
                '. + {project_id: null, level: $lvl}' \
                "$old_user/events.jsonl" >> "$EVENTS_FILE"
            echo "  ✓ user events merged"
        fi
    fi

    echo ""
    if [ "$DRY_RUN" = 1 ]; then
        echo "Dry-run complete. Re-run without --dry-run to execute."
    else
        cat <<EOF
Migration complete.

Schema changes:
  tier / tm / path → removed
  strict (bool for rule, null for insight/trap) added
  ref (replaces path) added
  hits / revs → removed (runtime now derived from events)

Legacy detail files consolidated to:
  docs/legacy-v6-details.md
Review and move content into proper docs/decision/ or docs/arch/; update
trigger refs with: bash scripts/know-ctl.sh update <kw> '{"ref":"docs/xxx.md#anchor"}'

To remove v6 data after verification:
  rm -rf "$old_projects" "$old_user"
EOF
    fi
}

cmd_keywords() {
    # Output unique keywords with usage counts, sorted by count desc.
    # Aggregates across both levels.
    parse_level "$@"
    local all_kws=""
    while IFS= read -r level; do
        local tf
        tf=$(level_to_triggers "$level")
        [ -f "$tf" ] || continue
        all_kws=$(printf '%s\n%s' "$all_kws" "$(jq -r '.keywords[]? // empty' "$tf" 2>/dev/null)")
    done < <(levels_to_use both)
    if [ -z "$all_kws" ]; then
        echo "(keyword vocabulary empty)"
        return
    fi
    echo "$all_kws" | awk 'NF>0' | sort | uniq -c | sort -rn | awk '{printf "%s (%d)\n", $2, $1}'
}

cmd_retag_keywords() {
    # Interactive stub: prints each trigger with empty keywords and
    # suggests user run /know learn or update --keywords manually.
    # (Claude can drive the interaction from its context.)
    parse_level "$@"
    local found=0
    while IFS= read -r level; do
        local tf
        tf=$(level_to_triggers "$level")
        [ -f "$tf" ] || continue
        jq -c 'select(.keywords == null or (.keywords | length) == 0)' "$tf" 2>/dev/null | while IFS= read -r line; do
            summary=$(echo "$line" | jq -r '.summary')
            scope=$(echo "$line" | jq -r '.scope')
            tag=$(echo "$line" | jq -r '.tag')
            echo "[$level] [$tag] $scope :: $summary"
            found=1
        done
    done < <(levels_to_use both)
    if [ "$found" = 0 ]; then
        echo "All triggers have keywords. Nothing to retag."
    else
        echo ""
        echo "For each entry above, suggest keywords and run:"
        echo "  bash know-ctl.sh update \"<keyword-in-summary>\" '{\"keywords\":[\"k1\",\"k2\",...]}' --level <L>"
    fi
}

# ─── self-test ───────────────────────────────────────────────────────

cmd_self_test() {
    local ORIG_XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-}"
    local ORIG_XDG_DATA_HOME="${XDG_DATA_HOME:-}"
    local ORIG_HOME="$HOME"
    local ORIG_CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
    local TMPDIR_TEST
    TMPDIR_TEST=$(mktemp -d)

    export XDG_CONFIG_HOME="$TMPDIR_TEST/config"
    export XDG_DATA_HOME="$TMPDIR_TEST/data"
    export HOME="$TMPDIR_TEST/home"
    export CLAUDE_PROJECT_DIR="$TMPDIR_TEST/project"
    mkdir -p "$CLAUDE_PROJECT_DIR/docs"
    export KNOW_CTL_SKIP_LEGACY_CHECK=1

    # Re-derive
    PROJECT_DIR="$CLAUDE_PROJECT_DIR"
    PROJECT_ID=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
    PROJECT_TRIGGERS="$PROJECT_DIR/docs/triggers.jsonl"
    USER_TRIGGERS="$XDG_CONFIG_HOME/know/triggers.jsonl"
    EVENTS_FILE="$XDG_DATA_HOME/know/events.jsonl"
    DOCS_DIR="$PROJECT_DIR/docs"
    LEGACY_XDG_DATA="$XDG_DATA_HOME/know"

    local PASS=0 FAIL=0
    _assert() {
        local name="$1" cmd="$2"
        if eval "$cmd" > /dev/null 2>&1; then
            echo "  ✓ $name"; PASS=$((PASS + 1))
        else
            echo "  ✗ $name"; FAIL=$((FAIL + 1))
        fi
    }

    echo "=== know-ctl v7 self-test ==="
    echo ""

    # 1. init
    echo "init:"
    cmd_init > /dev/null 2>&1
    _assert "project triggers created" '[ -f "$PROJECT_TRIGGERS" ]'
    _assert "user triggers created" '[ -f "$USER_TRIGGERS" ]'
    _assert "events file created" '[ -f "$EVENTS_FILE" ]'

    # 2. append project rule (strict=true)
    echo "append project (rule, strict=true):"
    cmd_append '{"tag":"rule","scope":"Auth.session","summary":"project rule entry","strict":true,"ref":null,"source":"learn","created":"2026-04-22","updated":"2026-04-22"}' > /dev/null
    _assert "written to project triggers" '[ "$(wc -l < "$PROJECT_TRIGGERS" | tr -d " ")" -eq 1 ]'
    _assert "user triggers unchanged" '[ "$(wc -l < "$USER_TRIGGERS" | tr -d " ")" -eq 0 ]'
    _assert "created event emitted" 'grep -q "\"event\":\"created\"" "$EVENTS_FILE"'
    _assert "event has project_id" 'grep -q "\"project_id\"" "$EVENTS_FILE"'
    _assert "event has level" 'grep -q "\"level\":\"project\"" "$EVENTS_FILE"'

    # 3. append user insight (strict=null)
    echo "append user (insight, strict=null):"
    cmd_append --level user '{"tag":"insight","scope":"methodology.general","summary":"user insight entry","strict":null,"ref":null,"source":"learn","created":"2026-04-22","updated":"2026-04-22"}' > /dev/null
    _assert "written to user triggers" '[ "$(wc -l < "$USER_TRIGGERS" | tr -d " ")" -eq 1 ]'

    # 4. invalid: rule with strict=null → fail
    echo "invalid entry checks:"
    _assert "rule + strict=null fails" '! ( cmd_append "{\"tag\":\"rule\",\"scope\":\"X\",\"summary\":\"bad\",\"strict\":null,\"ref\":null,\"source\":\"learn\",\"created\":\"2026-01-01\",\"updated\":\"2026-01-01\"}" ) 2>/dev/null'
    _assert "insight + strict=true fails" '! ( cmd_append "{\"tag\":\"insight\",\"scope\":\"X\",\"summary\":\"bad\",\"strict\":true,\"ref\":null,\"source\":\"learn\",\"created\":\"2026-01-01\",\"updated\":\"2026-01-01\"}" ) 2>/dev/null'
    _assert "missing summary fails" '! ( cmd_append "{\"tag\":\"rule\",\"scope\":\"X\",\"strict\":true,\"ref\":null,\"source\":\"learn\",\"created\":\"2026-01-01\",\"updated\":\"2026-01-01\"}" ) 2>/dev/null'
    _assert "invalid tag fails" '! ( cmd_append "{\"tag\":\"bogus\",\"scope\":\"X\",\"summary\":\"bad\",\"strict\":null,\"ref\":null,\"source\":\"learn\",\"created\":\"2026-01-01\",\"updated\":\"2026-01-01\"}" ) 2>/dev/null'
    _assert "invalid source fails" '! ( cmd_append "{\"tag\":\"insight\",\"scope\":\"X\",\"summary\":\"bad\",\"strict\":null,\"ref\":null,\"source\":\"bogus\",\"created\":\"2026-01-01\",\"updated\":\"2026-01-01\"}" ) 2>/dev/null'
    _assert "ref as number fails" '! ( cmd_append "{\"tag\":\"insight\",\"scope\":\"X\",\"summary\":\"bad\",\"strict\":null,\"ref\":42,\"source\":\"learn\",\"created\":\"2026-01-01\",\"updated\":\"2026-01-01\"}" ) 2>/dev/null'

    # 5. query
    echo "query:"
    local out
    out=$(cmd_query "Auth")
    _assert "query finds project entry with _level" 'echo "$out" | grep -q "\"_level\":\"project\""'
    out=$(cmd_query "methodology")
    _assert "query finds user entry" 'echo "$out" | grep -q "\"_level\":\"user\""'
    out=$(cmd_query --level project "methodology")
    _assert "query --level project excludes user" '[ -z "$out" ]'

    # 6. search
    echo "search:"
    _assert "search matches project" 'cmd_search "project rule" | grep -q "_level.*project"'

    # 7. hit
    echo "hit:"
    cmd_hit "project rule" > /dev/null
    _assert "hit event emitted" 'grep -q "\"event\":\"hit\"" "$EVENTS_FILE"'

    # 8. update
    echo "update:"
    cmd_update "project rule" '{"scope":"Auth.session.refresh"}' > /dev/null
    _assert "scope updated in triggers" 'grep -q "Auth.session.refresh" "$PROJECT_TRIGGERS"'
    _assert "updated event emitted" 'grep -q "\"event\":\"updated\"" "$EVENTS_FILE"'
    # update that breaks schema must fail
    _assert "update breaking schema fails" '! ( cmd_update "project rule" "{\"strict\":null}" ) 2>/dev/null'

    # 9. stats
    echo "stats:"
    local stats_out
    stats_out=$(cmd_stats 2>&1)
    _assert "stats shows project section" 'echo "$stats_out" | grep -q "\[project\]"'
    _assert "stats shows user section" 'echo "$stats_out" | grep -q "\[user\]"'
    _assert "stats shows strict counts" 'echo "$stats_out" | grep -q "hard\|soft"'

    # 10. metrics
    echo "metrics:"
    local metrics_out
    metrics_out=$(cmd_metrics 2>&1)
    _assert "metrics contains 命中率" 'echo "$metrics_out" | grep -q "命中率"'
    _assert "metrics contains 防御次数" 'echo "$metrics_out" | grep -q "防御次数"'
    _assert "defensive_hits > 0 after hit" 'echo "$metrics_out" | grep -E "防御次数:[[:space:]]+[1-9]" > /dev/null'

    # 11. history
    echo "history:"
    local hist_out
    hist_out=$(cmd_history "rule")
    _assert "history finds events" 'echo "$hist_out" | grep -q "\[project\]"'
    hist_out=$(cmd_history --level user "")
    _assert "history --level user filters" '[ -n "$hist_out" ] || [ -z "$hist_out" ]'

    # 12. recall-log
    echo "recall-log:"
    cmd_recall_log "Auth.session" "1"
    _assert "recall_query event emitted" 'grep -q "\"event\":\"recall_query\"" "$EVENTS_FILE"'
    cmd_recall_log "Payment.webhook" "2" --keywords "webhook,signature-verification" --kw-hits "2"
    _assert "recall_query with keywords field" 'grep -q "\"keywords\":\[\"webhook\",\"signature-verification\"\]" "$EVENTS_FILE"'
    _assert "recall_query with kw_hits field" 'grep -q "\"kw_hits\":2" "$EVENTS_FILE"'
    local metrics_out
    metrics_out=$(cmd_metrics 2>&1)
    _assert "metrics shows avg kw_hits" 'echo "$metrics_out" | grep -q "avg kw_hits"'
    _assert "metrics shows top keywords" 'echo "$metrics_out" | grep -q "top keywords"'
    local rr_out
    rr_out=$(cmd_report_recall --days 30 2>&1)
    _assert "report-recall outputs markdown header" 'echo "$rr_out" | grep -q "# Recall Report"'

    # 13. decay no-op
    echo "decay:"
    local decay_out
    decay_out=$(cmd_decay)
    _assert "decay outputs deferred msg" 'echo "$decay_out" | grep -q "推延"'
    _assert "no deletion from triggers" '[ "$(wc -l < "$PROJECT_TRIGGERS" | tr -d " ")" -ge 1 ]'

    # 14. delete
    echo "delete:"
    cmd_delete "project rule" > /dev/null
    _assert "project entry removed" '[ "$(wc -l < "$PROJECT_TRIGGERS" | tr -d " ")" -eq 0 ]'
    _assert "user entry remains" '[ "$(wc -l < "$USER_TRIGGERS" | tr -d " ")" -eq 1 ]'
    _assert "deleted event emitted" 'grep -q "\"event\":\"deleted\"" "$EVENTS_FILE"'

    # 15. migrate-v7 idempotency: existing non-empty triggers → refuse
    echo "migrate-v7 idempotency:"
    # setup: leave user trigger non-empty
    _assert "migrate-v7 refuses non-empty triggers" '! ( cmd_migrate_v7 ) 2>/dev/null'
    # but dry-run should work regardless
    _assert "migrate-v7 --dry-run works on non-empty" 'cmd_migrate_v7 --dry-run 2>&1 | grep -q "dry-run"'

    # 16. keyword validation (hard contract)
    echo "keyword validation:"
    _assert "lowercase-kebab ok" 'validate_keyword "webhook"'
    _assert "multi-word kebab ok" 'validate_keyword "signature-verification"'
    _assert "with digits ok" 'validate_keyword "api-v2"'
    _assert "reject uppercase" '! validate_keyword "Webhook"'
    _assert "reject underscore" '! validate_keyword "web_hook"'
    _assert "reject space" '! validate_keyword "api design"'
    _assert "reject chinese" '! validate_keyword "签名"'
    _assert "reject single char" '! validate_keyword "a"'
    _assert "reject empty" '! validate_keyword ""'

    # 17. append with keywords: valid + invalid
    echo "append with keywords:"
    # user entries were removed, project empty; setup a fresh one
    cmd_append '{"tag":"rule","scope":"Auth.session","summary":"kw test","strict":true,"ref":null,"keywords":["authentication","session-management"],"source":"learn","created":"2026-04-22","updated":"2026-04-22"}' > /dev/null
    _assert "append with valid keywords accepts" 'grep -q "\"authentication\"" "$PROJECT_TRIGGERS"'
    _assert "append with invalid keyword rejects" '! ( cmd_append "{\"tag\":\"insight\",\"scope\":\"X\",\"summary\":\"bad\",\"strict\":null,\"ref\":null,\"keywords\":[\"Bad_Name\"],\"source\":\"learn\",\"created\":\"2026-04-22\",\"updated\":\"2026-04-22\"}" ) 2>/dev/null'

    # 18. keywords subcommand: output vocabulary
    echo "keywords subcommand:"
    local kwout
    kwout=$(cmd_keywords 2>&1)
    _assert "keywords lists authentication" 'echo "$kwout" | grep -q authentication'
    _assert "keywords lists session-management" 'echo "$kwout" | grep -q session-management'

    # 19. query --keywords: intersection match
    echo "query --keywords:"
    local qout
    qout=$(cmd_query "NoSuchScope" --keywords authentication,session-management)
    _assert "query --keywords hits by keyword alone" 'echo "$qout" | grep -q "kw test"'
    qout=$(cmd_query "NoSuchScope" --keywords unrelated-kw)
    _assert "query --keywords misses when keywords absent" '[ -z "$qout" ]'

    # 20. scope bidirectional prefix: parent scope call matches child trigger AND vice versa
    echo "scope bidirectional:"
    cmd_append '{"tag":"rule","scope":"Auth.session.refresh","summary":"child scope entry","strict":false,"ref":null,"keywords":null,"source":"learn","created":"2026-04-22","updated":"2026-04-22"}' > /dev/null
    # query with parent scope should also match child entry
    qout=$(cmd_query "Auth.session" --level project)
    _assert "parent-scope query matches parent entry" 'echo "$qout" | grep -q "kw test"'
    _assert "parent-scope query matches child entry" 'echo "$qout" | grep -q "child scope entry"'
    # query with child scope should also match parent entry (bidirectional)
    qout=$(cmd_query "Auth.session.refresh.deep" --level project)
    _assert "deep-child query matches parent (bidirectional)" 'echo "$qout" | grep -q "kw test"'

    # 21. scope="project" no longer returns all (special case removed)
    echo "scope project no-special-case:"
    qout=$(cmd_query "project" --level project)
    # "project" as a literal scope prefix matches no trigger whose scope starts with "project" (none of ours do)
    _assert "scope=project no longer returns all" '[ -z "$(echo "$qout" | grep -v "^$")" ]'

    # Cleanup
    rm -rf "$TMPDIR_TEST"
    if [ -n "$ORIG_XDG_CONFIG_HOME" ]; then export XDG_CONFIG_HOME="$ORIG_XDG_CONFIG_HOME"; else unset XDG_CONFIG_HOME; fi
    if [ -n "$ORIG_XDG_DATA_HOME" ]; then export XDG_DATA_HOME="$ORIG_XDG_DATA_HOME"; else unset XDG_DATA_HOME; fi
    export HOME="$ORIG_HOME"
    if [ -n "$ORIG_CLAUDE_PROJECT_DIR" ]; then export CLAUDE_PROJECT_DIR="$ORIG_CLAUDE_PROJECT_DIR"; else unset CLAUDE_PROJECT_DIR; fi
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

# ─── Dispatch ────────────────────────────────────────────────────────

CMD="${1:-help}"
shift || true

case "$CMD" in
    init)        cmd_init "$@" ;;
    append)      cmd_append "$@" ;;
    query)       cmd_query "$@" ;;
    search)      cmd_search "$@" ;;
    hit)         cmd_hit "$@" ;;
    delete)      cmd_delete "$@" ;;
    update)      cmd_update "$@" ;;
    decay)       cmd_decay ;;
    stats)       cmd_stats "$@" ;;
    metrics)     cmd_metrics "$@" ;;
    history)     cmd_history "$@" ;;
    recall-log)  cmd_recall_log "$@" ;;
    report-recall) cmd_report_recall "$@" ;;
    check)       cmd_check ;;
    migrate-v7)  cmd_migrate_v7 "$@" ;;
    keywords)    cmd_keywords "$@" ;;
    retag-keywords) cmd_retag_keywords "$@" ;;
    self-test)   cmd_self_test ;;
    help|*)
        cat <<'EOF'
know-ctl.sh (v7) — CLI for know knowledge base

Storage (3 files):
  <project>/docs/triggers.jsonl          project source (git)
  $XDG_CONFIG_HOME/know/triggers.jsonl   user source (dotfiles-git optional)
  $XDG_DATA_HOME/know/events.jsonl       runtime (all events; project_id+level fields)

Entry schema (8 fields):
  tag:     "rule" | "insight" | "trap"
  scope:   dot-separated keypath
  summary: ≤80 chars
  strict:  bool (rule only) | null (insight/trap)
  ref:     "docs/x.md#a" | "src/f:42" | "https://..." | null
  source:  "learn" | "extract"
  created: YYYY-MM-DD
  updated: YYYY-MM-DD

Commands:
  init [--level L]                    Create triggers/events files (detect v6 → suggest migrate)
  append '<json>' [--level L]         Add entry (validates 8 fields + strict rule)
  query <scope> [--level L] [--tag t] Scope-prefix search; output has _level field
  search <pattern> [--level L]        Regex search summary
  hit <keyword> [--level L]           Record hit event
  update <keyword> '<patch>' [--level L]
  delete <keyword> [--level L]
  decay                               v7: no-op (deferred to next sprint)
  stats [--level L]                   Counts by tag/scope/strict
  metrics [--level L]                 Hit rate + defensive count (derived from events)
  history [keyword] [--level L]       Event lifecycle
  recall-log <scope> <matched> [--level L] [--keywords k1,k2,k3] [--kw-hits N]
  report-recall [--days N] [--level L]  Recall query window report (markdown)
  check                               Template-doc structure consistency
  migrate-v7 [--dry-run]              v6 → v7 data migration (T2 impl)
  self-test                           Run 29+ assertions in isolated XDG
EOF
        ;;
esac
