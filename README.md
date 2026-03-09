# @zanreal/devcontainer

A batteries-included dev container image for modern TypeScript/JavaScript projects. Ships with AI coding assistants, infrastructure CLIs, and cache isolation out of the box.

## What's included

| Category | Tools |
|----------|-------|
| **AI assistants** | Claude Code, Gemini CLI, OpenAI Codex |
| **Infrastructure** | Supabase CLI, Tinybird CLI, Stripe CLI |
| **Runtimes** | Bun (Node.js added via devcontainer feature) |
| **Extras** | Docker credential fix, uv (Python) |

## Quick start

**1. Copy `setup.sh` and the example config into your project:**

```
.devcontainer/
├── devcontainer.json
└── setup.sh          # from this repo
```

**2. Reference the image in your `devcontainer.json`:**

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

See [`examples/devcontainer.json`](examples/devcontainer.json) for a full annotated config.

## Cache isolation

Dev containers bind-mount your workspace from the host. Without cache isolation, build artifacts (`.next`, `.turbo`, `.pnpm-store`, `node_modules`) end up on your local drive. This image solves that:

| Cache | Strategy | Where it goes |
|-------|----------|---------------|
| `node_modules` | Named Docker volume | Persists across rebuilds, never on host |
| `.next` | Anonymous Docker volume | Ephemeral, wiped on rebuild |
| `.turbo` | `TURBO_CACHE_DIR` env var | `/tmp/.turbo` inside container |
| `.pnpm-store` | `store-dir` in `.npmrc` | `/home/vscode/.local/share/pnpm/store` |
| bun cache | `BUN_INSTALL_CACHE_DIR` env var | `/tmp/.bun-cache` inside container |

## Auto-detected setup

`setup.sh` auto-detects your project and runs the right setup:

- **Package manager**: detects `pnpm-lock.yaml`, `bun.lock`, `package-lock.json`, or `yarn.lock`
- **Supabase**: starts automatically if `supabase/config.toml` exists
- **Tinybird**: starts if `TINYBIRD=1` env var is set
- **Project hook**: runs `.devcontainer/post-setup.sh` if it exists (for migrations, Redis, etc.)

## Build args

When building locally instead of using the prebuilt image:

| Arg | Default | Description |
|-----|---------|-------------|
| `BUN_VERSION` | `latest` | Bun version to install |
| `STRIPE_CLI` | `true` | Set to `false` to skip Stripe CLI |

```jsonc
{
  "build": {
    "dockerfile": "Dockerfile",
    "args": { "STRIPE_CLI": "false" }
  }
}
```

## License

MIT
