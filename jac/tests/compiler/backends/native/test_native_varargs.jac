"""Behavioral tests for variadic parameters (*args / **kwargs) on native.

Graduated from the guardrail ("star-args def is rejected loudly" in
test_native_crash_guards.jac, #7320). The call site materializes the pack:
`*args: T` is a native List of T (List.jacval for `*args: any`) and
`**kwargs: T` a native str-keyed Dict, each passed as one pointer and
released after the call. Shapes the lowering does not cover demote their
owning callable to a Python-only seam (call-site argument unpacking
`f(*xs)` / `f(**d)`, def:pub variadics, and since #8234 a variadic `init`,
whose construction sites then refuse), while shapes with no demotable
owner at all stay structured errors (unannotated variadics).

Expected values are pinned against CPython (see each fixture wrapper).

The generic cases at the bottom (#8247) run through a subprocess instead of
the JIT: a pack of a generic archetype's erased type parameter used to lower
without diagnostic and then read the pack pointer as a `str`, so the failure
mode is a segfault, which has to fail the test rather than take the runner
down with it.
"""

import ctypes;
import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR, compile_native, get_func, has_error_code, native_force_opts, unit_symbol }
import jaclang;

import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Compile a snippet through the native pipeline and return the program."""
def compile_na_inline(label: str, code: str) -> JacProgram {
    path = os.path.join(FIXTURES, f"_varargs_{label}.jac");
    prog = JacProgram();
    prog.compile(file_path=path, use_str=code, options=native_force_opts());
    return prog;
}

"""Like `compile_na_inline`, but also hand back the compiled module so a
granular demotion (epic #8201) is observable through the native layout."""
def compile_na_inline_ir(label: str, code: str) -> tuple {
    path = os.path.join(FIXTURES, f"_varargs_{label}.jac");
    prog = JacProgram();
    ir = prog.compile(file_path=path, use_str=code, options=native_force_opts());
    return (prog, ir, );
}

"""Run a fixture on the server pathway, where CPython is the oracle."""
def sv_run(fixture: str) -> str {
    proc = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", os.path.join(FIXTURES, fixture)],
        capture_output=True,
        text=True,
        timeout=900
    );
    assert proc.returncode == 0 , f"sv run failed: {proc.stderr[-800:]
        if proc.stderr
        else '(empty)'}";
    return proc.stdout;
}

"""Build a fixture into a binary and run it, so a crash is a test failure."""
def na_run(fixture: str) -> str {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "nacompile",
            os.path.join(FIXTURES, fixture),
            "-o",
            out_bin
        ],
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , f"nacompile failed: {comp.stderr[-800:]
        if comp.stderr
        else '(empty)'}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , (
        f"native binary exited {proc.returncode} "
        f"(a negative code is a signal, i.e. a crash): {proc.stderr[-400:]
            if proc.stderr
            else '(empty)'}"
    );
    return proc.stdout;
}

def same_lines(sv_text: str, na_text: str, what: str) {
    sv = [
        _l
        for _l in sv_text.split("\n")
        if _l.strip()
    ];
    na = [
        _l
        for _l in na_text.split("\n")
        if _l.strip()
    ];
    assert sv , f"{what}: sv pathway produced no output";
    assert len(sv) == len(na) , f"{what} line count: sv {len(sv)} vs na {len(na)}";
    for idx in range(len(sv)) {
        assert sv[idx] == na[idx] , f"{what} line {idx}: sv {sv[idx]!r} vs na {na[
            idx
        ]!r}";
    }
}

test "varargs: *args sums positional extras" {
    (eng, _) = compile_native("varargs.jac");
    f = get_func(eng, "test_sum_all", ctypes.c_int64);
    assert f() == 6 , f"Expected 6, got {f()}";
}

test "varargs: empty *args materializes an empty list" {
    (eng, _) = compile_native("varargs.jac");
    f = get_func(eng, "test_sum_empty", ctypes.c_int64);
    assert f() == 0 , f"Expected 0, got {f()}";
}

test "varargs: fixed params bind before the pack" {
    (eng, _) = compile_native("varargs.jac");
    f = get_func(eng, "test_mixed", ctypes.c_int64);
    assert f() == 7003 , f"Expected 7003, got {f()}";
}

test "varargs: defaults compose with *args" {
    (eng, _) = compile_native("varargs.jac");
    packed = get_func(eng, "test_default_packed", ctypes.c_int64);
    empty = get_func(eng, "test_default_empty", ctypes.c_int64);
    assert packed() == 36 , f"Expected 36, got {packed()}";
    assert empty() == 0 , f"Expected 0, got {empty()}";
}

test "varargs: indexing and len over the pack" {
    (eng, _) = compile_native("varargs.jac");
    f = get_func(eng, "test_idx_ends", ctypes.c_int64);
    assert f() == 47 , f"Expected 47, got {f()}";
}

test "varargs: str pack (RC pointer elements)" {
    (eng, _) = compile_native("varargs.jac");
    f = get_func(eng, "test_join_lens", ctypes.c_int64);
    assert f() == 5 , f"Expected 5, got {f()}";
}

test "varargs: *args: any boxes heterogeneous values" {
    (eng, _) = compile_native("varargs.jac");
    f = get_func(eng, "test_any_pack", ctypes.c_int64);
    assert f() == 3 , f"Expected 3, got {f()}";
}

test "kwargs: **kwargs get and contains" {
    (eng, _) = compile_native("varargs.jac");
    hit = get_func(eng, "test_kw_hit", ctypes.c_int64);
    miss = get_func(eng, "test_kw_miss", ctypes.c_int64);
    assert hit() == 4 , f"Expected 4, got {hit()}";
    assert miss() == -1 , f"Expected -1, got {miss()}";
}

test "kwargs: **kwargs iteration sums values" {
    (eng, _) = compile_native("varargs.jac");
    f = get_func(eng, "test_kw_sum", ctypes.c_int64);
    e = get_func(eng, "test_kw_sum_empty", ctypes.c_int64);
    assert f() == 6 , f"Expected 6, got {f()}";
    assert e() == 0 , f"Expected 0, got {e()}";
}

test "varargs+kwonly+kwargs combined binding" {
    (eng, _) = compile_native("varargs.jac");
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
    (eng, _) = compile_native("varargs.jac");
    f = get_func(eng, "test_method_pack", ctypes.c_int64);
    assert f() == 106 , f"Expected 106, got {f()}";
}

test "varargs: cross-module callee receives the pack" {
    (eng, _) = compile_native("varargs.jac");
    f = get_func(eng, "test_xmod_pack", ctypes.c_int64);
    assert f() == 15 , f"Expected 15, got {f()}";
}

test "callsite star-unpack of a LIST into a fixed-arity callee demotes the caller" {
    # A list's arity is not statically known, so this stays refused even now
    # that tuple spreads and variadic-callee list spreads lower (#7626 A6).
    # Before wave 2, two(*xs) compiled CLEAN and returned 0 (the star
    # expression lowered to None and both params default-padded); the
    # refusal now demotes use() to its Python implementation instead of
    # failing the whole module.
    (prog, ir) = compile_na_inline_ir(
        "star_fixed",
        "def two(a: int, b: int) -> int { return a * 10 + b; }\n"
        "def use() -> int { xs = [7, 8]; return two(*xs); }\n"
    );
    assert not prog.errors_had , (
        f"two(*xs) is owned by use(), which must demote to a seam, got: "
        f"{[str(e) for e in prog.errors_had]}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "two" in layout.functions , (
        f"clean sibling function was lost: {list(layout.functions)}"
    );
    assert "use" not in layout.functions , (
        "the unpacking caller must be demoted out of the native layout"
    );
}

test "callsite star-unpack: tuple spread splits into declared params" {
    # #7626 A6: a tuple spread's arity is static, so add3(*xs) lowers by
    # splitting the tuple into the three declared params.
    (eng, _) = compile_native("call_unpack.jac");
    f = get_func(eng, "spread_tuple", ctypes.c_int64);
    assert f() == 30201 , "add3(1, 2, 3)";
    g = get_func(eng, "spread_mixed", ctypes.c_int64);
    assert g(1) == 30201 , "add3(1, *(2, 3)) mixes positional and spread";
}

test "callsite star-unpack: list spread routes through a variadic callee" {
    (eng, _) = compile_native("call_unpack.jac");
    f = get_func(eng, "spread_variadic", ctypes.c_int64);
    assert f() == 15 , "vsum(*[4, 5, 6])";
}

test "double-star unpack at a call site demotes the calling function" {
    (prog, ir) = compile_na_inline_ir(
        "dstar_fixed",
        "def two(a: int, b: int) -> int { return a * 10 + b; }\n"
        "def use() -> int { d = {'a': 1, 'b': 2}; return two(**d); }\n"
    );
    assert not prog.errors_had , (
        f"two(**d) is owned by use(), which must demote to a seam, got: "
        f"{[str(e) for e in prog.errors_had]}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "two" in layout.functions , (
        f"clean sibling function was lost: {list(layout.functions)}"
    );
    assert "use" not in layout.functions , (
        "the unpacking caller must be demoted out of the native layout"
    );
}

test "unannotated variadic parameter is a loud error" {
    prog = compile_na_inline("unannot", "def f(*args) -> int { return 0; }\n");
    assert prog.errors_had , "Expected a loud error for an unannotated *args";
}

test "def:pub variadic demotes off the native interop surface" {
    (prog, ir) = compile_na_inline_ir(
        "pubvar", "def:pub f(*args: int) -> int { return 0; }\n"
    );
    assert not prog.errors_had , (
        f"the interop bridge cannot marshal a parameter pack, so the pub "
        f"variadic must demote to its Python implementation, got: "
        f"{[str(e) for e in prog.errors_had]}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "f" not in layout.functions , (
        "the pub variadic must be demoted out of the native layout"
    );
}

test "variadic init demotes the constructor and refuses its callers" {
    (prog, ir) = compile_na_inline_ir(
        "initvar",
        "obj P { has n: int = 0; def init(*vals: int) { self.n = 0; } }\n"
        "def mk() -> int { p = P(); return p.n; }\n"
        "def pure(x: int) -> int { return x + 1; }\n"
    );
    assert not prog.errors_had , (
        f"a constructor owns its own capability violation since #8234, so a "
        f"variadic init demotes instead of refusing the module, got: "
        f"{[str(e) for e in prog.errors_had]}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "pure" in layout.functions , (
        f"clean sibling function was lost: {list(layout.functions)}"
    );
    assert "P.init" not in layout.methods , (
        "the variadic init must be demoted out of the native layout"
    );
    assert "mk" not in layout.functions , (
        "constructing through a demoted initializer must refuse, not build a "
        "half-initialized object"
    );
}

test "a pack of a generic archetype's erased T answers what CPython answers" {
    same_lines(
        sv_run("varargs_generic.jac"), na_run("varargs_generic.jac"), "erased pack"
    );
}

test "a generic pack slot is a native list, not the bare erased pointer" {
    (eng, ir) = compile_native("varargs_generic.jac");
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "Cell.get" in layout.methods , (
        f"the variadic method must reach the native image: {sorted(layout.methods)}"
    );
    assert "Cell.count" in layout.methods , (
        f"the variadic method must reach the native image: {sorted(layout.methods)}"
    );
    assert "Cell.pick" in layout.methods , (
        f"a pack after a fixed parameter must lower too: {sorted(layout.methods)}"
    );
    text = str(ir.gen.llvm_ir);
    assert f'define i8* @"{unit_symbol(ir, "Cell.get")}"(%"Cell"* %"self", %"List.ptr"* %"fallback")'
        in text , (
        "the pack slot must lay out as the pointer-flavoured native list; a bare "
        "i8* there is the erased element leaking into the pack's own slot"
    );
}

test "a generic pack at a by-value type argument is refused, not lowered" {
    out_bin = os.path.join(tempfile.mkdtemp(), "nope.bin");
    comp = subprocess.run(
        [
            sys.executable,
            "-m",
            "jaclang",
            "nacompile",
            os.path.join(FIXTURES, "varargs_generic_scalar.jac"),
            "-o",
            out_bin
        ],
        capture_output=True,
        text=True,
        timeout=900
    );
    combined = (comp.stdout or "") + (comp.stderr or "");
    assert comp.returncode != 0 , (
        f"an int in a pointer-element pack compiled silently: {combined[-600:]}"
    );
    assert "Cell[int]" in combined , (
        f"diagnostic does not name the instantiation: {combined[-600:]}"
    );
}

test "a callee whose pack slot did not lay out refuses its caller" {
    (prog, ir) = compile_na_inline_ir(
        "packslot",
        "obj Cell[T] { has n: int = 0; def take(*xs: dict[T, T]) -> int { return 0; } }\n"
        "def use() -> int { c = Cell[Cell[int]](); return c.take(); }\n"
        "def pure(x: int) -> int { return x + 1; }\n"
    );
    assert not prog.errors_had , (
        f"the caller owns the refusal, so the module must still compile: "
        f"{[str(e) for e in prog.errors_had]}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "pure" in layout.functions , (
        f"clean sibling function was lost: {list(layout.functions)}"
    );
    assert "use" not in layout.functions , (
        "binding the extras into a slot that is not a pack is a silent misread; "
        "the caller must demote instead"
    );
}
