import time;

glob N: int = 1000000;

with entry {
    acc: int = 0;
    i: int = 0;

    t0: int = time.monotonic_ns();
    while i < N {
        acc += i % 65536;
        i += 1;
    }
    t1: int = time.monotonic_ns();
    print("bare_loop_ns_per_iter:", (t1 - t0) / N);

    i = 0;
    t0 = time.monotonic_ns();
    while i < N {
        acc += time.monotonic_ns() % 65536;
        i += 1;
    }
    t1 = time.monotonic_ns();
    print("bundled_monotonic_ns_per_iter:", (t1 - t0) / N, "acc:", acc);

    f0: float = time.monotonic();
    i = 0;
    while i < N {
        acc += int(time.monotonic() * 1000000.0) % 65536;
        i += 1;
    }
    f1: float = time.monotonic();
    print(
        "bundled_monotonic_float_ns_per_iter:",
        (f1 - f0) * 1000000000.0 / N,
        "acc:",
        acc
    );
}
