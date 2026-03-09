# devcontainer

A modular, AI-first dev container for modern software development. A slim base image with AI coding agents, plus opt-in features for the tools you actually use.

## Why

AI coding agents (Claude Code, Gemini CLI, Codex) need a consistent, reproducible environment to work effectively. When agents run in inconsistent local setups, they hit missing tools, broken PATHs, and permission errors. Dev containers solve this by giving every developer — and every AI agent — the same deterministic environment.

This image is designed around three principles:

1. **AI-first** — every major coding agent is pre-installed and configured
2. **Modular** — slim base image, add only the tools you need via features
3. **Zero cache leakage** — build artifacts stay in the container, never pollute your host drive

## Quick start

Add a `devcontainer.json` to your project:

```jsonc
{
  "image": "ghcr.io/zanreal-labs/devcontainer:latest",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": { "moby": false },
    "ghcr.io/devcontainers/features/node:1": { "version": "22" },
    // Add what you need:
    "ghcr.io/zanreal-labs/devcontainer/bun:1": {},
    "ghcr.io/zanreal-labs/devcontainer/supabase-cli:1": {}
  },
  "postCreateCommand": "bash /usr/local/share/devcontainer/setup.sh"
}
```

Open in VS Code or any devcontainer-compatible editor. Done.

See [`examples/devcontainer.json`](examples/devcontainer.json) for a fully annotated configuration.

## What's included

### Base image (always included)

| Category | Tools |
|----------|-------|
| **AI coding agents** | [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [Gemini CLI](https://github.com/google/gemini-cli), [OpenAI Codex](https://github.com/openai/codex) |
| **Security** | GPG commit signing (macOS path fix), SSH agent forwarding, Docker credential isolation |
| **System** | Custom CA certificate support, embedded setup script |

### Optional features (pick what you need)

| Feature | ID | Description |
|---------|----|-------------|
| **Bun** | `ghcr.io/zanreal-labs/devcontainer/bun:1` | Fast JavaScript runtime and package manager |
| **uv** | `ghcr.io/zanreal-labs/devcontainer/uv:1` | Fast Python package manager and toolchain |
| **Supabase CLI** | `ghcr.io/zanreal-labs/devcontainer/supabase-cli:1` | Local Supabase development stack |
| **Stripe CLI** | `ghcr.io/zanreal-labs/devcontainer/stripe-cli:1` | Payment integration development |
| **Tinybird CLI** | `ghcr.io/zanreal-labs/devcontainer/tinybird-cli:1` | Real-time analytics (auto-installs uv if needed) |

```jsonc
"features": {
  // Only add what your project uses:
  "ghcr.io/zanreal-labs/devcontainer/bun:1": { "version": "1.3.3" },
  "ghcr.io/zanreal-labs/devcontainer/supabase-cli:1": {}
}
```

## Cache isolation

Dev containers bind-mount your workspace from the host. Without cache isolation, build artifacts end up on your local drive.

| Cache | Strategy | Location | Lifetime |
|-------|----------|----------|----------|
| `node_modules` | Named Docker volume | Container volume | Persists across rebuilds |
| `.next` | Anonymous Docker volume | Container volume | Wiped on rebuild |
| `.turbo` | `TURBO_CACHE_DIR` env var | `/tmp/.turbo` | Wiped on rebuild |
| `.pnpm-store` | `store-dir` in `.npmrc` | `~/.local/share/pnpm/store` | Wiped on rebuild |
| bun cache | `BUN_INSTALL_CACHE_DIR` env var | `/tmp/.bun-cache` | Wiped on rebuild |

```jsonc
"mounts": [
  "source=my-project-node-modules,target=${containerWorkspaceFolder}/node_modules,type=volume",
  "target=${containerWorkspaceFolder}/apps/web/.next,type=volume"
]
```

## AI credential management

Mount AI config directories from your host to persist authentication across container rebuilds:

```jsonc
"mounts": [
  "source=${localEnv:HOME}/.claude,target=/home/vscode/.claude,type=bind,consistency=cached",
  "source=${localEnv:HOME}/.claude.json,target=/home/vscode/.claude.json,type=bind,consistency=cached",
  "source=${localEnv:HOME}/.gemini,target=/home/vscode/.gemini,type=bind,consistency=cached",
  "source=${localEnv:HOME}/.codex,target=/home/vscode/.codex,type=bind,consistency=cached"
]
```

For API keys, use your editor's secrets management or a `.env` file excluded from version control. Never bake API keys into the image.

## Git & SSH

```jsonc
"mounts": [
  "source=${localEnv:HOME}/.gitconfig,target=/home/vscode/.gitconfig,type=bind,consistency=cached",
  "source=${localEnv:HOME}/.gnupg,target=/home/vscode/.gnupg,type=bind,consistency=cached"
]
```

SSH agent forwarding is handled automatically by VS Code. For CI or non-VS Code editors:

```jsonc
"source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,readonly"
```

## Auto-detected setup

The embedded setup script (`/usr/local/share/devcontainer/setup.sh`) runs automatically:

| Signal | Action |
|--------|--------|
| `pnpm-lock.yaml` | Enables corepack, activates pnpm, runs `pnpm install` |
| `bun.lock` / `bun.lockb` | Cleans stale symlinks, runs `bun install` |
| `package-lock.json` | Runs `npm install` |
| `yarn.lock` | Runs `yarn install` |
| `supabase/config.toml` | Starts Supabase local dev stack |
| `TINYBIRD=1` env var | Starts Tinybird local container |
| `.devcontainer/post-setup.sh` | Runs project-specific setup |

## Corporate / enterprise

### Custom CA certificates

```dockerfile
FROM ghcr.io/zanreal-labs/devcontainer:latest
COPY my-corporate-ca.crt /usr/local/share/ca-certificates/extra/
RUN update-ca-certificates
```

### Custom DNS

```jsonc
"runArgs": ["--dns", "10.0.0.1", "--dns", "1.1.1.1"]
```

### Extending with post-setup.sh

```bash
#!/bin/bash
# .devcontainer/post-setup.sh
docker compose up -d redis
pnpm db:migrate
```

## License

MIT
