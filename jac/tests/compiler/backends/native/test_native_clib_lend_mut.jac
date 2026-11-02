"""`&mut x` lends the address of x even when the C declaration that fixed
the symbol's ABI takes a plain `ptr[ptr[T]]`: dict.jac defines PyDict_Pop
that way while cpython_api.jac declares the parameter `&mut T | None`, and
the whole-program plan follows the definition. Passing x's value instead left
`metaclass=` unread in __build_class__. An obj lent with `&mut` hands over its
own storage."""
import ctypes;
import from tests.support { compile_native, get_func }

test "an &mut argument to a plain pointer parameter lends the variable's address" {
    (eng, _) = compile_native("clib_lend_mut.jac");
    assert get_func(eng, "lend_run", ctypes.c_int64)() == 1 , (
        "the callee must have written through the lent variable's address"
    );
    assert get_func(eng, "lend_box_run", ctypes.c_int64)() == 42 , (
        "an obj lent with &mut must hand the callee its own storage"
    );
}
