"""Mixed tuple iteration preserves each member for flow narrowing."""

"""A tuple of an int, a str and an int: three elements, two storage widths."""
def mixed_tuple(seed: int) -> int {
    acc = seed;
    for v in (1, 'ab', 3) {
        acc = acc * 5;
        if isinstance(v, str) {
            acc = acc + len(v);
        } elif isinstance(v, int) {
            acc = acc + v;
        }
    }
    return acc;
}


"""The same three values as a list, which lowers."""
def mixed_list(seed: int) -> int {
    acc = seed;
    for v in [1, 'ab', 3] {
        acc = acc * 5;
        if isinstance(v, str) {
            acc = acc + len(v);
        } elif isinstance(v, int) {
            acc = acc + v;
        }
    }
    return acc;
}


obj Item {
    has value: int;
}

def optional_tuple(seed: int) -> int {
    absent: Item | None = None;
    present: Item | None = Item(seed);
    total = 0;
    for value in (Item(seed), absent, present) {
        if value is not None {
            total += value.value;
        }
    }
    return total;
}


with entry {
    print(mixed_tuple(0));
    print(mixed_list(0));
}
