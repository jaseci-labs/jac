impl Rect.right -> int {
    return self.x + self.width;
}

impl Rect.bottom -> int {
    return self.y + self.height;
}

impl Rect.is_empty -> bool {
    return self.width <= 0 or self.height <= 0;
}

impl Rect.contains_point(col: int, row: int) -> bool {
    return (
        col >= self.x and col < self.right() and row >= self.y and row < self.bottom()
    );
}

impl Rect.intersects(other: Rect) -> bool {
    if self.is_empty() or other.is_empty() {
        return False;
    }
    return (
        self.x < other.right()
        and self.right() > other.x
        and self.y < other.bottom()
        and self.bottom() > other.y
    );
}

impl Rect.copy -> Rect {
    return Rect(x=self.x, y=self.y, width=self.width, height=self.height,);
}


impl rect_union(a: Rect, b: Rect) -> Rect {
    if a.is_empty() {
        return b.copy();
    }
    if b.is_empty() {
        return a.copy();
    }
    x0 = min(a.x, b.x);
    y0 = min(a.y, b.y);
    x1 = max(a.right(), b.right());
    y1 = max(a.bottom(), b.bottom());
    return Rect(x=x0, y=y0, width=x1 - x0, height=y1 - y0);
}
