#!/bin/bash

# Install hunspell dictionaries for English and German spell checking.
#
# Chromium/Electron apps (Brave, Slack, Signal) manage their own spellcheck
# dictionaries via app settings — they do NOT use system hunspell. Configure
# spellcheck languages in each app's preferences:
#   - Brave:  brave://settings/languages
#   - Slack:  Preferences > Language & region
#   - Signal: Right-click text field > Spelling
#
# System hunspell is still useful for other apps (LibreOffice, GTK editors).
#
# NOTE: Do NOT set the LANGUAGE environment variable for spellcheck — it
# changes the UI language of CLI tools (git, pacman, etc.) to German.

set -e

# Clean up the old LANGUAGE env var approach which broke CLI tool locales
ENV_FILE="$HOME/.config/environment.d/language.conf"
if [[ -f "$ENV_FILE" ]] && grep -q 'LANGUAGE=.*de' "$ENV_FILE"; then
  rm "$ENV_FILE"
  echo "[spellcheck] Removed $ENV_FILE (was breaking CLI locale)."
fi

echo "[spellcheck] Installing hunspell dictionaries..."

omarchy-pkg-add hunspell-en_us hunspell-de

echo "[spellcheck] Done."
