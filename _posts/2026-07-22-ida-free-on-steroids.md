---
title: 'IDA Free on Steroids: Automating Reverse Engineering with IDC and Codex'
date: '2026-07-22T14:00:00+02:00'
author: tbarabosch
layout: post
tags:
  - AI tooling
  - reverse engineering
  - IDA
---

IDA Free can disassemble a binary, debug it, save the database and even decompile x86 code through Hex-Rays' cloud. For a personal project that is already a serious toolbox. The painful omission appears when I want to automate a repetitive job: Free has no IDAPython API or C++ SDK. Its one built-in scripting route is IDC.

<!--more-->

That sounds like a dead end only until the task becomes concrete. IDC is awkward, but it can still walk functions and cross-references, inspect names and flags, rename database objects, write comments and produce reports. In this post I use it to turn a stripped ELF's anonymous functions into an explainable first-pass map. Then I package the knowledge required to write such scripts as a Codex skill, so I do not have to relearn IDC for every small reversing job.

## What IDA Free gives me

First, host and target architecture are different things. The host is the machine on which IDA runs; the target is the processor used by the binary under analysis. My validation host was ARM64 Linux, while the sample was an x86-64 Linux ELF. That works because the current Free edition provides the x86-32 and x86-64 disassemblers on supported x64 and ARM64 hosts.

The current [IDA Free page](https://hex-rays.com/ida-free) and [pricing matrix](https://hex-rays.com/pricing) describe the boundary clearly:

| Capability | IDA Free |
| --- | --- |
| License | Named, non-commercial use |
| Input formats | PE, ELF and Mach-O for supported targets |
| Disassembly | x86-32 and x86-64 |
| Decompilation | x86-32 and x86-64, cloud only |
| Debugging | Local x86/x64 |
| Databases | Analysis can be saved |
| Lumina | Public service only |
| Development | No IDAPython, C++ SDK or IDAlib |

The non-commercial restriction matters. This workflow is aimed at my own research and hobby projects.

Cloud decompilation is also a separate trust decision from local disassembly. Hex-Rays says that the cloud decompiler needs an online connection while disassembly works offline, and that information about the function being decompiled is sent to its service. Its [cloud-services FAQ](https://hex-rays.com/faqs/which-information-does-ida-share-with-cloud-services) says the data is not persisted after decompilation, but I still would not press F5 on confidential code without permission. IDC automation of the local database does not need the cloud decompiler at all.

## IDC: the language nobody likes, but the one Free gives me

IDC is IDA's embedded C-like language. It has been around for a long time, has no external runtime dependency and is available inside the application. Hex-Rays' [IDC overview](https://docs.hex-rays.com/developer-guide/idc/idc-api-reference/index-of-debugger-related-idc-functions) documents the API, its [example collection](https://docs.hex-rays.com/8.4/developer-guide/idc/idc-examples) shows the basic patterns, and [Igor's Tip #124](https://hex-rays.com/blog/igors-tip-of-the-week-124-scripting-examples) explicitly identifies IDC as the scripting language available in IDA Free.

A minimal script looks like this:

```c
#include <idc.idc>

static main()
{
  auto ea;

  auto_wait();
  ea = get_screen_ea();
  if ( ea == BADADDR )
  {
    warning("No current address");
    return 1;
  }

  msg("Current address: %a\n", ea);
  return 0;
}
```
{: data-language="IDC" }

Run it through **File > Script file** and it reads `msg()` output in IDA's Output pane. `auto_wait()` prevents the script from racing the initial analysis, and `BADADDR` is the check whenever an address lookup can fail.

The language feels old-fashioned. Variables are declared with `auto` and are dynamically typed. Some familiar C operators are missing; `value = value + 1` is safer than assuming `+=` exists. References are written at the call site, such as `update(&value)`, despite IDC not having C pointers. Examples are much scarcer than IDAPython examples, and search results regularly mix native IDC functions with Python's similarly named `idc` compatibility module. Copying `idautils.Functions()` or an `ida_funcs` call into an `.idc` file will not make it work.

## Case study: prefix functions by observed behavior

I wanted a sample that was harmless, small and reproducible, but not so artificial that imports disappeared. The program below (generated with Codex) makes direct calls in five categories and includes one function that deliberately mixes networking and file behavior.

```c
#include <arpa/inet.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define NOINLINE __attribute__((noinline))

static NOINLINE int network_task(void)
{
    struct sockaddr_in address = {0};
    int descriptor;
    int result;

    address.sin_family = AF_INET;
    address.sin_port = htons(9);
    inet_pton(AF_INET, "127.0.0.1", &address.sin_addr);
    descriptor = socket(AF_INET, SOCK_STREAM, 0);
    if (descriptor < 0)
        return -1;
    result = connect(descriptor, (struct sockaddr *)&address, sizeof(address));
    close(descriptor);
    return result;
}

static NOINLINE int file_task(void)
{
    char byte;
    int descriptor;
    int result;

    descriptor = open("/dev/null", O_RDONLY);
    if (descriptor < 0)
        return -1;
    result = (int)read(descriptor, &byte, sizeof(byte));
    close(descriptor);
    return result;
}

static NOINLINE int memory_task(void)
{
    void *allocation;
    void *mapping;

    allocation = malloc(64);
    if (allocation == NULL)
        return -1;
    memset(allocation, 0x41, 64);
    free(allocation);
    mapping = mmap(NULL, 4096, PROT_READ | PROT_WRITE,
                   MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mapping == MAP_FAILED)
        return -1;
    munmap(mapping, 4096);
    return 0;
}

static NOINLINE int process_task(void)
{
    pid_t child;
    int status;

    child = fork();
    if (child == 0)
        _exit(0);
    if (child < 0)
        return -1;
    return waitpid(child, &status, 0) < 0 ? -1 : status;
}

static NOINLINE void *thread_start(void *argument)
{
    return argument;
}

static NOINLINE int thread_task(void)
{
    pthread_t thread;

    if (pthread_create(&thread, NULL, thread_start, NULL) != 0)
        return -1;
    return pthread_join(thread, NULL);
}

static NOINLINE int mixed_network_file_task(void)
{
    int descriptor;
    int file;

    descriptor = socket(AF_INET, SOCK_DGRAM, 0);
    file = open("/dev/null", O_WRONLY);
    if (descriptor >= 0)
        close(descriptor);
    if (file >= 0)
        close(file);
    return descriptor < 0 || file < 0 ? -1 : 0;
}

int main(void)
{
    volatile int result;

    result = network_task();
    result = result + file_task();
    result = result + memory_task();
    result = result + process_task();
    result = result + thread_task();
    result = result + mixed_network_file_task();
    return result == INT32_MIN;
}
```

I built and stripped it in an isolated Linux environment. `-O0`, `-fno-inline` and `-fno-builtin` keep the internal functions and their calls visible; dynamic linking retains the imports.

```bash
x86_64-linux-gnu-gcc \
  -O0 -fno-inline -fno-builtin -fno-omit-frame-pointer \
  -fno-pie -no-pie -pthread \
  triage_fixture.c -o triage_fixture
x86_64-linux-gnu-strip --strip-all triage_fixture
```

The stripped binary begins with the expected anonymous `sub_...` functions:

![IDA Free 9.4 before IDC categorization, showing the six anonymous fixture functions](/assets/images/posts/ida-free-on-steroids/ida-before.png)

This is the prompt I gave Codex after installing the skill described below:

```text
Use $write-idc-scripts for IDA Free 9.4. Create a native IDC script for
a stripped Linux x86-64 ELF. Wait for analysis, inspect direct outgoing
calls from ordinary user functions, and classify known APIs as net, file,
proc, mem, or thread. Prefix only IDA-generated function names, preserve
analyst names, append exact API evidence to a repeatable function comment,
support dry-run, combine tags deterministically, and make reruns idempotent.
```

The generated script normalizes names such as `_socket`, `j_socket` and versioned ELF symbols before consulting a bounded API map. Its central loop uses only native IDC calls:

```c
for ( ea = func_ea;
      ea != BADADDR && ea < end_ea;
      ea = next_head(ea, end_ea) )
{
  for ( target = get_first_fcref_from(ea);
        target != BADADDR;
        target = get_next_fcref_from(ea, target) )
  {
    type = get_xref_type() & ~XREF_USER;
    if ( type != fl_CF && type != fl_CN )
      continue;

    api = normalize_api_name(get_func_name(target));
    category = api_category(api);
    if ( category != "" )
    {
      add_unique(&category_tokens, &category_display, category);
      add_unique(&evidence_tokens, &evidence, api);
    }
  }
}

if ( !has_user_name(get_full_flags(func_ea)) )
  set_name(func_ea, prefix + "__" + current_name,
           SN_CHECK | SN_NOWARN);
```
{: data-language="IDC" }

The [complete script and fixture](https://github.com/tbarabosch/ida_free_idc_scripts/tree/main/function-categorizer) also skip `FUNC_LIB` and `FUNC_THUNK`, check every function boundary and rename result, and add a marked repeatable comment. Since IDC 9.4's `set_func_cmt()` returns no status, the script reads the comment back and verifies the marker. That marker also prevents duplicates. Category order is fixed as `net`, `file`, `proc`, `mem`, `thread`, so a mixed result is always `net_file__sub_...`, never whichever order a cross-reference happened to appear in.

I left `DRY_RUN` set to `1` for the first pass. IDA Free visited 71 functions, found six matches and renamed zero:

![IDA Free 9.4 Output pane showing the IDC dry run and zero database changes](/assets/images/posts/ida-free-on-steroids/ida-dry-run.png)

After reviewing the proposals, I changed the constant to `0` in a temporary copy and ran it again. The result is much easier to scan:

![IDA Free 9.4 after IDC categorization, showing net, file, mem, proc, thread and net-file prefixes](/assets/images/posts/ida-free-on-steroids/ida-after.png)

The comments retain the reason for every decision. For example, the network function records `inet_pton, socket, connect`; the memory function records `malloc, memset, free, mmap, munmap`; and the mixed function records `socket, open`. Apply mode reported six matches and six renames. A second apply run reported six matches and zero renames. I also manually renamed the network function to `analyst_socket_setup`; the next run kept that name. Imports, thunks, the unmatched thread entry point and `main` remained unchanged. These checks were performed in IDA Free 9.4.0.260714.

This is triage evidence, not semantic truth. Direct call references are easy to explain, which is why I like them for a first pass, but the script will miss wrappers, register-indirect calls, inlined code and statically linked implementations. An imported API can also be present in dead or error-handling code. The prefixes tell me where to look; they do not tell me what a function ultimately does.

## Turning the workaround into a Codex skill

The hard part of a one-off IDC script is rarely the idea. It is remembering which names are native IDC, which failure value an API returns, how function iteration behaves, and which tempting Python example does not apply. I encoded those constraints in [`$write-idc-scripts`](https://github.com/tbarabosch/codex-skills/tree/main/write-idc-scripts).

Codex [skills](https://learn.chatgpt.com/docs/build-skills.md) are directories containing reusable instructions in `SKILL.md`, with optional references, scripts and assets. Codex can select a skill from its name and description, then loads the full instructions when the skill is used. That progressive disclosure is useful here: the IDC API notes stay out of unrelated conversations but are available when I ask for an IDC script.

From a clone of my skills repository, installation is just a directory copy:

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
cp -R ./write-idc-scripts "${CODEX_HOME:-$HOME/.codex}/skills/"
```

I can then invoke it explicitly:

```text
Use $write-idc-scripts to prefix functions by the imported APIs they call.
```

The skill first pins down the IDA version, target and intended database changes. It reads a compact, verified IDC reference, starts from a guarded template, selects native functions for the job, and defaults bulk mutations to dry-run. Before returning, it checks for Python modules, unsupported SDK calls, missing `BADADDR` handling, unsafe name or comment replacement and non-idempotent output.

Its output contract is deliberately practical: one self-contained `.idc` file, stated assumptions, exact IDB or file effects, **File > Script file** instructions, and known blind spots. If IDC cannot perform the request, the skill must say so. It does not invent an IDAPython shim or pretend that the missing SDK can be recovered from inside IDA Free.

## A useful middle ground

This setup does not turn IDA Free into IDA Pro. It does make IDA Free more comfortable for personal x86 and x64 projects. I keep the interactive disassembler, debugger, saved database and optional cloud decompiler, while small generated IDC programs handle the repetitive local bookkeeping.

IDC remains IDC. The win is that I no longer pay its rediscovery cost every time I want to rename twenty functions, annotate a family of calls or export a small slice of the database. I describe the reversing task, review a guarded script, run the dry pass and keep the evidence in the IDB.
