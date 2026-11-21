"""Lists of objects reversed and sorted in place keep every element."""
obj Point {
    has x: float = 0.0,
        y: float = 0.0;
}

def by_x(point: Point) -> float {
    return point.x;
}

"""Allocate and drop enough that an element freed by mistake is reused."""
def churn -> int {
    total = 0;
    for round in range(50) {
        junk: list[Point] = [];
        for i in range(200) {
            junk.append(Point(x=float(i) + 1000.0, y=9.0));
        }
        total += len(junk);
    }
    return total;
}

def reversed_points(count: int) -> list[Point] {
    items: list[Point] = [];
    for i in range(count) {
        items.append(Point(x=float(i), y=2.0));
    }
    items.reverse();
    return items;
}

with entry {
    even = reversed_points(8);
    odd = reversed_points(5);
    churn();
    print([int(point.x) for point in even], [int(point.y) for point in even]);
    print([int(point.x) for point in odd], [int(point.y) for point in odd]);
    shuffled: list[Point] = [Point(x=float((i * 5) % 8), y=2.0) for i in range(8)];
    shuffled.sort(key=by_x);
    churn();
    print([int(point.x) for point in shuffled], [int(point.y) for point in shuffled]);
    rows: list[list[int]] = [[i, i * 2] for i in range(4)];
    rows.reverse();
    lookups: list[dict[str, int]] = [{"n": i} for i in range(5)];
    lookups.reverse();
    churn();
    print(rows);
    print([lookup["n"] for lookup in lookups]);
}
