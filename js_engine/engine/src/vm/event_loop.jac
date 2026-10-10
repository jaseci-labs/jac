"""
Core Event Loop.

Wires the existing libuv bindings  into a real EventLoop that
drives the js_engine VM.  After `run_script` executes the top-level synchronous
JS code, any remaining libuv handles (timers, async I/O — added in sub-phases
3.2 and 3.5) keep the loop alive until they are all closed.

Architecture
────────────
  1. An EventLoop object wraps a UVLoop (uv_loop_t) from  together
     with a uv_async_t wakeup handle and a pending-callback queue.

  2. The async handle is immediately unreffed (uv_unref) so it does NOT count
     as an active handle.  Only explicit handles added later (timers, fs, …)
     will keep the loop alive — matching Node.js / Bun behaviour.

  3. el_schedule(el, fn, args) pushes a JS callback onto the pending queue and
     calls uv_async_send to wake the loop on the next tick.  Called by timer
     and fs C callbacks in later sub-phases.

  4. _el_wakeup_cb (C callback registered with uv_async_init) drains the
     pending queue via el_tick on every wakeup.

  5. el_run(source) is the full entry point:
       a. Create GlobalContext, init built-ins.
       b. Initialise the event loop (el_create).
       c. Run the top-level script synchronously via run_script.
       d. Enter uv_run(UV_RUN_DEFAULT) — blocks until all reffed handles close.
       e. Flush final callbacks, close handles, return 0 on clean exit.

Bun reference  : bun/src/bun.js/VirtualMachine.zig    (eventLoop, tick,
                                                        drainMicrotasks)
                 bun/src/async/posix_event_loop.zig    (PosixEventLoop)
ECMAScript     : §8.4 – Jobs and Host Operations to Enqueue Jobs
                 https://tc39.es/ecma262/#sec-jobs
"""

import from engine.src.ffi.libuv {
    UVLoop,
    UVHandle,
    uvloop_create,
    uvloop_run_default,
    uvloop_run_nowait,
    uvloop_stop,
    uvloop_close,
    uvloop_update_time,
    uvasync_create,
    uvasync_send,
    uvasync_close,
    uvhandle_unref
}

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    js_int,
    jsv_from_string_id,
    jsv_to_table_id,
    js_boolean,
    jsv_is_int32,
    jsv_to_int32,
    jsv_is_double,
    jsv_to_double,
    jsv_is_undefined,
    jsv_is_string_cell,
    jsv_is_object_cell
}
import from engine.src.vm.vm {
    VM,
    make_vm,
    vm_call_js_fn,
    vm_call_js_fn_threw,
    vm_fire_register_hooks,
    vm_exec_reaction,
    vm_set_require_cache,
    vm_set_require_main,
    vm_init_require_extensions,
    vm_attach_module_compile,
    vm_finalize_entry_module,
    vm_mark_esm_namespace,
    vm_preseed_esm_namespace,
    vm_finalize_esm_namespace,
    vm_handle_unhandled_rejection,
    jsval_to_str
}
import from engine.src.vm.vm { proxy_vm_bind_for_traps }
import from engine.src.runtime.realm {
    Realm,
    realm_new,
    _GC_MIN_THRESHOLD,
    realm_request_exit
}
import from engine.src.runtime.global {
    GlobalContext,
    global_context_create,
    init_global,
    create_vm,
    run_script_with_vm,
    get_global,
    set_global,
    bootstrap_js_globals
}
import from engine.src.vm.timers {
    timer_init,
    timer_fired_count,
    timer_fired_fn,
    timer_fired_args,
    timer_fired_clear
}
import from engine.src.vm.scheduler {
    scheduler_has_pending,
    sched_nt_count,
    sched_nt_fn,
    sched_nt_args,
    sched_nt_clear,
    sched_mt_count,
    sched_mt_fn,
    sched_mt_args,
    sched_mt_clear,
    sched_react_count,
    sched_react_on_f,
    sched_react_on_r,
    sched_react_state,
    sched_react_val,
    sched_react_next_p,
    sched_react_clear
}
import from engine.src.builtins.process {
    process_build_argv,
    process_populate_env,
    process_get_cwd,
    process_do_exit,
    process_get_env,
    process_get_exec_path,
    process_get_input_type,
    process_get_eval_print,
    process_get_preserve_symlinks_main,
    process_get_unhandled_rejections,
    process_set_rejection_error_code,
    process_get_rejection_error_code,
    process_get_preloads,
    process_get_pid,
    process_apply_env_file_vars,
    process_get_unhandled_rejection_listeners,
    process_get_unhandled_rejection_once,
    process_get_exit_listeners,
    process_get_before_exit_listeners,
    process_rejection_handled_count,
    process_rejection_handled_fn,
    process_rejection_handled_promise,
    process_rejection_handled_clear
}
import from engine.src.ffi.libc { getenv }
import from engine.src.runtime.uncaught {
    print_unhandled_rejection_warning,
    print_uncaught
}
import from engine.src.builtins.promise {
    promise_unhandled_count,
    promise_unhandled_reason,
    promise_unhandled_promise,
    promise_unhandled_clear
}
import from engine.src.builtins.fs {
    fs_init,
    fs_fired_count,
    fs_fired_fn,
    fs_fired_args,
    fs_fired_clear
}
import from engine.src.builtins.fs_watch { fs_watch_module_init }
import from engine.src.builtins.child_process_bridge {
    cp_init,
    cp_event_pending,
    cp_get_drain_fn,
    cp_any_active,
    cp_reap_active_handles
}
import from engine.src.builtins.path_utils { path_dirname, path_abspath }
import from engine.src.builtins.net_bridge {
    nb_init,
    nb_fired_count,
    nb_fired_fn,
    nb_fired_args,
    nb_fired_clear,
    nb_unref_async
}
import from engine.src.builtins.stdin {
    stdin_init,
    stdin_chunk_count,
    stdin_chunk_get,
    stdin_chunk_clear,
    stdin_eof,
    stdin_is_started,
    stdin_stop,
    stdin_get_stream
}
import from engine.src.builtins.streams {
    stream_push,
    stream_pending_count,
    stream_pending_fn,
    stream_pending_args,
    stream_pending_clear
}
import from engine.src.builtins.module_resolver { package_type_for_path }
import from engine.src.builtins.modules { module_cache_set }
import from engine.src.builtins.fs { path_realpath_str }
import from engine.src.builtins.array { js_array_create, js_array_set }
import from engine.src.runtime.jsobject {
    js_object_get,
    js_object_set,
    js_object_create_null,
    js_object_delete
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.parser.parser { _source_is_module }
import from engine.src.builtins.module_bindings { module_create_bound_require }
import from napi.src.napi_tsfn { tsfn_init, tsfn_drain_all }
import from napi.src.napi_async { napi_async_init, napi_async_drain_all }
import from "lib/libnapi_shim.so" {
    def _napi_set_vm_call_fn(fn_ptr: int) -> None;  def _napi_argv_i64(
        argv_ptr: int, idx: int
    ) -> int;
}

# Bridge: called from C (via _napi_vm_call_fn) to invoke a JS closure via the VM.
# C typedef: int64_t fn(int64_t vm_ptr, int64_t fn_val, int64_t this_val,
#                       int64_t argc, int64_t *argv_jsv)
def:pub _napi_vm_call_bridge(
    vm_ptr: int, fn_val: int, this_val: int, argc: int, argv_ptr: int
) -> int {
    args: list[int] = [];
    i: int = 0;
    while i < argc {
        args.append(_napi_argv_i64(argv_ptr, i));
        i = i + 1;
    }
    return vm_call_js_fn(_GLOBAL_VM, fn_val, this_val, args);
}

# ══════════════════════════════════════════════════════════════════════════════
# EventLoop struct
# ══════════════════════════════════════════════════════════════════════════════

"""
Wraps a libuv uv_loop_t together with the js_engine pending-callback queue.

Fields:
  loop         — underlying libuv loop wrapper ( UVLoop)
  async_hdl    — uv_async_t used to wake the loop when JS callbacks are queued
  pending_fns  — JS function values (closures) waiting to be called on the
                 next tick
  pending_args — parallel args arrays for pending_fns
  running      — True while uv_run is executing
  tick_count   — monotonic counter of el_tick invocations (for debugging)

Bun Zig: VirtualMachine.event_loop_handle (uv_loop) + DeferredTaskQueue
"""
obj:pub EventLoop {
    has loop: UVLoop = UVLoop(),
        async_hdl: UVHandle = UVHandle(),
        pending_fns: list[JSValue] = [],
        pending_args: list[list[JSValue]] = [],
        running: bool = False,
        tick_count: int = 0;
}

# ── Module-level singletons ──────────────────────────────────────────────────
# Timers (3.2), fs (3.5), and other modules reference these to schedule
# callbacks without passing the EventLoop/VM around as parameters.

glob:pub _GLOBAL_EL: EventLoop = EventLoop(),
     _GLOBAL_VM: VM = make_vm();

"""True after 'exit' listeners have been dispatched (Node: fires exactly once)."""
glob _EXIT_LISTENERS_FIRED: bool = False;
# _DEFAULT_REALM: the C-callback boundary realm reference.
# C-level libuv callbacks cannot receive Realm as a parameter, so they read
# this global.  Jac→Jac calls receive realm via vm.realm or explicit param.
glob:pub _DEFAULT_REALM: Realm = realm_new(),
     _EL_GC_ENABLED: bool = True;

# ── GC enable flag — set True via --gc command-line switch before el_run() ───
# the collector is on by default; --nogc (main.jac) turns it off
glob _EL_REJECTION_ID: int = 0;  # numbering for --unhandled-rejections=warn messages (Node's "rejection id")

"""A JS string literal for `s` (preload specifiers)."""
def _el_js_quote(s: str) -> str {
    out: str = "\"";
    i: int = 0;
    while i < len(s) {
        c: str = s[i];
        if c == "\\" or c == "\"" {
            out = out + "\\" + c;
        } elif c == "\n" {
            out = out + "\\n";
        } else {
            out = out + c;
        }
        i = i + 1;
    }
    return out + "\"";
}

def:pub el_gc_enable {
    _EL_GC_ENABLED = True;
}
def:pub el_gc_disable {
    _EL_GC_ENABLED = False;
}

"""Return the raw uv_loop_t* pointer for the global event loop."""
def:pub el_get_loop_ptr -> int {
    return _GLOBAL_EL.loop.loop_ptr;
}

"""Return the raw uv_async_t* pointer for the global wakeup handle."""
def:pub el_get_async_ptr -> int {
    return _GLOBAL_EL.async_hdl.handle_ptr;
}

# ══════════════════════════════════════════════════════════════════════════════
# C callback bridge
# ══════════════════════════════════════════════════════════════════════════════

"""
libuv fires this function (in the loop thread) when uv_async_send is called.
Drains all pending JS callbacks scheduled since the last tick.

C signature: void (*uv_async_cb)(uv_async_t *handle)
"""
def _el_wakeup_cb(handle: int) {
    el_tick(_GLOBAL_EL, _GLOBAL_VM);
}

# ══════════════════════════════════════════════════════════════════════════════
# EventLoop lifecycle
# ══════════════════════════════════════════════════════════════════════════════

"""
Allocate and initialise a new EventLoop.

Creates a uv_loop_t via uvloop_create() and registers a uv_async_t wakeup
handle that calls _el_wakeup_cb.  The async handle is immediately unreffed so
it does not prevent the loop from exiting naturally when all other handles
(timers, I/O) are done.

Bun Zig: VirtualMachine.create() / PosixEventLoop.init()
"""
def:pub el_create -> EventLoop {
    el: EventLoop = EventLoop();
    el.loop = uvloop_create();
    el.async_hdl = uvasync_create(el.loop, _el_wakeup_cb);
    # Unref: the wakeup handle must not keep the loop alive on its own.
    # Timer handles and fs handles added in 3.2/3.5 are reffed by default and
    # will sustain the loop until they are stopped and closed.
    uvhandle_unref(el.async_hdl);
    return el;
}

"""
Schedule a JS callback to fire on the next event loop tick.

Appends (fn, args) to the pending queue then calls uv_async_send on the
wakeup handle, causing _el_wakeup_cb to fire on the next uv_run iteration.

Called by:
  -  timer callbacks after uv_timer fires
  -  fs callbacks after uv_fs completes
  - Any code that needs to defer a JS callback to the next event loop tick

Bun Zig: JSCScheduler.scheduleOnNextTick / DeferredTaskQueue.push
"""
def:pub el_schedule(el: EventLoop, fn: JSValue, args: list[JSValue]) {
    el.pending_fns.append(fn);
    el.pending_args.append(args);
    uvasync_send(el.async_hdl);
}

"""
Drain nextTick, deferred promise reactions, and queueMicrotask queues.

Order (Node.js / ECMAScript): nextTick → Promise jobs → queueMicrotask.
Re-drains until queues are empty or the per-tick cap is hit.

Must run before timer/macrotask callbacks so microtasks scheduled during
synchronous script execution precede setTimeout(0).
"""
def el_drain_scheduler(vm: VM) {
    _sched_max: int = 10000;
    # ECMAScript microtask checkpoint: drain nextTick + reactions + microtasks
    # until ALL THREE are jointly empty. A job in one phase can enqueue a job in
    # an already-drained phase (e.g. a Promise reaction calling `resolve()`
    # pushes a fresh reaction; a queueMicrotask scheduling nextTick), so the
    # phases must be wrapped in an outer loop — otherwise the late job is
    # stranded until the next wakeup, and if no reffed handle keeps the loop
    # alive it idles straight to `beforeExit` with the job undelivered. That
    # stranding was vite build's dropped addModuleSource continuation.
    _outer: int = 0;
    while (
        sched_nt_count(vm.realm) > 0
        or sched_react_count(vm.realm) > 0
        or sched_mt_count(vm.realm) > 0
    )
        and _outer < _sched_max {
        _outer = _outer + 1;
        el_drain_scheduler_once(vm, _sched_max);
    }
}

def el_drain_scheduler_once(vm: VM, _sched_max: int) {
    # CLEAR ONLY WHAT WAS PROCESSED. Each phase snapshots the queue length,
    # processes entries by index, then removes them from the front. The inner
    # loop can stop early at the _sched_max cap (with processed < snapshot);
    # clearing the SNAPSHOT count there removed unprocessed entries too — a
    # DROPPED continuation. For a large graph (vite bundling rollup's fan-out of
    # ~hundreds of concurrent resolveId/load promises) a single checkpoint can
    # exceed the cap, so the drop stranded plugin promises → rollup's
    # "Promises ... cannot resolve" early exit. Clearing the PROCESSED count
    # leaves the remainder queued for the next _once / outer drain iteration.
    _nt_total: int = 0;
    while sched_nt_count(vm.realm) > 0 and _nt_total < _sched_max {
        _snt: int = sched_nt_count(vm.realm);
        _sni: int = 0;
        while _sni < _snt and _nt_total < _sched_max {
            _sn_fn: JSValue = sched_nt_fn(vm.realm, _sni);
            _sn_args: list[JSValue] = sched_nt_args(vm.realm, _sni);
            _sni = _sni + 1;
            _nt_total = _nt_total + 1;
            vm_call_js_fn(vm, _sn_fn, js_undefined(), _sn_args);
        }
        sched_nt_clear(vm.realm, _sni);
    }

    _rt_total: int = 0;
    while sched_react_count(vm.realm) > 0 and _rt_total < _sched_max {
        _srn: int = sched_react_count(vm.realm);
        _sri: int = 0;
        while _sri < _srn and _rt_total < _sched_max {
            _sr_on_f: JSValue = sched_react_on_f(vm.realm, _sri);
            _sr_on_r: JSValue = sched_react_on_r(vm.realm, _sri);
            _sr_st: int = sched_react_state(vm.realm, _sri);
            _sr_val: JSValue = sched_react_val(vm.realm, _sri);
            _sr_np: JSValue = sched_react_next_p(vm.realm, _sri);
            _sri = _sri + 1;
            _rt_total = _rt_total + 1;
            vm_exec_reaction(vm, _sr_on_f, _sr_on_r, _sr_st, _sr_val, _sr_np);
        }
        sched_react_clear(vm.realm, _sri);
    }

    _mt_total: int = 0;
    while sched_mt_count(vm.realm) > 0 and _mt_total < _sched_max {
        _smt: int = sched_mt_count(vm.realm);
        _smi: int = 0;
        while _smi < _smt and _mt_total < _sched_max {
            _sm_fn: JSValue = sched_mt_fn(vm.realm, _smi);
            _sm_args: list[JSValue] = sched_mt_args(vm.realm, _smi);
            _smi = _smi + 1;
            _mt_total = _mt_total + 1;
            vm_call_js_fn(vm, _sm_fn, js_undefined(), _sm_args);
        }
        sched_mt_clear(vm.realm, _smi);
    }
}

"""
Drain all pending JS callbacks then check for loop shutdown.

Snapshot-then-drain pattern: processes only the callbacks that were queued
*before* this call.  New callbacks pushed during execution are deferred to the
next tick, preventing unbounded spin within a single loop iteration.

Called from _el_wakeup_cb on every async wakeup, and directly by el_run
after uv_run returns (to flush any final callbacks).

Bun Zig: VirtualMachine.drainMicrotasks() + tick()
"""
def:pub el_tick(el: EventLoop, vm: VM) {
    el.tick_count = el.tick_count + 1;

    # ── 1. Drain pending callbacks scheduled via el_schedule ──────────────
    n: int = len(el.pending_fns);
    i: int = 0;
    while i < n {
        fn: JSValue = el.pending_fns[i];
        args: list[JSValue] = el.pending_args[i];
        i = i + 1;
        vm_call_js_fn(vm, fn, js_undefined(), args);
    }
    # O(remaining) rebuild — repeated `del [0]` is O(n^2) for a batch of n.
    if n > 0 {
        pf_kept: list[JSValue] = [];
        pa_kept: list[list[JSValue]] = [];
        pk: int = n;
        plen: int = len(el.pending_fns);
        while pk < plen {
            pf_kept.append(el.pending_fns[pk]);
            pa_kept.append(el.pending_args[pk]);
            pk = pk + 1;
        }
        el.pending_fns = pf_kept;
        el.pending_args = pa_kept;
    }

    # ── 1b. Microtask checkpoint before macrotasks (timers / I/O) ─────────
    el_drain_scheduler(vm);

    # ── 2. Drain fired timer callbacks ───────────────────────
    # Timer C callbacks push into _FIRED_FNS/_FIRED_ARGS from vm.timers.
    # We access them via functions to avoid cross-module glob copy issues.
    tn: int = timer_fired_count();
    ti: int = 0;
    while ti < tn {
        tfn: JSValue = timer_fired_fn(ti);
        targs: list[JSValue] = timer_fired_args(ti);
        ti = ti + 1;
        vm_call_js_fn(vm, tfn, js_undefined(), targs);
    }
    timer_fired_clear(tn);

    # ── 2b. Drain fired fs callbacks ──────────────────────
    # fs operations push into _FS_FIRED_FNS/_FS_FIRED_ARGS from builtins.fs.
    # Drain in a LOOP: a fs callback may call another async fs function which
    # pushes more items (e.g. appendFile → stat → lstat → ...).  We keep
    # draining until the queue is empty, exactly like the net-bridge section.
    fn_fs: int = fs_fired_count();
    while fn_fs > 0 {
        fi: int = 0;
        while fi < fn_fs {
            ffn: JSValue = fs_fired_fn(fi);
            fargs: list[JSValue] = fs_fired_args(fi);
            fi = fi + 1;
            vm_call_js_fn(vm, ffn, js_undefined(), fargs);
        }
        fs_fired_clear(fn_fs);
        fn_fs = fs_fired_count();
    }

    # ── 2c-net. Drain fired net-bridge callbacks (Phase 6.6) ──────────
    # Non-blocking connect/read ops push into _NB_FIRED_FNS/_NB_FIRED_ARGS.
    # Drain in a LOOP: JS callbacks invoked during this drain (e.g. a connect
    # callback that calls tcpReadNb which gets data immediately) may push
    # more items.  The outer loop ensures everything is drained before we
    # proceed.  _nb_wake() refs the async handle to keep the event loop
    # alive; we unref it once after draining so the loop can exit naturally.
    nb_had_items: bool = False;
    nb_n: int = nb_fired_count();
    while nb_n > 0 {
        nb_had_items = True;
        nb_i: int = 0;
        while nb_i < nb_n {
            nb_fn: JSValue = nb_fired_fn(nb_i);
            nb_args: list[JSValue] = nb_fired_args(nb_i);
            nb_i = nb_i + 1;
            vm_call_js_fn(vm, nb_fn, js_undefined(), nb_args);
        }
        nb_fired_clear(nb_n);
        nb_n = nb_fired_count();
    }
    if nb_had_items {
        nb_unref_async();
    }

    # ── 2d. Drain stdin chunks ────────────────────────────
    # The stdin polling callback (builtins.stdin) reads from fd 0 and stores
    # raw string chunks in _STDIN_CHUNKS.  Here we convert each chunk to a
    # JSValue string and push it into the process.stdin readable stream.
    # stream_push queues data listener callbacks into the stream pending-emit
    # queue, which we then drain via vm_call_js_fn.
    sc: int = stdin_chunk_count();
    if sc > 0 {
        stdin_obj: JSValue = stdin_get_stream();
        sci: int = 0;
        while sci < sc {
            chunk_str: str = stdin_chunk_get(sci);
            chunk_id: int = str_intern(chunk_str);
            chunk_val: JSValue = jsv_from_string_id(chunk_id);
            stream_push(stdin_obj, [chunk_val]);
            sci = sci + 1;
        }
        stdin_chunk_clear(sc);
        # Drain pending stream emits generated by stream_push.
        # Clear each entry BEFORE executing its callback so that
        # re-entrant _drain_stream_pending in the VM does not
        # re-process the same entry.
        while stream_pending_count() > 0 {
            sp_fn: JSValue = stream_pending_fn(0);
            sp_args: list[JSValue] = stream_pending_args(0);
            stream_pending_clear(1);
            vm_call_js_fn(vm, sp_fn, js_undefined(), sp_args);
        }
    }
    # Handle stdin EOF — push null to signal end of stream
    if stdin_eof() and stdin_is_started() {
        stdin_stop();
        stdin_obj_e: JSValue = stdin_get_stream();
        stream_push(stdin_obj_e, [js_null()]);
        # Drain pending emits from the end signal
        while stream_pending_count() > 0 {
            sp_fn_e: JSValue = stream_pending_fn(0);
            sp_args_e: list[JSValue] = stream_pending_args(0);
            stream_pending_clear(1);
            vm_call_js_fn(vm, sp_fn_e, js_undefined(), sp_args_e);
        }
    }

    # ── 2e. Drain child-process events (poll → queue → JS ChildProcess emit) ──
    # Reap in native code each tick so exit/close are not lost when nextTick drain
    # stops and libuv has not yet polled pipe EOF.
    if cp_any_active() > 0 {
        cp_reap_active_handles();
    }
    if cp_event_pending() > 0 {
        cp_df: JSValue = cp_get_drain_fn();
        if not jsv_is_undefined(cp_df) {
            vm_call_js_fn(vm, cp_df, js_undefined(), []);
        }
    }

    # ── 2f. Drain NAPI async-work completes, then TSFN callbacks ─────────
    # napi_async_drain_all() delivers complete(env, napi_ok, data) for work
    # queued since the last tick — BEFORE the microtask checkpoint below, so
    # promises settled by complete run their reactions in this same tick.
    napi_async_drain_all();
    # tsfn_drain_all() iterates the C-side registry and calls call_js_cb for
    # each item in each ring buffer.  Safe to call even when no TSFNs exist.
    tsfn_drain_all();

    # ── 3. Microtask checkpoint after macrotasks / I/O ─────────────────────
    el_drain_scheduler(vm);

    # 4. Dispatch pending unhandledRejection callbacks synchronously (before next timer tick).
    # We call vm_call_js_fn directly so listeners fire in the CURRENT el_tick, before any
    # new timer callbacks that the next uv_run iteration may queue.
    # Snapshot listeners before iterating: a listener callback may call process.on/off,
    # mutating the live glob lists. Operating on snapshots avoids iterator invalidation.
    _ur_n: int = promise_unhandled_count();
    if _ur_n > 0 {
        _ur_live: list[int] = process_get_unhandled_rejection_listeners();
        _ur_live_once: list[int] = process_get_unhandled_rejection_once();
        # Build snapshots
        _ur_snap_fns: list[int] = [];
        _ur_snap_once: list[int] = [];
        _ur_si: int = 0;
        while _ur_si < len(_ur_live) {
            _ur_snap_fns.append(_ur_live[_ur_si]);
            _ur_snap_once.append(_ur_live_once[_ur_si]);
            _ur_si = _ur_si + 1;
        }
        _ur_mode: str = process_get_unhandled_rejections();
        _ur_i: int = 0;
        while _ur_i < _ur_n {
            _ur_reason: JSValue = promise_unhandled_reason(_ur_i);
            _ur_promise: JSValue = promise_unhandled_promise(_ur_i);
            _ur_i = _ur_i + 1;
            # --unhandled-rejections (Node): warn / warn-with-error-code always print
            # a warning; strict always raises the rejection as an uncaught exception
            # (listeners still run when it is handled); throw (default) raises it only
            # when there is no 'unhandledRejection' listener; none stays silent.
            if _ur_mode == "warn" or _ur_mode == "warn-with-error-code" {
                _EL_REJECTION_ID = _EL_REJECTION_ID + 1;
                print_unhandled_rejection_warning(
                    _ur_reason, process_get_pid(), _EL_REJECTION_ID
                );
                if _ur_mode == "warn-with-error-code" {
                    process_set_rejection_error_code();
                }
            }
            if _ur_mode == "strict"
                or (_ur_mode == "throw" and len(_ur_snap_fns) == 0) {
                # Fatal unless an uncaughtException listener handles it (Node and bun:
                # stderr + exit 1). Stop at the first fatal one — the process is
                # exiting; the remaining queue is cleared below.
                vm_handle_unhandled_rejection(vm, _ur_reason);
                if vm.realm.pending_exit {
                    break;
                }
            }
            if len(_ur_snap_fns) > 0 {
                _ur_li: int = 0;
                _ur_remove: list[int] = [];
                while _ur_li < len(_ur_snap_fns) {
                    _ur_fn: JSValue = _ur_snap_fns[_ur_li];
                    vm_call_js_fn(
                        vm, _ur_fn, js_undefined(), [_ur_reason, _ur_promise]
                    );
                    # Listener throw (e.g. vite.js rethrow) must fail the process — vm_call_js_fn
                    # clears had_exception after each callback; honor via pending_exit.
                    if vm.had_exception {
                        realm_request_exit(vm.realm);
                        vm.realm.pending_exit_code = 1;
                        vm.had_exception = False;
                    }
                    if _ur_snap_once[_ur_li] == 1 {
                        _ur_remove.append(_ur_li);
                    }
                    _ur_li = _ur_li + 1;
                }
                # Remove once-listeners from the live list and snapshot, reverse order
                _ur_ri: int = len(_ur_remove) - 1;
                while _ur_ri >= 0 {
                    _ur_idx: int = _ur_remove[_ur_ri];
                    # Sync removal to the live glob list so future ticks see the removal
                    del _ur_live[_ur_idx];
                    del _ur_live_once[_ur_idx];
                    del _ur_snap_fns[_ur_idx];
                    del _ur_snap_once[_ur_idx];
                    _ur_ri = _ur_ri - 1;
                }
            }
        }
        promise_unhandled_clear(_ur_n);
    }

    # Step 5: dispatch any pending 'rejectionHandled' events
    # (A promise that was previously unhandled and then got a .catch() handler.)
    _rh_n: int = process_rejection_handled_count();
    if _rh_n > 0 {
        _rh_i: int = 0;
        while _rh_i < _rh_n {
            _rh_fn: JSValue = process_rejection_handled_fn(_rh_i);
            _rh_promise: JSValue = process_rejection_handled_promise(_rh_i);
            vm_call_js_fn(vm, _rh_fn, js_undefined(), [_rh_promise]);
            _rh_i = _rh_i + 1;
        }
        process_rejection_handled_clear(_rh_n);
    }
}

"""
Stop the event loop. The current or next uv_run call will return.

Use this from process.exit()  or when the entry script calls
process.exit() or throws a top-level uncaught exception.

Bun Zig: VirtualMachine.exit() / uv_stop()
"""
def:pub el_stop(el: EventLoop) {
    uvloop_stop(el.loop);
}

"""
Full entry point: source JS → lex/parse/compile → synchronous exec → event loop.

Steps:
  1. Create a GlobalContext and populate built-ins (init_global).
  2. Initialise the event loop (el_create) and wire it to the module-level
     _GLOBAL_EL / _GLOBAL_VM singletons used by timer/fs callbacks.
  3. Run the top-level script synchronously via run_script.
  4. Enter uv_run(UV_RUN_DEFAULT) — blocks until all reffed handles close.
  5. Flush any final callbacks queued after the last libuv event.
  6. Close the wakeup handle, drain its close callback, close the loop.
  7. Return 0 on clean exit.

This replaces the bare run_script call from main.na.jac for async-capable runs.

Bun Zig: VirtualMachine.loadEntryPointForMainThread() + uv_run(DEFAULT)
"""
# Remove CJS pseudo-globals from vm.globals and globalThis (ESM entry).
def _strip_cjs_pseudo_globals(vm: VM) {
    names: list[str] = ["require", "module", "exports", "__dirname", "__filename"];
    ni: int = 0;
    while ni < len(names) {
        nm: str = names[ni];
        if nm in vm.globals {
            vm.globals[nm] = js_undefined();
            vm.gw_epoch = vm.gw_epoch + 1;
        }
        js_object_set(vm.global_this, str_intern(nm), js_undefined());
        ni = ni + 1;
    }
}

def _fire_exit_listeners(exit_code: int) -> None {
    if _EXIT_LISTENERS_FIRED {
        return;
    }
    _EXIT_LISTENERS_FIRED = True;
    saved_pe: bool = _GLOBAL_VM.realm.pending_exit;
    _GLOBAL_VM.realm.pending_exit = False;
    live: list[int] = process_get_exit_listeners();
    snap: list[int] = [];
    si: int = 0;
    while si < len(live) {
        snap.append(live[si]);
        si = si + 1;
    }
    exit_args: list[JSValue] = [];
    exit_args.append(js_int(exit_code));
    el_fi: int = 0;
    while el_fi < len(snap) {
        pe_before: bool = _GLOBAL_VM.realm.pending_exit;
        threw: int = vm_call_js_fn_threw(
            _GLOBAL_VM, snap[el_fi], js_undefined(), exit_args
        );
        if threw == 1 {
            break;
        }
        # Node: process.exit() from inside an exit handler stops further handlers.
        if _GLOBAL_VM.realm.pending_exit and not pe_before {
            break;
        }
        el_fi = el_fi + 1;
    }
    if saved_pe or _GLOBAL_VM.realm.pending_exit {
        realm_request_exit(_GLOBAL_VM.realm);
    }
}

def:pub el_run(source: str, script_name: str, extra_args: list[str]) -> int {
    ctx: GlobalContext = global_context_create();
    init_global(ctx);

    # Apply GC-enable flag set by the --gc command-line switch (default: disabled)
    ctx.realm.gc_enabled = _EL_GC_ENABLED;
    # Apply the (possibly env-tuned) GC frequency floor to this realm, in case it
    # was constructed before main() parsed JAC_GC_MIN_THRESHOLD.
    ctx.realm.gc_threshold = _GC_MIN_THRESHOLD;

    # : populate process.env from libc getenv() (native context)
    process_populate_env();
    process_apply_env_file_vars();  # --env-file variables (only those not already set)

    # : set process.argv = ["js_engine", script_name, ...extra_args]
    # Use get_global (same-module accessor in global.na.jac) to avoid cross-module
    # multi-level struct field dereference (ctx.global_obj.object → garbage IR).
    proc_obj: JSValue = get_global(ctx, str_intern("process"));
    argv_arr: JSValue = process_build_argv(script_name, extra_args);
    js_object_set(proc_obj, str_intern("argv"), argv_arr);

    _GLOBAL_EL = el_create();
    _GLOBAL_VM = create_vm(ctx);
    tsfn_init(_GLOBAL_EL.loop.loop_ptr);
    # Async-work drain wakeup: bind the loop's own wakeup handle (ref'd
    # while completes are pending; see napi_async.na.jac keep-alive notes).
    el_aw_hdl: UVHandle = _GLOBAL_EL.async_hdl;
    napi_async_init(el_aw_hdl.handle_ptr);
    _napi_set_vm_call_fn(_napi_vm_call_bridge);

    proxy_vm_bind_for_traps(_GLOBAL_VM);
    # Compute absolute script dir immediately so nested require() resolves absolute paths
    cwd_v_pre: JSValue = process_get_cwd();
    cwd_str_pre: str = str_from_id(jsv_to_table_id(cwd_v_pre));
    abs_script: str = path_abspath(script_name, cwd_str_pre);
    _GLOBAL_VM.script_dir = path_dirname(abs_script);
    # Resolve engine root: JAC_ENGINE_ROOT env, else parent of bin/js_engine, else cwd.
    er_root_set: int = 0;
    env_obj: JSValue = process_get_env();
    if jsv_is_object_cell(env_obj) {
        jer_v: JSValue = js_object_get(env_obj, str_intern("JAC_ENGINE_ROOT"));
        if jsv_is_string_cell(jer_v) {
            jer_s: str = str_from_id(jsv_to_table_id(jer_v));
            if jer_s != "" {
                # Normalize: if JAC_ENGINE_ROOT points to the project root
                # (js_engine/) rather than the engine dir (js_engine/engine/),
                # append "/engine" so builtins resolve correctly.
                jer_len: int = len(jer_s);
                jer_has_engine: bool = False;
                if jer_len >= 7 {
                    jer_suf: str = jer_s[jer_len - 7:];
                    if jer_suf == "/engine" {
                        jer_has_engine = True;
                    }
                }
                if jer_has_engine {
                    _GLOBAL_VM.engine_root = jer_s;
                } else {
                    _GLOBAL_VM.engine_root = jer_s + "/engine";
                }
                er_root_set = 1;
            }
        }
    }
    if er_root_set == 0 {
        exec_p: str = process_get_exec_path();
        bin_d: str = path_dirname(exec_p);
        par: str = path_dirname(bin_d);
        # Probe: when running as a compiled binary (bin/js_engine), par is the
        # project root (js_engine/) and builtins live under engine/src/builtins/js/.
        # When running via `jac run engine/src/main.na.jac`, exec_p IS the .na.jac
        # file, so par resolves to js_engine/engine/ directly.
        # Detect by checking which path actually contains the builtins directory.
        if par != "" {
            # Detect case: when running via `jac run engine/src/main.na.jac`,
            # exec_p is the .na.jac file, so par = .../engine/ (ends with "/engine").
            # When running as a compiled binary (bin/js_engine), par is the
            # project root (e.g. js_engine/), which does NOT end with "/engine".
            # In the binary case we need to append "/engine" to get the engine root.
            par_len: int = len(par);
            is_already_engine: bool = False;
            if par_len >= 7 {
                suf: str = par[par_len - 7:];
                if suf == "/engine" {
                    is_already_engine = True;
                }
            }
            if is_already_engine {
                _GLOBAL_VM.engine_root = par;
            } else {
                _GLOBAL_VM.engine_root = par + "/engine";
            }
        } else {
            _GLOBAL_VM.engine_root = cwd_str_pre;
        }
    }
    _GLOBAL_EL.running = True;

    # Bootstrap JS-defined globals: fetch, Headers, Request, Response,
    # AbortController, AbortSignal — these are globals in Node.js ≥18,
    # not modules.  Must run after engine_root is set.
    #
    # Loading the builtins/.jsbc bytecode allocates ~1M objects that live for the
    # whole process (not leaks). When JS_ENGINE_DISABLE_JSBC_MEM_LEAKS_TESTING is
    # set, silence the RC leak trace across this bootstrap so it does not drown the
    # trace, then re-enable it afterwards. No-op unless the trace was compiled in.
    _disable_jsbc_trace: bool = getenv("JS_ENGINE_DISABLE_JSBC_MEM_LEAKS_TESTING")
        != None;
    if _disable_jsbc_trace {
        __rc_debug_disable();
    }
    bootstrap_js_globals(_GLOBAL_VM, ctx);
    if _disable_jsbc_trace {
        __rc_debug_enable();
    }

    # CJS require.extensions table (shared by global require and createRequire)
    vm_init_require_extensions();

    # : initialise timer subsystem with loop + async handle pointers
    timer_init(
        _GLOBAL_EL.loop.loop_ptr, _GLOBAL_EL.async_hdl.handle_ptr, _GLOBAL_VM.realm
    );

    # : initialise fs subsystem with async handle pointer for wakeup
    fs_init(_GLOBAL_EL.async_hdl.handle_ptr);
    fs_watch_module_init(_GLOBAL_EL.loop.loop_ptr);

    cp_init(_GLOBAL_EL.loop.loop_ptr, _GLOBAL_EL.async_hdl.handle_ptr);

    # : initialise non-blocking I/O subsystem (Phase 6.6)
    nb_init(_GLOBAL_EL.loop.loop_ptr, _GLOBAL_EL.async_hdl.handle_ptr);

    # : initialise stdin subsystem with loop + async handle pointers
    # Actual polling starts lazily when the first data listener is added
    # to process.stdin (via stream_on → stdin_start).
    stdin_init(_GLOBAL_EL.loop.loop_ptr, _GLOBAL_EL.async_hdl.handle_ptr);

    # Refresh the loop's cached time so that timers created during script
    # execution get deadlines relative to *now*, not the stale time from
    # uv_loop_init (which may be hundreds of ms earlier due to JIT overhead).
    uvloop_update_time(_GLOBAL_EL.loop);

    # Step 1: synchronous script execution (may schedule timers / fs ops)
    # Use run_script_with_vm so the same VM instance (_GLOBAL_VM) is shared
    # between the synchronous top-level script and async timer/fs callbacks.
    # This ensures globals set during script execution (e.g., `var order = []`)
    # are visible to callbacks invoked later via vm_call_js_fn(_GLOBAL_VM, ...).

    cwd_v: JSValue = process_get_cwd();
    cwd_str: str = str_from_id(jsv_to_table_id(cwd_v));

    # -r / --require / --import / --preload: load each module before the entry
    # point, resolved from the cwd like Node's Module._load(request, null). The
    # require native lives in the VM's call opcode, so each preload runs as a
    # one-line script; an exception is fatal (run_script_with_vm prints it).
    el_preloads: list[str] = process_get_preloads();
    if len(el_preloads) > 0 {
        el_saved_rp: str = _GLOBAL_VM.require_parent_override;
        _GLOBAL_VM.require_parent_override = cwd_str + "/[preload]";
        for el_pre in el_preloads {
            run_script_with_vm(
                _GLOBAL_VM,
                "require(" + _el_js_quote(el_pre) + ");",
                cwd_str + "/[preload]"
            );
            if _GLOBAL_VM.realm.pending_exit or _GLOBAL_VM.had_exception {
                el_pre_code: int = 1;
                if _GLOBAL_VM.realm.pending_exit {
                    el_pre_code = _GLOBAL_VM.realm.pending_exit_code;
                }
                _fire_exit_listeners(el_pre_code);
                process_do_exit(el_pre_code);
            }
        }
        _GLOBAL_VM.require_parent_override = el_saved_rp;
    }

    cjs_abs_path: str = path_abspath(script_name, cwd_str);
    # Node loads the main module through its symlinks (fs.realpathSync) unless
    # --preserve-symlinks-main: `node_modules/.bin/vite -> ../vite/bin/vite.js`
    # must resolve `../dist/node/cli.js` against vite/bin/, not .bin/. process.argv[1]
    # keeps the path as given (Node only path.resolve()s it).
    if not process_get_preserve_symlinks_main() {
        el_main_rp: str = path_realpath_str(cjs_abs_path);
        if el_main_rp != "" {
            cjs_abs_path = el_main_rp;
        }
    }
    cjs_dir: str = path_dirname(cjs_abs_path);
    # A failing top-level await is fatal for the entry script only (vm.jac
    # _vm_is_entry_module_frame); -e/-p code keeps "" (always the entry).
    if script_name != "<eval>" {
        _GLOBAL_VM.entry_file = cjs_abs_path;
    }

    # Node: the main entry's own resolution happens after preloads run, so
    # registerHooks resolve hooks observe it too. The engine runs the main
    # script directly (no require()) — fire the chain explicitly. A throwing
    # hook is fatal (Node exits non-zero when a resolve hook raises).
    if script_name != "<eval>" and len(process_get_preloads()) > 0 {
        me_threw: int = vm_fire_register_hooks(_GLOBAL_VM, cjs_abs_path);
        if me_threw != 0 {
            me_exc: JSValue = _GLOBAL_VM.pending_exc;
            _GLOBAL_VM.pending_exc = js_undefined();
            _GLOBAL_VM.had_exception = False;
            print_uncaught(me_exc);
            return 1;
        }
    }

    # Detect ESM entry (.mjs / type:module / --input-type=module) — no CJS globals
    el_is_esm: bool = False;
    el_input_type: str = process_get_input_type();
    sn: str = script_name;
    sn_len: int = len(sn);
    if el_input_type == "module" {
        el_is_esm = True;
    } elif el_input_type == "commonjs" {
        el_is_esm = False;
    } elif sn_len >= 4
        and sn[sn_len - 4] == "."
        and sn[sn_len - 3] == "m"
        and sn[sn_len - 2] == "j"
        and sn[sn_len - 1] == "s" {
        el_is_esm = True;
    } elif sn_len >= 4
        and sn[sn_len - 4] == "."
        and sn[sn_len - 3] == "c"
        and sn[sn_len - 2] == "j"
        and sn[sn_len - 1] == "s" {
        # `.cjs` is CommonJS even inside a "type": "module" package (Node).
        el_is_esm = False;
    } elif package_type_for_path(cjs_abs_path) == "module" {
        el_is_esm = True;
    }

    # --print / -p: evaluate and print the completion value (Node-compatible).
    el_source: str = source;
    if process_get_eval_print() {
        el_source = "console.log((" + source + "))";
    }
    # Plain `.js` entries that contain import/export (e.g. test262 cyclic-import
    # sandboxes that keep the original `.js` basename) still parse as modules.
    # Track that so we can mark the exports object as a Module Namespace Exotic
    # even when the CJS-wrapper path is used for globals.
    el_src_is_mod: bool = el_is_esm or _source_is_module(el_source);

    cjs_module: JSValue = js_undefined();
    if not el_is_esm {
        # ── CJS module wrapper globals (§Node.js CJS wrapper) ─────────────────
        cjs_exports: JSValue = js_object_create_null();
        cjs_module = js_object_create_null();
        js_object_set(cjs_module, str_intern("exports"), cjs_exports);
        js_object_set(
            cjs_module,
            str_intern("filename"),
            jsv_from_string_id(str_intern(cjs_abs_path))
        );
        js_object_set(
            cjs_module, str_intern("id"), jsv_from_string_id(str_intern(cjs_abs_path))
        );
        js_object_set(cjs_module, str_intern("loaded"), js_boolean(False));
        js_object_set(cjs_module, str_intern("children"), js_array_create([]));
        js_object_set(cjs_module, str_intern("parent"), js_null());
        js_object_set(
            cjs_module, str_intern("require"), module_create_bound_require(cjs_abs_path)
        );
        el_paths_arr: JSValue = js_array_create([]);
        el_paths_idx: int = 0;
        el_paths_cur: str = cjs_dir;
        el_paths_prev: str = "";
        while el_paths_cur != el_paths_prev and el_paths_cur != "" {
            el_nm: str = el_paths_cur + "/node_modules";
            js_array_set(
                el_paths_arr, el_paths_idx, jsv_from_string_id(str_intern(el_nm))
            );
            el_paths_idx = el_paths_idx + 1;
            el_paths_prev = el_paths_cur;
            el_paths_cur = path_dirname(el_paths_cur);
        }
        js_object_set(cjs_module, str_intern("paths"), el_paths_arr);
        vm_attach_module_compile(cjs_module);
        _GLOBAL_VM.globals["__filename"] = jsv_from_string_id(str_intern(cjs_abs_path));
        _GLOBAL_VM.gw_epoch = _GLOBAL_VM.gw_epoch + 1;
        _GLOBAL_VM.globals["__dirname"] = jsv_from_string_id(str_intern(cjs_dir));
        _GLOBAL_VM.gw_epoch = _GLOBAL_VM.gw_epoch + 1;
        _GLOBAL_VM.globals["module"] = cjs_module;
        _GLOBAL_VM.gw_epoch = _GLOBAL_VM.gw_epoch + 1;
        _GLOBAL_VM.globals["exports"] = cjs_exports;
        _GLOBAL_VM.gw_epoch = _GLOBAL_VM.gw_epoch + 1;
        # A plain-.js entry whose source uses `import`/`export` is parsed with the
        # module goal even though it runs through this CJS-wrapper branch.  ESM
        # export statements write to the `__jac_esm_exports` global; point it at
        # the CJS exports object so `export default`/`export {x}` land there, and
        # register that object in the module cache *before* the body runs so an
        # ESM self-import resolves to the in-progress record instead of
        # re-executing the file (ES ModuleEvaluation registers before evaluation).
        _GLOBAL_VM.globals["__jac_esm_exports"] = cjs_exports;
        _GLOBAL_VM.gw_epoch = _GLOBAL_VM.gw_epoch + 1;
        module_cache_set(cjs_abs_path, cjs_exports);
        el_cjs_rp: str = path_realpath_str(cjs_abs_path);
        if el_cjs_rp != "" and el_cjs_rp != cjs_abs_path {
            module_cache_set(el_cjs_rp, cjs_exports);
        }
        if el_src_is_mod {
            # test262 cyclic-import sandboxes keep the `.js` basename; mark the
            # shared exports object so `import * as ns` sees namespace exotic ops.
            vm_mark_esm_namespace(_GLOBAL_VM, cjs_exports);
            vm_preseed_esm_namespace(_GLOBAL_VM, cjs_exports, el_source);
            _GLOBAL_VM.esm_entry = 1;
        }
        cjs_req_cache: JSValue = js_object_create_null();
        vm_set_require_cache(cjs_req_cache);
        vm_set_require_main(cjs_module);
    } else {
        # ESM module goal: no CJS pseudo-globals visible (NCJS-CTX-*)
        _GLOBAL_VM.globals["__jacEntryFilename"] = jsv_from_string_id(
            str_intern(cjs_abs_path)
        );
        _GLOBAL_VM.gw_epoch = _GLOBAL_VM.gw_epoch + 1;
        el_esm_exports: JSValue = js_object_create_null();
        _GLOBAL_VM.globals["__jac_esm_exports"] = el_esm_exports;
        _GLOBAL_VM.gw_epoch = _GLOBAL_VM.gw_epoch + 1;
        cjs_req_cache2: JSValue = js_object_create_null();
        vm_set_require_cache(cjs_req_cache2);
        # Synthetic require.main so createRequire(...).main.filename works in ESM
        # (Node test harness skip() reads require.main?.filename).
        el_esm_main: JSValue = js_object_create_null();
        js_object_set(el_esm_main, str_intern("exports"), el_esm_exports);
        js_object_set(
            el_esm_main,
            str_intern("filename"),
            jsv_from_string_id(str_intern(cjs_abs_path))
        );
        js_object_set(
            el_esm_main, str_intern("id"), jsv_from_string_id(str_intern(cjs_abs_path))
        );
        js_object_set(el_esm_main, str_intern("loaded"), js_boolean(False));
        js_object_set(el_esm_main, str_intern("children"), js_array_create([]));
        js_object_set(el_esm_main, str_intern("parent"), js_null());
        vm_set_require_main(el_esm_main);
        _strip_cjs_pseudo_globals(_GLOBAL_VM);
        _GLOBAL_VM.esm_entry = 1;
        # Register the entry module's live exports in the module cache *before*
        # its body runs, so an ESM self-import (`import x from './this.js'` inside
        # the entry itself) resolves to the in-progress module record instead of
        # re-executing the file (ES ModuleEvaluation registers the record before
        # evaluation). `_require_module` realpath-normalizes resolved paths, so
        # cache under both the abspath and its realpath.
        module_cache_set(cjs_abs_path, el_esm_exports);
        el_entry_rp: str = path_realpath_str(cjs_abs_path);
        if el_entry_rp != "" and el_entry_rp != cjs_abs_path {
            module_cache_set(el_entry_rp, el_esm_exports);
        }
        # Mark as Module Namespace Exotic before evaluation so self-imports
        # observe exotic [[Set]]/[[Delete]]/[[IsExtensible]]/@@toStringTag.
        vm_mark_esm_namespace(_GLOBAL_VM, el_esm_exports);
        vm_preseed_esm_namespace(_GLOBAL_VM, el_esm_exports, el_source);
    }

    _GLOBAL_VM.script_dir = cjs_dir;
    # RC leak-hunt: JS_ENGINE_LEAKS_SCRIPT enables the RC trace ONLY around the
    # synchronous top-level script execution, so the ~1M startup/bootstrap
    # allocations (init_global, shapes, jsbc load) do not drown the trace. No-op
    # unless the engine was built with JAC_RC_DEBUG_CODEGEN.
    _leak_script_only: bool = getenv("JS_ENGINE_LEAKS_SCRIPT") != None;
    if _leak_script_only {
        __rc_debug_enable();
    }
    run_script_with_vm(_GLOBAL_VM, el_source, cjs_abs_path);
    if _leak_script_only {
        __rc_debug_disable();
    }

    if not el_is_esm {
        vm_finalize_entry_module(_GLOBAL_VM, cjs_module, cjs_abs_path);
        if el_src_is_mod and "__jac_esm_exports" in _GLOBAL_VM.globals {
            vm_finalize_esm_namespace(
                _GLOBAL_VM, _GLOBAL_VM.globals["__jac_esm_exports"]
            );
        }
    } else {
        # Seal the entry module namespace after evaluation (non-extensible +
        # non-configurable export descriptors).
        if "__jac_esm_exports" in _GLOBAL_VM.globals {
            vm_finalize_esm_namespace(
                _GLOBAL_VM, _GLOBAL_VM.globals["__jac_esm_exports"]
            );
        }
    }

    # If process.exit() was called synchronously during script execution,
    # or an uncaught exception occurred, fire exit listeners then exit.
    el_sync_realm: Realm = _GLOBAL_VM.realm;
    if el_sync_realm.pending_exit or _GLOBAL_VM.had_exception {
        el_early_code: int = 1;
        if el_sync_realm.pending_exit {
            el_early_code = el_sync_realm.pending_exit_code;
        }
        _fire_exit_listeners(el_early_code);
        el_exit_code: int = el_early_code;
        if el_sync_realm.pending_exit {
            el_exit_code = el_sync_realm.pending_exit_code;
        }
        process_do_exit(el_exit_code);
    }

    # : drain scheduler queues (nextTick + microtask) that were
    # enqueued during synchronous script execution, before entering uv_run.
    # This ensures process.nextTick and queueMicrotask callbacks fire before
    # any timer or I/O callbacks (matching Node.js behaviour).
    el_tick(_GLOBAL_EL, _GLOBAL_VM);

    # Step 2: event loop — blocks until all reffed handles close
    uvloop_run_default(_GLOBAL_EL.loop);
    _GLOBAL_EL.running = False;

    # Step 3: flush any final callbacks queued synchronously after last event
    el_tick(_GLOBAL_EL, _GLOBAL_VM);

    # Step 3b: 'beforeExit' — fire when loop drains naturally with code 0 and no pending_exit.
    # Listeners may schedule more async work; if so, re-enter the UV loop.
    # Not fired if process.exit() was explicitly called or an exception occurred.
    el_be_realm: Realm = _GLOBAL_VM.realm;
    if not el_be_realm.pending_exit and not _GLOBAL_VM.had_exception {
        el_be_listeners: list[int] = process_get_before_exit_listeners();
        if len(el_be_listeners) > 0 {
            el_be_code: int = 0;
            el_be_code_v: JSValue = js_object_get(proc_obj, str_intern("exitCode"));
            if jsv_is_int32(el_be_code_v) {
                el_be_code = jsv_to_int32(el_be_code_v);
            } elif jsv_is_double(el_be_code_v) {
                el_be_code = int(jsv_to_double(el_be_code_v));
            }
            if el_be_code == 0 {
                # Fire all beforeExit listeners
                el_be_code_jsv: JSValue = js_int(el_be_code);
                el_be_args: list[JSValue] = [];
                el_be_args.append(el_be_code_jsv);
                el_be_fi: int = 0;
                while el_be_fi < len(el_be_listeners) {
                    vm_call_js_fn(
                        _GLOBAL_VM,
                        el_be_listeners[el_be_fi],
                        js_undefined(),
                        el_be_args
                    );
                    el_be_fi = el_be_fi + 1;
                }
                # If listeners scheduled new work, re-enter the UV loop
                el_tick(_GLOBAL_EL, _GLOBAL_VM);
                el_rerun: int = uvloop_run_nowait(_GLOBAL_EL.loop);
                if el_rerun != 0 {
                    _GLOBAL_EL.running = True;
                    uvloop_run_default(_GLOBAL_EL.loop);
                    _GLOBAL_EL.running = False;
                    el_tick(_GLOBAL_EL, _GLOBAL_VM);
                }
            }
        }
    }

    # Step 4: close the wakeup handle + drain its close callback + close loop
    uvasync_close(_GLOBAL_EL.async_hdl);
    uvloop_run_nowait(_GLOBAL_EL.loop);  # drain the close callback
    uvloop_close(_GLOBAL_EL.loop);

    # If an uncaught exception occurred during async execution, exit with 1.
    # Determine final exit code: pending_exit wins over exception wins over exitCode property.
    el_final_realm: Realm = _GLOBAL_VM.realm;
    el_final_code: int = 0;
    if el_final_realm.pending_exit {
        el_final_code = el_final_realm.pending_exit_code;
        _fire_exit_listeners(el_final_code);
        if el_final_realm.pending_exit {
            el_final_code = el_final_realm.pending_exit_code;
        }
        process_do_exit(el_final_code);
    } elif _GLOBAL_VM.had_exception {
        el_final_code = 1;
        _fire_exit_listeners(el_final_code);
        process_do_exit(el_final_code);
    }

    # Natural process exit should honor process.exitCode when present.
    exit_code_v: JSValue = js_object_get(proc_obj, str_intern("exitCode"));
    if jsv_is_int32(exit_code_v) {
        el_final_code = jsv_to_int32(exit_code_v);
    } elif jsv_is_double(exit_code_v) {
        el_final_code = int(jsv_to_double(exit_code_v));
    }
    # --unhandled-rejections=warn-with-error-code: a warned rejection makes a clean exit 1.
    if el_final_code == 0 and process_get_rejection_error_code() {
        el_final_code = 1;
    }
    _fire_exit_listeners(el_final_code);
    return el_final_code;
}
