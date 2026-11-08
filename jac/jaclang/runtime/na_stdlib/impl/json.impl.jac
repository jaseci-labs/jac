impl JSONDecodeError.init(msg: str, doc: str, pos: int) {
    self.msg = msg;
    self.doc = doc;
    self.pos = pos;
    self.lineno = 1;
    self.colno = pos + 1;
    i: int = 0;
    while i < pos and i < len(doc) {
        if doc[i] == "\n" {
            self.lineno += 1;
            self.colno = pos - i;
        }
        i += 1;
    }
}

impl JSONDecodeError.__str__ -> str {
    return (
        self.msg
        + ": line "
        + str(self.lineno)
        + " column "
        + str(self.colno)
        + " (char "
        + str(self.pos)
        + ")"
    );
}

impl JSONDecoder._mkparser(s: str) -> _JsonParser {
    raw: bytes = s.encode("utf-8", "surrogatepass");
    return _JsonParser(
        buf=raw,
        n=len(raw),
        strict=self.strict,
        object_hook=self.object_hook,
        object_pairs_hook=self.object_pairs_hook,
        parse_float=self.parse_float,
        parse_int=self.parse_int,
        parse_constant=self.parse_constant
    );
}

impl JSONDecoder.decode(s: str) -> any {
    p: _JsonParser = self._mkparser(s);
    v: any = p._parse_value();
    p._skip_ws();
    if p.pos < p.n {
        p._fail("Extra data", p.pos);
    }
    return v;
}

impl JSONDecoder.raw_decode(s: str, idx: int = 0) -> tuple[any, int] {
    p: _JsonParser = self._mkparser(s);
    p.pos = idx;
    v: any = p._parse_scalar();
    return (v, p.pos);
}

impl JSONEncoder.init(
    skipkeys: bool = False,
    ensure_ascii: bool = True,
    check_circular: bool = True,
    allow_nan: bool = True,
    sort_keys: bool = False,
    indent: (int | str | None) = None,
    separators: (tuple[str, str] | None) = None,
    `default: (Callable[[any], any] | None) = None
) {
    self.skipkeys = skipkeys;
    self.ensure_ascii = ensure_ascii;
    self.check_circular = check_circular;
    self.allow_nan = allow_nan;
    self.sort_keys = sort_keys;
    self.indent = indent;
    self.separators = separators;
    self.item_separator = ", ";
    self.key_separator = ": ";
    if separators is not None {
        (item_sep, key_sep) = separators;
        self.item_separator = item_sep;
        self.key_separator = key_sep;
    } elif indent is not None {
        self.item_separator = ",";
    }
    self._default_fn = `default;
}

impl JSONEncoder.`default(o: any) -> any {
    if self._default_fn is not None {
        return _apply_hook(self._default_fn, o);
    }
    raise TypeError("Object of type " + typename(o) + " is not JSON serializable");
}

impl JSONEncoder.encode(o: any) -> str {
    style: _JsonStyle = _make_style(
        self.skipkeys,
        self.ensure_ascii,
        self.check_circular,
        self.allow_nan,
        self.sort_keys,
        self.indent,
        self.item_separator,
        self.key_separator,
        lambda (v: any) -> any { return self.`default(v); }
    );
    seen: list[any] = [];
    return _dump_value(o, style, 0, seen);
}

impl JSONEncoder.iterencode(o: any) -> list[str] {
    return [self.encode(o)];
}

impl load(
    fp: File,
    cls: (type | None) = None,
    object_hook: (Callable[[any], any] | None) = None,
    parse_float: (Callable[[any], any] | None) = None,
    parse_int: (Callable[[any], any] | None) = None,
    parse_constant: (Callable[[any], any] | None) = None,
    object_pairs_hook: (Callable[[any], any] | None) = None
) -> any {
    return loads(
        fp.read(),
        cls=cls,
        object_hook=object_hook,
        parse_float=parse_float,
        parse_int=parse_int,
        parse_constant=parse_constant,
        object_pairs_hook=object_pairs_hook
    );
}

impl loads(
    s: str,
    cls: (type | None) = None,
    object_hook: (Callable[[any], any] | None) = None,
    parse_float: (Callable[[any], any] | None) = None,
    parse_int: (Callable[[any], any] | None) = None,
    parse_constant: (Callable[[any], any] | None) = None,
    object_pairs_hook: (Callable[[any], any] | None) = None
) -> any {
    if cls is not None {
        raise NotImplementedError(
            "json.loads: cls= is not supported on the native pathway"
        );
    }
    dec: JSONDecoder = JSONDecoder(
        object_hook=object_hook,
        parse_float=parse_float,
        parse_int=parse_int,
        parse_constant=parse_constant,
        object_pairs_hook=object_pairs_hook
    );
    return dec.decode(s);
}

impl dump(
    `obj: any,
    fp: File,
    skipkeys: bool = False,
    ensure_ascii: bool = True,
    check_circular: bool = True,
    allow_nan: bool = True,
    cls: (type | None) = None,
    indent: (int | str | None) = None,
    separators: (tuple[str, str] | None) = None,
    `default: (Callable[[any], any] | None) = None,
    sort_keys: bool = False
) {
    fp.write(
        dumps(
            `obj,
            skipkeys=skipkeys,
            ensure_ascii=ensure_ascii,
            check_circular=check_circular,
            allow_nan=allow_nan,
            cls=cls,
            indent=indent,
            separators=separators,
            `default=`default,
            sort_keys=sort_keys
        )
    );
}

impl dumps(
    `obj: any,
    skipkeys: bool = False,
    ensure_ascii: bool = True,
    check_circular: bool = True,
    allow_nan: bool = True,
    cls: (type | None) = None,
    indent: (int | str | None) = None,
    separators: (tuple[str, str] | None) = None,
    `default: (Callable[[any], any] | None) = None,
    sort_keys: bool = False
) -> str {
    if cls is not None {
        raise NotImplementedError(
            "json.dumps: cls= is not supported on the native pathway"
        );
    }
    enc: JSONEncoder = JSONEncoder(
        skipkeys=skipkeys,
        ensure_ascii=ensure_ascii,
        check_circular=check_circular,
        allow_nan=allow_nan,
        sort_keys=sort_keys,
        indent=indent,
        separators=separators,
        `default=`default
    );
    return enc.encode(`obj);
}

impl _JsonParser._cc -> int {
    if self.pos >= self.n {
        return -1;
    }
    return self.buf[self.pos];
}

impl _JsonParser._peek(off: int) -> int {
    at: int = self.pos + off;
    if at >= self.n {
        return -1;
    }
    return self.buf[at];
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

impl _JsonParser._doc -> str {
    return self.buf.decode("utf-8", "surrogatepass");
}

impl _JsonParser._fail(msg: str, pos: int) {
    raise JSONDecodeError(msg, self._doc(), pos);
}

impl _JsonParser._match(w: bytes) -> bool {
    e: int = self.pos + len(w);
    if e > self.n {
        return False;
    }
    if self.buf[self.pos:e] != w {
        return False;
    }
    self.pos = e;
    return True;
}

impl _JsonParser._parse_value -> any {
    self._skip_ws();
    return self._parse_scalar();
}

impl _JsonParser._parse_scalar -> any {
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
    if c == 116 and self._match(b"true") {
        return True;
    }
    if c == 102 and self._match(b"false") {
        return False;
    }
    if c == 110 and self._match(b"null") {
        return None;
    }
    if c == 78 and self._match(b"NaN") {
        return self._parse_const("NaN");
    }
    if c == 73 and self._match(b"Infinity") {
        return self._parse_const("Infinity");
    }
    if c == 45 and self._match(b"-Infinity") {
        return self._parse_const("-Infinity");
    }
    if c == 45 or _is_digit(c) {
        return self._parse_number();
    }
    self._fail("Expecting value", self.pos);
}

impl _JsonParser._parse_string -> str {
    str_start: int = self.pos;
    self.pos += 1;
    closing: int = self.buf.find(b"\"", self.pos);
    if closing >= 0 {
        plain: bytes = self.buf[self.pos:closing];
        if plain.find(b"\\") < 0 {
            if self.strict {
                k: int = 0;
                m: int = len(plain);
                while k < m {
                    if plain[k] < 32 {
                        self._fail("Invalid control character at", self.pos + k);
                    }
                    k += 1;
                }
            }
            self.pos = closing + 1;
            return plain.decode("utf-8", "surrogatepass");
        }
    }
    parts: list[str] = [];
    run_start: int = self.pos;
    while True {
        c: int = self._cc();
        if c == 34 {
            if self.pos > run_start {
                parts.append(
                    self.buf[run_start:self.pos].decode("utf-8", "surrogatepass")
                );
            }
            self.pos += 1;
            break;
        }
        if c == -1 {
            self._fail("Unterminated string starting at", str_start);
        }
        if c < 32 and self.strict {
            self._fail("Invalid control character at", self.pos);
        }
        if c == 92 {
            if self.pos > run_start {
                parts.append(
                    self.buf[run_start:self.pos].decode("utf-8", "surrogatepass")
                );
            }
            self.pos += 1;
            epos: int = self.pos;
            e: int = self._cc();
            if e == -1 {
                self._fail("Unterminated string starting at", str_start);
            }
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
            } else {
                self._fail("Invalid \\escape", epos - 1);
            }
            run_start = self.pos;
        } else {
            self.pos += 1;
        }
    }
    return "".join(parts);
}

impl _JsonParser._hex4 -> int {
    u_at: int = self.pos - 1;
    v: int = 0;
    k: int = 0;
    while k < 4 {
        d: int = self._cc();
        nib: int = 0;
        if d >= 48 and d <= 57 {
            nib = d - 48;
        } elif d >= 97 and d <= 102 {
            nib = d - 87;
        } elif d >= 65 and d <= 70 {
            nib = d - 55;
        } else {
            self._fail("Invalid \\uXXXX escape", u_at);
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
    if self._cc() == 48 {
        self.pos += 1;
    } elif _is_digit(self._cc()) {
        while _is_digit(self._cc()) {
            self.pos += 1;
        }
    } else {
        self._fail("Expecting value", start);
    }
    if self._cc() == 46 and _is_digit(self._peek(1)) {
        is_float = 1;
        self.pos += 1;
        while _is_digit(self._cc()) {
            self.pos += 1;
        }
    }
    c: int = self._cc();
    if c == 101 or c == 69 {
        nxt: int = self._peek(1);
        sign: int = 0;
        if nxt == 43 or nxt == 45 {
            sign = 1;
            nxt = self._peek(2);
        }
        if _is_digit(nxt) {
            is_float = 1;
            self.pos += 1 + sign;
            while _is_digit(self._cc()) {
                self.pos += 1;
            }
        }
    }
    numstr: str = self.buf[start:self.pos].decode();
    if is_float == 1 {
        if self.parse_float is not None {
            return _apply_hook(self.parse_float, numstr);
        }
        return float(numstr);
    }
    if self.parse_int is not None {
        return _apply_hook(self.parse_int, numstr);
    }
    return int(numstr);
}

impl _JsonParser._parse_const(txt: str) -> any {
    if self.parse_constant is not None {
        return _apply_hook(self.parse_constant, txt);
    }
    if txt == "NaN" {
        return float("nan");
    }
    if txt == "Infinity" {
        return float("inf");
    }
    return float("-inf");
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
            comma: int = self.pos;
            self.pos += 1;
            self._skip_ws();
            if self._cc() == 93 {
                self._fail("Illegal trailing comma before end of array", comma);
            }
        } elif c == 93 {
            self.pos += 1;
            break;
        } else {
            self._fail("Expecting ',' delimiter", self.pos);
        }
    }
    return out;
}

impl _JsonParser._finish_obj(out: dict[str, any], pairs: list[any]) -> any {
    if self.object_pairs_hook is not None {
        return _apply_hook(self.object_pairs_hook, pairs);
    }
    if self.object_hook is not None {
        return _apply_hook(self.object_hook, out);
    }
    return out;
}

impl _JsonParser._parse_object -> any {
    self.pos += 1;
    self._skip_ws();
    if self._cc() == 125 {
        self.pos += 1;
        return self._finish_obj({}, []);
    }
    out: dict[str, any] = {};
    pairs: list[any] = [];
    while True {
        if self._cc() != 34 {
            self._fail("Expecting property name enclosed in double quotes", self.pos);
        }
        key: str = self._parse_string();
        self._skip_ws();
        if self._cc() != 58 {
            self._fail("Expecting ':' delimiter", self.pos);
        }
        self.pos += 1;
        v: any = self._parse_value();
        if self.object_pairs_hook is not None {
            pairs.append((key, v));
        } else {
            out[key] = v;
        }
        self._skip_ws();
        c: int = self._cc();
        if c == 44 {
            comma: int = self.pos;
            self.pos += 1;
            self._skip_ws();
            if self._cc() == 125 {
                self._fail("Illegal trailing comma before end of object", comma);
            }
        } elif c == 125 {
            self.pos += 1;
            break;
        } else {
            self._fail("Expecting ',' delimiter", self.pos);
        }
    }
    return self._finish_obj(out, pairs);
}

impl _apply_hook(f: Callable[[any], any], v: any) -> any {
    return f(v);
}

impl _is_digit(c: int) -> bool {
    return c >= 48 and c <= 57;
}

impl _hex4_str(n: int) -> str {
    return hex2(n // 256) + hex2(n % 256);
}

impl _indent_str(indent: (int | str | None)) -> (str | None) {
    if indent is None {
        return None;
    }
    if isinstance(indent, str) {
        s: str = indent;
        return s;
    }
    i: int = indent;
    if i <= 0 {
        return "";
    }
    return " " * i;
}

impl _make_style(
    skipkeys: bool,
    ensure_ascii: bool,
    check_circular: bool,
    allow_nan: bool,
    sort_keys: bool,
    indent: (int | str | None),
    item_sep: str,
    key_sep: str,
    default_fn: (Callable[[any], any] | None)
) -> _JsonStyle {
    style: _JsonStyle = _JsonStyle(
        sort_keys=sort_keys,
        ensure_ascii=ensure_ascii,
        skipkeys=skipkeys,
        check_circular=check_circular,
        allow_nan=allow_nan,
        item_sep=item_sep,
        key_sep=key_sep,
        default_fn=default_fn
    );
    style.indent = _indent_str(indent);
    return style;
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

impl _dump_float(f_val: float, allow_nan: bool) -> str {
    if f_val != f_val or f_val == float("inf") or f_val == float("-inf") {
        if not allow_nan {
            raise ValueError(
                "Out of range float values are not JSON compliant: " + str(f_val)
            );
        }
        if f_val != f_val {
            return "NaN";
        }
        if f_val == float("inf") {
            return "Infinity";
        }
        return "-Infinity";
    }
    return str(f_val);
}

impl _key_text(k: any, style: _JsonStyle) -> (str | None) {
    if isinstance(k, str) {
        s: str = k;
        return s;
    }
    if isinstance(k, bool) {
        b: bool = k;
        if b {
            return "true";
        }
        return "false";
    }
    if k is None {
        return "null";
    }
    if isinstance(k, int) {
        i: int = k;
        return str(i);
    }
    if isinstance(k, float) {
        f: float = k;
        return _dump_float(f, style.allow_nan);
    }
    if style.skipkeys {
        return None;
    }
    raise TypeError("keys must be str, int, float, bool or None, not " + typename(k));
}

impl _num_key(v: any) -> (float | None) {
    if isinstance(v, float) {
        return v;
    }
    if isinstance(v, bool) {
        vb: bool = v;
        return float(vb);
    }
    if isinstance(v, int) {
        vi: int = v;
        return float(vi);
    }
    return None;
}

impl _key_cmp(a: any, b: any) -> int {
    fa: (float | None) = _num_key(a);
    fb: (float | None) = _num_key(b);
    if fa is not None and fb is not None {
        if fa < fb {
            return -1;
        }
        if fa > fb {
            return 1;
        }
        return 0;
    }
    if isinstance(a, str) and isinstance(b, str) {
        sa: str = a;
        sb: str = b;
        if sa < sb {
            return -1;
        }
        if sa > sb {
            return 1;
        }
        return 0;
    }
    raise TypeError(
        "'<' not supported between instances of '"
            + typename(a)
            + "' and '"
            + typename(b)
            + "'"
    );
}

impl _sort_keys(keys: list[any]) {
    n: int = len(keys);
    if n < 2 {
        return;
    }
    mid: int = n // 2;
    left: list[any] = keys[0:mid];
    right: list[any] = keys[mid:n];
    _sort_keys(left);
    _sort_keys(right);
    i: int = 0;
    j: int = 0;
    t: int = 0;
    while i < mid and j < n - mid {
        if _key_cmp(left[i], right[j]) <= 0 {
            keys[t] = left[i];
            i += 1;
        } else {
            keys[t] = right[j];
            j += 1;
        }
        t += 1;
    }
    while i < mid {
        keys[t] = left[i];
        i += 1;
        t += 1;
    }
    while j < n - mid {
        keys[t] = right[j];
        j += 1;
        t += 1;
    }
}

impl _dump_items(items: any, style: _JsonStyle, depth: int, seen: list[any]) -> str {
    n: int = len(items);
    if n == 0 {
        return "[]";
    }
    ind: str = "";
    if style.indent is not None {
        ind = style.indent;
    }
    pretty: bool = style.indent is not None;
    pad: str = "\n" + ind * (depth + 1);
    back: str = "\n" + ind * depth;
    parts: list[str] = ["["];
    i: int = 0;
    while i < n {
        if i > 0 {
            parts.append(style.item_sep);
        }
        if pretty {
            parts.append(pad);
        }
        parts.append(_dump_value(items[i], style, depth + 1, seen));
        i += 1;
    }
    if pretty {
        parts.append(back);
    }
    parts.append("]");
    return "".join(parts);
}

impl _dump_dict(
    d: dict[str, any], style: _JsonStyle, depth: int, seen: list[any]
) -> str {
    keys: list[any] = list(d.keys());
    if style.sort_keys {
        _sort_keys(keys);
    }
    if len(keys) == 0 {
        return "{}";
    }
    ind: str = "";
    if style.indent is not None {
        ind = style.indent;
    }
    pretty: bool = style.indent is not None;
    pad: str = "\n" + ind * (depth + 1);
    back: str = "\n" + ind * depth;
    parts: list[str] = ["{"];
    first: int = 1;
    for k in keys {
        kt: (str | None) = _key_text(k, style);
        if kt is None {
            continue;
        }
        if first == 0 {
            parts.append(style.item_sep);
        }
        if pretty {
            parts.append(pad);
        }
        first = 0;
        kstr: str = kt;
        parts.append(_dump_str(kstr, style.ensure_ascii));
        parts.append(style.key_sep);
        parts.append(_dump_value(d[k], style, depth + 1, seen));
    }
    if pretty {
        parts.append(back);
    }
    parts.append("}");
    return "".join(parts);
}

impl _dump_value(value: any, style: _JsonStyle, depth: int, seen: list[any]) -> str {
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
        return _dump_float(f_val, style.allow_nan);
    }
    if isinstance(value, str) {
        s_val: str = value;
        return _dump_str(s_val, style.ensure_ascii);
    }
    if isinstance(value, list) or isinstance(value, tuple) {
        if style.check_circular {
            for c in seen {
                if c is value {
                    raise ValueError("Circular reference detected");
                }
            }
            seen.append(value);
        }
        r: str = _dump_items(value, style, depth, seen);
        if style.check_circular {
            seen.pop();
        }
        return r;
    }
    if isinstance(value, dict) {
        if style.check_circular {
            for c in seen {
                if c is value {
                    raise ValueError("Circular reference detected");
                }
            }
            seen.append(value);
        }
        d: dict[str, any] = value;
        r: str = _dump_dict(d, style, depth, seen);
        if style.check_circular {
            seen.pop();
        }
        return r;
    }
    if style.default_fn is not None {
        return _dump_value(_apply_hook(style.default_fn, value), style, depth, seen);
    }
    raise TypeError("Object of type " + typename(value) + " is not JSON serializable");
}
