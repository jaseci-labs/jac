/*
 * 13_rollup_audit — R0.2 of docs/ROLLUP_SUPPORT_PLAN.md.
 * One-op probes for every symbol the rollup@4.63.1 addon imports that is
 * not already covered by suites 01-12, using napi-rs-shaped call patterns.
 * Buffer/TypedArray and async_work ops are deliberately absent (R1/R2).
 */
#include <node_api.h>
#include <stdio.h>
#include <stdlib.h>

#define NCHECK(call, what)                                          \
    do {                                                            \
        napi_status s__ = (call);                                   \
        if (s__ != napi_ok) {                                       \
            char m__[128];                                          \
            snprintf(m__, sizeof m__, "%s -> status %d", what, s__);\
            napi_throw_error(env, "E_AUDIT", m__);                  \
            return NULL;                                            \
        }                                                           \
    } while (0)

/* napi_get_prototype(obj) — returned verbatim */
static napi_value AuditGetPrototype(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    napi_value proto;
    NCHECK(napi_get_prototype(env, argv[0], &proto), "get_prototype");
    return proto;
}

/* napi_has_own_property(obj, key) — key passed through untouched */
static napi_value AuditHasOwn(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    bool has = false;
    NCHECK(napi_has_own_property(env, argv[0], argv[1], &has), "has_own_property");
    napi_value out;
    NCHECK(napi_get_boolean(env, has, &out), "get_boolean");
    return out;
}

/* napi_define_class + napi_wrap + napi_unwrap (rollup wraps ParseTask) */
typedef struct { double x; int finalized; } Point;
static int point_finalize_count = 0;

static void PointFinalize(napi_env env, void* data, void* hint) {
    (void)env; (void)hint;
    point_finalize_count++;
    free(data);
}

static napi_value PointCtor(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1], jsthis;
    NCHECK(napi_get_cb_info(env, info, &argc, argv, &jsthis, NULL), "get_cb_info");
    double x = 0;
    NCHECK(napi_get_value_double(env, argv[0], &x), "get_value_double");
    Point* p = (Point*)malloc(sizeof(Point));
    p->x = x; p->finalized = 0;
    NCHECK(napi_wrap(env, jsthis, p, PointFinalize, NULL, NULL), "wrap");
    return jsthis;
}

static napi_value PointGetX(napi_env env, napi_callback_info info) {
    napi_value jsthis;
    NCHECK(napi_get_cb_info(env, info, NULL, NULL, &jsthis, NULL), "get_cb_info");
    Point* p = NULL;
    NCHECK(napi_unwrap(env, jsthis, (void**)&p), "unwrap(method)");
    napi_value out;
    NCHECK(napi_create_double(env, p->x, &out), "create_double");
    return out;
}

/* F1 minimal repro: create_object + wrap, no class involved. The wrapped
 * plain object must stay typeof "object" (regression pin for the
 * _KEY_NAPI_WRAP == KEY_CTOR_KIND key-id collision). */
static napi_value AuditWrapPlain(napi_env env, napi_callback_info info) {
    (void)info;
    napi_value obj;
    NCHECK(napi_create_object(env, &obj), "create_object");
    Point* q = (Point*)malloc(sizeof(Point));
    q->x = 99; q->finalized = 0;
    NCHECK(napi_wrap(env, obj, q, PointFinalize, NULL, NULL), "wrap(plain)");
    return obj;
}

/* unwrap from outside the class — napi-rs does this for &self borrows */
static napi_value AuditUnwrapX(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    Point* p = NULL;
    NCHECK(napi_unwrap(env, argv[0], (void**)&p), "unwrap(external)");
    napi_value out;
    NCHECK(napi_create_double(env, p->x, &out), "create_double");
    return out;
}

/* create_reference(rc=1) -> get_reference_value -> unref to 0 -> delete */
static napi_value AuditRefCycle(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    napi_ref ref;
    NCHECK(napi_create_reference(env, argv[0], 1, &ref), "create_reference");
    napi_value back;
    NCHECK(napi_get_reference_value(env, ref, &back), "get_reference_value");
    bool same = false;
    NCHECK(napi_strict_equals(env, argv[0], back, &same), "strict_equals");
    uint32_t rc = 999;
    NCHECK(napi_reference_unref(env, ref, &rc), "reference_unref");
    NCHECK(napi_delete_reference(env, ref), "delete_reference");
    napi_value result, sameV, rcV;
    NCHECK(napi_create_object(env, &result), "create_object");
    NCHECK(napi_get_boolean(env, same, &sameV), "get_boolean");
    NCHECK(napi_create_uint32(env, rc, &rcV), "create_uint32");
    NCHECK(napi_set_named_property(env, result, "same", sameV), "set_named_property");
    NCHECK(napi_set_named_property(env, result, "rc", rcV), "set_named_property");
    return result;
}

/* napi_coerce_to_string on arbitrary values */
static napi_value AuditCoerce(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    napi_value out;
    NCHECK(napi_coerce_to_string(env, argv[0], &out), "coerce_to_string");
    return out;
}

/* napi_get_value_bool — returns the bool, or "status:<n>" for non-bools */
static napi_value AuditGetBool(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    bool b = false;
    napi_status s = napi_get_value_bool(env, argv[0], &b);
    napi_value out;
    if (s == napi_ok) {
        NCHECK(napi_get_boolean(env, b, &out), "get_boolean");
    } else {
        char m[32];
        snprintf(m, sizeof m, "status:%d", s);
        NCHECK(napi_create_string_utf8(env, m, NAPI_AUTO_LENGTH, &out), "create_string_utf8");
    }
    return out;
}

static napi_value AuditStrictEq(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    bool eq = false;
    NCHECK(napi_strict_equals(env, argv[0], argv[1], &eq), "strict_equals");
    napi_value out;
    NCHECK(napi_get_boolean(env, eq, &out), "get_boolean");
    return out;
}

static napi_value AuditTypeof(napi_env env, napi_callback_info info) {
    static const char* names[] = {
        "undefined", "null", "boolean", "number", "string",
        "symbol", "object", "function", "external", "bigint"
    };
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    napi_valuetype t;
    NCHECK(napi_typeof(env, argv[0], &t), "typeof");
    const char* name = (t >= 0 && t <= 9) ? names[t] : "??";
    napi_value out;
    NCHECK(napi_create_string_utf8(env, name, NAPI_AUTO_LENGTH, &out), "create_string_utf8");
    return out;
}

/* create_error -> is_error -> throw -> is_exception_pending ->
 * get_and_clear_last_exception -> is_error/strict_equals on the recovery */
static napi_value AuditErrorFlow(napi_env env, napi_callback_info info) {
    (void)info;
    napi_value code, msg, err;
    NCHECK(napi_create_string_utf8(env, "E_FLOW", NAPI_AUTO_LENGTH, &code), "create_string_utf8");
    NCHECK(napi_create_string_utf8(env, "flow-boom", NAPI_AUTO_LENGTH, &msg), "create_string_utf8");
    NCHECK(napi_create_error(env, code, msg, &err), "create_error");
    bool isErrBefore = false;
    NCHECK(napi_is_error(env, err, &isErrBefore), "is_error(created)");
    NCHECK(napi_throw(env, err), "throw");
    bool pending = false;
    NCHECK(napi_is_exception_pending(env, &pending), "is_exception_pending");
    napi_value exc;
    NCHECK(napi_get_and_clear_last_exception(env, &exc), "get_and_clear_last_exception");
    bool pendingAfter = true;
    NCHECK(napi_is_exception_pending(env, &pendingAfter), "is_exception_pending(after)");
    bool isErrAfter = false;
    NCHECK(napi_is_error(env, exc, &isErrAfter), "is_error(cleared)");
    bool sameErr = false;
    NCHECK(napi_strict_equals(env, err, exc, &sameErr), "strict_equals(err,exc)");

    napi_value result, v;
    NCHECK(napi_create_object(env, &result), "create_object");
    NCHECK(napi_get_boolean(env, isErrBefore, &v), "get_boolean");
    NCHECK(napi_set_named_property(env, result, "isErrBefore", v), "set");
    NCHECK(napi_get_boolean(env, pending, &v), "get_boolean");
    NCHECK(napi_set_named_property(env, result, "pending", v), "set");
    NCHECK(napi_get_boolean(env, pendingAfter, &v), "get_boolean");
    NCHECK(napi_set_named_property(env, result, "pendingAfter", v), "set");
    NCHECK(napi_get_boolean(env, isErrAfter, &v), "get_boolean");
    NCHECK(napi_set_named_property(env, result, "isErrAfter", v), "set");
    NCHECK(napi_get_boolean(env, sameErr, &v), "get_boolean");
    NCHECK(napi_set_named_property(env, result, "sameErr", v), "set");
    return result;
}

/* napi_throw_error with a code — JS must see .message and .code */
static napi_value AuditThrowError(napi_env env, napi_callback_info info) {
    (void)info;
    napi_throw_error(env, "E_KABOOM", "kaboom");
    return NULL;
}

/* napi_is_error on an arbitrary JS argument — for + and - cases from JS. */
static napi_value AuditIsError(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    bool is_err = false;
    NCHECK(napi_is_error(env, argv[0], &is_err), "is_error(arg)");
    napi_value out;
    NCHECK(napi_get_boolean(env, is_err, &out), "get_boolean");
    return out;
}

/* napi_create_type_error returned (not thrown) so JS can read name/message/code
 * off the create path (exercises _make_napi_error name + proto). */
static napi_value AuditMakeTypeError(napi_env env, napi_callback_info info) {
    (void)info;
    napi_value code, msg, err;
    NCHECK(napi_create_string_utf8(env, "E_TYPE", NAPI_AUTO_LENGTH, &code), "create_string_utf8");
    NCHECK(napi_create_string_utf8(env, "bad type", NAPI_AUTO_LENGTH, &msg), "create_string_utf8");
    NCHECK(napi_create_type_error(env, code, msg, &err), "create_type_error");
    return err;
}

/* get_value_string_utf8 double-call: NULL buffer for length, then read.
 * This is exactly how napi-rs reads every string argument. */
static napi_value AuditStrRoundtrip(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    size_t len = 0;
    NCHECK(napi_get_value_string_utf8(env, argv[0], NULL, 0, &len), "get_value_string_utf8(NULL)");
    char* buf = (char*)malloc(len + 1);
    size_t copied = 0;
    napi_status s = napi_get_value_string_utf8(env, argv[0], buf, len + 1, &copied);
    if (s != napi_ok) { free(buf); napi_throw_error(env, "E_AUDIT", "get_value_string_utf8(buf)"); return NULL; }
    napi_value result, lenV, copiedV, echoed;
    NCHECK(napi_create_object(env, &result), "create_object");
    NCHECK(napi_create_uint32(env, (uint32_t)len, &lenV), "create_uint32");
    NCHECK(napi_create_uint32(env, (uint32_t)copied, &copiedV), "create_uint32");
    s = napi_create_string_utf8(env, buf, copied, &echoed);
    free(buf);
    if (s != napi_ok) { napi_throw_error(env, "E_AUDIT", "create_string_utf8(echo)"); return NULL; }
    NCHECK(napi_set_named_property(env, result, "len", lenV), "set");
    NCHECK(napi_set_named_property(env, result, "copied", copiedV), "set");
    NCHECK(napi_set_named_property(env, result, "echoed", echoed), "set");
    return result;
}

/* utf8 byte-length only (NULL-buffer probe) — napi-rs sizes its Rust String
 * buffer with this exact call before the copy. */
static napi_value AuditUtf8Len(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    size_t len = 0;
    NCHECK(napi_get_value_string_utf8(env, argv[0], NULL, 0, &len), "get_value_string_utf8(NULL)");
    napi_value out;
    NCHECK(napi_create_uint32(env, (uint32_t)len, &out), "create_uint32");
    return out;
}

/* utf8 copy into an undersized buffer: must copy bufcap-1 bytes + NUL and
 * still report the FULL length. Returns { copied, reported, truncated }. */
static napi_value AuditUtf8Truncate(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    uint32_t cap = 0;
    NCHECK(napi_get_value_uint32(env, argv[1], &cap), "get_value_uint32");
    char small[64];
    if (cap > sizeof small) cap = sizeof small;
    size_t reported = 0;
    NCHECK(napi_get_value_string_utf8(env, argv[0], small, cap, &reported), "get_value_string_utf8(small)");
    size_t copied = 0;
    while (copied < cap && small[copied] != '\0') copied++;
    napi_value result, v;
    NCHECK(napi_create_object(env, &result), "create_object");
    NCHECK(napi_create_uint32(env, (uint32_t)copied, &v), "create_uint32");
    NCHECK(napi_set_named_property(env, result, "copied", v), "set");
    NCHECK(napi_create_uint32(env, (uint32_t)reported, &v), "create_uint32");
    NCHECK(napi_set_named_property(env, result, "reported", v), "set");
    return result;
}

/* napi_call_function(global, fn, 2 numeric args) */
static napi_value AuditCallFn(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    napi_value global, a, b, out;
    NCHECK(napi_get_global(env, &global), "get_global");
    NCHECK(napi_create_double(env, 19, &a), "create_double");
    NCHECK(napi_create_double(env, 23, &b), "create_double");
    napi_value args[2] = { a, b };
    NCHECK(napi_call_function(env, global, argv[0], 2, args, &out), "call_function");
    return out;
}

/* napi_define_properties: data property + method + getter on one object */
static napi_value TwiceMethod(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    double d = 0;
    NCHECK(napi_get_value_double(env, argv[0], &d), "get_value_double");
    napi_value out;
    NCHECK(napi_create_double(env, d * 2, &out), "create_double");
    return out;
}

static napi_value SevenGetter(napi_env env, napi_callback_info info) {
    (void)info;
    napi_value out;
    NCHECK(napi_create_double(env, 7, &out), "create_double");
    return out;
}

/* getter/setter pair backed by a static cell — proves NAPI setters run and
 * getters observe the written value (accessor round-trip). */
static double g_cell = 10;
static napi_value CellGetter(napi_env env, napi_callback_info info) {
    (void)info;
    napi_value out;
    NCHECK(napi_create_double(env, g_cell, &out), "create_double");
    return out;
}
static napi_value CellSetter(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    NCHECK(napi_get_value_double(env, argv[0], &g_cell), "get_value_double");
    return NULL;
}

static napi_value AuditDefineProps(napi_env env, napi_callback_info info) {
    (void)info;
    napi_value obj, answer;
    NCHECK(napi_create_object(env, &obj), "create_object");
    NCHECK(napi_create_double(env, 42, &answer), "create_double");
    napi_property_descriptor descs[] = {
        { "answer", NULL, NULL, NULL, NULL, answer, napi_enumerable, NULL },
        { "twice", NULL, TwiceMethod, NULL, NULL, NULL, napi_enumerable, NULL },
        { "seven", NULL, NULL, SevenGetter, NULL, NULL, napi_enumerable, NULL },
        { "cell", NULL, NULL, CellGetter, CellSetter, NULL, napi_enumerable, NULL },
    };
    NCHECK(napi_define_properties(env, obj, 4, descs), "define_properties");
    return obj;
}

/* finalize-count probe for the wrap finalizer (GC/RC dependent) */
static napi_value AuditFinalizeCount(napi_env env, napi_callback_info info) {
    (void)info;
    napi_value out;
    NCHECK(napi_create_double(env, point_finalize_count, &out), "create_double");
    return out;
}

/* napi_add_env_cleanup_hook — observational: prints at env teardown */
static void CleanupHook(void* arg) {
    (void)arg;
    fprintf(stderr, "CLEANUP_HOOK_RAN\n");
    fflush(stderr);
}

static napi_value AuditRegisterCleanup(napi_env env, napi_callback_info info) {
    (void)info;
    NCHECK(napi_add_env_cleanup_hook(env, CleanupHook, NULL), "add_env_cleanup_hook");
    napi_value out;
    NCHECK(napi_get_undefined(env, &out), "get_undefined");
    return out;
}

NAPI_MODULE_INIT() {
    napi_value point_class;
    napi_property_descriptor point_props[] = {
        { "getX", NULL, PointGetX, NULL, NULL, NULL, napi_default, NULL },
    };
    napi_define_class(env, "AuditPoint", NAPI_AUTO_LENGTH, PointCtor, NULL,
                      1, point_props, &point_class);

    napi_property_descriptor exports_props[] = {
        { "AuditPoint", NULL, NULL, NULL, NULL, point_class, napi_enumerable, NULL },
        { "getPrototype", NULL, AuditGetPrototype, NULL, NULL, NULL, napi_enumerable, NULL },
        { "hasOwn", NULL, AuditHasOwn, NULL, NULL, NULL, napi_enumerable, NULL },
        { "wrapPlain", NULL, AuditWrapPlain, NULL, NULL, NULL, napi_enumerable, NULL },
        { "unwrapX", NULL, AuditUnwrapX, NULL, NULL, NULL, napi_enumerable, NULL },
        { "refCycle", NULL, AuditRefCycle, NULL, NULL, NULL, napi_enumerable, NULL },
        { "coerce", NULL, AuditCoerce, NULL, NULL, NULL, napi_enumerable, NULL },
        { "getBool", NULL, AuditGetBool, NULL, NULL, NULL, napi_enumerable, NULL },
        { "strictEq", NULL, AuditStrictEq, NULL, NULL, NULL, napi_enumerable, NULL },
        { "typeOf", NULL, AuditTypeof, NULL, NULL, NULL, napi_enumerable, NULL },
        { "errorFlow", NULL, AuditErrorFlow, NULL, NULL, NULL, napi_enumerable, NULL },
        { "throwError", NULL, AuditThrowError, NULL, NULL, NULL, napi_enumerable, NULL },
        { "makeTypeError", NULL, AuditMakeTypeError, NULL, NULL, NULL, napi_enumerable, NULL },
        { "isError", NULL, AuditIsError, NULL, NULL, NULL, napi_enumerable, NULL },
        { "strRoundtrip", NULL, AuditStrRoundtrip, NULL, NULL, NULL, napi_enumerable, NULL },
        { "utf8Len", NULL, AuditUtf8Len, NULL, NULL, NULL, napi_enumerable, NULL },
        { "utf8Truncate", NULL, AuditUtf8Truncate, NULL, NULL, NULL, napi_enumerable, NULL },
        { "callFn", NULL, AuditCallFn, NULL, NULL, NULL, napi_enumerable, NULL },
        { "defineProps", NULL, AuditDefineProps, NULL, NULL, NULL, napi_enumerable, NULL },
        { "finalizeCount", NULL, AuditFinalizeCount, NULL, NULL, NULL, napi_enumerable, NULL },
        { "registerCleanup", NULL, AuditRegisterCleanup, NULL, NULL, NULL, napi_enumerable, NULL },
    };
    napi_define_properties(env, exports, sizeof exports_props / sizeof exports_props[0], exports_props);
    return exports;
}
