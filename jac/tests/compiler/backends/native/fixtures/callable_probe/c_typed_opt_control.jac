def dbl(x: int) -> int {
    return x * 2;
}

obj Hooks {
    has g: (Callable[[int], int] | None) = None;
}

def call_it(h: Hooks) -> int {
    if h.g is not None {
        return h.g(5);
    }
    return 0;
}

with entry {
    print(call_it(Hooks(g=dbl)));
    print(call_it(Hooks()));
}
