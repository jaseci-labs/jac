"""A call follows the calling module's own declaration of a C symbol.

Two modules may declare one C symbol differently: `&mut ptr[T]` in one,
`ptr[ptr[T]]` in another, both the same C `T **`. Every declaration the
program holds was lowered into one plan per symbol and the last one won, so
a module passing a pointer it holds could have the address of its local
passed instead (JacPython's type_module and _PyUnicode_InternMortal).
"""
import ctypes;
import from tests.support { compile_native, get_func }

test "a plain pointer argument reaches a Jac-defined C symbol as declared" {
    (engine, _) = compile_native("clib_decl_clash.jac");
    via_ptr = get_func(engine, "via_ptr", ctypes.c_int64, ctypes.c_void_p);
    cell = ctypes.c_void_p(4096);
    assert via_ptr(ctypes.addressof(cell)) == 2;
    assert cell.value is None;
}
