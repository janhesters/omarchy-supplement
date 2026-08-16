#!/bin/bash

# Enable the DisplayLink service used by the Elgato Prompter. The recording
# hotkey and wf-recorder helper live in dotfiles. A Quattro shell indicator will
# live in a separate plugin; this script does not modify Omarchy's bar.

set -euo pipefail

echo "[teleprompter] Setting up DisplayLink for teleprompter recording..."

if ! omarchy pkg present displaylink; then
  echo "[teleprompter] displaylink is missing. Run install-packages.sh first."
  exit 1
fi

# Omarchy has no generic service wrapper for third-party services.
sudo systemctl enable --now displaylink.service

echo "[teleprompter] Done. Super + Alt + P toggles teleprompter recording."
