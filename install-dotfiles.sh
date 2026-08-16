#!/bin/bash

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dev/dotfiles}"
DOTFILES_REPO="git@github.com:janhesters/dotfiles.git"
# agents first so ~/.agents/AGENTS.md exists before claude/codex/grok symlinks
STOW_PACKAGES=(agents claude codex grok cursor hyprland fastfetch voxtype xcompose espanso wireplumber)
SNAPSHOT_DIR="$HOME/.local/state/dotfiles/omarchy-templates"
OMARCHY_CONFIG="${OMARCHY_PATH:-/usr/share/omarchy}/config"
TIMESTAMP="$(date +%Y%m%d%H%M%S)-$$"
BACKUP_DIR="$HOME/.local/state/dotfiles/backups/$TIMESTAMP"
backup_created=0

# Quattro templates replaced by personal Lua modules. Other files in the Stow
# packages have no matching Omarchy template and therefore need no drift copy.
TEMPLATE_FILES=(
  hypr/autostart.lua
  hypr/bindings.lua
  hypr/hyprsunset.conf
  hypr/input.lua
  hypr/monitors.lua
)

# Omarchy 3 overrides are inert under Quattro. Archive them so the live config
# contains one clear source of truth.
LEGACY_FILES=(
  .config/hypr/autostart.conf
  .config/hypr/bindings.conf
  .config/hypr/input.conf
  .config/hypr/looknfeel.conf
  .config/hypr/monitors.conf
  .config/espanso/config/default.yml
)

REQUIRED_DOTFILES=(
  hyprland/.config/hypr/autostart.lua
  hyprland/.config/hypr/bindings.lua
  hyprland/.config/hypr/input.lua
  hyprland/.config/hypr/monitors.lua
  hyprland/.config/hypr/scripts/espanso-layout-sync
  espanso/.config/espanso/profiles/dvorak.yml
  espanso/.config/espanso/profiles/qwerty.yml
)

ensure_backup_dir() {
  if ((backup_created == 0)); then
    mkdir -p "$BACKUP_DIR"
    backup_created=1
  fi
}

backup_target() {
  local relative=$1
  local source=${2:-}
  local destination="$HOME/$relative"
  local ancestor link_target resolved_link resolved_source

  # Never inspect, copy, or remove a leaf through a symlinked directory. The
  # preceding Stow delete pass deliberately unfolds package-owned directories;
  # anything remaining here belongs to another owner and needs manual review.
  ancestor=$(dirname "$destination")
  while [[ $ancestor != "$HOME" && $ancestor != / ]]; do
    if [[ -L "$ancestor" ]]; then
      echo "[dotfiles] Error: refusing to replace $destination through symlinked parent $ancestor"
      exit 1
    fi
    ancestor=$(dirname "$ancestor")
  done

  [[ -e "$destination" || -L "$destination" ]] || return 0

  # A link is already correct only when its immediate target resolves to this
  # exact package source. Do not treat an arbitrary link into the repo as owned.
  if [[ -n $source && -L "$destination" ]]; then
    link_target=$(readlink -- "$destination")
    resolved_link=$(realpath -sm -- "$(dirname "$destination")/$link_target")
    resolved_source=$(realpath -sm -- "$source")
    if [[ $resolved_link == "$resolved_source" ]]; then
      return 0
    fi
  fi

  ensure_backup_dir
  mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
  cp -a -- "$destination" "$BACKUP_DIR/$relative"
  rm -f -- "$destination"
  echo "  -> Backed up $relative"
}

echo "[dotfiles] Setting up Quattro dotfiles..."

if ! omarchy pkg present stow; then
  echo "[dotfiles] Error: stow is not installed. Run install-packages.sh first."
  exit 1
fi

# Clone if not present.
if [[ -d "$DOTFILES_DIR" ]]; then
  echo "[dotfiles] Repository already exists at $DOTFILES_DIR, skipping clone."
else
  echo "[dotfiles] Cloning dotfiles..."
  mkdir -p "$HOME/dev"
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# Fail before changing live state if the two compatibility PRs were applied out
# of order or the configured path is not the expected Quattro dotfiles tree.
if ! git -C "$DOTFILES_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
  echo "[dotfiles] Error: $DOTFILES_DIR is not a Git checkout."
  exit 1
fi

for package in "${STOW_PACKAGES[@]}"; do
  if [[ ! -d "$DOTFILES_DIR/$package" ]]; then
    echo "[dotfiles] Error: required Stow package '$package' is missing from $DOTFILES_DIR."
    exit 1
  fi
done

for file in "${REQUIRED_DOTFILES[@]}"; do
  if [[ ! -f "$DOTFILES_DIR/$file" ]]; then
    echo "[dotfiles] Error: missing Quattro artifact $file. Update the dotfiles checkout first."
    exit 1
  fi
done

if [[ ! -x "$DOTFILES_DIR/hyprland/.config/hypr/scripts/espanso-layout-sync" ]]; then
  echo "[dotfiles] Error: the Espanso layout-sync helper is not executable."
  exit 1
fi

for command in git find realpath stow hyprctl; do
  if ! command -v "$command" &>/dev/null; then
    echo "[dotfiles] Error: required command '$command' is unavailable."
    exit 1
  fi
done

if command -v espanso &>/dev/null; then
  for command in flock jq socat uwsm-app; do
    if ! command -v "$command" &>/dev/null; then
      echo "[dotfiles] Error: $command is required for Espanso layout synchronization."
      exit 1
    fi
  done
fi

if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || ! hyprctl monitors &>/dev/null; then
  echo "[dotfiles] Error: run this installer from an active Omarchy desktop session."
  exit 1
fi

if [[ ! -d "$OMARCHY_CONFIG" ]]; then
  echo "[dotfiles] Error: Omarchy's config templates were not found at $OMARCHY_CONFIG."
  exit 1
fi

for file in "${TEMPLATE_FILES[@]}"; do
  if [[ ! -f "$OMARCHY_CONFIG/$file" ]]; then
    echo "[dotfiles] Error: required Omarchy template $file is missing."
    exit 1
  fi
done

# Replace the previous snapshot set instead of mixing Omarchy 3 .conf files
# with Quattro's Lua templates. The previous set remains recoverable.
echo "[dotfiles] Saving Quattro template snapshots..."
if [[ -d "$SNAPSHOT_DIR" ]]; then
  ensure_backup_dir
  mv "$SNAPSHOT_DIR" "$BACKUP_DIR/omarchy-templates"
fi
mkdir -p "$SNAPSHOT_DIR"

for file in "${TEMPLATE_FILES[@]}"; do
  mkdir -p "$SNAPSHOT_DIR/$(dirname "$file")"
  cp "$OMARCHY_CONFIG/$file" "$SNAPSHOT_DIR/$file"
done

# Remove links and directory folds owned by earlier Stow runs. This leaves
# ordinary user files in place for the backup pass, then --no-folding ensures
# Espanso's mutable selector can never be written through into the repository.
echo "[dotfiles] Unstowing previous package links..."
for package in "${STOW_PACKAGES[@]}"; do
  stow --delete --dir "$DOTFILES_DIR" --target "$HOME" "$package"
done

# Back up every existing destination owned by a Stow package. Files already
# linked into this checkout are left alone, which keeps repeated runs clean.
echo "[dotfiles] Backing up existing managed files..."
for package in "${STOW_PACKAGES[@]}"; do
  while IFS= read -r -d '' source; do
    relative=${source#"$DOTFILES_DIR/$package/"}
    backup_target "$relative" "$source"
  done < <(find "$DOTFILES_DIR/$package" \( -type f -o -type l \) -print0)
done

for relative in "${LEGACY_FILES[@]}"; do
  backup_target "$relative"
done

echo "[dotfiles] Stowing packages..."
for package in "${STOW_PACKAGES[@]}"; do
  echo "  -> stow $package"
  stow --no-folding --dir "$DOTFILES_DIR" --target "$HOME" "$package"
done

echo "[dotfiles] Reloading Quattro configuration..."
omarchy restart hyprctl

config_errors=$(hyprctl configerrors)
if [[ -n ${config_errors//[[:space:]]/} ]]; then
  echo "[dotfiles] Hyprland reported configuration errors:"
  printf '%s\n' "$config_errors"
  exit 1
fi

omarchy restart xcompose
omarchy restart hyprsunset

if command -v espanso &>/dev/null; then
  layout_sync="$HOME/.config/hypr/scripts/espanso-layout-sync"
  if [[ ! -x $layout_sync ]]; then
    echo "[dotfiles] Error: $layout_sync is missing or not executable."
    exit 1
  fi
  echo "[dotfiles] Selecting the active Espanso layout profile..."
  if ! espanso service check &>/dev/null; then
    espanso service register
  fi
  "$layout_sync" --once
  if ! espanso service status &>/dev/null; then
    espanso service start
    "$layout_sync" --once
  fi

  printf -v launch_cmd 'uwsm-app -- %q' "$layout_sync"
  hyprctl dispatch exec "$launch_cmd" >/dev/null
fi

if ((backup_created)); then
  echo "[dotfiles] Previous files are backed up at $BACKUP_DIR"
fi

echo "[dotfiles] Done."
