#!/bin/bash

# Set up Dvorak + US QWERTY + Pinyin on Omarchy.
#
# - A Quattro Lua binding handles Dvorak <-> QWERTY (Left Alt + Right Alt)
# - fcitx5 handles Pinyin on/off (Ctrl+/)
# - Pinyin inherits the active Latin layout (macOS-like behavior)
# - Omarchy Shell shows the active XKB layout indicator
#
# NOTE: Hyprland input settings are managed by the dotfiles repo.
# This script configures fcitx5, ensures the Omarchy keyboard layout widget is
# present, and applies the same two-layout settings live. Dotfiles also keeps
# Espanso synchronized with the active layout.
#
# NOTE: fcitx5-chinese-addons is installed via install-packages.sh

set -euo pipefail

FCITX5_DIR="$HOME/.config/fcitx5"
FCITX5_CONFIG="$FCITX5_DIR/config"
FCITX5_PROFILE="$HOME/.config/fcitx5/profile"
BACKUP_DIR="$HOME/.local/state/dotfiles/backups/fcitx5-$(date +%Y%m%d%H%M%S)-$$"

backup_file() {
  local source=$1
  local relative=${source#"$HOME/"}

  [[ -e "$source" || -L "$source" ]] || return 0
  mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
  cp -a -- "$source" "$BACKUP_DIR/$relative"
}

echo "[keyboard] Setting up Dvorak + US QWERTY + Pinyin..."

# 1. Verify fcitx5-chinese-addons is installed
if ! omarchy pkg present fcitx5-chinese-addons; then
  echo "[keyboard] Error: fcitx5-chinese-addons is not installed. Run install-packages.sh first."
  exit 1
fi

# 2. Configure fcitx5 for Pinyin with Ctrl+/ trigger
echo "[keyboard] Configuring fcitx5 for Pinyin..."

backup_file "$FCITX5_CONFIG"
backup_file "$FCITX5_PROFILE"
backup_file "$FCITX5_DIR/conf/config"
if [[ -d $BACKUP_DIR ]]; then
  echo "  -> Previous Fcitx files backed up at $BACKUP_DIR"
fi

# Keep a running Fcitx instance in sync before replacing its files. A graceful
# restart saves the old in-memory profile on exit and would overwrite the new
# profile. Updating the live group first makes later saves deterministic.
fcitx_running=0
if fcitx5-remote --check &>/dev/null; then
  fcitx_running=1
  gdbus call --session \
    --dest org.fcitx.Fcitx5 \
    --object-path /controller \
    --method org.fcitx.Fcitx.Controller1.Refresh >/dev/null
  gdbus call --session \
    --dest org.fcitx.Fcitx5 \
    --object-path /controller \
    --method org.fcitx.Fcitx.Controller1.SetInputMethodGroupInfo \
    Default us "[('keyboard-us', ''), ('pinyin', '')]" >/dev/null
  fcitx5-remote -s pinyin
  gdbus call --session \
    --dest org.fcitx.Fcitx5 \
    --object-path /controller \
    --method org.fcitx.Fcitx.Controller1.Save >/dev/null
fi

mkdir -p "$FCITX5_DIR"

cat > "$FCITX5_CONFIG" <<'EOF'
[Hotkey/TriggerKeys]
0=Control+slash
EOF

cat > "$FCITX5_PROFILE" <<'EOF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=pinyin

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=pinyin
Layout=

[GroupOrder]
0=Default
EOF

# Remove the ineffective path written by the pre-Quattro installer.
rm -f "$FCITX5_DIR/conf/config"

if ((fcitx_running)); then
  fcitx5-remote -r
fi

echo "  -> Pinyin trigger: Ctrl+/"
echo "  -> Pinyin inherits active XKB layout"

# 3. Ensure the Quattro keyboard layout widget is on the Omarchy Shell bar
echo "[keyboard] Ensuring the Omarchy keyboard layout widget is present..."
omarchy bar put omarchy.keyboard-layout --after omarchy.clock

# 4. Apply Hyprland settings live (dotfiles have the persistent config)
echo "[keyboard] Applying keyboard settings live..."
if command -v hyprctl &>/dev/null; then
  hyprctl keyword input:kb_layout "us,us" 2>/dev/null || true
  hyprctl keyword input:kb_variant "dvorak," 2>/dev/null || true
  hyprctl keyword input:kb_options "compose:paus" 2>/dev/null || true
fi

echo "[keyboard] Done."
echo ""
echo "  Dvorak <-> QWERTY    Left Alt + Right Alt"
echo "  Pinyin on/off        Ctrl + /"
