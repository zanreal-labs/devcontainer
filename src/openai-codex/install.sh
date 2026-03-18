#!/bin/bash
set -e

echo "Installing OpenAI Codex..."

# OpenAI Codex requires Node.js — check availability
if ! command -v npm &>/dev/null; then
  echo "ERROR: npm not found. Add the Node.js feature before openai-codex:"
  echo '  "ghcr.io/devcontainers/features/node:1": { "version": "22" }'
  exit 1
fi

npm install -g @openai/codex

echo "OpenAI Codex installed: $(codex --version 2>/dev/null || echo 'version check skipped')"
