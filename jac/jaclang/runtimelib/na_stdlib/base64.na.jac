glob _B16: bytes = b"0123456789ABCDEF",
     _B32: bytes = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567",
     _B64: bytes = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
     _B85: bytes = b"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~",
     _PAD: int = 61,
     _rev_b16: list[int] = [],
     _rev_b32: list[int] = [],
     _rev_b64: list[int] = [],
     _rev_b64url: list[int] = [],
     _rev_b85: list[int] = [];


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


def _rev_for(alphabet: bytes, cache: list[int]) -> list[int] {
    if len(cache) == 0 {
        built: list[int] = _make_rev(alphabet);
        k: int = 0;
        while k < 256 {
            cache.append(built[k]);
            k += 1;
        }
    }
    return cache;
}


def _casefold_rev(rev: list[int], alphabet: bytes) {
    n: int = len(alphabet);
    j: int = 0;
    while j < n {
        c: int = alphabet[j];
        if c >= 65 and c <= 90 {
            rev[c + 32] = rev[c];
        }
        j += 1;
    }
}


def _copy_rev(rev: list[int]) -> list[int] {
    out: list[int] = [];
    k: int = 0;
    while k < 256 {
        out.append(rev[k]);
        k += 1;
    }
    return out;
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


def _decode_bits(data: bytes, rev: list[int], bits: int, errmsg: str) -> bytes {
    out: list[int] = [];
    acc: int = 0;
    nbits: int = 0;
    n: int = len(data);
    i: int = 0;
    while i < n {
        c: int = data[i];
        v: int = rev[c];
        if v < 0 {
            raise ValueError(errmsg);
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
    rev: list[int] = _rev_for(_B16, _rev_b16);
    if casefold {
        rev = _copy_rev(rev);
        _casefold_rev(rev, _B16);
    }
    n: int = len(s);
    i: int = 0;
    while i < n {
        if rev[s[i]] < 0 {
            raise ValueError("Non-base16 digit found");
        }
        i += 1;
    }
    if (n % 2) != 0 {
        raise ValueError("Odd-length string");
    }
    return _decode_bits(s, rev, 4, "Non-base16 digit found");
}


def:pub b32encode(s: bytes) -> bytes {
    return _encode_bits(s, _B32, 5, 8);
}


def:pub b32decode(s: bytes, casefold: bool = False, map01: bytes = b"") -> bytes {
    if (len(s) % 8) != 0 {
        raise ValueError("Incorrect padding");
    }
    work: bytes = s;
    if len(map01) != 0 {
        if len(map01) != 1 {
            raise ValueError("map01 must be exactly 1 byte");
        }
        mapped: list[int] = [];
        m: int = len(s);
        k: int = 0;
        while k < m {
            c: int = s[k];
            if c == 48 {
                mapped.append(79);
            } elif c == 49 {
                mapped.append(map01[0]);
            } else {
                mapped.append(c);
            }
            k += 1;
        }
        work = bytes(mapped);
    }
    rev: list[int] = _rev_for(_B32, _rev_b32);
    if casefold {
        rev = _copy_rev(rev);
        _casefold_rev(rev, _B32);
    }
    end: int = len(work);
    while end > 0 and work[end - 1] == _PAD {
        end -= 1;
    }
    padchars: int = len(work) - end;
    decoded: bytes = _decode_bits(work[0:end], rev, 5, "Non-base32 digit found");
    if padchars != 0
    and padchars != 1
    and padchars != 3
    and padchars != 4
    and padchars != 6 {
        raise ValueError("Incorrect padding");
    }
    return decoded;
}


def _b64_alphabet(altchars: bytes) -> bytes {
    if len(altchars) != 0 {
        if len(altchars) != 2 {
            raise ValueError("altchars must be exactly 2 bytes");
        }
        return _B64[0:62] + altchars;
    }
    return _B64;
}


def _b64_decode_core(data: bytes, rev: list[int], strict: bool) -> bytes {
    n: int = len(data);
    if strict and n > 0 and data[0] == _PAD {
        raise ValueError("Leading padding not allowed");
    }
    out: list[int] = [];
    acc: int = 0;
    quad_pos: int = 0;
    pads: int = 0;
    datachars: int = 0;
    padding_started: bool = False;
    padding_done: bool = False;
    i: int = 0;
    while i < n {
        c: int = data[i];
        if c == _PAD {
            if strict {
                padding_started = True;
                if padding_done or quad_pos < 2 {
                    raise ValueError("Excess padding not allowed");
                }
                pads += 1;
                if quad_pos + pads >= 4 {
                    if quad_pos == 2 {
                        out.append((acc >> 4) & 255);
                    } else {
                        out.append((acc >> 10) & 255);
                        out.append((acc >> 2) & 255);
                    }
                    acc = 0;
                    quad_pos = 0;
                    pads = 0;
                    padding_done = True;
                }
            } elif quad_pos >= 2 {
                pads += 1;
            }
            i += 1;
            continue;
        }
        v: int = rev[c];
        if v < 0 {
            if strict {
                raise ValueError("Only base64 data is allowed");
            }
            i += 1;
            continue;
        }
        if strict and padding_started {
            if padding_done {
                raise ValueError("Excess data after padding");
            }
            raise ValueError("Discontinuous padding not allowed");
        }
        pads = 0;
        datachars += 1;
        acc = (acc << 6) | v;
        quad_pos += 1;
        if quad_pos == 4 {
            out.append((acc >> 16) & 255);
            out.append((acc >> 8) & 255);
            out.append(acc & 255);
            acc = 0;
            quad_pos = 0;
        }
        i += 1;
    }
    if quad_pos == 1 {
        raise ValueError(
            "Invalid base64-encoded string: number of data characters (" + str(
                datachars
            ) + ") cannot be 1 more than a multiple of 4"
        );
    }
    if quad_pos >= 2 {
        if quad_pos + pads >= 4 {
            if quad_pos == 2 {
                out.append((acc >> 4) & 255);
            } else {
                out.append((acc >> 10) & 255);
                out.append((acc >> 2) & 255);
            }
        } else {
            raise ValueError("Incorrect padding");
        }
    }
    return bytes(out);
}


def:pub b64encode(s: bytes, altchars: bytes = b"") -> bytes {
    return _encode_bits(s, _b64_alphabet(altchars), 6, 4);
}


def:pub b64decode(s: bytes, altchars: bytes = b"", validate: bool = False) -> bytes {
    rev: list[int] = _rev_for(_B64, _rev_b64);
    if len(altchars) != 0 {
        if len(altchars) != 2 {
            raise ValueError("altchars must be exactly 2 bytes");
        }
        rev = _copy_rev(rev);
        rev[altchars[0]] = 62;
        rev[altchars[1]] = 63;
    }
    return _b64_decode_core(s, rev, validate);
}


def:pub standard_b64encode(s: bytes) -> bytes {
    return b64encode(s, b"");
}


def:pub standard_b64decode(s: bytes) -> bytes {
    return b64decode(s, b"");
}


def _rev_urlsafe_for(cache: list[int]) -> list[int] {
    if len(cache) == 0 {
        built: list[int] = _copy_rev(_rev_for(_B64, _rev_b64));
        built[45] = 62;
        built[95] = 63;
        k: int = 0;
        while k < 256 {
            cache.append(built[k]);
            k += 1;
        }
    }
    return cache;
}


def:pub urlsafe_b64encode(s: bytes) -> bytes {
    return b64encode(s, b"-_");
}


def:pub urlsafe_b64decode(s: bytes) -> bytes {
    return _b64_decode_core(s, _rev_urlsafe_for(_rev_b64url), False);
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
    rev: list[int] = _rev_for(_B85, _rev_b85);
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
                raise ValueError("bad base85 character at position " + str(i + j));
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
