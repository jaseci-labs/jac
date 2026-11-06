"""Augmented assignment on entry-block globals and `bool()` values (#10556).

One row per line, each labelled; the test compares every row with Python.
"""

import math;

def half(x: float) -> float {
    return x / 2;
}

def show(n: int, f: float, s: str) {
    print("def bool()", bool(n), bool(f), bool(s), str(bool(n)), f"{bool(n)}");
}

def in_def {
    h = 10.0;
    h += bool(1);
    k = 10.0;
    k += True;
    q = 1.5;
    q /= True;
    print("def bool as float", h, k, q, half(bool(1)), half(True), half(bool(0)));
    print(
        "def bool() count", "x" * bool(1), bool(1) * "ab", [1] * bool(1), bool(0) * [1]
    );
    print("def True count", "x" * True, True * "ab", [1] * True, False * [1]);
    print("def divmod", divmod(bool(1), 1), divmod(True, 1), divmod(5, bool(1)));
    print("def round", round(bool(1)), round(True), round(False, 2));
    print("def set", {bool(0), bool(1)}, {False, True});
    l = [1, 2];
    l *= 2;
    s = "ab";
    s *= 3;
    d = {"a": 1};
    d |= {"b": 2};
    print("def seq aug", l, s, d);
    al = [1];
    bl = al;
    al *= 2;
    cl = [3, 4];
    el = cl;
    cl *= 0;
    print("def list alias", bl, el);
}

with entry {
    g: float = 10.0;
    g /= 2;
    a = 9.0;
    a /= 2.0;
    m = 9.5;
    m %= 2.0;
    fl = 9.0;
    fl //= 2.0;
    s = 9.0;
    s += 1;
    s -= 0.5;
    s *= 2;
    t = 1.5;
    t /= True;
    print("float aug", g, a, m, fl, s, t);
    z = 1.0;
    try {
        z /= 0.0;
        print("float /= 0.0", z);
    } except ZeroDivisionError {
        print("float /= 0.0", "ZeroDivisionError");
    }
    d = {"a": 1};
    d |= {"b": 2};
    lst = [1, 2];
    lst *= 2;
    txt = "ab";
    txt *= 3;
    once = [7];
    once *= bool(1);
    print("seq aug", d, lst, txt, once);
    al = [1];
    bl = al;
    al *= 2;
    cl = [3, 4];
    el = cl;
    cl *= 0;
    print("list alias", bl, el);
    print(
        "bool()", bool(0), bool(2.5), bool(""), bool("a"), bool(-0.0), bool(math.nan)
    );
    print(
        "bool() text", str(bool(0)), f"{bool(3)}", bool(True), bool(5) + 1, int(bool(7))
    );
    w: float = bool(1);
    w /= 4;
    print("bool as float", w, half(bool(1)), half(True), 1.5 + bool(1), float(bool(1)));
    print("bool() count", "x" * bool(1), bool(1) * "ab", [1] * bool(1), bool(0) * [1]);
    print("True count", "x" * True, True * "ab", [1] * True, False * [1]);
    print("divmod", divmod(bool(1), 1), divmod(True, 1), divmod(5, bool(1)));
    print("round", round(bool(1)), round(True), round(False, 2));
    show(0, 0.0, "");
    show(-3, 0.1, "x");
    in_def();
}
