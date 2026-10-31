#!/bin/bash
set -euo pipefail

FLAGS=()

# Wayland auto-detection and flags
if [ -n "${WAYLAND_DISPLAY:-}" ] || [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
    FLAGS+=(
        --ozone-platform-hint=auto
        --enable-features=WaylandWindowDecorations
    )
fi

# Allow user custom flags via ~/.config/claude-flags.conf or claude-desktop-flags.conf
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
if [ -f "$CONFIG_DIR/claude-flags.conf" ]; then
    mapfile -t USER_FLAGS < <(grep -Ev '^\s*$|^#' "$CONFIG_DIR/claude-flags.conf")
    FLAGS+=("${USER_FLAGS[@]}")
elif [ -f "$CONFIG_DIR/claude-desktop-flags.conf" ]; then
    mapfile -t USER_FLAGS < <(grep -Ev '^\s*$|^#' "$CONFIG_DIR/claude-desktop-flags.conf")
    FLAGS+=("${USER_FLAGS[@]}")
fi

# Set temporary directory
export TMPDIR="${XDG_CACHE_HOME:-$HOME/.cache}"

# chrome-native-host (spawned by the host browser, see scripts/install-chrome-native-host.sh)
# creates its socket in /tmp, which is private per sandbox. Point it at a shared dir.
BRIDGE_DIR="$TMPDIR/claude-mcp-browser-bridge"
mkdir -p "$BRIDGE_DIR" && chmod 700 "$BRIDGE_DIR"
ln -sfn "$BRIDGE_DIR" "/tmp/claude-mcp-browser-bridge-$(id -un)"

# Execute using zypak-wrapper (from org.electronjs.Electron2.BaseApp)
exec zypak-wrapper /app/lib/claude-desktop/claude-desktop "${FLAGS[@]}" "$@"
