def hex2(c: int) -> str {
    digits: str = "0123456789abcdef";
    return digits[c // 16] + digits[c % 16];
}


def:pub repr_str(s: str) -> str {
    has_single: bool = False;
    has_double: bool = False;
    i: int = 0;
    n: int = len(s);
    while i < n {
        c: int = ord(s[i]);
        if c == 39 {
            has_single = True;
        } elif c == 34 {
            has_double = True;
        }
        i += 1;
    }
    quote: str = "'";
    qc: int = 39;
    if has_single and not has_double {
        quote = "\"";
        qc = 34;
    }
    out: str = quote;
    j: int = 0;
    while j < n {
        c2: int = ord(s[j]);
        if c2 == 92 {
            out += "\\\\";
        } elif c2 == qc {
            out += "\\" + quote;
        } elif c2 == 10 {
            out += "\\n";
        } elif c2 == 9 {
            out += "\\t";
        } elif c2 == 13 {
            out += "\\r";
        } elif c2 < 32 or c2 == 127 {
            out += "\\x" + hex2(c2);
        } else {
            out += s[j];
        }
        j += 1;
    }
    out += quote;
    return out;
}


def:pub str_gt(a: str, b: str) -> bool {
    m: int = len(a);
    if len(b) < m {
        m = len(b);
    }
    i: int = 0;
    while i < m {
        ca: int = ord(a[i]);
        cb: int = ord(b[i]);
        if ca != cb {
            return ca > cb;
        }
        i += 1;
    }
    return len(a) > len(b);
}


def:pub sorted_str_keys(keys: list[str]) -> list[str] {
    i: int = 1;
    n: int = len(keys);
    while i < n {
        j: int = i;
        while j > 0 and str_gt(keys[j - 1], keys[j]) {
            tmp: str = keys[j - 1];
            keys[j - 1] = keys[j];
            keys[j] = tmp;
            j -= 1;
        }
        i += 1;
    }
    return keys;
}
