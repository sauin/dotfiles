#!/usr/bin/env bash
#
# Deploy the WezTerm config and the fish shell-integration to their runtime
# locations. On this setup WezTerm runs on Windows while the shells run in WSL,
# so the two files live on different filesystems:
#
#   .wezterm.lua                    ->  <Windows home>\.wezterm.lua
#   wezterm-shell-integration.fish  ->  ~/.config/fish/conf.d/
#
# The Windows home is taken from $WINHOME if set, otherwise detected via
# cmd.exe. On a non-WSL machine (no cmd.exe) the config is installed to the
# standard ~/.wezterm.lua instead.
#
# Usage: ./deploy.sh
set -euo pipefail

# Directory this script (and the source files) live in.
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Resolve where .wezterm.lua should go -----------------------------------
win_home=""
if [ -n "${WINHOME:-}" ]; then
    win_home="$WINHOME"
elif command -v cmd.exe >/dev/null 2>&1; then
    # cmd.exe prints the Windows path (e.g. C:\Users\me); strip CR and convert
    # to a WSL path. The "UNC paths not supported" warning goes to stderr.
    win_profile="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r' || true)"
    if [ -n "$win_profile" ] && command -v wslpath >/dev/null 2>&1; then
        win_home="$(wslpath "$win_profile")"
    fi
fi

if [ -n "$win_home" ]; then
    wezterm_dest="$win_home/.wezterm.lua"
else
    # Not WSL, or detection failed: use the standard local location.
    wezterm_dest="$HOME/.wezterm.lua"
fi

# --- Install ----------------------------------------------------------------
fish_dest="$HOME/.config/fish/conf.d/wezterm-shell-integration.fish"
mkdir -p "$(dirname "$fish_dest")"

cp -f "$SRC_DIR/.wezterm.lua" "$wezterm_dest"
echo "installed: $wezterm_dest"

cp -f "$SRC_DIR/wezterm-shell-integration.fish" "$fish_dest"
echo "installed: $fish_dest"

echo
echo "Done. Open a new tab, or in already-open fish shells run:"
echo "    source $fish_dest"
echo "Reload WezTerm with Ctrl+Shift+R if it doesn't auto-reload."
