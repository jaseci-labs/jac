"""
JSFunctionMeta and BuiltinFn type definitions — shared by builtins/function.na.jac and realm.na.jac.

Does NOT import runtime.realm (that would create a cycle).
Does NOT define _FUNCTION_TABLE or _BUILTIN_TABLE — those stay in function.na.jac.
"""

import from engine.src.runtime.jsvalue { JSValue }


# ═══════════════════════════════════════════════════════════════════════════════
# JSFunctionMeta
# ═══════════════════════════════════════════════════════════════════════════════

"""
Metadata stored for every compiled JS function value.

  name         — [[Name]] shown in stack traces and .name property
  arg_count    — [[FormalParameters]].length  (§10.2.8)
  prototype_obj — the .prototype property (for `new`)
  source        — original source text (for .toString())
"""
obj:pub JSFunctionMeta {
    has name: str,
        arg_count: int,
        prototype_obj: JSValue,
        source: str,
        cell_kind: int = 3,
        cell_flags: int = 0,
        structure_id: int = 0;
}


# ── Cell header (A2.1) ─────────────────────────────────────────────────
# CELL_KIND_FUNCTION
# ═══════════════════════════════════════════════════════════════════════════════
# BuiltinFn
# ═══════════════════════════════════════════════════════════════════════════════

"""
Descriptor for a native Jac function exposed as a callable JS value.

  name   — the function's [[Name]] (shown in stack traces, .toString())
  arity  — formal parameter count (JS .length property)
  kind   — stable numeric dispatch ID; VM will switch on this
           to invoke the corresponding Jac implementation.

ECMAScript §10.3 — Built-in Function Objects
"""
obj:pub BuiltinFn {
    has name: str,
        arity: int,
        kind: int,
        cell_kind: int = 4,
        cell_flags: int = 0,
        structure_id: int = 0;
}
# ── Cell header (A2.1) ─────────────────────────────────────────────────
# CELL_KIND_BUILTIN
