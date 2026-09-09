"""Fixture: a dependency seam only the backend's emitter discovers.

`from_code` invokes `Hue` as a constructor. No AST-level capability check
refuses it, so the demotion verdict exists only after NaIRGenPass lowers the
dependency. `double` must stay native.

`Hue` receives a floating-point argument. Native integer-enum construction
does not coerce floats to integers, so its emitter still refuses this shape.
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
