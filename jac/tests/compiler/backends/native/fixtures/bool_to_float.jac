"""A bool used as a float counts as 1.0 and 0.0, never -1.0."""

def half(x: float) -> float {
    return x / 2;
}

def inner {
    h = 10.0;
    h += bool(1);
    k = 10.0;
    k += True;
    print(h, k, half(bool(1)), half(True), half(bool(0)));
}

with entry {
    g = 10.0;
    g += bool(1);
    t = 10.0;
    t -= True;
    print(g, t, half(bool(1)), half(True), 1.5 + bool(1), float(bool(1)));
    inner();
}
