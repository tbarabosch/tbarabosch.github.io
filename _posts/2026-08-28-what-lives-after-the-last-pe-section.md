---
title: 'What lives after the last PE section?'
date: '2026-08-28T12:00:00+02:00'
last_modified_at: '2026-08-28T12:00:00+02:00'
author: tbarabosch
layout: post
tags:
  - malware analysis
  - reverse engineering
  - Windows
---

A Portable Executable does not necessarily end with its last mapped section. Trailing bytes form an *overlay*: data that Windows does not map as part of the image, but which still belongs to the file.

Removing an overlay is easy. Doing it without discarding useful information is the interesting part. This post revisits an old helper I wrote a couple of years ago and adds the missing guardrails using OpenAI's Codex.

This somehow continues my work on [PE timestamps](/malware-analyst-guide-to-pe-timestamps/) and [PE magic numbers](/fix-pe-magic-numbers-with-malduck/), but at the other end of the file.

<!--more-->

## An old helper

Years ago, I wrote a small script to remove PE overlays. It is from 2021 and simple enough to show in full:

```python
import sys
import pefile


def main(argv):

    if len(argv) != 2:
        print('Usage: pe_strip_overlay.py PATH_TO_PE_WITH_OVERLAY')

    with open(argv[1], 'rb') as f:
        data = f.read()
        try:
            pe = pefile.PE(data=data)
            if pe:
                with open(argv[1].replace('.bin', '') + '_stripped.bin', 'wb') as g:
                    g.write(pe.trim())
        except Exception as e:
            print(f'Could not trim PE file: {e}')


if __name__ == '__main__':
    main(sys.argv)
```

As you can see, the heavy lifting is done mostly by `pefile`. It looked like a good idea for a short post, so I used Codex to review its assumptions and turn it into the safer public helper described below as this is a common problem you might stumble upon while reversing Windows malware.

The old script discarded the overlay, invented a name with `str.replace()`, caught every exception and reported no hashes. Its filename could collide with another file. More importantly, `pefile.PE.trim()` does not ask whether the suffix contains a PE Certificate Table. So in summary, a classical RE script!

## The section table is not the whole file

The raw end of a section is `PointerToRawData + SizeOfRawData`. The highest relevant end offset gives an overlay candidate:

```text
file offset ->

+---------+---------+---------+------------------+
| headers | .text   | .idata  | appended bytes   |
+---------+---------+---------+------------------+
                              ^ overlay candidate
```

That boundary needs a parser. The [Microsoft PE/COFF specification](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format) has one awkward exception: the Certificate Table contains a file offset, not an RVA, because the loader does not map its `WIN_CERTIFICATE` records.

```text
Optional Header
  Certificate Table ---------------------+
                                          v
+---------+----------+-------------------+----------+
| headers | sections | WIN_CERTIFICATE   | more data|
+---------+----------+-------------------+----------+
                     outside mapped sections
```

The pinned [`pefile` 2024.8.26 implementation](https://github.com/erocarrera/pefile/blob/v2024.8.26/pefile.py#L7903-L7966) skips the Security directory while finding the overlay. Its `trim()` therefore removes certificate bytes too. They are outside the mapped sections, but not undescribed junk.

## Preserve the suffix before trimming it

The updated script uses explicit paths, exclusive output creation, SHA-256 and a hard stop for a nonempty or malformed Certificate Table. The [complete helper and reusable Apple Container environment live in `re-scripts` at commit `06c38cc`](https://github.com/tbarabosch/re-scripts/blob/06c38cccce956731244703f68c8239426759d0e6/pe/trim_pe_overlay.py). The abbreviated excerpts below cover only its two important decisions.

First, the Security data-directory entry is either empty or a stop sign. A malformed pair of offset and size is not a reason to guess:

```python
offset = entry.VirtualAddress
size = entry.Size
if offset == 0 and size == 0:
    return
if offset == 0 or size == 0 or offset % 8 != 0 or offset + size > file_size:
    raise OverlayError("malformed PE Certificate Table entry; refusing to trim")
raise OverlayError("PE Certificate Table present; refusing to trim")
```
{: data-language="PYTHON EXCERPT" }

Only after that check does the helper split the bytes at `pefile`'s overlay offset. It writes the evidence first and the derived executable second:

```python
overlay_offset = pe.get_overlay_data_start_offset()
if overlay_offset is None:
    return 0
if not 0 < overlay_offset < len(data):
    raise OverlayError("invalid overlay offset")

overlay_data = data[overlay_offset:]
trimmed_data = data[:overlay_offset]

write_new(args.overlay_out, overlay_data)
write_new(args.trimmed_out, trimmed_data)
```
{: data-language="PYTHON EXCERPT" }

I built this no-op with `x86_64-w64-mingw32-gcc 13-win32` in an Ubuntu 24.04 Apple Container:

```c
int main(void)
{
    return 0;
}
```

I put `OVERLAY-DEMO.txt` into a ZIP, appended it and ran the helper with `pefile` 2024.8.26:

```console
$ x86_64-w64-mingw32-gcc -Os -s -o hello.exe hello.c
$ zip -X payload.zip OVERLAY-DEMO.txt
$ cp hello.exe hello-overlay.exe
$ dd if=payload.zip of=hello-overlay.exe oflag=append conv=notrunc status=none
$ python3 trim_pe_overlay.py hello-overlay.exe --overlay-out recovered.zip --trimmed-out hello-trimmed.exe
input:   hello-overlay.exe (15021 bytes, sha256=223aaf2145a3d03ae375c72251a320320b3728c83ee1440221ffcf2253b6ed7a)
overlay: recovered.zip (173 bytes at 0x3a00, sha256=06dfd3404725f7152381d9e44a3fbb9021cdddd8e508b743efe3c1313d18e5dc)
trimmed: hello-trimmed.exe (14848 bytes, sha256=7c71c75a9d692a7c3436be34b487d96c1a21c6ad3868079d060675af2b070623)

$ cmp payload.zip recovered.zip
$ cmp hello.exe hello-trimmed.exe
```

Both comparisons succeeded: the suffix was the exact ZIP and the derived PE was the pre-append executable.

## A certificate table is a stop sign

I locally signed the executable with `osslsigncode`. The helper found its Certificate Table and refused before creating output:

```console
$ python3 trim_pe_overlay.py hello-signed.exe --overlay-out signed.overlay --trimmed-out hello-signed-trimmed.exe
error: PE Certificate Table present; refusing to trim (offset=0x3a00, size=1488)
```

A Certificate Table proves neither signature validity nor trust. It only describes certificate data at a file offset and probably not the job of this script. Authenticode verification is a separate job and shall be addressed in another blog post.
