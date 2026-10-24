impl UniScopeNode.is_python_scoping(nd: (UniNode | None)) -> bool {
    return isinstance(
        nd, (Module, Enum, Archetype, Ability, ImplDef, Test, LambdaExpr)
    );
}

impl Module.make_stub(
    inject_name: (str | None) = None, inject_src: (Source | None) = None
) -> Module {
    return Module(
        name=(inject_name or ''),
        source=(inject_src or Source('', '')),
        doc=None,
        body=[],
        terminals=[],
        stub_only=True,
        kid=[EmptyToken()]
    );
}

impl Name.gen_stub_from_node(
    nd: AstSymbolNode, name_str: str, set_name_of: (AstSymbolNode | None) = None
) -> Name {
    ret = Name(
        orig_src=nd.loc.orig_src,
        name=Tok.NAME.value,
        value=name_str,
        col_start=nd.loc.col_start,
        col_end=nd.loc.col_end,
        line=nd.loc.first_line,
        end_line=nd.loc.last_line,
        pos_start=nd.loc.pos_start,
        pos_end=nd.loc.pos_end
    );
    if nd.parent is not None {
        ret.set_parent(nd.parent);
    }
    ret.name_of = set_name_of or ret;
    return ret;
}

impl _lit_prefix_len(text: str) -> int {
    n = len(text);
    i = 0;
    while (i < n and i < 2) {
        ch = text[i];
        if (ch == '"' or ch == "'") {
            return i;
        }
        if (ch not in _LIT_PREFIX_CHARS) {
            return -1;
        }
        i += 1;
    }
    if (i < n and (text[i] == '"' or text[i] == "'")) {
        return i;
    }
    return -1;
}

impl _lit_quote_len(text: str, start: int) -> int {
    if ((len(text) - start) >= 6) {
        opener = text[start:start + 3];
        if (opener == '"""' or opener == "'''") {
            return 3;
        }
    }
    return 1;
}

impl radix_int(digits: str, base: int) -> int {
    value = 0;
    seen = False;
    for c in digits.lower() {
        if c == "_" and seen {
            continue;
        }
        digit = _RADIX_DIGITS.find(c);
        if digit < 0 or digit >= base {
            raise ValueError(f"invalid literal for int() with base {base}: '{digits}'");
        }
        value = value * base + digit;
        seen = True;
    }
    if not seen {
        raise ValueError(f"invalid literal for int() with base {base}: '{digits}'");
    }
    return value;
}

impl int_literal_digits(text: str) -> tuple[str, int] {
    lowered = text.lower();
    for (prefix, base) in (("0x", 16), ("0o", 8), ("0b", 2)) {
        if lowered.startswith(prefix) {
            body = text[2:];
            if body.startswith("_") {
                body = body[1:];
            }
            return (body, base);
        }
    }
    digits = text.replace("_", "");
    if len(digits) > 1 and digits.startswith("0") and digits.strip("0") {
        raise ValueError(f"invalid literal for int() with base 0: '{text}'");
    }
    return (text, 10);
}

impl int_literal_value(text: str) -> int {
    (body, base) = int_literal_digits(text);
    return radix_int(body, base);
}

impl int_literal_limbs(text: str) -> (tuple[int, int] | None) {
    """The literal as two 32-bit halves `(high, low)`, or None past 64 bits.
    No intermediate leaves 37 bits, so the native compiler, whose int is 64
    bits, reads every literal the way the bytecode compiler does.""";
    (body, base) = int_literal_digits(text);
    high = 0;
    low = 0;
    seen = False;
    for c in body.lower() {
        if c == "_" and seen {
            continue;
        }
        digit = _RADIX_DIGITS.find(c);
        if digit < 0 or digit >= base {
            raise ValueError(f"invalid literal for int() with base {base}: '{body}'");
        }
        low = low * base + digit;
        high = high * base + (low >> 32);
        low = low & 4294967295;
        if high > 4294967295 {
            return None;
        }
        seen = True;
    }
    if not seen {
        raise ValueError(f"invalid literal for int() with base {base}: '{body}'");
    }
    return (high, low);
}

impl int_literal_i64(text: str) -> (int | None) {
    limbs = int_literal_limbs(text);
    if limbs is None or limbs[0] >= 2147483648 {
        return None;
    }
    return limbs[0] * 4294967296 + limbs[1];
}

impl int_literal_u64_bits(text: str) -> (int | None) {
    """The literal's 64-bit two's-complement pattern, as the signed int that
    holds it, when it fits an unsigned 64-bit int: `0xFFFF_FFFF_FFFF_FFFF`
    is -1. None past 64 bits.""";
    limbs = int_literal_limbs(text);
    if limbs is None {
        return None;
    }
    (high, low) = limbs;
    if high >= 2147483648 {
        return (high - 4294967296) * 4294967296 + low;
    }
    return high * 4294967296 + low;
}

impl int_literal_float(text: str) -> float {
    """The literal's value as a float, without forming the integer: a literal
    past 64 bits still has one (`x: f64 = 9223372036854775808`).""";
    (body, base) = int_literal_digits(text);
    if base == 10 {
        return float(body.replace("_", ""));
    }
    total = 0.0;
    for c in body.lower() {
        if c != "_" {
            total = total * base + _RADIX_DIGITS.find(c);
        }
    }
    return total;
}

impl _hex_escape_value(text: str, at: int, width: int, kind: str) -> int {
    digits = text[at + 2:at + 2 + width];
    bad = len(digits) != width;
    if not bad {
        for c in digits {
            if (c not in _HEX_DIGITS) {
                bad = True;
                break;
            }
        }
    }
    if bad {
        raise ValueError(
            f"truncated \\{kind} escape: expected {width} hex digits, got '{digits}'"
        );
    }
    code = radix_int(digits, 16);
    if (code > _MAX_CODE_POINT) {
        raise ValueError(f"illegal Unicode character in \\{kind}{digits} escape");
    }
    return code;
}

impl _decode_str_escapes(text: str) -> str {
    if ('\\' not in text) {
        return text;
    }
    out: list[str] = [];
    i = 0;
    n = len(text);
    while (i < n) {
        ch = text[i];
        if (ch != '\\' or (i + 1) >= n) {
            out.append(ch);
            i += 1;
            continue;
        }
        nxt = text[i + 1];
        if (nxt in _SIMPLE_ESCAPES) {
            out.append(_SIMPLE_ESCAPES[nxt]);
            i += 2;
            continue;
        }
        if (nxt == '\n') {
            i += 2;
            continue;
        }
        if (nxt == '\r') {
            i += 3 if ((i + 2) < n and text[i + 2] == '\n') else 2;
            continue;
        }
        if (nxt in _OCT_DIGITS) {
            j = i + 1;
            end = min(n, i + 4);
            while (j < end and text[j] in _OCT_DIGITS) {
                j += 1;
            }
            out.append(chr(radix_int(text[i + 1:j], 8)));
            i = j;
            continue;
        }
        if (nxt == 'x' or nxt == 'u' or nxt == 'U') {
            width = 2 if (nxt == 'x') else (4 if (nxt == 'u') else 8);
            out.append(chr(_hex_escape_value(text, i, width, nxt)));
            i += 2 + width;
            continue;
        }
        if (nxt == 'N') {
            raise ValueError(
                "the \\N{name} escape is not supported: the Unicode name "
                "database is not available to the compiler, so write the "
                "code point as \\uXXXX or \\UXXXXXXXX instead"
            );
        }
        out.append('\\');
        out.append(nxt);
        i += 2;
    }
    return ''.join(out);
}

impl _decode_bytes_escapes(text: str, is_raw: bool) -> bytes {
    out: list[int] = [];
    i = 0;
    n = len(text);
    while (i < n) {
        ch = text[i];
        code = ord(ch);
        if (code > 127) {
            raise ValueError('bytes can only contain ASCII literal characters');
        }
        if (is_raw or ch != '\\' or (i + 1) >= n) {
            out.append(code);
            i += 1;
            continue;
        }
        nxt = text[i + 1];
        if (nxt in _SIMPLE_ESCAPES) {
            out.append(ord(_SIMPLE_ESCAPES[nxt]));
            i += 2;
            continue;
        }
        if (nxt == '\n') {
            i += 2;
            continue;
        }
        if (nxt == '\r') {
            i += 3 if ((i + 2) < n and text[i + 2] == '\n') else 2;
            continue;
        }
        if (nxt in _OCT_DIGITS) {
            j = i + 1;
            end = min(n, i + 4);
            while (j < end and text[j] in _OCT_DIGITS) {
                j += 1;
            }
            out.append(radix_int(text[i + 1:j], 8) % 256);
            i = j;
            continue;
        }
        if (nxt == 'x') {
            out.append(_hex_escape_value(text, i, 2, 'x'));
            i += 4;
            continue;
        }
        if (ord(nxt) > 127) {
            raise ValueError('bytes can only contain ASCII literal characters');
        }
        out.append(92);
        out.append(ord(nxt));
        i += 2;
    }
    return bytes(out);
}

impl literal_string_value(expr: UniNode) -> str | None {
    if isinstance(expr, (String, MultiString)) {
        value = expr.lit_value;
        if isinstance(value, str) {
            return value;
        }
    }
    return None;
}

impl decode_string_literal(text: str) -> str | bytes {
    start = _lit_prefix_len(text);
    if (start < 0) {
        return text;
    }
    prefix = text[:start].lower();
    quote_len = _lit_quote_len(text, start);
    body = text[start + quote_len:len(text) - quote_len];
    is_raw = 'r' in prefix;
    if ('b' in prefix) {
        return _decode_bytes_escapes(body, is_raw);
    }
    if is_raw {
        return body;
    }
    return _decode_str_escapes(body);
}
