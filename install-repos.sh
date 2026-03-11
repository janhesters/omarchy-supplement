#!/bin/bash

echo "[repos] Cloning development repositories..."

mkdir -p "$HOME/dev"

if [ -d "$HOME/dev/aidd-jan" ]; then
  echo "[repos] aidd-jan already exists, skipping."
else
  git clone git@github.com:janhesters/aidd-jan.git "$HOME/dev/aidd-jan"
fi

echo "[repos] Done."
