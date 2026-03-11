#!/bin/bash

set -e

echo "[ddcutil] Setting up DDC/CI for external monitor control..."

sudo modprobe i2c-dev

if [ -f /etc/modules-load.d/i2c-dev.conf ]; then
  echo "[ddcutil] /etc/modules-load.d/i2c-dev.conf already exists, skipping."
else
  echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf > /dev/null
  echo "[ddcutil] Created /etc/modules-load.d/i2c-dev.conf for persistent loading."
fi

echo "[ddcutil] Done."
