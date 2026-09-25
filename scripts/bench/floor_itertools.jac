"""FFI-floor lane for itertools: raw native iteration costs without the module.

    jac run -b native scripts/bench/floor_itertools.jac

Measures, per element: a bare while loop, a typed list[int] for-loop, a
list[any] (jacval) for-loop, a hand-written Iterator[int] generator resumed
per element, and an Iterator[any] generator yielding boxed values. These are
the floors the itertools rows can approach.
"""

import time;


def emit_i(name: str, n: int, dt: float, acc: int) {
    print(name, "|", n, "|", dt * 1000000000.0 / n, "ns/op |", acc);
}


def _gen_ints(n: int) -> Iterator[int] {
    i: int = 0;
    while i < n {
        yield i;
        i += 1;
    }
}


def _gen_any(n: int) -> Iterator[any] {
    i: int = 0;
    while i < n {
        yield i;
        i += 1;
    }
}


def _gen_count_any -> Iterator[any] {
    v: int = 0;
    while True {
        yield v;
        v += 1;
    }
}


def bench_raw(n: int) -> tuple[float, int] {
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        acc += i;
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_list_int(n: int) -> tuple[float, int] {
    data: list[int] = [];
    for i in range(512) {
        data.append(i % 17);
    }
    reps: int = n // 512;
    t0: float = time.perf_counter();
    acc: int = 0;
    r: int = 0;
    while r < reps {
        for v in data {
            acc += v;
        }
        r += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_list_any(n: int) -> tuple[float, int] {
    data: list[any] = [];
    for i in range(512) {
        data.append(i % 17);
    }
    reps: int = n // 512;
    t0: float = time.perf_counter();
    acc: int = 0;
    r: int = 0;
    while r < reps {
        for v in data {
            vi: int = v;
            acc += vi;
        }
        r += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_gen_int(n: int) -> tuple[float, int] {
    reps: int = n // 512;
    t0: float = time.perf_counter();
    acc: int = 0;
    r: int = 0;
    while r < reps {
        for v in _gen_ints(512) {
            acc += v;
        }
        r += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_gen_any(n: int) -> tuple[float, int] {
    reps: int = n // 512;
    t0: float = time.perf_counter();
    acc: int = 0;
    r: int = 0;
    while r < reps {
        for v in _gen_any(512) {
            vi: int = v;
            acc += vi;
        }
        r += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_gen_count(n: int) -> tuple[float, int] {
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        acc += i;
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def best3(
    f: Callable[[int], tuple[float, int]], warm: int, n: int
) -> tuple[float, int] {
    f(warm);
    res = f(n);
    d: float = res[0];
    a: int = res[1];
    i: int = 0;
    while i < 2 {
        res = f(n);
        if res[0] < d {
            d = res[0];
            a = res[1];
        }
        i += 1;
    }
    return (d, a);
}


with entry {
    res = best3(bench_raw, 100000, 2000000);
    emit_i("floor.while_int", 2000000, res[0], res[1]);

    res = best3(bench_list_int, 16384, 1638400);
    emit_i("floor.for_list_int", 1638400, res[0], res[1]);

    res = best3(bench_list_any, 16384, 1638400);
    emit_i("floor.for_list_any", 1638400, res[0], res[1]);

    res = best3(bench_gen_int, 16384, 1638400);
    emit_i("floor.gen_int", 1638400, res[0], res[1]);

    res = best3(bench_gen_any, 16384, 1638400);
    emit_i("floor.gen_any", 1638400, res[0], res[1]);
}
