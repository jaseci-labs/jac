"""
Iterator factory.

js_make_iterator(v) extracts the GET_ITER opcode logic into a callable function
so that both the VM opcode and the Symbol.iterator native dispatch can share it
without duplicating code.

Iterator shape (plain JSObject):
  __I  — source array (JS Array JSValue):
           • Array  → the array itself
           • String → chars array built from the string
           • Object → enumerable string-key names as a string array
           • Other  → empty array
  __J  — current index (Int32, starts at 0)

ECMAScript spec: §7.4 Iterator Records, §25.1 Iteration

R15: CreateArrayIterator / %ArrayIteratorPrototype% (§23.1.5)
  Hidden own slots (not WK_I/WK_J — those divert into the legacy shell path):
    __AI_TARGET__ — [[IteratedArrayLike]] (undefined once permanently closed)
    __AI_INDEX__  — [[ArrayLikeNextIndex]]
    __AI_KIND__   — [[ArrayLikeIterationKind]] (0=key, 1=value, 2=key+value)
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_int,
    jsv_undefined,
    jsv_is_object_cell,
    jsv_is_string_cell,
    jsv_is_undefined,
    jsv_is_int32,
    jsv_is_double,
    jsv_to_table_id,
    jsv_to_int32,
    jsv_to_double,
    jsv_from_string_id
}
import from engine.src.runtime.encoding { SYMBOL_KEY_BASE }
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_create,
    js_object_set,
    js_object_get,
    js_object_keys,
    js_object_has_own,
    js_object_define_property,
    js_object_get_ordinary_proto,
    js_object_set_prototype,
    SYMBOL_KEY_BASE
}
import from engine.src.runtime.wk_keys { WK_LENGTH }
import from engine.src.runtime.gc_pin { gc_pin_value }
import from engine.src.runtime.jsobj_type { JSProperty }
import from engine.src.runtime.jsstring {
    str_intern_index,
    str_intern,
    str_from_id,
    str_substr,
    js_string_utf16_units,
    utf16_units_to_scalars,
    utf8_encode_scalar
}
import from engine.src.runtime.wk_keys { WK_NEXT }
import from engine.src.runtime.jssymbol { SYMBOL_ITERATOR, SYMBOL_TO_STRING_TAG }
import from engine.src.builtins.array { _KEY_IS_ARRAY, js_array_create, js_is_array }
import from engine.src.builtins.markers { _KEY_IS_ARGUMENTS }
import from engine.src.builtins.string { is_string_object, string_value_of }
import from engine.src.builtins.native_registry { js_native_create }
import from engine.src.builtins.native_kinds {
    NATIVE_KIND_ARRAY_ITER_NEXT,
    NATIVE_KIND_ITERATOR_RETURN_THIS
}

# ── Array Iterator kind constants (§23.1.5) ───────────────────────────────────
glob:pub ARRAY_ITER_KIND_KEY: int = 0,
     ARRAY_ITER_KIND_VALUE: int = 1,
     ARRAY_ITER_KIND_KEY_VALUE: int = 2;

# Hidden internal-slot keys (lazily interned once).
glob _AI_TARGET_KEY: int = -1,
     _AI_INDEX_KEY: int = -1,
     _AI_KIND_KEY: int = -1;

def _ai_target_key -> int {
    if _AI_TARGET_KEY < 0 {
        _AI_TARGET_KEY = str_intern("__AI_TARGET__");
    }
    return _AI_TARGET_KEY;
}

def _ai_index_key -> int {
    if _AI_INDEX_KEY < 0 {
        _AI_INDEX_KEY = str_intern("__AI_INDEX__");
    }
    return _AI_INDEX_KEY;
}

def _ai_kind_key -> int {
    if _AI_KIND_KEY < 0 {
        _AI_KIND_KEY = str_intern("__AI_KIND__");
    }
    return _AI_KIND_KEY;
}

# Lazy singleton %ArrayIteratorPrototype%.
glob _ARRAY_ITERATOR_PROTO: JSValue = jsv_undefined(),
     _ITERATOR_HELPER_PROTO: JSValue = jsv_undefined();

"""After Iterator.prototype is installed, chain %ArrayIteratorPrototype% from it."""
def:pub js_set_iterator_helper_proto(p: JSValue) {
    _ITERATOR_HELPER_PROTO = p;
    gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
    if jsv_is_object_cell(_ARRAY_ITERATOR_PROTO)
        and jsv_to_table_id(_ARRAY_ITERATOR_PROTO) > 0 {
        js_object_set_prototype(_ARRAY_ITERATOR_PROTO, p);
    }
}

"""
Return %ArrayIteratorPrototype% (§23.1.5.2), creating it on first use.
[[Prototype]] = Object.prototype.
Own properties:
  next, [Symbol.iterator] (return this), [Symbol.toStringTag] = "Array Iterator".
"""
def:pub js_get_array_iterator_proto -> JSValue {
    if not jsv_is_object_cell(_ARRAY_ITERATOR_PROTO) {
        ai_super: JSValue = js_object_get_ordinary_proto();
        if jsv_is_object_cell(_ITERATOR_HELPER_PROTO)
            and jsv_to_table_id(_ITERATOR_HELPER_PROTO) > 0 {
            ai_super = _ITERATOR_HELPER_PROTO;
        }
        p: JSValue = js_object_create(ai_super);
        next_fn: JSValue = js_native_create("next", 0, NATIVE_KIND_ARRAY_ITER_NEXT);
        js_object_define_property(
            p,
            WK_NEXT,
            JSProperty(
                key=WK_NEXT,
                value=next_fn,
                writable=True,
                enumerable=False,
                configurable=True,
                deleted=False
            )
        );
        iter_key: int = SYMBOL_KEY_BASE + SYMBOL_ITERATOR;
        iter_fn: JSValue = js_native_create(
            "[Symbol.iterator]", 0, NATIVE_KIND_ITERATOR_RETURN_THIS
        );
        js_object_define_property(
            p,
            iter_key,
            JSProperty(
                key=iter_key,
                value=iter_fn,
                writable=True,
                enumerable=False,
                configurable=True,
                deleted=False
            )
        );
        tag_key: int = SYMBOL_KEY_BASE + SYMBOL_TO_STRING_TAG;
        tag_val: JSValue = jsv_from_string_id(str_intern("Array Iterator"));
        js_object_define_property(
            p,
            tag_key,
            JSProperty(
                key=tag_key,
                value=tag_val,
                writable=False,
                enumerable=False,
                configurable=True,
                deleted=False
            )
        );
        _ARRAY_ITERATOR_PROTO = p;
        gc_pin_value(p);  # glob-held singleton — invisible to the GC root walk
    }
    return _ARRAY_ITERATOR_PROTO;
}

"""CreateArrayIterator(array, kind) — §23.1.5.1."""
def:pub js_make_array_iterator(o: JSValue, kind: int) -> JSValue {
    it: JSValue = js_object_create(js_get_array_iterator_proto());
    js_object_set(it, _ai_target_key(), o);
    js_object_set(it, _ai_index_key(), js_int(0));
    js_object_set(it, _ai_kind_key(), js_int(kind));
    return it;
}

"""True iff v is an Array Iterator instance (has [[IteratedArrayLike]] slot)."""
def:pub _ai_is_instance(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    return js_object_has_own(v, _ai_target_key());
}

def:pub _ai_get_target(it: JSValue) -> JSValue {
    return js_object_get(it, _ai_target_key());
}

def:pub _ai_set_target(it: JSValue, v: JSValue) {
    js_object_set(it, _ai_target_key(), v);
}

def:pub _ai_get_index(it: JSValue) -> int {
    idx_v: JSValue = js_object_get(it, _ai_index_key());
    if jsv_is_int32(idx_v) {
        return jsv_to_int32(idx_v);
    }
    if jsv_is_double(idx_v) {
        return int(jsv_to_double(idx_v));
    }
    return 0;
}

def:pub _ai_set_index(it: JSValue, idx: int) {
    js_object_set(it, _ai_index_key(), js_int(idx));
}

def:pub _ai_get_kind(it: JSValue) -> int {
    kind_v: JSValue = js_object_get(it, _ai_kind_key());
    if jsv_is_int32(kind_v) {
        return jsv_to_int32(kind_v);
    }
    if jsv_is_double(kind_v) {
        return int(jsv_to_double(kind_v));
    }
    return ARRAY_ITER_KIND_VALUE;
}

"""
Build and return an iterator object `{__I: src_arr, __J: 0}` for v.

Rules (mirrors GET_ITER VM opcode):
  JS Array  → iterate element values directly
  String    → iterate characters (each as a single-char String JSValue)
  JSObject  → iterate enumerable string-keyed property names (symbol keys hidden)
  Anything  → empty iterator

Used by: Symbol.iterator native dispatch, any future higher-level iterable calls.
"""
def:pub js_make_iterator(v: JSValue) -> JSValue {
    src_arr: JSValue = js_undefined();

    if jsv_is_object_cell(v) and js_is_array(v) {
        # Array — iterate element values
        src_arr = v;
    } elif jsv_is_string_cell(v) or is_string_object(v) {
        # String primitive or String exotic — iterate Unicode code points
        # (ES §22.1.5 StringIterator). String objects must not fall through to
        # plain-object key iteration (indices are exotic, not ordinary own keys).
        jmi_prim: JSValue = string_value_of(v);
        jmi_s: str = str_from_id(jsv_to_table_id(jmi_prim));
        jmi_chars: list[JSValue] = [];
        jmi_scalars: list[int] = utf16_units_to_scalars(js_string_utf16_units(jmi_s));
        for jmi_cp in jmi_scalars {
            jmi_chars.append(
                jsv_from_string_id(str_intern(utf8_encode_scalar(jmi_cp)))
            );
        }
        src_arr = js_array_create(jmi_chars);
    } elif jsv_is_object_cell(v) and js_object_has_own(v, _KEY_IS_ARGUMENTS) {
        # `arguments` exotic object — iterate the indexed VALUES (0..length-1) like an
        # array, NOT the property names (ES §10.4.4: its @@iterator is
        # %Array.prototype.values%).
        jmi_len_v: JSValue = js_object_get(v, WK_LENGTH);
        jmi_len: int = 0;
        if jsv_is_int32(jmi_len_v) {
            jmi_len = jsv_to_int32(jmi_len_v);
        } elif jsv_is_double(jmi_len_v) {
            jmi_len = int(jsv_to_double(jmi_len_v));
        }
        jmi_vals: list[JSValue] = [];
        jmi_vi: int = 0;
        while jmi_vi < jmi_len {
            jmi_vals.append(js_object_get(v, str_intern_index(jmi_vi)));
            jmi_vi = jmi_vi + 1;
        }
        src_arr = js_array_create(jmi_vals);
    } elif jsv_is_object_cell(v) {
        # Plain object — iterate enumerable string-keyed property names
        jmi_kids: list[int] = js_object_keys(v);
        jmi_keys: list[JSValue] = [];
        jmi_ki: int = 0;
        jmi_kn: int = len(jmi_kids);
        while jmi_ki < jmi_kn {
            jmi_kid: int = jmi_kids[jmi_ki];
            # Skip symbol-keyed properties and hidden markers (_KEY_IS_ARRAY etc.)
            if jmi_kid < SYMBOL_KEY_BASE and jmi_kid != _KEY_IS_ARRAY {
                jmi_ks: str = str_from_id(jmi_kid);
                if jmi_ks != "" {
                    jmi_keys.append(jsv_from_string_id(str_intern(jmi_ks)));
                }
            }
            jmi_ki = jmi_ki + 1;
        }
        src_arr = js_array_create(jmi_keys);
    } else {
        # Anything else — empty iterator
        src_arr = js_array_create([]);
    }

    # Build the iterator object with @@iterator so Array.from / for-of GetMethod work.
    jmi_iter: JSValue = js_object_create_null();
    js_object_set(jmi_iter, str_intern("__I"), src_arr);
    js_object_set(jmi_iter, str_intern("__J"), js_int(0));
    jmi_iter_key: int = SYMBOL_KEY_BASE + SYMBOL_ITERATOR;
    jmi_iter_fn: JSValue = js_native_create(
        "[Symbol.iterator]", 0, NATIVE_KIND_ITERATOR_RETURN_THIS
    );
    js_object_define_property(
        jmi_iter,
        jmi_iter_key,
        JSProperty(
            key=jmi_iter_key,
            value=jmi_iter_fn,
            writable=True,
            enumerable=False,
            configurable=True,
            deleted=False
        )
    );
    return jmi_iter;
}
