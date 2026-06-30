"""Bundled native ``fractions`` cross-backend equivalence fixture (#6978 Phase 2).

The sv entry uses CPython's operators (``a + b``, ``a == b``, ``a < b``); the na
entry calls the dunder methods directly (``a.__add__(b)``, ``a.__eq__(b)``, ...)
because the native backend has no operator-overload dispatch yet. Both must
yield identical output. ES/JS opts out.
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
        sum_s = str(a.__add__(b));
        diff_s = str(a.__sub__(b));
        prod_s = str(a.__mul__(b));
        quot_s = str(a.__truediv__(b));
        return {
            "a": str(a),
            "b": str(b),
            "num_a": a.numerator,
            "den_a": a.denominator,
            "sum": sum_s,
            "diff": diff_s,
            "prod": prod_s,
            "quot": quot_s,
            "neg": str(Fraction(-3, 6)),
            "dneg": str(Fraction(3, -6)),
            "dd": str(Fraction(-3, -6)),
            "whole": str(Fraction(8, 4)),
            "whole_den": Fraction(8, 4).denominator,
            "zero": str(Fraction(0, 5)),
            "zero_den": Fraction(0, 5).denominator,
            "eq": 1 if a.__eq__(Fraction(1, 2)) else 0,
            "lt": 1 if b.__lt__(a) else 0,
            "gt": 1 if a.__lt__(b) else 0,

        };
    }
}
