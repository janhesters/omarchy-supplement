#!/bin/bash

set -e

echo "[scarlett] Setting up Focusrite Scarlett 2i2 USB audio fix..."

CONF="/etc/modprobe.d/scarlett.conf"
EXPECTED="options snd_usb_audio device_setup=1"

if [ -f "$CONF" ] && grep -qF "$EXPECTED" "$CONF"; then
  echo "[scarlett] $CONF already configured, skipping."
else
  echo "$EXPECTED" | sudo tee "$CONF" > /dev/null
  echo "[scarlett] Created $CONF to fix distorted audio capture."
fi

echo "[scarlett] Done."
