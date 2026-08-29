---
title: 'From Problem to Operations: An Engineering Workflow for Security Teams'
date: '2026-07-27T10:00:00+02:00'
last_modified_at: '2026-07-27T10:00:00+02:00'
author: tbarabosch
layout: post
toc: true
image:
  path: /assets/images/posts/from-problem-to-operations/social-card.png
  width: 1200
  height: 630
social_card:
  layout: ascii
  subtitle: 'Security engineering ends in an observable, maintainable operation.'
  eyebrow: 'Incident Response / Engineering'
  panel_label: 'Deployment / escalation'
  source:
    language: text
    occurrence: 4
  highlight: 'run in shadow'
  accent: 'automated response?'
tags:
  - engineering
  - incident response
  - mentoring
---

## TL;DR

- Effective security work follows a lifecycle that runs from evidence to operations.
- Start with evidence that a problem deserves attention, then define it before choosing a solution.
- Design, phased deployment, observation, documentation and training matter as much as implementation.
- A capability succeeds when it remains observable, useful and maintainable in operation.

## Engineering the whole lifecycle

I have been teaching some version of this workflow to junior security engineers and analysts for years. I use “engineering” here to describe a way of approaching security work, not a particular job title. The same discipline applies to detection and log ingestion projects, threat intelligence pipelines, malware analysis tooling and incident response automation. The details change, but the shape remains surprisingly stable.

Security projects often appear to begin when somebody opens an editor and end when a rule, service or configuration reaches production. In practice, the decisive work starts earlier and finishes much later. A technically correct implementation can still address an irrelevant problem, fail during rollout, overwhelm the SOC or become impossible for anybody else to maintain.

Implementation, including programming, is an important stage in this lifecycle. Coding agents such as Codex and Claude Code can make that stage considerably faster. That is useful, but it leaves the surrounding decisions intact: which organizational problem deserves attention, what trade-offs are acceptable, how the change should reach production and who will own it two years later.

Put differently:

> An engineering approach turns a justified security problem into a capability that can be deployed safely, observed, understood and maintained over time.

That system needs more than code. It needs evidence, a clear problem statement, a reviewed design, safe delivery, feedback from production, useful documentation, trained users and an owner.

<!--more-->

<nav class="post-toc" aria-labelledby="contents-heading" markdown="1">
<p id="contents-heading" class="manual-label">CONTENTS</p>

* TOC
{:toc}
</nav>

## A running example: detecting MFA fatigue

Consider a representative incident. A user reports a stream of unexpected MFA prompts and says that they rejected them. During the investigation, the security operations center discovers a later successful authentication for the same identity. The identity provider contains some useful events, but the data available in the SIEM is incomplete and the analysts have no reliable detection for the sequence.

Repeated MFA requests are not automatically proof of an attack. A broken application, a policy change, an expired session or an authenticator problem can produce similar symptoms. The successful authentication may also be legitimate. The analysts need enough context to distinguish these cases instead of treating every prompt as an incident.

The attack pattern is commonly called MFA fatigue. MITRE ATT&CK tracks it as [Multi-Factor Authentication Request Generation, T1621](https://attack.mitre.org/techniques/T1621/). The project in this post is to create a dependable detection and investigation capability for it.

Detection is only one control. Phishing-resistant MFA is preferable, and [CISA recommends number matching](https://www.cisa.gov/sites/default/files/publications/fact-sheet-implement-number-matching-in-mfa-applications-508c.pdf) as an interim mitigation when an organization cannot immediately deploy phishing-resistant MFA. Those preventative changes belong in the wider risk treatment, but they are not substitutes for understanding what happened in the environment.

## An engineering workflow for security work

My workflow is ordered, but it is not a waterfall. Each stage creates evidence for later decisions, and production frequently sends the project back to an earlier stage. Observation may show that the problem was defined too broadly. An analyst exercise may expose missing context. A schema change may require a new design decision.

```text
identify -> collect evidence -> define -> design -> implement
   ^                                               |
   |                                               v
   +---- learn <- observe <- phased deployment <- evaluate*
                               |
                               v
                    document -> train -> operate
                                            |
                                            +----> new evidence

* Dedicated evaluation is conditional; verification is not.
```

The rest of the post walks the MFA-fatigue example through every stage. At each step I want four things to be clear: the question being answered, the decision or artifact produced, how the example changes and the shortcut that commonly causes trouble.

## 1. Identify the problem

Problem identification begins with a signal: an incident, an analyst complaint, an audit finding, a change in the threat landscape or repeated manual work. It is a hypothesis that something deserves a deliberate engineering effort, not yet permission to build a particular solution.

In the example, the immediate signal is the user report and the difficulty of reconstructing the authentication sequence. The hypothesis is that the organization has a visibility and detection gap around abusive MFA requests. At this point I would not define the problem as “we need a new SIEM rule.” That has already selected a solution before establishing the need.

A common mistake is to convert the first proposed mechanism into the project goal. Somebody asks for a dashboard, so the team builds a dashboard. Somebody asks for a log connector, so the team ingests everything the product can export. The first question is: what harmful condition or operational failure are we trying to change?

## 2. Collect evidence

The next step determines whether the hypothesis is real and important enough to tackle. I would review relevant incident tickets, user and help-desk reports, previous identity investigations and whatever historical events are available at the identity provider. I would also measure how long analysts currently spend reconstructing an authentication sequence and which questions the existing data cannot answer.

This is deliberately broader than counting past attacks. Low-frequency events can still justify work when their impact is high. The evidence should cover likelihood, consequence, operational cost, current control coverage and the feasibility of obtaining better telemetry.

For the MFA case, a small sample of source events can answer early technical questions. Does an event distinguish a challenge from an approval or denial? Is there a stable identity identifier? Can authentication steps be connected through a session or correlation identifier? How late do events arrive? Are source IP, device, application and location present consistently? What will retention and SIEM ingestion cost?

This data collection is not yet the production ingestion pipeline. It can be a read-only export or a bounded query at the source. Its purpose is to support a decision. Building a durable, monitored collector before knowing whether the source contains the necessary evidence simply moves implementation ahead of definition and design.

The output is an evidence-backed decision to proceed, narrow the idea or stop. Stopping here because the problem is already covered, cannot be measured or costs more than its expected benefit is a successful outcome.

## 3. Define the problem

A useful problem statement describes the current failure, the affected employees and the required outcome without hiding a preferred solution inside it. For this project, it could be:

> The security operations center cannot reliably identify and triage suspicious sequences of repeated MFA challenges or denials, particularly when they are followed by a successful authentication, within the response time required to contain account compromise.

The definition should add measurable boundaries: which identities and authentication paths are in scope, how fresh and complete the evidence must be, what context an analyst needs, and how much alert volume the SOC can reasonably absorb. It should also state non-goals. This detector will not find every form of credential theft or session-token abuse, and it will not replace improvements to the authentication policy of the organization.

The common failure here is a vague objective such as “improve identity security.” Nobody can test whether that happened. A narrower definition gives the later design something to satisfy and gives reviewers a reason to reject unnecessary complexity.

## 4. Write and review the design

The design document is the point where the proposed solution becomes reviewable before implementation makes it expensive to change. It should be short enough that the relevant people actually read it, but concrete enough to expose assumptions.

For this project it describes the threat model, data sources, normalized event contract, detection logic, alert enrichment and analyst workflow. It covers retention, access control and privacy because identity events can be sensitive. It estimates ingestion and storage cost, records alternatives, identifies failure modes and defines the deployment and rollback plan. It names the eventual owner rather than leaving maintenance as a problem for the end of the project.

The proposed flow is deliberately ordinary:

```text
identity provider
       |
       v
collection -> raw events -> normalization -> correlation
                                  |              |
                                  v              v
                           health metrics    enrichment
                                                  |
                                                  v
                                            alert / case
                                                  |
                                                  v
                                          analyst response
```

Analysts review whether the resulting case would let them make a decision. Identity engineers confirm the semantics and limitations of the source. SIEM engineers review volume, failure handling and platform fit. Privacy stakeholders review collection and access. The team that will maintain the capability reviews its operability.

This discussion is part of the work showing that corporate security is highly cross functional!

## 5. Implement the capability

Only now does implementation become the main activity. It includes more than the correlation rule: collection, authentication to the source, checkpoints, retry behavior, raw-event preservation, normalization, health monitoring, tests, deployment configuration, alert enrichment and the connection to the incident workflow all have to work together.

The normalized event contract keeps the rule independent of one vendor's field names. At minimum, the design needs stable meanings for these fields:

| Field | Purpose |
| --- | --- |
| Event time | Order authentication steps and calculate detection latency |
| Identity ID | Correlate activity without relying on a mutable display name |
| Session or correlation ID | Connect prompts, outcomes and later authentication |
| MFA action and outcome | Distinguish challenge, approval, denial and failure |
| Source and device | Compare network and endpoint context |
| Application | Explain which service initiated authentication |
| Location or risk context | Enrich investigation without treating it as proof |
| Raw-event reference | Let the analyst recover the original evidence |

Missing session identifiers need an explicit fallback correlation strategy using identity, time and other available context. The weaker match must remain visible to the analyst. A shared source IP must not merge several users into one authentication session, and a location derived from that IP is supporting context rather than a verdict.

The rule can remain vendor-neutral in pseudocode:

```text
WINDOW    = duration selected from the observed baseline
THRESHOLD = count selected from the observed baseline

GROUP normalized authentication events
  BY identity_id AND session_id_if_present
  WITHIN WINDOW

LET repeated_requests = COUNT(
  event.mfa_action == "challenge" OR event.mfa_outcome == "denied"
)

LET later_success = EXISTS(
  event.authentication_outcome == "success"
  AFTER repeated requests
)

WHEN repeated_requests >= THRESHOLD
EMIT alert WITH
  priority = "higher" IF later_success ELSE "review",
  source, device, application, location, risk_context,
  correlation_quality, raw_event_references
```

The threshold and window are configuration derived from evidence, not magic numbers copied from a public rule. The alert should contain useful enrichment, but it should never replace or conceal the raw evidence used to create it.

The common shortcut is to call the query the implementation. A perfect query on an unreliable pipeline is an unreliable detection.

## 6. Verify, then evaluate where necessary

Verification is mandatory. The team must show that the delivered system behaves according to the design. A dedicated evaluation phase is conditional: it becomes especially important for machine-learning models, anomaly detection and other probabilistic systems whose behavior cannot be covered by a small set of deterministic tests.

Our correlation rule still deserves serious validation. Synthetic sequences should cover repeated denials followed by success, denials without success, legitimate repeated prompts, an application authentication loop, missing session identifiers, duplicated events and events arriving out of order. Historical replay should include known incidents where available and representative quiet periods. Analysts should review the resulting cases, because a technically correct match can still be operationally useless.

The useful measures include whether expected sequences are found, false-positive volume, detection latency, duplicate rate and whether the alert contains enough context for a timely decision.

## 7. Deploy in phases

Security systems can cause harm when deployed carelessly. A noisy rule can hide better alerts, an ingestion change can multiply SIEM cost and an automated response can lock out legitimate users. Deployment therefore needs stages with explicit entry criteria, rollback conditions and a person authorized to advance the rollout.

```text
validate source -> run in shadow -> analyst pilot -> broad alerting
                                                        |
                                                        v
                                           automated response?
```

First validate the source and normalized fields without relying on alerts. Then run the rule in shadow mode and study its matches. Route it to a limited analyst group once the data and volume are understood. Expand alerting only after the pilot meets its criteria. Automated session revocation or account restriction, if it is justified at all, comes later with a separate risk decision.

“We can turn it off” is not a rollback plan unless the team has tested the switch, knows what happens to queued events and cases, and has agreed on the conditions that trigger it.

## 8. Observe the production system

Deployment changes the source of truth from assumptions to production evidence. I'd observe the capability on three planes:

The data plane includes ingestion latency, dropped events, parser failures, unexpected volume, missing fields and so on. The detection plane includes matches, duplicates, false positives, detection latency, conversion from alerts into confirmed incidents and so on. The operational plane includes analyst triage time, escalation outcomes. In addition, I'd work with the analysts to collect missing context and direct feedback from the analysts who are responding to the alert.

## 9. Document the system that actually exists

Documentation starts during problem definition and design. The later documentation stage updates those working documents to describe the behavior observed in production rather than the system everybody expected to build.

For the MFA capability, the final material covers the architecture, data contract, source limitations, rule rationale, tuning decisions, known gaps, health dashboards, investigation runbook, response playbook, rollback procedure and change history. It explains why a decision was made, not only which setting currently contains it.

Documentation written solely from the implementation misses the human interfaces: who can approve an exception, which team owns the identity source, how analysts report a bad alert and what happens when the source schema changes. Generating a first draft with an agent can save time, but the owners still have to verify it against reality.

## 10. Train the people who will use it

A new alert is a change to an analyst's job. Sending a link to a runbook is not the same as training. Analysts need to understand the story the rule is telling, the evidence it does and does not have, and the decisions expected from them.

Therefore, I usually root for a presentation for the analysts. This presentation should include an overview of the new system, the technical details (as much as the audience needs to know) and the new processes that are related to it.

## The result is an operational capability

Better tools can shorten implementation, but they do not remove the decisions and operational work around it. The saved effort is most valuable when it is invested in evidence, design review, safe deployment, observation and the people who will use and maintain the result.

In the MFA example, the durable result is not a correlation query. It is a justified capability with trustworthy data, a reviewed design, a verified rule, a safe rollout, visible health, trained analysts and a maintenance process that keeps it useful.

That is the whole workflow. It begins with evidence that a problem matters and finishes when the resulting capability holds up in operations and has somebody responsible for its future. Also, keep in mind that security work tends to be highly cross functional, involving many stakeholders within and outside the security organization.
