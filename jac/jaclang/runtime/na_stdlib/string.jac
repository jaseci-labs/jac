import from _ascii { is_id_start, is_word }

glob:pub whitespace: str = " \t\n\r\x0b\x0c",
     ascii_lowercase: str = "abcdefghijklmnopqrstuvwxyz",
     ascii_uppercase: str = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
     ascii_letters: str = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
     digits: str = "0123456789",
     hexdigits: str = "0123456789abcdefABCDEF",
     octdigits: str = "01234567",
     punctuation: str = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~",
     printable: str = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~ \t\n\r\x0b\x0c";


def:pub capwords(s: str, sep: (str | None) = None) -> str {
    if sep is None {
        bv: bytes = s.encode();
        n: int = len(bv);
        src: int = __bytes_data(bv);
        inword: int = 0;
        first: int = 1;
        j: int = 0;
        i: int = 0;
        while i < n {
            c: int = __mem_load_i8(src + i);
            if c == 32 or (c >= 9 and c <= 13) {
                inword = 0;
                i += 1;
                continue;
            }
            if not inword {
                inword = 1;
                if not first {
                    __mem_store_i8(src + j, 32);
                    j += 1;
                }
                first = 0;
                if c >= 97 and c <= 122 {
                    c -= 32;
                }
            } elif c >= 65 and c <= 90 {
                c += 32;
            }
            __mem_store_i8(src + j, c);
            j += 1;
            i += 1;
        }
        return bv[0:j].decode();
    }
    sepv: str = sep;
    parts: list[str] = s.split(sepv);
    joiner: str = sepv;
    out2: str = "";
    i: int = 0;
    n2: int = len(parts);
    while i < n2 {
        if i > 0 {
            out2 += joiner;
        }
        out2 += parts[i].capitalize();
        i += 1;
    }
    return out2;
}


def _strval(v: any) -> str {
    if isinstance(v, str) {
        s: str = v;
        return s;
    }
    if isinstance(v, bool) {
        b: bool = v;
        return "True" if b else "False";
    }
    if isinstance(v, int) {
        i: int = v;
        return str(i);
    }
    if isinstance(v, float) {
        f: float = v;
        return str(f);
    }
    raise ValueError(
        "Template substitution value must be str/int/float/bool on native"
    );
}


def _invalid(template: str, i: int) {
    bv: bytes = template.encode();
    lineno: int = 1;
    lastnl: int = -1;
    j: int = 0;
    while j < i {
        if bv[j] == 10 {
            lineno += 1;
            lastnl = j;
        }
        j += 1;
    }
    colno: int = 0;
    k: int = lastnl + 1;
    while k < i {
        if (bv[k] & 192) != 128 {
            colno += 1;
        }
        k += 1;
    }
    raise ValueError(
        "Invalid placeholder in string: line " + str(lineno) + ", col " + str(colno)
    );
}


def _ph(bv: bytes, i: int, n: int) -> tuple[(str, int, str)] {
    nx: int = bv[i + 1];
    if nx == 123 {
        j: int = i + 2;
        while j < n and is_word(bv[j]) {
            j += 1;
        }
        if j > i + 2 and j < n and bv[j] == 125 {
            return (bv[i + 2:j].decode(), j + 1 - i, bv[i:j + 1].decode());
        }
        return ("", 0, "");
    }
    if is_id_start(nx) {
        j = i + 1;
        while j < n and is_word(bv[j]) {
            j += 1;
        }
        return (bv[i + 1:j].decode(), j - i, bv[i:j].decode());
    }
    return ("", 0, "");
}


def _expand(template: str, mapping: (dict[str, any] | None), safe: bool) -> str {
    out: str = "";
    bv: bytes = template.encode();
    src: int = __bytes_data(bv);
    i: int = 0;
    n: int = len(bv);
    while i < n {
        c: int = __mem_load_i8(src + i);
        if c != 36 {
            j0: int = i;
            while j0 < n and __mem_load_i8(src + j0) != 36 {
                j0 += 1;
            }
            out += bv[i:j0].decode();
            i = j0;
            continue;
        }
        if i + 1 >= n {
            if safe {
                out += "$";
                i += 1;
                continue;
            }
            _invalid(template, i);
        }
        nx: int = __mem_load_i8(src + i + 1);
        if nx == 36 {
            out += "$";
            i += 2;
            continue;
        }
        ph: tuple[(str, int, str)] = _ph(bv, i, n);
        name: str = ph[0];
        consumed: int = ph[1];
        raw: str = ph[2];
        if consumed == 0 {
            if safe {
                out += "$";
                i += 1;
                continue;
            }
            _invalid(template, i);
        }
        hit: bool = False;
        val: any = None;
        if isinstance(mapping, dict) {
            m2: dict[str, any] = mapping;
            if name in m2 {
                hit = True;
                val = m2[name];
            }
        }
        if hit {
            out += _strval(val);
        } elif safe {
            out += raw;
        } elif mapping is None {
            out += name;
        } else {
            raise KeyError(name);
        }
        i += consumed;
    }
    return out;
}


obj:pub Template {
    has template: str = "";

    def init(template: str) {
        self.template = template;
    }

    def substitute(mapping: dict[str, any]) -> str {
        return _expand(self.template, mapping, False);
    }

    def safe_substitute(mapping: dict[str, any]) -> str {
        return _expand(self.template, mapping, True);
    }

    def is_valid -> bool {
        try {
            _expand(self.template, None, False);
        } except ValueError {
            return False;
        }
        return True;
    }

    def get_identifiers -> list[str] {
        ids: list[str] = [];
        bv: bytes = self.template.encode();
        src: int = __bytes_data(bv);
        i: int = 0;
        n: int = len(bv);
        while i < n {
            c: int = __mem_load_i8(src + i);
            if c != 36 {
                i += 1;
                continue;
            }
            if i + 1 >= n {
                i += 1;
                continue;
            }
            if __mem_load_i8(src + i + 1) == 36 {
                i += 2;
                continue;
            }
            ph: tuple[(str, int, str)] = _ph(bv, i, n);
            if ph[1] == 0 {
                i += 1;
                continue;
            }
            name: str = ph[0];
            seen: bool = False;
            k: int = 0;
            while k < len(ids) {
                if ids[k] == name {
                    seen = True;
                    break;
                }
                k += 1;
            }
            if not seen {
                ids.append(name);
            }
            i += ph[1];
        }
        return ids;
    }
}
