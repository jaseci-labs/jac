"""Tuple values read out of a dictionary keep their tuple layout.

Tuple-valued dictionaries share the generic pointer value slot, so every read
has to recover the tuple the dictionary's value type declares. Each probe
subscripts the read result instead of unpacking it, which is the path that
used to index the erased pointer as a string.
"""
glob RANGES: dict[str, tuple[int, int]] = {"near": (2, 9)};

def int_pair_literal_key -> int {
    table: dict[str, tuple[int, int]] = {"a": (3, 4)};
    return table["a"][1];
}

def int_pair_bound -> int {
    table: dict[str, tuple[int, int]] = {"a": (3, 4), "b": (5, 6)};
    pair = table["b"];
    return pair[0] * 10 + pair[1];
}

def str_pair_bound -> int {
    table: dict[str, tuple[str, str]] = {"a": ("p", "q")};
    pair = table["a"];
    return 1 if pair[0] == "p" and pair[1] == "q" else 0;
}

def str_pair_variable_key(key: str) -> int {
    table: dict[str, tuple[str, str]] = {"a": ("p", "qq"), "b": ("rrr", "s")};
    pair = table[key];
    joined = pair[0] + pair[1];
    return len(joined) * 10 + len(table[key][1]);
}

def membership_then_lookup(kind: str) -> int {
    table: dict[str, tuple[str, str]] = {};
    if kind.startswith("a") {
        table = {"a1": ("p", "q"), "a2": ("rs", "t")};
    }
    if kind in table {
        spec = table[kind];
        return 1 if (spec[0] + spec[1]) == "rst" else 2;
    }
    return 0;
}

def three_element_values(kind: str) -> int {
    table: dict[str, tuple[str, str, int]] = {"a1": ("p", "q", 2)};
    if kind in table {
        spec = table[kind];
        label = spec[0] + spec[1] + str(spec[2]);
        return len(label) * 100 + spec[2] * 10 + len(table[kind][1]);
    }
    return -1;
}

def nested_subscripts(outer: str, inner: str) -> int {
    table: dict[str, dict[str, tuple[int, int, int]]] = {
        "x": {"y": (1, 2, 3), "z": (4, 5, 6)}
    };
    return table[outer][inner][2] * 10 + table[outer]["y"][0];
}

def global_subscript -> int {
    return RANGES["near"][0] * 100 + RANGES["near"][1] * 10 + RANGES["far"][0];
}

def get_method -> int {
    table: dict[str, tuple[int, int]] = {"a": (3, 4)};
    found = table.get("a");
    missing = table.get("b");
    if found is not None and missing is None {
        return found[1];
    }
    return -1;
}

def pop_and_setdefault -> int {
    table: dict[str, tuple[int, int]] = {"a": (3, 4), "b": (5, 6)};
    popped = table.pop("a");
    kept = table.setdefault("b", (7, 8));
    added = table.setdefault("c", (1, 9));
    return popped[1] * 100 + kept[1] * 10 + added[1];
}

def items_loop -> int {
    table: dict[str, tuple[str, int]] = {"a": ("xy", 4), "b": ("z", 5)};
    total = 0;
    for (key, value) in table.items() {
        total += len(value[0]) * 10 + value[1];
    }
    return total;
}

glob dropped: int = 0;

obj DictReadItem {
    has value: int;

    def drop {
        dropped += 1;
    }
}

def object_elements(key: str) -> int {
    table: dict[str, tuple[DictReadItem, DictReadItem]] = {
        "items": (DictReadItem(5), DictReadItem(8))
    };
    pair = table[key];
    return pair[0].value + table[key][1].value;
}

def drop_count -> int {
    return dropped;
}

with entry {
    RANGES["far"] = (7, 1);
}
