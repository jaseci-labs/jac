def scale_all(k: int) -> int {
    t = 0;
    for v in map(lambda (x: int) -> int { x * k; }, [1, 2, 3]) {
        t = t + v;
    }
    return t;
}

def make_adder(base: int) -> Callable[[int], int] {
    return lambda (x: int) -> int { x + base; };
}

def use_adder(base: int, v: int) -> int {
    f = make_adder(base);
    return f(v);
}

with entry {
    print("scaled:", scale_all(3));
    print("added:", use_adder(10, 5));
}
