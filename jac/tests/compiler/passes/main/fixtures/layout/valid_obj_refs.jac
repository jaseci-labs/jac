"""Fixture: obj with other obj reference fields."""

obj Point {
    has x: int,
        y: int;
}

obj Line {
    has start: Point,
        end: Point,
        label: str;
}
