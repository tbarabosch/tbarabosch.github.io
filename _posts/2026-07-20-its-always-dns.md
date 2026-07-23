---
title: "It's always DNS"
date: '2026-07-20T12:00:00+02:00'
author: tbarabosch
layout: post
tags:
  - site notes
---

[tbarabosch.com](https://tbarabosch.com) is now the official domain of this blog.

The GitHub Pages address served this site well, but the blog now has a proper home of its own. Nothing else has changed: the same posts, the same manpage-inspired layout and, inevitably, the same author.

Moving a static blog to a custom domain sounds harmless. Change a couple of DNS records, watch `dig` for a while and wait for caches to agree. This is also roughly how a surprising number of outage reports begin.

I therefore hope this does not break everything in the grand tradition of a small DNS change making an entire service disappear. If the blog does vanish, we can at least skip the first hour of troubleshooting. The incident report already has a title: it’s always DNS.
