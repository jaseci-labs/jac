obj Shape {
    has size: int;

    def area -> int {
        return self.size;
    }
}

obj Circle(Shape) {
    def area -> int {
        return 3 * self.size * self.size;
    }
}

obj Counter {
    has start: int = 1,
        step: int = 1;
}

obj Point {
    has x: int = 0,
        y: int = 0;

    def init(x: int, y: int = 5) {
        self.x = x;
        self.y = y;
    }
}

obj Factory {
    has kind: type[Shape];

    def make(size: int) -> Shape {
        return self.kind(size=size);
    }
}

def build(kind: type[Shape], size: int) -> Shape {
    return kind(size=size);
}

def build_positional(kind: type[Shape], size: int) -> Shape {
    return kind(size);
}

def build_from(kind: type[Shape], options: dict[str, int]) -> int {
    try {
        return kind(**options).area();
    } except TypeError {
        return -1;
    }
}

def allocate(kind: type[Shape], size: int) -> Shape {
    return new(kind, size);
}

def try_build(kind: type[Shape], size: int) -> int {
    try {
        return build(kind, size).area();
    } except TypeError {
        return -1;
    }
}

def count_from(kind: type[Counter]) -> Counter {
    return kind();
}

def count_by(kind: type[Counter], step: int) -> Counter {
    return kind(step=step);
}

def place(kind: type[Point], x: int) -> Point {
    return kind(x);
}

def place_both(kind: type[Point], x: int, y: int) -> Point {
    return kind(x, y=y);
}

def try_place(kind: type[Point]) -> int {
    try {
        return place(kind, 1).x;
    } except TypeError {
        return -1;
    }
}
