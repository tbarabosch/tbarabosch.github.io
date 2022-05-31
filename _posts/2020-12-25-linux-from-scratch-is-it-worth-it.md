---
title: 'Linux from Scratch &#8211; Is it worth it?'
date: '2020-12-25T16:30:11+00:00'
author: tbarabosch
layout: post
feature_image: /wp-content/uploads/2021/01/linux_penguin-1200x766.jpg
categories:
    - 'OS Internals'
tags:
    - LFS
    - linux
---

One thing on my ever-growing ToDo list was to build my own Linux system since I stumbled upon [Linux from Scratch](http://www.linuxfromscratch.org) (LFS) a couple of years ago. LFS is an online book that guides you through the whole process of building your own minimal Linux system. It consists of several phases: initially, you create partitions for your new system and download all the packages you need to build it. Then, you add an initial user LFS and set up a temporary system with a clean toolchain (assembler, compiler, linker) as well as other system tools. Next, you chroot into your temporary system, create essential files and folders, mount virtual filesystems like */dev* and */sys* and start to compile essential packages with your new toolchain. Finally, you install boot scripts, compile the Linux kernel, install Grub, and reboot. And wait, don’t forget to pray before booting into your system!

<!--more-->

The book’s chapters are well-structured. They present you command lines commands to execute in order to, for instance, to build one piece of the puzzle and reasons why this piece is required, e.g. see the chapter on [Bzip2](http://www.linuxfromscratch.org/lfs/view/stable/chapter06/bzip2.html). Even though the LFS book suggests that the system you build is fully usable and could be used as the primary system, it is more an educational project. For instance, do not expect to end up with a comfortable package manager like *apt-get*. Hence, many LFSers are likely to build their system in a virtual machine. One clear advantage is that you can create snapshots during the build process, which is assumed to take place in one pass without turning off your machine. Otherwise, you have to set up your chroot again.

Based on a such minimal system, further guides can be followed to get something more usable. These guides include [Beyond Linux From Scratch](http://www.linuxfromscratch.org/blfs/), which also introduces security measures to the system, and [Cross Linux From Scratch](http://www.linuxfromscratch.org/alfs/), which teaches how to cross-compile and how to build multilib environments.

I followed [Linux from Scratch 8.0](http://www.linuxfromscratch.org/lfs/view/stable/), which is the latest stable version. You will build a Linux system based on the Linux Kernel in version 4.9.9. There are three major points, making LFS a great project for a couple of evenings, which I discuss in the following. Finally, I wrap up my lines of thoughts in a quick conclusion.

What is really needed to end up with a bash shell? Which package depends on which one? What are all these libraries in my *libs* directories good for? There are many questions you could pose here. LFS makes you realize what it takes to build a minimal Linux system. For instance, it made me realize what forms *binutils*, *coreutils* and *util-linux*. Tools that I use on a daily basis, I took them for granted but never knew where they came from.

## Learning by Doing

LFS is Learning by doing, no beating around the bush here. You build a Linux system from scratch with your bare hands! After theory comes implementation. The stuff you learn here should be applicable to a wide range of Linux-related problems. Be it building your own cross-compiling toolchain as you actually do in LFS, be it building your custom Linux system for an embedded platform.

Furthermore, for those that would like to get into OS development, Linux from Scratch allows them to review certain key concepts like the toolchain of linker, compiler, assembler, which are [critical to OS development](http://wiki.osdev.org/Required_Knowledge). Before diving into OS development, I would certainly recommend going through LFS to see how to glue components together to an OS.

However, you won’t code anything. For instance, the LFS guys provide you with a set of init scripts so that you don’t need to write custom ones. They serve as a fully-working template: study them and extend them, if needed.  
But IMHO it would be too much to extend these scripts in a first LFS iteration. A rough understanding of the boot process is sufficient.

## Take your time – It is well spent and worth it!

Take your time! I repeat slowly: take your time! I guess many just rush through the chapters, blindly executing commands, and end up with a working Linux system, without ever having understood what has happened. If you do this, it just boils to many *./configure &amp;&amp; make &amp;&amp; make install* calls. And actually there are tools to [automate the whole LFS process](http://www.linuxfromscratch.org/alfs/).

Linux from Scratch should be rather seen as a marathon than as a quick sprint. There will be so many questions popping up in your mind. Try to follow them, search for answers on Google or Wikipedia while your computer is heating your room. Most of the time, I started by reading the project’s Wikipedia page and in case there were still open questions I consulted the project’s website. This made me read up on the project’s history, the people, and the organizations behind and it enabled me to see connections between various projects. Then, I started to poke around in the project’s folder structure and opened some source files. After compilation and installation, I checked the files produced and the locations where they were put.

Doing this, for example, made me realize what kind of a monster [gcc](1https://en.wikipedia.org/wiki/GNU_Compiler_Collection) really is. … It made me think about the pros and cons of gcc and why llvm is a brilliant compiler. So I continued to read up more on the [pros and cons](https://clang.llvm.org/comparison.html) of clang/llvm and gcc. I knew that llvm is the default compiler on macOS, where I already enjoy it. However, the fact that [FreeBSD](https://www.freebsd.org/) and [Sony’s PS4 system software](http://llvm.org/devmtg/2013-11/slides/Robinson-PS4Toolchain.pdf) also use clang/llvm was new to me. Actually, there is a [project](https://github.com/ramosian-glider/clang-kernel-build) that provides patches for the Linux kernel in order to make it compilable with clang. As you can see, you can start with one thing and end up on the PS4. Nevertheless, it is very educational and many new ideas will come to your mind.

## Final thoughts on Linux from Scratch

First, of it all, it is a nice feeling to boot into your own Linux system, built with your bare hands. You end up with run level 3, a simple bash shell, nothing fancy at all. You see the cursor blinking and think: “Puh, I did not mess anything up”, since there are so many pitfalls. Then, you relax and toy around with your system. Totally worth it!

Of course, I did register my Linux from Scratch system at the [lfscounter](http://www.linuxfromscratch.org/cgi-bin/lfscounter.php):

```
You have successfully registered!
ID: 26656
Name: Thomas Barabosch
First LFS Version: 8.0
```

Even though 26656 seems to be a huge number, it isn’t if you take into account that LFS will turn 20 next year. On the other side, not everybody registers his system.

There is so much future work still left. As mentioned earlier, no package manager is installed. Actually, the current strategy is [It is All in My Head!](http://www.linuxfromscratch.org/lfs/view/stable/chapter06/pkgmgt.html), which only works for a very exclusive group of Linux users:

> Yes, this is a package management technique. Some folks do not find the need for a package manager because they know the packages intimately and know what files are installed by each package. Some users also do not need any package management because they plan on rebuilding the entire system when a package is changed.

In the end, I invested several evenings to build the whole system, even though my initial SBU was less than five minutes. In retrospect, time was invested well. Can I now compile my custom Linux distribution and ditch my Ubuntu installation? Probably not, but it is a start and some may dive deeper into this topic because of Linux from Scratch. For me, the next thing to do is [Beyond Linux From Scratch](http://www.linuxfromscratch.org/blfs/) and to have a look at how exactly [security features](http://www.linuxfromscratch.org/blfs/view/stable-systemd/postlfs/security.html) like PAM are incorporated in a Linux system.
