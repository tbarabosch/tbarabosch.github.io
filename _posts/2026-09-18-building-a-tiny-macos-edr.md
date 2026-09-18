---
title: 'Building a tiny macOS EDR with eslogger and Python'
date: '2026-09-18T12:00:00+02:00'
last_modified_at: '2026-09-18T12:00:00+02:00'
author: tbarabosch
layout: post
toc: true
image:
  path: /assets/images/posts/building-a-tiny-macos-edr/social-card.png
  width: 1200
  height: 630
social_card:
  layout: text
  title: 'Tiny macOS EDR'
  subtitle: 'From eslogger events to a one-file Python proof of concept.'
  eyebrow: 'Systems Security / macOS'
  panel_label: 'ESLOGGER → PYTHON'
  text: 'Seven events, three rules, JSONL evidence, and one guarded response.'
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

On macOS, the natural sensor is Apple's [Endpoint Security framework](https://developer.apple.com/documentation/endpointsecurity). Direct clients need a restricted entitlement, but Apple already ships an entitled exploration tool called [`eslogger`](https://developer.apple.com/videos/play/wwdc2022/110345/). This post first looks at Endpoint Security, what `eslogger` provides and why the tool is useful for debugging and malware analysis. Then we use its events to build the complete one-file Python PoC.

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

Apple's [Endpoint Security framework](https://developer.apple.com/documentation/endpointsecurity) is a C API for monitoring security-relevant activity. A client subscribes to specific [`es_event_type_t` values](https://developer.apple.com/documentation/endpointsecurity/es_event_type_t) and receives messages about executions, forks, signals, mounts, file operations and many other actions. Apple's [WWDC22 Endpoint Security session](https://developer.apple.com/videos/play/wwdc2022/110345/) documents the macOS Ventura additions for authentication, login sessions, Gatekeeper and XProtect.

There are two event families worth remembering. An `AUTH` event arrives before an operation and asks the client for a decision. A `NOTIFY` event arrives after the operation. Apple's [`es_message_t` documentation](https://developer.apple.com/documentation/endpointsecurity/es_message_t) describes both. If you want to deny an execution before the first instruction runs, you need [`AUTH_EXEC`](https://developer.apple.com/documentation/endpointsecurity/es_event_type_auth_exec). If you receive `NOTIFY_EXEC` and kill the process afterwards, you are reacting. That distinction matters when we add the response action below.

The API is not available to every program. Direct clients need the restricted [`com.apple.developer.endpoint-security.client` entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.endpoint-security.client). A production Endpoint Security client normally lives in a system extension bundled with an application. Apple's [System Extensions and DriverKit overview](https://developer.apple.com/system-extensions/) explains the user-space model, while the [installation documentation](https://developer.apple.com/documentation/systemextensions/installing-system-extensions-and-drivers/) covers bundling, activation and entitlement checks.

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

Listing the event names needs no special privilege. Collecting events does. Apple states that [`eslogger` must run as superuser and that its responsible process needs Full Disk Access](https://developer.apple.com/videos/play/wwdc2022/110345/). If you run it from Terminal, grant Terminal Full Disk Access, quit it completely, reopen it and then use `sudo`. Otherwise, you may spend some quality time wondering why the command that needs to see the system cannot see the system.

A narrow process-lifecycle capture takes one command:

```bash
sudo /usr/bin/eslogger exec fork exit > process-events.jsonl
```

[JSON Lines](https://jsonlines.org/) is a convenient format here. Python can read one event at a time without loading the complete capture into memory, and tools such as [`jq`](https://jqlang.org/) can inspect the same file. Apple says that [`eslogger` structures its JSON like the native C representation](https://developer.apple.com/videos/play/wwdc2022/110345/). For example, an `exec` event contains the target process, arguments and environment values documented for [`es_event_exec_t`](https://developer.apple.com/documentation/endpointsecurity/es_event_exec_t).

Before building anything on top of that output, read Apple's warning: [`eslogger` is not intended for use by applications and its output may change in software updates](https://developer.apple.com/videos/play/wwdc2022/110345/). It also exposes notification events, not authorization events. Apple presents it as an exploration and prototyping tool, not as an application API or a replacement for a native Endpoint Security client.

## eslogger is useful beyond this PoC

Even if the EDR idea ends here, `eslogger` deserves a place in the debugging toolbox.

Suppose a command unexpectedly starts another process, creates a helper and renames a configuration file. A short capture can show the relevant process and file events without adding instrumentation to the program. The `--select` option narrows events to a program-path prefix:

```bash
sudo /usr/bin/eslogger --select /bin/zsh exec create rename
```

This helps when debugging installers, launch agents, shell scripts and system utilities. It can also show what changed between two versions of an application. Start a narrow capture, reproduce the behavior and compare the results. No debugger injection and no modifications to the program are required.

For malware analysis, the same approach works inside an isolated and disposable analysis system. `eslogger` can record the processes, files and launch items created by a sample. Apple explicitly calls out [observing malicious software behavior and prototyping detections](https://developer.apple.com/videos/play/wwdc2022/110345/) as uses for the tool. Running the logger does not provide containment, so the usual laboratory isolation still applies.

It is also handy for detection development. Capture a benign reproducer once, sanitize the JSONL file and replay it while working on a rule. This is much nicer than launching the same command every time an index into a nested dictionary is wrong.

Do not subscribe to every event just because the option exists. Events such as `open`, `write`, `stat` and directory lookups arrive in impressive quantities. Collecting all of them with a small synchronous Python script mostly demonstrates that computers are busy. Use `--select` and a short event list whenever possible.

## Seven events are enough for now

For the PoC, I settled on seven event types:

| Event | Reason for keeping it |
| --- | --- |
| [`exec`](https://developer.apple.com/documentation/endpointsecurity/es_event_exec_t) | Supplies the new executable, arguments and target PID. |
| [`fork`](https://developer.apple.com/documentation/endpointsecurity/es_event_fork_t) | Preserves basic process-lifecycle context for later work. |
| [`exit`](https://developer.apple.com/documentation/endpointsecurity/es_event_exit_t) | Marks the other end of a process lifetime. |
| [`create`](https://developer.apple.com/documentation/endpointsecurity/es_event_create_t) | Exposes new filesystem objects, including launch-item paths. |
| [`rename`](https://developer.apple.com/documentation/endpointsecurity/es_event_rename_t) | Catches files moved into an interesting destination. |
| [`unlink`](https://developer.apple.com/documentation/endpointsecurity/es_event_unlink_t) | Records removal without subscribing to every write. |
| [`btm_launch_item_add`](https://developer.apple.com/documentation/endpointsecurity/es_event_btm_launch_item_add_t) | Reports a Background Task Management launch-item addition. |

Only three events or event combinations produce alerts: execution from a temporary directory, inline code passed to a shell or interpreter and launch-item persistence. `fork`, `exit` and `unlink` are simply recorded. An event can be useful during an investigation without being suspicious by itself.

The log is sensitive. Command arguments can contain passwords or tokens, and environment variables are even worse. The PoC needs arguments for the inline-interpreter rule, so it keeps them. It removes the environment array from `exec` events and creates the log with mode `0600`. That reduces the problem; it does not magically turn endpoint telemetry into harmless data.

## From eslogger to one Python file

With the sensor question answered, the rest of the path can remain small:

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

The result is [`mini_edr.py`](https://github.com/tbarabosch/macos-re/blob/9ef9883b5616328baab5a161da33cc958a537ad4/mini_edr/mini_edr.py): exactly 303 physical lines of Python at commit `9ef9883`. It starts `eslogger`, reads JSON Lines, removes environment variables, writes the evidence, runs three rules and can kill a process after checking its PID and path. Everything lives in one file and uses the Python 3.11 standard library. There is no package to install and no configuration format to learn.

The first version squeezed all of this into 180 lines. The number looked nice; some of the code did not. I expanded the imports, added a docstring to every function and split argument parsing, event processing, alert emission and process cleanup into separate helpers. No function is longer than 20 physical lines. The program is still small, but a reader no longer has to decode a 39-line `main()` to understand its lifecycle.

The three rules are teaching examples, not an attempt to reproduce production detection content. Their job is to make the path from event to alert, and from alert to response, easy to follow. A commercial EDR combines substantially richer endpoint context, correlation, policy and operational safeguards.

## Start eslogger ourselves

The Python script is not an Endpoint Security client. It starts the entitled client that Apple already put in `/usr/bin`:

```python
ESLOGGER = "/usr/bin/eslogger"
EVENTS = ("exec", "fork", "exit", "create", "rename", "unlink", "btm_launch_item_add")

def check_live_requirements():
    """Reject unsupported macOS versions and unprivileged live runs."""
    version = platform.mac_ver()[0]
    if platform.system() != "Darwin" or not version or int(version.split(".")[0]) < 13:
        raise RuntimeError("live collection requires macOS 13 or newer")
    if os.geteuid() != 0:
        raise RuntimeError("live collection must run as root")

def live_stream():
    """Start eslogger and return its child process and stdout stream."""
    check_live_requirements()
    child = subprocess.Popen(
        [ESLOGGER, *EVENTS],
        stdout=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
    )
    return child, child.stdout
```

Python's [`subprocess.Popen`](https://docs.python.org/3.11/library/subprocess.html#subprocess.Popen) leaves `eslogger` in the current process group because the script does not request a new session or process group. The local `eslogger(1)` manual documents that the tool suppresses events generated by processes in its own process group. The Python process can therefore write the evidence file without collecting its own writes and creating a feedback loop.

I leave standard error attached to the terminal. If `eslogger` complains about Full Disk Access or exits for another reason, the message should be visible instead of disappearing into a pipe. The main loop reads one line at a time. Malformed JSON is reported and skipped, but a failed log write stops the program. The evidence and alert stream should remain consistent.

`SIGINT` and `SIGTERM` terminate the child. If it does not exit within two seconds, the script kills it. That small amount of process supervision is enough for an interactive lab tool and avoids leaving an `eslogger` process behind after pressing Ctrl-C.

Live mode requires the exact Python interpreter to run as root:

```bash
sudo "$(command -v python3)" mini_edr.py
```

The terminal that launches the script still needs Full Disk Access. The program neither changes TCC settings nor installs itself as a service. It is a script, and it behaves like one.

## Log first, detect second

Every parsed event is written before its rules run. The log contains two record shapes:

```json
{"kind":"event","received_at":"2026-09-18T10:00:00+00:00","event":{"schema_version":1}}
{"kind":"alert","received_at":"2026-09-18T10:00:00+00:00","rule":"exec-from-temporary-directory","severity":"high","pid":4242,"path":"/private/tmp/mini-edr-demo","response":"disabled"}
```

The event record keeps the original `eslogger` object, including its version fields. I saw little value in inventing another unstable schema on top of Apple's unstable schema. Alerts are smaller and contain the rule, severity, PID, executable path and response result.

There is one exception before an event reaches the file:

```python
def redact_environment(message):
    """Remove execution environment variables before persistence."""
    exec_data = dig(message, "event", "exec")
    if isinstance(exec_data, dict):
        exec_data.pop("env", None)
```

Apple's [`es_event_exec_t`](https://developer.apple.com/documentation/endpointsecurity/es_event_exec_t) includes arguments and environment variables. Environment values are unnecessary for these rules and frequently contain credentials, so they are removed. Arguments stay because the inline-interpreter rule needs `-c` and `-e`. They can also contain secrets, which means the resulting log is still sensitive.

The file is opened with append mode, [`O_NOFOLLOW`](https://docs.python.org/3.11/library/os.html#os.O_NOFOLLOW) where available and permission mode `0600`. There is no rotation. “Delete the lab log when finished” is the entire retention policy.

Offline replay uses the same processing path without root:

```bash
python3 mini_edr.py --input capture.jsonl --log replay.jsonl
```

Replay refuses `--enforce`. PIDs from an old capture may now belong to completely unrelated processes. Response actions only make sense for the live event stream that supplied the PID.

## Three functions for three teaching rules

For three detections, a rule language would be mostly ceremony. The PoC uses normal Python functions and a small table:

```python
RULES = (
    ("exec-from-temporary-directory", "high", temporary_exec, "kill", "target"),
    ("inline-interpreter-execution", "medium", inline_interpreter, "alert", "target"),
    ("launch-item-persistence", "high", launch_item, "alert", "source"),
)
```

Each row specifies a name, severity, predicate, action and whether the alert refers to the source or target process. Every predicate sees the same small event view. There is no precedence, correlation or state machine hiding behind the table.

### Execution from a temporary directory

The first rule checks the target executable path of an `exec` event:

```python
def temporary_exec(event):
    """Match execution from a common temporary directory."""
    return event["name"] == "exec" and event["target_path"].startswith(TEMP_DIRS)
```

`TEMP_DIRS` contains `/private/tmp/`, `/tmp/` and `/var/tmp/`. Execution from a temporary directory is easy to reproduce and sometimes suspicious. It is certainly not proof of malware. Installers, update systems, developers and test harnesses do this as well. I still chose it for the response demonstration because the `exec` event gives us a clear target PID and executable path to verify.

### Inline interpreter code

The second rule recognizes `sh`, `bash`, `zsh`, `osascript`, `perl`, `ruby` and Python basenames, then searches their arguments for an exact `-c` or `-e`. For example, it catches `/bin/zsh -c 'sleep 1'`.

This rule also catches a tremendous amount of legitimate automation. Shell scripts, build systems and application helpers use inline code all the time. Consequently, it produces a medium-severity alert and never kills anything. For this broad teaching rule, alert-only is the appropriate response.

### Launch-item persistence

The third rule matches `btm_launch_item_add` directly. It also searches paths from `create` and `rename` events for `/Library/LaunchAgents` or `/Library/LaunchDaemons`. File events do not put every path at the same place in the JSON object, so a short recursive function collects all fields named `path`.

This rule remains alert-only. The process reported for a Background Task Management event may be an intermediary, and a process that creates a plist is not necessarily the process that later loads it. The available attribution is not strong enough for an automatic response.

## Guarding the SIGKILL response

`--enforce` changes only the temporary-execution rule. Before sending a signal, the script rejects PID 0, PID 1, itself, its parent and the `eslogger` child. It then asks macOS which executable currently owns the PID:

```python
def process_path(pid):
    """Ask macOS for the executable path currently associated with a PID."""
    library = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
    function = library.proc_pidpath
    function.argtypes = (ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32)
    function.restype = ctypes.c_int
    buffer = ctypes.create_string_buffer(4096)
    if function(pid, buffer, len(buffer)) <= 0:
        return ""
    return buffer.value.decode("utf-8", "replace")
```

[`ctypes`](https://docs.python.org/3.11/library/ctypes.html) is part of the standard library and `libproc` ships with macOS. Apple publishes the [`proc_pidpath` declaration in XNU's `libproc.h`](https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/libsyscall/wrappers/libproc/libproc.h#L102), where the surrounding header also labels these process-information interfaces private and subject to change. The path returned by `proc_pidpath` must match the path from the event after resolving symlinks. Only then does the script call [`os.kill(pid, signal.SIGKILL)`](https://docs.python.org/3.11/library/os.html#os.kill).

Even this check is not perfect. The process can exit between `proc_pidpath` and `os.kill`, and the PID can theoretically be reused. Therefore, the alert says `signal-sent`, not `process-killed`. The script knows that the system call succeeded; it does not wait for proof that the process died.

Also remember that `eslogger` gave us a notification. The program has already started by the time Python sees it. This PoC demonstrates post-execution response; an entitled native Endpoint Security client could instead use [`AUTH_EXEC`](https://developer.apple.com/documentation/endpointsecurity/es_event_type_auth_exec) for a pre-execution decision.

## So, does it work?

I compile-checked the program with Python 3.14.6 on macOS 26.6.2 and compared its imports with Python's standard-library module set. No third-party module sneaked in. A synthetic capture then exercised the three rules, malformed input and environment removal. Synthetic data is useful for repeatable tests, but it is not Endpoint Security telemetry.

The more interesting test was live. I started the collector without `--enforce` and ran the three harmless demonstrations below. The log contained 398 events: 62 `exec`, 80 `fork`, 93 `exit`, 82 `create`, 49 `rename` and 32 `unlink` records. The three commands produced the following sanitized alerts; I replaced the PIDs and random directory suffix:

```text
ALERT high exec-from-temporary-directory pid=<pid> path=/private/tmp/mini-edr-demo.<random>/sleep response=disabled
ALERT medium inline-interpreter-execution pid=<pid> path=/bin/zsh response=not-configured
ALERT high launch-item-persistence pid=<pid> path=/usr/bin/touch response=not-configured
```

The shell wrapper used to start the collector produced a fourth inline-interpreter alert. The detector had managed to alert on part of its own launch command. That was a useful and immediate demonstration of why this deliberately broad rule is alert-only. All 62 stored `exec` events had their `env` member removed, and the log kept mode `0600`.

I tested the response function separately with a copy of `/bin/sleep` below a new `/private/tmp` directory. It refused PID 1, the Python process, its parent, the `eslogger` child and a PID with the wrong executable path. With the real PID and path it returned `signal-sent`; waiting for the child produced exit status 137. Afterwards, I removed the test directory.

For a manual end-to-end check, start the monitor in one terminal and run this benign executable in another:

```bash
demo_dir="$(mktemp -d /private/tmp/mini-edr-demo.XXXXXX)"
cp /bin/sleep "$demo_dir/sleep"
"$demo_dir/sleep" 10
rm -f "$demo_dir/sleep"
rmdir "$demo_dir"
```

Run the monitor without `--enforce` first. The other two rules can be exercised without loading a launch item:

```bash
/bin/zsh -c 'sleep 1'

demo_plist="$HOME/Library/LaunchAgents/com.example.mini-edr-demo.plist"
touch "$demo_plist"
rm -f "$demo_plist"
```

These are test cases, not malware simulations. The plist is empty and never passed to `launchctl`.

## From a PoC to a production design

The complete [`mini_edr` directory at commit `9ef9883`](https://github.com/tbarabosch/macos-re/tree/9ef9883b5616328baab5a161da33cc958a537ad4/mini_edr) is small enough to read in one sitting. The PoC deliberately leaves out schema compatibility, dropped-event accounting, process trees, correlation, databases, log rotation, service installation, network telemetry, signing, notarization, quarantine, tamper protection and remote collection. Those are capabilities a production endpoint agent needs, and implementing them would be a different project.

The next technical step would be a native Swift [system extension](https://developer.apple.com/system-extensions/), subject to receiving the [Endpoint Security entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.endpoint-security.client). Typed Endpoint Security messages would replace the JSON parsing, and `AUTH` events could make pre-execution decisions possible. The client would also need asynchronous processing, load testing, event muting and bounded storage. At that point, 303 lines would be a distant memory.

[YARA](https://yara.readthedocs.io/en/stable/) scanning would be a useful optional addition for files that triggered a rule. I would also like to revisit my old [`classify_macho.py`](https://github.com/tbarabosch/macos-re/blob/main/malware_toys/classify_macho.py) experiment. It compared several classifiers using only file size, section count and Mach-O header flags. The script has Python 2-era APIs, and the original dataset and evaluation are not good enough for a modern experiment. Even after fixing that, an ML score should provide another hint to an analyst. It should not decide whether a process deserves `SIGKILL`.

Network telemetry, process trees, code-signing information, quarantine, host isolation and fleet collection are obvious next steps as well. They would turn this small teaching implementation into a much larger project. For now, the 303-line version is enough to show where an event comes from, how a rule interprets it and why a response needs strong identity and policy checks.
