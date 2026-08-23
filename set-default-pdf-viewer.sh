#!/bin/bash

set -euo pipefail

readonly PDF_VIEWER_DESKTOP_ID="org.gnome.Evince.desktop"

echo "[pdf] Setting Document Viewer as default PDF viewer..."
xdg-mime default "$PDF_VIEWER_DESKTOP_ID" application/pdf

if [[ $(xdg-mime query default application/pdf) != "$PDF_VIEWER_DESKTOP_ID" ]]; then
  echo "[pdf] Failed to set Document Viewer as the default PDF viewer." >&2
  exit 1
fi

echo "[pdf] Done."
