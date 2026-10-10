"""
TimerEntry type definition — shared by vm/timers.na.jac and realm.na.jac.

Does NOT import runtime.realm (that would create a cycle).
Does NOT define _TIMERS — that stays in timers.na.jac.
"""

import from engine.src.runtime.jsvalue { JSValue }
import from engine.src.ffi.libuv { UVHandle }


# ═══════════════════════════════════════════════════════════════════════════════
# TimerEntry
# ═══════════════════════════════════════════════════════════════════════════════

"""
A single active timer.

  id        — unique timer ID returned by setTimeout/setInterval
  callback  — the JS function (closure JSValue) to call when the timer fires
  args      — extra arguments to pass to the callback
  handle    — libuv UVHandle wrapping uv_timer_t
  handle_ptr — raw pointer (int) for fast lookup in C callback
  repeat       — True for setInterval, False for setTimeout/setImmediate
  is_immediate — True for setImmediate (reported as "Immediate" by getActiveResourcesInfo)
  cleared      — True after clearTimeout/clearInterval — prevents firing
  refd         — False after Timeout.unref(); unreffed timers do not keep uv_run alive
"""
obj:pub TimerEntry {
    has id: int = 0,
        callback: JSValue = 0,
        args: list[JSValue] = [],
        handle: UVHandle = UVHandle(),
        handle_ptr: int = 0,
        repeat: bool = False,
        is_immediate: bool = False,
        cleared: bool = False,
        refd: bool = True;
}
