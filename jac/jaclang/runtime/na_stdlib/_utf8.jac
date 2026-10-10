def:pub utf8_cps(bv: bytes) -> list[int] {
    out: list[int] = [];
    i: int = 0;
    n: int = len(bv);
    while i < n {
        b: int = bv[i];
        if b < 128 {
            out.append(b);
            i += 1;
        } elif b < 224 and i + 1 < n {
            out.append(((b - 192) << 6) | (bv[i + 1] - 128));
            i += 2;
        } elif b < 240 and i + 2 < n {
            out.append(
                ((b - 224) << 12) | ((bv[i + 1] - 128) << 6) | (bv[i + 2] - 128)
            );
            i += 3;
        } elif i + 3 < n {
            out.append(
                ((b - 240) << 18)
                    | ((bv[i + 1] - 128) << 12)
                    | ((bv[i + 2] - 128) << 6)
                    | (bv[i + 3] - 128)
            );
            i += 4;
        } else {
            out.append(b);
            i += 1;
        }
    }
    return out;
}


def:pub cp_off(bv: bytes, cp: int) -> int {
    i: int = 0;
    n: int = len(bv);
    k: int = 0;
    while i < n and k < cp {
        if bv[i] < 128 {
            i += 1;
        } else {
            i += 1;
            while i < n and (bv[i] & 192) == 128 {
                i += 1;
            }
        }
        k += 1;
    }
    return i;
}


def:pub cp_len(bv: bytes, n: int) -> int {
    c: int = 0;
    i: int = 0;
    while i < n {
        if (bv[i] & 192) != 128 {
            c += 1;
        }
        i += 1;
    }
    return c;
}


def:pub cps_str(cps: list[int], a: int, b: int) -> str {
    s: str = "";
    k: int = a;
    while k < b {
        s += chr(cps[k]);
        k += 1;
    }
    return s;
}


def:pub cpslice_str(bv: bytes, lo: int, hi: int) -> str {
    return bv[cp_off(bv, lo):cp_off(bv, hi)].decode();
}


def:pub is_ascii(bv: bytes) -> bool {
    i: int = 0;
    n: int = len(bv);
    while i < n {
        if bv[i] >= 128 {
            return False;
        }
        i += 1;
    }
    return True;
}
