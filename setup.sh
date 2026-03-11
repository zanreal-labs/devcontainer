#!/bin/bash
set -e

# ── Git config ───────────────────────────────────────────────────────────────
# .gitconfig is bind-mounted to a staging path (/tmp/.host-gitconfig) because
# Docker file bind mounts can't handle atomic rename (git config writes a
# temp file then renames). We copy it so git can modify it freely.
if [ -f /tmp/.host-gitconfig ]; then
  echo "==> Copying host .gitconfig..."
  cp /tmp/.host-gitconfig "$HOME/.gitconfig"
  chown vscode:vscode "$HOME/.gitconfig"
fi

# ── GPG ──────────────────────────────────────────────────────────────────────
echo "==> Setting up GPG..."

if [ -d "$HOME/.gnupg" ]; then
  # Fix ownership — bind mounts may come in as root
  sudo chown -R vscode:vscode "$HOME/.gnupg" 2>/dev/null || true
  chmod 700 "$HOME/.gnupg"
  chmod 600 "$HOME/.gnupg/"*.conf 2>/dev/null || true
  chmod 600 "$HOME/.gnupg/private-keys-v1.d"/* 2>/dev/null || true

  # Kill stale agent so it picks up the refreshed keyring / socket
  gpgconf --kill gpg-agent 2>/dev/null || true

  # On Linux hosts the bind-mounted .gnupg may contain a live agent socket
  # pointing back to the host agent — this just works.
  # On macOS, Docker cannot forward Unix sockets so we start a local agent
  # using the mounted keyring and enable loopback pinentry for non-interactive
  # terminals (VS Code integrated terminal, CI, background processes).
  if [ ! -S "$HOME/.gnupg/S.gpg-agent" ]; then
    AGENT_CONF="$HOME/.gnupg/gpg-agent.conf"
    if [ ! -f "$AGENT_CONF" ] || ! grep -q 'allow-loopback-pinentry' "$AGENT_CONF" 2>/dev/null; then
      echo "allow-loopback-pinentry" >> "$AGENT_CONF"
    fi

    GPG_CONF="$HOME/.gnupg/gpg.conf"
    if [ ! -f "$GPG_CONF" ] || ! grep -q 'pinentry-mode loopback' "$GPG_CONF" 2>/dev/null; then
      echo "pinentry-mode loopback" >> "$GPG_CONF"
    fi

    gpg-agent --daemon 2>/dev/null || true
  fi
fi

# Set GPG_TTY dynamically so pinentry can prompt in the right terminal
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [ -f "$rc" ] && ! grep -q 'GPG_TTY' "$rc" 2>/dev/null; then
    echo 'export GPG_TTY=$(tty)' >> "$rc"
  fi
done
export GPG_TTY=$(tty) 2>/dev/null || true

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
echo "==> Environment ready"
echo ""

echo "  Runtimes"
printf "    %-12s %s\n" "node" "$(node --version 2>/dev/null || echo 'MISSING')"
command -v bun &>/dev/null && printf "    %-12s %s\n" "bun" "$(bun --version 2>/dev/null)"
command -v python3 &>/dev/null && printf "    %-12s %s\n" "python" "$(python3 --version 2>/dev/null | awk '{print $2}')"
command -v uv &>/dev/null && printf "    %-12s %s\n" "uv" "$(uv --version 2>/dev/null | awk '{print $2}')"
echo ""

echo "  AI Agents"
printf "    %-12s %s\n" "claude" "$(claude --version 2>/dev/null || echo 'MISSING')"
command -v gemini &>/dev/null && printf "    %-12s %s\n" "gemini" "$(gemini --version 2>/dev/null | head -1)"
command -v codex &>/dev/null && printf "    %-12s %s\n" "codex" "$(codex --version 2>/dev/null)"
echo ""

echo "  Infrastructure"
command -v docker &>/dev/null && printf "    %-12s %s\n" "docker" "$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')"
command -v gh &>/dev/null && printf "    %-12s %s\n" "gh" "$(gh --version 2>/dev/null | head -1 | awk '{print $3}')"
command -v supabase &>/dev/null && printf "    %-12s %s\n" "supabase" "$(supabase --version 2>/dev/null)"
command -v stripe &>/dev/null && printf "    %-12s %s\n" "stripe" "$(stripe version 2>/dev/null)"
command -v tb &>/dev/null && printf "    %-12s %s\n" "tinybird" "$(tb --version 2>/dev/null | awk '{print $NF}')"
echo ""
