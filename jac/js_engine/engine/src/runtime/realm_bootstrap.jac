"""
realm_bootstrap.na.jac — Secondary realm creation for test262 $262.createRealm (R13).

Kept separate from global.na.jac to avoid vm.na.jac ↔ global.na.jac circular imports.
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_true,
    js_int,
    jsv_from_string_id,
    jsv_is_symbol
}
import from engine.src.runtime.jsobject {
    JSProperty,
    js_object_create_null,
    js_object_create,
    js_object_new_ordinary,
    js_object_set,
    js_object_get,
    js_object_has_own,
    js_object_all_keys,
    js_object_set_ordinary_proto,
    js_object_define_property,
    js_object_set_accessor_getter,
    js_object_set_prototype,
    js_object_set_accessor_enumerable,
    js_object_set_accessor_configurable
}
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.encoding { SYMBOL_KEY_BASE }
import from engine.src.runtime.jssymbol { symbol_seed_well_known, SYMBOL_SPECIES }
import from engine.src.runtime.realm { Realm, realm_new, realm_register }
import from engine.src.builtins.markers { KEY_HOME_REALM_ID, _KEY_IS_ARRAY }
import from engine.src.builtins.native_registry { js_native_create, js_callable_create }
import from engine.src.builtins.native_kinds {
    NATIVE_KIND_OBJECT,
    NATIVE_KIND_FUNCTION,
    NATIVE_KIND_ARRAY,
    NATIVE_KIND_ARRAY_SPECIES_GET,
    NATIVE_KIND_STRING,
    NATIVE_KIND_NUMBER,
    NATIVE_KIND_BOOLEAN,
    NATIVE_KIND_SYMBOL,
    NATIVE_KIND_SYMBOL_FOR,
    NATIVE_KIND_SYMBOL_KEYFOR,
    NATIVE_KIND_REGEXP,
    NATIVE_KIND_DATE,
    NATIVE_KIND_ERROR,
    NATIVE_KIND_TYPE_ERROR,
    NATIVE_KIND_REFERENCE_ERROR,
    NATIVE_KIND_SYNTAX_ERROR,
    NATIVE_KIND_RANGE_ERROR,
    NATIVE_KIND_URI_ERROR,
    NATIVE_KIND_EVAL_ERROR,
    NATIVE_KIND_PROXY,
    NATIVE_KIND_PROXY_REVOCABLE,
    NATIVE_KIND_EVAL,
    NATIVE_KIND_MAP,
    NATIVE_KIND_SET,
    NATIVE_KIND_WEAKMAP,
    NATIVE_KIND_WEAKSET,
    NATIVE_KIND_PROMISE,
    NATIVE_KIND_BIGINT
}
import from engine.src.runtime.intrinsic_manifest { INTRINSIC_IDENTITY_SENSITIVE }
import from engine.src.runtime.proxy { js_proxy_create }

def _rb_define_prop(jobj: JSValue, key: int, val: JSValue, w: bool, e: bool, c: bool) {
    p: JSProperty = JSProperty(
        key=key, value=val, writable=w, enumerable=e, configurable=c, deleted=False
    );
    js_object_define_property(jobj, key, p);
}

def _rb_define_proto_method(jobj: JSValue, key: int, val: JSValue) {
    _rb_define_prop(jobj, key, val, True, False, True);
}

def _rb_tag_home(o: JSValue, realm_id: int) {
    js_object_set(o, KEY_HOME_REALM_ID, js_int(realm_id));
}

def _rb_wire_error_ctor(
    ctor: JSValue,
    proto: JSValue,
    fn_proto: JSValue,
    k_prototype: int,
    k_constructor: int,
    name_key: int
) {
    js_object_set_prototype(ctor, fn_proto);
    _rb_define_prop(ctor, k_prototype, proto, False, False, False);
    _rb_define_prop(proto, k_constructor, ctor, True, False, True);
    _rb_define_prop(
        ctor, str_intern("name"), jsv_from_string_id(name_key), False, False, True
    );
}

def _rb_copy_global_if_present(gv: JSValue, main_gv: JSValue, name: str) {
    k: int = str_intern(name);
    if js_object_has_own(main_gv, k) {
        js_object_set(gv, k, js_object_get(main_gv, k));
    }
}

"""Install a realm-local identity for a main-realm intrinsic.
Callable/constructible values become a fresh Proxy(target, {}) so
`sec.ArrayBuffer !== main.ArrayBuffer` while construct/call forward.
Plain namespace objects (Atomics, Reflect) get a fresh ordinary object with
own properties shallow-copied."""
def _rb_install_fresh_identity(
    gv: JSValue, main_gv: JSValue, name: str, obj_proto: JSValue, realm_id: int
) -> None {
    k: int = str_intern(name);
    if not js_object_has_own(main_gv, k) {
        return;
    }
    main_val: JSValue = js_object_get(main_gv, k);
    # Namespace objects: fresh ordinary + shallow own copy.
    if name == "Atomics" or name == "Reflect" or name == "JSON" {
        fresh: JSValue = js_object_create(obj_proto);
        for ok in js_object_all_keys(main_val) {
            if ok < 0 {
                continue;
            }
            js_object_set(fresh, ok, js_object_get(main_val, ok));
        }
        _rb_tag_home(fresh, realm_id);
        js_object_set(gv, k, fresh);
        return;
    }
    # Constructors / callables: Proxy wrapper → distinct identity, shared behavior.
    handler: JSValue = js_object_create_null();
    alias: JSValue = js_proxy_create(main_val, handler);
    _rb_tag_home(alias, realm_id);
    js_object_set(gv, k, alias);
}

"""
Bootstrap a secondary realm with core intrinsics for cross-realm test262 tests.

Intrinsics are allocated in the active (main) object table so JSValue table
indices remain unambiguous; KEY_HOME_REALM_ID tags them for GetFunctionRealm.
Returns `{ global: <secondary global object> }`.
"""
def:pub realm_bootstrap_secondary(main_realm: Realm) -> JSValue {
    sec: Realm = realm_new();
    realm_register(sec);
    symbol_seed_well_known(sec);

    k_object_k: int = str_intern("Object");
    k_func_k: int = str_intern("Function");
    k_array_k: int = str_intern("Array");
    k_proto_k: int = str_intern("prototype");
    k_ctor_k: int = str_intern("constructor");

    obj_proto: JSValue = js_object_new_ordinary();
    obj_ctor: JSValue = js_callable_create("Object", 1, NATIVE_KIND_OBJECT);
    _rb_define_prop(obj_ctor, k_proto_k, obj_proto, True, False, True);
    js_object_set_ordinary_proto(obj_proto);

    # Guest globalThis is an ordinary object with %Object.prototype%.
    gv: JSValue = js_object_create(obj_proto);
    sec.global_this = gv;

    fn_proto: JSValue = js_object_create(obj_proto);
    fn_ctor: JSValue = js_callable_create("Function", 1, NATIVE_KIND_FUNCTION);
    _rb_define_proto_method(fn_proto, k_ctor_k, fn_ctor);
    _rb_define_prop(fn_ctor, k_proto_k, fn_proto, True, False, True);

    arr_proto: JSValue = js_object_create(obj_proto);
    _rb_define_prop(arr_proto, _KEY_IS_ARRAY, js_true(), False, False, False);
    arr_ctor: JSValue = js_callable_create("Array", 1, NATIVE_KIND_ARRAY);
    sp_key: int = SYMBOL_KEY_BASE + SYMBOL_SPECIES;
    sp_getter: JSValue = js_native_create(
        "get [Symbol.species]", 0, NATIVE_KIND_ARRAY_SPECIES_GET
    );
    js_object_set_accessor_getter(arr_ctor, sp_key, sp_getter);
    js_object_set_accessor_enumerable(arr_ctor, sp_key, False);
    js_object_set_accessor_configurable(arr_ctor, sp_key, True);
    _rb_define_proto_method(arr_proto, k_ctor_k, arr_ctor);
    _rb_define_prop(arr_ctor, k_proto_k, arr_proto, False, False, False);
    _rb_define_prop(arr_proto, str_intern("length"), js_int(0), True, False, False);

    sec.intrinsics.object_ctor = obj_ctor;
    sec.intrinsics.object_proto = obj_proto;
    sec.intrinsics.function_ctor = fn_ctor;
    sec.intrinsics.function_proto = fn_proto;
    sec.intrinsics.array_ctor = arr_ctor;
    sec.intrinsics.array_proto = arr_proto;
    rid_sec: int = sec.realm_id;
    _rb_tag_home(obj_ctor, rid_sec);
    _rb_tag_home(obj_proto, rid_sec);
    _rb_tag_home(fn_ctor, rid_sec);
    _rb_tag_home(fn_proto, rid_sec);
    _rb_tag_home(arr_ctor, rid_sec);
    _rb_tag_home(arr_proto, rid_sec);

    js_object_set(gv, k_object_k, obj_ctor);
    js_object_set(gv, k_func_k, fn_ctor);
    js_object_set(gv, k_array_k, arr_ctor);

    # String / Number / Boolean — identity-sensitive cross-realm tests need
    # distinct secondary-realm intrinsics (not main-realm object references).
    k_str_k: int = str_intern("String");
    k_num_k: int = str_intern("Number");
    k_bool_k: int = str_intern("Boolean");
    str_proto: JSValue = js_object_create(obj_proto);
    str_ctor: JSValue = js_callable_create("String", 1, NATIVE_KIND_STRING);
    _rb_define_proto_method(str_proto, k_ctor_k, str_ctor);
    _rb_define_prop(str_ctor, k_proto_k, str_proto, True, False, True);
    num_proto: JSValue = js_object_create(obj_proto);
    num_ctor: JSValue = js_callable_create("Number", 1, NATIVE_KIND_NUMBER);
    _rb_define_proto_method(num_proto, k_ctor_k, num_ctor);
    _rb_define_prop(num_ctor, k_proto_k, num_proto, True, False, True);
    bool_proto: JSValue = js_object_create(obj_proto);
    bool_ctor: JSValue = js_callable_create("Boolean", 1, NATIVE_KIND_BOOLEAN);
    _rb_define_proto_method(bool_proto, k_ctor_k, bool_ctor);
    _rb_define_prop(bool_ctor, k_proto_k, bool_proto, True, False, True);
    _rb_tag_home(str_ctor, rid_sec);
    _rb_tag_home(str_proto, rid_sec);
    _rb_tag_home(num_ctor, rid_sec);
    _rb_tag_home(num_proto, rid_sec);
    _rb_tag_home(bool_ctor, rid_sec);
    _rb_tag_home(bool_proto, rid_sec);
    js_object_set(gv, k_str_k, str_ctor);
    js_object_set(gv, k_num_k, num_ctor);
    js_object_set(gv, k_bool_k, bool_ctor);

    k_sym_k: int = str_intern("Symbol");
    sym_proto: JSValue = js_object_create(obj_proto);
    sym_ctor: JSValue = js_callable_create("Symbol", 0, NATIVE_KIND_SYMBOL);
    _rb_define_proto_method(sym_proto, k_ctor_k, sym_ctor);
    _rb_define_prop(sym_ctor, k_proto_k, sym_proto, True, False, True);
    # Install the static members of Symbol on the realm-local ctor. `Symbol.for` /
    # `Symbol.keyFor` are FRESH realm-local functions (distinct identity per realm —
    # `sec.Symbol.for !== main.Symbol.for` — while the GlobalSymbolRegistry they
    # operate on is realm-independent, §20.4.2). The well-known symbol constants
    # (Symbol.iterator, Symbol.asyncIterator, …) are shared VALUES, copied by
    # reference so SameValue holds across realms (built-ins/Symbol/for|keyFor/
    # cross-realm, well-known-symbol cross-realm identity).
    sym_k_for: int = str_intern("for");
    sym_k_keyfor: int = str_intern("keyFor");
    _rb_define_prop(
        sym_ctor,
        sym_k_for,
        js_native_create("for", 1, NATIVE_KIND_SYMBOL_FOR),
        True,
        False,
        True
    );
    _rb_define_prop(
        sym_ctor,
        sym_k_keyfor,
        js_native_create("keyFor", 1, NATIVE_KIND_SYMBOL_KEYFOR),
        True,
        False,
        True
    );
    if js_object_has_own(main_realm.global_this, k_sym_k) {
        main_sym: JSValue = js_object_get(main_realm.global_this, k_sym_k);
        if jsv_is_object_cell(main_sym) {
            sym_skip_name: int = str_intern("name");
            sym_skip_len: int = str_intern("length");
            for sym_ok in js_object_all_keys(main_sym) {
                if sym_ok < 0 {
                    continue;
                }
                if sym_ok == k_proto_k
                    or sym_ok == sym_skip_name
                    or sym_ok == sym_skip_len {
                    continue;
                }
                if sym_ok == sym_k_for or sym_ok == sym_k_keyfor {
                    continue;
                }
                # Only copy symbol-valued statics (well-known symbols) by reference;
                # skip any other callable to avoid sharing function identity.
                sym_sv: JSValue = js_object_get(main_sym, sym_ok);
                if jsv_is_symbol(sym_sv) {
                    js_object_set(sym_ctor, sym_ok, sym_sv);
                }
            }
        }
    }
    k_regexp_k: int = str_intern("RegExp");
    regexp_proto: JSValue = js_object_create(obj_proto);
    regexp_ctor: JSValue = js_callable_create("RegExp", 2, NATIVE_KIND_REGEXP);
    _rb_define_proto_method(regexp_proto, k_ctor_k, regexp_ctor);
    _rb_define_prop(regexp_ctor, k_proto_k, regexp_proto, True, False, True);
    k_date_k: int = str_intern("Date");
    date_proto: JSValue = js_object_create(obj_proto);
    date_ctor: JSValue = js_callable_create("Date", 7, NATIVE_KIND_DATE);
    _rb_define_proto_method(date_proto, k_ctor_k, date_ctor);
    _rb_define_prop(date_ctor, k_proto_k, date_proto, True, False, True);

    k_error_k: int = str_intern("Error");
    k_typerr_k: int = str_intern("TypeError");
    k_referr_k: int = str_intern("ReferenceError");
    k_synterr_k: int = str_intern("SyntaxError");
    k_rangerr_k: int = str_intern("RangeError");
    k_urierr_k: int = str_intern("URIError");
    k_evalerr_k: int = str_intern("EvalError");
    k_proxy_k: int = str_intern("Proxy");
    k_eval_k: int = str_intern("eval");
    k_name_k: int = str_intern("name");
    k_message_k: int = str_intern("message");

    err_proto: JSValue = js_object_create(obj_proto);
    js_object_set(err_proto, k_name_k, jsv_from_string_id(k_error_k));
    js_object_set(err_proto, k_message_k, jsv_from_string_id(str_intern("")));
    err_ctor: JSValue = js_callable_create("Error", 1, NATIVE_KIND_ERROR);
    _rb_wire_error_ctor(err_ctor, err_proto, fn_proto, k_proto_k, k_ctor_k, k_error_k);

    typerr_proto: JSValue = js_object_create(err_proto);
    js_object_set(typerr_proto, k_name_k, jsv_from_string_id(k_typerr_k));
    typerr_ctor: JSValue = js_callable_create("TypeError", 1, NATIVE_KIND_TYPE_ERROR);
    _rb_wire_error_ctor(
        typerr_ctor, typerr_proto, fn_proto, k_proto_k, k_ctor_k, k_typerr_k
    );

    referr_proto: JSValue = js_object_create(err_proto);
    js_object_set(referr_proto, k_name_k, jsv_from_string_id(k_referr_k));
    referr_ctor: JSValue = js_callable_create(
        "ReferenceError", 1, NATIVE_KIND_REFERENCE_ERROR
    );
    _rb_wire_error_ctor(
        referr_ctor, referr_proto, fn_proto, k_proto_k, k_ctor_k, k_referr_k
    );

    synterr_proto: JSValue = js_object_create(err_proto);
    js_object_set(synterr_proto, k_name_k, jsv_from_string_id(k_synterr_k));
    synterr_ctor: JSValue = js_callable_create(
        "SyntaxError", 1, NATIVE_KIND_SYNTAX_ERROR
    );
    _rb_wire_error_ctor(
        synterr_ctor, synterr_proto, fn_proto, k_proto_k, k_ctor_k, k_synterr_k
    );

    rangerr_proto: JSValue = js_object_create(err_proto);
    js_object_set(rangerr_proto, k_name_k, jsv_from_string_id(k_rangerr_k));
    rangerr_ctor: JSValue = js_callable_create(
        "RangeError", 1, NATIVE_KIND_RANGE_ERROR
    );
    _rb_wire_error_ctor(
        rangerr_ctor, rangerr_proto, fn_proto, k_proto_k, k_ctor_k, k_rangerr_k
    );

    urierr_proto: JSValue = js_object_create(err_proto);
    js_object_set(urierr_proto, k_name_k, jsv_from_string_id(k_urierr_k));
    urierr_ctor: JSValue = js_callable_create("URIError", 1, NATIVE_KIND_URI_ERROR);
    _rb_wire_error_ctor(
        urierr_ctor, urierr_proto, fn_proto, k_proto_k, k_ctor_k, k_urierr_k
    );

    evalerr_proto: JSValue = js_object_create(err_proto);
    js_object_set(evalerr_proto, k_name_k, jsv_from_string_id(k_evalerr_k));
    evalerr_ctor: JSValue = js_callable_create("EvalError", 1, NATIVE_KIND_EVAL_ERROR);
    _rb_wire_error_ctor(
        evalerr_ctor, evalerr_proto, fn_proto, k_proto_k, k_ctor_k, k_evalerr_k
    );

    proxy_ctor: JSValue = js_callable_create("Proxy", 2, NATIVE_KIND_PROXY);
    _rb_define_prop(
        proxy_ctor,
        str_intern("revocable"),
        js_native_create("revocable", 2, NATIVE_KIND_PROXY_REVOCABLE),
        True,
        False,
        True
    );
    # eval is object-backed (js_callable_create) so it can carry KEY_HOME_REALM_ID: an
    # indirect `realm.global.eval(src)` runs in THIS realm and code it creates (e.g. a class
    # with private members) belongs to this realm, so a brand-check TypeError uses this
    # realm's %TypeError% (cross-realm brand-check tests).
    eval_fn: JSValue = js_callable_create("eval", 1, NATIVE_KIND_EVAL);

    # Wire [[Prototype]] → this realm's Function.prototype (Error* already via
    # _rb_wire_error_ctor). JSON/Reflect are shared from the main realm.
    js_object_set_prototype(obj_ctor, fn_proto);
    js_object_set_prototype(fn_ctor, fn_proto);
    js_object_set_prototype(arr_ctor, fn_proto);
    js_object_set_prototype(str_ctor, fn_proto);
    js_object_set_prototype(num_ctor, fn_proto);
    js_object_set_prototype(bool_ctor, fn_proto);
    js_object_set_prototype(sym_ctor, fn_proto);
    js_object_set_prototype(regexp_ctor, fn_proto);
    js_object_set_prototype(date_ctor, fn_proto);
    js_object_set_prototype(proxy_ctor, fn_proto);

    _rb_tag_home(sym_ctor, rid_sec);
    _rb_tag_home(sym_proto, rid_sec);
    _rb_tag_home(regexp_ctor, rid_sec);
    _rb_tag_home(regexp_proto, rid_sec);
    _rb_tag_home(date_ctor, rid_sec);
    _rb_tag_home(date_proto, rid_sec);
    _rb_tag_home(err_ctor, rid_sec);
    _rb_tag_home(err_proto, rid_sec);
    _rb_tag_home(typerr_ctor, rid_sec);
    _rb_tag_home(typerr_proto, rid_sec);
    _rb_tag_home(referr_ctor, rid_sec);
    _rb_tag_home(referr_proto, rid_sec);
    _rb_tag_home(synterr_ctor, rid_sec);
    _rb_tag_home(synterr_proto, rid_sec);
    _rb_tag_home(rangerr_ctor, rid_sec);
    _rb_tag_home(rangerr_proto, rid_sec);
    _rb_tag_home(urierr_ctor, rid_sec);
    _rb_tag_home(urierr_proto, rid_sec);
    _rb_tag_home(evalerr_ctor, rid_sec);
    _rb_tag_home(evalerr_proto, rid_sec);
    _rb_tag_home(proxy_ctor, rid_sec);
    _rb_tag_home(eval_fn, rid_sec);
    js_object_set(gv, k_sym_k, sym_ctor);
    js_object_set(gv, k_regexp_k, regexp_ctor);
    js_object_set(gv, k_date_k, date_ctor);
    js_object_set(gv, k_error_k, err_ctor);
    js_object_set(gv, k_typerr_k, typerr_ctor);
    js_object_set(gv, k_referr_k, referr_ctor);
    js_object_set(gv, k_synterr_k, synterr_ctor);
    js_object_set(gv, k_rangerr_k, rangerr_ctor);
    js_object_set(gv, k_urierr_k, urierr_ctor);
    js_object_set(gv, k_evalerr_k, evalerr_ctor);
    js_object_set(gv, k_proxy_k, proxy_ctor);
    js_object_set(gv, k_eval_k, eval_fn);

    # Shared / JS-defined globals from the main realm. Identity-sensitive
    # binary/reflection intrinsics get fresh realm-local identities (manifest).
    # Merge note: HEAD shared these by object identity (spec-incorrect for
    # ShadowRealm — each realm must have distinct intrinsics); adel_fixes' manifest
    # + fresh-identity install is kept.
    main_gv: JSValue = main_realm.global_this;
    for id_name in INTRINSIC_IDENTITY_SENSITIVE {
        _rb_install_fresh_identity(gv, main_gv, id_name, obj_proto, rid_sec);
    }
    # JSON remains shared (not identity-sensitive in the manifest).
    _rb_copy_global_if_present(gv, main_gv, "JSON");
    _rb_copy_global_if_present(gv, main_gv, "AggregateError");
    _rb_copy_global_if_present(gv, main_gv, "GeneratorFunction");
    _rb_copy_global_if_present(gv, main_gv, "AsyncGeneratorFunction");
    _rb_copy_global_if_present(gv, main_gv, "AsyncFunction");
    # ArrayBuffer / SharedArrayBuffer / DataView / all TypedArrays / Atomics are
    # installed with fresh realm-local identity above via the manifest loop —
    # HEAD's shared-copy of them here is dropped (it would overwrite the fresh
    # identities with shared ones and break cross-realm identity tests).
    _rb_copy_global_if_present(gv, main_gv, "Iterator");
    _rb_copy_global_if_present(gv, main_gv, "WeakRef");
    _rb_copy_global_if_present(gv, main_gv, "FinalizationRegistry");
    _rb_copy_global_if_present(gv, main_gv, "DisposableStack");
    _rb_copy_global_if_present(gv, main_gv, "AsyncDisposableStack");
    # ShadowRealm is in the identity-sensitive manifest and installed fresh above.

    # Map / Set / WeakMap / WeakSet / Promise / BigInt — realm-distinct ctors
    # (identity-sensitive cross-realm tests). Proto method tables stay on the
    # main-realm singleton; instances still function via native dispatch.
    k_map_k: int = str_intern("Map");
    map_proto: JSValue = js_object_create(obj_proto);
    map_ctor: JSValue = js_callable_create("Map", 0, NATIVE_KIND_MAP);
    _rb_define_proto_method(map_proto, k_ctor_k, map_ctor);
    _rb_define_prop(map_ctor, k_proto_k, map_proto, False, False, False);

    k_set_k: int = str_intern("Set");
    set_proto: JSValue = js_object_create(obj_proto);
    set_ctor: JSValue = js_callable_create("Set", 0, NATIVE_KIND_SET);
    _rb_define_proto_method(set_proto, k_ctor_k, set_ctor);
    _rb_define_prop(set_ctor, k_proto_k, set_proto, False, False, False);

    k_weakmap_k: int = str_intern("WeakMap");
    weakmap_proto: JSValue = js_object_create(obj_proto);
    weakmap_ctor: JSValue = js_callable_create("WeakMap", 0, NATIVE_KIND_WEAKMAP);
    _rb_define_proto_method(weakmap_proto, k_ctor_k, weakmap_ctor);
    _rb_define_prop(weakmap_ctor, k_proto_k, weakmap_proto, False, False, False);

    k_weakset_k: int = str_intern("WeakSet");
    weakset_proto: JSValue = js_object_create(obj_proto);
    weakset_ctor: JSValue = js_callable_create("WeakSet", 0, NATIVE_KIND_WEAKSET);
    _rb_define_proto_method(weakset_proto, k_ctor_k, weakset_ctor);
    _rb_define_prop(weakset_ctor, k_proto_k, weakset_proto, False, False, False);

    k_promise_k: int = str_intern("Promise");
    promise_proto: JSValue = js_object_create(obj_proto);
    promise_ctor: JSValue = js_callable_create("Promise", 1, NATIVE_KIND_PROMISE);
    _rb_define_proto_method(promise_proto, k_ctor_k, promise_ctor);
    _rb_define_prop(promise_ctor, k_proto_k, promise_proto, True, False, True);

    k_bigint_k: int = str_intern("BigInt");
    bigint_ctor: JSValue = js_callable_create("BigInt", 1, NATIVE_KIND_BIGINT);

    js_object_set_prototype(map_ctor, fn_proto);
    js_object_set_prototype(set_ctor, fn_proto);
    js_object_set_prototype(weakmap_ctor, fn_proto);
    js_object_set_prototype(weakset_ctor, fn_proto);
    js_object_set_prototype(promise_ctor, fn_proto);
    js_object_set_prototype(bigint_ctor, fn_proto);

    _rb_tag_home(map_ctor, rid_sec);
    _rb_tag_home(map_proto, rid_sec);
    _rb_tag_home(set_ctor, rid_sec);
    _rb_tag_home(set_proto, rid_sec);
    _rb_tag_home(weakmap_ctor, rid_sec);
    _rb_tag_home(weakmap_proto, rid_sec);
    _rb_tag_home(weakset_ctor, rid_sec);
    _rb_tag_home(weakset_proto, rid_sec);
    _rb_tag_home(promise_ctor, rid_sec);
    _rb_tag_home(promise_proto, rid_sec);
    _rb_tag_home(bigint_ctor, rid_sec);

    js_object_set(gv, k_map_k, map_ctor);
    js_object_set(gv, k_set_k, set_ctor);
    js_object_set(gv, k_weakmap_k, weakmap_ctor);
    js_object_set(gv, k_weakset_k, weakset_ctor);
    js_object_set(gv, k_promise_k, promise_ctor);
    js_object_set(gv, k_bigint_k, bigint_ctor);

    # Math — share main-realm Math (stateless natives; distinct copy is heavy).
    _rb_copy_global_if_present(gv, main_gv, "Math");

    # §19.1 Value Properties of the Global Object (NaN / Infinity / undefined) and
    # §19.2 Function Properties (parseInt / parseFloat / isNaN / isFinite, the URI
    # helpers). The value props are primitives and the functions are stateless
    # natives, so sharing the main-realm bindings is correct — without them a guest
    # `r.evaluate('NaN')` / `r.evaluate('parseInt(...)')` throws "X is not defined"
    # (ShadowRealm/prototype/evaluate/returns-primitive-values).
    _rb_copy_global_if_present(gv, main_gv, "NaN");
    _rb_copy_global_if_present(gv, main_gv, "Infinity");
    _rb_copy_global_if_present(gv, main_gv, "undefined");
    _rb_copy_global_if_present(gv, main_gv, "parseInt");
    _rb_copy_global_if_present(gv, main_gv, "parseFloat");
    _rb_copy_global_if_present(gv, main_gv, "isNaN");
    _rb_copy_global_if_present(gv, main_gv, "isFinite");
    _rb_copy_global_if_present(gv, main_gv, "encodeURI");
    _rb_copy_global_if_present(gv, main_gv, "decodeURI");
    _rb_copy_global_if_present(gv, main_gv, "encodeURIComponent");
    _rb_copy_global_if_present(gv, main_gv, "decodeURIComponent");

    # §9.3.4 SetDefaultGlobalBindings: `globalThis` is a self-reference to the guest
    # global object. Without it a ShadowRealm/createRealm guest cannot resolve
    # `globalThis` (ShadowRealm/prototype/evaluate/* — `r.evaluate('globalThis.x=…')`).
    js_object_set(gv, str_intern("globalThis"), gv);

    wrapper: JSValue = js_object_create_null();
    js_object_set(wrapper, str_intern("global"), gv);
    return wrapper;
}
