# Compiler infrastructure

Start at `api.jac` for consumer requests and `pipeline/schedule.jac` for execution
order. The graph vocabulary starts at `ir/schema.jac`. Pass implementations live
with the algorithms they execute, rather than in one flat pass directory.

| Package | Responsibility |
| --- | --- |
| `pipeline` | Typed pass/product contracts, registration, execution, progress and result ownership |
| `session` | Application and target contexts, source revisions, module loading, dependency records and persistence |
| `ir` | Shared graph schema, checked mutation and graph-derived accessors |
| `frontend` | Parsing, source positions, native parser adapter and graph materialization |
| `analysis` | Binding, placement, types, flow, memory ownership, capabilities, boundaries, interfaces and compile-time evaluation |
| `lowering` | Structural lowering, layout and MTIR |
| `backends` | Python, ES and native code generation and target artifacts |
| `bootstrap` | Compiler self-loading, catalog acquisition and native kernel scope |
| `tools` | Formatting, linting, documentation and graph inspection |
| `jaclang/build` | Application inventory and assembly/publication of prepared artifacts |

## Requests and passes

```mermaid
flowchart TD
    Consumer[CLI / LSP / build / HMR] --> API[compiler.api]
    API --> Session[Selected application and target context]
    Session --> Source[Reuse pristine source revision]
    Source --> Graph[Contextual analyzed graph]
    API --> Registry[pipeline.schedule]
    Registry --> Executor[pipeline.executor]
    Executor --> Pass[Registered analysis / lowering / backend pass]
    Pass --> Graph
    Pass --> Prerequisite[Require prerequisite product]
    Prerequisite --> Executor
    Executor --> Store[pipeline.products]
    Store --> Consumer
```

`schedule.jac` owns phase ordering, product prerequisites, pass factories and
query factories. A consumer requests a product; it does not instantiate a pass
or assemble a private list. `executor.jac` establishes diagnostic, artifact and
mutation scopes and reports progress. Its shared compilation resource scope
applies the compiler's GC thresholds and restores the caller's settings.
Compilation, scheduled passes and queries, and application preparation use
this scope, including the work between module compilation and artifact collection.
`products.jac` tracks task outcomes,
dependencies, versions and invalidation. `request.jac` advances a module request
through the selected schedule.

The symbol-only schedule leaves compile-time imports as interfaces. Full
compilation loads their bodies in `ComptimeImportsPass`; a scheduled type query
that actually evaluates a compile-time value can demand its source through the
existing evaluator. Merely discovering symbols does not load unused bodies.

`PassIdentity`, `CompilationProduct`, `AnalysisFact`, `PassSpec` and `QuerySpec`
make the execution contract explicit. `ProductKey[T]` pairs a product identity
with its result type. Analyses receive `AnalysisServices`; application
orchestration uses `JacProgram`. Semantic service interfaces do not expose an
unrestricted compiler implementation.

## Graph domains

```mermaid
flowchart LR
    Syntax[ir/syntax] -->|binding relations| Symbols[ir/symbols]
    Syntax -->|type relations| Types[ir/types]
    Syntax -->|placement relations| Placement[ir/placement]
    Flow[ir/flow] -->|control-flow relations| Flow
    Schema[ir/schema catalog] -. validates .-> Syntax
    Schema -. validates .-> Symbols
    Schema -. validates .-> Types
    Schema -. validates .-> Placement
    Schema -. validates .-> Flow
```

These are domains of one shared graph. Node declarations define capabilities;
edge declarations name their Jac endpoint types. The schema catalog derives
endpoint descriptors and adds multiplicity, ordering, lifetime and relation
family metadata. Graph identity and mutation permits live in `ir/identity.jac`.
Accessors check graph ownership and write authority before changing relations.
Their generation-tagged caches are derived views, not semantic producers.

Declaration identity reconstructed from an interface or library catalog is
persistent semantic data. `ClassDetailsShared.declaration_identity` preserves
that origin even when the catalog supplies a placeholder scope. The separate
`_identity_key` cache is only a derived view of a live declaration; clearing it
or changing unrelated type relations cannot change a catalog type's identity.
MRO linearization compares this declaration identity, so independently hydrated
copies of one ancestor occupy one position in the inheritance order.

Structural role replacement checks every proposed connection before removing
the previous edges. Its validation phase uses the same typed endpoint checks
as insertion. Product cleanup also tolerates nested graph collection: a
weak-reference callback queues its removal while another sweep is active.

IR code may navigate existing structure and facts. It may not import analysis
implementations, acquire a compiler session, resolve dependencies or infer a
missing type. A property that needs new semantic work becomes a scheduled query.
Backend output belongs to the context's artifact store, not to the syntax base.

`session/sources.jac` shares pristine syntax by content revision, including
annexes. Different application or target contexts receive distinct mutable
graphs. A graph cannot be silently adopted by an unrelated session. Releasing a
context releases its products and artifacts without invalidating another
context's graph.

A symbol-only request cannot reuse a graph transformed by inferred native
placement. The request creates a fresh graph from the pristine source revision
and runs its scheduled analysis; it does not parse that source again. Packaging
can therefore produce bytecode first and still publish the ordinary import
interface afterward.

`session/context.jac` distinguishes graph identity from artifact identity.
Entry points keep separate mutable graphs, while disk artifacts are reusable
across entries with the same application, placement defaults, framework, and
code-generation settings. Loading an interface creates a graph in the requesting
context; it does not share another context's live objects.

An interface lookup prefers a valid local interface, but a local bytecode-only
record cannot hide the interface in a sealed SDK image. Packaging consumes the
same selected metadata and rebases its paths for the destination package.
Member lookup stops at an ordinary local declaration. Conditional child scopes
are searched when the name is absent locally or when a local overload set can
merge with conditional overloads.

Type lookup consumes these interfaces even for compile-time imports; evaluating
a compile-time value requests the producer's body separately.

Packaging retains the self-host compilation closure until both bytecode and
interface metadata are collected. Native artifacts are retained normally;
only graph release is deferred. A symbol request can reuse the compatible
compiled graph in that same self-host context, and the packaging unit releases
its graphs afterward.

Application **context** selects the app's entry and boundary rules. **Placement**
describes participating codespaces. **Ownership** is reserved for memory and
borrowing analysis.

## Persistence and bootstrap

Interface and artifact codecs under `session/cache` consume prepared records.
Interface preparation belongs to `analysis/interfaces`; dependency loading
belongs to `session/imports`. Cache decoding reconstructs graph data within the
selected mutation scope and does not substitute a graph from another context.
Interface hydration restores application context without walking transitive
class references. The session resolver loads missing referenced modules through
the compilation pipeline and requests the scheduled `TypeQueryPass` when a
source class's type is missing. Catalog providers
continue to decode their recorded types without running semantic analysis.
Dependency interfaces are requested after symbol discovery returns, so an
import cycle cannot publish a partially resolved inheritance chain.

The native parser adapter consumes the central schema and registered early-pass
bits. `jaclang/bootstrap_manifest.py` is the minimal Python seed boundary needed
before Jac imports work. Bootstrap support does not create another semantic
schedule. Native kernel runtime units are compiled in the requesting context;
their analyzed graphs are not process-global cached objects.

Known server-hosted library sources use the native early passes for symbol
imports, including imports in explicit server compilations. Each request
receives a fresh graph and its own mutation authority. Full compilation
targets, client/native imports, and nested applications keep the ordinary
source pipeline. The executor consumes early results under the same pass
contracts rather than repeating those passes in Python.

OSP records and analysis helpers live in `analysis/binding/osp_facts.jac` and
`osp_model.jac`. Scheduled ES and native passes produce separate models for
their codespaces. The runtime owns dispatch and graph operations, not compiler
analysis. Its native graph ABI uses integer object handles; native code
generation converts traversal results to language pointer lists before
iteration, filtering or field access.

The full design and acceptance requirements are in
[`docs/architecture/compiler-reorganization.md`](../../../docs/architecture/compiler-reorganization.md).

## OSP algorithms and graph storage

Declare endpoint types on the edge, then express relationships through OSP
references and connections. For example, `scope +>:ScopePrimary:+> binding`
and `binding +>:BindingTarget:+> symbol` construct a named binding;
`[scope->:ScopePrimary:->->:BindingTarget:->]` reads its symbols. Name lookup
retains a graph-derived index because repeated lookup must not scan a scope.

Connections have one commit hook on `GraphNode`, which checks relation
cardinality and mutation authority and adopts previously unclaimed nodes.
Replacement accessors preflight every proposed target before deleting existing
relations. `CollectUnclaimed` validates a reachable graph through typed walker
abilities, then its caller commits the collected claims. `ValidateGraph` also
uses an OSP traversal with an explicit visited set. These operations enforce IR
integrity; they do not perform semantic analysis or schedule compiler passes.

Semantic node handling belongs in abilities on the relevant node types.
`NativeBlockerScan`, invoked by scheduled placement work, receives candidates
from the syntax index and handles imports, abilities, root references, and
server-only constructs through typed abilities. The enclosing analysis preserves diagnostic priority
and publishes the result through the scheduled product/query infrastructure.
`ElementReferenceScan` resolves each name once to collect both references and
function escapes. Its declaration-to-element map lives only for that summary,
so a later binding or structure change cannot reuse stale associations.
`BindingFactsPass` likewise seeds typed scope/name abilities from the syntax
index, then dispatches the collected `Symbol` nodes for storage and binding
classification. It avoids a separate walk of every syntax node.
Import classification computes the module's client-context flag once per
analysis traversal, rather than rescanning the module body for each import.

`ir/syntax/cloning.jac` is the storage boundary for copying validated syntax.
It preserves endpoint types, edge ordering, and shared children while creating
fresh anchors and incoming weak references. It excludes analysis relations.
Copying assigns the destination context and clears derived state, avoiding
separate adoption and thaw traversals. Pristine source freezing and authority
assignment likewise share one checked traversal.

Runtime optimizations preserve the OSP surface: the traversal kernel caches
ordered callback plans, and the seed compiler lowers indexed first/last graph
references without allocating an intermediate list for simple transient hops.

## Native hash containers

Dictionaries and sets share `backends/native/na_ir_gen_pass.impl/hash_core.impl.jac`
and `hash_order.impl.jac`. The order allocation contains `capacity` hash-slot
indices, `capacity` inverse slot-to-position indices, then one extent word.
Deletion marks its order position as -1 and trims trailing holes. Ordered reads
compact holes once; insertion also compacts when the order allocation fills.
Rehashing rebuilds both indices. This makes deletion amortized constant time,
preserves insertion order, and bounds order storage during repeated mutations.

`frontend/kernel/materialize` decodes this private order storage when copying native
dictionaries. Keep its decoder synchronized with changes to this allocation;
the container field offsets still come from the backend's ABI metadata.
The native dictionary scaling, mutation, and materialization tests cover these
contracts.

## Packaged interfaces and compilation lifetimes

Precompilation requests an analysis interface through the dependency registry
before generating bytecode through the existing pipeline. Packaging explicitly
initializes the existing interface codec: the separate bootstrap finalization
process does not otherwise load it during symbol-only compilation. The registry's
non-importing readiness check remains safe during compiler bootstrapping.
The precompiler also activates the existing stub catalog before sealing
symbol-only selfhost units, so cross-references to conditional stub classes
resolve through the same authority used by application analysis.
Payload assembly builds this catalog from staged sources before precompilation
and bootstrap finalization. Its recursion guard belongs only to catalog
construction; interface encoding must be able to open the completed catalog.
Sealing preserves the interface, dependency hashes,
diagnostic profiles, and placement facts, including for bootstrap modules
whose executable bytecode is produced by jac0. A bytecode-only cache is
upgraded through `IfaceRegistry` instead of introducing a second analyzer.
Normal code generation keeps its existing interface policy.
Bytecode loads establish their own compilation request, including when a
type check lazily loads compiler code. The caller's analysis and full-tree
requirements resume after the bytecode load and do not force interface
encoding into that executable build.
An application's analysis request also does not implicitly publish interfaces
for symbol-only selfhost dependencies covered by the compiler fingerprint.
Their types remain available on demand; packaging requests the interface
product explicitly through the same registry. Other bundled libraries keep
their dependency interfaces because their sources are outside that fingerprint.
Interface preparation, replay, and persistence share one source eligibility
rule. Typed Python packages and type stubs remain content-fingerprinted
dependencies; explicitly requesting an interface does not force their lazy
imports into a recursively encoded package closure.
Loading a dependency-validated interface also seeds the registry's encoding
memo. A consumer that needs the source tree can still run its requested
passes without re-encoding that unchanged interface and its dependency closure.
Include bindings own local declaration nodes and retain the original symbol's
lazy provider. Already-local symbols keep their existing bindings: copying
them during a self-include would append to the overload list being traversed.
Foreign declarations are never rebound. Interface
encoding takes an alias category from its resolved definition, keeping hashes
stable when later imports refine that definition.

Interface paths are encoded relative to their source module before hashing.
JIR's `SEC_PATH_ROOT` records the local base directory; sealed packages store
only its relative location inside the package. The dependency, interface,
diagnostic, and placement readers relocate path fields to the installed root
without changing interface hashes or literal text. Identical staged packages
therefore produce identical artifacts. Reused bytes
keep their path mapping through local cache writes and subsequent packaging. Diagnostic
profile and dependency checks still govern reuse. Dependencies outside the
package retain their existing validation and source fallback. References into
the running SDK use `<jaclang>/` paths, resolved against the installed SDK,
so a temporary runtime extraction directory cannot change a bundle's digest.
Packaging requests bytecode before its interface, allowing the interface pass
to reuse the compiled graph instead of preparing a separate symbol graph first.

A hydrated interface installs its contextual facts once per graph. Placement
tracking preserves an existing summary when first indexing a source graph;
refresh after a structural change invalidates the summary before reindexing.
Catalog graphs rebuild summaries for placement walks because serialized
element indices describe the original source body.
Lazy name lookup preserves the catalog's declaration order when the full
namespace is materialized, so constructor parameters do not depend on which
field a caller queried first.
Symbol-only diagnostic profiles omit lint selection because their schedule
does not run the lint pass. Full analysis retains lint policy in its profile,
and both profiles retain diagnostic suppression settings.

Per-unit release keeps parsed stub trees while a compilation uses them.
The runtime graph driver indexes anchors with non-owning handles, including
inside an execution context. Node and edge references keep reachable topology
alive, and the persistence store owns stored anchors. When the last owner
releases a component, weak-handle callbacks retire its kernel rows and recycle
its handles. Closing a context also retires its region, even for graph objects
still held by callers. Handle metadata uses a slotted weak reference with a
shared callback, avoiding a closure and captured cells for every anchor.
At a completed compilation boundary, `release_compile_state` releases both
source and stub roots. Activating the stub catalog also retires the private
selfhost bootstrap closure before application compilation starts; it never
changes the stub lens of an active application compilation.
