obj Point {
    has x: int,
        y: float = 1.5;
}

obj Named(Point) {
    has label: str = "p",
        tags: list[str] = [];
}

obj Empty {}

node Stop {
    has val: int;
}

obj Holder {
    has inner: Point,
        maybe: Point | None = None,
        flag: bool = True;
}

obj Link {
    has name: str,
        nxt: Link | None = None;
}

obj Bag {
    has counts: dict[str, int] = {},
        seen: set[int] = {1},
        pair: tuple[int, str] = (1, "a"),
        anything: any = None,
        ratio: float = 0.1;
}

walker Tour {
    has depth: int = 2;
}

edge Road: any --> any {
    has km: int = 5;
}

with entry {
    p = Point(x=3);
    print(p);
    print(Named(x=1, y=2.0, label="it's", tags=["a", "b"]));
    print(Empty(), Stop(val=7));
    print(Holder(inner=p), [p, Point(x=4, y=0.5)]);
    print(str(p), f"{p}");
    chain = Link(name="a", nxt=Link(name="b"));
    print(chain);
    print(Bag(counts={"x": 1}, anything="q"));
    print(Tour(), Road(km=9));
    print([Link(name="z")], {"k": Link(name="v")});
}
