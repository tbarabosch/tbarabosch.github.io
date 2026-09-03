---
title: 'Running NetBSD OCI images with Apple Container'
date: '2026-09-03T21:30:00+02:00'
last_modified_at: '2026-09-03T21:30:00+02:00'
author: tbarabosch
layout: post
toc: true
image:
  path: /assets/images/posts/running-netbsd-oci-images-with-apple-container/social-card.png
  width: 1200
  height: 630
social_card:
  title: 'NetBSD OCI images on Apple Container'
  layout: ascii
  subtitle: 'An external runtime turns NetBSD userspace layers into an EFI-bootable VM.'
  eyebrow: 'Systems Security / NetBSD'
  panel_label: 'OCI image / runtime path'
  source:
    language: text
    occurrence: 1
  highlight: 'ghcr.io/tbarabosch/netbsd:11'
  accent: 'NVZA agent -> execve(2)'
tags:
  - systems security
  - Apple Containers
  - NetBSD
  - OCI
  - virtualization
  - macOS
---

Finally, the public [`ghcr.io/tbarabosch/netbsd:11`](https://github.com/tbarabosch/container-runtime-netbsd/pkgs/container/netbsd) image I built runs with Apple's `container` tool on Apple silicon. The [`container-runtime-netbsd` proof of concept](https://github.com/tbarabosch/container-runtime-netbsd/tree/v0.3.0) pulls the `netbsd/arm64` image, turns its OCI layers into a bootable FFS disk, starts NetBSD 11 with Virtualization.framework and runs the requested program through a small guest agent.

![Animated terminal showing container netbsd pulling the GHCR image, assembling its disk, booting NetBSD 11 and executing uname](/assets/images/posts/running-netbsd-oci-images-with-apple-container/netbsd-container-uname.gif)

The current CLI only prints the final command output. I added the four status lines to make its otherwise silent work visible.

```text
ghcr.io/tbarabosch/netbsd:11
              |
 OCI layers -> GPT / EFI / FFS
              |
     Apple VZ -> NetBSD 11
              |
     NVZA agent -> execve(2)
```

This is not NetBSD support in an unmodified Apple Container release. I had to use OpenAI's Codex to patch Apple Container 1.3.0 and use the NetBSD platform kit from the earlier experiments. With those two pieces installed, `container netbsd run` behaves like a real container command: it fetches the image, boots the guest, connects the process streams and returns its exit status.

<!--more-->

<nav class="post-toc" aria-labelledby="contents-heading" markdown="1">
<p id="contents-heading" class="manual-label">CONTENTS</p>

* TOC
{:toc}
</nav>

## Reusing the earlier NetBSD VM

Apple Container already puts every Linux container in its own lightweight virtual machine. In [Detecting Apple Container from inside the guest](/detecting-apple-container-from-inside-the-guest/), I followed a request from the `container` CLI through `container-apiserver`, the Linux runtime plugin and Virtualization.framework to `vminitd` inside the guest. Each container gets its own VM instead of sharing one Linux kernel with the other containers.

In [Porting NetBSD to Apple VZ](/porting-netbsd-to-apple-vz/), I replaced that Linux guest with NetBSD 11. The patched kernel booted on the virtual ARM machine, used its Virtio console, block, entropy and network devices, mounted an FFS root filesystem and shut down cleanly. However, a purpose-built Swift program still had to start a prepared kernel and disk. It was a NetBSD VM, not a container runtime.

[Moving NetBSD on Apple VZ from direct boot to EFI](/moving-netbsd-on-apple-vz-from-direct-boot-to-efi/) removed another custom part. Virtualization.framework's generic EFI firmware starts NetBSD's unmodified `bootaa64.efi`, the loader starts a `GENERIC64` kernel and ACPI describes the hardware. Only the three generic Virtio patches remained in the platform kit.

That left the OCI image. As described in [OCI fundamentals: images, layers and registries](/oci-fundamentals-images-layers-and-registries/), an OCI image normally contains a userspace filesystem and process configuration, not a kernel. The GHCR image therefore provides NetBSD userspace. The runtime adds the kernel, EFI loader, disk format and process-control agent.

## What I had to patch

Apple Container supports CLI and runtime plugins. I use both. The CLI plugin adds `container netbsd`; the runtime plugin starts and controls one NetBSD VM. The [`netbsd` CLI plugin](https://github.com/tbarabosch/container-runtime-netbsd/blob/v0.3.0/runtime/Sources/NetBSDCLI/main.swift) asks Apple's image service for the `netbsd/arm64` manifest, assembles a RAW disk and creates a container handled by `container-runtime-netbsd`. It passes the disk path to the runtime as opaque data. CPU and memory still use the normal container resource settings.

There was one problem: `container-apiserver` assumed that every runtime needed the Linux kernel, initial filesystem and image-root snapshot prepared by Apple Container. The NetBSD runtime cannot use any of them. Its EFI disk already contains the loader, kernel and root filesystem.

The included [Apple Container compatibility patch](https://github.com/tbarabosch/container-runtime-netbsd/blob/v0.3.0/compat/apple-container-runtime-owned-resources.patch) adds one explicit service capability:

```text
[[servicesConfig.services]]
type = "runtime"
capabilities = ["runtime-owned-resources"]
```

When a runtime declares this capability, `container-apiserver` requires `runtimeData` and skips the Linux kernel, initial filesystem and root snapshot. Nothing changes for runtimes without the capability, and the Linux runtime still rejects a request without its Linux resources.

NetBSD still needs two corrections for the devices used by the runtime. PCI memory decoding must be enabled for modern Virtio BARs, and a Virtio 1.0 reset must wait until the device reports status zero. The earlier MTU negotiation patch is also present in the kernel, although the runtime currently does not attach a network device. None of the NetBSD changes names Apple or adds a VZ-specific platform. Neither patch set is upstream, so the stock releases of NetBSD 11 and Apple Container 1.3.0 cannot run this setup on their own.

## Turn OCI layers into a bootable FFS disk

The public image contains NetBSD userspace, but no kernel, EFI loader or guest agent. The CLI checks that the image declares `netbsd/arm64` and a NetBSD 11 release. It then reads each layer from Apple's local content store and passes it to the [OCI layer applier](https://github.com/tbarabosch/container-runtime-netbsd/blob/v0.3.0/runtime/Sources/NetBSDOCI/OCILayerApplier.swift).

Layers may be plain tar archives or use gzip or zstd compression. They are applied in manifest order, including ordinary and opaque whiteouts, hardlinks, symbolic links and file modes. The applier rejects absolute paths, parent traversal, paths through existing symlinks, extended attributes and special files. Device nodes therefore do not come from an untrusted image layer.

After all layers have been staged, the [disk assembler](https://github.com/tbarabosch/container-runtime-netbsd/blob/v0.3.0/runtime/Sources/NetBSDOCI/NetBSDDiskAssembler.swift) verifies that the result looks like a complete NetBSD root. At minimum, it expects `init`, a shell, the password database and `MAKEDEV`. Only then does it overlay the runtime-owned files:

- the patched `GENERIC64` kernel and unmodified `bootaa64.efi`
- the statically linked NetBSD guest agent and its `rc.d` service
- `fstab`, `rc.conf`, `ttys` and the EFI `boot.cfg`
- device metadata generated by NetBSD's own `MAKEDEV`

I also lock the root password, disable interactive gettys on both Virtio ports and leave DHCP, SSH, `inetd` and Postfix switched off. The agent starts the container process. There is no reason to log in to the guest.

NetBSD's Darwin-hosted `nbmakefs`, `nbgpt` and `nbpwd_mkdb` tools do the filesystem-specific work. The resulting RAW disk has a GPT, a 64 MiB FAT32 EFI System Partition and an FFSv1 root partition labeled `netbsd-root`. The ESP contains the AArch64 removable-media path `EFI/BOOT/BOOTAA64.EFI`, and `boot.cfg` selects `/netbsd` with `root=NAME=netbsd-root`.

## Use a serial device as the process API

The [runtime service](https://github.com/tbarabosch/container-runtime-netbsd/blob/v0.3.0/runtime/Sources/ContainerRuntimeNetBSD/RuntimeService.swift) is an XPC helper launched once per container. It creates a generic VZ platform with persistent machine identity and EFI variable state, the cloned root disk, an entropy device, a small Virtio GPU for EFI output and two Virtio console ports. There is no virtual NIC.

Port `ttyVI00` is the boot console. Its output is appended to `boot.log`, but its input comes from `/dev/null` and no getty listens on it. Port `ttyVI10` is a private, root-owned connection between the macOS runtime and `/usr/sbin/netbsd-vz-agent` in the guest.

That second port carries the [NetBSD VZ Agent protocol](https://github.com/tbarabosch/container-runtime-netbsd/blob/v0.3.0/protocol/PROTOCOL.md), or NVZA. Every frame has a fixed 32-byte header containing the magic, protocol version, frame type, request identifier, process identifier and payload length. Control messages are bounded JSON objects; standard input, standard output, standard error and file contents remain opaque bytes.

After a version handshake, the runtime translates Apple Container operations into agent requests. It supports process creation, start, wait, signal, terminal resize, standard-input closure, deletion and regular-file copy in both directions. Non-terminal processes keep stdout and stderr separate; a PTY merges them. The agent drains the output and sends EOF before reporting the final exit event. Otherwise, the last bytes from a short-lived command could disappear.

There is no hidden shell. The CLI combines the OCI entrypoint and command, adds environment overrides and sends the executable and its literal argument vector to the guest. The agent calls `execve(2)` and only searches `PATH` when the executable contains no slash. If you want shell operators, use `/bin/sh -c` yourself. Every process currently runs as root; OCI user selection is not implemented.

Virtio console works, but its tty input queue is small. NVZA permits larger stream frames, while the serial adapter sends at most 768 data bytes at a time and waits for an acknowledgement before continuing. This prevents terminal input and file transfers from overrunning the queue. A vsock transport should eventually make this workaround unnecessary.

When the main process exits, the runtime asks the agent to shut down NetBSD, waits briefly and force-stops the VZ machine only if the guest remains alive. A direct stop first signals the process and gives it a bounded wait. The process exit status then travels back through NVZA and Apple Container to the invoking CLI.

## Run it and what remains

Building the runtime requires an Apple silicon Mac with macOS 26 or newer, Xcode, network access and Apple Container 1.3.0. The repository pins the Apple source revision and the NetBSD platform-kit archive. The following commands keep the locally built Apple binaries and both NetBSD plugins under the repository's ignored `.build` directory:

```bash
git clone --branch v0.3.0 --depth 1 \
  https://github.com/tbarabosch/container-runtime-netbsd.git
cd container-runtime-netbsd

make compatible-container
CONTAINER_INSTALL_ROOT="$PWD/.build/apple-container-compat" make install

CLI="$PWD/.build/apple-container-compat/bin/container"
"$CLI" system stop
"$CLI" system start \
  --install-root "$PWD/.build/apple-container-compat" \
  --disable-kernel-install
```

`system stop` stops the active Apple Container service and its containers, so check existing work before running it. The locally built API server is necessary because the stock 1.3.0 server does not understand `runtime-owned-resources`.

The NetBSD image is public and does not require a GHCR login:

```console
$ "$CLI" netbsd run ghcr.io/tbarabosch/netbsd:11 \
    --name hello --remove -- /usr/bin/uname -a
NetBSD container-runtime-netbsd 11.0 NetBSD 11.0 (GENERIC64) #0: Thu Aug 27 21:53:13 CEST 2026  tbarabosch@Thomass-MacBook-Neo.local:/Users/tbarabosch/code/netbsd-vz/.build/obj/sys/arch/evbarm/compile/GENERIC64 evbarm
```

I captured this run on an Apple silicon Mac with macOS 26.6.2, Xcode 26.6, Swift 6.3.3 and the patched Apple Container 1.3.0 source. The output is exact, including the cross-builder identity and object path embedded in the kernel version string. The command exited successfully, the `--remove` option deleted its container state and the runtime shut the guest down.

The important part is that the custom Swift VM runner from the first article is no longer involved. Apple Container fetched the public image, the CLI assembled the disk, Virtualization.framework booted NetBSD through EFI and NVZA started `uname`. Its output and exit status reached the host as expected.

There is still plenty to do:

- Submit the generic Virtio corrections to NetBSD and the external-runtime changes to Apple Container.
- Add guest networking, mounts, published ports and socket APIs.
- Replace or complement the serial transport with vsock and handle crashed runtimes more cleanly.
- Support non-root processes, recursive copy and more complete OCI filesystem metadata.
- Rehash cached disks, serialize concurrent cache writes and expand negative and integration testing.
- Replace the one-off base-image publisher with a reproducible, automated and attested GHCR pipeline.

That's it. `container netbsd run ghcr.io/tbarabosch/netbsd:11` now boots NetBSD 11 and runs a real NetBSD program. It still needs patched components and lacks several everyday container features. But it works, and the image is available on GHCR for others who want to try it.
