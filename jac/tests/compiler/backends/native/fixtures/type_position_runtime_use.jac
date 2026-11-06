"""A genuinely run-time use of a Python module still refuses.

The negative half of the type-position contract: widening the gate to accept
compile-time positions must not accept a name a native unit would have to
call.
"""

import fractions;


def run -> int {
    value = fractions.Fraction(1, 2);
    return value.numerator;
}
