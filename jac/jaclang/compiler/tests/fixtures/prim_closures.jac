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

cl def closures_cl -> dict {
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
}
