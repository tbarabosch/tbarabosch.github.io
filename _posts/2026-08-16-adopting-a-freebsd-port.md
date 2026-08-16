---
title: 'Adopting a FreeBSD port'
date: '2026-08-16T12:00:00+02:00'
last_modified_at: '2026-08-16T12:00:00+02:00'
author: tbarabosch
layout: post
toc: true
tags:
  - FreeBSD
  - software supply chain
  - product security
  - open source
---

Installing the package `xdelta3` on FreeBSD is one command:

```bash
pkg install xdelta3
```

The command does not mention an upstream release, a checksum, local patches, a build system, a packing list or a package builder. That is a feature. Package installation should be simple: I ask for a package and FreeBSD handles the machinery behind it.

Somebody still has to maintain all of that.

I spend quite a lot of time thinking about software supply chains from the security side, especially after recent [campaigns against npm packages](https://unit42.paloaltonetworks.com/monitoring-npm-supply-chain-attacks/). Incident reports tell me what failed after the fact. Maintaining a port exposes the decisions made before users receive software: which source archive, checksum, dependencies, patches and installed files. I wanted to work through that process myself, so I adopted `misc/xdelta3`, my first FreeBSD port.

<!--more-->

<nav class="post-toc" aria-labelledby="contents-heading" markdown="1">
<p id="contents-heading" class="manual-label">CONTENTS</p>

* TOC
{:toc}
</nav>

## From an upstream release to pkg

FreeBSD distinguishes the base system from third-party applications. As the [FreeBSD Handbook explains](https://docs.freebsd.org/en/books/handbook/ports/), the latter can be installed from source through the Ports Collection or as pre-built binary packages managed with [`pkg(8)`](https://man.freebsd.org/cgi/man.cgi?query=pkg&sektion=8&format=html). These are not two unrelated software ecosystems. The packages are built from the ports tree.

The path looks roughly like this:

```text
upstream source
       |
       v
FreeBSD port
metadata + checksums + patches
       |
       v
package builders
       |
       v
package repository
       |
       v
pkg install
```

In August 2026, [FreshPorts](https://www.freshports.org) tracked a little more than 35,000 ports, with 172 new ones added during the preceding month. The count changes every day as upstream projects publish releases, dependencies move, compilers become stricter and old software disappears.

A port selects the source archive, records the expected checksum, declares build and runtime dependencies, applies FreeBSD-specific patches and describes the files that belong in the resulting package. Changing any of these inputs changes what eventually reaches a system through `pkg`.

These are security-relevant inputs. I have to check where the source came from, whether the declared license still matches upstream, whether the build downloads undeclared code, whether a dependency is necessary and whether an update changes the installed interface. A clean package build also catches undeclared dependencies: the port must not work only because some header or library happens to exist on my machine.

None of this turns a port maintainer into an auditor of every upstream line. A correct checksum identifies the archive I intended to use, but it cannot tell me that the archive is benign. A green build shows that the source compiled in that environment, not that it contains no vulnerabilities.

## What is actually in a port

The [FreeBSD Handbook](https://docs.freebsd.org/en/books/handbook/ports/) describes a port as a collection of files that automates fetching, extracting, patching, compiling and installing an application. The [Porter's Handbook](https://docs.freebsd.org/en/books/porters-handbook/quick-porting/) explains how to assemble that recipe. The actual application source is normally not stored in the ports tree. A small port instead looks like this:

```text
misc/xdelta3/
|-- Makefile
|-- distinfo
|-- pkg-descr
|-- pkg-plist
`-- files/
    `-- patches, when required
```

The `Makefile` contains most of the build metadata: the version, maintainer, license, upstream location, build framework and dependencies. `distinfo` records the names, sizes and checksums of downloaded files. `pkg-descr` explains what the software does, while `pkg-plist` lists what the package installs. The optional `files/` directory holds patches and other local material needed to make the software behave correctly on FreeBSD.

The framework then moves the source through a sequence of phases. In simplified form:

```text
fetch -> checksum -> extract -> patch
      -> configure -> build -> stage -> package
```

The [`ports(7)` manual page](https://man.freebsd.org/cgi/man.cgi?query=ports&sektion=7&format=html) documents the user-facing targets and their order. `fetch` retrieves the declared distfiles. `checksum` compares them with `distinfo`. The framework extracts and patches the source, invokes the upstream configuration and build system, and stages the installed files in a temporary directory. The packaging step turns that staged tree and its metadata into a `.pkg` file.

A user can enter a port directory and run `make install`. Package builders can instead build the same port in isolated jails and publish its binary package. [Poudriere](https://docs.freebsd.org/en/books/handbook/ports/#ports-poudriere) is the standard tool for creating and testing such package repositories. The result can be installed quickly on other machines with `pkg`, without compiling the program again.

The distinction matters when mixing locally built ports and repository packages. The main ports branch follows current changes, while quarterly branches receive a more conservative set of updates. Dependencies and options can differ between them. The [Handbook therefore recommends](https://docs.freebsd.org/en/books/handbook/ports/#ports-using) matching a local ports tree to the branch used by the configured package repository.

The complete tree can be browsed in the canonical [FreeBSD ports repository](https://cgit.freebsd.org/ports/tree/) or its [read-only GitHub mirror](https://github.com/freebsd/freebsd-ports). Ben Woods's presentation [Introduction to FreeBSD Ports - 25 years and counting](https://www.youtube.com/watch?v=zj_GXPHLyGw&themeRefresh=1) gives a good longer tour of the framework.

## What a maintainer actually does

The [`MAINTAINER` field](https://docs.freebsd.org/en/books/porters-handbook/makefiles/) gives FreeBSD a contact for a port. It neither transfers ownership of the upstream project nor grants a FreeBSD commit bit. For an unmaintained port, the [FreeBSD problem report guide](https://docs.freebsd.org/en/articles/problem-reports/) tells contributors to submit a report requesting maintainership. I can prepare and test a change, but a committer still reviews and lands it.

Changing the maintainer address is the easy part. The [FreeBSD contribution guide](https://docs.freebsd.org/en/articles/contributing/#ports-contributing) describes the recurring work: watch upstream for releases and security fixes, update checksums and dependencies, carry or remove local patches, keep the packing list accurate and check whether consumers break. It recommends testing builds, installation, deinstallation and packaging across as many relevant platforms as possible.

I did not want to stop after a version bump. Maintaining the port means tracking build-system and license changes, rejecting undeclared downloads and debugging failures outside my local architecture. That is the product-security work I wanted to learn in a real setting.

## Why I picked xdelta3

For a first port, I deliberately looked for software small enough to read and test without inheriting a desktop stack. `xdelta3` is a focused C library and command line tool useful for my area of interest. The 3.2.0 update was still real work: upstream changed the build system, library interface, dependencies and installed files.

FreeBSD also had a real maintenance gap. According to the [FreshPorts history for `misc/xdelta3`](https://www.freshports.org/misc/xdelta3/), the port entered the tree in 2007 and had been without a maintainer since 2021. Its packaged version had remained on 3.1.0 since the 2018 update.

Xdelta creates binary deltas. Given an old file and a compact description of the changes, it reconstructs a new file:

```text
old file --------------------+
                             |
delta: COPY + ADD + RUN ---> xdelta3 ---> new file
```

Version 3 implements the [VCDIFF format specified in RFC 3284](https://datatracker.ietf.org/doc/html/rfc3284). At a high level, `COPY` instructions reuse bytes from the source or already decoded target, `ADD` supplies new bytes and `RUN` repeats a byte. The resulting delta can be much smaller than transferring the complete target file. The decoder is also a binary parser. It consumes lengths and offsets from a delta, allocates memory and combines two inputs into a new artifact.

Updating the port was not a matter of changing `3.1.0` to `3.2.0`. The current [upstream xdelta repository](https://github.com/jmacd/xdelta) moved the build to CMake and relicensed the 3.2 series under Apache 2.0. The port had to reflect both changes. It also had to use FreeBSD's `devel/libblake3` dependency so that CMake would not fetch its own copy during configuration.

## The patch landed

`misc/xdelta3` is the first FreeBSD port for which I am now the maintainer. The update and adoption [landed in the ports tree as commit `4fe2fada927d`](https://cgit.freebsd.org/ports/commit/?id=4fe2fada927d063c57cf7006de4f0dfacb8913aa). [Problem Report 297302](https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=297302) contains the patch and its review history.

With the commit in the tree, the `MAINTAINER` field now points at me. The next upstream release, compiler failure, package-builder report or security fix is mine to triage.

From the user's side, `pkg install xdelta3` remains one command. In the ports tree, the upstream archive, checksum, dependency and installed files now have a reviewed update and a named maintainer. That does not make xdelta3 secure. It removes some ambiguity about what gets built and who should fix it when that changes. That is enough for a first port. The useful test comes with the next update.
