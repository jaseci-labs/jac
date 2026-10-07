/*
 * 15_async_work — napi_create/queue/cancel/delete_async_work (R2 of
 * docs/ROLLUP_SUPPORT_PLAN.md), exercised the way napi-rs AsyncTask drives
 * them: promise + async work, execute computes off-env, complete settles
 * the deferred and deletes the work.
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
            napi_throw_error(env, "E_ASYNC", m__);                  \
            return NULL;                                            \
        }                                                           \
    } while (0)

typedef struct {
    napi_async_work work;
    napi_deferred deferred;
    double input;
    double result;
    int fail;              /* complete rejects instead of resolving */
    int execute_ran;
} DoubleTask;

static int g_execute_calls = 0;

static void DoubleExecute(napi_env env, void *data) {
    /* Runs "off-thread" per NAPI contract: no env access allowed. */
    (void)env;
    DoubleTask *t = (DoubleTask*)data;
    t->result = t->input * 2;
    t->execute_ran = 1;
    g_execute_calls++;
}

static void DoubleComplete(napi_env env, napi_status status, void *data) {
    DoubleTask *t = (DoubleTask*)data;
    if (t->fail) {
        napi_value code, msg, err;
        napi_create_string_utf8(env, "E_TASK", NAPI_AUTO_LENGTH, &code);
        napi_create_string_utf8(env, "task failed", NAPI_AUTO_LENGTH, &msg);
        napi_create_error(env, code, msg, &err);
        napi_reject_deferred(env, t->deferred, err);
    } else if (status == napi_cancelled) {
        /* Node delivers this when cancel won the threadpool race. */
        napi_value code, msg, err;
        napi_create_string_utf8(env, "E_CANCELLED", NAPI_AUTO_LENGTH, &code);
        napi_create_string_utf8(env, "cancelled", NAPI_AUTO_LENGTH, &msg);
        napi_create_error(env, code, msg, &err);
        napi_reject_deferred(env, t->deferred, err);
    } else if (status == napi_ok && t->execute_ran) {
        napi_value out;
        napi_create_double(env, t->result, &out);
        napi_resolve_deferred(env, t->deferred, out);
    } else {
        napi_value code, msg, err;
        napi_create_string_utf8(env, "E_STATUS", NAPI_AUTO_LENGTH, &code);
        napi_create_string_utf8(env, "bad status or execute skipped", NAPI_AUTO_LENGTH, &msg);
        napi_create_error(env, code, msg, &err);
        napi_reject_deferred(env, t->deferred, err);
    }
    napi_delete_async_work(env, t->work);
    free(t);
}

static napi_value StartDouble(napi_env env, napi_callback_info info, int fail) {
    size_t argc = 1; napi_value argv[1];
    NCHECK(napi_get_cb_info(env, info, &argc, argv, NULL, NULL), "get_cb_info");
    DoubleTask *t = (DoubleTask*)calloc(1, sizeof(DoubleTask));
    t->fail = fail;
    if (argc > 0) napi_get_value_double(env, argv[0], &t->input);
    napi_value promise, rname;
    NCHECK(napi_create_promise(env, &t->deferred, &promise), "create_promise");
    NCHECK(napi_create_string_utf8(env, "double-task", NAPI_AUTO_LENGTH, &rname), "resource_name");
    NCHECK(napi_create_async_work(env, NULL, rname, DoubleExecute, DoubleComplete,
                                  t, &t->work), "create_async_work");
    NCHECK(napi_queue_async_work(env, t->work), "queue_async_work");
    return promise;
}

static napi_value AsyncDouble(napi_env env, napi_callback_info info) {
    return StartDouble(env, info, 0);
}

static napi_value AsyncFail(napi_env env, napi_callback_info info) {
    return StartDouble(env, info, 1);
}

/* Immediately after queue returns: has execute run (sync-execute model)?
 * Under real Node this is racy, so the JS test only asserts it under the
 * engine runner. Returns g_execute_calls. */
static napi_value ExecuteCalls(napi_env env, napi_callback_info info) {
    (void)info;
    napi_value out;
    NCHECK(napi_create_double(env, g_execute_calls, &out), "create_double");
    return out;
}

/* cancel after queue must fail (work already executing/executed). */
static napi_value CancelAfterQueue(napi_env env, napi_callback_info info) {
    (void)info;
    DoubleTask *t = (DoubleTask*)calloc(1, sizeof(DoubleTask));
    t->input = 1;
    napi_value promise, rname;
    NCHECK(napi_create_promise(env, &t->deferred, &promise), "create_promise");
    NCHECK(napi_create_string_utf8(env, "cancel-probe", NAPI_AUTO_LENGTH, &rname), "resource_name");
    NCHECK(napi_create_async_work(env, NULL, rname, DoubleExecute, DoubleComplete,
                                  t, &t->work), "create_async_work");
    NCHECK(napi_queue_async_work(env, t->work), "queue_async_work");
    napi_status cs = napi_cancel_async_work(env, t->work);
    /* Return { status, promise } so JS can observe both the cancel status
     * and the eventual settlement (avoids an unhandled rejection when the
     * cancel wins the race under Node). */
    napi_value result, v;
    NCHECK(napi_create_object(env, &result), "create_object");
    NCHECK(napi_create_double(env, (double)cs, &v), "create_double");
    NCHECK(napi_set_named_property(env, result, "status", v), "set");
    NCHECK(napi_set_named_property(env, result, "promise", promise), "set");
    return result;
}

NAPI_MODULE_INIT() {
    napi_property_descriptor props[] = {
        { "asyncDouble", NULL, AsyncDouble, NULL, NULL, NULL, napi_enumerable, NULL },
        { "asyncFail", NULL, AsyncFail, NULL, NULL, NULL, napi_enumerable, NULL },
        { "executeCalls", NULL, ExecuteCalls, NULL, NULL, NULL, napi_enumerable, NULL },
        { "cancelAfterQueue", NULL, CancelAfterQueue, NULL, NULL, NULL, napi_enumerable, NULL },
    };
    napi_define_properties(env, exports, sizeof props / sizeof props[0], props);
    return exports;
}
