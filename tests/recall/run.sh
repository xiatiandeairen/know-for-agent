#!/bin/bash
# run.sh — run recall scenarios, output M1 (self-check rate) + M2 (contamination rate)
#
# Reads tests/recall/scenarios.jsonl (real triggers are read live from
# docs/triggers.jsonl + $XDG_CONFIG_HOME/know/triggers.jsonl via know-ctl).
# No synthetic fixture. Events go to isolated tmp to avoid polluting real.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KNOW_CTL="$PROJECT_ROOT/scripts/know-ctl.sh"
SCENARIOS="$PROJECT_ROOT/tests/recall/scenarios.jsonl"
RESULTS_DIR="$PROJECT_ROOT/tests/recall/results"

DATE=$(date +%Y-%m-%dT%H%M%S)
REPORT="$RESULTS_DIR/$DATE.md"
mkdir -p "$RESULTS_DIR"

# Preserve real XDG_DATA_HOME for post-run metrics; isolate scenario queries to tmp
REAL_XDG_DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
TMP_DATA=$(mktemp -d)
trap 'rm -rf "$TMP_DATA"' EXIT
export XDG_DATA_HOME="$TMP_DATA"
mkdir -p "$XDG_DATA_HOME/know"

[ -f "$SCENARIOS" ] || { echo "[recall] No scenarios file. Run generate-scenarios.sh first." >&2; exit 1; }

n_self_total=0; n_self_pass=0
n_cont_total=0; n_cont_fail=0
declare -a failures=()

{
    echo "# recall test scenarios — $DATE"
    echo ""
    echo "## Setup"
    echo "- scenarios: $(wc -l < "$SCENARIOS" | tr -d ' ')"
    echo "- triggers source: docs/triggers.jsonl (project) + \$XDG_CONFIG_HOME/know/triggers.jsonl (user) — live read"
    echo ""
    echo "## Per scenario"
    echo ""
    echo "| # | test | file | scope queried | returned | verdict |"
    echo "|---|------|------|---------------|----------|---------|"
} > "$REPORT"

idx=0
while IFS= read -r line; do
    [ -z "$line" ] && continue
    idx=$((idx + 1))
    id=$(echo "$line" | jq -r .id)
    title=$(echo "$line" | jq -r '.title // .id')
    kind=$(echo "$line" | jq -r .kind)
    origin=$(echo "$line" | jq -r .origin)
    file=$(echo "$line" | jq -r '.file_path // "null"')
    level=$(echo "$line" | jq -r '.level // ""')
    include=$(echo "$line" | jq -r '.expected.include | join(",")')
    exclude=$(echo "$line" | jq -r '.expected.exclude | if type=="string" then . else join(",") end')

    # scope to query: if file_path is real, derive like runner would (simple first-segment); else use include[0]
    if [ "$file" != "null" ] && [ -n "$file" ]; then
        scope_q=$(echo "$file" | sed -E 's#\.[^./]+$##' | tr '/' '.' | sed -E 's#^(src|lib|app|tests|scripts|skills|docs|workflows)\.##')
    else
        scope_q=$(echo "$line" | jq -r '.expected.include[0] // "project"')
    fi

    returned=$(bash "$KNOW_CTL" query "$scope_q" 2>/dev/null | jq -r '.scope // empty' | grep -v '^$' || true)
    returned_csv=$(echo "$returned" | tr '\n' ',' | sed 's/,$//; s/^$/—/')

    verdict="✓"
    if [ "$kind" = "self-check" ]; then
        n_self_total=$((n_self_total + 1))
        # All include scopes must be present
        all_present=1
        if [ -n "$include" ]; then
            IFS=',' read -ra req <<< "$include"
            for s in "${req[@]}"; do
                echo "$returned" | grep -qxF "$s" || { all_present=0; break; }
            done
        fi
        if [ "$all_present" -eq 1 ]; then
            n_self_pass=$((n_self_pass + 1))
        else
            verdict="✗ miss"
            failures+=("$title — expected [$include] got [$returned_csv]")
        fi
    elif [ "$kind" = "contamination" ]; then
        n_cont_total=$((n_cont_total + 1))
        polluted=0
        if [ "$exclude" = "*" ]; then
            [ -n "$returned" ] && polluted=1
        elif [ -n "$exclude" ]; then
            IFS=',' read -ra ex <<< "$exclude"
            for s in "${ex[@]}"; do
                echo "$returned" | grep -qxF "$s" && { polluted=1; break; }
            done
        fi
        if [ "$polluted" -eq 1 ]; then
            n_cont_fail=$((n_cont_fail + 1))
            verdict="✗ polluted"
            failures+=("$title — got unexpected [$returned_csv]")
        fi
    fi

    printf "| %d | %s | %s | %s | %s | %s |\n" \
        "$idx" "$title" "$(basename "$file" 2>/dev/null || echo —)" "$scope_q" "$returned_csv" "$verdict" \
        >> "$REPORT"
done < "$SCENARIOS"

m1=0
[ "$n_self_total" -gt 0 ] && m1=$((n_self_pass * 100 / n_self_total))
m2=0
[ "$n_cont_total" -gt 0 ] && m2=$((n_cont_fail * 100 / n_cont_total))

{
    echo ""
    echo "## Metrics"
    echo ""
    echo "| # | metric | value | meaning |"
    echo "|---|--------|-------|---------|"
    echo "| M1 | self-retrievability rate | ${m1}% ($n_self_pass/$n_self_total) | 每条 trigger 能否被自生成 scenario 召回自己 |"
    echo "| M2 | contamination rate | ${m2}% ($n_cont_fail/$n_cont_total) | 干扰场景是否误召 |"
    echo ""
    if [ ${#failures[@]} -gt 0 ]; then
        echo "## Failures"
        echo ""
        for f in "${failures[@]}"; do echo "- $f"; done
        echo ""
    fi
    echo "## Action thresholds"
    echo ""
    echo "- M1 < 75% → trigger 的 scope/keywords 标注差，review triggers.jsonl"
    echo "- M2 > 0%  → 某 trigger 写太泛，scope 或 keywords 需收窄"
    echo ""
    echo "## 生产指标（近 30 天，从真实 events.jsonl 派生）"
    echo ""
    echo "### project level"
    echo ""
    echo '```'
    XDG_DATA_HOME="$REAL_XDG_DATA" bash "$KNOW_CTL" metrics --level project 2>&1 | sed -n '/真指标/,/---/p' | grep -v '^---' || echo "(无数据)"
    echo '```'
    echo ""
    echo "### user level"
    echo ""
    echo '```'
    XDG_DATA_HOME="$REAL_XDG_DATA" bash "$KNOW_CTL" metrics --level user 2>&1 | sed -n '/真指标/,/---/p' | grep -v '^---' || echo "(无数据)"
    echo '```'
    echo ""
    echo "## Follow-up"
    echo ""
    echo "- **M3 采纳率**：需加 \`recall_query.returned_scopes[]\` + \`hit.scope\` 事件字段，计算 \`hits / recall_query with matched>0\`"
} >> "$REPORT"

# Final summary print
metrics_p=$(XDG_DATA_HOME="$REAL_XDG_DATA" bash "$KNOW_CTL" metrics --level project 2>&1)
metrics_u=$(XDG_DATA_HOME="$REAL_XDG_DATA" bash "$KNOW_CTL" metrics --level user 2>&1)
m3_project=$(echo "$metrics_p" | grep 'M3 采纳率' | awk -F'[()]' '{print $2}' || echo "—")
m3_user=$(echo "$metrics_u" | grep 'M3 采纳率' | awk -F'[()]' '{print $2}' || echo "—")
m4_project=$(echo "$metrics_p" | grep 'M4 利用率' | awk -F'[()]' '{print $2}' || echo "—")
m4_user=$(echo "$metrics_u" | grep 'M4 利用率' | awk -F'[()]' '{print $2}' || echo "—")
echo ""
echo "--- all metrics summary ---"
printf "  M1 自查率:   %s%% (%s/%s)\n" "$m1" "$n_self_pass" "$n_self_total"
printf "  M2 污染率:   %s%% (%s/%s)\n" "$m2" "$n_cont_fail" "$n_cont_total"
printf "  M3 采纳率:   project=%s  user=%s\n" "${m3_project:-—}" "${m3_user:-—}"
printf "  M4 利用率:   project=%s  user=%s  (estimated)\n" "${m4_project:-—}" "${m4_user:-—}"
printf "  M5 深度分布: 见 report\n"

echo "Report: $REPORT"
echo "M1=${m1}% M2=${m2}%"
[ ${#failures[@]} -eq 0 ] || echo "Failures: ${#failures[@]}"
