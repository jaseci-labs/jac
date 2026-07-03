def _hex2(c: int) -> str {
    digits: str = "0123456789abcdef";
    return digits[c // 16] + digits[c % 16];
}


def _repr_str(s: str) -> str {
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
            out += "\\x" + _hex2(c2);
        } else {
            out += s[j];
        }
        j += 1;
    }
    out += quote;
    return out;
}


def _str_gt(a: str, b: str) -> bool {
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


def _sorted_keys(keys: list[str]) -> list[str] {
    i: int = 1;
    n: int = len(keys);
    while i < n {
        j: int = i;
        while j > 0 and _str_gt(keys[j - 1], keys[j]) {
            tmp: str = keys[j - 1];
            keys[j - 1] = keys[j];
            keys[j] = tmp;
            j -= 1;
        }
        i += 1;
    }
    return keys;
}


def _format(value: any) -> str {
    if isinstance(value, bool) {
        flag: bool = value;
        if flag {
            return "True";
        }
        return "False";
    }
    if isinstance(value, int) {
        i_val: int = value;
        return str(i_val);
    }
    if isinstance(value, float) {
        f_val: float = value;
        return str(f_val);
    }
    if isinstance(value, str) {
        s_val: str = value;
        return _repr_str(s_val);
    }
    if isinstance(value, list) {
        arr: list[any] = value;
        out: str = "[";
        n: int = len(arr);
        i: int = 0;
        while i < n {
            if i > 0 {
                out += ", ";
            }
            out += _format(arr[i]);
            i += 1;
        }
        out += "]";
        return out;
    }
    if isinstance(value, dict) {
        d: dict[str, any] = value;
        keys: list[str] = [];
        for k in d {
            keys.append(k);
        }
        keys = _sorted_keys(keys);
        out2: str = "{";
        m: int = len(keys);
        j: int = 0;
        while j < m {
            if j > 0 {
                out2 += ", ";
            }
            kk: str = keys[j];
            out2 += _repr_str(kk) + ": " + _format(d[kk]);
            j += 1;
        }
        out2 += "}";
        return out2;
    }
    if isinstance(value, set) {
        raise ValueError("pprint: unsupported value type on native");
    }
    return "None";
}


def:pub pformat(value: any) -> str {
    return _format(value);
}
