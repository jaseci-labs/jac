import from crypto { def RAND_bytes(buf: bytes, num: i32) -> i32;  }


def:pub csprng_bytes(n: int) -> bytes {
    if n < 0 {
        raise ValueError("negative argument not allowed");
    }
    if n > 2147483647 {
        raise OverflowError("Python int too large to convert to C int");
    }
    if n == 0 {
        return b"";
    }
    out = b"\x00" * n;
    if RAND_bytes(out, i32(n)) != 1 {
        raise ValueError("RAND_bytes failed (CSPRNG entropy unavailable)");
    }
    return out;
}
