obj UUID {
    has hex: str,
        version: int = 4;

    def __str__ -> str {
        h: str = self.hex;
        return h[0:8]
            + "-"
            + h[8:12]
            + "-"
            + h[12:16]
            + "-"
            + h[16:20]
            + "-"
            + h[20:32];
    }
}


def _hex(n: int) -> str {
    digits: str = "0123456789abcdef";
    return digits[n];
}


def:pub uuid4 -> UUID {
    out: str = "00000000000000000000000000000000";
    i: int = 0;
    built: str = "";
    while i < 32 {
        built += _hex((i * 11 + 5) % 16);
        i += 1;
    }
    return UUID(hex=built, version=4);
}
