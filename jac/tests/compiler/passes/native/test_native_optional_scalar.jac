"""Behavioral tests for tagged scalar optionals (#7626 C5).

`int | None` lowers as a JacOptional {tag, payload} value instead of
silently collapsing to a bare int (where None was indistinguishable from
0). Pins return/assign/param seams and `is None` tag reads, matching the
Python backend: use_pick (6, -1), opt_local (5, -1), use_opt_param
(7, -5).
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

test "scalar optional: fn returning int|None distinguishes None from 0" {
    (eng, _) = compile_native("optional_scalar.na.jac");
    f = get_func(eng, "use_pick", ctypes.c_int64, ctypes.c_int64);
    assert f(3) == 6 , "pick(3) == 6 through the optional";
    assert f(0) == -1 , "pick(0) is None -- NOT 0";
}

test "scalar optional: int|None local assigns None and a value" {
    (eng, _) = compile_native("optional_scalar.na.jac");
    f = get_func(eng, "opt_local", ctypes.c_int64, ctypes.c_int64);
    assert f(4) == 5 , "x = 4 then x + 1";
    assert f(0) == -1 , "x stays None";
}

test "scalar optional: int|None parameter passes None and a value" {
    (eng, _) = compile_native("optional_scalar.na.jac");
    f = get_func(eng, "use_opt_param", ctypes.c_int64, ctypes.c_int64);
    assert f(7) == 7 , "value flows through the optional param";
    assert f(0) == -5 , "explicit None selects the alternative";
}
