def pystr_count_char(s: str, ch: int) -> int {
    n: int = 0;
    i: int = 0;
    want: int = 0;
    got: int = 0;
    if (s == 0) {
        return 0;
    }

    want = ch & 255;
    n = 0;
    i = 0;
    while (s[i] != 0) {
        got = s[i] & 255;
        if (got == want) {
            n += 1;
        }

        i += 1;
    }

    return n;
}
