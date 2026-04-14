#!/usr/bin/env bash
# uninstall.sh — One-line uninstaller for know skill
# Usage: curl -fsSL https://raw.githubusercontent.com/xiatiandeairen/know-for-agent/main/uninstall.sh | bash

set -euo pipefail

PLUGIN_NAME="know"
INSTALL_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
SETTINGS_FILE="$HOME/.claude/settings.json"
INSTALLED_FILE="$HOME/.claude/plugins/installed_plugins.json"

info()  { printf '\033[1;34m[know]\033[0m %s\n' "$1"; }
ok()    { printf '\033[1;32m[know]\033[0m %s\n' "$1"; }

# Step 1: Remove from settings.json
if [ -f "$SETTINGS_FILE" ] && command -v jq &>/dev/null; then
  info "Removing from settings.json..."
  jq '
    del(.extraKnownMarketplaces.know) |
    del(.enabledPlugins["know@know"])
  ' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
fi

# Step 2: Remove from installed_plugins.json
if [ -f "$INSTALLED_FILE" ] && command -v jq &>/dev/null; then
  info "Removing from installed_plugins.json..."
  jq '
    del(.plugins["know@know"])
  ' "$INSTALLED_FILE" > "${INSTALLED_FILE}.tmp" && mv "${INSTALLED_FILE}.tmp" "$INSTALLED_FILE"
fi

# Step 3: Remove installation directory
if [ -d "$INSTALL_DIR" ]; then
  info "Removing $INSTALL_DIR..."
  rm -rf "$INSTALL_DIR"
fi

# Step 4: Remove plugin cache
CACHE_DIR="$HOME/.claude/plugins/cache/know"
if [ -d "$CACHE_DIR" ]; then
  info "Removing cache..."
  rm -rf "$CACHE_DIR"
fi

ok "Uninstall complete. Restart Claude Code to take effect."
echo ""
echo "  Note: .know/ directories in your projects are NOT removed."
echo "  They contain your project knowledge and can be safely kept or deleted manually."
echo ""
