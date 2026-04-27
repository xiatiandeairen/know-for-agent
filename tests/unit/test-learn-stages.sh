#!/usr/bin/env bash
# tests/unit/test-learn-stages.sh — workflows/learn.md 结构单元测试
#
# 用法：
#   bash tests/unit/test-learn-stages.sh            # 跑全部 case
#   bash tests/unit/test-learn-stages.sh test_gate_names  # 跑指定 case
#
# 退出码：0=全 pass / 1=有 fail

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
TARGET="$REPO_ROOT/workflows/learn.md"

# ────────────────────────── helpers ──────────────────────────

assert_contains() {
  local label="$1" needle="$2"
  if grep -qF "$needle" "$TARGET"; then
    return 0
  fi
  echo "  missing: '$needle'"
  return 1
}

assert_count() {
  local label="$1" pattern="$2" expected="$3"
  local actual
  actual=$(grep -cE "$pattern" "$TARGET" 2>/dev/null || true)
  if [ "$actual" -eq "$expected" ]; then
    return 0
  fi
  echo "  pattern: '$pattern'"
  echo "  expected count: $expected  actual: $actual"
  return 1
}

# ────────────────────────── cases ──────────────────────────

test_file_exists() {
  if [ -f "$TARGET" ]; then return 0; fi
  echo "  file not found: $TARGET"
  return 1
}

test_stage_count() {
  assert_count "5 stages" "^## Stage [1-5]:" 5
}

test_stage_names() {
  assert_contains "stage detect"  "## Stage 1: detect"  || return 1
  assert_contains "stage gate"    "## Stage 2: gate"    || return 1
  assert_contains "stage refine"  "## Stage 3: refine"  || return 1
  assert_contains "stage locate"  "## Stage 4: locate"  || return 1
  assert_contains "stage write"   "## Stage 5: write"   || return 1
}

test_stage_intro_format() {
  assert_contains "stage 1/5 intro" "[learn] stage 1/5 — detect" || return 1
  assert_contains "stage 2/5 intro" "[learn] stage 2/5 — gate"   || return 1
  assert_contains "stage 3/5 intro" "[learn] stage 3/5 — refine" || return 1
  assert_contains "stage 4/5 intro" "[learn] stage 4/5 — locate" || return 1
  assert_contains "stage 5/5 intro" "[learn] stage 5/5 — write"  || return 1
}

test_claim_classification() {
  assert_contains "[纠正] label" "[纠正]" || return 1
  assert_contains "[捕捉] label" "[捕捉]" || return 1
}

test_gate_names() {
  assert_contains "信息熵 gate" "信息熵" || return 1
  assert_contains "复用 gate"   "复用"   || return 1
  assert_contains "可触发 gate" "可触发" || return 1
  assert_contains "可执行 gate" "可执行" || return 1
}

test_gate_adjust_before_reject() {
  # 每道 gate 应有"调整方向"逻辑，而非直接 reject
  assert_contains "adjust direction" "调整" || return 1
}

test_refine_steps() {
  assert_contains "场景泛化" "场景泛化" || return 1
  assert_contains "知识深化" "知识深化" || return 1
  assert_contains "颗粒度校准" "颗粒度校准" || return 1
}

test_locate_levels() {
  assert_contains "project level" "project" || return 1
  assert_contains "module level"  "module"  || return 1
  assert_contains "user level"    "user"    || return 1
}

test_locate_user_path() {
  assert_contains "user level path" "~/.claude/rules/know.md" || return 1
}

test_locate_project_path() {
  assert_contains "project level path" "{git root}/.claude/rules/know.md" || return 1
}

test_locate_module_path() {
  assert_contains "module level path" "/CLAUDE.md" || return 1
}

test_yaml_entry_fields() {
  assert_contains "when field"   "when:"    || return 1
  assert_contains "field placeholder" "{field}:" || return 1
  assert_contains "how field"    "how:"     || return 1
  assert_contains "until field"  "until:"   || return 1
}

test_entry_content_field_names() {
  # 至少有两种强度字段（以 backtick 或字段名出现均可）
  assert_contains "should field" "should" || return 1
  assert_contains "avoid field"  "avoid"  || return 1
}

test_know_section_target() {
  assert_contains "## know block" "## know" || return 1
}

test_output_markers() {
  assert_contains "[learn] entry candidate" "[learn] entry candidate:" || return 1
  assert_contains "[learn] reject"          "[learn] reject:"          || return 1
}

test_conflict_check() {
  assert_contains "conflict step" "conflict" || return 1
}

test_commit_suggestion() {
  assert_contains "commit suggestion" "suggest-commit" || return 1
}

# ────────────────────────── runner ──────────────────────────

main() {
  local cases=()
  if [ $# -ge 1 ]; then
    if declare -F "$1" >/dev/null; then
      cases=("$1")
    else
      echo "Error: no such case '$1'" >&2
      declare -F | awk '$3 ~ /^test_/ {print "  "$3}' >&2
      exit 1
    fi
  else
    while IFS= read -r line; do cases+=("$line"); done \
      < <(declare -F | awk '$3 ~ /^test_/ {print $3}')
  fi

  local pass=0 fail=0
  for c in "${cases[@]}"; do
    if ( "$c" ); then
      echo "[pass] $c"
      pass=$((pass + 1))
    else
      echo "[fail] $c"
      fail=$((fail + 1))
    fi
  done

  echo "──"
  echo "$pass pass / $fail fail (of $((pass + fail)))"
  [ "$fail" -eq 0 ]
}

main "$@"
