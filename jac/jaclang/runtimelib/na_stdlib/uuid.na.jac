import from _csprng_native { csprng_bytes }


obj:pub UUID {
    has hex: str,
        version: int = 4;

    def __str__ -> str {
        h: str = self.hex;
        return h[0:8] + "-" + h[8:12] + "-" + h[12:16] + "-" + h[16:20] + "-" + h[20:32];
    }
}


def:pub uuid4 -> UUID {
    raw = csprng_bytes(16);
    digits: str = "0123456789abcdef";
    out: str = "";
    i: int = 0;
    while i < 16 {
        v: int = raw[i];
        if i == 6 {
            v = (v & 15) | 64;
        }
        if i == 8 {
            v = (v & 63) | 128;
        }
        out += digits[v >> 4];
        out += digits[v & 15];
        i += 1;
    }
    return UUID(hex=out, version=4);
}
