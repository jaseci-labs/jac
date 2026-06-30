"""Bundled native ``fractions`` cross-backend equivalence fixture (#6978 Phase 2).

The SAME ``import from fractions { Fraction }`` binds CPython's ``fractions`` on
the sv (Python) backend and the bundled ``na_stdlib/fractions.na.jac``
Mechanism-B module on the na (native LLVM) backend. This fixture pins the two
congruent on construction/reduction (sign normalization, GCD reduction, whole
numbers, zero), ``numerator`` / ``denominator``, and the arithmetic *values*
compared via ``str()``.

Native has no operator-overload dispatch, so the na entry point drives
arithmetic/ordering through the module's methods (``add`` / ``sub`` / ``mul`` /
``div`` / ``eq`` / ``lt``) while the sv entry point uses CPython's operators --
both must yield identical output. ES/JS opts out.
"""

import from fractions { Fraction }


def fractions_py() -> dict {
    a = Fraction(3, 6);
    b = Fraction(2, 5);
    return {
        "a": str(a),
        "b": str(b),
        "num_a": a.numerator,
        "den_a": a.denominator,
        "sum": str(a + b),
        "diff": str(a - b),
        "prod": str(a * b),
        "quot": str(a / b),
        "neg": str(Fraction(-3, 6)),
        "dneg": str(Fraction(3, -6)),
        "dd": str(Fraction(-3, -6)),
        "whole": str(Fraction(8, 4)),
        "whole_den": Fraction(8, 4).denominator,
        "zero": str(Fraction(0, 5)),
        "zero_den": Fraction(0, 5).denominator,
        "eq": 1 if a == Fraction(1, 2) else 0,
        "lt": 1 if b < a else 0,
        "gt": 1 if a < b else 0,

    };
}


cl def fractions_cl() -> dict {
    return {};
}


na {
    def fractions_na() -> dict[str, any] {
        a = Fraction(3, 6);
        b = Fraction(2, 5);
        return {
            "a": str(a),
            "b": str(b),
            "num_a": a.numerator,
            "den_a": a.denominator,
            "sum": str(a.add(b)),
            "diff": str(a.sub(b)),
            "prod": str(a.mul(b)),
            "quot": str(a.div(b)),
            "neg": str(Fraction(-3, 6)),
            "dneg": str(Fraction(3, -6)),
            "dd": str(Fraction(-3, -6)),
            "whole": str(Fraction(8, 4)),
            "whole_den": Fraction(8, 4).denominator,
            "zero": str(Fraction(0, 5)),
            "zero_den": Fraction(0, 5).denominator,
            "eq": 1 if a.eq(Fraction(1, 2)) else 0,
            "lt": 1 if b.lt(a) else 0,
            "gt": 1 if a.lt(b) else 0,

        };
    }
}
