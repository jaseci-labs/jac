"""Augmented assignment to a float assigned in a `with entry` block (#10556)."""

with entry {
    g: float = 10.0;
    g /= 2;
    print(g);
    a = 9.0;
    a /= 2.0;
    print(a);
    m = 9.5;
    m %= 2.0;
    print(m);
    fl = 9.0;
    fl //= 2.0;
    print(fl);
    s = 9.0;
    s += 1;
    s -= 0.5;
    s *= 2;
    print(s);
    z = 1.0;
    try {
        z /= 0.0;
        print("no error", z);
    } except ZeroDivisionError {
        print("ZeroDivisionError");
    }
}
