#!/bin/bash

set -euo pipefail

terminal_list="$HOME/.config/xdg-terminals.list"

# Older dotfiles revisions stowed this shared state file. Unlink that selector
# before asking Omarchy to write it, or a default change would edit the repo.
if [[ -L "$terminal_list" ]]; then
  backup="$HOME/.local/state/dotfiles/backups/xdg-terminals-list-$(date +%Y%m%d%H%M%S)-$$"
  mkdir -p "$(dirname "$backup")"
  printf '%s\n' "$(readlink -- "$terminal_list")" >"$backup.link-target"
  if [[ -f $terminal_list ]]; then
    cp -L --preserve=mode,timestamps "$terminal_list" "$backup"
  fi
  rm -f "$terminal_list"
  echo "[terminal] Archived the old Stow selector under $backup"
fi

echo "[terminal] Setting Alacritty as default terminal..."
omarchy default terminal alacritty
if [[ $(omarchy default terminal) != "alacritty" ]]; then
  echo "[terminal] Error: Alacritty did not become the default terminal." >&2
  exit 1
fi
echo "[terminal] Done."
