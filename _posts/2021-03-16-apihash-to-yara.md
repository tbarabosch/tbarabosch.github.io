---
title: 'Detect API hashing with YARA'
date: '2021-03-16T16:42:31+00:00'
author: tbarabosch
layout: post
image: /wp-content/uploads/2021/03/teaser_apihashing-scaled.jpg
categories:
    - 'Malware Analysis'
    - Tools
tags:
    - 'API hashing'
    - Buer
    - Malpedia
    - 'Panda Banker'
    - PlugX
    - PoisonIvy
    - VMZeus
    - yara
---

Malware utilizes obfuscation to complicate its analysis. There is one obfuscation technique that targets specifically static analysis: API hashing. In a nutshell, malware uses hashes of API names (e.g. `0x0688eae1`) instead of plain strings (e.g. `kernel32!Sleep`) to obfuscate the API functionality it relies on. This is typically a pretty nasty obfuscation technique since it requires malware analysts to resolve this API hashing before they can conduct a meaningful analysis. There are many advanced malware families that utilize API hashing including [Buer](https://www.proofpoint.com/us/threat-insight/post/buer-new-loader-emerges-underground-marketplace), [PoisonIvy](https://www.fireeye.com/blog/threat-research/2012/11/precalculated-string-hashes-reverse-engineering-shellcode.html), [PlugX](https://blogs.jpcert.or.jp/en/2017/02/plugx-poison-iv-919a.html) and [UrlZone](https://twitter.com/VK_Intel/status/981326743486185472?s=20).

As a first step in the triage phase, it nice to have a first pointer whether or not a malware family could use API hashing and if so which algorithm it uses to hash API names. Therefore, I wrote a tiny project called `apihash_to_yara.py` that generates YARA rules to detect this behavior fast and without too many false positives. The source code is on [Github](https://github.com/tbarabosch/apihash_to_yara) where you’ll also find two sets of precompiled YARA rules.

API hashing is an obfuscation technique that you’ll typically encounter in advanced malware. Normally, the names of APIs are stored in plain text in a binary (e.g. as part of the Import Table of the PE header). Remember that strings and APIs are very important corner stones in the reverse engineering puzzle. Hence, malware authors try to obfuscate them so that malware analysts have to significantly invest more time.

In API hashing, API names are not stored in plain text but rather their hashes are stored in the binary. Malware utilizes these hashes and resolves the addresses to APIs itself. To resolve an API hash `h` to an API name, it typically hashes the exported APIs of DLL loaded into the process space with an embedded hashing algorithm. Then, it compares each computed hash to `h`. A good write-up on how malware achieves this by enumerating DLLs via the PEB [can be found here](https://modexp.wordpress.com/2017/01/15/shellcode-resolving-api-addresses/).

A common algorithm that you’ll encounter is [CRC32](https://en.wikipedia.org/wiki/Cyclic_redundancy_check). The following Python snippet shows how we can compute the CRC32 hash of the API name `Sleep`:

```
<pre class="wp-block-code">```python
>>> import zlib
>>> h = zlib.crc32(b'Sleep')
>>> hex(h)
 '0xcef2eda8'         
```
```

Note that we do not have to come up with our own implementations for the many API hashing algorithms that exist in malware since there is already an implementation of many in [make\_sc\_hash\_db from flare-ida](https://github.com/fireeye/flare-ida/blob/master/shellcode_hashes/make_sc_hash_db.py), which we’ll use later.

To detect this behavior fast with YARA, we’ll do not have to know how the resolving works in detail. We won’t match the embedded algorithm either. Instead, we’ll match the API hashes that have to be stored in the malicious binary somewhere.

There are two ways how malware stores these hashes. Both ways correspond to one way how they are resolved. The first way is to resolve the API hashes during the initialization of the malware. Therefore, the malware comprises an array of API hashes and resolves one after another on startup. For instance, this is what the malware PoisonIvy does. The following screenshot shows the API hash array found in its binary. I’ve marked the hash `0xBA36C10A`, which corresponds to the API function `Kernel32!Sleep`.

<figure class="wp-block-image size-large">![](https://0xc0decafe.com/wp-content/uploads/2021/03/apihashing_poison_ivy_table.png)<figcaption>Table of API hashes in PoisonIvy dump, hash of Kernel32!Sleep (0xBA36C10A) marked in blue</figcaption></figure>The second way is to resolve the API hashes just in time. This means that every time the malware calls an API function, it first resolves the hash. The following screenshot of the malware family VMZeus depicts this behavior. The function `resolve_api_hashing` takes among other parameters an API hash as input. It resolves the API hash and returns the address to the API in the register `eax`. This is subsequently called (`call eax`).

<figure class="wp-block-image size-large">![API hashing in VMZeus sample: red boxes contain API hashes, the hash 0xCEF2EDA8 is the CRC32 hash of Sleep](https://0xc0decafe.com/wp-content/uploads/2021/03/apihashing_vmzeus_crc32.png)<figcaption>API hashing in VMZeus sample: red boxes contain API hashes, the hash 0xCEF2EDA8 is the CRC32 hash of Sleep</figcaption></figure>## <span class="ez-toc-section" id="Whats_the_main_idea"></span>What’s the main idea?<span class="ez-toc-section-end"></span>

The main idea is to generate one YARA rule for several API hashes that are generated with API hashing algorithm. I didn’t want to reinvent the wheel and therefore I adjusted the API hashing algorithms found in [make\_sc\_hash\_db from flare-ida](https://github.com/fireeye/flare-ida/blob/master/shellcode_hashes/make_sc_hash_db.py). [This project ](https://www.fireeye.com/blog/threat-research/2012/11/precalculated-string-hashes-reverse-engineering-shellcode.html)comprises more than a dozen API hashing algorithms.

`apihash_to_yara` requires a list of DLL names and API names (e.g. `kernel32!Sleep`) as input and generates based on them a YARA rule set. I recommend to include `A` / `W` versions of an API (e.g. `SleepA` and `SleepW`) since their API hashes are likely different. If you create your own list using the script `generate_api_list.py` then this script will handle this for you. Since some malware families store their hashes in little endian format and some in big endian format, both formats are always generated.

There are already two API lists included in the `data` directory of the project. The first `top100_winapi_malpedia.txt` comprises the Top100 Windows API functions found in samples hosted on [Malpedia](https://malpedia.caad.fkie.fraunhofer.de/). The second API list `custom_apis.txt` comprises all API names found in common Windows DLLs such as `kernel32.dll`.

There are two parameters that help you to tweak the detection performance. First, there is the parameter `--yara_condition_match_threshold` that defines how many API hashes have to be matched in a binary. The default value is `10` API hashes, which is just an educated guess. The value `5` API hashes yielded to many false positives. The second parameter that you could tweak is `--yara_condition_filesize_threshold` that ensures that only binaries with less than `n` kilobytes are considered. This is another way to reduce false positives. Feel free to adjust these parameters to your needs. In the following, I’ll list all command line options of `apihash_to_yara.py` for your reference:

```
<pre class="wp-block-code">```bash
usage: apihash_to_yara.py [-h] [--yara_condition_match_threshold YARA_CONDITION_MATCH_THRESHOLD] [--yara_condition_filesize_threshold YARA_CONDITION_FILESIZE_THRESHOLD] path_api_names output
 positional arguments:
   path_api_names        Path to list of API names
   output                Path to output
 optional arguments:
   -h, --help            show this help message and exit
   --yara_condition_match_threshold YARA_CONDITION_MATCH_THRESHOLD
                         Threshold of required matches in YARA condition
   --yara_condition_filesize_threshold YARA_CONDITION_FILESIZE_THRESHOLD
                         Filesize threshold of required matches in YARA condition
```
```

The output of `apihash_to_yara.py` looks similar to the following:

```
<pre class="wp-block-code">```c
rule api_hash_ror7AddHash32 {
     meta:
         author = "Thomas Barabosch"
         reference1 = "https://0xc0decafe.com/apihash-to-yara/"
         reference2 = "https://github.com/tbarabosch/apihash_to_yara"
         reference3 = "https://github.com/fireeye/flare-ida/tree/master/shellcode_hashes"
         reference4 = "https://malpedia.caad.fkie.fraunhofer.de/stats/api_usage"
         api_count = "300"
         yara_condition_match_threshold = "10"
         yara_condition_filesize_threshold = "1024"
     strings:
         $kernel32_dll_Sleep = { cb 97 65 a0 }
         $kernel32_dll_Sleep_little_endian = { a0 65 97 cb }
         $kernel32_dll_SleepA = { 41 97 2f 0c }
         $kernel32_dll_SleepA_little_endian = { 0c 2f 97 41 }
         $kernel32_dll_SleepW = { 41 97 2f 22 }
         $kernel32_dll_SleepW_little_endian = { 22 2f 97 41 }
         $kernel32_dll_CloseHandle = { ff 0d 66 57 }
         $kernel32_dll_CloseHandle_little_endian = { 57 66 0d ff }
         $kernel32_dll_CloseHandleA = { af fe 1b 0d }
         $kernel32_dll_CloseHandleA_little_endian = { 0d 1b fe af }
         $kernel32_dll_CloseHandleW = { af fe 1b 23 }
         $kernel32_dll_CloseHandleW_little_endian = { 23 1b fe af }
 […]
     condition:
         10 of them and filesize < 1024KB
 }
```
```

There are two precompiled sets of YARA rules in the [repository](https://github.com/tbarabosch/apihash_to_yara). First, `top100_apis_malpedia.yar` (based on the Malpedia API names) and `custom_apis.yar.gz` (based on `custom_apis.txt`, gzipped due to size restrictions).

## <span class="ez-toc-section" id="Does_it_work_-_A_very_unscientific_evaluation"></span>Does it work? – A very unscientific evaluation<span class="ez-toc-section-end"></span>

No real scientific evaluation here, just some random case studies. I ran `top100_apis_malpedia.yar` on Malpedia. I had more than 450 matches but this included different versions of a malware family. From 68 families I had at least one match. Throughout the years I’ve analyzed some of these families and remember them to use API hashing (not exactly the algorithm but the fact that they do). While this is a very weak confirmation that `apihash_to_yara.py` works, I had a look at a handful samples.

I’ll refrain from posting the list of matches due to the TLP:AMBER nature of some of the families. If you’ve access to the Malpedia corpus, please run it yourself. Play a bit with the threshold parameters to avoid false positives. Let me know your results and suggest improvements! Some examples that I stumbled upon are:

- [Buer](https://www.proofpoint.com/us/threat-insight/post/buer-new-loader-emerges-underground-marketplace) (ror13AddHash32Sub20h)
- [Panda Banker](https://www.botconf.eu/wp-content/uploads/2018/12/2018-Dennis-Schwarz-everything_panda_banker.pdf) (crc32)
- [Poison Ivy and PlugX](https://blogs.jpcert.or.jp/en/2017/02/plugx-poison-iv-919a.html) (PoisonIvyHash)

Furthermore, I scheduled a Retrohunt on VirusTotal’s Goodware corpus. Actually, I scheduled two Retrohunts since the maximal size is 1MB per rule set. The `top100_apis_malpedia.yar` has a filesize of 1.3MB. Therefore, I split the rule set accordingly. In total, there were `7` false positives, all of them matched the rule `sll1AddHash32`. In environments where you can not tolerate false positives, you should turn off this rule.

<figure class="wp-block-image size-large">![VirusTotal Retrohunt on Goodware corpus with top100_apis_malpedia.yar](https://0xc0decafe.com/wp-content/uploads/2021/03/vt_retrohunt_api_hashing-1024x115.png)<figcaption>VirusTotal Retrohunt on Goodware corpus with top100\_apis\_malpedia.yar</figcaption></figure>## <span class="ez-toc-section" id="Conclusion"></span>Conclusion<span class="ez-toc-section-end"></span>

Let me quickly conclude what we’ve presented in this blog post. This blog post presented `apihashing_to_yara.py`, a tiny project to generate YARA rules to detect API hashing in malware fast and without too many false positives. The project can be[ found on Github](https://github.com/tbarabosch/apihash_to_yara). There are also two precompiled YARA rules already included. Shout out to the giants on whose shoulders I stand: [make\_sc\_hash\_db from flare-ida](https://github.com/fireeye/flare-ida/blob/master/shellcode_hashes/make_sc_hash_db.py) and [Malpedia](https://malpedia.caad.fkie.fraunhofer.de/).

As always, there is always room for improvement. One path that could be followed is finding the perfect condition thresholds. Right now the default value is 10 API hash matches and 1024KB filesize, however these values may be too conservative. Quick tests with lower thresholds (e.g. 5 matches) yielded too many FPs. Another path is adding more API hashing algorithms. If time permits, I’ll port new algorithms from [make\_sc\_hash\_db from flare-ida](https://github.com/fireeye/flare-ida/blob/master/shellcode_hashes/make_sc_hash_db.py).
