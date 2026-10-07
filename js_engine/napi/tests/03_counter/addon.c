/*
 * 03_counter — stateful counter via napi_wrap.
 * Exports: create(initial?) → { inc(), dec(), reset(), getValue() }
 */
#include <node_api.h>
#include <stdlib.h>

typedef struct { int64_t value; } Counter;

static void counter_finalize(napi_env env, void *data, void *hint) {
    free((Counter *)data);
}

static napi_value counter_inc(napi_env env, napi_callback_info info) {
    napi_value self;
    size_t argc = 0;
    napi_get_cb_info(env, info, &argc, NULL, &self, NULL);
    Counter *c;
    napi_unwrap(env, self, (void **)&c);
    c->value++;
    napi_value out;
    napi_create_int64(env, c->value, &out);
    return out;
}

static napi_value counter_dec(napi_env env, napi_callback_info info) {
    napi_value self;
    size_t argc = 0;
    napi_get_cb_info(env, info, &argc, NULL, &self, NULL);
    Counter *c;
    napi_unwrap(env, self, (void **)&c);
    c->value--;
    napi_value out;
    napi_create_int64(env, c->value, &out);
    return out;
}

static napi_value counter_reset(napi_env env, napi_callback_info info) {
    napi_value self;
    size_t argc = 0;
    napi_get_cb_info(env, info, &argc, NULL, &self, NULL);
    Counter *c;
    napi_unwrap(env, self, (void **)&c);
    c->value = 0;
    napi_value undef;
    napi_get_undefined(env, &undef);
    return undef;
}

static napi_value counter_getValue(napi_env env, napi_callback_info info) {
    napi_value self;
    size_t argc = 0;
    napi_get_cb_info(env, info, &argc, NULL, &self, NULL);
    Counter *c;
    napi_unwrap(env, self, (void **)&c);
    napi_value out;
    napi_create_int64(env, c->value, &out);
    return out;
}

static napi_value counter_create(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    int32_t init = 0;
    if (argc > 0) napi_get_value_int32(env, args[0], &init);
    Counter *c = malloc(sizeof(Counter));
    c->value = init;
    napi_value obj;
    napi_create_object(env, &obj);
    napi_wrap(env, obj, c, counter_finalize, NULL, NULL);
    napi_value fn;
#define METHOD(name) \
    napi_create_function(env, #name, NAPI_AUTO_LENGTH, counter_##name, NULL, &fn); \
    napi_set_named_property(env, obj, #name, fn);
    METHOD(inc)
    METHOD(dec)
    METHOD(reset)
    METHOD(getValue)
#undef METHOD
    return obj;
}

NAPI_MODULE_INIT() {
    napi_value fn;
    napi_create_function(env, "create", NAPI_AUTO_LENGTH, counter_create, NULL, &fn);
    napi_set_named_property(env, exports, "create", fn);
    return exports;
}
