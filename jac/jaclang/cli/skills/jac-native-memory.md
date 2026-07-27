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

`&mut x` takes the exclusive mutable borrow: any number of live `&`, or exactly one live `&mut`, never both (violations are E1302).

- `own` is **affine**: dropping without consuming is fine, not an error. Passing an owned local to a call, `return`, or field store consumes it.
- Storing an owned value into a field/subscript/graph object seals it into managed storage (**the membrane**): the source binding dies, and reading it back yields a plain managed value. `node`/`edge`/`walker` stay fully managed - no `own`/`&` of graph state.
- Borrows are second-class: returning or storing one is E1306 (single passthrough of a borrow *parameter* is allowed); a borrow outliving its owner is E1304.
- Sendability (E1308): only `imm`, moved `own` (including an `own Region` handle), or scalars cross `flow`/`thread_run` boundaries; live borrows never do.
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
- Graph-native: nodes/edges created under an open allocate in the arena; a walker ability grows the region automatically - its allocations anchor to the region of the visited node (`here`), no `&Region` field needed. Wiring region topology to managed topology (either direction) is E1307. Walkers themselves are now RC-managed and reclaimed (`def drop` fires once per instance), not immortal.
- Moving an `own Region` across `flow` transfers the whole subgraph zero-copy; legal only while no borrows of the handle are live.
- Python backend: memory stays GC-managed, but `drop` hooks fire at portable points - LIFO at the closing brace for an anonymous open, at handle death for a named one.
- `W1310` lints an open with an empty body. Region opens are rejected (E1406) inside nogc-enforced modules for now.

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
   | E1406 | Retaining/aliasing construct (`iter`/`globals`/`locals`, `managed()` of a heap value under `--gc none`, or an `in { }` region open) | Use an owned-compatible alternative or move the code out of the enforced module |

3. **Verify**: `--assert-no-rc` fails the build if the emitted IR contains any `__rc_*` helper, trace function, roots-buffer global, or entry-point GC env probe; on success it prints `assert-no-rc ok`.

Under `--gc none` an enforced module compiles **headerless**: owned payloads are bare `malloc` allocations (no RC header) and each free is a direct statically-placed `__drop_<T>` call, which also runs the user `def drop` hook. Note: an unhandled `raise` in an enforced module prints a line and calls `abort()` instead of unwinding.

## Measuring and debugging

- `JAC_RC_STATS=1 jac nacompile mod.jac` prints per-module RC coverage to stderr: `rc-stats [mod.jac] gc=cycles retains=1 releases=10 elided=3 coverage=21.4%` - a fully covered module shows `retains=0 releases=0 ... rc-free`. Move elision is proven automatically (core `RcFactsPass` backward-liveness), annotated or not.
- `JAC_NO_GC=1 ./binary` disables reclamation at run time in managed-mode binaries - useful to bisect whether a crash is RC-related (memory is then never freed).
- Reserved intrinsics callable from native code: `__rc_debug_enable()` / `__rc_debug_disable()` (log retain/release traffic), `__rc_gc_disable()` / `__rc_gc_enable()`, `__rc_collect_cycles()`. These names are claimed by the runtime - never define your own.

## Gotchas

- Ownership diagnostics gate native codegen (they are required analyses there), but whether they are *displayed* never changes the binary.
- A shared library (`--shared`) exports `jac_retain`/`jac_release` for host-side lifetime management **only when built under a managed gc mode**; a zero-RC (`--gc none`) library has no RC helpers to wrap, so those exports are absent by design.
- `linear` (must-use marker, E1305) is planned but **not implemented** - do not write it.
- `managed(x)` is the identity function on the Python backend; annotations there are checked, then erased.
- `jac build --as native` does not take the gc flags; use file-level `jac nacompile` for zero-RC builds.
