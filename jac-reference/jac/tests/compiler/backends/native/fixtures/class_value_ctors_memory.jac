obj Shape {
    has size: int;

    def area -> int {
        return self.size;
    }
}

obj Square(Shape) {
    has sides: int = 4;

    def area -> int {
        return self.size * self.sides;
    }
}

def build(kind: type[Shape], size: int) -> Shape {
    return kind(size=size);
}

def pick(wide: bool) -> type[Shape] {
    return Square if wide else Shape;
}

with entry {
    print(build(Shape, 3).area() + build(pick(True), 3).area());
}
