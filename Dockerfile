FROM mcr.microsoft.com/devcontainers/base:bookworm

LABEL org.opencontainers.image.source="https://github.com/zanreal-labs/devcontainer"
LABEL org.opencontainers.image.description="Batteries-included dev container for AI-assisted TypeScript/JavaScript development"
LABEL org.opencontainers.image.licenses="MIT"

ARG BUN_VERSION=""
ARG STRIPE_CLI=true

# ── Infrastructure CLIs ──────────────────────────────────────────────────────

# Supabase CLI
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ]; then ARCH="arm64"; elif [ "$ARCH" = "x86_64" ]; then ARCH="amd64"; fi && \
    curl -fsSL "https://github.com/supabase/cli/releases/latest/download/supabase_linux_${ARCH}.tar.gz" -o /tmp/supabase.tar.gz && \
    tar -xzf /tmp/supabase.tar.gz -C /usr/local/bin supabase && \
    rm /tmp/supabase.tar.gz

# Bun (latest if BUN_VERSION is empty, otherwise pinned)
RUN if [ -z "$BUN_VERSION" ]; then \
      curl -fsSL https://bun.sh/install | BUN_INSTALL=/usr/local bash; \
    else \
      curl -fsSL https://bun.sh/install | BUN_INSTALL=/usr/local bash -s "bun-v${BUN_VERSION}"; \
    fi

# Tinybird CLI via uv (pinned to Python 3.13 for pydantic compatibility)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    /root/.local/bin/uv tool install --python 3.13 tinybird-cli && \
    ln -sf /root/.local/bin/tb /usr/local/bin/tb

# Stripe CLI (optional)
RUN if [ "$STRIPE_CLI" = "true" ]; then \
      curl -s https://packages.stripe.dev/api/security/keypair/stripe-cli-gpg/public | gpg --dearmor -o /usr/share/keyrings/stripe.gpg && \
      echo "deb [signed-by=/usr/share/keyrings/stripe.gpg] https://packages.stripe.dev/stripe-cli-debian-local stable main" > /etc/apt/sources.list.d/stripe.list && \
      apt-get update && apt-get install -y stripe && \
      rm -rf /var/lib/apt/lists/*; \
    fi

# ── AI coding agents ────────────────────────────────────────────────────────

# Claude Code
USER vscode
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/vscode/.local/bin:$PATH"

# Gemini CLI and OpenAI Codex (need npm from base image)
USER root
RUN npm install -g @google/gemini-cli @openai/codex 2>/dev/null || true

# ── System setup ─────────────────────────────────────────────────────────────

# GPG symlink (macOS .gitconfig references /usr/local/bin/gpg, Debian has /usr/bin/gpg)
RUN ln -sf /usr/bin/gpg /usr/local/bin/gpg 2>/dev/null || true

# Custom CA certificates (for corporate proxies — mount or COPY certs here)
RUN mkdir -p /usr/local/share/ca-certificates/extra

# Docker credential fix (avoids "error getting credentials" inside DinD)
RUN mkdir -p /home/vscode/.docker && \
    echo '{"credsStore":""}' > /home/vscode/.docker/config.json && \
    chown -R vscode:vscode /home/vscode/.docker

# Ensure ~/.local/bin is in PATH for all shell sessions
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/vscode/.bashrc && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/vscode/.zshrc 2>/dev/null || true

# ── Embedded setup script ───────────────────────────────────────────────────
COPY setup.sh /usr/local/share/devcontainer/setup.sh
RUN chmod +x /usr/local/share/devcontainer/setup.sh

USER vscode
