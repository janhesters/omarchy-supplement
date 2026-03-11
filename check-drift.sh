#!/bin/bash

# Compare saved omarchy template snapshots against current omarchy templates.
# If they differ, omarchy has updated a template that our dotfiles override,
# and we should review the changes and update our dotfiles accordingly.

SNAPSHOT_DIR="$HOME/.local/state/dotfiles/omarchy-templates"
OMARCHY_CONFIG="$HOME/.local/share/omarchy/config"
DRIFTED=0

if [ ! -d "$SNAPSHOT_DIR" ]; then
  echo "No template snapshots found. Run install-dotfiles.sh first."
  exit 1
fi

echo "Checking for omarchy template drift..."
echo ""

for snapshot in $(find "$SNAPSHOT_DIR" -type f | sort); do
  relative="${snapshot#$SNAPSHOT_DIR/}"
  current="$OMARCHY_CONFIG/$relative"

  if [ ! -f "$current" ]; then
    echo "  REMOVED: $relative (template no longer exists in omarchy)"
    DRIFTED=1
  elif ! diff -q "$snapshot" "$current" &>/dev/null; then
    echo "  CHANGED: $relative"
    diff -u "$snapshot" "$current" --label "snapshot (at install time)" --label "current (omarchy)" | head -30
    echo ""
    DRIFTED=1
  fi
done

if [ "$DRIFTED" -eq 0 ]; then
  echo "  No drift detected. All omarchy templates match your snapshots."
else
  echo ""
  echo "Templates have changed. Review the diffs above and update your dotfiles if needed."
  echo "After updating, re-run install-dotfiles.sh to refresh the snapshots."
fi
