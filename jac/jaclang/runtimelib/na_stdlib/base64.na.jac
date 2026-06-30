glob _B16: bytes = b"0123456789ABCDEF",
     _B32: bytes = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567",
     _B64: bytes = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
     _B85: bytes = b"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~",
     _PAD: int = 61;


def _make_rev(alphabet: bytes) -> list[int] {
    rev: list[int] = [];
    k: int = 0;
    while k < 256 {
        rev.append(-1);
        k += 1;
    }
    n: int = len(alphabet);
    j: int = 0;
    while j < n {
        rev[alphabet[j]] = j;
        j += 1;
    }
    return rev;
}


def _encode_bits(data: bytes, alphabet: bytes, bits: int, quantum: int) -> bytes {
    out: list[int] = [];
    acc: int = 0;
    nbits: int = 0;
    mask: int = (1 << bits) - 1;
    n: int = len(data);
    i: int = 0;
    while i < n {
        acc = (acc << 8) | data[i];
        nbits += 8;
        while nbits >= bits {
            nbits -= bits;
            out.append(alphabet[(acc >> nbits) & mask]);
        }
        acc = acc & ((1 << nbits) - 1);
        i += 1;
    }
    if nbits > 0 {
        out.append(alphabet[(acc << (bits - nbits)) & mask]);
    }
    while quantum > 1 and (len(out) % quantum) != 0 {
        out.append(_PAD);
    }
    return bytes(out);
}


def _decode_bits(data: bytes, rev: list[int], bits: int) -> bytes {
    out: list[int] = [];
    acc: int = 0;
    nbits: int = 0;
    n: int = len(data);
    i: int = 0;
    while i < n {
        c: int = data[i];
        if c == _PAD {
            break;
        }
        v: int = rev[c];
        if v < 0 {
            raise ValueError("Invalid base-encoded character: " + str(c));
        }
        acc = (acc << bits) | v;
        nbits += bits;
        if nbits >= 8 {
            nbits -= 8;
            out.append((acc >> nbits) & 255);
            acc = acc & ((1 << nbits) - 1);
        }
        i += 1;
    }
    return bytes(out);
}


def:pub b16encode(s: bytes) -> bytes {
    return _encode_bits(s, _B16, 4, 1);
}


def:pub b16decode(s: bytes, casefold: bool = False) -> bytes {
    rev: list[int] = _make_rev(_B16);
    if casefold {
        rev[97] = 10;
        rev[98] = 11;
        rev[99] = 12;
        rev[100] = 13;
        rev[101] = 14;
        rev[102] = 15;
    }
    return _decode_bits(s, rev, 4);
}


def:pub b32encode(s: bytes) -> bytes {
    return _encode_bits(s, _B32, 5, 8);
}


def:pub b32decode(s: bytes, casefold: bool = False) -> bytes {
    rev: list[int] = _make_rev(_B32);
    if casefold {
        j: int = 0;
        while j < 26 {
            rev[97 + j] = j;
            j += 1;
        }
    }
    return _decode_bits(s, rev, 5);
}


def _b64_alphabet(altchars: bytes) -> bytes {
    if len(altchars) == 2 {
        return _B64[0:62] + altchars;
    }
    return _B64;
}


def:pub b64encode(s: bytes, altchars: bytes = b"") -> bytes {
    return _encode_bits(s, _b64_alphabet(altchars), 6, 4);
}


def:pub b64decode(s: bytes, altchars: bytes = b"") -> bytes {
    return _decode_bits(s, _make_rev(_b64_alphabet(altchars)), 6);
}


def:pub standard_b64encode(s: bytes) -> bytes {
    return b64encode(s, b"");
}


def:pub standard_b64decode(s: bytes) -> bytes {
    return b64decode(s, b"");
}


def:pub urlsafe_b64encode(s: bytes) -> bytes {
    return b64encode(s, b"-_");
}


def:pub urlsafe_b64decode(s: bytes) -> bytes {
    return b64decode(s, b"-_");
}


def:pub b85encode(b: bytes, pad: bool = False) -> bytes {
    n: int = len(b);
    padding: int = (4 - (n % 4)) % 4;
    work: bytes = b;
    if padding > 0 {
        work = b + (b"\x00" * padding);
    }
    out: list[int] = [];
    m: int = len(work);
    i: int = 0;
    while i < m {
        b0: int = work[i];
        b1: int = work[i + 1];
        b2: int = work[i + 2];
        b3: int = work[i + 3];
        word: int = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3;

        d4: int = word % 85;
        word = word // 85;
        d3: int = word % 85;
        word = word // 85;
        d2: int = word % 85;
        word = word // 85;
        d1: int = word % 85;
        word = word // 85;
        d0: int = word % 85;
        out.append(_B85[d0]);
        out.append(_B85[d1]);
        out.append(_B85[d2]);
        out.append(_B85[d3]);
        out.append(_B85[d4]);
        i += 4;
    }
    res: bytes = bytes(out);
    if padding > 0 and not pad {
        res = res[0:len(res) - padding];
    }
    return res;
}


def:pub b85decode(b: bytes) -> bytes {
    rev: list[int] = _make_rev(_B85);
    n: int = len(b);
    padding: int = (5 - (n % 5)) % 5;
    out: list[int] = [];
    i: int = 0;
    while i < n {
        acc: int = 0;
        j: int = 0;
        while j < 5 {
            c: int = 126;
            if i + j < n {
                c = b[i + j];
            }
            v: int = rev[c];
            if v < 0 {
                raise ValueError("bad base85 character: " + str(c));
            }
            acc = acc * 85 + v;
            j += 1;
        }
        if acc > 4294967295 {
            raise ValueError("base85 overflow in hunk starting at byte " + str(i));
        }
        out.append((acc >> 24) & 255);
        out.append((acc >> 16) & 255);
        out.append((acc >> 8) & 255);
        out.append(acc & 255);
        i += 5;
    }
    res: bytes = bytes(out);
    if padding > 0 {
        res = res[0:len(res) - padding];
    }
    return res;
}
