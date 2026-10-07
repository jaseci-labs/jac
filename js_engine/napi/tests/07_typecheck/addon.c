/*
 * 07_typecheck — runtime type inspection and guarded coercion addon.
 * Exports: getType(v), assertNumber(v), assertString(v), isIntLike(v)
 */
#include <node_api.h>
#include <stdint.h>

static napi_value tc_getType(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    napi_valuetype t;
    napi_typeof(env, args[0], &t);
    const char *name;
    switch (t) {
        case napi_undefined: name = "undefined"; break;
        case napi_null:      name = "null";      break;
        case napi_boolean:   name = "boolean";   break;
        case napi_number:    name = "number";    break;
        case napi_string:    name = "string";    break;
        case napi_symbol:    name = "symbol";    break;
        case napi_object:    name = "object";    break;
        case napi_function:  name = "function";  break;
        case napi_bigint:    name = "bigint";    break;
        default:             name = "unknown";   break;
    }
    napi_value out;
    napi_create_string_utf8(env, name, NAPI_AUTO_LENGTH, &out);
    return out;
}

static napi_value tc_assertNumber(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    napi_valuetype t;
    napi_typeof(env, args[0], &t);
    if (t != napi_number) {
        napi_throw_type_error(env, NULL, "Expected a number");
        return NULL;
    }
    double v;
    napi_get_value_double(env, args[0], &v);
    napi_value out;
    napi_create_double(env, v, &out);
    return out;
}

static napi_value tc_assertString(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    napi_valuetype t;
    napi_typeof(env, args[0], &t);
    if (t != napi_string) {
        napi_throw_type_error(env, NULL, "Expected a string");
        return NULL;
    }
    return args[0];
}

static napi_value tc_isIntLike(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    napi_valuetype t;
    napi_typeof(env, args[0], &t);
    bool result = false;
    if (t == napi_number) {
        double v;
        napi_get_value_double(env, args[0], &v);
        result = (v == (double)(int64_t)v);
    }
    napi_value out;
    napi_get_boolean(env, result, &out);
    return out;
}

NAPI_MODULE_INIT() {
    napi_value fn;
#define EXPORT(name) \
    napi_create_function(env, #name, NAPI_AUTO_LENGTH, tc_##name, NULL, &fn); \
    napi_set_named_property(env, exports, #name, fn);
    EXPORT(getType)
    EXPORT(assertNumber)
    EXPORT(assertString)
    EXPORT(isIntLike)
#undef EXPORT
    return exports;
}
