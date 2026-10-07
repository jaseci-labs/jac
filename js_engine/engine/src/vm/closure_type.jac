"""
JSClosure type definition — shared by vm.na.jac and realm.na.jac.

Does NOT import runtime.realm (that would create a cycle).
Does NOT define _CLOSURE_TABLE — that stays in vm.na.jac.
"""

import from engine.src.runtime.jsvalue { JSValue, js_undefined }
import from engine.src.bytecode.op { CompiledFunction }


# ═══════════════════════════════════════════════════════════════════════════════
# JSClosure
# ═══════════════════════════════════════════════════════════════════════════════

"""A compiled function bundled with the outer-scope values it has captured.

GC invariant: every JSValue-holding field added here MUST also be traced in
runtime/gc.na.jac's closure arm of gc_trace, or its referent can be swept
while live.
"""
obj:pub JSClosure {
    has func: CompiledFunction,
        free_vals: list[JSValue],
        lexical_this: JSValue,
        prototype_obj: JSValue,
        super_class: JSValue,
        fn_props: JSValue,
        module_fns: list[CompiledFunction],
        is_arrow: bool,
        is_non_constructor: bool = False,
        name_deleted: bool = False,
        length_deleted: bool = False,
        home_object: JSValue = js_undefined(),
        object_proto: JSValue = js_undefined(),
        name_removed: bool = False,
        length_removed: bool = False,
        lexical_new_target: JSValue = js_undefined(),
        napi_cb_ptr: int = 0,
        napi_cb_data: int = 0,
        cell_kind: int = 2,
        cell_flags: int = 0,
        structure_id: int = 0,
        captured_with_objs: list[JSValue] = [],
        this_binding_cell: JSValue = 0,
        class_brand: JSValue = 0,
        class_brand_sid: int = 0,
        home_realm_id: int = 0,
        prototype_writable: bool = True,
        jac_module: JSValue = js_undefined();
}
# captured values (index = free_vars slot)
# lexical `this` for arrow functions
# the function's .prototype property (for `new`)
# super class JSValue set by DEFINE_METHOD
# backing JSObject for user-defined properties
# compilation unit this closure belongs to
# True for arrow functions (not [[Construct]]able)
# Built-in / JS-layer methods marked non-constructible via __jacMarkNonConstructor.
# Distinct from is_method (concise methods): plain function expressions used as
# builtin methods need this flag so IsConstructor returns false.

# `name` / `length` are configurable own properties: a `delete fn.name` removes
# them (they become absent).  Track that here since they are otherwise synthesized.

# [[HomeObject]] for a concise *object-literal* method (B13): super.x resolves to
# GetPrototypeOf(home_object)[x]. Undefined for class methods (which use
# super_class.prototype instead) and ordinary functions.

# Function object's [[Prototype]] internal slot (defaults to %Function.prototype%
# when undefined). Used by Object.getPrototypeOf / setPrototypeOf on closures.

# Tombstones for configurable delete of synthesized name/length (spec §10.1.10).

# Lexical `new.target` for arrow functions (captured at MAKE_ARROW).

# ── NAPI callback fields (Phase N4) ───────────────────────────────────
# C napi_callback fn ptr (uintptr_t); 0 = Jac closure
# user data pointer for napi_get_cb_info
# ── Cell header (A2.1) ─────────────────────────────────────────────────
# CELL_KIND_CLOSURE

# `with` object environment records captured at closure creation (innermost
# last).  A function defined inside a `with` body inherits that object env
# record on its scope chain (ES §9.1 lexical environments), so name
# resolution inside the closure must consult these before globals.  Empty
# for the common case (closure not created inside a `with`).

# Shared this-binding cell (ES §9.1.1.3 FunctionEnvironment [[ThisBindingStatus]]):
# an arrow lexically nested in a DERIVED constructor captures that ctor's this-binding
# record so `super()` inside the arrow initializes (or double-inits → ReferenceError)
# the enclosing ctor's `this`. A make_cell holding the TDZ sentinel = uninitialized,
# else the bound `this`. 0 = ordinary closure (no shared this-binding). Appended LAST —
# struct field order is offset-sensitive.

# Per-EVALUATION private brand of the class this closure is a member of (method,
# accessor, field initializer, or constructor). Captured at DEFINE_METHOD / DEFINE_FIELD
# / DEFINE_GETTER / DEFINE_SETTER time from the class object's `__brand@cur`. A private
# access compares this to the target object's own `__brand@<sid>` (ES §6.2.12 / §15.7 —
# each class *evaluation* mints fresh private names). 0 = not a class member (private
# access falls back to the legacy presence check). Appended LAST — offset-sensitive.

# The class SCOPE id (compile-time `@<sid>`) that `class_brand` belongs to. A private
# access `obj.#x` (mangled `__priv_#x@<sid>`) enforces the per-eval brand ONLY when the
# key's sid == this sid — i.e. the private is the accessing class's OWN. For an OUTER
# class's private accessed from a NESTED class (different sid) the value-compare is
# skipped (lenient presence), since the accessing closure's brand is a different class's.
# Appended LAST — offset-sensitive.

# The realm this function was DEFINED in (ES GetFunctionRealm / cross-realm brand
# checks). Set when a foreign realm's `eval`/Function creates code; inherited by nested
# functions/arrows/methods (lexical). A runtime TypeError thrown by this function's body
# (e.g. a private-brand-check failure) uses this realm's %TypeError% so `assert.throws
# (realm.TypeError, …)` in cross-realm test262 tests observes the correct constructor.
# 0 = the process/default realm. Appended LAST — offset-sensitive.

# [[Writable]] of the synthesized `prototype` own property (ES §10.2.4). A function's
# prototype starts { writable:true, enumerable:false, configurable:false };
# Object.defineProperty may downgrade writable to false (a non-configurable data
# property still permits true→false), after which `fn.prototype = x` is a no-op
# (sloppy) / TypeError (strict). Appended LAST — offset-sensitive.

# The CJS module object this closure was defined in (also stored as the hidden
# `__jacModule` own property of fn_props, which is what code outside the VM
# reads). _fn_jac_module reads this field: every inline call asks for it, and
# the property read walked fn_props' prototype chain for every non-CJS closure.
# Set wherever WK_JAC_MODULE is set. Appended LAST — offset-sensitive.
