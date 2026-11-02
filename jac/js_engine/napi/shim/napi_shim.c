/*
 * napi_shim.c — Node-API (NAPI) ABI surface for js_engine
 *
 * Compiled into libjs_native.so, which the engine library links and the
 * launcher loads RTLD_GLOBAL, so every napi_* symbol is globally visible to
 * subsequently dlopen'd .node addons.
 *
 * Architecture (Phase N1):
 *   - N1 stubs (ops 1–33) pack their C arguments into a stack-allocated
 *     int64_t argv[] and call _dispatch(op_id, argv, argc).
 *   - Pointer args (napi_env, napi_value, out-pointers) are cast via
 *     (int64_t)(uintptr_t).  Scalar int32/int64/bool args are zero- or
 *     sign-extended.  double args are bit-cast via a union.
 *   - The Jac dispatcher reads slots via _napi_argv_i64(argv, idx) and
 *     writes out-params via _napi_write_i64 / _napi_write_i32 / etc.
 *   - Remaining stubs (ops 34–147, not yet implemented) still pass NULL, 0.
 *   - napi_value == JSValue (identity model); real handle-slot pool deferred
 *     to Phase N4.
 *   - _napi_set_dispatch / _napi_get_pending_init / _napi_invoke_register:
 *     unchanged from Phase 0.
 *   - _napi_argv_i64 / _napi_write_*: new N1 helpers exported from the .so
 *     so Jac can call them via `import from "libjs_native.so"`.
 *   Op-ID constants are defined in napi/src/napi_dispatch.na.jac and must
 *   stay in sync with the enum below.
 */

#define NAPI_EXPERIMENTAL   /* expose all napi_version fields */
/* Node 22+ maps "basic" NAPI entry points to const napi_env / nogc finalizers
 * when NAPI_EXPERIMENTAL is set.  Our shim passes napi_env (non-const) and
 * napi_finalize everywhere; opt out so declarations match implementations. */
#define NODE_API_EXPERIMENTAL_BASIC_ENV_OPT_OUT
#define NODE_API_EXPERIMENTAL_NOGC_ENV_OPT_OUT
#include <node_api.h>

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <malloc.h>
#include <pthread.h>
#include <uv.h>
#include <execinfo.h>
#include <unistd.h>

/* ── Jac dispatcher callback ──────────────────────────────────────────────── */

typedef int (*jac_dispatch_fn)(int op, int64_t *argv, int argc);
static jac_dispatch_fn _jac_dispatch = NULL;

/* Called from Jac once at first .node load: _napi_set_dispatch(_napi_dispatch) */
void _napi_set_dispatch(int64_t fn_ptr) {
    _jac_dispatch = (jac_dispatch_fn)(uintptr_t)fn_ptr;
}

/* ── TSFN ring-buffer queue ─────────────────────────────────────────────────
 *
 * jac_tsfn_t holds all the state for one napi_threadsafe_function.  It lives
 * on the heap and its pointer IS the opaque napi_threadsafe_function handle.
 *
 * Threading contract:
 *   - Only Tokio worker threads write to the queue (via lock + push).
 *   - Only the JS (libuv) thread reads from the queue (via drain callback).
 *   - uv_async_send is the single thread-safe libuv primitive used for wakeup.
 */

#define JAC_TSFN_QUEUE_CAP 256

typedef struct jac_tsfn_s {
    napi_env  env;
    int64_t   js_func;   /* NaN-boxed JSValue of the JS callback (0 = completion) */
    void     *context;   /* addon context pointer */
    napi_threadsafe_function_call_js call_js_cb; /* addon trampoline */
    napi_finalize thread_finalize_cb;
    void     *thread_finalize_data;

    /* ring buffer of `data` pointers pushed by worker threads */
    void     *queue[JAC_TSFN_QUEUE_CAP];
    size_t    q_head;    /* next read position  */
    size_t    q_tail;    /* next write position */
    pthread_mutex_t lock;

    int       thread_count; /* acquire/release refcount */
    int       ref;          /* ref/unref: >0 keeps the loop alive */
    int       closing;      /* set when thread_count reaches 0 */
} jac_tsfn_t;

/* Pointer to the uv_async_t that the JS thread owns for TSFN drain wakeups.
 * Set by Jac via _napi_tsfn_set_drain_handle() after el_create(). */
static uv_async_t *_tsfn_drain_handle = NULL;

/* Registry of all live tsfns — the JS-thread drain walks this list.
 * Access is single-threaded (JS thread only) except for appends at CREATE
 * time which also happen on the JS thread (during the napi init callback). */
#define JAC_TSFN_MAX 64
static jac_tsfn_t *_tsfn_registry[JAC_TSFN_MAX];
static int         _tsfn_count = 0;

/* Called from Jac (JS thread) to register the uv_async_t drain handle. */
void _napi_tsfn_set_drain_handle(int64_t handle_ptr) {
    _tsfn_drain_handle = (uv_async_t *)(uintptr_t)handle_ptr;
}

/* ── TSFN accessors exported to Jac ────────────────────────────────────────── */

int64_t _napi_tsfn_get_js_func(int64_t tsfn_ptr) {
    jac_tsfn_t *t = (jac_tsfn_t *)(uintptr_t)tsfn_ptr;
    return t ? t->js_func : 0;
}
int64_t _napi_tsfn_get_context(int64_t tsfn_ptr) {
    jac_tsfn_t *t = (jac_tsfn_t *)(uintptr_t)tsfn_ptr;
    return t ? (int64_t)(uintptr_t)t->context : 0;
}
int64_t _napi_tsfn_get_env(int64_t tsfn_ptr) {
    jac_tsfn_t *t = (jac_tsfn_t *)(uintptr_t)tsfn_ptr;
    return t ? (int64_t)(uintptr_t)t->env : 0;
}
int64_t _napi_tsfn_get_call_js_cb(int64_t tsfn_ptr) {
    jac_tsfn_t *t = (jac_tsfn_t *)(uintptr_t)tsfn_ptr;
    return t ? (int64_t)(uintptr_t)t->call_js_cb : 0;
}
int _napi_tsfn_thread_count(int64_t tsfn_ptr) {
    jac_tsfn_t *t = (jac_tsfn_t *)(uintptr_t)tsfn_ptr;
    return t ? t->thread_count : 0;
}

/* Pop one data pointer from the ring buffer.  Returns 1 on success, 0 if empty.
 * Must be called from the JS thread only. */
int _napi_tsfn_pop(int64_t tsfn_ptr, int64_t *data_out) {
    jac_tsfn_t *t = (jac_tsfn_t *)(uintptr_t)tsfn_ptr;
    if (!t) return 0;
    pthread_mutex_lock(&t->lock);
    int empty = (t->q_head == t->q_tail);
    if (!empty) {
        *data_out = (int64_t)(uintptr_t)t->queue[t->q_head];
        t->q_head = (t->q_head + 1) % JAC_TSFN_QUEUE_CAP;
    }
    pthread_mutex_unlock(&t->lock);
    return !empty;
}

/* Invoke call_js_cb on the JS thread.  Jac calls this instead of calling the
 * function pointer directly (Jac cannot call C function pointers with 4 args). */
void _napi_invoke_tsfn_cb(int64_t cb_ptr, int64_t env_ptr,
                           int64_t js_func, int64_t context, int64_t data) {
    napi_threadsafe_function_call_js cb =
        (napi_threadsafe_function_call_js)(uintptr_t)cb_ptr;
    if (cb) {
        cb((napi_env)(uintptr_t)env_ptr,
           (napi_value)(uintptr_t)js_func,
           (void *)(uintptr_t)context,
           (void *)(uintptr_t)data);
    }
}

/* Finalize a tsfn (JS thread, after thread_count reaches 0). */
static void _tsfn_finalize(jac_tsfn_t *t) {
    if (t->thread_finalize_cb) {
        t->thread_finalize_cb(t->env, t->thread_finalize_data, t->context);
    }
    pthread_mutex_destroy(&t->lock);
    free(t);
}

/* Remove tsfn from the JS-thread registry and finalize it. */
void _napi_tsfn_destroy(int64_t tsfn_ptr) {
    jac_tsfn_t *t = (jac_tsfn_t *)(uintptr_t)tsfn_ptr;
    for (int i = 0; i < _tsfn_count; i++) {
        if (_tsfn_registry[i] == t) {
            _tsfn_registry[i] = _tsfn_registry[--_tsfn_count];
            break;
        }
    }
    _tsfn_finalize(t);
}

/* How many entries are in the drain registry. */
int _napi_tsfn_registry_count(void) { return _tsfn_count; }

/* Number of TSFNs that must keep the event loop alive: live (thread_count>0,
 * not closing) AND reffed (ref>0).  Node semantics: napi_unref_threadsafe_
 * function marks a TSFN as not-loop-holding — napi-rs registers a background
 * "CustomGC" TSFN at module load and immediately unrefs it, so ignoring unref
 * held the loop open forever (the rollup/vite no-natural-exit tail). */
int64_t _napi_tsfn_hold_count(void) {
    int64_t n = 0;
    for (int i = 0; i < _tsfn_count; i++) {
        jac_tsfn_t *t = _tsfn_registry[i];
        if (t && !t->closing && t->thread_count > 0 && t->ref > 0) n++;
    }
    return n;
}

/* Return the i-th tsfn pointer in the registry. */
int64_t _napi_tsfn_registry_get(int idx) {
    if (idx < 0 || idx >= _tsfn_count) return 0;
    return (int64_t)(uintptr_t)_tsfn_registry[idx];
}

/* Scratch globals for Jac to read argv slots without Unknown-return issues. */
static int64_t _tsfn_scratch0 = 0;
static int64_t _tsfn_scratch1 = 0;

/* Read argv[0] and argv[1] into scratch globals (called from Jac). */
void _napi_tsfn_read_argv2(int64_t *argv) {
    _tsfn_scratch0 = argv ? argv[0] : 0;
    _tsfn_scratch1 = argv ? argv[1] : 0;
}
int64_t _napi_tsfn_scratch0(void) { return _tsfn_scratch0; }
int64_t _napi_tsfn_scratch1(void) { return _tsfn_scratch1; }

/* Result slot: _dispatch_tsfn writes here; caller reads via _napi_tsfn_result(). */
static int64_t _tsfn_result = 0;
void  _napi_tsfn_set_result(int64_t v) { _tsfn_result = v; }
int64_t _napi_tsfn_result(void)        { return _tsfn_result; }

/* Jac-side VM call-function hook.
 * Signature: int64_t fn(int64_t vm_ptr, int64_t fn_val, int64_t this_val,
 *                       int64_t argc, int64_t *argv)
 * Returns the resulting JSValue as int64_t.
 * Registered by event_loop.na.jac via _napi_set_vm_call_fn. */
typedef int64_t (*_vm_call_fn_t)(int64_t, int64_t, int64_t, int64_t, int64_t*);
static _vm_call_fn_t _vm_call_fn = NULL;
void    _napi_set_vm_call_fn(int64_t fn_ptr) { _vm_call_fn = (_vm_call_fn_t)(uintptr_t)fn_ptr; }
/* Scratch buffer for passing JSValue arrays to _vm_call_fn from Jac.
 * Filled via _napi_vm_call_write_arg; max 32 args. */
#define VM_CALL_MAX_ARGS 32
static int64_t _vm_call_argv[VM_CALL_MAX_ARGS];
void _napi_vm_call_write_arg(int64_t idx, int64_t jsval) {
    if (idx >= 0 && idx < VM_CALL_MAX_ARGS) _vm_call_argv[(size_t)idx] = jsval;
}

int64_t _napi_vm_call_fn(int64_t vm_ptr, int64_t fn_val, int64_t this_val, int64_t argc) {
    if (!_vm_call_fn) return 0;
    return _vm_call_fn(vm_ptr, fn_val, this_val, argc, _vm_call_argv);
}

/* Invoke a napi_finalize callback: void (*)(napi_env, void* data, void* hint).
 * Used by the Jac side (napi_binary.na.jac) to fire external-buffer
 * finalizers from the GC sweep and the process-exit flush. */
typedef void (*_napi_finalize_t)(int64_t, int64_t, int64_t);
void _napi_call_finalize(int64_t cb, int64_t env, int64_t data, int64_t hint) {
    if (cb) ((_napi_finalize_t)(uintptr_t)cb)(env, data, hint);
}

/* Invoke async-work callbacks (napi_async.na.jac).
 * execute:  void (*)(napi_env, void* data)               — env-free CPU work
 * complete: void (*)(napi_env, napi_status, void* data)  — runs on JS thread */
typedef void (*_napi_async_execute_t)(int64_t, int64_t);
typedef void (*_napi_async_complete_t)(int64_t, int64_t, int64_t);
void _napi_call_async_execute(int64_t cb, int64_t env, int64_t data) {
    if (cb) ((_napi_async_execute_t)(uintptr_t)cb)(env, data);
}
void _napi_call_async_complete(int64_t cb, int64_t env, int64_t status, int64_t data) {
    if (cb) ((_napi_async_complete_t)(uintptr_t)cb)(env, (int64_t)(int)status, data);
}

/* Signal a uv_async handle (thread-safe loop wakeup). */
void _napi_uv_async_send(int64_t handle_ptr) {
    if (handle_ptr) uv_async_send((uv_async_t *)(uintptr_t)handle_ptr);
}

/* libuv wrappers callable from Jac without importing libuv directly.
 * These avoid the mixed-FFI type-poisoning issue in the Jac type checker. */
void _napi_uv_ref(int64_t handle_ptr) {
    if (handle_ptr) uv_ref((uv_handle_t *)(uintptr_t)handle_ptr);
}
void _napi_uv_unref(int64_t handle_ptr) {
    if (handle_ptr) uv_unref((uv_handle_t *)(uintptr_t)handle_ptr);
}
/* Close a uv_async_t drain handle cleanly.  Called from Jac when the last
 * TSFN is released so libuv does not warn about unclosed handles at exit. */
void _napi_uv_async_close(int64_t handle_ptr) {
    uv_async_t *h = (uv_async_t *)(uintptr_t)handle_ptr;
    if (h && !uv_is_closing((uv_handle_t *)h)) {
        uv_close((uv_handle_t *)h, NULL);
    }
}
int64_t _napi_uv_async_create(int64_t loop_ptr, int64_t cb_ptr) {
    if (!loop_ptr) return 0;
    int sz = uv_handle_size(UV_ASYNC);
    void *buf = calloc(1, sz);
    uv_async_init((uv_loop_t *)(uintptr_t)loop_ptr,
                  (uv_async_t *)buf,
                  (uv_async_cb)(uintptr_t)cb_ptr);
    return (int64_t)(uintptr_t)buf;
}
/* Store the uv_loop_t* here when event_loop.na.jac calls tsfn_init. */
static int64_t _tsfn_loop_ptr = 0;
void _napi_tsfn_store_loop(int64_t loop_ptr) { _tsfn_loop_ptr = loop_ptr; }
int64_t _napi_tsfn_get_loop(void) { return _tsfn_loop_ptr; }

/* Return 1 if the tsfn queue has pending items. */
int _napi_tsfn_has_pending(int64_t tsfn_ptr) {
    jac_tsfn_t *t = (jac_tsfn_t *)(uintptr_t)tsfn_ptr;
    if (!t) return 0;
    pthread_mutex_lock(&t->lock);
    int has = (t->q_head != t->q_tail);
    pthread_mutex_unlock(&t->lock);
    return has;
}

/* Pop one item and return the data pointer value.  Returns 0 if queue empty.
 * Jac cannot pass an int* out-parameter, so this returns the value directly. */
int64_t _napi_tsfn_pop_slot(int64_t tsfn_ptr) {
    jac_tsfn_t *t = (jac_tsfn_t *)(uintptr_t)tsfn_ptr;
    if (!t) return 0;
    pthread_mutex_lock(&t->lock);
    if (t->q_head == t->q_tail) {
        pthread_mutex_unlock(&t->lock);
        return 0;
    }
    int64_t val = (int64_t)(uintptr_t)t->queue[t->q_head];
    t->q_head = (t->q_head + 1) % JAC_TSFN_QUEUE_CAP;
    pthread_mutex_unlock(&t->lock);
    return val;
}

static int _dispatch(int op, int64_t *argv, int argc) {
    /* Force a heap consistency check before each op (needs MALLOC_CHECK_=3). */
    static int _heap_check = -1;
    if (_heap_check < 0) _heap_check = getenv("HEAP_CHECK") ? 1 : 0;
    if (_heap_check) {
        void *_hc = malloc(1);
        if (_hc) free(_hc);
    }
    if (_jac_dispatch) return _jac_dispatch(op, argv, argc);
    return napi_generic_failure;
}

/* ── Op IDs (must match napi_dispatch.na.jac) ─────────────────────────────── */
/* Phase 0: ops are sent but dispatcher is NULL → generic_failure for all.    */
/* Phase N1: dispatcher is installed and handles the implemented ops.         */
enum NapiOp {
    NAPI_OP_OPEN_HANDLE_SCOPE              =  1,
    NAPI_OP_CLOSE_HANDLE_SCOPE             =  2,
    NAPI_OP_OPEN_ESCAPABLE_HANDLE_SCOPE    =  3,
    NAPI_OP_CLOSE_ESCAPABLE_HANDLE_SCOPE   =  4,
    NAPI_OP_ESCAPE_HANDLE                  =  5,
    NAPI_OP_TYPEOF                         =  6,
    NAPI_OP_IS_ARRAY                       =  7,
    NAPI_OP_IS_ARRAYBUFFER                 =  8,
    NAPI_OP_IS_BUFFER                      =  9,
    NAPI_OP_IS_DATE                        = 10,
    NAPI_OP_IS_ERROR                       = 11,
    NAPI_OP_IS_PROMISE                     = 12,
    NAPI_OP_IS_TYPEDARRAY                  = 13,
    NAPI_OP_IS_DATAVIEW                    = 14,
    NAPI_OP_IS_DETACHED_ARRAYBUFFER        = 15,
    NAPI_OP_STRICT_EQUALS                  = 16,
    NAPI_OP_CREATE_INT32                   = 17,
    NAPI_OP_CREATE_UINT32                  = 18,
    NAPI_OP_CREATE_INT64                   = 19,
    NAPI_OP_CREATE_DOUBLE                  = 20,
    NAPI_OP_GET_BOOLEAN                    = 21,
    NAPI_OP_GET_GLOBAL                     = 22,
    NAPI_OP_GET_NULL                       = 23,
    NAPI_OP_GET_UNDEFINED                  = 24,
    NAPI_OP_GET_VALUE_INT32                = 25,
    NAPI_OP_GET_VALUE_UINT32               = 26,
    NAPI_OP_GET_VALUE_INT64                = 27,
    NAPI_OP_GET_VALUE_DOUBLE               = 28,
    NAPI_OP_GET_VALUE_BOOL                 = 29,
    NAPI_OP_GET_LAST_ERROR_INFO            = 30,
    NAPI_OP_GET_NODE_VERSION               = 31,
    NAPI_OP_GET_UV_EVENT_LOOP             = 32,
    NAPI_OP_GET_VERSION                    = 33,
    NAPI_OP_CREATE_STRING_UTF8             = 34,
    NAPI_OP_CREATE_STRING_UTF16            = 35,
    NAPI_OP_CREATE_STRING_LATIN1           = 36,
    NAPI_OP_GET_VALUE_STRING_UTF8          = 37,
    NAPI_OP_GET_VALUE_STRING_UTF16         = 38,
    NAPI_OP_GET_VALUE_STRING_LATIN1        = 39,
    NAPI_OP_CREATE_SYMBOL                  = 40,
    NAPI_OP_NODE_API_SYMBOL_FOR            = 41,
    NAPI_OP_CREATE_OBJECT                  = 42,
    NAPI_OP_CREATE_ARRAY                   = 43,
    NAPI_OP_CREATE_ARRAY_WITH_LENGTH       = 44,
    NAPI_OP_CREATE_DATE                    = 45,
    NAPI_OP_GET_DATE_VALUE                 = 46,
    NAPI_OP_GET_PROPERTY                   = 47,
    NAPI_OP_SET_PROPERTY                   = 48,
    NAPI_OP_HAS_PROPERTY                   = 49,
    NAPI_OP_DELETE_PROPERTY                = 50,
    NAPI_OP_GET_NAMED_PROPERTY             = 51,
    NAPI_OP_SET_NAMED_PROPERTY             = 52,
    NAPI_OP_HAS_NAMED_PROPERTY             = 53,
    NAPI_OP_HAS_OWN_PROPERTY               = 54,
    NAPI_OP_GET_ELEMENT                    = 55,
    NAPI_OP_SET_ELEMENT                    = 56,
    NAPI_OP_HAS_ELEMENT                    = 57,
    NAPI_OP_DELETE_ELEMENT                 = 58,
    NAPI_OP_GET_ARRAY_LENGTH               = 59,
    NAPI_OP_GET_PROPERTY_NAMES             = 60,
    NAPI_OP_GET_ALL_PROPERTY_NAMES         = 61,
    NAPI_OP_DEFINE_PROPERTIES              = 62,
    NAPI_OP_GET_PROTOTYPE                  = 63,
    NAPI_OP_OBJECT_FREEZE                  = 64,
    NAPI_OP_OBJECT_SEAL                    = 65,
    NAPI_OP_COERCE_TO_BOOL                 = 66,
    NAPI_OP_COERCE_TO_NUMBER               = 67,
    NAPI_OP_COERCE_TO_OBJECT               = 68,
    NAPI_OP_COERCE_TO_STRING               = 69,
    NAPI_OP_CREATE_FUNCTION                = 70,
    NAPI_OP_CALL_FUNCTION                  = 71,
    NAPI_OP_NEW_INSTANCE                   = 72,
    NAPI_OP_GET_CB_INFO                    = 73,
    NAPI_OP_GET_NEW_TARGET                 = 74,
    NAPI_OP_DEFINE_CLASS                   = 75,
    NAPI_OP_WRAP                           = 76,
    NAPI_OP_UNWRAP                         = 77,
    NAPI_OP_REMOVE_WRAP                    = 78,
    NAPI_OP_ADD_FINALIZER                  = 79,
    NAPI_OP_INSTANCEOF                     = 80,
    NAPI_OP_CREATE_EXTERNAL                = 81,
    NAPI_OP_GET_VALUE_EXTERNAL             = 82,
    NAPI_OP_CREATE_PROMISE                 = 83,
    NAPI_OP_RESOLVE_DEFERRED               = 84,
    NAPI_OP_REJECT_DEFERRED                = 85,
    NAPI_OP_CREATE_ARRAYBUFFER             = 86,
    NAPI_OP_GET_ARRAYBUFFER_INFO           = 87,
    NAPI_OP_DETACH_ARRAYBUFFER             = 88,
    NAPI_OP_CREATE_EXTERNAL_ARRAYBUFFER    = 89,
    NAPI_OP_CREATE_TYPEDARRAY              = 90,
    NAPI_OP_GET_TYPEDARRAY_INFO            = 91,
    NAPI_OP_CREATE_DATAVIEW                = 92,
    NAPI_OP_GET_DATAVIEW_INFO              = 93,
    NAPI_OP_CREATE_BUFFER                  = 94,
    NAPI_OP_CREATE_BUFFER_COPY             = 95,
    NAPI_OP_CREATE_EXTERNAL_BUFFER         = 96,
    NAPI_OP_GET_BUFFER_INFO                = 97,
    NAPI_OP_CREATE_ERROR                   = 98,
    NAPI_OP_CREATE_TYPE_ERROR              = 99,
    NAPI_OP_CREATE_RANGE_ERROR             = 100,
    NAPI_OP_CREATE_SYNTAX_ERROR            = 101,
    NAPI_OP_THROW                          = 102,
    NAPI_OP_THROW_ERROR                    = 103,
    NAPI_OP_THROW_TYPE_ERROR               = 104,
    NAPI_OP_THROW_RANGE_ERROR              = 105,
    NAPI_OP_THROW_SYNTAX_ERROR             = 106,
    NAPI_OP_IS_EXCEPTION_PENDING           = 107,
    NAPI_OP_GET_AND_CLEAR_LAST_EXCEPTION   = 108,
    NAPI_OP_FATAL_EXCEPTION                = 109,
    NAPI_OP_CREATE_REFERENCE               = 110,
    NAPI_OP_DELETE_REFERENCE               = 111,
    NAPI_OP_REFERENCE_REF                  = 112,
    NAPI_OP_REFERENCE_UNREF                = 113,
    NAPI_OP_GET_REFERENCE_VALUE            = 114,
    NAPI_OP_CREATE_BIGINT_INT64            = 115,
    NAPI_OP_CREATE_BIGINT_UINT64           = 116,
    NAPI_OP_CREATE_BIGINT_WORDS            = 117,
    NAPI_OP_GET_VALUE_BIGINT_INT64         = 118,
    NAPI_OP_GET_VALUE_BIGINT_UINT64        = 119,
    NAPI_OP_GET_VALUE_BIGINT_WORDS         = 120,
    NAPI_OP_TYPE_TAG_OBJECT                = 121,
    NAPI_OP_CHECK_OBJECT_TYPE_TAG          = 122,
    NAPI_OP_ADD_ENV_CLEANUP_HOOK           = 123,
    NAPI_OP_REMOVE_ENV_CLEANUP_HOOK        = 124,
    NAPI_OP_CREATE_ASYNC_WORK              = 125,
    NAPI_OP_DELETE_ASYNC_WORK              = 126,
    NAPI_OP_QUEUE_ASYNC_WORK               = 127,
    NAPI_OP_CANCEL_ASYNC_WORK              = 128,
    NAPI_OP_ASYNC_INIT                     = 129,
    NAPI_OP_ASYNC_DESTROY                  = 130,
    NAPI_OP_MAKE_CALLBACK                  = 131,
    NAPI_OP_OPEN_CALLBACK_SCOPE            = 132,
    NAPI_OP_CLOSE_CALLBACK_SCOPE           = 133,
    NAPI_OP_CREATE_THREADSAFE_FUNCTION     = 134,
    NAPI_OP_GET_THREADSAFE_FUNCTION_CONTEXT= 135,
    NAPI_OP_CALL_THREADSAFE_FUNCTION       = 136,
    NAPI_OP_ACQUIRE_THREADSAFE_FUNCTION    = 137,
    NAPI_OP_RELEASE_THREADSAFE_FUNCTION    = 138,
    NAPI_OP_REF_THREADSAFE_FUNCTION        = 139,
    NAPI_OP_UNREF_THREADSAFE_FUNCTION      = 140,
    NAPI_OP_RUN_SCRIPT                     = 141,
    NAPI_OP_ADJUST_EXTERNAL_MEMORY         = 142,
    NAPI_OP_SET_INSTANCE_DATA              = 143,
    NAPI_OP_GET_INSTANCE_DATA              = 144,
    NAPI_OP_ADD_ASYNC_CLEANUP_HOOK         = 145,
    NAPI_OP_REMOVE_ASYNC_CLEANUP_HOOK      = 146,
    NAPI_OP_GET_MODULE_FILE_NAME           = 147,
    /* Internal: Jac-side drain step — not a real NAPI op; fired by C drain cb */
    NAPI_OP_TSFN_DRAIN_ONE                 = 148,
};

/* ── Module registration ──────────────────────────────────────────────────── */
/* Called from the addon's __attribute__((constructor)) via NAPI_MODULE(...). */

static napi_addon_register_func _pending_init = NULL;
static napi_module *_pending_module            = NULL;

void napi_module_register(napi_module *mod) {
    if (!mod) return;
    _pending_module = mod;
    _pending_init   = mod->nm_register_func;
}

/* Return the pending Init function pointer (and clear it).
 * Called from napi_loader.na.jac immediately after dlopen. */
int64_t _napi_get_pending_init(void) {
    int64_t fn = (int64_t)(uintptr_t)_pending_init;
    _pending_init  = NULL;
    _pending_module = NULL;
    return fn;
}

/* Call an addon's Init(env, exports) through its C function pointer.
 * init_fn, env, exports are all int64_t (pointer-width values on x86-64).
 * Returns the napi_value returned by Init (which is exports for simple addons). */
int64_t _napi_invoke_register(int64_t init_fn, int64_t env, int64_t exports) {
    if (!init_fn) return exports;  /* no-op if no init fn */
    napi_addon_register_func fn = (napi_addon_register_func)(uintptr_t)init_fn;
    napi_value result = fn((napi_env)(uintptr_t)env,
                           (napi_value)(uintptr_t)exports);
    return (int64_t)(uintptr_t)result;
}

/* ── Handle-slot helpers (Phase N1: identity model) ──────────────────────── */
/* napi_value == JSValue in N1. Real slot indirection deferred to N4.         */

int64_t _napi_slot_read(int64_t slot_ptr) {
    /* N1: napi_value IS the JSValue — identity */
    return slot_ptr;
}

void _napi_slot_write(int64_t slot_ptr, int64_t jsval) {
    /* N1: no-op — slot is the JSValue, no indirection */
    (void)slot_ptr; (void)jsval;
}

/* ── Argument helpers (Phase N1) ───────────────────────────────────────────── */
/* _napi_argv_i64: read one int64 slot from the argv array (called by Jac).  */
int64_t _napi_argv_i64(int64_t *argv, int idx) { return argv[idx]; }

/* Out-param write helpers: Jac passes raw C out-pointers as int64_t values.  */
/* Doing the dereference in C avoids Jac LLVM IR issues with raw ptr stores.  */
void _napi_write_i64 (int64_t  *p, int64_t  v) { if (p) *p = v; }
void _napi_write_i32 (int32_t  *p, int32_t  v) { if (p) *p = v; }
void _napi_write_u32 (uint32_t *p, uint32_t v) { if (p) *p = v; }
void _napi_write_bool(bool     *p, bool     v) { if (p) *p = v; }
void _napi_write_f64 (double   *p, double   v) { if (p) *p = v; }

/* ── N4 C callback trampoline (Phase N4) ─────────────────────────────────── */
/* Called by Jac (napi_func.na.jac) to invoke a C napi_callback by function  */
/* pointer.  Returns the napi_value result cast to int64_t.                   */
int64_t _napi_call_c_callback(int64_t fn_ptr, int64_t env_int,
                               int64_t cbinfo_int) {
    napi_callback cb      = (napi_callback)(uintptr_t)fn_ptr;
    napi_env      env     = (napi_env)(uintptr_t)env_int;
    napi_callback_info ci = (napi_callback_info)(uintptr_t)cbinfo_int;
    napi_value ret = cb(env, ci);
    return (int64_t)(uintptr_t)ret;
}

/* ── Static error info (returned by napi_get_last_error_info) ────────────── */

static napi_extended_error_info _last_error = {
    .error_message      = "napi_generic_failure",
    .engine_reserved    = NULL,
    .engine_error_code  = 0,
    .error_code         = napi_generic_failure,
};

/* ── Static Node version info ────────────────────────────────────────────── */

static const napi_node_version _node_ver = {
    .major   = 22,
    .minor   = 0,
    .patch   = 0,
    .release = "node",
};

/* ══════════════════════════════════════════════════════════════════════════ */
/* NAPI stub implementations                                                  */
/*                                                                            */
/* Phase 0: every function calls _dispatch(OP, NULL, 0).                     */
/* Since _jac_dispatch is NULL at startup, _dispatch returns                  */
/* napi_generic_failure for all ops.  The dispatcher is installed on the      */
/* first .node load via _napi_set_dispatch(_napi_dispatch).                   */
/*                                                                            */
/* A few functions that are trivially safe to handle in the shim always work: */
/*   napi_get_last_error_info — returns the static struct above               */
/*   napi_get_node_version    — returns _node_ver                             */
/*   napi_get_version         — returns NAPI_VERSION                          */
/*   napi_adjust_external_memory — no-op, returns napi_ok                     */
/*   napi_fatal_error         — prints and aborts                             */
/* ══════════════════════════════════════════════════════════════════════════ */

/* ── Error/info ────────────────────────────────────────────────────────────── */

napi_status napi_get_last_error_info(napi_env env,
                                      const napi_extended_error_info **info) {
    if (info) *info = &_last_error;
    return napi_ok;
}

napi_status napi_get_node_version(napi_env env,
                                   const napi_node_version **version) {
    if (version) *version = &_node_ver;
    return napi_ok;
}

napi_status napi_get_version(napi_env env, uint32_t *version) {
    if (version) *version = NAPI_VERSION;
    return napi_ok;
}

napi_status napi_adjust_external_memory(napi_env env,
                                         int64_t change_in_bytes,
                                         int64_t *adjusted_value) {
    /* No-op for Phase 0 — safe to report napi_ok */
    if (adjusted_value) *adjusted_value = 0;
    return napi_ok;
}

void napi_fatal_error(const char *location, size_t location_len,
                      const char *message,  size_t message_len) {
    (void)location_len; (void)message_len;
    fprintf(stderr, "FATAL ERROR in NAPI: %s %s\n",
            location ? location : "(unknown)",
            message  ? message  : "");
    fflush(stderr);
    abort();
}

/* ── Handle scopes ─────────────────────────────────────────────────────────── */

napi_status napi_open_handle_scope(napi_env env, napi_handle_scope *scope) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)scope };
    return (napi_status)_dispatch(NAPI_OP_OPEN_HANDLE_SCOPE, argv, 2);
}
napi_status napi_close_handle_scope(napi_env env, napi_handle_scope scope) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)scope };
    return (napi_status)_dispatch(NAPI_OP_CLOSE_HANDLE_SCOPE, argv, 2);
}
napi_status napi_open_escapable_handle_scope(napi_env env,
                                              napi_escapable_handle_scope *scope) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)scope };
    return (napi_status)_dispatch(NAPI_OP_OPEN_ESCAPABLE_HANDLE_SCOPE, argv, 2);
}
napi_status napi_close_escapable_handle_scope(napi_env env,
                                               napi_escapable_handle_scope scope) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)scope };
    return (napi_status)_dispatch(NAPI_OP_CLOSE_ESCAPABLE_HANDLE_SCOPE, argv, 2);
}
napi_status napi_escape_handle(napi_env env, napi_escapable_handle_scope scope,
                                napi_value escapee, napi_value *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)scope,
                        (int64_t)(uintptr_t)escapee, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_ESCAPE_HANDLE, argv, 4);
}

/* ── Type queries ──────────────────────────────────────────────────────────── */

napi_status napi_typeof(napi_env env, napi_value value, napi_valuetype *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_TYPEOF, argv, 3);
}
napi_status napi_is_array(napi_env env, napi_value value, bool *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_IS_ARRAY, argv, 3);
}
napi_status napi_is_arraybuffer(napi_env env, napi_value value, bool *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_IS_ARRAYBUFFER, argv, 3);
}
napi_status napi_is_buffer(napi_env env, napi_value value, bool *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_IS_BUFFER, argv, 3);
}
napi_status napi_is_date(napi_env env, napi_value value, bool *is_date) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)is_date };
    return (napi_status)_dispatch(NAPI_OP_IS_DATE, argv, 3);
}
napi_status napi_is_error(napi_env env, napi_value value, bool *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_IS_ERROR, argv, 3);
}
napi_status napi_is_promise(napi_env env, napi_value value, bool *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_IS_PROMISE, argv, 3);
}
napi_status napi_is_typedarray(napi_env env, napi_value value, bool *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_IS_TYPEDARRAY, argv, 3);
}
napi_status napi_is_dataview(napi_env env, napi_value value, bool *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_IS_DATAVIEW, argv, 3);
}
napi_status napi_is_exception_pending(napi_env env, bool *result) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_IS_EXCEPTION_PENDING, argv, 2);
}
napi_status napi_strict_equals(napi_env env, napi_value lhs, napi_value rhs,
                                bool *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)lhs,
                        (int64_t)(uintptr_t)rhs,  (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_STRICT_EQUALS, argv, 4);
}
napi_status napi_instanceof(napi_env env, napi_value object,
                             napi_value constructor, bool *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)object,
                        (int64_t)(uintptr_t)constructor, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_INSTANCEOF, argv, 4);
}

/* ── Create primitives ─────────────────────────────────────────────────────── */

napi_status napi_create_int32(napi_env env, int32_t value, napi_value *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_INT32, argv, 3);
}
napi_status napi_create_uint32(napi_env env, uint32_t value, napi_value *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uint64_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_UINT32, argv, 3);
}
napi_status napi_create_int64(napi_env env, int64_t value, napi_value *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_INT64, argv, 3);
}
napi_status napi_create_double(napi_env env, double value, napi_value *result) {
    union { double d; int64_t i; } u; u.d = value;
    int64_t argv[3] = { (int64_t)(uintptr_t)env, u.i,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_DOUBLE, argv, 3);
}
napi_status napi_get_boolean(napi_env env, bool value, napi_value *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_BOOLEAN, argv, 3);
}
napi_status napi_get_global(napi_env env, napi_value *result) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_GLOBAL, argv, 2);
}
napi_status napi_get_null(napi_env env, napi_value *result) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_NULL, argv, 2);
}
napi_status napi_get_undefined(napi_env env, napi_value *result) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_UNDEFINED, argv, 2);
}

/* ── Get primitive values ──────────────────────────────────────────────────── */

napi_status napi_get_value_int32(napi_env env, napi_value value, int32_t *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_VALUE_INT32, argv, 3);
}
napi_status napi_get_value_uint32(napi_env env, napi_value value, uint32_t *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_VALUE_UINT32, argv, 3);
}
napi_status napi_get_value_int64(napi_env env, napi_value value, int64_t *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_VALUE_INT64, argv, 3);
}
napi_status napi_get_value_double(napi_env env, napi_value value, double *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_VALUE_DOUBLE, argv, 3);
}
napi_status napi_get_value_bool(napi_env env, napi_value value, bool *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_VALUE_BOOL, argv, 3);
}
napi_status napi_get_value_external(napi_env env, napi_value value, void **result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_VALUE_EXTERNAL, argv, 3);
}

/* ── Strings ───────────────────────────────────────────────────────────────── */

napi_status napi_create_string_utf8(napi_env env, const char *str,
                                     size_t length, napi_value *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)str,
                        (int64_t)length,          (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_STRING_UTF8, argv, 4);
}
napi_status napi_create_string_utf16(napi_env env, const char16_t *str,
                                      size_t length, napi_value *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)str,
                        (int64_t)length,          (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_STRING_UTF16, argv, 4);
}
napi_status napi_create_string_latin1(napi_env env, const char *str,
                                       size_t length, napi_value *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)str,
                        (int64_t)length,          (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_STRING_LATIN1, argv, 4);
}
napi_status napi_get_value_string_utf8(napi_env env, napi_value value,
                                        char *buf, size_t bufsize,
                                        size_t *result) {
    int64_t argv[5] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)buf,  (int64_t)bufsize,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_VALUE_STRING_UTF8, argv, 5);
}
napi_status napi_get_value_string_utf16(napi_env env, napi_value value,
                                         char16_t *buf, size_t bufsize,
                                         size_t *result) {
    int64_t argv[5] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)buf,  (int64_t)bufsize,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_VALUE_STRING_UTF16, argv, 5);
}
napi_status napi_get_value_string_latin1(napi_env env, napi_value value,
                                          char *buf, size_t bufsize,
                                          size_t *result) {
    int64_t argv[5] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)buf,  (int64_t)bufsize,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_VALUE_STRING_LATIN1, argv, 5);
}

/* ── Symbol ────────────────────────────────────────────────────────────────── */

napi_status napi_create_symbol(napi_env env, napi_value description,
                                napi_value *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)description,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_SYMBOL, argv, 3);
}
napi_status node_api_symbol_for(napi_env env, const char *utf8description,
                                 size_t length, napi_value *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)utf8description,
                        (int64_t)length,          (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_NODE_API_SYMBOL_FOR, argv, 4);
}


/* ── Object / array ────────────────────────────────────────────────────────── */

napi_status napi_create_object(napi_env env, napi_value *result) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_OBJECT, argv, 2);
}
napi_status napi_create_array(napi_env env, napi_value *result) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_ARRAY, argv, 2);
}
napi_status napi_create_array_with_length(napi_env env, size_t length,
                                           napi_value *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)length,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_ARRAY_WITH_LENGTH, argv, 3);
}
napi_status napi_get_array_length(napi_env env, napi_value value,
                                   uint32_t *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_ARRAY_LENGTH, argv, 3);
}
napi_status napi_get_property(napi_env env, napi_value object,
                               napi_value key, napi_value *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)object,
                        (int64_t)(uintptr_t)key,  (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_PROPERTY, argv, 4);
}
napi_status napi_set_property(napi_env env, napi_value object,
                               napi_value key, napi_value value) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env,   (int64_t)(uintptr_t)object,
                        (int64_t)(uintptr_t)key,    (int64_t)(uintptr_t)value };
    return (napi_status)_dispatch(NAPI_OP_SET_PROPERTY, argv, 4);
}
napi_status napi_has_property(napi_env env, napi_value object,
                               napi_value key, bool *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env,   (int64_t)(uintptr_t)object,
                        (int64_t)(uintptr_t)key,    (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_HAS_PROPERTY, argv, 4);
}
napi_status napi_delete_property(napi_env env, napi_value object,
                                  napi_value key, bool *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env,   (int64_t)(uintptr_t)object,
                        (int64_t)(uintptr_t)key,    (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_DELETE_PROPERTY, argv, 4);
}
napi_status napi_has_own_property(napi_env env, napi_value object,
                                   napi_value key, bool *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env,   (int64_t)(uintptr_t)object,
                        (int64_t)(uintptr_t)key,    (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_HAS_OWN_PROPERTY, argv, 4);
}
napi_status napi_get_named_property(napi_env env, napi_value object,
                                     const char *utf8name, napi_value *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env,      (int64_t)(uintptr_t)object,
                        (int64_t)(uintptr_t)utf8name,  (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_NAMED_PROPERTY, argv, 4);
}
napi_status napi_set_named_property(napi_env env, napi_value object,
                                     const char *utf8name, napi_value value) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env,      (int64_t)(uintptr_t)object,
                        (int64_t)(uintptr_t)utf8name,  (int64_t)(uintptr_t)value };
    return (napi_status)_dispatch(NAPI_OP_SET_NAMED_PROPERTY, argv, 4);
}
napi_status napi_has_named_property(napi_env env, napi_value object,
                                     const char *utf8name, bool *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env,      (int64_t)(uintptr_t)object,
                        (int64_t)(uintptr_t)utf8name,  (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_HAS_NAMED_PROPERTY, argv, 4);
}
napi_status napi_get_element(napi_env env, napi_value object,
                              uint32_t index, napi_value *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)object,
                        (int64_t)index,           (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_ELEMENT, argv, 4);
}
napi_status napi_set_element(napi_env env, napi_value object,
                              uint32_t index, napi_value value) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)object,
                        (int64_t)index,           (int64_t)(uintptr_t)value };
    return (napi_status)_dispatch(NAPI_OP_SET_ELEMENT, argv, 4);
}
napi_status napi_has_element(napi_env env, napi_value object,
                              uint32_t index, bool *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)object,
                        (int64_t)index,           (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_HAS_ELEMENT, argv, 4);
}
napi_status napi_delete_element(napi_env env, napi_value object,
                                 uint32_t index, bool *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)object,
                        (int64_t)index,           (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_DELETE_ELEMENT, argv, 4);
}
napi_status napi_get_property_names(napi_env env, napi_value object,
                                     napi_value *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)object,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_PROPERTY_NAMES, argv, 3);
}
napi_status napi_get_all_property_names(napi_env env, napi_value object,
                                         napi_key_collection_mode key_mode,
                                         napi_key_filter key_filter,
                                         napi_key_conversion key_conversion,
                                         napi_value *result) {
    int64_t argv[6] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)object,
                        (int64_t)key_mode,        (int64_t)key_filter,
                        (int64_t)key_conversion,  (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_ALL_PROPERTY_NAMES, argv, 6);
}
napi_status napi_define_properties(napi_env env, napi_value object,
                                    size_t property_count,
                                    const napi_property_descriptor *properties) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env,    (int64_t)(uintptr_t)object,
                        (int64_t)property_count,     (int64_t)(uintptr_t)properties };
    return (napi_status)_dispatch(NAPI_OP_DEFINE_PROPERTIES, argv, 4);
}
napi_status napi_get_prototype(napi_env env, napi_value object,
                                napi_value *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)object,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_PROTOTYPE, argv, 3);
}
napi_status napi_object_freeze(napi_env env, napi_value object) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)object };
    return (napi_status)_dispatch(NAPI_OP_OBJECT_FREEZE, argv, 2);
}
napi_status napi_object_seal(napi_env env, napi_value object) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)object };
    return (napi_status)_dispatch(NAPI_OP_OBJECT_SEAL, argv, 2);
}

/* ── Coercions ─────────────────────────────────────────────────────────────── */

napi_status napi_coerce_to_bool(napi_env env, napi_value value,
                                 napi_value *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_COERCE_TO_BOOL, argv, 3);
}
napi_status napi_coerce_to_number(napi_env env, napi_value value,
                                   napi_value *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_COERCE_TO_NUMBER, argv, 3);
}
napi_status napi_coerce_to_object(napi_env env, napi_value value,
                                   napi_value *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_COERCE_TO_OBJECT, argv, 3);
}
napi_status napi_coerce_to_string(napi_env env, napi_value value,
                                   napi_value *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_COERCE_TO_STRING, argv, 3);
}

/* ── Functions / classes / callbacks ────────────────────────────────────────── */

napi_status napi_create_function(napi_env env, const char *utf8name,
                                  size_t length, napi_callback cb,
                                  void *data, napi_value *result) {
    int64_t argv[6] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)utf8name,
                        (int64_t)length, (int64_t)(uintptr_t)cb,
                        (int64_t)(uintptr_t)data, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_FUNCTION, argv, 6);
}
napi_status napi_call_function(napi_env env, napi_value recv,
                                napi_value func, size_t argc,
                                const napi_value *argv, napi_value *result) {
    int64_t a[6] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)recv,
                     (int64_t)(uintptr_t)func, (int64_t)argc,
                     (int64_t)(uintptr_t)argv, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CALL_FUNCTION, a, 6);
}
napi_status napi_new_instance(napi_env env, napi_value constructor,
                               size_t argc, const napi_value *argv,
                               napi_value *result) {
    int64_t a[5] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)constructor,
                     (int64_t)argc, (int64_t)(uintptr_t)argv,
                     (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_NEW_INSTANCE, a, 5);
}
napi_status napi_get_cb_info(napi_env env, napi_callback_info cbinfo,
                              size_t *argc, napi_value *argv,
                              napi_value *this_arg, void **data) {
    int64_t a[6] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)cbinfo,
                     (int64_t)(uintptr_t)argc, (int64_t)(uintptr_t)argv,
                     (int64_t)(uintptr_t)this_arg, (int64_t)(uintptr_t)data };
    return (napi_status)_dispatch(NAPI_OP_GET_CB_INFO, a, 6);
}
napi_status napi_get_new_target(napi_env env, napi_callback_info cbinfo,
                                 napi_value *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)cbinfo,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_NEW_TARGET, argv, 3);
}
napi_status napi_define_class(napi_env env, const char *utf8name,
                               size_t length, napi_callback constructor,
                               void *data, size_t property_count,
                               const napi_property_descriptor *properties,
                               napi_value *result) {
    int64_t argv[8] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)utf8name,
                        (int64_t)length, (int64_t)(uintptr_t)constructor,
                        (int64_t)(uintptr_t)data, (int64_t)property_count,
                        (int64_t)(uintptr_t)properties, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_DEFINE_CLASS, argv, 8);
}

/* ── Wrap / external ───────────────────────────────────────────────────────── */

napi_status napi_wrap(napi_env env, napi_value js_object, void *native_object,
                      napi_finalize finalize_cb, void *finalize_hint,
                      napi_ref *result) {
    int64_t argv[6] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)js_object,
                        (int64_t)(uintptr_t)native_object, (int64_t)(uintptr_t)finalize_cb,
                        (int64_t)(uintptr_t)finalize_hint, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_WRAP, argv, 6);
}
napi_status napi_unwrap(napi_env env, napi_value js_object, void **result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)js_object,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_UNWRAP, argv, 3);
}
napi_status napi_remove_wrap(napi_env env, napi_value js_object, void **result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)js_object,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_REMOVE_WRAP, argv, 3);
}
napi_status napi_create_external(napi_env env, void *data,
                                  napi_finalize finalize_cb,
                                  void *finalize_hint, napi_value *result) {
    int64_t argv[5] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)data,
                        (int64_t)(uintptr_t)finalize_cb, (int64_t)(uintptr_t)finalize_hint,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_EXTERNAL, argv, 5);
}
napi_status napi_add_finalizer(napi_env env, napi_value js_object,
                                void *native_object, napi_finalize finalize_cb,
                                void *finalize_hint, napi_ref *result) {
    int64_t argv[6] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)js_object,
                        (int64_t)(uintptr_t)native_object, (int64_t)(uintptr_t)finalize_cb,
                        (int64_t)(uintptr_t)finalize_hint, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_ADD_FINALIZER, argv, 6);
}
/* ── Promises ──────────────────────────────────────────────────────────────── */

napi_status napi_create_promise(napi_env env, napi_deferred *deferred,
                                 napi_value *promise) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)deferred,
                        (int64_t)(uintptr_t)promise };
    return (napi_status)_dispatch(NAPI_OP_CREATE_PROMISE, argv, 3);
}
napi_status napi_resolve_deferred(napi_env env, napi_deferred deferred,
                                   napi_value resolution) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)deferred,
                        (int64_t)(uintptr_t)resolution };
    return (napi_status)_dispatch(NAPI_OP_RESOLVE_DEFERRED, argv, 3);
}
napi_status napi_reject_deferred(napi_env env, napi_deferred deferred,
                                  napi_value rejection) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)deferred,
                        (int64_t)(uintptr_t)rejection };
    return (napi_status)_dispatch(NAPI_OP_REJECT_DEFERRED, argv, 3);
}
/* ── Buffers ───────────────────────────────────────────────────────────────── */

napi_status napi_create_arraybuffer(napi_env env, size_t byte_length,
                                     void **data, napi_value *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)byte_length,
                        (int64_t)(uintptr_t)data, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_ARRAYBUFFER, argv, 4);
}
napi_status napi_get_arraybuffer_info(napi_env env, napi_value arraybuffer,
                                       void **data, size_t *byte_length) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)arraybuffer,
                        (int64_t)(uintptr_t)data, (int64_t)(uintptr_t)byte_length };
    return (napi_status)_dispatch(NAPI_OP_GET_ARRAYBUFFER_INFO, argv, 4);
}
napi_status napi_create_external_arraybuffer(napi_env env, void *external_data,
                                              size_t byte_length,
                                              napi_finalize finalize_cb,
                                              void *finalize_hint,
                                              napi_value *result) {
    int64_t argv[6] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)external_data,
                        (int64_t)byte_length, (int64_t)(uintptr_t)finalize_cb,
                        (int64_t)(uintptr_t)finalize_hint, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_EXTERNAL_ARRAYBUFFER, argv, 6);
}
napi_status napi_detach_arraybuffer(napi_env env, napi_value arraybuffer) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)arraybuffer };
    return (napi_status)_dispatch(NAPI_OP_DETACH_ARRAYBUFFER, argv, 2);
}
napi_status napi_is_detached_arraybuffer(napi_env env, napi_value arraybuffer,
                                          bool *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)arraybuffer,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_IS_DETACHED_ARRAYBUFFER, argv, 3);
}
napi_status napi_create_typedarray(napi_env env, napi_typedarray_type type,
                                    size_t length, napi_value arraybuffer,
                                    size_t byte_offset, napi_value *result) {
    int64_t argv[6] = { (int64_t)(uintptr_t)env, (int64_t)type,
                        (int64_t)length, (int64_t)(uintptr_t)arraybuffer,
                        (int64_t)byte_offset, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_TYPEDARRAY, argv, 6);
}
napi_status napi_get_typedarray_info(napi_env env, napi_value typedarray,
                                      napi_typedarray_type *type, size_t *length,
                                      void **data, napi_value *arraybuffer,
                                      size_t *byte_offset) {
    int64_t argv[7] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)typedarray,
                        (int64_t)(uintptr_t)type, (int64_t)(uintptr_t)length,
                        (int64_t)(uintptr_t)data, (int64_t)(uintptr_t)arraybuffer,
                        (int64_t)(uintptr_t)byte_offset };
    return (napi_status)_dispatch(NAPI_OP_GET_TYPEDARRAY_INFO, argv, 7);
}
napi_status napi_create_dataview(napi_env env, size_t length,
                                  napi_value arraybuffer, size_t byte_offset,
                                  napi_value *result) {
    int64_t argv[5] = { (int64_t)(uintptr_t)env, (int64_t)length,
                        (int64_t)(uintptr_t)arraybuffer, (int64_t)byte_offset,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_DATAVIEW, argv, 5);
}
napi_status napi_get_dataview_info(napi_env env, napi_value dataview,
                                    size_t *bytelength, void **data,
                                    napi_value *arraybuffer,
                                    size_t *byte_offset) {
    int64_t argv[6] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)dataview,
                        (int64_t)(uintptr_t)bytelength, (int64_t)(uintptr_t)data,
                        (int64_t)(uintptr_t)arraybuffer, (int64_t)(uintptr_t)byte_offset };
    return (napi_status)_dispatch(NAPI_OP_GET_DATAVIEW_INFO, argv, 6);
}
napi_status napi_create_buffer(napi_env env, size_t size, void **data,
                                napi_value *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)size,
                        (int64_t)(uintptr_t)data, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_BUFFER, argv, 4);
}
napi_status napi_create_buffer_copy(napi_env env, size_t length,
                                     const void *data, void **result_data,
                                     napi_value *result) {
    int64_t argv[5] = { (int64_t)(uintptr_t)env, (int64_t)length,
                        (int64_t)(uintptr_t)data, (int64_t)(uintptr_t)result_data,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_BUFFER_COPY, argv, 5);
}
napi_status napi_create_external_buffer(napi_env env, size_t length,
                                         void *data,
                                         napi_finalize finalize_cb,
                                         void *finalize_hint,
                                         napi_value *result) {
    int64_t argv[6] = { (int64_t)(uintptr_t)env, (int64_t)length,
                        (int64_t)(uintptr_t)data, (int64_t)(uintptr_t)finalize_cb,
                        (int64_t)(uintptr_t)finalize_hint, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_EXTERNAL_BUFFER, argv, 6);
}
napi_status napi_get_buffer_info(napi_env env, napi_value value,
                                  void **data, size_t *length) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)data, (int64_t)(uintptr_t)length };
    return (napi_status)_dispatch(NAPI_OP_GET_BUFFER_INFO, argv, 4);
}

/* ── Errors / throw ─────────────────────────────────────────────────────────── */

napi_status napi_create_error(napi_env env, napi_value code, napi_value msg,
                               napi_value *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)code,
                        (int64_t)(uintptr_t)msg,  (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_ERROR, argv, 4);
}
napi_status napi_create_type_error(napi_env env, napi_value code, napi_value msg,
                                    napi_value *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)code,
                        (int64_t)(uintptr_t)msg,  (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_TYPE_ERROR, argv, 4);
}
napi_status napi_create_range_error(napi_env env, napi_value code, napi_value msg,
                                     napi_value *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)code,
                        (int64_t)(uintptr_t)msg,  (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_RANGE_ERROR, argv, 4);
}
napi_status node_api_create_syntax_error(napi_env env, napi_value code,
                                          napi_value msg, napi_value *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)code,
                        (int64_t)(uintptr_t)msg,  (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_SYNTAX_ERROR, argv, 4);
}
napi_status napi_throw(napi_env env, napi_value error) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)error };
    return (napi_status)_dispatch(NAPI_OP_THROW, argv, 2);
}
napi_status napi_throw_error(napi_env env, const char *code,
                              const char *msg) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)code,
                        (int64_t)(uintptr_t)msg };
    return (napi_status)_dispatch(NAPI_OP_THROW_ERROR, argv, 3);
}
napi_status napi_throw_type_error(napi_env env, const char *code,
                                   const char *msg) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)code,
                        (int64_t)(uintptr_t)msg };
    return (napi_status)_dispatch(NAPI_OP_THROW_TYPE_ERROR, argv, 3);
}
napi_status napi_throw_range_error(napi_env env, const char *code,
                                    const char *msg) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)code,
                        (int64_t)(uintptr_t)msg };
    return (napi_status)_dispatch(NAPI_OP_THROW_RANGE_ERROR, argv, 3);
}
napi_status node_api_throw_syntax_error(napi_env env, const char *code,
                                         const char *msg) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)code,
                        (int64_t)(uintptr_t)msg };
    return (napi_status)_dispatch(NAPI_OP_THROW_SYNTAX_ERROR, argv, 3);
}
napi_status napi_get_and_clear_last_exception(napi_env env,
                                               napi_value *result) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_AND_CLEAR_LAST_EXCEPTION, argv, 2);
}
napi_status napi_fatal_exception(napi_env env, napi_value err) {
    /* May be called from a Tokio worker thread — do NOT call _dispatch (not
       thread-safe).  Print a C backtrace and abort. */
    void *bt[32];
    int n = backtrace(bt, 32);
    backtrace_symbols_fd(bt, n, STDERR_FILENO);
    abort();
    return napi_generic_failure;
}

/* ── References ─────────────────────────────────────────────────────────────── */

napi_status napi_create_reference(napi_env env, napi_value value,
                                   uint32_t initial_refcount,
                                   napi_ref *result) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)initial_refcount, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_REFERENCE, argv, 4);
}
napi_status napi_delete_reference(napi_env env, napi_ref ref) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)ref };
    return (napi_status)_dispatch(NAPI_OP_DELETE_REFERENCE, argv, 2);
}
napi_status napi_reference_ref(napi_env env, napi_ref ref, uint32_t *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)ref,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_REFERENCE_REF, argv, 3);
}
napi_status napi_reference_unref(napi_env env, napi_ref ref, uint32_t *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)ref,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_REFERENCE_UNREF, argv, 3);
}
napi_status napi_get_reference_value(napi_env env, napi_ref ref,
                                      napi_value *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)ref,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_GET_REFERENCE_VALUE, argv, 3);
}

/* ── BigInt ──────────────────────────────────────────────────────────────────── */

napi_status napi_create_bigint_int64(napi_env env, int64_t value,
                                      napi_value *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_BIGINT_INT64, argv, 3);
}
napi_status napi_create_bigint_uint64(napi_env env, uint64_t value,
                                       napi_value *result) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)value,
                        (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_BIGINT_UINT64, argv, 3);
}
napi_status napi_create_bigint_words(napi_env env, int sign_bit,
                                      size_t word_count,
                                      const uint64_t *words,
                                      napi_value *result) {
    return (napi_status)_dispatch(NAPI_OP_CREATE_BIGINT_WORDS, NULL, 0);
}
napi_status napi_get_value_bigint_int64(napi_env env, napi_value value,
                                         int64_t *result, bool *lossless) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result, (int64_t)(uintptr_t)lossless };
    return (napi_status)_dispatch(NAPI_OP_GET_VALUE_BIGINT_INT64, argv, 4);
}
napi_status napi_get_value_bigint_uint64(napi_env env, napi_value value,
                                          uint64_t *result, bool *lossless) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)value,
                        (int64_t)(uintptr_t)result, (int64_t)(uintptr_t)lossless };
    return (napi_status)_dispatch(NAPI_OP_GET_VALUE_BIGINT_UINT64, argv, 4);
}
napi_status napi_get_value_bigint_words(napi_env env, napi_value value,
                                         int *sign_bit, size_t *word_count,
                                         uint64_t *words) {
    return (napi_status)_dispatch(NAPI_OP_GET_VALUE_BIGINT_WORDS, NULL, 0);
}

/* ── Type tagging ────────────────────────────────────────────────────────────── */

napi_status napi_type_tag_object(napi_env env, napi_value object,
                                  const napi_type_tag *type_tag) {
    int64_t argv[3] = { (int64_t)env, (int64_t)object, (int64_t)type_tag };
    return (napi_status)_dispatch(NAPI_OP_TYPE_TAG_OBJECT, argv, 3);
}
napi_status napi_check_object_type_tag(napi_env env, napi_value object,
                                        const napi_type_tag *type_tag,
                                        bool *result) {
    int64_t argv[4] = { (int64_t)env, (int64_t)object, (int64_t)type_tag, (int64_t)result };
    return (napi_status)_dispatch(NAPI_OP_CHECK_OBJECT_TYPE_TAG, argv, 4);
}

/* ── Dates ───────────────────────────────────────────────────────────────────── */

napi_status napi_create_date(napi_env env, double time, napi_value *result) {
    return (napi_status)_dispatch(NAPI_OP_CREATE_DATE, NULL, 0);
}
napi_status napi_get_date_value(napi_env env, napi_value value, double *result) {
    return (napi_status)_dispatch(NAPI_OP_GET_DATE_VALUE, NULL, 0);
}

/* ── Instance data ───────────────────────────────────────────────────────────── */

napi_status napi_set_instance_data(napi_env env, void *data,
                                    napi_finalize finalize_cb,
                                    void *finalize_hint) {
    int64_t argv[4] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)data,
                        (int64_t)(uintptr_t)finalize_cb,
                        (int64_t)(uintptr_t)finalize_hint };
    return (napi_status)_dispatch(NAPI_OP_SET_INSTANCE_DATA, argv, 4);
}
napi_status napi_get_instance_data(napi_env env, void **data) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)data };
    return (napi_status)_dispatch(NAPI_OP_GET_INSTANCE_DATA, argv, 2);
}

/* ── Cleanup hooks ───────────────────────────────────────────────────────────── */

napi_status napi_add_env_cleanup_hook(napi_env env,
                                       napi_cleanup_hook fun, void *arg) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)fun,
                        (int64_t)(uintptr_t)arg };
    return (napi_status)_dispatch(NAPI_OP_ADD_ENV_CLEANUP_HOOK, argv, 3);
}
napi_status napi_remove_env_cleanup_hook(napi_env env,
                                          napi_cleanup_hook fun, void *arg) {
    int64_t argv[3] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)fun,
                        (int64_t)(uintptr_t)arg };
    return (napi_status)_dispatch(NAPI_OP_REMOVE_ENV_CLEANUP_HOOK, argv, 3);
}
napi_status napi_add_async_cleanup_hook(napi_env env,
                                         napi_async_cleanup_hook hook,
                                         void *arg,
                                         napi_async_cleanup_hook_handle *handle) {
    return (napi_status)_dispatch(NAPI_OP_ADD_ASYNC_CLEANUP_HOOK, NULL, 0);
}
napi_status napi_remove_async_cleanup_hook(napi_async_cleanup_hook_handle handle) {
    return (napi_status)_dispatch(NAPI_OP_REMOVE_ASYNC_CLEANUP_HOOK, NULL, 0);
}

/* ── Script ──────────────────────────────────────────────────────────────────── */

napi_status napi_run_script(napi_env env, napi_value script,
                             napi_value *result) {
    return (napi_status)_dispatch(NAPI_OP_RUN_SCRIPT, NULL, 0);
}

/* ── Async work ──────────────────────────────────────────────────────────────── */

napi_status napi_create_async_work(napi_env env, napi_value async_resource,
                                    napi_value async_resource_name,
                                    napi_async_execute_callback execute,
                                    napi_async_complete_callback complete,
                                    void *data, napi_async_work *result) {
    int64_t argv[7] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)async_resource,
                        (int64_t)(uintptr_t)async_resource_name,
                        (int64_t)(uintptr_t)execute, (int64_t)(uintptr_t)complete,
                        (int64_t)(uintptr_t)data, (int64_t)(uintptr_t)result };
    return (napi_status)_dispatch(NAPI_OP_CREATE_ASYNC_WORK, argv, 7);
}
napi_status napi_delete_async_work(napi_env env, napi_async_work work) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)work };
    return (napi_status)_dispatch(NAPI_OP_DELETE_ASYNC_WORK, argv, 2);
}
napi_status napi_queue_async_work(napi_env env, napi_async_work work) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)work };
    return (napi_status)_dispatch(NAPI_OP_QUEUE_ASYNC_WORK, argv, 2);
}
napi_status napi_cancel_async_work(napi_env env, napi_async_work work) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)work };
    return (napi_status)_dispatch(NAPI_OP_CANCEL_ASYNC_WORK, argv, 2);
}
/* ── Async context ───────────────────────────────────────────────────────────── */

napi_status napi_async_init(napi_env env, napi_value async_resource,
                             napi_value async_resource_name,
                             napi_async_context *result) {
    return (napi_status)_dispatch(NAPI_OP_ASYNC_INIT, NULL, 0);
}
napi_status napi_async_destroy(napi_env env, napi_async_context async_context) {
    return (napi_status)_dispatch(NAPI_OP_ASYNC_DESTROY, NULL, 0);
}
napi_status napi_make_callback(napi_env env, napi_async_context async_context,
                                napi_value recv, napi_value func,
                                size_t argc, const napi_value *argv,
                                napi_value *result) {
    return (napi_status)_dispatch(NAPI_OP_MAKE_CALLBACK, NULL, 0);
}
napi_status napi_open_callback_scope(napi_env env, napi_value resource_object,
                                      napi_async_context context,
                                      napi_callback_scope *result) {
    return (napi_status)_dispatch(NAPI_OP_OPEN_CALLBACK_SCOPE, NULL, 0);
}
napi_status napi_close_callback_scope(napi_env env, napi_callback_scope scope) {
    return (napi_status)_dispatch(NAPI_OP_CLOSE_CALLBACK_SCOPE, NULL, 0);
}

/* ── Threadsafe functions ────────────────────────────────────────────────────── */

napi_status napi_create_threadsafe_function(
        napi_env env, napi_value func, napi_value async_resource,
        napi_value async_resource_name, size_t max_queue_size,
        size_t initial_thread_count, void *thread_finalize_data,
        napi_finalize thread_finalize_cb, void *context,
        napi_threadsafe_function_call_js call_js_cb,
        napi_threadsafe_function *result) {
    /* Allocate a jac_tsfn_t and pass its pointer + the JS func to Jac. */
    jac_tsfn_t *t = (jac_tsfn_t *)calloc(1, sizeof(jac_tsfn_t));
    if (!t) return napi_generic_failure;
    t->env                  = env;
    t->js_func              = (int64_t)(uintptr_t)func;
    t->context              = context;
    t->call_js_cb           = call_js_cb;
    t->thread_finalize_cb   = thread_finalize_cb;
    t->thread_finalize_data = thread_finalize_data;
    t->thread_count         = (int)initial_thread_count;
    t->ref                  = 1; /* reffed by default at creation */
    pthread_mutex_init(&t->lock, NULL);

    /* Register in the JS-thread registry (we're on the JS thread here —
       napi_create_threadsafe_function is always called during module init). */
    if (_tsfn_count < JAC_TSFN_MAX) {
        _tsfn_registry[_tsfn_count++] = t;
    }

    /* Write the tsfn pointer as the opaque handle into *result. */
    if (result) *result = (napi_threadsafe_function)(uintptr_t)t;

    /* Notify Jac so it can ref the keepalive handle.
       argv[0] = tsfn pointer, argv[1] = js_func value */
    int64_t argv[2] = { (int64_t)(uintptr_t)t, t->js_func };
    return (napi_status)_dispatch(NAPI_OP_CREATE_THREADSAFE_FUNCTION, argv, 2);
}

napi_status napi_get_threadsafe_function_context(napi_threadsafe_function func,
                                                  void **result) {
    jac_tsfn_t *t = (jac_tsfn_t *)(uintptr_t)func;
    if (result && t) *result = t->context;
    return napi_ok;
}

napi_status napi_call_threadsafe_function(napi_threadsafe_function func,
                                           void *data,
                                           napi_threadsafe_function_call_mode mode) {
    /* Called from Tokio worker threads: push data to the ring buffer,
       then wake the JS thread via uv_async_send.  Must NOT call _dispatch. */
    jac_tsfn_t *t = (jac_tsfn_t *)(uintptr_t)func;
    if (!t) return napi_invalid_arg;
    if (t->closing) return napi_closing;

    pthread_mutex_lock(&t->lock);
    size_t next_tail = (t->q_tail + 1) % JAC_TSFN_QUEUE_CAP;
    if (next_tail == t->q_head) {
        /* Queue full */
        pthread_mutex_unlock(&t->lock);
        return (mode == napi_tsfn_nonblocking) ? napi_queue_full : napi_generic_failure;
    }
    t->queue[t->q_tail] = data;
    t->q_tail = next_tail;
    pthread_mutex_unlock(&t->lock);

    /* Wake the JS thread.  uv_async_send is the one thread-safe libuv call. */
    if (_tsfn_drain_handle) uv_async_send(_tsfn_drain_handle);
    return napi_ok;
}

napi_status napi_acquire_threadsafe_function(napi_threadsafe_function func) {
    jac_tsfn_t *t = (jac_tsfn_t *)(uintptr_t)func;
    if (!t) return napi_invalid_arg;
    pthread_mutex_lock(&t->lock);
    if (t->closing) { pthread_mutex_unlock(&t->lock); return napi_closing; }
    t->thread_count++;
    pthread_mutex_unlock(&t->lock);
    int64_t argv[1] = { (int64_t)(uintptr_t)t };
    return (napi_status)_dispatch(NAPI_OP_ACQUIRE_THREADSAFE_FUNCTION, argv, 1);
}

napi_status napi_release_threadsafe_function(napi_threadsafe_function func,
                                              napi_threadsafe_function_release_mode mode) {
    jac_tsfn_t *t = (jac_tsfn_t *)(uintptr_t)func;
    if (!t) return napi_invalid_arg;
    pthread_mutex_lock(&t->lock);
    t->thread_count--;
    int should_close = (t->thread_count <= 0);
    if (should_close) t->closing = 1;
    pthread_mutex_unlock(&t->lock);
    int64_t argv[2] = { (int64_t)(uintptr_t)t, (int64_t)should_close };
    return (napi_status)_dispatch(NAPI_OP_RELEASE_THREADSAFE_FUNCTION, argv, 2);
}

napi_status napi_ref_threadsafe_function(napi_env env,
                                          napi_threadsafe_function func) {
    jac_tsfn_t *t = (jac_tsfn_t *)(uintptr_t)func;
    if (!t) return napi_invalid_arg;
    t->ref++;
    int64_t argv[1] = { (int64_t)(uintptr_t)t };
    return (napi_status)_dispatch(NAPI_OP_REF_THREADSAFE_FUNCTION, argv, 1);
}

napi_status napi_unref_threadsafe_function(napi_env env,
                                            napi_threadsafe_function func) {
    jac_tsfn_t *t = (jac_tsfn_t *)(uintptr_t)func;
    if (!t) return napi_invalid_arg;
    if (t->ref > 0) t->ref--;
    int64_t argv[1] = { (int64_t)(uintptr_t)t };
    return (napi_status)_dispatch(NAPI_OP_UNREF_THREADSAFE_FUNCTION, argv, 1);
}

/* ── Event loop ──────────────────────────────────────────────────────────────── */

napi_status napi_get_uv_event_loop(napi_env env, struct uv_loop_s **loop) {
    int64_t argv[2] = { (int64_t)(uintptr_t)env, (int64_t)(uintptr_t)loop };
    return (napi_status)_dispatch(NAPI_OP_GET_UV_EVENT_LOOP, argv, 2);
}

/* ── Module file name ────────────────────────────────────────────────────────── */

napi_status node_api_get_module_file_name(napi_env env,
                                           const char **file_name_utf8) {
    return (napi_status)_dispatch(NAPI_OP_GET_MODULE_FILE_NAME, NULL, 0);
}
