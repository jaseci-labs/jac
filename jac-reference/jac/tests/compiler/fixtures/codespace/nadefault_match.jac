"""Pure markerless module whose only exotic constructs are structural
match patterns (sequence, star, mapping). Under a native default the
classifier must infer native: structural patterns lower natively and are
no longer server signals."""

def shape_code(n: int) -> int {
    xs: list[int] = [];
    for i in range(n) {
        xs.append(i);
    }
    match xs {
        case []: return 0;
        case [a]: return 1;
        case [a, *rest]: return 2 + len((rest as list[int]));
        case _: return -1;
    }
}

def probe(k: int) -> int {
    d: dict[str, int] = {"a": 1, "b": 2};
    match d {
        case {"a": v} if k == 0: return (v as int);
        case {"a": v, "b": w}: return (v as int) + (w as int);
        case _: return -1;
    }
}

with entry {
    print(shape_code(3), probe(1));
}
