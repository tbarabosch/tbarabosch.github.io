# Agent Guidelines

## Purpose and Authority

- This repository is the static Jekyll/GitHub Pages site for
  `tbarabosch.com`.
- The site demonstrates Thomas Barabosch's technical expertise and shares
  durable knowledge with the cyber security and systems communities.
- Treat this file as the complete agent contract for editorial work, site
  changes, validation, and handoff. `README.md` remains the human-facing
  project guide.
- The public site is published from `main`. Do not infer a branch, commit,
  push, pull-request, or merge workflow; follow the current task's explicit
  Git instructions.
- Keep changes focused on the static site, its content, and its local build
  workflow. Do not introduce a different publishing platform, theme system,
  or application stack unless explicitly requested.

## Before Any Work

- Run `git status --short --branch` before editing.
- Inspect the relevant implementation, content, and current diff before
  deciding what to change.
- `ideas.md` is a local editorial notebook. Never stage, commit, publish, or
  otherwise add it to the Git repository.
- Preserve all user changes, including untracked files. Never assume that an
  unrelated draft, generated-looking file, or partial edit is disposable.
- Do not rewrite published prose during layout, metadata, taxonomy, tooling,
  or mechanical maintenance work. Editorial changes require explicit task
  scope.
- When editorial changes are requested, preserve the article's meaning,
  citations, examples, and authorial stance. Surface any material factual
  reinterpretation for author review.
- Preserve existing publication dates, permalinks, and external research
  citations unless the task explicitly requires changing them.

## Editorial Audience and Language

- Write for experienced security and systems practitioners who may work in an
  adjacent specialty rather than the article's exact niche.
- Explain uncommon mechanisms, assumptions, system boundaries, and relevant
  domain terms. Do not pad an article with basic computing or security
  instruction unless the argument depends on it.
- Prefer technical precision and useful context over introductory filler.
- Use American English for new or materially revised prose. Do not normalize
  untouched historical articles merely to change spelling or punctuation.
- Use `cyber security` when referring to the broad field unless a proper name,
  quotation, or established compound requires different spelling.

## Canonical Writing Voice

- Write as an experienced practitioner explaining what was done, what the
  evidence shows, how the mechanism works, which tradeoffs matter, and where
  the result stops.
- Keep the voice direct, technically grounded, and personal without becoming
  promotional. Favor precise nouns and verbs, active constructions where
  natural, and paragraphs centered on one technical idea.
- Prefer second person for reader actions, generic procedures, and explanations
  of how an API is used. Prefer a neutral construction when no actor matters.
  Reserve first person for actions, findings, measurements, experience, or
  opinions supported by author notes, repository artifacts, or other evidence.
  Never invent an action, anecdote, judgment, result, or belief to make prose
  sound personal.
- Preserve restrained personality: dry humor, blunt phrasing, rhetorical
  questions, and short anecdotes are welcome when they help the explanation.
  Do not make victims, sensitive incidents, or unsupported claims the joke.
- Vary sentence and paragraph length naturally. Short sentences may emphasize
  a real point; do not manufacture punchiness throughout an article.
- Use concrete technical artifacts such as code, commands, diagrams,
  screenshots, commits, patches, and source excerpts when they materially
  support the explanation.
- State what a piece of evidence proves and what it does not prove. Prefer a
  narrow, defensible conclusion over a broad claim.

### Voice Calibration

- Before drafting or materially rewriting an article, read at least one recent
  hands-on reference and one historical technical reference. Skip this only
  for metadata-only or mechanical changes.
- Recent hands-on references include:
  - `_posts/2026-08-11-trap-fuzzing.md`
  - `_posts/2026-08-12-detecting-apple-container-from-inside-the-guest.md`
- Historical technical references include:
  - `_posts/2020-12-23-detect-rc4-encryption-in-malicious-binaries.md`
  - `_posts/2020-12-28-never-upload-ransomware-samples-to-the-internet.md`
  - `_posts/2021-01-22-malware-analyst-guide-to-pe-timestamps.md`
- Learn from their directness, practical artifacts, anecdotes, mild
  irreverence, and technical depth. Do not copy historical grammar mistakes,
  outdated claims, or terminology merely because they appear in an older post.
- Do not use the newer conceptual or AI-workflow essays as the primary cadence
  template. They may still be used for facts, citations, or structural context.

### Article Shape

- Use a concrete sentence-case title that identifies the problem, mechanism,
  experiment, or conclusion. Restrained wordplay is acceptable when the
  technical subject remains clear.
- Open with the concrete problem, observation, action, or result and establish
  why it matters before providing general background.
- Make the introduction self-contained, then place `<!--more-->` after it when
  an excerpt separator is appropriate.
- A `TL;DR` is optional. Use one only when it genuinely helps a long,
  decision-heavy, or multi-result article.
- Organize sections around the technical story rather than a universal blog
  template. Headings should describe the next idea, not merely label generic
  stages such as `Background`, `Discussion`, or `Conclusion`.
- Use lists for actual sets, sequences, and comparisons. Prefer connected
  prose when the relationship between ideas is the point.
- End with a specific result, implication, lesson, or unresolved question.
  Avoid a generic recap that repeats the introduction.

### Prose to Avoid

- Do not use clickbait, urgency bait, SEO keyword stuffing, marketing copy,
  grand claims, or inflated certainty.
- Avoid generic scene-setting such as broad claims about a rapidly changing
  world when a concrete observation can open the article.
- Remove canned AI transitions, repetitive section summaries, forced
  three-part rhetoric, excessive headings, excessive bullet lists, and
  ornamental em dashes.
- Do not invent quotations, dialogue, authorities, or consensus. Clearly
  marked rhetorical humor must remain unmistakable and appropriate.
- Do not mechanically add `Limitations`, `Future work`, or similar sections.
  Discuss a limitation where it affects the claim, and discuss future work only
  when there is a concrete next experiment or operational consequence.
- Avoid smoothing every paragraph into the same polished cadence. The blog
  should sound like a technically careful person, not a generic publication or
  model-generated essay.

## Research, Evidence, and Technical Integrity

- Research primary sources first. Prefer official documentation, source code,
  commits, standards, advisories, issue trackers, errata, and research papers.
  Use reputable secondary sources when they add necessary context or when no
  primary source exists.
- Cite factual and technical claims inline, close to the claim they support.
  Distinguish sourced fact, direct observation, inference, and personal
  judgment.
- Record versions, platforms, configurations, and dates when a fact or result
  can change over time.
- Never fabricate a citation, personal experience, CVE status, disclosure
  status, command output, benchmark, test result, crash, successful build, or
  reproduction result.
- Code and command examples may be accepted after careful technical review
  without every snippet having been executed. Do not imply that an unexecuted
  example was tested, observed, or reproduced.
- Clearly distinguish executable code, abbreviated code, pseudocode, and
  schematic output. Ellipses and placeholders must not look like captured
  evidence.
- Preserve external research citations even when their URLs contain legacy
  path segments such as `wp-content/uploads`. The prohibition on `wp-content/`
  applies to site-owned media paths, not cited external sources.

## Security Publication Safety

- Technical depth, defensive research, benign reproducers, exploit-mechanism
  explanations, and malware analysis are allowed when they serve the article.
- Never publish secrets, credentials, authentication material, personal data,
  confidential incident details, or live malware samples.
- Require explicit author review before publishing weaponizable exploit code,
  an unpublished vulnerability, active-case indicators, disclosure-sensitive
  details, or artifacts that materially increase operational risk.
- Sanitize examples and consider coordinated-disclosure status, affected
  versions, available fixes, and likely reader impact before including risky
  details.
- Do not execute malware, exploit unknown targets, or access third-party
  systems as part of writing or validating an article.
- Do not fabricate privacy, legal, employment, or disclosure language. Material
  in those areas requires appropriate author or jurisdiction-specific review.

## Post Front Matter and Data Model

- Posts live in `_posts/` and use the filename form
  `YYYY-MM-DD-post-slug.md`. Preserve existing permalinks.
- Every post requires this front matter shape:

  ```yaml
  ---
  title: 'Concrete sentence-case title'
  date: '2026-08-14T12:00:00+02:00'
  last_modified_at: '2026-08-14T12:00:00+02:00'
  author: tbarabosch
  layout: post
  tags:
    - systems security
    - FreeBSD
  ---
  ```

- `tags` must be a nonempty YAML block list. Inline arrays, empty lists, and
  duplicate front-matter keys are invalid.
- Set `last_modified_at` equal to `date` for a new post. Change it only for a
  substantive technical or factual revision that should resurface the article
  as updated.
- Do not bump `last_modified_at` for spelling, punctuation, formatting, tags,
  alt text, link repair, metadata cleanup, or layout-only changes.
- A post may belong to multiple topics through its tags.
- Every post must match at least one curated topic. The only topic-neutral
  exception is a post whose tag list is exactly:

  ```yaml
  tags:
    - site notes
  ```

- A post with at least 1,500 words and at least two H2 sections must set
  `toc: true` and include this build-time Kramdown contents block after the
  introduction and excerpt separator:

  ```html
  <nav class="post-toc" aria-labelledby="contents-heading" markdown="1">
  <p id="contents-heading" class="manual-label">CONTENTS</p>

  * TOC
  {:toc}
  </nav>
  ```

- Keep the contents list functional without JavaScript.

## Topics and Tags

- `_data/topics.yml` is the curated expertise taxonomy. Agents must not add,
  rename, remove, reorder, or remap topics without explicit author approval.
- The five topics and their matching tags are:
  - **Systems Security:** `systems security`, `FreeBSD`, `OpenBSD`, `NetBSD`,
    `virtualization`, `Apple Containers`, `fuzzing`
  - **Reverse Engineering:** `reverse engineering`, `malware analysis`, `IDA`
  - **Threat Research:** `threat hunting`, `VirusTotal`, `YARA`
  - **Incident Response:** `incident response`, `security operations`,
    `Microsoft Sentinel`
  - **AI Engineering:** `AI tooling`, `skill development`, `Prolog`
- If a proposed article does not fit an existing topic, ask before changing
  the taxonomy. Do not force an inaccurate tag merely to pass validation.
- Granular tags may be added when they accurately describe an article. Tag
  spelling and capitalization are exact and should reuse existing forms where
  applicable.
- `_data/tags.yml` is generated from post front matter and includes every used
  tag, including singletons. Never edit it manually.
- After changing post tags, run `scripts/update-tags.sh`; its generated change
  belongs with the post change. Use `scripts/update-tags.sh --check` when no
  rewrite is desired.
- The repository-managed pre-commit hook reads staged posts, regenerates the
  tag catalog from the Git index, and stages `_data/tags.yml`. Install it once
  per checkout with `scripts/install-hooks.sh`.

## Information Architecture and Discovery

- Preserve the homepage hierarchy unless the task explicitly changes it:
  1. Existing `NAME` section and H1
  2. `RECENT CHANGES`
  3. Existing footer
- The homepage H1 and positioning statement are established content and must
  not change during unrelated work.
- `RECENT CHANGES` shows the ten newest or substantively updated posts, sorted
  by `last_modified_at` descending. Each entry shows its change date and title
  without a status label, and the section links to the complete archive.
- Preserve these discovery routes:
  - `/topics/` for the complete grouped knowledge index
  - `/archive/` for all posts by original publication year and date
  - `/search/` for local title, excerpt, topic, and tag search
  - `/tags/` for all granular tags, including singletons
- Preserve the navigation structure:
  - Primary: `topics / archive / about / contact`
  - Utility: `search / rss`
- Do not add category systems or duplicate indexes that compete with topics,
  tags, archive, or search without an explicit information-architecture change.

## Post Reading Experience

- The post layout must continue to expose author, publication date, optional
  updated date, estimated reading time, and functional tag links.
- Preserve the post-ending sections:
  - `SEE ALSO` for previous/next articles and matching topics
  - `FEEDBACK` for the GitHub correction form and prefilled email fallback
  - `FOLLOW` for the full-content RSS feed and LinkedIn profile
- Correction links must include enough article context to identify the page.
  GitHub and email activate only after an explicit reader click.
- Keep the GitHub correction issue form's required article URL and correction
  details, optional evidence, and warning against secrets, personal data,
  credentials, and live malware.
- Repository Issues must remain enabled for the GitHub correction route. Keep
  the click-activated email link as the fallback when GitHub is unavailable.

### Progressive Enhancement

- Core content, navigation, topic and tag browsing, archive access, and the
  complete search corpus must remain available without JavaScript.
- Local search must render every article in the initial HTML and explain the
  browser-find fallback inside `noscript`.
- `assets/js/site.js` is a small, deferred, first-party enhancement for:
  - copying the exact text of fenced code blocks
  - H2/H3 permalinks
  - full-resolution links for local technical images
  - keyboard-focusable scrolling code blocks
  - local search filtering and query-string state
- JavaScript must not become a dependency for layout, primary navigation,
  reading, or discovery. Do not add a frontend framework for these features.
- Ordinary page loads must not contact third parties.

## Design, Responsive Behavior, and Accessibility

- Preserve the Unix/BSD manpage hybrid: content density, readable line length,
  and clear section hierarchy matter more than decoration.
- Keep the palette monochrome by default. Do not add accent-color themes,
  gradients, decorative cards, hero imagery, or new rounded surfaces.
- Keep typography hybrid: readable serif body text with monospace navigation,
  metadata, headings, and code.
- Use restrained ASCII-inspired structure through section labels, aligned
  metadata, simple rules, and small markers. Do not ship fragile ASCII box art
  as responsive interface chrome.
- Tag pills and the small inline SVG channel icons used on contact and post
  support links are intentional. New graphical conventions must be equally
  restrained.
- Preserve a visible-on-focus skip link and programmatic focus on the main
  content target.
- Keep interactive navigation and reading controls at least 24 by 24 CSS
  pixels, with visible keyboard focus states.
- All meaningful images require descriptive alternative text. Do not use an
  empty `alt` attribute for a technical image that carries information.
- Prevent page-level horizontal scrolling at narrow widths. Long inline code
  paths may wrap; fenced code must preserve formatting and scroll inside its
  own container.
- Maintain usable layouts at approximately 390 px and 1280 px widths.
- Keep print output readable and remove interactive-only controls and redundant
  navigation from print.
- Maintain a useful 404 page with clear routes back into the site.

## Code Fences and Technical Media

- Label source fences with a Rouge language supported by the pinned
  `github-pages` bundle.
- Use `bash` for executable shell snippets, `console` for commands mixed with
  output, and `text` for raw output, hex tables, directory trees, and ASCII
  diagrams.
- Use `cpp`, `swift`, `prolog`, and `diff` when those languages apply; the
  stylesheet exposes `TEXT`, `C++`, `SWIFT`, `PROLOG`, and `DIFF` labels.
- Rouge 3.30 has no YARA lexer. Use a `c` fence followed by
  `{: data-language="YARA" }` to retain tokenization and display the correct
  label.
- Use `data-language` for other intentional display-label overrides such as
  `PSEUDOCODE` or `IDC`.
- Keep fenced source free of inline Markdown or HTML annotations. Language
  labels are generated by CSS; do not add labels to the source text.
- Preserve exact code text so the copy control reproduces the source without
  UI labels or transformations.
- Put post images in `assets/images/posts/<post-slug>/` and reference them with
  absolute site paths:

  ```markdown
  ![Descriptive alternative text](/assets/images/posts/example-post/image.png)
  ```

- Do not add or reintroduce site-owned `wp-content/` paths.
- Do not automatically load remote images, video, audio, embeds, fonts,
  scripts, styles, or icon fonts. Keep only local assets that the site uses.

## SEO, Feeds, and Privacy

- Keep `jekyll-seo-tag` and `jekyll-sitemap` enabled through the pinned
  `github-pages` bundle.
- Use `{% seo %}` as the single source for document titles, descriptions,
  canonical URLs, Open Graph metadata, and JSON-LD. Do not reintroduce duplicate
  hand-written SEO elements.
- Preserve unique titles, descriptions, and canonical URLs on generated HTML
  pages. Post JSON-LD must identify a `BlogPosting` and include author,
  publication date, and modification date.
- Preserve the local 1200 by 630 monochrome default social image. Per-post
  overrides must also be local and must not add an ordinary-load third-party
  request.
- Generate configured per-post social cards with
  `scripts/generate-social-card.py`. The script reads `image` and
  `social_card` front matter without editing the post, writes a deterministic
  1200 by 630 PNG under the post's asset directory, and supports a non-writing
  `--check` mode. Use the exact-pinned, wheel-only artwork requirements in the
  ignored `.venv-social-card` environment on macOS.
- Preserve `/sitemap.xml`, `/robots.txt`, and the full-content `/feed.xml` with
  author metadata.
- Do not add analytics, trackers, remote fonts, remote scripts, social widgets,
  Giscus, or other automatically loaded third-party resources without explicit
  approval.
- External research links and click-activated GitHub or email feedback are
  allowed; they must not trigger a third-party request before the reader acts.
- Preserve the site-level AI-use disclosure on the About page. Do not alter its
  meaning or add article-specific authorship claims without explicit scope.

## Local Runtime and Dependency Safety

- Use Apple Containers as the only local Jekyll build and validation boundary.
- The canonical build command is:

  ```bash
  scripts/build-site.sh
  ```

- Do not run host `bundle`, `jekyll`, `gem install`, or other host Ruby
  dependency commands.
- If the `container` CLI or Apple Containers runtime is unavailable, report the
  blocker instead of falling back to host Ruby.
- Do not add heavyweight dependencies, new build systems, unreviewed install
  hooks, or remote frontend dependencies unless explicitly requested.
- Do not mount host secrets, credentials, SSH agents, cloud configuration,
  password-manager sockets, `$HOME`, `/Users`, or `/` into a project container.
  The canonical build mounts only this repository at `/workspace`.
- If `IMAGE_NAME` overrides the default image for the build, use the same image
  for subsequent validation.

## Validation

- Run validation in proportion to the change. Changes to posts, layouts,
  styles, JavaScript, configuration, data, navigation, SEO, or build tooling
  require the complete validation sequence below.
- First build the site and its local image:

  ```bash
  scripts/build-site.sh
  ```

- Then run the staged tag check, tag-generator tests, and generated-site
  validator inside that image:

  ```bash
  container run --rm \
    --volume "$PWD:/workspace" \
    --workdir /workspace \
    tbarabosch-github-io-jekyll \
    bash -lc 'scripts/update-tags.sh --check --staged && scripts/test-update-tags.sh && ruby scripts/validate-site.rb'
  ```

- The generated-site validator checks internal paths and fragments, required
  post metadata, topic coverage, tag completeness, unique SEO elements, Open
  Graph data, JSON-LD, sitemap, robots, feed, social image, homepage structure,
  search fallback, and the absence of remote scripts and trackers.
- For presentation or interaction changes, also check at approximately 390 px
  and 1280 px that:
  - the homepage H1 is unchanged, Recent Changes follows it, and no topic
    overview is present
  - no page-level horizontal scrolling occurs
  - fenced code scrolls internally and copies exact source text
  - singleton tags resolve to article lists
  - search works with JavaScript and exposes the complete list without it
  - keyboard focus, skip navigation, local image links, and print remain usable
  - an ordinary page load makes no third-party request
- Before handoff, review the complete relevant diff and rerun
  `git status --short --branch`.
- Do not commit `_site/`, `.jekyll-cache/`, `.jekyll-metadata`, `.sass-cache/`,
  `.bundle/`, `vendor/bundle/`, or other generated build and dependency state.

## Contract Maintenance

- Treat the implementation, this file, `README.md`, and automated validation as
  one versioned contract.
- A change to information architecture, post metadata, topic or tag behavior,
  design, accessibility, privacy, progressive enhancement, SEO, or validation
  must update all affected documentation and automated checks in the same
  change.
- Do not document planned behavior as if it already exists. When implementation
  and documentation disagree, inspect the source of truth, fix the mismatch in
  scope, and state any unresolved inconsistency at handoff.
