def:pub loads(s: str) -> dict[str, any] {
    src: str = s.replace("\r\n", "\n");
    p: _Parser = _Parser(src);
    return p._run();
}


glob _FROZEN: int = 0,
     _EXPLICIT: int = 1,
     _I64_MAX: int = 9223372036854775807,
     _DEC_OVF: int = 922337203685477580;


obj TOMLDecodeError(Exception) {
    has msg: str = "",
        doc: str = "",
        pos: int = 0,
        lineno: int = 0,
        colno: int = 0,
        at_eod: bool = False;

    def init(msg: str, doc: str, pos: int) {
        self.msg = msg;
        self.doc = doc;
        self.pos = pos;
        nl: int = 0;
        last: int = -1;
        i: int = 0;
        while i < pos and i < len(doc) {
            if doc[i] == "\n" {
                nl += 1;
                last = i;
            }
            i += 1;
        }
        self.lineno = nl + 1;
        self.colno = pos - last;
        if pos >= len(doc) {
            self.at_eod = True;
        }
    }

    def __str__ -> str {
        if self.at_eod {
            return self.msg + " (at end of document)";
        }
        return self.msg
            + " (at line "
            + str(self.lineno)
            + ", column "
            + str(self.colno)
            + ")";
    }
}


obj _TDate {
    has year: int = 0,
        month: int = 0,
        day: int = 0;

    def isoformat -> str {
        return _pad4(self.year) + "-" + _pad2(self.month) + "-" + _pad2(self.day);
    }

    def __str__ -> str {
        return self.isoformat();
    }
}


obj _TTime {
    has hour: int = 0,
        minute: int = 0,
        second: int = 0,
        microsecond: int = 0;

    def isoformat -> str {
        out: str = _pad2(self.hour)
            + ":"
            + _pad2(self.minute)
            + ":"
            + _pad2(self.second);
        if self.microsecond != 0 {
            out += "." + _pad6(self.microsecond);
        }
        return out;
    }

    def __str__ -> str {
        return self.isoformat();
    }
}


obj _TDatetime {
    has year: int = 0,
        month: int = 0,
        day: int = 0,
        hour: int = 0,
        minute: int = 0,
        second: int = 0,
        microsecond: int = 0,
        offset_minutes: int = 0,
        has_offset: bool = False;

    def isoformat(sep: str = "T") -> str {
        out: str = _pad4(self.year) + "-" + _pad2(self.month) + "-" + _pad2(self.day);
        out += sep
            + _pad2(self.hour)
            + ":"
            + _pad2(self.minute)
            + ":"
            + _pad2(self.second);
        if self.microsecond != 0 {
            out += "." + _pad6(self.microsecond);
        }
        if self.has_offset {
            out += _offset_str(self.offset_minutes);
        }
        return out;
    }

    def __str__ -> str {
        return self.isoformat(" ");
    }
}


obj _Flags {
    has m: dict[str, int] = {},
        pk: list[str] = [],
        pf: list[int] = [];

    def init {
        self.m = {};
        self.pk = [];
        self.pf = [];
    }

    def _join(parts: list[str]) -> str {
        out: str = "";
        i: int = 0;
        while i < len(parts) {
            out += str(len(parts[i])) + ":" + parts[i];
            i += 1;
        }
        return out;
    }

    def _is(parts: list[str], flag: int) -> bool {
        n: int = len(parts);
        if n == 0 {
            return False;
        }
        bit: int = 1 << flag;
        rbit: int = 1 << (flag + 8);
        i: int = 1;
        while i < n {
            pre: str = self._join(_prefix(parts, i));
            mask: int = 0;
            if pre in self.m {
                mask = self.m[pre];
            }
            if mask & rbit != 0 {
                return True;
            }
            i += 1;
        }
        whole: str = self._join(parts);
        wmask: int = 0;
        if whole in self.m {
            wmask = self.m[whole];
        }
        if wmask & bit != 0 or wmask & rbit != 0 {
            return True;
        }
        return False;
    }

    def _set_joined(path: str, flag: int, recursive: bool) {
        add: int = 1 << flag;
        if recursive {
            add = 1 << (flag + 8);
        }
        cur: int = 0;
        if path in self.m {
            cur = self.m[path];
        }
        self.m[path] = cur | add;
    }

    def _set(parts: list[str], flag: int, recursive: bool) {
        self._set_joined(self._join(parts), flag, recursive);
    }

    def _unset_all(parts: list[str]) {
        path: str = self._join(parts);
        lp: int = len(path);
        dead: list[str] = [];
        for k in self.m {
            if len(k) >= lp {
                if k[:lp] == path {
                    dead.append(k);
                }
            }
        }
        i: int = 0;
        while i < len(dead) {
            self.m[dead[i]] = 0;
            i += 1;
        }
    }

    def _add_pending(parts: list[str], flag: int) {
        self.pk.append(self._join(parts));
        self.pf.append(flag);
    }

    def _finalize_pending {
        i: int = 0;
        while i < len(self.pk) {
            self._set_joined(self.pk[i], self.pf[i], False);
            i += 1;
        }
        self.pk = [];
        self.pf = [];
    }
}


obj _Data {
    has top: dict[str, any] = {};

    def init {
        self.top = {};
    }

    def _get_or_create_nest(parts: list[str], access_lists: bool) -> dict[str, any] {
        cont: dict[str, any] = self.top;
        i: int = 0;
        n: int = len(parts);
        while i < n {
            k: str = parts[i];
            if k not in cont {
                child: dict[str, any] = {};
                cont[k] = child;
            }
            cur: any = cont[k];
            if access_lists {
                if isinstance(cur, list) {
                    lst: list[any] = cur;
                    cur = lst[len(lst) - 1];
                }
            }
            if not isinstance(cur, dict) {
                raise KeyError("There is no nest behind this key");
            }
            cont = cur;
            i += 1;
        }
        return cont;
    }

    def _append_nest_to_list(parts: list[str]) {
        parent: list[str] = _all_but_last(parts);
        cont: dict[str, any] = self._get_or_create_nest(parent, True);
        last: str = parts[len(parts) - 1];
        if last in cont {
            cur: any = cont[last];
            if not isinstance(cur, list) {
                raise KeyError("An object other than list found behind this key");
            }
            lst: list[any] = cur;
            fresh: dict[str, any] = {};
            lst.append(fresh);
        } else {
            lst2: list[any] = [];
            item: dict[str, any] = {};
            lst2.append(item);
            cont[last] = lst2;
        }
    }
}


obj _Parser {
    has src: str = "",
        pos: int = 0,
        out_data: _Data = _Data(),
        out_flags: _Flags = _Flags(),
        header: list[str] = [];

    def init(s: str) {
        self.src = s;
        self.pos = 0;
        self.out_data = _Data();
        self.out_flags = _Flags();
        self.header = [];
    }

    def _cc(p: int) -> int {
        if p >= len(self.src) {
            return -1;
        }
        return ord(self.src[p]);
    }

    def _at(p: int) -> str {
        if p >= len(self.src) {
            return "";
        }
        return self.src[p];
    }

    def _starts_at(q: str, p: int) -> bool {
        n: int = len(q);
        if p + n > len(self.src) {
            return False;
        }
        i: int = 0;
        while i < n {
            if self.src[p + i] != q[i] {
                return False;
            }
            i += 1;
        }
        return True;
    }

    def _err(msg: str, p: int) {
        raise TOMLDecodeError(msg, self.src, p);
    }

    def _skip_ws(p: int) -> int {
        while True {
            c: int = self._cc(p);
            if c == 32 or c == 9 {
                p += 1;
            } else {
                break;
            }
        }
        return p;
    }

    def _skip_ws_nl(p: int) -> int {
        while True {
            c: int = self._cc(p);
            if c == 32 or c == 9 or c == 10 {
                p += 1;
            } else {
                break;
            }
        }
        return p;
    }

    def _skip_comment(p: int) -> int {
        if self._cc(p) != 35 {
            return p;
        }
        p += 1;
        while True {
            c: int = self._cc(p);
            if c == -1 or c == 10 {
                return p;
            }
            if _is_illegal_basic(c) {
                self._err("Found invalid character " + _char_repr(c), p);
            }
            p += 1;
        }
        return p;
    }

    def _skip_array_ws(p: int) -> int {
        while True {
            before: int = p;
            p = self._skip_ws_nl(p);
            p = self._skip_comment(p);
            if p == before {
                return p;
            }
        }
        return p;
    }

    def _run -> dict[str, any] {
        while True {
            self.pos = self._skip_ws(self.pos);
            if self.pos >= len(self.src) {
                break;
            }
            ch: str = self.src[self.pos];
            if ch == "\n" {
                self.pos += 1;
                continue;
            }
            if _is_key_init(ord(ch)) {
                self._key_value_rule();
                self.pos = self._skip_ws(self.pos);
            } elif ch == "[" {
                self.out_flags._finalize_pending();
                second: str = "";
                if self.pos + 1 < len(self.src) {
                    second = self.src[self.pos + 1];
                }
                if second == "[" {
                    self._create_list_rule();
                } else {
                    self._create_dict_rule();
                }
                self.pos = self._skip_ws(self.pos);
            } elif ch != "#" {
                self._err("Invalid statement", self.pos);
            }
            self.pos = self._skip_comment(self.pos);
            if self.pos >= len(self.src) {
                break;
            }
            if self.src[self.pos] != "\n" {
                self._err(
                    "Expected newline or end of document after a statement", self.pos
                );
            }
            self.pos += 1;
        }
        return self.out_data.top;
    }

    def _create_dict_rule {
        self.pos += 1;
        self.pos = self._skip_ws(self.pos);
        key: list[str] = self._parse_key();
        if self.out_flags._is(key, _EXPLICIT) or self.out_flags._is(key, _FROZEN) {
            self._err("Cannot declare " + _fmt_key(key) + " twice", self.pos);
        }
        self.out_flags._set(key, _EXPLICIT, False);
        try {
            self.out_data._get_or_create_nest(key, True);
        } except KeyError {
            self._err("Cannot overwrite a value", self.pos);
        }
        if not self._starts_at("]", self.pos) {
            self._err("Expected ']' at the end of a table declaration", self.pos);
        }
        self.pos += 1;
        self.header = key;
    }

    def _create_list_rule {
        self.pos += 2;
        self.pos = self._skip_ws(self.pos);
        key: list[str] = self._parse_key();
        if self.out_flags._is(key, _FROZEN) {
            self._err("Cannot mutate immutable namespace " + _fmt_key(key), self.pos);
        }
        self.out_flags._unset_all(key);
        self.out_flags._set(key, _EXPLICIT, False);
        try {
            self.out_data._append_nest_to_list(key);
        } except KeyError {
            self._err("Cannot overwrite a value", self.pos);
        }
        if not self._starts_at("]]", self.pos) {
            self._err("Expected ']]' at the end of an array declaration", self.pos);
        }
        self.pos += 2;
        self.header = key;
    }

    def _key_value_rule {
        (key, value) = self._parse_key_value_pair();
        parent: list[str] = _all_but_last(key);
        stem: str = key[len(key) - 1];
        abs_parent: list[str] = _concat(self.header, parent);
        i: int = 1;
        while i < len(key) {
            cont_key: list[str] = _concat(self.header, _prefix(key, i));
            if self.out_flags._is(cont_key, _EXPLICIT) {
                self._err("Cannot redefine namespace " + _fmt_key(cont_key), self.pos);
            }
            self.out_flags._add_pending(cont_key, _EXPLICIT);
            i += 1;
        }
        if self.out_flags._is(abs_parent, _FROZEN) {
            self._err(
                "Cannot mutate immutable namespace " + _fmt_key(abs_parent), self.pos
            );
        }
        try {
            nest: dict[str, any] = self.out_data._get_or_create_nest(abs_parent, True);
            if stem in nest {
                self._err("Cannot overwrite a value", self.pos);
            }
            if isinstance(value, dict) or isinstance(value, list) {
                self.out_flags._set(_concat(self.header, key), _FROZEN, True);
            }
            nest[stem] = value;
        } except KeyError {
            self._err("Cannot overwrite a value", self.pos);
        }
    }

    def _parse_key_value_pair -> tuple[(list[str], any)] {
        key: list[str] = self._parse_key();
        if self._at(self.pos) != "=" {
            self._err("Expected '=' after a key in a key/value pair", self.pos);
        }
        self.pos += 1;
        self.pos = self._skip_ws(self.pos);
        value: any = self._parse_value();
        return (key, value);
    }

    def _parse_key -> list[str] {
        parts: list[str] = [];
        first: str = self._parse_key_part();
        parts.append(first);
        self.pos = self._skip_ws(self.pos);
        while True {
            if self._at(self.pos) != "." {
                return parts;
            }
            self.pos += 1;
            self.pos = self._skip_ws(self.pos);
            part: str = self._parse_key_part();
            parts.append(part);
            if len(parts) > 1000 {
                raise RecursionError("TOML key has more than the allowed 1000 parts");
            }
            self.pos = self._skip_ws(self.pos);
        }
        return parts;
    }

    def _parse_key_part -> str {
        c: int = self._cc(self.pos);
        if _is_bare(c) {
            start: int = self.pos;
            while _is_bare(self._cc(self.pos)) {
                self.pos += 1;
            }
            return self.src[start:self.pos];
        }
        if c == 39 {
            return self._parse_literal_str();
        }
        if c == 34 {
            self.pos += 1;
            return self._parse_basic_str(False);
        }
        self._err("Invalid initial character for a key part", self.pos);
        return "";
    }

    def _parse_value -> any {
        c: int = self._cc(self.pos);
        if c == 34 {
            if self._starts_at("\"\"\"", self.pos) {
                return self._parse_multiline_str(False);
            }
            self.pos += 1;
            return self._parse_basic_str(False);
        }
        if c == 39 {
            if self._starts_at("'''", self.pos) {
                return self._parse_multiline_str(True);
            }
            return self._parse_literal_str();
        }
        if c == 116 {
            if self._starts_at("true", self.pos) {
                self.pos += 4;
                return True;
            }
        }
        if c == 102 {
            if self._starts_at("false", self.pos) {
                self.pos += 5;
                return False;
            }
        }
        if c == 91 {
            return self._parse_array();
        }
        if c == 123 {
            return self._parse_inline_table();
        }
        dend: int = self._match_datetime(self.pos);
        if dend != -1 {
            v: any = self._build_datetime(self.pos, dend);
            self.pos = dend;
            return v;
        }
        lend: int = self._match_localtime(self.pos);
        if lend != -1 {
            v2: any = self._build_localtime(self.pos, lend);
            self.pos = lend;
            return v2;
        }
        nend: int = self._match_number(self.pos);
        if nend != -1 {
            v3: any = self._build_number(self.pos, nend);
            self.pos = nend;
            return v3;
        }
        if self._starts_at("inf", self.pos) {
            self.pos += 3;
            return float("inf");
        }
        if self._starts_at("nan", self.pos) {
            self.pos += 3;
            return float("nan");
        }
        if self._starts_at("-inf", self.pos) {
            self.pos += 4;
            return float("-inf");
        }
        if self._starts_at("+inf", self.pos) {
            self.pos += 4;
            return float("inf");
        }
        if self._starts_at("-nan", self.pos) {
            self.pos += 4;
            return float("nan");
        }
        if self._starts_at("+nan", self.pos) {
            self.pos += 4;
            return float("nan");
        }
        self._err("Invalid value", self.pos);
        return None;
    }

    def _parse_array -> any {
        self.pos += 1;
        arr: list[any] = [];
        self.pos = self._skip_array_ws(self.pos);
        if self._starts_at("]", self.pos) {
            self.pos += 1;
            return arr;
        }
        while True {
            val: any = self._parse_value();
            arr.append(val);
            self.pos = self._skip_array_ws(self.pos);
            c: str = self._at(self.pos);
            if c == "]" {
                self.pos += 1;
                return arr;
            }
            if c != "," {
                self._err("Unclosed array", self.pos);
            }
            self.pos += 1;
            self.pos = self._skip_array_ws(self.pos);
            if self._starts_at("]", self.pos) {
                self.pos += 1;
                return arr;
            }
        }
        return arr;
    }

    def _parse_inline_table -> any {
        self.pos += 1;
        nd: _Data = _Data();
        fl: _Flags = _Flags();
        self.pos = self._skip_ws(self.pos);
        if self._starts_at("}", self.pos) {
            self.pos += 1;
            return nd.top;
        }
        while True {
            (key, value) = self._parse_key_value_pair();
            stem: str = key[len(key) - 1];
            parent: list[str] = _all_but_last(key);
            if fl._is(key, _FROZEN) {
                self._err(
                    "Cannot mutate immutable namespace " + _fmt_key(key), self.pos
                );
            }
            try {
                nest: dict[str, any] = nd._get_or_create_nest(parent, False);
                if stem in nest {
                    self._err(
                        "Duplicate inline table key " + _str_repr(stem), self.pos
                    );
                }
                nest[stem] = value;
            } except KeyError {
                self._err("Cannot overwrite a value", self.pos);
            }
            self.pos = self._skip_ws(self.pos);
            c: str = self._at(self.pos);
            if c == "}" {
                self.pos += 1;
                return nd.top;
            }
            if c != "," {
                self._err("Unclosed inline table", self.pos);
            }
            if isinstance(value, dict) or isinstance(value, list) {
                fl._set(key, _FROZEN, True);
            }
            self.pos += 1;
            self.pos = self._skip_ws(self.pos);
        }
        return nd.top;
    }

    def _parse_literal_str -> str {
        self.pos += 1;
        start: int = self.pos;
        end: int = -1;
        while True {
            c: int = self._cc(self.pos);
            if c == -1 {
                self._err("Expected \"'\"", len(self.src));
            }
            if c == 39 {
                end = self.pos;
                break;
            }
            self.pos += 1;
        }
        scan: int = start;
        while scan < end {
            c2: int = ord(self.src[scan]);
            if _is_illegal_basic(c2) {
                self._err("Found invalid character " + _char_repr(c2), scan);
            }
            scan += 1;
        }
        self.pos = end + 1;
        return self.src[start:end];
    }

    def _scan_ml_literal -> str {
        start: int = self.pos;
        end: int = -1;
        while True {
            c: int = self._cc(self.pos);
            if c == -1 {
                self._err("Expected \"'''\"", len(self.src));
            }
            if c == 39 and self._starts_at("'''", self.pos) {
                end = self.pos;
                break;
            }
            self.pos += 1;
        }
        scan: int = start;
        while scan < end {
            c2: int = ord(self.src[scan]);
            if _is_illegal_ml_basic(c2) {
                self._err("Found invalid character " + _char_repr(c2), scan);
            }
            scan += 1;
        }
        self.pos = end + 3;
        return self.src[start:end];
    }

    def _parse_multiline_str(literal: bool) -> str {
        self.pos += 3;
        if self._starts_at("\n", self.pos) {
            self.pos += 1;
        }
        result: str = "";
        if literal {
            result = self._scan_ml_literal();
        } else {
            result = self._parse_basic_str(True);
        }
        delim: str = "'";
        if not literal {
            delim = "\"";
        }
        if not self._starts_at(delim, self.pos) {
            return result;
        }
        self.pos += 1;
        if not self._starts_at(delim, self.pos) {
            return result + delim;
        }
        self.pos += 1;
        return result + delim + delim;
    }

    def _parse_basic_str(multiline: bool) -> str {
        out: str = "";
        start_pos: int = self.pos;
        while True {
            ch: int = self._cc(self.pos);
            if ch == -1 {
                self._err("Unterminated string", self.pos);
            }
            if ch == 34 {
                if not multiline {
                    s: str = self.src[start_pos:self.pos];
                    self.pos += 1;
                    return out + s;
                }
                if self._starts_at("\"\"\"", self.pos) {
                    s2: str = self.src[start_pos:self.pos];
                    self.pos += 3;
                    return out + s2;
                }
                self.pos += 1;
                continue;
            }
            if ch == 92 {
                out += self.src[start_pos:self.pos];
                esc: str = self._parse_escape(multiline);
                out += esc;
                start_pos = self.pos;
                continue;
            }
            if multiline {
                if _is_illegal_ml_basic(ch) {
                    self._err("Illegal character " + _char_repr(ch), self.pos);
                }
            } else {
                if _is_illegal_basic(ch) {
                    self._err("Illegal character " + _char_repr(ch), self.pos);
                }
            }
            self.pos += 1;
        }
        return "";
    }

    def _parse_escape(multiline: bool) -> str {
        e0: int = self._cc(self.pos + 1);
        self.pos += 2;
        if multiline {
            if e0 == 32 or e0 == 9 or e0 == 10 {
                if e0 != 10 {
                    self.pos = self._skip_ws(self.pos);
                    if self.pos >= len(self.src) {
                        return "";
                    }
                    if self.src[self.pos] != "\n" {
                        self._err("Unescaped '\\' in a string", self.pos);
                    }
                    self.pos += 1;
                }
                self.pos = self._skip_ws_nl(self.pos);
                return "";
            }
        }
        if e0 == 117 {
            return self._parse_hex_char(4);
        }
        if e0 == 85 {
            return self._parse_hex_char(8);
        }
        if e0 == 98 {
            return chr(8);
        }
        if e0 == 116 {
            return "\t";
        }
        if e0 == 110 {
            return "\n";
        }
        if e0 == 102 {
            return chr(12);
        }
        if e0 == 114 {
            return "\r";
        }
        if e0 == 34 {
            return "\"";
        }
        if e0 == 92 {
            return "\\";
        }
        self._err("Unescaped '\\' in a string", self.pos);
        return "";
    }

    def _parse_hex_char(n: int) -> str {
        v: int = 0;
        cnt: int = 0;
        while cnt < n {
            c: int = self._cc(self.pos + cnt);
            if not _is_hexdig(c) {
                self._err("Invalid hex value", self.pos);
            }
            v = v * 16 + _hexval(c);
            cnt += 1;
        }
        self.pos += n;
        if v > 1114111 or (v >= 55296 and v <= 57343) {
            self._err("Escaped character is not a Unicode scalar value", self.pos);
        }
        return chr(v);
    }

    def _match_time_tail(p: int, with_offset: bool) -> int {
        n: int = len(self.src);
        i: int = p;
        if i + 8 > n {
            return -1;
        }
        h0: int = self._cc(i);
        h1: int = self._cc(i + 1);
        if h0 == 48 or h0 == 49 {
            if not _is_dig(h1) {
                return -1;
            }
        } elif h0 == 50 {
            if h1 < 48 or h1 > 51 {
                return -1;
            }
        } else {
            return -1;
        }
        if self._cc(i + 2) != 58 {
            return -1;
        }
        m0: int = self._cc(i + 3);
        if m0 < 48 or m0 > 53 {
            return -1;
        }
        if not _is_dig(self._cc(i + 4)) {
            return -1;
        }
        if self._cc(i + 5) != 58 {
            return -1;
        }
        s0: int = self._cc(i + 6);
        if s0 < 48 or s0 > 53 {
            return -1;
        }
        if not _is_dig(self._cc(i + 7)) {
            return -1;
        }
        i += 8;
        if self._cc(i) == 46 {
            if _is_dig(self._cc(i + 1)) {
                i += 1;
                while _is_dig(self._cc(i)) {
                    i += 1;
                }
            }
        }
        if not with_offset {
            return i;
        }
        oc: int = self._cc(i);
        if oc == 90 or oc == 122 {
            return i + 1;
        }
        if oc == 43 or oc == 45 {
            if i + 6 <= n {
                oh0: int = self._cc(i + 1);
                oh1: int = self._cc(i + 2);
                ok: bool = False;
                if oh0 == 48 or oh0 == 49 {
                    ok = _is_dig(oh1);
                } elif oh0 == 50 {
                    ok = oh1 >= 48 and oh1 <= 51;
                }
                if ok {
                    if self._cc(i + 3) == 58 {
                        om0: int = self._cc(i + 4);
                        if om0 >= 48 and om0 <= 53 and _is_dig(self._cc(i + 5)) {
                            return i + 6;
                        }
                    }
                }
            }
        }
        return i;
    }

    def _match_datetime(p: int) -> int {
        n: int = len(self.src);
        i: int = p;
        if i + 10 > n {
            return -1;
        }
        if not _is_dig(self._cc(i))
            or not _is_dig(self._cc(i + 1))
            or not _is_dig(self._cc(i + 2))
            or not _is_dig(self._cc(i + 3)) {
            return -1;
        }
        if self._cc(i + 4) != 45 {
            return -1;
        }
        m0: int = self._cc(i + 5);
        m1: int = self._cc(i + 6);
        if m0 == 48 {
            if m1 < 49 or m1 > 57 {
                return -1;
            }
        } elif m0 == 49 {
            if m1 < 48 or m1 > 50 {
                return -1;
            }
        } else {
            return -1;
        }
        if self._cc(i + 7) != 45 {
            return -1;
        }
        d0: int = self._cc(i + 8);
        d1: int = self._cc(i + 9);
        if d0 == 48 {
            if d1 < 49 or d1 > 57 {
                return -1;
            }
        } elif d0 == 49 or d0 == 50 {
            if not _is_dig(d1) {
                return -1;
            }
        } elif d0 == 51 {
            if d1 != 48 and d1 != 49 {
                return -1;
            }
        } else {
            return -1;
        }
        i += 10;
        sep: int = self._cc(i);
        if sep == 84 or sep == 116 or sep == 32 {
            t_end: int = self._match_time_tail(i + 1, True);
            if t_end != -1 {
                return t_end;
            }
        }
        return i;
    }

    def _match_localtime(p: int) -> int {
        if self._cc(p + 2) != 58 {
            return -1;
        }
        return self._match_time_tail(p, False);
    }

    def _match_digits(j: int) -> int {
        n: int = len(self.src);
        while True {
            if j < n and _is_dig(self._cc(j)) {
                j += 1;
            } elif j + 1 < n and self._cc(j) == 95 and _is_dig(self._cc(j + 1)) {
                j += 2;
            } else {
                break;
            }
        }
        return j;
    }

    def _match_radix_digits(j: int, kind: int) -> int {
        n: int = len(self.src);
        if _rad_val(self._cc(j), kind) == -1 {
            return -1;
        }
        j += 1;
        while True {
            if _rad_val(self._cc(j), kind) != -1 {
                j += 1;
            } elif j + 1 < n
                and self._cc(j) == 95
                and _rad_val(self._cc(j + 1), kind) != -1 {
                j += 2;
            } else {
                break;
            }
        }
        return j;
    }

    def _match_dec_float(start: int, j: int) -> int {
        n: int = len(self.src);
        if j < n and self._cc(j) == 46 {
            if j + 1 < n and _is_dig(self._cc(j + 1)) {
                j = self._match_digits(j + 2);
            }
        }
        if j < n {
            ce: int = self._cc(j);
            if ce == 101 or ce == 69 {
                k: int = j + 1;
                if k < n {
                    cs: int = self._cc(k);
                    if cs == 43 or cs == 45 {
                        k += 1;
                    }
                    if k < n and _is_dig(self._cc(k)) {
                        j = self._match_digits(k + 1);
                    }
                }
            }
        }
        return j;
    }

    def _match_number(p: int) -> int {
        n: int = len(self.src);
        c0: int = self._cc(p);
        if c0 == 48 {
            if p + 1 < n {
                c1: int = self._cc(p + 1);
                if c1 == 120 or c1 == 98 or c1 == 111 {
                    r: int = self._match_radix_digits(p + 2, c1);
                    if r != -1 {
                        return r;
                    }
                }
                return self._match_dec_float(p, p + 1);
            }
        }
        if c0 == 43 or c0 == 45 {
            if p + 1 >= n {
                return -1;
            }
            c1b: int = self._cc(p + 1);
            if c1b == 48 {
                return self._match_dec_float(p, p + 2);
            }
            if c1b >= 49 and c1b <= 57 {
                j: int = self._match_digits(p + 2);
                return self._match_dec_float(p, j);
            }
            return -1;
        }
        if c0 >= 49 and c0 <= 57 {
            j2: int = self._match_digits(p + 1);
            return self._match_dec_float(p, j2);
        }
        return -1;
    }

    def _build_datetime(start: int, end: int) -> any {
        year: int = _dig4(self.src, start);
        month: int = _dig2(self.src, start + 5);
        day: int = _dig2(self.src, start + 8);
        if end - start == 10 {
            if not _day_valid(year, month, day) {
                self._err("Invalid date or datetime", start);
            }
            return _TDate(year=year, month=month, day=day);
        }
        hour: int = _dig2(self.src, start + 11);
        minute: int = _dig2(self.src, start + 14);
        second: int = _dig2(self.src, start + 17);
        micros: int = 0;
        i: int = start + 19;
        if i < end and self.src[i] == "." {
            i += 1;
            mult: int = 100000;
            while i < end and _is_dig(ord(self.src[i])) {
                if mult > 0 {
                    micros += (ord(self.src[i]) - 48) * mult;
                    mult //= 10;
                }
                i += 1;
            }
        }
        has_off: bool = False;
        omin: int = 0;
        if i < end {
            oc: int = ord(self.src[i]);
            if oc == 90 or oc == 122 {
                has_off = True;
            } elif oc == 43 or oc == 45 {
                sign: int = 1;
                if oc == 45 {
                    sign = -1;
                }
                oh: int = _dig2(self.src, i + 1);
                om: int = _dig2(self.src, i + 4);
                omin = sign * (oh * 60 + om);
                has_off = True;
            }
        }
        if not _day_valid(year, month, day) {
            self._err("Invalid date or datetime", start);
        }
        return _TDatetime(
            year=year,
            month=month,
            day=day,
            hour=hour,
            minute=minute,
            second=second,
            microsecond=micros,
            offset_minutes=omin,
            has_offset=has_off
        );
    }

    def _build_localtime(start: int, end: int) -> any {
        hour: int = _dig2(self.src, start);
        minute: int = _dig2(self.src, start + 3);
        second: int = _dig2(self.src, start + 6);
        micros: int = 0;
        i: int = start + 8;
        if i < end and self.src[i] == "." {
            i += 1;
            mult: int = 100000;
            while i < end and _is_dig(ord(self.src[i])) {
                if mult > 0 {
                    micros += (ord(self.src[i]) - 48) * mult;
                    mult //= 10;
                }
                i += 1;
            }
        }
        return _TTime(hour=hour, minute=minute, second=second, microsecond=micros);
    }

    def _build_number(start: int, end: int) -> any {
        c0: int = ord(self.src[start]);
        if c0 == 48 and end - start >= 2 {
            kind: int = ord(self.src[start + 1]);
            if kind == 120 or kind == 98 or kind == 111 {
                radix: int = 16;
                if kind == 98 {
                    radix = 2;
                }
                if kind == 111 {
                    radix = 8;
                }
                v: int = 0;
                i: int = start + 2;
                while i < end {
                    ch: int = ord(self.src[i]);
                    if ch != 95 {
                        d: int = _rad_val(ch, kind);
                        lim: int = (_I64_MAX - d) // radix;
                        if v > lim {
                            raise OverflowError(
                                "TOML integer exceeds the 64-bit signed range"
                            );
                        }
                        v = v * radix + d;
                    }
                    i += 1;
                }
                return v;
            }
        }
        i2: int = start;
        neg: bool = False;
        if c0 == 43 {
            i2 = start + 1;
        } elif c0 == 45 {
            neg = True;
            i2 = start + 1;
        }
        isf: bool = False;
        k: int = i2;
        while k < end {
            ck: int = ord(self.src[k]);
            if ck == 46 or ck == 101 or ck == 69 {
                isf = True;
                break;
            }
            k += 1;
        }
        if isf {
            clean: str = _strip_underscore(self.src, start, end);
            return float(clean);
        }
        acc: int = 0;
        k2: int = i2;
        while k2 < end {
            ch2: int = ord(self.src[k2]);
            if ch2 != 95 {
                d2: int = ch2 - 48;
                if acc > _DEC_OVF {
                    raise OverflowError("TOML integer exceeds the 64-bit signed range");
                }
                if acc == _DEC_OVF {
                    if neg {
                        if d2 > 8 {
                            raise OverflowError(
                                "TOML integer exceeds the 64-bit signed range"
                            );
                        }
                    } else {
                        if d2 > 7 {
                            raise OverflowError(
                                "TOML integer exceeds the 64-bit signed range"
                            );
                        }
                    }
                }
                acc = acc * 10 + d2;
            }
            k2 += 1;
        }
        if neg {
            return -acc;
        }
        return acc;
    }
}


def _is_dig(c: int) -> bool {
    return c >= 48 and c <= 57;
}


def _is_bare(c: int) -> bool {
    return (c >= 97 and c <= 122)
        or (c >= 65 and c <= 90)
        or (c >= 48 and c <= 57)
        or c == 45
        or c == 95;
}


def _is_key_init(c: int) -> bool {
    return _is_bare(c) or c == 34 or c == 39;
}


def _is_hexdig(c: int) -> bool {
    return (c >= 48 and c <= 57) or (c >= 97 and c <= 102) or (c >= 65 and c <= 70);
}


def _hexval(c: int) -> int {
    if c >= 97 {
        return c - 87;
    }
    if c >= 65 {
        return c - 55;
    }
    return c - 48;
}


def _rad_val(c: int, kind: int) -> int {
    if kind == 120 {
        if _is_hexdig(c) {
            return _hexval(c);
        }
        return -1;
    }
    if kind == 98 {
        if c == 48 or c == 49 {
            return c - 48;
        }
        return -1;
    }
    if c >= 48 and c <= 55 {
        return c - 48;
    }
    return -1;
}


def _is_illegal_basic(c: int) -> bool {
    return (c < 32 and c != 9) or c == 127;
}


def _is_illegal_ml_basic(c: int) -> bool {
    return (c < 32 and c != 9 and c != 10) or c == 127;
}


def _dig2(s: str, i: int) -> int {
    return (ord(s[i]) - 48) * 10 + (ord(s[i + 1]) - 48);
}


def _dig4(s: str, i: int) -> int {
    return (ord(s[i]) - 48) * 1000
        + (ord(s[i + 1]) - 48) * 100
        + (ord(s[i + 2]) - 48) * 10
        + (ord(s[i + 3]) - 48);
}


def _day_valid(year: int, month: int, day: int) -> bool {
    if year == 0 {
        return False;
    }
    dim: int = 31;
    if month == 4 or month == 6 or month == 9 or month == 11 {
        dim = 30;
    } elif month == 2 {
        dim = 28;
        if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) {
            dim = 29;
        }
    }
    return day <= dim;
}


def _pad2(n: int) -> str {
    if n < 10 {
        return "0" + str(n);
    }
    return str(n);
}


def _pad4(n: int) -> str {
    if n < 10 {
        return "000" + str(n);
    }
    if n < 100 {
        return "00" + str(n);
    }
    if n < 1000 {
        return "0" + str(n);
    }
    return str(n);
}


def _pad6(n: int) -> str {
    if n < 10 {
        return "00000" + str(n);
    }
    if n < 100 {
        return "0000" + str(n);
    }
    if n < 1000 {
        return "000" + str(n);
    }
    if n < 10000 {
        return "00" + str(n);
    }
    if n < 100000 {
        return "0" + str(n);
    }
    return str(n);
}


def _offset_str(offset_min: int) -> str {
    o: int = offset_min;
    sign: str = "+";
    if o < 0 {
        sign = "-";
        o = -o;
    }
    return sign + _pad2(o // 60) + ":" + _pad2(o % 60);
}


def _char_repr(ch: int) -> str {
    return _str_repr(chr(ch));
}


def _str_repr(s: str) -> str {
    out: str = "'";
    n: int = len(s);
    i: int = 0;
    while i < n {
        ch: int = ord(s[i]);
        if ch == 92 {
            out += "\\\\";
        } elif ch == 39 {
            out += "\\'";
        } elif ch == 10 {
            out += "\\n";
        } elif ch == 13 {
            out += "\\r";
        } elif ch == 9 {
            out += "\\t";
        } elif ch < 32 or ch == 127 {
            out += "\\x" + _hex2(ch);
        } else {
            out += s[i];
        }
        i += 1;
    }
    return out + "'";
}


def _hex2(v: int) -> str {
    hi: int = v // 16;
    lo: int = v % 16;
    return _hex1(hi) + _hex1(lo);
}


def _hex1(v: int) -> str {
    if v < 10 {
        return chr(48 + v);
    }
    return chr(87 + v);
}


def _fmt_key(parts: list[str]) -> str {
    n: int = len(parts);
    if n == 0 {
        return "()";
    }
    if n == 1 {
        return "(" + _str_repr(parts[0]) + ",)";
    }
    out: str = "(";
    i: int = 0;
    while i < n {
        if i > 0 {
            out += ", ";
        }
        out += _str_repr(parts[i]);
        i += 1;
    }
    return out + ")";
}


def _all_but_last(parts: list[str]) -> list[str] {
    out: list[str] = [];
    i: int = 0;
    n: int = len(parts) - 1;
    while i < n {
        out.append(parts[i]);
        i += 1;
    }
    return out;
}


def _prefix(parts: list[str], n: int) -> list[str] {
    out: list[str] = [];
    i: int = 0;
    while i < n {
        out.append(parts[i]);
        i += 1;
    }
    return out;
}


def _concat(a: list[str], b: list[str]) -> list[str] {
    out: list[str] = [];
    i: int = 0;
    while i < len(a) {
        out.append(a[i]);
        i += 1;
    }
    i = 0;
    while i < len(b) {
        out.append(b[i]);
        i += 1;
    }
    return out;
}


def _strip_underscore(s: str, start: int, end: int) -> str {
    out: str = "";
    i: int = start;
    while i < end {
        if s[i] != "_" {
            out += s[i];
        }
        i += 1;
    }
    return out;
}
