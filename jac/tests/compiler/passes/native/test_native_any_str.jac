"""End-to-end tests for native str() on an `any`-boxed scalar (#7498).

`str()` on a value boxed as `any` (e.g. the return of `dict.get` on a
`dict[str, any]`) used to stringify the JacVal type-discriminant tag instead of
unboxing and converting the underlying scalar. These assertions pin the native
(`na`) result to what CPython's `str()` would produce for each scalar kind.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Compile a .na.jac fixture and return the JIT engine."""
def compile_native(fixture: str) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: object, name: str, restype: type | None, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

test "str() on an any-boxed str unboxes to the string" {
    (eng, _) = compile_native("any_str.na.jac");
    f = get_func(eng, "any_str_str", ctypes.c_char_p);
    assert f() == b"hello";
}

test "str() on an any-boxed int unboxes to the decimal value" {
    (eng, _) = compile_native("any_str.na.jac");
    f = get_func(eng, "any_str_int", ctypes.c_char_p);
    assert f() == b"7";
}

test "str() on an any-boxed float unboxes to the float repr" {
    (eng, _) = compile_native("any_str.na.jac");
    f = get_func(eng, "any_str_float", ctypes.c_char_p);
    assert f() == b"1.5";
}

test "str() on an any-boxed bool renders True/False" {
    (eng, _) = compile_native("any_str.na.jac");
    f = get_func(eng, "any_str_bool", ctypes.c_char_p);
    assert f() == b"True";
}

test "str() on an any-boxed None renders \"None\"" {
    (eng, _) = compile_native("any_str.na.jac");
    f = get_func(eng, "any_str_none", ctypes.c_char_p);
    assert f() == b"None";
}
