obj Point {
    has x: int,
        y: int;
}

with entry {
    kw: dict[str, int] = {"y": 5, "x": 4};
    p = Point(**kw);
    print(p.x, p.y);
}
