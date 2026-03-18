#!/bin/bash
set -e

echo "Installing Claude Code..."

# Claude Code installs to ~/.local/bin — install as the target user
REMOTE_USER="${_REMOTE_USER:-vscode}"
REMOTE_HOME="${_REMOTE_USER_HOME:-/home/vscode}"

su - "$REMOTE_USER" -c 'curl -fsSL https://claude.ai/install.sh | bash'

# Ensure ~/.local/bin is in PATH for all shell sessions
for rc in "$REMOTE_HOME/.bashrc" "$REMOTE_HOME/.zshrc"; do
  if [ -f "$rc" ] && ! grep -q '\.local/bin' "$rc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
  fi
done

echo "Claude Code installed: $(su - "$REMOTE_USER" -c 'claude --version' 2>/dev/null || echo 'version check skipped')"
