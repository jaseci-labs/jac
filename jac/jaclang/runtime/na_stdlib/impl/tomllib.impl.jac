impl TOMLDecodeError.postinit {
    line: int = 1;
    last_newline: int = -1;
    i: int = 0;
    limit: int = self.pos;
    if limit > len(self.doc) {
        limit = len(self.doc);
    }
    while i < limit {
        if self.doc[i] == "\n" {
            line += 1;
            last_newline = i;
        }
        i += 1;
    }
    self.lineno = line;
    self.colno = self.pos - last_newline;
}

impl TOMLDecodeError.__str__ -> str {
    if self.pos >= len(self.doc) {
        return self.msg + " (at end of document)";
    }
    return self.msg
        + " (at line "
        + str(self.lineno)
        + ", column "
        + str(self.colno)
        + ")";
}

impl loads(s: str) -> dict[str, any] {
    parser = _TomlParser(src=s.replace("\r\n", "\n"));
    return parser.parse();
}

impl load(fp: File) -> dict[str, any] {
    data = fp.read();
    if isinstance(data, bytes) {
        return loads(data.decode("utf-8"));
    }
    return loads(data);
}

impl _join_path(path: str, key: str) -> str {
    if path == "" {
        return key;
    }
    return path + _PATH_SEP + key;
}

impl _is_bare_key_char(c: str) -> bool {
    return ("a" <= c and c <= "z")
        or ("A" <= c and c <= "Z")
        or ("0" <= c and c <= "9")
        or c == "_"
        or c == "-";
}

impl _is_digit(c: str) -> bool {
    return c != "" and "0" <= c and c <= "9";
}

impl _is_hex_digit(c: str) -> bool {
    return _is_digit(c) or ("a" <= c and c <= "f") or ("A" <= c and c <= "F");
}

impl _is_control(c: str, allow_newline: bool) -> bool {
    code = ord(c);
    if c == "\t" {
        return False;
    }
    if c == "\n" {
        return not allow_newline;
    }
    return code < 32 or code == 127;
}

impl _digit_value(c: str) -> int {
    if _is_digit(c) {
        return ord(c) - 48;
    }
    if "a" <= c and c <= "f" {
        return ord(c) - 87;
    }
    return ord(c) - 55;
}

impl _TomlParser.postinit {
    self.n = len(self.src);
    self.current = self.doc;
}

impl _TomlParser.error(message: str) -> TOMLDecodeError {
    return TOMLDecodeError(msg=message, doc=self.src, pos=self.pos);
}

impl _TomlParser.at(offset: int = 0) -> str {
    i = self.pos + offset;
    if i >= self.n {
        return "";
    }
    return self.src[i];
}

impl _TomlParser.starts(text: str) -> bool {
    return self.src.startswith(text, self.pos);
}

impl _TomlParser.eof -> bool {
    return self.pos >= self.n;
}

impl _TomlParser.parse -> dict[str, any] {
    while True {
        self.skip_blank();
        if self.eof() {
            break;
        }
        if self.starts("[[") {
            self.parse_array_table_header();
        } elif self.at() == "[" {
            self.parse_table_header();
        } else {
            self.parse_key_value(self.current, self.current_path);
        }
        self.end_of_line();
    }
    return self.doc;
}

impl _TomlParser.skip_ws {
    while self.pos < self.n {
        c = self.src[self.pos];
        if c != " " and c != "\t" {
            return;
        }
        self.pos += 1;
    }
}

impl _TomlParser.skip_comment {
    if self.at() != "#" {
        return;
    }
    self.pos += 1;
    while self.pos < self.n {
        c = self.src[self.pos];
        if c == "\n" {
            return;
        }
        if _is_control(c, False) {
            raise self.error("Illegal character in comment");
        }
        self.pos += 1;
    }
}

impl _TomlParser.skip_blank {
    while True {
        self.skip_ws();
        self.skip_comment();
        if self.at() != "\n" {
            return;
        }
        self.pos += 1;
    }
}

impl _TomlParser.skip_array_ws {
    self.skip_blank();
}

impl _TomlParser.end_of_line {
    self.skip_ws();
    self.skip_comment();
    if self.eof() {
        return;
    }
    if self.at() != "\n" {
        raise self.error("Expected newline or end of document after a statement");
    }
    self.pos += 1;
}

impl _TomlParser.parse_key -> list[str] {
    keys: list[str] = [self.parse_simple_key()];
    while True {
        self.skip_ws();
        if self.at() != "." {
            return keys;
        }
        self.pos += 1;
        self.skip_ws();
        keys.append(self.parse_simple_key());
    }
}

impl _TomlParser.parse_simple_key -> str {
    c = self.at();
    if c == "\"" {
        return self.parse_basic_string();
    }
    if c == "'" {
        return self.parse_literal_string();
    }
    start = self.pos;
    while self.pos < self.n and _is_bare_key_char(self.src[self.pos]) {
        self.pos += 1;
    }
    if self.pos == start {
        raise self.error("Invalid initial character for a key part");
    }
    return self.src[start:self.pos];
}

impl _TomlParser.close_section {
    for path in self.section_dotted {
        self.closed.add(path);
    }
    self.section_dotted = set();
}

impl _TomlParser.descend_header(keys: list[str]) -> tuple[dict[str, any], str] {
    table = self.doc;
    path = "";
    for key in keys {
        full = _join_path(path, key);
        if key not in table {
            table[key] = {};
            self.implicit.add(full);
        }
        value = table[key];
        if isinstance(value, list) {
            if full not in self.arrays {
                raise self.error("Cannot extend a static array");
            }
            items: list[any] = value;
            last = items[len(items) - 1];
            path = full + _PATH_SEP + "#" + str(len(items) - 1);
            table = last;
            continue;
        }
        if not isinstance(value, dict) {
            raise self.error("Cannot use a value as a table");
        }
        if full in self.frozen {
            raise self.error("Cannot extend an inline table");
        }
        table = value;
        path = full;
    }
    return (table, path);
}

impl _TomlParser.parse_table_header {
    self.pos += 1;
    self.skip_ws();
    keys = self.parse_key();
    if self.at() != "]" {
        raise self.error("Expected ']' at the end of a table declaration");
    }
    self.pos += 1;
    self.close_section();
    (table, path) = self.descend_header(keys[:len(keys) - 1]);
    last = keys[len(keys) - 1];
    full = _join_path(path, last);
    if last in table {
        existing = table[last];
        if not isinstance(existing, dict)
            or full not in self.implicit
            or full in self.explicit {
            raise self.error("Cannot declare (" + ".".join(keys) + ") twice");
        }
        self.implicit.remove(full);
    } else {
        table[last] = {};
    }
    self.explicit.add(full);
    self.current = table[last];
    self.current_path = full;
}

impl _TomlParser.parse_array_table_header {
    self.pos += 2;
    self.skip_ws();
    keys = self.parse_key();
    if not self.starts("]]") {
        raise self.error("Expected ']]' at the end of an array of tables declaration");
    }
    self.pos += 2;
    self.close_section();
    (table, path) = self.descend_header(keys[:len(keys) - 1]);
    last = keys[len(keys) - 1];
    full = _join_path(path, last);
    if last not in table {
        table[last] = [];
        self.arrays.add(full);
    } elif full not in self.arrays {
        raise self.error("Cannot append to (" + ".".join(keys) + "): not an array of tables");
    }
    items: list[any] = table[last];
    element: dict[str, any] = {};
    items.append(element);
    self.current = element;
    self.current_path = full + _PATH_SEP + "#" + str(len(items) - 1);
}

impl _TomlParser.descend_dotted(
    table: dict[str, any], path: str, keys: list[str]
) -> tuple[dict[str, any], str] {
    for key in keys {
        full = _join_path(path, key);
        if key not in table {
            table[key] = {};
            self.section_dotted.add(full);
        } else {
            value = table[key];
            if not isinstance(value, dict)
                or full in self.frozen
                or full not in self.section_dotted {
                raise self.error("Cannot redefine namespace (" + ".".join(keys) + ")");
            }
        }
        table = table[key];
        path = full;
    }
    return (table, path);
}

impl _TomlParser.parse_key_value(table: dict[str, any], path: str) {
    keys = self.parse_key();
    self.skip_ws();
    if self.at() != "=" {
        raise self.error("Expected '=' after a key in a key/value pair");
    }
    self.pos += 1;
    self.skip_ws();
    (target, target_path) = self.descend_dotted(table, path, keys[:len(keys) - 1]);
    last = keys[len(keys) - 1];
    full = _join_path(target_path, last);
    if last in target {
        raise self.error("Cannot overwrite a value (" + ".".join(keys) + ")");
    }
    value = self.parse_value(full);
    target[last] = value;
    if isinstance(value, dict) {
        self.frozen.add(full);
    }
}

impl _TomlParser.parse_value(path: str) -> any {
    c = self.at();
    if c == "" {
        raise self.error("Expected a value");
    }
    if c == "\"" {
        if self.starts("\"\"\"") {
            return self.parse_multiline_basic_string();
        }
        return self.parse_basic_string();
    }
    if c == "'" {
        if self.starts("'''") {
            return self.parse_multiline_literal_string();
        }
        return self.parse_literal_string();
    }
    if c == "[" {
        return self.parse_array(path);
    }
    if c == "{" {
        return self.parse_inline_table(path);
    }
    if self.starts("true") {
        self.pos += 4;
        return True;
    }
    if self.starts("false") {
        self.pos += 5;
        return False;
    }
    if self.starts("inf") or self.starts("nan") {
        return self.parse_special_float("");
    }
    if (c == "+" or c == "-") and (
        self.src.startswith("inf", self.pos + 1)
        or self.src.startswith("nan", self.pos + 1)
    ) {
        self.pos += 1;
        return self.parse_special_float(c);
    }
    if _is_digit(c) or c == "+" or c == "-" {
        return self.parse_number_or_datetime();
    }
    raise self.error("Invalid value");
}

impl _TomlParser.parse_special_float(sign: str) -> float {
    word = self.src[self.pos:self.pos + 3];
    self.pos += 3;
    value: float = float("inf") if word == "inf" else float("nan");
    if sign == "-" {
        return -value;
    }
    return value;
}

impl _TomlParser.parse_escape -> str {
    self.pos += 1;
    e = self.at();
    self.pos += 1;
    if e == "b" {
        return chr(8);
    }
    if e == "t" {
        return "\t";
    }
    if e == "n" {
        return "\n";
    }
    if e == "f" {
        return chr(12);
    }
    if e == "r" {
        return "\r";
    }
    if e == "\"" {
        return "\"";
    }
    if e == "\\" {
        return "\\";
    }
    if e == "u" or e == "U" {
        width = 4 if e == "u" else 8;
        code = 0;
        i = 0;
        while i < width {
            h = self.at();
            if not _is_hex_digit(h) {
                raise self.error("Invalid hex value in a unicode escape");
            }
            code = code * 16 + _digit_value(h);
            self.pos += 1;
            i += 1;
        }
        if code > 1114111 or (code >= 55296 and code <= 57343) {
            raise self.error("Escaped character is not a Unicode scalar value");
        }
        return chr(code);
    }
    self.pos -= 1;
    raise self.error("Unescaped '\\' in a string");
}

impl _TomlParser.parse_basic_string -> str {
    self.pos += 1;
    parts: list[str] = [];
    start = self.pos;
    while True {
        if self.eof() {
            raise self.error("Unterminated string");
        }
        c = self.src[self.pos];
        if c == "\"" {
            parts.append(self.src[start:self.pos]);
            self.pos += 1;
            return "".join(parts);
        }
        if c == "\\" {
            parts.append(self.src[start:self.pos]);
            parts.append(self.parse_escape());
            start = self.pos;
            continue;
        }
        if _is_control(c, False) {
            raise self.error("Illegal character in a basic string");
        }
        self.pos += 1;
    }
}

impl _TomlParser.parse_multiline_basic_string -> str {
    self.pos += 3;
    if self.at() == "\n" {
        self.pos += 1;
    }
    parts: list[str] = [];
    start = self.pos;
    while True {
        if self.eof() {
            raise self.error("Unterminated multiline string");
        }
        c = self.src[self.pos];
        if c == "\"" {
            run = 0;
            while self.at(run) == "\"" {
                run += 1;
            }
            if run < 3 {
                self.pos += run;
                continue;
            }
            if run > 5 {
                raise self.error("Too many quotes closing a multiline string");
            }
            parts.append(self.src[start:self.pos + run - 3]);
            self.pos += run;
            return "".join(parts);
        }
        if c == "\\" {
            parts.append(self.src[start:self.pos]);
            probe = self.pos + 1;
            while probe < self.n and (self.src[probe] == " " or self.src[probe] == "\t") {
                probe += 1;
            }
            if probe < self.n and self.src[probe] == "\n" {
                self.pos = probe;
                while self.pos < self.n {
                    w = self.src[self.pos];
                    if w != " " and w != "\t" and w != "\n" {
                        break;
                    }
                    self.pos += 1;
                }
            } else {
                parts.append(self.parse_escape());
            }
            start = self.pos;
            continue;
        }
        if _is_control(c, True) {
            raise self.error("Illegal character in a multiline basic string");
        }
        self.pos += 1;
    }
}

impl _TomlParser.parse_literal_string -> str {
    self.pos += 1;
    start = self.pos;
    while True {
        if self.eof() {
            raise self.error("Unterminated literal string");
        }
        c = self.src[self.pos];
        if c == "'" {
            text = self.src[start:self.pos];
            self.pos += 1;
            return text;
        }
        if _is_control(c, False) {
            raise self.error("Illegal character in a literal string");
        }
        self.pos += 1;
    }
}

impl _TomlParser.parse_multiline_literal_string -> str {
    self.pos += 3;
    if self.at() == "\n" {
        self.pos += 1;
    }
    start = self.pos;
    while True {
        if self.eof() {
            raise self.error("Unterminated multiline literal string");
        }
        c = self.src[self.pos];
        if c == "'" {
            run = 0;
            while self.at(run) == "'" {
                run += 1;
            }
            if run < 3 {
                self.pos += run;
                continue;
            }
            if run > 5 {
                raise self.error("Too many quotes closing a multiline literal string");
            }
            text = self.src[start:self.pos + run - 3];
            self.pos += run;
            return text;
        }
        if _is_control(c, True) {
            raise self.error("Illegal character in a multiline literal string");
        }
        self.pos += 1;
    }
}

impl _TomlParser.parse_array(path: str) -> list[any] {
    self.pos += 1;
    items: list[any] = [];
    while True {
        self.skip_array_ws();
        if self.at() == "]" {
            self.pos += 1;
            return items;
        }
        items.append(self.parse_value(path + _PATH_SEP + "[]"));
        self.skip_array_ws();
        c = self.at();
        if c == "," {
            self.pos += 1;
            continue;
        }
        if c == "]" {
            self.pos += 1;
            return items;
        }
        raise self.error("Unclosed array");
    }
}

impl _TomlParser.parse_inline_table(path: str) -> dict[str, any] {
    self.pos += 1;
    table: dict[str, any] = {};
    saved = self.section_dotted;
    self.section_dotted = set();
    self.skip_ws();
    if self.at() == "}" {
        self.pos += 1;
        self.section_dotted = saved;
        return table;
    }
    while True {
        self.parse_key_value(table, path);
        self.skip_ws();
        c = self.at();
        if c == "}" {
            self.pos += 1;
            self.section_dotted = saved;
            return table;
        }
        if c != "," {
            raise self.error("Unclosed inline table");
        }
        self.pos += 1;
        self.skip_ws();
        if self.at() == "}" {
            raise self.error("Trailing comma in an inline table");
        }
    }
}

impl _TomlParser.scan_token -> str {
    start = self.pos;
    while self.pos < self.n {
        c = self.src[self.pos];
        if c == " "
            or c == "\t"
            or c == "\n"
            or c == ","
            or c == "]"
            or c == "}"
            or c == "#" {
            break;
        }
        self.pos += 1;
    }
    return self.src[start:self.pos];
}

impl _TomlParser.looks_like_date -> bool {
    i = 0;
    while i < 4 {
        if not _is_digit(self.at(i)) {
            return False;
        }
        i += 1;
    }
    return self.at(4) == "-";
}

impl _TomlParser.looks_like_time -> bool {
    return _is_digit(self.at()) and _is_digit(self.at(1)) and self.at(2) == ":";
}

impl _TomlParser.read_digits(count: int) -> int {
    value = 0;
    i = 0;
    while i < count {
        c = self.at();
        if not _is_digit(c) {
            raise self.error("Invalid date or time");
        }
        value = value * 10 + _digit_value(c);
        self.pos += 1;
        i += 1;
    }
    return value;
}

impl _TomlParser.parse_date -> date {
    year = self.read_digits(4);
    if self.at() != "-" {
        raise self.error("Invalid date");
    }
    self.pos += 1;
    month = self.read_digits(2);
    if self.at() != "-" {
        raise self.error("Invalid date");
    }
    self.pos += 1;
    day = self.read_digits(2);
    try {
        return date(year, month, day);
    } except ValueError {
        raise self.error("Invalid date");
    }
}

impl _TomlParser.parse_time_parts -> tuple[int, int, int, int] {
    hour = self.read_digits(2);
    if self.at() != ":" {
        raise self.error("Invalid time");
    }
    self.pos += 1;
    minute = self.read_digits(2);
    if self.at() != ":" {
        raise self.error("Invalid time");
    }
    self.pos += 1;
    second = self.read_digits(2);
    micro = 0;
    if self.at() == "." {
        self.pos += 1;
        if not _is_digit(self.at()) {
            raise self.error("Invalid fractional seconds");
        }
        scale = 100000;
        while _is_digit(self.at()) {
            if scale > 0 {
                micro += _digit_value(self.at()) * scale;
                scale = scale // 10;
            }
            self.pos += 1;
        }
    }
    if hour > 23 or minute > 59 or second > 59 {
        raise self.error("Invalid time");
    }
    return (hour, minute, second, micro);
}

impl _TomlParser.parse_offset -> (timezone | None) {
    c = self.at();
    if c == "Z" or c == "z" {
        self.pos += 1;
        return timezone.utc;
    }
    if c != "+" and c != "-" {
        return None;
    }
    self.pos += 1;
    hours = self.read_digits(2);
    if self.at() != ":" {
        raise self.error("Invalid time offset");
    }
    self.pos += 1;
    minutes = self.read_digits(2);
    if hours > 23 or minutes > 59 {
        raise self.error("Invalid time offset");
    }
    delta = timedelta(hours=hours, minutes=minutes);
    if c == "-" {
        delta = -delta;
    }
    return timezone(delta);
}

impl _TomlParser.parse_number_or_datetime -> any {
    if self.looks_like_date() {
        day = self.parse_date();
        sep = self.at();
        if not (
            sep == "T"
            or sep == "t"
            or (sep == " " and _is_digit(self.at(1)) and self.at(3) == ":")
        ) {
            return day;
        }
        self.pos += 1;
        (hour, minute, second, micro) = self.parse_time_parts();
        zone = self.parse_offset();
        if zone is None {
            return datetime(day.year, day.month, day.day, hour, minute, second, micro);
        }
        return datetime(
            day.year, day.month, day.day, hour, minute, second, micro, tzinfo=zone
        );
    }
    if self.looks_like_time() {
        (hour, minute, second, micro) = self.parse_time_parts();
        return time(hour, minute, second, micro);
    }
    token = self.scan_token();
    if token == "" {
        raise self.error("Invalid value");
    }
    body = token;
    if body[0] == "+" or body[0] == "-" {
        body = body[1:];
    }
    if len(body) > 1
        and body[0] == "0"
        and (body[1] == "x" or body[1] == "o" or body[1] == "b") {
        if body != token {
            raise self.error("A sign is not allowed on a non-decimal integer");
        }
        return self.parse_integer(token);
    }
    if "." in body or "e" in body or "E" in body {
        return self.parse_float(token);
    }
    return self.parse_integer(token);
}

impl _TomlParser.check_digits(text: str, allow_hex: bool) {
    if text == "" or text[0] == "_" or text[len(text) - 1] == "_" {
        raise self.error("Invalid number");
    }
    previous = "";
    for c in text {
        if c == "_" {
            if previous == "_" {
                raise self.error("Invalid number");
            }
        } elif not (_is_hex_digit(c) if allow_hex else _is_digit(c)) {
            raise self.error("Invalid number");
        }
        previous = c;
    }
}

impl _TomlParser.parse_integer(token: str) -> int {
    sign = 1;
    body = token;
    if body[0] == "+" or body[0] == "-" {
        sign = -1 if body[0] == "-" else 1;
        body = body[1:];
    }
    base = 10;
    if len(body) > 1 and body[0] == "0" and body[1] == "x" {
        base = 16;
        body = body[2:];
    } elif len(body) > 1 and body[0] == "0" and body[1] == "o" {
        base = 8;
        body = body[2:];
    } elif len(body) > 1 and body[0] == "0" and body[1] == "b" {
        base = 2;
        body = body[2:];
    }
    self.check_digits(body, base == 16);
    if base == 10 and len(body) > 1 and body[0] == "0" {
        raise self.error("Leading zeros are not allowed in an integer");
    }
    value = 0;
    for c in body {
        if c == "_" {
            continue;
        }
        digit = _digit_value(c);
        if digit >= base {
            raise self.error("Invalid digit for the integer's base");
        }
        value = value * base + digit;
    }
    return sign * value;
}

impl _TomlParser.parse_float(token: str) -> float {
    body = token;
    if body[0] == "+" or body[0] == "-" {
        body = body[1:];
    }
    mantissa = body;
    exponent = "";
    cut = -1;
    i = 0;
    while i < len(body) {
        if body[i] == "e" or body[i] == "E" {
            cut = i;
            break;
        }
        i += 1;
    }
    if cut >= 0 {
        mantissa = body[:cut];
        exponent = body[cut + 1:];
        if exponent != "" and (exponent[0] == "+" or exponent[0] == "-") {
            exponent = exponent[1:];
        }
        self.check_digits(exponent, False);
    }
    dot = mantissa.find(".");
    whole = mantissa if dot < 0 else mantissa[:dot];
    self.check_digits(whole, False);
    if len(whole) > 1 and whole[0] == "0" {
        raise self.error("Leading zeros are not allowed in a float");
    }
    if dot >= 0 {
        self.check_digits(mantissa[dot + 1:], False);
    }
    return float(token.replace("_", ""));
}
