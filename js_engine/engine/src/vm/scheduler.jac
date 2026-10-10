"""
Microtask & process.nextTick Scheduler.

Implements the two-tier priority queue that matches Node.js / Bun event loop
ordering:

  1. **nextTick queue** — highest priority, drained completely before microtasks.
     Used by `process.nextTick(fn, ...args)`.
  2. **microtask queue** — standard Promise `.then` / `queueMicrotask` callbacks.
     Drained completely after nextTick queue is empty.

Both queues re-drain if new tasks are enqueued during draining (a nextTick
callback may schedule another nextTick, etc.).  A starvation guard limits
each queue to 10 000 drains per el_tick to prevent infinite loops from
starving I/O callbacks.

Architecture
────────────
  - This module imports only from runtime.realm and runtime.jsvalue.
    It does NOT import from engine.src.vm.vm, vm.event_loop, runtime.global, or
    builtins.dispatch.  This avoids the circular dependency chain
    (dispatch → scheduler → vm → dispatch).
  - All public functions receive a `realm: Realm` as their first parameter.
    Queue state lives in Realm fields (next_tick_fns, microtask_fns, etc.)
    rather than module-level globs, enabling per-context isolation.
  - The module exposes accessor functions (same pattern as vm/timers.na.jac).
  - The event loop (vm/event_loop.na.jac) reads the queues via accessor
    functions in el_tick and calls vm_call_js_fn itself.
  - The dispatch module (builtins/dispatch.na.jac) calls scheduler_push_microtask
    and scheduler_push_next_tick from the queueMicrotask and
    process.nextTick native handlers respectively.

Bun reference  : bun/src/bun.js/event_loop/DeferredTaskQueue.zig
                 bun/src/bun.js/JSCScheduler.zig
Node.js spec   : https://nodejs.org/api/process.html#processnexttickcallback-args
ECMAScript     : §9.4 — HostEnqueuePromiseJob
                 https://tc39.es/ecma262/#sec-hostenqueuepromisejob
"""

import from engine.src.runtime.jsvalue { JSValue, js_undefined }
import from engine.src.runtime.realm { Realm }
import from engine.src.builtins.array { js_array_create }

# react_states values: PROMISE_FULFILLED (1), PROMISE_REJECTED (2), MICROTASK_JOB (3)
glob:pub SCHED_REACT_FULFILLED: int = 1,
     SCHED_REACT_REJECTED: int = 2,
     SCHED_REACT_MICROTASK: int = 3;

# ══════════════════════════════════════════════════════════════════════════════
# Enqueueing API  (called from builtins/dispatch.na.jac)
# ══════════════════════════════════════════════════════════════════════════════

"""
Push a callback onto the nextTick queue.

Called by the `process.nextTick(fn, ...args)` dispatch handler.
Matches Node.js `process.nextTick` — fires before microtasks on the next tick.
"""
def:pub scheduler_push_next_tick(realm: Realm, fn: JSValue, args: list[JSValue]) {
    realm.next_tick_fns.append(fn);
    realm.next_tick_args.append(args);
}

"""
Push a callback onto the microtask queue.

Called by the `queueMicrotask(fn)` dispatch handler.
Enqueued on the same FIFO as Promise reactions via `scheduler_push_microtask_job`.
"""
def:pub scheduler_push_microtask(realm: Realm, fn: JSValue, args: list[JSValue]) {
    scheduler_push_microtask_job(realm, fn, args);
}

"""
Append a queueMicrotask job to the unified microtask FIFO (interleaved with Promise jobs).
Uses react_* queues with an empty on_r and PROMISE_FULFILLED state; vm_exec_reaction
dispatches callable jobs when on_f is a function.
"""
def:pub scheduler_push_microtask_job(realm: Realm, fn: JSValue, args: list[JSValue]) {
    realm.react_on_f.append(fn);
    realm.react_on_r.append(js_undefined());
    realm.react_states.append(SCHED_REACT_MICROTASK);
    # Args for microtasks ride react_vals (array) to avoid double-drain via microtask_fns.
    if len(args) > 0 {
        realm.react_vals.append(js_array_create(args));
    } else {
        realm.react_vals.append(js_undefined());
    }
    realm.react_next_p.append(js_undefined());
}

"""
Push a deferred promise reaction onto the reaction queue.

Called by NATIVE_KIND_PROMISE_THEN / NATIVE_KIND_PROMISE_CATCH when the
target promise is already settled.  Deferring via this queue ensures
process.nextTick callbacks (added during the same synchronous turn) fire
before Promise .then callbacks, matching Node.js / Bun semantics.

ECMAScript §9.4.4 PerformPromiseThen — HostEnqueuePromiseJob.
"""
def:pub scheduler_push_reaction(
    realm: Realm,
    on_f: JSValue,
    on_r: JSValue,
    state: int,
    value: JSValue,
    next_p: JSValue
) {
    realm.react_on_f.append(on_f);
    realm.react_on_r.append(on_r);
    realm.react_states.append(state);
    realm.react_vals.append(value);
    realm.react_next_p.append(next_p);
}

# ══════════════════════════════════════════════════════════════════════════════
# Accessor functions for cross-module use  (called from vm/event_loop.na.jac)
# ══════════════════════════════════════════════════════════════════════════════
# Same pattern as vm/timers.na.jac — avoids cross-module glob copy issues.

# ── nextTick queue accessors ─────────────────────────────────────────────────

"""Return the number of pending nextTick callbacks."""
def:pub sched_nt_count(realm: Realm) -> int {
    return len(realm.next_tick_fns);
}

"""Return the i-th nextTick callback function."""
def:pub sched_nt_fn(realm: Realm, i: int) -> JSValue {
    return realm.next_tick_fns[i];
}

"""Return the i-th nextTick callback args."""
def:pub sched_nt_args(realm: Realm, i: int) -> list[JSValue] {
    return realm.next_tick_args[i];
}

"""Remove the first n entries from the nextTick queue.

O(remaining) rebuild instead of repeated `del [0]` (which is O(n) per pop,
i.e. O(n^2) to drain a batch of n)."""
def:pub sched_nt_clear(realm: Realm, n: int) -> None {
    if n <= 0 {
        return;
    }
    nt_fn_kept: list[JSValue] = [];
    nt_arg_kept: list[list[JSValue]] = [];
    nt_i: int = n;
    nt_len: int = len(realm.next_tick_fns);
    while nt_i < nt_len {
        nt_fn_kept.append(realm.next_tick_fns[nt_i]);
        nt_arg_kept.append(realm.next_tick_args[nt_i]);
        nt_i = nt_i + 1;
    }
    realm.next_tick_fns = nt_fn_kept;
    realm.next_tick_args = nt_arg_kept;
}

# ── microtask queue accessors ────────────────────────────────────────────────

"""Return the number of pending microtask callbacks."""
def:pub sched_mt_count(realm: Realm) -> int {
    return len(realm.microtask_fns);
}

"""Return the i-th microtask callback function."""
def:pub sched_mt_fn(realm: Realm, i: int) -> JSValue {
    return realm.microtask_fns[i];
}

"""Return the i-th microtask callback args."""
def:pub sched_mt_args(realm: Realm, i: int) -> list[JSValue] {
    return realm.microtask_args[i];
}

"""Remove the first n entries from the microtask queue.

O(remaining) rebuild instead of repeated `del [0]` (O(n^2) batch drain)."""
def:pub sched_mt_clear(realm: Realm, n: int) -> None {
    if n <= 0 {
        return;
    }
    mt_fn_kept: list[JSValue] = [];
    mt_arg_kept: list[list[JSValue]] = [];
    mt_i: int = n;
    mt_len: int = len(realm.microtask_fns);
    while mt_i < mt_len {
        mt_fn_kept.append(realm.microtask_fns[mt_i]);
        mt_arg_kept.append(realm.microtask_args[mt_i]);
        mt_i = mt_i + 1;
    }
    realm.microtask_fns = mt_fn_kept;
    realm.microtask_args = mt_arg_kept;
}

# ── Deferred reaction queue accessors ───────────────────────────────────────

"""Return the number of pending deferred promise reactions."""
def:pub sched_react_count(realm: Realm) -> int {
    return len(realm.react_on_f);
}

"""Return the on_f handler of the i-th reaction."""
def:pub sched_react_on_f(realm: Realm, i: int) -> JSValue {
    return realm.react_on_f[i];
}

"""Return the on_r handler of the i-th reaction."""
def:pub sched_react_on_r(realm: Realm, i: int) -> JSValue {
    return realm.react_on_r[i];
}

"""Return the promise state of the i-th reaction."""
def:pub sched_react_state(realm: Realm, i: int) -> int {
    return realm.react_states[i];
}

"""Return the resolution value of the i-th reaction."""
def:pub sched_react_val(realm: Realm, i: int) -> JSValue {
    return realm.react_vals[i];
}

"""Return the chained next_p promise of the i-th reaction."""
def:pub sched_react_next_p(realm: Realm, i: int) -> JSValue {
    return realm.react_next_p[i];
}

"""Remove the first n entries from the reaction queue.

O(remaining) rebuild instead of repeated `del [0]` (O(n^2) batch drain)."""
def:pub sched_react_clear(realm: Realm, n: int) -> None {
    if n <= 0 {
        return;
    }
    rf_kept: list[JSValue] = [];
    rr_kept: list[JSValue] = [];
    rs_kept: list[int] = [];
    rv_kept: list[JSValue] = [];
    rn_kept: list[JSValue] = [];
    ri: int = n;
    rlen: int = len(realm.react_on_f);
    while ri < rlen {
        rf_kept.append(realm.react_on_f[ri]);
        rr_kept.append(realm.react_on_r[ri]);
        rs_kept.append(realm.react_states[ri]);
        rv_kept.append(realm.react_vals[ri]);
        rn_kept.append(realm.react_next_p[ri]);
        ri = ri + 1;
    }
    realm.react_on_f = rf_kept;
    realm.react_on_r = rr_kept;
    realm.react_states = rs_kept;
    realm.react_vals = rv_kept;
    realm.react_next_p = rn_kept;
}

# ── Combined query ───────────────────────────────────────────────────────────

"""Return True if either queue has pending work."""
def:pub scheduler_has_pending(realm: Realm) -> bool {
    return len(realm.next_tick_fns) > 0
        or len(realm.microtask_fns) > 0
        or len(realm.react_on_f) > 0;
}
