"""Container shapes used by protocol guards and compiler classification tables."""

def protocol_guard -> int {
    active: set[tuple[int, int]] = set();
    active.add((0, 1));
    active.add((0, 2));
    active.add((0, 1));
    if (0, 3) in active or (0, 2) not in active {
        return -1;
    }
    before = len(active);
    active.discard((0, 1));
    active.discard((0, 1));
    return before * 10 + len(active);
}

def runtime_base_kinds -> int {
    kinds: dict[str, tuple[str, ...]] = {
        "all": ("node", "edge", "walker", "object"),
        "node": ("node", )
    };
    if kinds["all"][2] != "walker" or kinds["node"][0] != "node" {
        return -1;
    }
    before = len(kinds["all"]) * 10 + len(kinds["node"]);
    kinds["node"] = ("node", "extra");
    del kinds["all"];
    if kinds["node"][1] != "extra" {
        return -2;
    }
    return before * 100 + len(kinds["node"]) * 10 + len(kinds);
}

def maybe_interval(flag: int) -> tuple[int, int] | None {
    if flag {
        return (3, 7);
    }
    return None;
}

def read_interval(flag: int) -> int {
    value = maybe_interval(flag);
    if value is None {
        return -1;
    }
    (low, high) = value;
    return low * 10 + high;
}

def canonical_intern_keys -> int {
    interned: dict[tuple[tuple[str, int, int, str], str], int] = {};
    path = ".".join(["module", "jac"]);
    name = "".join(["Class", "Name"]);
    digest = "".join(["source", "hash"]);
    interned[((path, 3, 7, name), digest)] = 42;
    same = (("module.jac", 3, 7, "ClassName"), "sourcehash");
    if same not in interned or interned[same] != 42 {
        return -1;
    }
    if interned.get(same, 0) != 42 or interned.setdefault(same, 99) != 42 {
        return -2;
    }
    interned[same] = 9;
    interned[((path, 3, 8, name), digest)] = 5;
    del interned[same];
    before = len(interned);
    popped = interned.pop(((path, 3, 8, name), digest));
    if len(interned) != 0 {
        return -3;
    }
    return before * 10 + popped;
}

def signed_zero_key -> int {
    keys: set[tuple[float]] = set();
    keys.add((-0.0, ));
    if (0.0, ) not in keys {
        return -1;
    }
    keys.add((0.0, ));
    return len(keys);
}
