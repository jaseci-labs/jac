import from crypto { def RAND_bytes(buf: bytes, num: i32) -> i32;  }


def:pub csprng_bytes(n: int) -> bytes {
    if n <= 0 {
        return b"";
    }
    out = b"\x00" * n;
    if RAND_bytes(out, n) != 1 {
        raise ValueError("RAND_bytes failed (CSPRNG entropy unavailable)");
    }
    return out;
}


def:pub to_hex(data: bytes) -> str {
    digits: str = "0123456789abcdef";
    out: str = "";
    n: int = len(data);
    i: int = 0;
    while i < n {
        v: int = data[i];
        out += digits[(v // 16) % 16];
        out += digits[v % 16];
        i += 1;
    }
    return out;
}
