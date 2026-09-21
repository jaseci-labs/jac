"""An if clause of a comprehension narrows the element and every later clause."""

obj Box {
    has v: int,
        tag: str | None = None;
}

def firsts(xs: list[Box | None]) -> list[int] {
    return [
        x.v
        for x in xs
        if x is not None
        if x.v > 1
    ];
}

def tags(xs: list[Box]) -> list[str] {
    return [
        b.tag.upper()
        for b in xs
        if b.tag is not None
    ];
}

def pairs(xs: list[Box | None], ys: list[int]) -> list[int] {
    return [
        x.v + y
        for x in xs
        if x is not None
        for y in ys
        if y > x.v
    ];
}

def as_set(xs: list[Box | None]) -> set[int] {
    return {
        x.v
        for x in xs
        if x is not None
    };
}

def as_dict(xs: list[Box | None]) -> dict[int, str] {
    return {
        x.v: "ok"
        for x in xs
        if x is not None
        if x.tag is None
    };
}
