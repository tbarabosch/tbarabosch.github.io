---
title: 'Earning the BSD Specialist certification'
date: '2026-08-31T12:00:00+02:00'
last_modified_at: '2026-08-31T12:00:00+02:00'
author: tbarabosch
layout: post
image:
  path: /assets/images/posts/earning-the-bsd-specialist-certification/social-card.png
  width: 1200
  height: 630
social_card:
  layout: text
  subtitle: 'A credential after years of BSD security research, patches, and maintenance.'
  eyebrow: 'Systems Security / BSD'
  panel_label: 'Credential'
  text: 'Practical work across FreeBSD, NetBSD, and OpenBSD came before the badge.'
tags:
  - systems security
  - FreeBSD
  - NetBSD
  - OpenBSD
---

On 31 August 2026, I earned the [LPI BSD Specialist certification](https://www.credly.com/badges/5bcfb19e-b19e-4168-a041-554545aeaa0c). The exam covers administration across FreeBSD, NetBSD and OpenBSD: installation, storage, networking, security, system maintenance and the Unix tools shared between them.

I am pleased to have passed, but the credential does not mark the beginning of my work with BSD. It is a formal checkpoint after years of approaching these systems from several directions.

<!--more-->

<figure class="credential-badge">
  <a href="https://www.credly.com/badges/5bcfb19e-b19e-4168-a041-554545aeaa0c" aria-label="View my LPI BSD Specialist credential on Credly">
    <img src="/assets/images/posts/earning-the-bsd-specialist-certification/bsd-specialist-badge.png" alt="LPI BSD Specialist Certification badge issued to Thomas Barabosch" width="600" height="600">
  </a>
</figure>

Much of that work began on the security side. A malformed ELF header led to a FreeBSD kernel crash and memory disclosure fixed as [CVE-2018-6924](https://www.freebsd.org/security/advisories/FreeBSD-SA-18:12.elf.asc). Trap fuzzing exposed the OpenBSD denial of service later assigned [CVE-2018-14775](https://www.openbsd.org/errata63.html). Together with Maxime Villard, I designed KLEAK, the kernel memory-disclosure detector credited with finding thirteen issues in [NetBSD-SA2019-001](https://mail-index.netbsd.org/current-users/2019/02/06/msg035047.html).

BSD projects also accepted reports and patches that became fixes in their source trees. Some crossed project boundaries: related mistakes in KAME-derived networking tools were corrected in both NetBSD and OpenBSD. I described that work in [One BSD's fix is another BSD's bug](/one-bsds-fix-is-another-bsds-bug/).

More recently, I moved from finding faults in BSD software to maintaining a small part of its supply chain. I updated FreeBSD's [`misc/xdelta3` port](https://cgit.freebsd.org/ports/commit/?id=4fe2fada927d063c57cf7006de4f0dfacb8913aa) to version 3.2.0 and became its maintainer. Keeping build metadata, dependencies and packaging correct is the sort of quiet maintenance an operating system ecosystem needs!

The certification does not make FreeBSD, NetBSD and OpenBSD interchangeable. It confirms a useful, independent administrative baseline across all three and gives this part of my career a tidy marker. For anyone preparing for the same exam, I published the [one-page BSD Specialist cheat sheet](/2026/08/27/preparing-for-bsd-specialist-with-a-one-page-cheat-sheet.html) that I used for my final review.
