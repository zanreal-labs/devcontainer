#!/bin/bash
set -e

echo "Installing uv..."

# Install directly to /usr/local/bin so it's on PATH for all users
export UV_INSTALL_DIR="/usr/local/bin"
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "uv installed: $(uv --version)"
