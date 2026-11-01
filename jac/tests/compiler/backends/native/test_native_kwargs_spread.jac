"""`**` spread lowers into a callee's `**kwargs` sink and binds named params.

Native already lowered the declaration half of kwargs: a callee with a
`**kwargs` sink gets a trailing dict slot in its native signature, and a call
site's leftover *literal* keywords are collected into that dict at compile
time. The spread operand is merged into the sink
with an index loop over the source dict, reusing the same len/get_key/
get_val primitives dict iteration already uses.

A spread key that names a *keyword-bindable declared parameter* follows
CPython binding semantics at runtime: it binds the slot when unbound,
raises TypeError when the slot is already bound (positionally, by literal
keyword, or by an earlier spread), and a required slot no spread supplies
raises TypeError. Bound keys never reach the sink. Only the truly dynamic
shape stays statically refused: a spread at a callee with no sink, where
unmatched keys would have nowhere to go, demotes the calling function to
its Python implementation (a granular seam, epic #8201).

Refs #8039
"""

import ctypes;
import from pathlib { Path }
import from tests.support {
    compile_mir,
    compile_native,
    diagnostics_text,
    fixture_path,
    get_func,
    has_error_code,
    kernel_check_source,
    kernel_compile_file,
    native_force_opts,
    unit_symbol,
    write_case
}
import from jaclang.compiler.driver.compile_options { CompileOptions }

"""Run a snippet through the check entry with the native capability authority
on -- the `jac check` path that surfaces E5090."""
def check_na_inline(label: str, code: str) -> any {
    return kernel_check_source(
        code, f"kwspread_{label}.jac", CompileOptions(force_codespace="native")
    );
}

"""Write a snippet as its own module; return its path."""
def inline_case(label: str, code: str) -> Path {
    return Path(write_case(code, f"kwspread_{label}.jac"));
}

# sink() encodes both arity and identity: base + 100*len(kw), then +1000 / +2000
# / +4000 for keys "p" / "q" / "r". A count-only check would pass even if the
# merge inserted the wrong keys, so every expectation below pins the key set.

test "literal keywords still fill the sink (no regression)" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "call_literal_kwargs", ctypes.c_int64, ctypes.c_int64);
    # p, q -> 10 + 200 + 1000 + 2000
    assert f(10) == 3210 , f"got {f(10)}";
}

test "a forwarded **kwargs reaches the inner sink with its keys intact" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "call_forwarded", ctypes.c_int64, ctypes.c_int64);
    # p, r -> 10 + 200 + 1000 + 4000
    assert f(10) == 5210 , f"got {f(10)}";
}

test "a plain dict spreads into the sink" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "call_spread_dict", ctypes.c_int64, ctypes.c_int64);
    # p, q, r -> 10 + 300 + 1000 + 2000 + 4000
    assert f(10) == 7310 , f"got {f(10)}";
}

test "a spread merges with literal keywords at the same call site" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "call_spread_plus_literal", ctypes.c_int64, ctypes.c_int64);
    # q literal + r spread -> 10 + 200 + 2000 + 4000
    assert f(10) == 6210 , f"got {f(10)}";
}

test "spreading an empty dict yields an empty sink" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "call_spread_empty", ctypes.c_int64, ctypes.c_int64);
    assert f(10) == 10 , f"got {f(10)}";
}

test "the spread fixture compiles with no native diagnostics" {
    result = kernel_compile_file(fixture_path("kwargs_spread.jac"), native_force_opts());
    assert result.ok() , diagnostics_text(result);
}

# ─────────────────────────────────────────────────────────────────────
# A callee with fixed parameters binds the spread; only an unknown
# signature stays rejected
# ─────────────────────────────────────────────────────────────────────

test "a spread at a callee with no sink binds its declared parameters" {
    path = inline_case(
        "onto_named",
        "def sink(a: int, b: int) -> int { return a + b; }\n"
        "def use -> int {\n"
        "    d: dict[str, int] = {\"b\": 2};\n"
        "    return sink(1, **d);\n"
        "}\n"
    );
    (eng, fx) = compile_native(path.name, str(path.parent));
    assert unit_symbol(fx, "use") not in fx.iface().demoted , (
        f"the fixed-signature spread caller must lower: {fx.iface().demoted}"
    );
    use = get_func(eng, "use", ctypes.c_int64);
    assert use() == 3 , f"got {use()}";
}

test "guardrail: a spread into a callee with no known signature demotes" {
    path = inline_case(
        "unknown_callee",
        "def sink(a: int, b: int) -> int { return a + b; }\n"
        "def use(f: Callable[..., int]) -> int {\n"
        "    d: dict[str, int] = {\"b\": 2};\n"
        "    return f(1, **d);\n"
        "}\n"
    );
    fx = compile_mir(path.name, str(path.parent));
    assert not has_error_code(fx.result, "E5090") , (
        f"the unknown-callee spread is owned by use(), which must demote to a "
        f"seam, got {diagnostics_text(fx.result)}"
    );
    assert not fx.is_demoted("sink") , f"clean sibling function was lost: {fx.demoted()}";
    assert fx.is_demoted("use") , (
        "a spread into a callee without a static signature must be demoted"
    );
}

test "a spread into a sink no longer trips the capability gate" {
    checked = check_na_inline(
        "into_sink",
        "def sink(a: int, **kw: int) -> int { return a + len(kw); }\n"
        "def use -> int {\n"
        "    d: dict[str, int] = {\"b\": 2};\n"
        "    return sink(1, **d);\n"
        "}\n"
    );
    assert checked.ok() , diagnostics_text(checked);
}

# ─────────────────────────────────────────────────────────────────────
# Congruence with the Python backend on ordering and duplicates
# ─────────────────────────────────────────────────────────────────────

# CPython evaluates call arguments strictly left to right, spreads included.
# The first cut of this lowering emitted every literal keyword and only then
# the spreads, so a spread appearing first in source ran second. `_SEQ`
# records the order each operand fired as decimal digits.
test "a spread and a literal keyword evaluate in source order" {
    (eng, _) = compile_native("kwargs_spread.jac");
    spread_first = get_func(eng, "order_spread_then_literal", ctypes.c_int64);
    assert spread_first() == 12 , (
        f"**spread should evaluate before the later literal, got {spread_first()}"
    );
    lit_first = get_func(eng, "order_literal_then_spread", ctypes.c_int64);
    assert lit_first() == 12 , (
        f"literal should evaluate before the later **spread, got {lit_first()}"
    );
}

# ─────────────────────────────────────────────────────────────────────
# Spread keys that name declared parameters bind them (CPython parity)
# ─────────────────────────────────────────────────────────────────────

# CPython binds a spread key naming a keyword-bindable declared parameter to
# that parameter, never to the **kwargs sink: `f(**{"a": 5})` against
# `def f(a=0, **kw)` means a=5, kw={}. Each expectation below is chosen so
# the sink-diversion wrong answer (a left at its default, the key landing in
# kw) is numerically distinct from the bound answer.

test "a spread key naming a defaulted param binds it, not the sink" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "spread_binds_declared", ctypes.c_int64);
    # a=5, kw={} -> 5000. Sink diversion would give 105.
    assert f() == 5000 , f"got {f()}";
}

test "a spread key satisfies a required param" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "spread_binds_required", ctypes.c_int64, ctypes.c_int64);
    # a=n, kw={} -> n*10. Sink diversion would give 1 for any n.
    assert f(6) == 60 , f"got {f(6)}";
}

test "one spread splits between a declared param and the sink" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "mixed_bind_and_sink", ctypes.c_int64, ctypes.c_int64);
    # a=3 bound, {"z": 9} sunk -> 3100. Sink diversion would give 203.
    assert f(3) == 3100 , f"got {f(3)}";
}

test "two spreads split: first binds the param, second fills the sink" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "two_spread_split", ctypes.c_int64);
    # a=4 from d1, {"z": 9} from d2 -> 4100. Sink diversion would give 204.
    assert f() == 4100 , f"got {f()}";
}

test "a spread key binds a keyword-only param" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "kwonly_bind", ctypes.c_int64);
    # args=(1,2), k=7, kw={} -> 20700. Sink diversion would give 20001.
    assert f() == 20700 , f"got {f()}";
}

test "the sink parameter's own name stays a sink key" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "sink_name_not_bindable", ctypes.c_int64);
    # "kw" is not keyword-bindable: a=0, kw={"kw": 3} -> 100.
    assert f() == 100 , f"got {f()}";
}

# CPython: TypeError "got multiple values for keyword argument 'a'" /
# "... for argument 'a'". Each fixture returns 1 from the except arm and a
# distinct sentinel when no raise fired.

test "a spread key colliding with a literal keyword raises TypeError" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "collide_bound_kw", ctypes.c_int64);
    assert f() == 1 , f"expected TypeError, got sentinel {f()}";
}

test "a spread key colliding with a positional binding raises TypeError" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "collide_bound_pos", ctypes.c_int64);
    assert f() == 1 , f"expected TypeError, got sentinel {f()}";
}

test "a second spread re-binding a param raises TypeError" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "collide_two_spreads", ctypes.c_int64);
    assert f() == 1 , f"expected TypeError, got sentinel {f()}";
}

test "a required param a spread never supplies raises TypeError" {
    (eng, _) = compile_native("kwargs_spread.jac");
    f = get_func(eng, "missing_required", ctypes.c_int64);
    # Sentinel -x surfaces the zero-filled wrong answer if no raise fired.
    assert f() == 1 , f"expected TypeError, got sentinel {f()}";
}

# ─────────────────────────────────────────────────────────────────────
# Duplicate literal keywords stay a compile-time rejection
# ─────────────────────────────────────────────────────────────────────

# A name-keyed binding map would silently drop the first of two identical
# literal keywords, but ast_validation_pass rejects the call
# with E0065 on every codespace before codegen can see it. Pinned here so the
# front-end guard can't regress out from under the native lowering.
test "duplicate literal keywords are rejected at check time" {
    checked = check_na_inline(
        "dup_literal",
        "def sink(**kw: int) -> int { return len(kw); }\n"
        "def use -> int {\n"
        "    d: dict[str, int] = {};\n"
        "    return sink(p=1, p=2, **d);\n"
        "}\n"
    );
    assert has_error_code(checked, "E0065") , (
        f"expected E0065 for a duplicate literal keyword, got {diagnostics_text(checked)}"
    );
}
