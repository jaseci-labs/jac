/*
 * 02_string — native string manipulation addon.
 * Exports: reverseStr(s), wordCount(s), capitalize(s)
 */
#include <node_api.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

static napi_value str_reverseStr(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    size_t len;
    napi_get_value_string_utf8(env, args[0], NULL, 0, &len);
    char *buf = malloc(len + 1);
    napi_get_value_string_utf8(env, args[0], buf, len + 1, &len);
    for (size_t i = 0; len > 0 && i < len / 2; i++) {
        size_t j = len - 1 - i;
        char t = buf[i]; buf[i] = buf[j]; buf[j] = t;
    }
    napi_value out;
    napi_create_string_utf8(env, buf, len, &out);
    free(buf);
    return out;
}

static napi_value str_wordCount(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    size_t len;
    napi_get_value_string_utf8(env, args[0], NULL, 0, &len);
    char *buf = malloc(len + 2);
    napi_get_value_string_utf8(env, args[0], buf, len + 1, &len);
    buf[len] = '\0';
    int count = 0, in_word = 0;
    for (size_t i = 0; i <= len; i++) {
        if (buf[i] && !isspace((unsigned char)buf[i])) {
            if (!in_word) { count++; in_word = 1; }
        } else {
            in_word = 0;
        }
    }
    free(buf);
    napi_value out;
    napi_create_int32(env, count, &out);
    return out;
}

static napi_value str_capitalize(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    size_t len;
    napi_get_value_string_utf8(env, args[0], NULL, 0, &len);
    char *buf = malloc(len + 1);
    napi_get_value_string_utf8(env, args[0], buf, len + 1, &len);
    for (size_t i = 0; i < len; i++)
        buf[i] = (i == 0) ? toupper((unsigned char)buf[i])
                          : tolower((unsigned char)buf[i]);
    napi_value out;
    napi_create_string_utf8(env, buf, len, &out);
    free(buf);
    return out;
}

NAPI_MODULE_INIT() {
    napi_value fn;
#define EXPORT(name) \
    napi_create_function(env, #name, NAPI_AUTO_LENGTH, str_##name, NULL, &fn); \
    napi_set_named_property(env, exports, #name, fn);
    EXPORT(reverseStr)
    EXPORT(wordCount)
    EXPORT(capitalize)
#undef EXPORT
    return exports;
}
