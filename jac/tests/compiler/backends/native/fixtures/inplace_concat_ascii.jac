def grow_ascii(n: int) -> int {
    s = "ab";
    i: int = 0;
    while i < n {
        s += "c";
        i += 1;
    }
    return 1 if s.isascii() else 0;
}

def grow_then_wide(n: int) -> int {
    s = "ab";
    i: int = 0;
    while i < n {
        s += "c";
        i += 1;
    }
    s += "é";
    return (len(s) * 2) + (1 if s.isascii() else 0);
}
