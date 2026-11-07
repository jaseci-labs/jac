def check_case(source: str, expected: str, mode: int, ascii: bool) -> int {
    snapshot = source + "";
    result: str;
    if mode == 0 {
        result = source.lower();
    } elif mode == 1 {
        result = source.upper();
    } else {
        result = source.casefold();
    }
    if result != expected {
        return 1;
    }
    if result.isascii() != ascii {
        return 2;
    }
    if len(result) != len(expected) {
        return 3;
    }
    if source != snapshot {
        return 4;
    }
    return 0;
}

def check_view(source: str, expected: str) -> int {
    return check_case(source[1:len(source) - 1], expected, 0, True);
}

glob source = "The QUICK Brown FOX 0123456789!\n" * 40,
     lower = "the quick brown fox 0123456789!\n" * 40,
     upper = "THE QUICK BROWN FOX 0123456789!\n" * 40;

def churn -> int {
    for _ in range(8) {
        assert check_case(source, lower, 0, True) == 0;
        assert check_case(source, upper, 1, True) == 0;
        assert check_case(source, lower, 2, True) == 0;
    }
    return 1;
}

with entry {
    __rc_debug_enable();
    answer = churn();
    __rc_debug_disable();
    print(answer);
}
