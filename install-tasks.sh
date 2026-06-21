#!/bin/bash

# Install the omarchy-tasks Waybar module: shows actionable Taskwarrior tasks
# (overdue + due today) in the bar, with upcoming tasks in the tooltip.
# Click it or press Super + T to open taskwarrior-tui.
#
# Requires task + taskwarrior-tui (installed by install-packages.sh).

set -e

REPO_DIR="$HOME/dev/omarchy-tasks"

echo "[tasks] Setting up Taskwarrior waybar module..."

mkdir -p "$HOME/dev"

if [ -d "$REPO_DIR" ]; then
  echo "[tasks] omarchy-tasks already cloned, pulling latest."
  git -C "$REPO_DIR" pull --ff-only || true
else
  git clone git@github.com:janhesters/omarchy-tasks.git "$REPO_DIR"
fi

"$REPO_DIR/install.sh"

echo "[tasks] Done."
