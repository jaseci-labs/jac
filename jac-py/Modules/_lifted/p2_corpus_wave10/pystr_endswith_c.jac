def pystr_len_u(s: str) -> int {
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

def pystr_endswith_c(s: str, suffix: str) -> int {
    ns: int = 0;
    nfx: int = 0;
    i: int = 0;
    if ((s == 0) or (suffix == 0)) {
        return 0;
    }

    ns = pystr_len_u(s);
    nfx = pystr_len_u(suffix);
    if (nfx > ns) {
        return 0;
    }

    i = 0;
    while (i < nfx) {
        if ((s[((ns - nfx) + i)] & 255) != (suffix[i] & 255)) {
            return 0;
        }

        i += 1;
    }

    return 1;
}
