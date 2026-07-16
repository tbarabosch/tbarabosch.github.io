---
title: 'How I contain OSS supply-chain risk with Apple Containers'
date: '2026-07-16T12:00:00+02:00'
author: tbarabosch
layout: post
---

I have been using coding agents quite a lot lately. Much of their usefulness does not come from code generation alone. Codex can run the compiler, look at a failing test, change a file and try again. I do not have to copy commands between a chat window and a terminal. For this to work, the agent needs access to a shell, and this shell can also run a package manager.

Let’s say a Python import is missing. The fastest fix is often a `pip install`. For a missing JavaScript package, the equivalent is `npm install`. An agent can find a package, install it and continue with the actual task before I have even looked at the package name. Perhaps the package is well known and was already part of the project. Perhaps the model just came up with a plausible name and found something under that name on PyPI. Both cases can produce a green test.

Package installation can execute code. [npm runs lifecycle scripts](https://docs.npmjs.com/cli/using-npm/scripts/), [pip may invoke a project’s build backend when installing from a source distribution](https://packaging.python.org/en/latest/flow/), and [RubyGems builds native extensions on the user’s machine at install time](https://guides.rubygems.org/gems-with-extensions/). Running a package manager on my workstation therefore means running code written by a large number of strangers. If something goes wrong, my SSH agent, cloud credentials, package tokens and every repository my user can access are nearby.

This was already a problem before agentic programming. Agents just make it much easier to cross this boundary quickly and repeatedly.

<!--more-->

## The current threat landscape

The classic dependency risk is a vulnerable library. There are useful scanners for this case. But a scanner that checks CVEs does not help much if a previously legitimate package was deliberately backdoored this morning.

Attackers do not necessarily need to break into a package registry. Recent campaigns relied on [compromised maintainer credentials and package tokens](https://github.blog/security/supply-chain-security/strengthening-supply-chain-security-preparing-for-the-next-malware-campaign/) or [compromised CI workflows](https://unit42.paloaltonetworks.com/monitoring-npm-supply-chain-attacks/). There is also the less sophisticated end of the spectrum: typosquatting, dependency confusion and publishing malicious packages under names that look useful enough.

Shai-Hulud is a good example of how ugly this can become. The first npm campaign in 2025 used compromised maintainer access and malicious install scripts to steal credentials. The stolen npm and GitHub credentials were then used to compromise and republish further packages. In other words, the package registry became part of the worm’s propagation mechanism. GitHub published a good [summary of the different Shai-Hulud waves](https://github.blog/security/supply-chain-security/strengthening-supply-chain-security-preparing-for-the-next-malware-campaign/).

This was not a single campaign that disappeared after a couple of packages were removed. Unit 42’s regularly updated [overview of npm supply-chain attacks](https://unit42.paloaltonetworks.com/monitoring-npm-supply-chain-attacks/) describes later waves with CI/CD persistence, multi-stage payloads and more credential theft. Some of the malicious packages even had valid provenance. This sounds contradictory at first, but it is not. The provenance was correct: the compromised pipeline had built and signed the malicious artifact.

This is an important limitation of signatures and attestations. [npm provenance](https://github.blog/security/supply-chain-security/introducing-npm-package-provenance/) and [PyPI attestations](https://docs.pypi.org/attestations/) help us to connect an artifact to a repository and a build process. This is useful evidence about the origin of a package, but it says nothing about whether the source code is benign. The [PyPI documentation](https://docs.pypi.org/attestations/security-model/) makes exactly this distinction.

While npm currently provides many convenient examples, this is not an npm-only problem. OpenSSF describes [shared package-repository security challenges](https://openssf.org/blog/2026/02/19/advancing-package-repository-security-through-collaboration/) across npm, PyPI, RubyGems, crates.io and several other ecosystems. Anything that pulls code from somebody else and executes it is part of the software supply chain.

## Why coding agents make this riskier

For a malicious npm package, it does not matter whether `npm install` was typed by me or by Codex. The difference is how much friction there is before somebody types it.

Normally, I might search for a library, have a quick look at its repository, add it to a manifest and then run the package manager. This is not a formal security review, but at least there are several points where a strange name, a two-day-old project or an unexpected maintainer might catch my attention. An agent can combine all of these steps into one command sequence and optimize for the result I asked for: make the build work.

There is another problem specific to generative models. A 2025 USENIX Security paper found that [code-generating models invent package names](https://www.usenix.org/conference/usenixsecurity25/presentation/spracklen). Most of these hallucinations simply result in a `404`. An attacker can, however, register a repeatedly hallucinated name and wait for a developer or an agent to use it. This has become known as slopsquatting for packages. Unit 42 recently described the related problem of [phantom squatting](https://unit42.paloaltonetworks.com/phantom-squatting-hallucinated-web-domains/), where attackers register hallucinated domains. An autonomous agent is a nice target for both attacks because it may retrieve and process the result without another human decision in between.

An agent also inherits the authority of its environment. If I start it in a normal shell, it may be able to read my home directory, use existing Git authentication, reach credentials in environment variables and modify other writable directories. Malware does not need a sandbox escape if I run it outside a sandbox in the first place.

For me, the conclusion is rather obvious: I do not want package installation and build steps to run directly on my Mac. I also do not want an agent to add arbitrary dependencies just because this is the shortest way to fix an error.

## Reducing the risk

There is no particularly clever solution here. I try to combine a couple of boring controls that cover different parts of the problem.

The easiest mitigation is to use fewer dependencies. If twenty lines of straightforward code replace a tiny package and I can maintain them, this is often a good trade. I also want to review dependency changes separately from the rest of an agent’s patch. The exact package name, the upstream repository, its maintainers and the additional transitive dependencies are worth a quick look. A model suggestion is only a starting point for this check.

I pin what gets installed. Lockfiles belong in version control and should be reviewed like other source files. CI should use the locked dependency graph, for instance with [`npm ci`](https://docs.npmjs.com/cli/commands/npm-ci/) instead of a floating `npm install`. Python dependencies can be pinned with hashes. The [pip documentation on secure installs](https://pip.pypa.io/en/stable/topics/secure-installs/) recommends `--require-hashes` and, if possible, binary packages:

```bash
npm ci --ignore-scripts
npm audit signatures

python -m pip install \
  --require-hashes \
  --only-binary=:all: \
  -r requirements.txt
```

The [`npm audit signatures` command](https://docs.npmjs.com/cli/v11/commands/npm-audit/#audit-signatures) verifies registry signatures and provenance attestations for the installed packages.

Hashes are an integrity control, not a malware detector. If I approve the hash of a malicious package, pip will reliably install the malicious package on every build. Still, hashes prevent the resolver from silently selecting a different artifact later.

I disable install scripts by default where this is practical. Unit 42 specifically [recommends disabling lifecycle scripts](https://unit42.paloaltonetworks.com/monitoring-npm-supply-chain-attacks/) because attacks commonly use `preinstall` or `postinstall` to gain execution during installation. `--ignore-scripts` blocks this direct path. Newer npm versions also support an [`allowScripts` policy](https://docs.npmjs.com/cli/commands/npm-ci/) for packages that genuinely need an installation step. Of course, blocking lifecycle scripts is not sufficient on its own. The executable supplied by a package can be malicious as well and will run as soon as a test or the application calls it.

For a larger environment, I would add a private registry proxy. Unit 42 recommends using such a proxy to [hold back new releases for 24 to 72 hours](https://unit42.paloaltonetworks.com/monitoring-npm-supply-chain-attacks/), since malicious packages are often identified within this window. It is also possible to restrict build network access to this proxy instead of allowing arbitrary egress. An SBOM ([Software Bill of Materials](https://github.com/resources/articles/what-is-an-sbom-software-bill-of-materials)), or at least a reliable dependency inventory, helps later when a package is reported as malicious and somebody has to find all affected builds. [CISA describes this type of impact analysis as a primary SBOM use case](https://www.cisa.gov/sites/default/files/2024-07/SBOM%20FAQ%202024.pdf).

Most importantly, I contain the actual execution. Package managers, compilers, code generators and test suites run in a disposable container or VM that receives only the files required for the build. Routine builds do not need my home directory, an SSH agent or a package publishing token. Publishing is a separate operation with separate credentials.

## Apple Containers

On my Mac, I use Apple Containers for this last part. Apple’s open source [`container`](https://github.com/apple/container) tool builds and runs OCI-compatible Linux images. I can therefore use a familiar `Containerfile`, and the resulting images also work with other OCI tooling.

The interesting bit is how the containers are isolated. Instead of running all Linux containers in one shared Linux VM, Apple Containers starts a lightweight VM for each container. The tool uses Apple’s Virtualization framework and is optimized for Apple silicon. Apple’s [technical overview](https://github.com/apple/container/blob/main/docs/technical-overview.md) describes the design in more detail.

For this use case, I like the per-container VM boundary. A malicious Linux package does not run directly on macOS, and host files only appear inside the VM if I mount them. The workflow still feels like working with containers rather than maintaining a separate development VM.

However, the word *container* should not create a false sense of security. Malware inside the VM can read every mounted file, modify every writable mount and send data over the network. If I pass an AWS key into the container, the VM boundary does not make the key secret. A compromised dependency can also modify build output that I later publish or execute. I can still build and publish something malicious, but the malicious code has fewer places to look for host secrets.

## How I use this with Codex

This blog is a small example of the setup. Jekyll requires Ruby and quite a few gems. I do not install any of them into the Ruby environment on my Mac.

The repository contains a very small `Containerfile`:

```dockerfile
FROM ruby:3.3-bookworm

ENV BUNDLE_PATH=/bundle \
    BUNDLE_BIN=/bundle/bin \
    GEM_HOME=/bundle \
    PATH=/bundle/bin:$PATH

WORKDIR /workspace
```

The script `scripts/build-site.sh` builds this image and runs the site build inside an ephemeral Apple container:

```bash
container system start >/dev/null 2>&1 || true
container build -t "${image_name}" "${repo_root}"
container run --rm \
  --volume "${repo_root}:/workspace" \
  --workdir /workspace \
  "${image_name}" \
  bash -lc 'bundle install && bundle exec jekyll build --trace'
```

Hence, `bundle install`, native gem extensions and Jekyll itself execute in a Linux VM. The container is removed after the build. The repository is mounted into `/workspace`, but my macOS home directory including my SSH creds are not mounted.

Having a container script is only half of the setup. Codex also needs to know that it must use it. This policy lives in the repository’s `AGENTS.md`. [Codex reads this file before starting work](https://developers.openai.com/codex/guides/agents-md), which makes it a useful place for persistent repository-specific instructions:

```markdown
## Local Runtime
- Use Apple Containers as the only local build and validation boundary.
- The canonical validation command is `scripts/build-site.sh`.
- Do not run host `bundle`, `jekyll`, `gem install`, or other host Ruby
  dependency commands.
- If the `container` CLI or Apple Containers runtime is unavailable,
  report that blocker instead of falling back to host Ruby.
```

The last rule is there for a reason. If Apple Containers is not available, I want the build to fail instead of quietly installing gems on the host. `AGENTS.md` tells the agent what to do, the script provides the easy path, and Apple Containers enforces the actual runtime boundary. [Bundler uses `Gemfile.lock` to retain the exact dependency versions](https://bundler.io/man/bundle-install.1.html). None of these controls would be sufficient on its own.

## What this setup does not solve

This blog does not have a perfectly hermetic build. Actually, the current setup has a couple of obvious gaps.

The repository is mounted read-write because Jekyll writes the generated site to `_site/`. A malicious gem could also modify tracked files in the same mount. I would see this in `git diff`, but only after the fact. A stricter build would mount the source read-only and use a separate writable output volume.

Furthermore, `bundle install` has network access. It can download gems, but malicious code can also download another payload or send readable source files somewhere else. A more sensitive project should fetch reviewed dependencies through a controlled proxy and run the subsequent build without Internet access.

The base image is currently referenced as `ruby:3.3-bookworm`. [Image tags can change, while digests are immutable](https://docs.docker.com/dhi/core-concepts/digests/), so pinning its OCI digest would make this part of the build reproducible as well. And although `Gemfile.lock` fixes gem versions, it does not prove that those versions are good. If I add a malicious version to the lockfile, the container will happily reproduce my mistake.

I consider the current setup a reasonable baseline for this static blog, not the final word on supply-chain security. A repository containing production infrastructure or valuable credentials would need a stricter registry, network and publishing setup.

For this static blog, I am fine with that trade-off. It is already much better than running a newly installed gem alongside everything my macOS user can reach. New dependencies still deserve an explicit look, while lockfiles and hashes make it harder for the selected artifacts to change unnoticed. Apple Containers gives me a disposable place to run them without maintaining a separate development VM.

None of this will stop the next Shai-Hulud campaign. It should, however, make a successful package compromise on my development system considerably less interesting.
