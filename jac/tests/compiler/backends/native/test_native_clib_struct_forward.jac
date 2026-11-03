"""A `&mut` C struct parameter of a Jac function lends the caller's storage.

The callee's writes, and those of the C function it forwards the parameter
to (`pipe2(fds, flags)` in JacPython's posix_fileio), land in the caller's
struct, inside one module and across modules.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "a forwarded &mut C struct parameter is the caller's struct" {
    (eng, _mod) = compile_native("clib_struct_forward.jac");
    for (name, want) in [
        ("direct", 1),
        ("forwarded", 1),
        ("across", 1),
        ("written", 43)
    ] {
        got = get_func(eng, name, ctypes.c_int64)();
        assert got == want , f"{name}() = {got}, want {want}";
    }
}
