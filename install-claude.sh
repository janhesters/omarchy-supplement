#!/bin/bash

set -e

echo "[claude] Configuring Claude Code..."

CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"

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

# System-wide instructions for Claude Code
echo "[claude] Setting up CLAUDE.md..."
cat > "$CLAUDE_DIR/CLAUDE.md" << 'CLAUDEEOF'
# System-Wide Instructions

## Asking Questions

When unsure about the user's intent, constraints, or the best approach, ask clarifying questions rather than guessing. This applies both before starting work (e.g., before researching, fetching, or writing code) and after gathering information (e.g., when findings are ambiguous or multiple paths are viable). Prefer a short question over a wrong assumption.

## Omarchy

Omarchy wraps system tools with its own commands. Always use `omarchy` wrappers — never call underlying tools (systemctl, systemd-run, notify-send, pacman, yay, etc.) directly. Discover available commands with `omarchy commands`.

OmarchyConstraints {
  Never use underlying tools directly when an `omarchy` command exists.
  Never edit files in `~/.local/share/omarchy/` — always override in `~/.config/`.
}

OmarchyPackageManagement {
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

## Mise

Bun (and potentially other dev tools) are managed via [mise](https://mise.jdx.dev/). To upgrade:
- `mise upgrade bun` — upgrade bun to latest
- `mise install bun@latest && mise use -g bun@latest` — install and set a specific version globally

Do not use `bun upgrade` or system package managers for bun.

## Calendar

constraint CalendarEvents {
  create_event silently drops `location` — after creating, get_event to verify it stuck; if missing, set via update_event.
  Use a full geocodable address (street, postal code, city, country).
}

## Gmail

constraint ThreadReads {
  search_threads returns only a partial subset of a thread's messages — never treat it as the full thread.
  To read or summarize a thread => get_thread(threadId) for the complete message list.
}

## Todos

Personal todos live in **Taskwarrior** (`task` CLI; `taskwarrior-tui` for an interactive board). Drive everything through the `task` command — never hand-edit `~/.task/`.

Tasks {
  add(desc, priority?, due?, project?, tags?) => `task add "$desc" [priority:H|M|L] [due:$date] [project:$project] [+$tag]`
  list   => `task next`        // urgency-ranked view
  done(id)   => `task $id done`
  drop(id)   => `task $id delete`
  edit(id, …)=> `task $id modify …`

  Priority ∈ { H, M, L, none }.
  due accepts natural forms: due:today, due:tomorrow, due:friday, due:eod, due:2026-06-25.
  Ranking in `task next` = computed urgency (priority + due + age + tags), not a manual sort.
}

constraint TodoIntake {
  Never guess priority or deadline — ask.
  If an item's meaning is ambiguous or underspecified (e.g. a terse label like "Post checken"), ask what it refers to before adding, so the stored task is self-explanatory later.
  On a pasted batch: ask once (batched, not item-by-item spam) for each item's priority (H/M/L/none) and whether it has a deadline/delivery time + when, vs. a plain "need to do this". Only fall back to no-priority/no-due after the user declines.
  On a single later add: ask where it sits in the priority order — capture as priority level, and when finer ranking is needed set a `due` date to position it relative to neighbours.
  After any change, show the resulting `task next` so the user sees the new ranking.
}

## Personal Repos

- **`~/dev/dotfiles`** — GNU Stow packages for config file overrides (`~/.config/hypr/`, `~/.config/espanso/`, etc.). Use for files that can be fully owned by the user and symlinked into `~/.config/`. Not suitable for shared files like `mimeapps.list` that other tools also write to.
- **`~/dev/omarchy-supplement`** — Idempotent install scripts for post-Omarchy setup (packages, key remapping, default apps, web apps, themes, etc.). Use for imperative actions like `xdg-mime default`, package installs, or anything that modifies shared system state.
CLAUDEEOF

echo "[claude] Done."
