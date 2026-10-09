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


def _strip_dashes(s: any) -> str {
    out: str = "";
    for ch in s {
        if ch != "-" {
            out += ch;
        }
    }
    return out;
}


def _fallback_uuid4 -> str {
    out: str = "";
    for _ in range(32) {
        n: int = int(Math.floor(Math.random() * 16));
        out += hex(n)[2:];
    }
    return out;
}


def:pub uuid4 -> UUID {
    crypto = globalThis.crypto;
    if crypto and crypto.randomUUID {
        return UUID(hex=_strip_dashes(crypto.randomUUID()), version=4);
    }
    return UUID(hex=_fallback_uuid4(), version=4);
}
