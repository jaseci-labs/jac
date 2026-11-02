impl loads(s: str) -> any {
    raw: bytes = s.encode("utf-8", "surrogatepass");
    p: _JsonParser = _JsonParser(buf=raw, n=len(raw));
    return p._parse_value();
}

impl load(fp: File) -> any {
    return loads(fp.read());
}

impl dumps(
    `obj: any,
    sort_keys: bool = False,
    separators: (tuple[str, str] | None) = None,
    ensure_ascii: bool = True
) -> str {
    style: _JsonStyle = _JsonStyle(sort_keys=sort_keys, ensure_ascii=ensure_ascii);
    if separators is not None {
        (item_sep, key_sep) = separators;
        style.item_sep = item_sep;
        style.key_sep = key_sep;
    }
    return _dump_value(`obj, style);
}

impl _JsonParser._cc -> int {
    if self.pos >= self.n {
        return -1;
    }
    return self.buf[self.pos];
}

impl _JsonParser._skip_ws {
    while True {
        c: int = self._cc();
        if c == 32 or c == 9 or c == 10 or c == 13 {
            self.pos += 1;
        } else {
            break;
        }
    }
}

impl _JsonParser._parse_value -> any {
    self._skip_ws();
    c: int = self._cc();
    if c == 123 {
        return self._parse_object();
    }
    if c == 91 {
        return self._parse_array();
    }
    if c == 34 {
        return self._parse_string();
    }
    if c == 116 {
        self.pos += 4;
        return True;
    }
    if c == 102 {
        self.pos += 5;
        return False;
    }
    if c == 110 {
        self.pos += 4;
        return None;
    }
    return self._parse_number();
}

impl _JsonParser._parse_string -> str {
    self.pos += 1;
    closing: int = self.buf.find(b"\"", self.pos);
    if closing >= 0 {
        plain: bytes = self.buf[self.pos:closing];
        if plain.find(b"\\") < 0 {
            self.pos = closing + 1;
            return plain.decode("utf-8", "surrogatepass");
        }
    }
    parts: list[str] = [];
    run_start: int = self.pos;
    while True {
        c: int = self._cc();
        if c == 34 or c == -1 {
            if self.pos > run_start {
                parts.append(
                    self.buf[run_start:self.pos].decode("utf-8", "surrogatepass")
                );
            }
            self.pos += 1;
            break;
        }
        if c == 92 {
            if self.pos > run_start {
                parts.append(
                    self.buf[run_start:self.pos].decode("utf-8", "surrogatepass")
                );
            }
            self.pos += 1;
            e: int = self._cc();
            self.pos += 1;
            while self.pos < self.n and (self.buf[self.pos] & 192) == 128 {
                self.pos += 1;
            }
            if e == 34 {
                parts.append("\"");
            } elif e == 92 {
                parts.append("\\");
            } elif e == 47 {
                parts.append("/");
            } elif e == 110 {
                parts.append("\n");
            } elif e == 116 {
                parts.append("\t");
            } elif e == 114 {
                parts.append("\r");
            } elif e == 98 {
                parts.append(chr(8));
            } elif e == 102 {
                parts.append(chr(12));
            } elif e == 117 {
                parts.append(chr(self._hex4_pair()));
            }
            run_start = self.pos;
        } else {
            self.pos += 1;
        }
    }
    return "".join(parts);
}

impl _JsonParser._hex4 -> int {
    v: int = 0;
    k: int = 0;
    while k < 4 {
        d: int = self._cc();
        if d == -1 {
            break;
        }
        nib: int = 0;
        if d >= 48 and d <= 57 {
            nib = d - 48;
        } elif d >= 97 and d <= 102 {
            nib = d - 87;
        } elif d >= 65 and d <= 70 {
            nib = d - 55;
        }
        v = v * 16 + nib;
        self.pos += 1;
        k += 1;
    }
    return v;
}

impl _JsonParser._hex4_pair -> int {
    cp: int = self._hex4();
    if cp < 55296
        or cp >= 56320
        or self._cc() != 92
        or self.pos + 1 >= self.n
        or self.buf[self.pos + 1] != 117 {
        return cp;
    }
    mark: int = self.pos;
    self.pos += 2;
    low: int = self._hex4();
    if low >= 56320 and low < 57344 {
        return 65536 + (cp - 55296) * 1024 + (low - 56320);
    }
    self.pos = mark;
    return cp;
}

impl _JsonParser._parse_number -> any {
    start: int = self.pos;
    is_float: int = 0;
    if self._cc() == 45 {
        self.pos += 1;
    }
    while _is_digit(self._cc()) {
        self.pos += 1;
    }
    if self._cc() == 46 {
        is_float = 1;
        self.pos += 1;
        while _is_digit(self._cc()) {
            self.pos += 1;
        }
    }
    c: int = self._cc();
    if c == 101 or c == 69 {
        is_float = 1;
        self.pos += 1;
        sign: int = self._cc();
        if sign == 43 or sign == 45 {
            self.pos += 1;
        }
        while _is_digit(self._cc()) {
            self.pos += 1;
        }
    }
    numstr: str = self.buf[start:self.pos].decode();
    if is_float == 1 {
        return float(numstr);
    }
    return int(numstr);
}

impl _JsonParser._parse_array -> any {
    self.pos += 1;
    out: list[any] = [];
    self._skip_ws();
    if self._cc() == 93 {
        self.pos += 1;
        return out;
    }
    while True {
        out.append(self._parse_value());
        self._skip_ws();
        c: int = self._cc();
        if c == 44 {
            self.pos += 1;
        } elif c == 93 {
            self.pos += 1;
            break;
        } else {
            break;
        }
    }
    return out;
}

impl _JsonParser._parse_object -> any {
    self.pos += 1;
    out: dict[str, any] = {};
    self._skip_ws();
    if self._cc() == 125 {
        self.pos += 1;
        return out;
    }
    while True {
        self._skip_ws();
        key: str = self._parse_string();
        self._skip_ws();
        if self._cc() == 58 {
            self.pos += 1;
        }
        out[key] = self._parse_value();
        self._skip_ws();
        c: int = self._cc();
        if c == 44 {
            self.pos += 1;
        } elif c == 125 {
            self.pos += 1;
            break;
        } else {
            break;
        }
    }
    return out;
}

impl _is_digit(c: int) -> bool {
    return c >= 48 and c <= 57;
}

impl _hex_digit(v: int) -> str {
    if v < 10 {
        return chr(48 + v);
    }
    return chr(97 + v - 10);
}

impl _hex4_str(n: int) -> str {
    return (
        _hex_digit((n // 4096) % 16)
        + _hex_digit((n // 256) % 16)
        + _hex_digit((n // 16) % 16)
        + _hex_digit(n % 16)
    );
}

impl _dump_plain(ch: int, ensure_ascii: bool) -> bool {
    return ch >= 32 and ch != 34 and ch != 92 and (ch < 127 or not ensure_ascii);
}

impl _dump_str(s: str, ensure_ascii: bool) -> str {
    plain: bool = True;
    for c in s {
        if not _dump_plain(ord(c), ensure_ascii) {
            plain = False;
            break;
        }
    }
    if plain {
        return "\"" + s + "\"";
    }
    parts: list[str] = ["\""];
    for c in s {
        ch: int = ord(c);
        if _dump_plain(ch, ensure_ascii) {
            parts.append(c);
        } elif ch == 34 {
            parts.append("\\\"");
        } elif ch == 92 {
            parts.append("\\\\");
        } elif ch == 10 {
            parts.append("\\n");
        } elif ch == 9 {
            parts.append("\\t");
        } elif ch == 13 {
            parts.append("\\r");
        } elif ch == 8 {
            parts.append("\\b");
        } elif ch == 12 {
            parts.append("\\f");
        } elif ch < 32 {
            parts.append("\\u" + _hex4_str(ch));
        } elif ch == 127 {
            parts.append("\\u007f");
        } elif ch > 65535 {
            v: int = ch - 65536;
            parts.append("\\u" + _hex4_str(55296 + v // 1024));
            parts.append("\\u" + _hex4_str(56320 + v % 1024));
        } else {
            parts.append("\\u" + _hex4_str(ch));
        }
    }
    parts.append("\"");
    return "".join(parts);
}

impl _dump_float(f_val: float) -> str {
    if f_val != f_val {
        return "NaN";
    }
    if f_val == float("inf") {
        return "Infinity";
    }
    if f_val == float("-inf") {
        return "-Infinity";
    }
    return str(f_val);
}

impl _dump_items(items: list[any], style: _JsonStyle) -> str {
    parts: list[str] = ["["];
    n: int = len(items);
    i: int = 0;
    while i < n {
        if i > 0 {
            parts.append(style.item_sep);
        }
        parts.append(_dump_value(items[i], style));
        i += 1;
    }
    parts.append("]");
    return "".join(parts);
}

impl _dump_value(value: any, style: _JsonStyle) -> str {
    if value is None {
        return "null";
    }
    if isinstance(value, bool) {
        flag: int = value;
        if flag != 0 {
            return "true";
        }
        return "false";
    }
    if isinstance(value, int) {
        i_val: int = value;
        return str(i_val);
    }
    if isinstance(value, float) {
        f_val: float = value;
        return _dump_float(f_val);
    }
    if isinstance(value, str) {
        s_val: str = value;
        return _dump_str(s_val, style.ensure_ascii);
    }
    if isinstance(value, list) {
        arr: list[any] = value;
        return _dump_items(arr, style);
    }
    if isinstance(value, dict) {
        d: dict[str, any] = value;
        parts: list[str] = ["{"];
        first: int = 1;
        keys: list[str] = sorted(d.keys()) if style.sort_keys else list(d.keys());
        for k in keys {
            if first == 0 {
                parts.append(style.item_sep);
            }
            first = 0;
            parts.append(_dump_str(k, style.ensure_ascii));
            parts.append(style.key_sep);
            parts.append(_dump_value(d[k], style));
        }
        parts.append("}");
        return "".join(parts);
    }
    raise TypeError("Object is not JSON serializable");
}
