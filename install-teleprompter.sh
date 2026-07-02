#!/bin/bash

# Set up teleprompter screen recording for the Elgato Prompter.
#
# The Elgato Prompter is a DisplayLink/evdi virtual display, which
# gpu-screen-recorder (Omarchy's Super+Ctrl+C capture menu) cannot record:
# its kms backend can't see evdi outputs ("display not found") and its portal
# backend fails the EGL DMA-BUF modifier import on AMD. wf-recorder, which uses
# the wlr-screencopy protocol, records it fine.
#
# This script:
#   - enables the DisplayLink service (so the Prompter shows up as a monitor)
#   - installs a waybar indicator that distinguishes a teleprompter recording
#     (cyan monitor glyph) from a normal gpu-screen-recorder one (red dot) and
#     stops whichever is active on click; while the record-teleprompter watchdog
#     waits for a disconnected prompter to come back (dock USB drop), the glyph
#     turns orange instead of disappearing
#
# Packages (wf-recorder, displaylink, evdi-dkms) are installed by install-packages.sh.
# The Super+Alt+P keybinding and the record-teleprompter script live in the dotfiles repo.

set -e

INDICATOR_DIR="$HOME/.config/waybar/indicators"
WAYBAR_CONFIG="$HOME/.config/waybar/config.jsonc"
WAYBAR_STYLE="$HOME/.config/waybar/style.css"

echo "[teleprompter] Setting up teleprompter recording..."

# 1. Enable the DisplayLink service so the Elgato Prompter is driven as a monitor.
if pacman -Q displaylink &>/dev/null; then
  if systemctl is-enabled displaylink.service &>/dev/null; then
    echo "  -> DisplayLink service already enabled."
  else
    sudo systemctl enable --now displaylink.service
    echo "  -> Enabled DisplayLink service."
  fi
else
  echo "  -> displaylink not installed (run install-packages.sh first); skipping service enable."
fi

# 2. Install the waybar screen-recording indicator scripts.
mkdir -p "$INDICATOR_DIR"

cat > "$INDICATOR_DIR/screen-recording.sh" <<'INDICATOR'
#!/bin/bash
#
# Waybar screen-recording indicator. Overrides the stock omarchy indicator so it
# also shows wf-recorder (teleprompter) captures, with a distinct icon/color, and
# lets you tell at a glance which kind of recording is running.
#
#   teleprompter (wf-recorder) -> cyan monitor glyph
#   teleprompter waiting to auto-resume after a dock drop -> orange monitor glyph
#   normal screen (gpu-screen-recorder) -> red record dot
#
# The waiting state file is written by the record-teleprompter watchdog (dotfiles)
# while the prompter output is gone and the recording will resume on reconnect.

if [[ -f /tmp/record-teleprompter.waiting ]]; then
  echo '{"text": "󰍹", "tooltip": "Prompter disconnected — recording auto-resumes when it returns; click to end the session", "class": "teleprompter-waiting"}'
elif pgrep -x wf-recorder >/dev/null; then
  echo '{"text": "󰍹", "tooltip": "Recording teleprompter — click to stop", "class": "teleprompter"}'
elif pgrep -f "^gpu-screen-recorder" >/dev/null; then
  echo '{"text": "󰻂", "tooltip": "Stop recording", "class": "active"}'
else
  echo '{"text": ""}'
fi
INDICATOR
chmod +x "$INDICATOR_DIR/screen-recording.sh"
echo "  -> Installed screen-recording indicator"

cat > "$INDICATOR_DIR/screen-recording-stop.sh" <<'STOP'
#!/bin/bash
#
# on-click for the waybar screen-recording indicator: stop whichever capture is
# active. Teleprompter (wf-recorder) takes precedence; its toggle script also
# tears down any audio-mix modules, kills the reconnect watchdog when the session
# is in the waiting-to-resume state, and refreshes waybar.

if pgrep -x wf-recorder >/dev/null || [[ -f /tmp/record-teleprompter.waiting ]]; then
  exec ~/.config/hypr/scripts/record-teleprompter
elif pgrep -f "^gpu-screen-recorder" >/dev/null; then
  exec omarchy-capture-screenrecording
fi
STOP
chmod +x "$INDICATOR_DIR/screen-recording-stop.sh"
echo "  -> Installed screen-recording stop helper"

# 3. Point the existing waybar screenrecording-indicator module at our scripts
#    (replaces the stock gpu-screen-recorder exec/on-click; idempotent).
if [[ -f "$WAYBAR_CONFIG" ]]; then
  if grep -q 'indicators/screen-recording-stop.sh' "$WAYBAR_CONFIG"; then
    echo "  -> Waybar already points at teleprompter indicator, skipping."
  else
    sed -i'' \
      -e 's|"on-click": "omarchy-capture-screenrecording"|"on-click": "$HOME/.config/waybar/indicators/screen-recording-stop.sh"|' \
      -e 's|"exec": "\$OMARCHY_PATH/default/waybar/indicators/screen-recording.sh"|"exec": "$HOME/.config/waybar/indicators/screen-recording.sh"|' \
      "$WAYBAR_CONFIG"
    echo "  -> Repointed waybar screenrecording-indicator module"
  fi
fi

# 4. Add the teleprompter icon colors (cyan = recording, orange = waiting to
#    resume after a dock drop), next to the stock red .active rule.
if [[ -f "$WAYBAR_STYLE" ]]; then
  if grep -q '#custom-screenrecording-indicator.teleprompter {' "$WAYBAR_STYLE"; then
    echo "  -> Waybar style already has teleprompter rule, skipping."
  else
    cat >> "$WAYBAR_STYLE" <<'CSSEOF'

#custom-screenrecording-indicator.teleprompter {
  color: #5fd7d7;
}
CSSEOF
    echo "  -> Added teleprompter indicator styling"
  fi
  if grep -q '#custom-screenrecording-indicator.teleprompter-waiting' "$WAYBAR_STYLE"; then
    echo "  -> Waybar style already has teleprompter-waiting rule, skipping."
  else
    cat >> "$WAYBAR_STYLE" <<'CSSEOF'

#custom-screenrecording-indicator.teleprompter-waiting {
  color: #f5a97f;
}
CSSEOF
    echo "  -> Added teleprompter waiting-state styling"
  fi
fi

# 5. Restart waybar to pick up the changes.
omarchy-restart-waybar 2>/dev/null || true

echo "[teleprompter] Done."
echo ""
echo "  Super + Alt + P   Toggle teleprompter recording (binding lives in dotfiles)"
echo "  Waybar icon       cyan monitor = teleprompter, orange monitor = waiting to auto-resume,"
echo "                    red dot = normal recording; click to stop"
