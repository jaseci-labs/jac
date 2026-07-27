"""Behavioral tests for native structural match patterns (#7593 item 7).

Sequence, mapping, star, and class (MatchArch) patterns lower to native
LLVM IR. Expected values are pinned against real CPython `match`
semantics (see fixtures/match_patterns.na.jac).
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

"""Compile a snippet through the FRONT-END check schedule (`jac check` path:
type_check on, codegen off) so check-time capability behavior is pinned."""
def check_na_inline(label: str, code: str) -> JacProgram {
    path = os.path.join(FIXTURES, f"_check_{label}.na.jac");
    prog = JacProgram();
    prog.compile(file_path=path, use_str=code, type_check=True, no_cgen=True);
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

test "match sequence dispatches on length" {
    (eng, _) = compile_native("match_patterns.na.jac");
    f = get_func(eng, "seq_lengths", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 0;
    assert f(1) == 1;
    assert f(2) == 2;
    assert f(5) == -1;
}

test "match sequence literal and capture arms" {
    (eng, _) = compile_native("match_patterns.na.jac");
    f = get_func(eng, "seq_fixed", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(1, 2) == 1;
    assert f(3, 4) == 7;
}

test "match star binds head and rest slice" {
    (eng, _) = compile_native("match_patterns.na.jac");
    f = get_func(eng, "seq_star_head", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == -1;
    assert f(1) == 1000;
    assert f(3) == 1002;
}

test "match star binds init and last" {
    (eng, _) = compile_native("match_patterns.na.jac");
    f = get_func(eng, "seq_star_tail", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == -1;
    assert f(1) == 1000;
    assert f(3) == 1202;
}

test "match star between head and tail binds the middle" {
    (eng, _) = compile_native("match_patterns.na.jac");
    f = get_func(eng, "seq_star_mid", ctypes.c_int64, ctypes.c_int64);
    assert f(1) == -1;
    assert f(2) == 1110;
    assert f(4) == 1312;
}

test "match mapping probes keys and binds values" {
    (eng, _) = compile_native("match_patterns.na.jac");
    f = get_func(eng, "map_probe", ctypes.c_int64, ctypes.c_int64);
    assert f(0) == 1;
    assert f(1) == 3;
}

test "match mapping falls through on a missing key" {
    (eng, _) = compile_native("match_patterns.na.jac");
    f = get_func(eng, "map_missing", ctypes.c_int64);
    assert f() == -1;
}

test "match mapping rest collects unmatched entries" {
    (eng, _) = compile_native("match_patterns.na.jac");
    f = get_func(eng, "map_rest", ctypes.c_int64);
    assert f() == 102;
}

test "match class pattern binds fields by keyword" {
    (eng, _) = compile_native("match_patterns.na.jac");
    f = get_func(eng, "arch_kw", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(3, 4) == 34;
}

test "match class pattern binds fields by position" {
    (eng, _) = compile_native("match_patterns.na.jac");
    f = get_func(eng, "arch_pos", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(5, 6) == 56;
}

test "match class pattern dispatches subclass via vtable" {
    (eng, _) = compile_native("match_patterns.na.jac");
    f = get_func(eng, "arch_subtype", ctypes.c_int64, ctypes.c_int64);
    assert f(1) == 9 , "Sub instance must hit the Sub arm";
    assert f(0) == 7 , "Base instance must NOT hit the Sub arm";
}

test "nested sequence patterns recurse" {
    (eng, _) = compile_native("match_patterns.na.jac");
    hit = get_func(eng, "nested_seq", ctypes.c_int64);
    miss = get_func(eng, "nested_seq_miss", ctypes.c_int64);
    assert hit() == 6;
    assert miss() == -1 , "inner length mismatch must fall through";
}

test "match guard runs after structural binding" {
    (eng, _) = compile_native("match_patterns.na.jac");
    f = get_func(eng, "seq_guard", ctypes.c_int64, ctypes.c_int64, ctypes.c_int64);
    assert f(5, 1) == 1;
    assert f(1, 5) == 2;
}

test "structural match patterns no longer raise E5090 at check time" {
    prog = check_na_inline(
        "match_structural_ok",
        "obj Pt { has x: int, y: int; }\n"
        "def f(a: int, b: int) -> int {\n"
        "    xs: list[int] = [a, b];\n"
        "    match xs {\n"
        "        case [1, 2]: return 1;\n"
        "        case [x, *rest]: return (x as int) + len((rest as list[int]));\n"
        "        case _: return 0;\n"
        "    }\n"
        "}\n"
        "def g(k: int) -> int {\n"
        "    d: dict[str, int] = {\"a\": 1};\n"
        "    match d {\n"
        "        case {\"a\": v}: return (v as int) + k;\n"
        "        case _: return -1;\n"
        "    }\n"
        "}\n"
        "def h(px: int) -> int {\n"
        "    p = Pt(x=px, y=0);\n"
        "    match p {\n"
        "        case Pt(x=a, y=b): return (a as int);\n"
        "        case _: return -1;\n"
        "    }\n"
        "}\n"
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not has_error_code(prog, "E5090") , (
        f"structural patterns must pass the capability check: {errors}"
    );
}
