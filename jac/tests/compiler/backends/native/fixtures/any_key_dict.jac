"""A dict keyed on `any`: keys hash and compare by value across kinds, so 2.0
finds 2, True and 1 are one key, and None is a key like any other."""
def mixed_count -> int {
    d: dict[any, any] = {"a": 1, 2: "two", 2.5: "f", None: "n", True: "t", 1: "one"};
    hits = 0;
    if d[2.0] == "two" {
        hits += 1;
    }
    if d[1] == "one" {
        hits += 10;
    }
    if d[True] == "one" {
        hits += 100;
    }
    if None in d {
        hits += 1000;
    }
    if "b" not in d {
        hits += 10000;
    }
    return len(d) * 100000 + hits;
}
