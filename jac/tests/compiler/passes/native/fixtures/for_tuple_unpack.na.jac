"""Native for-loop tuple destructuring (issue #7238).

`for (a, b) in <list-of-tuples>` must bind each target from the tuple's
per-position element type, so heterogeneous payloads (str + bytes) type and
lower correctly, the same idiom that already works on the @sv pathway.
"""

def sum_products(pairs: list[tuple[int, int]]) -> int {
    total = 0;
    for (a, b) in pairs {
        total += a * b;
    }
    return total;
}

def run_products() -> int {
    pairs: list[tuple[int, int]] = [(1, 10), (2, 20), (3, 30)];
    return sum_products(pairs);
}

def run_str_bytes_lengths() -> int {
    files: list[tuple[str, bytes]] = [
        ("a", b"hello"),
        ("bb", b"xy"),
        ("ccc", b""),
    ];
    total = 0;
    for (name, payload) in files {
        total += len(name) + len(payload);
    }
    return total;
}

def run_reuse_across_loops() -> int {
    pairs: list[tuple[int, int]] = [(1, 2), (3, 4)];
    total = 0;
    for (a, b) in pairs {
        total += a + b;
    }
    for (a, b) in pairs {
        total += a * b;
    }
    return total;
}
