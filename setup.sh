#!/bin/bash
set -e

# ── GPG ──────────────────────────────────────────────────────────────────────
echo "==> Setting up GPG..."
export GPG_TTY=$(tty) 2>/dev/null || true
if [ -d "$HOME/.gnupg" ]; then
  sudo chown -R vscode:vscode "$HOME/.gnupg" 2>/dev/null || true
  chmod 700 "$HOME/.gnupg"
  chmod 600 "$HOME/.gnupg/"* 2>/dev/null || true
fi

# ── Gemini config ────────────────────────────────────────────────────────────
if [ -d "$HOME/.gemini" ]; then
  echo "==> Fixing Gemini CLI permissions..."
  sudo chown -R vscode:vscode "$HOME/.gemini"
fi

# ── AI coding assistants ─────────────────────────────────────────────────────
echo "==> Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh | bash
# Add ~/.local/bin to PATH for this script and future shell sessions
export PATH="$HOME/.local/bin:$PATH"
grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zshrc" 2>/dev/null || \
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"

echo "==> Installing Gemini CLI and OpenAI Codex..."
npm install -g @google/gemini-cli @openai/codex

# ── Node modules volume ownership ───────────────────────────────────────────
if [ -d "node_modules" ]; then
  echo "==> Fixing node_modules volume ownership..."
  sudo chown vscode:vscode node_modules
fi

# ── Package manager setup & install ─────────────────────────────────────────
if [ -f "pnpm-lock.yaml" ]; then
  echo "==> Setting up pnpm via corepack..."
  if command -v corepack &>/dev/null; then
    corepack enable
    # Use version from packageManager field in package.json, or fall back to latest
    corepack prepare --activate 2>/dev/null || corepack prepare pnpm@latest --activate
  fi
  echo "==> Installing dependencies with pnpm..."
  pnpm install
elif [ -f "bun.lock" ] || [ -f "bun.lockb" ]; then
  echo "==> Cleaning stale node_modules symlinks..."
  find . -path ./node_modules -prune -o -name node_modules -type d -print -exec rm -rf {} + 2>/dev/null || true
  echo "==> Installing dependencies with bun..."
  bun install
elif [ -f "package-lock.json" ]; then
  echo "==> Installing dependencies with npm..."
  npm install
elif [ -f "yarn.lock" ]; then
  echo "==> Installing dependencies with yarn..."
  yarn install
fi

# ── Services ─────────────────────────────────────────────────────────────────
if [ -f "supabase/config.toml" ]; then
  echo "==> Starting Supabase..."
  supabase stop --no-backup 2>/dev/null || true
  supabase start
fi

if [ "${TINYBIRD:-}" = "1" ]; then
  echo "==> Starting Tinybird Local..."
  docker start tinybird-local 2>/dev/null || \
    docker run -d -p 7181:7181 --name tinybird-local tinybirdco/tinybird-local:latest || \
    echo "    WARNING: Tinybird failed to start"
  sleep 3
fi

# ── Project-specific hook ────────────────────────────────────────────────────
if [ -f ".devcontainer/post-setup.sh" ]; then
  echo "==> Running project-specific post-setup..."
  bash .devcontainer/post-setup.sh
fi

# ── Health check ─────────────────────────────────────────────────────────────
echo "==> Verifying tools..."
echo "    node     $(node --version 2>/dev/null || echo 'MISSING')"
echo "    bun      $(bun --version 2>/dev/null || echo 'MISSING')"
echo "    claude   $(claude --version 2>/dev/null || echo 'MISSING')"
echo "    supabase $(supabase --version 2>/dev/null || echo 'MISSING')"
echo "    docker   $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',' || echo 'MISSING')"
echo "    uv       $(/home/vscode/.local/bin/uv --version 2>/dev/null || echo 'MISSING')"

echo "==> Setup complete!"
