#!/bin/bash

# Make the bar's night-light toggle restore the user's scheduled profile.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$SCRIPT_DIR/shell/install-shell-indicator.sh" "$SCRIPT_DIR/shell/indicators/NightLight.qml"

echo "[nightlight] Bar toggle now restores scheduled color and brightness."
