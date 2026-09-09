# The Two Ideas Behind Jac

Jac combines two independent design ideas: continuity across execution
environments and computation expressed as movement through connected data.
The research vocabulary calls languages with these properties *synechic* and
*topokinetic*, respectively. This page explains the ideas and how Jac applies
them. For a practical introduction, start with
[Core Concepts](what-makes-jac-different.md) or the
[day-planner tutorial](../tutorials/first-app/build-ai-day-planner.md).

## Synechic

The synechic class concerns continuity of program expression across runtimes,
ecosystems, and toolchains. The aim is to let a programmer compose behavior
across these boundaries using language-level declarations, with the compiler
responsible for supported representation changes.

In Jac, a client can call a declared server function without separately naming
an HTTP route and maintaining a second copy of its signature. The compiler
has information about both declarations and can diagnose supported contract
mismatches. The precise coverage depends on the construct, available type
information, and execution target.

### Substrate transparency

A *substrate* comprises an execution environment, its libraries, and its
toolchain. Substrate transparency describes how much of their variation the
language can handle without requiring application-specific adapters.

Jac applies this idea through:

- [Placement inference](../reference/placement.md), which assigns declarations
  to client, server, or native execution, with configuration for explicit pins.
- [Imports](../reference/import-anything.md) into supported Python, JavaScript,
  and native ecosystems. Dependencies and target-specific restrictions still apply.
- [Meaning types and byLLM](../reference/plugins/byllm.md), which derive model
  requests from function declarations and semantic annotations. A valid output
  shape does not establish the truth or suitability of the result.
- [Gradual borrow checking](../reference/language/ownership-borrowing.md), which
  allows supported code to adopt explicit ownership constraints incrementally.

## The boundaries Jac refuses to hide

Shared syntax does not remove network latency, partial failure, concurrency,
or resource costs. Cross-tier calls need asynchronous control flow; shared
state needs authorization and transaction handling. Applications must handle
these conditions even when the compiler generates transport code.

The design distinction is between representation work that tooling can
automate and execution conditions that remain part of program behavior.

## Topokinetic

The topokinetic class makes a moving locus of computation over a data topology
a first-class language construct. It provides a programming-level contrast
with the von Neumann picture of data delivered to a fixed processing site.
This contrast concerns how a program is expressed, not the processor on which
it executes.

Jac realizes the idea through *Object-Spatial Programming* (OSP). Nodes hold
data, edges express relationships, and walkers carry state through the graph.
A walker's abilities execute at matching nodes. The program describes both
what happens at a location and which locations to visit next.

This can be useful when relationships organize the work: traversing a workflow,
collecting context from connected records, or exploring an agent's memory.
Ordinary functions remain available for computations that do not need traversal.
See [Object-Spatial Programming](../tutorials/language/osp.md) for examples.

A graph can be transient or persistent. In a persistence-enabled context,
connecting transient nodes to a persistent root can promote them into durable
storage. Disconnecting an edge is not equivalent to deleting every previously
persisted node it reached. Transactions, access checks, and explicit deletion
are described in the [persistence reference](../reference/persistence.md).

## The two ideas compound

The classes are independent: continuity across substrates does not require a
graph model, and graph traversal does not require multiple execution targets.
Jac combines them so that graph operations can participate in applications
with clients, services, and model-backed functions.

For example, a server walker can collect related records and report a typed
result to a client. The traversal expresses the domain relationships; the
cross-tier machinery carries the request and result. The storage engine,
network, and deployment configuration remain parts of the implementation.

## What stays visible

- **Operational behavior:** latency, failures, authorization, and resource use
  require application and deployment decisions.
- **Target constraints:** library availability and ownership rules depend on
  where code runs. Consult the reference for the relevant target.
- **Model behavior:** generated outputs require task-appropriate validation,
  even when they satisfy a declared schema.

## The vocabulary

[The Vocabulary of Jac](vocabulary.md) collects the terms used in these pages.
[Research & Papers](../community/research.md) links to the underlying work.

## Next steps

- [Core Concepts](what-makes-jac-different.md): the language features in examples.
- [One App, Two Stacks](jac-vs-traditional-stack.md): an implementation comparison.
- [Build an AI Day Planner](../tutorials/first-app/build-ai-day-planner.md): a guided application.
