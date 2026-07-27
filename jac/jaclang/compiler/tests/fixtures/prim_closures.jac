"""Nested-function closure capture cross-backend equivalence fixture.

Pins the py (sv) semantics against native: read captures are late-bound
(the callee observes the variable's current value at each call) and rebound
captures (Jac implicit-rebind, sv emits `nonlocal`) write through to the
enclosing frame. ES/JS opts out.
"""

def closures_py -> dict {
    y = 2;
    def add_y(x: int) -> int {
        return x + y;
    }
    r1 = add_y(10);
    y = 7;
    r2 = add_y(10);

    total = 0;
    def bump(k: int) -> int {
        total = total + k;
        return total;
    }
    bump(5);
    bump(5);

    depth = 0;
    def walk(k: int) -> int {
        depth = depth + 1;
        if k <= 0 {
            return depth;
        }
        return walk(k - 1);
    }
    walked = walk(3);
    return {
        "late_r1": r1,
        "late_r2": r2,
        "rebound_total": total,
        "recursive_depth": walked,

    };
}

def closures_escape_py -> dict {
    count = 0;
    def bump -> int {
        count = count + 1;
        return count;
    }
    c = bump;
    c();
    c();
    counter = c();

    total = 10;
    def add3 -> int {
        total = total + 3;
        return total;
    }
    fns = [add3];
    f = fns[0];
    f();
    passed = f() * 1000 + total;

    n = 0;
    def inc -> int {
        n = n + 1;
        return n;
    }
    def dec -> int {
        n = n - 1;
        return n;
    }
    pair = [inc, dec];
    g = pair[0];
    h = pair[1];
    g();
    g();
    h();

    def mk -> Callable[[], int] {
        k = 0;
        def b -> int {
            k = k + 1;
            return k;
        }
        return b;
    }
    ca = mk();
    cb = mk();
    ca();
    ca();
    cb();
    independent = ca() * 10 + cb();
    return {
        "counter": counter,
        "passed": passed,
        "shared": n,
        "independent": independent,

    };
}


def closures_adapters_py -> dict {
    k = 3;
    scaled = 0;
    for v in map(lambda (x: int) -> int { x * k; }, [1, 2, 3]) {
        scaled = scaled + v;
    }
    cut = 4;
    kept = 0;
    for v in filter(lambda (x: int) -> bool { x >= cut; }, [1, 5, 9, 3]) {
        kept = kept + v;
    }
    chained = 0;
    for v in map(
        lambda (x: int) -> int { x * k; },
        filter(lambda (x: int) -> bool { x >= cut; }, [1, 4, 6])
    ) {
        chained = chained + v;
    }
    return {"scaled": scaled, "kept": kept, "chained": chained,};
}

cl def closures_cl -> dict {
    return {};
}

cl def closures_escape_cl -> dict {
    return {};
}

cl def closures_adapters_cl -> dict {
    return {};
}

na {
    def closures_na -> dict[str, any] {
        y = 2;
        def add_y(x: int) -> int {
            return x + y;
        }
        r1 = add_y(10);
        y = 7;
        r2 = add_y(10);

        total = 0;
        def bump(k: int) -> int {
            total = total + k;
            return total;
        }
        bump(5);
        bump(5);

        depth = 0;
        def walk(k: int) -> int {
            depth = depth + 1;
            if k <= 0 {
                return depth;
            }
            return walk(k - 1);
        }
        walked = walk(3);
        return {
            "late_r1": r1,
            "late_r2": r2,
            "rebound_total": total,
            "recursive_depth": walked,

        };
    }

    def closures_escape_na -> dict[str, any] {
        count = 0;
        def bump -> int {
            count = count + 1;
            return count;
        }
        c = bump;
        c();
        c();
        counter = c();

        total = 10;
        def add3 -> int {
            total = total + 3;
            return total;
        }
        fns: list[Callable[[], int]] = [add3];
        f = fns[0];
        f();
        passed = f() * 1000 + total;

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

        def mk -> Callable[[], int] {
            k = 0;
            def b -> int {
                k = k + 1;
                return k;
            }
            return b;
        }
        ca = mk();
        cb = mk();
        ca();
        ca();
        cb();
        independent = ca() * 10 + cb();
        return {
            "counter": counter,
            "passed": passed,
            "shared": n,
            "independent": independent,

        };
    }

    def closures_adapters_na -> dict[str, any] {
        k = 3;
        scaled = 0;
        for v in map(lambda (x: int) -> int { x * k; }, [1, 2, 3]) {
            scaled = scaled + v;
        }
        cut = 4;
        kept = 0;
        for v in filter(lambda (x: int) -> bool { x >= cut; }, [1, 5, 9, 3]) {
            kept = kept + v;
        }
        chained = 0;
        for v in map(
            lambda (x: int) -> int { x * k; },
            filter(lambda (x: int) -> bool { x >= cut; }, [1, 4, 6])
        ) {
            chained = chained + v;
        }
        return {"scaled": scaled, "kept": kept, "chained": chained,};
    }
}
