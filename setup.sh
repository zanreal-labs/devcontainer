#!/bin/bash
set -e

# ── Detect current user ──────────────────────────────────────────────────────
# Zed may run as root instead of honoring remoteUser, so we detect dynamically.
CURRENT_USER="$(id -un)"
CURRENT_GROUP="$(id -gn)"

# ── Git config ───────────────────────────────────────────────────────────────
# Check multiple paths: DinD mounts tmpfs over /tmp, hiding bind mounts there
HOST_GITCONFIG=""
for p in "$HOME/.host-gitconfig" /tmp/.host-gitconfig; do
  [ -f "$p" ] && HOST_GITCONFIG="$p" && break
done
if [ -n "$HOST_GITCONFIG" ]; then
  echo "==> Copying host .gitconfig..."
  cp "$HOST_GITCONFIG" "$HOME/.gitconfig"
  chown "$CURRENT_USER:$CURRENT_GROUP" "$HOME/.gitconfig" 2>/dev/null || true
fi

# ── SSH ──────────────────────────────────────────────────────────────────────
if [ -d /tmp/.host-ssh ]; then
  echo "==> Copying host SSH keys..."
  mkdir -p "$HOME/.ssh"
  cp -a /tmp/.host-ssh/. "$HOME/.ssh/"
  chown -R "$CURRENT_USER:$CURRENT_GROUP" "$HOME/.ssh" 2>/dev/null || true
  chmod 700 "$HOME/.ssh"
  chmod 600 "$HOME/.ssh"/* 2>/dev/null || true
  chmod 644 "$HOME/.ssh"/*.pub 2>/dev/null || true
  chmod 644 "$HOME/.ssh/known_hosts" 2>/dev/null || true
  chmod 644 "$HOME/.ssh/config" 2>/dev/null || true
fi

# ── GPG ──────────────────────────────────────────────────────────────────────
if [ -d /tmp/.host-gnupg ]; then
  echo "==> Setting up GPG..."
  mkdir -p "$HOME/.gnupg"
  cp -a /tmp/.host-gnupg/. "$HOME/.gnupg/"
  chown -R "$CURRENT_USER:$CURRENT_GROUP" "$HOME/.gnupg" 2>/dev/null || true
  chmod 700 "$HOME/.gnupg"
  chmod 600 "$HOME/.gnupg/"*.conf 2>/dev/null || true
  chmod 600 "$HOME/.gnupg/private-keys-v1.d"/* 2>/dev/null || true
  gpgconf --kill gpg-agent 2>/dev/null || true
  if [ ! -S "$HOME/.gnupg/S.gpg-agent" ]; then
    AGENT_CONF="$HOME/.gnupg/gpg-agent.conf"
    grep -q 'allow-loopback-pinentry' "$AGENT_CONF" 2>/dev/null || echo "allow-loopback-pinentry" >> "$AGENT_CONF"
    GPG_CONF="$HOME/.gnupg/gpg.conf"
    grep -q 'pinentry-mode loopback' "$GPG_CONF" 2>/dev/null || echo "pinentry-mode loopback" >> "$GPG_CONF"
    gpg-agent --daemon 2>/dev/null || true
  fi
fi
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] && ! grep -q 'GPG_TTY' "$rc" 2>/dev/null && echo 'export GPG_TTY=$(tty)' >> "$rc"
done
export GPG_TTY=$(tty) 2>/dev/null || true

# ── Volume ownership ────────────────────────────────────────────────────────
# Docker volumes are created as root — fix ownership for all mounted volumes
echo "==> Fixing volume ownership..."
if [ -d "node_modules" ]; then
  sudo chown "$CURRENT_USER:$CURRENT_GROUP" node_modules 2>/dev/null || true
fi
# Fix .next directories (anonymous volume mounts)
find . -maxdepth 3 -name ".next" -type d -exec sudo chown -R "$CURRENT_USER:$CURRENT_GROUP" {} \; 2>/dev/null || true

# ── Package manager setup & install ─────────────────────────────────────────
if [ -f "pnpm-lock.yaml" ]; then
  if command -v pnpm &>/dev/null || command -v corepack &>/dev/null; then
    echo "==> Setting up pnpm via corepack..."
    if command -v corepack &>/dev/null; then
      corepack enable
      corepack prepare --activate 2>/dev/null || corepack prepare pnpm@latest --activate
    fi
    echo "==> Installing dependencies with pnpm..."
    pnpm install
  else
    echo "==> Skipping dependency install — pnpm not found."
    echo "    Run 'devcontainer-wizard' to install it."
  fi
elif [ -f "bun.lock" ] || [ -f "bun.lockb" ]; then
  if command -v bun &>/dev/null; then
    echo "==> Cleaning stale node_modules symlinks..."
    find . -path ./node_modules -prune -o -name node_modules -type d -print -exec rm -rf {} + 2>/dev/null || true
    echo "==> Installing dependencies with bun..."
    bun install
  else
    echo "==> Skipping dependency install — bun not found."
    echo "    Run 'devcontainer-wizard' to install it."
  fi
elif [ -f "package-lock.json" ]; then
  if command -v npm &>/dev/null; then
    echo "==> Installing dependencies with npm..."
    npm install
  else
    echo "==> Skipping dependency install — npm not found."
  fi
elif [ -f "yarn.lock" ]; then
  if command -v yarn &>/dev/null; then
    echo "==> Installing dependencies with yarn..."
    yarn install
  else
    echo "==> Skipping dependency install — yarn not found."
  fi
fi

# ── Services ─────────────────────────────────────────────────────────────────
if [ -f "supabase/config.toml" ] && command -v supabase &>/dev/null; then
  echo "==> Starting Supabase..."
  supabase stop --no-backup 2>/dev/null || true
  supabase start
fi

if [ "${TINYBIRD:-}" = "1" ] && command -v docker &>/dev/null; then
  echo "==> Starting Tinybird Local..."
  docker start tinybird-local 2>/dev/null || \
    docker run -d -p 7181:7181 --name tinybird-local tinybirdco/tinybird-local:latest || \
    echo "    WARNING: Tinybird failed to start"
  sleep 3
fi

if [ -f "/usr/local/share/traefik/docker-compose.yml" ] && command -v docker &>/dev/null; then
  traefik-start
fi

# ── Setup wizard ─────────────────────────────────────────────────────────────
# Interactive TUI for selecting optional tools (AI agents, CLIs, etc.)
# Runs on first container start; re-run with: devcontainer-wizard --force
if [ ! -f "$HOME/.devcontainer-wizard-done" ]; then
  if [ -n "${DEVCONTAINER_TOOLS:-}" ]; then
    echo "==> Running wizard in headless mode (DEVCONTAINER_TOOLS set)..."
    bash /usr/local/share/devcontainer/wizard.sh
  elif [ -t 0 ]; then
    echo "==> Running setup wizard..."
    bash /usr/local/share/devcontainer/wizard.sh
  else
    echo "==> No TTY detected. Run 'devcontainer-wizard' to install additional tools."
  fi
fi

# ── Claude Code onboarding bypass ───────────────────────────────────────────
# Skip the first-run wizard (Claude subscription / API key / Bedrock) and the
# per-workspace trust dialog. Env vars alone (ANTHROPIC_API_KEY, ANTHROPIC_BASE_URL)
# are not enough — Claude Code still runs onboarding when ~/.claude.json is missing
# and when `theme` is unset.
#
# The native installer drops the binary at ~/.local/bin/claude, which is not on
# the non-interactive PATH that setup.sh inherits. We check several known
# locations instead of relying on `command -v claude`.
CLAUDE_BIN=""
for p in "$HOME/.local/bin/claude" "$HOME/.claude/local/claude" "$(command -v claude 2>/dev/null)"; do
  [ -n "$p" ] && [ -x "$p" ] && CLAUDE_BIN="$p" && break
done

if [ -n "$CLAUDE_BIN" ] || [ -d "$HOME/.claude" ]; then
  CLAUDE_JSON="$HOME/.claude.json"
  WORKDIR_ABS="$(pwd)"
  if [ ! -f "$CLAUDE_JSON" ]; then
    echo "==> Seeding ~/.claude.json to skip Claude Code onboarding..."
    cat > "$CLAUDE_JSON" <<EOF
{
  "theme": "dark",
  "hasCompletedOnboarding": true,
  "numStartups": 1,
  "projects": {
    "$WORKDIR_ABS": {
      "hasTrustDialogAccepted": true,
      "allowedTools": [],
      "mcpContextUris": [],
      "projectOnboardingSeenCount": 1
    }
  }
}
EOF
    chown "$CURRENT_USER:$CURRENT_GROUP" "$CLAUDE_JSON" 2>/dev/null || true
  else
    # File exists (e.g. bind-mounted from host or created during a prior run).
    # Ensure the current workspace is marked trusted so trust prompts don't block.
    if command -v jq &>/dev/null; then
      TMP="$(mktemp)"
      jq --arg dir "$WORKDIR_ABS" '
        .theme = (.theme // "dark")
        | .hasCompletedOnboarding = true
        | .projects = (.projects // {})
        | .projects[$dir] = (
            (.projects[$dir] // {})
            + { hasTrustDialogAccepted: true, projectOnboardingSeenCount: 1 }
          )
      ' "$CLAUDE_JSON" > "$TMP" && mv "$TMP" "$CLAUDE_JSON"
      chown "$CURRENT_USER:$CURRENT_GROUP" "$CLAUDE_JSON" 2>/dev/null || true
    fi
  fi
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
command -v claude &>/dev/null && printf "    %-12s %s\n" "claude" "$(claude --version 2>/dev/null)"
command -v forge &>/dev/null && printf "    %-12s %s\n" "forge" "$(forge --version 2>/dev/null)"
command -v gemini &>/dev/null && printf "    %-12s %s\n" "gemini" "$(gemini --version 2>/dev/null | head -1)"
command -v codex &>/dev/null && printf "    %-12s %s\n" "codex" "$(codex --version 2>/dev/null)"
command -v opencode &>/dev/null && printf "    %-12s %s\n" "opencode" "$(opencode version 2>/dev/null)"
echo ""

echo "  Infrastructure"
command -v docker &>/dev/null && printf "    %-12s %s\n" "docker" "$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')"
command -v gh &>/dev/null && printf "    %-12s %s\n" "gh" "$(gh --version 2>/dev/null | head -1 | awk '{print $3}')"
command -v supabase &>/dev/null && printf "    %-12s %s\n" "supabase" "$(supabase --version 2>/dev/null)"
command -v stripe &>/dev/null && printf "    %-12s %s\n" "stripe" "$(stripe version 2>/dev/null)"
command -v tb &>/dev/null && printf "    %-12s %s\n" "tinybird" "$(tb --version 2>/dev/null | awk '{print $NF}')"
echo ""
