import from jaclang.compiler.types.ct_value {
    CtBool,
    CtBytes,
    CtDict,
    CtEnumMember,
    CtError,
    CtFloat,
    CtInt,
    CtList,
    CtNone,
    CtRecord,
    CtSet,
    CtStr,
    CtTuple,
    CtValue,
    as_ct_int,
    ascii_escape,
    ct_exc,
    ct_exc_value,
    ct_iter,
    ct_repr,
    ct_str,
    ct_type_name,
    dict_get,
    dict_set,
    float_to_ct_int,
    int_decimal,
    mk_str
}
import from jaclang.compiler.types.ct_ops {
    ct_binop,
    ct_getitem,
    int_abs,
    int_is_neg,
    int_to_base_str,
    int_to_float,
    set_algebra
}

obj CtFormatSpec {
    has fill: str = " ",
        align: str = "",
        sign: str = "",
        no_neg_0: bool = False,
        alternate: bool = False,
        width: int = -1,
        grouping: str = "",
        group_size: int = 3,
        frac_grouping: str = "",
        precision: int = -1,
        kind: str = "";
}

def _read_int(spec: str, pos: int) -> tuple[int, int] {
    start = pos;
    val = 0;
    while pos < len(spec) and "0" <= spec[pos] and spec[pos] <= "9" {
        val = val * 10 + (ord(spec[pos]) - 48);
        if val > 9223372036854775807 // 10 {
            raise ct_exc("ValueError", "Too many decimal digits in format string");
        }
        pos += 1;
    }
    return (val if pos > start else -1, pos);
}

def parse_format_spec(
    spec: str, owner: str, default_type: str, default_align: str
) -> CtFormatSpec {
    out = CtFormatSpec(align=default_align, kind=default_type);
    pos = 0;
    end = len(spec);
    fill_given = False;
    align_given = False;
    if end - pos >= 2 and spec[pos + 1] in "<>=^" {
        out.align = spec[pos + 1];
        out.fill = spec[pos];
        fill_given = True;
        align_given = True;
        pos += 2;
    } elif end - pos >= 1 and spec[pos] in "<>=^" {
        out.align = spec[pos];
        align_given = True;
        pos += 1;
    }
    if pos < end and spec[pos] in "+- " {
        out.sign = spec[pos];
        pos += 1;
    }
    if pos < end and spec[pos] == "z" {
        out.no_neg_0 = True;
        pos += 1;
    }
    if pos < end and spec[pos] == "#" {
        out.alternate = True;
        pos += 1;
    }
    if not fill_given and pos < end and spec[pos] == "0" {
        out.fill = "0";
        if not align_given and default_align == ">" {
            out.align = "=";
        }
        pos += 1;
    }
    (width, pos) = _read_int(spec, pos);
    out.width = width;
    if pos < end and spec[pos] == "," {
        out.grouping = ",";
        pos += 1;
    }
    if pos < end and spec[pos] == "_" {
        if out.grouping {
            raise ct_exc("ValueError", "Cannot specify both ',' and '_'.");
        }
        out.grouping = "_";
        pos += 1;
    }
    if pos < end and spec[pos] == "," and out.grouping == "_" {
        raise ct_exc("ValueError", "Cannot specify both ',' and '_'.");
    }
    if pos < end and spec[pos] == "." {
        pos += 1;
        (prec, pos) = _read_int(spec, pos);
        out.precision = prec;
        if pos < end and spec[pos] == "," {
            out.frac_grouping = ",";
            pos += 1;
        }
        if pos < end and spec[pos] == "_" {
            if out.frac_grouping {
                raise ct_exc("ValueError", "Cannot specify both ',' and '_'.");
            }
            out.frac_grouping = "_";
            pos += 1;
        }
        if pos < end and spec[pos] == "," and out.frac_grouping == "_" {
            raise ct_exc("ValueError", "Cannot specify both ',' and '_'.");
        }
        if prec == -1 and not out.frac_grouping {
            raise ct_exc("ValueError", "Format specifier missing precision");
        }
    }
    if end - pos > 1 {
        raise ct_exc(
            "ValueError",
            f"Invalid format specifier '{spec}' for object of type '{owner}'"
        );
    }
    if end - pos == 1 {
        out.kind = spec[pos];
    }
    if out.grouping {
        k = out.kind;
        if k in ("d", "e", "f", "g", "E", "G", "%", "F", "") {
            out.group_size = 3;
        } elif k in ("b", "o", "x", "X") and out.grouping == "_" {
            out.group_size = 4;
        } else {
            raise ct_exc("ValueError", _bad_separator(out.grouping, k));
        }
    }
    if out.kind == "n" and out.frac_grouping {
        raise ct_exc("ValueError", _bad_separator(out.frac_grouping, "n"));
    }
    return out;
}

def _bad_separator(sep: str, kind: str) -> str {
    o = ord(kind) if kind else 0;
    if o > 32 and o < 128 {
        return f"Cannot specify '{sep}' with '{kind}'.";
    }
    return f"Cannot specify '{sep}' with '\\x{format(o, 'x')}'.";
}

def _unknown_code(kind: str, owner: str) -> str {
    o = ord(kind);
    if o > 32 and o < 128 {
        return f"Unknown format code '{kind}' for object of type '{owner}'";
    }
    return f"Unknown format code '\\x{format(o, 'x')}' for object of type '{owner}'";
}

def group_digits(digits: str, min_width: int, sep: str, size: int) -> str {
    min_width = max(0, min_width);
    remaining = len(digits);
    pieces: list[str] = [];
    use_sep = False;
    broke = False;
    if size > 0 {
        while True {
            length = min(size, max(max(remaining, min_width), 1));
            n_zeros = max(0, length - remaining);
            n_chars = max(0, min(remaining, length));
            chunk = "0" * n_zeros + digits[remaining - n_chars:remaining];
            if use_sep {
                pieces.append(sep);
            }
            pieces.append(chunk);
            use_sep = True;
            remaining -= n_chars;
            min_width -= length;
            if remaining <= 0 and min_width <= 0 {
                broke = True;
                break;
            }
            min_width -= len(sep);
        }
    }
    if not broke {
        length = max(max(remaining, min_width), 1);
        n_zeros = max(0, length - remaining);
        n_chars = max(0, min(remaining, length));
        if use_sep {
            pieces.append(sep);
        }
        pieces.append("0" * n_zeros + digits[remaining - n_chars:remaining]);
    }
    pieces.reverse();
    return "".join(pieces);
}

def _layout_number(
    fs: CtFormatSpec,
    negative: bool,
    prefix: str,
    digits: str,
    remainder: str,
    sep: str,
    group_size: int
) -> str {
    sign = "";
    if fs.sign == "+" {
        sign = "-" if negative else "+";
    } elif fs.sign == " " {
        sign = "-" if negative else " ";
    } elif negative {
        sign = "-";
    }
    non_digit = len(sign) + len(prefix) + len(remainder);
    min_width = fs.width - non_digit if fs.fill == "0" and fs.align == "=" else 0;
    grouped = group_digits(digits, min_width, sep, group_size) if digits else "";
    n_padding = fs.width - (non_digit + len(grouped));
    (lpad, spad, rpad) = (0, 0, 0);
    if n_padding > 0 {
        if fs.align == "<" {
            rpad = n_padding;
        } elif fs.align == "^" {
            lpad = n_padding // 2;
            rpad = n_padding - lpad;
        } elif fs.align == "=" {
            spad = n_padding;
        } else {
            lpad = n_padding;
        }
    }
    return fs.fill * lpad
        + sign
        + prefix
        + fs.fill * spad
        + grouped
        + remainder
        + fs.fill * rpad;
}

def format_int(v: CtInt, spec: str, owner: str) -> str {
    fs = parse_format_spec(spec, owner, "d", ">");
    k = fs.kind;
    if k in ("e", "E", "f", "F", "g", "G", "%") {
        return format_float(int_to_float(v), spec);
    }
    if k not in ("b", "c", "d", "o", "x", "X", "n") {
        raise ct_exc("ValueError", _unknown_code(k, owner));
    }
    if fs.precision != -1 {
        raise ct_exc("ValueError", "Precision not allowed in integer format specifier");
    }
    if fs.no_neg_0 {
        raise ct_exc(
            "ValueError",
            "Negative zero coercion (z) not allowed in integer format specifier"
        );
    }
    if k == "c" {
        if fs.sign {
            raise ct_exc(
                "ValueError", "Sign not allowed with integer format specifier 'c'"
            );
        }
        if fs.alternate {
            raise ct_exc(
                "ValueError",
                "Alternate form (#) not allowed with integer format specifier 'c'"
            );
        }
        if v.mag {
            raise ct_exc("OverflowError", "Python int too large to convert to C long");
        }
        if v.small < 0 or v.small > 1114111 {
            raise ct_exc("OverflowError", "%c arg not in range(0x110000)");
        }
        return _layout_number(fs, False, "", "", chr(v.small), "", 0);
    }
    base = 10;
    prefix = "";
    if k == "b" {
        base = 2;
        prefix = "0b";
    } elif k == "o" {
        base = 8;
        prefix = "0o";
    } elif k in ("x", "X") {
        base = 16;
        prefix = "0x";
    }
    digits = int_to_base_str(v, base);
    if not fs.alternate {
        prefix = "";
    }
    if k == "X" {
        digits = digits.upper();
        prefix = prefix.upper();
    }
    sep = fs.grouping;
    return _layout_number(
        fs, int_is_neg(v), prefix, digits, "", sep, fs.group_size if sep else 0
    );
}

def format_str(s: str, spec: str) -> str {
    fs = parse_format_spec(spec, "str", "s", "<");
    if fs.kind != "s" {
        raise ct_exc("ValueError", _unknown_code(fs.kind, "str"));
    }
    if fs.sign {
        raise ct_exc("ValueError", "Sign not allowed in string format specifier");
    }
    if fs.no_neg_0 {
        raise ct_exc(
            "ValueError",
            "Negative zero coercion (z) not allowed in string format specifier"
        );
    }
    if fs.alternate {
        raise ct_exc(
            "ValueError", "Alternate form (#) not allowed in string format specifier"
        );
    }
    if fs.align == "=" {
        raise ct_exc(
            "ValueError", "'=' alignment not allowed in string format specifier"
        );
    }
    text = s;
    if fs.precision >= 0 and len(text) > fs.precision {
        text = text[:fs.precision];
    }
    return pad_text(text, fs.width, fs.align, fs.fill);
}

def pad_text(text: str, width: int, align: str, fill: str) -> str {
    n = len(text);
    total = max(width, n) if width >= 0 else n;
    if align == ">" {
        lpad = total - n;
    } elif align == "^" {
        lpad = (total - n) // 2;
    } else {
        lpad = 0;
    }
    return fill * lpad + text + fill * (total - n - lpad);
}

def format_float(f: float, spec: str) -> str {
    try {
        return format(f, spec);
    } except ValueError as e {
        raise ct_exc("ValueError", str(e));
    }
}

def ct_format(v: CtValue, spec: str) -> str {
    if not spec {
        return ct_str(v);
    }
    if isinstance(v, CtInt) {
        return format_int(v, spec, "int");
    }
    if isinstance(v, CtBool) {
        return format_int(CtInt(small=1 if v.value else 0), spec, "bool");
    }
    if isinstance(v, CtFloat) {
        return format_float(v.value, spec);
    }
    if isinstance(v, CtStr) {
        return format_str(v.value, spec);
    }
    raise ct_exc(
        "TypeError", f"unsupported format string passed to {ct_type_name(v)}.__format__"
    );
}

def ct_convert(v: CtValue, conv: str) -> CtValue {
    if conv == "r" {
        return mk_str(ct_repr(v));
    }
    if conv == "s" {
        return mk_str(ct_str(v));
    }
    if conv == "a" {
        return mk_str(ascii_escape(ct_repr(v)));
    }
    return v;
}

def _percent_int_digits(
    v: CtInt, conv: str, prec: int, alternate: bool
) -> tuple[bool, str, str] {
    base = 10;
    prefix = "";
    if conv == "o" {
        base = 8;
        prefix = "0o";
    } elif conv in ("x", "X") {
        base = 16;
        prefix = "0x";
    }
    digits = int_to_base_str(v, base);
    if prec > len(digits) {
        digits = "0" * (prec - len(digits)) + digits;
    }
    if not alternate {
        prefix = "";
    }
    if conv == "X" {
        digits = digits.upper();
        prefix = prefix.upper();
    }
    return (int_is_neg(v), prefix, digits);
}

def _percent_number_arg(v: CtValue, conv: str) -> CtInt {
    iv = as_ct_int(v);
    if iv is not None {
        return iv;
    }
    if isinstance(v, CtFloat) and conv in ("d", "i", "u") {
        return float_to_ct_int(v.value);
    }
    if conv in ("d", "i", "u") {
        raise ct_exc(
            "TypeError",
            f"%{conv} format: a real number is required, not {ct_type_name(v)}"
        );
    }
    raise ct_exc(
        "TypeError", f"%{conv} format: an integer is required, not {ct_type_name(v)}"
    );
}

def ct_percent_format(fmt: str, args: CtValue) -> str {
    items: list[CtValue] = [];
    mapping: (CtValue | None) = None;
    if isinstance(args, CtTuple) {
        items = args.items;
    } else {
        items = [args];
        if isinstance(args, (CtDict, CtList)) {
            mapping = args;
        }
    }
    argidx = 0;
    out = "";
    i = 0;
    n = len(fmt);
    while i < n {
        ch = fmt[i];
        if ch != "%" {
            j = fmt.find("%", i);
            if j < 0 {
                j = n;
            }
            out += fmt[i:j];
            i = j;
            continue;
        }
        i += 1;
        if i >= n {
            raise ct_exc("ValueError", "incomplete format");
        }
        key_val: (CtValue | None) = None;
        if fmt[i] == "(" {
            if mapping is None {
                raise ct_exc("TypeError", "format requires a mapping");
            }
            depth = 1;
            i += 1;
            kstart = i;
            while i < n and depth > 0 {
                if fmt[i] == "(" {
                    depth += 1;
                } elif fmt[i] == ")" {
                    depth -= 1;
                }
                i += 1;
            }
            if depth > 0 {
                raise ct_exc("ValueError", "incomplete format key");
            }
            key_val = ct_getitem(mapping, mk_str(fmt[kstart:i - 1]));
        }
        flags = "";
        while i < n and fmt[i] in "-+ #0" {
            flags += fmt[i];
            i += 1;
        }
        width = -1;
        if i < n and fmt[i] == "*" {
            if argidx >= len(items) {
                raise ct_exc("TypeError", "not enough arguments for format string");
            }
            wv = as_ct_int(items[argidx]);
            argidx += 1;
            if wv is None {
                raise ct_exc("TypeError", "* wants int");
            }
            width = wv.small;
            if width < 0 {
                flags += "-";
                width = -width;
            }
            i += 1;
        } else {
            (width, i) = _read_int(fmt, i);
        }
        prec = -1;
        if i < n and fmt[i] == "." {
            i += 1;
            if i < n and fmt[i] == "*" {
                if argidx >= len(items) {
                    raise ct_exc("TypeError", "not enough arguments for format string");
                }
                pv = as_ct_int(items[argidx]);
                argidx += 1;
                if pv is None {
                    raise ct_exc("TypeError", "* wants int");
                }
                prec = max(pv.small, 0);
                i += 1;
            } else {
                (prec, i) = _read_int(fmt, i);
                if prec < 0 {
                    prec = 0;
                }
            }
        }
        while i < n and fmt[i] in "hlL" {
            i += 1;
        }
        if i >= n {
            raise ct_exc("ValueError", "incomplete format");
        }
        conv = fmt[i];
        i += 1;
        if conv == "%" {
            out += "%";
            continue;
        }
        if key_val is not None {
            arg = key_val;
        } else {
            if argidx >= len(items) {
                raise ct_exc("TypeError", "not enough arguments for format string");
            }
            arg = items[argidx];
            argidx += 1;
        }
        ljust = "-" in flags;
        zero = "0" in flags and not ljust;
        if conv in ("s", "r", "a") {
            text = ct_str(arg) if conv == "s" else ct_repr(arg);
            if conv == "a" {
                text = ascii_escape(text);
            }
            if prec >= 0 {
                text = text[:prec];
            }
            out += pad_text(text, width, "<" if ljust else ">", " ");
        } elif conv in ("d", "i", "u", "o", "x", "X") {
            iv = _percent_number_arg(arg, conv);
            (neg, prefix, digits) = _percent_int_digits(iv, conv, prec, "#" in flags);
            sign = "-"
                if neg
                else ("+" if "+" in flags else (" " if " " in flags else ""));
            body = sign + prefix + digits;
            if width > len(body) {
                if ljust {
                    body = body + " " * (width - len(body));
                } elif zero {
                    body = sign + prefix + "0" * (width - len(body)) + digits;
                } else {
                    body = " " * (width - len(body)) + body;
                }
            }
            out += body;
        } elif conv in ("e", "E", "f", "F", "g", "G") {
            if isinstance(arg, CtFloat) {
                fv = arg.value;
            } else {
                iv2 = as_ct_int(arg);
                if iv2 is None {
                    raise ct_exc(
                        "TypeError", f"must be real number, not {ct_type_name(arg)}"
                    );
                }
                fv = int_to_float(iv2);
            }
            spec = "<" if ljust else "";
            if "+" in flags {
                spec += "+";
            } elif " " in flags {
                spec += " ";
            }
            if "#" in flags {
                spec += "#";
            }
            if zero {
                spec += "0";
            }
            if width >= 0 {
                spec += str(width);
            }
            spec += "." + str(prec if prec >= 0 else 6) + conv;
            out += format_float(fv, spec);
        } elif conv == "c" {
            civ = as_ct_int(arg);
            if civ is not None {
                if civ.mag or civ.small < 0 or civ.small > 1114111 {
                    raise ct_exc("OverflowError", "%c arg not in range(0x110000)");
                }
                text2 = chr(civ.small);
            } elif isinstance(arg, CtStr) and len(arg.value) == 1 {
                text2 = arg.value;
            } elif isinstance(arg, CtStr) {
                raise ct_exc(
                    "TypeError",
                    f"%c requires an int or a unicode character, not a string of length {len(
                        arg.value
                    )}"
                );
            } else {
                raise ct_exc(
                    "TypeError",
                    f"%c requires an int or a unicode character, not {ct_type_name(
                        arg
                    )}"
                );
            }
            out += pad_text(text2, width, "<" if ljust else ">", " ");
        } else {
            raise ct_exc(
                "ValueError",
                f"unsupported format character '{conv}' ({hex(ord(conv))}) at index {i
                    - 1}"
            );
        }
    }
    if argidx < len(items) and mapping is None {
        raise ct_exc(
            "TypeError", "not all arguments converted during string formatting"
        );
    }
    return out;
}

obj CtFormatState {
    has args: list[CtValue],
        kwargs: dict[str, CtValue],
        auto_idx: int = 0,
        mode: str = "";
}

def ct_str_format(fmt: str, args: list[CtValue], kwargs: dict[str, CtValue]) -> str {
    return _str_format(fmt, CtFormatState(args=args, kwargs=kwargs), 2);
}

def _str_format(fmt: str, st: CtFormatState, depth: int) -> str {
    if depth < 0 {
        raise ct_exc("ValueError", "Max string recursion exceeded");
    }
    out = "";
    i = 0;
    n = len(fmt);
    while i < n {
        ch = fmt[i];
        if ch == "}" {
            if i + 1 < n and fmt[i + 1] == "}" {
                out += "}";
                i += 2;
                continue;
            }
            raise ct_exc("ValueError", "Single '}' encountered in format string");
        }
        if ch != "{" {
            out += ch;
            i += 1;
            continue;
        }
        if i + 1 < n and fmt[i + 1] == "{" {
            out += "{";
            i += 2;
            continue;
        }
        if i + 1 >= n {
            raise ct_exc("ValueError", "Single '{' encountered in format string");
        }
        j = i + 1;
        nest = 1;
        while j < n {
            if fmt[j] == "{" {
                nest += 1;
            } elif fmt[j] == "}" {
                nest -= 1;
                if nest == 0 {
                    break;
                }
            }
            j += 1;
        }
        if j >= n {
            raise ct_exc("ValueError", "expected '}' before end of string");
        }
        field = fmt[i + 1:j];
        i = j + 1;
        out += _render_field(field, st, depth);
    }
    return out;
}

def _render_field(field: str, st: CtFormatState, depth: int) -> str {
    k = 0;
    while k < len(field) and field[k] not in "!:" {
        if field[k] == "[" {
            while k < len(field) and field[k] != "]" {
                k += 1;
            }
        }
        k += 1;
    }
    k = min(k, len(field));
    name = field[:k];
    conv = "";
    spec = "";
    rest = field[k:];
    if rest.startswith("!") {
        if len(rest) < 2 {
            raise ct_exc(
                "ValueError", "end of string while looking for conversion specifier"
            );
        }
        conv = rest[1];
        rest = rest[2:];
        if rest and not rest.startswith(":") {
            raise ct_exc("ValueError", "expected ':' after conversion specifier");
        }
    }
    if rest.startswith(":") {
        spec = rest[1:];
    }
    value = _field_value(name, st);
    if conv {
        if conv not in ("r", "s", "a") {
            raise ct_exc("ValueError", f"Unknown conversion specifier {conv}");
        }
        value = ct_convert(value, conv);
    }
    if "{" in spec {
        spec = _str_format(spec, st, depth - 1);
    }
    return ct_format(value, spec);
}

def _field_value(name: str, st: CtFormatState) -> CtValue {
    k = 0;
    while k < len(name) and name[k] not in ".[" {
        k += 1;
    }
    head = name[:k];
    tail = name[k:];
    if not head {
        if st.mode == "manual" {
            raise ct_exc(
                "ValueError",
                "cannot switch from manual field specification to automatic field numbering"
            );
        }
        st.mode = "auto";
        idx = st.auto_idx;
        st.auto_idx += 1;
        value = _positional(st, idx);
    } elif head.isdigit() {
        if st.mode == "auto" {
            raise ct_exc(
                "ValueError",
                "cannot switch from automatic field numbering to manual field specification"
            );
        }
        st.mode = "manual";
        value = _positional(st, int(head));
    } else {
        if head not in st.kwargs {
            raise ct_exc_value("KeyError", mk_str(head));
        }
        value = st.kwargs[head];
    }
    while tail {
        if tail.startswith(".") {
            m = 1;
            while m < len(tail) and tail[m] not in ".[" {
                m += 1;
            }
            attr = tail[1:m];
            tail = tail[m:];
            value = _format_attr(value, attr);
        } elif tail.startswith("[") {
            close = tail.find("]");
            if close < 0 {
                raise ct_exc("ValueError", "Missing ']' in format string");
            }
            key = tail[1:close];
            tail = tail[close + 1:];
            if key.isdigit() {
                from_int = int(key);
                value = ct_getitem(value, CtInt(small=from_int));
            } else {
                value = ct_getitem(value, mk_str(key));
            }
        } else {
            raise ct_exc(
                "ValueError", "Only '.' or '[' may follow ']' in format field specifier"
            );
        }
    }
    return value;
}

def _positional(st: CtFormatState, idx: int) -> CtValue {
    if idx >= len(st.args) {
        raise ct_exc(
            "IndexError",
            f"Replacement index {idx} out of range for positional args tuple"
        );
    }
    return st.args[idx];
}

def _format_attr(value: CtValue, attr: str) -> CtValue {
    if isinstance(value, CtRecord) and attr in value.fields {
        return value.fields[attr];
    }
    if isinstance(value, CtEnumMember) {
        if attr == "name" {
            return mk_str(value.member);
        }
        if attr == "value" {
            return value.value;
        }
    }
    raise CtError(
        f"attribute '{attr}' in a str.format field is not supported in comptime code"
    );
}

def ct_binary(sym: str, l: CtValue, r: CtValue) -> CtValue {
    if sym == "%" and isinstance(l, CtStr) {
        return mk_str(ct_percent_format(l.value, r));
    }
    return ct_binop(sym, l, r);
}

def ct_inplace(sym: str, cur: CtValue, val: CtValue) -> CtValue {
    if sym == "+" and isinstance(cur, CtList) {
        cur.items.extend(ct_iter(val));
        return cur;
    }
    if sym == "*" and isinstance(cur, CtList) {
        n = as_ct_int(val);
        if n is None {
            raise ct_exc(
                "TypeError",
                f"can't multiply sequence by non-int of type '{ct_type_name(val)}'"
            );
        }
        if n.mag {
            raise ct_exc(
                "OverflowError", "cannot fit 'int' into an index-sized integer"
            );
        }
        cur.items = cur.items * max(n.small, 0);
        return cur;
    }
    if sym in ("|", "&", "-", "^")
        and isinstance(cur, CtSet)
        and not cur.frozen
        and isinstance(val, CtSet) {
        res = set_algebra(sym, cur, val, False);
        cur.items = res.items;
        cur.index = res.index;
        return cur;
    }
    if sym == "|" and isinstance(cur, CtDict) and isinstance(val, CtDict) {
        for (i, k) in enumerate(val.keys) {
            dict_set(cur, k, val.vals[i]);
        }
        return cur;
    }
    return ct_binary(sym, cur, val);
}
