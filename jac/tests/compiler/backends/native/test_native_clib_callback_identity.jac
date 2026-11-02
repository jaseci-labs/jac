"""A Jac def used as a C function pointer has one address.

C compares function pointers for identity: CPython's subtype_dealloc walks
the bases while `tp_dealloc == subtype_dealloc`. A def declared without
`-> T` returns a word while the C slot it fills says void, and each C-typed
use used to get its own trampoline, so the slot and `ptr(f)` differed and
that walk never ended.
"""
import ctypes;
import from tests.support { compile_native, get_func }

test "a callback slot and ptr(f) agree on a def's and a C function's address" {
    (eng, _) = compile_native("clib_callback_identity.jac");
    for name in [
        "stored_slot_matches",
        "table_slot_matches",
        "stored_c_function_matches"
    ] {
        assert get_func(eng, name, ctypes.c_int64)() == 1 , (
            f"{name}: the slot and ptr(f) hold different addresses"
        );
    }
}
