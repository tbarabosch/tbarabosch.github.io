---
title: 'The Last Engineer in the Loop'
date: '2026-08-03T12:00:00+02:00'
author: tbarabosch
layout: post
tags:
  - AI tooling
  - engineering
  - skill development
---

I use coding agents a lot. Given a repository and a reasonably bounded task, they can inspect the code, implement a change, run the compiler, look at a failed test and try again. This is far more useful than autocomplete with a larger vocabulary. I have no desire to return to a world where every missing semicolon requires my personal attention.

A common description of this workflow is that developers are becoming managers of AI agents. We define the task, delegate the implementation and review the result. I am not convinced by this analogy.

A manager can delegate technical work because a trained engineer receives it. With a coding agent, no trained engineer magically appears on the other side of the prompt. The LLM produces the code, but I still have to decide whether the architecture makes sense, whether the tests prove anything and whether the result is safe to ship. Calling myself the manager does not remove the engineering part of the job. I am also the last engineer in the loop.

<!--more-->

## The last engineer in the loop

The problem is older than LLMs. In her 1983 paper [*Ironies of Automation*](https://web.archive.org/web/20200717054958if_/https://www.ise.ncsu.edu/wp-content/uploads/2017/02/Bainbridge_1983_Automatica.pdf), Lisanne Bainbridge described what happens when an operator is left monitoring an automated process and handling the unusual situations that the automation cannot solve. These are exactly the situations in which understanding the system matters most.

I highly recommend reading the paper. It is only five pages long. Whenever Bainbridge writes *automated system*, mentally read *agentic coding*. Replace *operator* with *developer*. Not every sentence maps, but far more of the paper survives this substitution than I expected.

Applied to coding, the picture looks roughly like this:

```text
old model:

manager -> engineer -> code
           (trained)

agent model:

developer -> LLM -> code
    ^               |
    +---- review ---+
    (still must be trained)
```

Of course, software development is not an industrial control room. The important bit still maps: the automation handles more of the normal work, while the human inherits the strange failures. Those failures do not become easier because the first draft appeared in a few seconds.

## Reviewing is not training

Reviewing a diff is not the same as producing it. A generated patch can look clean and plausible. It may even pass the tests. When I write the solution myself, I have to model the problem, make design choices, understand an API, read the compiler error, use the debugger and eventually discover which assumption was wrong. Merely reading the finished patch skips most of this.

The general research on skill decay is rather clear. The meta-analysis [*Factors That Influence Skill Decay and Retention*](https://doi.org/10.1207/s15327043hup1101_3) reviewed 53 articles and found substantial skill loss after periods without practice. There were, unsurprisingly, no coding agents in those studies. The paper cannot tell me how quickly my C skills will decay, but I see no reason why programming should be exempt from nonuse.

A [CHI 2025 study of 319 knowledge workers](https://www.microsoft.com/en-us/research/publication/the-impact-of-generative-ai-on-critical-thinking-self-reported-reductions-in-cognitive-effort-and-confidence-effects-from-a-survey-of-knowledge-workers/) found that higher confidence in GenAI was associated with less reported critical-thinking effort. The work shifted toward verification, integration and task stewardship. This was a survey, not a long-term study of developers losing their skills. Still, moving most of the work to *verification* seems unwise if I no longer practise the skills required to verify the result.

This is the loop I want to avoid: I write less code, reviewing code gets harder, and I delegate even more because reviewing has become hard. Everything looks productive until the generated code fails outside the generated test suite.

## Write something yourself

My countermeasure is boring: I keep some side projects LLM-free by default. I am not trying to maximize output per hour in these projects. I am trying to keep my skills sharp.

One of them is a small Lisp interpreter written in C. I am following Daniel Holden's excellent online book [*Build Your Own Lisp*](https://www.buildyourownlisp.com/), which teaches C by building a programming language in about a thousand lines of code. It is small enough that I might actually finish it, but large enough to involve parsing, data structures, pointers, memory management and plenty of opportunities to disagree with the compiler.

I could ask an agent to implement each chapter. The result would probably arrive faster and might even be better than my first attempt. It would also defeat the purpose. In this project, the compiler error and the hour spent chasing the wrong pointer are not interruptions to the work. They are the work.

## Let the LLM teach, not replace

I am not dogmatic about keeping the LLM out. If I am genuinely stuck, I can use it like a teacher rather than an implementation subcontractor:

```text
book / documentation
         |
         v
write -> compile -> debug
                    |
                still stuck?
                    |
                    v
          ask for a hint
          or explanation
                    |
                    v
            fix it yourself
                    |
                    v
          request a critique
```

I first try to understand and debug the problem myself. If I remain stuck, I ask for a hint, an explanation or a question that points me at a bad assumption. I do not ask for a replacement function. Once my version works, I may ask the model to critique it or show me a better design. By then I understand the problem well enough to argue with the answer.

Anthropic recently ran a [randomized study of AI assistance and coding-skill formation](https://www.anthropic.com/research/AI-assistance-coding-skills) with 52 mostly junior developers. The AI group averaged 50 percent on an immediate mastery quiz; the group coding by hand averaged 67 percent. The largest gap was in debugging questions. Participants who used the model for conceptual questions were among the higher-scoring interaction patterns.

This is preliminary work with a small sample and an immediate quiz. It did not measure experienced developers over several years, nor did it test a full agentic workflow. I would not derive a universal rule from it. The debugging gap is nevertheless exactly what worries me: debugging is one of the skills I need when the agent gets something wrong.

## Keep the reviewer qualified

I am not arguing that every use of an agent makes a developer worse. I use these tools every day, and I am happy when they remove hours of mechanical work. I simply do not count reviewing their output as coding practice.

The manager analogy only works while a trained engineer remains somewhere in the system. If I want to remain capable of reviewing the machine, I still need to write code without it.
