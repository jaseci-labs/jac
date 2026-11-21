"""Call-site star-unpacking (#7626 A6).

Two supported shapes: a tuple spread into a fixed-arity callee (the
static arity is known, so the spread splits into the declared params),
and a list spread into a variadic callee (routed through the typed-
container varargs convention). A list spread into a fixed-arity callee
stays a loud error -- its arity is not statically known.
"""

def add3(a: int, b: int, c: int) -> int {
    return a + 100 * b + 10000 * c;
}

def vsum(*xs: int) -> int {
    t = 0;
    for x in xs {
        t += x;
    }
    return t;
}

def spread_tuple -> int {
    xs = (1, 2, 3);
    return add3(*xs);
}

def spread_variadic -> int {
    lst = [4, 5, 6];
    return vsum(*lst);
}

def spread_mixed(a: int) -> int {
    rest = (2, 3);
    return add3(a, *rest);
}
