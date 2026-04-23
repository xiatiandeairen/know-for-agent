#!/bin/bash
# recall benchmark runner — black-box evaluation of recall quality
#
# Reads fixture-triggers.jsonl + scenarios.jsonl, isolates know-ctl
# via temp CLAUDE_PROJECT_DIR + XDG dirs, queries per scenario's
# inferred_scope, compares actual vs expected, outputs precision /
# recall / F1 per scenario and per type group.
#
# Black-box discipline: this script only calls the `know-ctl query`
# CLI. It must NOT inline the scope-matching logic (jq expressions
# against triggers.jsonl) — that would collapse into circular
# validation of the algorithm against itself.

set -euo pipefail

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$BENCH_DIR/../../.." && pwd)"
KNOW_CTL="$PROJECT_ROOT/scripts/know-ctl.sh"
FIXTURE="$BENCH_DIR/fixture-triggers.jsonl"
SCENARIOS="$BENCH_DIR/scenarios.jsonl"
RESULTS_DIR="$BENCH_DIR/results"

DATE=$(date +%Y-%m-%dT%H%M%S)
REPORT="$RESULTS_DIR/$DATE.md"

# ─── Setup isolated env ──────────────────────────────────────

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

export CLAUDE_PROJECT_DIR="$TMPDIR_TEST/project"
export XDG_CONFIG_HOME="$TMPDIR_TEST/config"
export XDG_DATA_HOME="$TMPDIR_TEST/data"
export KNOW_CTL_SKIP_LEGACY_CHECK=1

mkdir -p "$CLAUDE_PROJECT_DIR/docs"
mkdir -p "$XDG_CONFIG_HOME/know"
mkdir -p "$XDG_DATA_HOME/know"

# Split fixture by _level; strip _level (v7 schema doesn't have it)
jq -c 'select(._level == "project") | del(._level)' "$FIXTURE" \
    > "$CLAUDE_PROJECT_DIR/docs/triggers.jsonl"
jq -c 'select(._level == "user") | del(._level)' "$FIXTURE" \
    > "$XDG_CONFIG_HOME/know/triggers.jsonl"

# ─── Metric helpers ──────────────────────────────────────────

# expected_ids and actual_ids are newline-separated
# Output: tp fp fn (space-separated)
compute_counts() {
    local expected="$1" actual="$2"
    local tp fp fn exp_sorted act_sorted
    exp_sorted=$(echo "$expected" | grep -v '^$' | sort -u)
    act_sorted=$(echo "$actual" | grep -v '^$' | sort -u)
    tp=$(comm -12 <(echo "$exp_sorted") <(echo "$act_sorted") | grep -cv '^$' || true)
    fp=$(comm -13 <(echo "$exp_sorted") <(echo "$act_sorted") | grep -cv '^$' || true)
    fn=$(comm -23 <(echo "$exp_sorted") <(echo "$act_sorted") | grep -cv '^$' || true)
    # strip any whitespace
    tp=$(echo "$tp" | head -1 | tr -d ' \n')
    fp=$(echo "$fp" | head -1 | tr -d ' \n')
    fn=$(echo "$fn" | head -1 | tr -d ' \n')
    echo "${tp:-0} ${fp:-0} ${fn:-0}"
}

# precision = tp/(tp+fp); recall = tp/(tp+fn); F1 = 2PR/(P+R)
# Special cases:
#   expected=[] AND actual=[] → P=1 R=1 F1=1 (correctly empty)
#   expected=[] AND actual!=[] → P=0 R=1 F1=0 (false positives)
#   expected!=[] AND actual=[] → P=1 R=0 F1=0 (complete miss)
compute_metrics() {
    local tp="$1" fp="$2" fn="$3"
    local p r f1
    local expected_size=$((tp + fn))
    local actual_size=$((tp + fp))
    if [ "$expected_size" -eq 0 ] && [ "$actual_size" -eq 0 ]; then
        p=100; r=100; f1=100
    elif [ "$expected_size" -eq 0 ]; then
        # no expected, some actual → all false positives
        p=0; r=100; f1=0
    elif [ "$actual_size" -eq 0 ]; then
        # no actual, some expected → complete miss
        p=100; r=0; f1=0
    else
        p=$((tp * 100 / actual_size))
        r=$((tp * 100 / expected_size))
        if [ "$p" -eq 0 ] && [ "$r" -eq 0 ]; then
            f1=0
        else
            f1=$((2 * p * r / (p + r)))
        fi
    fi
    echo "$p $r $f1"
}

# ─── Run scenarios ───────────────────────────────────────────

mkdir -p "$RESULTS_DIR"
REPORT_TMP=$(mktemp)

{
    echo "# recall benchmark — $DATE"
    echo ""
    echo "## Setup"
    echo ""
    echo "- fixture: $(jq -c . "$FIXTURE" | wc -l | tr -d ' ') triggers"
    echo "- scenarios: $(jq -c . "$SCENARIOS" | wc -l | tr -d ' ')"
    echo "- isolated env: \`\$CLAUDE_PROJECT_DIR=$TMPDIR_TEST/project\`"
    echo ""
    echo "## Per scenario detail"
    echo ""
    echo "| id | type | scope | expected | actual | tp | fp | fn | P | R | F1 |"
    echo "|----|------|-------|----------|--------|----|----|----|---|---|-----|"
} > "$REPORT_TMP"

# Accumulators per type
declare -A TYPE_TP TYPE_FP TYPE_FN TYPE_COUNT
ALL_TP=0 ALL_FP=0 ALL_FN=0 ALL_COUNT=0

while IFS= read -r scenario; do
    id=$(echo "$scenario" | jq -r '.id')
    type=$(echo "$scenario" | jq -r '.type')
    scope=$(echo "$scenario" | jq -r '.inferred_scope')
    expected=$(echo "$scenario" | jq -r '.expected_recalls[]' 2>/dev/null || true)

    # BLACK BOX: only call know-ctl query. Do NOT inline query logic.
    actual=$(bash "$KNOW_CTL" query "$scope" 2>/dev/null | jq -r '._id' 2>/dev/null | grep -v '^null$' || true)

    read -r tp fp fn <<< "$(compute_counts "$expected" "$actual")"
    read -r p r f1 <<< "$(compute_metrics "$tp" "$fp" "$fn")"

    expected_compact=$(echo "$expected" | tr '\n' ',' | sed 's/,$//; s/^$/—/')
    actual_compact=$(echo "$actual"     | tr '\n' ',' | sed 's/,$//; s/^$/—/')

    printf "| %s | %s | %s | %s | %s | %d | %d | %d | %d%% | %d%% | %d |\n" \
        "$id" "$type" "$scope" "$expected_compact" "$actual_compact" "$tp" "$fp" "$fn" "$p" "$r" "$f1" \
        >> "$REPORT_TMP"

    # accumulate per-type
    TYPE_TP[$type]=$(( ${TYPE_TP[$type]:-0} + tp ))
    TYPE_FP[$type]=$(( ${TYPE_FP[$type]:-0} + fp ))
    TYPE_FN[$type]=$(( ${TYPE_FN[$type]:-0} + fn ))
    TYPE_COUNT[$type]=$(( ${TYPE_COUNT[$type]:-0} + 1 ))

    ALL_TP=$((ALL_TP + tp))
    ALL_FP=$((ALL_FP + fp))
    ALL_FN=$((ALL_FN + fn))
    ALL_COUNT=$((ALL_COUNT + 1))
done < "$SCENARIOS"

# ─── Aggregate ───────────────────────────────────────────────

{
    echo ""
    echo "## By type"
    echo ""
    echo "| type | n | tp | fp | fn | P | R | F1 |"
    echo "|------|---|----|----|----|---|---|-----|"

    for type in exact prefix confuse cross-level empty; do
        n=${TYPE_COUNT[$type]:-0}
        [ "$n" -eq 0 ] && continue
        tp=${TYPE_TP[$type]:-0}
        fp=${TYPE_FP[$type]:-0}
        fn=${TYPE_FN[$type]:-0}
        read -r p r f1 <<< "$(compute_metrics "$tp" "$fp" "$fn")"
        printf "| %s | %d | %d | %d | %d | %d%% | %d%% | %d |\n" "$type" "$n" "$tp" "$fp" "$fn" "$p" "$r" "$f1"
    done

    echo ""
    echo "## Overall"
    echo ""
    read -r p r f1 <<< "$(compute_metrics "$ALL_TP" "$ALL_FP" "$ALL_FN")"
    echo "- **scenarios**: $ALL_COUNT"
    echo "- **tp**: $ALL_TP, **fp**: $ALL_FP, **fn**: $ALL_FN"
    echo "- **Precision**: $p%"
    echo "- **Recall**: $r%"
    echo "- **F1**: $f1"
    echo ""
    echo "## Methodology"
    echo ""
    echo "- **Black-box**: this runner only calls \`know-ctl query\` via CLI. It does NOT re-implement or inspect the query/ranking logic."
    echo "- **Expected annotations** in scenarios.jsonl are based on user-value reasoning (\"what should AI see when editing this file\"), not on current algorithm behavior."
    echo "- **Special metric cases**:"
    echo "  - empty expected + empty actual → P=100% R=100% F1=100 (correctly empty)"
    echo "  - empty expected + non-empty actual → P=0% R=100% F1=0 (false positives)"
    echo "  - non-empty expected + empty actual → P=100% R=0% F1=0 (complete miss)"
} >> "$REPORT_TMP"

mv "$REPORT_TMP" "$REPORT"

echo ""
echo "Report written: $REPORT"
echo ""
cat "$REPORT"
