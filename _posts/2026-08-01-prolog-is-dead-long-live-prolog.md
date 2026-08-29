---
title: 'Prolog is dead, long live Prolog!'
date: '2026-08-01T12:00:00+02:00'
last_modified_at: '2026-08-01T12:00:00+02:00'
author: tbarabosch
layout: post
toc: true
image:
  path: /assets/images/posts/prolog-is-dead-long-live-prolog/social-card.png
  width: 1200
  height: 630
social_card:
  layout: ascii
  subtitle: 'Let the model translate; let a deterministic engine perform the deduction.'
  eyebrow: 'AI Engineering / Prolog'
  panel_label: 'Query / relation'
  source:
    language: console
    occurrence: 1
  highlight: 'Grandchild = carol'
  accent: 'Grandchild = dave'
tags:
  - AI tooling
  - reverse engineering
  - Prolog
---

## TL;DR

- Large Language Models (LLMs) can decompose difficult problems and still invent a convincing step between two correct observations.
- Research such as Logic-LM, Faithful Chain-of-Thought and LINC shows that an LLM can translate a problem while a deterministic symbolic engine performs the actual deduction.
- Prolog is a compact way to express facts, relations and rules, then ask reproducible questions about them.
- Between IDA and an LLM, a reviewed Prolog knowledge base could make reverse-engineering conclusions more consistent, testable and auditable.
- This would constrain one class of reasoning error. It would not make incorrect IDA output, incomplete facts or a bad translation magically true.

---

LLMs are surprisingly capable reasoners. They can divide a vague problem into smaller questions, connect information spread across a large context and produce explanations that would have taken me much longer to write. Reasoning-oriented models push this further by spending more computation before returning an answer. I use these capabilities every day.

The uncomfortable part is that a plausible explanation and a valid deduction look almost identical in prose. A model may identify two correct facts, insert one unsupported bridge between them and continue as if the bridge had been proven. The final answer can be coherent, detailed and wrong. A longer reasoning trace does not necessarily fix this. It can simply provide more room in which to be confidently mistaken.

This matters in reverse engineering. A model may see a call to `VirtualAlloc`, a suspicious string and a network import, then declare that a function injects code into another process. The observations might all be real while the conclusion is not supported by them. An analyst can check the disassembly, cross-references and call graph, but the model itself is producing text rather than executing a formal proof.

I do not want to stretch the word *hallucination* until it means every incorrect answer. Factual fabrication, an invalid logical step and an explanation that does not reflect how the answer was produced are related but different failures. Logic programming is most relevant to the middle one: whether a conclusion follows from a defined set of facts and rules.

That narrower problem suggests an old solution. Let the language model translate and explain. Let a symbolic engine perform the deduction.

<!--more-->

<nav class="post-toc" aria-labelledby="contents-heading" markdown="1">
<p id="contents-heading" class="manual-label">CONTENTS</p>

* TOC
{:toc}
</nav>

## Make the reasoning executable

This division of labor is usually described as *neurosymbolic reasoning*. The neural component handles language and ambiguous input. The symbolic component operates over a constrained representation with explicit rules. Three frequently cited papers from 2023 provide useful evidence for this approach.

| Paper | Division of labor | Reported result |
| --- | --- | --- |
| [Logic-LM](https://aclanthology.org/2023.findings-emnlp.248/) | An LLM translates natural language into logic programs, constraints or satisfiability problems; Pyke, a finite-domain solver or Z3 performs inference. | Across five logical-reasoning datasets, the paper reports an average improvement of 39.2% over standard prompting and 18.4% over chain-of-thought prompting. |
| [Faithful Chain-of-Thought Reasoning](https://aclanthology.org/2023.ijcnlp-main.20/) | An LLM produces an executable reasoning chain in Python, Datalog or PDDL; an interpreter or planner computes the answer. | The executed program makes the returned answer follow from the displayed reasoning chain and improves accuracy across several arithmetic, symbolic and planning tasks. |
| [LINC](https://aclanthology.org/2023.emnlp-main.313/) | An LLM acts as a semantic parser from natural language to first-order logic; Prover9 performs deduction. | With GPT-4, LINC scores 26% higher than chain-of-thought on ProofWriter and performs comparably on FOLIO. |

These systems are not identical. Logic-LM and Faithful Chain-of-Thought include logic programming among their symbolic paths, while LINC uses a first-order-logic theorem prover. Together they support the more general design: use the LLM where language is useful and move the part that can be made formal into an executable representation.

This does not eliminate errors. The model can mistranslate the original question. A solver can receive a perfectly valid formalization of the wrong problem. The knowledge base can omit a fact or contain a bad rule. The important improvement is that translation, deduction and explanation become separate failure boundaries. I can inspect and test each one instead of receiving one uninterrupted paragraph of synthetic confidence.

## We have met Prolog before

Prolog is a logic-programming language built around relations. Instead of describing a sequence of state changes, I provide facts and rules. I then submit a query, and the runtime attempts to satisfy it through unification and backtracking.

Many of us learned Prolog because a university curriculum made sure that we did. We wrote a family tree, discovered that a harmless-looking recursive rule could search until the heat death of the universe, met the cut operator, passed the exam and promptly declared the language dead. This was slightly unfair to Prolog, although perhaps not entirely unfair to the assignment.

For a proper reintroduction, I recommend W. F. Clocksin and C. S. Mellish's [*Programming in Prolog*](https://athena.ecs.csus.edu/~mei/logicp/Programming_in_Prolog.pdf). The linked fifth edition uses ISO Prolog. An experienced programmer can work through the opening chapters and type the small examples over a weekend. That is enough to recover the different mental model; the rest of the book remains useful once the first recursive predicate goes sideways.

The following examples use SWI-Prolog. Source belongs in a `.pl` file and queries are entered at the `?-` prompt.

## Example 1: facts, rules and backtracking

A family relation is the canonical Prolog example for a reason. It introduces most of the language without hiding the idea behind application code.

```prolog
parent(alice, bob).
parent(bob, carol).
parent(bob, dave).

grandparent(X, Z) :-
    parent(X, Y),
    parent(Y, Z).
```
{: data-language="PROLOG" }

Lowercase names are atoms. Names beginning with uppercase letters are variables. The comma means that both goals must hold. A query asks Prolog to find bindings that satisfy the relation:

```console
?- grandparent(alice, Grandchild).
Grandchild = carol ;
Grandchild = dave.
```

The semicolon asks for another solution. Prolog first binds `Y` to `bob`, then searches for every matching value of `Z`. I did not write a loop or allocate a result list. I described the relation and let the runtime search it.

## Example 2: recursive reachability

The same model can express whether one city is reachable from another through a small directed road network:

```prolog
road(madrid, zaragoza).
road(zaragoza, barcelona).
road(madrid, valencia).

route(From, To) :-
    road(From, To).

route(From, To) :-
    road(From, Via),
    route(Via, To).
```
{: data-language="PROLOG" }

The first rule covers a direct road. The second says that a route exists when there is a road to an intermediate city and a route from there to the destination.

```console
?- route(madrid, barcelona).
true.

?- route(madrid, Destination).
Destination = zaragoza ;
Destination = valencia ;
Destination = barcelona.
```

This tiny graph has no cycles. A real road map—or a real call graph—needs cycle handling through a visited set, tabling or another bounded strategy. Declarative does not mean exempt from algorithmic consequences.

## Example 3: constraints instead of guesses

SWI-Prolog's finite-domain constraint library lets me state relationships between integer variables before asking the runtime to assign values. Suppose unpacking, analysis and reporting must occupy three distinct slots in that order:

```prolog
:- use_module(library(clpfd)).

schedule(Unpack, Analyze, Report) :-
    [Unpack, Analyze, Report] ins 1..3,
    all_distinct([Unpack, Analyze, Report]),
    Unpack #< Analyze,
    Analyze #< Report,
    labeling([], [Unpack, Analyze, Report]).
```
{: data-language="PROLOG" }

The constraints narrow the possible values. `labeling/2` performs the final search for concrete assignments.

```console
?- schedule(Unpack, Analyze, Report).
Unpack = 1,
Analyze = 2,
Report = 3.
```

The interesting feature is not this deliberately tiny schedule. It is that the constraints are executable and reviewable. There is no prose step claiming that analysis happened after unpacking. The solver either finds an assignment that satisfies `Unpack #< Analyze` or it does not.

## Put Prolog between IDA and the LLM

I recently wrote about using [IDC and Codex with IDA Free](/ida-free-on-steroids/). The LLM is useful at that boundary because it can turn analyst intent into a script and explain unfamiliar APIs. The next question is whether a logic layer can also improve conclusions drawn from the resulting database.

The architecture I am considering looks like this:

```text
binary -> IDA -> observations + provenance ---+
                                               |
reviewed analyst rules ------------------------+--> Prolog
                                                    ^   |
                                                    |   v
analyst question -> LLM -> allow-listed query ------+   result + evidence
                                                            |
                                                            v
                                                     LLM explanation
                                                            |
                                                            v
                                                         analyst
```

IDA should supply observations without asking an LLM to reinvent them. A small exporter can normalize function boundaries, names, calls, imports, strings and cross-references into predicates such as `function(Address, Name)`, `calls(Caller, Callee)`, `references_import(Function, Library, Symbol)` and `references_string(Function, Address, Text)`. Every observation should retain its database address and extraction source.

A reviewed rule base can then define higher-level relations. One rule may classify APIs associated with networking. Another may calculate transitive reachability in the call graph. A third may ask whether an exported entry point can reach a function that references both a network API and a file-writing API. These are analyst definitions, not universal truths about malicious behavior.

The LLM remains useful on both sides. Before execution, it can translate “Which exported functions eventually reach networking and file-writing behavior?” into a query over an allow-listed predicate vocabulary. After execution, it can turn the bindings and supporting addresses into a readable explanation. It should not be allowed to silently add a missing call edge because that edge would make the story nicer.

There is also room for hypotheses, but they need a different namespace. If the model believes that `sub_401000` implements configuration parsing, that can become a candidate assertion with its prompt, model and supporting evidence attached. It must not be indistinguishable from a call edge extracted directly from IDA. Observations, derived conclusions and model hypotheses have different levels of authority.

## The theoretical benefits

The first benefit is repeatability. Given the same facts, rules and query, the logic layer returns the same result. Model sampling no longer changes whether a call path exists. Two analysts can inspect the same rule, run the same query and disagree about its meaning without disagreeing about what the program executed.

The second benefit is compositional reasoning. Reverse engineering contains many multi-hop questions: which entry points reach this import, which functions reference strings used by callees, or which paths connect parsing to an eventual process-creation API. These relationships are awkward to repeat in natural-language prompts but natural to express as reusable predicates.

The third benefit is auditability. A result can carry the facts and rule applications that supported it. Prolog does not automatically turn every successful query into the proof report I would want, so the rules or wrapper must be instrumented to preserve that evidence. Once it is preserved, the LLM can cite addresses and relations instead of presenting a conclusion without a trail.

The fourth benefit is a smaller and more stable context. An LLM does not need an entire decompiler listing merely to answer a graph query. It can work with the query contract and the solver's bounded result, while IDA remains the source for the underlying evidence. This should reduce irrelevant context and make repeated questions cheaper.

Finally, the interface can represent ignorance honestly. A production wrapper should distinguish `proved`, `contradicted`, `unknown` and `error`. Plain Prolog failure means that a goal could not be proven from the current program; it does not prove that the goal is false. That difference is essential when static analysis is incomplete.

## What Prolog does not fix

A deterministic proof from bad premises is still wrong. IDA can misidentify a function boundary, miss an indirect call or fail to recover useful structure from obfuscated code. Prolog will propagate those mistakes with admirable consistency. Provenance makes the problem inspectable, but it does not remove it.

Incomplete knowledge also makes negation dangerous. In ordinary Prolog, negation as failure treats an unprovable goal as failure. Concluding that a function does not call an API merely because `calls(Function, API)` cannot be proven would confuse absence of evidence with evidence of absence. Rules over IDA data need an explicit incomplete-world policy rather than casual use of `\+`.

The translation boundary remains probabilistic. An LLM can choose the wrong predicate, reverse two arguments or omit part of the analyst's question. An allow-listed query language, schema validation and a rendered “query understood as” step can make that visible. They cannot guarantee that the translation captured the analyst's intent.

Prolog is also executable code, not a harmless serialization format. Arbitrary model-generated clauses could invoke unwanted predicates or create searches that never terminate. The integration needs a restricted vocabulary, resource limits and isolation. Reviewed static rules and generated data-only queries are a much safer starting point than letting the model rewrite the reasoning engine.

Finally, symbolic rules cover only what somebody has formalized. They are excellent for graph reachability, constraints and explicit relationships. They do not automatically understand an undocumented algorithm, recover runtime-only state or decide whether a novel combination of behaviors is malicious. Dynamic analysis, analyst judgment and the LLM's broader pattern recognition remain useful.

## The next experiment

I am exploring this architecture now. The useful test is not whether Prolog can solve a family tree; universities settled that question rather thoroughly. I want to compare an LLM working directly from IDA evidence with an LLM that must route defined questions through a Prolog layer.

I plan to use binaries with known behavior and measure correct conclusions, unsupported claims, consistency across repeated runs, evidence coverage, abstention and latency. The interesting failures will be at least as important as the successful proofs: bad fact extraction, bad question translation, insufficient rules and queries where `unknown` is the only honest result.

I will write about the implementation and results in detail soon. Prolog's first career was helping computers reason. Its next one may be keeping modern AI honest.
