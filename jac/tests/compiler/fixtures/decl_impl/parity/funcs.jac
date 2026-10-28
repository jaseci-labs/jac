def tally(n: int) -> int {
    total = 0;
    add = lambda (t: int) -> int {
        total = total + t;
        return total;
    };
    for i in range(n) {
        add(i);
    }
    return total;
}

def scaled(n: int, unused: int) -> int {
    return n * 2;
}

def first_even(items: list[int]) -> int {
    if (
        found
        := [
            i
            for i in items
            if i % 2 == 0
        ]
    ) {
        return found[0];
    }
    return -1;
}

def outer(n: int) -> int {
    def inner(m: int) -> int {
        return m * 2;
    }
    return inner(n) + 1;
}

obj Point {
    has x: int = 0,
        y: int = 0;

    def norm1 -> int {
        return abs(self.x) + abs(self.y);
    }

    def shifted(dx: int) -> Point {
        return Point(x=self.x + dx, y=self.y);
    }

    static def origin -> Point {
        return Point();
    }
}

with entry {
    print(
        tally(4),
        scaled(2, 0),
        first_even([1, 4, 6]),
        outer(3),
        Point(x=1, y=-2).shifted(2).norm1(),
        Point.origin().x
    );
}
