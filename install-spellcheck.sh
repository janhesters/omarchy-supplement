#!/bin/bash

# Add German (de) spell checking alongside English in Electron apps
# (Signal, Slack, Brave, etc.).
#
# Electron/Chromium on Linux reads the LANGUAGE environment variable to
# determine which spell-check dictionaries to load. Setting it via
# environment.d makes it persistent across reboots and available to all
# apps launched in the systemd user session.

set -e

ENV_DIR="$HOME/.config/environment.d"
ENV_FILE="$ENV_DIR/language.conf"

echo "[spellcheck] Configuring spell check languages..."

mkdir -p "$ENV_DIR"

if [[ -f "$ENV_FILE" ]] && grep -q 'LANGUAGE=.*de' "$ENV_FILE"; then
  echo "  -> LANGUAGE already includes de, skipping."
else
  echo "LANGUAGE=en_US:de" > "$ENV_FILE"
  echo "  -> Set LANGUAGE=en_US:de in $ENV_FILE"
fi

echo "[spellcheck] Done. Log out and back in for changes to take effect."
