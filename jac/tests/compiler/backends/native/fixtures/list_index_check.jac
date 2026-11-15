"""List subscripts with Python index semantics: in range, negative, out of range."""

def read_at(n: int, i: int) -> int {
    xs: list[int] = [];
    for k in range(n) {
        xs.append(k * 10);
    }
    try {
        return xs[i];
    } except IndexError {
        return -999;
    }
}

def write_at(n: int, i: int, v: int) -> int {
    xs: list[int] = [];
    for k in range(n) {
        xs.append(0);
    }
    try {
        xs[i] = v;
    } except IndexError {
        return -999;
    }
    total: int = 0;
    for k in range(n) {
        total = total * 31 + xs[k];
    }
    return total;
}

def walk(n: int) -> int {
    xs: list[int] = [];
    for k in range(n) {
        xs.append(k);
    }
    total: int = 0;
    for k in range(n) {
        total = total + xs[k] - xs[0 - 1 - k];
    }
    return total;
}

with entry {
    print(
        read_at(5, 2),
        read_at(5, -1),
        read_at(5, -5),
        read_at(5, 5),
        read_at(5, -6),
        read_at(0, 0),
        read_at(0, -1)
    );
    print(write_at(4, 1, 7), write_at(4, -1, 7), write_at(4, 4, 7), write_at(4, -5, 7));
    print(walk(1000));
}
