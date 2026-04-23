#!/bin/bash
# recall semantic benchmark runner — dual strategy evaluation
#
# Strategy A: current string-match (know-ctl query on extracted scope)
# Strategy B: ideal concept-match (upper bound, simulated via _concepts overlap)
#
# Computes graded metrics per scenario and aggregated per type:
#   recall@must        : must_recall trigger IDs captured by strategy
#   recall@should      : should_recall IDs captured
#   precision_penalty  : must_not_recall IDs that appeared in actual (lower better)
#
# Black-box for Strategy A: runner calls know-ctl query CLI; does not
# inline scope-matching logic. Strategy B simulates an upper-bound
# algorithm using fixture's _concepts metadata.

set -euo pipefail

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$BENCH_DIR/../../.." && pwd)"
KNOW_CTL="$PROJECT_ROOT/scripts/know-ctl.sh"
FIXTURE="$BENCH_DIR/fixture-triggers.jsonl"
SCENARIOS="$BENCH_DIR/scenarios.jsonl"
RESULTS_DIR="$BENCH_DIR/results"

DATE=$(date +%Y-%m-%dT%H%M%S)
REPORT="$RESULTS_DIR/$DATE.md"

# ─── isolated env for Strategy A ─────────────────────────────
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

export CLAUDE_PROJECT_DIR="$TMPDIR_TEST/project"
export XDG_CONFIG_HOME="$TMPDIR_TEST/config"
export XDG_DATA_HOME="$TMPDIR_TEST/data"
export KNOW_CTL_SKIP_LEGACY_CHECK=1

mkdir -p "$CLAUDE_PROJECT_DIR/docs"
mkdir -p "$XDG_CONFIG_HOME/know"
mkdir -p "$XDG_DATA_HOME/know"

# split fixture by _level into triggers files (keep _id/_concepts; know-ctl
# passes through extra fields on read — only validate_entry enforces on append)
jq -c 'select(._level == "project")' "$FIXTURE" \
    > "$CLAUDE_PROJECT_DIR/docs/triggers.jsonl"
jq -c 'select(._level == "user")' "$FIXTURE" \
    > "$XDG_CONFIG_HOME/know/triggers.jsonl"

# ─── Strategy A scope extraction (simulates P1 path→module) ─
extract_scope() {
    local path="${1:-}"
    if [ -z "$path" ]; then
        echo "project"
        return
    fi
    # strip leading conventional dirs, strip extension, / → .
    echo "$path" \
        | sed -E 's#^(src|lib|app|tests|scripts|migrations)/##' \
        | sed -E 's#\.[^./]+$##' \
        | tr '/' '.'
}

# ─── metric helpers ───────────────────────────────────────────
count_items() {
    if [ -z "$1" ]; then echo 0; return; fi
    # awk never exits non-zero on empty input (avoids set -e + pipefail tripping)
    printf '%s\n' "$1" | awk 'BEGIN{n=0} NF>0{n++} END{print n+0}'
}

count_intersection() {
    local a="$1" b="$2"
    if [ -z "$a" ] || [ -z "$b" ]; then
        echo 0; return
    fi
    # wrap in subshell disabling pipefail to tolerate empty-intersection edge
    ( set +o pipefail
      comm -12 <(printf '%s\n' "$a" | awk 'NF>0' | sort -u) \
               <(printf '%s\n' "$b" | awk 'NF>0' | sort -u) \
          | awk 'BEGIN{n=0} NF>0{n++} END{print n+0}'
    )
}

# ─── run ──────────────────────────────────────────────────────
mkdir -p "$RESULTS_DIR"
REPORT_TMP=$(mktemp)

{
    echo "# recall semantic benchmark — $DATE"
    echo ""
    echo "## Setup"
    echo "- fixture: $(jq -c . "$FIXTURE" | wc -l | tr -d ' ') triggers with _concepts"
    echo "- scenarios: $(jq -c . "$SCENARIOS" | wc -l | tr -d ' ')"
    echo "- Strategy A: current string-match via \`know-ctl query\`"
    echo "- Strategy B: ideal concept-match (upper bound simulated via _concepts overlap with required_concepts)"
    echo ""
    echo "## Per scenario detail"
    echo ""
    echo "| id | type | task (trimmed) | A scope | A actual | B actual | A R@must | B R@must | A R@should | B R@should | A P@3 | B P@3 | A pen | B pen |"
    echo "|----|------|-----|---------|----------|----------|----------|----------|-----------|-----------|-------|-------|-------|-------|"
} > "$REPORT_TMP"

# per-type accumulators — use plain vars with type in name since macOS bash 3.2 lacks assoc arrays
for type in concept-match cross-cutting analogy risk-domain intent-gap; do
    eval "TYPE_${type//-/_}_N_MUST=0"
    eval "TYPE_${type//-/_}_N_SHOULD=0"
    eval "TYPE_${type//-/_}_TP_MUST_A=0"
    eval "TYPE_${type//-/_}_TP_MUST_B=0"
    eval "TYPE_${type//-/_}_TP_SHOULD_A=0"
    eval "TYPE_${type//-/_}_TP_SHOULD_B=0"
    eval "TYPE_${type//-/_}_N_ACTUAL_A=0"
    eval "TYPE_${type//-/_}_N_ACTUAL_B=0"
    eval "TYPE_${type//-/_}_MUSTNOT_A=0"
    eval "TYPE_${type//-/_}_MUSTNOT_B=0"
    eval "TYPE_${type//-/_}_COUNT=0"
done

while IFS= read -r scenario; do
    id=$(echo "$scenario" | jq -r '.id')
    type=$(echo "$scenario" | jq -r '.type')
    type_var="${type//-/_}"
    task=$(echo "$scenario" | jq -r '.task' | cut -c1-40)
    file_hint=$(echo "$scenario" | jq -r '.file_hints[0] // ""')

    must=$(echo "$scenario" | jq -r '.must_recall[]? // empty')
    should=$(echo "$scenario" | jq -r '.should_recall[]? // empty')
    must_not=$(echo "$scenario" | jq -r '.must_not_recall[]? // empty')
    required_concepts=$(echo "$scenario" | jq -c '.required_concepts')

    # Strategy A: extract scope + keywords, query know-ctl
    scope_A=$(extract_scope "$file_hint")
    kw_csv=$(echo "$required_concepts" | jq -r '. | join(",")')
    if [ -n "$kw_csv" ]; then
        actual_A=$(bash "$KNOW_CTL" query "$scope_A" --keywords "$kw_csv" 2>/dev/null | jq -r '._id // empty' | grep -v '^$' || true)
    else
        actual_A=$(bash "$KNOW_CTL" query "$scope_A" 2>/dev/null | jq -r '._id // empty' | grep -v '^$' || true)
    fi

    # Strategy B: (concepts ∪ synonyms) overlap with required (≥1 match)
    actual_B=$(jq -r --argjson req "$required_concepts" \
        'select(((._concepts // []) + (._synonyms // [])) as $c | any($c[]; . as $x | $req | index($x))) | ._id' \
        "$FIXTURE" | grep -v '^$' || true)

    n_must=$(count_items "$must")
    n_should=$(count_items "$should")
    n_actual_A=$(count_items "$actual_A")
    n_actual_B=$(count_items "$actual_B")

    tp_must_A=$(count_intersection "$actual_A" "$must")
    tp_must_B=$(count_intersection "$actual_B" "$must")
    tp_should_A=$(count_intersection "$actual_A" "$should")
    tp_should_B=$(count_intersection "$actual_B" "$should")
    mustnot_A=$(count_intersection "$actual_A" "$must_not")
    mustnot_B=$(count_intersection "$actual_B" "$must_not")

    # top3 precision — know-ctl query already sorts by _kw_hits desc
    top3_A=$(echo "$actual_A" | awk 'NF>0' | head -3)
    top3_B=$(echo "$actual_B" | awk 'NF>0' | head -3)
    tp3_A=$(count_intersection "$top3_A" "$must")
    tp3_B=$(count_intersection "$top3_B" "$must")
    if [ "$n_must" -eq 0 ]; then p3_A=100; p3_B=100; else p3_A=$((tp3_A * 100 / 3)); p3_B=$((tp3_B * 100 / 3)); fi

    if [ "$n_must" -eq 0 ]; then rmust_A=100; rmust_B=100; else rmust_A=$((tp_must_A * 100 / n_must)); rmust_B=$((tp_must_B * 100 / n_must)); fi
    if [ "$n_should" -eq 0 ]; then rshould_A=100; rshould_B=100; else rshould_A=$((tp_should_A * 100 / n_should)); rshould_B=$((tp_should_B * 100 / n_should)); fi
    if [ "$n_actual_A" -eq 0 ]; then pen_A=0; else pen_A=$((mustnot_A * 100 / n_actual_A)); fi
    if [ "$n_actual_B" -eq 0 ]; then pen_B=0; else pen_B=$((mustnot_B * 100 / n_actual_B)); fi

    actual_A_compact=$(echo "$actual_A" | tr '\n' ',' | sed 's/,$//; s/^$/—/')
    actual_B_compact=$(echo "$actual_B" | tr '\n' ',' | sed 's/,$//; s/^$/—/')

    printf "| %s | %s | %s | %s | %s | %s | %d%% | %d%% | %d%% | %d%% | %d%% | %d%% | %d%% | %d%% |\n" \
        "$id" "$type" "$task" "$scope_A" "$actual_A_compact" "$actual_B_compact" \
        "$rmust_A" "$rmust_B" "$rshould_A" "$rshould_B" "$p3_A" "$p3_B" "$pen_A" "$pen_B" \
        >> "$REPORT_TMP"

    # init accumulator lazily if unseen
    eval ": \${TYPE_${type_var}_COUNT:=0}"
    eval ": \${TYPE_${type_var}_N_MUST:=0}"
    eval ": \${TYPE_${type_var}_N_SHOULD:=0}"
    eval ": \${TYPE_${type_var}_TP_MUST_A:=0}"
    eval ": \${TYPE_${type_var}_TP_MUST_B:=0}"
    eval ": \${TYPE_${type_var}_TP_SHOULD_A:=0}"
    eval ": \${TYPE_${type_var}_TP_SHOULD_B:=0}"
    eval ": \${TYPE_${type_var}_N_ACTUAL_A:=0}"
    eval ": \${TYPE_${type_var}_N_ACTUAL_B:=0}"
    eval ": \${TYPE_${type_var}_MUSTNOT_A:=0}"
    eval ": \${TYPE_${type_var}_MUSTNOT_B:=0}"
    eval ": \${TYPE_${type_var}_TP3_A:=0}"
    eval ": \${TYPE_${type_var}_TP3_B:=0}"

    eval "TYPE_${type_var}_N_MUST=\$((TYPE_${type_var}_N_MUST + n_must))"
    eval "TYPE_${type_var}_N_SHOULD=\$((TYPE_${type_var}_N_SHOULD + n_should))"
    eval "TYPE_${type_var}_TP_MUST_A=\$((TYPE_${type_var}_TP_MUST_A + tp_must_A))"
    eval "TYPE_${type_var}_TP_MUST_B=\$((TYPE_${type_var}_TP_MUST_B + tp_must_B))"
    eval "TYPE_${type_var}_TP_SHOULD_A=\$((TYPE_${type_var}_TP_SHOULD_A + tp_should_A))"
    eval "TYPE_${type_var}_TP_SHOULD_B=\$((TYPE_${type_var}_TP_SHOULD_B + tp_should_B))"
    eval "TYPE_${type_var}_N_ACTUAL_A=\$((TYPE_${type_var}_N_ACTUAL_A + n_actual_A))"
    eval "TYPE_${type_var}_N_ACTUAL_B=\$((TYPE_${type_var}_N_ACTUAL_B + n_actual_B))"
    eval "TYPE_${type_var}_MUSTNOT_A=\$((TYPE_${type_var}_MUSTNOT_A + mustnot_A))"
    eval "TYPE_${type_var}_MUSTNOT_B=\$((TYPE_${type_var}_MUSTNOT_B + mustnot_B))"
    eval "TYPE_${type_var}_TP3_A=\$((TYPE_${type_var}_TP3_A + tp3_A))"
    eval "TYPE_${type_var}_TP3_B=\$((TYPE_${type_var}_TP3_B + tp3_B))"
    eval "TYPE_${type_var}_COUNT=\$((TYPE_${type_var}_COUNT + 1))"
done < "$SCENARIOS"

# ─── aggregate ────────────────────────────────────────────────

{
    echo ""
    echo "## By type — Strategy A (current string-match)"
    echo ""
    echo "| type | n | recall@must | recall@should | precision@3 | precision_penalty |"
    echo "|------|---|-------------|---------------|-------------|-------------------|"

    for type in concept-match cross-cutting analogy risk-domain intent-gap synonym-gap ranking pure-noise; do
        tv="${type//-/_}"
        eval "c=\$TYPE_${tv}_COUNT"
        [ "$c" -eq 0 ] && continue
        eval "nm=\$TYPE_${tv}_N_MUST; ns=\$TYPE_${tv}_N_SHOULD"
        eval "tpm=\$TYPE_${tv}_TP_MUST_A; tps=\$TYPE_${tv}_TP_SHOULD_A"
        eval "na=\$TYPE_${tv}_N_ACTUAL_A; mn=\$TYPE_${tv}_MUSTNOT_A; tp3=\$TYPE_${tv}_TP3_A"
        if [ "$nm" -eq 0 ]; then rm=100; p3=100; else rm=$((tpm * 100 / nm)); p3=$((tp3 * 100 / (c * 3) )); fi
        if [ "$ns" -eq 0 ]; then rs=100; else rs=$((tps * 100 / ns)); fi
        if [ "$na" -eq 0 ]; then pp=0; else pp=$((mn * 100 / na)); fi
        printf "| %s | %d | %d%% | %d%% | %d%% | %d%% |\n" "$type" "$c" "$rm" "$rs" "$p3" "$pp"
    done

    echo ""
    echo "## By type — Strategy B (concept ∪ synonyms upper bound)"
    echo ""
    echo "| type | n | recall@must | recall@should | precision@3 | precision_penalty |"
    echo "|------|---|-------------|---------------|-------------|-------------------|"

    for type in concept-match cross-cutting analogy risk-domain intent-gap synonym-gap ranking pure-noise; do
        tv="${type//-/_}"
        eval "c=\$TYPE_${tv}_COUNT"
        [ "$c" -eq 0 ] && continue
        eval "nm=\$TYPE_${tv}_N_MUST; ns=\$TYPE_${tv}_N_SHOULD"
        eval "tpm=\$TYPE_${tv}_TP_MUST_B; tps=\$TYPE_${tv}_TP_SHOULD_B"
        eval "na=\$TYPE_${tv}_N_ACTUAL_B; mn=\$TYPE_${tv}_MUSTNOT_B; tp3=\$TYPE_${tv}_TP3_B"
        if [ "$nm" -eq 0 ]; then rm=100; p3=100; else rm=$((tpm * 100 / nm)); p3=$((tp3 * 100 / (c * 3) )); fi
        if [ "$ns" -eq 0 ]; then rs=100; else rs=$((tps * 100 / ns)); fi
        if [ "$na" -eq 0 ]; then pp=0; else pp=$((mn * 100 / na)); fi
        printf "| %s | %d | %d%% | %d%% | %d%% | %d%% |\n" "$type" "$c" "$rm" "$rs" "$p3" "$pp"
    done

    echo ""
    echo "## Gap analysis — Strategy B − Strategy A (recall@must)"
    echo ""
    echo "A−B 差越大说明当前字符串算法在该场景越盲；负值表示 A 幸运命中但 B 未覆盖（罕见）。"
    echo ""
    echo "| type | A recall@must | B recall@must | gap (B−A) | interpretation |"
    echo "|------|---------------|---------------|-----------|----------------|"

    for type in concept-match cross-cutting analogy risk-domain intent-gap synonym-gap ranking pure-noise; do
        tv="${type//-/_}"
        eval "c=\$TYPE_${tv}_COUNT"
        [ "$c" -eq 0 ] && continue
        eval "nm=\$TYPE_${tv}_N_MUST"
        eval "tpma=\$TYPE_${tv}_TP_MUST_A; tpmb=\$TYPE_${tv}_TP_MUST_B"
        if [ "$nm" -eq 0 ]; then rma=100; rmb=100; else rma=$((tpma * 100 / nm)); rmb=$((tpmb * 100 / nm)); fi
        gap=$((rmb - rma))
        if [ "$gap" -ge 40 ]; then interp="字符串算法严重盲——语义升级回报大"
        elif [ "$gap" -ge 15 ]; then interp="明显 gap——语义升级有价值"
        elif [ "$gap" -ge 0 ]; then interp="接近上界——该类 scope 机制够用"
        else interp="A>B 异常——检查 concepts 标注完整性"
        fi
        printf "| %s | %d%% | %d%% | %+d%% | %s |\n" "$type" "$rma" "$rmb" "$gap" "$interp"
    done

    echo ""
    echo "## Methodology"
    echo ""
    echo "- 语义 benchmark v2：测概念/模式/横切/风险/意图 5 类召回能力，非字符串匹配"
    echo "- **Strategy A**：runner 从 file_hints[0] 抽 scope（strip src|lib|app|tests|scripts|migrations 前缀 + strip 扩展名 + / → .），调 \`know-ctl query\` 获取当前算法行为"
    echo "- **Strategy B**：(\`_concepts ∪ _synonyms\`) ∩ required_concepts ≠ ∅ → 召回。模拟理想上界（含同义词层）"
    echo "- recall@must 为核心；precision@3 反映排序（know recall 只展示 max 3）；precision_penalty 越低越好"
    echo "- 空集处理：n_must=0 时 recall@must=100（"无需召回也是召回完成"）"
} >> "$REPORT_TMP"

mv "$REPORT_TMP" "$REPORT"
echo ""
echo "Report written: $REPORT"
echo ""
cat "$REPORT"
