"""Behavioral lift oracle: original C under cc vs lifted Jac under jac run.

Expectations are auto-derived from `LiftResult.quarantined_functions` — the
manifest carries no expected-band column. MATCH when the entry is clean; TRAP
when it is quarantined. Collect-all reporting so one CI run surfaces every
divergence (including hangs that would previously deadlock the shard).
"""

import os;
import from tests.compiler.c2jac.lift_oracle {
    FIXTURES,
    assert_lift_matches_c,
    assert_lift_matches_c_or_traps,
    lift_to_jac
}
import from tests.compiler.c2jac.support { BREADTH, recompile_errors }
import from jaclang.compiler.cfront.fidelity {
    FidelityBand,
    fidelity_band,
    diag_num_of_code
}

glob MINILIB: str = os.path.join(FIXTURES, "minilib"),
     ARR_SUM: str = os.path.join(FIXTURES, "lift_oracle", "arr_sum.c");

glob _MINILIB_DRIVER: str = "#include <stdio.h>\n"
     "#include \"vec2.h\"\n"
     "int main(void) {\n"
     "    struct Vec2 a = {3, 4}, b = {1, 2};\n"
     "    printf(\"%d\\n\", vec2_dot(a, b) + vec2_len_sq(a) + vec2_sum_to(5));\n"
     "    return 0;\n"
     "}\n",
     _MINILIB_ENTRY: str = "with entry {\n"
     "    a = Vec2(x=3, y=4);\n"
     "    b = Vec2(x=1, y=2);\n"
     "    print(vec2_dot(a, b) + vec2_len_sq(a) + vec2_sum_to(5));\n"
     "}\n",
     _ARR_DRIVER: str = "#include <stdio.h>\n"
     "int run_arr_sum(void);\n"
     "int main(void) {\n"
     "    printf(\"%d\\n\", run_arr_sum());\n"
     "    return 0;\n"
     "}\n",
     _ARR_ENTRY: str = "with entry {\n"
     "    print(run_arr_sum());\n"
     "}\n";


def _scalar_case(
    name: str,
    c_expr: str,
    jac_expr: str,
    c_prelude: str = "",
    jac_prelude: str = "",
    c_helpers: str = "",
    jac_helpers: str = ""
) -> tuple[str, str, str, str] {
    fn: str = c_expr.split("(")[0];
    return (
        name,
        "#include <stdio.h>\n"
        + "int " + fn + "();\n"
        + c_helpers
        + "int main(void) {\n"
        + c_prelude
        + "    printf(\"%d\\n\", " + c_expr + ");\n"
        + "    return 0;\n"
        + "}\n",
        jac_helpers
        + "with entry {\n"
        + jac_prelude
        + "    print(" + jac_expr + ");\n"
        + "}\n",
        fn
    );
}

# Callable deterministic fixtures. No expected-band column — the lifter
# supplies MATCH vs TRAP via quarantined_functions.
glob _BREADTH_CASES: list[tuple[str, str, str, str]] = [
    _scalar_case("arrays.c", "sum_array(5)", "sum_array(5)"),
    _scalar_case("cfor.c", "sum_for(5)", "sum_for(5)"),
    _scalar_case(
        "control_flow.c",
        "find_first(values, 4, 9)",
        "find_first([1, 2, -1, 4], 4, 9)",
        c_prelude="int values[] = {1, 2, -1, 4};\n"
    ),
    _scalar_case("do_while.c", "countdown(5)", "countdown(5)"),
    _scalar_case("enum_collision.c", "test_b()", "test_b()"),
    _scalar_case("enum_flags.c", "has_read(7)", "has_read(7)"),
    _scalar_case(
        "enum_simple.c",
        "get_color()",
        "1 if get_color() == Color.GREEN else 0"
    ),
    _scalar_case("expr_stmts.c", "f(3)", "f(3)"),
    _scalar_case(
        "for_array_body.c",
        "sum_array(values, 3)",
        "sum_array(values, 3)",
        c_prelude="int values[] = {1, 2, 3};\n",
        jac_prelude="values = [1, 2, 3];\n",
        c_helpers="void note(const char *msg) {}\n"
    ),
    _scalar_case("for_block_spacing.c", "accumulate(4)", "accumulate(4)"),
    _scalar_case("for_body_rich.c", "classify(6)", "classify(6)"),
    _scalar_case(
        "for_call_body.c",
        "run(4)",
        "run(4)",
        c_helpers="int sink(int v) { return v; }\n",
        jac_helpers="def sink(v: int) -> int { return v; }\n\n"
    ),
    _scalar_case("for_char_cond.c", "match_char('a')", "match_char(97)"),
    _scalar_case("for_comma.c", "impure_comma(4)", "impure_comma(4)"),
    _scalar_case("for_comma_init.c", "run(3)", "run(3)"),
    _scalar_case(
        "for_comma_init_rich.c",
        "run(4)",
        "run(4)",
        c_helpers="int seed(void) { return 7; }\n",
        jac_helpers="def seed() -> int { return 7; }\n\n"
    ),
    _scalar_case("for_comma_step.c", "run(3)", "run(3)"),
    _scalar_case("for_continue.c", "sum_odd_descending(5)", "sum_odd_descending(5)"),
    _scalar_case("for_empty_stmt.c", "run(4)", "run(4)"),
    _scalar_case("for_funcall_step.c", "run(4)", "run(4)"),
    _scalar_case("for_funcall_step_continue.c", "run(4)", "run(4)"),
    _scalar_case("for_incdec_body.c", "run(4)", "run(4)"),
    _scalar_case("for_infinite_continue.c", "sum_until(5)", "sum_until(5)"),
    _scalar_case("for_initlist.c", "run(5)", "run(5)"),
    _scalar_case("for_multidecl_init.c", "run(3)", "run(3)"),
    _scalar_case("for_ternary.c", "clamp_sum(5, 2)", "clamp_sum(5, 2)"),
    _scalar_case("for_unsupported.c", "spin()", "spin()"),
    # `*(p+1)` on char* is now a faithful str-cursor deref (MATCH with
    # length-1 `"a"` where the peeked byte is NUL).
    _scalar_case(
        "for_unmappable_cond.c", 'scan("a")', 'scan("a")'
    ),
    _scalar_case(
        "for_nested_cond_clobber.c", 'scan("a")', 'scan("a")'
    ),
    _scalar_case("for_nested_dowhile.c", "clean(4)", "clean(4)"),
    _scalar_case("for_nested_dowhile.c", "dirty(4)", "dirty(4)"),
    _scalar_case("for_nested_switch.c", "clean(4)", "clean(4)"),
    _scalar_case("for_nested_switch.c", "dirty(4)", "dirty(4)"),
    _scalar_case(
        "for_deref.c",
        "sum_deref(&v, 3)",
        "sum_deref(7, 3)",
        c_prelude="int v = 7;\n"
    ),
    _scalar_case(
        "for_deref.c",
        "sum_computed_deref(a, 3)",
        "sum_computed_deref([1, 2, 3], 3)",
        c_prelude="int a[3] = {1, 2, 3};\n"
    ),
    _scalar_case("do_while_continue.c", "sum_odd(5)", "sum_odd(5)"),
    _scalar_case("switch_fallthrough.c", "classify(1)", "classify(1)"),
    _scalar_case("for_cast.c", "truncate_sum(5)", "truncate_sum(5)"),
    _scalar_case("edge_cases.c", "goto_test(1)", "goto_test(1)"),
    _scalar_case("edge_cases_2.c", "variadic_sum(0)", "variadic_sum(0)"),
    _scalar_case("edge_cases_3.c", "pointer_array()", "pointer_array()"),
    _scalar_case("nonascii_str.c", "use()", "use()"),
    _scalar_case("hello.c", "add(2, 3)", "add(2, 3)"),
    _scalar_case(
        "cpython/pystrcmp.c",
        'PyOS_mystricmp("Ab", "aB")',
        'PyOS_mystricmp("Ab", "aB")'
    ),
    _scalar_case(
        "cpython/pystrcmp.c",
        'PyOS_mystrnicmp("Abc", "aBd", 2)',
        'PyOS_mystrnicmp("Abc", "aBd", 2)'
    ),
    _scalar_case(
        "pointers.c",
        "get_x(make_point(7, 9))",
        "get_x(make_point(7, 9))",
        c_helpers="typedef struct { int x; int y; } Point;\n"
        "Point *make_point();\n"
    ),
    _scalar_case(
        "ptr_idioms.c",
        "sum_via_ref(&point)",
        "sum_via_ref(point)",
        c_prelude="Point point = {3, 4};\n",
        jac_prelude="point = Point(x=3, y=4);\n",
        c_helpers="typedef struct { int x; int y; } Point;\n"
        "void set_field(int *slot, int v) { *slot = v; }\n",
        jac_helpers="def set_field(slot: int, v: int) -> None {}\n\n"
    ),
    _scalar_case("struct_array.c", "build()", "build()"),
    _scalar_case("switch_basic.c", "classify(2)", "classify(2)"),
    _scalar_case("ternary.c", "absval(-7)", "absval(-7)"),
    # Former STYLE skips: defined writes / scalar entries make them differential.
    _scalar_case("obj_array.c", "sum_first(5)", "sum_first(5)"),
    _scalar_case("struct_shape.c", "point_sum()", "point_sum()"),
    _scalar_case("struct_shape.c", "point_init_sum()", "point_init_sum()"),
    _scalar_case("struct_shape.c", "point_desig_sum()", "point_desig_sum()"),
    _scalar_case(
        "cpython/rotatingtree.c",
        "RotatingTree_RandomBits(3)",
        "RotatingTree_RandomBits(3)"
    )
];

# Every STYLE/none breadth fixture now has a callable oracle entry.
glob _ORACLE_SKIP: set[str] = set();


def _format_mismatches(mismatches: list) -> str {
    lines: list = [f"{len(mismatches)} oracle divergence(s):"];
    for (name, status, detail) in mismatches {
        lines.append(f"  [{status}] {name}: {detail}");
    }
    return "\n".join(lines);
}


def _codes_are_style_or_none(codes: list[str]) -> bool {
    for code in codes {
        num = diag_num_of_code(code);
        if num is None {
            return False;
        }
        if fidelity_band(num) != FidelityBand.STYLE {
            return False;
        }
    }
    return True;
}


test "lift oracle: every callable fixture obeys its fidelity claim" {
    mismatches: list = [];
    ran: int = 0;
    for (name, driver, entry, entry_fn) in _BREADTH_CASES {
        path = os.path.join(FIXTURES, name);
        (status, detail) = assert_lift_matches_c_or_traps(
            path, driver, entry, entry_fn
        );
        ran += 1;
        if status != "ok" {
            mismatches.append((name, status, detail));
        }
    }
    assert mismatches == [] , _format_mismatches(mismatches);
    assert ran == len(_BREADTH_CASES) , ran;
}


test "lift oracle: STYLE/none breadth fixtures are gated or explicitly skipped" {
    # Coverage ratchet: every breadth fixture whose expected diagnostics are
    # STYLE-only (or empty) must appear in the oracle manifest unless listed
    # in `_ORACLE_SKIP`. Behavior/hole fixtures are covered by the TRAP regime
    # only when they have a callable entry in `_BREADTH_CASES`.
    oracle_names: set = {c[0] for c in _BREADTH_CASES};
    missing: list = [];
    for (name, codes) in BREADTH {
        if name in _ORACLE_SKIP {
            continue;
        }
        if not _codes_are_style_or_none(codes) {
            continue;
        }
        if name not in oracle_names {
            missing.append(name);
        }
    }
    assert missing == [] , (
        "STYLE/none breadth fixtures missing from lift oracle "
        f"(add a case or _ORACLE_SKIP): {missing}"
    );
}


test "lift oracle: minilib ints agree under cc vs jac run" {
    assert_lift_matches_c(
        os.path.join(MINILIB, "vec2.c"),
        _MINILIB_DRIVER,
        _MINILIB_ENTRY,
        include_dirs=[MINILIB]
    );
}

test "lift oracle: idiomatic array lift agrees under cc vs jac run" {
    jac_src = lift_to_jac(ARR_SUM);
    assert "list[int]" in jac_src , jac_src;
    assert recompile_errors(jac_src, "arr_sum.c") == [] , jac_src;
    assert_lift_matches_c(ARR_SUM, _ARR_DRIVER, _ARR_ENTRY);
}
