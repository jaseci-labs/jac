node Shape {
    has sides: int = 0;
}

node Square(Shape) {
    def __str__ -> str {
        return "square";
    }
}

node Triangle(Shape) {
    def __str__ -> str {
        return "triangle";
    }
}

node Blob(Shape) {}

def pick(n: int) -> Shape {
    if n == 1 {
        return Square();
    }
    if n == 2 {
        return Triangle();
    }
    return Blob();
}

def str_through_base -> int {
    return (1 if str(pick(1)) == "square" else 0)
        + (2 if f"{pick(2)}" == "triangle" else 0);
}

def base_without_str_keeps_default_repr -> int {
    return 1 if str(pick(3)).startswith("<") else 0;
}
