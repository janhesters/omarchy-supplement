#!/bin/bash

# Install the native Omarchy shell plugin for Taskwarrior tasks.

set -euo pipefail

PLUGIN_ID="io.github.janhesters.tasks"
PLUGIN_URL="https://github.com/janhesters/omarchy-tasks.git"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

echo "[tasks] Setting up the Taskwarrior shell plugin..."

omarchy pkg add task taskwarrior-tui

if [[ -d $PLUGIN_DIR/.git ]]; then
  echo "[tasks] Updating the installed plugin."
  omarchy plugin update "$PLUGIN_ID" --yes
elif [[ -d $PLUGIN_DIR ]]; then
  echo "[tasks] Using the locally installed plugin."
  omarchy plugin validate "$PLUGIN_DIR"
  omarchy-shell shell rescanPlugins
else
  omarchy plugin add "$PLUGIN_URL" --enable --yes
fi

for _ in {1..40}; do
  if omarchy plugin list --json | jq -e --arg id "$PLUGIN_ID" 'any(.[]; .id == $id)' >/dev/null; then
    break
  fi
  sleep 0.05
done

omarchy plugin enable "$PLUGIN_ID"
if omarchy plugin list --json | jq -e 'any(.[]; .id == "io.github.janhesters.focus" and .enabled)' >/dev/null; then
  omarchy bar move "$PLUGIN_ID" --section center --before io.github.janhesters.focus
else
  omarchy bar move "$PLUGIN_ID" --section center --before omarchy.system-update
fi

echo "[tasks] Done."
