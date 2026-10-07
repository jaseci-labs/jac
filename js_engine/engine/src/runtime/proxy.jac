"""
ECMAScript Proxy objects — creation, revocation, and type identification.

Trap dispatch lives in src/vm/vm.na.jac (requires vm_call_js_fn).
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_int,
    jsv_is_cell,
    jsv_is_object_cell,
    jsv_is_undefined,
    jsv_is_any_object,
    jsv_is_htmldda,
    jsv_is_int32,
    jsv_to_int32,
    jsv_to_table_id,
    jsv_cell_kind,
    JS_CELL_KIND_NATIVE,
    jsv_from_string_id
}
import from engine.src.runtime.wk_keys { WK_IS_CLASS }
import from engine.src.builtins.native_registry {
    is_native_val,
    get_native_kind,
    js_native_create
}
import from engine.src.runtime.jsobject {
    js_object_get,
    js_object_set,
    js_object_has_own,
    js_object_create_null,
    js_object_define_property,
    JSProperty,
    js_object_table_get,
    js_object_alloc_slot,
    js_object_wrap_slot,
    KEY_CTOR_KIND,
    js_object_class_id_id
}
import from engine.src.runtime.jsstring { str_intern, str_get_realm }
import from engine.src.runtime.error {
    make_type_error,
    vm_throw_native,
    vm_has_native_exc
}
import from engine.src.runtime.jsobj_type { JSObject, ProxyState }
import from engine.src.builtins.native_kinds {
    NATIVE_KIND_PROXY_REVOKE,
    native_kind_is_constructible
}

glob:pub CLASS_ID_PROXY: int = 1;

glob _K_PROXY_REF: int = 0;

def:pub proxy_init_keys {
    _K_PROXY_REF = str_intern("_jacProxyRef");
}

def _proxy_raw(idx: int) -> JSObject {
    return js_object_table_get(idx);
}

# Proxy internal slots live in realm.proxy_slots[idx] (a ProxyState row created
# by js_proxy_create), not on the JSObject — see docs/OBJECT_FOOTPRINT_PLAN.md.
# A row exists for every class_id==CLASS_ID_PROXY object, so every caller here
# guards on js_is_proxy(p) first.
def _px(idx: int) -> ProxyState {
    return str_get_realm().proxy_slots[idx];
}

def:pub js_is_proxy(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    idx: int = jsv_to_table_id(v);
    if idx <= 0 {
        return False;
    }
    # Scalar field read — no JSObject reference (this runs ~50M times in a
    # vite build, ahead of most property operations).
    return js_object_class_id_id(idx) == CLASS_ID_PROXY;
}

def:pub js_proxy_is_revoked(p: JSValue) -> bool {
    if not js_is_proxy(p) {
        return False;
    }
    return _px(jsv_to_table_id(p)).revoked;
}

def:pub js_proxy_target(p: JSValue) -> JSValue {
    if not js_is_proxy(p) {
        return js_undefined();
    }
    return _px(jsv_to_table_id(p)).target;
}

def:pub js_proxy_handler(p: JSValue) -> JSValue {
    if not js_is_proxy(p) {
        return js_undefined();
    }
    return _px(jsv_to_table_id(p)).handler;
}

def:pub js_proxy_mark_revoked(p: JSValue) -> None {
    if not js_is_proxy(p) {
        return;
    }
    _px(jsv_to_table_id(p)).revoked = True;
}

"""IsCallable(target) at ProxyCreate — includes nested callable Proxies."""
def _proxy_compute_callable(target: JSValue) -> bool {
    if jsv_is_htmldda(target) {
        return True;
    }
    if is_native_val(target) {
        return True;
    }
    if jsv_is_cell(target) and jsv_cell_kind(target) == JS_CELL_KIND_NATIVE {
        if jsv_to_table_id(target) < 1000000 {
            return True;
        }
    }
    if js_is_proxy(target) {
        # Revocation clears [[ProxyHandler]] but does not remove [[Call]].
        # ProxyCreate of a revoked callable Proxy must still be callable
        # (test262 create-target-is-revoked-function-proxy).
        return _px(jsv_to_table_id(target)).callable;
    }
    if jsv_is_object_cell(target) and jsv_to_table_id(target) > 0 {
        if js_object_has_own(target, KEY_CTOR_KIND) {
            return True;
        }
        if js_object_has_own(target, WK_IS_CLASS) {
            return True;
        }
    }
    return False;
}

"""IsConstructor(target) snapshot at ProxyCreate — nested Proxies use stored bit."""
def _proxy_compute_constructible(target: JSValue) -> bool {
    if js_is_proxy(target) {
        # Same as callable: [[Construct]] presence is a creation-time snapshot.
        return _px(jsv_to_table_id(target)).constructible;
    }
    if is_native_val(target) {
        return native_kind_is_constructible(get_native_kind(target));
    }
    if jsv_is_object_cell(target) and jsv_to_table_id(target) > 0 {
        if js_object_has_own(target, WK_IS_CLASS) {
            return True;
        }
        if js_object_has_own(target, KEY_CTOR_KIND) {
            ck: JSValue = js_object_get(target, KEY_CTOR_KIND);
            if jsv_is_int32(ck) {
                return native_kind_is_constructible(jsv_to_int32(ck));
            }
        }
    }
    # JS closures live in the native-cell low range; treat as constructible unless
    # the VM later clears the bit (ProxyCreate from VM path may refine).
    if jsv_is_cell(target) and jsv_cell_kind(target) == JS_CELL_KIND_NATIVE {
        if jsv_to_table_id(target) < 1000000 {
            return True;
        }
    }
    return False;
}

def:pub js_proxy_create(target: JSValue, handler: JSValue) -> JSValue {
    if not jsv_is_any_object(target) {
        vm_throw_native(
            make_type_error("Cannot create proxy with a non-object as target")
        );
        return js_undefined();
    }
    if not jsv_is_object_cell(handler) or jsv_to_table_id(handler) <= 0 {
        vm_throw_native(
            make_type_error("Cannot create proxy with a non-object as handler")
        );
        return js_undefined();
    }
    idx: int = js_object_alloc_slot(-1);
    raw: JSObject = _proxy_raw(idx);
    raw.class_id = CLASS_ID_PROXY;
    # Compute the callable/constructible snapshots BEFORE inserting the row —
    # for a proxy-of-a-proxy they read the target proxy's own row.
    px_call: bool = _proxy_compute_callable(target);
    px_ctor: bool = _proxy_compute_constructible(target);
    str_get_realm().proxy_slots[idx] = ProxyState(
        target=target,
        handler=handler,
        revoked=False,
        callable=px_call,
        constructible=px_ctor
    );
    return js_object_wrap_slot(idx);
}

def:pub js_proxy_is_callable(p: JSValue) -> bool {
    if not js_is_proxy(p) {
        return False;
    }
    return _px(jsv_to_table_id(p)).callable;
}

def:pub js_proxy_is_constructible(p: JSValue) -> bool {
    if not js_is_proxy(p) {
        return False;
    }
    return _px(jsv_to_table_id(p)).constructible;
}

"""Refine constructible bit after ProxyCreate when the VM knows IsConstructor."""
def:pub js_proxy_set_constructible(p: JSValue, constructible: bool) -> None {
    if not js_is_proxy(p) {
        return;
    }
    _px(jsv_to_table_id(p)).constructible = constructible;
}

def:pub js_Proxy_ctor(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        vm_throw_native(
            make_type_error("Proxy constructor requires at least 2 arguments")
        );
        return js_undefined();
    }
    return js_proxy_create(args[0], args[1]);
}

def:pub js_Proxy_revocable(args: list[JSValue]) -> JSValue {
    if len(args) < 2 {
        vm_throw_native(make_type_error("Proxy.revocable requires target and handler"));
        return js_undefined();
    }
    p: JSValue = js_proxy_create(args[0], args[1]);
    if vm_has_native_exc() {
        return js_undefined();
    }
    revoke_fn: JSValue = js_object_create_null();
    js_object_set(revoke_fn, KEY_CTOR_KIND, js_int(NATIVE_KIND_PROXY_REVOKE));
    js_object_set(revoke_fn, _K_PROXY_REF, p);
    js_object_define_property(
        revoke_fn,
        str_intern("length"),
        JSProperty(
            key=str_intern("length"),
            value=js_int(0),
            writable=False,
            enumerable=False,
            configurable=True,
            deleted=False
        )
    );
    js_object_define_property(
        revoke_fn,
        str_intern("name"),
        JSProperty(
            key=str_intern("name"),
            value=jsv_from_string_id(str_intern("")),
            writable=False,
            enumerable=False,
            configurable=True,
            deleted=False
        )
    );
    result: JSValue = js_object_create_null();
    js_object_set(result, str_intern("proxy"), p);
    js_object_set(result, str_intern("revoke"), revoke_fn);
    return result;
}

def:pub js_proxy_revoke_callable(revoke_obj: JSValue) -> JSValue {
    pref: JSValue = js_object_get(revoke_obj, _K_PROXY_REF);
    if not js_is_proxy(pref) {
        pref = js_object_get(revoke_obj, str_intern("proxy"));
    }
    if js_is_proxy(pref) {
        js_proxy_mark_revoked(pref);
    }
    return js_undefined();
}
