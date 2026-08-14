---
title: 'One BSD’s fix is another BSD’s bug'
date: '2026-08-10T18:00:00+02:00'
last_modified_at: '2026-08-10T18:00:00+02:00'
author: tbarabosch
layout: post
toc: true
tags:
  - systems security
  - FreeBSD
  - OpenBSD
  - NetBSD
---

A source-code fix describes two things at once. It shows how the code should look after the change, but its removed lines also preserve a small description of the bug. When several operating systems share ancestry and code, that description becomes a useful question: did the same code reach another tree without the fix?

Years ago I turned this question into a research prototype called [HistRepo](https://github.com/tbarabosch/bsd-histrepo). It collected the histories of several BSD projects, selected commits that looked like bug fixes and searched the other source trees for code resembling the pre-fix version. The implementation was rather crude. The idea was not.

<!--more-->

<nav class="post-toc" aria-labelledby="contents-heading" markdown="1">
<p id="contents-heading" class="manual-label">CONTENTS</p>

* TOC
{:toc}
</nav>

## A patch is also a search signature

FreeBSD, NetBSD and OpenBSD are separate projects with different goals, developers and release processes. They nevertheless share history, interfaces and imported components. Similar code does not imply identical behavior, but it is often close enough to carry the same mistake.

A normal search begins with a suspicious function and tries to decide whether it contains a bug. HistRepo started one step later. It used a commit that appeared to fix a bug and asked where the old code still existed:

```text
Project A history                    Project B tree

old code --[ fix ]--> new code       related code
              |
              +-- removed lines ---------+
                                           |
                                           v
                                  similar old code?
                                           |
                                           v
                                      human review
```

This changes the economics of source review. I did not have to invent every possible bad pattern or inspect every line in every kernel. Developers had already marked interesting code by changing it. Commit messages supplied a rough classification, and the patch supplied a concrete fragment to search for.

The result was never proof. A similar fragment in another tree might be unreachable, protected by a check elsewhere, or merely look the same while following different semantics. The match only told me where to start reading.

The removed side of the patch was the important part. Searching for the added check would answer whether another project had already adopted a similar repair. Searching for the deleted code asked the more interesting question: where might the unfixed state still survive? Context lines kept the signature specific enough to distinguish a real shared implementation from a generic statement such as `return error`. In that sense, HistRepo treated version control as a database of negative examples. Each promising fix contributed another piece of code that I no longer wanted to see elsewhere.

## Turn history into a corpus

The first stage imported complete Git histories into MongoDB. [`HistRepo.py`](https://github.com/tbarabosch/bsd-histrepo/blob/main/src/HistRepo.py) walked each repository and stored the commit ID, author, timestamp, message, aggregate change statistics, changed paths and full textual patch against the first parent. Each operating system received its own collection in a database named `bsd`.

MongoDB was not important to the research idea. It was simply convenient for keeping hundreds of thousands of commits and their patches in a form that I could query repeatedly. The expensive part was building the corpus. Once it existed, I could change the keywords or matching rules without walking every Git object again.

The preserved scripts contain definitions for FreeBSD, OpenBSD, NetBSD, DragonFly BSD, Darwin/XNU and illumos. The comparison configuration that survived enables the first three. I also copied the large source trees to a RAM-backed filesystem before scanning them. Repeatedly sliding text windows over several kernel trees was not elegant, but memory was much faster than the disks in my workstation at the time.

In simplified form, the whole experiment looked like this:

```text
Git histories
     |
     v
commit messages -- keyword filter --> likely bug fixes
                                         |
                                         v
                                  old side of patch
                                         |
                                         v
                              sibling BSD source trees
                                         |
                                         v
                                fuzzy text matches
                                         |
                                         v
                                  manual validation
```

## Let commit messages narrow the search

The first filter was deliberately unsophisticated. HistRepo searched commit messages for phrases such as `buffer overflow`, `null pointer`, `out of bounds`, `use after free`, `kernel panic`, `uninitialized` and `information leak`. Each phrase mapped to a coarse category.

This favored recall over precision. A commit saying “fix null pointer dereference” was worth inspecting, even if the failure was only a local denial of service. A security fix whose message said only “correct accounting” would be missed entirely. Commit messages are evidence written for maintainers, not a vulnerability database with a stable schema.

The keywords were therefore a queueing mechanism, not a definition of security. They moved patches with promising language to the front of the review, where code could confirm or reject the message. This also made the approach useful for ordinary correctness bugs. A memory leak, panic or missing validation step can be worth propagating even when it does not cross the threshold for a security advisory.

For every selected commit, HistRepo split the commit-wide diff into individual file patches. The preserved version then restricted the experiment to the configured kernel root, normally `sys/`. It reconstructed the old side of each hunk by discarding added lines while retaining removed lines and context:

```text
diff hunk

  context_before();
- old_code();
+ fixed_code();
  context_after();
          |
          +-- '+' line: discard
          +-- '-' line: keep without marker
          `-- ' ' line: keep as context
          |
          v
pre-fix snippet

  context_before();
  old_code();
  context_after();
```

This is not a general-purpose patch parser. It assumes conventional textual Git diffs and ordinary hunks. For this corpus it produced the material I wanted: an approximation of the function or block as it looked before the candidate fix.

## Search for resemblance, not equality

Exact matching would have been too strict. Related BSD implementations accumulate formatting changes, renamed variables, different comments and small local modifications. HistRepo therefore used `fuzzywuzzy.fuzz.ratio` to compare each pre-fix snippet with windows from the other trees.

To reduce the search space, it considered only C and header files whose path contained the same filename as the patched file. The window had the same length as the snippet and advanced by one quarter of that length. Scores above 80 were printed for review. The central loop was small:

```text
patched file:  sys/.../route6d.c
                         |
                         v
search:         */route6d.c in other trees

pre-fix snippet
[================]

candidate file
[================]............  score 72
....[================]........  score 84  --> review
........[================]....  score 61
    ^
    `-- move by one quarter of the snippet length
```

None of these numbers had a statistical interpretation. A score of 81 did not mean an 81 percent probability of a vulnerability. The filename rule could miss copied code that had moved or been renamed. The quarter-window stride could skip a better alignment, while a common error path could generate uninteresting matches. These were pragmatic controls for turning a very large search into a manageable pile of leads.

The useful output was not the score. It was a filename, two pieces of code and a reason to compare their surrounding functions.

## Two bugs, four fixes

Two small userland bugs show the method particularly well. Both affected programs derived from the KAME IPv6 code, and both appeared in NetBSD and OpenBSD. They were not kernel vulnerabilities. They were missing releases of address information returned by `getaddrinfo()`.

The fixes landed close together:

```text
                 NetBSD              OpenBSD

route6d          2018-06-14          2018-06-14
                     \                  /
                      +-- same leak ---+

ndp              2018-06-16          2018-06-17
                     \                  /
                      +-- same leak ---+
```

In `route6d`, the result was used to initialize a socket address and then forgotten. The [NetBSD patch](https://freshbsd.org/netbsd/src/commit/Z13ovdA7TmSFAgGA/diff/raw) and [OpenBSD patch](https://freshbsd.org/openbsd/src/commit/yJ2tdyzIbhIEvnh2/diff/raw) added the same missing cleanup at the corresponding points. The `ndp` fixes did likewise in several command paths in [NetBSD](https://freshbsd.org/netbsd/src/commit/lCfKrqa1m0zouvGA/diff/raw) and [OpenBSD](https://freshbsd.org/openbsd/src/commit/xHUblD74mVzd4SK8/diff/raw).

Reduced to their essential shape, the patches looked like this:

```diff
 memcpy(&ripsin, res->ai_addr, res->ai_addrlen);
+freeaddrinfo(res);

 makeaddr(mysin, res->ai_addr);
+freeaddrinfo(res);
```

There is nothing exotic here. That is precisely why history comparison was useful. A memory leak in a mature networking utility is easy to overlook during an open-ended audit. Once another tree contains the relevant fix, the old code becomes a very specific signature. The question is no longer “does this large program leak anything?” It is “does this related implementation release the object at this corresponding point?”

The two pairs are representative examples, not a complete accounting of the research. The broader [FreshBSD attribution trail](https://freshbsd.org/?q=Barabosch) also contains branch merges, backports, downstream imports and findings produced with other techniques. It is useful as a public record, but it should not be read as a count of unique HistRepo bugs.

## The matcher was not the analyst

After a match, the real work started. I had to establish whether both functions used the same ownership rules, whether every successful allocation reached the candidate path, and whether a cleanup already happened through another helper. For kernel code the questions became more serious: could an unprivileged process reach the path, what locks and reference counts were active, did a different invariant prevent the failure, and which supported branches contained the code?

Dates also mattered. The preserved matcher compared historical fixes with copied working trees rather than checking out each target at a date aligned with the source commit. A match might therefore describe a bug that had already been fixed independently. Conversely, looking only at a modern tree could hide a historically vulnerable version. Before reporting anything, I needed to reconstruct the relevant timeline from the target project's own history.

This manual step prevented a similarity engine from becoming a vulnerability-claim generator. Sometimes the code was genuinely affected. Sometimes another BSD had already repaired the problem differently. Sometimes the surrounding implementation made the apparent match irrelevant. All three outcomes were useful because they replaced a fuzzy textual lead with an explanation.

Reporting was also part of the method. Each project had its own conventions and maintainers who understood the code far better than I did. A useful report needed the originating fix, the matching target code, the reason the same defect applied and, where possible, a small patch or reproducer. “My script found a score above 80” was not evidence a maintainer could act on.

The published HistRepo repository should be read as a historical artifact, not as a maintained scanner. It contains machine-specific paths, incomplete reporting paths, unpinned dependencies and no preserved tests. Its surviving configuration is kernel-focused, while the confirmed `route6d` and `ndp` examples came from the earlier, broader workflow that is no longer completely represented by the snapshot.

## I would run this experiment again

The old matcher understood characters, not code. A renamed function, a moved file or a differently written check could hide a related bug from it. Today I would keep the historical corpus and the hard requirement for manual validation, but use an LLM to formulate and evaluate candidates while ordinary tools perform the retrieval.

The model should not receive several complete kernels and a vague instruction to find vulnerabilities. I would start with a known fix and ask the model to describe the actual bug condition: which state becomes invalid, which check is missing, who controls the input and what the patch changes. Ordinary tools could then retrieve candidates through filenames, symbols, syntax trees, text search and embeddings. The model would read the smaller set of surrounding functions and compare semantics rather than spelling.

```text
commit + diff + advisory
          |
          v
LLM extracts the bug condition
          |
          v
text / symbol / AST retrieval
across the other BSD histories
          |
          v
agent reads code and queries Git history
          |
          v
reproducer / sanitizer / regression test
          |
          v
human validation and coordinated disclosure
```

This is no longer a hypothetical workflow. [Google Project Zero's Big Sleep experiment](https://projectzero.google/2024/10/from-naptime-to-big-sleep.html) collected recent commits, supplied an agent with a commit message and diff, and asked it to inspect the current SQLite tree for related issues that might not have been fixed. That variant-analysis run found a previously unknown memory-safety bug. [More recent LLM vulnerability research](https://www.anthropic.com/research/zero-days) also describes models reading past fixes to locate similar unaddressed bugs. The researchers still had humans validate the findings and write the initial patches, which is exactly where I would keep the boundary.

The agent could do more than rank matches. It could follow renamed functions through Git history, compare ownership and locking rules, propose a reproducer, build the affected kernel in an isolated environment and turn a confirmed fix into regression tests for the sibling projects. Every one of those outputs would still need deterministic evidence. A plausible explanation is not a reachable code path, and a generated test that only crashes the wrong configuration proves very little.

This experiment is worth repeating. The BSD trees have continued to diverge, import code and accumulate fixes since my original run. Their histories now contain a much larger collection of reviewed negative examples, while LLMs are better suited to semantic variant analysis than my sliding text windows ever were. A new run would almost certainly produce noise. I would be surprised if it produced nothing else.

## Forks share more than code

The obvious lesson is that related projects share bugs. The less obvious lesson is that they do not necessarily share the maintenance event that removes the bug. Once code has crossed a project boundary, its future fixes have to cross that boundary again deliberately. Different filenames, local refactoring, release branches and project priorities make that propagation increasingly difficult over time.

This is not a criticism of the BSD projects. Independent development is the point, and maintainers cannot blindly import every neighboring change. A patch may depend on assumptions that are true in one kernel and false in another. The safe response is not automatic synchronization. It is deliberate comparison: identify the common ancestry, understand the fix and decide whether the sibling implementation needs an equivalent change.

HistRepo automated only the cheapest part of that process. It scavenged through history and placed suspicious similarities in front of me. The maintainers and I still had to determine what the code meant.

One BSD's fix can be another BSD's bug, but only until somebody follows the history across the fork.
