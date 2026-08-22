def pystr_cmp_c(a: str, b: str) -> int {
    i: int = 0;
    ca: int = 0;
    cb: int = 0;
    if ((a == 0) and (b == 0)) {
        return 0;
    }

    if (a == 0) {
        return -1;
    }

    if (b == 0) {
        return 1;
    }

    i = 0;
    while 1 {
        ca = a[i] & 255;
        cb = b[i] & 255;
        if (ca != cb) {
            return (ca - cb);
        }

        if (ca == 0) {
            return 0;
        }

        i += 1;
    }
}
