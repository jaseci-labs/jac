"""Null (`= 0`) defaults for `Callable` fields (issue #6569).

C callback-based APIs (CEF, libuv) describe vtables as structs whose
function-pointer slots default to NULL. In native code an integer zero
must be accepted where a `Callable[[...], ret]` is expected and lower to
a null C function pointer — both in clib vtable structs and plain native
objects used as dispatch tables.
"""

import from "/usr/lib/libm.so.6" {
    obj handler_vt {
        has size: int = 0,
            on_event: Callable[[int, int], None] = 0;
    }
    def sqrt(x: f64) -> f64;
}

obj Op {
    has tag: int = 0,
        fn: Callable[[int], int] = 0;
}

def op_default_is_null() -> int {
    o = Op();
    return o.fn;
}

def op_slot_reset_to_null(x: int) -> int {
    o = Op(tag=1, fn=double);
    o.fn = 0;
    return o.fn;
}

def vt_default_is_null() -> int {
    h = handler_vt(size=56);
    return h.on_event;
}

def double(x: int) -> int {
    return x * 2;
}
