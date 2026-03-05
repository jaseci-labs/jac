"""Test fixture for tuple and struct marshalling."""

obj Point {
    has x: int,
        y: int;
}

obj Result {
    has value: int,
        label: str;
}

def make_point(x: int, y: int) -> Point {
    return Point(x=x, y=y);
}

def make_result(v: int, s: str) -> Result {
    return Result(value=v, label=s);
}

def point_list(n: int) -> list[Point] {
    result: list[Point] = [];
    i = 0;
    while i < n {
        result.append(Point(x=i, y=i * 2));
        i = i + 1;
    }
    return result;
}

def split_points(n: int) -> tuple[list[Point], list[int]] {
    points: list[Point] = [];
    sums: list[int] = [];
    i = 0;
    while i < n {
        points.append(Point(x=i, y=i * 10));
        sums.append(i + i * 10);
        i = i + 1;
    }
    return (points, sums);
}

with entry {
    x = 0;
}
