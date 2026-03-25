# devcontainer

A modular, AI-first dev container for modern software development. A slim base image with an interactive setup wizard and opt-in features for the tools you actually use.

## Why

AI coding agents (Claude Code, Gemini CLI, OpenCode, Codex) need a consistent, reproducible environment to work effectively. When agents run in inconsistent local setups, they hit missing tools, broken PATHs, and permission errors. Dev containers solve this by giving every developer — and every AI agent — the same deterministic environment.

This image is designed around three principles:

1. **AI-first** — every major coding agent is available via the setup wizard
2. **Modular** — slim base image, add only the tools you need via features or the wizard
3. **Zero cache leakage** — build artifacts stay in the container, never pollute your host drive

## Quick start

Add a `devcontainer.json` to your project:

```jsonc
{
  "image": "ghcr.io/zanreal-labs/devcontainer:latest",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": { "moby": false },
    "ghcr.io/devcontainers/features/node:1": { "version": "22" },
    "ghcr.io/zanreal-labs/devcontainer/bun:1": {},
    "ghcr.io/zanreal-labs/devcontainer/supabase-cli:1": {}
  },
  "postCreateCommand": "bash /usr/local/share/devcontainer/setup.sh"
}
```

Open in VS Code or any devcontainer-compatible editor. The setup wizard will run on first start and let you pick which AI agents and tools to install.

See [`examples/devcontainer.json`](examples/devcontainer.json) for a fully annotated configuration.

## What's included

### Base image (always included)

| Category | Tools |
|----------|-------|
| **TUI** | Interactive setup wizard ([gum](https://github.com/charmbracelet/gum)), tmux |
| **Security** | GPG commit signing (macOS path fix), SSH agent forwarding, Docker credential isolation |
| **System** | Custom CA certificate support, embedded setup & wizard scripts |

### Setup wizard

On first container start, the wizard presents an interactive menu for installing tools. Re-run anytime with `devcontainer-wizard --force`.

**AI coding agents:** Claude Code, OpenCode, Gemini CLI (requires Node.js), OpenAI Codex (requires Node.js)

**Package managers:** bun, uv

**Infrastructure:** Supabase CLI, Tinybird CLI, Stripe CLI, GitHub CLI

For headless/CI environments, set `DEVCONTAINER_TOOLS` to skip the interactive prompt:

```jsonc
"containerEnv": {
  "DEVCONTAINER_TOOLS": "claude-code,bun,uv"
}
```

### Optional features (add to `devcontainer.json`)

| Feature | ID | Description |
|---------|----|-------------|
| **Bun** | `ghcr.io/zanreal-labs/devcontainer/bun:1` | Fast JavaScript runtime and package manager |
| **uv** | `ghcr.io/zanreal-labs/devcontainer/uv:1` | Fast Python package manager and toolchain |
| **Supabase CLI** | `ghcr.io/zanreal-labs/devcontainer/supabase-cli:1` | Local Supabase development stack |
| **Stripe CLI** | `ghcr.io/zanreal-labs/devcontainer/stripe-cli:1` | Payment integration development |
| **Tinybird CLI** | `ghcr.io/zanreal-labs/devcontainer/tinybird-cli:1` | Real-time analytics (auto-installs uv) |
| **Traefik** | `ghcr.io/zanreal-labs/devcontainer/traefik:1` | Reverse proxy with subdomain routing |

Features are installed at image build time and are available immediately. Use features for tools your project always needs, and the wizard for personal preferences.

## Traefik reverse proxy

Route local dev servers through clean `.localhost` domains with automatic HTTPS.

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

The `defaultApp` is served on the root domain. All other apps get `<name>.<domain>` subdomains. Requires Docker-in-Docker feature.

Traefik starts automatically during setup. You can also manage it manually:

```bash
traefik-start   # start the proxy
traefik-stop    # stop the proxy
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `domain` | `app.localhost` | Base domain for routing |
| `routes` | `""` | Comma-separated `name:port` pairs |
| `defaultApp` | `""` | App name served on the root domain |

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

## Git & SSH

```jsonc
"mounts": [
  "source=${localEnv:HOME}/.gitconfig,target=/tmp/.host-gitconfig,type=bind,consistency=cached",
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
| Traefik feature installed | Starts Traefik reverse proxy |
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
