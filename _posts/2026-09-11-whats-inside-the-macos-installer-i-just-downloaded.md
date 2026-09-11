---
title: "What's inside the macOS installer I just downloaded?"
date: '2026-09-11T12:00:00+02:00'
last_modified_at: '2026-09-11T12:00:00+02:00'
author: tbarabosch
layout: post
toc: true
image:
  path: /assets/images/posts/whats-inside-the-macos-installer-i-just-downloaded/social-card.png
  width: 1200
  height: 630
social_card:
  layout: ascii
  subtitle: 'A disk image outside, a signed XAR and two component packages inside.'
  eyebrow: 'Systems Security / macOS installer'
  panel_label: 'DMG -> PKG -> payload'
  source:
    language: text
    occurrence: 2
  highlight: '`-- VirtualBox.pkg'
  accent: 'UDIF + APFS'
tags:
  - systems security
  - macOS
---

I usually expect a macOS download to be an application bundled in a DMG, or a PKG hiding in one. The official Oracle VirtualBox installer gives us the second case. That is useful because a DMG and a PKG are often treated as the same kind of installer. They are not.

Here, *Installer* means Apple's Installer application: the macOS program that opens a `.pkg`, interprets its distribution definition and presents the installation choices. Apple describes that role in its [Installer documentation](https://developer.apple.com/documentation/installer_js).

[Oracle's instructions](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/installation.html) say to mount the disk image and then open `VirtualBox.pkg`. I wanted to know what happens between those clicks, which files the package contains and which scripts that application would run. None of that requires starting Installer or executing extracted programs.

I used the Apple Silicon build of VirtualBox 7.2.12 on an `arm64` Mac running macOS 26.6.2. Oracle publishes the download and its checksum in the [7.2.12 release directory](https://download.virtualbox.org/virtualbox/7.2.12/):

```console
$ curl --fail --location --remote-name \
    https://download.virtualbox.org/virtualbox/7.2.12/VirtualBox-7.2.12-174389-macOSArm64.dmg
$ curl --fail --location --remote-name \
    https://download.virtualbox.org/virtualbox/7.2.12/SHA256SUMS
$ grep 'VirtualBox-7.2.12-174389-macOSArm64.dmg$' SHA256SUMS
e6e7158592392486974f312ce85a8a2fff3673eca2c643cbd6a0a9bbf8fac07b *VirtualBox-7.2.12-174389-macOSArm64.dmg
$ shasum -a 256 VirtualBox-7.2.12-174389-macOSArm64.dmg
e6e7158592392486974f312ce85a8a2fff3673eca2c643cbd6a0a9bbf8fac07b  VirtualBox-7.2.12-174389-macOSArm64.dmg
```

The hashes match, so the rest refers to that exact file.

<!--more-->

<nav class="post-toc" aria-labelledby="contents-heading" markdown="1">
<p id="contents-heading" class="manual-label">CONTENTS</p>

* TOC
{:toc}
</nav>

## The first magic is misleading

The first result from `file` is correct, but not especially helpful:

```console
$ file VirtualBox-7.2.12-174389-macOSArm64.dmg
VirtualBox-7.2.12-174389-macOSArm64.dmg: bzip2 compressed data, block size = 100k
```

The disk image uses bzip2 compression, but it is not merely a `.bz2` file. Apple's UDIF format keeps its identifying `koly` structure in the final 512 bytes rather than at offset zero.

```console
$ tail -c 512 VirtualBox-7.2.12-174389-macOSArm64.dmg | \
    /usr/bin/hexdump -C -n 32
```

```text
00000000  6b 6f 6c 79 00 00 00 04  00 00 02 00 00 00 00 01  |koly............|
00000010  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00000020
```
{: data-language="HEXDUMP" }

`hdiutil` knows how to interpret the whole file and gives the less surprising answer:

```console
$ hdiutil imageinfo VirtualBox-7.2.12-174389-macOSArm64.dmg | \
    grep -E '^(Format Description|Class Name|Checksum Type|Format:)'
Format Description: UDIF read-only compressed (bzip2)
Class Name: CUDIFDiskImage
Checksum Type: CRC32
Format: UDBZ
```

The download is a read-only compressed disk image containing a filesystem. Apple also uses UDIF images in its current [Mac software distribution guidance](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution).

## Checking and mounting the DMG

The SHA-256 pins the download, while the CRC stored in the image checks its internal chunks and partition structures. `hdiutil verify` walks those structures without mounting the volume:

```console
$ hdiutil verify VirtualBox-7.2.12-174389-macOSArm64.dmg 2>&1 | tail -3
  GPT Header (Backup GPT Header : 7): verified CRC32 $18631006
verified CRC32 $39E33C33
hdiutil: verify: checksum of "VirtualBox-7.2.12-174389-macOSArm64.dmg" is VALID
```

The image itself is code-signed as well. I filtered the verbose output to the fields that matter here:

```console
$ codesign --display --verbose=4 VirtualBox-7.2.12-174389-macOSArm64.dmg 2>&1 | \
    grep -E '^(Identifier|Format|Authority|Timestamp|Notarization)'
Identifier=VirtualBox-7.2.12-r174389
Format=disk image
Authority=Developer ID Application: Oracle America, Inc. (VB5E2TV963)
Authority=Developer ID Certification Authority
Authority=Apple Root CA
Timestamp=26 Jun 2026 at 18:15:02
Notarization Ticket=stapled
$ spctl --assess --verbose=4 --type open --context context:primary-signature \
    VirtualBox-7.2.12-174389-macOSArm64.dmg
VirtualBox-7.2.12-174389-macOSArm64.dmg: accepted
source=Notarized Developer ID
```

This establishes who signed the DMG and that Gatekeeper accepts its notarization. To see the files, I mounted it read-only and told Finder not to browse it automatically:

```console
$ hdiutil attach -readonly -nobrowse VirtualBox-7.2.12-174389-macOSArm64.dmg
expected CRC32 $39E33C33
/dev/disk8           GUID_partition_scheme
/dev/disk8s1         Apple_APFS
/dev/disk9           EF57347C-0000-11AA-AA11-0030654
/dev/disk9s1         41504653-0000-11AA-AA11-0030654 /Volumes/VirtualBox
$ ls -1 /Volumes/VirtualBox
Applications
UserManual.pdf
VirtualBox.pkg
VirtualBox_Uninstall.tool
$ readlink /Volumes/VirtualBox/Applications
/Applications/
$ cp /Volumes/VirtualBox/VirtualBox.pkg .
$ hdiutil detach /Volumes/VirtualBox
"disk8" ejected.
```

Besides the PKG, the APFS volume contains a manual, an Applications symlink and a standalone shell-script uninstaller. The DMG is the delivery container; `VirtualBox.pkg` is the installer inside it.

```text
VirtualBox-7.2.12-macOSArm64.dmg
|
+-- UDIF + APFS
+-- UserManual.pdf
+-- VirtualBox_Uninstall.tool
`-- VirtualBox.pkg (XAR)
    +-- Distribution + Resources/
    +-- app: metadata, BOM, payload, scripts
    `-- CLI: metadata, BOM, payload
```

Nothing has been installed at this point.

## The PKG inside the image

The package has its own signature, made with a different kind of Developer ID certificate:

```console
$ pkgutil --check-signature VirtualBox.pkg | sed -n '1,7p'
Package "VirtualBox.pkg":
   Status: signed by a developer certificate issued by Apple for distribution
   Notarization: trusted by the Apple notary service
   Signed with a trusted timestamp on: 2026-06-26 16:11:32 +0000
   Certificate Chain:
    1. Developer ID Installer: Oracle America, Inc. (VB5E2TV963)
       Expires: 2027-04-05 15:09:01 +0000
```

Now `file` reports a XAR archive. This time the identifying bytes really are at the front:

```text
00000000  78 61 72 21 00 1c 00 01  00 00 00 00 00 00 14 ce  |xar!............|
00000010  00 00 00 00 00 00 4e ae  00 00 00 01 78 da ec 5c  |......N.....x..\|
00000020
```
{: data-language="HEXDUMP" }

The dump came from `/usr/bin/hexdump -C -n 32 VirtualBox.pkg`. Read as big-endian values, the header describes XAR version 1, a 5,326-byte compressed table of contents, 20,142 bytes after decompression and checksum algorithm 1. Apple's open source XAR header [defines the fields and identifies algorithm 1 as SHA-1](https://github.com/apple-oss-distributions/xar/blob/main/xar/include/xar.h.in#L57-L79).

```console
$ xar --dump-header -f VirtualBox.pkg
magic:                  0x78617221 (OK)
size:                   28
version:                1
Compressed TOC length:  5326
Uncompressed TOC length: 20142
Checksum algorithm:     1 (SHA1)
```

Apple [marks the XAR API as deprecated](https://github.com/apple-oss-distributions/xar/blob/main/xar/include/xar.h.in#L158-L160), but the tool still takes this package apart. Its table of contents is small enough to show in full:

```console
$ xar -tf VirtualBox.pkg
VirtualBox.pkg
VirtualBox.pkg/Bom
VirtualBox.pkg/Payload
VirtualBox.pkg/Scripts
VirtualBox.pkg/PackageInfo
VirtualBoxCLI.pkg
VirtualBoxCLI.pkg/Bom
VirtualBoxCLI.pkg/Payload
VirtualBoxCLI.pkg/PackageInfo
Resources
Resources/en.lproj
Resources/en.lproj/Welcome.rtf
Resources/en.lproj/Localizable.strings
Resources/background.tiff
Distribution
```

This is a flat product package containing two component packages. `pkgutil` expands the XAR into ordinary directories without processing either payload:

```console
$ pkgutil --expand VirtualBox.pkg virtualbox-pkg
$ find virtualbox-pkg -maxdepth 3 -type f | sort
virtualbox-pkg/Distribution
virtualbox-pkg/Resources/background.tiff
virtualbox-pkg/Resources/en.lproj/Localizable.strings
virtualbox-pkg/Resources/en.lproj/Welcome.rtf
virtualbox-pkg/VirtualBox.pkg/Bom
virtualbox-pkg/VirtualBox.pkg/PackageInfo
virtualbox-pkg/VirtualBox.pkg/Payload
virtualbox-pkg/VirtualBox.pkg/Scripts/postflight
virtualbox-pkg/VirtualBox.pkg/Scripts/preflight
virtualbox-pkg/VirtualBoxCLI.pkg/Bom
virtualbox-pkg/VirtualBoxCLI.pkg/PackageInfo
virtualbox-pkg/VirtualBoxCLI.pkg/Payload
```

The top-level `Distribution` file supplies the Installer choices and connects them to the two components. It also restricts this product to ARM64 hosts:

```xml
<options customize="allow" rootVolumeOnly="true" hostArchitectures="arm64"/>
<choice id="choiceVBox">
  <pkg-ref id="org.virtualbox.pkg.virtualbox"/>
</choice>
<choice id="choiceVBoxCLI">
  <pkg-ref id="org.virtualbox.pkg.virtualboxcli"/>
</choice>
<pkg-ref id="org.virtualbox.pkg.virtualbox">#VirtualBox.pkg</pkg-ref>
<pkg-ref id="org.virtualbox.pkg.virtualboxcli">#VirtualBoxCLI.pkg</pkg-ref>
```
{: data-language="XML EXCERPT" }

I formatted the original XML and removed the presentation attributes. The relationship between `choice` and `pkg-ref` follows Apple's [distribution XML schema](https://developer.apple.com/library/archive/documentation/DeveloperTools/Reference/DistributionDefinitionRef/Chapters/Distribution_XML_Ref.html).

## Where the files will land

The component `PackageInfo` files answer two immediate questions: where does each payload go, and does installation require root?

```xml
<pkg-info identifier="org.virtualbox.pkg.virtualbox" version="7.2.12"
  install-location="/Applications/" auth="root">
  <payload numberOfFiles="488" installKBytes="338060"/>
  <bundle path="./VirtualBox.app" id="org.virtualbox.app.VirtualBox"/>
</pkg-info>

<pkg-info identifier="org.virtualbox.pkg.virtualboxcli" version="7.2.12"
  install-location="/usr/local/bin" auth="root">
  <payload numberOfFiles="13" installKBytes="6"/>
</pkg-info>
```
{: data-language="XML EXCERPT" }

Both request root authorization. The large component installs the application; the tiny one installs command-line wrappers. Their BOMs, or Bills of Materials, record the individual paths and file metadata. The CLI BOM begins with another useful magic value:

```text
00000000  42 4f 4d 53 74 6f 72 65  00 00 00 01 00 00 00 31  |BOMStore.......1|
00000010  00 00 36 48 00 00 55 90  00 00 23 22 00 00 00 3c  |..6H..U...#"...<|
00000020
```
{: data-language="HEXDUMP" }

`lsbom` turns the binary inventory into something more convenient:

```console
$ lsbom virtualbox-pkg/VirtualBoxCLI.pkg/Bom | sed -n '1,8p' | column -t
.                  40755   0/0
./VBoxAudioTest    100755  0/0  80   2322252598
./VBoxAutostart    100755  0/0  80   2068167003
./VBoxBalloonCtrl  100755  0/0  82   2983924263
./VBoxBugReport    100755  0/0  80   4051432796
./VBoxHeadless     100755  0/0  115  3914748263
./VBoxManage       100755  0/0  77   325582486
./VBoxVRDP         100755  0/0  115  3914748263
```

After each path come the mode and UID/GID. Regular files also have a size and a 32-bit CRC. The application BOM records group 80 and, notably, a setuid mode for `VBoxNetAdpCtl`:

```console
$ lsbom virtualbox-pkg/VirtualBox.pkg/Bom | \
    grep -E '^\./VirtualBox\.app/Contents/(Info\.plist|MacOS/(VirtualBox|VBoxNetAdpCtl))[[:space:]]' | \
    column -t
./VirtualBox.app/Contents/Info.plist           100644  0/80  4107     771930153
./VirtualBox.app/Contents/MacOS/VBoxNetAdpCtl  104755  0/80  71040    4203402627
./VirtualBox.app/Contents/MacOS/VirtualBox     100755  0/80  2422880  3706879293
```

Joining a BOM path to the component's installation location gives the destination:

```text
PackageInfo: install-location="/Applications/"
                              +
BOM:         ./VirtualBox.app/Contents/MacOS/VirtualBox
                              =
             /Applications/VirtualBox.app/Contents/MacOS/VirtualBox
```

## Peeling open a payload

`pkgutil --payload-files` gives us a quick look at the 488 application entries:

```console
$ pkgutil --payload-files VirtualBox.pkg | sed -n '1,8p'
.
./VirtualBox.app
./VirtualBox.app/Contents
./VirtualBox.app/Contents/_CodeSignature
./VirtualBox.app/Contents/_CodeSignature/CodeResources
./VirtualBox.app/Contents/MacOS
./VirtualBox.app/Contents/MacOS/VBoxXPCOMIPCD.dylib
./VirtualBox.app/Contents/MacOS/VBoxSharedFolders.dylib
```

The component BOMs are better when permissions, ownership and CRCs matter. To inspect actual file contents, we need `Payload`.

The CLI payload is the nicer example because it expands to only 2,560 bytes:

```console
$ file virtualbox-pkg/VirtualBoxCLI.pkg/Payload
virtualbox-pkg/VirtualBoxCLI.pkg/Payload: gzip compressed data, from Unix, original size modulo 2^32 2560
```

```text
00000000  1f 8b 08 00 00 00 00 00  00 03 e5 95 41 6f 82 30  |............Ao.0|
00000010  14 80 3d fb 2b c4 ed aa  6d c1 c2 75 ea 96 6c c9  |..=.+...m..u..l.|
00000020
```
{: data-language="HEXDUMP" }

The `1f 8b` prefix is gzip. After decompression, another archive header appears:

```console
$ gzip -dc virtualbox-pkg/VirtualBoxCLI.pkg/Payload | file -
/dev/stdin: ASCII cpio archive (pre-SVR4 or odc)
```

```text
00000000  30 37 30 37 30 37 30 30  30 30 30 30 30 30 30 30  |0707070000000000|
00000010  30 30 30 34 30 37 35 35  30 30 30 30 30 30 30 30  |0004075500000000|
00000020  30 30 30 30 30 30 30 30  31 36 30 30 30 30 30 30  |0000000016000000|
```
{: data-language="HEXDUMP" }

`070707` identifies old ASCII CPIO. `ditto` understands the gzip-compressed archive directly:

```console
$ mkdir cli-payload
$ ditto -x virtualbox-pkg/VirtualBoxCLI.pkg/Payload cli-payload
$ find cli-payload -mindepth 1 -maxdepth 1 -print | sort | sed -n '1,6p'
cli-payload/VBoxAudioTest
cli-payload/VBoxAutostart
cli-payload/VBoxBalloonCtrl
cli-payload/VBoxBugReport
cli-payload/VBoxHeadless
cli-payload/VBoxManage
$ sed -n '1,2p' cli-payload/VBoxManage
#!/bin/bash
exec /Applications/VirtualBox.app/Contents/MacOS/VBoxManage "$@"
```

So `/usr/local/bin/VBoxManage` is not the main binary. It is a 77-byte dispatcher into the application bundle.

## The scripts are the interesting part

Payload inspection tells us what the package supplies. It does not cover changes made by installer scripts, and this package has two of them. `PackageInfo` assigns their execution roles even though their filenames use the older *flight* terminology:

```xml
<scripts>
  <preinstall file="./preflight" component-id="org.virtualbox.app.VirtualBox"/>
  <postinstall file="./postflight" component-id="org.virtualbox.app.VirtualBox"/>
</scripts>
```
{: data-language="XML EXCERPT" }

There are three kinds of executable text in this download, and they run at different times:

```text
downloaded DMG
|
+-- VirtualBox_Uninstall.tool
|   `-- runs only when explicitly launched
|
`-- VirtualBox.pkg
    +-- preinstall  -> Scripts/preflight
    |   `-- preserve existing Extension Packs
    +-- Payload
    |   `-- copy the application and CLI wrappers
    `-- postinstall -> Scripts/postflight
        +-- install Python bindings when available
        +-- install a per-user LaunchAgent
        +-- register file extensions
        +-- restore Extension Packs
        +-- reset ownership and the VBoxNetAdpCtl setuid bit
        `-- install a provisioning profile when present
```

The standalone uninstaller belongs to the DMG, not the PKG. It runs only if somebody launches it. The CLI wrappers are payload files and run later when a user invokes their commands. `preflight` and `postflight`, on the other hand, are run by Installer around the application payload.

The preinstall script is short. If an older VirtualBox installation contains Extension Packs, it copies them into Installer's temporary directory before the old application is replaced. The postinstall script restores them afterward, then performs the integration work that does not fit neatly into the BOM.

That second script searches for local Python interpreters and may install VirtualBox bindings. It can also copy a `vboxwebsrv` LaunchAgent into the user's library, register file extensions, change the application ownership to `root:admin`, restore the setuid bit on `VBoxNetAdpCtl` and install an embedded provisioning profile.

## Takeaways

A DMG is a disk image containing a filesystem, not another spelling of PKG. In this download it is the outer, signed delivery container, while the inner flat PKG is a XAR containing `Distribution`, two component packages, their BOMs, payloads and installer scripts. The system tools make each layer visible without starting an installation, but payload listings only tell half the story: any useful review also has to account for the code Installer will run around those files.
