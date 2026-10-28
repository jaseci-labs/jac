"""A conditional expression with a tuple a function returned on one side and
a tuple literal on the other."""

def named(x: int) -> tuple[str, float] {
    return ("n" * x, float(x));
}

def pair(x: int) -> tuple[int, int] {
    return (x, x * 2);
}

def chosen(flag: bool) -> float {
    (word, value) = named(2) if flag else ("s", 0.5);
    return value + float(len(word));
}

def reversed_sides(flag: bool) -> int {
    found = (7, 8) if flag else pair(3);
    return found[0] + found[1];
}

def many(count: int) -> int {
    total = 0;
    for k in range(count) {
        (word, value) = named(k % 3) if k % 2 == 0 else ("ab", 1.0);
        total += len(word) + int(value);
    }
    return total;
}

with entry {
    print(chosen(True), chosen(False));
    print(reversed_sides(True), reversed_sides(False));
    print(many(1000));
}
