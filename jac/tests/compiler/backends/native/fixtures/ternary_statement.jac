"""A conditional expression used as a statement runs one branch for its effect.

`found.append(b) if b else None;` keeps no value, so the branches need no
common type: one call returns None, the other is the literal None.
"""
obj Box {
    has n: int = 0;
}

def collect(first: Box | None, second: Box | None) -> int {
    found: list[Box] = [];
    found.append(first) if first else None;
    found.append(second) if second else found.clear();
    return len(found);
}

def chk_ternary_statement -> int {
    return collect(Box(), Box()) * 100
        + collect(Box(), None) * 10
        + collect(None, None);
}

with entry {
    print(chk_ternary_statement());
}
