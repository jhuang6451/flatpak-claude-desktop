#!/bin/bash
set -euo pipefail

FLAGS=()
FEATURES=()

# Wayland auto-detection and flags
if [ -n "${WAYLAND_DISPLAY:-}" ] || [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
    FLAGS+=(--ozone-platform-hint=auto)
    FEATURES+=(WaylandWindowDecorations)
fi

# Allow user custom flags via ~/.config/claude-flags.conf or claude-desktop-flags.conf
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
USER_FLAGS=()
if [ -f "$CONFIG_DIR/claude-flags.conf" ]; then
    mapfile -t USER_FLAGS < <(grep -Ev '^\s*$|^#' "$CONFIG_DIR/claude-flags.conf" || true)
elif [ -f "$CONFIG_DIR/claude-desktop-flags.conf" ]; then
    mapfile -t USER_FLAGS < <(grep -Ev '^\s*$|^#' "$CONFIG_DIR/claude-desktop-flags.conf" || true)
fi

# Chromium keeps only the last --enable-features, so merge the user's list
# with ours instead of letting it override the defaults.
for flag in "${USER_FLAGS[@]}"; do
    case "$flag" in
        --enable-features=*) FEATURES+=("${flag#--enable-features=}") ;;
        *) FLAGS+=("$flag") ;;
    esac
done
if [ "${#FEATURES[@]}" -gt 0 ]; then
    FEATURES_JOINED=$(IFS=,; echo "${FEATURES[*]}")
    FLAGS+=("--enable-features=$FEATURES_JOINED")
fi

# Desktop actions (see the .desktop file) pass a short name instead of a URL,
# because Flatpak rewrites quoted Exec arguments in a way desktop-file-validate rejects.
case "${1:-}" in
    --action=new-chat) shift; set -- "claude://claude.ai/new?surface=chat&source=desktop_action" "$@" ;;
    --action=new-code) shift; set -- "claude://code/new?source=desktop_action" "$@" ;;
esac

# Keep temporary files in their own dir instead of mixing them into the cache root
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}"
export TMPDIR="$CACHE_ROOT/tmp"
mkdir -p "$TMPDIR"

# chrome-native-host (spawned by the host browser, see scripts/install-chrome-native-host.sh)
# creates its socket in /tmp, which is private per sandbox. Point it at a shared dir.
BRIDGE_DIR="$CACHE_ROOT/claude-mcp-browser-bridge"
mkdir -p "$BRIDGE_DIR" && chmod 700 "$BRIDGE_DIR"
ln -sfn "$BRIDGE_DIR" "/tmp/claude-mcp-browser-bridge-$(id -un)"

# Execute using zypak-wrapper (from org.electronjs.Electron2.BaseApp)
exec zypak-wrapper /app/lib/claude-desktop/claude-desktop "${FLAGS[@]}" "$@"
