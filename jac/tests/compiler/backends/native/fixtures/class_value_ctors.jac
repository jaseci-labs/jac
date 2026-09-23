import from class_value_ctors_lib {
    Counter,
    Factory,
    Point,
    Shape,
    allocate,
    build,
    build_from,
    build_positional,
    count_by,
    count_from,
    place,
    place_both,
    try_build,
    try_place
}

obj Square(Shape) {
    has label: str = "square";

    def area -> int {
        return self.size * self.size;
    }
}

obj Tagged(Shape) {
    has tag: str;
}

obj Hundred(Counter) {
    has start: int = 100;
}

obj Scaled(Point) {
    has scale: int = 3;
}

obj Named(Point) {
    def init(label: str) {
        self.x = len(label);
        self.y = 0;
    }
}

obj Shifted(Point) {
    def init(x: int, y: int = 7) {
        self.x = x + 10;
        self.y = y;
    }
}

node Box {
    has n: int = 0;
}

obj Ctx {
    has log: list[str] = [];
}

walker Base {
    has ctx: Ctx,
        box: Box;
}

walker Inc(Base) {
    can go with Box entry {
        here.n += 1;
        self.ctx.log.append("inc");
    }
}

walker Dbl(Base) {
    has factor: int = 2;

    can go with Box entry {
        here.n *= self.factor;
        self.ctx.log.append("dbl");
    }
}

edge Link: Box --> Box {
    has weight: int = 1;
}

edge Heavy(Link) {
    has extra: int = 5;
}

node Tile {
    has cost: int = 1;
}

node Wall(Tile) {
    has cost: int = 9,
        hp: int = 3;
}

glob PASSES: tuple[type[Base], ...] = (Inc, Dbl, Inc);

def make_link(kind: type[Link], weight: int) -> Link {
    return kind(weight=weight);
}

def launch(kind: type[Base], box: Box, **options: any) -> Base {
    return kind(box=box, **options);
}

def make_tile(kind: type[Tile]) -> Tile {
    return kind();
}

def total_area(kinds: list[type[Shape]], size: int) -> int {
    total = 0;
    for kind in kinds {
        total += kind(size=size).area();
    }
    return total;
}

def pick(big: bool) -> type[Shape] {
    return Square if big else Shape;
}

with entry {
    print(build(Square, 3).area(), build(Shape, 3).area());
    print(build_positional(Square, 4).area());
    square = build(Square, 2);
    print(square.size, isinstance(square, Square));
    print(try_build(Tagged, 2), try_build(Square, 5));
    print(
        count_from(Counter).start, count_from(Hundred).start, count_by(Hundred, 7).step
    );
    print(place(Point, 2).y, place(Scaled, 2).x, place_both(Scaled, 1, 9).y);
    print(try_place(Named), place(Shifted, 1).x, place(Shifted, 1).y);
    print(total_area([Shape, Square], 3));
    factory = Factory(kind=Square);
    print(factory.make(6).area());
    print(allocate(Square, 7).area());
    box = Box(n=1);
    ctx = Ctx();
    for step in PASSES {
        walker_value = step(ctx=ctx, box=box);
        box spawn walker_value;
    }
    print(box.n, len(ctx.log));
    launched = launch(Dbl, box, ctx=ctx);
    box spawn launched;
    print(
        box.n,
        build_from(Square, {"size": 5}),
        build_from(Square, {"size": 1, "sides": 4})
    );
    print(make_link(Heavy, 4).weight, make_link(Link, 2).weight);
    print(make_tile(Wall).cost, make_tile(Tile).cost, pick(True)(size=2).area());
}
