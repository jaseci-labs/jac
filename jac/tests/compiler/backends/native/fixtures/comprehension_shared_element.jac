"""A comprehension that repeats one object keeps it alive in every element.

`[shared for _ in range(n)]` used to move `shared` out of its variable on the
first pass, because the read was the variable's only use: every later element
was null. The part of a comprehension that runs once per element is a loop,
so nothing read there is moved; only the first source collection runs once."""
obj C {
    has n: int = 0;
}

def repeated(cap: int) -> str {
    shared = C(n=7);
    slots: list[C] = [shared for _i in range(cap)];
    slots[1] = C(n=1);
    slots[2] = C(n=2);
    return " ".join([str(s.n) for s in slots]);
}

def in_dict(cap: int) -> str {
    shared = C(n=9);
    table: dict[int, C] = {i: shared for i in range(cap)};
    table[0] = C(n=0);
    return " ".join([str(table[i].n) for i in range(cap)]);
}

def in_condition(items: list[int]) -> int {
    limit = C(n=2);
    return len(
        [
            i
            for i in items
            if i > limit.n
        ]
    );
}

def nested(rows: int) -> int {
    cell = C(n=1);
    grid = [[cell for _c in range(3)] for _r in range(rows)];
    grid[0][0] = C(n=50);
    total = 0;
    for row in grid {
        for c in row {
            total += c.n;
        }
    }
    return total;
}

def source_once(n: int) -> int {
    data = [C(n=i) for i in range(n)];
    return sum([c.n for c in data]);
}

with entry {
    out = "";
    for rep in range(200) {
        out = f"{repeated(6)} | {in_dict(4)} | {in_condition([1, 2, 3, 4])} | {nested(
            3
        )} | {source_once(5)}";
    }
    print(out);
}
