obj Shape {
    has sides: int = 0;

    def area -> int {
        return 0;
    }
}

obj Square(Shape) {
    has width: int = 2;

    def area -> int {
        return self.width * self.width;
    }
}

obj Named(Square) {
    has label: str = "n";

    def __repr__ -> str {
        return "Named<" + self.label + ">";
    }
}

def pick(n: int) -> Shape {
    if n == 1 {
        return Square(sides=4);
    }
    if n == 2 {
        return Named(sides=4, width=3, label="q");
    }
    return Shape();
}

with entry {
    print(pick(0), pick(1), pick(2));
    shapes: list[Shape] = [pick(1), pick(0), pick(2)];
    print(shapes, str(pick(1)), f"{pick(2)}");
}
