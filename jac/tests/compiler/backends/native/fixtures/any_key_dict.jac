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



def built_count -> int {
    xs: list[any] = [1, "a", 1.0, True, None, "a"];
    seen = {x: None for x in xs};
    zeros: dict[any, int] = {0.0: 1};
    zeros[-0.0] = 2;
    owned: dict[any, int] = {};
    for n in ["ab", "cde"] {
        owned[n + "!"] = len(n);
    }
    return len(seen) * 1000 + zeros[0] * 100 + owned["ab!"] * 10 + len(owned);
}


def make_key(n: int) -> any {
    return f"k{n}";
}


def computed_count -> int {
    total = 0;
    for _ in range(3) {
        d = {make_key(n): n for n in range(50)};
        total += len(d) + d["k7"];
    }
    return total;
}
