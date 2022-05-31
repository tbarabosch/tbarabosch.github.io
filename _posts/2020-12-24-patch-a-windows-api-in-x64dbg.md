---
id: 39
title: 'How to patch a Windows API in x64dbg'
date: '2020-12-24T12:00:00+00:00'
author: tbarabosch
layout: post
guid: 'https://0xc0decafe.com/?p=39'
permalink: /patch-a-windows-api-in-x64dbg/
rank_math_internal_links_processed:
    - '1'
rank_math_primary_category:
    - '20'
rank_math_seo_score:
    - '67'
rank_math_focus_keyword:
    - 'patch a windows api in x64dbg'
rank_math_description:
    - 'This article explains how to patch a Windows API in the x64dbg debugger via x64dbgpy and shortcuts.'
site-sidebar-layout:
    - default
site-content-layout:
    - default
theme-transparent-header-meta:
    - default
image: /wp-content/uploads/2020/12/surveillance_cams-scaled-e1608651625550-1200x785.jpg
categories:
    - 'Malware Analysis'
tags:
    - 'malware analysis'
    - Python
    - win32
    - x64dbg
---

Some months ago, I analyzed a banking Trojan that employed a chain of injections. First, it hollowed an instance of *svchost.exe*. From there, it injected its code into several processes (especially browsers). My goal was to analyze the network protocol. Unfortunately, all processes could communicate with the CC and there was a mutual exclusion scheme that ensured only one network communicator at a time. This resulted in my process never contacting the CC and in me not seeing the network protocol.

My quick hack was to prevent others instances to communicate via the network by preventing further code injections. The malware at hand utilized *ZwOpenProcess* during its code injections. The solution: patch a Windows API in *x64dbg* to always return zero yielded no more injections. And finally, I was able to tamper with the network protocol.

Most of the time I utilize [x64dbg](http://x64dbg.com/), an open source debugger. Since a couple of months [python bindings exist](https://github.com/x64dbg/x64dbgpy). They work fine, though there is no documentation. The following gist does the trick: patching ZwOpenProcess to always return zero. This should yield no more code injections in many malware families. Furthmore, you can use it as a blue print for patching other APIs in *x64dbg*.

```
<pre class="wp-block-code">```python
<strong>from x64dbgpy.pluginsdk import *       
                         
def patchZwOpenProcess():       
    # This function patches the function ZwOpenProcess in such way that the XXX fails to open and infect more processes       
    # The good thing about that is that there won't be any concurrency issues and you can be sure that the networking       
    # will be done in the current process.       
                
    # patches mov eax, 0; jmp TO_RETURN (should be +3)       
    PATCH = "\xB8" + "\x00" * 4 + "\xEB\x03" + "\x90" * 3       
    addrZwOpenProcess = RemoteGetProcAddress('ntdll', 'ZwOpenProcess')       
    memory.Write(addrZwOpenProcess, PATCH)       
                
def main():       
    patchZwOpenProcess()       
                
main()</strong>
```
```

The gist just assembles some shellcode (*mov eax, 0; jmp TO\_RETURN*) to force the API to return zero, resolves the target API with *RemoteGetProcAddress* and overwrites the original code of the api with *memory.Write*. As I said, there is no documentation of *x64dbgpy*. You can refer to [this folder of x64dbgpy’s repo](https://github.com/x64dbg/x64dbgpy/tree/v25/swig/x64dbgpy/pluginsdk/_scriptapi).

Another quick way to do this is without Python was decribed in this Tweet:

<figure class="wp-block-embed is-type-rich is-provider-twitter wp-block-embed-twitter"><div class="wp-block-embed__wrapper">> Alternative x64dbg command (you can also bind it to a hotkey or execute on debug init): mov ntdll:NtOpenProcess, #31C0C21000#
> 
> — x64dbg (@x64dbg) [January 10, 2017](https://twitter.com/x64dbg/status/818902513244143617?ref_src=twsrc%5Etfw)

<script async="" charset="utf-8" src="https://platform.twitter.com/widgets.js"></script></div></figure>