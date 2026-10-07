/*
 * 09_promise — native promise creation, resolution, and rejection addon.
 * Exports: fulfilledWith(value), rejectedWith(message)
 */
#include <node_api.h>

static napi_value prom_fulfilledWith(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    napi_deferred deferred;
    napi_value promise;
    napi_create_promise(env, &deferred, &promise);
    napi_resolve_deferred(env, deferred, args[0]);
    return promise;
}

static napi_value prom_rejectedWith(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    napi_deferred deferred;
    napi_value promise;
    napi_create_promise(env, &deferred, &promise);
    napi_value err;
    napi_create_error(env, NULL, args[0], &err);
    napi_reject_deferred(env, deferred, err);
    return promise;
}

NAPI_MODULE_INIT() {
    napi_value fn;
    napi_create_function(env, "fulfilledWith", NAPI_AUTO_LENGTH, prom_fulfilledWith, NULL, &fn);
    napi_set_named_property(env, exports, "fulfilledWith", fn);
    napi_create_function(env, "rejectedWith", NAPI_AUTO_LENGTH, prom_rejectedWith, NULL, &fn);
    napi_set_named_property(env, exports, "rejectedWith", fn);
    return exports;
}
