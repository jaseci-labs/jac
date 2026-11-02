"""
Timers.

Implements setTimeout, setInterval, clearTimeout, clearInterval,
setImmediate, clearImmediate, and performance.now().

All timer functions schedule callbacks through libuv's uv_timer_t handle.
When a timer fires, the C callback pushes the JS callback + args onto a
module-local **fired queue** (_FIRED_FNS / _FIRED_ARGS) and signals the
event loop's async handle (via uv_async_send on the stored raw pointer).
The event loop (vm/event_loop.na.jac) drains the fired queue in el_tick
and invokes each callback through vm_call_js_fn.

Architecture
────────────
  - Each active timer is stored in _TIMER_REALM.timers (list[TimerEntry]).
  - A monotonically incrementing _TIMER_NEXT_ID provides unique timer IDs.
  - _TIMER_LOOP_PTR / _TIMER_ASYNC_PTR are raw int pointers set once by
    timer_init() — called from el_run before the script executes.  This
    avoids importing vm.event_loop, which would create a circular dep
    (event_loop → global → dispatch → timers → event_loop).
  - The C callback _timer_fire_cb receives the uv_timer_t handle pointer,
    looks up the corresponding TimerEntry by handle pointer, and pushes
    the callback + args into the fired queue.  It then calls uv_async_send
    to wake the event loop so el_tick drains the queue.
  - For setInterval, the uv_timer_t repeat field re-arms the timer
    automatically — no manual restart needed.
  - clearTimeout/clearInterval set `cleared = True` and call uv_timer_stop
    so the handle is deactivated.
  - performance.now() uses uv_hrtime() (nanosecond monotonic clock) / 1e6.

Bun reference:
  bun/src/bun.js/node/time_like.zig   (SetTimeoutObject, SetIntervalObject)
  bun/src/bun.js/api/Timer.zig        (TimerCallback)

Node.js spec:
  https://nodejs.org/api/timers.html

Import constraints:
  This module must NOT import from engine.src.vm.event_loop, runtime.global, vm.vm,
  or builtins.dispatch — any of those would create a circular dependency.
  Only ffi.libuv and runtime.jsvalue are safe.
"""

import from engine.src.ffi.libuv {
    UVLoop,
    UVHandle,
    uvtimer_create,
    uvtimer_start,
    uvtimer_stop,
    uvtimer_close,
    uvasync_send,
    uvhrtime,
    uvhandle_ref,
    uvhandle_unref
}
import from engine.src.runtime.jsvalue { JSValue }
import from engine.src.vm.timer_type { TimerEntry }
import from engine.src.runtime.realm { Realm }

# ══════════════════════════════════════════════════════════════════════════════
# TimerEntry — one active timer
# ══════════════════════════════════════════════════════════════════════════════

"""
Bridge realm singleton — holds timer_next_id, timer_loop_ptr, timer_async_ptr,
fired_fns, fired_args.  Set once by timer_init() at startup.
C callbacks (_timer_fire_cb) use this singleton since they cannot receive
a realm parameter.
"""
glob _TIMER_REALM: Realm;  # starts null; timer_init() must be called before use

# ══════════════════════════════════════════════════════════════════════════════
# Initialisation — called once from el_run in event_loop.na.jac
# ══════════════════════════════════════════════════════════════════════════════

"""
Initialise timer subsystem with event loop pointers.

Must be called before any timer API function.  Receives raw int pointers
to avoid importing EventLoop (which would create a cycle).

  loop_ptr  — UVLoop.loop_ptr from the global EventLoop
  async_ptr — UVHandle.handle_ptr of the EventLoop's wakeup async handle
"""
def:pub timer_init(loop_ptr: int, async_ptr: int, realm: Realm) {
    _TIMER_REALM = realm;
    _TIMER_REALM.timer_loop_ptr = loop_ptr;
    _TIMER_REALM.timer_async_ptr = async_ptr;
}

"""
Return the number of pending fired timer callbacks.
Called by el_tick to decide whether to drain.
"""
def:pub timer_fired_count -> int {
    return len(_TIMER_REALM.fired_fns);
}

"""
Return the i-th fired callback function.
"""
def:pub timer_fired_fn(idx: int) -> JSValue {
    return _TIMER_REALM.fired_fns[idx];
}

"""
Return the i-th fired callback args list.
"""
def:pub timer_fired_args(idx: int) -> list[JSValue] {
    return _TIMER_REALM.fired_args[idx];
}

"""
Remove the first n entries from the fired queues (after draining).

O(remaining) rebuild instead of repeated `del [0]` (O(n^2) batch drain).
"""
def:pub timer_fired_clear(n: int) -> None {
    if n <= 0 {
        return;
    }
    tf_kept: list[JSValue] = [];
    ta_kept: list[list[JSValue]] = [];
    ti: int = n;
    tlen: int = len(_TIMER_REALM.fired_fns);
    while ti < tlen {
        tf_kept.append(_TIMER_REALM.fired_fns[ti]);
        ta_kept.append(_TIMER_REALM.fired_args[ti]);
        ti = ti + 1;
    }
    _TIMER_REALM.fired_fns = tf_kept;
    _TIMER_REALM.fired_args = ta_kept;
}

# ══════════════════════════════════════════════════════════════════════════════
# C callback — fired by libuv when a uv_timer_t expires
# ══════════════════════════════════════════════════════════════════════════════

"""
libuv calls this function when any timer handle fires.

Signature: void (*uv_timer_cb)(uv_timer_t *handle)

We receive the raw handle pointer, look up the corresponding TimerEntry
in _TIMER_REALM.timers, and — if not cleared — push the callback + args onto the
module-local fired queue.  Then call uv_async_send to wake the event loop
so el_tick drains the queue.

For one-shot timers (setTimeout/setImmediate) we also stop and close the
handle.
"""
def _timer_fire_cb(handle_ptr: int) -> None {
    i: int = 0;
    while i < len(_TIMER_REALM.timers) {
        t_entry: TimerEntry = _TIMER_REALM.timers[i];
        if t_entry.handle_ptr == handle_ptr {
            if not t_entry.cleared {
                # Push onto the fired queue — el_tick will drain it
                _TIMER_REALM.fired_fns.append(t_entry.callback);
                _TIMER_REALM.fired_args.append(t_entry.args);

                if not t_entry.repeat {
                    # One-shot timer: stop and close the handle
                    t_entry.cleared = True;
                    uvtimer_stop(t_entry.handle);
                    uvtimer_close(t_entry.handle);
                }

                # Wake the event loop so el_tick runs
                ah: UVHandle = UVHandle();
                ah.handle_ptr = _TIMER_REALM.timer_async_ptr;
                uvasync_send(ah);
            }
            return;
        }
        i = i + 1;
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# Public API — called from call_native dispatch
# ══════════════════════════════════════════════════════════════════════════════

"""
setTimeout(fn, delay_ms, ...extra_args) -> timer_id

Allocates a uv_timer_t, starts it as a one-shot timer with the given delay
(in milliseconds).  Returns a numeric timer ID that can be passed to
clearTimeout() to cancel it before it fires.

Node.js spec: https://nodejs.org/api/timers.html#settimeoutcallback-delay-args
Bun Zig: SetTimeoutObject in time_like.zig
"""
def:pub timer_set_timeout(
    fn: JSValue, delay_ms: int, extra_args: list[JSValue]
) -> int {
    tid: int = _TIMER_REALM.timer_next_id;
    _TIMER_REALM.timer_next_id = _TIMER_REALM.timer_next_id + 1;

    lp: UVLoop = UVLoop();
    lp.loop_ptr = _TIMER_REALM.timer_loop_ptr;
    h: UVHandle = uvtimer_create(lp);

    t_entry: TimerEntry = TimerEntry();
    t_entry.id = tid;
    t_entry.callback = fn;
    t_entry.args = extra_args;
    t_entry.handle = h;
    t_entry.handle_ptr = h.handle_ptr;
    t_entry.repeat = False;
    t_entry.cleared = False;
    _TIMER_REALM.timers.append(t_entry);
    _TIMER_REALM.timers_mark_epoch.append(0);  # A2.2b GC mark bitmap

    # Start one-shot timer: repeat=0 means fire once
    uvtimer_start(h, _timer_fire_cb, delay_ms, 0);

    return tid;
}

"""
clearTimeout(id) -> None

Stops and closes the timer handle associated with the given timer ID.
If the timer has already fired or been cleared, this is a no-op.

Node.js spec: https://nodejs.org/api/timers.html#cleartimeouttimeout
"""
def:pub timer_clear_timeout(tid: int) -> None {
    i: int = 0;
    while i < len(_TIMER_REALM.timers) {
        t_entry: TimerEntry = _TIMER_REALM.timers[i];
        if t_entry.id == tid and not t_entry.cleared {
            t_entry.cleared = True;
            uvtimer_stop(t_entry.handle);
            uvtimer_close(t_entry.handle);
            return;
        }
        i = i + 1;
    }
}

"""
setInterval(fn, delay_ms, ...extra_args) -> timer_id

Like setTimeout but the timer fires repeatedly every delay_ms milliseconds
until clearInterval is called.

Node.js spec: https://nodejs.org/api/timers.html#setintervalcallback-delay-args
Bun Zig: SetIntervalObject in time_like.zig
"""
def:pub timer_set_interval(
    fn: JSValue, delay_ms: int, extra_args: list[JSValue]
) -> int {
    tid: int = _TIMER_REALM.timer_next_id;
    _TIMER_REALM.timer_next_id = _TIMER_REALM.timer_next_id + 1;

    lp: UVLoop = UVLoop();
    lp.loop_ptr = _TIMER_REALM.timer_loop_ptr;
    h: UVHandle = uvtimer_create(lp);

    t_entry: TimerEntry = TimerEntry();
    t_entry.id = tid;
    t_entry.callback = fn;
    t_entry.args = extra_args;
    t_entry.handle = h;
    t_entry.handle_ptr = h.handle_ptr;
    t_entry.repeat = True;
    t_entry.cleared = False;
    _TIMER_REALM.timers.append(t_entry);
    _TIMER_REALM.timers_mark_epoch.append(0);  # A2.2b GC mark bitmap

    # Start repeating timer: repeat=delay_ms means re-arm after each fire
    uvtimer_start(h, _timer_fire_cb, delay_ms, delay_ms);

    return tid;
}

"""
clearInterval(id) -> None

Identical to clearTimeout — stops and closes the interval timer.

Node.js spec: https://nodejs.org/api/timers.html#clearintervaltimeout
"""
def:pub timer_clear_interval(tid: int) {
    timer_clear_timeout(tid);
}

"""
setImmediate(fn, ...extra_args) -> timer_id

Schedules fn to fire at the end of the current event loop iteration
(implemented as a 0ms one-shot timer).

Node.js spec: https://nodejs.org/api/timers.html#setimmediatecallback-args
"""
def:pub timer_set_immediate(fn: JSValue, extra_args: list[JSValue]) -> int {
    tid: int = _TIMER_REALM.timer_next_id;
    _TIMER_REALM.timer_next_id = _TIMER_REALM.timer_next_id + 1;

    lp: UVLoop = UVLoop();
    lp.loop_ptr = _TIMER_REALM.timer_loop_ptr;
    h: UVHandle = uvtimer_create(lp);

    t_entry: TimerEntry = TimerEntry();
    t_entry.id = tid;
    t_entry.callback = fn;
    t_entry.args = extra_args;
    t_entry.handle = h;
    t_entry.handle_ptr = h.handle_ptr;
    t_entry.repeat = False;
    t_entry.is_immediate = True;
    t_entry.cleared = False;
    _TIMER_REALM.timers.append(t_entry);
    _TIMER_REALM.timers_mark_epoch.append(0);

    uvtimer_start(h, _timer_fire_cb, 0, 0);
    return tid;
}

"""
Return type-name strings for active (uncleared) timers — used by
process.getActiveResourcesInfo(). Node reports "Timeout" for setTimeout/
setInterval and "Immediate" for setImmediate.
"""
def:pub timer_active_resource_types -> list[str] {
    out: list[str] = [];
    i: int = 0;
    while i < len(_TIMER_REALM.timers) {
        t_entry: TimerEntry = _TIMER_REALM.timers[i];
        if not t_entry.cleared {
            if t_entry.is_immediate {
                out.append("Immediate");
            } else {
                out.append("Timeout");
            }
        }
        i = i + 1;
    }
    return out;
}

"""
clearImmediate(id) -> None

Cancels an immediate scheduled by setImmediate.

Node.js spec: https://nodejs.org/api/timers.html#clearimmediateimmediate
"""
def:pub timer_clear_immediate(tid: int) {
    timer_clear_timeout(tid);
}

"""
Timeout.unref() — timer no longer keeps the event loop alive (Node.js timers API).
"""
def:pub timer_unref(tid: int) -> None {
    i: int = 0;
    while i < len(_TIMER_REALM.timers) {
        t_entry: TimerEntry = _TIMER_REALM.timers[i];
        if t_entry.id == tid and not t_entry.cleared and t_entry.refd {
            t_entry.refd = False;
            uvhandle_unref(t_entry.handle);
            return;
        }
        i = i + 1;
    }
}

"""
Timeout.ref() — re-reference a timer so it keeps the event loop alive again.
"""
def:pub timer_ref(tid: int) -> None {
    i: int = 0;
    while i < len(_TIMER_REALM.timers) {
        t_entry: TimerEntry = _TIMER_REALM.timers[i];
        if t_entry.id == tid and not t_entry.cleared and not t_entry.refd {
            t_entry.refd = True;
            uvhandle_ref(t_entry.handle);
            return;
        }
        i = i + 1;
    }
}

"""
performance.now() -> float (milliseconds since process start)

Uses libuv's uv_hrtime() which returns nanoseconds from a monotonic clock.
We convert to milliseconds (float) matching the W3C performance.now() API.

W3C reference: https://www.w3.org/TR/hr-time-3/#dom-performance-now
"""
def:pub timer_performance_now -> float {
    ns: int = uvhrtime();
    # Convert nanoseconds to milliseconds as a float
    ms: float = ns * 1.0 / 1000000.0;
    return ms;
}
