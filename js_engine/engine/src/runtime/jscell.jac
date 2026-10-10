"""
runtime/jscell.na.jac — Cell-kind constants and GC flag bits.

Every heap-allocated JS cell carries three header fields:

    has cell_kind:    int = <KIND_CONST>;
    has cell_flags:   int = 0;
    has structure_id: int = 0;

These are copy-pasted verbatim into each cell-bearing struct (no inheritance —
open compiler bugs prevent mixin inheritance from working reliably).

Used by:
  - A2.2  mark bookkeeping helpers (gc_mark_object, gc_mark_closure, …)
  - A2.4  gc_mark() dispatch (switch on cell_kind)
  - B1    shape dispatch (structure_id → Shape lookup)
  - A2.5  FLAG_HAS_WEAK check during sweep

Phase: A2.1
"""

# ─── Cell-kind discriminators ────────────────────────────────────────────────
# These are stable IDs — do NOT renumber once A2.4 ships.

glob:pub CELL_KIND_OBJECT: int = 1,
     CELL_KIND_CLOSURE: int = 2,
     CELL_KIND_FUNCTION: int = 3,
     CELL_KIND_BUILTIN: int = 4,
     CELL_KIND_NATIVE: int = 5,
     CELL_KIND_MAP: int = 6,
     CELL_KIND_SET: int = 7,
     CELL_KIND_GENERATOR: int = 8,
     CELL_KIND_REGEXP: int = 9,
     CELL_KIND_SYMBOL: int = 10,
     CELL_KIND_STRING: int = 11,
     CELL_KIND_TIMER: int = 12,
     GC_CELL_OBJECT: int = CELL_KIND_OBJECT,
     GC_CELL_CLOSURE: int = CELL_KIND_CLOSURE,
     GC_CELL_FUNCTION: int = CELL_KIND_FUNCTION,
     GC_CELL_BUILTIN: int = CELL_KIND_BUILTIN,
     GC_CELL_NATIVE: int = CELL_KIND_NATIVE,
     GC_CELL_MAP: int = CELL_KIND_MAP,
     GC_CELL_SET: int = CELL_KIND_SET,
     GC_CELL_GENERATOR: int = CELL_KIND_GENERATOR,
     GC_CELL_REGEXP: int = CELL_KIND_REGEXP,
     GC_CELL_SYMBOL: int = CELL_KIND_SYMBOL,
     GC_CELL_STRING: int = CELL_KIND_STRING,
     GC_CELL_TIMER: int = CELL_KIND_TIMER,
     FLAG_MARKED: int = 1,
     FLAG_HAS_WEAK: int = 2,
     FLAG_FROZEN: int = 4,
     FLAG_SEALED: int = 8,
     FLAG_IS_PROTO: int = 16,
     FLAG_IS_CLASS: int = 32,
     FLAG_MODULE_NS: int = 64,
     CELL_FLAG_DEAD: int = 255,
     FLAG_NON_EXTENSIBLE: int = 256,
     FLAG_MAPPED_ARGS: int = 512,
     FLAG_IS_ARGUMENTS: int = 1024,
     FLAG_IS_GLOBAL: int = 2048;
# reserved for B3 (string interning refactor)
# internal: TimerEntry (not a JS-visible cell kind)

# GC header aliases (disambiguate from JSV_KIND_* NaN-box tags in jsvalue.na.jac)

# ─── cell_flags bit-field ────────────────────────────────────────────────────

# 0x01 — GC mark bit (set during mark phase)
# 0x02 — cell is referenced by a WeakRef/WeakMap
# 0x04 — Object.freeze()
# 0x08 — Object.seal()
# 0x10 — object serves as some object's [[Prototype]]
# 0x20 — object is a class (mirrors the WK_IS_CLASS own prop; lets the GET/SET hot paths route the class branch with a flag test instead of a per-access has_own shape probe)
#        (gates the dense-elements index protector)
# 0x40 — Module Namespace Exotic Object (§10.4.6); replaces the former inline JSObject.is_module_namespace bool (docs/OBJECT_FOOTPRINT_PLAN.md Phase 1). Never cleared on a live object, so no bit-clear path is needed.
# 0xFF — slot reclaimed by GC sweep; reuse-eligible
# P5 packs three former inline JSObject bools into cell_flags. Bits are ABOVE the
# 0xFF DEAD sentinel so no combination of live flags can ever equal CELL_FLAG_DEAD.
# All three are set-only on a live object (JS [[PreventExtensions]] is one-way; the
# arguments flags are set once at creation) and cleared only by the `cell_flags = 0`
# slot-reuse reset — so no bitwise-NOT clear path is needed (Jac has none in use).
# 0x100 — set ⇒ [[Extensible]] is false (default 0 ⇒ extensible)
# 0x200 — mapped `arguments` exotic (parameter-slot aliasing)
# 0x400 — mapped OR unmapped `arguments` object
# 0x800 — the realm's global object: every write is
#         recorded (global_obj_note_write) so bare
#         global-name reads pick it up; kept off the
#         shape ICs so no write bypasses that record
