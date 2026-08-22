def pystr_find_char(s: str, ch: int) -> int {
    i: int = 0;
    want: int = 0;
    got: int = 0;
    if (s == 0) {
        return -1;
    }

    want = ch & 255;
    i = 0;
    while (s[i] != 0) {
        got = s[i] & 255;
        if (got == want) {
            return i;
        }

        i += 1;
    }

    return -1;
}
