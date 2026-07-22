# Documentation

Long-form documentation for the `ghcr.io/zanreal-labs/devcontainer` image and
the features published alongside it, kept in the repository so it versions with
the `Dockerfile`, `setup.sh` and `src/` it describes.

These pages are also the source for the rendered documentation at
**<https://zanreal.com/docs>**. The site pulls this directory; there is no
second copy to keep in sync. Edit the files here.

## Layout

| File                        | Contents                                                             |
| --------------------------- | -------------------------------------------------------------------- |
| `index.{en,pl}.mdx`         | What the image is, quick start, what it ships, the setup wizard      |
| `features.{en,pl}.mdx`      | The ten published features, feature vs wizard, Traefik reverse proxy |
| `configuration.{en,pl}.mdx` | What `setup.sh` does on every start, cache isolation, image tags     |
| `meta.json`                 | Page order and section title for the docs site (English)             |
| `meta.pl.json`              | The same, for Polish                                                 |

The `.en` and `.pl` suffixes carry the locale. Each locale is written
independently rather than translated, so the two versions differ in structure
and emphasis by design.

`meta.json` is consumed by the docs site to order pages within the section. It
has no effect when reading these files on GitHub, and nothing else in the
repository depends on it.

## Conventions

- **Links between pages are relative** (`./features.en.mdx`), so they resolve
  both on GitHub and on the docs site. Links to files elsewhere in the repo, such
  as `examples/devcontainer.json`, use absolute GitHub URLs for the same reason.
- **Plain Markdown only.** These pages are read on GitHub at least as often as
  on the docs site, so they avoid renderer-specific MDX components. Callouts use
  GitHub's `> [!NOTE]` and `> [!WARNING]` syntax, which renders natively in both
  places.
- Behaviour described here is taken from `setup.sh`, `wizard.sh` and the feature
  definitions in `src/`. When you change those, change these.

## README or docs?

`README.md` is the landing page: what the image is and enough configuration to
get a container running. This directory is where behaviour is documented in
full - the setup sequence step by step, every feature option, and the failure
modes that only turn up in real use.
