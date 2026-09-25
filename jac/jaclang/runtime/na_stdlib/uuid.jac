import from _csprng_native { csprng_bytes }
import from _hex { to_hex }


obj:pub UUID {
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


def:pub uuid4 -> UUID {
    src = csprng_bytes(16);
    raw: list[int] = [];
    i: int = 0;
    while i < 16 {
        raw.append(src[i]);
        i += 1;
    }
    raw[6] = (raw[6] & 15) | 64;
    raw[8] = (raw[8] & 63) | 128;
    return UUID(hex=to_hex(bytes(raw)), version=4);
}
