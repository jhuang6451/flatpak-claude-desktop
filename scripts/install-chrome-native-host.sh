#!/bin/bash
# Make "Claude in Chrome" work with the Flatpak build.
# Installs a host-side wrapper for the sandboxed chrome-native-host and registers
# the native messaging manifest with the browsers found on the host.
set -euo pipefail

APP_ID=com.anthropic.Claude
HOST_NAME=com.anthropic.claude_browser_extension
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
WRAPPER="$BIN_DIR/claude-chrome-native-host"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"

mkdir -p "$BIN_DIR"
cat > "$WRAPPER" <<WRAP
#!/bin/sh
# Run chrome-native-host inside the Claude Flatpak. /tmp is private per sandbox,
# so link the bridge socket dir to the shared one that claude.sh also uses.
exec flatpak run --command=sh $APP_ID -c '
d="$CACHE_DIR/claude-mcp-browser-bridge"
mkdir -p "\$d" && chmod 700 "\$d"
ln -sfn "\$d" "/tmp/claude-mcp-browser-bridge-\$(id -un)"
exec /app/lib/claude-desktop/resources/chrome-native-host "\$@"' sh "\$@"
WRAP
chmod +x "$WRAPPER"

manifest=$(cat <<JSON
{
  "name": "$HOST_NAME",
  "description": "Claude Browser Extension Native Host",
  "path": "$WRAPPER",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://dihbgbndebgnbjfmelmegjepbnkhlgni/",
    "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/",
    "chrome-extension://dngcpimnedloihjnnfngkgjoidhnaolf/"
  ]
}
JSON
)

for b in google-chrome google-chrome-beta chromium BraveSoftware/Brave-Browser microsoft-edge vivaldi; do
  [ -d "$CONFIG_DIR/$b" ] || continue
  mkdir -p "$CONFIG_DIR/$b/NativeMessagingHosts"
  printf '%s\n' "$manifest" > "$CONFIG_DIR/$b/NativeMessagingHosts/$HOST_NAME.json"
  echo "installed manifest for $b"
done
echo "wrapper: $WRAPPER"
echo "Restart Claude Desktop (so claude.sh links the socket dir) and the browser."
