"""Crash-family regression tests for the native pathway (issue #7320,
Cluster 3).

Each fixture exercises an idiom that previously segfaulted, corrupted
the heap, hung, or returned garbage on na while working on sv/CPython.
Results encode multiple sub-cases into single i64s via the ctypes JIT
harness.
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

# --- Slice semantics: negative bounds, clamping, steps ---
test "str slices: negative bounds, clamping, and steps match CPython" {
    (eng, _) = compile_native("py_slices.na.jac");
    get_func(eng, "jac_entry", None)();
    fn = get_func(eng, "str_slices", ctypes.c_int64);
    result = fn();
    assert result == 11111111 , f"Expected 11111111 (all 8 cases), got {result}";
}

test "list slices: negative bounds, clamping, and steps match CPython" {
    (eng, _) = compile_native("py_slices.na.jac");
    get_func(eng, "jac_entry", None)();
    fn = get_func(eng, "list_slices", ctypes.c_int64);
    result = fn();
    assert result == 111111 , f"Expected 111111 (all 6 cases), got {result}";
}

test "slice with zero step raises instead of looping" {
    (eng, _) = compile_native("py_slices.na.jac");
    get_func(eng, "jac_entry", None)();
    fn = get_func(eng, "slice_zero_step_raises", ctypes.c_int64);
    result = fn();
    assert result == 1 , f"Expected 1 (caught ValueError), got {result}";
}

# --- String edge cases: negative repeat, empty-needle count ---
test "str repeat with a negative count yields empty, not heap corruption" {
    (eng, _) = compile_native("py_str_edge.na.jac");
    get_func(eng, "jac_entry", None)();
    fn = get_func(eng, "repeat_negative", ctypes.c_int64);
    result = fn();
    assert result == 1111 , f"Expected 1111, got {result}";
}

test "str count with an empty needle returns len+1, not a hang" {
    (eng, _) = compile_native("py_str_edge.na.jac");
    get_func(eng, "jac_entry", None)();
    fn = get_func(eng, "count_empty_needle", ctypes.c_int64);
    result = fn();
    # count('a') = 2, count('') = 7
    assert result == 207 , f"Expected 207, got {result}";
}

# --- Custom exception subclasses carry their fields ---
test "exception subclass fields survive raise and catch" {
    (eng, _) = compile_native("py_exc_subclass.na.jac");
    get_func(eng, "jac_entry", None)();
    fn = get_func(eng, "subclass_field_roundtrip", ctypes.c_int64);
    result = fn();
    # line_no 42 and hint intact
    assert result == 421 , f"Expected 421, got {result}";
}

test "base except handler still sees a readable message for struct raises" {
    (eng, _) = compile_native("py_exc_subclass.na.jac");
    get_func(eng, "jac_entry", None)();
    fn = get_func(eng, "base_handler_message", ctypes.c_int64);
    result = fn();
    assert result == 1 , f"Expected 1 (str(e) is the type name), got {result}";
}
