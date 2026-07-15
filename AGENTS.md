# Agent Guidelines

## Project
- This repository is the static Jekyll/GitHub Pages site for `tbarabosch.github.io`.
- The public site is published from `main`.
- Keep changes focused on the static site, its content, and its local build workflow.

## Local Runtime
- Use Apple Containers as the only local build and validation boundary.
- The canonical validation command is:
  ```bash
  scripts/build-site.sh
  ```
- Do not run host `bundle`, `jekyll`, `gem install`, or other host Ruby dependency commands.
- If the `container` CLI or Apple Containers runtime is unavailable, report that blocker instead of falling back to host Ruby.

## Repository Hygiene
- Check `git status --short --branch` before editing.
- Preserve user changes and keep edits scoped to the requested task.
- Do not commit generated files such as `_site/`, `.jekyll-cache/`, `.jekyll-metadata`, `.sass-cache/`, `.bundle/`, or `vendor/bundle/`.
- Do not add heavyweight dependencies or new build systems unless explicitly requested.

## Site Structure
- `_posts/` contains blog posts.
- `_layouts/` and `_includes/` contain Liquid templates.
- `_sass/_bsd-manpage.scss` and `assets/css/style.scss` contain styling.
- The site should not need JavaScript or icon fonts for layout, navigation, or social links.
- `_data/social.json` contains offsite link metadata.
- Post images belong in `assets/images/posts/<post-slug>/`.

## Design Style
- Preserve the Unix/BSD manpage hybrid style: content density, readable line length, and clear section hierarchy matter more than decorative UI.
- Use monochrome styling by default. Do not add accent-color themes, gradients, cards, rounded decorative surfaces, or hero imagery.
- Use ASCII-inspired structure only: section labels, aligned metadata, and simple rules. Do not ship fragile ASCII box art in responsive UI.
- Keep typography hybrid: readable serif body text with monospace chrome, metadata, headings, and code.
- Avoid new frontend dependencies, remote fonts, remote scripts, icon fonts, or JavaScript for basic navigation.

## Media Rules
- Do not add or reintroduce `wp-content/` paths.
- Reference local post images with absolute site paths under `/assets/images/posts/<post-slug>/`.
- Keep only assets that are actually used by the site.

## Publishing Safety
- Do not add secrets, credentials, live malware samples, external trackers, or new remote scripts without explicit approval.
- Preserve external research citations, even when the remote URL includes legacy path segments such as `wp-content/uploads`.
