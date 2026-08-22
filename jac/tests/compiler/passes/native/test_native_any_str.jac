"""End-to-end tests for native str() on an `any`-boxed scalar (#7498).

`str()` on a value boxed as `any` (e.g. the return of `dict.get` on a
`dict[str, any]`) used to stringify the JacVal type-discriminant tag instead of
unboxing and converting the underlying scalar. These assertions pin the native
(`na`) result to what CPython's `str()` would produce for each scalar kind.

This file intentionally recompiles the fixture per test, matching the native
suite's isolation convention and keeping each JIT engine local to its test.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_force_opts, native_str_func }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     ),
     FIXTURE = "any_str.jac";


def _compile(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine for {fixture}";
    return (eng, ir);
}


test "str() on an any-boxed str unboxes to the string" {
    (eng, _) = _compile(FIXTURE);
    f = native_str_func(eng, "any_str_str", ctypes.c_char_p);
    assert f() == b"hello";
}

test "str() on an any-boxed int unboxes to the decimal value" {
    (eng, _) = _compile(FIXTURE);
    f = native_str_func(eng, "any_str_int", ctypes.c_char_p);
    assert f() == b"7";
}

test "str() on an any-boxed float unboxes to the float repr" {
    (eng, _) = _compile(FIXTURE);
    f = native_str_func(eng, "any_str_float", ctypes.c_char_p);
    assert f() == b"1.5";
}

test "str() on an any-boxed bool renders True/False" {
    (eng, _) = _compile(FIXTURE);
    f = native_str_func(eng, "any_str_bool", ctypes.c_char_p);
    assert f() == b"True";
}

test "str() on an any-boxed None renders \"None\"" {
    (eng, _) = _compile(FIXTURE);
    f = native_str_func(eng, "any_str_none", ctypes.c_char_p);
    assert f() == b"None";
}
