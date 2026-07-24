# The Two Ideas Behind Jac

Jac can look like a bag of features: one language for three tiers, a graph
that persists itself, functions implemented by LLMs, a binary that deploys to
Kubernetes. It is not. Every feature follows from two properties, and knowing
them makes the rest of the documentation predictable. This page defines both
properties, states why they compound, and names what they refuse to hide.

The diagnosis behind the design lives on [Why Jac Exists](why-jac.md): the
*discontinuities* of the modern stack, the *glue* they cost, and the two
seventy-year-old assumptions they trace to. For the practical tour of what
these ideas become in the language, see
[Core Concepts](what-makes-jac-different.md).

---

## Synechic

A language is *synechic* if it presents a single continuous semantic medium
across conventionally discrete ecosystems, tiers, and toolchains, such that no
program point requires glue code, marshaling, or interop scaffolding to cross
a substrate boundary. The name comes from the Greek *synecheia*, continuity.
In a synechic language, the compiler that checks composition *within* a
substrate checks composition *across* one, because they are the same
expression. Building the first production synechic language is the whole
point of Jac.

### Substrate transparency

The property beneath the name is *substrate transparency*: the identity of the
underlying runtime, ecosystem, and toolchain at any program point has no
bearing on how the program is expressed. A *substrate* is a runtime, the
ecosystem importable at it, and the toolchain that builds and ships for it.
The browser is a substrate. The server is a substrate. Native machine code is
a substrate. The LLM is a substrate whose executor happens to be stochastic.

The ordering in the definition, ecosystems before tiers, is deliberate.
Languages that unify the *tiers* of a web application have existed for two
decades in the "tierless" research lineage. What no prior language does is
make foreign *ecosystems* native territory, so that PyPI, npm, and the C
world arrive through a plain `import` with no wrapper to find, generate, or
maintain. Tiers are where the pain is most familiar. Ecosystems are where the
property earns its name.

Concretely, substrate transparency is why:

- **Placement is a modifier, not an architecture.** Where code runs is
  declared per-declaration (`cl { }`, `na { }`, a file suffix), never
  per-repository. Moving a function across the client/server boundary is an
  edit, not a rearchitecture. See
  [codespaces](what-makes-jac-different.md#1-how-can-one-language-target-frontends-backends-and-native-binaries-at-the-same-time).
- **Every ecosystem enters through the ordinary import.** PyPI, npm, and C
  libraries arrive via `import` with no binding generators or wrapper
  packages, because each codespace compiles into its host substrate as a
  first-class citizen: ordinary bytecode among bytecode, ordinary JavaScript
  among JavaScript, machine code with a C ABI. See
  [Import Anything](../reference/import-anything.md).
- **One declaration per contract.** A `node` declared once is the same type in
  the store, on the wire, and in the browser. The compiler owns every
  representation in between. Rename a field and every stale use in every tier
  is a compile error. In the conventional stack, that same rename is a textual
  search whose misses ship.
- **The toolchain is inside the language.** Version skew is a discontinuity in
  *time*: the same marshaling failure, with the filesystem as the wire format.
  The `jac` binary internalizes the interpreter, compilers, linker, package
  managers, server, and deployer under one content-addressed version. "Works
  on my machine" stops being a sentence with content. See
  [One Binary, Build Anything](one-binary.md).
- **Memory discipline is a dial, not a divide.** The split between managed
  languages and systems languages is a discontinuity like the rest, drawn
  where memory discipline changes. Jac's *gradual borrow checking* renders that line
  as a gradient within one checked medium: managed semantics by default,
  ownership adopted one declaration at a time, and a checked boundary
  mediating every value that crosses between the regimes. See
  [Gradual Borrow Checking](../reference/language/ownership-borrowing.md).
- **The LLM is a substrate too.** A hand-written prompt is glue: it restates
  your types in prose, nothing checks the restatement, and it silently rots
  when the code moves on. Jac's *meaning types* make the model a declared
  executor of an ordinary typed function. The prompt is derived from the
  program (names, types, `sem` annotations) so it cannot drift, and the return
  type is enforced as an output schema. See
  [byLLM](../reference/plugins/byllm.md).
- **The deployment is not the program.** One user or many, one machine or
  many, transient or persistent: the program text does not change (`jac run`
  -> `jac start` -> `jac start --scale`). This property is *scale invariance*,
  and deployment shape is a runtime concern, the way garbage collection is a
  runtime concern. See
  [the scale-invariance contract](../reference/plugins/jac-scale.md#the-scale-invariance-contract).

## The boundaries Jac refuses to hide

A famous 1994 critique of RPC systems observed that latency, partial failure,
and concurrency make remote interaction genuinely different from local
interaction, and that systems which paper over the difference collapse when
the difference asserts itself at runtime, at the worst moment. The synechic
answer treats that critique as a design rule rather than an objection. The key
insight is that the boundaries in modern software can be decoupled into 1)
representational boundaries, which are artifacts of description that a
language can dissolve, and 2) physical boundaries such as latency, partial
failure, and cost, which a language must surface rather than hide. We call the
second kind *lawful boundaries*.

> Dissolve every boundary that is an artifact of representation. Surface every
> boundary that is physics, as typed, visible semantics at the point where it
> exists.

This is why cross-tier calls are `async` (latency is real, so control flow
must acknowledge it), why write conflicts under concurrency surface as replay
or a typed error rather than silent corruption, and why data sharing across
users takes an explicit `grant`: isolation is the default geometry, and
sharing is the act that deserves ceremony. What is dissolved is the paperwork:
the duplicated schemas, the route strings, the serializers. What remains
visible is the world.

---

## Topokinetic

The second property inverts the deeper assumption. In every mainstream
language, the site of computation is fixed and data is delivered to it: from
memory to processor, disk to memory, database to application server, vector
store to prompt. The database ships rows to compute because computation cannot
go to the data. The cache exists to disguise the cost of the shipping.

A language is *topokinetic* if the mobile locus of computation over a topology
of data is a first-class semantic construct, inverting the von Neumann
convention of streaming data to a fixed site of computation. The name comes
from the Greek *topos*, place, and *kinesis*, motion. Where the inherited
question is "how do I bring the data here?", the topokinetic question is "how
does the computation get there?"

*Object-Spatial Programming* (OSP) is the concrete paradigm realizing
topokinesis: programs expressed as walkers traversing a persistent topology of
nodes and edges, with abilities triggered by arrival. Data lives as a
*topology* of typed nodes and edges, at once the program's data model and its
store. The unit of program is the *walker*, a typed, stateful locus that
travels along the topology. Code is dispatched by arrival: the runtime matches
the type of the arriving walker against the type of the node it lands on, and
either side of the encounter can declare what happens.

Three habits shift when we program this way:

1. **Relationships stop being encodings.** No follower-ID lists, no join
   tables: we draw a `Follow` edge, and the whiteboard diagram *is* the data
   model.
2. **Queries become paths.** "The tweets of everyone this user follows" is
   not a join to compose but a route to name:
   `[me->:Follow:->[?:Profile]-->[?:Tweet]]`.
3. **Algorithms become itineraries.** Instead of a procedure that branches on
   what it holds, a walker's abilities say what to do at each kind of place,
   and arrival does the dispatch.

The property pays off where the domain has shape: users, sessions, workflows,
knowledge, and above all agent memory. The standard memory-bearing AI agent is
a miniature fragmented stack: an app, a vector store behind an API, and
prompt-assembly glue between them. Object-spatially, an agent's memory is a
topology hung from the root, remembering is walking, and context assembly
becomes path selection in a language that has a semantics for paths. See
[Object-Spatial Programming](../tutorials/language/osp.md).

Persistence closes the loop, and the rule is one sentence: **whatever is
reachable from `root` persists.** The rule is called *persistence by
reachability*. There is no connection to open, no ORM, and no save call.
Durability is a property a datum has by where it stands, exactly as liveness
under garbage collection is a property of reachability from roots. One rule
decides what survives the past (collection) and what survives into the future
(persistence). And because every user of a served deployment is issued a root
of their own, isolation is not tenancy code. It is the shape of the graph. A
walker spawned at your root cannot wander into someone else's data because no
edge leads there.

---

## The two ideas compound

The two properties are independent. A language can be synechic and
conventional in its data model, and a language can be topokinetic inside a
single process. The *composition thesis* is that they compound: the deepest
dissolutions require both at once.

The disappearance of the database is the flagship example. A synechic language
without motion still calls a store that lives outside its semantics: one
discontinuity survives, and it is the one carrying the schemas, the
migrations, and the mapping layers. A topokinetic language without continuity
is a graph paradigm marooned inside one process: the topology dies with the
run, or is serialized across the same old seam. With both properties at once,
the topology is the data model and the store, it persists by reachability,
and the same program text serves one user or N. The database does not get a
better API. It stops existing as a separate system.

Jac is the first language that is a member of both classes, and every page of
this documentation is downstream of that claim.

---

## What stays visible

The claims above are bounded, and the bounds are part of the design:

- **The physics stays.** Latency, partial failure, and cost are not abstracted
  away. They are surfaced as `async`, typed errors, and explicit operational
  contracts, and scaling to more machines is paid for in machines.
- **OSP is a complement, not a replacement.** Jac is a full imperative
  language (a superset of Python's semantics), and programs with no graph in
  them are none the worse for the paradigm's presence. Walkers earn their keep
  where the domain has shape. A numerical kernel or bulk whole-graph analytics
  is better served by plain functions or a batch engine.
- **The binary is big on purpose.** It carries the same stack you would
  otherwise install piecewise, relocated into one file with one owner. What it
  eliminates is not disk usage but combinatorics: the version vector of your
  toolchain collapses to length one.

---

## The vocabulary

Every italicized term on this page has a canonical one-line definition in
[The Vocabulary of Jac](vocabulary.md), and the peer-reviewed foundations
behind the terms are collected on
[Research & Papers](../community/research.md).

## Next steps

- [Core Concepts](what-makes-jac-different.md): the practical tour of what
  these ideas become in the language
- [One App, Two Stacks](jac-vs-traditional-stack.md): the same argument, made
  by building one app both ways and counting
- [Build an AI Day Planner](../tutorials/first-app/build-ai-day-planner.md):
  every idea on this page in one guided project
