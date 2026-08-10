---
title: 'Giving Every macOS App a Security Passport'
date: '2026-08-10T12:00:00+02:00'
author: tbarabosch
layout: post
tags:
  - AI tooling
  - macOS
  - systems security
---

macOS applications carry quite a lot of useful security metadata. The code signature identifies the signer, entitlements describe requested capabilities, and the App Sandbox entitlement tells me whether that containment boundary is present. `codesign` will print all of this and then leave me with a property list full of names such as `com.apple.security.cs.allow-jit`.

This is a nice job for a small local model. I do not need it to discover a vulnerability or decide whether an application is trustworthy. I need it to turn facts collected by ordinary tools into a short explanation and a few tags. Apple's [Foundation Models framework](https://developer.apple.com/documentation/FoundationModels) now makes that possible from Python, directly on my MacBook.

<!--more-->

## One of the most underrated Python SDKs

The Foundation Models framework arrived as a Swift API, which is probably why I had filed it under application development. Apple has since released an official [Foundation Models SDK for Python](https://apple.github.io/python-apple-fm-sdk/). Its [WWDC26 introduction](https://developer.apple.com/videos/play/wwdc2026/334/) presents Python mainly as a convenient environment for scripting, rapid prompt iteration and evaluation. That is also a good description of many small security tools.

The package calls Apple's on-device [`SystemLanguageModel`](https://apple.github.io/python-apple-fm-sdk/api/systemmodel.html) through the native framework. Installation is straight forward:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install apple-fm-sdk==0.2.1
```

Apple's [getting-started guide](https://apple.github.io/python-apple-fm-sdk/getting_started.html) requires a compatible Apple silicon Mac, macOS and Xcode 26 or later, Python 3.10 or later, and Apple Intelligence enabled. However, you have not to worry about: no API key, model server, provider account or per-call cloud fee. Once the system model is ready, scripts do not have to select or manage weights. The [SDK source](https://github.com/apple/python-apple-fm-sdk) is also open source.

For a security workflow, data privacy is the main attraction. An inventory of installed applications, internal paths or incident notes does not have to leave the machine merely to receive a summary. The model is small, which is fine. Summarization and tagging are small jobs and super fast.

## Turn a signed property list into a passport

Entitlements are key-value claims carried in signed code. Apple's [entitlement catalog](https://developer.apple.com/documentation/bundleresources/entitlements) covers capabilities ranging from network access and shared containers to Hardened Runtime exceptions. Its [code signing technote](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles) also explains the relationship between an entitlement claim and the provisioning profile that may authorize it.

 A sandboxed app may declare file or camera access without using it, and macOS may still require the user to approve a protected resource. Apple's [App Sandbox guide](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox) makes that second boundary explicit. A valid signature establishes identity and integrity under the applicable signing policy; it does not establish that the signed software is benign (remember: certs might be stolen...). Apple documents the signing and entitlement relationship in [Creating distribution-signed code for macOS](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/).

I used Codex to vibecode a simple [scanner](https://github.com/tbarabosch/macos-re/tree/main/app-security-passport). This scanner reads `Info.plist`, verifies the main executable and extracts its entitlements with `/usr/bin/codesign`. The extraction boundary is ordinary standard library Python:

```python
result = subprocess.run(
    ["/usr/bin/codesign", "--display", "--entitlements", "-", "--xml", executable],
    capture_output=True,
    check=False,
    timeout=20,
)
entitlements = plistlib.loads(result.stdout) if result.stdout else {}
```

The script contains a small reviewed dictionary for common security-relevant entitlements. Private or unfamiliar keys remain unknown. Application-controlled strings are sanitized before reaching the terminal, and the prompt receives only normalized descriptions from the dictionary rather than arbitrary values taken from an app.

You can pass one app, several apps or a directory whose immediate `.app` children should be processed:

```console
$ python app_security_passport.py "/System/Applications/TextEdit.app"
$ python app_security_passport.py "/Applications/Visual Studio Code.app" \
    "/Applications/WhatsApp.app"
$ python app_security_passport.py /Applications
```

Directory entries are sorted, deduplicated and handled sequentially. A broken bundle does not stop the remaining scan. The SDK exposes an explicit [model-availability check](https://apple.github.io/python-apple-fm-sdk/api/systemmodel.html#apple_fm_sdk.SystemLanguageModel.is_available); if Apple Intelligence is unavailable, the deterministic passport still prints, the model section says why it is missing and the process returns a nonzero status (e.g. because Apple Intelligence is not enabled).

## Let the model translate, not investigate

Apple's [guided-generation API](https://apple.github.io/python-apple-fm-sdk/guided_generation.html) keeps the response in a tiny typed structure:

```python
@fm.generable("A neutral explanation of signed macOS app metadata")
class PassportExplanation:
    summary: str = fm.guide("One or two sentences using only supplied facts")
    tags: list[str] = fm.guide("Tags chosen only from the allowed prompt tags")

session = fm.LanguageModelSession(model=model, instructions=INSTRUCTIONS)
result = await session.respond(prompt, generating=PassportExplanation)
```

Each app gets a fresh [`LanguageModelSession`](https://apple.github.io/python-apple-fm-sdk/api/session.html) and no tools. The script accepts only tags already established by deterministic parsing. It also rejects long summaries and anything that makes a safety, trust, malware or risk verdict.

## Three applications

I ran the scanner on macOS 26.5.1 with Xcode 26.6, Python 3.14.6 and `apple-fm-sdk` 0.2.1:

| App | Deterministic highlights | Accepted model tags |
| --- | --- | --- |
| TextEdit 1.20 | Sandboxed; user-selected files, executable file output, printing and iCloud documents | `devices`, `files` |
| Visual Studio Code 1.132.0 | No App Sandbox entitlement; Apple Events, audio input, camera and JIT executable memory | `devices`, `automation`, `hardening-exception` |
| WhatsApp 26.30.20 | Sandboxed; files, network client/server, media devices, personal information, groups and iCloud | `devices`, `files`, `network`, `personal-data` |

The Visual Studio Code passport included this compact explanation:

```text
APP SANDBOX
  not declared

HARDENING EXCEPTIONS
  [code-execution] com.apple.security.cs.allow-jit
    May create writable and executable memory using MAP_JIT.

MODEL TAGS
  devices, automation, hardening-exception

PLAIN-LANGUAGE EXPLANATION
  The signed metadata declares that the application may send Apple events to
  automate other applications, declare audio and camera access, and may create
  writable and executable memory using MAP_JIT.
```

That is not a security finding. Apple's [`allow-jit` documentation](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.allow-jit) describes exactly what the entitlement permits. JIT is expected in many developer tools and browsers, while the absence of App Sandbox is not a malware signal. The passport makes the metadata legible without hiding the original keys.

## Small local models fit small jobs

There is no particularly clever AI workflow here. A deterministic tool collects evidence, a reviewed map supplies meaning, the model compresses the result, and validation prevents it from going completely off the rails. The same pattern could explain launch agents, summarize code-signing changes or tag privacy manifests without uploading the local inventory to a cloud model.

This is why I like Apple's Foundation Model Python SDK. A virtual environment, one package and a few asynchronous calls are enough to add local language processing to an ordinary security script. I would not ask this model to be the analyst as it has [only a few billion parameters](https://machinelearning.apple.com/research/introducing-third-generation-of-apple-foundation-models).
