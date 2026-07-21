# Research & Papers

Jac's core ideas are peer-reviewed research, not just design taste. The
project grew out of research at the University of Michigan and is developed in
the open. This page collects the published foundations, what each one
contributes, and how to cite the project.

## Published foundations

**Object-Spatial Programming**
&nbsp;·&nbsp; [arXiv:2503.15812](https://arxiv.org/abs/2503.15812)

The formal model behind `node`, `edge`, and `walker`: programs expressed as
mobile computation traversing a persistent typed topology, with abilities
dispatched by arrival. This is the paradigm the
[Graphs & Walkers tutorial](../tutorials/language/osp.md) teaches by example
and the [OSP reference](../reference/language/osp.md) specifies; the paper
gives it a precise semantics and situates it against actors, mobile agents,
and vertex-centric graph processing.

**MTP: A Meaning-Typed Language Abstraction for AI-Integrated Programming**
&nbsp;·&nbsp; OOPSLA 2025 &nbsp;·&nbsp; [arXiv:2405.08965](https://arxiv.org/abs/2405.08965)

The research behind `by llm()` and `sem`: treat the semantic content that
well-written code already carries (names, types, targeted annotations) as the
specification of delegated behavior, and make the compiler and runtime --
not the programmer -- responsible for prompt construction and typed output
enforcement. The paper's evaluation compares MTP against hand-engineered
prompt pipelines and reports comparable or better accuracy with substantially
less code, lower token cost, and robustness to degraded naming quality.

**The Jaseci Programming Paradigm and Runtime Stack: Building Scale-Out
Production Applications Easy and Fast**
&nbsp;·&nbsp; IEEE Computer Architecture Letters, 22(2), 2023

The production lineage. The Jaseci stack -- Jac's earlier generation --
served walkers as scale-out API endpoints in commercial products, and the
experience reported here (small teams shipping multi-user, persistent,
AI-heavy applications without a conventional backend stack) is what motivated
building the current language and runtime the way they are built.

## In preparation

A book-length treatment of the language's design and theory -- the diagnosis
of the fragmented stack, the formal definition of the continuity property,
the object-spatial calculus, and the design space of languages that share
these properties -- is in preparation, along with companion papers. The
practitioner's distillation of that material lives in the docs at
[The Ideas Behind Jac](../quick-guide/ideas-behind-jac.md).

## Citing Jac

GitHub's "Cite this repository" button on
[the repo](https://github.com/jaseci-labs/jaseci) (powered by
`CITATION.cff`) gives a ready-made reference. For the specific ideas, cite
the papers above: OSP for the paradigm, MTP for the AI integration, and the
Jaseci letter for the runtime lineage.

## Working with us

The project welcomes research collaborations -- language design, type
systems, distributed runtimes, and human-factors studies of the paradigm are
all live areas (several open problems are sketched at the end of
[The Ideas Behind Jac](../quick-guide/ideas-behind-jac.md)). Reach out on
[Discord](https://discord.gg/6j3QNdtcN6) or open a discussion on GitHub.
