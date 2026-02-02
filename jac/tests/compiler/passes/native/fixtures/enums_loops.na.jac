enum Color {
    WHITE = 0,
    BLACK = 1
}

enum Kind {
    PAWN = 0,
    KNIGHT = 1,
    BISHOP = 2
}

def opposite_color(c: int) -> Color {
    if c == Color.WHITE {
        return Color.BLACK;
    }
    return Color.WHITE;
}

def sum_range(n: int) -> int {
    total: int = 0;
    for i in range(n) {
        total = total + i;
    }
    return total;
}

def first_break(n: int) -> int {
    result: int = 0;
    for i in range(n) {
        if i == 5 {
            break;
        }
        result = result + 1;
    }
    return result;
}

def skip_even(n: int) -> int {
    total: int = 0;
    for i in range(n) {
        if i % 2 == 0 {
            continue;
        }
        total = total + i;
    }
    return total;
}

def bool_and(a: int, b: int) -> int {
    if a > 0 and b > 0 {
        return 1;
    }
    return 0;
}

def bool_or(a: int, b: int) -> int {
    if a > 0 or b > 0 {
        return 1;
    }
    return 0;
}

def ternary_test(x: int) -> int {
    result: int = 10 if x > 0 else -10;
    return result;
}

def enum_kind_test(k: int) -> int {
    if k == Kind.PAWN {
        return 100;
    } elif k == Kind.KNIGHT {
        return 200;
    } elif k == Kind.BISHOP {
        return 300;
    }
    return 0;
}
