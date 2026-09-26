"""Unannotated locals whose bindings disagree on their native type."""

def mixed_member_values -> int {
    total = 0;
    for i in range(6) {
        v = None;
        if i % 2 == 0 {
            v = "7";
        }
        if i % 3 == 0 {
            v = int("1" + str(i));
        }
        if isinstance(v, int) {
            total += v;
        } elif isinstance(v, str) {
            total += 100 * len(v);
        }
    }
    return total;
}

def optional_str_stays_text -> int {
    s = None;
    s = "hello";
    return len(s);
}

def one_type_stays_scalar -> int {
    n = 1;
    n = n + 41;
    return n;
}
