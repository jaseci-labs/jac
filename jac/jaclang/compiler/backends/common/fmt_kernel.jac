def _jac_fmt_is_align(ch: str) -> bool {
    return ch == "<" or ch == ">" or ch == "^" or ch == "=";
}

def _jac_fmt_is_digit(ch: str) -> bool {
    return ch >= "0" and ch <= "9";
}

def _jac_fmt_parse(
    spec: str
) -> tuple[str, str, str, int, int, int, int, str, int, str] {
    fill = "";
    align = "";
    sign = "";
    alt = 0;
    zero = 0;
    zc = 0;
    width = -1;
    grouping = "";
    prec = -1;
    typ = "";
    i = 0;
    n = len(spec);
    if n >= 2 and _jac_fmt_is_align(spec[1]) {
        fill = spec[0];
        align = spec[1];
        i = 2;
    } elif n >= 1 and _jac_fmt_is_align(spec[0]) {
        align = spec[0];
        i = 1;
    }
    if i < n and (spec[i] == "+" or spec[i] == "-" or spec[i] == " ") {
        sign = spec[i];
        i += 1;
    }
    if i < n and spec[i] == "z" {
        zc = 1;
        i += 1;
    }
    if i < n and spec[i] == "#" {
        alt = 1;
        i += 1;
    }
    if i < n and spec[i] == "0" {
        zero = 1;
        i += 1;
    }
    while i < n and _jac_fmt_is_digit(spec[i]) {
        if width < 0 {
            width = 0;
        }
        width = width * 10 + (ord(spec[i]) - 48);
        i += 1;
    }
    if i < n and (spec[i] == "," or spec[i] == "_") {
        grouping = spec[i];
        i += 1;
        if i < n and (spec[i] == "," or spec[i] == "_") {
            raise ValueError("Cannot specify both ',' and '_'.");
        }
    }
    if i < n and spec[i] == "." {
        i += 1;
        if i >= n or not _jac_fmt_is_digit(spec[i]) {
            raise ValueError("Format specifier missing precision");
        }
        prec = 0;
        while i < n and _jac_fmt_is_digit(spec[i]) {
            prec = prec * 10 + (ord(spec[i]) - 48);
            i += 1;
        }
    }
    if i < n {
        typ = spec[i];
        i += 1;
    }
    if i < n {
        raise ValueError("Invalid format specifier '" + spec + "'");
    }
    return (fill, align, sign, alt, zero, zc, width, grouping, prec, typ);
}

def _jac_fmt_rep(fill: str, count: int) -> str {
    out = "";
    i = 0;
    while i < count {
        out += fill;
        i += 1;
    }
    return out;
}

def _jac_fmt_pad(body: str, fill: str, align: str, width: int) -> str {
    if width <= len(body) {
        return body;
    }
    n = width - len(body);
    if align == "<" {
        return body + _jac_fmt_rep(fill, n);
    }
    if align == "^" {
        left = n // 2;
        return _jac_fmt_rep(fill, left) + body + _jac_fmt_rep(fill, n - left);
    }
    return _jac_fmt_rep(fill, n) + body;
}

def _jac_fmt_group(digits: str, sep: str, gsize: int) -> str {
    out = "";
    cnt = 0;
    i = len(digits) - 1;
    while i >= 0 {
        out = digits[i] + out;
        cnt += 1;
        if cnt == gsize and i > 0 {
            out = sep + out;
            cnt = 0;
        }
        i -= 1;
    }
    return out;
}

def _jac_fmt_has_digit(s: str) -> bool {
    i = 0;
    n = len(s);
    while i < n {
        if s[i] >= "0" and s[i] <= "9" {
            return True;
        }
        i += 1;
    }
    return False;
}

def _jac_fmt_all_zero_val(s: str) -> bool {
    i = 0;
    n = len(s);
    while i < n {
        if s[i] >= "1" and s[i] <= "9" {
            return False;
        }
        i += 1;
    }
    return True;
}

def _jac_fmt_finish(
    intpart: str,
    rest: str,
    sign_str: str,
    prefix: str,
    fill: str,
    align: str,
    zero: int,
    width: int,
    grouping: str,
    gsize: int
) -> str {
    grouped = intpart;
    if grouping != "" and gsize > 0 {
        grouped = _jac_fmt_group(intpart, grouping, gsize);
    }
    if zero == 1 {
        if fill == "" {
            fill = "0";
        }
        if align == "" {
            align = "=";
        }
    }
    if fill == "" {
        fill = " ";
    }
    if align == "" {
        align = ">";
    }
    head = sign_str + prefix;
    if align == "=" {
        if fill == "0" and grouping != "" and gsize > 0 {
            pdig = intpart;
            while len(head) + len(grouped) + len(rest) < width {
                pdig = "0" + pdig;
                grouped = _jac_fmt_group(pdig, grouping, gsize);
            }
        } else {
            room = width - len(head) - len(grouped) - len(rest);
            if room > 0 {
                grouped = _jac_fmt_rep(fill, room) + grouped;
            }
        }
        return head + grouped + rest;
    }
    return _jac_fmt_pad(head + grouped + rest, fill, align, width);
}

def _jac_fmt_sign_str(neg: bool, sign: str) -> str {
    if neg {
        return "-";
    }
    if sign == "+" {
        return "+";
    }
    if sign == " " {
        return " ";
    }
    return "";
}

def _jac_fmt_strip_zeros(s: str, keep_one: int) -> str {
    has_dot = False;
    i = 0;
    n = len(s);
    while i < n {
        if s[i] == "." {
            has_dot = True;
        }
        i += 1;
    }
    if not has_dot {
        return s;
    }
    out = s;
    while len(out) > 1 and out[len(out) - 1] == "0" {
        if keep_one == 1 and out[len(out) - 2] == "." {
            break;
        }
        out = out[:len(out) - 1];
    }
    if keep_one == 0 and len(out) > 0 and out[len(out) - 1] == "." {
        out = out[:len(out) - 1];
    }
    return out;
}

def _jac_fmt_float_none_prec(v: float, prec: int) -> str {
    p = prec;
    if p == 0 {
        p = 1;
    }
    er = format(v, "." + str(p - 1) + "e");
    if not _jac_fmt_has_digit(er) {
        return er;
    }
    ei = len(er) - 1;
    while ei >= 0 and er[ei] != "e" and er[ei] != "E" {
        ei -= 1;
    }
    mant = er[:ei];
    ex = int(er[ei + 1:]);
    if ex < -4 or ex >= p - 1 {
        mant = _jac_fmt_strip_zeros(mant, 0);
        esign = "-" if ex < 0 else "+";
        ea = 0 - ex if ex < 0 else ex;
        etxt = str(ea);
        if len(etxt) < 2 {
            etxt = "0" + etxt;
        }
        return mant + "e" + esign + etxt;
    }
    fd = p - 1 - ex;
    return _jac_fmt_strip_zeros(format(v, "." + str(fd) + "f"), 1);
}

def jac_fmt_int(v: int, spec: str) -> str {
    (fill, align, sign, alt, zero, zc, width, grouping, prec, typ) = _jac_fmt_parse(
        spec
    );
    if typ == "f"
        or typ == "F"
        or typ == "e"
        or typ == "E"
        or typ == "g"
        or typ == "G"
        or typ == "%" {
        return jac_fmt_float(float(v), spec);
    }
    if zc == 1 {
        raise ValueError(
            "Negative zero coercion (z) not allowed in integer format specifier"
        );
    }
    if prec >= 0 {
        raise ValueError("Precision not allowed in integer format specifier");
    }
    if typ == "c" {
        if sign != "" {
            raise ValueError("Sign not allowed with integer format specifier 'c'");
        }
        if alt == 1 {
            raise ValueError(
                "Alternate form (#) not allowed with integer format specifier 'c'"
            );
        }
        if grouping != "" {
            raise ValueError("Cannot specify '" + grouping + "' with 'c'.");
        }
        return _jac_fmt_finish(chr(v), "", "", "", fill, align, zero, width, "", 0);
    }
    if typ != ""
        and typ != "d"
        and typ != "n"
        and typ != "b"
        and typ != "o"
        and typ != "x"
        and typ != "X" {
        raise ValueError("Unknown format code '" + typ + "' for object of type 'int'");
    }
    gsize = 3;
    if typ == "b" or typ == "o" or typ == "x" or typ == "X" {
        gsize = 4;
        if grouping == "," {
            raise ValueError("Cannot specify ',' with '" + typ + "'.");
        }
    }
    if typ == "n" and grouping != "" {
        raise ValueError("Cannot specify '" + grouping + "' with 'n'.");
    }
    neg = v < 0;
    digits = "";
    if neg and 0 - v == v {
        if typ == "x" or typ == "X" {
            digits = "8000000000000000";
        } elif typ == "o" {
            digits = "1000000000000000000000";
        } elif typ == "b" {
            digits = "1" + _jac_fmt_rep("0", 63);
        } else {
            digits = "9223372036854775808";
        }
    } else {
        av = 0 - v if neg else v;
        if typ == "x" {
            digits = format(av, "llx");
        } elif typ == "X" {
            digits = format(av, "llX");
        } elif typ == "o" {
            digits = format(av, "llo");
        } elif typ == "b" {
            if av == 0 {
                digits = "0";
            } else {
                t = av;
                while t > 0 {
                    digits = ("1" if t % 2 == 1 else "0") + digits;
                    t = t // 2;
                }
            }
        } else {
            digits = format(av, "lld");
        }
    }
    prefix = "";
    if alt == 1 {
        if typ == "x" {
            prefix = "0x";
        } elif typ == "X" {
            prefix = "0X";
        } elif typ == "o" {
            prefix = "0o";
        } elif typ == "b" {
            prefix = "0b";
        }
    }
    return _jac_fmt_finish(
        digits,
        "",
        _jac_fmt_sign_str(neg, sign),
        prefix,
        fill,
        align,
        zero,
        width,
        grouping,
        gsize
    );
}

def jac_fmt_float(v: float, spec: str) -> str {
    (fill, align, sign, alt, zero, zc, width, grouping, prec, typ) = _jac_fmt_parse(
        spec
    );
    if typ != ""
        and typ != "f"
        and typ != "F"
        and typ != "e"
        and typ != "E"
        and typ != "g"
        and typ != "G"
        and typ != "%"
        and typ != "n" {
        raise ValueError(
            "Unknown format code '" + typ + "' for object of type 'float'"
        );
    }
    if typ == "n" and grouping != "" {
        raise ValueError("Cannot specify '" + grouping + "' with 'n'.");
    }
    hash_s = "#" if alt == 1 else "";
    p = prec if prec >= 0 else 6;
    body = "";
    if typ == "f" or typ == "F" or typ == "e" or typ == "E" {
        body = format(v, hash_s + "." + str(p) + typ);
    } elif typ == "g" or typ == "G" or typ == "n" {
        if p == 0 {
            p = 1;
        }
        body = format(v, hash_s + "." + str(p) + ("G" if typ == "G" else "g"));
    } elif typ == "%" {
        body = format(v * 100.0, hash_s + "." + str(p) + "f") + "%";
    } elif prec >= 0 {
        body = _jac_fmt_float_none_prec(v, prec);
    } else {
        body = str(v);
    }
    neg = False;
    if len(body) > 0 and body[0] == "-" {
        neg = True;
        body = body[1:];
    }
    if not _jac_fmt_has_digit(body) {
        if len(body) > 0 and (body[0] == "n" or body[0] == "N") {
            neg = False;
        }
        if zero == 1 and fill == "" {
            fill = " ";
        }
        return _jac_fmt_finish(
            "", body, _jac_fmt_sign_str(neg, sign), "", fill, align, zero, width, "", 0
        );
    }
    if zc == 1 and neg and _jac_fmt_all_zero_val(body) {
        neg = False;
    }
    ip = 0;
    n = len(body);
    while ip < n and body[ip] >= "0" and body[ip] <= "9" {
        ip += 1;
    }
    return _jac_fmt_finish(
        body[:ip],
        body[ip:],
        _jac_fmt_sign_str(neg, sign),
        "",
        fill,
        align,
        zero,
        width,
        grouping,
        3
    );
}

def jac_fmt_str(s: str, spec: str) -> str {
    (fill, align, sign, alt, zero, zc, width, grouping, prec, typ) = _jac_fmt_parse(
        spec
    );
    if typ != "" and typ != "s" {
        raise ValueError("Unknown format code '" + typ + "' for object of type 'str'");
    }
    if sign != "" {
        raise ValueError("Sign not allowed in string format specifier");
    }
    if align == "=" {
        raise ValueError("'=' alignment not allowed in string format specifier");
    }
    if alt == 1 {
        raise ValueError("Alternate form (#) not allowed in string format specifier");
    }
    if grouping != "" {
        raise ValueError("Cannot specify '" + grouping + "' with 's'.");
    }
    if zc == 1 {
        raise ValueError(
            "Negative zero coercion (z) not allowed in string format specifier"
        );
    }
    body = s;
    if prec >= 0 {
        body = s[:prec];
    }
    if zero == 1 and fill == "" {
        fill = "0";
    }
    if fill == "" {
        fill = " ";
    }
    if align == "" {
        align = "<";
    }
    return _jac_fmt_pad(body, fill, align, width);
}

def jac_fmt_bool(v: bool, spec: str) -> str {
    if spec == "" {
        return "True" if v else "False";
    }
    return jac_fmt_int(1 if v else 0, spec);
}

def _jac_hex_digit(ch: str) -> int {
    idx = "0123456789abcdefABCDEF".find(ch);
    if idx < 0 {
        return -1;
    }
    return idx if idx < 16 else idx - 6;
}

def _jac_int_digit(ch: str) -> int {
    idx = "0123456789abcdefghijklmnopqrstuvwxyz".find(ch.lower());
    return idx if idx >= 0 else 99;
}

def _jac_int_bad(text: str, base: int) {
    raise ValueError(f"invalid literal for int() with base {base}: '{text}'");
}

def jac_int_parse(text: str, base: int) -> int {
    if base != 0 and (base < 2 or base > 36) {
        raise ValueError("int() base must be >= 2 and <= 36, or 0");
    }
    i = 0;
    j = len(text);
    while i < j and text[i] in " \t\n\r\x0b\x0c" {
        i += 1;
    }
    while j > i and text[j - 1] in " \t\n\r\x0b\x0c" {
        j -= 1;
    }
    neg = False;
    if i < j and (text[i] == "+" or text[i] == "-") {
        neg = text[i] == "-";
        i += 1;
    }
    radix = base;
    prefixed = False;
    if i + 1 < j and text[i] == "0" {
        mark = text[i + 1].lower();
        found = 16
            if mark == "x"
            else (8 if mark == "o" else (2 if mark == "b" else 0));
        if found != 0 and (base == 0 or base == found) {
            radix = found;
            prefixed = True;
            i += 2;
        }
    }
    decimal_zero_rule = radix == 0;
    if radix == 0 {
        radix = 10;
    }
    value = 0;
    digits = 0;
    nonzero = False;
    under_ok = prefixed;
    last_under = False;
    while i < j {
        ch = text[i];
        if ch == "_" {
            if not under_ok {
                _jac_int_bad(text, base);
            }
            under_ok = False;
            last_under = True;
            i += 1;
            continue;
        }
        d = _jac_int_digit(ch);
        if d >= radix {
            _jac_int_bad(text, base);
        }
        if d != 0 {
            nonzero = True;
        }
        value = value * radix + d;
        digits += 1;
        under_ok = True;
        last_under = False;
        i += 1;
    }
    if digits == 0 or last_under {
        _jac_int_bad(text, base);
    }
    if decimal_zero_rule and nonzero and digits > 1 {
        k = 0;
        while k < len(text) and text[k] in " \t\n\r\x0b\x0c+-" {
            k += 1;
        }
        if k < len(text) and text[k] == "0" {
            _jac_int_bad(text, base);
        }
    }
    return -value if neg else value;
}

def jac_bytes_hex(data: bytes) -> str {
    digits = "0123456789abcdef";
    out = "";
    for v in data {
        out += digits[v // 16];
        out += digits[v % 16];
    }
    return out;
}

def jac_bytes_fromhex(text: str) -> bytes {
    out = bytearray();
    n = len(text);
    i = 0;
    while i < n {
        if text[i] in " \t\n\r\x0b\x0c" {
            i += 1;
            continue;
        }
        hi = _jac_hex_digit(text[i]);
        if hi >= 0 and i + 1 == n {
            raise ValueError(
                "fromhex() arg must contain an even number of hexadecimal digits"
            );
        }
        lo = _jac_hex_digit(text[i + 1]) if hi >= 0 else -1;
        if hi < 0 or lo < 0 {
            bad = i if hi < 0 else i + 1;
            raise ValueError(
                f"non-hexadecimal number found in fromhex() arg at position {bad}"
            );
        }
        out.append(hi * 16 + lo);
        i += 2;
    }
    return bytes(out);
}

def _jac_bytes_is_space(v: int) -> bool {
    return v == 32 or (v >= 9 and v <= 13);
}

def jac_bytes_upper(data: bytes) -> bytes {
    out = bytearray();
    for v in data {
        out.append(v - 32 if v >= 97 and v <= 122 else v);
    }
    return bytes(out);
}

def jac_bytes_lower(data: bytes) -> bytes {
    out = bytearray();
    for v in data {
        out.append(v + 32 if v >= 65 and v <= 90 else v);
    }
    return bytes(out);
}

def jac_bytes_strip(data: bytes, chars: bytes, has_chars: bool, which: int) -> bytes {
    start = 0;
    end = len(data);
    if which != 2 {
        while start < end
            and (
                data[start] in chars if has_chars else _jac_bytes_is_space(data[start])
            ) {
            start += 1;
        }
    }
    if which != 1 {
        while end > start
            and (
                data[end - 1] in chars
                    if has_chars
                    else _jac_bytes_is_space(data[end - 1])
            ) {
            end -= 1;
        }
    }
    return data[start:end];
}

def _jac_bytes_split_ws(data: bytes, maxsplit: int) -> list[bytes] {
    parts: list[bytes] = [];
    n = len(data);
    i = 0;
    while i < n {
        while i < n and _jac_bytes_is_space(data[i]) {
            i += 1;
        }
        if i >= n {
            break;
        }
        if maxsplit >= 0 and len(parts) == maxsplit {
            parts.append(data[i:]);
            break;
        }
        j = i;
        while j < n and not _jac_bytes_is_space(data[j]) {
            j += 1;
        }
        parts.append(data[i:j]);
        i = j;
    }
    return parts;
}

def jac_bytes_split(
    data: bytes, sep: bytes, has_sep: bool, maxsplit: int
) -> list[bytes] {
    if not has_sep {
        return _jac_bytes_split_ws(data, maxsplit);
    }
    if len(sep) == 0 {
        raise ValueError("empty separator");
    }
    parts: list[bytes] = [];
    start = 0;
    at = data.find(sep, start);
    while at >= 0 and (maxsplit < 0 or len(parts) < maxsplit) {
        parts.append(data[start:at]);
        start = at + len(sep);
        at = data.find(sep, start);
    }
    parts.append(data[start:]);
    return parts;
}

def jac_bytes_replace(data: bytes, old: bytes, new: bytes, count: int) -> bytes {
    out = bytearray();
    done = 0;
    if len(old) == 0 {
        i = 0;
        while i <= len(data) {
            if count < 0 or done < count {
                out.extend(new);
                done += 1;
            }
            if i < len(data) {
                out.append(data[i]);
            }
            i += 1;
        }
        return bytes(out);
    }
    start = 0;
    at = data.find(old, start);
    while at >= 0 and (count < 0 or done < count) {
        out.extend(data[start:at]);
        out.extend(new);
        done += 1;
        start = at + len(old);
        at = data.find(old, start);
    }
    out.extend(data[start:]);
    return bytes(out);
}

def jac_bytes_join(sep: bytes, parts: list[bytes]) -> bytes {
    out = bytearray();
    first = True;
    for part in parts {
        if not first {
            out.extend(sep);
        }
        out.extend(part);
        first = False;
    }
    return bytes(out);
}
