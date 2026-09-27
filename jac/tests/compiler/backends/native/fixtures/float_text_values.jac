"""Floats rendered by print, str, f-strings and str.format read like CPython."""

def half -> float {
    return 1.5;
}

def scaled(i: int) -> float {
    return i * 0.125 + 100.0;
}

with entry {
    for i in range(3) {
        print(half());
        print(scaled(i), -2.5, 3.0);
        print(str(scaled(i)));
        print(f"{half()}|{scaled(i):.2f}|{half()!r}|{i}");
        print("v={} w={} n={}".format(half(), scaled(i), i));
    }
    print(1e20, 1e-7, 0.1, 123456789.125);
}
