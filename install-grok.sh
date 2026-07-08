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

GROK_DIR="$HOME/.grok"
AGENTS_MD="$HOME/.agents/AGENTS.md"
CONFIG_TOML="$GROK_DIR/config.toml"
mkdir -p "$GROK_DIR"

# Global instructions: symlink to the shared ~/.agents/AGENTS.md body
if [[ -f "$AGENTS_MD" || -L "$AGENTS_MD" ]]; then
  ln -sfn ../.agents/AGENTS.md "$GROK_DIR/AGENTS.md"
  echo "[grok] $GROK_DIR/AGENTS.md -> ../.agents/AGENTS.md"
else
  echo "[grok] WARNING: $AGENTS_MD missing — skip AGENTS.md link. Run install-dotfiles.sh / install-claude.sh first."
fi

# Permission mode: "auto" (classifier) — not always-approve/yolo.
# Merge into existing config.toml without clobbering other keys.
echo "[grok] Ensuring permission_mode = auto..."
if [[ ! -f "$CONFIG_TOML" ]]; then
  cat > "$CONFIG_TOML" << 'EOF'
[ui]
permission_mode = "auto"
EOF
  echo "[grok] Created $CONFIG_TOML with permission_mode = auto."
elif grep -qE '^\s*permission_mode\s*=' "$CONFIG_TOML"; then
  # Replace any existing permission_mode assignment
  sed -i 's/^\s*permission_mode\s*=.*/permission_mode = "auto"/' "$CONFIG_TOML"
  echo "[grok] Updated permission_mode to auto in $CONFIG_TOML."
elif grep -qE '^\s*\[ui\]' "$CONFIG_TOML"; then
  # Insert under the first [ui] section
  sed -i '/^\s*\[ui\]/a permission_mode = "auto"' "$CONFIG_TOML"
  echo "[grok] Added permission_mode = auto under [ui] in $CONFIG_TOML."
else
  printf '\n[ui]\npermission_mode = "auto"\n' >> "$CONFIG_TOML"
  echo "[grok] Appended [ui] permission_mode = auto to $CONFIG_TOML."
fi

# Prefer permission_mode over legacy yolo flag when both exist
if grep -qE '^\s*yolo\s*=' "$CONFIG_TOML"; then
  sed -i 's/^\s*yolo\s*=.*/yolo = false/' "$CONFIG_TOML"
fi

echo "[grok] Done. Run 'grok' once to sign in via browser OAuth (SuperGrok / X Premium+ account)."
