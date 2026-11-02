impl _hexd(v: int) -> str {
    if v < 10 {
        return chr(48 + v);
    }
    return chr(87 + v);
}


impl _hex2(v: int) -> str {
    hi: int = v // 16;
    lo: int = v % 16;
    return _hexd(hi) + _hexd(lo);
}


impl _pad2(n: int) -> str {
    s: str = str(n);
    if n >= 10 {
        return s;
    }
    return " " + s;
}


impl _repr_str(s: str) -> str {
    has_s: bool = s.find("'") >= 0;
    has_d: bool = s.find("\"") >= 0;
    q: str = "'";
    if has_s and not has_d {
        q = "\"";
    }
    out: str = q;
    i: int = 0;
    n: int = len(s);
    while i < n {
        ch: str = s[i];
        code: int = ord(ch);
        if ch == "\\" {
            out += "\\\\";
        } elif ch == q {
            out += "\\";
            out += q;
        } elif code == 10 {
            out += "\\n";
        } elif code == 13 {
            out += "\\r";
        } elif code == 9 {
            out += "\\t";
        } elif code < 32 or code == 127 {
            out += "\\x" + _hex2(code);
        } else {
            out += ch;
        }
        i += 1;
    }
    out += q;
    return out;
}


impl _is_ws_start(s: str, at: int) -> bool {
    c: int = ord(s[at]);
    if c == 9
        or c == 10
        or c == 11
        or c == 12
        or c == 13
        or c == 32
        or (c >= 28 and c <= 32) {
        return True;
    }
    if c == 160
        or c == 5760
        or (c >= 8192 and c <= 8202)
        or c == 8232
        or c == 8233
        or c == 8239
        or c == 8287
        or c == 12288 {
        return True;
    }
    if c == 194 and at + 1 < len(s) and ord(s[at + 1]) == 160 {
        return True;
    }
    if c == 225
        and at + 2 < len(s)
        and ord(s[at + 1]) == 154
        and ord(s[at + 2]) == 128 {
        return True;
    }
    if c == 226 and at + 2 < len(s) and ord(s[at + 1]) == 128 {
        c2: int = ord(s[at + 2]);
        return (c2 >= 128 and c2 <= 138) or c2 == 160 or c2 == 161 or c2 == 175;
    }
    if c == 226
        and at + 2 < len(s)
        and ord(s[at + 1]) == 129
        and ord(s[at + 2]) == 159 {
        return True;
    }
    if c == 227
        and at + 2 < len(s)
        and ord(s[at + 1]) == 128
        and ord(s[at + 2]) == 128 {
        return True;
    }
    return False;
}


impl _is_ws(s: str, at: int) -> bool {
    start: int = at;
    while start >= 0 and at - start <= 2 {
        if _is_ws_start(s, start) {
            width: int = 1;
            c: int = ord(s[start]);
            if c == 194 {
                width = 2;
            } elif c == 225 or c == 226 or c == 227 {
                width = 3;
            }
            if start + width - 1 == at {
                return True;
            }
        }
        start -= 1;
    }
    return False;
}


impl _starts_at(s: str, sub: str, at: int) -> bool {
    m: int = len(sub);
    if at + m > len(s) {
        return False;
    }
    i: int = 0;
    while i < m {
        if s[at + i] != sub[i] {
            return False;
        }
        i += 1;
    }
    return True;
}


impl _find_from(s: str, sub: str, start: int) -> int {
    n: int = len(s);
    m: int = len(sub);
    i: int = start;
    while i <= n - m {
        if _starts_at(s, sub, i) {
            return i;
        }
        i += 1;
    }
    return -1;
}


impl _prefix_chars(s: str, end: int) -> str {
    out: str = "";
    i: int = 0;
    while i < end {
        c: int = ord(s[i]);
        cp: int = c;
        width: int = 1;
        if c >= 194 and c <= 223 {
            width = 2;
            cp = (c - 192) * 64 + ord(s[i + 1]) - 128;
        } elif c >= 224 and c <= 239 {
            width = 3;
            cp = (c - 224) * 4096 + (ord(s[i + 1]) - 128) * 64 + ord(s[i + 2]) - 128;
        } elif c >= 240 and c <= 244 {
            width = 4;
            cp = (c - 240) * 262144
                + (ord(s[i + 1]) - 128) * 4096
                + (ord(s[i + 2]) - 128) * 64
                + ord(s[i + 3])
                - 128;
        }
        out += chr(cp);
        i += width;
    }
    return out;
}


impl _lstrip(s: str) -> str {
    n: int = len(s);
    start: int = 0;
    while start < n {
        width: int = 1;
        c: int = ord(s[start]);
        if c == 194 {
            width = 2;
        } elif c == 225 or c == 226 or c == 227 {
            width = 3;
        }
        if not _is_ws(s, start + width - 1) {
            break;
        }
        start += width;
    }
    return s[start:n];
}


impl _rstrip(s: str) -> str {
    n: int = len(s);
    e: int = n;
    while e > 0 {
        if _is_ws(s, e - 1) {
            e -= 1;
        } else {
            break;
        }
    }
    return _prefix_chars(s, e);
}


impl _strip(s: str) -> str {
    return _rstrip(_lstrip(s));
}


impl _join_nl(parts: list[str]) -> str {
    if len(parts) == 0 {
        return "";
    }
    out: str = parts[0];
    i: int = 1;
    n: int = len(parts);
    while i < n {
        out += "\n";
        out += parts[i];
        i += 1;
    }
    return _rstrip(out);
}


impl _cat(parts: list[str]) -> str {
    out: str = "";
    i: int = 0;
    n: int = len(parts);
    while i < n {
        out += parts[i];
        i += 1;
    }
    return out;
}


impl _remove_all(s: str, sub: str) -> str {
    out: str = "";
    i: int = 0;
    n: int = len(s);
    m: int = len(sub);
    while i < n {
        if i + m <= n and _starts_at(s, sub, i) {
            i += m;
        } else {
            out += s[i];
            i += 1;
        }
    }
    return out;
}


impl _match_keyref(s: str, i: int) -> int {
    if not _starts_at(s, "%(", i) {
        return 0;
    }
    rp: int = _find_from(s, ")", i + 2);
    if rp < i + 3 {
        return 0;
    }
    if rp + 1 >= len(s) or s[rp + 1] != "s" {
        return 0;
    }
    return rp + 2 - i;
}


impl _strip_refs(s: str) -> str {
    out: str = "";
    i: int = 0;
    n: int = len(s);
    while i < n {
        m: int = _match_keyref(s, i);
        if m > 0 {
            i += m;
        } else {
            out += s[i];
            i += 1;
        }
    }
    return out;
}


impl _split_keepends(s: str) -> list[str] {
    parts: list[str] = [];
    start: int = 0;
    i: int = 0;
    n: int = len(s);
    while i < n {
        if s[i] == "\n" {
            parts.append(s[start:i + 1]);
            start = i + 1;
        }
        i += 1;
    }
    if start < n {
        parts.append(s[start:n]);
    }
    return parts;
}


impl _dict_without(d: dict[str, str], key: str) -> dict[str, str] {
    out: dict[str, str] = {};
    for k in d {
        if k != key {
            out[k] = d[k];
        }
    }
    return out;
}


impl _sect_without(
    d: dict[str, dict[str, str]], key: str
) -> dict[str, dict[str, str]] {
    out: dict[str, dict[str, str]] = {};
    for k in d {
        if k != key {
            out[k] = d[k];
        }
    }
    return out;
}


impl NoSectionError.init(section: str) {
    self.section = section;
}


impl NoSectionError.__str__ -> str {
    return "No section: " + _repr_str(self.section);
}


impl DuplicateSectionError.init(
    section: str, source: str = "", lineno: int = 0, has_source: bool = False
) {
    self.section = section;
    self.source = source;
    self.lineno = lineno;
    self._has_source = has_source;
}


impl DuplicateSectionError.__str__ -> str {
    if not self._has_source {
        return "Section " + _repr_str(self.section) + " already exists";
    }
    out: str = "While reading from " + _repr_str(self.source);
    if self.lineno > 0 {
        out += " [line " + _pad2(self.lineno) + "]";
    }
    out += ": section " + _repr_str(self.section) + " already exists";
    return out;
}


impl DuplicateOptionError.init(
    section: str,
    option: str,
    source: str = "",
    lineno: int = 0,
    has_source: bool = False
) {
    self.section = section;
    self.option = option;
    self.source = source;
    self.lineno = lineno;
    self._has_source = has_source;
}


impl DuplicateOptionError.__str__ -> str {
    if not self._has_source {
        return "Option "
            + _repr_str(self.option)
            + " in section "
            + _repr_str(self.section)
            + " already exists";
    }
    out: str = "While reading from " + _repr_str(self.source);
    if self.lineno > 0 {
        out += " [line " + _pad2(self.lineno) + "]";
    }
    out += ": option "
        + _repr_str(self.option)
        + " in section "
        + _repr_str(self.section)
        + " already exists";
    return out;
}


impl NoOptionError.init(option: str, section: str) {
    self.option = option;
    self.section = section;
}


impl NoOptionError.__str__ -> str {
    return "No option "
        + _repr_str(self.option)
        + " in section: "
        + _repr_str(self.section);
}


impl InterpolationMissingOptionError.init(
    option: str, section: str, rawval: str, reference: str
) {
    self.option = option;
    self.section = section;
    self.rawval = rawval;
    self.reference = reference;
}


impl InterpolationMissingOptionError.__str__ -> str {
    return "Bad value substitution: option "
        + _repr_str(self.option)
        + " in section "
        + _repr_str(self.section)
        + " contains an interpolation key "
        + _repr_str(self.reference)
        + " which is not a valid option name. Raw value: "
        + _repr_str(self.rawval);
}


impl InterpolationSyntaxError.init(option: str, section: str, msg: str) {
    self.option = option;
    self.section = section;
    self.msg = msg;
}


impl InterpolationSyntaxError.__str__ -> str {
    return self.msg;
}


impl InterpolationDepthError.init(option: str, section: str, rawval: str) {
    self.option = option;
    self.section = section;
    self.rawval = rawval;
}


impl InterpolationDepthError.__str__ -> str {
    return "Recursion limit exceeded in value substitution: option "
        + _repr_str(self.option)
        + " in section "
        + _repr_str(self.section)
        + " contains an interpolation key which cannot be substituted in "
        + str(MAX_INTERPOLATION_DEPTH)
        + " steps. Raw value: "
        + _repr_str(self.rawval);
}


impl ParsingError.init(source: str) {
    self.source = source;
    self.msg = "Source contains parsing errors: " + _repr_str(source);
}


impl ParsingError.append(lineno: int, line: str) {
    self.n_errors += 1;
    self.msg += "\n\t[line " + _pad2(lineno) + "]: " + _repr_str(line);
}


impl ParsingError.__str__ -> str {
    return self.msg;
}


impl MissingSectionHeaderError.init(source: str, lineno: int, line: str) {
    self.source = source;
    self.lineno = lineno;
    self.line = line;
}


impl MissingSectionHeaderError.__str__ -> str {
    return "File contains no section headers.\nfile: "
        + _repr_str(self.source)
        + ", line: "
        + str(self.lineno)
        + "\n"
        + _repr_str(self.line);
}


impl ConfigParser.init(
    delimiters: list[str] | None = None,
    comment_prefixes: list[str] | None = None,
    strict: bool = True,
    empty_lines_in_values: bool = True,
    default_section: str = "DEFAULT",
    interpolation: bool = True,
    inline_comment_prefixes: list[str] | None = None,
) {
    if delimiters is None {
        self.delimiters = ["=", ":"];
    } else {
        self.delimiters = delimiters;
    }
    if comment_prefixes is None {
        self.comment_prefixes = ["#", ";"];
    } else {
        self.comment_prefixes = comment_prefixes;
    }
    if inline_comment_prefixes is None {
        self.inline_comment_prefixes = [];
    } else {
        self.inline_comment_prefixes = inline_comment_prefixes;
    }
    self.strict = strict;
    self.empty_lines_in_values = empty_lines_in_values;
    self.default_section = default_section;
    self.interpolation = interpolation;
    self._sections = {};
    self._defaults = {};
}


impl ConfigParser.defaults -> dict[str, str] {
    return self._defaults;
}


impl ConfigParser.sections -> list[str] {
    out: list[str] = [];
    for s in self._sections {
        out.append(s);
    }
    return out;
}


impl ConfigParser.has_section(section: str) -> bool {
    r: bool = section in self._sections;
    return r;
}


impl ConfigParser.add_section(section: str) {
    if section == self.default_section {
        raise ValueError("Invalid section name: " + _repr_str(section));
    }
    if section in self._sections {
        raise DuplicateSectionError(section);
    }
    self._sections[section] = {};
}


impl ConfigParser.options(section: str) -> list[str] {
    if section in self._sections {
        sd: dict[str, str] = self._sections[section];
        out: list[str] = [];
        for k in sd {
            out.append(k);
        }
        for dk in self._defaults {
            seen: bool = dk in sd;
            if not seen {
                out.append(dk);
            }
        }
        return out;
    }
    raise NoSectionError(section);
}


impl ConfigParser.has_option(section: str, option: str) -> bool {
    opt: str = option.lower();
    if section == "" or section == self.default_section {
        r: bool = opt in self._defaults;
        return r;
    }
    if section in self._sections {
        sd: dict[str, str] = self._sections[section];
        if opt in sd {
            return True;
        }
        r2: bool = opt in self._defaults;
        return r2;
    }
    return False;
}


impl ConfigParser.set(section: str, option: str, value: str) {
    if value != "" and self.interpolation {
        value = self._before_set(value);
    }
    opt: str = option.lower();
    if section == "" or section == self.default_section {
        self._defaults[opt] = value;
        return;
    }
    if section in self._sections {
        sd: dict[str, str] = self._sections[section];
        sd[opt] = value;
        return;
    }
    raise NoSectionError(section);
}


impl ConfigParser.remove_option(section: str, option: str) -> bool {
    opt: str = option.lower();
    if section == "" or section == self.default_section {
        if opt in self._defaults {
            del self._defaults[opt];
            return True;
        }
        return False;
    }
    if section in self._sections {
        sd: dict[str, str] = self._sections[section];
        if opt in sd {
            self._sections[section] = _dict_without(sd, opt);
            return True;
        }
        return False;
    }
    raise NoSectionError(section);
}


impl ConfigParser.remove_section(section: str) -> bool {
    if section in self._sections {
        self._sections = _sect_without(self._sections, section);
        return True;
    }
    return False;
}


impl ConfigParser.get(
    section: str, option: str, raw: bool = False, fallback: any = _NO_FALLBACK
) -> any {
    in_sect: bool = section in self._sections;
    if not in_sect and section != self.default_section {
        if isinstance(fallback, _NoFallback) {
            raise NoSectionError(section);
        }
        return fallback;
    }
    mvals: dict[str, str] = {};
    for k in self._defaults {
        mvals[k] = self._defaults[k];
    }
    if in_sect {
        sd: dict[str, str] = self._sections[section];
        for k2 in sd {
            mvals[k2] = sd[k2];
        }
    }
    opt: str = option.lower();
    if opt in mvals {
        value: str = mvals[opt];
        if raw {
            return value;
        }
        if self.interpolation {
            acc: list[str] = [];
            self._interp_some(opt, section, value, mvals, 1, acc, value);
            return _cat(acc);
        }
        return value;
    }
    if isinstance(fallback, _NoFallback) {
        raise NoOptionError(opt, section);
    }
    return fallback;
}


impl ConfigParser.getint(
    section: str, option: str, raw: bool = False, fallback: any = _NO_FALLBACK
) -> any {
    try {
        v: str = self.get(section, option, raw, _NO_FALLBACK);
    } except (NoSectionError, NoOptionError) {
        if isinstance(fallback, _NoFallback) {
            raise;
        }
        return fallback;
    }
    return int(v);
}


impl ConfigParser.getfloat(
    section: str, option: str, raw: bool = False, fallback: any = _NO_FALLBACK
) -> any {
    try {
        v: str = self.get(section, option, raw, _NO_FALLBACK);
    } except (NoSectionError, NoOptionError) {
        if isinstance(fallback, _NoFallback) {
            raise;
        }
        return fallback;
    }
    return float(v);
}


impl ConfigParser.getboolean(
    section: str, option: str, raw: bool = False, fallback: any = _NO_FALLBACK
) -> any {
    try {
        v: str = self.get(section, option, raw, _NO_FALLBACK);
    } except (NoSectionError, NoOptionError) {
        if isinstance(fallback, _NoFallback) {
            raise;
        }
        return fallback;
    }
    vl: str = v.lower();
    if vl == "1" or vl == "yes" or vl == "true" or vl == "on" {
        return True;
    }
    if vl == "0" or vl == "no" or vl == "false" or vl == "off" {
        return False;
    }
    raise ValueError("Not a boolean: " + v);
}


impl ConfigParser.items(section: str, raw: bool = False) -> list[tuple[(str, str)]] {
    d: dict[str, str] = {};
    for k in self._defaults {
        d[k] = self._defaults[k];
    }
    if section in self._sections {
        sd: dict[str, str] = self._sections[section];
        for k2 in sd {
            d[k2] = sd[k2];
        }
    } elif section != self.default_section {
        raise NoSectionError(section);
    }
    out: list[tuple[(str, str)]] = [];
    for k3 in d {
        v: str = d[k3];
        if not raw and self.interpolation {
            acc: list[str] = [];
            self._interp_some(k3, section, v, d, 1, acc, v);
            v = _cat(acc);
        }
        row: tuple[(str, str)] = (k3, v);
        out.append(row);
    }
    return out;
}


impl ConfigParser.read_string(s: str) {
    self._read_lines(_split_keepends(s), "<string>");
}


impl ConfigParser.read_file(lines: list[str]) {
    self._read_lines(lines, "<???>");
}


impl ConfigParser.read_dict(dictionary: dict[str, dict[str, str]]) {
    source: str = "<dict>";
    added_opt: dict[str, bool] = {};
    for section in dictionary {
        keys: dict[str, str] = dictionary[section];
        if section != self.default_section {
            if section not in self._sections {
                self._sections[section] = {};
            }
        }
        for key in keys {
            k: str = key.lower();
            pk: str = section + "\x00" + k;
            seen: bool = pk in added_opt;
            if self.strict and seen {
                raise DuplicateOptionError(section, k, source, 0, True);
            }
            added_opt[pk] = True;
            self.set(section, k, keys[key]);
        }
    }
}


impl ConfigParser.write -> str {
    delim: str = " " + self.delimiters[0] + " ";
    out: str = "";
    if len(self._defaults) > 0 {
        out += self._write_section(self.default_section, self._defaults, delim);
    }
    for s in self._sections {
        out += self._write_section(s, self._sections[s], delim);
    }
    return out;
}


impl ConfigParser._write_section(name: str, opts: dict[str, str], delim: str) -> str {
    out: str = "[" + name + "]\n";
    for k in opts {
        v: str = self._write_value(opts[k]);
        out += k + delim + v + "\n";
    }
    out += "\n";
    return out;
}


impl ConfigParser._write_value(value: str) -> str {
    out: str = "";
    i: int = 0;
    n: int = len(value);
    while i < n {
        c: str = value[i];
        if c == "\r" {
            out += "\n\t";
            if i + 1 < n and value[i + 1] == "\n" {
                i += 1;
            }
        } elif c == "\n" {
            out += "\n\t";
        } else {
            out += c;
        }
        i += 1;
    }
    return out;
}


impl ConfigParser._before_set(value: str) -> str {
    tmp: str = _remove_all(value, "%%");
    tmp2: str = _strip_refs(tmp);
    p: int = tmp2.find("%");
    if p >= 0 {
        raise ValueError(
            "invalid interpolation syntax in "
                + _repr_str(value)
                + " at position "
                + str(p)
        );
    }
    return value;
}


impl ConfigParser._interp_some(
    option: str,
    section: str,
    rawval: str,
    mvals: dict[str, str],
    depth: int,
    acc: list[str],
    topval: str
) {
    if depth > MAX_INTERPOLATION_DEPTH {
        raise InterpolationDepthError(option, section, topval);
    }
    rest: str = rawval;
    while True {
        p: int = rest.find("%");
        if p < 0 {
            acc.append(rest);
            break;
        }
        if p > 0 {
            acc.append(rest[0:p]);
            rest = rest[p:];
        }
        nxt: str = rest[1:2];
        if nxt == "%" {
            acc.append("%");
            rest = rest[2:];
        } elif nxt == "(" {
            mlen: int = _match_keyref(rest, 0);
            if mlen == 0 {
                raise InterpolationSyntaxError(
                    option,
                    section,
                    "bad interpolation variable reference " + _repr_str(rest)
                );
            }
            vcut: str = rest[2:mlen - 2];
            var: str = vcut.lower();
            rest = rest[mlen:];
            if var in mvals {
                v: str = mvals[var];
                if v.find("%") >= 0 {
                    self._interp_some(
                        option, section, v, mvals, depth + 1, acc, topval
                    );
                } else {
                    acc.append(v);
                }
            } else {
                raise InterpolationMissingOptionError(option, section, topval, var);
            }
        } else {
            raise InterpolationSyntaxError(
                option,
                section,
                "'%' must be followed by '%' or '(', found: " + _repr_str(rest)
            );
        }
    }
}


impl ConfigParser._strip_comments(text: str) -> str {
    n: int = len(text);
    i: int = 0;
    while i < n {
        if i == 0 {
            j: int = 0;
            while j < len(self.comment_prefixes) {
                if _starts_at(text, self.comment_prefixes[j], 0) {
                    return "";
                }
                j += 1;
            }
            j2: int = 0;
            while j2 < len(self.inline_comment_prefixes) {
                if _starts_at(text, self.inline_comment_prefixes[j2], 0) {
                    return "";
                }
                j2 += 1;
            }
        } elif _is_ws(text, i - 1) {
            j3: int = 0;
            while j3 < len(self.inline_comment_prefixes) {
                prefix: str = self.inline_comment_prefixes[j3];
                if _starts_at(text, prefix, i) {
                    return _rstrip(_prefix_chars(text, i));
                }
                j3 += 1;
            }
        }
        i += 1;
    }
    return _rstrip(text);
}


impl ConfigParser._sect_header(clean: str) -> str {
    if len(clean) < 3 {
        return "";
    }
    if clean[0] != "[" {
        return "";
    }
    rp: int = clean.rfind("]");
    if rp < 2 {
        return "";
    }
    return clean[1:rp];
}


impl ConfigParser._find_delim(clean: str) -> int {
    best: int = -1;
    i: int = 0;
    while i < len(self.delimiters) {
        p: int = clean.find(self.delimiters[i]);
        if p >= 0 {
            if best < 0 or p < best {
                best = p;
            }
        }
        i += 1;
    }
    return best;
}


impl ConfigParser._delim_len(clean: str, pos: int) -> int {
    i: int = 0;
    while i < len(self.delimiters) {
        if _starts_at(clean, self.delimiters[i], pos) {
            return len(self.delimiters[i]);
        }
        i += 1;
    }
    return 1;
}


impl ConfigParser._read_lines(lines: list[str], source: str) {
    parts_sect: dict[str, dict[str, list[str]]] = {};
    parts_def: dict[str, list[str]] = {};
    elements_sect: dict[str, bool] = {};
    elements_opt: dict[str, dict[str, bool]] = {};
    cur: dict[str, list[str]] = {};
    has_cur: bool = False;
    cur_sectname: str = "";
    optname: str = "";
    has_opt: bool = False;
    indent_level: int = 0;
    pe: ParsingError = ParsingError(source);
    n_errs: int = 0;
    fail_kind: int = 0;
    f_sect: str = "";
    f_opt: str = "";
    f_lineno: int = 0;
    f_line: str = "";
    n: int = len(lines);
    i: int = 0;
    while i < n {
        raw: str = lines[i];
        lineno: int = i + 1;
        i += 1;
        trimmed: str = _strip(raw);
        clean: str = self._strip_comments(trimmed);
        has_comments: bool = trimmed != clean;
        if clean == "" {
            if self.empty_lines_in_values {
                if not has_comments and has_cur and has_opt {
                    pl: list[str] = cur[optname];
                    pl.append("");
                }
            } else {
                indent_level = _INDENT_MAX;
            }
            continue;
        }
        cur_indent: int = 0;
        ci: int = 0;
        while ci < len(raw) {
            if not _is_ws(raw, ci) {
                cur_indent = ci;
                break;
            }
            ci += 1;
        }
        if has_cur and has_opt and cur_indent > indent_level {
            cl: list[str] = cur[optname];
            cl.append(clean);
            continue;
        }
        indent_level = cur_indent;
        sectname: str = self._sect_header(clean);
        if sectname == "" {
            if not has_cur {
                fail_kind = 1;
                f_lineno = lineno;
                f_line = raw;
                break;
            }
            best: int = self._find_delim(clean);
            if best < 0 {
                pe.append(lineno, raw);
                n_errs += 1;
                continue;
            }
            dlen: int = self._delim_len(clean, best);
            on_raw: str = _rstrip(clean[0:best]);
            optname = on_raw.lower();
            if optname == "" {
                pe.append(lineno, raw);
                n_errs += 1;
            }
            sub: dict[str, bool] = {};
            if cur_sectname in elements_opt {
                sub = elements_opt[cur_sectname];
            } else {
                elements_opt[cur_sectname] = sub;
            }
            if self.strict {
                seen: bool = optname in sub;
                if seen {
                    fail_kind = 3;
                    f_sect = cur_sectname;
                    f_opt = optname;
                    f_lineno = lineno;
                    break;
                }
            }
            sub[optname] = True;
            vraw: str = clean[best + dlen:];
            val: str = _strip(vraw);
            cur[optname] = [val];
            has_opt = optname != "";
        } else {
            has_opt = False;
            has_cur = True;
            if sectname in self._sections {
                if self.strict {
                    dup: bool = sectname in elements_sect;
                    if dup {
                        fail_kind = 2;
                        f_sect = sectname;
                        f_lineno = lineno;
                        break;
                    }
                }
                if sectname in parts_sect {
                    cur = parts_sect[sectname];
                } else {
                    rd: dict[str, list[str]] = {};
                    parts_sect[sectname] = rd;
                    cur = rd;
                }
                cur_sectname = sectname;
                elements_sect[sectname] = True;
            } elif sectname == self.default_section {
                cur = parts_def;
                cur_sectname = sectname;
            } else {
                nd: dict[str, list[str]] = {};
                parts_sect[sectname] = nd;
                self._sections[sectname] = {};
                cur = nd;
                cur_sectname = sectname;
                elements_sect[sectname] = True;
            }
        }
    }
    dk: str = "";
    for dk in parts_def {
        self._defaults[dk] = _join_nl(parts_def[dk]);
    }
    for sk in parts_sect {
        tgt: dict[str, str] = self._sections[sk];
        src2: dict[str, list[str]] = parts_sect[sk];
        for ok2 in src2 {
            tgt[ok2] = _join_nl(src2[ok2]);
        }
    }
    if fail_kind == 1 {
        raise MissingSectionHeaderError(source, f_lineno, f_line);
    }
    if fail_kind == 2 {
        raise DuplicateSectionError(f_sect, source, f_lineno, True);
    }
    if fail_kind == 3 {
        raise DuplicateOptionError(f_sect, f_opt, source, f_lineno, True);
    }
    if n_errs > 0 {
        raise pe;
    }
}
