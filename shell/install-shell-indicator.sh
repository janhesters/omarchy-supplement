#!/bin/bash

# Install a custom indicator into the Omarchy 4 shell bar.
#
# Omarchy 4 replaced waybar with a Quickshell-based shell. Bar indicators are
# QML files loaded by the `omarchy.indicators` widget from its own plugin
# directory, so a custom indicator means owning a clone of that plugin -- the
# packaged copy under /usr/share/omarchy is overwritten on every update.
#
# Usage:
#   install-shell-indicator.sh <path-to-qml> [--register]
#
# --register also adds the indicator to the plugin manifest (so it shows up in
# the shell settings UI) and to the bar widget's item list (so it is actually
# rendered). Overrides of stock indicators -- e.g. ScreenRecording.qml -- do not
# need it, since they replace an id the bar already draws.

set -euo pipefail

SOURCE_QML="${1:-}"
REGISTER="${2:-}"

PLUGIN_ID="${USER}.indicators"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SHELL_JSON="$HOME/.config/omarchy/shell.json"

# Mirrors defaultIndicatorEntries in the packaged Indicators.qml. Once a bar
# widget carries an explicit item list it no longer falls back to that default,
# so the stock entries have to be named alongside any custom one.
STOCK_INDICATORS='["Dictation","ScreenRecording","Reminder","NightLight","Dnd","StayAwake"]'

if [ -z "$SOURCE_QML" ] || [ ! -f "$SOURCE_QML" ]; then
  echo "install-shell-indicator: need a readable .qml file (got '${SOURCE_QML:-}')" >&2
  exit 1
fi

INDICATOR_ID="$(basename "$SOURCE_QML" .qml)"

# 1. Own a clone of the indicators plugin.
if [ ! -d "$PLUGIN_DIR" ]; then
  echo "  -> Cloning omarchy.indicators to $PLUGIN_ID"
  omarchy plugin clone omarchy.indicators >/dev/null
fi

if [ ! -d "$PLUGIN_DIR/indicators" ]; then
  echo "install-shell-indicator: $PLUGIN_DIR/indicators is missing; clone looks incomplete" >&2
  exit 1
fi

# 2. Drop the indicator in. Saving under ~/.config/omarchy/plugins reloads it.
install -m 644 "$SOURCE_QML" "$PLUGIN_DIR/indicators/$INDICATOR_ID.qml"
echo "  -> Installed $INDICATOR_ID indicator into $PLUGIN_ID"

[ "$REGISTER" = "--register" ] || exit 0

# 3. Offer it in the shell settings UI.
python3 - "$PLUGIN_DIR/manifest.json" "$INDICATOR_ID" <<'PY'
import json, sys

path, indicator = sys.argv[1], sys.argv[2]
with open(path) as fh:
    manifest = json.load(fh)

for field in manifest.get("barWidget", {}).get("schema", []):
    if field.get("key") != "items":
        continue
    options = field.setdefault("options", [])
    if any(option.get("value") == indicator for option in options):
        print(f"  -> {indicator} already offered in settings, skipping.")
        break
    options.append({
        "value": indicator,
        "label": indicator,
        "description": f"{indicator} status",
    })
    with open(path, "w") as fh:
        json.dump(manifest, fh, indent=2)
        fh.write("\n")
    print(f"  -> Registered {indicator} in the plugin manifest")
    break
PY

# 4. Make the bar actually draw it.
python3 - "$SHELL_JSON" "$PLUGIN_ID" "$INDICATOR_ID" "$STOCK_INDICATORS" <<'PY'
import json, sys

path, plugin_id, indicator, stock = sys.argv[1], sys.argv[2], sys.argv[3], json.loads(sys.argv[4])
with open(path) as fh:
    config = json.load(fh)

widgets = [
    widget
    for section in config.get("bar", {}).get("layout", {}).values()
    if isinstance(section, list)
    for widget in section
    if isinstance(widget, dict) and widget.get("id") in (plugin_id, "omarchy.indicators")
]

if not widgets:
    print(f"  -> No indicators widget in the bar layout; add one to show {indicator}.")
    sys.exit(0)

changed = False
for widget in widgets:
    items = widget.get("items") or list(stock)
    if indicator in items:
        continue
    items.append(indicator)
    widget["items"] = items
    changed = True

if not changed:
    print(f"  -> Bar already shows {indicator}, skipping.")
    sys.exit(0)

with open(path, "w") as fh:
    json.dump(config, fh, indent=2)
    fh.write("\n")
print(f"  -> Added {indicator} to the bar indicators")
PY
