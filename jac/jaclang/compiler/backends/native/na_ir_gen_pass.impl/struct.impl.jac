impl NaIRGenPass._emit_struct_call(name: str, nd: uni.FuncCall) -> (ir.Value | None) {
    params: Sequence[any] = nd.params or [];
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
        } elif ch == "P" {
            for _r in range(rep) {
                fields.append(("int", 8, False));
                total = total + 8;
            }
        } elif ch == "?" {
            for _r in range(rep) {
                fields.append(("bool", 1, False));
                total = total + 1;
            }
        } elif ch == "c" {
            for _r in range(rep) {
                fields.append(("bytes", 1, False));
                total = total + 1;
            }
        } elif ch == "s" {
            fields.append(("bytes", rep, False));
            total = total + rep;
        } elif ch == "p" {
            fields.append(("pstr", rep, False));
            total = total + rep;
        } elif ch == "e" {
            for _r in range(rep) {
                fields.append(("half", 2, False));
                total = total + 2;
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
    if name == "unpack_from" {
        return self._emit_struct_unpack_from(nd, params, fields, total, little);
    }
    if name == "pack_into" {
        return self._emit_struct_pack_into(nd, params, fields, total, little);
    }
    return None;
}

impl NaIRGenPass._emit_struct_pack(
    nd: uni.FuncCall,
    params: Sequence[uni.Expr | uni.KWPair],
    fields: list[tuple[str, int, bool]],
    total: int,
    little: bool
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
    arg_vals: list[ir.Value] = [];
    for p in params[1:] {
        v = self._codegen_expr(p);
        if v is not None {
            arg_vals.append(v);
        }
    }
    bv = self._bytes_alloc(ir.Constant(i64, total));
    data = self._bytes_data_ptr(bv);
    if not self._emit_struct_pack_fields(nd, arg_vals, fields, little, data) {
        return None;
    }
    return bv;
}

impl NaIRGenPass._emit_struct_pack_fields(
    nd: uni.FuncCall,
    arg_vals: list[ir.Value],
    fields: list[tuple[str, int, bool]],
    little: bool,
    data: ir.Value
) -> bool {
    b = self.builder;
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    f32 = ir.FloatType();
    f64 = ir.DoubleType();
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

        if kind == "bytes" or kind == "pstr" {
            src_view = self._bytearray_src_of(raw);
            if src_view is None {
                self.ctx.emit(
                    E5092,
                    node_override=nd,
                    kind="struct.pack buffer field",
                    name="s/p/c formats require a bytes or bytearray argument"
                );
                return False;
            }
            src_ptr = src_view[0];
            src_len = src_view[1];
            if kind == "bytes" and sz == 1 {
                bad = b.icmp_signed(
                    "!=", src_len, ir.Constant(i64, 1), name="pk.c.len"
                );
                self._emit_runtime_raise(
                    bad,
                    "struct.error",
                    "char format requires a bytes object of length 1"
                );
            }
            memset_fn = self._get_or_declare_extern(
                "memset", i8.as_pointer(), [i8.as_pointer(), i32, i64]
            );
            if kind == "pstr" {
                if sz > 0 {
                    limit = ir.Constant(i64, sz - 1);
                    fits = b.icmp_signed("<", src_len, limit, name="pk.p.fits");
                    n_copy = b.select(fits, src_len, limit, name="pk.p.n");
                    dp0 = b.gep(data, [ir.Constant(i64, off)], name="pk.p.cnt");
                    b.store(b.trunc(n_copy, i8, name="pk.p.c8"), dp0);
                    dst = b.gep(data, [ir.Constant(i64, off + 1)], name="pk.p.dst");
                    b.call(
                        memset_fn, [dst, ir.Constant(i32, 0), ir.Constant(i64, sz - 1)]
                    );
                    self._emit_struct_copy_bytes(dst, src_ptr, n_copy);
                }
            } else {
                dst0 = b.gep(data, [ir.Constant(i64, off)], name="pk.s.dst0");
                b.call(memset_fn, [dst0, ir.Constant(i32, 0), ir.Constant(i64, sz)]);
                if sz > 0 {
                    limit = ir.Constant(i64, sz);
                    fits = b.icmp_signed("<", src_len, limit, name="pk.s.fits");
                    n_copy = b.select(fits, src_len, limit, name="pk.s.n");
                    dst = b.gep(data, [ir.Constant(i64, off)], name="pk.s.dst");
                    self._emit_struct_copy_bytes(dst, src_ptr, n_copy);
                }
            }
            off = off + sz;
            continue;
        }

        bits: ir.Value = ir.Constant(i64, 0);
        if kind == "float" and sz == 4 {
            fv = self._coerce_type(raw, f64);
            small = b.fptrunc(fv, f32, name="pk.f32");
            asi = b.bitcast(small, i32, name="pk.f32.bits");
            bits = b.zext(asi, i64, name="pk.f32.ext");
        } elif kind == "float" {
            fv = self._coerce_type(raw, f64);
            bits = b.bitcast(fv, i64, name="pk.f64.bits");
        } elif kind == "half" {
            fv = self._coerce_type(raw, f64);
            bits = self._emit_struct_f64_to_half(nd, fv);
        } elif kind == "bool" {
            iv = self._coerce_type(raw, i64);
            nz = b.icmp_signed("!=", iv, ir.Constant(i64, 0), name="pk.bool.nz");
            bits = b.zext(nz, i64, name="pk.bool.ext");
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
    return True;
}

impl NaIRGenPass._emit_struct_copy_bytes(dst: ir.Value, src: ir.Value, n: ir.Value) {
    i8p = ir.IntType(8).as_pointer();
    memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, ir.IntType(64)]);
    self.builder.call(memcpy_fn, [dst, src, n]);
}

impl NaIRGenPass._emit_struct_decode(
    fields: list[tuple[str, int, bool]], little: bool, data: ir.Value
) -> tuple[list[ir.Value], list[ir.Type]] {
    b = self.builder;
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    f32 = ir.FloatType();
    f64 = ir.DoubleType();
    values: list[ir.Value] = [];
    elem_types: list[ir.Type] = [];
    off = 0;
    for (kind, sz, signed) in fields {
        if kind == "pad" {
            off = off + 1;
            continue;
        }
        if kind == "bytes" {
            bv = self._bytes_alloc(ir.Constant(i64, sz));
            dst = self._bytes_data_ptr(bv);
            if sz > 0 {
                src = b.gep(data, [ir.Constant(i64, off)], name="up.s.src");
                self._emit_struct_copy_bytes(dst, src, ir.Constant(i64, sz));
            }
            values.append(bv);
            elem_types.append(bv.type);
            off = off + sz;
            continue;
        }
        if kind == "pstr" {
            cnt_ptr = b.gep(data, [ir.Constant(i64, off)], name="up.p.cp");
            cnt8 = b.load(cnt_ptr, name="up.p.c8");
            cnt = b.zext(cnt8, i64, name="up.p.cnt");
            limit = ir.Constant(i64, sz - 1);
            fits = b.icmp_signed("<", cnt, limit, name="up.p.fits");
            n_out = b.select(fits, cnt, limit, name="up.p.n");
            if sz <= 1 {
                n_out = ir.Constant(i64, 0);
            }
            bv = self._bytes_alloc(n_out);
            dst = self._bytes_data_ptr(bv);
            src = b.gep(data, [ir.Constant(i64, off + 1)], name="up.p.src");
            self._emit_struct_copy_bytes(dst, src, n_out);
            values.append(bv);
            elem_types.append(bv.type);
            off = off + sz;
            continue;
        }
        if kind == "bool" {
            ptr = b.gep(data, [ir.Constant(i64, off)], name="up.b.ptr");
            byte = b.load(ptr, name="up.b.byte");
            flag = b.icmp_signed("!=", byte, ir.Constant(i8, 0), name="up.b.nz");
            values.append(flag);
            elem_types.append(ir.IntType(1));
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
        } elif kind == "half" {
            values.append(self._emit_struct_half_to_f64(acc));
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
    return (values, elem_types);
}

impl NaIRGenPass._emit_struct_tuple(
    values: list[ir.Value], elem_types: list[ir.Type]
) -> ir.Value {
    b = self.builder;
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    tuple_type = ir.LiteralStructType(elem_types);
    null_ptr = ir.Constant(tuple_type.as_pointer(), None);
    size_gep = b.gep(null_ptr, [ir.Constant(i32, 1)], name="up.sizeof.gep");
    size = b.ptrtoint(size_gep, i64, name="up.sizeof");
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    _alloc_fn = self.rc_alloc_fn;
    assert _alloc_fn is not None , "rc helpers are emitted before struct unpack";
    raw = self._rc_call_with_ctx(
        _alloc_fn, [size], op="struct_unpack", loc="", name="up.tuple.raw"
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

impl NaIRGenPass._emit_struct_unpack(
    nd: uni.FuncCall,
    params: Sequence[uni.Expr | uni.KWPair],
    fields: list[tuple[str, int, bool]],
    total: int,
    little: bool
) -> (ir.Value | None) {
    if len(params) < 2 {
        return None;
    }
    i64 = ir.IntType(64);
    data_val = self._codegen_expr(params[1]);
    if data_val is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="struct.unpack buffer",
            name="unsupported buffer (native accepts bytes and bytearray)"
        );
        return None;
    }
    view = self._bytearray_src_of(data_val);
    if view is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="struct.unpack buffer",
            name="unsupported buffer (native accepts bytes and bytearray)"
        );
        return None;
    }
    buf_len = view[1];
    data = view[0];
    too_short = self.builder.icmp_signed(
        "!=", buf_len, ir.Constant(ir.IntType(64), total), name="up.short"
    );
    self._emit_runtime_raise(
        too_short, "struct.error", f"unpack requires a buffer of {total} bytes"
    );
    (values, elem_types) = self._emit_struct_decode(fields, little, data);
    return self._emit_struct_tuple(values, elem_types);
}

impl NaIRGenPass._emit_struct_unpack_from(
    nd: uni.FuncCall,
    params: Sequence[uni.Expr | uni.KWPair],
    fields: list[tuple[str, int, bool]],
    total: int,
    little: bool
) -> (ir.Value | None) {
    if len(params) < 2 {
        return None;
    }
    i64 = ir.IntType(64);
    data_val = self._codegen_expr(params[1]);
    if data_val is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="struct.unpack_from buffer",
            name="unsupported buffer (native accepts bytes and bytearray)"
        );
        return None;
    }
    view = self._bytearray_src_of(data_val);
    if view is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="struct.unpack_from buffer",
            name="unsupported buffer (native accepts bytes and bytearray)"
        );
        return None;
    }
    off_val: ir.Value = ir.Constant(i64, 0);
    if len(params) >= 3 {
        _off_raw = self._codegen_expr(params[2]);
        if _off_raw is None {
            self.emit(
                E5092,
                node_override=nd,
                kind="struct.unpack_from offset",
                name="offset expression did not lower"
            );
            return None;
        }
        off_val = self._coerce_type(_off_raw, i64);
    }
    buf_len = view[1];
    neg = self.builder.icmp_signed("<", off_val, ir.Constant(i64, 0), name="uf.neg");
    off_adj = self.builder.select(
        neg,
        self.builder.add(off_val, buf_len, name="uf.neg.adjusted"),
        off_val,
        name="uf.offset"
    );
    end_off = self.builder.add(off_adj, ir.Constant(i64, total), name="uf.end");
    too_low = self.builder.icmp_signed(
        "<", off_adj, ir.Constant(i64, 0), name="uf.low"
    );
    oob = self.builder.icmp_signed(">", end_off, buf_len, name="uf.oob");
    self._emit_runtime_raise(
        self.builder.or_(too_low, oob, name="uf.bad"),
        "struct.error",
        f"unpack_from requires a buffer of at least {total} bytes"
    );
    data = self.builder.gep(view[0], [off_adj], name="uf.data");
    (values, elem_types) = self._emit_struct_decode(fields, little, data);
    return self._emit_struct_tuple(values, elem_types);
}

impl NaIRGenPass._emit_struct_half_to_f64(hv: ir.Value) -> ir.Value {
    b = self.builder;
    i64 = ir.IntType(64);
    f64 = ir.DoubleType();
    s = b.and_(
        b.lshr(hv, ir.Constant(i64, 15), name="hh.s0"), ir.Constant(i64, 1), name="hh.s"
    );
    e = b.and_(
        b.lshr(hv, ir.Constant(i64, 10), name="hh.e0"),
        ir.Constant(i64, 31),
        name="hh.e"
    );
    f = b.and_(hv, ir.Constant(i64, 1023), name="hh.f");

    nrm = b.or_(
        b.or_(
            b.shl(s, ir.Constant(i64, 63), name="hh.n.s"),
            b.shl(
                b.add(e, ir.Constant(i64, 1008), name="hh.n.e"),
                ir.Constant(i64, 52),
                name="hh.n.es"
            ),
            name="hh.n.se"
        ),
        b.shl(f, ir.Constant(i64, 42), name="hh.n.f"),
        name="hh.n"
    );
    nrmv = b.bitcast(nrm, f64, name="hh.n.v");

    infnan = b.or_(
        b.or_(
            b.shl(s, ir.Constant(i64, 63), name="hh.i.s"),
            ir.Constant(i64, 0x7FF0000000000000),
            name="hh.i.e"
        ),
        b.shl(f, ir.Constant(i64, 42), name="hh.i.f"),
        name="hh.i"
    );
    infnanv = b.bitcast(infnan, f64, name="hh.i.v");

    ff = b.sitofp(f, f64, name="hh.ff");
    subv0 = b.fmul(ff, ir.Constant(f64, 5.9604644775390625e-8), name="hh.sub");
    neg = b.icmp_signed("!=", s, ir.Constant(i64, 0), name="hh.neg");
    subv = b.select(neg, b.fneg(subv0, name="hh.sub.n"), subv0, name="hh.sub.s");
    szero = b.bitcast(
        b.shl(s, ir.Constant(i64, 63), name="hh.z.s"), f64, name="hh.z.v"
    );
    subres = b.select(
        b.icmp_signed("==", f, ir.Constant(i64, 0), name="hh.z.c"),
        szero,
        subv,
        name="hh.z"
    );
    is_inf = b.icmp_signed("==", e, ir.Constant(i64, 31), name="hh.ei");
    is_zero = b.icmp_signed("==", e, ir.Constant(i64, 0), name="hh.ez");
    res = b.select(
        is_inf, infnanv, b.select(is_zero, subres, nrmv, name="hh.zs"), name="hh.res"
    );
    return res;
}

impl NaIRGenPass._emit_struct_f64_to_half(nd: uni.FuncCall, fv: ir.Value) -> ir.Value {
    b = self.builder;
    i64 = ir.IntType(64);
    f64 = ir.DoubleType();
    db = b.bitcast(fv, i64, name="hf.db");
    s = b.and_(
        b.lshr(db, ir.Constant(i64, 63), name="hf.s0"), ir.Constant(i64, 1), name="hf.s"
    );
    be = b.and_(
        b.lshr(db, ir.Constant(i64, 52), name="hf.be0"),
        ir.Constant(i64, 2047),
        name="hf.be"
    );
    m = b.and_(db, ir.Constant(i64, 4503599627370495), name="hf.m");
    is_special = b.icmp_signed("==", be, ir.Constant(i64, 2047), name="hf.sp");

    ue = b.sub(be, ir.Constant(i64, 1023), name="hf.ue");
    too_big = b.icmp_signed(">", ue, ir.Constant(i64, 15), name="hf.ovf0");
    ovf = b.and_(
        too_big,
        b.icmp_signed("!=", be, ir.Constant(i64, 2047), name="hf.nsp"),
        name="hf.ovf"
    );
    self._emit_runtime_raise(
        ovf, "struct.error", "float too large to pack with e format"
    );
    e_sig = b.sub(be, ir.Constant(i64, 1008), name="hf.esig");

    nres = b.lshr(m, ir.Constant(i64, 42), name="hf.nr");
    ndrop = b.and_(m, ir.Constant(i64, 4398046511103), name="hf.nd");
    nhalf = ir.Constant(i64, 2199023255552);
    ngt = b.icmp_unsigned(">", ndrop, nhalf, name="hf.ngt");
    neq = b.icmp_signed("==", ndrop, nhalf, name="hf.neq");
    nodd = b.icmp_signed(
        "!=",
        b.and_(nres, ir.Constant(i64, 1), name="hf.no"),
        ir.Constant(i64, 0),
        name="hf.noc"
    );
    nrnd = b.or_(ngt, b.and_(neq, nodd, name="hf.nea"), name="hf.nrnd");
    norm_m = b.add(nres, b.zext(nrnd, i64, name="hf.nrndz"), name="hf.nm");

    mant53 = b.or_(m, ir.Constant(i64, 4503599627370496), name="hf.m53");
    shift_raw = b.sub(ir.Constant(i64, 43), e_sig, name="hf.ss0");

    shift = b.select(
        b.icmp_signed("<", shift_raw, ir.Constant(i64, 60), name="hf.ssc"),
        shift_raw,
        ir.Constant(i64, 60),
        name="hf.ss"
    );
    sres = b.lshr(mant53, shift, name="hf.sr");
    shalf = b.shl(
        ir.Constant(i64, 1),
        b.sub(shift, ir.Constant(i64, 1), name="hf.sh1"),
        name="hf.sh"
    );
    smask = b.sub(
        b.shl(ir.Constant(i64, 1), shift, name="hf.sm1"),
        ir.Constant(i64, 1),
        name="hf.sm"
    );
    sdrop = b.and_(mant53, smask, name="hf.sd");
    sgt = b.icmp_unsigned(">", sdrop, shalf, name="hf.sgt");
    seq = b.icmp_signed("==", sdrop, shalf, name="hf.seq");
    sodd = b.icmp_signed(
        "!=",
        b.and_(sres, ir.Constant(i64, 1), name="hf.so"),
        ir.Constant(i64, 0),
        name="hf.soc"
    );
    srnd = b.or_(sgt, b.and_(seq, sodd, name="hf.sea"), name="hf.srnd");
    sub_m = b.add(sres, b.zext(srnd, i64, name="hf.srndz"), name="hf.sm2");

    is_sub = b.icmp_signed("<", e_sig, ir.Constant(i64, 1), name="hf.issub");
    under = b.icmp_signed("<", e_sig, ir.Constant(i64, -10), name="hf.und");
    h_mant = b.select(
        under,
        ir.Constant(i64, 0),
        b.select(is_sub, sub_m, norm_m, name="hf.hm0"),
        name="hf.hm"
    );
    e_field = b.select(
        is_sub,
        ir.Constant(i64, 0),
        b.shl(e_sig, ir.Constant(i64, 10), name="hf.ef0"),
        name="hf.ef"
    );

    h_norm = b.add(
        b.shl(s, ir.Constant(i64, 15), name="hf.hs"),
        b.add(e_field, h_mant, name="hf.em"),
        name="hf.hn"
    );

    nanp = b.or_(
        b.lshr(m, ir.Constant(i64, 42), name="hf.np0"),
        ir.Constant(i64, 1),
        name="hf.np"
    );
    h_special = b.or_(
        b.or_(
            b.shl(s, ir.Constant(i64, 15), name="hf.sps"),
            ir.Constant(i64, 0x7C00),
            name="hf.spe"
        ),
        b.select(
            b.icmp_signed("!=", m, ir.Constant(i64, 0), name="hf.isnan"),
            nanp,
            ir.Constant(i64, 0),
            name="hf.nsel"
        ),
        name="hf.hsp"
    );
    return b.select(is_special, h_special, h_norm, name="hf.res");
}
