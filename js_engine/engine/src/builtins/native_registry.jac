"""
Native Function Registry

Provides the encoding, storage, and lookup helpers for native built-in
functions.  Both `dispatch.na.jac` and `streams.na.jac` import from this
module, which breaks the circular dependency that would otherwise exist
between them.

Encoding scheme:
  NATIVE_BASE = 2_000_000
  js_native_val(idx)  → JSValue{tag=Object, as_ptr=-(NATIVE_BASE + idx + 1)}
  is_native_val(v)    → v.tag == Object and jsv_to_table_id(v) < 0
                        and -(jsv_to_table_id(v)+1) >= NATIVE_BASE
  get_native_idx(v)   → -(jsv_to_table_id(v)+1) - NATIVE_BASE
  get_native_kind(v)  → _NR_REALM.natives[get_native_idx(v)].kind
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_int,
    js_undefined,
    jsv_from_cell_kind,
    jsv_from_string_id,
    jsv_is_cell,
    jsv_cell_kind,
    jsv_to_table_id,
    jsv_is_object_cell,
    jsv_is_undefined,
    JS_CELL_KIND_NATIVE
}
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.jsobject {
    JSProperty,
    js_object_create_null,
    js_object_set,
    js_object_has_own,
    js_object_delete,
    js_object_define_property,
    KEY_CTOR_KIND
}
import from engine.src.runtime.realm { Realm }
import from engine.src.runtime.encoding { NATIVE_BASE }
import from engine.src.runtime.wk_keys { WK_NAME, WK_LENGTH }
import from engine.src.builtins.native_type { NativeFn }

# ══════════════════════════════════════════════════════════════════════════════
# 1.  Storage
# ══════════════════════════════════════════════════════════════════════════════

"""Separator below which indices cannot appear in the global native table.
Canonical value in runtime/encoding.na.jac (imported above)."""
# Bridge realm singleton — holds realm.natives table.
# Set once by native_set_realm() at startup.  Analogous to _STR_REALM in jsstring.na.jac.
glob _NR_REALM: Realm;

"""Bind this module to a Realm.  Must be called before js_native_create()."""
def:pub native_set_realm(r: Realm) {
    _NR_REALM = r;
    _NR_SINGLETONS = {};  # native indices are per-realm
}

# ══════════════════════════════════════════════════════════════════════════════
# 2.  Encoding helpers
# ══════════════════════════════════════════════════════════════════════════════

"""Encode a _NR_REALM.natives index as a JSValue function."""
def:pub js_native_val(idx: int) -> JSValue {
    return jsv_from_cell_kind(NATIVE_BASE + idx, JS_CELL_KIND_NATIVE);
}

"""
Return True if v is a native built-in value registered through this module.
Must be checked BEFORE is_fn_val in the VM dispatch loop because native vals
also satisfy jsv_cell_kind == JS_CELL_KIND_NATIVE.
"""
def:pub is_native_val(v: JSValue) -> bool {
    if not jsv_is_cell(v) {
        return False;
    }
    if jsv_cell_kind(v) != JS_CELL_KIND_NATIVE {
        return False;
    }
    return jsv_to_table_id(v) >= NATIVE_BASE;
}

"""Decode the _NR_REALM.natives index from a native JSValue."""
def:pub get_native_idx(v: JSValue) -> int {
    return jsv_to_table_id(v) - NATIVE_BASE;
}

"""Return the dispatch kind for a native JSValue."""
def:pub get_native_kind(v: JSValue) -> int {
    idx: int = get_native_idx(v);
    if idx < 0 or idx >= len(_NR_REALM.natives) {
        return 0;
    }
    return _NR_REALM.natives[idx].kind;
}

"""Return the name string of a native function value."""
def:pub get_native_name(v: JSValue) -> str {
    if not is_native_val(v) {
        return "";
    }
    idx: int = get_native_idx(v);
    if idx < 0 or idx >= len(_NR_REALM.natives) {
        return "";
    }
    return _NR_REALM.natives[idx].name;
}

"""Return the arity (formal param count) of a native function value."""
def:pub get_native_arity(v: JSValue) -> int {
    if not is_native_val(v) {
        return 0;
    }
    idx: int = get_native_idx(v);
    if idx < 0 or idx >= len(_NR_REALM.natives) {
        return 0;
    }
    return _NR_REALM.natives[idx].arity;
}

"""Register a native function and return its JSValue."""
def:pub js_native_create(name: str, arity: int, kind: int) -> JSValue {
    fn: NativeFn = NativeFn(name=name, arity=arity, kind=kind);
    _NR_REALM.natives.append(fn);
    _NR_REALM.natives_mark_epoch.append(0);  # A2.2b GC mark bitmap
    return js_native_val(len(_NR_REALM.natives) - 1);
}

# One shared native per kind for the built-in methods the VM materialises on
# demand (fn.call/apply/bind, gen.next, (1).toFixed, str[Symbol.iterator], …).
# Natives are never swept, so minting a fresh one per property READ leaked a
# 96-byte cell forever — 4.2M live "call" natives (384MB) in a loop of
# RegExp.prototype.exec.call(r, s), and every fn.call in rollup's render. The
# spec has one Function.prototype.call anyway (fn.call === fn.call).
glob _NR_SINGLETONS: dict[int, JSValue] = {};

"""js_native_create, memoised per kind (name/arity are fixed per kind)."""
def:pub js_native_singleton(name: str, arity: int, kind: int) -> JSValue {
    if kind in _NR_SINGLETONS {
        return _NR_SINGLETONS[kind];
    }
    v: JSValue = js_native_create(name, arity, kind);
    _NR_SINGLETONS[kind] = v;
    return v;
}

"""Return the lazy own-property store for a native, or undefined if none yet."""
def:pub native_props_get(v: JSValue) -> JSValue {
    if not is_native_val(v) {
        return js_undefined();
    }
    idx: int = get_native_idx(v);
    if idx < 0 or idx >= len(_NR_REALM.natives) {
        return js_undefined();
    }
    return _NR_REALM.natives[idx].props;
}

"""Lazily create and return the own-property store for a native function."""
def:pub native_props_ensure(v: JSValue) -> JSValue {
    if not is_native_val(v) {
        return js_undefined();
    }
    idx: int = get_native_idx(v);
    if idx < 0 or idx >= len(_NR_REALM.natives) {
        return js_undefined();
    }
    p: JSValue = _NR_REALM.natives[idx].props;
    if jsv_is_object_cell(p) {
        return p;
    }
    p = js_object_create_null();
    _NR_REALM.natives[idx].props = p;
    return p;
}

"""True if the synthesized name/length intrinsic has been deleted (tombstone)."""
def:pub native_key_removed(v: JSValue, key: int) -> bool {
    if not is_native_val(v) {
        return False;
    }
    idx: int = get_native_idx(v);
    if idx < 0 or idx >= len(_NR_REALM.natives) {
        return False;
    }
    if key == WK_NAME {
        return _NR_REALM.natives[idx].name_removed;
    }
    if key == WK_LENGTH {
        return _NR_REALM.natives[idx].length_removed;
    }
    return False;
}

"""Mark synthesized name/length as deleted (configurable own property)."""
def:pub native_mark_key_removed(v: JSValue, key: int) -> None {
    if not is_native_val(v) {
        return;
    }
    idx: int = get_native_idx(v);
    if idx < 0 or idx >= len(_NR_REALM.natives) {
        return;
    }
    if key == WK_NAME {
        _NR_REALM.natives[idx].name_removed = True;
    } elif key == WK_LENGTH {
        _NR_REALM.natives[idx].length_removed = True;
    }
}

"""Clear a name/length tombstone (e.g. after defineProperty restore)."""
def:pub native_clear_key_removed(v: JSValue, key: int) -> None {
    if not is_native_val(v) {
        return;
    }
    idx: int = get_native_idx(v);
    if idx < 0 or idx >= len(_NR_REALM.natives) {
        return;
    }
    if key == WK_NAME {
        _NR_REALM.natives[idx].name_removed = False;
    } elif key == WK_LENGTH {
        _NR_REALM.natives[idx].length_removed = False;
    }
}

"""
Delete an own property of a native function.

For name/length: set tombstone (and remove any props override). Returns True
(configurable). For other keys: delete from the props store if present.
"""
def:pub native_delete_own(v: JSValue, key: int) -> bool {
    if not is_native_val(v) {
        return True;
    }
    idx: int = get_native_idx(v);
    if idx < 0 or idx >= len(_NR_REALM.natives) {
        return True;
    }
    p: JSValue = _NR_REALM.natives[idx].props;
    if jsv_is_object_cell(p) and js_object_has_own(p, key) {
        js_object_delete(p, key);
    }
    if key == WK_NAME {
        _NR_REALM.natives[idx].name_removed = True;
        return True;
    }
    if key == WK_LENGTH {
        _NR_REALM.natives[idx].length_removed = True;
        return True;
    }
    return True;
}

"""
Create a callable JSObject (constructor with static-method slots).

Unlike js_native_create() which returns an opaque encoding, this creates a
real JSObject so that static methods can be attached as ordinary properties.
The VM's CALL/CALL_METHOD/NEW handlers check for KEY_CTOR_KIND on the object
and dispatch to call_native(kind) directly.

ECMAScript: Function objects are ordinary objects that happen to be callable
(§10.2).  For native constructors we use this lighter representation.
"""
def:pub js_callable_create(name: str, arity: int, kind: int) -> JSValue {
    object: JSValue = js_object_create_null();
    js_object_set(object, KEY_CTOR_KIND, js_int(kind));
    k_len: int = str_intern("length");
    k_name: int = str_intern("name");
    js_object_define_property(
        object,
        k_len,
        JSProperty(
            key=k_len,
            value=js_int(arity),
            writable=False,
            enumerable=False,
            configurable=True,
            deleted=False
        )
    );
    js_object_define_property(
        object,
        k_name,
        JSProperty(
            key=k_name,
            value=jsv_from_string_id(str_intern(name)),
            writable=False,
            enumerable=False,
            configurable=True,
            deleted=False
        )
    );
    return object;
}
