# Native Memory Patterns

Detailed patterns for `jac-native-memory`. Start with `jac guide jac-native-memory` for the essential rules; use `--sections` and `--section` to retrieve a particular pattern. Examples below may be contextual fragments.

Native Jac heap values (objects, strings, lists, dicts, sets) are reference-counted by default. Ownership annotations are **opt-in**: they let the compiler move/borrow-check tagged bindings, and - taken to full coverage - compile memory management the way Rust would emit it: alloc at construction, free at a statically determined drop point, **no RC or collector in the binary**, proven by the RC-free scan every `nogc` build runs.

## Memory profiles

```bash
jac build --native app.jac --memory managed   # default: RC + Bacon-Rajan cycle collector
jac build --native app.jac --memory rc       # RC only; no collector code; ref cycles leak
jac build --native app.jac --memory nogc     # zero retain/release call sites emitted
```

- Default comes from `jac.toml`: `[memory] profile = "managed"`; `--memory` overrides it for one build.
- Under `managed` the cycle collector runs automatically; `JAC_GC=off ./binary` switches collection off at run time for leak debugging.
- `nogc` holds every module to the ownership contract (below) and emits no RC or collector runtime: statically placed drops replace RC entirely, and the emitted IR is proven free of RC machinery on every build.

## Ownership surface (opt-in - unannotated code is untouched)

The checker only tracks bindings tagged `own`/`lin`/`imm`/`&`/`&mut` and their derived moves and views plus allocations under an `in <handle> { }` region open. Under nogc enforcement, unmarked locals also infer ownership states. Annotations are compile-time-only on every backend (`&x` compiles to exactly `x`).

```jac
obj Buffer { has n: int = 0; }

def use_buf(x: Buffer) -> None {}

with entry {
    a: own Buffer = Buffer();   # unique owner
    v: &Buffer = &a;            # shared borrow - owner is read-only while `v` is live (write = E1303)
    use_buf(v);
    b = a;                      # MOVES; reading `a` after this is E1301 (reassigning revives it)
    d: imm Buffer = Buffer();   # deep-immutable - any write through `d` is E1309
    use_buf(d);
}
```

`&mut x` takes the exclusive mutable borrow: any number of live `&`, or exactly one live `&mut`, never both (violations are E1302). Borrows split at single-field granularity: `&p.name` loans only that field, so a write to `p.score` (or a `&mut p.score`) under it is legal; same-field overlaps, whole-object borrows, subscripts, and deeper paths conflict as before.

- The `imm` prefix operator freezes a statically unique value (an `own` binding, consumed, or a fresh expression) into the immutable world: `cfg = imm build();` binds `cfg` as `imm` with no annotation needed. Identity at runtime on every backend, E1311 when uniqueness cannot be proven; frozen values are the natural `flow` payload (imm crosses freely). The rule of the surface: states are annotations, transitions are operators (`&x`, `&mut x`, `own x`, `imm x`), and the exit is a call (`managed(x)`).
- `own` is **affine**: dropping without consuming is fine, not an error. Passing an owned local to a consuming parameter, owned return, or owned field store consumes it; read-only builtin methods and native stdlib calls borrow instead (see the idioms section below).
- `lin` is implemented: `f: lin File = File()` must be consumed on every control-flow path before scope exit (`E1305`), and a second consumption is `E1301`. Use `own` when automatic dropping is acceptable; use `lin` when the caller must explicitly hand off the resource.
- Owned fields and containers preserve ownership: `has child: own T`, `list[own T]`, and `dict[str, own T]` move stored objects and drop replaced/removed values. Storing into ordinary managed storage instead crosses the ownership boundary; under enforcement it needs an explicit `managed(...)` transfer where the selected profile permits one. Graph storage is managed or region-owned; an `own` walker is affine and spawning it consumes it, but that annotation does not make graph nodes uniquely owned.
- Borrowed results must remain tied to their owners. A borrowed parameter may be returned; a local owner's borrow may not escape (`E1306`), and no borrow may outlive its owner (`E1304`). Local borrow-containing objects are views, with the restrictions below.
- `flow for x in &xs { }` / `flow for m in &mut xs { }` - the disjoint-partition loop: per-element body, closing brace is the join. Collection must be lent, `break`/`return`/`yield`/`disengage` in the body are E1313 (`continue` ok), nesting rejected, and body captures follow sendability (outer writes are E1308 except integer `+=`, `min`, and `max` reductions; otherwise write through the `&mut` element). **Runs genuinely parallel in zero-RC enforced builds** (`--memory nogc`): body outlined, element ranges over pthreads, join at the brace, `[native] threads` sets the width (default 4; `JAC_THREADS` overrides at run time) - sound because a `nogc` binary has no refcounts to race on. `--memory rc` builds fan out too - retain/release are atomic, so crossings are safe with atomic lifetime updates; `--memory managed`, the Python backend, and wasm stay sequential. Results are byte-identical either way.
- Sendability (E1308): only `imm`, moved `own` (including an `own Region` handle), or scalars cross `flow`/`thread_run` boundaries. Exception - scoped lending: `h = flow f(&a); ... wait h;` in one block lends `a` for exactly the spawn-to-join extent, provided the owner is untouched in between; any other live borrow never crosses.
- `def drop` (reserved ability, like `postinit`) runs exactly once at destruction, **after the owner's last use and no later than scope exit**, at the same observable point under every native memory profile. Some drops are eager; do not rely on immediate destruction after every last-read statement. No resurrection; under `cycles`, intra-cycle drop order is unspecified. The Python backend calls it only for region-allocated values (below); rely on it elsewhere only in native modules.

## Places, methods, and views

- `take(place)` reads and clears an optional local or field, leaving `None`. Use it to move an optional owned child; it also works for an optional scalar handle. It does not validate the lifetime of an opaque foreign handle. `swap(&mut a, &mut b)` exchanges same-typed locals/fields with both receivers evaluated once. Invalid places are E1319; use container `pop` for elements.
- Method receiver modes are inferred from the body, including mutations through helper methods. Read methods borrow shared; mutators require exclusive access (E1318 through a shared receiver). Explicit `self: own` consumes the receiver. Generic parameters and `Callable[[own T], None]` preserve ownership at calls.
- A type with borrow-containing fields, including inherited fields and generic arguments, is a view. For example `obj View { has player: &Player; }` can be constructed and used locally. It cannot be bound `own`, stored into a field/container/global, or sent to another task. Returning a view is legal only when its roots derive from borrowed parameters or the receiver; callers retain all those lifetime dependencies. E1315 rejects escaping views; build a fresh owned value if it must escape.
- `for x in &xs` and `for x in &mut xs` yield scoped element borrows. The mutable form updates elements in place; neither allows growing or clearing the container during the loan. The element cannot escape, and the container becomes reusable after the loop.
- `flow for chunk in &mut xs.chunks(3)` lends disjoint mutable chunks (the last may be shorter); `&xs.chunks(3)` lends shared chunks. Use `chunks` directly in the lent loop, not as a stored iterator. No structural growth or escaping chunk; ordinary flow capture and reduction rules apply.
- Use `&x` with no space for a shared ownership borrow. Legacy `& expr` and `&(expr)` perform graph UUID lookup. Avoid rewriting one as the other.

For complete examples and lifetime rules, read `reference/language/ownership-borrowing.md` in the bundled docs; for diagnostic contracts read `internals/ownership-checker-spec.md`. Rocket Arena (`examples/jaclang_org/core/site/game`) demonstrates owned aggregates, generic pool removal, inferred receivers, field splitting, local render views, swap, and an explicit browser handle lifecycle. It does not demonstrate regions or concurrency. Its simulation is validated across managed/RC/nogc and Python; the website uses managed memory.

## Regions - first-class arenas

The old `region { }` block **no longer parses** (clean break). A `Region` is a first-class, ownable, sendable handle; the `in <handle> { }` statement opens it for allocation with **dynamic, thread-scoped extent**: everything constructed while the open is active on this thread lives in the region - including allocations made by helpers the open calls - and is reclaimed wholesale when the handle drops. On the native backend that is a bump arena (a Jac kernel unit, `runtime/region_native.jac`) torn down with one LIFO dtor-log walk plus a single bulk free; the same rule holds on the Python backend.

```jac
obj Buffer { has n: int = 0; }

with entry {
    in Region() { tmp = Buffer(); }   # anonymous: extent is exactly the block
    r: own Region = Region();
    in r { keep = Buffer(); }         # reclaimed when `r` drops (scope exit, reassignment, early return)
}
```

- Inside an open there is **no ownership discipline** - alias and build cycles freely. The checker polices the boundary: a region-rooted reference may not be returned, stored to outlive the handle, handed to an opaque callee, or sent across `flow` (E1307). Because extent is dynamic, the heap-typed result of a call made under the open is region-rooted too, unless the callee receives the handle; constructors and non-retaining builtins (`print`, `len`, ...) are exempt.
- Escape hatches: scalars copy out freely; `own <expr>` **reboxes** a scalar/string copy out; helpers taking `&Region` legally carry region-rooted values, and a function with exactly ONE `&Region` param may return region-rooted results (single-region elision - two region params stay rejected). `managed(T(...))` constructs on the managed heap regardless of the current region - the allocation-side exit for process-lifetime bookkeeping. Kernel units (the OSP, fmt, and region kernels) are built with `CompileOptions.kernel_unit`, which takes the heap path for every construction: the allocator's bookkeeping never allocates through itself, and the seed-tier sources stay region-agnostic.
- Handles have dynamic extent: return one from a helper, grow it through a `Region`-typed param, drop it remotely. `Region` lowers to a pointer in native signatures. A thread starts with no current region: a `flow`/`thread_run` body allocates on the heap unless it opens a partition it was sent.
- Graph-native: nodes/edges created under an open allocate in the arena; a walker ability grows the region by the same rule - dispatch enters `region_of(here)` for the ability body, so its allocations land in the visited node's region, no `&Region` field needed. `region_of(x)` is a builtin. Walkers themselves are RC-managed and reclaimed (`def drop` fires once per instance), not immortal.
- **Connect-as-seal**: a directed connect from a managed anchor (root above all) *into* a region-local node, under an open on an **owned named** handle, is the membrane seal for subgraphs - it consumes the handle (E1301 on reuse) and promotes the topology into the managed world: pages stay live, no teardown ever runs, no drop hooks fire, traversable from the anchor afterwards. The seal closes the region for graph operations (allocating or wiring after it in the open is E1307). Every non-seal shape keeps E1307: a region edge wired *out* to a managed node, undirected wiring, an anonymous open, or a borrowed `&Region` handle.
- Moving an `own Region` across `flow` transfers the whole subgraph zero-copy; legal only while no borrows of the handle are live. `fr = imm r` consumes the owned handle and transfers handle-ness: the frozen result deep-freezes the subgraph and crosses `flow` freely under the imm sendability rule (share one frozen graph with N parallel readers); opening a frozen handle for allocation is E1309.
- Python backend: memory stays GC-managed, but `drop` hooks fire at portable points - LIFO at the closing brace for an anonymous open, at handle death for a named one.
- `W1310` lints an open with an empty body. Region opens are fully supported inside nogc-enforced modules: the arena core (bump alloc, dtor log, bulk free) needs no RC, so build-traverse-discard region code compiles headerless with the RC-free invariant holding and the same LIFO teardown as the managed modes.
- **Sub-arenas**: `c: own Region = r.partition()` yields an owned child handle - open it, allocate under it, move it across `flow` (owned-handle sendability); child death **reabsorbs** its memory and drop log into the parent (hooks fire once, at parent death, child entries first), and a parent dying first zombie-defers its teardown to the last reabsorb. Alternatively `(a, b) = r.partition(2)` immediately unpacks a literal count into exactly that many plain names. Dynamic counts, wrong arity, and unowned receivers are E1314; use separate calls for dynamic counts.
- **Inferred anonymous regions**: a block that builds a graph from fresh node locals, connects them only among themselves, and consumes it with expression-statement spawns is rewritten by `RegionInferPass` into a real `in Region() { }` open at zero annotation - arena allocation, `drop` hooks LIFO right after the last spawn, one bulk free, identical in every gc mode and on the Python backend. Touching `root`/`here`, passing a member to a call, consuming the spawn result, or control flow through the extent declines the inference (graph stays managed, never wrong). Enforced-mode traversals still wait on the walker engine's zero-RC factoring.

## Zero-RC enforced builds - the workflow

```bash
jac build --native service.jac --memory nogc
```

1. **Enforce**: `--memory nogc` (every native module in the artifact) or `jac.toml` patterns (fnmatch vs module name):

   ```toml
   [memory]
   enforce = ["service*"]       # compiled under the zero-RC contract
   exempt = ["legacy*"]  # incremental exemption under managed/rc only
   ```

2. **Fix the E140x hard errors** (each blocks codegen; `{provenance}` says why the module is enforced):

   | Code | Meaning | Fix |
   |------|---------|-----|
   | E1401 | Heap-typed param/return/`has` field has no ownership state, or a local whose conditional arms disagree | Annotate the contract position `own`/`&`/`&mut`/`imm`; locals infer (fresh RHS = `own`, literal = `imm`, field/element read = borrow of the root), so write a local only when its arms disagree |
   | E1402 | Owned value sealed into managed storage | Keep it owned, or cross explicitly with `managed(x)` at the boundary |
   | E1403 | Heap value crosses out of the module implicitly | Wrap the argument in `managed(x)`; scalars and `imm` cross freely |
   | E1404 | `any`-typed value could be heap | Give it a concrete type, or confine `any` to scalars |
   | E1405 | Escaping closure capture | Pass the value as an explicit parameter or keep the closure local |
   | E1406 | A value that cannot enter the owned world as it is: a borrow, `imm` value or place read stored into a container, a retaining builtin (`iter`/`globals`/`locals`), or `managed()` under a nogc build | Follow the help: `xs.append(own p)` copies a str, `take(place)` extracts an optional field, `pop` removes a container element, `for p in xs` iterates by value, or build the element fresh at the store |
   | E1407 | Entry block leaves an inferred exception unhandled | Handle the call with `try`/`except`; functions can propagate to their callers |

   A whole-artifact `nogc` profile admits no exemptions: use `enforce`/`exempt` under managed or RC while migrating, then switch the profile.

3. **Verify**: every `nogc` build scans the emitted IR for `__rc_*` helpers, trace functions, roots-buffer globals, and run-time collector probes; a hit is a compiler bug, and success prints `nogc invariant ok`.

Under `--memory nogc` an enforced module compiles **headerless**: owned payloads are bare `malloc` allocations (no RC header) and each free is a direct statically-placed `__drop_<T>` call, which also runs the user `def drop` hook. Raising functions propagate through hidden error slots; callers dispatch `except`, execute `finally`, and release owned locals on error paths. An entry block must handle its inferred raises effect (`E1407`); it has no caller to propagate to. See the language reference's “Errors without unwinding” section.

## Enforced-module idioms (what real programs look like)

- Locals infer ownership from any fresh right-hand side: calls, literals,
  f-strings and comprehensions. Step-free string slices (`p = src[0:n]`)
  are lifetime-bound views under enforcement; use `src[0:n:1]` for an owned
  materialization. Neither consumes `src`. Only enforced contract positions
  (params, returns, `has` fields) need explicit `own`/`&`/`&mut`/`imm`.
- Read-only builtin methods (`find`, `startswith`, `split`, `join`,
  `replace`, `get`, `write`, ...) and the native stdlib surface
  (`os`/`sys`/`time`/`math`/`random`/`struct` calls) borrow their owned
  receivers and arguments - `i = hay.find(pat)` leaves both live, and
  `os.system(cmd)` does not seal `cmd`. Passing an owned value to a
  jac-defined function with an `own` param still moves it.
- Containers of `str` elements are fully supported: `xs.append(f"x{i}")`,
  set `add`, dict literals, and `d[k] = v` all work. Fresh strings
  (f-strings, concats, slices, call results) move into the container; named
  bindings and string literals are copied in, so the source stays live
  (`xs.append(s); print(s);` is legal). The container owns its elements and
  frees them when it drops. A borrowed (`&str`) or field-read string must be
  laundered through an explicit copy first (`xs.append(f"{p}")`).
- Named `own` archetypes and fresh constructors move into list literals, `append`/`insert`, and dict values. Reading the named owner afterwards is E1301. `pop()` / `pop(i)` / dict `pop(key)` transfer the removed value; direct field/element reads cannot silently become owners (E1316/E1317). Sets and dict keys of archetypes remain outside this ownership support; check the concrete container shape rather than assuming all nested containers are supported.
- Under nogc, eligible acyclic owned fields are embedded in the parent, and scalar-only leaf object list elements use by-value storage. The compiler chooses layout from the resolved type, so generic helpers and borrowed container parameters agree with callers. Do not reproduce element lifetime or layout logic in application code.
- Typed-base int enum members are scalar constants; string globs are not
  expressible under the contract - use a `def` returning `own str` for
  string constants.
- The compiler's own modules are never enforced: a project-wide
  `[memory] enforce = ["*"]` applies to your code only, so a release
  binary can drive a `[dev] jaclang_source` checkout under full enforcement.

## Measuring and debugging

- `jac explain memory mod.jac` prints per-module RC coverage and the inferred ownership facts: `rc-stats [mod.jac] gc=cycles retains=1 releases=10 elided=3 coverage=21.4%` - a fully covered module shows `retains=0 releases=0 ... rc-free`, and `promoted=N` counts owned locals allocated on the stack instead of the heap. Move elision is proven automatically (core `RcFactsPass` backward-liveness), annotated or not; stack promotion additionally consumes the `own` annotation (frame-local borrows and scalar field reads do not force a heap allocation).
- `JAC_GC=off ./binary` disables reclamation at run time in managed-mode binaries - useful to bisect whether a crash is RC-related (memory is then never freed).
- Reserved intrinsics callable from native code: `__rc_debug_enable()` / `__rc_debug_disable()` (log retain/release traffic), `__rc_gc_disable()` / `__rc_gc_enable()`, `__rc_collect_cycles()`. These names are claimed by the runtime - never define your own.

## Gotchas

- Ownership diagnostics gate native codegen (they are required analyses there), but whether they are *displayed* never changes the binary.
- A shared library (`--lib`) exports `jac_retain`/`jac_release` for host-side lifetime management **only when built under a managed gc mode**; a zero-RC (`--memory nogc`) library has no RC helpers to wrap, so those exports are absent by design.
- Spell the must-consume marker `lin`, not `linear`. A static ownership contract does not validate aliases hidden behind `any`, opaque C/Wasm handles, or separately obtained managed references.
- `managed(x)` is the identity function on the Python backend; annotations there are checked, then erased.
- `jac build --as native` does not take the gc flags; use file-level `jac build --native` for zero-RC builds.
