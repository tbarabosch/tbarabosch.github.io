---
title: 'If NetBSD runs on a toaster, it must run on Apple VZ: Porting NetBSD to yet another platform'
date: '2026-08-18T21:30:00+02:00'
last_modified_at: '2026-08-18T21:30:00+02:00'
author: tbarabosch
layout: post
toc: true
tags:
  - NetBSD
  - virtualization
  - macOS
---

In 2005, Technologic Systems put a TS-7200 ARM board inside a standard two-slice toaster and ran NetBSD on it. [The appliance still made toast](https://www.netbsd.org/foundation/reports/2005Q3Q4.html). [NetBSD 3.0 subsequently listed the TS-7200](https://www.netbsd.org/releases/formal-3/NetBSD-3.0.html) as the “NetBSD Controlled Toaster,” turning the old portability joke into supported hardware.

Twenty-one years later, I had a less thermally ambitious target: Apple’s Virtualization.framework on an Apple silicon Mac. If NetBSD could run a toaster, it had no excuse for avoiding a virtual ARM machine. The result is [`netbsd-vz`](https://github.com/tbarabosch/netbsd-vz), a reproducible build that boots NetBSD 11.0 from a direct AArch64 kernel image, mounts an FFS root disk, drives the VZ Virtio devices and shuts the virtual machine down cleanly.

```text
                           |\
                           | \~~~~~~~~~~~~~~~~\
                           |  \     NetBSD      \
                           |   \          /~~~~~/
                           |    \~~~~~~~~/
                           |
              .-""""-.    |
           .-'////////`-._ |
         .'/////////////  `|
        ////////////    _.-|
        \///////   _..-'   |
         `--...---'        |
             __..---.      |      .---..__
          .-'::::::::`-.__.|.__.-'::::::::`-.
        .'::::::::::::::::::::::::::::::::::::`.
       /::::::::::::::::::::::::::::::::::::::::\
      /::::::....::::::::::::::::::::::::::::::::\
     |::::..    ..:::::::::::::::::::::::::::::::|
     |:::..      ..::::::::::::::::::::::::::::::|
     |::::..    ..:::::::::::::::::::::::::::::::|
      \::::::....:::::::::::::::::::::::::::::::/
       \:::::::::::::::::::::::::::::::::::::::/
        `.:::::::::::::::::::::::::::::::::::.'
          `-._:::::::::::::::::::::::::::_.-'
              `--..__::::::::::::__..--'
                     `--.::::.--'
                         `--'
```

<!--more-->

<nav class="post-toc" aria-labelledby="contents-heading" markdown="1">
<p id="contents-heading" class="manual-label">CONTENTS</p>

* TOC
{:toc}
</nav>

The complete boot is easier to recognize in motion. The following GIF animates
a condensed transcript from an actual offline `make smoke` run. It omits
repetitive `dmesg` output and machine-local paths, but retains the device
attachment, root mount, login, userspace marker, clean FFS unmount and guest
poweroff.

![Animated condensed terminal transcript of NetBSD 11 booting on Apple VZ and shutting down cleanly](/assets/images/posts/porting-netbsd-to-apple-vz/netbsd-vz-boot.gif)

## Start with the virtual hardware contract

I described the host side of Virtualization.framework in [Build a tiny Linux VM with Apple VZ](/build-a-tiny-linux-vm-with-apple-vz/). The NetBSD runner uses the same small part of the framework: a generic ARM platform, one virtual CPU, 512 MiB of memory, a direct kernel loader and selected Virtio devices. Console and entropy are always present. Block storage and VZ NAT are explicit additions.

The interesting work is therefore in the guest, not another tour through the Swift configuration. Apple’s class is named [`VZLinuxBootLoader`](https://developer.apple.com/documentation/virtualization/vzlinuxbootloader), and Apple documents it as a Linux kernel loader. In practice, the interface accepts the uncompressed AArch64 `Image` format expected by that boot path.

```text
macOS
  |
  `-- Virtualization.framework
        |-- direct AArch64 Image loader
        |-- flattened device tree
        |-- Virtio console
        |-- Virtio entropy
        |-- Virtio block ---- 1 GiB RAW disk
        `-- optional NIC ---- VZ NAT
                    |
              NetBSD VZ64
```

This is close to hardware that NetBSD already understands. The `evbarm-aarch64` port handles AArch64, FDT, PSCI, GICv3 and generic timers. NetBSD also has drivers for Virtio console, block, entropy and network devices. Nevertheless, there were still some issues that needed to be resolved: how VZ reserved memory around the kernel image, how the FDT was mapped, which PCI address spaces were enabled, when a Virtio reset had completed, which console became the kernel console and which network features the guest accepted.

## FreeBSD took a different route through VZ

This was not the first BSD bring-up on Virtualization.framework. Thomas Fontaine’s [FreeBSD-on-Apple-Virtualization work](https://github.com/tjfontaine/freebsd-apple-virtualization) booted a prepared FreeBSD 16.0-CURRENT/aarch64 guest to multiuser, persisted data on UFS, configured `vtnet0` through VZ NAT, wrote through a Virtio console and shut down cleanly.

The two experiments reached a similar device set through different boot contracts. The FreeBSD work uses VZ’s generic EFI platform. EFI starts the stock FreeBSD `loader.efi`, which follows the ACPI handoff into the kernel. The NetBSD experiment bypasses EFI and enters a raw AArch64 Image with an FDT. That difference decides where the investigation starts: EFI media and ACPI for FreeBSD, kernel-image placement and FDT bootstrap mappings for NetBSD.

## First Things First: Prepare the Kernel Image before touching a driver

The build starts with the official NetBSD 11.0 [`src`, `gnusrc`, `sharesrc` and `syssrc` sets](https://cdn.netbsd.org/pub/NetBSD/NetBSD-11.0/source/sets/). [`scripts/build.sh`](https://github.com/tbarabosch/netbsd-vz/blob/main/scripts/build.sh) pins and verifies the SHA-512 digest of every archive, extracts the source, applies four tracked patches and uses NetBSD’s own [`build.sh`](https://www.netbsd.org/docs/guide/en/chap-build.html) to create Darwin-hosted AArch64 cross tools. This is actually one of my favorite NetBSD features: apart from it's portability, it can be cross-compiled on several platforms. Personally, I can confirm this for Linux and macOS.

I did not keep the full `GENERIC64` configuration as it included far more evbarm hardware than VZ exposes. The project-specific [`VZ64` configuration](https://github.com/tbarabosch/netbsd-vz/blob/main/patches/vz64-config.patch) keeps the most important modules while also retaining DDB, symbols and tracing for failures. For instance, it removes modules, memory disks, compatibility ABIs, EFI, ACPI and drivers for physical storage, USB, display and audio hardware.

VZ placed adjacent boot data close enough to the reduced kernel image to stop the kernel from starting. The builder now reserves exactly 8 MiB, pads the payload and regenerates its AArch64 header with the final declared size and `ARM\x64` magic. It also rejects a kernel that grows into the reservation. This prevents the boot inputs from colliding.

## Make the FDT mapping agree with the kernel

VZ passes the flattened device tree to the kernel in register `x0`. NetBSD maps that FDT during the early AArch64 bootstrap. On the observed VZ layout, the FDT can share a 2 MiB L2 block with an existing kernel bootstrap mapping.

The original FDT mapping requested both unprivileged execute-never (`UXN`) and privileged execute-never (`PXN`) attributes. The existing block used `UXN`. `pmapboot_enter` could not reuse one block for two mappings with different attributes, so boot stopped before any useful console existed. The [platform patch](https://github.com/tbarabosch/netbsd-vz/blob/main/patches/vz-platform.patch) makes the attributes compatible:

```diff
 mov x2, #L2_SIZE
 mov x3, #L2_SIZE
 mov x4, #LX_BLKPAG_ATTR_NORMAL_WB | LX_BLKPAG_AP_RW
-orr x4, x4, #LX_BLKPAG_UXN | LX_BLKPAG_PXN
+/* The FDT may share an L2 block with the kernel bootstrap mapping. */
+orr x4, x4, #LX_BLKPAG_UXN
 mov x5, x26
 bl  pmapboot_enter
```

This is a tiny diff at a particularly problematic point in the boot. There is no filesystem, debugger transport or working console yet. The useful fact came from the mapping geometry: the FDT and kernel were not independently broken; they asked the same page-table block to describe memory in incompatible ways.

## Enable the PCI path and finish resetting Virtio

Once the kernel reached device discovery, the next boundary was PCI. VZ presents modern Virtio devices with their capabilities in memory BARs (Base Address Registers). NetBSD’s Virtio PCI attach path enabled bus mastering and I/O decoding, but not PCI memory decoding. The first half of the fix is exactly as plain as it sounds:

```diff
 csr = pci_conf_read(pc, tag, PCI_COMMAND_STATUS_REG);
-csr |= PCI_COMMAND_MASTER_ENABLE | PCI_COMMAND_IO_ENABLE;
+csr |= PCI_COMMAND_MASTER_ENABLE | PCI_COMMAND_MEM_ENABLE |
+    PCI_COMMAND_IO_ENABLE;
 pci_conf_write(pc, tag, PCI_COMMAND_STATUS_REG, csr);
```

That made the BARs accessible. It did not make the queues reliable. The second half concerns time rather than address space.

The [Virtio 1.0 specification](https://docs.oasis-open.org/virtio/virtio/v1.0/virtio-v1.0.html) requires a driver resetting a device to write status zero and then wait until a subsequent read returns zero. VZ completes that reset asynchronously. NetBSD wrote zero and continued into queue configuration before VZ had reported completion. The writes appeared to happen, but the queue state did not survive.

```diff
 bus_space_write_1(iot, ioh, VIRTIO_CONFIG1_DEVICE_STATUS,
     status | old);
+if (status == 0) {
+    /* Virtio 1.0 requires the driver to wait for reset completion. */
+    while (bus_space_read_1(iot, ioh,
+        VIRTIO_CONFIG1_DEVICE_STATUS) != 0)
+        DELAY(1);
+}
```

Waiting for the status byte closed the race. Console, block, entropy and network devices all use the same Virtio PCI transport, so this one correction sits below most of the useful machine.

## Turn a Virtio port into the kernel console

VZ connects the host terminal to a Virtio console device. NetBSD 11’s [`viocon(4)`](https://man.netbsd.org/viocon.4) attaches that device as a tty, but it does not promote port zero to the kernel console. A tty appearing during autoconfiguration is not enough for `printf`, DDB and the polling console operations used during shutdown or panic handling.

The patch is substantially derived from kernel-console support originally written by Taylor R. Campbell and carried as patch 2 in Emile “iMil” Heitor’s [ongoing full VirtIO console patch series](https://mail-index.netbsd.org/port-amd64/2026/01/22/msg003793.html). I adapted its late-console portion to NetBSD 11 and the VZ configuration. The project does not include the series’ early Virtio-MMIO console or multiport work.

After `viocon(4)` has created and filled port zero’s queues, the [console patch](https://github.com/tbarabosch/netbsd-vz/blob/main/patches/viocon-console.patch) installs its `consdev` operations:

```diff
+if (cn_tab == NULL || cn_tab->cn_dev == NODEV ||
+    cn_tab->cn_pri < CN_NORMAL) {
+    sc->sc_ports[0]->vp_cntab = (struct consdev) {
+        .cn_pollc = viocon_cnpollc,
+        .cn_getc = viocon_cngetc,
+        .cn_putc = viocon_cnputc,
+        .cn_dev = VIOCONDEV(device_unit(self), 0),
+        .cn_pri = CN_REMOTE,
+    };
+    cn_set_tab(&sc->sc_ports[0]->vp_cntab);
+    printf("NetBSD/VZ viocon console attached\n");
+}
```

The distinction between *late* and *early* matters. Live output begins only after FDT, PCI, Virtio PCI and `viocon(4)` have attached. Messages from kernel entry through that point remain invisible on the terminal. The smoke test runs `dmesg` after login to recover them. This limitation makes early boot issues harder to diagnose.

## Put an FFS root behind Virtio block

A kernel reaching a root-device prompt proves less than it first appears to. I wanted the normal NetBSD base system to reach `init`, start `getty`, accept a console login and shut itself down.

The disk builder downloads the official NetBSD 11.0 `evbarm-aarch64` [`base` and `etc` sets](https://cdn.netbsd.org/pub/NetBSD/NetBSD-11.0/evbarm-aarch64/binary/sets/) and verifies their SHA-512 hashes. NetBSD’s cross-built `nbmakefs` creates a little-endian FFSv1 filesystem. `nbgpt` wraps it in a fixed 1 GiB RAW disk with a protective MBR, primary and backup GPT, and one NetBSD FFS partition beginning at LBA 2048.

Both the GPT wedge and the filesystem use the label `netbsd-root`. The kernel command line selects `root=NAME=netbsd-root`, avoiding a dependency on whichever unit number autoconfiguration assigns. In the accepted run, Virtio block attached as `ld0`, wedge discovery created `dk0`, and the kernel mounted FFS from that wedge.

The root overlay changes only `fstab`, `rc.conf` and `ttys`. It enables a secure console login, disables ordinary network services and starts DHCP only when a `vioif` interface exists. The release set’s empty root password is retained for this isolated console proof. Networking remains opt-in, and enabling remote services without first setting a password is not recommended.

## Negotiate the MTU that VZ advertises

At this point, the offline guest has no NIC. Adding a `VZVirtioNetworkDeviceConfiguration` with VZ NAT exposes another Virtio PCI function, but the first attempts did not produce a usable `vioif` interface.

VZ advertises the Virtio network `VIRTIO_NET_F_MTU` feature. In this configuration, feature negotiation failed until the NetBSD driver accepted that feature and read the advertised MTU. The [network patch](https://github.com/tbarabosch/netbsd-vz/blob/main/patches/vioif-mtu.patch) adds the bit to the requested feature set and applies the device value to the interface:

```diff
+#define VIRTIO_NET_F_MTU        __BIT(3)

 req_features =
-    VIRTIO_NET_F_MAC | VIRTIO_NET_F_STATUS | VIRTIO_NET_F_CTRL_VQ |
-    VIRTIO_NET_F_CTRL_RX | VIRTIO_F_NOTIFY_ON_EMPTY;
+    VIRTIO_NET_F_MTU | VIRTIO_NET_F_MAC | VIRTIO_NET_F_STATUS |
+    VIRTIO_NET_F_CTRL_VQ | VIRTIO_NET_F_CTRL_RX |
+    VIRTIO_F_NOTIFY_ON_EMPTY;

+if (features & VIRTIO_NET_F_MTU)
+    ifp->if_mtu = virtio_read_device_config_2(vsc,
+        VIRTIO_NET_CONFIG_MTU);
```

With that change, `vioif0` attached with an MTU of 1500, reported active carrier, acquired an IPv4 address by DHCP and installed the VZ NAT gateway as its default route.

## Companion Code

The companion code separates building from booting. An Apple silicon Mac, the selected Xcode or Command Line Tools, `make`, network access to the official NetBSD archives and roughly 10 GiB of free space are enough for the first build. No prebuilt NetBSD cross compiler is assumed.

```console
$ git clone https://github.com/tbarabosch/netbsd-vz.git
$ cd netbsd-vz
$ make build
$ make disk
$ make smoke
```

`make build` verifies the source archives, builds the cross tools and produces the 8 MiB VZ64 Image. `make disk` verifies the binary sets and assembles the GPT/FFSv1 root disk. The default `make smoke` invocation does not attach a network device. It proves the console, root mount, userspace and guest-driven poweroff without giving the guest an external path.

Networking is a separate test:

```console
$ make smoke-network
```

This adds VZ NAT, waits for DHCP and checks both the local gateway and public IPv4 reachability (`8.8.8.8`).

Both automated targets boot a copy-on-write clone of the default RAW disk and delete it after success. Interactive `make run` and `make run-network` do the same. Supplying an explicit `DISK=/absolute/path/root.raw` instead attaches that file directly and makes guest changes persistent.

## Summing Up

I tested the result on Apple silicon with macOS 26.6.1, Xcode 26.6 and Swift 6.3.3. The runner used one virtual CPU and 512 MiB of RAM. The following are selected, non-contiguous lines from fresh offline and network runs; device unit numbers, addresses and timings can change between boots.

```text
NetBSD/VZ viocon console attached
ld0 at virtio1: features: 0x110002244<V1,INDIRECT_DESC,DISCARD,FLUSH,BLK_SIZE,SEG_MAX>
viornd0 at virtio2: features: 0x110000000<V1,INDIRECT_DESC>
dk0 at ld0: "netbsd-root", 2093056 blocks at 2048, type: ffs
root on dk0
root file system type: ffs

NetBSD 11.0 (VZ64) #0: Tue Aug 18 20:55:23 CEST 2026
NETBSD_VZ_USERSPACE_OK

vioif0 at virtio0: features: 0x130010028<V1,EVENT_IDX,INDIRECT_DESC,STATUS,MAC,MTU>
vioif0: flags=0x8b43<UP,BROADCAST,RUNNING,PROMISC,ALLMULTI,SIMPLEX,MULTICAST> mtu 1500
        status: active
        inet 192.168.65.12/24 broadcast 192.168.65.255 flags 0
NETBSD_VZ_NETWORK_GATEWAY_192.168.65.1
NETBSD_VZ_NETWORK_PUBLIC_8.8.8.8
NETBSD_VZ_NETWORK_OK

unmounted /dev/dk0 on / type ffs
Observed NETBSD_VZ_USERSPACE_OK and NETBSD_VZ_NETWORK_OK and guest poweroff; smoke test passed.
```

The offline test separately rejects an unexpected `vioif` attachment. The network variant requires an active interface, a non-link-local DHCP address, a default route, one successful ping to the VZ gateway and one to `8.8.8.8`. Both variants log in through the Virtio console, execute a userspace marker, issue `shutdown -p now`, wait for a clean FFS unmount and require the VZ virtual machine to reach its stopped state.

This shows that NetBSD support yet another platform. All in all, getting a NetBSD kernel to boot was easier than expected. First, NetBSD's stellar cross-compilation feature and portability capabilities made it easy to achieve that directly on my macOS machine. Second, partnering with Codex to overcome the obstacles during boot and later stages helped me to overcome technical isseus that would have taken days to solve in a couple of hours only.

The patched NetBSD 11 kernel and root disk boot on the VZ platform and drive console, entropy, block and optional network devices through shutdown. I did not enable an early console, EFI boot, graphics, shared directories, suspend and resume, multiple volumes or support in an unmodified NetBSD release. The full build, patch rationale and disk layout are documented in the companion repository’s [technical account](https://github.com/tbarabosch/netbsd-vz/blob/main/docs/TECHNICAL.md).

As a next step, I'd like to engage with the NetBSD community and see which patches could actually reach NetBSD-current. The console work should remain aligned with the existing VirtIO work mentioned before, while the reset, PCI and network changes probably need testing beyond this single VZ device model.

Furthermore, there is already an [open request for FreeBSD support](https://github.com/apple/containerization/issues/226) in Apple’s Containerization project. The next experiment is to find out whether this NetBSD guest can be integrated into [Apple Container](https://github.com/apple/container), but that belongs to another article.
