"""Behavioral tests for variadic parameters (*args / **kwargs) on native.

Graduated from the guardrail ("star-args def is rejected loudly" in
test_native_crash_guards.jac, #7320). The call site materializes the pack:
`*args: T` is a native List of T (List.jacval for `*args: any`) and
`**kwargs: T` a native str-keyed Dict, each passed as one pointer and
released after the call. Shapes the lowering does not cover stay structured
errors: call-site argument unpacking (`f(*xs)` / `f(**d)`), unannotated
variadics, variadic `init`, and def:pub variadics.

Expected values are pinned against CPython (see each fixture wrapper).
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
    path = os.path.join(FIXTURES, f"_varargs_{label}.na.jac");
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

test "varargs: *args sums positional extras" {
    (eng, _) = compile_native("varargs.na.jac");
    f = get_func(eng, "test_sum_all", ctypes.c_int64);
    assert f() == 6 , f"Expected 6, got {f()}";
}

test "varargs: empty *args materializes an empty list" {
    (eng, _) = compile_native("varargs.na.jac");
    f = get_func(eng, "test_sum_empty", ctypes.c_int64);
    assert f() == 0 , f"Expected 0, got {f()}";
}

test "varargs: fixed params bind before the pack" {
    (eng, _) = compile_native("varargs.na.jac");
    f = get_func(eng, "test_mixed", ctypes.c_int64);
    assert f() == 7003 , f"Expected 7003, got {f()}";
}

test "varargs: defaults compose with *args" {
    (eng, _) = compile_native("varargs.na.jac");
    packed = get_func(eng, "test_default_packed", ctypes.c_int64);
    empty = get_func(eng, "test_default_empty", ctypes.c_int64);
    assert packed() == 36 , f"Expected 36, got {packed()}";
    assert empty() == 0 , f"Expected 0, got {empty()}";
}

test "varargs: indexing and len over the pack" {
    (eng, _) = compile_native("varargs.na.jac");
    f = get_func(eng, "test_idx_ends", ctypes.c_int64);
    assert f() == 47 , f"Expected 47, got {f()}";
}

test "varargs: str pack (RC pointer elements)" {
    (eng, _) = compile_native("varargs.na.jac");
    f = get_func(eng, "test_join_lens", ctypes.c_int64);
    assert f() == 5 , f"Expected 5, got {f()}";
}

test "varargs: *args: any boxes heterogeneous values" {
    (eng, _) = compile_native("varargs.na.jac");
    f = get_func(eng, "test_any_pack", ctypes.c_int64);
    assert f() == 3 , f"Expected 3, got {f()}";
}

test "kwargs: **kwargs get and contains" {
    (eng, _) = compile_native("varargs.na.jac");
    hit = get_func(eng, "test_kw_hit", ctypes.c_int64);
    miss = get_func(eng, "test_kw_miss", ctypes.c_int64);
    assert hit() == 4 , f"Expected 4, got {hit()}";
    assert miss() == -1 , f"Expected -1, got {miss()}";
}

test "kwargs: **kwargs iteration sums values" {
    (eng, _) = compile_native("varargs.na.jac");
    f = get_func(eng, "test_kw_sum", ctypes.c_int64);
    e = get_func(eng, "test_kw_sum_empty", ctypes.c_int64);
    assert f() == 6 , f"Expected 6, got {f()}";
    assert e() == 0 , f"Expected 0, got {e()}";
}

test "varargs+kwonly+kwargs combined binding" {
    (eng, _) = compile_native("varargs.na.jac");
    mn = get_func(eng, "test_combo_min", ctypes.c_int64);
    rest = get_func(eng, "test_combo_rest", ctypes.c_int64);
    kwonly = get_func(eng, "test_combo_kwonly", ctypes.c_int64);
    full = get_func(eng, "test_combo_full", ctypes.c_int64);
    assert mn() == 100000 , f"Expected 100000, got {mn()}";
    assert rest() == 207000 , f"Expected 207000, got {rest()}";
    assert kwonly() == 207500 , f"Expected 207500, got {kwonly()}";
    assert full() == 102309 , f"Expected 102309, got {full()}";
}

test "varargs: method receives the pack after self" {
    (eng, _) = compile_native("varargs.na.jac");
    f = get_func(eng, "test_method_pack", ctypes.c_int64);
    assert f() == 106 , f"Expected 106, got {f()}";
}

test "varargs: cross-module callee receives the pack" {
    (eng, _) = compile_native("varargs.na.jac");
    f = get_func(eng, "test_xmod_pack", ctypes.c_int64);
    assert f() == 15 , f"Expected 15, got {f()}";
}

test "callsite star-unpack of a LIST into a fixed-arity callee is a loud error" {
    # A list's arity is not statically known, so this stays loud even now
    # that tuple spreads and variadic-callee list spreads lower (#7626 A6).
    # Before wave 2, two(*xs) compiled CLEAN and returned 0 (the star
    # expression lowered to None and both params default-padded).
    prog = compile_na_inline(
        "star_fixed",
        "def two(a: int, b: int) -> int { return a * 10 + b; }\n"
        "def use() -> int { xs = [7, 8]; return two(*xs); }\n"
    );
    assert has_error_code(prog, "E5090") or has_error_code(prog, "E5092") , (
        f"Expected a loud E5090/E5092 for two(*xs), got: "
        f"{[str(e) for e in prog.errors_had]}"
    );
}

test "callsite star-unpack: tuple spread splits into declared params" {
    # #7626 A6: a tuple spread's arity is static, so add3(*xs) lowers by
    # splitting the tuple into the three declared params.
    (eng, _) = compile_native("call_unpack.na.jac");
    f = get_func(eng, "spread_tuple", ctypes.c_int64);
    assert f() == 30201 , "add3(1, 2, 3)";
    g = get_func(eng, "spread_mixed", ctypes.c_int64);
    assert g(1) == 30201 , "add3(1, *(2, 3)) mixes positional and spread";
}

test "callsite star-unpack: list spread routes through a variadic callee" {
    (eng, _) = compile_native("call_unpack.na.jac");
    f = get_func(eng, "spread_variadic", ctypes.c_int64);
    assert f() == 15 , "vsum(*[4, 5, 6])";
}

test "double-star unpack at a call site is a loud error" {
    prog = compile_na_inline(
        "dstar_fixed",
        "def two(a: int, b: int) -> int { return a * 10 + b; }\n"
        "def use() -> int { d = {'a': 1, 'b': 2}; return two(**d); }\n"
    );
    assert has_error_code(prog, "E5090") or has_error_code(prog, "E5092") , (
        f"Expected a loud E5090/E5092 for two(**d), got: "
        f"{[str(e) for e in prog.errors_had]}"
    );
}

test "unannotated variadic parameter is a loud error" {
    prog = compile_na_inline("unannot", "def f(*args) -> int { return 0; }\n");
    assert prog.errors_had , "Expected a loud error for an unannotated *args";
}

test "def:pub variadic stays a loud E5090" {
    prog = compile_na_inline("pubvar", "def:pub f(*args: int) -> int { return 0; }\n");
    assert has_error_code(prog, "E5090") , (
        f"Expected E5090 for a def:pub variadic, got: "
        f"{[str(e) for e in prog.errors_had]}"
    );
}

test "variadic init stays a loud E5090" {
    prog = compile_na_inline(
        "initvar",
        "obj P { has n: int = 0; def init(*vals: int) { self.n = 0; } }\n"
        "def mk() -> int { p = P(); return p.n; }\n"
    );
    assert has_error_code(prog, "E5090") , (
        f"Expected E5090 for a variadic init, got: "
        f"{[str(e) for e in prog.errors_had]}"
    );
}
