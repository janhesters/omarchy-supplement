#!/bin/bash

# Install a focus mode that blocks distracting websites (X, YouTube, Reddit)
# via /etc/hosts, with a Quattro shell indicator showing when it is active.
#
# Usage after install:
#   focus       - Block sites
#   focus off   - Unblock sites

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
FOCUS_SCRIPT="$BIN_DIR/focus"
LEGACY_INDICATOR="$BIN_DIR/focus-indicator"

echo "[focus] Setting up focus mode..."

mkdir -p "$BIN_DIR"

cat > "$FOCUS_SCRIPT" <<'SCRIPT'
#!/bin/bash

set -euo pipefail

BLOCKED_SITES=(
  "twitter.com"
  "www.twitter.com"
  "x.com"
  "www.x.com"
  "youtube.com"
  "www.youtube.com"
  "reddit.com"
  "www.reddit.com"
  "old.reddit.com"
)

MARKER="# focus-block"

# The bar indicator reads /etc/hosts on demand rather than polling, so it has to
# be told when the marker changes. Quattro replaced waybar's RTMIN+11 signal
# with an IPC call into the shell.
refresh_indicator() {
  omarchy shell -q omarchy.indicators refresh 2>/dev/null || true
}

case "${1:-on}" in
  on)
    for site in "${BLOCKED_SITES[@]}"; do
      echo "127.0.0.1 $site $MARKER" | sudo tee -a /etc/hosts > /dev/null
    done
    refresh_indicator
    echo "Blocked: X, YouTube, Reddit"
    ;;
  off)
    sudo sed -i "/$MARKER/d" /etc/hosts
    refresh_indicator
    echo "Unblocked all sites"
    ;;
  *)
    echo "Usage: focus [on|off]"
    ;;
esac
SCRIPT
chmod +x "$FOCUS_SCRIPT"
echo "  -> Installed focus script"

# The Omarchy 3 indicator was a waybar exec script; waybar is gone under Quattro.
if [[ -f $LEGACY_INDICATOR ]]; then
  rm -f "$LEGACY_INDICATOR"
  echo "  -> Removed the legacy waybar focus indicator"
fi

"$SCRIPT_DIR/shell/install-shell-indicator.sh" "$SCRIPT_DIR/shell/indicators/Focus.qml" --register

echo "[focus] Done."
echo ""
echo "  focus        Block X, YouTube, Reddit"
echo "  focus off    Unblock all sites"
echo "  The bar indicator turns red when focus mode is active"
