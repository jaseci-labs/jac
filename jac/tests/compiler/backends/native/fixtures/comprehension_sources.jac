glob POINTS: set[int] = {ord(c) for c in "xyz"};

def stepped -> int {
    xs = [i for i in range(1, 10, 3)];
    return len(xs) * 100 + xs[2];
}

def descending -> int {
    xs = [i for i in range(10, 0, -4)];
    return len(xs) * 100 + xs[2];
}

def over_str -> int {
    points = {ord(c) for c in "abca"};
    return len(points) * 10 + (1 if 99 in points else 0);
}

def over_glob_literal -> int {
    return len(POINTS) * 10 + (1 if 121 in POINTS else 0);
}

def over_bytes -> int {
    xs = [b * 2 for b in b"\x01\x02\x03"];
    return len(xs) * 100 + xs[2];
}

def over_set -> int {
    doubled = [x * 2 for x in {5, 6}];
    return len(doubled) * 100 + doubled[0] + doubled[1];
}

def short_circuit -> int {
    xs = [
        12 // x
        for x in [4, 0, 3]
        if x != 0
        if 12 // x > 3
    ];
    return len(xs) * 100 + xs[0];
}

def enumerated -> int {
    idx = [
        i
        for (i, c) in enumerate("banana")
        if c == "a"
    ];
    return idx[0] * 100 + idx[1] * 10 + idx[2];
}
