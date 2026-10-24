impl _fill_head(limit: int) -> int {
    i: int = (limit - 3) // 2;
    if i < 0 {
        i = 0;
    }
    return i;
}


impl _fill_tail(limit: int) -> int {
    j: int = limit - 3 - _fill_head(limit);
    if j < 0 {
        j = 0;
    }
    return j;
}


impl _cplen(s: str) -> int {
    sb: bytes = s.encode();
    return cp_len(sb, len(sb));
}


impl _ellipsize(s: str, limit: int) -> str {
    sb: bytes = s.encode();
    n: int = cp_len(sb, len(sb));
    lo: int = n - _fill_tail(limit);
    if lo < 0 {
        lo = 0;
    }
    return cpslice_str(sb, 0, _fill_head(limit)) + "..." + cpslice_str(sb, lo, n);
}


impl _fill(s: str, limit: int) -> str {
    if _cplen(s) <= limit {
        return s;
    }
    return _ellipsize(s, limit);
}


impl _dict_keys(d: dict[str, any]) -> list[str] {
    keys: list[str] = [];
    for k in d {
        keys.append(k);
    }
    return sorted_str_keys(keys);
}


impl Repr._iter(x: list[any], level: int, left: str, right: str, maxiter: int) -> str {
    n: int = len(x);
    if level <= 0 and n > 0 {
        return left + "..." + right;
    }
    out: str = left;
    i: int = 0;
    while i < n and i < maxiter {
        if i > 0 {
            out += ", ";
        }
        out += self.repr1(x[i], level - 1);
        i += 1;
    }
    if n > maxiter {
        if i > 0 {
            out += ", ";
        }
        out += "...";
    }
    return out + right;
}

impl Repr.repr1(x: any, level: int) -> str {
    if isinstance(x, bool) {
        bv: bool = x;
        return "True" if bv else "False";
    }
    if isinstance(x, int) {
        iv: int = x;
        return _fill(str(iv), self.maxlong);
    }
    if isinstance(x, float) {
        fv: float = x;
        return str(fv);
    }
    if isinstance(x, str) {
        sv: str = x;
        sb: bytes = sv.encode();
        r: str = repr_str(cpslice_str(sb, 0, self.maxstring));
        if _cplen(r) <= self.maxstring {
            return r;
        }
        sn: int = cp_len(sb, len(sb));
        lo: int = sn - _fill_tail(self.maxstring);
        if lo < 0 {
            lo = 0;
        }
        return _ellipsize(
            repr_str(
                cpslice_str(sb, 0, _fill_head(self.maxstring)) + cpslice_str(sb, lo, sn)
            ),
            self.maxstring
        );
    }
    if isinstance(x, list) {
        lv: list[any] = x;
        return self._iter(lv, level, "[", "]", self.maxlist);
    }
    if isinstance(x, dict) {
        dv: dict[str, any] = x;
        n: int = len(dv);
        if n == 0 {
            return "{}";
        }
        if level <= 0 {
            return "{...}";
        }
        keys: list[str] = _dict_keys(dv);
        out: str = "{";
        i: int = 0;
        while i < n and i < self.maxdict {
            if i > 0 {
                out += ", ";
            }
            k: str = keys[i];
            out += self.repr1(k, level - 1) + ": " + self.repr1(dv[k], level - 1);
            i += 1;
        }
        if n > self.maxdict {
            if i > 0 {
                out += ", ";
            }
            out += "...";
        }
        return out + "}";
    }
    if isinstance(x, set) or isinstance(x, frozenset) {
        raise ValueError("reprlib: unsupported value type on native");
    }
    return "None";
}

impl Repr.repr(x: any) -> str {
    return self.repr1(x, self.maxlevel);
}


impl repr(x: any) -> str {
    return _AREPR.repr(x);
}
