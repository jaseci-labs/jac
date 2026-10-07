/*
 * 05_stats — native descriptive statistics on JS arrays.
 * Exports: sum(arr), mean(arr), min(arr), max(arr)
 */
#include <node_api.h>

static napi_value stats_sum(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    uint32_t len;
    napi_get_array_length(env, args[0], &len);
    double s = 0;
    for (uint32_t i = 0; i < len; i++) {
        napi_value el;
        napi_get_element(env, args[0], i, &el);
        double v;
        napi_get_value_double(env, el, &v);
        s += v;
    }
    napi_value out;
    napi_create_double(env, s, &out);
    return out;
}

static napi_value stats_mean(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    uint32_t len;
    napi_get_array_length(env, args[0], &len);
    if (len == 0) {
        napi_throw_range_error(env, NULL, "empty array");
        return NULL;
    }
    double s = 0;
    for (uint32_t i = 0; i < len; i++) {
        napi_value el;
        napi_get_element(env, args[0], i, &el);
        double v;
        napi_get_value_double(env, el, &v);
        s += v;
    }
    napi_value out;
    napi_create_double(env, s / len, &out);
    return out;
}

static napi_value stats_min(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    uint32_t len;
    napi_get_array_length(env, args[0], &len);
    if (len == 0) {
        napi_throw_range_error(env, NULL, "empty array");
        return NULL;
    }
    napi_value el;
    napi_get_element(env, args[0], 0, &el);
    double m;
    napi_get_value_double(env, el, &m);
    for (uint32_t i = 1; i < len; i++) {
        napi_get_element(env, args[0], i, &el);
        double v;
        napi_get_value_double(env, el, &v);
        if (v < m) m = v;
    }
    napi_value out;
    napi_create_double(env, m, &out);
    return out;
}

static napi_value stats_max(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    uint32_t len;
    napi_get_array_length(env, args[0], &len);
    if (len == 0) {
        napi_throw_range_error(env, NULL, "empty array");
        return NULL;
    }
    napi_value el;
    napi_get_element(env, args[0], 0, &el);
    double m;
    napi_get_value_double(env, el, &m);
    for (uint32_t i = 1; i < len; i++) {
        napi_get_element(env, args[0], i, &el);
        double v;
        napi_get_value_double(env, el, &v);
        if (v > m) m = v;
    }
    napi_value out;
    napi_create_double(env, m, &out);
    return out;
}

NAPI_MODULE_INIT() {
    napi_value fn;
#define EXPORT(name) \
    napi_create_function(env, #name, NAPI_AUTO_LENGTH, stats_##name, NULL, &fn); \
    napi_set_named_property(env, exports, #name, fn);
    EXPORT(sum)
    EXPORT(mean)
    EXPORT(min)
    EXPORT(max)
#undef EXPORT
    return exports;
}
