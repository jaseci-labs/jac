"""Fixture for W2050: Missing return statement (not all paths return)."""

def bad_func(x: int) -> int {
    if x > 0 {
        return x;
    }
    # Missing return for x <= 0 path!  # <-- Warning W2050
}

def good_func(x: int) -> int {
    if x > 0 {
        return x;
    } else {
        return -x;  # <-- Ok: all paths return
    }
}

def also_good(x: int) -> int {
    if x > 0 {
        return x;
    }
    return 0;  # <-- Ok: fallthrough return
}
