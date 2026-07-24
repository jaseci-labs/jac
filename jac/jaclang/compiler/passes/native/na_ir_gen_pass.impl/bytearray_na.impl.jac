impl NaIRGenPass._ensure_bytearray_type -> ir.Type {
    self._emit_list_helpers("u8", ir.IntType(8));
    return self.list_types["u8"].as_pointer();
}

impl NaIRGenPass._bytearray_runtime_fns -> dict {
    if self._bytearray_fns {
        return self._bytearray_fns;
    }
    ba_ptr = self._ensure_bytearray_type();
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    memmove_fn = self._get_or_declare_extern("memmove", i8p, [i8p, i8p, i64]);
    memset_fn = self._get_or_declare_extern("memset", i8p, [i8p, i32, i64]);

    res_fnty = ir.FunctionType(ir.VoidType(), [ba_ptr, i64]);
    res_fn = ir.Function(self.llvm_module, res_fnty, name="__bytearray_reserve");
    res_fn.linkage = "private";
    res_fn.args[0].name = "buf";
    res_fn.args[1].name = "need";
    entry_bb = res_fn.append_basic_block("entry");
    chk_bb = res_fn.append_basic_block("check");
    grow_bb = res_fn.append_basic_block("grow");
    done_bb = res_fn.append_basic_block("done");
    b = ir.IRBuilder(entry_bb);
    buf_a = res_fn.args[0];
    need_a = res_fn.args[1];
    len_p = b.gep(buf_a, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.p");
    cap_p = b.gep(buf_a, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cap.p");
    data_p = b.gep(buf_a, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.p");
    b.branch(chk_bb);
    b = ir.IRBuilder(chk_bb);
    cap_v = b.load(cap_p, name="cap");
    fits = b.icmp_signed(">=", cap_v, need_a, name="fits");
    b.cbranch(fits, done_bb, grow_bb);
    b = ir.IRBuilder(grow_bb);
    len_v = b.load(len_p, name="len");

    is_zero = b.icmp_signed("==", cap_v, ir.Constant(i64, 0), name="cap.zero");
    floored = b.select(is_zero, ir.Constant(i64, 4), cap_v, name="cap.floor");
    b.store(floored, cap_p);
    self._emit_grow_array(b, data_p, i8, len_v, cap_p, floored);
    b.branch(chk_bb);
    b = ir.IRBuilder(done_bb);
    b.ret_void();

    ext_fnty = ir.FunctionType(ir.VoidType(), [ba_ptr, i8p, i64]);
    ext_fn = ir.Function(self.llvm_module, ext_fnty, name="__bytearray_extend_raw");
    ext_fn.linkage = "private";
    ext_fn.args[0].name = "buf";
    ext_fn.args[1].name = "src";
    ext_fn.args[2].name = "n";
    e_bb = ext_fn.append_basic_block("entry");
    b = ir.IRBuilder(e_bb);
    e_buf = ext_fn.args[0];
    e_src = ext_fn.args[1];
    e_n = ext_fn.args[2];
    e_len_p = b.gep(e_buf, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.p");
    e_data_p = b.gep(e_buf, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.p");
    e_len = b.load(e_len_p, name="len");
    e_old_data = b.load(e_data_p, name="old.data");
    e_src_i = b.ptrtoint(e_src, i64, name="src.i");
    e_old_i = b.ptrtoint(e_old_data, i64, name="old.i");
    e_old_end = b.add(e_old_i, e_len, name="old.end");
    e_in_lo = b.icmp_unsigned(">=", e_src_i, e_old_i, name="alias.lo");
    e_in_hi = b.icmp_unsigned("<", e_src_i, e_old_end, name="alias.hi");
    e_alias = b.and_(e_in_lo, e_in_hi, name="alias");
    e_off = b.sub(e_src_i, e_old_i, name="alias.off");
    e_need = b.add(e_len, e_n, name="need");
    b.call(res_fn, [e_buf, e_need]);
    e_data = b.load(e_data_p, name="data");
    e_re = b.gep(e_data, [e_off], name="src.rederived");
    e_src2 = b.select(e_alias, e_re, e_src, name="src.eff");
    e_dst = b.gep(e_data, [e_len], name="dst");
    b.call(memcpy_fn, [e_dst, e_src2, e_n]);
    b.store(e_need, e_len_p);
    b.ret_void();

    ss_fnty = ir.FunctionType(ir.VoidType(), [ba_ptr, i64, i64, i8p, i64]);
    ss_fn = ir.Function(self.llvm_module, ss_fnty, name="__bytearray_setslice");
    ss_fn.linkage = "private";
    ss_fn.args[0].name = "buf";
    ss_fn.args[1].name = "start";
    ss_fn.args[2].name = "stop";
    ss_fn.args[3].name = "src";
    ss_fn.args[4].name = "n";
    s_bb = ss_fn.append_basic_block("entry");
    b = ir.IRBuilder(s_bb);
    s_buf = ss_fn.args[0];
    s_start = ss_fn.args[1];
    s_stop = ss_fn.args[2];
    s_src = ss_fn.args[3];
    s_n = ss_fn.args[4];
    s_len_p = b.gep(s_buf, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.p");
    s_data_p = b.gep(s_buf, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.p");
    s_len = b.load(s_len_p, name="len");

    malloc_fn = self._get_or_declare_extern("malloc", i8p, [i64]);
    free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
    s_tmp = b.call(malloc_fn, [s_n], name="src.snap");
    b.call(memcpy_fn, [s_tmp, s_src, s_n]);
    s_src = s_tmp;

    zero = ir.Constant(i64, 0);
    st_neg = b.icmp_signed("<", s_start, zero, name="st.neg");
    st_adj = b.select(st_neg, b.add(s_start, s_len), s_start, name="st.adj");
    st_lo = b.select(
        b.icmp_signed("<", st_adj, zero, name="st.lo.c"), zero, st_adj, name="st.lo"
    );
    start_c = b.select(
        b.icmp_signed(">", st_lo, s_len, name="st.hi.c"), s_len, st_lo, name="start.c"
    );
    sp_neg = b.icmp_signed("<", s_stop, zero, name="sp.neg");
    sp_adj = b.select(sp_neg, b.add(s_stop, s_len), s_stop, name="sp.adj");
    sp_lo = b.select(
        b.icmp_signed("<", sp_adj, start_c, name="sp.lo.c"),
        start_c,
        sp_adj,
        name="sp.lo"
    );
    stop_c = b.select(
        b.icmp_signed(">", sp_lo, s_len, name="sp.hi.c"), s_len, sp_lo, name="stop.c"
    );
    span = b.sub(stop_c, start_c, name="span");
    diff = b.sub(s_n, span, name="diff");
    new_len = b.add(s_len, diff, name="new.len");
    b.call(res_fn, [s_buf, new_len]);
    s_data = b.load(s_data_p, name="data");
    tail_n = b.sub(s_len, stop_c, name="tail.n");
    tail_src = b.gep(s_data, [stop_c], name="tail.src");
    tail_dst_off = b.add(start_c, s_n, name="tail.dst.off");
    tail_dst = b.gep(s_data, [tail_dst_off], name="tail.dst");
    b.call(memmove_fn, [tail_dst, tail_src, tail_n]);
    ins_dst = b.gep(s_data, [start_c], name="ins.dst");
    b.call(memcpy_fn, [ins_dst, s_src, s_n]);
    b.call(free_fn, [s_tmp]);
    b.store(new_len, s_len_p);
    b.ret_void();

    self._bytearray_fns = {
        "reserve": res_fn,
        "extend_raw": ext_fn,
        "setslice": ss_fn,
        "memset": memset_fn
    };
    return self._bytearray_fns;
}

impl NaIRGenPass._bytearray_src_of(val: ir.Value) -> (tuple | None) {
    if self._is_bytes_value(val) {
        return (self._bytes_data_ptr(val), self._bytes_len_val(val));
    }
    if "u8" in self.list_types and val.type == self.list_types["u8"].as_pointer() {
        i32 = ir.IntType(32);
        d_p = self.builder.gep(
            val, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="ba.data.p"
        );
        l_p = self.builder.gep(
            val, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ba.len.p"
        );
        return (
            self.builder.load(d_p, name="ba.data"),
            self.builder.load(l_p, name="ba.len")
        );
    }
    return None;
}

impl NaIRGenPass._dispatch_bytearray_method(
    method_name: str, recv: ir.Value, nd: uni.FuncCall
) -> (ir.Value | None) {
    fns = self._bytearray_runtime_fns();
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    params = nd.params or [];
    if method_name == "append" {
        if not params {
            return None;
        }
        v = self._codegen_expr(params[0]);
        if v is None {
            return None;
        }
        byte_v = self.builder.trunc(self._coerce_type(v, i64), i8, name="ba.append.b");
        self.builder.call(self.list_helpers["u8"]["append"], [recv, byte_v], name="");
        return ir.Constant(i64, 0);
    }
    if method_name == "extend" {
        if not params {
            return None;
        }
        v = self._codegen_expr(params[0]);
        if v is None {
            return None;
        }
        src = self._bytearray_src_of(v);
        if src is None {
            return None;
        }
        self.builder.call(fns["extend_raw"], [recv, src[0], src[1]], name="");
        if self._is_owned(v) {
            self._emit_rc_release_simple(v, op="ba_extend", loc="");
        }
        return ir.Constant(i64, 0);
    }
    return None;
}

impl NaIRGenPass._emit_struct_pack_into(
    nd: uni.FuncCall,
    params: list,
    fields: list[tuple[str, int, bool]],
    total: int,
    little: bool
) -> (ir.Value | None) {
    if len(params) < 3 {
        return None;
    }
    b = self.builder;
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    f32 = ir.FloatType();
    f64 = ir.DoubleType();

    buf_val = self._codegen_expr(params[1]);
    if buf_val is None
    or "u8" not in self.list_types
    or buf_val.type != self.list_types["u8"].as_pointer() {
        self.emit(
            E5092,
            node_override=nd,
            kind="struct.pack_into buffer",
            name="expected a bytearray"
        );
        return None;
    }
    _off_raw = self._codegen_expr(params[2]);
    if _off_raw is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="struct.pack_into offset",
            name="offset expression did not lower"
        );
        return None;
    }
    off_val = self._coerce_type(_off_raw, i64);

    _expected = len(
        [
            f
            for f in fields
            if f[0] != "pad"
        ]
    );
    if len(params) - 3 != _expected {
        self.emit(
            E5092,
            node_override=nd,
            kind="struct.pack_into argument count",
            name=f"expected {_expected}, got {len(params) - 3}"
        );
        return None;
    }
    arg_vals: list = [];
    for p in params[3:] {
        v = self._codegen_expr(p);
        if v is not None {
            arg_vals.append(v);
        }
    }
    len_p = b.gep(buf_val, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="pi.len.p");
    buf_len = b.load(len_p, name="pi.len");
    end_off = b.add(off_val, ir.Constant(i64, total), name="pi.end");
    oob = b.icmp_signed(">", end_off, buf_len, name="pi.oob");
    neg = b.icmp_signed("<", off_val, ir.Constant(i64, 0), name="pi.neg");
    self._emit_runtime_raise(
        b.or_(oob, neg, name="pi.bad"),
        "RuntimeError",
        "pack_into requires a buffer of at least the packed size"
    );
    data_p = b.gep(
        buf_val, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="pi.data.p"
    );
    data = b.load(data_p, name="pi.data");
    off = 0;
    ai = 0;
    for (kind, sz, signed) in fields {
        if kind == "pad" {
            pos_v = b.add(off_val, ir.Constant(i64, off), name="pi.pad.off");
            ptr = b.gep(data, [pos_v], name="pi.pad");
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
            small = b.fptrunc(fv, f32, name="pi.f32");
            asi = b.bitcast(small, i32, name="pi.f32.bits");
            bits = b.zext(asi, i64, name="pi.f32.ext");
        } elif kind == "float" {
            fv = self._coerce_type(raw, f64);
            bits = b.bitcast(fv, i64, name="pi.f64.bits");
        } else {
            bits = self._coerce_type(raw, i64);
        }
        for k in range(sz) {
            shifted = b.lshr(bits, ir.Constant(i64, k * 8), name="pi.sh");
            byte = b.trunc(shifted, i8, name="pi.byte");
            rel = off + (k if little else (sz - 1 - k));
            pos_v = b.add(off_val, ir.Constant(i64, rel), name="pi.off");
            ptr = b.gep(data, [pos_v], name="pi.ptr");
            b.store(byte, ptr);
        }
        off = off + sz;
    }
    return ir.Constant(i64, 0);
}
