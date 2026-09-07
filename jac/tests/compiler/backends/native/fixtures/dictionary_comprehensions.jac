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
