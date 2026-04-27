#!/usr/bin/env bash
# tests/unit/test-write-stages.sh — workflows/write.md 结构单元测试
#
# 用法：
#   bash tests/unit/test-write-stages.sh             # 跑全部 case
#   bash tests/unit/test-write-stages.sh test_paths  # 跑指定 case
#
# 退出码：0=全 pass / 1=有 fail

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
TARGET="$REPO_ROOT/workflows/write.md"

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

assert_not_contains() {
  local label="$1" needle="$2"
  if ! grep -qF "$needle" "$TARGET"; then
    return 0
  fi
  echo "  should not contain: '$needle'"
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
  assert_contains "stage infer"   "## Stage 1: infer"   || return 1
  assert_contains "stage gate"    "## Stage 2: gate"    || return 1
  assert_contains "stage confirm" "## Stage 3: confirm" || return 1
  assert_contains "stage draft"   "## Stage 4: draft"   || return 1
  assert_contains "stage write"   "## Stage 5: write"   || return 1
}

test_stage_intro_format() {
  assert_contains "stage 1/5 intro" "[write] stage 1/5 — infer"   || return 1
  assert_contains "stage 2/5 intro" "[write] stage 2/5 — gate"    || return 1
  assert_contains "stage 3/5 intro" "[write] stage 3/5 — confirm" || return 1
  assert_contains "stage 4/5 intro" "[write] stage 4/5 — draft"   || return 1
  assert_contains "stage 5/5 intro" "[write] stage 5/5 — write"   || return 1
}

test_type_count() {
  # 10 种 type 在同一行列出
  assert_contains "10 types header" "10 种" || return 1
}

test_type_names() {
  local types="roadmap prd tech arch decision schema ui capabilities ops marketing"
  for t in $types; do
    assert_contains "type $t" "$t" || return 1
  done
}

test_paths_no_standalone_section() {
  # 路径章节已内嵌，不应有独立的 ## 路径 顶级 section
  assert_not_contains "no standalone paths section" "## 路径" || return 1
}

test_doc_paths_inlined() {
  # Stage 1 内联文档路径表
  assert_contains "roadmap path"      "docs/roadmap.md"      || return 1
  assert_contains "prd path"          "docs/requirements/{name}/prd.md" || return 1
  assert_contains "tech path"         "docs/requirements/{name}/tech.md" || return 1
  assert_contains "arch path"         "docs/arch/{name}.md"  || return 1
}

test_templates_path_inlined() {
  # 模板基目录在 Stage 2 / Step 4 / Step 7 内联引用
  assert_contains "templates dir" "workflows/templates/" || return 1
}

test_no_script_dependency() {
  # 不应再引用已删除的 know-paths.sh
  assert_not_contains "no KNOW_PATHS"  "KNOW_PATHS"   || return 1
  assert_not_contains "no know-paths"  "know-paths.sh" || return 1
}

test_gate_high_risk_only() {
  # Stage 2 gate 仅对高风险 type 运行
  assert_contains "high risk types" "prd / tech / arch / schema / decision / ui" || return 1
}

test_create_update_modes() {
  assert_contains "create mode" "create 模式" || return 1
  assert_contains "update mode" "update 模式" || return 1
}

test_tbd_rule() {
  assert_contains "TBD marker" "TBD" || return 1
}

test_validate_checklist() {
  assert_contains "checklist file" "checklist.md" || return 1
}

test_validate_loop_cap() {
  # 校验最多 3 轮
  assert_contains "max 3 rounds" "3 轮" || return 1
}

test_output_markers() {
  assert_contains "[write] preview"  "[write] Preview:"  || return 1
  assert_contains "[written] path"   "[written]"         || return 1
  assert_contains "[progress] update" "[progress]"       || return 1
}

test_parent_sync() {
  # tech → prd，prd → roadmap 回写
  assert_contains "tech backwrite" "tech 写完" || return 1
  assert_contains "prd backwrite"  "prd 写完"  || return 1
}

test_no_standalone_paths_chapter() {
  # 确认没有 ## 路径 这个章节（已内嵌）
  local count
  count=$(grep -c "^## 路径" "$TARGET" 2>/dev/null || true)
  if [ "$count" -eq 0 ]; then return 0; fi
  echo "  found $count standalone ## 路径 section(s) — should be inlined"
  return 1
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
