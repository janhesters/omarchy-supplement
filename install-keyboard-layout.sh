#!/bin/bash

# Set up Dvorak + ABC Extended (QWERTY) + Pinyin on Omarchy.
#
# - Hyprland keybind handles Dvorak <-> QWERTY (Left Alt + Right Alt)
# - fcitx5 handles Pinyin on/off (Ctrl+/)
# - Pinyin inherits the active Latin layout (macOS-like behavior)
# - Waybar shows the active XKB layout indicator
#
# NOTE: Hyprland input settings are managed by the dotfiles repo.
# This script configures fcitx5, adds the waybar language module, and
# applies settings live.
#
# NOTE: fcitx5-chinese-addons is installed via install-packages.sh

set -e

FCITX5_CONF_DIR="$HOME/.config/fcitx5/conf"
FCITX5_PROFILE="$HOME/.config/fcitx5/profile"
WAYBAR_CONFIG="$HOME/.config/waybar/config.jsonc"
WAYBAR_STYLE="$HOME/.config/waybar/style.css"

echo "[keyboard] Setting up Dvorak + ABC Extended + Pinyin..."

# 1. Verify fcitx5-chinese-addons is installed
if ! pacman -Q fcitx5-chinese-addons &>/dev/null; then
  echo "[keyboard] Error: fcitx5-chinese-addons is not installed. Run install-packages.sh first."
  exit 1
fi

# 2. Configure fcitx5 for Pinyin with Ctrl+/ trigger
echo "[keyboard] Configuring fcitx5 for Pinyin..."

mkdir -p "$FCITX5_CONF_DIR"

cat > "$FCITX5_CONF_DIR/config" <<'EOF'
[Hotkey]
TriggerKeys="Control+slash"
EnumerateKeys=
EOF

cat > "$FCITX5_PROFILE" <<'EOF'
[Groups/0]
Name=Default
Default Layout=
DefaultIM=pinyin

[Groups/0/Items/0]
Name=pinyin
Layout=

[GroupOrder]
0=Default
EOF

echo "  -> Pinyin trigger: Ctrl+/"
echo "  -> Pinyin inherits active XKB layout"

# 3. Add waybar keyboard layout indicator
echo "[keyboard] Adding waybar layout indicator..."

if [[ -f "$WAYBAR_CONFIG" ]]; then
  if grep -q 'hyprland/language' "$WAYBAR_CONFIG"; then
    echo "  -> Waybar already has language module, skipping."
  else
    # Add hyprland/language to modules-right (after tray-expander)
    sed -i'' -e 's/"group\/tray-expander",/"group\/tray-expander",\n    "hyprland\/language",/' "$WAYBAR_CONFIG"

    # Add the module config (before the tray definition)
    sed -i'' -e '/"tray": {/i\
  "hyprland/language": {\
    "format": "{short}",\
    "tooltip-format": "{long}",\
    "on-click": "hyprctl switchxkblayout all next"\
  },' "$WAYBAR_CONFIG"

    echo "  -> Added hyprland/language module to waybar"
  fi
fi

if [[ -f "$WAYBAR_STYLE" ]]; then
  if grep -q '#language' "$WAYBAR_STYLE"; then
    echo "  -> Waybar style already has language rule, skipping."
  else
    cat >> "$WAYBAR_STYLE" <<'CSSEOF'

#language {
  min-width: 12px;
  margin: 0 7.5px;
}
CSSEOF
    echo "  -> Added language indicator styling"
  fi
fi

# 4. Apply Hyprland settings live (dotfiles have the persistent config)
# QWERTY is index 0 so Electron apps (Cursor) that read the first/default
# XKB layout see QWERTY for correct hotkeys. We then switch to Dvorak (index 1).
echo "[keyboard] Applying keyboard settings live..."
if command -v hyprctl &>/dev/null; then
  hyprctl keyword input:kb_layout "us,us" 2>/dev/null || true
  hyprctl keyword input:kb_variant ",dvorak" 2>/dev/null || true
  hyprctl keyword input:kb_options "compose:paus" 2>/dev/null || true
  hyprctl switchxkblayout all 1 2>/dev/null || true
fi

if command -v fcitx5-remote &>/dev/null; then
  fcitx5-remote -r 2>/dev/null || true
fi

# Restart waybar to pick up language module
omarchy-restart-waybar 2>/dev/null || true

# Start espanso layout sync listener (dotfiles autostart.conf makes this persist across reboots).
# The listener watches for Hyprland layout change events and updates espanso's
# keyboard_layout config so triggers work on both Dvorak and QWERTY.
if command -v socat &>/dev/null && command -v espanso &>/dev/null; then
  echo "[keyboard] Starting espanso layout sync listener..."
  pkill -f espanso-layout-sync 2>/dev/null || true
  ~/.config/hypr/scripts/espanso-layout-sync &
  disown
fi

echo "[keyboard] Done."
echo ""
echo "  Dvorak <-> QWERTY    Left Alt + Right Alt"
echo "  Pinyin on/off        Ctrl + /"
echo "  Espanso layout sync  automatic (via Hyprland event listener)"
