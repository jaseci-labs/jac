"""
runtime/gc_pin.na.jac — GC pin registry (leaf module).

Values registered here are treated as GC roots by gc_mark_roots and never
collected. This lives in its own leaf module (imports only jsvalue) so that
ANY module can pin its glob-held singletons without creating an import cycle
through runtime/gc.na.jac.

GC invariant: a module-level `glob` holding a JSValue is INVISIBLE to the
collector — the mark phase cannot enumerate Jac globals. Every glob that
stores a heap cell (object/closure) past the current opcode MUST
gc_pin_value() it at assignment, or the referent is swept while live
(lazy-singleton prototypes are the classic case: %ArrayIteratorPrototype%
is referenced only by its glob between iterations).
"""

import from engine.src.runtime.jsvalue { JSValue }

glob _gc_pinned: list[JSValue] = [];

"""Pin a JSValue so it is treated as a GC root and never collected.
Call once per value that must outlive the normal root set (module exports,
glob-held singletons). Re-pinning a replaced value leaks the old pin — fine
for bootstrap singletons, use gc_unpin_value for churning values."""
def:pub gc_pin_value(v: JSValue) {
    _gc_pinned.append(v);
}

"""Remove one occurrence of v from the GC pin list.  No-op if not pinned."""
def:pub gc_unpin_value(v: JSValue) -> None {
    i: int = 0;
    n: int = len(_gc_pinned);
    while i < n {
        if _gc_pinned[i] == v {
            del _gc_pinned[i];
            return;
        }
        i = i + 1;
    }
}

"""The current pin list (read by gc_mark_roots; do not mutate)."""
def:pub gc_pinned_list -> list[JSValue] {
    return _gc_pinned;
}

# ── Awaited-promise roots (suspended async frames) ───────────────────────────
# When `await P` suspends an async function, the frame is snapshotted into a
# JSGeneratorState and P gets a resume reaction holding only the frame's integer
# index — nothing GC-visible references P. In JS an awaited promise stays live
# until it settles; here P was only kept alive incidentally by whoever created
# it, so a chain of pending promises (e.g. rollup's this.resolve for ~60 sibling
# imports) could have an intermediate P swept mid-flight, dropping its resume
# reaction → the frame never resumes → rollup's "Promises ... cannot resolve"
# early exit. Root P here keyed by the frame index; drop it when the frame
# resumes (both fulfil and reject go through _resume_async_frame). Keyed (not a
# flat list) so re-suspends and out-of-order settles delete the right entry.
glob _gc_await_roots: dict[int, JSValue] = {};

"""Root the promise a suspended async frame (index `idx`) is awaiting."""
def:pub gc_await_root_add(idx: int, p: JSValue) {
    _gc_await_roots[idx] = p;
}

"""Drop the awaited-promise root for a resumed/abandoned frame index."""
def:pub gc_await_root_del(idx: int) {
    if idx in _gc_await_roots {
        del _gc_await_roots[idx];
    }
}

"""The awaited-promise root map (read by gc_mark_roots; do not mutate)."""
def:pub gc_await_roots_map -> dict[int, JSValue] {
    return _gc_await_roots;
}

# Registered LIVE lists: the list reference is held here and its CURRENT
# contents are traced at every mark. Use for glob callback queues whose
# contents churn (pending timers/fs/net callbacks) — pin-at-append would leak
# every value ever queued.
glob _gc_pinned_lists: list[list[JSValue]] = [];

"""Register a glob list[JSValue] as a permanent GC root (contents traced live).
Call ONCE per glob list, at module init."""
def:pub gc_pin_live_list(l: list[JSValue]) {
    _gc_pinned_lists.append(l);
}

"""All registered live root lists (read by gc_mark_roots; do not mutate)."""
def:pub gc_pinned_live_lists -> list[list[JSValue]] {
    return _gc_pinned_lists;
}
