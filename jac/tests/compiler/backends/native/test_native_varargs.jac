"""Behavioral tests for variadic parameters (*args / **kwargs) on native.

Graduated from the guardrail ("star-args def is rejected loudly" in
test_native_crash_guards.jac, #7320). The call site materializes the pack:
`*args: T` is a native List of T (List.jacval for `*args: any`) and
`**kwargs: T` a native str-keyed Dict, each passed as one pointer and
released after the call. Shapes the lowering does not cover demote their
owning callable to a Python-only seam (def:pub variadics, which a C caller
cannot hand a pack, and since #8234 an `init` that cannot lower, whose
construction sites then refuse), while shapes with no demotable owner at
all stay structured errors (unannotated variadics).

Expected values are pinned against CPython (see each fixture wrapper).

The generic cases at the bottom (#8247) run through a subprocess instead of
the JIT: a pack of a generic archetype's erased type parameter used to lower
without diagnostic and then read the pack pointer as a `str`, so the failure
mode is a segfault, which has to fail the test rather than take the runner
down with it.
"""

import ctypes;
import os;
import from tests.support {
    TESTS_DIR,
    by_source_name,
    compile_native,
    get_func,
    has_error_code,
    native_force_opts,
    sv_run,
    na_run,
    same_lines
}
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
def compile_na_inline_ir(label: str, code: str) -> tuple[any, ...] {
    path = os.path.join(FIXTURES, f"_varargs_{label}.jac");
    prog = JacProgram();
    options = native_force_opts();
    options.no_ir_cache = True;
    options.skip_native_engine = True;
    ir = prog.compile(file_path=path, use_str=code, options=options);
    return (prog, ir, );
}

"""Compile a snippet that must lower cleanly and hand back its JIT engine."""
def compile_native_inline(label: str, code: str) -> tuple[any, ...] {
    path = os.path.join(FIXTURES, f"_varargs_{label}.jac");
    prog = JacProgram();
    ir = prog.compile(file_path=path, use_str=code, options=native_force_opts());
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    assert ir.gen.native_engine is not None , f"no JIT engine for {label}";
    return (ir.gen.native_engine, ir, );
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

test "double-star unpack into fixed parameters stays native" {
    (prog, ir) = compile_na_inline_ir(
        "dstar_fixed",
        "def two(a: int, b: int) -> int { return a * 10 + b; }\n"
        "def use() -> int { d = {'a': 1, 'b': 2}; return two(**d); }\n"
    );
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "two" in layout.functions and "use" in layout.functions , (
        f"a ** spread into fixed parameters binds natively: {list(layout.functions)}"
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

test "a variadic init binds its pack" {
    (eng, _) = compile_native_inline(
        "initvar_lowers",
        "obj P { has n: int = 0; def init(*vals: int) { self.n = len(vals) * 10 + vals[0]; } }\n"
        "def mk() -> int { p = P(4, 5, 6); return p.n; }\n"
    );
    assert get_func(eng, "mk", ctypes.c_int64)() == 34 , "three extras, the first is 4";
}

test "an init that cannot lower demotes the constructor and refuses its callers" {
    (prog, ir) = compile_na_inline_ir(
        "initvar",
        "obj P { has n: int = 0; def init(*vals: int) { self.n = len(memoryview(b'ab')) + len(vals); } }\n"
        "def mk() -> int { p = P(); return p.n; }\n"
        "def pure(x: int) -> int { return x + 1; }\n"
    );
    assert not prog.errors_had , (
        f"a constructor owns its own refusal since #8234, so an init that "
        f"cannot lower demotes instead of refusing the module, got: "
        f"{[str(e) for e in prog.errors_had]}"
    );
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "pure" in layout.functions , (
        f"clean sibling function was lost: {list(layout.functions)}"
    );
    assert "P.init" not in by_source_name(layout.methods) , (
        "the refused init must be demoted out of the native layout"
    );
    assert "mk" not in layout.functions , (
        "constructing through a demoted initializer must refuse, not build a "
        "half-initialized object"
    );
}

test "a pack of a generic archetype's erased T answers what CPython answers" {
    (sv_out, _sv_err) = sv_run(os.path.join(FIXTURES, "varargs_generic.jac"));
    (na_out, _na_err) = na_run(os.path.join(FIXTURES, "varargs_generic.jac"));
    same_lines(sv_out, na_out, "erased pack");
}

test "a generic archetype's variadic methods reach the native image" {
    prog = JacProgram();
    options = native_force_opts();
    options.no_ir_cache = True;
    options.skip_native_engine = True;
    ir = prog.compile(os.path.join(FIXTURES, "varargs_generic.jac"), options=options);
    assert not prog.errors_had , str(prog.errors_had);
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "Cell.get" in by_source_name(layout.methods) , (
        f"the variadic method must reach the native image: {sorted(layout.methods)}"
    );
    assert "Cell.count" in by_source_name(layout.methods) , (
        f"the variadic method must reach the native image: {sorted(layout.methods)}"
    );
    assert "Cell.pick" in by_source_name(layout.methods) , (
        f"a pack after a fixed parameter must lower too: {sorted(layout.methods)}"
    );
}

test "a generic pack at a by-value type argument answers what CPython answers" {
    # The old backend erased `T` to a pointer list, so `Cell[int]` had no sound
    # element slot and was refused. MIR specializes the pack per
    # instantiation, so the by-value pack lowers and must answer as CPython.
    (sv_out, _sv_err) = sv_run(os.path.join(FIXTURES, "varargs_generic_scalar.jac"));
    (na_out, _na_err) = na_run(os.path.join(FIXTURES, "varargs_generic_scalar.jac"));
    same_lines(sv_out, na_out, "by-value pack");
    assert sv_out.strip() == "7" , f"the fixture's answer moved: {sv_out!r}";
}

test "a callee whose pack cannot lay out refuses its caller" {
    # A pack whose element type has no native form refuses its callee, and a
    # call into that callee demotes the caller rather than binding the extras
    # into a slot that is not a pack.
    (prog, ir) = compile_na_inline_ir(
        "packslot",
        "obj Cell[T] { has n: int = 0; def take(*xs: memoryview) -> int { return len(xs); } }\n"
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

test "a generic pack of a nested instantiation binds no extras" {
    (eng, _) = compile_native_inline(
        "packslot_lowers",
        "obj Cell[T] { has n: int = 0; def take(*xs: dict[T, T]) -> int { return len(xs); } }\n"
        "def use() -> int { c = Cell[Cell[int]](); return c.take(); }\n"
        "def two() -> int { c = Cell[int](); return c.take({1: 2}, {3: 4}); }\n"
    );
    assert get_func(eng, "use", ctypes.c_int64)() == 0 , "no extras were passed";
    assert get_func(eng, "two", ctypes.c_int64)() == 2 , "two extras were passed";
}
