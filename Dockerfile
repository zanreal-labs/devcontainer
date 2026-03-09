FROM mcr.microsoft.com/devcontainers/base:bookworm

LABEL org.opencontainers.image.source="https://github.com/zanreal-labs/devcontainer"
LABEL org.opencontainers.image.description="Batteries-included dev container for modern TypeScript/JavaScript projects"
LABEL org.opencontainers.image.licenses="MIT"

ARG BUN_VERSION=""
ARG STRIPE_CLI=true

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

# Docker credential fix (avoids "error getting credentials" inside DinD)
RUN mkdir -p /home/vscode/.docker && \
    echo '{"credsStore":""}' > /home/vscode/.docker/config.json && \
    chown -R vscode:vscode /home/vscode/.docker
