# Native Units

Every native module owns a reusable compilation unit, and every native
artifact is a link of units. This page records the design behind
`compiler/backends/native/link_plan.jac`, `link_glue.jac`,
`kernel_resolve.jac`, `driver/nativecache.jac` and `driver/native_iface.jac`,
and the reasons that shaped it. The [native pathway reference](../reference/language/native-pathway.md)
describes the user-facing surface; the [analysis cache](analysis-cache.md)
page describes the JIR sections the interface layer owns.

## The unit

A native unit is one module analyzed in a build-owned compiler session. Its products
live in the module's JIR entry, beside the bytecode the compiler runs for
the same file, under `MODKEY`. Each native section holds a map of stamped variants:

| Section | Holds |
|---|---|
| `SEC_NIFACE` | The unit's native interface, 64-hex digest prefixed like `SEC_IFACE` |
| `SEC_NOBJ` | The relocatable object, compiled position-independent, small code model |
| `SEC_NBITCODE` | The unit's optimized bitcode |
| `SEC_NDEPS` | The native-interface digest of every unit it was compiled against |
| `SEC_NCTDEPS` | Compile-time inputs, using the shared CTDEPS encoding under a native stamp |

The stamp (`NativeStamp`) names the compiler digest, the codegen identity
(gc mode, target, opt level and the rest of `CompileOptions.codegen_identity`)
and the triple. Readers select the matching variant; different options and
targets coexist without evicting one another. A compiler upgrade discards
obsolete compiler variants. Only a native compile writes these five sections;
a bytecode compile of the same file merges around them. The shared bootstrap-safe
file lock covers the complete JIR read/merge/replace transaction, so concurrent
writers preserve one another’s products. JIR format 28 makes this a clean
cache-format break. That is why the native
digests have their own section: when they lived in `SEC_DEPS`, every
bytecode compile of a unit rewrote the rows without them and the next link
plan recompiled the whole closure.

### The interface

`NativeIface` is everything a consumer links against: exports (symbol,
kind, parameter and return types, default argument tokens, ownership convention, `:pub`), class
layouts, enums, the initializer and entry symbols, the demoted function
set, clib paths, the module layout, and the dependency edges. Its digest
covers all of that except the edges and coverage. So an ordinary body edit or a renamed
local leaves the digest alone and rebuilds one
object; a new or removed export, a changed signature or ownership
convention, a changed layout, a new enum member, or a gained or lost
initializer moves it and rebuilds dependents. Default expressions are part of the source
contract because callers embed them; binary signature equality alone is not
enough. Imported generic bodies use the shared compile-time dependency
encoding in stamped `SEC_NCTDEPS`, including their implementation annexes. Codegen options never enter
the digest: the stamp carries them.

Symbols that are not `:pub` are module-qualified, `<prefix>.<name>`, where
the prefix is the native-safe form of the module key; `:pub` symbols keep
bare names, and only two `:pub` exports of one name in one link collide.

Bundled `na_stdlib` shims retain qualified symbols even for their public
Jac APIs. Their public names (for example `hashlib.new` and `hmac.new`)
belong to separate library modules and are not bare C ABI exports.

The prefix is keyed on the module's identity within its package, not on its
absolute path: a module under a sealed package (a directory holding
`_precompiled`), a `jac.toml` project, or the jaclang package itself is
keyed by `<root name>/<path within the root>`. A sealed unit is compiled at
the build's staging path and served from wherever the kit lands, and a
consumer compiled at run time names the sealed unit's symbols by computing
the same key from its own path, so the key has to agree across the move. A
module outside any such root keeps its real path as its identity. Variants
of one module written to different roots are still different units.

A unit names the units it depends on, in its interface and in its
dependency-digest rows, by package identity rather than by path: the
reference `jaclang/runtime/region_native.jac` resolves under whichever
jaclang the reading process runs, and `natapp/fast.jac` resolves beside the
reading unit's own root. A unit outside any root is referenced by its real
path. This is what lets the sealed kit's units, compiled at the build's
staging directory, be linked from wherever the kit lands.

Explicit imports of the compiler's runtime modules resolve against the
running compiler package before searching nearby checkouts. They must use
the same units as implicit walker and region support, so a checkout beside
an installed kit cannot introduce a second copy of the runtime state.

### Dependency edges

The IR generator records an edge for every unit it calls into and for every
type-only import that names a native unit. The second kind matters because
a type-only import contributes layouts: a layout change there must
recompile the importer, and a compile that could not see the unit at all
(mid-build in a cycle) records no digest for it and is recompiled once it
can. A type-only import of a Python-lane module is no link edge.

Two lookups feed the walk. A consumer declaring its calls takes the
dependency's interface as it stands, whether or not the dependency's own
records are current (`ensure(..., check_deps=False)`): that agreement is the
plan's check, and checking it from inside every consumer nested a fresh
compile of every cycle member on every visit. The plan's own walk does
check records (`check_deps=True`), so a dependent whose recorded digest
moved is recompiled during the walk.

## The link plan

One plan produces every artifact: `jac build --native`, native app builds,
the kernel resolver, `jac precompile --seal` and the in-process JIT are all
callers, and the plan knows nothing about any of them.

1. Resolve roots: an entry module, `jc_unit` for the kernel, every native
   unit of a package for a seal.
2. Discover the native dependency closure. Read matching unit records without
   recursively compiling their consumers; the plan owns dependency agreement.
3. Schedule the reachable graph through `driver/dependency_graph.jac`. The
   deterministic scheduler puts dependencies first and groups import cycles.
   One `NativeBuildSession` owns the reachable semantic graph. Each stale unit
   runs frontend analysis once; interface settlement reuses its typed tree.
4. Recompile a unit only when its source/compile-time inputs changed or a
   dependency's recorded interface differs. Process dependents after their
   dependencies, refresh edges after lowering, and recompute reachability when
   the graph changes. Repeated disagreement states produce an explicit
   convergence error rather than an arbitrary six-round cutoff.
   Fileless modules retry from their in-memory source through the same compile
   API, and record the interfaces they consumed even without a disk cache entry.
5. Optimize and persist each reachable changed unit once, after interface
   agreement. Order initializers topologically and synthesize the glue object.
6. Collect floor archives, clib paths and needed libraries from the unit
   interfaces.
7. Link in one of two modes. `objects`, the incremental default, links the
   units' relocatable objects. `bitcode` links every unit's bitcode into one
   LLVM module and runs the pass pipeline whole-program before a single
   codegen; executables are internalized first. This is the release lane,
   and what the JIT, PE and wasm targets use.
8. Record the plan digest, the merged class layout and its digest, the unit
   list and the source key in the `<artifact>.layout.json` sidecar.

The JIT is the same plan rooted at the module, always in bitcode mode, with
the merged module optimized whole-program before MCJIT sees it. Its target
machine is llvmlite's default for `jit=True`: with the position-independent
small-model pair the linked artifacts use, MCJIT's AArch64 stubs branch into
the GOT instead of through it.

C imports bind through handles for their declared shared libraries, using
the platform loader's search paths. The link plan installs those addresses
in the execution engine and retains the handles for the engine's lifetime.
Missing libraries or symbols fail compilation before an engine is returned;
a symbol from an unrelated library already loaded in the process cannot
silently replace the declared dependency.

### Incremental development builds

`jac build --native` enters through the link plan, so a warm entry module is not
unconditionally parsed and lowered before the cache is consulted. A no-op
objects build lowers no units. An ordinary body edit recompiles its unit;
a changed source contract recompiles the affected consumers.

`NativeUnitEntry` owns the interface, consumed dependency digests, source
revision, compile-time dependencies, object and bitcode together. Disk and
memory checks use the shared module source key, which includes annex
membership and content. Deletion and restored timestamps do not make stale
sources fresh. Native compile-time dependencies have their own stamped section so a
bytecode compile cannot erase them. They reuse the existing CTDEPS codec
and are rebased with the other native sections when sealing.
The registry's `compiled_paths` records finalized unit code generation;
cache counters distinguish unit code generation, object emission, linking,
and artifact reuse.

Objects are materialized on demand from stored bitcode, without repeating
the frontend. Bitcode builds and the JIT avoid emitting unused unit objects;
debug builds still eagerly produce their debugger artifacts. The optimization level is unchanged.
The JIT still optimizes and emits a merged program; this is not incremental
whole-program optimization.

For native linked files, the existing layout sidecar records an action digest
of the unit products, textual glue IR, runtime archive contents, exports,
libraries, kind and output name, plus the artifact's SHA-256. The check happens
before whole-program optimization and object emission. A matching artifact is
reused without rewriting it. Corruption or changed inputs cause a rebuild;
debug builds and explicit IR dumps bypass reuse. Wasm retains its existing
emission path.

Compiler-source edits still change the producing compiler digest. This is a
correctness boundary: results from different compiler implementations cannot
be assumed interchangeable. The existing Jac0 seed has its own content-keyed
bootstrap cache; native products retain the full compiler identity.

### The glue

Every artifact needs a little code no unit owns, and all of it is one LLVM
module built from the plan's unit records, never by pattern-matching linked
IR: the `jac_entry` preamble (the root's runtime probe, every initializer in
dependency order, the root's entry body), the platform entry point, the
`__jac_shared_init` a shared library exports, the `jac_retain` /
`jac_release` / `jac_str_new` C ABI wrappers and the `atexit` shim. The shim is
for glibc, which exports `__cxa_atexit` but keeps `atexit` in
`libc_nonshared.a`: every ELF artifact that is not static against musl
defines `atexit` over `__cxa_atexit`, or the loader refuses it.

Two rules keep the glue honest about what the units define:

- A wrapper is emitted only when a unit defines its target. `jac_str_new`
  binds to the `weak_odr` string constructor a unit carries; a library
  whose units never build a string exports no `jac_str_new`.
- The region-death hook (`__jac_region_died_hook`) is defined by a unit
  that registers the OSP runtime and recorded in its interface; the glue
  emits its no-op fallback only when no unit supplies it. A weak stub would
  otherwise replace a unit's definition when the modules merge, and the
  graph runtime would keep anchors of nodes whose arena is gone. The unit's
  own definition is `weak`, not `linkonce_odr`: nothing in that unit calls
  it, and the unit's optimizer discards an unreferenced `linkonce_odr`
  definition before the plan ever sees it.

Weak cells every unit carries (the region TLS slot, the GC switches,
`__jac_str_new`) become one cell per artifact: the Mach-O linker keeps the
first definition of an external name and binds later references to it,
letting a strong definition replace a weak one, exactly as a fused module
or a system linker would have it.

### Names across units

An importing unit declares the functions it reaches in other units from
their ASTs, under the symbols their interfaces record. Two imported modules
may each define one name (hashlib's private `new` next to hmac's public
`new`): the consumer keeps the first binding under the bare name and every
imported function under a module-qualified key, so `hmac.new(...)` finds
hmac's. A private function of another module is neither declared nor able
to mark the bare name as demoted, and two `:pub` definitions of one name are
left to the plan, which reports the collision (E5026) before anything
links. Inherited-method thunks a subclass gets from its base keep external
linkage and are recorded as exports, since callers look them up by the
subclass's name.

A module made only of imports and includes is a re-export surface, not a
unit with code of its own: an importer records the units behind it as its
dependencies, so a star or include chain links what it forwards.

### The wasm host contract

A wasm program is the same plan in bitcode mode. Its host calls the entry
module's functions by the names the source gives them, and initializes the
module before it calls anything, so for wasm the glue also defines a bare
`__jac_glob_init` that runs every unit's initializer (each runs once,
whoever calls first), and the root unit's module-level functions and
globals take their bare names in the merged module, the way `:pub`
symbols already do. The RC-free audit a `[gc] default = "none"` project
demands reads the application's own units: the runtime units linked beside
them define the reference-counting helpers whatever the application's
setting, and stay inert unless the application calls them.

## The kernel

The native compiler kernel is the plan rooted at `jc_unit` with the
frontend scope compiled as native units, linked as a shared library in
bitcode mode. `resolve_kernel()` in `kernel_resolve.jac` is the one lookup,
with a fixed precedence:

1. Explicit switches. `JAC_COMPILER_LIB` as a path is used as given and
   must carry its layout sidecar; `off` selects the store parser;
   `JAC_STUBCAT_BUILDING` keeps the store parser during the catalog build.
2. Sealed image. The manifest's `native` record names the artifact, its
   sha256, layout digest and plan digest; missing or mismatched is a startup
   error.
3. Source tree. The kernel beside `native_compiler.jac` is accepted when the
   source key its sidecar records equals the one the sources have now.
   Otherwise, under a lock, the checkout first looks at the kernel the
   running kit carries: a rerouted checkout runs on a kit's interpreter,
   and when that kit was built from these very sources its kernel's source
   key matches, so the kernel is copied beside the loader and accepted.
   Only a checkout whose compiler differs from every kernel in reach has a
   child `jac` process rebuild one, with the store parser pinned for the
   build.
4. No native toolchain: the store parser serves, silently.

The source key is the compiler digest plus, for every unit the kernel was
linked from, the unit's package identity and module key. Nothing in it is
a path, which is what lets a kernel built at the kit's staging directory
be accepted in a checkout elsewhere; the sidecar records each unit's
identity next to the path the build used, and acceptance finds the unit
where this process's jaclang lives. Accepting a kernel therefore costs one
content hash per unit and no plan, which is what makes a warm `jac run` in
a source tree start in well under a second. The derivation runs in a child
on purpose: the first parse of a checkout happens inside the compiler's own
import chain, where half the checker is not importable yet, and a rebuild
must not depend on the state of the process that asked for it. The kernel
build and the seal use the same in-process build session as applications.

The kernel is always the host's. `kernel_options()` pins the target to the
host whatever `JAC_NATIVE_TARGET` says, so a cross-compiled artifact's units
parse with a kernel the process can load.

The toolchain units (the OSP kernel, the format kernel, the region arena)
are ordinary native units pulled in by dependency edge. The region arena
allocates on the heap for the kernel units themselves and in the current
arena for everything else; the kernel unit never depends on itself.

## Semantic ownership and lifetime

Dependency types resolve on demand through the evaluator. In particular, a
context-manager alias uses the same binding operation during lazy dependency
analysis and the statement checker; its type does not depend on which walker
visited a body first.

The build session owns its `JacProgram`, module hub, evaluator and hydrated
catalog objects. Source analysis never borrows mutable trees from the
process-global program used to execute the compiler itself. A `StubCatalog`
session shares immutable catalog bytes and their backing storage, while its
memo tables and hydrated types belong to that session. Releasing a compile
closure drops the evaluator, every module (including stubs), and the catalog.

The meta importer keeps the compiler's own analysis session alive until the
outermost module execution completes, including its nested imports. Retrieving
bytecode alone does not end that session: otherwise execution immediately
re-ingests the dependencies just analyzed. The existing self-host cache defers
its release to that boundary, including exception unwinding.

This ownership boundary replaces per-unit subprocess isolation and its option
serialization, recursion guards and product-transfer codec. Interface records
still pass through `NativeUnitRegistry`; the build session uses the same
registry, source keys and compile-time dependency checks as disk cache reads.
A full AST requested behind a catalog interface loads through the program's
existing dependency loader.

`NativeBuildSession.lower()` reuses analyzed trees during dependency-ordered
interface settlement. `finish()` checks source revisions, optimizes each
reachable changed unit once, and persists ordinary JIR products. Session
cleanup runs on success and failure. Target and codespace overrides are scoped
to the build and restored on exit. The existing analysis counters distinguish
frontend analysis, lowering visits and final code generation.

## Compiler runtime archives

Linux AArch64 floor libraries call outline-atomic helpers supplied by compiler-rt.
The payload vendor builds the pinned upstream LLVM implementations into
`libclang_rt.atomics.a`, with one helper per archive member and a separate CPU
detection member. The ordinary archive selection code follows undefined
symbols to select the helpers and their feature flag, without bringing in
unrelated libc definitions. The upstream helpers use LSE where available and
fall back to LL/SC. No handwritten atomic ABI implementation is emitted in glue.

The ELF linker preserves input constructors and their priority order for shared
and executable artifacts, so the runtime's CPU detection runs before application
initializers. Runtime archive bytes participate in artifact invalidation.

## Sealed applications

`jac precompile --seal` links every native unit of the package into one
shared artifact in bitcode mode and records it in the manifest (format 9):
path, sha256, layout digest and plan digest, verified at load. A sealed app
with native pins runs it through `runtime/native_library.jac`'s
`SharedNativeEngine`, a `ctypes` engine with the same surface as the JIT
(`get_function_address`, `get_global_value_address`, static init symbols),
so the interop stubs and the meta importer are unchanged. Native imports of
Python functions bind through the JIT's symbol table and are not served by
a sealed artifact.

## Costs and where they come from

Measured on the chess example (`jac/examples/chess`) and the compiler's own
frontend, macOS arm64, September 2026:

| | fused build (main) | unit model |
|---|---|---|
| `jac run chess.jac -b 1`, first compile | 1.9 s | 3.5 s |
| same, warm | 1.7 s | 1.9 s |
| `jac run chess.jac -b 20` | 4.2 s | 4.4 s |
| `jac build --native chess.jac`, warm units | 1.7 s, 102 KB | objects 1.5 s, 110 KB; bitcode 1.7 s, 101 KB |
| `./chess -b 20` | 2.93 s | 2.94 s (objects), 2.89 s (bitcode) |
| kernel, parsing 14k lines four times | 1.73 s | 1.76 s |
| kernel, cold derivation | about 3 min | about 5.5 min |
| kernel size | 9.2 MB | 8.4 MB |

The table above records the original unit-model implementation, before build
sessions. A local session-path kernel build took 175 seconds for 34 units:
34 frontend analyses, 73 lowering visits and 34 final code generations, with
about 7.5 GB peak process RSS. These are local measurements, not a controlled
CI comparison. Build-kit timing must be measured separately because it also
includes bytecode sealing, runtime packaging and compression.

## Diagnosing a broken artifact

- A kernel that parses one file and crashes on the second is stale state
  keyed on reused addresses, not a plain use-after-free. `MallocScribble=1
  MallocPreScribble=1` makes it deterministic; `libgmalloc` makes it vanish
  because every allocation gets fresh pages.
- `EXC_BAD_ACCESS (code=2)` at an address inside a read-write page, from
  JIT code, is the target-machine mismatch described above.
- A plan with fewer units than expected means edges were lost: check the
  consumer's demoted set (a demoted caller records no edge) and whether its
  dependency was served from the catalog when it compiled.
- `JAC_NA_DEBUG=1` prints the plan's unsettled units per round, each typed
  import the walk resolved and with what, and the stack of any unit compile
  that raised.

Native binaries and layout sidecars are published with the shared bootstrap-safe
atomic writer. Replacing a binary preserves the old image for open readers and
gives macOS a fresh file identity for code-signature validation. JIR merge
transactions hold the shared file lock across their read and atomic replacement.
