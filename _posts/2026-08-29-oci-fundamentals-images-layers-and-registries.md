---
title: 'OCI fundamentals: images, layers and registries'
date: '2026-08-29T12:00:00+02:00'
last_modified_at: '2026-08-29T12:00:00+02:00'
author: tbarabosch
layout: post
tags:
  - systems security
  - Apple Containers
  - NetBSD
  - OCI
---

While working on the ongoing [NetBSD on Apple Virtualization series](/porting-netbsd-to-apple-vz/), I eventually had to look beyond boot loaders and Virtio drivers. I needed to understand how to package NetBSD as an OCI image for Apple's `container` tool. The actual NetBSD image deserves a separate future post. This short article is the reference material for it.

[OCI](https://opencontainers.org/) stands for Open Container Initiative. Canonical's presentation [What is the Open Container Initiative?](https://www.youtube.com/watch?v=RBAQyqgFl4w) provides a good introduction to this technology.

<!--more-->

## Three specifications, not one runtime

The OCI project maintains three specifications. The [Image Specification](https://specs.opencontainers.org/image-spec/) describes the packaged content. The [Distribution Specification](https://specs.opencontainers.org/distribution-spec/) defines how registries push and pull that content. The [Runtime Specification](https://specs.opencontainers.org/runtime-spec/) describes the filesystem bundle, configuration and lifecycle used to start a container.

```text
build input
    |
    v
OCI image ------ Image Specification
    |
    v
registry API --- Distribution Specification
    |
    v
runtime bundle - Runtime Specification
    |
    v
container process
```

OCI does not build or run anything on its own. Its specifications let a tool build an image, a registry store it and another compatible tool fetch and run it.

## An image is a graph of blobs

An image manifest references a configuration and an ordered list of filesystem layers. Each descriptor records a media type, size and content digest. An optional image index points to several manifests, usually one per operating-system and CPU-architecture combination.

```text
image index (optional)
`-- manifest: linux/arm64
    |-- config: command, environment, layer order
    `-- filesystem changes
        |-- layer 2: /hello.txt
        `-- layer 1: Alpine root filesystem
```

Layers are changesets, not complete copies of the filesystem. A runtime applies them from the base upward to produce one root filesystem. The configuration holds properties such as the entry point, default arguments, environment and working directory. A digest identifies immutable content; a convenient tag such as `1.0` is only a movable name that resolves to a manifest.

A normal container image does not include a kernel. It supplies userspace files and process settings; the runtime supplies the execution environment. That distinction is one reason the NetBSD experiment needs more than a different `FROM` line.

## Push an image to GitHub Container Registry

This minimal `Containerfile` adds one filesystem layer and one command:

```dockerfile
FROM alpine:3.22
RUN printf 'hello from OCI\n' >/hello.txt
CMD ["cat", "/hello.txt"]
```

[GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry) accepts OCI images at `ghcr.io`. With Apple's [`container` commands](https://github.com/apple/container/blob/main/docs/command-reference.md), a local round trip looks like this:

The reference `ghcr.io/OWNER/oci-demo:1.0` contains the registry, account namespace, image name and tag. During a push, the client uploads missing blobs and then the manifest. A pull resolves the tag and downloads the referenced configuration and layers.

```bash
container system start

GHCR_OWNER=your-lowercase-github-name
IMAGE="ghcr.io/${GHCR_OWNER}/oci-demo:1.0"
read -rsp 'GHCR token: ' CR_PAT
printf '\n'
printf '%s' "$CR_PAT" | container registry login \
  --username "$GHCR_OWNER" --password-stdin ghcr.io
unset CR_PAT

container build --tag "$IMAGE" .
container image push "$IMAGE"
```

The classic personal access token needs `write:packages`. New packages are private by default. After repeating the login on another Mac, fetch and run the image with:

```bash
container system start
container image pull "ghcr.io/your-lowercase-github-name/oci-demo:1.0"
container run --rm "ghcr.io/your-lowercase-github-name/oci-demo:1.0"
```

Public packages can be pulled without authentication. This example publishes only the builder's platform; multi-platform NetBSD images are a subject for the follow-up.
