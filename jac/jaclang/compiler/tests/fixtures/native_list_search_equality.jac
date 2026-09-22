def search_strings -> int {
    values = ["attak201", "attak202", "attak201"];
    needle = "attak" + str(201);
    if not (needle == values[0] and needle in values) {
        return 0;
    }
    if not (values.index(needle) == 0) {
        return 0;
    }
    if not (values.count(needle) == 2) {
        return 0;
    }
    values.remove(needle);
    if not (len(values) == 2 and values[0] == "attak202") {
        return 0;
    }
    if not (values.index(needle) == 1 and values.count(needle) == 1) {
        return 0;
    }
    if not (values.count("absent") == 0) {
        return 0;
    }
    return 1;
}

def search_floats -> int {
    values = [1.5, -0.0, 1.5];
    if not (values.index(1.5) == 0 and values.count(1.5) == 2) {
        return 0;
    }
    if not (values.index(0.0) == 1) {
        return 0;
    }
    values.remove(1.5);
    if not (len(values) == 2 and values[0] == 0.0) {
        return 0;
    }
    return 1;
}

def search_bytes -> int {
    values = [b"a\x00b", b"different", b"a\x00b"];
    needle = bytes([97, 0, 98]);
    if not (values.index(needle) == 0 and values.count(needle) == 2) {
        return 0;
    }
    values.remove(needle);
    if not (len(values) == 2 and values.index(needle) == 1) {
        return 0;
    }
    if not (values.count(b"a\x00c") == 0) {
        return 0;
    }
    return 1;
}

def search_lists -> int {
    values = [[1, 2], [3, 4], [1, 2]];
    needle = [1, 2];
    if not (values.index(needle) == 0 and values.count(needle) == 2) {
        return 0;
    }
    values.remove(needle);
    if not (len(values) == 2 and values.index(needle) == 1) {
        return 0;
    }
    return 1;
}

def search_missing -> int {
    values = ["present"];
    try {
        values.index("missing" + str(1));
    } except ValueError {
        return 1;
    }
    return 0;
}
