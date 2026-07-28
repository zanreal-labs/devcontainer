FROM mcr.microsoft.com/devcontainers/base:bookworm

LABEL org.opencontainers.image.source="https://github.com/zanreal-labs/devcontainer"
LABEL org.opencontainers.image.description="AI-first dev container base image"
LABEL org.opencontainers.image.licenses="MIT"

# ── System setup ─────────────────────────────────────────────────────────────

# GPG symlink (macOS .gitconfig references /usr/local/bin/gpg, Debian has /usr/bin/gpg)
# plus a drop-in dir for custom CA certificates (corporate proxies - mount or
# COPY certs here). The symlink is best-effort, so its status is discarded.
RUN ln -sf /usr/bin/gpg /usr/local/bin/gpg 2>/dev/null; \
    mkdir -p /usr/local/share/ca-certificates/extra

# Default non-root user — Microsoft base uses "vscode", override with build arg
ARG USERNAME=vscode

# Docker credential fix (avoids "error getting credentials" inside DinD)
RUN mkdir -p /home/${USERNAME}/.docker && \
    echo '{"credsStore":""}' > /home/${USERNAME}/.docker/config.json && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.docker

# Ensure ~/.local/bin is in PATH for all shell sessions
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/${USERNAME}/.bashrc && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/${USERNAME}/.zshrc 2>/dev/null || true

# ── TUI toolkit (Charmbracelet gum) ─────────────────────────────────────────
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL --proto-redir '=https' https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" > /etc/apt/sources.list.d/charm.list && \
    apt-get update && \
    apt-get install -y gum tmux && \
    rm -rf /var/lib/apt/lists/*

# ── tmux config ──────────────────────────────────────────────────────────────
COPY tmux.conf /home/${USERNAME}/.tmux.conf
RUN chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.tmux.conf

# ── Embedded scripts ────────────────────────────────────────────────────────
COPY setup.sh /usr/local/share/devcontainer/setup.sh
COPY wizard.sh /usr/local/share/devcontainer/wizard.sh
RUN chmod +x /usr/local/share/devcontainer/setup.sh /usr/local/share/devcontainer/wizard.sh && \
    ln -s /usr/local/share/devcontainer/wizard.sh /usr/local/bin/devcontainer-wizard

USER ${USERNAME}
