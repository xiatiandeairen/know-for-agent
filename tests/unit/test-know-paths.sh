#!/usr/bin/env bash
# tests/unit/test-know-paths.sh — know-paths.sh 单元测试
#
# 用法：
#   bash tests/unit/test-know-paths.sh                    # 跑全部 case
#   bash tests/unit/test-know-paths.sh test_default_docs  # 跑指定 case
#
# 退出码：0=全 pass / 1=有 fail
# 添加 case：写一个 `test_<scenario>` 函数即可，主循环反射拾取。

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
SCRIPT="$REPO_ROOT/scripts/know-paths.sh"

# ────────────────────────── helpers ──────────────────────────

# run_capture <out_file> <err_file> -- cmd args...
# 跑 cmd，stdout 写 out_file，stderr 写 err_file。返回 cmd 的 exit code。
run_capture() {
  local out="$1" err="$2"
  shift 2
  [ "${1:-}" = "--" ] && shift
  "$@" >"$out" 2>"$err"
}

# assert_eq <label> <expected> <actual>
assert_eq() {
  if [ "$2" = "$3" ]; then
    return 0
  fi
  echo "  expected: '$2'"
  echo "  actual:   '$3'"
  return 1
}

# assert_match <label> <needle> <haystack>
assert_match() {
  case "$3" in
    *"$2"*) return 0 ;;
    *)
      echo "  needle:   '$2'"
      echo "  haystack: '$3'"
      return 1
      ;;
  esac
}

# assert_exit <label> <expected_code> <actual_code>
assert_exit() {
  if [ "$2" = "$3" ]; then
    return 0
  fi
  echo "  expected exit: $2"
  echo "  actual exit:   $3"
  return 1
}

# 为每 case 提供干净 env 起点
clean_env() {
  unset KNOW_PROJECT_ROOT KNOW_DOCS_DIR KNOW_TEMPLATES_DIR KNOW_USER_CLAUDE_MD
}

# ────────────────────────── cases ──────────────────────────

test_default_root() {
  clean_env
  local out
  out=$(bash "$SCRIPT" root)
  assert_eq "default root" "$REPO_ROOT" "$out"
}

test_default_docs() {
  clean_env
  local out
  out=$(bash "$SCRIPT" docs)
  assert_eq "default docs" "$REPO_ROOT/docs" "$out"
}

test_default_templates() {
  clean_env
  local out
  out=$(bash "$SCRIPT" templates)
  assert_eq "default templates" "$REPO_ROOT/workflows/templates" "$out"
}

test_env_root_override() {
  clean_env
  export KNOW_PROJECT_ROOT="/tmp/k-test-$$"
  local out
  out=$(bash "$SCRIPT" root)
  assert_eq "env root override" "/tmp/k-test-$$" "$out"
}

test_env_root_propagates_to_docs() {
  clean_env
  export KNOW_PROJECT_ROOT="/tmp/k-test-$$"
  local out
  out=$(bash "$SCRIPT" docs)
  assert_eq "root propagates to docs" "/tmp/k-test-$$/docs" "$out"
}

test_env_root_propagates_to_templates() {
  clean_env
  export KNOW_PROJECT_ROOT="/tmp/k-test-$$"
  local out
  out=$(bash "$SCRIPT" templates)
  assert_eq "root propagates to templates" "/tmp/k-test-$$/workflows/templates" "$out"
}

test_env_docs_override() {
  clean_env
  export KNOW_DOCS_DIR="/tmp/k-test-$$/d"
  local out
  out=$(bash "$SCRIPT" docs)
  assert_eq "docs override" "/tmp/k-test-$$/d" "$out"
}

test_env_templates_override() {
  clean_env
  export KNOW_TEMPLATES_DIR="/tmp/k-test-$$/t"
  local out
  out=$(bash "$SCRIPT" templates)
  assert_eq "templates override" "/tmp/k-test-$$/t" "$out"
}

test_env_docs_overrides_root_propagation() {
  clean_env
  export KNOW_PROJECT_ROOT="/tmp/k-test-$$"
  export KNOW_DOCS_DIR="/tmp/k-test-$$/explicit-docs"
  local out
  out=$(bash "$SCRIPT" docs)
  assert_eq "docs override beats root propagation" \
    "/tmp/k-test-$$/explicit-docs" "$out"
}

test_unknown_kind_exits_1() {
  clean_env
  local out err code
  out=$(mktemp); err=$(mktemp)
  set +e
  bash "$SCRIPT" bogus >"$out" 2>"$err"
  code=$?
  set -e
  local err_content
  err_content=$(cat "$err")
  rm -f "$out" "$err"

  assert_exit "unknown kind exit" "1" "$code" || return 1
  assert_match "unknown kind stderr" "unknown" "$err_content"
}

test_no_arg_exits_1() {
  clean_env
  local out err code
  out=$(mktemp); err=$(mktemp)
  set +e
  bash "$SCRIPT" >"$out" 2>"$err"
  code=$?
  set -e
  local err_content
  err_content=$(cat "$err")
  rm -f "$out" "$err"

  assert_exit "no arg exit" "1" "$code" || return 1
  assert_match "no arg stderr" "Usage" "$err_content"
}

test_default_project_claude_md() {
  clean_env
  local out
  out=$(bash "$SCRIPT" project-claude-md)
  assert_eq "default project-claude-md" "$REPO_ROOT/CLAUDE.md" "$out"
}

test_env_root_propagates_to_project_claude_md() {
  clean_env
  export KNOW_PROJECT_ROOT="/tmp/k-test-$$"
  local out
  out=$(bash "$SCRIPT" project-claude-md)
  assert_eq "root propagates to project-claude-md" "/tmp/k-test-$$/CLAUDE.md" "$out"
}

test_default_user_claude_md() {
  clean_env
  local out
  out=$(bash "$SCRIPT" user-claude-md)
  assert_eq "default user-claude-md" "$HOME/.claude/CLAUDE.md" "$out"
}

test_env_user_claude_md_override() {
  clean_env
  export KNOW_USER_CLAUDE_MD="/tmp/k-user-$$/CLAUDE.md"
  local out
  out=$(bash "$SCRIPT" user-claude-md)
  assert_eq "user-claude-md override" "/tmp/k-user-$$/CLAUDE.md" "$out"
}

test_no_trailing_newline() {
  clean_env
  local out_file
  out_file=$(mktemp)
  bash "$SCRIPT" docs >"$out_file"
  local bytes
  bytes=$(wc -c <"$out_file" | tr -d ' ')
  local expected="$REPO_ROOT/docs"
  local expected_bytes=${#expected}
  rm -f "$out_file"
  assert_eq "no trailing newline (byte count)" "$expected_bytes" "$bytes"
}

# ────────────────────────── runner ──────────────────────────

main() {
  local cases=()
  if [ $# -ge 1 ]; then
    if declare -F "$1" >/dev/null; then
      cases=("$1")
    else
      echo "Error: no such case '$1'" >&2
      echo "Available cases:" >&2
      declare -F | awk '$3 ~ /^test_/ {print "  "$3}' >&2
      exit 1
    fi
  else
    # 反射所有 test_* 函数
    while IFS= read -r line; do
      cases+=("$line")
    done < <(declare -F | awk '$3 ~ /^test_/ {print $3}')
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
