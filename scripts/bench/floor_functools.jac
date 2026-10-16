"""FFI-floor lane for functools: raw native call and store costs without the module.

    jac run -b native scripts/bench/floor_functools.jac

Measures, per operation: a plain closure call through a Callable local, an
explicit `__call__` method dispatch on an object, a dict[int, any] lookup,
a dict[str, any] lookup, and the head of the isinstance key-dispatch chain.
These are the floors the functools rows (lru hit in particular) approach.
"""

import time;


def emit_i(name: str, n: int, dt: float, acc: int) {
    print(name, "|", n, "|", dt * 1000000000.0 / n, "ns/op |", acc);
}


def _inc(a: any) -> any {
    x: int = a;
    return x + 3;
}


obj Wrap {
    has f: Callable[[any], any];

    def __call__(x: any) -> any {
        g: Callable[[any], any] = self.f;
        return g(x);
    }
}


def bench_closure_call(n: int) -> tuple[float, int] {
    g: Callable[[any], any] = _inc;
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        r: any = g(i);
        ri: int = r;
        acc += ri;
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_method_call(n: int) -> tuple[float, int] {
    w = Wrap(_inc);
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        r: any = w.__call__(i);
        ri: int = r;
        acc += ri;
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_dict_i(n: int) -> tuple[float, int] {
    store: dict[int, any] = {};
    i: int = 0;
    while i < 64 {
        store[i] = i + 1;
        i += 1;
    }
    t0: float = time.perf_counter();
    acc: int = 0;
    i = 0;
    while i < n {
        v: any = store[i % 64];
        vi: int = v;
        acc += vi;
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_dict_s(n: int) -> tuple[float, int] {
    store: dict[str, any] = {};
    i: int = 0;
    while i < 64 {
        store["f:" + str(i)] = i + 1;
        i += 1;
    }
    t0: float = time.perf_counter();
    acc: int = 0;
    i = 0;
    while i < n {
        v: any = store["f:" + str(i % 64)];
        vi: int = v;
        acc += vi;
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_isinstance_head(n: int) -> tuple[float, int] {
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        x: any = i;
        if isinstance(x, bool) {
            acc += 1;
        } elif isinstance(x, int) {
            xi: int = x;
            acc += xi;
        } else {
            acc += 2;
        }
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
    res = best3(bench_closure_call, 100000, 2000000);
    emit_i("floor.closure_call", 2000000, res[0], res[1]);

    res = best3(bench_method_call, 100000, 2000000);
    emit_i("floor.obj_dunder_call", 2000000, res[0], res[1]);

    res = best3(bench_dict_i, 100000, 2000000);
    emit_i("floor.dict_int_hit", 2000000, res[0], res[1]);

    res = best3(bench_dict_s, 100000, 2000000);
    emit_i("floor.dict_str_hit", 2000000, res[0], res[1]);

    res = best3(bench_isinstance_head, 100000, 2000000);
    emit_i("floor.isinstance_head", 2000000, res[0], res[1]);
}
