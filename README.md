# tbarabosch.com

Source for [tbarabosch.com](https://tbarabosch.com/), a static Jekyll site published through GitHub Pages from `main`.

The site uses a Unix/BSD manpage-inspired design: serif long-form text, monospace navigation and metadata, compact section hierarchy, and minimal client-side behavior.

## Requirements

- macOS with the Apple Containers `container` CLI installed
- Apple Containers available to start locally
- Git
- Network access when the container image or Ruby gems must be downloaded

Ruby, Bundler, and Jekyll must not be installed or run directly on the host.

## Initial setup

Clone the repository, enable its Git hooks, and run the first build:

```bash
git clone https://github.com/tbarabosch/tbarabosch.github.io.git
cd tbarabosch.github.io
scripts/install-hooks.sh
scripts/build-site.sh
```

The hook installer configures this checkout to use `.githooks/`. It refuses to replace an existing custom `core.hooksPath` or legacy `.git/hooks/pre-commit` hook.

## Build and validation

The canonical build command is:

```bash
scripts/build-site.sh
```

The script starts Apple Containers when necessary, builds the local Ruby image, installs the locked dependencies inside the container, and runs Jekyll with tracing enabled. Generated output is written to `_site/` and is ignored by Git.

To override the local image name:

```bash
IMAGE_NAME=my-jekyll-image scripts/build-site.sh
```

Do not fall back to host `bundle`, `jekyll`, `gem install`, or other host Ruby commands when Apple Containers is unavailable.

The tag generator and generated-site validator are dependency-free. Run them inside the image created by the canonical build:

```bash
container run --rm \
  --volume "$PWD:/workspace" \
  --workdir /workspace \
  tbarabosch-github-io-jekyll \
  bash -lc 'scripts/test-update-tags.sh && ruby scripts/validate-site.rb'
```

If `IMAGE_NAME` was overridden for the build, use that image name for the test container as well.

## Git hooks and tags

Enable the repository hooks once per checkout:

```bash
scripts/install-hooks.sh
```

The pre-commit hook:

1. Reads post front matter from the staged Git index.
2. Regenerates `_data/tags.yml`.
3. Stages the generated tag catalog with the commit.

Every tag used by a post is included in the public tag index, including tags used once. `_data/tags.yml` is generated and must not be edited manually.

Post tags must use a YAML block list:

```yaml
tags:
  - malware analysis
  - reverse engineering
  - YARA
```

Inline tag arrays and empty tag lists are rejected. Useful maintenance commands are:

```bash
scripts/update-tags.sh
scripts/update-tags.sh --check
scripts/update-tags.sh --staged
```

Normal editing uses the first command. CI-style validation uses `--check`; the pre-commit hook uses `--staged` so unstaged post changes cannot leak into the commit.

## Repository layout

| Path | Purpose |
| --- | --- |
| `_posts/` | Blog posts named `YYYY-MM-DD-post-slug.md` |
| `_layouts/` | Shared page and post layouts |
| `_includes/` | Header, footer, and reusable Liquid fragments |
| `_sass/_bsd-manpage.scss` | Main visual system and responsive styles |
| `assets/css/style.scss` | Jekyll Sass entry point |
| `_data/tags.yml` | Generated public tag catalog |
| `_data/topics.yml` | Curated expertise areas and their matching tags |
| `_data/social.json` | Offsite link metadata |
| `assets/images/posts/<post-slug>/` | Local images belonging to a post |
| `assets/files/` | Downloadable documents referenced by the site |
| `scripts/` | Build, hook-installation, and tag-maintenance scripts |
| `.githooks/` | Repository-managed Git hooks |

## Writing posts

Create posts under `_posts/` with standard front matter:

```yaml
---
title: 'Example post title'
date: '2026-07-27T10:00:00+02:00'
last_modified_at: '2026-07-27T10:00:00+02:00'
author: tbarabosch
layout: post
tags:
  - systems security
  - reverse engineering
---
```

Keep `last_modified_at` equal to the publication date until the article receives a substantive technical revision. Every post except intentionally topic-neutral `site notes` must match at least one tag in `_data/topics.yml`.

For long posts with at least two sections, opt into Kramdown's build-time contents list:

```yaml
toc: true
```

Insert the standard `CONTENTS` block after the excerpt separator. It remains usable without JavaScript; the local script only adds heading permalinks and reading conveniences.

Use local post images with absolute site paths:

```markdown
![Descriptive alternative text](/assets/images/posts/example-post/image.png)
```

Do not introduce `wp-content/` asset paths. Legacy external citation URLs containing that segment may remain when they are the original research source.

### Code fences

- Use `bash` for executable shell snippets.
- Use `console` for commands mixed with their output.
- Use `text` for raw output, directory trees, hex tables, and ASCII diagrams.
- Use another Rouge language supported by the pinned `github-pages` bundle for source code.
- Keep Markdown and HTML annotations outside fenced source.

Rouge 3.30 does not include a YARA lexer. Use a `c` fence followed by a display-language attribute:

````markdown
```c
rule Example {
    condition:
        true
}
```
{: data-language="YARA" }
````

## Design conventions

Preserve the Unix/BSD manpage hybrid rather than introducing a generic blog theme.

- Favor content density, readable line lengths, and explicit section hierarchy.
- Keep the palette monochrome by default.
- Use serif body text and monospace navigation, headings, metadata, and code.
- Use simple rules, aligned metadata, and restrained ASCII-inspired markers.
- Avoid gradients, decorative cards, hero imagery, accent themes, and new rounded surfaces.
- Do not add remote fonts, icon fonts, remote scripts, or JavaScript for basic navigation.
- Keep navigation and layouts usable without JavaScript at narrow widths.

Tag pills and the small inline SVG contact icons are intentional existing components. New graphical conventions should remain equally restrained.

## Repository hygiene and publishing

Before editing or committing, inspect the working tree:

```bash
git status --short --branch
```

Before publishing a change, run the relevant script tests and the canonical build:

```bash
scripts/build-site.sh
container run --rm \
  --volume "$PWD:/workspace" \
  --workdir /workspace \
  tbarabosch-github-io-jekyll \
  bash -lc 'scripts/test-update-tags.sh && ruby scripts/validate-site.rb'
```

Do not commit `_site/`, Jekyll caches, local Bundler state, or `vendor/bundle/`. Keep changes focused, preserve external research citations, and never add secrets, credentials, trackers, or live malware samples.

The public site is deployed from `main` by GitHub Pages:

```bash
git push origin main
```

## License

See [LICENSE.md](LICENSE.md).
