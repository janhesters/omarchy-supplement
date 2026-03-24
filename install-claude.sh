#!/bin/bash

set -e

echo "[claude] Configuring Claude Code..."

CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"

# Settings: disable co-authorship attribution, enable notification hook
echo "[claude] Setting up settings.json..."
cat > "$CLAUDE_DIR/settings.json" << 'EOF'
{
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

# System-wide instructions for Claude Code
echo "[claude] Setting up CLAUDE.md..."
cat > "$CLAUDE_DIR/CLAUDE.md" << 'CLAUDEEOF'
# System-Wide Instructions

## Omarchy

OmarchyPackageManagement {
  Constraints {
    Never use `pacman -S` or `yay -S` directly to install packages.
    Never edit files in `~/.local/share/omarchy/` — always override in `~/.config/`.
    Omarchy wraps package management with its own commands that ensure consistency across updates.
  }

  install(package) => match (package) {
    case (official Arch repo) => `omarchy-pkg-add <package>`
    case (AUR) => `omarchy-pkg-aur-add <package>`
    case (interactive browsing) => `omarchy-pkg-install`
  }

  remove(package) => `omarchy-pkg-drop <package>`

  check(package) => match (intent) {
    case (is it missing?) => `omarchy-pkg-missing <package>`
    case (is it present?) => `omarchy-pkg-present <package>`
  }
}
CLAUDEEOF

echo "[claude] Done."
