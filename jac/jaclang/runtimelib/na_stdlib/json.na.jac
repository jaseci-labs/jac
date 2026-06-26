"""Bundled native `json` -- pure-Jac Mechanism-B standard library.

Part of the native standard library shipped under `jaclang/runtimelib/na_stdlib`
(issues #6404 / #6940). On the native (na) pathway `import from json { loads,
dumps }` resolves to this module through the shared bundled-stdlib resolver; on
the sv/Python pathway the identical import binds CPython's real `json`. The two
are held congruent by the tri-backend equivalence suite (`prim_json.jac`).

This is the recursive-descent half of the workload's JSON needs (#6940): a
parser producing boxed `any` (dict/list/str/int/float/bool/None -- all of which
now lower on na, unblocked by #6943/#6944) and a serializer consuming it.

KNOWN DIVERGENCES (documented, narrow):
  * float repr -- `dumps` renders floats via the native `str(float)`, which now
    emits CPython's shortest-round-trip repr (#6978 Phase 0.3, closed): a bare
    `dumps(1.0)` is byte-equal ("1.0") on both backends. Parsing floats
    (`loads`) is exact (compared with a tolerance). Integers, strings, bools,
    None, lists and objects all serialize byte-for-byte like CPython (default
    `(', ', ': ')` separators, insertion-ordered keys).
  * ensure_ascii -- CPython escapes non-ASCII as `\uXXXX` by default; this module
    escapes the control set (< 0x20) and the JSON metacharacters but passes
    printable non-ASCII through. Congruence therefore holds for ASCII payloads.
"""

"""Parse a JSON document `s` into boxed `any` (dict/list/str/int/float/bool/
None) -- json.loads."""
def:pub loads(s: str) -> any {
    p: _JsonParser = _JsonParser(src=s);
    return p._parse_value();
}


"""Serialize `value` (dict/list/str/int/float/bool/None) to a JSON string with
CPython's default separators -- json.dumps."""
def:pub dumps(value: any) -> str {
    return _dump_value(value);
}


# ----------------------------------------------------------------------------
# Parser -- a cursor over `src`; char codes (not 1-char strings) drive dispatch.
# ----------------------------------------------------------------------------
obj _JsonParser {
    has src: str,
        pos: int = 0;

    """Code point at the cursor, or -1 at end of input."""
    def _cc -> int {
        if self.pos >= len(self.src) {
            return -1;
        }
        return ord(self.src[self.pos]);
    }

    """Advance the cursor past any JSON whitespace."""
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

    """Parse one value at the cursor, skipping leading whitespace."""
    def _parse_value -> any {
        self._skip_ws();
        c: int = self._cc();
        if c == 123 {  # {
            return self._parse_object();
        }
        if c == 91 {  # [
            return self._parse_array();
        }
        if c == 34 {  # "
            return self._parse_string();
        }
        if c == 116 {  # true
            self.pos += 4;
            return True;
        }
        if c == 102 {  # false
            self.pos += 5;
            return False;
        }
        if c == 110 {  # null
            self.pos += 4;
            return None;
        }
        return self._parse_number();
    }

    """Parse a string literal (cursor on the opening quote), honoring escapes."""
    def _parse_string -> str {
        self.pos += 1;  # opening "
        out: str = "";
        while True {
            c: int = self._cc();
            if c == 34 or c == -1 {  # closing " or EOF
                self.pos += 1;
                break;
            }
            if c == 92 {  # backslash
                self.pos += 1;  # to the escape selector
                e: int = self._cc();
                self.pos += 1;  # consume the selector ('u' included)
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
                } elif e == 117 {  # \uXXXX
                    out += chr(self._hex4());
                }
            } else {
                out += self.src[self.pos];
                self.pos += 1;
            }
        }
        return out;
    }

    """Read four hex digits at the cursor as an int, advancing past them."""
    def _hex4 -> int {
        v: int = 0;
        k: int = 0;
        while k < 4 {
            d: int = self._cc();
            if d == -1 {
                # Truncated `\uXXXX` at end of input: stop rather than spin the
                # cursor past EOF. (Malformed-input rejection at large is a
                # documented gap; valid JSON always has the four digits.)
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

    """Parse a JSON number; returns an int unless a '.'/exponent forces float."""
    def _parse_number -> any {
        start: int = self.pos;
        is_float: int = 0;
        if self._cc() == 45 {  # leading '-'
            self.pos += 1;
        }
        while _is_digit(self._cc()) {
            self.pos += 1;
        }
        if self._cc() == 46 {  # '.'
            is_float = 1;
            self.pos += 1;
            while _is_digit(self._cc()) {
                self.pos += 1;
            }
        }
        c: int = self._cc();
        if c == 101 or c == 69 {  # e / E
            is_float = 1;
            self.pos += 1;
            sign: int = self._cc();
            if sign == 43 or sign == 45 {  # + / -
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

    """Parse an array (cursor on '['), returning a list[any]."""
    def _parse_array -> any {
        self.pos += 1;  # [
        out: list[any] = [];
        self._skip_ws();
        if self._cc() == 93 {  # empty []
            self.pos += 1;
            return out;
        }
        while True {
            out.append(self._parse_value());
            self._skip_ws();
            c: int = self._cc();
            if c == 44 {  # ,
                self.pos += 1;
            } elif c == 93 {  # ]
                self.pos += 1;
                break;
            } else {
                break;
            }
        }
        return out;
    }

    """Parse an object (cursor on '{'), returning a dict[str, any]."""
    def _parse_object -> any {
        self.pos += 1;  # {
        out: dict[str, any] = {};
        self._skip_ws();
        if self._cc() == 125 {  # empty {}
            self.pos += 1;
            return out;
        }
        while True {
            self._skip_ws();
            key: str = self._parse_string();
            self._skip_ws();
            if self._cc() == 58 {  # :
                self.pos += 1;
            }
            out[key] = self._parse_value();
            self._skip_ws();
            c: int = self._cc();
            if c == 44 {  # ,
                self.pos += 1;
            } elif c == 125 {  # }
                self.pos += 1;
                break;
            } else {
                break;
            }
        }
        return out;
    }
}


# ----------------------------------------------------------------------------
# Serializer -- recursive over boxed `any`, matching CPython's default layout.
# ----------------------------------------------------------------------------
"""True if char code `c` is an ASCII digit."""
def _is_digit(c: int) -> bool {
    return c >= 48 and c <= 57;
}


"""Lowercase hex digit for `v` in 0..15."""
def _hex_digit(v: int) -> str {
    if v < 10 {
        return chr(48 + v);
    }
    return chr(97 + v - 10);
}


"""`n` (0..0xFFFF) as a 4-digit lowercase hex string (\\uXXXX body)."""
def _hex4_str(n: int) -> str {
    return (
        _hex_digit((n // 4096) % 16) + _hex_digit((n // 256) % 16) + _hex_digit(
            (n // 16) % 16
        ) + _hex_digit(n % 16)
    );
}


"""Serialize a string with JSON escaping (CPython-compatible for ASCII)."""
def _dump_str(s: str) -> str {
    out: str = "\"";
    n: int = len(s);
    i: int = 0;
    while i < n {
        ch: int = ord(s[i]);
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
        } else {
            out += s[i];
        }
        i += 1;
    }
    out += "\"";
    return out;
}


"""Serialize any JSON value with CPython's default `(', ', ': ')` separators."""
def _dump_value(value: any) -> str {
    # None is handled by the trailing `return "null"`: it matches none of the
    # type checks below, and `value is None` does not lower to an i1 on the
    # native pathway (it would branch on the boxed JacVal directly).
    if isinstance(value, bool) {  # before int -- bool is a distinct na tag
        # Unbox through int (0/1): a direct `if value` would branch on the boxed
        # JacVal rather than an i1 on the native pathway.
        flag: int = value;
        if flag != 0 {
            return "true";
        }
        return "false";
    }
    if isinstance(value, int) {
        # Unbox to a concrete int first: str() on a still-boxed `any` reads 0.
        i_val: int = value;
        return str(i_val);
    }
    if isinstance(value, float) {  # str(float) is shortest round-trip (#6978 0.3)
        f_val: float = value;
        return str(f_val);
    }
    if isinstance(value, str) {
        s_val: str = value;
        return _dump_str(s_val);
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
            out += _dump_value(arr[i]);
            i += 1;
        }
        out += "]";
        return out;
    }
    if isinstance(value, dict) {
        d: dict[str, any] = value;
        out: str = "{";
        first: int = 1;
        for k in d {
            if first == 0 {
                out += ", ";
            }
            first = 0;
            out += _dump_str(k) + ": " + _dump_value(d[k]);
        }
        out += "}";
        return out;
    }
    return "null";
}
