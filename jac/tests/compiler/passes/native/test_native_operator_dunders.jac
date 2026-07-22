"""Behavioral tests for operator-overload dispatch on archetypes (#7626 B3).

Binary operators on archetype operands lower as static dunder calls:
the left operand's magic method resolves through the MRO (the same walk
class patterns use); when the left type has no matching dunder, the
right operand's reflected form dispatches with swapped operands.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
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

test "operator dunder: a + b dispatches __add__" {
    (eng, _) = compile_native("operator_dunders.na.jac");
    f = get_func(eng, "add_vecs", ctypes.c_int64);
    assert f() == 3142 , "Vec(1,2) + Vec(30,40) == Vec(31,42)";
}

test "operator dunder: a * k dispatches __mul__" {
    (eng, _) = compile_native("operator_dunders.na.jac");
    f = get_func(eng, "mul_vec", ctypes.c_int64);
    assert f() == 1520 , "Vec(3,4) * 5 == Vec(15,20)";
}

test "operator dunder: reflected __radd__ dispatches with swapped operands" {
    (eng, _) = compile_native("operator_dunders.na.jac");
    f = get_func(eng, "radd_vec", ctypes.c_int64);
    assert f() == 1314 , "Tag(10) + Vec(3,4) == Vec(13,14) via Vec.__radd__";
}

test "operator dunder: inherited __add__ resolves through the MRO" {
    (eng, _) = compile_native("operator_dunders.na.jac");
    f = get_func(eng, "inherited_add", ctypes.c_int64);
    assert f() == 809 , "Vec3(7,8) + Vec(1,1) == Vec(8,9)";
}
