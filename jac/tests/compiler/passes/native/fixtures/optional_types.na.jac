"""Test fixture for native Optional[T] via JacOptional tagged union."""

enum Color {
    RED = "red",
    GREEN = "green",
    BLUE = "blue"
}

def get_maybe_int(x: int) -> int | None {
    if x > 0 {
        return x * 2;
    }
    return None;
}

def get_maybe_float(x: float) -> float | None {
    if x > 0.0 {
        return x * 3.14;
    }
    return None;
}

def get_maybe_color(x: int) -> Color | None {
    if x == 0 {
        return Color.RED;
    }
    if x == 1 {
        return Color.GREEN;
    }
    if x == 2 {
        return Color.BLUE;
    }
    return None;
}

def check_is_none(x: int) -> int {
    val: int | None = get_maybe_int(x);
    if val is None {
        return -1;
    }
    return 1;
}

def check_is_not_none(x: int) -> int {
    val: int | None = get_maybe_int(x);
    if val is not None {
        return 1;
    }
    return -1;
}

def pointer_optional_still_works(x: int) -> str | None {
    if x > 0 {
        return "hello";
    }
    return None;
}
