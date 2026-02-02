obj Point {
    has x: int = 0, y: int = 0;

    def get_x() -> int {
        return self.x;
    }

    def get_y() -> int {
        return self.y;
    }

    def sum() -> int {
        return self.x + self.y;
    }
}

obj Counter {
    has count: int = 0;

    def increment() -> None {
        self.count = self.count + 1;
    }

    def get_count() -> int {
        return self.count;
    }
}

def make_point(x: int, y: int) -> Point {
    return Point(x=x, y=y);
}

def point_sum(x: int, y: int) -> int {
    p: Point = Point(x=x, y=y);
    return p.sum();
}

def test_counter() -> int {
    c: Counter = Counter();
    c.increment();
    c.increment();
    c.increment();
    return c.get_count();
}

def test_none() -> int {
    p: Point = Point(x=1, y=2);
    if p is not None {
        return 1;
    }
    return 0;
}
