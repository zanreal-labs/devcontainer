#!/bin/bash
set -e

echo "Installing uv..."

curl -LsSf https://astral.sh/uv/install.sh | sh
ln -sf /root/.local/bin/uv /usr/local/bin/uv
ln -sf /root/.local/bin/uvx /usr/local/bin/uvx

echo "uv installed: $(uv --version)"
