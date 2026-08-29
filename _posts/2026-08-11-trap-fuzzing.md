---
title: 'Trap fuzzing: random instructions, real bugs'
date: '2026-08-11T12:00:00+02:00'
last_modified_at: '2026-08-11T12:00:00+02:00'
author: tbarabosch
layout: post
image:
  path: /assets/images/posts/trap-fuzzing/social-card.png
  width: 1200
  height: 630
social_card:
  layout: text
  subtitle: 'Random instructions drive a rarely tested boundary in privileged code.'
  eyebrow: 'Systems Security / Fuzzing'
  panel_label: 'Input boundary'
  text: 'Generate bytes, execute them in disposable processes, and keep the crashing input.'
tags:
  - systems security
  - fuzzing
  - virtualization
---

Most fuzzers feed strange data to a program. Trap fuzzing feeds strange instructions to a processor.

The processor decodes those instructions, executes what it can and raises exceptions for what it cannot. The operating system or hypervisor then has to translate the result into something harmless: perhaps a signal, a terminated process or a clean return to the guest. This makes the instruction stream an input to privileged code that is rarely called directly but is exposed to every unprivileged process.

About a decade ago, I built a small fuzzer for this boundary. It sent random machine code into disposable processes and watched what happened above them. The implementation was small. The failure surface was not. This experiment eventually found two denial-of-service vulnerabilities, one in OpenBSD and one in VirtualBox.

<!--more-->

## The CPU is part of the input path

A processor does not know that a byte sequence came from a fuzzer. It decodes the bytes according to the current architecture, execution mode and processor state. Some sequences are ordinary instructions. Many are invalid, privileged or incomplete. Others become interesting only when combined with a particular register value, prefix or virtualization setting.

I use *trap* here as an umbrella term. Processor manuals and operating systems distinguish exceptions, faults, traps, aborts and virtualization exits more carefully. The names matter when analysing a specific failure. The general fuzzing path remains simple:

```text
generated native bytes
          |
          v
        [ CPU ]
          |
     trap / VM exit
          |
          v
 privileged handler
      |         |
      v         v
  expected     bug
 signal/exit   panic/reset/crash
```

Almost every result is boring. An illegal instruction kills the process, a bad memory reference produces a segmentation fault, or a loop reaches the timeout. That is expected behavior. The interesting case appears when an unprivileged instruction makes the kernel panic, resets the virtual machine or breaks the software emulating the operation.

This is black-box fuzzing in a rather literal form. It needs no model of the target's trap handlers and no source-level coverage. That simplicity is useful, but it is not efficient: random bytes spend most of their time rediscovering failure paths that already work.

## Sixty-four bytes at a time

My [Trap Fuzzer prototype](https://github.com/tbarabosch/pocs/tree/master/trap_fuzzer) has two sides. A Python server generates 64 random bytes, records the iteration number and bytes in a log, and sends the input over TCP. The target receives the bytes into writable memory, changes the mapping to executable and starts a child process that jumps directly into them.

The parent waits for the child or a one-second timeout. Ordinary exceptions only end the child. A stuck child is killed before the next iteration. The larger failure signals are external: a kernel panic on the console, a VM reset, a dead hypervisor or a network connection that suddenly disappears.

```text
generator host                       disposable target
+--------------------+   TCP    +-------------------------+
| generate 64 bytes  |--------->| map -> fork -> execute |
| log input + number |          +------------+------------+
+---------+----------+                       |
          |                                  v
          |                         kernel / hypervisor
          |                                  |
          +------ recover input <--- panic / hang / reset
                         |
                         v
                      replay
```

Keeping the generator and log outside the target was the most useful architectural choice. When the guest died, it did not take the only copy of the last input with it. After restoring the machine, I could extract the bytes belonging to the printed iteration, replay them and turn a reproducible case into a standalone program.

The code should be read as a historical prototype, not a modern fuzzing framework. It has no coverage feedback, mutation strategy, crash deduplication or automatic minimization. It also deliberately tries to crash privileged software.

## Two crashes became two CVEs

The first result became [CVE-2018-14775](https://github.com/tbarabosch/pocs/tree/master/OpenBSD/CVE-2018-14775). An unprivileged user on affected OpenBSD releases could trigger a kernel triple fault and take down the system. OpenBSD published the correction as the [i386 I/O-port permission fix in the 6.3 errata](https://www.openbsd.org/errata63.html).

The second became [CVE-2018-3005](https://github.com/tbarabosch/pocs/tree/master/VirtualBox/CVE-2018-3005), a denial of service in VirtualBox while running BSD-based guests. Oracle credited the finding in its [July 2018 Critical Patch Update](https://www.oracle.com/security-alerts/cpujul2018.html).

Both findings affected availability. They were not memory-corruption bugs, guest escapes or proof that every trap handler was broken. They demonstrated the narrower point that small unprivileged instruction sequences could reach failure modes below the process that executed them.

## The boundary keeps moving

Trap fuzzing remains interesting because processors and the software around them keep changing. ARM64 and RISC-V expose different exception models from x86. New instruction extensions add encodings, state and privilege transitions. Less frequently tested operating systems may implement the same architectural rules through very different handler code.

Virtualization adds more interpreters of the same event. An instruction may run directly, trap into a guest kernel, cause a VM exit, reach an emulator or cross another boundary in a nested setup. Compatibility layers and firmware add still more code that has to agree with the processor about what happened and what should happen next.

Physical devices make the experiment harder rather than less relevant. Phones, embedded systems and appliances may require serial consoles, watchdogs or external power control before a fuzzer can distinguish a reboot from a hang and recover automatically. Source code and coverage may also be unavailable. A black-box signal such as an unexpected reset can still identify an input worth investigating.

Pure random generation would not be my first choice today. A modern version could generate architecture-aware instruction sequences, preserve interesting processor state, use coverage where available, classify failures and restore virtual machines or devices automatically. It could also combine instruction fuzzing with syscall fuzzing instead of treating them as competing methods. One explores an explicit software interface; the other asks what happens when the CPU itself delivers the input.

The prototype is old. The boundary it tested is not.
