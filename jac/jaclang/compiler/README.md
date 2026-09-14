# The Jac compiler

This directory is the compiler: parsing, analysis, placement, and three code
generators. The pipeline, pass by pass, is documented in
[`cli/docs/internals/compiler_architecture.md`](../cli/docs/internals/compiler_architecture.md);
this file is the map of the tree and the rules that keep it organized.

## Layout

| Directory | Holds | Depends on |
|---|---|---|
| `frontend/` | Lexer, parser, the unified tree (`unitree`), roles and relations, source locations, diagnostics, per-node code info, and the module facts every later layer reads (`module_facts`, `const_fold`, `constant`) | nothing above it |
| `passes/` | Pass infrastructure (`transform`, `uni_pass`, `annex_weave`, `dataflow`) and the analysis passes: symbol tables, declaration matching, semantics, CFG, types, ownership, regions, capabilities, layout | `frontend`, `types` |
| `types/` | The type system and evaluator, compile-time values, the stub catalog, and the ambient `.pyi` surfaces | `frontend` |
| `placement/` | The placement solver: which module runs where, pins, workspaces | `frontend`, `passes` |
| `driver/` | `JacProgram`, `JacCompiler`, the schedules, module resolution, the caches (bytecode, interface, JIR), compile options | everything |
| `backends/common/` | What the generators share: the AST-gen base, the primitive emitter interfaces, the kernel unit lists, the format kernel | `frontend`, `passes` |
| `backends/py/` | Jac to JCIR to CPython bytecode | `backends/common` |
| `backends/es/` | Jac to ESTree to JavaScript, the client framework backends, view IR | `backends/common` |
| `backends/native/` | Jac to LLVM IR, the linkers (ELF, Mach-O, PE, wasm), the wasm runtime, and the in-tree LLVM binding (`llvm/`, a translation of llvmlite, see `llvm/LICENSE.llvmlite`) | `backends/common` |
| `tools/` | Formatter, linter, unparser, normalizer, doc IR, grammar extraction, code intelligence | `frontend`, `passes` |
| `tests/` | Cross-backend equivalence fixtures that ship with the package | |

The loose modules at this level are the native frontend kernel
(`jc_unit`, `jc_materialize`, `native_compiler`, `native_scope`: the parser
and its early analysis passes compiled natively and loaded as a shared library)
and registries shared by analysis and codegen (`symbol_utils`, `expr_keys`, `type_registry`,
`intrinsic_registry`).

## Native early analysis

When the driver knows a module's codespace before parsing, `jc_unit` runs the
existing `ASTValidationPass` and `SymTabBuildPass` after annex weaving, inside
the parse region. The tree and symbol graph cross into the host together.
Modules with wildcard imports defer symbol construction until the driver's
dependency resolver has made the imported names available. Parsing without a
compiler program, or without a known codespace, keeps the ordinary host schedule.

`PassResult` carries completed diagnostics and timing through the ordinary pass
driver, which applies diagnostic policy and records each pass once. Native field
and reference-container layouts come from the backend's ABI metadata;
`jc_materialize` preserves object identity when copying symbol indexes and edges.
Keep pass algorithms in `passes/`, and extend this shared boundary when another
pass moves into the kernel.

`scripts/native_compile_bench.jac` at the repository root measures uncached AOT
application builds with a warm compiler. Set `JAC_COMPILER_LIB` to each built
kernel when comparing revisions.

Measured on 2026-09-06 with `examples/chess/chess.jac`, Linux x86-64 on a
Threadripper 9980X: ten builds per kernel in two fresh-process batches, two
excluded warmups per batch, ordered baseline/new/new/baseline. Both kernels used
the same host compiler source; the baseline kernel predates native early passes.
Startup was excluded; application IR caching was disabled and linking included.

| Median | Parser-only kernel | Early-analysis kernel |
| --- | ---: | ---: |
| Full AOT build | 3.646 s | 3.537 s |
| AST validation (pass ledger) | 34.25 ms | 11.22 ms |
| Symbol construction (pass ledger) | 38.19 ms | 14.00 ms |
| Both passes combined (pass ledger) | 72.45 ms | 25.04 ms |

The observed total median improvement is 3.0%; the migrated passes are 2.9x
faster together. Total build ranges overlap (3.423–4.193 s baseline,
3.340–4.145 s new), so the end-to-end figure is a local measurement rather than a
guaranteed speedup. Both generated executables completed an automatic game.

## Native storage and temporary ownership

Native emitters register local storage through `NaIRGenPass._bind_local_slot`.
When a source name acquires a different native representation, the previous
slot and its ownership metadata remain in the existing frame cleanup. Entry
initialization makes cleanup safe on paths that skip either binding. Lexical
scopes use `_enter_bindings`, `_shadow_bindings`, and `_leave_bindings`; nested
functions use the corresponding function-state boundary.

`RcFactsPass` records early release by storage name. Every use of that name
constrains its lifetime, including uses through borrowed parameters and other
symbols that cannot independently request early release. Escaping bindings
retain the ordinary frame cleanup. A symbol's final use is insufficient when
another symbol lowers to the same storage name.

Owned expression temporaries use the same frame through `_borrow_owned_temp`
and `_release_temps_since`. Predicate operands and primitive receivers retain
their cleanup across exceptions; returning an input alias establishes its
ownership before the input temporaries are released. Primitive dispatch
evaluates the receiver once. Native ownership regressions check both destructor
counts and the existing debug allocation registry under reference counting and
cycle collection, so leaked container buffers and strings are covered too.

## Native hash containers

Dictionaries and sets share `backends/native/na_ir_gen_pass.impl/hash_core.impl.jac`
and `hash_order.impl.jac`. The order allocation contains `capacity` hash-slot
indices, `capacity` inverse slot-to-position indices, then one extent word.
Deletion marks its order position as -1 and trims trailing holes. Ordered reads
compact holes once; insertion also compacts when the order allocation fills.
Rehashing rebuilds both indices. This makes deletion amortized constant time,
preserves insertion order, and bounds order storage during repeated mutations.

`jc_materialize` decodes this private order storage when copying native
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
An executable request extends the live module's completed passes, including
for selfhost modules. Missing bytecode does not invalidate unchanged analysis.
Interface hashes describe declarations and exported types. Local escape,
stack-allocation, region-handle, and parameter-rebinding facts stay on the
analyzed tree; running lifetime analysis or code generation cannot change
an interface merely by filling in those facts.
Equivalent unknown types share their serialized identity, including their
diagnosed and incomplete flags; allocating another equivalent type object must
not change the exported interface.
Client invalidation removes the client section through the shared JIR writer;
it preserves executable and interface products. Closure publication prepares
all available interfaces before recording dependency hashes, then republishes
validated live executable products against that completed dependency set.
Preparation includes modules discovered while encoding another module's exports.
Completed diagnostic profiles remain owned by the module's analysis state while
dependency hashes are finalized and executable products are added. Source
invalidation and session eviction discard them through the shared task cleanup.
Application traversal batches this publication across its roots and contexts,
then publishes each completed context once. Single-module requests still publish
at their own boundary. Nested traversal shares the enclosing publication scope;
exceptions discard pending publication, and cancellation retains the registry's
normal eligibility checks.
Live source revisions use the same content and annex-membership identity as
disk products, so restored timestamps and deleted annexes cannot hide edits.
At an outer request, `JacProgram.refresh_compile_inputs` checks retained inputs
and invalidates affected dependents before serving products. Ordinary programs
and bounded sessions share this rule, including compile-time file dependencies.
Recursive compiler work and the process's executing compiler do not rescan the
closure on each import; source compilation owns its separate request context.
Executable requests preserve the producer's compilation options and context.
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
package retain their existing validation and source fallback.

`CompilationSession` owns a bounded set of context programs across roots.
Contexts share a `SourceStore` of unconsumed syntax from dependency discovery.
Compilation transfers each tree into its context's module hub and removes it
from the store. Compatible requests reuse that owned tree and its completed
products. An incompatible context parses its own tree; copying complete mutable
syntax graphs is not a prerequisite for compilation. Parser misses use the
existing native early-pass path when available. Evaluated trees, type memos,
catalog decodes, and product tasks belong to one context and worker. The default
budget is 256 source modules or 32 root requests. At a completed request,
reaching either budget, cancellation, or failure releases mutable analysis and
preserves compact interface products. A single dependency closure may exceed
the module budget while it is active; the precompile pool also retires workers
at its configured RSS limit. Neither bound interrupts an in-progress pass.

Source changes are checked at outer request boundaries and before publication.
The dependency graph records both imported modules and compile-time file reads.
Compile-time symbol resolution tracks visited import aliases and keeps its
recursion guard active through value evaluation. Cyclic reexports terminate
without a compile-time value; long acyclic chains resolve without a hop limit.
Type imports use the program's module hub and interface registry to resolve
cycles. An import encountered during cache validation can hydrate the module's
interface or enter its source pipeline; the evaluator does not replace an
in-progress module with an empty symbol table.
Successful outer analysis and executable requests publish their completed
interface cohort before returning, using the same publisher as precompile. This fills dependency
hashes that only become available when a cycle finishes, without rerunning
completed analysis. Failed or cancelled requests cannot publish that cohort.
An inferred native placement keeps the ordinary analysis interface unchanged,
but publishes its dependency records after the cohort's interface digests are
ready. A bytecode cache hit therefore has complete dependency proofs even when
the executable itself cannot publish an analysis interface.
An edit invalidates affected live products and their consumers. Disk replay uses
interface hashes for ordinary imports and content hashes for compile-time inputs,
so body-only edits retain the existing interface cutoff. Restored timestamps do
not establish freshness. Publication holds the JIR lock across validation and
merge; new dependency revisions cannot relabel older executable or diagnostic
products. Released trees cannot publish new analysis, even when their encoded
interfaces remain reusable.

Package precompilation plans work with this same dependency graph and module
resolver. Each strongly connected component runs its members in order as
separate jobs. The work pool releases a consumer only after its prerequisite
groups finish. Progress, failure reporting, and worker retirement operate
between members as well as between groups. Completed dependency
interfaces are published through `IfaceRegistry` before worker eviction. A
replacement worker hydrates those products; it never borrows another worker's
mutable tree or evaluator. Cold discovery retains at most the syntax budget,
so an evicted tree may be parsed again when a later product requires it.
Discovery and interface hydration use the compiler's common JIR lookup, including
validated artifacts restored into a fresh staging directory. Discarded syntax
uses the existing collection budget so cyclic trees do not accumulate behind
the compilation GC thresholds. The temporary planning session closes before
workers start, transferring only its bounded pristine syntax store.
Import discovery traverses the syntax without populating descendant indexes
on every retained node.

Before forking, precompile loads the shared compiler schedules and catalog once,
then releases completed compiler execution state. Automatic worker selection
uses at least the same memory budget as worker retirement; explicit worker
counts remain available for controlled measurements.
At a memory limit, workers collect released objects first, then evict the
session's retained trees and collect again before deciding to retire. This
also releases inherited discovery syntax: a planner cache larger than the
worker limit must not force a fresh worker for every subsequent module.

The compiler's execution program has a separate lifetime from owned source
sessions. Nested importer execution defers cleanup until the outer execution
returns, preserving live analysis needed by imports in progress.
A module compiled with the bootstrap IR schedule keeps that tier through
code generation even if the import cycle ends between those phases.

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

Build artifact identities, stage measurements, and the cold/warm validation
procedure are described in [`dist/payload/README.md`](../dist/payload/README.md).

Compile-time execution of user constructors follows the same demand/frame rule
as user functions. Speculative typing of a runtime constructor must not execute
its body, force its implementation dependencies, or record compile-time body
dependencies that disappear when the class is loaded from an interface.

## Rules

**Backends consume facts, they do not compute them.** Types are read from
`Expr.type`, symbols from `.sym`, layouts from the layout registry, and
module structure from `ModuleFacts`. `tests/compiler/test_backend_purity.jac`
scans the backends for analysis APIs and fails on any read that is not
sanctioned there with a reason. If a backend needs a fact, a pass stamps it.

**Shared code lives with the lowest layer that needs it, never in a sibling.**
A helper the passes and two backends all import belongs in `frontend/` or
`backends/common/`, not in the backend that happened to write it first.

**Every generator has the same shape.** One walker declaration
(`jcir_gen_pass.jac`, `esast_gen_pass.jac`, `na_ir_gen_pass.jac`) holds the
state fields and every method signature; the bodies live in
`<name>.impl/<concern>.impl.jac`, one file per concern (expressions,
statements, calls, declarations, module, and so on). There are no mixins and
no redeclared signatures.

**Where bodies go.** A declaration with one body file keeps it in
`impl/<module>.impl.jac`. A declaration with several keeps them in
`<module>.impl/<part>.impl.jac`. Nothing else.

**The bootstrap tier constrains imports.** `jaclang/bootstrap_manifest.py`
lists the modules the seed transpiler (`jac0`) compiles: the frontend, the
driver, placement, the Python backend and the pass bases. A seed module may
import a non-seed module only inside a function body, because a hoisted
import deadlocks bootstrap. That is why many imports in this tree are local
to the function that uses them; `scripts/check_seed_manifest.py` enforces it.

**Type checking.** `jac check .` runs in CI over the whole repository with
the exclusions in the root `.jacignore`. Every entry there is a debt with a
stated reason; the target is an empty file.
