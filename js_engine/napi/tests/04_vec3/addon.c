/*
 * 04_vec3 — 3-D vector math addon.
 * Exports: create(x,y,z), add(v1,v2), dot(v1,v2), magnitude(v), scale(v,s)
 * Vectors are plain JS objects { x, y, z }.
 */
#include <node_api.h>
#include <math.h>

static void get_vec3(napi_env env, napi_value v, double *x, double *y, double *z) {
    napi_value p;
    napi_get_named_property(env, v, "x", &p); napi_get_value_double(env, p, x);
    napi_get_named_property(env, v, "y", &p); napi_get_value_double(env, p, y);
    napi_get_named_property(env, v, "z", &p); napi_get_value_double(env, p, z);
}

static napi_value make_vec3(napi_env env, double x, double y, double z) {
    napi_value obj;
    napi_create_object(env, &obj);
    napi_value vx, vy, vz;
    napi_create_double(env, x, &vx); napi_set_named_property(env, obj, "x", vx);
    napi_create_double(env, y, &vy); napi_set_named_property(env, obj, "y", vy);
    napi_create_double(env, z, &vz); napi_set_named_property(env, obj, "z", vz);
    return obj;
}

static napi_value vec3_create(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    double x = 0, y = 0, z = 0;
    if (argc >= 1) napi_get_value_double(env, args[0], &x);
    if (argc >= 2) napi_get_value_double(env, args[1], &y);
    if (argc >= 3) napi_get_value_double(env, args[2], &z);
    return make_vec3(env, x, y, z);
}

static napi_value vec3_add(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    double ax, ay, az, bx, by, bz;
    get_vec3(env, args[0], &ax, &ay, &az);
    get_vec3(env, args[1], &bx, &by, &bz);
    return make_vec3(env, ax + bx, ay + by, az + bz);
}

static napi_value vec3_dot(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    double ax, ay, az, bx, by, bz;
    get_vec3(env, args[0], &ax, &ay, &az);
    get_vec3(env, args[1], &bx, &by, &bz);
    napi_value out;
    napi_create_double(env, ax * bx + ay * by + az * bz, &out);
    return out;
}

static napi_value vec3_magnitude(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    double x, y, z;
    get_vec3(env, args[0], &x, &y, &z);
    napi_value out;
    napi_create_double(env, sqrt(x * x + y * y + z * z), &out);
    return out;
}

static napi_value vec3_scale(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    double x, y, z, s;
    get_vec3(env, args[0], &x, &y, &z);
    napi_get_value_double(env, args[1], &s);
    return make_vec3(env, x * s, y * s, z * s);
}

NAPI_MODULE_INIT() {
    napi_value fn;
#define EXPORT(name) \
    napi_create_function(env, #name, NAPI_AUTO_LENGTH, vec3_##name, NULL, &fn); \
    napi_set_named_property(env, exports, #name, fn);
    EXPORT(create)
    EXPORT(add)
    EXPORT(dot)
    EXPORT(magnitude)
    EXPORT(scale)
#undef EXPORT
    return exports;
}
