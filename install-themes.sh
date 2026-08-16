#!/bin/bash

set -euo pipefail

echo "[themes] Installing missing Omarchy themes..."

theme_name_file="$HOME/.local/state/omarchy/current/theme.name"
original_theme=""
restore_needed=0

if [[ -f $theme_name_file ]]; then
  IFS= read -r original_theme <"$theme_name_file"
fi

restore_original_theme() {
  if ((restore_needed)) && [[ -n $original_theme ]]; then
    OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy theme set "$original_theme"
    restore_needed=0
  fi
}

restore_on_exit() {
  local status=$?
  trap - EXIT

  if ((restore_needed)) && [[ -n $original_theme ]]; then
    if ! OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy theme set "$original_theme"; then
      echo "[themes] Error: failed to restore $original_theme." >&2
      ((status == 0)) && status=1
    fi
  fi

  exit "$status"
}

trap restore_on_exit EXIT

install_theme_if_missing() {
  local name=$1
  local repository=$2
  local theme_dir="$HOME/.config/omarchy/themes/$name"

  if [[ -d "$theme_dir" ]]; then
    echo "  -> $name already exists; preserving the local checkout."
  else
    [[ -n $original_theme ]] && restore_needed=1
    OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy theme install "$repository"
  fi
}

install_theme_if_missing ash "https://github.com/bjarneo/omarchy-ash-theme"
install_theme_if_missing ayaka "https://github.com/abhijeet-swami/omarchy-ayaka-theme"
install_theme_if_missing harbordark "https://github.com/HANCORE-linux/omarchy-harbordark-theme.git"
install_theme_if_missing rainynight "https://github.com/atif-1402/omarchy-rainynight-theme"
install_theme_if_missing greek-noir "https://github.com/HANCORE-linux/omarchy-greek-noir-theme.git"
install_theme_if_missing night-owl "https://github.com/janhesters/omarchy-night-owl-theme.git"

restore_original_theme
trap - EXIT

echo "[themes] Done. Current theme: $(omarchy theme current)."
