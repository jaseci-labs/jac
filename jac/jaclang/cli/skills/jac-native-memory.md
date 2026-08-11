---
name: jac-native-memory
description: Memory management on the native pathway - the emit-time `--gc` modes (cycles/rc/none), the opt-in ownership & borrow checker (`own`, `&`/`&mut`, `imm`, `def drop`), first-class `Region` arenas (`in <handle> { }` opens, growth rule, sendable handles), zero-RC enforced builds (`--enforce-nogc`, E1401-E1406, `managed()`), and verification (`--assert-no-rc`, `JAC_RC_STATS`). Load when any E13xx/E14xx diagnostic or W1310 appears, when a native binary leaks or churns refcounts, or when building an RC-free binary. For the native subset itself see `jac-native`.
---

Native Jac heap values (objects, strings, lists, dicts, sets) are reference-counted by default. Ownership annotations are **opt-in**: they let the compiler move/borrow-check tagged bindings, and - taken to full coverage - compile memory management the way Rust would emit it: alloc at construction, free at a statically determined drop point, **no RC or collector in the binary**, checkable with `--assert-no-rc`.

## Emit-time `--gc` modes

```bash
jac nacompile app.jac --gc cycles   # default: RC + Bacon-Rajan cycle collector
jac nacompile app.jac --gc rc       # RC only; no collector code; ref cycles leak
jac nacompile app.jac --gc none     # zero retain/release call sites emitted
```

- Default comes from `jac.toml`: `[gc] default = "cycles"`.
- Under `cycles` the collector machinery is emitted but idle until the binary runs with `JAC_GC_CYCLES` set in the env (or code calls `__rc_collect_cycles()` explicitly).
- `--gc none` **without** ownership coverage means heap memory is never reclaimed (the compile-time analogue of running any managed binary with `JAC_NO_GC=1`). With nogc enforcement (below), statically inserted frees replace RC entirely.

## Ownership surface (opt-in - unannotated code is untouched)

The checker only tracks bindings tagged `own`/`imm`/`&`/`&mut` plus allocations under an `in <handle> { }` region open. Annotations are compile-time-only on every backend (`&x` compiles to exactly `x`).

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
- `own` is **affine**: dropping without consuming is fine, not an error. Passing an owned local to a jac-defined call, `return`, or field store consumes it; read-only builtin methods and native stdlib calls borrow instead (see the idioms section below).
- Storing an owned value into a field/subscript/graph object seals it into managed storage (**the membrane**): the source binding dies, and reading it back yields a plain managed value. `node`/`edge`/`walker` stay fully managed - no `own`/`&` of graph state. Exception: a field declared `has ref: own T` keeps the value in the owned world - the store still consumes the source, but it is not an E1402 seal; the parent drops the field at its own drop point and an overwrite drops the old value first.
- Borrows are second-class: returning or storing one is E1306 (single passthrough of a borrow *parameter* is allowed); a borrow outliving its owner is E1304.
- `flow for x in &xs { }` / `flow for m in &mut xs { }` - the disjoint-partition loop: per-element body, closing brace is the join. Collection must be lent, `break`/`return`/`yield`/`disengage` in the body are E1313 (`continue` ok), nesting rejected, and body captures follow sendability (write to any outer name is E1308 - write through the `&mut` element instead). **Runs genuinely parallel in zero-RC enforced builds** (`--enforce-nogc --gc none`): body outlined, element ranges over pthreads, join at the brace, `JAC_FLOW_THREADS` sets width (default 4) - sound because an `--assert-no-rc` binary has no refcounts to race on. `--gc rc` builds fan out too - retain/release are atomic, so crossings are safe at no added single-thread cost (measured ~7x on 8 threads); `--gc cycles`, the Python backend, and wasm stay sequential. Results are byte-identical either way.
- Sendability (E1308): only `imm`, moved `own` (including an `own Region` handle), or scalars cross `flow`/`thread_run` boundaries. Exception - scoped lending: `h = flow f(&a); ... wait h;` in one block lends `a` for exactly the spawn-to-join extent, provided the owner is untouched in between; any other live borrow never crosses.
- `def drop` (reserved ability, like `postinit`) runs exactly once at destruction, **at the owner's last use, not scope end** (NLL-style eager drop) - same observable point under every gc mode. No resurrection; under `cycles`, intra-cycle drop order is unspecified. The Python backend calls it only for region-allocated values (below); rely on it elsewhere only in native modules.

## Regions - first-class arenas

The old `region { }` block **no longer parses** (clean break). A `Region` is a first-class, ownable, sendable handle; the `in <handle> { }` statement opens it for allocation. Everything constructed under an open lives in the region and is reclaimed wholesale when the handle drops - on the native backend a bump arena torn down with one LIFO dtor-log walk plus a single bulk free.

```jac
obj Buffer { has n: int = 0; }

with entry {
    in Region() { tmp = Buffer(); }   # anonymous: extent is exactly the block
    r: own Region = Region();
    in r { keep = Buffer(); }         # reclaimed when `r` drops (scope exit, reassignment, early return)
}
```

- Inside an open there is **no ownership discipline** - alias and build cycles freely. The checker polices the boundary: a region-rooted reference may not be returned, stored to outlive the handle, handed to an opaque callee, or sent across `flow` (E1307).
- Escape hatches: scalars copy out freely; `own <expr>` **reboxes** a scalar/string copy out; helpers taking `&Region` legally carry region-rooted values, and a function with exactly ONE `&Region` param may return region-rooted results (single-region elision - two region params stay rejected).
- Handles have dynamic extent: return one from a helper, grow it through a `Region`-typed param, drop it remotely. `Region` lowers to a pointer in native signatures.
- Graph-native: nodes/edges created under an open allocate in the arena; a walker ability grows the region automatically - its allocations anchor to the region of the visited node (`here`), no `&Region` field needed. Walkers themselves are now RC-managed and reclaimed (`def drop` fires once per instance), not immortal.
- **Connect-as-seal**: a directed connect from a managed anchor (root above all) *into* a region-local node, under an open on an **owned named** handle, is the membrane seal for subgraphs - it consumes the handle (E1301 on reuse) and promotes the topology into the managed world: pages stay live, no teardown ever runs, no drop hooks fire, traversable from the anchor afterwards. The seal closes the region for graph operations (allocating or wiring after it in the open is E1307). Every non-seal shape keeps E1307: a region edge wired *out* to a managed node, undirected wiring, an anonymous open, or a borrowed `&Region` handle.
- Moving an `own Region` across `flow` transfers the whole subgraph zero-copy; legal only while no borrows of the handle are live. `fr = imm r` consumes the owned handle and transfers handle-ness: the frozen result deep-freezes the subgraph and crosses `flow` freely under the imm sendability rule (share one frozen graph with N parallel readers); opening a frozen handle for allocation is E1309.
- Python backend: memory stays GC-managed, but `drop` hooks fire at portable points - LIFO at the closing brace for an anonymous open, at handle death for a named one.
- `W1310` lints an open with an empty body. Region opens are fully supported inside nogc-enforced modules: the arena core (bump alloc, dtor log, bulk free) needs no RC, so build-traverse-discard region code compiles headerless with `--assert-no-rc` passing and the same LIFO teardown as the managed modes.
- **Sub-arenas**: `c: own Region = r.partition()` yields an owned child handle - open it, allocate under it, move it across `flow` (owned-handle sendability); child death **reabsorbs** its memory and drop log into the parent (hooks fire once, at parent death, child entries first), and a parent dying first zombie-defers its teardown to the last reabsorb. One `partition()` call per child.
- **Inferred anonymous regions**: a block that builds a graph from fresh node locals, connects them only among themselves, and consumes it with expression-statement spawns gets an implicit `in Region() { }` at zero annotation - arena allocation, `drop` hooks LIFO right after the last spawn, one bulk free, identical in every gc mode. Touching `root`/`here`, passing a member to a call, consuming the spawn result, or control flow through the extent declines the inference (graph stays managed, never wrong). Native-only; the Python backend erases it. Enforced-mode traversals still wait on the walker engine's zero-RC factoring.

## Zero-RC enforced builds - the workflow

```bash
jac nacompile service.jac --gc none --enforce-nogc --assert-no-rc
```

1. **Enforce**: `--enforce-nogc` (this module) or `jac.toml` patterns (fnmatch vs module name):

   ```toml
   [gc.enforce]
   modules = ["service*"]       # compiled under the zero-RC contract
   grandfathered = ["legacy*"]  # exempt while migrating (checked first)
   ```

2. **Fix the E140x hard errors** (each blocks codegen; `{provenance}` says why the module is enforced):

   | Code | Meaning | Fix |
   |------|---------|-----|
   | E1401 | Heap-typed param/return/`has` field has no ownership state | Annotate the contract position `own`/`&`/`&mut`/`imm` (locals infer from a fresh RHS) |
   | E1402 | Owned value sealed into managed storage | Keep it owned, or cross explicitly with `managed(x)` at the boundary |
   | E1403 | Heap value crosses out of the module implicitly | Wrap the argument in `managed(x)`; scalars and `imm` cross freely |
   | E1404 | `any`-typed value could be heap | Give it a concrete type, or confine `any` to scalars |
   | E1405 | Escaping closure capture | Pass the value as an explicit parameter or keep the closure local |
   | E1406 | Retaining/aliasing construct (`iter`/`globals`/`locals`, or `managed()` of a heap value under `--gc none`) | Use an owned-compatible alternative or move the code out of the enforced module |

3. **Verify**: `--assert-no-rc` fails the build if the emitted IR contains any `__rc_*` helper, trace function, roots-buffer global, or entry-point GC env probe; on success it prints `assert-no-rc ok`.

Under `--gc none` an enforced module compiles **headerless**: owned payloads are bare `malloc` allocations (no RC header) and each free is a direct statically-placed `__drop_<T>` call, which also runs the user `def drop` hook. Note: an unhandled `raise` in an enforced module runs the current frame's drop obligations (each exactly once -- eager-dropped locals are already nulled), prints a line, and calls `abort()` instead of unwinding.

## Enforced-module idioms (what real programs look like)

- Locals infer ownership from any fresh right-hand side: calls, literals,
  f-strings, comprehensions, and str-typed subscripts/slices (`p = src[0:n]`
  is an owned copy and does not consume `src`). Only contract positions
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
- Lists of archetype elements are supported for **fresh** values: a
  constructor result moves into `append`/`insert` (`xs.append(Res(tag=i))`)
  and into list literals, the container stamps the element type's drop in
  its element-drop slot, and every element is freed exactly once when the
  list drops. Named archetype bindings stay fenced (E1406) - there is no
  copy-in idiom for archetypes - and sets, dict keys/values of archetypes,
  and nested containers remain E1406 until their hashing and element-drop
  monomorphization land.
- Typed-base int enum members are scalar constants; string globs are not
  expressible under the contract - use a `def` returning `own str` for
  string constants.
- The compiler's own modules are never enforced: a project-wide
  `[gc.enforce] modules = ["*"]` applies to your code only, so a release
  binary can drive a `[dev] jaclang_source` checkout under full enforcement.

## Measuring and debugging

- `JAC_RC_STATS=1 jac nacompile mod.jac` prints per-module RC coverage to stderr: `rc-stats [mod.jac] gc=cycles retains=1 releases=10 elided=3 coverage=21.4%` - a fully covered module shows `retains=0 releases=0 ... rc-free`, and `promoted=N` counts owned locals allocated on the stack instead of the heap. Move elision is proven automatically (core `RcFactsPass` backward-liveness), annotated or not; stack promotion additionally consumes the `own` annotation (frame-local borrows and scalar field reads do not force a heap allocation).
- `JAC_NO_GC=1 ./binary` disables reclamation at run time in managed-mode binaries - useful to bisect whether a crash is RC-related (memory is then never freed).
- Reserved intrinsics callable from native code: `__rc_debug_enable()` / `__rc_debug_disable()` (log retain/release traffic), `__rc_gc_disable()` / `__rc_gc_enable()`, `__rc_collect_cycles()`. These names are claimed by the runtime - never define your own.

## Gotchas

- Ownership diagnostics gate native codegen (they are required analyses there), but whether they are *displayed* never changes the binary.
- A shared library (`--shared`) exports `jac_retain`/`jac_release` for host-side lifetime management **only when built under a managed gc mode**; a zero-RC (`--gc none`) library has no RC helpers to wrap, so those exports are absent by design.
- `linear` (must-use marker, E1305) is planned but **not implemented** - do not write it.
- `managed(x)` is the identity function on the Python backend; annotations there are checked, then erased.
- `jac build --as native` does not take the gc flags; use file-level `jac nacompile` for zero-RC builds.
