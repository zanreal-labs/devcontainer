#!/bin/bash

# ── Constants ────────────────────────────────────────────────────────────────
MARKER_FILE="$HOME/.devcontainer-wizard-done"
SELECTIONS_FILE="$HOME/.devcontainer-selections"
BRAND="#A855F7"

# ── gum theme — set via env vars so ALL gum components use brand color ───────
export GUM_CHOOSE_CURSOR_FOREGROUND="$BRAND"
export GUM_CHOOSE_SELECTED_FOREGROUND="$BRAND"
export GUM_CHOOSE_HEADER_FOREGROUND="$BRAND"
export GUM_CONFIRM_SELECTED_FOREGROUND="15"
export GUM_CONFIRM_SELECTED_BACKGROUND="$BRAND"
export GUM_CONFIRM_UNSELECTED_FOREGROUND="$BRAND"
export GUM_SPIN_SPINNER_FOREGROUND="$BRAND"

# ── Argument parsing ─────────────────────────────────────────────────────────
FORCE=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --force) FORCE=true; shift ;;
    *) shift ;;
  esac
done

# ── Guard: skip if already done (unless --force) ────────────────────────────
if [ -f "$MARKER_FILE" ] && [ "$FORCE" != "true" ]; then
  exit 0
fi

# ── Headless mode via DEVCONTAINER_TOOLS env var ─────────────────────────────
if [ -n "${DEVCONTAINER_TOOLS:-}" ]; then
  echo "==> Installing tools from DEVCONTAINER_TOOLS: $DEVCONTAINER_TOOLS"
  IFS=',' read -ra TOOLS <<< "$DEVCONTAINER_TOOLS"
  for tool in "${TOOLS[@]}"; do
    tool="$(echo "$tool" | xargs)" # trim whitespace
    case "$tool" in
      claude-code)
        command -v claude &>/dev/null || { echo "  Installing Claude Code..."; curl -fsSL https://claude.ai/install.sh | bash 2>/dev/null; } ;;
      gemini-cli)
        command -v gemini &>/dev/null || { echo "  Installing Gemini CLI..."; npm install -g @google/gemini-cli 2>/dev/null; } ;;
      openai-codex)
        command -v codex &>/dev/null || { echo "  Installing OpenAI Codex..."; npm install -g @openai/codex 2>/dev/null; } ;;
      forgecode)
        command -v forge &>/dev/null || { echo "  Installing ForgeCode..."; curl -fsSL https://forgecode.dev/cli | sh 2>/dev/null; } ;;
      opencode)
        command -v opencode &>/dev/null || { echo "  Installing OpenCode..."; curl -fsSL https://opencode.ai/install | bash 2>/dev/null; } ;;
      bun)
        command -v bun &>/dev/null || { echo "  Installing bun..."; curl -fsSL https://bun.sh/install | BUN_INSTALL="$HOME/.bun" bash 2>/dev/null; } ;;
      uv)
        command -v uv &>/dev/null || { echo "  Installing uv..."; curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null; } ;;
      supabase-cli)
        command -v supabase &>/dev/null || {
          echo "  Installing Supabase CLI..."
          ARCH=$(uname -m); [ "$ARCH" = "aarch64" ] && ARCH="arm64"; [ "$ARCH" = "x86_64" ] && ARCH="amd64"
          curl -fsSL "https://github.com/supabase/cli/releases/latest/download/supabase_linux_${ARCH}.tar.gz" -o /tmp/supabase.tar.gz
          sudo tar -xzf /tmp/supabase.tar.gz -C /usr/local/bin supabase && rm /tmp/supabase.tar.gz
        } ;;
      tinybird-cli)
        command -v tb &>/dev/null || {
          echo "  Installing Tinybird CLI..."
          command -v uv &>/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null
          uv tool install --python 3.13 tinybird-cli 2>/dev/null
        } ;;
      stripe-cli)
        command -v stripe &>/dev/null || {
          echo "  Installing Stripe CLI..."
          curl -s https://packages.stripe.dev/api/security/keypair/stripe-cli-gpg/public | sudo gpg --dearmor -o /usr/share/keyrings/stripe.gpg 2>/dev/null
          echo "deb [signed-by=/usr/share/keyrings/stripe.gpg] https://packages.stripe.dev/stripe-cli-debian-local stable main" | sudo tee /etc/apt/sources.list.d/stripe.list > /dev/null
          sudo apt-get update -qq && sudo apt-get install -y -qq stripe && sudo rm -rf /var/lib/apt/lists/*
        } ;;
      github-cli)
        command -v gh &>/dev/null || {
          echo "  Installing GitHub CLI..."
          curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
          echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
          sudo apt-get update -qq && sudo apt-get install -y -qq gh && sudo rm -rf /var/lib/apt/lists/*
        } ;;
    esac
  done
  echo "$DEVCONTAINER_TOOLS" > "$SELECTIONS_FILE"
  touch "$MARKER_FILE"
  exit 0
fi

# ── Guard: require TTY for interactive mode ──────────────────────────────────
if [ ! -t 0 ]; then
  echo "No TTY detected. Run 'devcontainer-wizard' manually, or set DEVCONTAINER_TOOLS env var."
  exit 0
fi

# ── gum availability check ──────────────────────────────────────────────────
if ! command -v gum &>/dev/null; then
  echo "ERROR: gum not found. Cannot run TUI wizard."
  exit 1
fi

# ── Header ──────────────────────────────────────────────────────────────────
gum style \
  --border double \
  --border-foreground "$BRAND" \
  --padding "1 2" \
  --margin "1 0" \
  "Dev Container Setup Wizard" \
  "" \
  "Select the tools you want installed." \
  "Use space to toggle, enter to confirm."

# ── Build options list ──────────────────────────────────────────────────────
OPTIONS=()

# AI Agents
OPTIONS+=("Claude Code" "ForgeCode" "OpenCode")
command -v npm &>/dev/null && OPTIONS+=("Gemini CLI" "OpenAI Codex")

# Package Managers
OPTIONS+=("bun" "uv")

# Infrastructure
OPTIONS+=("Supabase CLI" "Tinybird CLI" "Stripe CLI")
command -v gh &>/dev/null || OPTIONS+=("GitHub CLI")

# ── Single selection screen ─────────────────────────────────────────────────
CHOICES=$(gum choose --no-limit \
  --height "${#OPTIONS[@]}" \
  --cursor-prefix "[ ] " \
  --selected-prefix "[x] " \
  --unselected-prefix "[ ] " \
  --header "AI: Claude/Forge/OpenCode/Gemini/Codex | Pkg: bun/uv | Infra: Supabase/Tinybird/Stripe/GH" \
  "${OPTIONS[@]}") || true

if [ -z "$CHOICES" ]; then
  gum style --foreground 214 "No tools selected. Re-run with: devcontainer-wizard --force"
  touch "$MARKER_FILE"
  exit 0
fi

# ── Confirmation ─────────────────────────────────────────────────────────────
echo ""
gum style --foreground "$BRAND" --bold "Selected:"
while IFS= read -r line; do
  [ -n "$line" ] && echo "  - $line"
done <<< "$CHOICES"
echo ""

gum confirm "Install these tools?" || {
  echo "Cancelled. Re-run with: devcontainer-wizard --force"
  exit 0
}

# ── Save selections ─────────────────────────────────────────────────────────
echo "$CHOICES" > "$SELECTIONS_FILE"

# ── Install helper ───────────────────────────────────────────────────────────
INSTALL_LOG="/tmp/devcontainer-wizard.log"
: > "$INSTALL_LOG"

install_tool() {
  local name="$1"
  local cmd="$2"
  local installer="$3"

  if command -v "$cmd" &>/dev/null; then
    echo "  [ok] $name (already installed)"
    return 0
  fi

  echo "--- Installing $name ---" >> "$INSTALL_LOG"
  echo "  Installing $name..."
  if bash -c "$installer" >> "$INSTALL_LOG" 2>&1; then
    # Re-check PATH in case installer added to ~/.local/bin etc
    export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
    if command -v "$cmd" &>/dev/null; then
      echo "  [ok] $name"
    else
      echo "  [warn] $name — installed but not on PATH"
    fi
  else
    echo "  [fail] $name — see /tmp/devcontainer-wizard.log"
  fi
}

# ── Install loop ─────────────────────────────────────────────────────────────
echo ""
gum style --foreground "$BRAND" --bold "Installing..."

while IFS= read -r tool; do
  [ -z "$tool" ] && continue
  case "$tool" in
    "Claude Code")
      install_tool "Claude Code" "claude" \
        "curl -fsSL https://claude.ai/install.sh | bash"
      ;;
    "Gemini CLI")
      install_tool "Gemini CLI" "gemini" \
        "npm install -g @google/gemini-cli"
      ;;
    "OpenAI Codex")
      install_tool "OpenAI Codex" "codex" \
        "npm install -g @openai/codex"
      ;;
    "ForgeCode")
      install_tool "ForgeCode" "forge" \
        "curl -fsSL https://forgecode.dev/cli | sh"
      ;;
    "OpenCode")
      install_tool "OpenCode" "opencode" \
        "curl -fsSL https://opencode.ai/install | bash"
      ;;
    "bun")
      install_tool "bun" "bun" \
        "curl -fsSL https://bun.sh/install | BUN_INSTALL=\$HOME/.bun bash && sudo ln -sf \$HOME/.bun/bin/bun /usr/local/bin/bun"
      ;;
    "uv")
      install_tool "uv" "uv" \
        "curl -LsSf https://astral.sh/uv/install.sh | sh"
      ;;
    "Supabase CLI")
      install_tool "Supabase CLI" "supabase" \
        'ARCH=$(uname -m); [ "$ARCH" = "aarch64" ] && ARCH="arm64"; [ "$ARCH" = "x86_64" ] && ARCH="amd64"; curl -fsSL "https://github.com/supabase/cli/releases/latest/download/supabase_linux_${ARCH}.tar.gz" -o /tmp/supabase.tar.gz && sudo tar -xzf /tmp/supabase.tar.gz -C /usr/local/bin supabase && rm /tmp/supabase.tar.gz'
      ;;
    "Tinybird CLI")
      install_tool "Tinybird CLI" "tb" \
        'command -v uv &>/dev/null || (curl -LsSf https://astral.sh/uv/install.sh | sh); uv tool install --python 3.13 tinybird-cli'
      ;;
    "Stripe CLI")
      install_tool "Stripe CLI" "stripe" \
        'curl -s https://packages.stripe.dev/api/security/keypair/stripe-cli-gpg/public | sudo gpg --dearmor -o /usr/share/keyrings/stripe.gpg 2>/dev/null && echo "deb [signed-by=/usr/share/keyrings/stripe.gpg] https://packages.stripe.dev/stripe-cli-debian-local stable main" | sudo tee /etc/apt/sources.list.d/stripe.list > /dev/null && sudo apt-get update -qq && sudo apt-get install -y -qq stripe && sudo rm -rf /var/lib/apt/lists/*'
      ;;
    "GitHub CLI")
      install_tool "GitHub CLI" "gh" \
        'curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && sudo apt-get update -qq && sudo apt-get install -y -qq gh && sudo rm -rf /var/lib/apt/lists/*'
      ;;
  esac
done <<< "$CHOICES"

# ── Done ─────────────────────────────────────────────────────────────────────
touch "$MARKER_FILE"

echo ""
gum style \
  --border rounded \
  --border-foreground "$BRAND" \
  --padding "1 2" \
  --margin "1 0" \
  "Setup complete!" \
  "" \
  "Re-run anytime: devcontainer-wizard --force"
