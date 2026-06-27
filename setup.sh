#!/bin/bash
#
# One-time setup for the Claude Usage menu bar widget.
#   1. Installs SwiftBar (Homebrew cask) if needed
#   2. Captures a long-lived OAuth token and stores it in the macOS Keychain
#   3. Symlinks the plugin into SwiftBar's plugin folder
#
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$DIR/claude-usage.5m.sh"
KEYCHAIN_SERVICE="claude-usage-widget"

echo "== Claude Usage Widget setup =="
echo

# --- 1. SwiftBar ---------------------------------------------------------------
if [ -d "/Applications/SwiftBar.app" ]; then
  echo "✓ SwiftBar already installed"
else
  echo "Installing SwiftBar via Homebrew..."
  brew install --cask swiftbar
fi

# --- 2. OAuth token ------------------------------------------------------------
echo
if security find-generic-password -s "$KEYCHAIN_SERVICE" -a oauth -w >/dev/null 2>&1; then
  echo "✓ An OAuth token is already stored in the Keychain."
  read -r -p "  Replace it? [y/N] " ans
  REPLACE="${ans:-N}"
else
  REPLACE="y"
fi

if [[ "$REPLACE" =~ ^[Yy]$ ]]; then
  echo
  echo "Generate a long-lived token in another terminal with:"
  echo "    claude setup-token"
  echo "It prints a token starting with 'sk-ant-oat01-...'. Paste it below."
  echo
  read -r -s -p "Paste OAuth token: " TOKEN
  echo
  if [ -z "$TOKEN" ]; then
    echo "No token entered — aborting." >&2
    exit 1
  fi
  security add-generic-password -s "$KEYCHAIN_SERVICE" -a oauth -w "$TOKEN" -U
  echo "✓ Token stored in Keychain (service: $KEYCHAIN_SERVICE)"
fi

# --- 3. Plugin install ---------------------------------------------------------
echo
chmod +x "$PLUGIN"
echo "✓ Plugin marked executable"

echo
echo "Launch SwiftBar once (open -a SwiftBar). On first launch it asks you to"
echo "choose a Plugin Folder. Then symlink the plugin there, e.g.:"
echo
echo "    ln -sf \"$PLUGIN\" \"\$HOME/Library/Application Support/SwiftBar/Plugins/\""
echo
DEFAULT_PLUGINS="$HOME/Library/Application Support/SwiftBar/Plugins"
if [ -d "$DEFAULT_PLUGINS" ]; then
  ln -sf "$PLUGIN" "$DEFAULT_PLUGINS/"
  echo "✓ Detected SwiftBar plugin folder — symlinked automatically."
  echo "  Refresh SwiftBar (menu → Refresh All) to see it."
fi

echo
echo "== Done =="
