/*
 * 08_matrix — 2×2 matrix operations addon.
 * Matrices are flat 4-element JS arrays: [a00, a01, a10, a11].
 * Exports: mul(a, b), det(m), transpose(m)
 */
#include <node_api.h>

static void read_mat2(napi_env env, napi_value arr, double m[4]) {
    for (int i = 0; i < 4; i++) {
        napi_value el;
        napi_get_element(env, arr, (uint32_t)i, &el);
        napi_get_value_double(env, el, &m[i]);
    }
}

static napi_value make_mat2(napi_env env, double m[4]) {
    napi_value arr;
    napi_create_array_with_length(env, 4, &arr);
    for (int i = 0; i < 4; i++) {
        napi_value el;
        napi_create_double(env, m[i], &el);
        napi_set_element(env, arr, (uint32_t)i, el);
    }
    return arr;
}

static napi_value mat2_mul(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    double a[4], b[4];
    read_mat2(env, args[0], a);
    read_mat2(env, args[1], b);
    double c[4];
    c[0] = a[0]*b[0] + a[1]*b[2];
    c[1] = a[0]*b[1] + a[1]*b[3];
    c[2] = a[2]*b[0] + a[3]*b[2];
    c[3] = a[2]*b[1] + a[3]*b[3];
    return make_mat2(env, c);
}

static napi_value mat2_det(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    double m[4];
    read_mat2(env, args[0], m);
    napi_value out;
    napi_create_double(env, m[0]*m[3] - m[1]*m[2], &out);
    return out;
}

static napi_value mat2_transpose(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    double m[4];
    read_mat2(env, args[0], m);
    double t[4] = { m[0], m[2], m[1], m[3] };
    return make_mat2(env, t);
}

NAPI_MODULE_INIT() {
    napi_value fn;
#define EXPORT(cname, jsname) \
    napi_create_function(env, jsname, NAPI_AUTO_LENGTH, mat2_##cname, NULL, &fn); \
    napi_set_named_property(env, exports, jsname, fn);
    EXPORT(mul, "mul")
    EXPORT(det, "det")
    EXPORT(transpose, "transpose")
#undef EXPORT
    return exports;
}
