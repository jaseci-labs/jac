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
import from tests.support {
    TESTS_DIR,
    KernelFixture,
    compile_mir,
    compile_native,
    get_func,
    kernel_compile_source,
    native_build_fails,
    native_force_opts,
    sv_run,
    na_run,
    same_lines,
    write_case
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Compile a snippet through the kernel into the native codespace and return
its compile result."""
def compile_na_inline(label: str, code: str) -> any {
    return kernel_compile_source(code, f"_varargs_{label}.jac", native_force_opts());
}

"""Compile a snippet through the kernel and return the decision step's
verdict on it: a granular demotion (epic #8201) is observable in its demoted
set."""
def compile_na_inline_mir(label: str, code: str) -> KernelFixture {
    return compile_mir(write_case(code, f"_varargs_{label}.jac"));
}

"""The MIR text of `name`'s function in a compiled fixture."""
def mir_function(fx: KernelFixture, name: str) -> str {
    head = f"fn @{fx.symbol(name)}(";
    for chunk in fx.mir().split("\n\n") {
        if chunk.startswith(head) {
            return chunk;
        }
    }
    raise AssertionError(f"no MIR function {name} in {fx.path}: demoted {fx.demoted()}");
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
    fx = compile_na_inline_mir(
        "star_fixed",
        "def two(a: int, b: int) -> int { return a * 10 + b; }\n"
        "def use() -> int { xs = [7, 8]; return two(*xs); }\n"
    );
    assert not fx.is_demoted("two") , (
        f"clean sibling function was lost: {fx.demoted()}"
    );
    assert fx.is_demoted("use") , (
        f"the unpacking caller must be demoted: {fx.demoted()}"
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
    fx = compile_na_inline_mir(
        "dstar_fixed",
        "def two(a: int, b: int) -> int { return a * 10 + b; }\n"
        "def use() -> int { d = {'a': 1, 'b': 2}; return two(**d); }\n"
    );
    assert not fx.is_demoted("two") and not fx.is_demoted("use") , (
        f"a ** spread into fixed parameters binds natively: {fx.demoted()}"
    );
}

test "unannotated variadic parameter is a loud error" {
    result = compile_na_inline("unannot", "def f(*args) -> int { return 0; }\n");
    assert not result.ok() , "Expected a loud error for an unannotated *args";
}

test "def:pub variadic demotes off the native interop surface" {
    fx = compile_na_inline_mir(
        "pubvar", "def:pub f(*args: int) -> int { return 0; }\n"
    );
    assert fx.is_demoted("f") , (
        f"the interop bridge cannot marshal a parameter pack, so the pub "
        f"variadic must demote to its Python implementation: {fx.demoted()}"
    );
}

test "variadic init demotes the constructor and refuses its callers" {
    # A constructor owns its own capability violation since #8234, so a
    # variadic init demotes instead of refusing the module.
    fx = compile_na_inline_mir(
        "initvar",
        "obj P { has n: int = 0; def init(*vals: int) { self.n = 0; } }\n"
        "def mk() -> int { p = P(); return p.n; }\n"
        "def pure(x: int) -> int { return x + 1; }\n"
    );
    assert not fx.is_demoted("pure") , (
        f"clean sibling function was lost: {fx.demoted()}"
    );
    assert fx.reason("P.init") == "function 'variadic or keyword-only parameters'" , (
        f"the variadic init must be refused for its signature: {fx.demoted()}"
    );
    assert fx.is_demoted("mk") , (
        "constructing through a demoted initializer must refuse, not build a "
        f"half-initialized object: {fx.demoted()}"
    );
}

test "a pack of a generic archetype's erased T answers what CPython answers" {
    (sv_out, _sv_err) = sv_run(os.path.join(FIXTURES, "varargs_generic.jac"));
    (na_out, _na_err) = na_run(os.path.join(FIXTURES, "varargs_generic.jac"));
    same_lines(sv_out, na_out, "erased pack");
}

test "a generic pack slot is a native list, not the bare erased pointer" {
    fx = compile_mir("varargs_generic.jac");
    for name in ("Cell.get", "Cell.count", "Cell.pick") {
        assert not fx.is_demoted(name) , (
            f"the variadic method {name} must reach the native image: {fx.demoted()}"
        );
    }
    header = mir_function(fx, "Cell.get").split("\n")[0];
    assert "%fallback: list<" in header , (
        "the pack slot must lay out as a native list; an erased type variable "
        f"there is the element leaking into the pack's own slot: {header}"
    );
}

test "a generic pack at a by-value type argument is refused, not lowered" {
    combined = native_build_fails(os.path.join(FIXTURES, "varargs_generic_scalar.jac"));
    assert "Cell[int]" in combined , (
        f"diagnostic does not name the instantiation: {combined[-600:]}"
    );
}

test "a callee whose pack slot did not lay out refuses its caller" {
    fx = compile_na_inline_mir(
        "packslot",
        "obj Cell[T] { has n: int = 0; def take(*xs: dict[T, T]) -> int { return 0; } }\n"
        "def use() -> int { c = Cell[Cell[int]](); return c.take(); }\n"
        "def pure(x: int) -> int { return x + 1; }\n"
    );
    assert not fx.is_demoted("pure") , (
        f"clean sibling function was lost: {fx.demoted()}"
    );
    assert fx.is_demoted("use") , (
        "binding the extras into a slot that is not a pack is a silent misread; "
        f"the caller must demote instead: {fx.demoted()}"
    );
}
