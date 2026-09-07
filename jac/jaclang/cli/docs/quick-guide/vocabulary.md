# The Vocabulary of Jac

Use this glossary when a design term appears in the documentation. The linked references explain implementation details and constraints. A star (★) marks terminology used in Jac's research discussions; these terms are optional background for learning to program in Jac.

## The diagnosis

| Term | Definition |
|------|------------|
| [**Discontinuity**](why-jac.md) | A boundary requiring a change of representation that the checking tools in use do not cover. |
| [**Glue**](why-jac.md) | Code or configuration whose sole purpose is to carry meaning across a discontinuity, adding no domain behavior of its own. |
| [**Substrate**](ideas-behind-jac.md#substrate-transparency) | A runtime, the ecosystem importable at it, and the toolchain that builds and ships for it. A tier is a substrate, a foreign ecosystem is a substrate, and the LLM is a substrate whose executor is stochastic. |
| [**Jurisdiction**](why-jac.md#why-this-matters-more-in-the-era-of-ai-authorship) | The reach of a verifier: the set of program points and crossings a compiler, type checker, or other static instrument can examine and reject. |
| [**Lawful boundary**](ideas-behind-jac.md#the-boundaries-jac-refuses-to-hide) | An essential boundary (latency, partial failure, cost, stochasticity) that a language must surface as declared, typed semantics rather than dissolve. |

## Synechism: the theory of continuity

| Term | Definition |
|------|------------|
| [**Synechic**](ideas-behind-jac.md#synechic) ★ | A language class characterized by continuity of program expression across runtimes, ecosystems, and toolchains, with language-level support for crossing their boundaries. |
| [**Substrate transparency**](ideas-behind-jac.md#substrate-transparency) ★ | The extent to which a language handles substrate differences without application-specific adapters. |
| [**Meaning types**](../reference/plugins/byllm.md) ★ | Semantic annotations from which prompts are automatically synthesized, making delegation of program logic to large language models (`by llm()`) a typed language feature rather than string engineering. |
| [**Gradual borrow checking**](../reference/language/ownership-borrowing.md) ★ | Memory discipline as a continuum within one language: managed semantics by default, ownership adoptable one declaration at a time, and a checked boundary mediating every value that crosses between the regimes. |
| [**Ownership dial**](../reference/language/ownership-borrowing.md) | The four-position surface through which gradual borrow checking is adopted, per module: managed, annotated, enforced, headerless, with guarantees strengthening monotonically. |
| [**Membrane**](../reference/language/ownership-borrowing.md) | The checked boundary between the owned and managed memory regimes, admitting exactly three crossings: sealing, reboxing, and exceptional abort. |

## Topokinesis: the theory of motion

| Term | Definition |
|------|------------|
| [**Topokinetic**](ideas-behind-jac.md#topokinetic) ★ | A language is topokinetic if the mobile locus of computation over a topology of data is a first-class semantic construct, inverting the von Neumann convention of streaming data to a fixed site of computation. |
| [**Object-Spatial Programming (OSP)**](../reference/language/osp.md) ★ | The concrete paradigm realizing topokinesis: programs expressed as walkers traversing a topology of nodes and edges, with abilities triggered by arrival. |
| [**Node**](../reference/language/osp.md) | The archetype declaring an object that occupies a location in a topology: a place that knows when it is visited and can react. |
| [**Edge**](../reference/language/osp.md) | The archetype declaring a first-class, typed relationship between two nodes, with data fields and abilities of its own. |
| [**Walker**](../reference/language/osp.md) | The mobile locus of computation: an archetype carrying state, declaring location-triggered abilities, spawned onto a node and moved by `visit`. |
| [**Ability**](../reference/language/osp.md) | The unit of dispatch: a block of computation bound to an event of arrival or departure rather than to a caller's invocation. |
| [**Topology**](../reference/language/osp.md) | The live graph of typed nodes and edges over which walkers travel: at once the program's data model and its store. |
| [**Root node**](../reference/persistence.md) | The distinguished entry node for a graph context; in a served application, user roots also organize persistent data and access. |
| [**Persistence by reachability**](../reference/persistence.md) | Promotion of transient graph objects when they become reachable from persistent graph state in a persistence-enabled context. Later disconnection alone does not delete a persisted object. |

## The machinery and the classes

| Term | Definition |
|------|------------|
| [**Polypiler**](one-binary.md) ★ | A compiler whose unit of compilation is the whole polyglot application, whose targets are ecosystems rather than instruction sets, and whose optimization surface includes the boundaries between them. |
| [**Codespace**](../reference/language/primitives.md) | The execution assignment of code: server (`sv`), client (`cl`), or native (`na`), inferred by the compiler or constrained through placement configuration. |
| [**Scale invariance**](../reference/plugins/jac-scale.md#the-scale-invariance-contract) ★ | Program semantics are invariant under deployment-scale transformation: one user to N users, one machine to M machines, transient to persistent. |
| [**Single system image**](../reference/plugins/jac-scale.md#the-scale-invariance-contract) | The presentation of a collection of processes, machines, and users as one continuous machine: the same semantics at service scale as in a single-process script. |
| [**Composition thesis**](ideas-behind-jac.md#the-two-ideas-compound) | The thesis that the independent synechic and topokinetic properties offer additional benefits when combined. |
| [**Workspace**](../reference/apps.md) | One project holding several apps over one body of shared code, type-checked as a single program; a project with no `[apps]` table is the degenerate case of one implicit app. |
| [**App**](../reference/apps.md#the-appsname-table) | An `[apps.<name>]` table in `jac.toml`: a project kind plus a root (a directory, or a single entry file) that says what it builds and which modules are its. |
| [**Shared code**](../reference/apps.md#dir-rooted-file-rooted-and-shared) | A module under no app's root; any app may load it in-process, none owns it, and it never imports from an app. |
| [**Owner**](../reference/apps.md#ownership-one-owner-per-server-placed-shared-module) | The one serving app whose server runs a server-placed shared module's walkers and persisted archetypes, so every other app bridges to the same place. |
| [**Bridge surface**](../reference/apps.md#the-app-dependency-graph) | The walkers and `def:pub` functions of an app: the only things another app may call, compiled as a call across the boundary rather than an in-process reference. |
| [**App facts**](../reference/placement.md#app-facts) | What the driver stamps onto every module from `jac.toml` (its app, root, kind, owner) so that no compiler pass reads configuration. |

The peer-reviewed foundations behind these terms are collected on
[Research & Papers](../community/research.md).
