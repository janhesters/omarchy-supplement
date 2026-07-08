#!/bin/bash

set -e

echo "[grok] Installing Grok Build CLI..."

# No Omarchy/AUR path: the AUR grok-build package lags the beta's release
# pace, so use the official user-level installer (~/.grok, no root, self-updating).
if [[ -x "$HOME/.grok/bin/grok" ]]; then
  echo "[grok] Already installed ($("$HOME/.grok/bin/grok" --version)). Skipping."
else
  curl -fsSL https://x.ai/cli/install.sh | bash
fi

echo "[grok] Done. Run 'grok' once to sign in via browser OAuth (SuperGrok / X Premium+ account)."
