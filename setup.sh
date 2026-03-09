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

# ── AI coding assistants (runtime install — Node.js comes from features) ────
echo "==> Installing Gemini CLI and OpenAI Codex..."
npm install -g @google/gemini-cli @openai/codex

# ── Volume ownership ────────────────────────────────────────────────────────
# Docker volumes are created as root — fix ownership for all mounted volumes
echo "==> Fixing volume ownership..."
if [ -d "node_modules" ]; then
  sudo chown vscode:vscode node_modules
fi
# Fix .next directories (anonymous volume mounts)
find . -maxdepth 3 -name ".next" -type d -exec sudo chown -R vscode:vscode {} \; 2>/dev/null || true

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
echo ""
echo "  ┌──────────────────────────────────────────┐"
echo "  │         Environment ready                 │"
echo "  ├──────────────────────────────────────────┤"

# Runtimes (always present)
echo "  │                                          │"
echo "  │  Runtimes                                │"
printf "  │    %-12s %s\n" "node" "$(node --version 2>/dev/null || echo 'MISSING')" | sed 's/$/ │/'
command -v bun &>/dev/null && printf "  │    %-12s %s\n" "bun" "$(bun --version 2>/dev/null)" | sed 's/$/ │/'
command -v uv &>/dev/null && printf "  │    %-12s %s\n" "uv" "$(uv --version 2>/dev/null | awk '{print $2}')" | sed 's/$/ │/'

# AI Agents
echo "  │                                          │"
echo "  │  AI Agents                               │"
printf "  │    %-12s %s\n" "claude" "$(claude --version 2>/dev/null || echo 'MISSING')" | sed 's/$/ │/'
command -v gemini &>/dev/null && printf "  │    %-12s %s\n" "gemini" "$(gemini --version 2>/dev/null | head -1)" | sed 's/$/ │/'
command -v codex &>/dev/null && printf "  │    %-12s %s\n" "codex" "$(codex --version 2>/dev/null)" | sed 's/$/ │/'

# Infrastructure (only show what's installed)
INFRA=""
command -v docker &>/dev/null && INFRA="${INFRA}docker "
command -v supabase &>/dev/null && INFRA="${INFRA}supabase "
command -v stripe &>/dev/null && INFRA="${INFRA}stripe "
command -v tb &>/dev/null && INFRA="${INFRA}tinybird "

if [ -n "$INFRA" ]; then
  echo "  │                                          │"
  echo "  │  Infrastructure                          │"
  command -v docker &>/dev/null && printf "  │    %-12s %s\n" "docker" "$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')" | sed 's/$/ │/'
  command -v supabase &>/dev/null && printf "  │    %-12s %s\n" "supabase" "$(supabase --version 2>/dev/null)" | sed 's/$/ │/'
  command -v stripe &>/dev/null && printf "  │    %-12s %s\n" "stripe" "$(stripe version 2>/dev/null)" | sed 's/$/ │/'
  command -v tb &>/dev/null && printf "  │    %-12s %s\n" "tinybird" "$(tb --version 2>/dev/null | awk '{print $NF}')" | sed 's/$/ │/'
fi

echo "  │                                          │"
echo "  └──────────────────────────────────────────┘"
echo ""
