"""
NativeFn type definition — shared by builtins/native_registry.na.jac and realm.na.jac.

Does NOT import runtime.realm (that would create a cycle).
Does NOT define _NATIVE_TABLE — that stays in native_registry.na.jac.
"""

import from engine.src.runtime.jsvalue { JSValue, js_undefined }


# ═══════════════════════════════════════════════════════════════════════════════
# NativeFn
# ═══════════════════════════════════════════════════════════════════════════════

"""Descriptor stored per registered native function.

`props` is a lazily-created null-proto JSObject for user-defined own properties
(and for restored `name`/`length` after delete+defineProperty). `name_removed`
/ `length_removed` are tombstones so configurable `name`/`length` can be deleted
without allocating until mutation.
"""
obj:pub NativeFn {
    has name: str,
        arity: int,
        kind: int,
        props: JSValue = js_undefined(),
        name_removed: bool = False,
        length_removed: bool = False,
        cell_kind: int = 5,
        cell_flags: int = 0,
        structure_id: int = 0;
}
# Own-property store (lazy) + configurable name/length tombstones (R3).

# ── Cell header (A2.1) ─────────────────────────────────────────────────
# CELL_KIND_NATIVE
