#!/bin/bash
set -e

echo "Installing Gemini CLI..."

# Gemini CLI requires Node.js — check availability
if ! command -v npm &>/dev/null; then
  echo "ERROR: npm not found. Add the Node.js feature before gemini-cli:"
  echo '  "ghcr.io/devcontainers/features/node:1": { "version": "22" }'
  exit 1
fi

npm install -g @google/gemini-cli

echo "Gemini CLI installed: $(gemini --version 2>/dev/null | head -1 || echo 'version check skipped')"
