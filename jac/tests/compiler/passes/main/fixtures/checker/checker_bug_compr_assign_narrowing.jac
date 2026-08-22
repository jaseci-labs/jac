"""A comprehension on an assignment RHS keeps the enclosing narrowing."""

obj Inner {
    has parts: list[int] = [];
}

obj Outer {
    has name: (Inner | None) = None;
}

def local_target(x: (Inner | None)) -> None {
    if x is None {
        return;
    }
    xs = [p for p in x.parts];
    print(xs);
}

def attribute_target(el: Outer) -> None {
    if el.name is None {
        return;
    }
    xs = [p for p in el.name.parts];
    print(xs);
}

def filtered(x: (Inner | None)) -> None {
    if x is None {
        return;
    }
    xs = [
        p
        for p in x.parts
        if p > 0
    ];
    print(xs);
}

def self_referential(items: list[int]) -> None {
    items = [
        t
        for t in items
        if t > 0
    ];
    print(items);
}
