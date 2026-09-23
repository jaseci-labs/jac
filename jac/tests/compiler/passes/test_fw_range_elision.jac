"""An operation that cannot leave its range does not pay for a check.

The erased fixed-width types cost one range check on the operations that can
overflow. Most of those checks are provable at compile time: adding two `i8`
values into an `i16` cannot leave `i16`, and a literal-bounded operand pins
the interval exactly. The checker computes the interval the operation can
produce and marks the expression when that interval fits the target, so the
backends emit the bare machine operation.

The analysis is exact interval arithmetic over the operand types and folded
literals -- not a width heuristic -- so it is sound by construction: an
interval that does not fit is simply not marked, and the check stays.
"""

import from jaclang.compiler.types.fixed_width { interval_of_op }

test "widening makes the result provably in range" {
    assert interval_of_op("+", (-128, 127), (-128, 127), "i16");
    assert interval_of_op("-", (-128, 127), (-128, 127), "i16");
    assert interval_of_op("*", (0, 255), (0, 255), "u32");
    assert interval_of_op("*", (-128, 127), (-128, 127), "i32");
}

test "an operation at its own width is not provable" {
    assert not interval_of_op("+", (-128, 127), (-128, 127), "i8");
    assert not interval_of_op("*", (0, 255), (0, 255), "u8");
    assert not interval_of_op("-", (0, 255), (0, 255), "u8");
}

test "a literal operand pins the interval" {
    assert interval_of_op("+", (0, 200), (1, 1), "u8");
    assert not interval_of_op("+", (0, 255), (1, 1), "u8");
    assert interval_of_op("*", (0, 100), (2, 2), "u8");
    assert not interval_of_op("*", (0, 200), (2, 2), "u8");
}

test "unary negation is provable below the signed edge" {
    assert interval_of_op("neg", (-127, 127), (0, 0), "i8");
    assert not interval_of_op("neg", (-128, 127), (0, 0), "i8");
}

test "an unknown operand interval is never provable" {
    assert not interval_of_op("+", None, (1, 1), "i64");
    assert not interval_of_op("+", (0, 1), None, "i64");
    assert not interval_of_op("??", (0, 1), (0, 1), "i64");
}

test "an operation at the operand width is never marked, whatever it flows into" {
    import os;
    import from tests.support { TESTS_DIR }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.frontend.unitree { BinaryExpr }
    src = (
        "with entry {\n"
        "    a: i8 = 100;\n"
        "    b: i8 = 100;\n"
        "    wide: i16 = a + b;\n"
        "    tight: i8 = a + b;\n"
        "}\n"
    );
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(
            TESTS_DIR, "compiler", "passes", "fixtures", "checker", "_elide_probe.jac"
        ),
        use_str=src,
        options=CompileOptions(no_cgen=True, force_codespace="server")
    );
    marks = [nd.fw_safe for nd in ir.get_all_sub_nodes(BinaryExpr)];
    assert marks == [False, False] , (
        "`i8 + i8` is computed at i8 and can leave it, whether the result is "
        f"then widened or not, so neither may be marked: {marks}"
    );
}
