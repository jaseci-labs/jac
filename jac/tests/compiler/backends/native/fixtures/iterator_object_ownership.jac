"""Iteration borrows container elements; loop locals own separate references."""
obj Part {
    has values: list[int];
}

def scan_enumerate(parts: list[Part]) {
    for (index, part) in enumerate(parts) {
        if index == 0 {
            continue;
        }
        assert part.values[0] == 22;
    }
}

def scan_iter(parts: list[Part]) {
    for part in iter(parts) {
        assert part.values[0] > 0;
    }
}

def scan_zip(parts: list[Part]) {
    for (left, right) in zip(parts, parts) {
        assert left.values[0] == right.values[0];
    }
}

def enumerate_keeps_elements -> int {
    parts = [Part(values=[20]), Part(values=[22])];
    scan_enumerate(parts);
    return parts[0].values[0] + parts[1].values[0];
}

def iter_keeps_elements -> int {
    parts = [Part(values=[20]), Part(values=[22])];
    scan_iter(parts);
    return parts[0].values[0] + parts[1].values[0];
}

def zip_keeps_elements -> int {
    parts = [Part(values=[20]), Part(values=[22])];
    scan_zip(parts);
    return parts[0].values[0] + parts[1].values[0];
}
