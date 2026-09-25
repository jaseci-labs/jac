import from c {
    def regcomp(preg: bytes, pattern: str, cflags: i32) -> i32;  def regexec(
        preg: bytes, string: str, nmatch: u64, pmatch: bytes, eflags: i32
    ) -> i32;  def regfree(preg: bytes);
}

glob _REG_EXTENDED: i32 = 1,
     _REG_ICASE: i32 = 2;


def:pub posix_probe -> int {
    preg: bytes = b"\x00" * 256;
    if regcomp(preg, "a", _REG_EXTENDED) != 0 {
        return 0;
    }
    pm: bytes = b"\x00" * 64;
    rc: i32 = regexec(preg, "a", u64(1), pm, 0);
    regfree(preg);
    if rc != 0 {
        return 0;
    }
    if pm[4] == 1 and pm[8] == 0 {
        return 8;
    }
    if pm[8] == 1 {
        return 16;
    }
    return 0;
}


def:pub posix_compile(pat: str, icase: bool) -> bytes {
    preg: bytes = b"\x00" * 256;
    cflags: i32 = _REG_EXTENDED;
    if icase {
        cflags += _REG_ICASE;
    }
    if regcomp(preg, pat, cflags) != 0 {
        return b"";
    }
    return preg;
}


def:pub posix_exec(preg: bytes, s: str, nmatch: int, width: int) -> bytes {
    pm: bytes = b"\x00" * (width * nmatch);
    if regexec(preg, s, u64(nmatch), pm, 0) != 0 {
        return b"";
    }
    return pm;
}


def:pub pm_off(pm: bytes, width: int, i: int) -> int {
    if width == 8 {
        off: int = i * 4;
        v: int = pm[off]
            | (pm[off + 1] << 8)
            | (pm[off + 2] << 16)
            | (pm[off + 3] << 24);
        if v >= 2147483648 {
            v -= 4294967296;
        }
        return v;
    }
    off = i * 8;
    v = 0;
    k: int = 7;
    while k >= 0 {
        v = v * 256 + pm[off + k];
        k -= 1;
    }
    return v;
}


def:pub posix_free(preg: bytes) {
    regfree(preg);
}
