---
title: 'Moving NetBSD on Apple VZ from direct boot to EFI'
date: '2026-08-27T22:00:00+02:00'
last_modified_at: '2026-08-27T22:00:00+02:00'
author: tbarabosch
layout: post
image:
  path: /assets/images/posts/moving-netbsd-on-apple-vz-from-direct-boot-to-efi/social-card.png
  width: 1200
  height: 630
social_card:
  layout: ascii
  subtitle: 'EFI removed guest-specific boot patches and moved closer to stock NetBSD.'
  eyebrow: 'Systems Security / NetBSD'
  panel_label: 'Direct boot / EFI'
  source:
    language: text
    occurrence: 1
  highlight: 'four patch files'
  accent: 'three generic Virtio patches'
tags:
  - NetBSD
  - virtualization
  - macOS
---

The first version of [`netbsd-vz`](https://github.com/tbarabosch/netbsd-vz) booted NetBSD 11 directly through Apple's `VZLinuxBootLoader`. It worked, but the host had to prepare a padded AArch64 kernel image and pass a flattened device tree (FDT) to a project-specific `VZ64` kernel. That experiment needed four NetBSD patch files, including changes for the early bootstrap and console.

The same guest now boots through Virtualization.framework's generic EFI platform. EFI starts NetBSD's vanilla `bootaa64.efi`, the loader enters a vanilla `GENERIC64` kernel configuration, and ACPI describes the virtual hardware. Three generic Virtio fixes remain. Everything specific to direct kernel booting is gone.

```text
direct boot                         EFI boot
-----------                         --------
host loads kernel + FDT             firmware loads stock NetBSD loader
four patch files                    three generic Virtio patches
custom VZ64 configuration           stock GENERIC64 configuration
```

This is not just one patch fewer, it is less Apple VZ related code that needs to be added to the upstream NetBSD kernel.

<!--more-->

## EFI on Apple VZ in a nutshell

EFI is the firmware interface between the virtual machine and its operating system loader. With Virtualization.framework, [`VZEFIBootLoader`](https://developer.apple.com/documentation/virtualization/vzefibootloader) provides that environment in Apple VZ Framework. A [`VZEFIVariableStore`](https://developer.apple.com/documentation/virtualization/vzefivariablestore) keeps the firmware's NVRAM-style state separately from the guest disk.

The disk contains a FAT32 EFI System Partition (ESP). When no more specific boot entry exists, the [UEFI removable-media rules](https://uefi.org/specs/UEFI/2.11/03_Boot_Manager.html#removable-media-boot-behavior) give AArch64 firmware a standard loader path: `EFI/BOOT/BOOTAA64.EFI`. The disk builder copies NetBSD 11's unmodified `bootaa64.efi` there. Firmware loads it, the loader finds the kernel, and the kernel takes over.

```text
VZEFIBootLoader
      |
      +-- EFI variable store
      |
      `-- GPT disk
            |
            +-- FAT32 ESP
            |     `-- EFI/BOOT/BOOTAA64.EFI
            |
            `-- FFS root
                  `-- /netbsd (GENERIC64)
```

EFI does not know anything special about this NetBSD-on-VZ experiment. It knows how to find and start an EFI application. NetBSD's loader knows how to start NetBSD.

After the loader hands over control, `GENERIC64` uses the ACPI tables exposed by VZ to discover the CPUs, GICv3 interrupt controller, timer, PCI host bridge, and the devices below it. Direct boot obtained similar information from the FDT supplied with the raw kernel image. Changing the discovery mechanism is what allows the standard kernel configuration to replace the custom `VZ64`.

## From direct boot to EFI

The [earlier direct-boot version](/porting-netbsd-to-apple-vz/) used an API named for Linux, although the interface accepted the raw AArch64 `Image` format that a cross-compiled NetBSD could also produce. The runner supplied that image and a command line. VZ placed an FDT in memory and passed its address in register `x0` when it entered the kernel.

That short route made the project responsible for details normally handled by firmware and the operating-system loader. The build padded the kernel to an 8 MiB reservation, regenerated its AArch64 image header, and rejected a kernel that grew into adjacent boot data. The kernel configuration enabled the FDT path and removed EFI and ACPI.

The EFI path moves those jobs into firmware and NetBSD's normal arm64 loader:

```text
DIRECT

VZLinuxBootLoader
        |
        v
padded raw AArch64 Image + command line
        |
        v
host-supplied FDT -> VZ64 kernel


EFI

VZEFIBootLoader
        |
        v
GPT + ESP -> stock bootaa64.efi
        |
        v
ACPI handoff -> stock GENERIC64 kernel
```

The result is closer to an ordinary bootable NetBSD disk. The host configures a generic machine and attaches devices; it no longer prepares the kernel's entry format or describes the platform through a direct-boot FDT.

![Animated condensed terminal transcript of NetBSD 11 booting through EFI on Apple VZ and shutting down cleanly](/assets/images/posts/moving-netbsd-on-apple-vz-from-direct-boot-to-efi/netbsd-vz-efi-boot.gif)

## Less Patches, Less Issues

The direct-boot tree carried four patch files with 378 lines between them. The [current patch directory](https://github.com/tbarabosch/netbsd-vz/tree/main/patches) contains three files with 70 lines.

```text
DIRECT BOOT: 4 files / 378 lines
        |
        +-- viocon-console.patch ------- removed
        +-- vz64-config.patch ----------- removed
        +-- vz-platform.patch
        |      |-- FDT/bootstrap -------- removed
        |      |-- no-match console ----- removed
        |      |-- PCI memory decode ---- kept, split out
        |      `-- Virtio reset wait ---- kept, split out
        `-- vioif-mtu.patch ------------- kept
                    |
                    v
EFI BOOT: 3 files / 70 lines
```

The old [`viocon-console.patch`](https://github.com/tbarabosch/netbsd-vz/blob/8da4fae201966eb433a84dd35cd2aeda0a9e038c/patches/viocon-console.patch) promoted Virtio console port zero to the kernel console. EFI lets NetBSD keep its normal GOP console instead, while a vanilla getty provides the interactive serial login later. The old [`vz64-config.patch`](https://github.com/tbarabosch/netbsd-vz/blob/8da4fae201966eb433a84dd35cd2aeda0a9e038c/patches/vz64-config.patch) defined exactly the direct-boot hardware subset. `GENERIC64` already includes the EFI, ACPI, PCI, and Virtio paths needed by the new machine.

The old [`vz-platform.patch`](https://github.com/tbarabosch/netbsd-vz/blob/8da4fae201966eb433a84dd35cd2aeda0a9e038c/patches/vz-platform.patch) mixed platform-specific and generic work. Its FDT mapping and empty-console accommodations disappear with direct boot. Its two reusable corrections survive as focused patches: enable PCI memory decoding for modern Virtio BARs, and wait until a Virtio 1.0 reset actually completes before configuring queues.

The current [`virtio-pci-memory.patch`](https://github.com/tbarabosch/netbsd-vz/blob/main/patches/virtio-pci-memory.patch) enables memory decoding alongside PCI bus mastering and I/O decoding. [`virtio-reset.patch`](https://github.com/tbarabosch/netbsd-vz/blob/main/patches/virtio-reset.patch) polls the device status after writing zero, as required before queue setup continues. [`vioif-mtu.patch`](https://github.com/tbarabosch/netbsd-vz/blob/main/patches/vioif-mtu.patch) negotiates the MTU feature advertised by VZ's network device and applies its value to the interface.

None of these three patches names Apple, changes EFI or ACPI, or defines a VZ platform. They are generic driver corrections and therefore much better upstream candidates than the old patches.

## Less Complexity during VM Creation and Booting

EFI did not make the machine smaller. It moved complexity out of the kernel delta and into conventional firmware, storage, and display interfaces.

```text
1,088 MiB RAW disk
+------------------------------------------------------+
| GPT | 64 MiB FAT32 ESP | FFSv1 root              | GPT |
+------------------------------------------------------+
          |                   |
          |                   `-- /netbsd + base system
          `-- BOOTAA64.EFI + boot.cfg

separate host state
+----------------------+       +----------------------+
| machine identifier   |       | EFI variable store   |
+----------------------+       +----------------------+
```

The runner now creates or reuses a generic machine identifier and EFI variable store. The VM also needs a Virtio GPU because EFI and early kernel output use the Graphics Output Protocol (GOP). The VZ Virtio serial device is not an EFI console, so a headless terminal stays quiet until NetBSD starts `getty` on `/dev/ttyVI00`. Earlier messages remain available through `dmesg` after login.

The ESP contains a small `boot.cfg` that asks the loader to start `netbsd` verbosely with `root=NAME=netbsd-root`. Using the GPT and FFS label avoids coupling the root filesystem to whichever device number autoconfiguration assigns. The default runner boots a copy-on-write clone of the published disk and creates temporary EFI state. Supplying explicit disk and state paths makes both persistent.

Firmware and `bootaa64.efi` also add work before the kernel starts. Direct boot remains attractive when a firmware-free path and a small boot chain matter more than matching ordinary hardware. For this proof of concept, however, boot speed was not the main requirement. Reducing NetBSD-specific changes was.

## Wrapping It Up

Moving to EFI made `netbsd-vz` less of a special NetBSD platform and more of a normal arm64 guest. Stock firmware conventions select the vanilla loader. The vanilla loader starts `GENERIC64`. ACPI is responsible for the hardware description. The remaining changes sit in Virtio drivers without anything specific to Apple VZ.

In the end, NetBSD 11 is not unmodified yet, but the platform-specific patch set is now gone. The repository's [technical documentation](https://github.com/tbarabosch/netbsd-vz/blob/main/docs/TECHNICAL.md) documents the disk geometry, runner state, build inputs, and current patches.
