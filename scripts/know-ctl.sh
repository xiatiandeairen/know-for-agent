#!/bin/bash
# know-ctl.sh — CLI for .knowledge/ index operations
# Usage: bash know-ctl.sh <command> [args]
set -euo pipefail

# Resolve paths relative to project root
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"
KNOWLEDGE_DIR="$PROJECT_DIR/.knowledge"
INDEX_FILE="$KNOWLEDGE_DIR/index.jsonl"
ENTRIES_DIR="$KNOWLEDGE_DIR/entries"

# Ensure .knowledge/ structure exists
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
    local summary
    summary=$(echo "$json" | jq -r '.summary')
    echo "Appended: $summary"
}

cmd_hit() {
    # hit <path-or-index> — increment hits, update timestamp
    local target="${1:?Usage: hit <path-or-summary>}"
    local today
    today=$(date +%Y-%m-%d)
    local tmpfile="$INDEX_FILE.tmp"

    if [[ "$target" == entries/* ]]; then
        # Match by path
        jq -c "if .path == \"$target\" then .hits += 1 | .updated = \"$today\" else . end" "$INDEX_FILE" > "$tmpfile"
    else
        # Match by summary substring
        jq -c "if (.summary | test(\"$target\"; \"i\")) then .hits += 1 | .updated = \"$today\" else . end" "$INDEX_FILE" > "$tmpfile"
    fi
    mv "$tmpfile" "$INDEX_FILE"
}

cmd_delete() {
    # delete <keyword> — remove entry matching keyword from index + detail file
    local keyword="${1:?Usage: delete <keyword>}"
    local tmpfile="$INDEX_FILE.tmp"
    local deleted=0

    while IFS= read -r line; do
        if echo "$line" | jq -e "select(.summary | test(\"$keyword\"; \"i\"))" > /dev/null 2>&1; then
            # Remove detail file if exists
            local path
            path=$(echo "$line" | jq -r '.path // empty')
            [ -n "$path" ] && [ -f "$KNOWLEDGE_DIR/$path" ] && rm "$KNOWLEDGE_DIR/$path"
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
            # Apply patch, increment revs, update timestamp
            line=$(echo "$line" | jq -c ". * $patch | .revs = (.revs // 0) + 1 | .updated = \"$today\"")
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
        local tier created hits revs
        tier=$(echo "$line" | jq -r '.tier')
        created=$(echo "$line" | jq -r '.created')
        hits=$(echo "$line" | jq -r '.hits')
        revs=$(echo "$line" | jq -r '.revs // 0')

        local created_ts age_days
        created_ts=$(date -j -f "%Y-%m-%d" "$created" +%s 2>/dev/null || date -d "$created" +%s 2>/dev/null || echo 0)
        age_days=$(( (today_ts - created_ts) / 86400 ))

        # 备忘 (tier 2) + hits=0 + >30d → delete
        if [ "$tier" -eq 2 ] && [ "$hits" -eq 0 ] && [ "$age_days" -gt 30 ]; then
            local path
            path=$(echo "$line" | jq -r '.path // empty')
            [ -n "$path" ] && [ -f "$KNOWLEDGE_DIR/$path" ] && rm "$KNOWLEDGE_DIR/$path"
            deleted=$((deleted + 1))
            continue
        fi

        # 重要 (tier 1) + hits=0 + >180d → demote to 备忘
        if [ "$tier" -eq 1 ] && [ "$hits" -eq 0 ] && [ "$age_days" -gt 180 ]; then
            line=$(echo "$line" | jq -c '.tier = 2')
            demoted=$((demoted + 1))
        fi

        # revs > 3 + 重要 (tier 1) → demote to 备忘 (unstable)
        if [ "$tier" -eq 1 ] && [ "$revs" -gt 3 ]; then
            line=$(echo "$line" | jq -c '.tier = 2')
            demoted=$((demoted + 1))
        fi

        echo "$line" >> "$tmpfile"
    done < "$INDEX_FILE"

    mv "$tmpfile" "$INDEX_FILE"
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

cmd_init() {
    # init — create .knowledge/ directory structure
    ensure_dirs
    echo "Initialized: $KNOWLEDGE_DIR"
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
    init)    cmd_init ;;
    help|*)
        cat <<'EOF'
know-ctl.sh — CLI for .knowledge/ index operations

Commands:
  init                              Create .knowledge/ directory structure
  query <scope> [--tag t] [--tier n] [--tm m]
                                    Filter index by scope prefix + optional filters
  search <pattern>                  Regex search against summary field
  append '<json>'                   Append entry to index.jsonl
  hit <path-or-keyword>             Increment hits counter, update timestamp
  delete <keyword>                  Delete matching entry + detail file
  update <keyword> '<json-patch>'   Update matching entry fields, increment revs
  decay                             Apply decay policy (delete/demote expired entries)
  stats                             Show index summary (by tier, tag, scope)
EOF
        ;;
esac
