#!/usr/bin/env bash
# install.sh — One-line installer for know skill
# Usage: curl -fsSL https://raw.githubusercontent.com/xiatiandeairen/know-for-agent/main/install.sh | bash

set -euo pipefail

PLUGIN_NAME="know"
MARKETPLACE_NAME="know"
REPO_URL="https://github.com/xiatiandeairen/know-for-agent.git"
INSTALL_DIR="$HOME/.claude/plugins/$PLUGIN_NAME"
SETTINGS_FILE="$HOME/.claude/settings.json"
INSTALLED_FILE="$HOME/.claude/plugins/installed_plugins.json"

info()  { printf '\033[1;34m[know]\033[0m %s\n' "$1"; }
error() { printf '\033[1;31m[know]\033[0m %s\n' "$1" >&2; }
ok()    { printf '\033[1;32m[know]\033[0m %s\n' "$1"; }

# Step 1: Check jq
if ! command -v jq &>/dev/null; then
  error "jq is required but not installed."
  echo ""
  echo "  macOS:  brew install jq"
  echo "  Ubuntu: sudo apt-get install jq"
  echo "  Arch:   sudo pacman -S jq"
  echo ""
  exit 1
fi

# Step 2: Check git
if ! command -v git &>/dev/null; then
  error "git is required but not installed."
  exit 1
fi

# Step 3: Check Claude Code directory
if [ ! -d "$HOME/.claude" ]; then
  error "~/.claude/ not found. Is Claude Code installed?"
  exit 1
fi

# Step 4: Clone or update
if [ -d "$INSTALL_DIR" ]; then
  info "Updating existing installation..."
  git -C "$INSTALL_DIR" pull --quiet
else
  info "Installing know skill..."
  mkdir -p "$HOME/.claude/plugins"
  git clone --quiet "$REPO_URL" "$INSTALL_DIR"
fi

# Step 5: Register in settings.json
if [ ! -f "$SETTINGS_FILE" ]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Add extraKnownMarketplaces.know
UPDATED=$(jq --arg path "$INSTALL_DIR" '
  .extraKnownMarketplaces //= {} |
  .extraKnownMarketplaces.know = {
    "source": {
      "source": "directory",
      "path": $path
    }
  }
' "$SETTINGS_FILE")

# Add enabledPlugins["know@know"]
UPDATED=$(echo "$UPDATED" | jq '
  .enabledPlugins //= {} |
  .enabledPlugins["know@know"] = true
')

echo "$UPDATED" > "$SETTINGS_FILE"

# Step 6: Register in installed_plugins.json
NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
VERSION=$(jq -r '.version' "$INSTALL_DIR/.claude-plugin/plugin.json" 2>/dev/null || echo "1.0.0")

if [ ! -f "$INSTALLED_FILE" ]; then
  echo '{"version":2,"plugins":{}}' > "$INSTALLED_FILE"
fi

jq --arg now "$NOW" --arg path "$INSTALL_DIR/.claude/plugins/cache/$MARKETPLACE_NAME/$PLUGIN_NAME/$VERSION" --arg ver "$VERSION" '
  .plugins["know@know"] = [{
    "scope": "user",
    "installPath": $path,
    "version": $ver,
    "installedAt": $now,
    "lastUpdated": $now
  }]
' "$INSTALLED_FILE" > "${INSTALLED_FILE}.tmp" && mv "${INSTALLED_FILE}.tmp" "$INSTALLED_FILE"

ok "Installation complete!"
echo ""
echo "  Open any project in Claude Code and try:"
echo "    /know learn    — persist knowledge from conversation"
echo "    /know write    — generate structured documents"
echo "    /know review   — audit existing entries"
echo ""
echo "  To uninstall:"
echo "    curl -fsSL https://raw.githubusercontent.com/xiatiandeairen/know-for-agent/main/uninstall.sh | bash"
echo ""
