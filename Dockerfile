FROM mcr.microsoft.com/devcontainers/base:bookworm

LABEL org.opencontainers.image.source="https://github.com/zanreal-labs/devcontainer"
LABEL org.opencontainers.image.description="AI-first dev container base image"
LABEL org.opencontainers.image.licenses="MIT"

# ── AI coding agents ────────────────────────────────────────────────────────

# Claude Code (installed as vscode user, binary only — auth comes from bind mounts)
USER vscode
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/vscode/.local/bin:$PATH"

# Note: Gemini CLI and OpenAI Codex are installed at runtime via setup.sh
# because Node.js is added as a devcontainer feature (not available at build time)

USER root

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
