impl NativeLowering._struct_call_layout(
    nd: uni.FuncCall, params: Sequence[any]
) -> (tuple[list[tuple[str, int, bool]], int, bool] | None) {
    _fnode = params[0];
    if isinstance(_fnode, uni.MultiString) and len(_fnode.strings) == 1 {
        _fnode = _fnode.strings[0];
    }
    fmt: (str | None) = None;
    if isinstance(_fnode, uni.String) {
        _lv = _fnode.lit_value;
        if isinstance(_lv, str) {
            fmt = _lv;
        }
    }
    if fmt is None {
        self.emit(
            E5092, node_override=nd, kind="struct format", name="non-literal format"
        );
        return None;
    }

    little = True;
    fmt_body = fmt;
    if len(fmt) > 0 and fmt[0] in "<>=!@" {
        little = fmt[0] in "<=@";
        fmt_body = fmt[1:];
    }
    int_sizes = {
        "b": 1,
        "B": 1,
        "h": 2,
        "H": 2,
        "i": 4,
        "I": 4,
        "l": 4,
        "L": 4,
        "q": 8,
        "Q": 8,
        "n": 8,
        "N": 8
    };
    signed_codes = {"b", "h", "i", "l", "q", "n"};
    float_sizes = {"f": 4, "d": 8};
    fields: list[tuple[str, int, bool]] = [];
    total = 0;
    i = 0;
    count_str = "";
    parse_ok = True;
    while i < len(fmt_body) {
        ch = fmt_body[i];
        if ch.isdigit() {
            count_str = count_str + ch;
            i = i + 1;
            continue;
        }
        rep = int(count_str) if count_str else 1;
        count_str = "";
        if ch == "x" {
            for _r in range(rep) {
                fields.append(("pad", 1, False));
                total = total + 1;
            }
        } elif ch in int_sizes {
            _sz = int_sizes[ch];
            for _r in range(rep) {
                fields.append(("int", _sz, ch in signed_codes));
                total = total + _sz;
            }
        } elif ch in float_sizes {
            _sz = float_sizes[ch];
            for _r in range(rep) {
                fields.append(("float", _sz, False));
                total = total + _sz;
            }
        } elif ch == " " {} else {
            parse_ok = False;
            break;
        }
        i = i + 1;
    }
    if not parse_ok {
        self.emit(E5092, node_override=nd, kind="struct format code", name=fmt);
        return None;
    }
    return (fields, total, little);
}

impl NativeLowering._struct_pack_arity_ok(
    nd: uni.FuncCall,
    params: Sequence[uni.Expr | uni.KWPair],
    fields: list[tuple[str, int, bool]]
) -> bool {
    _expected = len(
        [
            f
            for f in fields
            if f[0] != "pad"
        ]
    );
    if len(params) - 1 != _expected {
        self.emit(
            E5092,
            node_override=nd,
            kind="struct.pack argument count",
            name=f"expected {_expected}, got {len(params) - 1}"
        );
        return False;
    }
    return True;
}
