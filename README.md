# devcontainer

A modular, AI-first dev container for modern software development. A slim base image with an interactive setup wizard that lets each developer pick their own tools.

## Why

AI coding agents (Claude Code, Gemini CLI, OpenCode, Codex) need a consistent, reproducible environment to work effectively. When agents run in inconsistent local setups, they hit missing tools, broken PATHs, and permission errors. Dev containers solve this by giving every developer — and every AI agent — the same deterministic environment.

This image is designed around three principles:

1. **AI-first** — every major coding agent is available via the setup wizard
2. **Modular** — slim base image, pick only the tools you need on first start
3. **Zero cache leakage** — build artifacts stay in the container, never pollute your host drive

## Quick start

Add a `devcontainer.json` to your project:

```jsonc
{
  "image": "ghcr.io/zanreal-labs/devcontainer:latest",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": { "moby": false },
    "ghcr.io/devcontainers/features/node:1": { "version": "22" }
  },
  "postCreateCommand": "bash /usr/local/share/devcontainer/setup.sh"
}
```

Open in VS Code or any devcontainer-compatible editor. On first start, the setup wizard will guide you through selecting AI agents and tools.

See [`examples/devcontainer.json`](examples/devcontainer.json) for a fully annotated configuration.

## What's included

### Base image

| Component | Description |
|-----------|-------------|
| **Setup wizard** | Interactive TUI for picking tools on first container start |
| **Setup script** | Auto-detects package manager, starts services, runs project hooks |
| **GPG** | Commit signing with macOS path fix and loopback pinentry |
| **SSH** | Agent forwarding from host |
| **Docker credentials** | Pre-configured to avoid DinD credential errors |
| **CA certificates** | Directory for custom corporate proxy certs |
| **tmux** | Terminal multiplexer with default config |

### Setup wizard

The wizard runs automatically on first container start. It presents an interactive TUI (powered by [gum](https://github.com/charmbracelet/gum)) where you select which tools to install:

```
╔══════════════════════════════════════╗
║                                      ║
║   Dev Container Setup Wizard         ║
║                                      ║
║   Select the tools you want          ║
║   installed.                         ║
║   Use space to toggle, enter to      ║
║   confirm.                           ║
║                                      ║
╚══════════════════════════════════════╝

[ ] Claude Code
[ ] OpenCode
[ ] Gemini CLI
[ ] OpenAI Codex
[ ] bun
[ ] uv
[ ] Supabase CLI
[ ] Tinybird CLI
[ ] Stripe CLI
[ ] GitHub CLI
```

Re-run anytime with:

```bash
devcontainer-wizard --force
```

#### Headless / CI mode

Skip the interactive prompt by setting `DEVCONTAINER_TOOLS`:

```jsonc
"containerEnv": {
  "DEVCONTAINER_TOOLS": "claude-code,bun,uv,supabase-cli"
}
```

Available tool names: `claude-code`, `opencode`, `gemini-cli`, `openai-codex`, `bun`, `uv`, `supabase-cli`, `tinybird-cli`, `stripe-cli`, `github-cli`

## Traefik reverse proxy

Route local dev servers through clean `.localhost` domains with automatic HTTPS. This is a devcontainer feature because it generates config at build time.

```jsonc
"features": {
  "ghcr.io/zanreal-labs/devcontainer/traefik:1": {
    "domain": "myapp.localhost",
    "routes": "web:3000,api:4000",
    "defaultApp": "web"
  }
}
```

This produces:

| URL | Target |
|-----|--------|
| `https://myapp.localhost` | `:3000` (web — default app) |
| `https://api.myapp.localhost` | `:4000` |

The `defaultApp` is served on the root domain. All other apps get `<name>.<domain>` subdomains.

Traefik starts automatically during setup. Manual control:

```bash
traefik-start   # start the proxy
traefik-stop    # stop the proxy
```

| Option | Default | Description |
|--------|---------|-------------|
| `domain` | `app.localhost` | Base domain for routing |
| `routes` | `""` | Comma-separated `name:port` pairs |
| `defaultApp` | `""` | App name served on the root domain |

Requires the `docker-in-docker` feature. Works with any dev server (Next.js, Vite, etc.) running inside the container — Traefik routes via `host.docker.internal`.

## Auto-detected setup

The setup script runs automatically via `postCreateCommand`:

| Signal | Action |
|--------|--------|
| `pnpm-lock.yaml` | Enables corepack, activates pnpm, runs `pnpm install` |
| `bun.lock` / `bun.lockb` | Cleans stale symlinks, runs `bun install` |
| `package-lock.json` | Runs `npm install` |
| `yarn.lock` | Runs `yarn install` |
| `supabase/config.toml` | Starts Supabase local dev stack |
| `TINYBIRD=1` env var | Starts Tinybird local container |
| Traefik feature installed | Starts Traefik reverse proxy |
| `.devcontainer/post-setup.sh` | Runs project-specific setup |

## Cache isolation

Build artifacts stay inside the container, never on your host drive.

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

## Git & SSH

```jsonc
"mounts": [
  "source=${localEnv:HOME}/.gitconfig,target=/tmp/.host-gitconfig,type=bind,consistency=cached",
  "source=${localEnv:HOME}/.gnupg,target=/tmp/.host-gnupg,type=bind,consistency=cached",
  "source=${localEnv:HOME}/.ssh,target=/tmp/.host-ssh,type=bind,consistency=cached"
]
```

The setup script copies these from `/tmp` staging mounts to `$HOME` with correct permissions. This avoids "Device busy" errors with direct bind mounts.

SSH agent forwarding is handled automatically by VS Code. For non-VS Code editors:

```jsonc
"containerEnv": { "SSH_AUTH_SOCK": "/tmp/ssh-agent.sock" },
"mounts": [
  "source=${localEnv:SSH_AUTH_SOCK},target=/tmp/ssh-agent.sock,type=bind"
]
```

## Extending

### Project-specific setup

Create `.devcontainer/post-setup.sh` — it runs automatically after the main setup:

```bash
#!/bin/bash
docker compose up -d redis
pnpm db:migrate
```

### Custom CA certificates (corporate proxies)

```dockerfile
FROM ghcr.io/zanreal-labs/devcontainer:latest
COPY my-corporate-ca.crt /usr/local/share/ca-certificates/extra/
RUN update-ca-certificates
```

### Custom DNS

```jsonc
"runArgs": ["--dns", "10.0.0.1", "--dns", "1.1.1.1"]
```

## License

MIT
