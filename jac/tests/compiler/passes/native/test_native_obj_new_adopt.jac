"""Native lowering of the `T.__new__(T)` adopt shell (rust-FFI handle soundness).

A ctor-bearing opaque type that is also a method return is adopted through a
static shell -- `adopted = T.__new__(T); adopted.field = ...; return adopted;` --
that must NOT re-run the real `init`.  NaIRGenPass now lowers `T.__new__(T)` to a
bare zero-filled allocation (vtable + type-tag wired, no init call), and the
external-local field writes on the result store through normally.  These tests
JIT the fixture and confirm the adopt path produces the right handle without
touching the origin, in parity with the plain constructor path.
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

"""Get a ctypes-callable int() function from the JIT engine."""
def get_int_func(eng: object, name: str) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr);
}

test "plain constructor path still runs init" {
    (eng, _) = compile_native("obj_new_adopt.na.jac");
    assert get_int_func(eng, "ctor_handle")() == 7;
}

test "__new__ adopt shell lowers and mints the adopted handle" {
    (eng, _) = compile_native("obj_new_adopt.na.jac");
    # alias() adopts via Cell.__new__(Cell) and writes handle = origin + 100.
    assert get_int_func(eng, "adopt_handle")() == 107;
}

test "adopt shell writes the flag field on the fresh __new__ local" {
    (eng, _) = compile_native("obj_new_adopt.na.jac");
    assert get_int_func(eng, "adopt_is_open")() == 1;
}

test "adopting does not disturb the originating instance" {
    (eng, _) = compile_native("obj_new_adopt.na.jac");
    assert get_int_func(eng, "adopt_leaves_origin")() == 7;
}
