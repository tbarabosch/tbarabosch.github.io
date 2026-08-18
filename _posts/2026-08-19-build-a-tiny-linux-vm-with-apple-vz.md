---
title: 'Build a tiny Linux VM with Apple VZ'
date: '2026-08-19T12:00:00+02:00'
last_modified_at: '2026-08-19T12:00:00+02:00'
author: tbarabosch
layout: post
toc: true
tags:
  - virtualization
  - macOS
---

While [detecting Apple Container from inside its Linux guest](/detecting-apple-container-from-inside-the-guest/), I found the marker `apple,virtualization-generic-platform` in the device tree. That trace told me that macOS Virtualization.framework had created the virtual machine. It did not show what the host had to configure before Linux could leave that trace behind.

I therefore built the smallest useful host-side experiment I could: a Swift program that boots an Alpine Linux kernel and initramfs on my Apple silicon Mac, connects the guest console to my terminal and optionally adds a disk or network interface. The default VM has no disk and no network. It still reaches a shell.

```text
container CLI
     |
     v
container runtime
     |
     v
Virtualization.framework
     |
-----+---------------- virtual machine boundary
     |
     v
Linux kernel -> initramfs -> process
```

Apple calls the API **Virtualization.framework**. Most of its types start with `VZ`, such as `VZVirtualMachine`, so this article uses *VZ* as informal shorthand. It is not a separate Apple product name.

The finished runner is small, but it still describes a complete hardware contract: how the kernel enters, which CPUs and memory exist, and which Virtio devices Linux can drive. The rest of this article assembles that machine from the host down.

<!--more-->

<nav class="post-toc" aria-labelledby="contents-heading" markdown="1">
<p id="contents-heading" class="manual-label">CONTENTS</p>

* TOC
{:toc}
</nav>

## Where VZ sits

Apple’s [Virtualization framework overview](https://developer.apple.com/documentation/virtualization) describes it as a high-level API for creating and managing virtual machines. The word *high-level* matters. At the other end of Apple’s virtualization APIs, [Hypervisor.framework](https://developer.apple.com/documentation/hypervisor) exposes virtual CPUs and memory. That is useful when a program wants to implement more of the virtual machine itself.

Virtualization.framework works with a larger unit. You give it a boot loader, CPU and memory limits, and a list of devices. It returns an object that starts, pauses, resumes and stops the resulting VM. Apple’s [WWDC22 virtualization overview](https://developer.apple.com/videos/play/wwdc2022/10002/) places both APIs above virtualization support built into the macOS kernel.

```text
host program
     |
     +--> Hypervisor.framework: virtual CPUs and memory
     |
     `--> Virtualization.framework: boot, devices, lifecycle
                          |
                          v
          macOS kernel virtualization support
                          |
                          v
                    Apple silicon
                          |
--------------------------+---------- VM boundary
                          |
                       Linux
```

This distinction saves a considerable amount of code. The runner does not implement a PCI host bridge, interrupt controller, block device or network card. VZ constructs the machine and implements the host side of those devices.

Linux still owns the other half. It must accept the selected boot convention, discover the platform and load drivers for the devices. A short host program can therefore create a real VM.

VZ also stops below distribution management. It does not select a Linux release, download a kernel, create users, install packages or decide what should run as PID 1. Apple’s Linux VM instructions leave obtaining the kernel and RAM disk to the application. This is different from the `container` command used in the earlier experiment: the container runtime handles image and process conventions above the VM, while VZ deals with the machine below them.

That boundary is useful for this experiment. You can change one host-side configuration and then ask Linux what appeared. There is no daemon in the guest translating your intent into a different device layout. The configuration says what hardware to construct; the kernel log and `/sys` show what Linux managed to use.

## Describe the machine before starting it

The center of the API is [`VZVirtualMachineConfiguration`](https://developer.apple.com/documentation/virtualization/vzvirtualmachineconfiguration). It is a description, not a running VM. The runner selects [`VZGenericPlatformConfiguration`](https://developer.apple.com/documentation/virtualization/vzgenericplatformconfiguration), uses the framework’s minimum allowed CPU count, and assigns 512 MiB of memory unless the framework requires more.

It also contains arrays of device configurations. An empty network array means no virtual NIC. Adding a `VZVirtioNetworkDeviceConfiguration` before startup changes the hardware Linux discovers. Apple’s Linux VM guide notes that [devices cannot be added to a running VM](https://developer.apple.com/documentation/virtualization/creating-and-running-a-linux-virtual-machine).

```text
VZVirtualMachineConfiguration
|-- platform: generic
|-- boot loader: Linux kernel + initramfs
|-- CPUs: framework minimum
|-- memory: at least 512 MiB
|-- serial ports: Virtio console
|-- entropy devices: Virtio RNG
|-- storage devices: [] or Virtio block
`-- network devices: [] or Virtio NIC
                 |
                 v
              validate()
                 |
                 v
           VZVirtualMachine
```

The process also needs Apple’s [`com.apple.security.virtualization` entitlement](https://developer.apple.com/documentation/virtualization/adding-the-virtualization-entitlement-to-your-project). The companion script compiles the Swift source and ad-hoc signs the executable with that entitlement.

Before constructing the VM, the runner calls [`validate()`](https://developer.apple.com/documentation/virtualization/vzvirtualmachineconfiguration/validate%28%29). This catches host-side configuration problems, including incompatible values and missing requirements. It does not boot Linux or prove that the guest has a suitable driver. That proof only arrives when the kernel starts talking through the configured devices.

The separation between configuration and runtime objects is visible throughout the API. A `VZVirtioNetworkDeviceConfiguration` belongs to the description assembled before startup. If the VM starts with it, the corresponding runtime network device is available through `VZVirtualMachine`. The class names are long, but they make the phase change hard to miss: first describe and validate, then instantiate and operate.

## Boot Linux directly

Apple documents an additive process for [creating and running a Linux VM](https://developer.apple.com/documentation/virtualization/creating-and-running-a-linux-virtual-machine): obtain an architecture-matched kernel and RAM disk, configure the machine, create the runtime object and start it. This experiment follows the direct-kernel branch of that process rather than installing a distribution through firmware.

The wrapper downloads the official [Alpine Linux 3.24.1](https://www.alpinelinux.org/posts/Alpine-3.24.1-released.html) ARM64 virtual ISO and verifies Alpine’s published SHA-256 checksum. Alpine wraps its compressed kernel in an EFI executable, so the wrapper extracts the embedded raw AArch64 `Image` and verifies the `ARMd` magic at offset 56. The initramfs can remain compressed because Linux unpacks it after entry.

That normalization step came from the experiment, not from the filename. The ISO calls the file `vmlinuz-virt`, and macOS identifies it as an AArch64 EFI application. Passing that wrapper directly to the direct kernel loader is the wrong interface. The companion scans it for the embedded gzip member, decompresses the candidate and accepts the result only if it contains the AArch64 Image header. A checksum proves that the ISO matches Alpine’s published artifact; the header check proves that the extracted file has the format this boot path expects.

[`VZLinuxBootLoader`](https://developer.apple.com/documentation/virtualization/vzlinuxbootloader) takes the kernel URL, optional initramfs URL and kernel command line. VZ maps those inputs into guest memory and enters the kernel. The command line sends the console to `hvc0` and asks Linux to start the initramfs shell directly:

```text
host filesystem
|-- raw ARM64 Image --------+
|-- Alpine initramfs -------+--> VZLinuxBootLoader
`-- console=hvc0 -----------+          |
                                       v
                                  guest memory
                                       |
                                       v
                              Linux -> /bin/sh
```

The essential Swift fits in one screen. The argument parser, file checks and error handling remain in the [complete companion](https://github.com/tbarabosch/macos-re/tree/main/vz_linux_runner).

```swift
let serial = VZVirtioConsoleDeviceSerialPortConfiguration()
serial.attachment = VZFileHandleSerialPortAttachment(
    fileHandleForReading: FileHandle.standardInput,
    fileHandleForWriting: FileHandle.standardOutput
)

let loader = VZLinuxBootLoader(kernelURL: kernelURL)
loader.initialRamdiskURL = initramfsURL
loader.commandLine = "console=hvc0 rdinit=/bin/sh"

let config = VZVirtualMachineConfiguration()
config.platform = VZGenericPlatformConfiguration()
config.bootLoader = loader
config.cpuCount = VZVirtualMachineConfiguration.minimumAllowedCPUCount
config.memorySize = max(
    VZVirtualMachineConfiguration.minimumAllowedMemorySize,
    512 * 1024 * 1024
)
config.serialPorts = [serial]
config.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
try config.validate()
```

This is not a Linux installation. The initramfs contains BusyBox and the modules needed for the experiment, which is enough to inspect the virtual hardware and power off. There is no persistent root filesystem unless you explicitly request one.

Using `rdinit=/bin/sh` is what keeps the test narrow. Linux skips Alpine’s normal early userspace sequence and starts the shell stored in the initramfs. The shell disappears with the VM, which is fine: its job is to mount `/proc` and `/sys`, load a few modules and report what it sees. A distribution installer would add storage layout, service startup and user configuration that do not help explain VZ.

## Attach only the devices Linux needs

VZ often separates a guest-visible device configuration from its host-side attachment. A Virtio block device is what Linux sees; a disk-image attachment tells VZ which host file supplies its bytes. The same pattern appears in networking and serial I/O.

The default runner always adds Apple’s [`VZVirtioConsoleDeviceSerialPortConfiguration`](https://developer.apple.com/documentation/virtualization/vzvirtioconsoledeviceserialportconfiguration). Its [`VZFileHandleSerialPortAttachment`](https://developer.apple.com/documentation/virtualization/vzfilehandleserialportattachment/init%28filehandleforreading%3Afilehandleforwriting%3A%29) names handles from the guest’s perspective. `fileHandleForReading` carries host input toward Linux; `fileHandleForWriting` receives bytes that Linux writes.

```text
host stdin  ---> fileHandleForReading ---> guest /dev/hvc0

host stdout <--- fileHandleForWriting <--- guest /dev/hvc0
```

That naming is easy to read backward when both ends are file handles. Connecting standard input and output makes the terminal interactive without a GUI. The default configuration also includes a [`VZVirtioEntropyDeviceConfiguration`](https://developer.apple.com/documentation/virtualization/vzvirtioentropydeviceconfiguration), which exposes a Virtio-compliant entropy source. After loading Alpine’s `virtio-rng` module, Linux creates `/dev/hwrng`.

The `--disk` option creates a sparse 64 MiB raw file. A [`VZDiskImageStorageDeviceAttachment`](https://developer.apple.com/documentation/virtualization/vzdiskimagestoragedeviceattachment), one concrete [`VZStorageDeviceAttachment`](https://developer.apple.com/documentation/virtualization/vzstoragedeviceattachment), opens that file. [`VZVirtioBlockDeviceConfiguration`](https://developer.apple.com/documentation/virtualization/vzvirtioblockdeviceconfiguration) presents the Virtio block interface to Linux. Loading `virtio_blk` produces `/dev/vda`.

```text
host scratch.raw
       |
       v
VZDiskImageStorageDeviceAttachment
       |
       v
VZVirtioBlockDeviceConfiguration
       |
-------+---------------------------- VM boundary
       |
       v
Linux virtio_blk -> /dev/vda
```

The disk is intentionally empty. The experiment tests attachment and enumeration, not a filesystem. Linux reports 131,072 logical blocks of 512 bytes and turns that geometry into the expected 64 MiB device. The wrapper removes the sparse host file after the VM exits, so repeated runs do not inherit guest state.

Networking is equally explicit. `--network` adds a [`VZVirtioNetworkDeviceConfiguration`](https://developer.apple.com/documentation/virtualization/vzvirtionetworkdeviceconfiguration) with a random locally administered MAC address. Its [`VZNATNetworkDeviceAttachment`](https://developer.apple.com/documentation/virtualization/vznatnetworkdeviceattachment) routes guest packets through NAT on the host. Without that option, the guest has only loopback.

```text
Linux eth0
     |
     v
Virtio network device
     |
-----+------------------------------ VM boundary
     |
     v
VZ NAT attachment -> macOS network path
```

The device and attachment are related, but they are not interchangeable. Linux negotiates with the Virtio device. The attachment decides where the host side sends the resulting bytes.

## Start the VM and check the guest

After validation, the runner creates [`VZVirtualMachine`](https://developer.apple.com/documentation/virtualization/vzvirtualmachine) and starts it asynchronously. The framework exposes a [state machine](https://developer.apple.com/documentation/virtualization/vzvirtualmachine/state-swift.enum) rather than pretending that start and stop are instantaneous operations.

```text
          start                      stop
stopped -------> starting -------> running -------> stopping
   ^                |                  |                 |
   |                +-------> error <--+-----------------+
   |                                                   |
   +---------------------------------------------------+
                      stop complete
```

I ran the experiment on Apple silicon with macOS 26.6.1, Xcode 26.6, Swift 6.3.3 and the macOS 26.5 SDK. The guest artifact was Alpine 3.24.1 for AArch64. After installing BusyBox’s applet links, mounting `devtmpfs`, `/proc` and `/sys`, and loading `virtio-rng`, the default guest reported:

```console
~ # uname -a
Linux (none) 6.18.35-0-virt #1-Alpine ... aarch64 Linux
~ # cat /proc/cmdline
console=hvc0 rdinit=/bin/sh
~ # ls -l /dev/hvc0 /dev/hwrng
crw-------  1 root root 229,   0 ... /dev/hvc0
crw-------  1 root root  10, 183 ... /dev/hwrng
~ # for n in /sys/class/net/*; do echo ${n##*/}; done
lo
```

The optional paths matched the host configuration. With `--disk`, loading `virtio_blk` produced a 64 MiB `/dev/vda`. With `--network`, loading `virtio_net` produced `eth0`; BusyBox obtained `192.168.65.7/24` from the VZ NAT service and reached its `192.168.65.1` gateway. The test did not contact a public host.

Those checks were performed separately as well as together. The default guest exposed Virtio device IDs for only its console and entropy source and listed `lo` as its sole network interface. The disk run added one block device. The network run added one NIC and no disk. Finally, the combined invocation exposed all four devices without changing the kernel or initramfs. This is a small but useful control: the difference observed by Linux followed the difference in the host configuration.

Finally, `poweroff -f` stopped the guest and VZ moved back to the stopped state. This closes the evidence loop: the Swift configuration requested specific hardware, Linux discovered and drove that hardware, and a guest action changed the host-visible VM lifecycle.

## The rest of the map

Booting a shell with a console, entropy source, disk and NIC covers only a small corner of Virtualization.framework. The rest of the Linux-facing surface is easier to read as groups of capabilities than as one long list of classes:

```text
Virtualization.framework
|
|-- presentation
|   |-- Virtio graphics
|   `-- audio
|
|-- host <-> guest exchange
|   |-- VirtioFS
|   |-- Virtio sockets
|   `-- Rosetta directory share
|
|-- resource control
|   `-- memory balloon
|
`-- machine capabilities
    |-- save / restore
    `-- nested virtualization
```

Presentation starts with [Virtio graphics](https://developer.apple.com/documentation/virtualization/vzvirtiographicsdeviceconfiguration) and [audio](https://developer.apple.com/documentation/virtualization/audio). These APIs add virtual devices; Linux still needs the corresponding guest drivers and userspace to turn them into a desktop or a sound path.

For host-to-guest exchange, Apple provides [VirtioFS directory sharing](https://developer.apple.com/documentation/virtualization/vzvirtiofilesystemdeviceconfiguration), [Virtio sockets](https://developer.apple.com/documentation/virtualization/sockets) and a [Rosetta directory share](https://developer.apple.com/documentation/virtualization/vzlinuxrosettadirectoryshare). These are distinct contracts: a shared directory, a socket transport and access to the Rosetta runtime are not variations of the same device.

The remaining branches change resource or machine behavior. A [Virtio memory balloon](https://developer.apple.com/documentation/virtualization/vzvirtiotraditionalmemoryballoondeviceconfiguration) provides a way to reclaim guest memory. Apple also documents [saving and restoring VM state](https://developer.apple.com/videos/play/wwdc2023/10007/) and exposes [nested virtualization](https://developer.apple.com/documentation/virtualization/vzgenericplatformconfiguration) through the generic platform configuration.
