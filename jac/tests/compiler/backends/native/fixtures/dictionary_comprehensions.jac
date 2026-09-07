def dictionary_comprehensions -> int {
    solution: dict[str, int] = {"T": 1, "U": 2, "V": 3};
    declared: set[str] = {"T", "V"};
    shadowed = {
        name
        for name in solution
        if name not in declared
    };
    ordered = [
        name
        for name in solution
        if solution[name] > 1
    ];
    selected = {
        name: solution[name]
        for name in solution
        if name != "T"
    };
    del solution;
    if len(shadowed) != 1 or "U" not in shadowed {
        return -1;
    }
    if ordered != ["U", "V"] or len(selected) != 2 {
        return -2;
    }
    return selected["U"] * 10 + selected["V"];
}

def empty_dictionary_comprehensions -> int {
    source: dict[str, int] = {};
    names = {key for key in source};
    ordered = [key for key in source];
    copied = {key: source[key] for key in source};
    return len(names) + len(ordered) + len(copied);
}

glob item_drops: int = 0;

obj Item {
    has value: int;

    def drop {
        item_drops += 1;
    }
}

def item_drop_count -> int {
    return item_drops;
}

def object_items_comprehension -> int {
    items: dict[str, Item] = {"one": Item(1), "two": Item(2)};
    selected: list[Item] = [
        item
        for (name, item) in items.items()
        if name == "two" and item.value > 0
    ];
    mapped = {name: item.value + 10 for (name, item) in items.items()};
    del items;
    return selected[0].value * 100 + mapped["one"] + mapped["two"];
}

def comprehension_scope(seed: int) -> int {
    name = "outside";
    item = Item(9);
    items: dict[str, Item] = {"one": Item(1), "two": Item(2)};
    values = [item.value for (name, item) in items.items()];
    empty: dict[str, Item] = {};
    none = [item.value for (name, item) in empty.items()];
    nested = [
        seed + item.value for seed in range(2)
        for (name, item) in items.items()
        if name == "two"
    ];
    source = [3, 4];
    copied = [source for source in source];
    if name != "outside" {
        return -11;
    }
    if item.value != 9 {
        return -12;
    }
    if seed != 7 {
        return -13;
    }
    if source != [3, 4] {
        return -21;
    }
    if copied != [3, 4] {
        return -22;
    }
    if len(none) != 0 {
        return -23;
    }
    return values[0] * 100 + values[1] * 10 + nested[0] + nested[1];
}


def stored_items_lifetime -> int {
    items: dict[str, Item] = {"one": Item(1), "two": Item(2)};
    pairs = items.items();
    del items;
    total = 0;
    for (name, item) in pairs {
        total += len(name) + item.value;
    }
    return total;
}


def set_items_lifetime -> int {
    items: dict[str, Item] = {"one": Item(1), "two": Item(2)};
    selected = {item for (name, item) in items.items()};
    del items;
    return len(selected);
}
