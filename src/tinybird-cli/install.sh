#!/bin/bash
set -e

echo "Installing Tinybird CLI..."

# Ensure uv is available (installed by uv feature or already present)
if ! command -v uv &>/dev/null; then
  echo "Installing uv (required for Tinybird CLI)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ln -sf /root/.local/bin/uv /usr/local/bin/uv
  ln -sf /root/.local/bin/uvx /usr/local/bin/uvx
fi

uv tool install --python 3.13 tinybird-cli
ln -sf /root/.local/bin/tb /usr/local/bin/tb

echo "Tinybird CLI installed: $(tb --version)"
