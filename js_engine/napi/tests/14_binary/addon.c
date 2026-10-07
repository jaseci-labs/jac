/*
 * 14_binary — NAPI binary ops 86–97 (ROLLUP_SUPPORT_PLAN.md R1).
 * ArrayBuffer / TypedArray / DataView / Buffer create + info ops, the
 * binary predicates, and both aliasing directions (C writes → JS reads,
 * JS writes → C reads) that zero-copy backing stores must satisfy.
 */
#include <node_api.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NCHECK(call, what)                                          \
    do {                                                            \
        napi_status s__ = (call);                                   \
        if (s__ != napi_ok) {                                       \
            char m__[128];                                          \
            snprintf(m__, sizeof m__, "%s -> status %d", what, s__);\
            napi_throw_error(env, "E_BIN", m__);                    \
            return NULL;                                            \
        }                                                           \
    } while (0)

/* create_arraybuffer(16), stamp bytes 0..15 through the data pointer. */
static napi_value MakeStampedAb(napi_env env, napi_callback_info info) {
    (void)info;
    void *data = NULL;
    napi_value ab;
    NCHECK(napi_create_arraybuffer(env, 16, &data, &ab), "create_arraybuffer");
    if (data == NULL) { napi_throw_error(env, "E_BIN", "create_arraybuffer NULL data"); return NULL; }
    for (int i = 0; i < 16; i++) ((unsigned char*)data)[i] = (unsigned char)i;
    return ab;
}

/* get_arraybuffer_info → { len, firstByte } */
static napi_value AbInfo(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    void *data = NULL; size_t len = 0;
    NCHECK(napi_get_arraybuffer_info(env, argv[0], &data, &len), "get_arraybuffer_info");
    napi_value result, v;
    NCHECK(napi_create_object(env, &result), "create_object");
    NCHECK(napi_create_double(env, (double)len, &v), "create_double");
    NCHECK(napi_set_named_property(env, result, "len", v), "set");
    NCHECK(napi_create_double(env, len > 0 && data ? ((unsigned char*)data)[0] : -1, &v), "create_double");
    NCHECK(napi_set_named_property(env, result, "firstByte", v), "set");
    return result;
}

/* external arraybuffer over malloc'd pattern memory (0xA0 + i). */
static void FreeExternal(napi_env env, void *data, void *hint) {
    (void)env; (void)hint;
    free(data);
}

static napi_value MakeExternalAb(napi_env env, napi_callback_info info) {
    (void)info;
    unsigned char *mem = (unsigned char*)malloc(8);
    for (int i = 0; i < 8; i++) mem[i] = (unsigned char)(0xA0 + i);
    napi_value ab;
    NCHECK(napi_create_external_arraybuffer(env, mem, 8, FreeExternal, NULL, &ab),
           "create_external_arraybuffer");
    return ab;
}

/* detach + predicate probe */
static napi_value DetachAb(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    NCHECK(napi_detach_arraybuffer(env, argv[0]), "detach_arraybuffer");
    bool detached = false;
    NCHECK(napi_is_detached_arraybuffer(env, argv[0], &detached), "is_detached");
    napi_value out;
    NCHECK(napi_get_boolean(env, detached, &out), "get_boolean");
    return out;
}

/* create_typedarray(uint32, 4 elems, ab, offset 0) */
static napi_value MakeU32Over(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    napi_value ta;
    NCHECK(napi_create_typedarray(env, napi_uint32_array, 4, argv[0], 0, &ta),
           "create_typedarray");
    return ta;
}

/* get_typedarray_info → { type, length, byteOffset, sum, buffer } */
static napi_value TaInfo(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    napi_typedarray_type type;
    size_t length = 0, byte_offset = 0;
    void *data = NULL;
    napi_value ab;
    NCHECK(napi_get_typedarray_info(env, argv[0], &type, &length, &data, &ab, &byte_offset),
           "get_typedarray_info");
    long sum = 0;
    for (size_t i = 0; i < length && data; i++) {
        /* sum raw BYTES of the view span (element-size agnostic) */
        sum += ((unsigned char*)data)[i];
    }
    napi_value result, v;
    NCHECK(napi_create_object(env, &result), "create_object");
    NCHECK(napi_create_double(env, (double)type, &v), "create_double");
    NCHECK(napi_set_named_property(env, result, "type", v), "set");
    NCHECK(napi_create_double(env, (double)length, &v), "create_double");
    NCHECK(napi_set_named_property(env, result, "length", v), "set");
    NCHECK(napi_create_double(env, (double)byte_offset, &v), "create_double");
    NCHECK(napi_set_named_property(env, result, "byteOffset", v), "set");
    NCHECK(napi_create_double(env, (double)sum, &v), "create_double");
    NCHECK(napi_set_named_property(env, result, "byteSumOfLenBytes", v), "set");
    NCHECK(napi_set_named_property(env, result, "buffer", ab), "set");
    return result;
}

/* create_dataview + get_dataview_info round-trip → { byteLength, byteOffset, sameBuffer } */
static napi_value DvRoundtrip(napi_env env, napi_callback_info info) {
    size_t argc = 3; napi_value argv[3];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    double off_d = 0, len_d = 0;
    NCHECK(napi_get_value_double(env, argv[1], &off_d), "get_value_double");
    NCHECK(napi_get_value_double(env, argv[2], &len_d), "get_value_double");
    napi_value dv;
    NCHECK(napi_create_dataview(env, (size_t)len_d, argv[0], (size_t)off_d, &dv),
           "create_dataview");
    bool is_dv = false;
    NCHECK(napi_is_dataview(env, dv, &is_dv), "is_dataview");
    size_t byte_length = 0, byte_offset = 0;
    void *data = NULL;
    napi_value ab_out;
    NCHECK(napi_get_dataview_info(env, dv, &byte_length, &data, &ab_out, &byte_offset),
           "get_dataview_info");
    bool same = false;
    NCHECK(napi_strict_equals(env, argv[0], ab_out, &same), "strict_equals");
    napi_value result, v;
    NCHECK(napi_create_object(env, &result), "create_object");
    NCHECK(napi_create_double(env, (double)byte_length, &v), "create_double");
    NCHECK(napi_set_named_property(env, result, "byteLength", v), "set");
    NCHECK(napi_create_double(env, (double)byte_offset, &v), "create_double");
    NCHECK(napi_set_named_property(env, result, "byteOffset", v), "set");
    NCHECK(napi_get_boolean(env, same, &v), "get_boolean");
    NCHECK(napi_set_named_property(env, result, "sameBuffer", v), "set");
    NCHECK(napi_get_boolean(env, is_dv, &v), "get_boolean");
    NCHECK(napi_set_named_property(env, result, "isDataView", v), "set");
    return result;
}

/* create_buffer(8) stamped 0x10+i through data */
static napi_value MakeStampedBuffer(napi_env env, napi_callback_info info) {
    (void)info;
    void *data = NULL;
    napi_value b;
    NCHECK(napi_create_buffer(env, 8, &data, &b), "create_buffer");
    if (data == NULL) { napi_throw_error(env, "E_BIN", "create_buffer NULL data"); return NULL; }
    for (int i = 0; i < 8; i++) ((unsigned char*)data)[i] = (unsigned char)(0x10 + i);
    return b;
}

/* create_buffer_copy from a C string literal */
static napi_value MakeBufferCopy(napi_env env, napi_callback_info info) {
    (void)info;
    static const char src[] = "rollup!";
    void *data = NULL;
    napi_value b;
    NCHECK(napi_create_buffer_copy(env, sizeof src - 1, src, &data, &b), "create_buffer_copy");
    /* mutate the ORIGINAL after the copy — must NOT affect the buffer */
    return b;
}

/* create_external_buffer over malloc'd pattern (0x40 + i) */
static napi_value MakeExternalBuffer(napi_env env, napi_callback_info info) {
    (void)info;
    unsigned char *mem = (unsigned char*)malloc(12);
    for (int i = 0; i < 12; i++) mem[i] = (unsigned char)(0x40 + i);
    napi_value b;
    NCHECK(napi_create_external_buffer(env, 12, mem, FreeExternal, NULL, &b),
           "create_external_buffer");
    return b;
}

/* R1.2 finalizer probe: external buffer whose finalizer counts invocations
 * and prints a marker (exactly-once proof: marker must appear ONCE, at GC
 * or at env/process teardown — never during normal use). */
static int ext_finalize_count = 0;
static void CountingFinalize(napi_env env, void *data, void *hint) {
    (void)env; (void)hint;
    ext_finalize_count++;
    fprintf(stderr, "EXT_FINALIZED count=%d\n", ext_finalize_count);
    free(data);
}

static napi_value MakeCountedExternal(napi_env env, napi_callback_info info) {
    (void)info;
    unsigned char *mem = (unsigned char*)malloc(4);
    for (int i = 0; i < 4; i++) mem[i] = (unsigned char)i;
    napi_value b;
    NCHECK(napi_create_external_buffer(env, 4, mem, CountingFinalize, NULL, &b),
           "create_external_buffer(counted)");
    return b;
}

static napi_value ExtFinalizeCount(napi_env env, napi_callback_info info) {
    (void)info;
    napi_value out;
    NCHECK(napi_create_double(env, ext_finalize_count, &out), "create_double");
    return out;
}

/* get_buffer_info → { len, sum } (C-side read of a JS-created buffer) */
static napi_value BufferInfo(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    void *data = NULL; size_t len = 0;
    NCHECK(napi_get_buffer_info(env, argv[0], &data, &len), "get_buffer_info");
    long sum = 0;
    for (size_t i = 0; i < len && data; i++) sum += ((unsigned char*)data)[i];
    napi_value result, v;
    NCHECK(napi_create_object(env, &result), "create_object");
    NCHECK(napi_create_double(env, (double)len, &v), "create_double");
    NCHECK(napi_set_named_property(env, result, "len", v), "set");
    NCHECK(napi_create_double(env, (double)sum, &v), "create_double");
    NCHECK(napi_set_named_property(env, result, "sum", v), "set");
    return result;
}

/* C-side mutation of a JS-provided view: add `delta` to every byte. */
static napi_value MutateBytes(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value argv[2];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    double delta = 0;
    NCHECK(napi_get_value_double(env, argv[1], &delta), "get_value_double");
    void *data = NULL; size_t len = 0;
    NCHECK(napi_get_buffer_info(env, argv[0], &data, &len), "get_buffer_info");
    for (size_t i = 0; i < len && data; i++)
        ((unsigned char*)data)[i] = (unsigned char)(((unsigned char*)data)[i] + (int)delta);
    napi_value out;
    NCHECK(napi_create_double(env, (double)len, &out), "create_double");
    return out;
}

/* all predicates on one value → { ab, buf, ta, dv, detached } */
static napi_value Preds(napi_env env, napi_callback_info info) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    bool ab = false, bu = false, ta = false, dv = false, det = false;
    NCHECK(napi_is_arraybuffer(env, argv[0], &ab), "is_arraybuffer");
    NCHECK(napi_is_buffer(env, argv[0], &bu), "is_buffer");
    NCHECK(napi_is_typedarray(env, argv[0], &ta), "is_typedarray");
    NCHECK(napi_is_dataview(env, argv[0], &dv), "is_dataview");
    napi_is_detached_arraybuffer(env, argv[0], &det); /* invalid-arg tolerated */
    napi_value result, v;
    NCHECK(napi_create_object(env, &result), "create_object");
    NCHECK(napi_get_boolean(env, ab, &v), "get_boolean");
    NCHECK(napi_set_named_property(env, result, "ab", v), "set");
    NCHECK(napi_get_boolean(env, bu, &v), "get_boolean");
    NCHECK(napi_set_named_property(env, result, "buf", v), "set");
    NCHECK(napi_get_boolean(env, ta, &v), "get_boolean");
    NCHECK(napi_set_named_property(env, result, "ta", v), "set");
    NCHECK(napi_get_boolean(env, dv, &v), "get_boolean");
    NCHECK(napi_set_named_property(env, result, "dv", v), "set");
    NCHECK(napi_get_boolean(env, det, &v), "get_boolean");
    NCHECK(napi_set_named_property(env, result, "detached", v), "set");
    return result;
}

NAPI_MODULE_INIT() {
    napi_property_descriptor props[] = {
        { "makeStampedAb", NULL, MakeStampedAb, NULL, NULL, NULL, napi_enumerable, NULL },
        { "abInfo", NULL, AbInfo, NULL, NULL, NULL, napi_enumerable, NULL },
        { "makeExternalAb", NULL, MakeExternalAb, NULL, NULL, NULL, napi_enumerable, NULL },
        { "detachAb", NULL, DetachAb, NULL, NULL, NULL, napi_enumerable, NULL },
        { "makeU32Over", NULL, MakeU32Over, NULL, NULL, NULL, napi_enumerable, NULL },
        { "taInfo", NULL, TaInfo, NULL, NULL, NULL, napi_enumerable, NULL },
        { "dvRoundtrip", NULL, DvRoundtrip, NULL, NULL, NULL, napi_enumerable, NULL },
        { "makeStampedBuffer", NULL, MakeStampedBuffer, NULL, NULL, NULL, napi_enumerable, NULL },
        { "makeBufferCopy", NULL, MakeBufferCopy, NULL, NULL, NULL, napi_enumerable, NULL },
        { "makeExternalBuffer", NULL, MakeExternalBuffer, NULL, NULL, NULL, napi_enumerable, NULL },
        { "makeCountedExternal", NULL, MakeCountedExternal, NULL, NULL, NULL, napi_enumerable, NULL },
        { "extFinalizeCount", NULL, ExtFinalizeCount, NULL, NULL, NULL, napi_enumerable, NULL },
        { "bufferInfo", NULL, BufferInfo, NULL, NULL, NULL, napi_enumerable, NULL },
        { "mutateBytes", NULL, MutateBytes, NULL, NULL, NULL, napi_enumerable, NULL },
        { "preds", NULL, Preds, NULL, NULL, NULL, napi_enumerable, NULL },
    };
    napi_define_properties(env, exports, sizeof props / sizeof props[0], props);
    return exports;
}
