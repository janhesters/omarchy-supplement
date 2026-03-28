#!/bin/bash

set -e

DOTFILES_DIR="$HOME/dev/dotfiles"
DOTFILES_REPO="git@github.com:janhesters/dotfiles.git"
STOW_PACKAGES=(hyprland fastfetch voxtype xdg xcompose espanso)
SNAPSHOT_DIR="$HOME/.local/state/dotfiles/omarchy-templates"

# Files we override (relative to ~/.config/)
MANAGED_FILES=(
  hypr/autostart.conf
  hypr/bindings.conf
  hypr/hyprsunset.conf
  hypr/input.conf
  hypr/looknfeel.conf
  hypr/monitors.conf
  fastfetch/config.jsonc
  voxtype/config.toml
  xdg-terminals.list
)

echo "[dotfiles] Setting up dotfiles..."

# Clone if not present
if [ -d "$DOTFILES_DIR" ]; then
  echo "[dotfiles] Repository already exists at $DOTFILES_DIR, skipping clone."
else
  echo "[dotfiles] Cloning dotfiles..."
  mkdir -p "$HOME/dev"
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# Snapshot the current omarchy templates before replacing them.
# This lets check-drift.sh detect when omarchy updates a template we override.
echo "[dotfiles] Saving omarchy template snapshots..."
OMARCHY_CONFIG="$HOME/.local/share/omarchy/config"
for file in "${MANAGED_FILES[@]}"; do
  if [ -f "$OMARCHY_CONFIG/$file" ]; then
    mkdir -p "$SNAPSHOT_DIR/$(dirname "$file")"
    cp "$OMARCHY_CONFIG/$file" "$SNAPSHOT_DIR/$file"
  fi
done

# Remove existing config files (omarchy templates) before stowing to avoid conflicts.
# Only remove files that our dotfiles repo manages — files identical to the omarchy
# template (alacritty, hypridle, hyprlock, xdph) are left untouched so they continue
# receiving omarchy updates.
echo "[dotfiles] Removing omarchy templates that we override..."
for file in "${MANAGED_FILES[@]}"; do
  rm -f "$HOME/.config/$file"
done

# Remove ~/.XCompose separately (lives in home root, not ~/.config/)
if [ -f "$HOME/.XCompose" ] || [ -L "$HOME/.XCompose" ]; then
  echo "[dotfiles] Removing existing ~/.XCompose to avoid stow conflict..."
  rm -f "$HOME/.XCompose"
fi

# Stow each package
echo "[dotfiles] Stowing packages..."
cd "$DOTFILES_DIR"
for pkg in "${STOW_PACKAGES[@]}"; do
  echo "  -> stow $pkg"
  stow -t "$HOME" "$pkg"
done

# Reload configs
echo "[dotfiles] Reloading Hyprland and Waybar..."
hyprctl reload 2>/dev/null || true
omarchy-restart-waybar 2>/dev/null || true
omarchy-restart-xcompose 2>/dev/null || true

# Enable espanso text expansion service
if command -v espanso &>/dev/null; then
  echo "[dotfiles] Registering and starting espanso..."
  espanso service register 2>/dev/null || true
  espanso start 2>/dev/null || true
fi

echo "[dotfiles] Done."
