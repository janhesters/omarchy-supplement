#!/bin/bash

set -e

echo "[packages] Installing packages..."

# Official repo packages
echo "[packages] Installing from official repos..."
omarchy-pkg-add stow bun ddcutil keyd voxtype fcitx5-chinese-addons

# AUR packages
echo "[packages] Installing from AUR..."
omarchy-pkg-aur-add brave-bin

echo "[packages] Done."
