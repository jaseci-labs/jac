"""Clib vtable struct with fn-ptr slots (issue #6570).

A Jac `def` stored into a `Callable` field of a clib struct must go
through a C-ABI trampoline: the slot's annotation describes the C
signature (here i32-based) while the Jac function uses native i64
parameters. `= 0` slots stay NULL C function pointers.
"""

import from "/usr/lib/libm.so.6" {
    obj event_handler_vt {
        has size: int = 0,
            on_event: Callable[[i32, i32], i32] = 0,
            on_close: Callable[[int], None] = 0;
    }
    def sqrt(x: f64) -> f64;
}

def _on_event(a: int, b: int) -> int {
    return a * 10 + b;
}

def make_handler() -> int {
    h = event_handler_vt(size=24, on_event=_on_event);
    return h.size;
}
