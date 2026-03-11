#!/bin/bash

# Run all install scripts in order.
# Each script is idempotent and safe to re-run.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== omarchy-supplement: full setup ==="
echo ""

"$SCRIPT_DIR/install-ssh.sh"
"$SCRIPT_DIR/install-packages.sh"
"$SCRIPT_DIR/install-keyd.sh"
"$SCRIPT_DIR/install-ddcutil.sh"
"$SCRIPT_DIR/install-keyboard-layout.sh"
"$SCRIPT_DIR/install-webapps.sh"
"$SCRIPT_DIR/install-dotfiles.sh"
"$SCRIPT_DIR/install-themes.sh"
"$SCRIPT_DIR/install-repos.sh"
"$SCRIPT_DIR/set-default-browser.sh"
"$SCRIPT_DIR/install-spellcheck.sh"

echo ""
echo "=== All done! ==="
