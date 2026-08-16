#!/bin/bash

# Enable the DisplayLink service used by the Elgato Prompter. The recording
# hotkey and wf-recorder helper live in dotfiles.
#
# The bar indicator is a Quattro shell plugin: shell/indicators/ScreenRecording.qml
# overrides Omarchy's stock indicator so a wf-recorder (teleprompter) capture
# stays distinguishable from a gpu-screen-recorder one.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[teleprompter] Setting up DisplayLink for teleprompter recording..."

if ! omarchy pkg present displaylink; then
  echo "[teleprompter] displaylink is missing. Run install-packages.sh first."
  exit 1
fi

# Omarchy has no generic service wrapper for third-party services.
sudo systemctl enable --now displaylink.service

# Overrides the stock ScreenRecording indicator rather than adding a new one, so
# the bar keeps a single recording glyph and no registration is needed.
"$SCRIPT_DIR/shell/install-shell-indicator.sh" "$SCRIPT_DIR/shell/indicators/ScreenRecording.qml"

echo "[teleprompter] Done. Super + Alt + P toggles teleprompter recording."
