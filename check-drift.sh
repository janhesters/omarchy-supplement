#!/bin/bash

# Compare saved template snapshots against the installed Quattro templates.
# Omarchy owns /usr/share/omarchy; this script only reads from it.

set -euo pipefail

SNAPSHOT_DIR="$HOME/.local/state/dotfiles/omarchy-templates"
OMARCHY_CONFIG="${OMARCHY_PATH:-/usr/share/omarchy}/config"
DRIFTED=0

if [[ ! -d "$SNAPSHOT_DIR" ]]; then
  echo "No template snapshots found. Run install-dotfiles.sh first."
  exit 1
fi

echo "Checking for Omarchy template drift..."

while IFS= read -r -d '' snapshot; do
  relative=${snapshot#"$SNAPSHOT_DIR/"}
  current="$OMARCHY_CONFIG/$relative"

  if [[ ! -f "$current" ]]; then
    echo "  REMOVED: $relative (template no longer exists in Omarchy)"
    DRIFTED=1
  elif ! diff -q "$snapshot" "$current" &>/dev/null; then
    echo "  CHANGED: $relative"
    diff -u "$snapshot" "$current" \
      --label "snapshot (at install time)" \
      --label "current (Omarchy)" | head -30 || true
    DRIFTED=1
  fi
done < <(find "$SNAPSHOT_DIR" -type f -print0 | sort -z)

if ((DRIFTED == 0)); then
  echo "  No drift detected. All Omarchy templates match the snapshots."
else
  echo "Templates changed. Review the diffs and update the dotfiles when needed."
  echo "After updating, run install-dotfiles.sh again to refresh the snapshots."
fi
