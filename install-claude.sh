#!/bin/bash

set -e

echo "[claude] Configuring Claude Code..."

CLAUDE_DIR="$HOME/.claude"
CODEX_DIR="$HOME/.codex"
AGENTS_DIR="$HOME/.agents"
AGENTS_MD="$AGENTS_DIR/AGENTS.md"
DOTFILES_AGENTS="$HOME/dev/dotfiles/agents/.agents/AGENTS.md"

mkdir -p "$CLAUDE_DIR" "$CODEX_DIR" "$AGENTS_DIR"

# Settings: disable co-authorship attribution, enable notification hook
echo "[claude] Setting up settings.json..."
cat > "$CLAUDE_DIR/settings.json" << 'EOF'
{
  "permissions": {
    "defaultMode": "auto"
  },
  "attribution": {
    "commit": "",
    "pr": ""
  },
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/home/jan/.claude/hooks/notify.sh"
          }
        ]
      }
    ]
  }
}
EOF

# Notification hook script
echo "[claude] Setting up notification hook..."
mkdir -p "$CLAUDE_DIR/hooks"
cat > "$CLAUDE_DIR/hooks/notify.sh" << 'HOOKEOF'
#!/bin/bash
INPUT=$(cat)
DIR=$(echo "$INPUT" | jq -r '.cwd // "unknown"' | xargs basename)
MSG=$(echo "$INPUT" | jq -r '.message // "Ready for your input"' | head -c 200)
notify-send "Claude Code — $DIR" "$MSG"
HOOKEOF
chmod +x "$CLAUDE_DIR/hooks/notify.sh"

# System-wide instructions: one body at ~/.agents/AGENTS.md; tool names are symlinks.
# Prefer the stowed file from the dotfiles agents package; fall back to copying from the repo.
echo "[claude] Linking global agent instructions..."
if [[ ! -f "$AGENTS_MD" && ! -L "$AGENTS_MD" ]]; then
  if [[ -f "$DOTFILES_AGENTS" ]]; then
    cp "$DOTFILES_AGENTS" "$AGENTS_MD"
    echo "[claude] Seeded $AGENTS_MD from dotfiles agents package."
  else
    echo "[claude] WARNING: $AGENTS_MD missing and $DOTFILES_AGENTS not found."
    echo "[claude] Run install-dotfiles.sh (with the agents package) first, or create the file manually."
  fi
fi

link_to_agents() {
  local target="$1"
  local dir
  dir="$(dirname "$target")"
  mkdir -p "$dir"
  # Relative target from ~/.claude or ~/.codex -> ~/.agents/AGENTS.md
  ln -sfn ../.agents/AGENTS.md "$target"
}

if [[ -f "$AGENTS_MD" || -L "$AGENTS_MD" ]]; then
  link_to_agents "$CLAUDE_DIR/CLAUDE.md"
  link_to_agents "$CODEX_DIR/AGENTS.md"
  echo "[claude] $CLAUDE_DIR/CLAUDE.md -> ../.agents/AGENTS.md"
  echo "[codex] $CODEX_DIR/AGENTS.md -> ../.agents/AGENTS.md"
fi

echo "[claude] Done."
