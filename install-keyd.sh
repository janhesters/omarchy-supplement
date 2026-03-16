#!/bin/bash

set -e

echo "[keyd] Configuring key remapping..."

sudo mkdir -p /etc/keyd
sudo tee /etc/keyd/default.conf > /dev/null << 'EOF'
[ids]
*

[main]
# Tap Caps Lock → Escape (exactly what you wanted!)
# Hold Caps Lock → Ctrl (super useful bonus)
capslock = overload(control, esc)

# Remap the physical Esc key to Pause so we can use it for compose
esc = pause
EOF

echo "[keyd] Enabling and starting keyd service..."
sudo systemctl enable --now keyd
sudo systemctl restart keyd

echo "[keyd] Done."
