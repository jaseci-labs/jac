def pystr_startswith_c(s: str, prefix: str) -> int {
    i: int = 0;
    if ((s == 0) or (prefix == 0)) {
        return 0;
    }

    i = 0;
    while (prefix[i] != 0) {
        if (s[i] == 0) {
            return 0;
        }

        if ((s[i] & 255) != (prefix[i] & 255)) {
            return 0;
        }

        i += 1;
    }

    return 1;
}
