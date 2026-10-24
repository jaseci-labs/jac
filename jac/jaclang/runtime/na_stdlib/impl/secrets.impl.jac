impl compare_digest(a: bytes, b: bytes) -> bool {
    return _hmac_compare_digest(a, b);
}

impl token_bytes(nbytes: any = None) -> bytes {
    n: int = DEFAULT_ENTROPY;
    if isinstance(nbytes, bool) {
        n = 1 if nbytes else 0;
    } elif isinstance(nbytes, int) {
        n = nbytes;
    } elif nbytes is not None {
        raise TypeError(
            "'" + typename(nbytes) + "' object cannot be interpreted as an integer"
        );
    }
    return csprng_bytes(n);
}

impl token_hex(nbytes: any = None) -> str {
    return to_hex(token_bytes(nbytes));
}

impl token_urlsafe(nbytes: any = None) -> str {
    return urlsafe_b64encode(token_bytes(nbytes)).decode().rstrip("=");
}

impl randbelow(exclusive_upper_bound: int) -> int {
    if exclusive_upper_bound <= 0 {
        raise ValueError("Upper bound must be positive.");
    }
    bits: int = 0;
    t: int = exclusive_upper_bound;
    while t > 0 {
        bits += 1;
        t = t >> 1;
    }
    nbytes: int = (bits + 7) // 8;
    mask: int = (1 << bits) - 1;

    r: int = exclusive_upper_bound;
    while r >= exclusive_upper_bound {
        data = csprng_bytes(nbytes);
        r = 0;
        i: int = 0;
        while i < nbytes {
            r = (r << 8) | data[i];
            i += 1;
        }
        r = r & mask;
    }
    return r;
}
