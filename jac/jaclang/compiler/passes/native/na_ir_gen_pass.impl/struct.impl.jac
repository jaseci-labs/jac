impl NaIRGenPass._emit_struct_call(name: str, nd: uni.FuncCall) -> (ir.Value | None) {
    params = nd.params or [];
    if not params {
        return None;
    }

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
    fields: list = [];
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
        } elif ch == " " { } else {
            parse_ok = False;
            break;
        }
        i = i + 1;
    }
    if not parse_ok {
        self.emit(E5092, node_override=nd, kind="struct format code", name=fmt);
        return None;
    }
    i64 = ir.IntType(64);
    if name == "calcsize" {
        return ir.Constant(i64, total);
    }
    if name == "pack" {
        return self._emit_struct_pack(nd, params, fields, total, little);
    }
    if name == "unpack" {
        return self._emit_struct_unpack(nd, params, fields, total, little);
    }
    if name == "pack_into" {
        return self._emit_struct_pack_into(nd, params, fields, total, little);
    }
    return None;
}

impl NaIRGenPass._emit_struct_pack(
    nd: uni.FuncCall, params: list, fields: list, total: int, little: bool
) -> (ir.Value | None) {
    b = self.builder;
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    f32 = ir.FloatType();
    f64 = ir.DoubleType();

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
        return None;
    }
    arg_vals: list = [];
    for p in params[1:] {
        v = self._codegen_expr(p);
        if v is not None {
            arg_vals.append(v);
        }
    }
    bv = self._bytes_alloc(ir.Constant(i64, total));
    data = self._bytes_data_ptr(bv);
    off = 0;
    ai = 0;
    for (kind, sz, signed) in fields {
        if kind == "pad" {
            ptr = b.gep(data, [ir.Constant(i64, off)], name="pk.pad");
            b.store(ir.Constant(i8, 0), ptr);
            off = off + 1;
            continue;
        }
        if ai >= len(arg_vals) {
            break;
        }
        raw = arg_vals[ai];
        ai = ai + 1;

        bits: ir.Value = ir.Constant(i64, 0);
        if kind == "float" and sz == 4 {
            fv = self._coerce_type(raw, f64);
            small = b.fptrunc(fv, f32, name="pk.f32");
            asi = b.bitcast(small, i32, name="pk.f32.bits");
            bits = b.zext(asi, i64, name="pk.f32.ext");
        } elif kind == "float" {
            fv = self._coerce_type(raw, f64);
            bits = b.bitcast(fv, i64, name="pk.f64.bits");
        } else {
            bits = self._coerce_type(raw, i64);
        }
        for k in range(sz) {
            shifted = b.lshr(bits, ir.Constant(i64, k * 8), name="pk.sh");
            byte = b.trunc(shifted, i8, name="pk.byte");
            pos = off + (k if little else (sz - 1 - k));
            ptr = b.gep(data, [ir.Constant(i64, pos)], name="pk.ptr");
            b.store(byte, ptr);
        }
        off = off + sz;
    }
    return bv;
}

impl NaIRGenPass._emit_struct_unpack(
    nd: uni.FuncCall, params: list, fields: list, total: int, little: bool
) -> (ir.Value | None) {
    if len(params) < 2 {
        return None;
    }
    b = self.builder;
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    f32 = ir.FloatType();
    f64 = ir.DoubleType();
    data_val = self._codegen_expr(params[1]);
    if data_val is None or not self._is_bytes_value(data_val) {
        self.emit(
            E5092,
            node_override=nd,
            kind="struct.unpack buffer",
            name="non-bytes buffer"
        );
        return None;
    }

    buf_len = self._bytes_len_val(data_val);
    too_short = self.builder.icmp_signed(
        "<", buf_len, ir.Constant(ir.IntType(64), total), name="up.short"
    );
    self._emit_runtime_raise(
        too_short, "struct.error", f"unpack requires a buffer of {total} bytes"
    );
    data = self._bytes_data_ptr(data_val);

    values: list = [];
    elem_types: list = [];
    off = 0;
    for (kind, sz, signed) in fields {
        if kind == "pad" {
            off = off + 1;
            continue;
        }
        acc: ir.Value = ir.Constant(i64, 0);
        for k in range(sz) {
            pos = off + (k if little else (sz - 1 - k));
            ptr = b.gep(data, [ir.Constant(i64, pos)], name="up.ptr");
            byte = b.load(ptr, name="up.byte");
            ext = b.zext(byte, i64, name="up.ext");
            if k == 0 {
                acc = ext;
            } else {
                sh = b.shl(ext, ir.Constant(i64, k * 8), name="up.sh");
                acc = b.or_(acc, sh, name="up.acc");
            }
        }
        off = off + sz;
        if kind == "float" and sz == 4 {
            asi = b.trunc(acc, i32, name="up.f32.bits");
            small = b.bitcast(asi, f32, name="up.f32");
            values.append(b.fpext(small, f64, name="up.f64"));
            elem_types.append(f64);
        } elif kind == "float" {
            values.append(b.bitcast(acc, f64, name="up.f64.bc"));
            elem_types.append(f64);
        } else {
            if signed and sz < 8 {
                shamt = ir.Constant(i64, 64 - sz * 8);
                acc = b.ashr(b.shl(acc, shamt, name="up.sxl"), shamt, name="up.sx");
            }
            values.append(acc);
            elem_types.append(i64);
        }
    }

    tuple_type = ir.LiteralStructType(elem_types);
    null_ptr = ir.Constant(tuple_type.as_pointer(), None);
    size_gep = b.gep(null_ptr, [ir.Constant(i32, 1)], name="up.sizeof.gep");
    size = b.ptrtoint(size_gep, i64, name="up.sizeof");
    raw = self._rc_call_with_ctx(
        self.rc_alloc_fn, [size], op="struct_unpack", loc="", name="up.tuple.raw"
    );
    tup = b.bitcast(raw, tuple_type.as_pointer(), name="up.tuple");
    n = 0;
    for v in values {
        ptr = b.gep(tup, [ir.Constant(i32, 0), ir.Constant(i32, n)], name="up.fld");
        b.store(v, ptr);
        n = n + 1;
    }
    tkey = "struct." + ".".join([str(t) for t in elem_types]);
    if tkey not in self.tuple_types {
        self.tuple_types[tkey] = tuple_type;
    }
    self._mark_owned(tup);
    return tup;
}
