"""Container keys preserve string content after embedded NUL bytes."""
def:pub string_nul_keys -> int {
    nul = chr(0);
    if len(nul) != 1 {
        return 3;
    }
    keys = ["", nul, nul + "tail", "x", "x" + nul, "x" + nul + "tail"];
    values: dict[str, int] = {};
    tuples: set[tuple[str, int]] = set();
    for i in range(len(keys)) {
        values[keys[i]] = i;
        tuples.add((keys[i], 7));
    }
    if len(values) != 6 {
        return 10 + len(values);
    }
    if len(tuples) != 6 {
        return 20 + len(tuples);
    }
    for i in range(len(keys)) {
        key = ("prefix" + keys[i])[6:];
        if values[key] != i or (key, 7) not in tuples {
            return 2;
        }
    }
    return 0;
}
