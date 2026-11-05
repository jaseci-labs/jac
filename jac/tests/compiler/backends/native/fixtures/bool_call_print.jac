"""`bool(...)` passed straight to `print`, `str` and an f-string (#10556)."""

import math;

def show(n: int, f: float, s: str) {
    print(bool(n), bool(f), bool(s), str(bool(n)), f"{bool(n)}");
}

with entry {
    print(bool(0), bool(2.5));
    x = bool(0);
    print(x);
    print(bool(1), bool(""), bool("a"), bool(0.0), bool(-0.0), bool(math.nan));
    print(str(bool(0)), f"{bool(3)}", bool(True), bool(False));
    print(bool(5) + 1, bool(0) == False, int(bool(7)));
    show(0, 0.0, "");
    show(-3, 0.1, "x");
}
