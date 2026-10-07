/*
 * 10_registry — string key→value store backed by a C struct via napi_wrap.
 * Exports: create(), set(r,k,v), get(r,k), has(r,k), size(r)
 * Uses a fixed-capacity open-addressing hash map (strings only).
 */
#include <node_api.h>
#include <stdlib.h>
#include <string.h>

#define REG_CAP 64

typedef struct { char *key; char *val; } RegEntry;
typedef struct { RegEntry entries[REG_CAP]; int size; } Registry;

static void reg_finalize(napi_env env, void *data, void *hint) {
    Registry *r = (Registry *)data;
    for (int i = 0; i < REG_CAP; i++) {
        if (r->entries[i].key) { free(r->entries[i].key); free(r->entries[i].val); }
    }
    free(r);
}

/* djb2 slot finder — returns index to insert/find key, or -1 if full */
static int reg_slot(const Registry *r, const char *key) {
    uint32_t h = 5381u;
    for (const char *p = key; *p; p++) h = ((h << 5) + h) + (unsigned char)*p;
    int start = (int)(h % REG_CAP);
    for (int d = 0; d < REG_CAP; d++) {
        int i = (start + d) % REG_CAP;
        if (!r->entries[i].key || strcmp(r->entries[i].key, key) == 0) return i;
    }
    return -1;
}

static napi_value reg_create(napi_env env, napi_callback_info info) {
    Registry *r = calloc(1, sizeof(Registry));
    napi_value obj;
    napi_create_object(env, &obj);
    napi_wrap(env, obj, r, reg_finalize, NULL, NULL);
    return obj;
}

static napi_value reg_set(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    Registry *r;
    napi_unwrap(env, args[0], (void **)&r);
    size_t klen, vlen;
    napi_get_value_string_utf8(env, args[1], NULL, 0, &klen);
    char *k = malloc(klen + 1);
    napi_get_value_string_utf8(env, args[1], k, klen + 1, &klen);
    napi_get_value_string_utf8(env, args[2], NULL, 0, &vlen);
    char *v = malloc(vlen + 1);
    napi_get_value_string_utf8(env, args[2], v, vlen + 1, &vlen);
    int i = reg_slot(r, k);
    if (i < 0) {
        free(k); free(v);
        napi_throw_error(env, NULL, "Registry full");
        return NULL;
    }
    if (!r->entries[i].key) { r->entries[i].key = k; r->size++; }
    else { free(k); free(r->entries[i].val); }
    r->entries[i].val = v;
    napi_value undef;
    napi_get_undefined(env, &undef);
    return undef;
}

static napi_value reg_get(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    Registry *r;
    napi_unwrap(env, args[0], (void **)&r);
    size_t klen;
    napi_get_value_string_utf8(env, args[1], NULL, 0, &klen);
    char *k = malloc(klen + 1);
    napi_get_value_string_utf8(env, args[1], k, klen + 1, &klen);
    int i = reg_slot(r, k);
    free(k);
    if (i < 0 || !r->entries[i].key) {
        napi_value undef;
        napi_get_undefined(env, &undef);
        return undef;
    }
    napi_value out;
    napi_create_string_utf8(env, r->entries[i].val, NAPI_AUTO_LENGTH, &out);
    return out;
}

static napi_value reg_has(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    Registry *r;
    napi_unwrap(env, args[0], (void **)&r);
    size_t klen;
    napi_get_value_string_utf8(env, args[1], NULL, 0, &klen);
    char *k = malloc(klen + 1);
    napi_get_value_string_utf8(env, args[1], k, klen + 1, &klen);
    int i = reg_slot(r, k);
    free(k);
    bool exists = (i >= 0 && r->entries[i].key != NULL);
    napi_value out;
    napi_get_boolean(env, exists, &out);
    return out;
}

static napi_value reg_size(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    Registry *r;
    napi_unwrap(env, args[0], (void **)&r);
    napi_value out;
    napi_create_int32(env, r->size, &out);
    return out;
}

NAPI_MODULE_INIT() {
    napi_value fn;
#define EXPORT(name) \
    napi_create_function(env, #name, NAPI_AUTO_LENGTH, reg_##name, NULL, &fn); \
    napi_set_named_property(env, exports, #name, fn);
    EXPORT(create)
    EXPORT(set)
    EXPORT(get)
    EXPORT(has)
    EXPORT(size)
#undef EXPORT
    return exports;
}
