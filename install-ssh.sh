#!/bin/bash

echo "[ssh] Setting up SSH key..."

if [ -f "$HOME/.ssh/id_ed25519" ]; then
  echo "[ssh] SSH key already exists, skipping generation."
else
  ssh-keygen -t ed25519 -N "" -C "jan@omarchy"
fi

echo ""
echo "Your public key:"
echo ""
cat "$HOME/.ssh/id_ed25519.pub"
echo ""
read -rp "Add this key to GitHub (https://github.com/settings/keys), then press Enter to continue..."

echo "[ssh] Verifying GitHub access..."
ssh -T git@github.com 2>&1 || true

echo "[ssh] Done."
