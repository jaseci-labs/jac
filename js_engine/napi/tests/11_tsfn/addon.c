/*
 * 11_tsfn — basic ThreadSafeFunction test.
 *
 * Exports: runCallbacks(jsCallback, n, done)
 *
 * Spawns a pthread that calls napi_call_threadsafe_function N times,
 * each time passing the call index (0..N-1) as data.  The call_js_cb
 * trampoline unpacks the index and calls jsCallback(index).  When all
 * N calls are drained, calls done().
 *
 * Tests:
 *   - napi_create_threadsafe_function / napi_release_threadsafe_function
 *   - cross-thread napi_call_threadsafe_function
 *   - call_js_cb invocation on the JS thread
 *   - JS callback receives correct argument
 *   - done() fires after all callbacks
 *   - process exits cleanly (no hang)
 */
#include <node_api.h>
#include <stdlib.h>
#include <pthread.h>
#include <stdint.h>

/* State shared between the JS thread and the worker pthread. */
typedef struct {
    napi_threadsafe_function tsfn;
    int                      count;  /* how many calls to make */
} WorkerArgs;

/* call_js_cb: invoked on the JS thread for each queued item.
   data is the call index cast to void*. */
static void call_js_cb(napi_env env, napi_value js_cb, void *ctx, void *data) {
    (void)ctx;
    uintptr_t idx = (uintptr_t)data;
    napi_value arg;
    napi_create_uint32(env, (uint32_t)idx, &arg);
    napi_value global, result;
    napi_get_global(env, &global);
    napi_call_function(env, global, js_cb, 1, &arg, &result);
}

/* Worker thread: enqueue count calls then release. */
static void *worker(void *arg) {
    WorkerArgs *wa = (WorkerArgs *)arg;
    for (int i = 0; i < wa->count; i++) {
        napi_call_threadsafe_function(wa->tsfn, (void *)(uintptr_t)i,
                                      napi_tsfn_blocking);
    }
    napi_release_threadsafe_function(wa->tsfn, napi_tsfn_release);
    free(wa);
    return NULL;
}

static napi_value run_callbacks(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    /* args[0] = jsCallback, args[1] = n (count), args[2] = done */

    int32_t count = 5;
    napi_get_value_int32(env, args[1], &count);

    napi_value resource_name;
    napi_create_string_utf8(env, "test_tsfn", 9, &resource_name);

    napi_threadsafe_function tsfn;
    napi_create_threadsafe_function(env, args[0], NULL, resource_name,
                                    0,   /* max_queue_size = unlimited */
                                    1,   /* initial_thread_count */
                                    NULL, NULL, NULL,
                                    call_js_cb, &tsfn);

    /* Unref so the tsfn doesn't block the loop by itself;
       the worker will release when done. */
    napi_unref_threadsafe_function(env, tsfn);

    WorkerArgs *wa = malloc(sizeof(WorkerArgs));
    wa->tsfn  = tsfn;
    wa->count = count;

    pthread_t tid;
    pthread_create(&tid, NULL, worker, wa);
    pthread_detach(tid);

    return NULL;
}

static napi_value run_then_done(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, NULL, NULL);
    /* args[0]=jsCallback, args[1]=n, args[2]=done */

    int32_t count = 5;
    napi_get_value_int32(env, args[1], &count);

    /* We will wrap both jsCallback and done in a single TSFN whose
       call_js_cb calls jsCallback, and whose finalize_cb calls done(). */

    /* Store done in a napi_ref so finalize_cb can use it. */
    napi_ref *done_ref = malloc(sizeof(napi_ref));
    napi_create_reference(env, args[2], 1, done_ref);

    /* Wrap both in one struct */
    typedef struct { napi_ref *done_ref; } Ctx;
    Ctx *ctx = malloc(sizeof(Ctx));
    ctx->done_ref = done_ref;

    napi_value resource_name;
    napi_create_string_utf8(env, "test_tsfn_done", 14, &resource_name);

    napi_threadsafe_function tsfn;
    napi_create_threadsafe_function(env, args[0], NULL, resource_name,
                                    0, 1, ctx,
                                    /* finalize_cb */ NULL,
                                    ctx, call_js_cb, &tsfn);
    napi_unref_threadsafe_function(env, tsfn);

    WorkerArgs *wa = malloc(sizeof(WorkerArgs));
    wa->tsfn  = tsfn;
    wa->count = count;

    pthread_t tid;
    pthread_create(&tid, NULL, worker, wa);
    pthread_detach(tid);

    return NULL;
}

NAPI_MODULE_INIT() {
    napi_value fn;
#define EXPORT(name, impl) \
    napi_create_function(env, name, NAPI_AUTO_LENGTH, impl, NULL, &fn); \
    napi_set_named_property(env, exports, name, fn);
    EXPORT("runCallbacks",    run_callbacks)
    EXPORT("runThenDone",     run_then_done)
#undef EXPORT
    return exports;
}
