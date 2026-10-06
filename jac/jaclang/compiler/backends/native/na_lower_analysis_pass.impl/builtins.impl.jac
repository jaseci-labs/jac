impl NativeLowering._print_stream_name(value: uni.Expr) -> (str | None) {
    if not isinstance(value, uni.AtomTrailer) {
        return None;
    }
    chain = value.as_attr_list;
    if len(chain) != 2 or chain[0].sym_name != "sys" {
        return None;
    }
    if chain[1].sym_name == "stdout" {
        return "stdout";
    }
    if chain[1].sym_name == "stderr" {
        return "stderr";
    }
    return None;
}

impl NativeLowering._fstring_spec_text(spec: uni.Expr) -> (str | None) {
    import from jaclang.compiler.passes.capability_check_pass {
        static_fstring_spec_text
    }
    return static_fstring_spec_text(spec);
}

impl NativeLowering._fstring_spec_to_printf(
    spec: str, kind: str
) -> (tuple[str, str] | None) {
    fill: (str | None) = None;
    align: (str | None) = None;
    i = 0;
    n = len(spec);
    if n >= 2 and spec[1] in "<>^=" {
        fill = spec[0];
        align = spec[1];
        i = 2;
    } elif n >= 1 and spec[0] in "<>^=" {
        align = spec[0];
        i = 1;
    }
    sign: (str | None) = None;
    if i < n and spec[i] in "+ " {
        sign = spec[i];
        i += 1;
    } elif i < n and spec[i] == "-" {
        i += 1;
    }
    if i < n and spec[i] == "#" {
        return None;
    }
    zero = False;
    if i < n and spec[i] == "0" {
        zero = True;
        i += 1;
    }
    width = "";
    while i < n and spec[i].isdigit() {
        width += spec[i];
        i += 1;
    }
    if i < n and spec[i] == "," {
        return None;
    }
    prec = "";
    if i < n and spec[i] == "." {
        i += 1;
        while i < n and spec[i].isdigit() {
            prec += spec[i];
            i += 1;
        }
        if not prec {
            return None;
        }
    }
    type_ch = "";
    if i < n {
        type_ch = spec[i];
        i += 1;
    }
    if i != n or align in ("^", "=") {
        return None;
    }
    if fill is not None and fill != " " {
        return None;
    }
    left = align == "<";
    if kind == "str" and align is None {
        left = True;
    }
    flags = "";
    if left {
        flags += "-";
    }
    if sign is not None {
        flags += sign;
    }
    if zero and not left {
        flags += "0";
    }
    body = flags + width + (("." + prec) if prec else "");
    if kind == "int" {
        if prec {
            return None;
        }
        if type_ch in ("", "d") {
            return ("%" + body + "lld", "int");
        }
        if type_ch == "x" {
            return ("%" + body + "llx", "int");
        }
        if type_ch == "X" {
            return ("%" + body + "llX", "int");
        }
        if type_ch == "o" {
            return ("%" + body + "llo", "int");
        }
        if type_ch in ("f", "F", "e", "E", "g", "G") {
            return ("%" + body + type_ch, "float");
        }
        return None;
    }
    if kind == "float" {
        if type_ch in ("f", "F", "e", "E", "g", "G") {
            return ("%" + body + type_ch, "float");
        }
        if type_ch == "" and not zero and sign is None and not prec {
            return ("%" + body + "s", "repr");
        }
        return None;
    }
    if kind == "str" and type_ch in ("", "s") and not zero and sign is None {
        return ("%" + body + "s", "str");
    }
    return None;
}
