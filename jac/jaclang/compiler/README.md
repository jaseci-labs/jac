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
| `backends/common/` | What the generators share: the primitive emitter interfaces and their dispatch tables, the kernel unit lists, the format kernel | `frontend`, `passes` |
| `backends/py/` | Jac to JCIR to CPython bytecode | `backends/common` |
| `backends/es/` | Jac to ESTree to JavaScript, the client framework backends, view IR | `backends/common` |
| `backends/native/` | Jac to LLVM IR, the linkers (ELF, Mach-O, PE, wasm), the wasm runtime, and the in-tree LLVM binding (`llvm/`, a translation of llvmlite, see `llvm/LICENSE.llvmlite`) | `backends/common` |
| `tools/` | Formatter, linter, unparser, normalizer, doc IR, grammar extraction, code intelligence | `frontend`, `passes` |
| `tests/` | Cross-backend equivalence fixtures that ship with the package | |

The loose modules at this level are the compiler kernel (`jc_unit`,
`native_compiler`, `native_scope`: analysis and code generation compiled
natively and loaded as a shared library) and registries shared by analysis and
codegen (`symbol_utils`, `expr_keys`, `type_registry`, `intrinsic_registry`).

## The compiler kernel

`native_scope.jac` lists the compiler modules the kernel links; each is an
ordinary native unit, and `jc_unit.jac` is the root that exports the entry
points. The kernel answers two requests, each a call and a take:

- `jc_analyze` / `jc_take_analysis` run the analysis pipeline over a module and
  return its diagnostics and per-module facts (`frontend/kernel_analyze.jac`).
- `jc_compile` / `jc_take_compile` run the same session through code
  generation and return each unit's compile products
  (`driver/unit_products.jac`): the JCIR bytes, the MTIR graph, the interop
  manifest, the client artifact, the placement summary and the comptime
  dependencies.

Nothing tree-shaped crosses. A session starts from a `KernelInputs` record
holding the facts every compile needs (the request, project defaults, layout
tables, the stub catalog's location) and the kernel's `KernelHost` answers
`HostServices` from it. When the pipeline asks something the record does not
hold yet (an import's resolution, a path's project, the interface of a Python
or `jaclang` module), the kernel calls the host through the session's asker
(`project/kernel_snapshot.jac`), merges the answer into its inputs and carries
on. A compile is one kernel run: the host does not parse the program to guess
at questions, and nothing is run again. A question the host cannot answer
raises `HostOnlyError`, the request reports a miss, and the compile fails:
with a kernel present the host never compiles a program module in its place.
Results come back as JSON records; the host assembles JCIR into bytecode,
restores the other products through the same path a JIR cache hit takes, and
writes the module JIR. A session emits a unit for every module it analysed
that has no cached products, so importing a program compiles its closure once
(`kernel_compile_application` does the same for an application).
`JAC_KERNEL_COMPILE=inprocess` runs the kernel's code under Python for tests.

Keep pass and generator algorithms in `passes/` and `backends/`. To move a
module into the kernel, add it to `native_scope.jac` and make it lower: a walker
ability that fails to lower fails its unit and every importer, while a function
that fails demotes to an abort stub the kernel must never reach. A new host
question belongs on `HostServices`, with a `KernelInputs` field that holds
its answer and a branch in the session's asker that produces it.

## Native hash containers

Dictionaries and sets share `backends/native/na_ir_gen_pass.impl/hash_core.impl.jac`
and `hash_order.impl.jac`. The order allocation contains `capacity` hash-slot
indices, `capacity` inverse slot-to-position indices, then one extent word.
Deletion marks its order position as -1 and trims trailing holes. Ordered reads
compact holes once; insertion also compacts when the order allocation fills.
Rehashing rebuilds both indices. This makes deletion amortized constant time,
preserves insertion order, and bounds order storage during repeated mutations.

Dictionary lookup exposes a borrowed value slot: a null slot means the key is
absent, while a present slot can contain zero or `None`. Native `dict.get()`
uses this shared lookup to search once and then apply its default-value rules.

The container field offsets come from the backend's ABI metadata. The native
dictionary scaling and mutation tests cover these contracts.

## Native edge type values

Graph operations accept edge classes passed as `type[Edge]` or a narrower
bound. `backends/native/na_ir_gen_pass.impl/edge_types.impl.jac` resolves these
values using the existing native class-name identity. The shared graph runtime
in `runtime/osp_graph.jac` registers each edge's tag and default-constructor
callback. Literal edge classes retain constant-tag lookup; dynamic filters use
the same subtype matching as literal filters.
Dynamic connections resolve one descriptor and reuse its tag and constructor;
the registry lookup also validates that the class is a registered edge type.
An unbounded class value uses `Edge` as its layout bound; its runtime class
identity still determines the registered descriptor.

Constructor callbacks use ordinary object construction, including inherited
defaults, initialization, and region allocation. Types that require arguments
remain usable for filtering; connecting through their bare class raises an
error. A factory result of zero signals that construction without arguments
is unavailable, rather than representing a graph handle. Generated calls
propagate pending errors even when there is no source declaration for the callee. Predicate fields and edge-ref element types come from the declared class
bound. Keep these semantics in the type evaluator, native lowering, and graph
runtime so callers such as `UniNode` can use ordinary graph operations without
maintaining lists of concrete edge classes.

Factory callbacks use the ordinary Jac closure representation, including when
stored in object fields. Callable parameters, fields, and calls must agree on
that representation; raw function pointers belong to the explicit C interop
path. Graph references restore their inferred list element type at the native
runtime boundary, so indexing, iteration, and spreads share normal list lowering.

`Kid` declares `UniNode` endpoints in `frontend/roles.jac`. This keeps direct
child traversals typed without a wrapper property. Its endpoint annotations
use a type-only import; the seed compiler erases these
annotations, so they introduce no runtime import cycle.

## Native construction from class values

Calling a class value, `kind(args)` where `kind: type[B]`, or `new(kind, ...)`
lowers natively for obj, node, edge, and walker archetypes. The arguments bind
against `B`'s constructor signature, the contract the type checker enforces:
`B`'s initializer parameters when an initializer is found through its MRO,
otherwise its initializing `has` fields. `**` may unpack one str-keyed mapping;
its keys must name parameters of that signature. The implementation lives in
`backends/native/na_ir_gen_pass.impl/class_ctors.impl.jac`.

Each module emits a construct entry for every archetype it declares. The entry
takes a presence mask followed by the class's own constructor parameters.
Omitted parameters use the class's own defaults, including overridden field
defaults; an omitted required parameter raises `TypeError`. The entry then
performs ordinary construction, including allocation, vtable, OSP tags,
initializer, and postinit. For each ancestor, the module also emits a bridge
from the ancestor's signature to the class's entry. When both signatures match,
the entry is used directly. A class cannot bridge from an ancestor when its
extra parameters are required or it lacks one of the ancestor's required
parameters. Parameter types must also agree. Such a class is not registered
for that ancestor, so construction through `type[ancestor]` raises `TypeError`,
as it does in the Python tier. An ancestor parameter that the class does not
accept raises only when the call supplies it.

Entries are published in a class record keyed by native class-name identity: the
same FNV name hash and address-then-`strcmp` name comparison used by
`isinstance`. Each record lists `(ancestor, entry)` pairs. Its module
initializer adds the record to the weak, program-wide `__jac_class_ctors` bucket
table, similar to edge-descriptor registration. This works across separately
compiled units and in closed-world kernel links: a subclass declared in another
module registers itself. A call site hashes the runtime class name, finds the
record, selects the entry for the static bound, and calls it. Arguments are
borrowed; the entry retains what it stores, and the call site releases its
owned temporaries after the call, like an ordinary constructor call. An entry
whose construction cannot lower is discarded and its diagnostics are rolled
back; the class is simply not constructible through a class value.

Construction binds arguments by name. A subclass initializer that renames a
positional parameter is therefore incompatible, although Python would accept
the positional call. Initializers that take `*args` or `**kwargs`, generic
archetypes, and Python-side bases are not supported; calls through those bounds
report E5092. Classes with the same name in different modules share one
identity, as they already do for `isinstance`. Zero-argument edge factories
still use the separate edge-descriptor registry.

Class records are built by walking each ancestor's recorded MRO in turn. A
subclass of an imported class can have a recorded MRO that stops at its
immediate base. Walking each recorded MRO still gives the subclass a bridge for
every ancestor.

Because a class value is its class-name identity, `kind.__name__` lowers to the
class value itself. `Name.__name__` lowers to the name constant, and
`type(x).__name__` still reads the object's class id. A walker built from a
class value spawns through the existing OSP path: `mod spawn kind(module=mod,
ctx=ctx)` takes the static bound's type-tag slot, which subclasses share by
layout prefix. The runtime tag then selects the runtime class's descriptor,
including inherited abilities and node abilities triggered by marker bases such
as `TreeWalker`. A walker typed only as `Walker` has no statically known
tag slot. For OSP archetypes, the class record also stores the stable OSP tag.
Spawn reads the object's runtime class name from its allocation header, finds
the record, and dispatches on that tag. An unregistered class raises
`TypeError`.

## Delete-target validation

`DeleteStmt.invalid_target` classifies one target's invalid syntax using
`DeleteTargetError`: literals, empty target lists, null-safe access, and
unpacking. It unwraps parentheses; callers recurse into nonempty target lists.
AST validation owns the corresponding diagnostic messages. Type checking uses
the same classification to skip the graph-destruction check on invalid syntax,
while continuing to check valid value targets. For example, `del *ints()` gets
an unpacking error, while `del ints()` gets a graph-type error when `ints()`
returns `list[int]`. Improving expression inference must not introduce a second,
dependent diagnostic for an already-invalid delete target.

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
package retain their existing validation and source fallback.

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

**Type checking.** `jac check .` runs in CI over the whole repository. It
reads its exclusions from `[check] exclude` in the root `jac.toml`, so CI, the
precommit hook and a local run apply the same policy. Every path entry there is
a debt with a stated reason; the target is a list holding only the test trees.
