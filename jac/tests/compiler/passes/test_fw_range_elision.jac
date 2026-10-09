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

"""The proof runs inside the native compiler kernel, where an `int` is a
signed 64-bit integer that traps on overflow, so it cannot compute the bounds
of an `i64` or `u64` operation the plain way: `i64 - 1` already leaves the
range. It decides each corner without forming it instead. This is the plain
interval arithmetic it has to agree with, on unbounded integers."""
def plain_proof(
    op: str, left: tuple[int, int], right: tuple[int, int], target: tuple[int, int]
) -> bool {
    (a_lo, a_hi) = left;
    (b_lo, b_hi) = right;
    if op == "+" {
        (lo, hi) = (a_lo + b_lo, a_hi + b_hi);
    } elif op == "-" {
        (lo, hi) = (a_lo - b_hi, a_hi - b_lo);
    } elif op == "*" {
        ends = [a_lo * b_lo, a_lo * b_hi, a_hi * b_lo, a_hi * b_hi];
        (lo, hi) = (min(ends), max(ends));
    } else {
        (lo, hi) = (-a_hi, -a_lo);
    }
    return target[0] <= lo and hi <= target[1];
}

glob EDGE: int = 9223372036854775807,
     U64_TOP: int = 18446744073709551615,
     TARGETS: dict[str, tuple[int, int]] = {
         "i8": (-128, 127),
         "u8": (0, 255),
         "i32": (-2147483648, 2147483647),
         "u32": (0, 4294967295),
         "i64": (-EDGE - 1, EDGE),
         "u64": (0, U64_TOP)
     };

def edge_intervals(points: list[int]) -> list[tuple[int, int]] {
    found: list[tuple[int, int]] = [];
    for (at, lo) in enumerate(points) {
        for hi in points[at:] {
            found.append((lo, hi));
        }
    }
    return found;
}

test "the 64-bit proof agrees with plain interval arithmetic at every edge" {
    points = [
        -EDGE - 1,
        -EDGE,
        -4611686018427387904,
        -4294967296,
        -3037000500,
        -2,
        -1,
        0,
        1,
        2,
        3037000499,
        3037000500,
        4294967295,
        4294967296,
        4611686018427387904,
        EDGE - 1,
        EDGE
    ];
    spans = edge_intervals(points);
    checked = 0;
    for (name, target) in TARGETS.items() {
        for op in ["+", "-", "*"] {
            for left in spans {
                for right in spans {
                    assert interval_of_op(op, left, right, name)
                        == plain_proof(op, left, right, target) , (
                        op,
                        left,
                        right,
                        name
                    );
                    checked += 1;
                }
            }
        }
        for left in spans {
            assert interval_of_op("neg", left, (0, 0), name)
                == plain_proof("neg", left, (0, 0), target) , ("neg", left, name);
        }
    }
    assert checked > 100000;
}

"""A u64 of unknown value ranges up to 2^64 - 1, which the kernel cannot
hold. `interval_of_expr` spells that range (0, -1) and the proof answers for
it by rule; the rules must be what the arithmetic gives."""
test "a u64 operand of unknown value is proved by the same arithmetic" {
    points = [-EDGE - 1, -EDGE, -2, -1, 0, 1, 2, 255, 4294967296, EDGE - 1, EDGE];
    spans = edge_intervals(points);
    spelled = (0, -1);
    actual = (0, U64_TOP);
    for (name, target) in TARGETS.items() {
        for op in ["+", "-", "*"] {
            for other in spans {
                assert interval_of_op(op, spelled, other, name)
                    == plain_proof(op, actual, other, target) , (
                    op,
                    "u64",
                    other,
                    name
                );
                assert interval_of_op(op, other, spelled, name)
                    == plain_proof(op, other, actual, target) , (
                    op,
                    other,
                    "u64",
                    name
                );
            }
            assert interval_of_op(op, spelled, spelled, name)
                == plain_proof(op, actual, actual, target) , (op, name);
        }
        assert not interval_of_op("neg", spelled, (0, 0), name);
    }
}

test "a literal past the signed 64-bit top keeps the plain arithmetic" {
    assert interval_of_op("+", (EDGE + 1, EDGE + 1), (1, 1), "u64");
    assert not interval_of_op("+", (U64_TOP, U64_TOP), (1, 1), "u64");
    assert interval_of_op("-", (U64_TOP, U64_TOP), (0, -1), "i64") is False;
    assert interval_of_op("*", (EDGE + 1, EDGE + 1), (1, 1), "u64");
    assert not interval_of_op("*", (EDGE + 1, EDGE + 1), (2, 2), "u64");
}
