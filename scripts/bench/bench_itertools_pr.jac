"""Dual-lane benchmark rows for the bundled itertools module.

    jac run -b native  scripts/bench/bench_itertools_pr.jac   (bundled na_stdlib)
    jac run -b python  scripts/bench/bench_itertools_pr.jac   (CPython bridge)

Rows print name|n|ns_per_op|acc; acc must match the CPython reference
(scripts/bench/bench_itertools_pr.py) lane for lane. Only operations with
identical spelling and row shapes on both lanes are benched.
"""

import time;
import itertools;
import from itertools {
    count,
    cycle,
    accumulate,
    chain,
    compress,
    groupby,
    islice,
    permutations,
    combinations,
    product,
    zip_longest,
    batched,
    tee
}


def emit_i(name: str, n: int, dt: float, acc: int) {
    print(name, "|", n, "|", dt * 1000000000.0 / n, "ns/op |", acc);
}


def digest_ints(vals: Iterator[any]) -> int {
    acc: int = 0;
    for v in vals {
        vi: int = v;
        acc = acc + vi;
    }
    return acc;
}


def digest_rows(vals: Iterator[any]) -> int {
    acc: int = 0;
    for row in vals {
        acc += 1;
        for v in row {
            vi: int = v;
            acc = acc + vi;
        }
    }
    return acc;
}


def digest_seq(vals: any) -> int {
    acc: int = 0;
    for v in vals {
        vi: int = v;
        acc = acc + vi;
    }
    return acc;
}


def bench_accumulate(n: int) -> tuple[float, int] {
    data: list[int] = [];
    for i in range(512) {
        data.append(i % 17);
    }
    reps: int = n // 512;
    t0: float = time.perf_counter();
    acc: int = 0;
    r: int = 0;
    while r < reps {
        acc += digest_ints(accumulate(data));
        r += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_chain(n: int) -> tuple[float, int] {
    a: list[any] = [];
    b: list[any] = [];
    c: list[any] = [];
    for i in range(170) {
        a.append(i);
        b.append(i * 2);
        c.append(i * 3);
    }
    reps: int = n // 510;
    t0: float = time.perf_counter();
    acc: int = 0;
    r: int = 0;
    while r < reps {
        acc += digest_ints(chain(a, b, c));
        r += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_islice_count(n: int) -> tuple[float, int] {
    t0: float = time.perf_counter();
    acc: int = 0;
    r: int = 0;
    while r < n {
        acc += digest_ints(islice(count(0), 100));
        r += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_permutations(n: int) -> tuple[float, int] {
    data: list[int] = [];
    for i in range(6) {
        data.append(i + 1);
    }
    reps: int = n // 720;
    t0: float = time.perf_counter();
    acc: int = 0;
    r: int = 0;
    while r < reps {
        acc += digest_rows(permutations(data));
        r += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_combinations(n: int) -> tuple[float, int] {
    data: list[int] = [];
    for i in range(16) {
        data.append(i);
    }
    reps: int = n // 560;
    t0: float = time.perf_counter();
    acc: int = 0;
    r: int = 0;
    while r < reps {
        acc += digest_rows(combinations(data, 3));
        r += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_product(n: int) -> tuple[float, int] {
    p2: list[any] = [0, 1];
    p3: list[any] = [0, 1, 2];
    reps: int = n // 64;
    t0: float = time.perf_counter();
    acc: int = 0;
    r: int = 0;
    while r < reps {
        acc += digest_rows(product(p2, p2, p2, repeat=1));
        acc += digest_rows(product(p3, repeat=2));
        r += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_groupby(n: int) -> tuple[float, int] {
    data: list[int] = [];
    for i in range(400) {
        data.append(i % 8);
    }
    reps: int = n // 400;
    t0: float = time.perf_counter();
    acc: int = 0;
    r: int = 0;
    while r < reps {
        for kg in groupby(data) {
            acc += 1;
            for v in kg[1] {
                vi: int = v;
                acc = acc + vi;
            }
        }
        r += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_zl_batched(n: int) -> tuple[float, int] {
    a: list[any] = [];
    b: list[any] = [];
    for i in range(150) {
        a.append(i);
        b.append(i * 2);
    }
    reps: int = n // 450;
    t0: float = time.perf_counter();
    acc: int = 0;
    r: int = 0;
    while r < reps {
        acc += digest_rows(zip_longest(a, b));
        for bt in batched(a, 5) {
            acc += 1;
            for v in bt {
                vi: int = v;
                acc = acc + vi;
            }
        }
        r += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_cycle_tee(n: int) -> tuple[float, int] {
    src: list[int] = [];
    for i in range(100) {
        src.append(i);
    }
    reps: int = n // 500;
    t0: float = time.perf_counter();
    acc: int = 0;
    r: int = 0;
    while r < reps {
        acc += digest_ints(islice(cycle(src), 250));
        t2 = tee(src, 2);
        acc += digest_seq(t2[0]);
        acc += digest_seq(t2[1]);
        r += 1;
    }
    return (time.perf_counter() - t0, acc);
}


with entry {
    bench_accumulate(64);
    resi = bench_accumulate(16384);
    dti: float = resi[0];
    acci: int = resi[1];
    i: int = 0;
    while i < 2 {
        resi = bench_accumulate(16384);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("itertools.accumulate", 16384, dti, acci);

    bench_chain(32);
    resi = bench_chain(8160);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_chain(8160);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("itertools.chain", 8160, dti, acci);

    bench_islice_count(1000);
    resi = bench_islice_count(100000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_islice_count(100000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("itertools.islice+count", 100000, dti, acci);

    bench_permutations(8);
    resi = bench_permutations(1440);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_permutations(1440);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("itertools.permutations", 1440, dti, acci);

    bench_combinations(8);
    resi = bench_combinations(4480);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_combinations(4480);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("itertools.combinations", 4480, dti, acci);

    bench_product(100);
    resi = bench_product(6400);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_product(6400);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("itertools.product", 6400, dti, acci);

    bench_groupby(50);
    resi = bench_groupby(8000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_groupby(8000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("itertools.groupby", 8000, dti, acci);

    bench_zl_batched(100);
    resi = bench_zl_batched(9000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_zl_batched(9000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("itertools.zip_longest+batched", 9000, dti, acci);

    bench_cycle_tee(100);
    resi = bench_cycle_tee(20000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_cycle_tee(20000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("itertools.cycle+tee", 20000, dti, acci);
}
