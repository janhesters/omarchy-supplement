#!/bin/bash

# Set up Dvorak + US QWERTY on Omarchy.
#
# - A Quattro Lua binding handles Dvorak <-> QWERTY (Left Alt + Right Alt)
# - Omarchy Shell shows the active XKB layout indicator
#
# NOTE: Hyprland input settings are managed by the dotfiles repo.
# This script removes the old optional Pinyin setup, ensures the Omarchy
# keyboard layout widget is present, and applies the same two-layout settings
# live. Dotfiles also keeps Espanso synchronized with the active layout.

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

echo "[keyboard] Setting up Dvorak + US QWERTY..."

# 1. Remove the old optional Pinyin input method. Omarchy still runs fcitx5 for
# XCompose, so disable only Pinyin and leave the service itself available.
echo "[keyboard] Disabling the old Pinyin input method..."

backup_file "$FCITX5_CONFIG"
backup_file "$FCITX5_PROFILE"
backup_file "$FCITX5_DIR/conf/config"
if [[ -d $BACKUP_DIR ]]; then
  echo "  -> Previous Fcitx files backed up at $BACKUP_DIR"
fi

# Keep a running Fcitx instance in sync before replacing its files. Otherwise,
# a later graceful shutdown could save its stale Pinyin group over the files.
fcitx_running=0
if fcitx5-remote --check &>/dev/null; then
  fcitx_running=1
  # Fcitx ignores an unknown addon ID, so this also works on clean installs
  # where the optional Chinese addon package was never installed.
  gdbus call --session \
    --dest org.fcitx.Fcitx5 \
    --object-path /controller \
    --method org.fcitx.Fcitx.Controller1.SetAddonsState \
    "[('pinyin', false)]" >/dev/null
  gdbus call --session \
    --dest org.fcitx.Fcitx5 \
    --object-path /controller \
    --method org.fcitx.Fcitx.Controller1.SetInputMethodGroupInfo \
    Default '' "[]" >/dev/null
  gdbus call --session \
    --dest org.fcitx.Fcitx5 \
    --object-path /controller \
    --method org.fcitx.Fcitx.Controller1.Deactivate >/dev/null
  gdbus call --session \
    --dest org.fcitx.Fcitx5 \
    --object-path /controller \
    --method org.fcitx.Fcitx.Controller1.Save >/dev/null
fi

mkdir -p "$FCITX5_DIR"

cat > "$FCITX5_CONFIG" <<'EOF'
[Behavior]
ActiveByDefault=False
ShareInputState=No

[Behavior/DisabledAddons]
0=pinyin
EOF

cat > "$FCITX5_PROFILE" <<'EOF'
[Groups/0]
Name=Default
Items=
Default Layout=
DefaultIM=

[GroupOrder]
0=Default
EOF

# Remove the ineffective path written by the pre-Quattro installer.
rm -f "$FCITX5_DIR/conf/config"

if ((fcitx_running)); then
  gdbus call --session \
    --dest org.fcitx.Fcitx5 \
    --object-path /controller \
    --method org.fcitx.Fcitx.Controller1.ReloadConfig >/dev/null
  gdbus call --session \
    --dest org.fcitx.Fcitx5 \
    --object-path /controller \
    --method org.fcitx.Fcitx.Controller1.Deactivate >/dev/null
fi

echo "  -> Pinyin disabled"

# 2. Ensure the Quattro keyboard layout widget is on the Omarchy Shell bar
echo "[keyboard] Ensuring the Omarchy keyboard layout widget is present..."
omarchy bar put omarchy.keyboard-layout --after omarchy.clock

# 3. Apply Hyprland settings live (dotfiles have the persistent config)
echo "[keyboard] Applying keyboard settings live..."
hyprctl eval 'hl.config({ input = { kb_layout = "us,us", kb_variant = "dvorak,", kb_options = "compose:paus" } })' >/dev/null

echo "[keyboard] Done."
echo ""
echo "  Dvorak <-> QWERTY    Left Alt + Right Alt"
