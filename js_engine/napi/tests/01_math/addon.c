/*
 * 01_math — native integer and float arithmetic addon.
 * Exports: factorial(n), gcd(a, b), clamp(x, lo, hi)
 */
#include <node_api.h>

static napi_value math_factorial(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    int32_t n;
    napi_get_value_int32(env, args[0], &n);
    if (n < 0 || n > 20) {
        napi_throw_range_error(env, NULL, "n must be 0..20");
        return NULL;
    }
    long long r = 1;
    for (int i = 2; i <= n; i++) r *= i;
    napi_value out;
    napi_create_int64(env, r, &out);
    return out;
}

static napi_value math_gcd(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    int32_t a, b;
    napi_get_value_int32(env, args[0], &a);
    napi_get_value_int32(env, args[1], &b);
    if (a < 0) a = -a;
    if (b < 0) b = -b;
    while (b) { int t = b; b = a % b; a = t; }
    napi_value out;
    napi_create_int32(env, a, &out);
    return out;
}

static napi_value math_clamp(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    double x, lo, hi;
    napi_get_value_double(env, args[0], &x);
    napi_get_value_double(env, args[1], &lo);
    napi_get_value_double(env, args[2], &hi);
    double r = x < lo ? lo : (x > hi ? hi : x);
    napi_value out;
    napi_create_double(env, r, &out);
    return out;
}

NAPI_MODULE_INIT() {
    napi_value fn;
#define EXPORT(name) \
    napi_create_function(env, #name, NAPI_AUTO_LENGTH, math_##name, NULL, &fn); \
    napi_set_named_property(env, exports, #name, fn);
    EXPORT(factorial)
    EXPORT(gcd)
    EXPORT(clamp)
#undef EXPORT
    return exports;
}
