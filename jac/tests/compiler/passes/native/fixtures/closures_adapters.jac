"""Capturing callbacks for the lazy map/filter adapters.

The adapter states carry a `{fn, env}` slot pair alongside the upstream
iterator: a bare named function bakes its callee into the per-callsite next
function exactly as before, while a capturing lambda, a named nested
closure, or a stored closure value routes through the closure thunk with
the env loaded from the adapter state. The state retains the env for the
adapter's lifetime and the struct release fn drops it with the upstream.
"""

def scale_all(k: int) -> int {
    t = 0;
    for v in map(lambda (x: int) -> int { x * k; }, [1, 2, 3]) {
        t = t + v;
    }
    return t;
}

def keep_over(cut: int) -> int {
    t = 0;
    for v in filter(lambda (x: int) -> bool { x > cut; }, [1, 5, 9, 3]) {
        t = t + v;
    }
    return t;
}

def make_adder(k: int) -> Callable[[int], int] {
    return lambda (x: int) -> int { x + k; };
}

def map_stored_closure(k: int) -> int {
    f = make_adder(k);
    t = 0;
    for v in map(f, [10, 20]) {
        t = t + v;
    }
    return t;
}

def map_named_capture(k: int) -> int {
    def scaled(x: int) -> int {
        return x * k;
    }
    t = 0;
    for v in map(scaled, [2, 3]) {
        t = t + v;
    }
    return t;
}

def filter_then_map(cut: int, k: int) -> int {
    t = 0;
    for v in map(
        lambda (x: int) -> int { x * k; },
        filter(lambda (x: int) -> bool { x >= cut; }, [1, 2, 3, 4])
    ) {
        t = t + v;
    }
    return t;
}
