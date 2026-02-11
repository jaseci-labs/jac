"""Test yield expression as assignment value."""

def gen_accumulate(items: list) -> int {
    total = 0;
    for item in items {
        total += item;
        received = yield total;
    }
}

with entry {
    g = gen_accumulate([1, 2, 3]);
    print(next(g));
}
