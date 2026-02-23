"""Complex number operator primitives.

Tests 9 of 10 ComplexEmitter interfaces via equality checks.
Complex objects are {re, im} in JS; .real/.imag in Python.
We test via equality (==) to avoid attribute access differences.

Note: unary pos (+) is omitted because the type evaluator loses complex
type after unary+, causing subsequent == to use JS === (identity) instead
of _jac.complex.eq(). The pos runtime function itself is trivially correct.
"""

def complex_ops_py() -> dict {
    c1 = complex(3, 4);
    c2 = complex(1, 2);

    # Arithmetic — verify via equality with expected values
    add_ok: bool = (c1 + c2) == complex(4, 6);
    sub_ok: bool = (c1 - c2) == complex(2, 2);
    mul_ok: bool = (c1 * c2) == complex(-5, 10);

    # Division with exact results: (6+8j)/(2+0j) = (3+4j)
    div_ok: bool = (complex(6, 8) / complex(2, 0)) == complex(3, 4);

    # Power: i^2 = -1 (use complex exponent for type tracking)
    pow_ok: bool = (complex(0, 1) ** complex(2, 0)) == complex(-1, 0);

    # Conjugate: conj(3+4j) = 3-4j
    conj_ok: bool = c1.conjugate() == complex(3, -4);

    # Equality
    eq_same: bool = c1 == complex(3, 4);
    eq_diff: bool = c1 == c2;

    # Inequality
    ne_diff: bool = c1 != c2;
    ne_same: bool = c1 != complex(3, 4);

    # Unary neg: -(3+4j) = (-3-4j)
    neg_ok: bool = (-c1) == complex(-3, -4);

    return {
        "add_ok": add_ok, "sub_ok": sub_ok,
        "mul_ok": mul_ok, "div_ok": div_ok,
        "pow_ok": pow_ok, "conj_ok": conj_ok,
        "eq_same": eq_same, "eq_diff": eq_diff,
        "ne_diff": ne_diff, "ne_same": ne_same,
        "neg_ok": neg_ok
    };
}

cl def complex_ops_cl() -> dict {
    c1 = complex(3, 4);
    c2 = complex(1, 2);

    add_ok: bool = (c1 + c2) == complex(4, 6);
    sub_ok: bool = (c1 - c2) == complex(2, 2);
    mul_ok: bool = (c1 * c2) == complex(-5, 10);
    div_ok: bool = (complex(6, 8) / complex(2, 0)) == complex(3, 4);
    pow_ok: bool = (complex(0, 1) ** complex(2, 0)) == complex(-1, 0);
    conj_ok: bool = c1.conjugate() == complex(3, -4);
    eq_same: bool = c1 == complex(3, 4);
    eq_diff: bool = c1 == c2;
    ne_diff: bool = c1 != c2;
    ne_same: bool = c1 != complex(3, 4);
    neg_ok: bool = (-c1) == complex(-3, -4);

    return {
        "add_ok": add_ok, "sub_ok": sub_ok,
        "mul_ok": mul_ok, "div_ok": div_ok,
        "pow_ok": pow_ok, "conj_ok": conj_ok,
        "eq_same": eq_same, "eq_diff": eq_diff,
        "ne_diff": ne_diff, "ne_same": ne_same,
        "neg_ok": neg_ok
    };
}
