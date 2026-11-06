"""A function-pointer field of a C struct is callable whatever its types.

`Callable[[], int]` names no sized C type, so the field typed as `any` and a
call through it did not lower (the launcher's PyApi table:
`PyInitConfig_Create`). The field is the C function type, its unsized parts
the C defaults, as for a C declaration."""

import ctypes;
import from tests.support { compile_native, get_func }

test "a call through an unsized function-pointer field lowers" {
    (engine, _) = compile_native("clib_untyped_fn_field.jac");
    call_fields = get_func(engine, "call_fields", ctypes.c_int64, ctypes.c_int64);
    assert call_fields(8) == 50;
}
