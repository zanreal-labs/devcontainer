#!/bin/bash
set -e

echo "Installing Bun..."

VERSION="${VERSION:-latest}"

if [[ "$VERSION" = "latest" ]]; then
  curl -fsSL --proto-redir '=https' https://bun.sh/install | BUN_INSTALL=/usr/local bash
else
  curl -fsSL --proto-redir '=https' https://bun.sh/install | BUN_INSTALL=/usr/local bash -s "bun-v${VERSION}"
fi

echo "Bun installed: $(bun --version)"
