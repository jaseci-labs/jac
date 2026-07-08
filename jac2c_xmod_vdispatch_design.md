# jac2c cross-module virtual dispatch — design (Leg 3 follow-up)

Status: **scoped + root-caused, not yet implemented.** Blocked on testing only
(the multi-module emit commit must land and the compiler cache must be warm).
Two findings below are now CONFIRMED from source, and they make this increment
larger than first assumed — the gating sub-problem is *whole-program vtable
decisions*, not just an extern-layout fallback.

## The bug

```
# lib.jac
obj Shape { def area -> int { return 0; } }

# main.jac
import from lib { Shape }
obj Sq(Shape) { has s:int; def init(s:int){self.s=s;} def area->int{return self.s*self.s;} }
def poly(sh: Shape) -> int { return sh.area(); }        # virtual site
```

`poly(Sq(4))` must return 16, `poly(Shape())` must return 0. Today both corrupt
memory / mis-dispatch. Three independent defects, in dependency order:

## Finding 1 — CONFIRMED: layout is local-only (this is case B)

`get_layout_registry(main_mod)` (layout_pass.jac:57) builds from
`_collect_archetypes` → `UniPass.get_all_sub_nodes(module, uni.Archetype)`
(layout_pass.impl.jac:49). `get_all_sub_nodes` reads `nd._sub_node_tab[typ]`
(uni_pass.jac:21-34) — the sub-node table of that **one** Module node. Imported
modules are separate `uni.Module` objects linked through the import symbol, NOT
inlined as child nodes of the importer, so `Shape`'s Archetype is absent from
main's table.

Consequence: in main's registry `get_layout("Shape")` is `None`, so
`has_vtable("Shape")` (c_gen_pass.jac:313) is False, and `extern_decls` →
`gen_ref_struct(Shape)` emits `struct Shape` **without** the leading
`void **__vtable;` member. A local `Sq` that carries a vtable then disagrees with
`Shape`'s extern struct on field offsets — ABI mismatch.

Fix lever: `index_imported(sub)` (c_gen_pass.jac:134) already holds the fully
compiled imported module `sub` (from `JacProgram().compile(path)` at line 113).
So we can call `get_layout_registry(sub, self.prog)` right there and stash each
imported ref-type's *own-TU* layout in a new `extern_layout` dict.

## Finding 2 — CONFIRMED: vtable-ness is decided per-TU, but it's whole-program

`needs_vtable` (layout_pass.impl.jac:206):
`needs_vtable = bool(parents) or aname in parents_set`, where `parents_set` is
every parent named in **this registry's** `class_parents`. lib.jac compiled alone
has only `Shape` and no local subclass → `parents_set` is empty → `Shape` gets
**no vtable** in lib.c. So lib.c emits:

- `struct Shape` with no `__vtable` member,
- no `Shape__vtable[]` array,
- a `Shape__new` that never sets `__vtable`.

But main.c subclasses `Shape` and dispatches `sh.area()` virtually through
`recv->__vtable`. `poly(Shape())` reads `__vtable` from a `Shape` that lib.c
never gave one → garbage. This is the core issue: **"does any module subclass
Shape?" is a whole-program question, and each independently-emitted TU
(test `_emit_c`, one fresh `CGenPass` per module — test:43-47) answers it with
only local knowledge.**

## Finding 3 — slot numbering diverges even for the local subclass

`_build_vtable_layout` for `Sq` (layout_pass.impl.jac:279) walks `mro[1:]` and
does `reg.layouts.get("Shape")` → `None` (Finding 1) → skips Shape's methods.
So main numbers `Sq`'s slots from Sq's own `get_methods()` order only. If Sq is
`def init; def area`, `area` lands at slot 1. But lib.c's `Shape__vtable[]`
numbers `area` at slot 0. The virtual site types the receiver as `Shape` and uses
Shape's slot (0) → in Sq's vtable that slot is `init`. Mis-dispatch.

The ABI invariant that must hold in every TU that emits or forward-declares `T`:

- `__vtable` is the first struct member (already true within a TU), and
- slot index of method `m` on `T` = pure function of `T`'s MRO + method-intro
  order — reproduced identically in the defining TU and every importing TU.

Finding 3 says main can only reproduce Sq's numbering if it sees Shape's method
set as the MRO prefix.

## Root cause (unifying 1–3)

All three are the same defect: **each TU is emitted from its own local layout
registry.** Correct cross-module dispatch needs one *program-wide* layout that has
seen every module, so that (a) `needs_vtable(Shape)` accounts for Sq, (b) Sq's
slots are numbered with Shape's prefix, and (c) the extern `struct Shape` gets the
matching `__vtable` + field order. Findings 1/3's `extern_layout` fallback is
necessary but NOT sufficient on its own — it fixes the importer's view of Shape,
but lib.c still has to actually *emit* Shape's vtable, which is Finding 2.

## Recommended fix — whole-program shared layout

Drive **all** TUs from one shared layout registry rather than per-module
independent compiles.

1. Build a combined arch_map over `main + every transitively-imported module`
   (reuse the imported `uni.Module`s already gathered in `classify_imports`).
2. Compute one `LayoutRegistry` over that combined arch_map (MRO, needs_vtable,
   fields, method slots) — so `Shape.needs_vtable` is True (Sq subclasses it) and
   Sq's slots are numbered with Shape's method prefix.
3. Seed every `CGenPass` (main's and each import's) with that shared registry
   instead of letting each call `get_layout_registry(mod)` locally. Concretely:
   add an optional `shared_layout` to `load_layout` — when present, use it; else
   fall back to the local build (preserves single-module behavior + native path).
4. The emission driver (today: test `_emit_c` running an independent pass per
   file) becomes a small orchestrator: compute shared layout once, then emit main
   - each import through passes carrying it. This is the real new surface area.

With the shared layout: lib.c emits `Shape__vtable[]` (slot 0 = `Shape__area`) and
`Shape__new` sets `__vtable`; main.c emits `Sq__vtable[]` (slot 0 = `Sq__area`,
slot 1 = `Sq__init`) and the extern `struct Shape` gets `__vtable` first. Dispatch
through slot 0 is correct for both `Shape()` and `Sq()`.

### Rejected alternative — conservative vtables

"Any exported ref arch always gets a vtable" (force `needs_vtable=True` for
exportable types). Smaller diff, but: (a) still needs the slot prefix to agree, so
it does NOT remove the shared-layout requirement (Finding 3 stands); (b) touching
`needs_vtable` in the shared layout_pass also changes the native backend's ABI;
(c) wastes a pointer + indirection on every leaf obj. Shared layout is both more
correct and more contained (opt-in, c-backend-only).

## Implementation increment plan

- **Step A (plumbing, safe alone):** `extern_layout` dict + build it in
  `index_imported` via `get_layout_registry(sub, self.prog)`; add fallback in
  `has_vtable` / `mro_of` / `layout_fields` so the importer's *view* of an extern
  base is correct. Lands the ABI-struct agreement (Finding 1). No behavior change
  for single-module emit.
- **Step B (the real fix):** shared program-wide layout seeded into each pass
  (Findings 2+3). Introduce the emission orchestrator; add `shared_layout` opt-in
  to `load_layout`.
- **Step C (proof):** the fixture below; assert differential equality.

## Fixture (differential, mirrors test_jac2c_multimodule.jac)

- `xmod_base.jac`: `obj Shape { def area -> int { return 0; } }`
- `xmod_main.jac`: `import from xmod_base { Shape }`;
  `obj Sq(Shape) { has s:int; def init(s:int){self.s=s;} def area->int{return self.s*self.s;} }`;
  `def poly(sh: Shape) -> int { return sh.area(); }`;
  `run_poly` → `poly(Sq(4))` == 16 (override) and `poly(Shape())` == 0.
- Oracle: `_c_output() == _cpython_output()`, same harness/driver as the
  multimodule test.
- Structural asserts: main.c's extern `struct Shape` contains `void **__vtable;`,
  lib.c emits `Shape__vtable[`, and the call site uses `jac_vtable_slot(` not a
  direct `Shape__area(`.
- NOTE: this fixture FAILS until Step B lands — it is the proof of the whole
  increment, not just Step A.

## Not in this increment (documented, deferred)

- Transitive base chains across 3+ modules (A→B→C): `classify_imports`
  (c_gen_pass.jac:94) walks only **direct** imports of `mod.body`. The combined
  arch_map in Step B must recurse the import graph. Fold into Step B or a follow-up.
- Cross-module abstract/pure-virtual methods with no local override.
- Ownership facts across the vtable boundary (dtor slot / rc release on imported
  bases).
