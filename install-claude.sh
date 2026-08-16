#!/bin/bash

set -euo pipefail

# Claude settings, hooks, and shared instructions are owned by the dotfiles
# package. This installer only supplies external language tooling.

echo "[claude] Setting up TypeScript language tooling..."

if command -v typescript-language-server &>/dev/null; then
  echo "[claude] typescript-language-server is already installed."
elif command -v npm &>/dev/null; then
  npm install -g typescript-language-server typescript
else
  echo "[claude] WARNING: npm is unavailable; skipping typescript-language-server."
fi

if ! command -v claude &>/dev/null; then
  echo "[claude] WARNING: Claude Code is unavailable; skipping the TypeScript plugin."
elif claude plugin list 2>/dev/null | grep -q "typescript-lsp@claude-plugins-official"; then
  echo "[claude] typescript-lsp plugin is already installed."
else
  echo "[claude] Installing the typescript-lsp plugin..."
  claude plugin install --scope user typescript-lsp@claude-plugins-official
fi

echo "[claude] Done."
