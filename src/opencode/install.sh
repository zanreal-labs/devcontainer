#!/bin/bash
set -e

echo "Installing OpenCode..."

curl -fsSL https://opencode.ai/install | bash

echo "OpenCode installed: $(opencode version 2>/dev/null || echo 'version check skipped')"
