---
id: 657
title: 'Learn how to fix PE magic numbers with Malduck'
date: '2021-01-28T07:00:00+00:00'
author: tbarabosch
layout: post
guid: 'https://0xc0decafe.com/?p=657'
permalink: /fix-pe-magic-numbers-with-malduck/
rank_math_seo_score:
    - '90'
rank_math_internal_links_processed:
    - '1'
site-sidebar-layout:
    - default
site-content-layout:
    - default
theme-transparent-header-meta:
    - default
rank_math_primary_category:
    - '20'
rank_math_focus_keyword:
    - 'fix PE magic numbers'
rank_math_description:
    - 'Malware often corrupts the PE header to thwart analysis. This post gives you an introduction to Malduck and shows how to fix PE magic numbers (MZ + PE) with it.'
image: /wp-content/uploads/2021/01/teaser_overwritten_magic_pe.jpg
categories:
    - 'Malware Analysis'
tags:
    - lief
    - malduck
    - 'memory dump'
    - PE
    - Python
---

Malware often corrupts the Portable Executable (PE) header to hinder its analysis. By overwriting parts of the PE header, malware evades simple memory dumpers and thwarts proper loading by analysis tools. If we’re lucky then malware only overwrites the magic numbers of the PE header (`MZ` and `PE`) and leaves the rest of the header intact. We can fix such corrupted PE headers with ease. All we need is a little bit of knowledge about the PE format and the right tool to manipulate memory dumps.

First, we’ll learn how to identify such corrupted PE headers quickly with a hexeditor. Next, we’ll see how to manipulate memory dumps with [Malduck](https://malduck.readthedocs.io/en/latest/). This section gives you a head start on how to use this great Python module effectively. Finally, we are putting it all together and write a script to fix PE magic numbers of a corrupted PE header.

<div class="ez-toc-v2_0_23 counter-hierarchy counter-decimal ez-toc-white" id="ez-toc-container"><div class="ez-toc-title-container">Table of Contents

<span class="ez-toc-title-toggle"><a class="ez-toc-pull-right ez-toc-btn ez-toc-btn-xs ez-toc-btn-default ez-toc-toggle" style="display: none;"></a></span></div><nav>- [Identifying overwritten magic numbers](https://0xc0decafe.com/fix-pe-magic-numbers-with-malduck/#Identifying_overwritten_magic_numbers "Identifying overwritten magic numbers")
- [Manipulating memory dumps with Malduck](https://0xc0decafe.com/fix-pe-magic-numbers-with-malduck/#Manipulating_memory_dumps_with_Malduck "Manipulating memory dumps with Malduck")
    - [Open a memory dump with Malduck](https://0xc0decafe.com/fix-pe-magic-numbers-with-malduck/#Open_a_memory_dump_with_Malduck "Open a memory dump with Malduck")
    - [Read ProcessMemoryPE](https://0xc0decafe.com/fix-pe-magic-numbers-with-malduck/#Read_ProcessMemoryPE "Read ProcessMemoryPE")
    - [Write ProcessMemoryPE](https://0xc0decafe.com/fix-pe-magic-numbers-with-malduck/#Write_ProcessMemoryPE "Write ProcessMemoryPE")
- [Putting it all together: fix PE magic numbers with Malduck](https://0xc0decafe.com/fix-pe-magic-numbers-with-malduck/#Putting_it_all_together_fix_PE_magic_numbers_with_Malduck "Putting it all together: fix PE magic numbers with Malduck")

</nav></div>## <span class="ez-toc-section" id="Identifying_overwritten_magic_numbers"></span>Identifying overwritten magic numbers<span class="ez-toc-section-end"></span>

In the following, I assume that you’ve got a basic understanding of the PE format. If not, I can recommend the article on [osdev.org](https://wiki.osdev.org/PE) (check the overview graphic of the PE format) as an introduction.

 There are two magic numbers in the PE header that are frequently overwritten by malware. First, the magic number of the DOS header (`_IMAGE_DOS_HEADER`), which is a two-byte or WORD constant (`MZ`). Second, the magic number of the PE header, which is a four-byte or DWORD constant (`PE\x00\x00`). This is illustrated in the following screenshot of a PE file opened in a hexeditor. Both magic numbers are colored in orange. The `MZ` magic is at offset `0x0` and the `PE\x00\x00` is at offset `0x80`.

<figure class="wp-block-image size-large">![Regular PE header with magic numbers (MZ + PE) highlighted.](https://0xc0decafe.com/wp-content/uploads/2021/01/magic_numbers_pe_color.png)<figcaption>Principal magic numbers of a PE file (orange)</figcaption></figure>Now that we’ve seen a perfectly fine PE header, let’s see how a slightly corrupted PE header looks like. The next screenshot shows a PE header with both (principal) magic numbers overwritten.

<figure class="wp-block-image size-large is-resized">![PE header with overwritten magic numbers.](https://0xc0decafe.com/wp-content/uploads/2021/01/overwritten_magic_numbers_pe-1.png)<figcaption>Overwritten magic numbers (MZ + PE)</figcaption></figure>We can still identify that this is likely a PE file since the famous string `This program cannot be run in DOS mode` is still there. But we are missing these two magic numbers, which in turn hinders many analysis tools to properly load and analyze such a binary.

So, fixing this kind of corrupted PE header is straightforward. First, we have to restore the magic number `MZ` at offset `0x0`. Second, we have to determine the offset to the PE header. The DOS header holds this offset in its field `e_lfanew` (see next code block with DOS header for reference). Therefore, we have to read the value of `e_lfanew` from the DOS header. `e_lfanew` resides at offset `0x3c`. Third, we have to restore the PE header magic number `PE\x00\x00` at the offset pointed to by `e_lfanew`. Finally, we should validate, if the file is now a valid PE file.

```
<pre class="wp-block-code" title="_IMAGE_DOS_HEADER structure (winnt.h)">```c
typedef struct _IMAGE_DOS_HEADER {                
    WORD  e_magic;      /* 00: MZ Header signature */       
    WORD  e_cblp;       /* 02: Bytes on last page of file */       
    WORD  e_cp;         /* 04: Pages in file */       
    WORD  e_crlc;       /* 06: Relocations */       
    WORD  e_cparhdr;    /* 08: Size of header in paragraphs */       
    WORD  e_minalloc;   /* 0a: Minimum extra paragraphs needed */       
    WORD  e_maxalloc;   /* 0c: Maximum extra paragraphs needed */       
    WORD  e_ss;         /* 0e: Initial (relative) SS value */       
    WORD  e_sp;         /* 10: Initial SP value */       
    WORD  e_csum;       /* 12: Checksum */        
    WORD  e_ip;         /* 14: Initial IP value */           
    WORD  e_cs;         /* 16: Initial (relative) CS value */          
    WORD  e_lfarlc;     /* 18: File address of relocation table */       
    WORD  e_ovno;       /* 1a: Overlay number */       
    WORD  e_res[4];     /* 1c: Reserved words */       
    WORD  e_oemid;      /* 24: OEM identifier (for e_oeminfo) */       
    WORD  e_oeminfo;    /* 26: OEM information; e_oemid specific */       
    WORD  e_res2[10];   /* 28: Reserved words */        
    DWORD e_lfanew;     /* 3c: Offset to extended header */       
} IMAGE_DOS_HEADER, *PIMAGE_DOS_HEADER;
```
```

Note that if you encounter a memory dump that starts with around 1000 / 0x400 zero bytes, followed by properly aligned code, then you are likely out of luck. What you are looking at is likely a completely overwritten PE header. Here I’ve encountered two scenarios throughout the years. First, the malware unpacks a perfectly fine PE file and overwrites the PE header, for instance, before injecting it into another process. If this is the case then go back to debugging and dump the PE file before the header is overwritten.

Second, the malware unpacks a PE file with an already corrupted PE header. In this case, you have to restore the PE header. If it is really necessary then you can try to [build a PE file from scratch](https://lief.quarkslab.com//doc/latest/tutorials/02_pe_from_scratch.html) with [LIEF](https://lief.quarkslab.com/doc/latest/index.html). However, this is out of the scope of this blog post.

## <span class="ez-toc-section" id="Manipulating_memory_dumps_with_Malduck"></span>Manipulating memory dumps with Malduck<span class="ez-toc-section-end"></span>

[Malduck](https://malduck.readthedocs.io/en/latest/) is a Python module that helps writing malware analysis scripts quickly. It is developed and maintained by [CERT.pl](https://www.cert.pl/). [Malduck’s documentation](https://malduck.readthedocs.io/en/latest/) is very decent. It is my default go-to tool to write malware analysis scripts (e.g. [for aPLib decompression](https://0xc0decafe.com/malware-analysts-guide-to-aplib-decompression/)).

### <span class="ez-toc-section" id="Open_a_memory_dump_with_Malduck"></span>Open a memory dump with Malduck<span class="ez-toc-section-end"></span>

Before we can manipulate memory dumps (of PE files), we have to open them with Malduck. The basis for all memory representations is the class `<a class="rank-math-link" href="https://malduck.readthedocs.io/en/latest/procmem.html">Malduck.procmem</a>` (alias for `malduck.procmem.procmem.ProcessMemory`). The constructor takes three parameters:

- **buf**: a buffer of the memory contents (as among others Python bytes)
- **base** (optional): the base address of the memory dump, which defaults to `0x0`
- **regions** (optional): a list of regions of the memory dump, defaults to `None` (not relevant in the following since we’ll work with PE dumps)

We can get the length of a `ProcessMemory` instance with the method `length` and close it with `close`.

Apart from methods for reading and writing (see next sections), there are methods for searching (**`findmz`**, `findp`, `findv`, `regexp`, `regexv`), YARA scanning (`yarap`, `yarav`), and disassembling (`disasmv`). Note that methods may be suffixed with either `v` (virtual) or `p` (physical). Methods suffixed with `v` work on virtual addresses and methods suffixed with `p` work on physical addresses (raw offsets in the memory dump). The methods `p2v` and `v2p` translate from physical addresses to virtual and vice versa.

Based on `malduck.procmem.procmem.ProcessMemory`, there are four more memory representations in Malduck:

- [ProcessMemoryPE](https://malduck.readthedocs.io/en/latest/procmem.html#processmemorype-procmempe) (alias `procmempe`) for PE files
- [ProcessMemoryELF](https://malduck.readthedocs.io/en/latest/procmem.html#processmemoryelf-procmemelf) (alias `malduck.procmemelf`) for ELF files
- [CuckooProcessMemory](https://malduck.readthedocs.io/en/latest/procmem.html#cuckooprocessmemory-cuckoomem) (alias `malduck.cuckoomem`) for memory dumps in Cuckoo 2.x format
- [IDAProcessMemory](https://malduck.readthedocs.io/en/latest/procmem.html#idaprocessmemory-idamem) (alias `malduck.idamem`) for working with IDAPython

Since this blog post covers PE files, we will work with `ProcessMemoryPE` (alias `procmempe`) in the following. The constructor differs slightly from the constructor of `ProcessMemory`. The first two parameters are still `buf` and `base`. However, it does not take the parameter `regions` but takes two more parameters:

- `image` (optional): indicate that this is a dump of a [memory-mapped](https://docs.microsoft.com/en-us/archive/msdn-magazine/2002/february/inside-windows-win32-portable-executable-file-format-in-detail) PE file, which defaults to `False`
- `detect_image` (optional): heuristically detects if is a [memory-mapped](https://docs.microsoft.com/en-us/archive/msdn-magazine/2002/february/inside-windows-win32-portable-executable-file-format-in-detail) PE file, which defaults to `False`

A useful method of `ProcessMemoryPE` is `is_valid`, which checks if the imagebase of the memory dump points to a valid PE header.

I encourage you to read the [documentation](https://malduck.readthedocs.io/en/latest/index.html) to find other hidden gems. There are further methods like `extract` that tries to extract a malware configuration from the memory dump. See Malduck’s [static configuration extractor engine](https://malduck.readthedocs.io/en/latest/extractor.html) for more information.

### <span class="ez-toc-section" id="Read_ProcessMemoryPE"></span>Read ProcessMemoryPE<span class="ez-toc-section-end"></span>

Malduck supports two ways to read from a `ProcessMemory` instance. First, it allows reading raw data chunks with `readp`, `readv`, and `readv_until`. While `readp` takes as input a raw `offset` and an optional `length`, `readv` takes as input a virtual `addr`. The method `readv_until` is useful when you want to read until a certain stop marker (e.g. end of configuration).

Second, Malduck supports reading various data types:

- strings: `asciiz` and `utf16z`
- signed integers: `int8p`/`int8v`, `int16p`/`int16v`, `int32p`/`int32v`, `int64p` /`int64v`
- unsigned integers: `uint8p`/`uint8v`, `uint16p`/`uint16v`, `uint32p`/`uint32v`, `uint64p` /`uint64v`

Note that there is always a physical (`p`) and virtual (`v`) version. Internally, all utilize either `readp` or `readv` to read the data.

### <span class="ez-toc-section" id="Write_ProcessMemoryPE"></span>Write ProcessMemoryPE<span class="ez-toc-section-end"></span>

The support for writing `ProcessMemory` instances is rudimentary when compared with the reading support. There are just two functions to know: `patchp` and `patchv`. Both accept a raw `offset` / virtual `addr` and a bytes `buf`. That’s it, pretty straight forward!

## <span class="ez-toc-section" id="Putting_it_all_together_fix_PE_magic_numbers_with_Malduck"></span>Putting it all together: fix PE magic numbers with Malduck<span class="ez-toc-section-end"></span>

This section puts it all together: our theoretical knowledge about the PE format and our practical knowledge about memory dump manipulation with Malduck. The script `fix_pe_magic_numbers.py` takes a path to a dump of PE file with a corrupted header as input and outputs a fixed dump.

First, it loads the dump into a buffer `data` and opens it with `malduck.procmempe` (alias of `malduck.procmem.procmempe.ProcessMemoryPE`) in line 11. The method `is_valid` checks if a `ProcessMemoryPE` object is a valid PE file (line 13). Next, it patches the `MZ` magic number with the method `patchp` (line 17) and reads the DOS header field `e_lfanew` with the method `uint32p`. Again, `e_lfanew` resides at offset `0x3C`. Afterwards, it patches the `PE\x00\x00` magic number with the method `patchp` (line 24). Finally, it validates the PE file with the method `is_valid` (line 26). If it is valid, then it writes all bytes of the `ProcessMemoryPE` object to a file (line 29).

```
<pre class="wp-block-code" title="fix_pe_magic_numbers.py">```python
import sys
import malduck

def main(argv):
   `if len(argv) != 2:`
`   print('Usage: fix_pe_magic_numbers.py PATH_TO_DUMP')     `
        `return`

    `with open(argv[1], 'rb') as f:     `
        `data = f.read()`
        `pe = malduck.procmempe(buf=data)     `

        `if pe.is_valid():         `
            `print('This file is already a valid PE file. Skipping...')         `
            `return     `

        `pe.patchp(0, b'MZ')     `
        `lfanew = pe.uint32p(0x3c)     `
        `if lfanew > len(data):         `
            `print('Bogus lfanew value ({hex(lfanew)}). Bailing out...')         `
            `return     `
        
        `print(f'lfanew: {hex(lfanew)}')     `
        `pe.patchp(lfanew, b'PE\x00\x00')     `
        
        `if pe.is_valid():         `
            `print('Fixed file successfully. Dumping to new file...')         `
            `with open(argv[1].replace('bin', '') + '_fixed_header.bin', 'wb') as g:`
 `    `    `g.write(pe.readp(0))         `
                `print('Done.')     `
        `else:         `
            `print('Could not fix file, still not a valid PE file.')     `
        
        `pe.close()`

if <strong>name</strong> == '<strong>main</strong>':
    main(sys.argv)
```
```

Let’s see how it works with our broken memory dump from the beginning:

```
<pre class="wp-block-code">```bash
> file memdump.bin
memdump.bin: data
> python fix_pe_magic_numbers.py memdump.bin
 lfanew: 0x80
 Fixed file successfully. Dumping to new file…
 Done.
> file memdump_fixed_header.bin
memdump_fixed_header.bin: PE32+ executable (console) x86-64, for MS Windows
```
```

et voilà! The script fixed the memory dump as we can see in the following screenshot:

<figure class="wp-block-image size-large is-resized">![Fix PE magic numbers with malduck.](https://0xc0decafe.com/wp-content/uploads/2021/01/fixed_pe.png)<figcaption>Fixed PE header with MZ and PE magic numbers restored</figcaption></figure>Both magic numbers are located at their correct offsets: the magic number of the DOS header `MZ` resides at offset zero and the magic number of the File header resides at offset 0x80 (as indicated by `e_lfanew`). Now you can load the PE file with other analysis tools and continue your analysis.