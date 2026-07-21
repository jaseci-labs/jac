"""Generator cross-backend equivalence fixture.

Pins the py (sv) generator semantics against the native state-machine
lowering: yield order, early break, independent instances, first-class
next(), plain-return stop, and the residual shapes (yield from, bare
yield, return <value>, yield inside try with exceptions across resumes,
yielding bodies over indexed collections). ES/JS opts out.
"""

def counter(n: int) -> Iterator[int] {
    i = 0;
    while i < n {
        yield i;
        i = i + 1;
    }
}

def chain2(n: int) -> Iterator[int] {
    yield from counter(n);
    yield from [100, 200];
    yield 999;
}

def pacer(n: int) -> Iterator[None] {
    i = 0;
    while i < n {
        yield ;
        i = i + 1;
    }
}

def upto_ret(n: int) -> Iterator[int] {
    yield 1;
    yield 2;
    return n * 10;
}

def doubles(xs: list[int]) -> Iterator[int] {
    for x in xs {
        yield x * 2;
    }
}

def resilient(n: int) -> Iterator[int] {
    try {
        yield 1;
        if n > 0 {
            raise ValueError("boom");
        }
        yield 2;
    } except ValueError {
        yield 3;
    }
    yield 4;
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
    chained = 0;
    for v in chain2(3) {
        chained = chained + v;
    }
    paced = 0;
    for p in pacer(4) {
        paced = paced + 1;
    }
    retv = 0;
    for v in upto_ret(9) {
        retv = retv + v;
    }
    listy = 0;
    for v in doubles([1, 2, 3]) {
        listy = listy + v;
    }
    resil = 0;
    for v in resilient(1) {
        resil = resil + v;
    }
    resil0 = 0;
    for v in resilient(0) {
        resil0 = resil0 + v;
    }
    return {
        "total": total,
        "seen": seen,
        "squares": total2,
        "chained": chained,
        "paced": paced,
        "retv": retv,
        "listy": listy,
        "resil": resil,
        "resil0": resil0,

    };
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

    def na_chain2(n: int) -> Iterator[int] {
        yield from na_counter(n);
        yield from [100, 200];
        yield 999;
    }

    def na_pacer(n: int) -> Iterator[None] {
        i = 0;
        while i < n {
            yield ;
            i = i + 1;
        }
    }

    def na_upto_ret(n: int) -> Iterator[int] {
        yield 1;
        yield 2;
        return n * 10;
    }

    def na_doubles(xs: list[int]) -> Iterator[int] {
        for x in xs {
            yield x * 2;
        }
    }

    def na_resilient(n: int) -> Iterator[int] {
        try {
            yield 1;
            if n > 0 {
                raise ValueError("boom");
            }
            yield 2;
        } except ValueError {
            yield 3;
        }
        yield 4;
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
        chained = 0;
        for v in na_chain2(3) {
            chained = chained + v;
        }
        paced = 0;
        for p in na_pacer(4) {
            paced = paced + 1;
        }
        retv = 0;
        for v in na_upto_ret(9) {
            retv = retv + v;
        }
        listy = 0;
        for v in na_doubles([1, 2, 3]) {
            listy = listy + v;
        }
        resil = 0;
        for v in na_resilient(1) {
            resil = resil + v;
        }
        resil0 = 0;
        for v in na_resilient(0) {
            resil0 = resil0 + v;
        }
        return {
            "total": total,
            "seen": seen,
            "squares": total2,
            "chained": chained,
            "paced": paced,
            "retv": retv,
            "listy": listy,
            "resil": resil,
            "resil0": resil0,

        };
    }
}
