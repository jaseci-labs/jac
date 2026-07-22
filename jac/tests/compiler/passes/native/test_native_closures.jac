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

test "adapter: map with a capturing lambda callback" {
    (eng, _) = compile_native("closures_adapters.na.jac");
    f = get_func(eng, "scale_all", ctypes.c_int64, ctypes.c_int64);
    assert f(3) == 18 , "3+6+9";
    assert f(0) == 0;
}

test "adapter: filter with a capturing lambda predicate" {
    (eng, _) = compile_native("closures_adapters.na.jac");
    f = get_func(eng, "keep_over", ctypes.c_int64, ctypes.c_int64);
    assert f(4) == 14 , "5+9";
    assert f(0) == 18 , "1+5+9+3";
}

test "adapter: stored closure value drives map" {
    (eng, _) = compile_native("closures_adapters.na.jac");
    f = get_func(eng, "map_stored_closure", ctypes.c_int64, ctypes.c_int64);
    assert f(7) == 44 , "(10+7)+(20+7)";
}

test "adapter: named nested closure passed to map by name" {
    (eng, _) = compile_native("closures_adapters.na.jac");
    f = get_func(eng, "map_named_capture", ctypes.c_int64, ctypes.c_int64);
    assert f(10) == 50 , "20+30";
}

test "adapter: capturing filter chained into capturing map" {
    (eng, _) = compile_native("closures_adapters.na.jac");
    f = get_func(
        eng, "filter_then_map", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64
    );
    assert f(3, 2) == 14 , "(3+4)*2";
}

test "frame scan: closure escaping an event-method frame" {
    (eng, _) = compile_native("closures_frames.na.jac");
    f = get_func(eng, "event_frame_escape", ctypes.c_int64, ctypes.c_int64);
    assert f(3) == 30 , "here.val captured, f(10) = 10*3";
}

test "frame scan: closure escaping a no-signature method frame" {
    (eng, _) = compile_native("closures_frames.na.jac");
    f = get_func(eng, "nosig_frame_escape", ctypes.c_int64, ctypes.c_int64);
    assert f(9) == 109 , "base captured, f(100) = 100+9";
}

test "frame scan: lambda escaping a global initializer" {
    (eng, _) = compile_native("closures_frames.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "globinit_lambda", ctypes.c_int64, ctypes.c_int64);
    assert f(5) == 15;
}

test "frame scan: lambda escaping the module entry frame" {
    (eng, _) = compile_native("closures_frames.na.jac");
    entry_fn = get_func(eng, "jac_entry", None);
    entry_fn();
    f = get_func(eng, "entry_frame_escape", ctypes.c_int64);
    assert f() == 8 , "entry-frame lambda called through the list, f(1) = 1+7";
}

test "entry lambda reading an entry-assigned name lowers as a global read" {
    # Python treats `with entry` assignments as module globals; the native
    # backend now registers entry-block assignment targets as module globals
    # (#7626 A1), so a lambda there reads them like any `glob` -- no more
    # frame-local E5092. Behavioral parity is pinned in
    # test_native_entry_globals.jac.
    prog = compile_na_inline(
        "entry_local_lambda",
        "glob acc: list[int] = [];\n"
        "with entry {\n"
        "    k = 7;\n"
        "    fns: list[Callable[[int], int]] = [lambda (x: int) -> int { x + k; }];\n"
        "    f = fns[0];\n"
        "    acc.append(f(1));\n"
        "}\n"
    );
    assert not prog.errors_had , (
        f"entry lambda over an entry-assigned name should lower natively, got: "
        f"{[str(e) for e in prog.errors_had]}"
    );
}
