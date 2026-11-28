"""Fixture: an integer enum constructed from a floating-point argument.

Native integer-enum construction does not coerce floats to integers, and no
AST-level capability check catches it, so NaIRGenPass's emitter refuses
`Hue(float(x))` as a compile error. `double` lowers natively.
"""

enum Hue { RED = 1, GREEN = 2 }

def from_code(x: str) -> int {
    h = Hue(float(x));
    return len(x) if h is not None else 0;
}

def double(x: int) -> int {
    return x * 2;
}

with entry {
    print(double(3));
}
