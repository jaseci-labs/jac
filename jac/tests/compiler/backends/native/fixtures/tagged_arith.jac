"""Arithmetic on `int | float` values and on `any` narrowed to numbers."""

def show(a: int | float, b: int | float) {
    print(a + b, a - b, a * b, a / b, a // b, a % b);
}

def scaled(v: any) -> any {
    if isinstance(v, (int, float)) {
        return v * 2 + 1;
    }
    return None;
}

def negated(v: any) -> any {
    if isinstance(v, (int, float, bool)) {
        return -v;
    }
    return None;
}

def plus(v: int | float) -> int | float {
    return +v;
}

def wrong(v: any) -> str {
    try {
        return str(v + 1);
    } except TypeError {
        return "TypeError";
    }
}

with entry {
    show(7, 2);
    show(-7, 2);
    show(7.5, 2);
    show(-7, 2.5);
    print(scaled(3), scaled(0.25), scaled("s"));
    print(negated(0.0), negated(True), negated(-4), negated(2.5));
    print(plus(4), plus(-2.5));
    print(wrong(1), wrong(1.5), wrong("a"), wrong(None));
}
