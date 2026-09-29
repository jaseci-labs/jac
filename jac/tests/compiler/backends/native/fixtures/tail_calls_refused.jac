"""Tail calls the native backend cannot guarantee; each one is refused."""

def two(a: int, b: int) -> int {
    return a + b;
}

def arity_mismatch(a: int) -> int {
    return tail two(a, 1);
}

def return_mismatch(n: int) -> int {
    return tail is_positive(n);
}

def is_positive(n: int) -> bool {
    return n > 0;
}

def owned_local(n: int) -> int {
    items: list[int] = [n, n + 1];
    return tail pass_through(items[0] + len(items));
}

def pass_through(n: int) -> int {
    return n;
}

def inside_finally(n: int) -> int {
    try {
        return tail pass_through(n);
    } finally {
        print("cleanup");
    }
}
