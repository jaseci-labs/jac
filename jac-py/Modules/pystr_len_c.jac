def pystr_len_c(s: str) -> int {
    n: int = 0;
    n = 0;
    if (s == 0) {
        return 0;
    }

    while (s[n] != 0) {
        n += 1;
    }

    return n;
}
