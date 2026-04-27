#!/usr/bin/env bash
# know-paths.sh — 路径解析 CLI
#
# Usage: bash scripts/know-paths.sh <kind>
#   kinds: root | docs | templates | project-claude-md | user-claude-md
#
# 解析优先级：
#   root:              $KNOW_PROJECT_ROOT  → git rev-parse --show-toplevel → realpath dirname/..
#   docs:              $KNOW_DOCS_DIR      → "$(root)/docs"
#   templates:         $KNOW_TEMPLATES_DIR → "$(root)/workflows/templates"
#   project-claude-md: "$(root)/CLAUDE.md"
#   user-claude-md:    $KNOW_USER_CLAUDE_MD → "~/.claude/CLAUDE.md"
#
# 输出：绝对路径，无尾部斜杠 / 换行（printf %s）
# 退出：0 ok | 1 unknown kind | 2 root resolution failed

set -euo pipefail

resolve_root() {
  if [ -n "${KNOW_PROJECT_ROOT:-}" ]; then
    printf "%s" "$KNOW_PROJECT_ROOT"
    return 0
  fi
  if command -v git >/dev/null 2>&1; then
    local r
    if r=$(git rev-parse --show-toplevel 2>/dev/null); then
      printf "%s" "$r"
      return 0
    fi
  fi
  local script_dir
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) || return 2
  local root
  root=$(cd "$script_dir/.." && pwd) || return 2
  printf "%s" "$root"
}

main() {
  local kind="${1:-}"
  if [ -z "$kind" ]; then
    echo "Usage: bash scripts/know-paths.sh <root|docs|templates>" >&2
    exit 1
  fi

  local root
  if ! root=$(resolve_root); then
    echo "Error: cannot resolve project root" >&2
    exit 2
  fi

  case "$kind" in
    root)
      printf "%s" "$root"
      ;;
    docs)
      printf "%s" "${KNOW_DOCS_DIR:-$root/docs}"
      ;;
    templates)
      printf "%s" "${KNOW_TEMPLATES_DIR:-$root/workflows/templates}"
      ;;
    project-claude-md)
      printf "%s" "$root/CLAUDE.md"
      ;;
    user-claude-md)
      printf "%s" "${KNOW_USER_CLAUDE_MD:-$HOME/.claude/CLAUDE.md}"
      ;;
    *)
      echo "Error: unknown kind '$kind' (expected: root|docs|templates|project-claude-md|user-claude-md)" >&2
      exit 1
      ;;
  esac
}

main "$@"
