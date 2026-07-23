---
title: 'Grill me with ASCII'
date: '2026-07-22T12:00:00+02:00'
author: tbarabosch
layout: post
tags:
  - AI tooling
---

Matt Pocock’s original [`grill-me` skill](https://github.com/mattpocock/skills/blob/main/skills/productivity/grill-me/SKILL.md) is delightfully stubborn. Give Codex a plan and it does not immediately produce an implementation. It inspects the available context, recommends an answer and asks one question. Then it waits. The interview continues until the design is clear enough to build, or until abandoning it starts to look like the sensible option.

I wanted to keep this interview workflow, but add diagrams that change along with the answers. My `grill-me-with-ascii` variant draws small component maps, flows, state diagrams or decision trees. Decisions are marked `[D]`, assumptions `[A]`, open questions `[?]` and actual risks `[R]`. This is not there to make the conversation look more technical. A wrong arrow is easier to notice than a wrong paragraph, and a missing branch has nowhere to hide.

To try it, I asked Codex to design a minimal ARM64 disassembler in Python. We started with an empty workspace, so the first useful question was scope: decode a curated A64 subset, attempt the much larger base integer ISA, or put a thin interface around Capstone or LLVM. The diagram made the trade-off rather hard to ignore. Codex recommended a dependency-free decoder for a curated subset, with tables and masks that could be extended later. This was a much better definition of minimal than whatever happens to fit into the first implementation.

![Codex using Grill Me with ASCII to compare three instruction-coverage options for a minimal ARM64 disassembler](/assets/images/posts/grill-me-with-ascii/grill-me-with-ascii-arm64.png)

That is why I find ASCII useful here. It turns Codex’s current model of the design into something I can inspect, correct and disagree with before any code exists. The [`grill-me-with-ascii` skill](https://github.com/tbarabosch/codex-skills/tree/main/grill-me-with-ascii) is available in my Codex skills repository. If it eventually draws a box labelled `[R] terrible idea`, I should probably take the hint.
