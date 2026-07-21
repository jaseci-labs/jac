"""Escaping capturing closures: returned, stored, and passed as values.

Captured variables of an escaping closure promote to RC heap cells (Python
cell semantics: rebinds are visible through the escaped closure, closures
capturing the same variable share one cell), and the closure value itself is
an RC {fn, env} pair whose env keeps the cells alive after the defining
frame dies. Note one identity divergence from Python: each evaluation of the
closure's name produces a distinct closure object (`f is g` may differ).
"""

def make_counter -> Callable[[], int] {
    count = 0;
    def bump -> int {
        count = count + 1;
        return count;
    }
    return bump;
}

def use_counter -> int {
    c = make_counter();
    c();
    c();
    return c();
}

def two_counters_independent -> int {
    a = make_counter();
    b = make_counter();
    a();
    a();
    b();
    return a() * 10 + b();
}

def call_twice(f: Callable[[], int]) -> int {
    f();
    return f();
}

def pass_closure(base: int) -> int {
    total = base;
    def add3 -> int {
        total = total + 3;
        return total;
    }
    r = call_twice(add3);
    return r * 1000 + total;
}

def stored_in_list(a: int, b: int) -> int {
    base = a;
    def addb(x: int) -> int {
        base = base + x;
        return base;
    }
    fns: list[Callable[[int], int]] = [addb];
    f = fns[0];
    return f(b);
}

def shared_cell -> int {
    n = 0;
    def inc -> int {
        n = n + 1;
        return n;
    }
    def dec -> int {
        n = n - 1;
        return n;
    }
    pair: list[Callable[[], int]] = [inc, dec];
    g = pair[0];
    h = pair[1];
    g();
    g();
    h();
    return n;
}

def make_greeter(name: str) -> Callable[[], int] {
    def greet -> int {
        return len(name);
    }
    return greet;
}

def use_greeter -> int {
    g = make_greeter("abcd");
    return g() + g();
}

def call_adder(f: Callable[[int], int]) -> int {
    return f(100);
}

def make_adder(y: int) -> Callable[[int], int] {
    return lambda (x: int) { x + y; };
}

def use_adder -> int {
    g = make_adder(5);
    return g(3) + g(10);
}

def lambda_escape(y: int) -> int {
    f = lambda (x: int) { x + y; };
    return call_adder(f) + f(10);
}
