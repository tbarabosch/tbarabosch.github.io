---
title: 'bap-mode: Emacs ❤️ BAP'
date: '2020-12-22T13:01:12+00:00'
author: tbarabosch
layout: post
feature_image: /wp-content/uploads/2020/12/black_keyboard-1200x675.jpg
---

The *[Binary Analysis Platform](https://github.com/BinaryAnalysisPlatform/bap)* (BAP) is a framework for automated binary code analysis. I utilize BAP quite a lot to implement cross-architecture analyses in the realm of firmware (e.g. ARM, PPC, Mips, …). Owed to the fact that BAP lifts assembly code to an intermediate representation (IR), you can (almost) write architecture-agnostic binary analyses. Before I implement an analysis I inspect the IR that is emitted by BAP for a certain piece of code. You can instrument BAP to lift a program to its IR by calling `bap PATH_TO_PROGRAM -d`.

<!--more-->

For example, the following is the IR emitted for a simple function that calls malloc, checks the return value and frees the malloc’d area again. As you can see, IRs are a double sided sword. On the one hand, they are simpler than the assemblies you may encounter since they usually comprise less instuction types. Furthermore, they are usually side effect free, when compared, e.g., to x86 assembly (think about the side effects of the `add` instruction). On the other hand, they bloat the code because assembly instructions are split into several IR instructions and the side effects are now obvious.

```
 00000139: sub if_statement()
 0000010b: 
 0000010c: v943 := SP
 0000010d: mem := mem with [v943 + 0xFFFFFFFC, el]:u32 <- LR
 0000010e: mem := mem with [v943 + 0xFFFFFFF8, el]:u32 <- R11
 0000010f: SP := SP - 8
 00000112: R11 := SP + 4
 00000115: SP := SP - 8
 00000116: R0 := 0x59
 00000117: LR := 0x10440
 00000118: call @malloc with return %00000119
 00000119: 
 0000011a: R3 := R0
 0000011b: mem := mem with [R11 + 0xFFFFFFF8, el]:u32 <- R3
 0000011c: R3 := 2
 0000011d: mem := mem with [R11 + 0xFFFFFFF4, el]:u32 <- R3
 0000011e: R3 := mem[R11 + 0xFFFFFFF4, el]:u32
 0000011f: v899 := R3
 00000121: v897 := R3 - 3
 00000123: VF := high:1[(v899 ^ 3) & (v899 ^ v897)]
 00000124: NF := high:1[v897]
 00000125: ZF := v897 = 0
 00000126: when ~ZF & NF = VF goto %0000012c
 00000127: goto %00000128
 00000128: 
 00000129: R3 := 0x21
 0000012a: mem := mem with [R11 + 0xFFFFFFF4, el]:u32 <- R3
 0000012b: goto %0000012c
 0000012c: 
 0000012d: R0 := mem[R11 + 0xFFFFFFF8, el]:u32
 0000012e: LR := 0x1046C
 0000012f: call @free with return %00000130
 00000130: 
 00000131: R0 := R0
 00000134: SP := R11 - 4
 00000135: v839 := SP
 00000136: R11 := mem[v839, el]:u32
 00000137: SP := SP + 8
 00000138: goto mem[v839 + 4, el]:u32
```

When I analyzed BAP’s IR in the terminal, this always led to anti-patterns like `bap PATH_TO_PROGRAM -d | less`. My eyes got quickly overwhelmed since there was so much data and no syntax highlighting. I greped around in the code but it did not feel right. Since I am an Emacs user, I wrote a major mode called *bap-mode* that allows to inspect BAP’s IR in Emacs. The following screenshot shows how it looks like.

![bap-mode in Emacs](https://0xc0decafe.com/wp-content/uploads/2020/12/bap_mode.jpg) 

That looks way better than in the terminal 🙂 I added several functions to improve the workflow. First, there are several functions like *bap-goto-function-definition* (`C-c C-b d`) or *bap-got-main* (`C-c C-b m`) that help the analyst to navigate the IR effectively. Second, there are two functions to invoke BAP from within Emacs: *bap-open-file* (`C-c C-b o`), which emits just the IR, and *bap-open-file-with-extra-pass* (`C-c C-b p`), which runs an extra pass on the file and then emits the IR. You can try *bap-mode* by installing it via MELPA (`M-x package-install <RET> bap-mode <RET>`).
