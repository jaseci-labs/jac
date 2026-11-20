impl capwords(s: str, sep: (str | None) = None) -> str {
    if sep is None {
        bv: bytes = s.encode();
        n: int = len(bv);
        src: int = __bytes_data(bv);
        inword: int = 0;
        first: int = 1;
        j: int = 0;
        i: int = 0;
        while i < n {
            c: int = int(__mem_load_i8(src + i));
            if c == 32 or (c >= 9 and c <= 13) {
                inword = 0;
                i += 1;
                continue;
            }
            if not inword {
                inword = 1;
                if not first {
                    __mem_store_i8(src + j, i8(32));
                    j += 1;
                }
                first = 0;
                if c >= 97 and c <= 122 {
                    c -= 32;
                }
            } elif c >= 65 and c <= 90 {
                c += 32;
            }
            __mem_store_i8(src + j, i8.wrap(c));
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


impl _strval(v: any) -> str {
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


impl _invalid(template: str, i: int) {
    bv: bytes = template.encode();
    lineno: int = 1;
    colno: int = 0;
    k: int = 0;
    while k <= i {
        c: int = bv[k];
        brk: bool = False;
        if c == 13 and k < i and bv[k + 1] == 10 {
            k += 1;
            brk = True;
        } elif (c >= 10 and c <= 13) or (c >= 28 and c <= 30) {
            brk = True;
        } elif c == 194 and k < i and bv[k + 1] == 133 {
            k += 1;
            brk = True;
        } elif c == 226
            and k + 1 < i
            and bv[k + 1] == 128
            and (bv[k + 2] == 168 or bv[k + 2] == 169) {
            k += 2;
            brk = True;
        }
        if brk {
            lineno += 1;
            colno = 0;
        } elif (c & 192) != 128 {
            colno += 1;
        }
        k += 1;
    }
    raise ValueError(
        "Invalid placeholder in string: line " + str(lineno) + ", col " + str(colno)
    );
}


impl _ph(bv: bytes, i: int, n: int) -> tuple[(str, int, str)] {
    nx: int = bv[i + 1];
    if nx == 123 {
        j: int = i + 2;
        while j < n and is_word(bv[j]) {
            j += 1;
        }
        if j > i + 2 and is_id_start(bv[i + 2]) and j < n and bv[j] == 125 {
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


impl _expand_ascii(template: str, mapping: (dict[str, any] | None), safe: bool) -> str {
    out: str = "";
    src: int = __str_data(template);
    n: int = len(template);
    i: int = 0;
    while i < n {
        hit0: int = memchr(src + i, i32(36), u64(n - i));
        j0: int = n if hit0 == 0 else hit0 - src;
        if j0 > i {
            out += template[i:j0];
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
        nx: int = int(__mem_load_i8(src + i + 1));
        if nx == 36 {
            out += "$";
            i += 2;
            continue;
        }
        a: int = i + 1;
        b: int = a;
        consumed: int = 0;
        if nx == 123 {
            a = i + 2;
            b = a;
            while b < n and is_word(int(__mem_load_i8(src + b))) {
                b += 1;
            }
            if b > a
                and is_id_start(int(__mem_load_i8(src + a)))
                and b < n
                and int(__mem_load_i8(src + b)) == 125 {
                consumed = b + 1 - i;
            }
        } elif is_id_start(nx) {
            while b < n and is_word(int(__mem_load_i8(src + b))) {
                b += 1;
            }
            consumed = b - i;
        }
        if consumed == 0 {
            if safe {
                out += "$";
                i += 1;
                continue;
            }
            _invalid(template, i);
        }
        name: str = template[a:b];
        if isinstance(mapping, dict) {
            m2: dict[str, any] = mapping;
            if name in m2 {
                out += _strval(m2[name]);
                i += consumed;
                continue;
            }
        }
        if safe {
            out += template[i:i + consumed];
        } elif mapping is None {
            out += name;
        } else {
            raise KeyError(name);
        }
        i += consumed;
    }
    return out;
}


impl _expand(template: str, mapping: (dict[str, any] | None), safe: bool) -> str {
    if template.isascii() {
        return _expand_ascii(template, mapping, safe);
    }
    out: str = "";
    bv: bytes = template.encode();
    src: int = __bytes_data(bv);
    i: int = 0;
    n: int = len(bv);
    while i < n {
        c: int = int(__mem_load_i8(src + i));
        if c != 36 {
            j0: int = i;
            while j0 < n and int(__mem_load_i8(src + j0)) != 36 {
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
        nx: int = int(__mem_load_i8(src + i + 1));
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


impl Template.init(template: str) {
    self.template = template;
}

impl Template.substitute(mapping: dict[str, any]) -> str {
    return _expand(self.template, mapping, False);
}

impl Template.safe_substitute(mapping: dict[str, any]) -> str {
    return _expand(self.template, mapping, True);
}

impl Template.is_valid -> bool {
    try {
        _expand(self.template, None, False);
    } except ValueError {
        return False;
    }
    return True;
}

impl Template.get_identifiers -> list[str] {
    ids: list[str] = [];
    bv: bytes = self.template.encode();
    src: int = __bytes_data(bv);
    i: int = 0;
    n: int = len(bv);
    while i < n {
        c: int = int(__mem_load_i8(src + i));
        if c != 36 {
            i += 1;
            continue;
        }
        if i + 1 >= n {
            i += 1;
            continue;
        }
        if int(__mem_load_i8(src + i + 1)) == 36 {
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
