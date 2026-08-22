"""Fixture: a dependency seam only the backend's emitter discovers.

`from_code` invokes `Hue` as a constructor. No AST-level capability check
refuses it, so the demotion verdict exists only after NaIRGenPass lowers the
dependency. `double` must stay native.

`Hue` carries string values on purpose. #8266 gave the int-valued spelling a
real lowering -- validate the value against the declared member table, raise
`ValueError` when it misses -- and a string-valued enum's runtime form is the
member's ordinal rather than its value, so the lookup is not the identity and
the emitter still refuses it by name. The day that refusal goes, this fixture
needs a different emit-time-only shape and the test above says so.
"""

enum Hue { RED = "red", GREEN = "green" }

def from_code(x: str) -> int {
    h = Hue(x);
    return len(x) if h is not None else 0;
}

def double(x: int) -> int {
    return x * 2;
}

with entry {
    print(double(3));
}
