---
title: 'Install Bindiff on Fedora'
date: '2021-01-07T17:25:06+00:00'
author: tbarabosch
layout: post
image: /wp-content/uploads/2021/01/fedora.jpg
categories:
    - Tools
tags:
    - Bindiff
    - Diaphora
    - Fedora
    - Google
    - 'IDA Pro'
    - Zynamics
---

**Update 2022-01-03**: I updated this blog post to work with `Fedora 35`, `IDA Pro 7.7`, and `BinDiff 7.1`.

[BinDiff](https://www.zynamics.com/bindiff.html) is a tool to diff to binary executables and finds differences and similarities, respectively. Originally, [Zynamics](https://www.zynamics.com/index.html) developed BinDiff but a couple of years ago it was bought by Google. Even though there are alternatives like [Diaphora](https://github.com/joxeankoret/diaphora), I still prefer `BinDiff`. It is the tool I utilize when analyzing a new version of a malware family. `BinDiff` saves me a lot of time since it detects most of the functionality in the new binary and lets me transfer annotations. Unfortunately, there are only `.deb` packages (Debian / Ubuntu) for Linux. Therefore, Fedora users must rebuild the `.deb` package to a `.rpm` package in order to install `BinDiff` on Fedora

 I know that there is an [article by 0x90](https://www.0x90.se/install-bindiff-in-fedora/) on how to install `BinDiff` on Fedora. However, it does not work out of the box anymore. Furthermore, the article is not reachable (as of time of writing). Therefore, I’ve decided to write a quick tip on how to install `BinDiff` on Fedora. The following was tested with `BinDiff 7.1` and `IDA Pro 7.7` on Fedora 35.

## Building a rpm package

First, we get the latest `.deb` package from [Zynamics’ download page](https://www.zynamics.com/software.html). Next, we need to convert the `.deb` package to a `.rpm` package. We’ll use `alien` for this. Its `man` page gives the following description for it:

> alien is a program that converts between Red Hat rpm, Debian deb, Stampede slp, Slackware tgz, and Solaris pkg file formats. If you want to use a package from another linux distribution than the one you have installed on your system, you can use alien to convert it to your preferred package format and install it. It also supports LSB packages.
> 
> <cite>man page of alien</cite>

The following command converts the `.deb` package to a `.rpm` package:

```bash
alien -v -k --to-rpm bindiff_7_amd64.deb
```


This is the output that I get on my system:

```bash
Warning: alien is not running as root!
Warning: Ownerships of files in the generated packages will probably be wrong.
	dpkg-deb --info 'bindiff_7_amd64.deb' control 2>/dev/null
	dpkg-deb --info 'bindiff_7_amd64.deb' control 2>/dev/null
	dpkg-deb --info 'bindiff_7_amd64.deb' conffiles 2>/dev/null
	dpkg-deb --fsys-tarfile 'bindiff_7_amd64.deb' | tar tf -
	dpkg-deb --info 'bindiff_7_amd64.deb' postinst 2>/dev/null
	dpkg-deb --info 'bindiff_7_amd64.deb' postrm 2>/dev/null
	dpkg-deb --info 'bindiff_7_amd64.deb' preinst 2>/dev/null
	dpkg-deb --info 'bindiff_7_amd64.deb' prerm 2>/dev/null
Warning: Skipping conversion of scripts in package bindiff: postinst postrm preinst
Warning: Use the --scripts parameter to include the scripts.
	mkdir bindiff-7
	chmod 755 bindiff-7
	dpkg-deb -x bindiff_7_amd64.deb bindiff-7
	rpm --showrc
	cd bindiff-7; rpmbuild --buildroot='~/ida_bins/bindiff-7' -bb --target x86_64 'bindiff-7-1.spec' 2>&1
bindiff-7-1.x86_64.rpm generated
```


We’re not yet there. If you try to install it with `dnf` right now, you will get an error.

```bash
dnf install ./bindiff-7-1.x86_64.rpm
Error: 
 Problem: conflicting requests
  - nothing provides libbinaryninjacore.so.1()(64bit) needed by bindiff-7-1.x86_64
(try to add '--skip-broken' to skip uninstallable packages or '--nobest' to use not only best candidate packages)
```

Seems that support for `BinaryNinja` was added, which we as `IDA Pro` users do not need. We have to rebuild the archive with `rpmrebuild`. It’s man page gives the following description:

> rpmrebuild is a tool to build easily rpm package. it can be used to build an rpm file from an installed package (lost rpm) or to quickly make change to a package: just have your change on installed files and call rpmrebuild.
> 
> <cite>man page of rpmrebuild</cite>

Run `rpmrebuild` as follows:

```bash
rpmrebuild -pe bindiff-7-1.x86_64.rpm
```

This command will drop you in your default text editor. Here, you have to locate the following entries and delete them:

```bash
Requires:      libbinaryninjacore.so.1()(64bit)
%dir %attr(0755, root, root) "/opt/bindiff/plugins/binaryninja"
%attr(0644, root, root) "/opt/bindiff/plugins/binaryninja/README"
%attr(0644, root, root) "/opt/bindiff/plugins/binaryninja/binexport12_binaryninja.so"

%dir %attr(0755, root, root) "/"
%dir %attr(0755, root, root) "/usr"
%dir %attr(0755, root, root) "/usr/bin"
%dir %attr(0755, root, root) "/usr/lib"
```


Exit the editor and answer the question `Do you want to continue? (y/N)` with yes. The fixed archive will be in `~/rpmbuild/RPMS/x86_64/bindiff-7-1.x86_64.rpm`.

Now, we can proceed to install `Bindiff 7.1` with `dnf`:

```bash
dnf install ./bindiff-7-1.x86_64.rpm
Dependencies resolved.

Installing:
 bindiff                                                  x86_64                                                  7-1                                                    @commandline                                                   59 M

Transaction Summary
=============================================================================================================================================================================================================================================
Install  1 Package

Total size: 59 M
Installed size: 99 M
Is this ok [y/N]: y
Downloading Packages:
Running transaction check
Transaction check succeeded.
Running transaction test
Transaction test succeeded.
Running transaction
  Preparing        :                                                                                                                                                                                                                     1/1 
  Installing       : bindiff-7-1.x86_64                                                                                                                                                                                                  1/1 
  Running scriptlet: bindiff-7-1.x86_64                                                                                                                                                                                                  1/1 
  Verifying        : bindiff-7-1.x86_64                                                                                                                                                                                                  1/1 

Installed:
  bindiff-7-1.x86_64                                                                                                                                                                                                                         

Complete!

```

## Install the Bindiff plugin in IDA Pro 7.7

Your `Bindiff` installation will be at `/opt/bindiff`. To use `Bindiff` from `IDA Pro 7.7`, you have to copy the precompiled `Bindiff` plugins (`bindiff7_ida.so`, `bindiff7_ida64.so`, `binexport12_ida.so`, and `binexport12_ida64.so`) from `/opt/bindiff/plugins` to your IDA Pro plugin directory `$IDA_DIR/plugins/`.

The next time you start IDA Pro 7.7, it should have loaded the BinExport and BinDiff plugins. Just press `ctrl + 6` to open the BinDiff plugin.

<figure class="wp-block-image size-large">![Screenshot shows how to install BinDiff on Fedora.](https://0xc0decafe.com/wp-content/uploads/2021/01/bindiff_on_fedora.png)<figcaption>Bindiff plugin in IDA Pro 7.7 on Fedora 35</figcaption></figure>Happy diffing 🙂
