#!/bin/bash

set -euo pipefail

echo "[packages] Installing packages..."

# Official repo packages
echo "[packages] Installing from official repos..."
omarchy pkg add stow ddcutil keyd voxtype socat task taskwarrior-tui wf-recorder

# AUR packages
echo "[packages] Installing from AUR..."
omarchy pkg aur add brave-bin slack-desktop-wayland espanso-wayland evdi-dkms displaylink

# Omarchy manages development runtimes through mise. Keep Bun out of the
# system package transaction so upgrades remain under mise's control.
echo "[packages] Installing Bun through mise..."
mise install bun@latest
mise use -g bun@latest

echo "[packages] Done."
