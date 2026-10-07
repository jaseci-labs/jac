def:pub loads(s: str) -> any {
    p: _JsonParser = _JsonParser(src=s);
    return p._parse_value();
}


def:pub load(fp: File) -> any {
    return loads(fp.read());
}


def:pub dumps(
    value: any,
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
    return _dump_value(value, style);
}


obj _JsonStyle {
    has sort_keys: bool = False,
        ensure_ascii: bool = True,
        item_sep: str = ", ",
        key_sep: str = ": ";
}


obj _JsonParser {
    has src: str,
        pos: int = 0;

    def _cc -> int {
        if self.pos >= len(self.src) {
            return -1;
        }
        return ord(self.src[self.pos]);
    }

    def _skip_ws {
        while True {
            c: int = self._cc();
            if c == 32 or c == 9 or c == 10 or c == 13 {
                self.pos += 1;
            } else {
                break;
            }
        }
    }

    def _parse_value -> any {
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

    def _parse_string -> str {
        self.pos += 1;
        closing: int = self.src.find("\"", self.pos);
        if closing >= 0 {
            plain: str = self.src[self.pos:closing];
            if plain.find("\\") < 0 {
                self.pos = closing + 1;
                return plain;
            }
        }
        out: str = "";
        while True {
            c: int = self._cc();
            if c == 34 or c == -1 {
                self.pos += 1;
                break;
            }
            if c == 92 {
                self.pos += 1;
                e: int = self._cc();
                self.pos += 1;
                if e == 34 {
                    out += "\"";
                } elif e == 92 {
                    out += "\\";
                } elif e == 47 {
                    out += "/";
                } elif e == 110 {
                    out += "\n";
                } elif e == 116 {
                    out += "\t";
                } elif e == 114 {
                    out += "\r";
                } elif e == 98 {
                    out += chr(8);
                } elif e == 102 {
                    out += chr(12);
                } elif e == 117 {
                    out += chr(self._hex4());
                }
            } else {
                start: int = self.pos;
                self.pos += 1;
                while True {
                    c2: int = self._cc();
                    if c2 == 34 or c2 == -1 or c2 == 92 {
                        break;
                    }
                    self.pos += 1;
                }
                out += self.src[start:self.pos];
            }
        }
        return out;
    }

    def _hex4 -> int {
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

    def _parse_number -> any {
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
        numstr: str = self.src[start:self.pos];
        if is_float == 1 {
            return float(numstr);
        }
        return int(numstr);
    }

    def _parse_array -> any {
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

    def _parse_object -> any {
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
}


def _is_digit(c: int) -> bool {
    return c >= 48 and c <= 57;
}


def _hex_digit(v: int) -> str {
    if v < 10 {
        return chr(48 + v);
    }
    return chr(97 + v - 10);
}


def _hex4_str(n: int) -> str {
    return (
        _hex_digit((n // 4096) % 16)
        + _hex_digit((n // 256) % 16)
        + _hex_digit((n // 16) % 16)
        + _hex_digit(n % 16)
    );
}


def _dump_str(s: str, ensure_ascii: bool) -> str {
    out: str = "\"";
    n: int = len(s);
    i: int = 0;
    start: int = 0;
    while i < n {
        ch: int = ord(s[i]);
        if ch >= 32 and ch != 34 and ch != 92 and (ch < 127 or not ensure_ascii) {
            i += 1;
            continue;
        }
        if i > start {
            out += s[start:i];
        }
        if ch == 34 {
            out += "\\\"";
        } elif ch == 92 {
            out += "\\\\";
        } elif ch == 10 {
            out += "\\n";
        } elif ch == 9 {
            out += "\\t";
        } elif ch == 13 {
            out += "\\r";
        } elif ch == 8 {
            out += "\\b";
        } elif ch == 12 {
            out += "\\f";
        } elif ch < 32 {
            out += "\\u" + _hex4_str(ch);
        } elif ensure_ascii and ch == 127 {
            out += "\\u007f";
        } elif ensure_ascii and ch > 127 {
            width: int = 2 if ch < 224 else (3 if ch < 240 else 4);
            code: int = ch % (64 if width == 2 else (32 if width == 3 else 16));
            k: int = 1;
            while k < width and i + k < n {
                code = code * 64 + ord(s[i + k]) % 64;
                k += 1;
            }
            i += width - 1;
            if code > 65535 {
                v: int = code - 65536;
                out += "\\u" + _hex4_str(55296 + v // 1024);
                out += "\\u" + _hex4_str(56320 + v % 1024);
            } else {
                out += "\\u" + _hex4_str(code);
            }
        } else {
            i += 1;
        }
        i += 1;
        start = i;
    }
    if start == 0 {
        return "\"" + s + "\"";
    }
    if n > start {
        out += s[start:n];
    }
    out += "\"";
    return out;
}


def _dump_float(f_val: float) -> str {
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


def _dump_items(items: list[any], style: _JsonStyle) -> str {
    out: str = "[";
    n: int = len(items);
    i: int = 0;
    while i < n {
        if i > 0 {
            out += style.item_sep;
        }
        out += _dump_value(items[i], style);
        i += 1;
    }
    return out + "]";
}


def _dump_value(value: any, style: _JsonStyle) -> str {
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
        out: str = "{";
        first: int = 1;
        keys: list[str] = sorted(d.keys()) if style.sort_keys else list(d.keys());
        for k in keys {
            if first == 0 {
                out += style.item_sep;
            }
            first = 0;
            out += _dump_str(k, style.ensure_ascii)
                + style.key_sep
                + _dump_value(d[k], style);
        }
        out += "}";
        return out;
    }
    raise TypeError("Object is not JSON serializable");
}
