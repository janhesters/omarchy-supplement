#!/bin/bash

set -e

echo "[keyd] Configuring key remapping..."

sudo mkdir -p /etc/keyd
sudo tee /etc/keyd/default.conf > /dev/null << 'EOF'
[ids]
*

[main]
capslock = overload(control, esc)
esc = pause
EOF

echo "[keyd] Enabling and starting keyd service..."
sudo systemctl enable --now keyd
sudo systemctl restart keyd

echo "[keyd] Done."
