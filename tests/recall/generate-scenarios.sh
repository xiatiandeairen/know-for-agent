#!/bin/bash
# generate-scenarios.sh — one-shot: real triggers → self-check scenarios
#
# Output: tests/recall/scenarios.jsonl (auto entries only; manual entries
# append separately). Re-running overwrites existing auto entries but
# preserves any manual ones via merge step.
#
# Usage: bash tests/recall/generate-scenarios.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

PROJECT_TRIGGERS="docs/triggers.jsonl"
USER_TRIGGERS="${XDG_CONFIG_HOME:-$HOME/.config}/know/triggers.jsonl"
OUT="tests/recall/scenarios.jsonl"
TMP_OUT=$(mktemp)

# Preserve existing manual scenarios
if [ -f "$OUT" ]; then
    jq -c 'select(.origin == "manual")' "$OUT" > "$TMP_OUT" 2>/dev/null || true
fi

gen_from_triggers() {
    local file="$1" level="$2"
    [ -f "$file" ] || return 0
    while IFS= read -r t; do
        [ -z "$t" ] && continue
        local scope first file_path
        scope=$(echo "$t" | jq -r '.scope')
        first=$(echo "$scope" | cut -d. -f1 | tr '[:upper:]' '[:lower:]')
        # Find first real file matching first segment
        file_path=$(git ls-files | grep -i -- "$first" | head -1 || true)
        [ -z "$file_path" ] && file_path=null || file_path="\"$file_path\""
        jq -cn --arg id "self-${scope}" \
               --arg scope "$scope" \
               --arg level "$level" \
               --argjson fp "$file_path" \
            '{id:$id, kind:"self-check", origin:"auto", level:$level, file_path:$fp, expected:{include:[$scope], exclude:[]}, notes:("auto-generated from " + $level + " trigger " + $scope)}' \
            >> "$TMP_OUT"
    done < "$file"
}

gen_from_triggers "$PROJECT_TRIGGERS" "project"
gen_from_triggers "$USER_TRIGGERS" "user"

# Sort: manual first, then self-check alphabetized
jq -s 'sort_by(.origin != "manual", .id) | .[]' -c "$TMP_OUT" > "$OUT"
rm "$TMP_OUT"

n_auto=$(jq -c 'select(.origin=="auto")' "$OUT" | wc -l | tr -d ' ')
n_manual=$(jq -c 'select(.origin=="manual")' "$OUT" | wc -l | tr -d ' ')
echo "Generated: $n_auto auto + $n_manual manual = $(wc -l < "$OUT" | tr -d ' ') total scenarios"
echo "Output: $OUT"
