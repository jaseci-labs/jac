/*
 * 12_tsfn_async — TSFN where the JS callback is async (returns a Promise).
 *
 * Exports: callAsync(asyncJsFn, value) → Promise<number>
 *
 * Flow:
 *   1. JS calls callAsync(fn, 42) → returns outer Promise.
 *   2. C spawns a pthread that enqueues one TSFN call (with value=42 as data).
 *   3. On the JS thread, async_call_js_cb fires:
 *        a. Calls fn(42) via napi_call_function → inner_promise (async fn).
 *        b. Attaches .then(resolve_outer, reject_outer) to inner_promise.
 *   4. When inner_promise resolves with the return value of fn, resolve_outer
 *      fires and calls napi_resolve_deferred → outer Promise resolves.
 *   5. JS test: outer.then(v => assert v === expected).
 *
 * Tests:
 *   - call_js_cb can call an async JS function via napi_call_function
 *   - The returned napi_value is a Promise object (typeof === 'object')
 *   - .then chaining through a native TSFN round-trip works
 *   - Outer Promise resolves with the value the async JS function returns
 *   - Process exits cleanly after settlement
 */
#include <node_api.h>
#include <stdlib.h>
#include <pthread.h>
#include <stdint.h>

/* Per-call context carried as TSFN data. */
typedef struct {
    napi_deferred deferred;
    int32_t       value;
} CallCtx;

/* Resolve/reject the outer deferred from a .then/.catch handler. */
static napi_value outer_resolve(napi_env env, napi_callback_info info) {
    void *data;
    size_t argc = 1; napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, &data);
    napi_value val; napi_get_undefined(env, &val);
    if (argc > 0) val = args[0];
    napi_resolve_deferred(env, (napi_deferred)data, val);
    return NULL;
}
static napi_value outer_reject(napi_env env, napi_callback_info info) {
    void *data;
    size_t argc = 1; napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, NULL, &data);
    napi_value val; napi_get_undefined(env, &val);
    if (argc > 0) val = args[0];
    napi_reject_deferred(env, (napi_deferred)data, val);
    return NULL;
}

/* call_js_cb: runs on the JS thread, invoked by the TSFN drain. */
static void async_call_js_cb(napi_env env, napi_value js_fn,
                              void *ctx, void *data) {
    (void)ctx;
    CallCtx *cc = (CallCtx *)data;

    /* Call the async JS function. */
    napi_value arg, global, inner_promise;
    napi_create_int32(env, cc->value, &arg);
    napi_get_global(env, &global);
    napi_status st = napi_call_function(env, global, js_fn, 1, &arg, &inner_promise);
    if (st != napi_ok || !inner_promise) {
        napi_value msg;
        napi_create_string_utf8(env, "napi_call_function failed", 25, &msg);
        napi_reject_deferred(env, cc->deferred, msg);
        free(cc);
        return;
    }

    /* Attach .then(resolve, reject) to inner_promise. */
    napi_value then_key, then_fn;
    napi_create_string_utf8(env, "then", 4, &then_key);
    napi_get_property(env, inner_promise, then_key, &then_fn);

    napi_value res_fn, rej_fn;
    napi_create_function(env, "res", 3, outer_resolve, cc->deferred, &res_fn);
    napi_create_function(env, "rej", 3, outer_reject,  cc->deferred, &rej_fn);

    napi_value then_args[2] = { res_fn, rej_fn };
    napi_call_function(env, inner_promise, then_fn, 2, then_args, NULL);

    free(cc);
}

/* Worker thread: enqueue one TSFN call then release. */
typedef struct { napi_threadsafe_function tsfn; CallCtx *cc; } WorkerArg;

static void *worker(void *arg) {
    WorkerArg *wa = (WorkerArg *)arg;
    napi_call_threadsafe_function(wa->tsfn, wa->cc, napi_tsfn_blocking);
    napi_release_threadsafe_function(wa->tsfn, napi_tsfn_release);
    free(wa);
    return NULL;
}

static napi_value call_async(napi_env env, napi_callback_info info) {
    size_t argc = 2; napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);

    int32_t value = 0;
    napi_get_value_int32(env, args[1], &value);

    /* Outer promise returned to JS immediately. */
    napi_value outer_promise;
    napi_deferred deferred;
    napi_create_promise(env, &deferred, &outer_promise);

    napi_value rname;
    napi_create_string_utf8(env, "tsfn_async", 10, &rname);

    napi_threadsafe_function tsfn;
    napi_create_threadsafe_function(env, args[0], NULL, rname,
                                    0, 1, NULL, NULL, NULL,
                                    async_call_js_cb, &tsfn);
    napi_unref_threadsafe_function(env, tsfn);

    CallCtx *cc = malloc(sizeof(CallCtx));
    cc->deferred = deferred;
    cc->value    = value;

    WorkerArg *wa = malloc(sizeof(WorkerArg));
    wa->tsfn = tsfn;
    wa->cc   = cc;

    pthread_t tid;
    pthread_create(&tid, NULL, worker, wa);
    pthread_detach(tid);

    return outer_promise;
}

NAPI_MODULE_INIT() {
    napi_value fn;
    napi_create_function(env, "callAsync", NAPI_AUTO_LENGTH, call_async, NULL, &fn);
    napi_set_named_property(env, exports, "callAsync", fn);
    return exports;
}
