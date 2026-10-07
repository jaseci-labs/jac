/*
 * 20_gcref — repro for: a STRONG napi_create_reference must keep its target
 * alive across GC.  The addon holds ONLY a strong napi_ref to the value (no JS
 * reference).  If the engine's GC does not treat the napi reference table as a
 * root, the target is swept (and its object slot reused) — and fetch() then
 * returns a wrong/dead object instead of the original.
 *
 *   stash(value): napi_create_reference(value, refcount=1)  -> keep the ref only
 *   fetch():      napi_get_reference_value(ref)             -> should be `value`
 *   refcount():   napi_reference_ref/unref round-trip (sanity)
 */
#include <node_api.h>

static napi_ref g_ref = NULL;

static napi_value stash(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    if (g_ref != NULL) { napi_delete_reference(env, g_ref); g_ref = NULL; }
    /* STRONG reference: initial refcount 1 => target must stay alive. */
    napi_create_reference(env, args[0], 1, &g_ref);
    napi_value undef; napi_get_undefined(env, &undef); return undef;
}

static napi_value fetch(napi_env env, napi_callback_info info) {
    napi_value v = NULL;
    if (g_ref == NULL) { napi_value u; napi_get_undefined(env, &u); return u; }
    napi_status st = napi_get_reference_value(env, g_ref, &v);
    if (st != napi_ok || v == NULL) { napi_value u; napi_get_undefined(env, &u); return u; }
    return v;
}

NAPI_MODULE_INIT() {
    napi_value fn;
    napi_create_function(env, "stash", NAPI_AUTO_LENGTH, stash, NULL, &fn);
    napi_set_named_property(env, exports, "stash", fn);
    napi_create_function(env, "fetch", NAPI_AUTO_LENGTH, fetch, NULL, &fn);
    napi_set_named_property(env, exports, "fetch", fn);
    return exports;
}
