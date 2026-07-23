---
title: 'Persistence on FreeBSD with BeastieSentry'
date: '2026-07-21T12:00:00+02:00'
author: tbarabosch
layout: post
tags:
  - incident response
  - systems security
  - FreeBSD
---

Persistence is often associated with exotic rootkits, patched kernels and stealthy implants. Those techniques exist, but an attacker who already controls a FreeBSD host may not need any of them. The operating system already contains reliable ways to start code during boot, run it on a schedule, load it into privileged processes or provide access later. Most of these mechanisms are also used every day by administrators.

This overlap is what makes persistence analysis difficult. An SSH key in `authorized_keys` is persistent access, but usually not malicious. A local rc service may be an approved monitoring agent or an implant. The interesting question is not merely whether an artifact exists. I want to know how it becomes active, which user it runs as, whether its path can be trusted and whether it still matches the expected FreeBSD release.

I built [BeastieSentry](https://github.com/tbarabosch/BeastieSentry) to learn this part of FreeBSD properly and to turn that map into a read-only incident-response tool.

<!--more-->

## What persistence means here

For this post, persistence is a configured path to future execution or reusable access. It may trigger at boot, during authentication, on a timer, or when somebody starts a login shell. A stopped program with a valid `@reboot` cron entry is still persistent; a process that survives my logout but disappears at the next reboot may not be.

FreeBSD does not put all of these paths into one database. They are distributed across boot configuration, service scripts, scheduling facilities, account data, authentication policy and runtime linker configuration. The current public version of BeastieSentry divides that surface into eleven modules:

| Area | BeastieSentry modules | Main question |
| --- | --- | --- |
| Boot and kernel | `rc`, `loader` | What will start before or during multi-user boot? |
| Scheduled execution | `cron`, `at`, `periodic` | What is retained for recurring or deferred execution? |
| Identity and sessions | `accounts`, `ssh`, `profiles`, `pam` | Who can return, and what runs when they authenticate or log in? |
| Init and library loading | `ttys`, `libmap` | What can `init` start, or the runtime linker substitute? |

This is a map of configured persistence, not a claim that every possible FreeBSD compromise fits into eleven boxes.

## Boot and kernel persistence

The normal FreeBSD startup path is the first obvious place to look. [`rc.conf(5)`](https://man.freebsd.org/cgi/man.cgi?query=rc.conf&sektion=5) controls base and local services, while [`rc(8)`](https://man.freebsd.org/cgi/man.cgi?query=rc&sektion=8) processes the rc.d dependency graph. Relevant inputs include `/etc/rc.conf`, `/etc/rc.conf.local`, service-specific `rc.conf.d` files, `/etc/rc.d`, `/usr/local/etc/rc.d` and local boot or shutdown hooks. A script can be entirely legitimate and still deserve review if it is non-stock, unexpectedly enabled or reached through a redirected `local_startup` path.

The `loader` surface executes even earlier. [`loader.conf(5)`](https://man.freebsd.org/cgi/man.cgi?query=loader.conf&sektion=5) can load kernel modules through `*_load` settings, alter `module_path` and pull in additional configuration. Local loader or menu scripts can also change the boot path. A configured object may run with kernel privilege before ordinary userland inspection begins, so its resolved path, ownership, permissions and release identity all matter.

## Scheduled and deferred execution

[`crontab(5)`](https://man.freebsd.org/cgi/man.cgi?query=crontab&sektion=5) provides both recurring jobs and the especially direct `@reboot` form. FreeBSD has a system crontab, cron.d directories and per-user tables below `/var/cron/tabs`. An investigation has to retain the user associated with each entry, apply the configured `PATH` carefully and resolve the first command token without executing the command.

[`at(1)`](https://man.freebsd.org/cgi/man.cgi?query=at&sektion=1) retains a job for later execution. It may run only once, but it survives the current shell and waits in `/var/at/jobs`. The body can contain commands and a saved environment, so its owner, metadata and a content digest are safer report evidence than the raw content.

FreeBSD also has [`periodic(8)`](https://man.freebsd.org/cgi/man.cgi?query=periodic&sektion=8). The daily, weekly, monthly and security runs dispatch scripts from the base and local periodic trees. An executable file in `/usr/local/etc/periodic/daily`, for example, obtains scheduled execution through an existing stock cron entry. Looking only for new crontab lines would miss that relationship.

## Identities, remote access and session hooks

Accounts are part of the persistence surface because an additional UID 0 identity or a changed service account can preserve unrestricted access. BeastieSentry parses the [`passwd(5)`](https://man.freebsd.org/cgi/man.cgi?query=passwd&sektion=5) view in `/etc/passwd`, looking for unexpected UID 0 records, duplicate identities, and low-numbered accounts with changed homes or login-capable shells. It deliberately does not collect password hashes or enumerate remote directory-service accounts.

SSH contains several independent hooks. [`sshd_config(5)`](https://man.freebsd.org/cgi/man.cgi?query=sshd_config&sektion=5) controls authorized-key and authorized-user paths, helper commands, `ForceCommand`, subsystems, user rc files and optional environment files. A public key is reusable access and should therefore appear in a persistence inventory even when it belongs to the administrator. The useful evidence is the account, path, key type and fingerprint, not the raw key blob or its comment. `AuthorizedKeysCommand` and similar helpers require even more attention because they extend the authentication trust boundary to another executable.

Login profiles are less privileged but very dependable. `/etc/profile`, `/etc/csh.cshrc`, `/etc/csh.login` and per-account files such as `.profile`, `.shrc`, `.login` and `.tcshrc` can execute in the account's context when the corresponding shell starts. Applicability matters: a csh profile for an account using `/bin/sh` may be dormant, while a writable profile in a shared home directory may be a broken trust relationship.

PAM policy is another execution boundary. [`pam.conf(5)`](https://man.freebsd.org/cgi/man.cgi?query=pam.conf&sektion=5) and the policy stacks below `/etc/pam.d` and `/usr/local/etc/pam.d` decide which modules participate in authentication, account, password and session processing. A changed stack may be legitimate local policy, but `pam_exec` or a module loaded from a non-base path can introduce direct command or code execution whenever the affected service authenticates a user.

## Init and runtime linker hooks

The [`ttys(5)`](https://man.freebsd.org/cgi/man.cgi?query=ttys&sektion=5) database tells `init` which terminal entries to enable. Besides the familiar login command, an entry may carry a window-system command. An enabled non-stock command can therefore be a persistent execution path even if no rc script or cron entry points to it.

Finally, [`libmap.conf(5)`](https://man.freebsd.org/cgi/man.cgi?query=libmap.conf&sektion=5) can substitute one shared library for another globally or for a selected program or directory tree. This is useful for compatibility, but it can also redirect the code loaded by a base utility without modifying that utility. Mappings involving base programs, `libc.so.7` or `libthr.so.3` deserve particularly careful review.

There are still other investigative questions. Replaced base binaries, a live kernel rootkit, modified boot code, firmware, application-specific plugins and remote identity providers are outside this eleven-module model. Process, socket and network-interface inspection also belongs to a live-response workflow, but not to BeastieSentry's configured-persistence scan.

## Why I built BeastieSentry

Manually following these paths is an excellent way to learn FreeBSD, but it is easy to miss a configuration layer or forget which user owns a cron entry. BeastieSentry encodes the inspection order and trust questions while leaving the final judgment with the analyst. Its [module documentation](https://github.com/tbarabosch/BeastieSentry/blob/main/Modules.md) describes every input and classification rule.

The first release deliberately targets only FreeBSD 15.1-RELEASE on arm64. It contains a reviewed baseline generated from the matching `base.txz` and `kernel.txz` release archives. A baseline match includes the path, file type, SHA-256 digest, owner, group and mode; runtime files cannot extend the allow-list. Scans require effective UID 0 (aka root) and must run outside a jail because the tool inspects the live `/` hierarchy.

The scanner treats configuration as data. It does not source a file, invoke a shell, load a kernel object, execute a discovered target, call a package manager or use the network. Files are read through an already-open root descriptor with bounded, descriptor-relative operations and without transparently following symbolic links. Raw commands, environment values, password hashes, key blobs and arbitrary arguments are not retained in the final finding model.

Each finding has a severity:

- `known` means that the artifact passed the applicable release baseline and trust checks.
- `review` means that it is custom, changed, dormant or unresolved and needs analyst judgment.
- `high` marks direct privileged execution or a broken trust boundary.
- `error` means that a selected check could not complete reliably.

State is a separate concept. `active`, `dormant` and `unknown` describe what the supported literal configuration analysis can establish. They do not claim that a command is currently running. This separation turned out to be useful while learning: a dormant custom hook is still worth knowing about, while an active stock service is not automatically suspicious.

## A scan on FreeBSD 15.1

I exported the public repository at commit [`d3dcbaa`](https://github.com/tbarabosch/BeastieSentry/commit/d3dcbaa3aa4a219613709f54b2e1c360467a47f0), built it in a temporary directory inside an arm64 VirtualBox guest and did not install it system-wide. The guest matched the scanner's platform gate:

```console
$ uname -a
FreeBSD freebsd 15.1-RELEASE FreeBSD 15.1-RELEASE releng/15.1-n283562-96841ea08dcf GENERIC arm64
$ freebsd-version -ku
15.1-RELEASE
15.1-RELEASE
$ sysctl -n kern.osreldate
1501000
$ uname -m
arm64
$ make clean all
[compiler output omitted]
$ ./beastiesentry -V
beastiesentry 1.0.0 (schema 1; FreeBSD 15.1/arm64)
```

For a compact example, I selected the account, SSH and profile modules and used `-A` to hide known rows. The following is real output from that VM. I shortened the temporary binary path, wrapped a few lines, omitted repeated findings and replaced complete host-specific hashes and the SSH fingerprint with `<redacted>`; the classifications, states and final counts are unchanged.

```console
$ su -
Password:
# ./beastiesentry -A -m accounts -m ssh -m profiles --color=never
BeastieSentry 1.0.0 -- FreeBSD 15.1/arm64 persistence assessment
Modules: accounts ssh profiles  Known rows: suppressed

== accounts ==
[REVIEW] BS-GEN-006 Baseline content digest differs -- /etc/passwd
  (state=unknown) principal=root sha256:<redacted>
  [reviewed local-account baseline mismatch]
  Why: Safe metadata does not establish that changed persistence content is expected.
  Action: Compare the file with the reviewed FreeBSD 15.1 source or authorized local change.

== ssh ==
[REVIEW] BS-SSH-001 Authorized SSH key exists --
  /home/thomas/.ssh/authorized_keys:1 (state=active) principal=thomas
  sha256:<redacted> [key-type=ssh-ed25519 fingerprint=SHA256:<redacted>]
  Why: Authorized keys provide persistent account access.
  Action: Validate the fingerprint, account owner, and key lifecycle.

== profiles ==
[REVIEW] BS-PROFILE-002 Non-stock login profile -- /root/.profile
  (state=active) principal=root,toor sha256:<redacted>
  [uid=0 gid=0 mode=0644 profile contents redacted]
  Why: Login profiles execute shell code for applicable sessions.
  Action: Review the profile privately and validate its provenance.

[additional review findings omitted]

Summary: high=0 review=9 known=9 error=0 suppressed-known=9 complete=true
Verdict: REVIEW REQUIRED
```

`REVIEW REQUIRED` does not say that this VM is compromised. The local account legitimately changes `/etc/passwd` from the release baseline, SSH keys are how the machine is administered, and local root profiles differ from the reviewed baseline. These are nevertheless exactly the artifacts I would want to validate during an investigation. The result also shows that `-A` is only a display filter: the nine known rows remain in the summary and still contribute to the completeness decision.

For automation, BeastieSentry can emit native `libxo` JSON or XML instead of terminal text. The structured schema carries the same stable rule IDs, severity, state, evidence, rationale and remediation. Output order is deterministic, which makes reports easier to compare, but a changed report still needs a human explanation.

## Reading the result conservatively

BeastieSentry does not declare a system clean or compromised. `NO INDICATORS FOUND` means only that the selected modules completed without `high` or `review` findings. A local root attacker could modify both the host and the scanner binary, so this is not remote attestation. Legitimately patched base files may differ from the compiled release baseline, and conservative parsers may report complex shell or SSH configuration rather than pretending to reproduce all of its semantics.

That restraint is intentional. Persistence mechanisms are normal operating-system features, and a warning alone cannot tell me why an administrator configured one. The tool's job is to expose the path, preserve safe evidence and make gaps visible. My job is to compare the result with the system's purpose, change records, key inventory and trusted release material.

For me, BeastieSentry has already succeeded as a learning project. Writing a separate parser for rc services, loader modules, cron tables, SSH policy, PAM stacks and library mappings forced me to understand how those pieces actually reach execution. Turning that knowledge into a repeatable read-only scan makes it useful after the lesson as well.
