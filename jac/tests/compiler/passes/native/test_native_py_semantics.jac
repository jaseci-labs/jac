"""CPython-parity value-semantics tests for the native pathway (issue
#7320, Cluster 2 silent-wrong-value family).

Each fixture exercises an idiom that previously compiled clean on na but
returned a different value than CPython/sv, with results encoded into a
single i64 so a silent divergence fails an equality assert.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR }
import jaclang;
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

# --- 2a: chained comparisons lower every link, not just the first ---
test "chained comparison: every link is evaluated and ANDed" {
    (eng, _) = compile_native("py_chain_cmp.na.jac");
    get_func(eng, "jac_entry", None)();
    cases = get_func(eng, "chain_cases", ctypes.c_int64);
    result = cases();
    # a=0 (2<3<1), b=1, c=1, d=1, e=0, f=1, g=1
    assert result == 111011 , f"Expected 111011, got {result}";
}

test "chained comparison: middle operand evaluated exactly once" {
    (eng, _) = compile_native("py_chain_cmp.na.jac");
    get_func(eng, "jac_entry", None)();
    once = get_func(eng, "middle_evaluated_once", ctypes.c_int64);
    result = once();
    assert result == 11 , f"Expected 11 (true, one bump), got {result}";
}

test "chained comparison: three-link chain with mixed directions" {
    (eng, _) = compile_native("py_chain_cmp.na.jac");
    get_func(eng, "jac_entry", None)();
    chain = get_func(eng, "long_chain", ctypes.c_int64);
    result = chain();
    assert result == 1 , f"Expected 1 (1<2<3>2), got {result}";
}
