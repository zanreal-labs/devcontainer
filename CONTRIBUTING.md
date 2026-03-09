# Contributing

## Development

1. Fork and clone the repository
2. Make changes to `Dockerfile` or `setup.sh`
3. Test locally:
   ```bash
   docker buildx build --tag devcontainer:local .
   ```

## Releasing

Releases are fully automated via GitHub Actions. Pushing a version tag builds the multi-arch image (amd64 + arm64), pushes it to GHCR, and creates a GitHub Release.

```bash
# Tag a new version
git tag v1.2.0
git push origin v1.2.0
```

This produces the following image tags on `ghcr.io/zanreal-labs/devcontainer`:

| Tag | Example | Description |
|-----|---------|-------------|
| `latest` | `latest` | Always points to the newest release |
| `{{version}}` | `1.2.0` | Exact version |
| `{{major}}.{{minor}}` | `1.2` | Tracks patch updates |
| `{{major}}` | `1` | Tracks minor + patch updates |

## Versioning

Follow [Semantic Versioning](https://semver.org/):

- **Patch** (`v1.0.1`) — tool version bumps, bug fixes
- **Minor** (`v1.1.0`) — new tools added, non-breaking changes to setup.sh
- **Major** (`v2.0.0`) — breaking changes to Dockerfile base, removed tools, setup.sh interface changes

## Package visibility

The GHCR package must be set to **Public** for external consumers. This is configured in:
`https://github.com/orgs/zanreal-labs/packages/container/devcontainer/settings`
