/*
 * 06_hash — native string hashing addon.
 * Exports: fnv1a32(s), djb2(s)  → uint32 hash value
 */
#include <node_api.h>
#include <stdlib.h>
#include <stdint.h>

static napi_value hash_fnv1a32(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    size_t len;
    napi_get_value_string_utf8(env, args[0], NULL, 0, &len);
    char *buf = malloc(len + 1);
    napi_get_value_string_utf8(env, args[0], buf, len + 1, &len);
    uint32_t h = 2166136261u;
    for (size_t i = 0; i < len; i++) {
        h ^= (unsigned char)buf[i];
        h *= 16777619u;
    }
    free(buf);
    napi_value out;
    napi_create_uint32(env, h, &out);
    return out;
}

static napi_value hash_djb2(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    size_t len;
    napi_get_value_string_utf8(env, args[0], NULL, 0, &len);
    char *buf = malloc(len + 1);
    napi_get_value_string_utf8(env, args[0], buf, len + 1, &len);
    uint32_t h = 5381u;
    for (size_t i = 0; i < len; i++)
        h = ((h << 5) + h) + (unsigned char)buf[i];
    free(buf);
    napi_value out;
    napi_create_uint32(env, h, &out);
    return out;
}

NAPI_MODULE_INIT() {
    napi_value fn;
#define EXPORT(name) \
    napi_create_function(env, #name, NAPI_AUTO_LENGTH, hash_##name, NULL, &fn); \
    napi_set_named_property(env, exports, #name, fn);
    EXPORT(fnv1a32)
    EXPORT(djb2)
#undef EXPORT
    return exports;
}
