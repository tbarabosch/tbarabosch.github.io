---
title: 'Detecting Apple Container from inside the guest'
date: '2026-08-12T12:00:00+02:00'
last_modified_at: '2026-08-12T12:00:00+02:00'
author: tbarabosch
layout: post
tags:
  - Apple Containers
  - virtualization
  - macOS
---

I have been using Apple’s open source [`container`](https://github.com/apple/container) for most of my local Linux work. Recently, I wanted a C++ program to print whether it was running inside an Apple container. There was one restriction: the program could only inspect the guest. No environment variable passed from the host, no call to the `container` CLI and no host-mounted marker file.

At first, this sounds like a simple task. Docker creates `/.dockerenv`, Podman creates `/run/.containerenv` and systemd defines a common container interface. Unfortunately, none of them tells us that Apple `container` started the process.

After checking the guest and the Containerization source code, I found two useful traces:

- `apple,virtualization-generic-platform` in the device tree
- `init=/sbin/vminitd` in the kernel command line

Let’s have a look at where these values come from and how useful they are.

<!--more-->

## One VM for every container

Before looking for traces, we have to understand how Apple runs the container. Apple `container` uses normal OCI images, but it does not put all containers into one shared Linux VM. It creates one lightweight VM for every container.

The [`container`](https://github.com/apple/container) CLI talks to `container-apiserver`. A runtime helper starts the VM with macOS Virtualization.framework. Inside the VM, `vminitd` prepares the OCI container and starts the requested process.

```text
macOS

container CLI
     |
     v
container-apiserver
     |
     v
container-runtime-linux
     |
     v
Virtualization.framework
     |
     v
Linux VM: vminitd -> OCI process
```

The VM is mostly hidden from the user. Starting Alpine still looks like a regular container command:

```console
$ container run --rm alpine echo hello
hello
```

However, from inside the guest we can see traces of both layers: Virtualization.framework and Containerization.

## Trying the usual container checks

First, I checked the files commonly used to detect Docker, Podman and systemd containers:

```console
$ test -e /.dockerenv && echo yes || echo no
no
$ test -e /run/.containerenv && echo yes || echo no
no
$ test -e /run/systemd/container && echo yes || echo no
no
```

No luck. Apple does not create any of these files. The `container=` variable recommended by the [systemd container interface](https://systemd.io/CONTAINER_INTERFACE/) was also missing from the environment of PID 1.

The cgroup path did not reveal a runtime name either:

```console
$ cat /proc/self/cgroup
0::/
```

We can still detect generic container behavior. The process runs in a non-initial PID namespace and the entrypoint becomes PID 1. But this only tells us that namespaces are in use. It does not tell us whether the runtime is Apple `container`, Docker or something else.

The VM also exposes VIRTIO devices such as `/dev/vsock`, `/dev/hvc0` and virtio block devices. Again, these devices are not unique to Apple. QEMU, Firecracker and other virtual machine monitors use VIRTIO as well.

So, the common checks are either absent or too generic. We need something more specific.

## The Apple Virtualization marker

On ARM systems, Linux obtains a description of the hardware from the device tree. Let’s inspect the hypervisor node inside an Apple container:

```console
$ tr '\0' '\n' </proc/device-tree/hypervisor/compatible
apple,virtualization-generic-platform
```

The same value is available at `/sys/firmware/devicetree/base/hypervisor/compatible`. Both files contain a NUL-terminated device-tree string, hence the `tr` command in the example.

Where does this string come from? It is not part of the OCI image and the `container` project does not write it. macOS Virtualization.framework creates the device tree when it builds the virtual ARM platform. On my Mac, the string is embedded in the Virtualization VM service next to the names of other device-tree properties:

```text
compatible
fixed-clock
hypervisor
apple,virtualization-generic-platform
cpu@%x
arm,arm-v8
```

Linux receives this device tree during boot and exposes the value through `/proc/device-tree` and `/sys/firmware/devicetree`. The kernel also creates the following modalias:

```text
of:NhypervisorT(null)Capple,virtualization-generic-platform
```

The Containerization code creates a [`VZGenericPlatformConfiguration`](https://github.com/apple/containerization/blob/0.33.3/Sources/Containerization/VZVirtualMachineInstance.swift#L517-L527), which Apple describes as the platform configuration for a generic Intel or ARM VM.

At this point, we know that the program runs in a Linux VM created by Apple Virtualization.framework. This is already useful, but it is not enough. Anyone can create a Linux VM with Virtualization.framework without using Apple `container`.

## The Containerization marker

The second trace is in `/proc/cmdline`:

```console
$ cat /proc/cmdline
console=hvc0 tsc=reliable panic=0 oops=panic lsm=lockdown,capability,landlock,yama,apparmor init=/sbin/vminitd ro rootfstype=ext4 root=/dev/vda
```

The interesting argument is `init=/sbin/vminitd`. It instructs Linux to start `vminitd` as the init process.

This is not an accidental value. The function [`linuxCommandline`](https://github.com/apple/containerization/blob/0.33.3/Sources/Containerization/VZVirtualMachineInstance.swift#L569-L599) in Containerization 0.33.3 appends it to the kernel command line:

```swift
args.append("init=/sbin/vminitd")
args.append("ro")
```

The `container` 1.0.0 release that I tested [pins Containerization 0.33.3](https://github.com/apple/container/blob/ee848e3ebfd7c73b04dd419683be54fb450b8779/Package.swift#L26). The current Containerization code still uses the same argument.

Checking whether `/sbin/vminitd` exists does not work. The runtime boots from an initial filesystem and later installs the application root filesystem. As a result, `/sbin/vminitd` was not visible in my Alpine container. The boot argument remains in `/proc/cmdline`, so this is the better place to look.

## Putting both markers together

Now we have one trace from the VM and one from the container runtime:

```text
Apple VZ marker   vminitd marker   Result
---------------   --------------   -----------------------------
yes               yes              likely Apple container
yes               no               Apple Virtualization VM
no                yes              Containerization on another VMM
no                no               not detected
```

I tested both files in Alpine, Debian and the long-running buildkit container. They were also readable as UID 65534, so the check does not require root privileges.

The following two checks are enough for a small diagnostic program:

```cpp
bool IsAppleVirtualizationPlatform() {
    const auto compatible = readFile(
        "/proc/device-tree/hypervisor/compatible");
    return compatible &&
        compatible->find("apple,virtualization-generic-platform") !=
            std::string::npos;
}

bool IsVminitdArgumentPresent() {
    const auto bootArgs = readFile("/proc/cmdline");
    return bootArgs &&
        bootArgs->find("init=/sbin/vminitd") != std::string::npos;
}
```

The complete C++17 example is available in [`apple_container_detect`](https://github.com/tbarabosch/macos-re/tree/main/apple_container_detect). Its runner starts an Ubuntu container, compiles the probe inside the disposable guest and prints both results:

```console
$ git clone https://github.com/tbarabosch/macos-re.git
$ cd macos-re/apple_container_detect
$ ./run.sh
...
Checking for traces of Apple containerization...
Apple virtualization compatible: True
vminitd argument present in /proc/cmdline: True
```

That’s it. The combination works well for diagnostics and does not need any help from the host.

There is one important limitation: these values are implementation details. They are not signed or authenticated. A custom VM can copy them, and a future Apple release can change them. Therefore, I would not use this check for a security decision. For a support bundle or a debug log, however, it is a practical way to detect the current Apple container runtime from inside the guest.
