# The Vocabulary of Jac

Jac's documentation introduces vocabulary the way the language's design does:
a small set of precise terms, each defined once on a canonical page and
repeated verbatim everywhere else. This page collects them in one place,
grouped in the order the argument builds them, one line apiece, with a link to
the page that carries each term's full statement. A star (★) marks the eight
terms coined in Jac's research literature. The defining pages remain the
arbiters; nothing here supersedes them.

## The diagnosis

| Term | Definition |
|------|------------|
| [**Discontinuity**](why-jac.md) | A boundary at which the representation of meaning must change and over which no verifier has jurisdiction; the site at which glue accrues and defects pool. |
| [**Glue**](why-jac.md) | Code or configuration whose sole purpose is to carry meaning across a discontinuity, adding no domain behavior of its own. |
| [**Substrate**](ideas-behind-jac.md#substrate-transparency) | A runtime, the ecosystem importable at it, and the toolchain that builds and ships for it. A tier is a substrate, a foreign ecosystem is a substrate, and the LLM is a substrate whose executor is stochastic. |
| [**Jurisdiction**](why-jac.md#why-this-matters-more-in-the-era-of-ai-authorship) | The reach of a verifier: the set of program points and crossings a compiler, type checker, or other static instrument can examine and reject. |
| [**Lawful boundary**](ideas-behind-jac.md#the-boundaries-jac-refuses-to-hide) | An essential boundary (latency, partial failure, cost, stochasticity) that a language must surface as declared, typed semantics rather than dissolve. |

## Synechism: the theory of continuity

| Term | Definition |
|------|------------|
| [**Synechic**](ideas-behind-jac.md#synechic) ★ | A language is synechic if it presents a single continuous semantic medium across conventionally discrete ecosystems, tiers, and toolchains, such that no program point requires glue code, marshaling, or interop scaffolding to cross a substrate boundary. |
| [**Substrate transparency**](ideas-behind-jac.md#substrate-transparency) ★ | The identity of the underlying runtime, ecosystem, and toolchain at any program point has no bearing on how the program is expressed. |
| [**Meaning types**](../reference/plugins/byllm.md) ★ | Semantic annotations from which prompts are automatically synthesized, making delegation of program logic to large language models (`by llm()`) a typed language feature rather than string engineering. |
| [**Gradual borrow checking**](../reference/language/ownership-borrowing.md) ★ | Memory discipline as a continuum within one language: managed semantics by default, ownership adoptable one declaration at a time, and a checked boundary mediating every value that crosses between the regimes. |
| [**Ownership dial**](../reference/language/ownership-borrowing.md) | The four-position surface through which gradual borrow checking is adopted, per module: managed, annotated, enforced, headerless, with guarantees strengthening monotonically. |
| [**Membrane**](../reference/language/ownership-borrowing.md) | The checked boundary between the owned and managed memory regimes, admitting exactly three crossings: sealing, reboxing, and exceptional abort. |

## Topokinesis: the theory of motion

| Term | Definition |
|------|------------|
| [**Topokinetic**](ideas-behind-jac.md#topokinetic) ★ | A language is topokinetic if the mobile locus of computation over a topology of data is a first-class semantic construct, inverting the von Neumann convention of streaming data to a fixed site of computation. |
| [**Object-Spatial Programming (OSP)**](../reference/language/osp.md) ★ | The concrete paradigm realizing topokinesis: programs expressed as walkers traversing a persistent topology of nodes and edges, with abilities triggered by arrival. |
| [**Node**](../reference/language/osp.md) | The archetype declaring an object that occupies a location in a topology: a place that knows when it is visited and can react. |
| [**Edge**](../reference/language/osp.md) | The archetype declaring a first-class, typed relationship between two nodes, with data fields and abilities of its own. |
| [**Walker**](../reference/language/osp.md) | The mobile locus of computation: an archetype carrying state, declaring location-triggered abilities, spawned onto a node and moved by `visit`. |
| [**Ability**](../reference/language/osp.md) | The unit of dispatch: a block of computation bound to an event of arrival or departure rather than to a caller's invocation. |
| [**Topology**](../reference/language/osp.md) | The live graph of typed nodes and edges over which walkers travel: at once the program's data model and its store. |
| [**Root node**](../reference/persistence.md) | The distinguished node anchoring every topology; reachability from it confers persistence, and each served user is issued a root of their own. |
| [**Persistence by reachability**](../reference/persistence.md) | The persistence rule of the topology: a datum is durable exactly while a path connects it to a root, the same reachability a tracing collector consults for liveness. |

## The machinery and the classes

| Term | Definition |
|------|------------|
| [**Polypiler**](one-binary.md) ★ | A compiler whose unit of compilation is the whole polyglot application, whose targets are ecosystems rather than instruction sets, and whose optimization surface includes the boundaries between them. |
| [**Codespace**](../reference/language/primitives.md) | The substrate assignment of a piece of code: server (`sv`), client (`cl`), or native (`na`), declared per-declaration, per-block, or per-file. |
| [**Scale invariance**](../reference/plugins/jac-scale.md#the-scale-invariance-contract) ★ | Program semantics are invariant under deployment-scale transformation: one user to N users, one machine to M machines, transient to persistent. |
| [**Single system image**](../reference/plugins/jac-scale.md#the-scale-invariance-contract) | The presentation of a collection of processes, machines, and users as one continuous machine: the same semantics at service scale as in a single-process script. |
| [**Composition thesis**](ideas-behind-jac.md#the-two-ideas-compound) | The claim that the synechic and topokinetic classes are independent in definition and compounding in value: the deepest dissolutions require a member of both at once. |

The peer-reviewed foundations behind these terms are collected on
[Research & Papers](../community/research.md).
