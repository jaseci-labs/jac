"""Behavioral tests for nested-function closure captures on native.

Graduated from the guardrail (`nested function capturing an enclosing local
is rejected` in test_native_feature_guardrail.jac). For direct calls in the
defining frame, read-only captures bind by value at each call and rebound
captures bind as a pointer to the enclosing frame's slot so writes
propagate. A capturing closure used as a VALUE (returned, stored, passed)
lowers via closure conversion: captured variables of the frame promote to
RC heap cells (Python cell semantics) and the closure becomes an RC
{fn, env} pair whose env keeps the cells alive after the frame dies. The
remaining unsupported shapes (a capture borrowed from an outer frame, a
call through an `any`-typed value) stay structured E5092 errors, never a
silently mis-bound value.
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

"""Compile a snippet through the native pipeline and return the program."""
def compile_na_inline(label: str, code: str) -> JacProgram {
    path = os.path.join(FIXTURES, f"_closure_{label}.na.jac");
    prog = JacProgram();
    prog.compile(file_path=path, use_str=code);
    return prog;
}

"""Return True if the program emitted at least one alert with the given code."""
def has_error_code(prog: JacProgram, code: str) -> bool {
    for alrt in prog.errors_had {
        if alrt.code is not None and alrt.code.code == code {
            return True;
        }
    }
    return False;
}

test "closure: nested def reads an enclosing param" {
    (eng, _) = compile_native("closures.na.jac");
    f = get_func(eng, "scaled", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(4, 5) == 20;
    assert f(0, 9) == 0;
}

test "closure: read captures are late-bound (py backend parity)" {
    (eng, _) = compile_native("closures.na.jac");
    f = get_func(eng, "late_bound", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    # r1 = 10 + a (before rebind), r2 = 10 + b (after rebind).
    assert f(2, 7) == 12017;
}

test "closure: rebound capture writes through to the enclosing frame" {
    (eng, _) = compile_native("closures.na.jac");
    f = get_func(eng, "rebind_out", ctypes.c_int64, ctypes.c_int64);
    # total = 0; bump(5) twice writes through: total == 10.
    assert f(5) == 10;
}

test "closure: RC pointer capture (str) reads without double release" {
    (eng, _) = compile_native("closures.na.jac");
    f = get_func(eng, "str_capture", ctypes.c_int64, ctypes.c_char_p);
    assert f(b"abcd") == 8;
}

test "closure: capturing lambda in the same frame keeps working" {
    (eng, _) = compile_native("closures.na.jac");
    f = get_func(eng, "lam_parity", ctypes.c_int64, ctypes.c_int64);
    assert f(6) == 18;
}

test "closure: self-recursive nested def forwards its own captures" {
    (eng, _) = compile_native("closures.na.jac");
    f = get_func(eng, "recursive_capture", ctypes.c_int64, ctypes.c_int64);
    # depth increments through the shared slot on every recursion level.
    assert f(3) == 4;
}

test "closure escape: counter factory returns a live closure" {
    (eng, _) = compile_native("closures_escape.na.jac");
    f = get_func(eng, "use_counter", ctypes.c_int64);
    assert f() == 3;
}

test "closure escape: two factory closures have independent cells" {
    (eng, _) = compile_native("closures_escape.na.jac");
    f = get_func(eng, "two_counters_independent", ctypes.c_int64);
    assert f() == 32;
}

test "closure escape: closure passed as argument writes through" {
    (eng, _) = compile_native("closures_escape.na.jac");
    f = get_func(eng, "pass_closure", ctypes.c_int64, ctypes.c_int64);
    assert f(10) == 16016;
}

test "closure escape: closure stored in a list and called later" {
    (eng, _) = compile_native("closures_escape.na.jac");
    f = get_func(eng, "stored_in_list", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(40, 2) == 42;
}

test "closure escape: two closures share one rebound cell" {
    (eng, _) = compile_native("closures_escape.na.jac");
    f = get_func(eng, "shared_cell", ctypes.c_int64);
    assert f() == 1;
}

test "closure escape: env keeps an RC capture alive after the frame dies" {
    (eng, _) = compile_native("closures_escape.na.jac");
    f = get_func(eng, "use_greeter", ctypes.c_int64);
    assert f() == 8;
}

test "closure escape: capturing lambda escapes as a value" {
    (eng, _) = compile_native("closures_escape.na.jac");
    f = get_func(eng, "lambda_escape", ctypes.c_int64, ctypes.c_int64);
    assert f(7) == 124;
    g = get_func(eng, "use_adder", ctypes.c_int64);
    assert g() == 23;
}

test "closure escape: capture borrowed from an outer frame stays rejected" {
    prog = compile_na_inline(
        "transitive_escape",
        "def outer(y: int) -> Callable[[], int] {\n"
        "    def mid -> Callable[[], int] {\n"
        "        def inner -> int { return y; }\n"
        "        return inner;\n"
        "    }\n"
        "    return mid();\n"
        "}\n"
    );
    assert has_error_code(prog, "E5092") , (
        f"expected E5092 for a closure escaping with an outer-frame capture, "
        f"got: {[str(e) for e in prog.errors_had]}"
    );
}

test "closure escape: calling a closure through an any-typed value stays rejected" {
    prog = compile_na_inline(
        "any_closure_call",
        "def outer(y: int) -> int {\n"
        "    def inner(x: int) -> int { return x * y; }\n"
        "    f: any = inner;\n"
        "    return f(3);\n"
        "}\n"
    );
    assert has_error_code(prog, "E5092") , (
        f"expected E5092 for an any-typed closure call site, got: "
        f"{[str(e) for e in prog.errors_had]}"
    );
}
