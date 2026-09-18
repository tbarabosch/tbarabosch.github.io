---
title: 'Building a tiny macOS EDR, part 1: exploring Endpoint Security with eslogger'
date: '2026-09-18T12:00:00+02:00'
last_modified_at: '2026-09-18T12:00:00+02:00'
author: tbarabosch
layout: post
toc: true
image:
  path: /assets/images/posts/building-a-tiny-macos-edr-part-1/social-card.png
  width: 1200
  height: 630
social_card:
  layout: text
  title: 'Tiny macOS EDR, part 1'
  subtitle: 'Explore Endpoint Security events with the logger Apple already ships.'
  eyebrow: 'Systems Security / macOS'
  panel_label: 'ESLOGGER'
  text: 'No system extension required: eslogger writes Endpoint Security notifications as JSON Lines.'
tags:
  - systems security
  - security operations
  - macOS
  - Endpoint Security
  - Python
---

While reading Matt Hand's [*Evading EDR*](https://nostarch.com/evading-edr), I kept translating its Windows examples to macOS. The book explains where endpoint events come from, how detections consume them and how attackers try to evade that visibility. What would the corresponding sensor look like on a Mac? Which events would I collect? How would I connect a detection to a response?

One of my favorite ways to answer questions like these is to build a tiny version of the system. My small [Yet Another Imperative Programming Language (`yaipl`)](https://github.com/tbarabosch/yaipl), for example, still forced me to think about tokens, parsing, an intermediate representation and code generation. It will not replace Clang, nor is that the point. After implementing the small version, the architecture of the real one is much easier to appreciate. Rather than only taking notes on the book, I wanted to do the same for EDR.

The result is a tiny EDR proof of concept: one sensor, a JSONL log, three simple rules and one response action. It is not an attempt to reproduce a production EDR product. The goal is to isolate a few core mechanisms so that I can inspect every event and every decision. No service, no external rule language and no third-party Python packages.

On macOS, the natural sensor is the Endpoint Security framework. Direct clients need a restricted entitlement, but Apple already ships an entitled exploration tool called `eslogger`. This first post looks at Endpoint Security, what `eslogger` provides and why the tool is useful for debugging and malware analysis as well. Part 2 will contain the complete one-file Python PoC.

<!--more-->

<nav class="post-toc" aria-labelledby="contents-heading" markdown="1">
<p id="contents-heading" class="manual-label">CONTENTS</p>

* TOC
{:toc}
</nav>

## Which parts should the PoC model?

Production EDR products combine endpoint sensors with telemetry processing, detection content, response controls, fleet operations and backend services. Recreating that system in one Python file would neither be realistic nor particularly useful. For this experiment, I chose five parts of the endpoint data flow:

1. A **sensor** observes processes, files or other system activity.
2. **Telemetry** describes what happened and which process caused it.
3. A **detector** decides whether an event looks interesting.
4. **Evidence storage** keeps the original event and the alert.
5. A **response** performs an action after a matching detection.

This is a learning model, not a description of everything a commercial EDR does. Real products add much richer event models, process ancestry, code-signing context, correlation, cloud analytics, policy, deployment and safeguards around response actions.

The first PoC rule alerts when a program executes from `/private/tmp`. I chose it because the behavior is easy to reproduce and the resulting event has a clear target process. Its purpose is to carry one event through the complete example, not to represent production detection content. Adding `SIGKILL` then lets us study which checks a response path needs before acting.

```text
system activity
      |
      v
   [sensor] -> telemetry -> [detection] -> alert
                                 |           |
                                 v           v
                              evidence    response
```

Hand's book discusses Windows facilities such as process callbacks, filesystem minifilters, ETW and scanners. macOS has different plumbing, but the questions stay the same. First, get useful events. Then store them, run detections and decide what evidence a response action should require.

## Endpoint Security on macOS

Apple's [Endpoint Security framework](https://developer.apple.com/documentation/EndpointSecurity) is a C API for monitoring security-relevant activity. A client subscribes to event types and receives messages about executions, forks, signals, mounts, file operations and many other actions. Newer macOS versions have added events for logins, launch items, Gatekeeper and XProtect as well.

There are two event families worth remembering. An `AUTH` event arrives before an operation and asks the client for a decision. A `NOTIFY` event arrives after the operation. Apple's [`es_message_t` documentation](https://developer.apple.com/documentation/endpointsecurity/es_message_t) describes both. If you want to deny an execution before the first instruction runs, you need `AUTH_EXEC`. If you receive `NOTIFY_EXEC` and kill the process afterwards, you are reacting. That difference will become rather important in part 2.

The API is not available to every program. Direct clients need the restricted [`com.apple.developer.endpoint-security.client` entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.endpoint-security.client). A production Endpoint Security client normally lives in a system extension bundled with an application. System extensions run in user space and replaced many jobs that previously required third-party kernel extensions; Apple's [deployment documentation](https://support.apple.com/guide/deployment/system-extensions-in-macos-depa5fb8376f/web) explains how they are approved and managed.

The entitlement and system-extension model is appropriate for software with system-wide visibility and response capabilities. For this 303-line learning project, I needed a way to study notification events without distributing a system extension. `ctypes` can load a C library, but it cannot obtain an Apple entitlement on my behalf. Direct access to Endpoint Security was therefore outside the scope of this experiment.

## Apple already ships an exploration tool

Apple added `/usr/bin/eslogger` in macOS Ventura and demonstrated it in the [WWDC22 Endpoint Security session](https://developer.apple.com/videos/play/wwdc2022/110345/). It is an Apple-signed and entitled Endpoint Security client. Give it one or more event names and it writes one JSON object per line:

```console
$ /usr/bin/eslogger --list-events
access
authentication
authorization_judgement
...
exec
exit
fork
...
```

Listing the event names needs no special privilege. Collecting events does. `eslogger(1)` requires root and Full Disk Access for the program that starts it. If you run it from Terminal, grant Terminal Full Disk Access, quit it completely, reopen it and then use `sudo`. Otherwise, you may spend some quality time wondering why the command that needs to see the system cannot see the system.

A narrow process-lifecycle capture takes one command:

```bash
sudo /usr/bin/eslogger exec fork exit > process-events.jsonl
```

JSON Lines is a convenient format here. Python can read one event at a time without loading the complete capture into memory, and tools such as `jq` can inspect the same file. The event-specific objects resemble their Endpoint Security counterparts. For example, an `exec` event contains the target process, arguments and environment values documented for [`es_event_exec_t`](https://developer.apple.com/documentation/endpointsecurity/es_event_exec_t).

Before building anything on top of that output, read the warning in the manual page: the JSON format is not an API and may change without warning. `eslogger` also exposes notification events, not authorization events. It is a tool for exploration and prototyping, which is exactly how Apple presents it in the WWDC session. It is not a shortcut for shipping an Endpoint Security product in Python.

## eslogger is useful beyond this PoC

Even if the EDR idea ends here, `eslogger` deserves a place in the debugging toolbox.

Suppose a command unexpectedly starts another process, creates a helper and renames a configuration file. A short capture can show the relevant process and file events without adding instrumentation to the program. The `--select` option narrows events to a program-path prefix:

```bash
sudo /usr/bin/eslogger --select /bin/zsh exec create rename
```

This helps when debugging installers, launch agents, shell scripts and system utilities. It can also show what changed between two versions of an application. Start a narrow capture, reproduce the behavior and compare the results. No debugger injection and no modifications to the program are required.

For malware analysis, the same approach works inside an isolated and disposable analysis system. `eslogger` can record the processes, files and launch items created by a sample. Running the logger does not provide containment, so the usual laboratory isolation still applies.

It is also handy for detection development. Capture a benign reproducer once, sanitize the JSONL file and replay it while working on a rule. This is much nicer than launching the same command every time an index into a nested dictionary is wrong.

Do not subscribe to every event just because the option exists. Events such as `open`, `write`, `stat` and directory lookups arrive in impressive quantities. Collecting all of them with a small synchronous Python script mostly demonstrates that computers are busy. Use `--select` and a short event list whenever possible.

## Seven events are enough for now

For the PoC, I settled on seven event types:

| Event | Reason for keeping it |
| --- | --- |
| `exec` | Supplies the new executable, arguments and target PID. |
| `fork` | Preserves basic process-lifecycle context for later work. |
| `exit` | Marks the other end of a process lifetime. |
| `create` | Exposes new filesystem objects, including launch-item paths. |
| `rename` | Catches files moved into an interesting destination. |
| `unlink` | Records removal without subscribing to every write. |
| `btm_launch_item_add` | Reports a Background Task Management launch-item addition. |

Only three events or event combinations produce alerts: execution from a temporary directory, inline code passed to a shell or interpreter and launch-item persistence. `fork`, `exit` and `unlink` are simply recorded. An event can be useful during an investigation without being suspicious by itself.

The log is sensitive. Command arguments can contain passwords or tokens, and environment variables are even worse. The PoC needs arguments for the inline-interpreter rule, so it keeps them. It removes the environment array from `exec` events and creates the log with mode `0600`. That reduces the problem; it does not magically turn endpoint telemetry into harmless data.

## The plan for the PoC

With the sensor question answered, the program can stay pleasantly small:

```text
Endpoint Security
       |
       v
  /usr/bin/eslogger        entitled, root, Full Disk Access
       |
       | JSON Lines on stdout
       v
   mini_edr.py             parse -> redact -> append evidence
       |
       +-----------------> three Python predicates -> alerts
                                                   |
                                                   v
                                           optional SIGKILL
```

The Python script starts `eslogger`, reads its standard output, removes environment variables and appends each event to a JSONL file. Afterwards, three plain Python functions inspect the event. One of them may send `SIGKILL`, but only when enforcement is explicitly enabled.

Both processes remain in the same process group. `eslogger` suppresses events from that group, which prevents the script's own log writes from feeding back into the capture. Without that behavior, the world's smallest EDR could become the world's least interesting perpetual-motion machine.

The complete implementation is available as [`mini_edr.py` at commit `9ef9883`](https://github.com/tbarabosch/macos-re/blob/9ef9883b5616328baab5a161da33cc958a537ad4/mini_edr/mini_edr.py). This version deliberately focuses on notification events and local experimentation. A production endpoint agent adds authorization decisions, tamper resistance, load management, schema compatibility and deployment controls. Keeping that distinction explicit lets the PoC remain small while showing why those additional components matter. Part 2 will build and test it.
