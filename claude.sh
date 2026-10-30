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

# Execute using zypak-wrapper (from org.electronjs.Electron2.BaseApp)
exec zypak-wrapper /app/lib/claude-desktop/claude-desktop "${FLAGS[@]}" "$@"
