# devcontainer

A production-ready dev container image built for AI-assisted software development. One image gives every developer on your team an identical environment with AI coding agents, infrastructure CLIs, and zero-config cache isolation — ready in minutes, not hours.

## Why

AI coding agents (Claude Code, Gemini CLI, Codex, Aider) need a consistent, reproducible environment to work effectively. When agents run in inconsistent local setups, they hit missing tools, broken PATHs, and permission errors. Dev containers solve this by giving every developer — and every AI agent — the same deterministic environment.

This image is designed around three principles:

1. **AI-first** — every major coding agent is pre-installed and configured
2. **Zero cache leakage** — build artifacts stay in the container, never pollute your host drive
3. **Convention over configuration** — auto-detects your project setup, just add a `devcontainer.json`

## What's included

| Category | Tools |
|----------|-------|
| **AI coding agents** | [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [Gemini CLI](https://github.com/google/gemini-cli), [OpenAI Codex](https://github.com/openai/codex) |
| **Infrastructure** | [Supabase CLI](https://supabase.com/docs/reference/cli), [Tinybird CLI](https://www.tinybird.co/docs/cli), [Stripe CLI](https://docs.stripe.com/stripe-cli) |
| **Runtimes** | [Bun](https://bun.sh), Node.js (via devcontainer feature), [uv](https://docs.astral.sh/uv/) (Python) |
| **Security** | GPG commit signing, SSH agent forwarding, Docker credential isolation |

## Quick start

**1. Copy `setup.sh` into your project:**

```
.devcontainer/
├── devcontainer.json
├── setup.sh            # from this repo
└── post-setup.sh       # optional, project-specific steps
```

**2. Add a `devcontainer.json`:**

```jsonc
{
  "image": "ghcr.io/zanreal-labs/devcontainer:latest",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": { "moby": false },
    "ghcr.io/devcontainers/features/node:1": { "version": "22" }
  },
  "postCreateCommand": "bash .devcontainer/setup.sh"
}
```

**3. Open in VS Code** or any devcontainer-compatible editor. Done.

See [`examples/devcontainer.json`](examples/devcontainer.json) for a fully annotated configuration.

## Cache isolation

Dev containers bind-mount your workspace from the host. Without cache isolation, build artifacts end up on your local drive — eating disk space and causing cross-platform inconsistencies.

This image redirects every cache to container-local storage:

| Cache | Strategy | Location | Lifetime |
|-------|----------|----------|----------|
| `node_modules` | Named Docker volume | Container volume | Persists across rebuilds |
| `.next` | Anonymous Docker volume | Container volume | Wiped on rebuild |
| `.turbo` | `TURBO_CACHE_DIR` env var | `/tmp/.turbo` | Wiped on rebuild |
| `.pnpm-store` | `store-dir` in `.npmrc` | `~/.local/share/pnpm/store` | Wiped on rebuild |
| bun cache | `BUN_INSTALL_CACHE_DIR` env var | `/tmp/.bun-cache` | Wiped on rebuild |

Add volume mounts in your `devcontainer.json`:

```jsonc
"mounts": [
  // Named volume — persists across rebuilds
  "source=my-project-node-modules,target=${containerWorkspaceFolder}/node_modules,type=volume",

  // Anonymous volumes — clean on every rebuild (one per Next.js app)
  "target=${containerWorkspaceFolder}/apps/web/.next,type=volume"
]
```

## AI credential management

AI agents authenticate via config files on your host. Mount them into the container so you don't have to re-authenticate after every rebuild:

```jsonc
"mounts": [
  // Claude Code
  "source=${localEnv:HOME}/.claude,target=/home/vscode/.claude,type=bind,consistency=cached",
  "source=${localEnv:HOME}/.claude.json,target=/home/vscode/.claude.json,type=bind,consistency=cached",

  // Gemini CLI
  "source=${localEnv:HOME}/.gemini,target=/home/vscode/.gemini,type=bind,consistency=cached",

  // OpenAI Codex
  "source=${localEnv:HOME}/.codex,target=/home/vscode/.codex,type=bind,consistency=cached"
]
```

For API keys (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, etc.), use your editor's secrets management or a `.env` file excluded from version control. Never bake API keys into the image.

## Git & SSH

The image supports GPG commit signing and SSH agent forwarding out of the box:

```jsonc
"mounts": [
  // Git config (aliases, user identity, signing config)
  "source=${localEnv:HOME}/.gitconfig,target=/home/vscode/.gitconfig,type=bind,consistency=cached",

  // GPG keys for commit signing
  "source=${localEnv:HOME}/.gnupg,target=/home/vscode/.gnupg,type=bind,consistency=cached"
]
```

SSH agent forwarding is handled automatically by VS Code and the devcontainers CLI — no manual mount needed. For explicit SSH key access (CI environments, non-VS Code editors):

```jsonc
"source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh,type=bind,readonly"
```

## Auto-detected setup

`setup.sh` detects your project and runs the right setup automatically:

| Signal | Action |
|--------|--------|
| `pnpm-lock.yaml` | Enables corepack, activates pnpm, runs `pnpm install` |
| `bun.lock` / `bun.lockb` | Cleans stale symlinks, runs `bun install` |
| `package-lock.json` | Runs `npm install` |
| `yarn.lock` | Runs `yarn install` |
| `supabase/config.toml` | Starts Supabase local dev stack |
| `TINYBIRD=1` env var | Starts Tinybird local container |
| `.devcontainer/post-setup.sh` | Runs project-specific setup (migrations, Redis, etc.) |

A health check runs at the end to verify all tools are available:

```
==> Verifying tools...
    node     v22.14.0
    bun      1.2.5
    claude   2.1.71
    supabase 2.20.0
    docker   28.0.1
    uv       0.6.12
```

## Corporate / enterprise environments

### Custom CA certificates

For environments behind corporate proxies with custom root certificates:

```dockerfile
FROM ghcr.io/zanreal-labs/devcontainer:latest
COPY my-corporate-ca.crt /usr/local/share/ca-certificates/extra/
RUN update-ca-certificates
```

### Private registries

Use the devcontainer features mechanism to authenticate with private npm/container registries, or add credentials via `post-setup.sh`.

### Custom DNS

Override DNS resolution for internal services:

```jsonc
"runArgs": [
  "--dns", "10.20.0.1",
  "--dns", "1.1.1.1"
]
```

## Build args

When building locally instead of using the prebuilt image:

| Arg | Default | Description |
|-----|---------|-------------|
| `BUN_VERSION` | latest | Bun version to install |
| `STRIPE_CLI` | `true` | Set to `false` to skip Stripe CLI |

```jsonc
{
  "build": {
    "dockerfile": "Dockerfile",
    "args": { "STRIPE_CLI": "false", "BUN_VERSION": "1.2.5" }
  }
}
```

## Extending the image

Add project-specific tools by extending the base image:

```dockerfile
FROM ghcr.io/zanreal-labs/devcontainer:latest

# Add your tools
RUN apt-get update && apt-get install -y postgresql-client && rm -rf /var/lib/apt/lists/*
```

Or use the `post-setup.sh` hook for runtime setup:

```bash
#!/bin/bash
# .devcontainer/post-setup.sh
echo "==> Starting Redis..."
docker compose up -d redis

echo "==> Running migrations..."
pnpm db:migrate
```

## License

MIT
