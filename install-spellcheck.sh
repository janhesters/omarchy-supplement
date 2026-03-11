#!/bin/bash

# Add German (de) spell checking alongside English in Electron apps.
#
# Signal and Brave use Chromium's built-in spell checker, which downloads
# .bdic dictionaries independently of the system's hunspell. The language
# list is stored in each app's Preferences JSON file.
#
# Apps must be restarted after running this script for changes to take effect.

set -e

SIGNAL_PREFS="$HOME/.config/Signal/Preferences"
BRAVE_PREFS="$HOME/.config/BraveSoftware/Brave-Browser/Default/Preferences"

add_dictionary() {
  local prefs_file="$1"
  local app_name="$2"
  local lang="$3"

  if [ ! -f "$prefs_file" ]; then
    echo "  -> $app_name preferences not found, skipping (install $app_name first)."
    return
  fi

  if python3 -c "
import json, sys
p = json.load(open('$prefs_file'))
d = p.get('spellcheck', {}).get('dictionaries', [])
if '$lang' in d:
    sys.exit(1)
" 2>/dev/null; then
    python3 -c "
import json
p = json.load(open('$prefs_file'))
d = p.setdefault('spellcheck', {}).setdefault('dictionaries', [])
d.append('$lang')
json.dump(p, open('$prefs_file', 'w'))
"
    echo "  -> Added $lang to $app_name spell check."
  else
    echo "  -> $app_name already has $lang, skipping."
  fi
}

echo "[spellcheck] Configuring spell check languages..."

add_dictionary "$SIGNAL_PREFS" "Signal" "de"
add_dictionary "$BRAVE_PREFS" "Brave" "de"

echo "[spellcheck] Done. Restart Signal and Brave for changes to take effect."
