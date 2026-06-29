import from _csprng_native { csprng_bytes, to_hex }


def:pub token_bytes(nbytes: int = 32) -> bytes {
    return csprng_bytes(nbytes);
}


def:pub token_hex(nbytes: int = 32) -> str {
    return to_hex(csprng_bytes(nbytes));
}


def:pub token_urlsafe(nbytes: int = 32) -> str {
    data = csprng_bytes(nbytes);
    alphabet: str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    out: str = "";
    n: int = len(data);
    i: int = 0;
    while i + 3 <= n {
        b0: int = data[i];
        b1: int = data[i + 1];
        b2: int = data[i + 2];
        out += alphabet[b0 >> 2];
        out += alphabet[((b0 & 3) << 4) | (b1 >> 4)];
        out += alphabet[((b1 & 15) << 2) | (b2 >> 6)];
        out += alphabet[b2 & 63];
        i += 3;
    }
    rem: int = n - i;
    if rem == 1 {
        b0: int = data[i];
        out += alphabet[b0 >> 2];
        out += alphabet[(b0 & 3) << 4];
    } elif rem == 2 {
        b0: int = data[i];
        b1: int = data[i + 1];
        out += alphabet[b0 >> 2];
        out += alphabet[((b0 & 3) << 4) | (b1 >> 4)];
        out += alphabet[(b1 & 15) << 2];
    }
    return out;
}


def:pub randbelow(exclusive_upper_bound: int) -> int {
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
