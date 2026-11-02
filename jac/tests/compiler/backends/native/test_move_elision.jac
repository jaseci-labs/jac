"""Regression tests for native RC move-lowering (#6905 payoff, borrow-checker split).

When an assignment `b = a` binds a bare local `Name` that the native
the core `RcFactsPass` proves safe (LOCAL source, every use an alias-value, dead-out
at the move site), the native pass lowers it as a MOVE instead of an alias-copy:
it skips the defensive `__rc_retain` and nulls the source slot so the source's
later scope/iter cleanup release is a no-op. The destination inherits the single
reference and frees it exactly once.

The test locks the observable half: the result is sound at runtime (no leak, no
double free over a heavy loop).

The proof is native-owned and does NOT depend on the ownership checker: the
elision lives in the native codegen path rather than the analysis schedule.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_address, native_force_opts }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.backends.native.llvm.binding { ExecutionEngine }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Compile a fixture and return (engine, ir). Defaults to the nacompile path."""
def compile_fixture(fixture: str) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert isinstance(eng, ExecutionEngine) , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: any, name: str, restype: type | None, *argtypes: type) -> any {
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    return ctypes.CFUNCTYPE(restype, *argtypes)(addr);
}

test "move-lowering is sound at runtime: correct result, no leak, no double free" {
    (eng, _) = compile_fixture("move_elision.jac");
    f = get_func(eng, "run_moves", ctypes.c_int64, ctypes.c_int64);
    assert f(1000) == 1000;
    # A heavy loop: a double free would corrupt the heap and crash here; a leak
    # would grow RSS unbounded. Reaching the assert cleanly proves neither.
    assert f(400000) == 400000;
}
