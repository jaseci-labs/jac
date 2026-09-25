import from _repr { repr_str, sorted_str_keys }
import from _utf8 { cpslice_str }


def _fill(s: str, limit: int) -> str {
    if len(s) <= limit {
        return s;
    }
    i: int = (limit - 3) // 2;
    if i < 0 {
        i = 0;
    }
    j: int = limit - 3 - i;
    if j < 0 {
        j = 0;
    }
    return s[0:i] + "..." + s[len(s) - j:];
}


def _dict_keys(d: dict[str, any]) -> list[str] {
    keys: list[str] = [];
    for k in d {
        keys.append(k);
    }
    return sorted_str_keys(keys);
}


obj:pub Repr {
    has maxlevel: int = 6,
        maxtuple: int = 6,
        maxlist: int = 6,
        maxdict: int = 4,
        maxset: int = 4,
        maxfrozenset: int = 4,
        maxstring: int = 30,
        maxlong: int = 40,
        maxother: int = 30;

    def _iter(x: list[any], level: int, left: str, right: str, maxiter: int) -> str {
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

    def repr1(x: any, level: int) -> str {
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
            r: str = repr_str(cpslice_str(sv.encode(), 0, self.maxstring));
            return _fill(r, self.maxstring);
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

    def repr(x: any) -> str {
        return self.repr1(x, self.maxlevel);
    }
}


glob _AREPR: Repr = Repr();


def:pub repr(x: any) -> str {
    return _AREPR.repr(x);
}
