"""Dual-lane benchmark rows for the bundled functools module.

    jac run -b native  scripts/bench/bench_functools_pr.jac   (bundled na_stdlib)
    jac run -b python  scripts/bench/bench_functools_pr.jac   (CPython bridge)

Rows print name|n|ns_per_op|acc; acc must match the CPython reference
(scripts/bench/bench_functools_pr.py) lane for lane. Wrapper products are
spelled `.__call__(...)` -- the one call shape valid on both backends.
"""

import time;
import functools;
import from functools { reduce, partial, lru_cache, cache, wraps, update_wrapper }


def emit_i(name: str, n: int, dt: float, acc: int) {
    print(name, "|", n, "|", dt * 1000000000.0 / n, "ns/op |", acc);
}


def ft_add(a: any, b: any) -> any {
    x: int = a;
    y: int = b;
    return x + y;
}

def ft_mul(a: any, b: any) -> any {
    x: int = a;
    y: int = b;
    return x * y;
}

def ft_square(x: any) -> any {
    v: int = x;
    return v * v;
}

def ft_id(x: any) -> any {
    return x;
}

def ft_base(x: any) -> any {
    v: int = x;
    return v + 1;
}

def ft_wrapped(x: any) -> any {
    v: int = x;
    return ft_base(v) * 10;
}


def bench_reduce(n: int) -> tuple[float, int] {
    data: list[any] = [];
    for i in range(1024) {
        data.append(i % 7);
    }
    reps: int = n // 1024;
    t0: float = time.perf_counter();
    acc: int = 0;
    r: int = 0;
    while r < reps {
        v: any = reduce(ft_add, data);
        vi: int = v;
        acc += vi;
        r += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_partial(n: int) -> tuple[float, int] {
    p = partial(ft_mul, 10);
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        v: any = p.__call__(i % 13);
        vi: int = v;
        acc += vi;
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_lru_hit(n: int) -> tuple[float, int] {
    sq = lru_cache(maxsize=128).__call__(ft_square);
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        v: any = sq.__call__(i % 64);
        vi: int = v;
        acc += vi;
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_lru_miss(n: int) -> tuple[float, int] {
    sq = lru_cache(maxsize=8).__call__(ft_square);
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        v: any = sq.__call__(i % 64);
        vi: int = v;
        acc += vi;
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_cache(n: int) -> tuple[float, int] {
    ub = cache(ft_id);
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        v: any = ub.__call__(i % 64);
        vi: int = v;
        acc += vi;
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_wraps_call(n: int) -> tuple[float, int] {
    g = wraps(ft_base).__call__(ft_wrapped);
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        v: any = g(i % 13);
        vi: int = v;
        acc += vi;
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


with entry {
    bench_reduce(16);
    resi = bench_reduce(16384);
    dti: float = resi[0];
    acci: int = resi[1];
    i: int = 0;
    while i < 2 {
        resi = bench_reduce(16384);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("functools.reduce", 16384, dti, acci);

    bench_partial(2000);
    resi = bench_partial(100000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_partial(100000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("functools.partial", 100000, dti, acci);

    bench_lru_hit(2000);
    resi = bench_lru_hit(100000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_lru_hit(100000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("functools.lru_cache hit", 100000, dti, acci);

    bench_lru_miss(2000);
    resi = bench_lru_miss(100000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_lru_miss(100000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("functools.lru_cache miss", 100000, dti, acci);

    bench_cache(2000);
    resi = bench_cache(100000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_cache(100000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("functools.cache", 100000, dti, acci);

    bench_wraps_call(2000);
    resi = bench_wraps_call(100000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_wraps_call(100000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("functools.wraps-call", 100000, dti, acci);
}
