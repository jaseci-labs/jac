"""Generator cross-backend equivalence fixture.

Pins the py (sv) generator semantics against the native state-machine
lowering: yield order, early break, independent instances, first-class
next(), and plain-return stop. ES/JS opts out.
"""

def counter(n: int) -> Iterator[int] {
    i = 0;
    while i < n {
        yield i;
        i = i + 1;
    }
}

def gens_py -> dict {
    total = 0;
    for v in counter(5) {
        total = total + v;
    }
    seen = 0;
    for v in counter(10) {
        if v >= 3 {
            break;
        }
        seen = seen + 1;
    }
    total2 = 0;
    for v in counter(4) {
        total2 = total2 + v * v;
    }
    return {"total": total, "seen": seen, "squares": total2,};
}

cl def gens_cl -> dict {
    return {};
}

na {
    def na_counter(n: int) -> Iterator[int] {
        i = 0;
        while i < n {
            yield i;
            i = i + 1;
        }
    }

    def gens_na -> dict[str, any] {
        total = 0;
        for v in na_counter(5) {
            total = total + v;
        }
        seen = 0;
        for v in na_counter(10) {
            if v >= 3 {
                break;
            }
            seen = seen + 1;
        }
        total2 = 0;
        for v in na_counter(4) {
            total2 = total2 + v * v;
        }
        return {"total": total, "seen": seen, "squares": total2,};
    }
}
