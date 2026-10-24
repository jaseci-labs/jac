"""`&mut x` lends x's address when the C symbol is defined in Jac.

A module may declare a C function with a `&mut T` parameter while another
module of the same program defines that symbol in Jac. The call is then lowered
to the Jac definition, and `&mut x` used to pass x's value: the definition
stored through address 0 (an out-variable never read again) or into a copy (one
reassigned afterwards).
"""
import ctypes;
import from tests.support { compile_native, get_func }

test "&mut through a C declaration reaches a Jac-defined symbol by address" {
    (engine, _) = compile_native("clib_mut_lend.jac");
    store_unread = get_func(engine, "store_unread", ctypes.c_int64);
    store_reassigned = get_func(
        engine, "store_reassigned", ctypes.c_int64, ctypes.c_int64
    );
    assert store_unread() == 1;
    assert store_reassigned(7) == 42;
}
