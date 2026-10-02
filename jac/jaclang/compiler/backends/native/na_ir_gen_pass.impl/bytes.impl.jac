impl NaIRGenPass._get_bytes_struct_type -> ir.Type {
    if self._bytes_struct_type is not None {
        return self._bytes_struct_type;
    }
    i64 = ir.IntType(64);
    i8 = ir.IntType(8);
    bt = self.llvm_module.context.get_identified_type("jacbytes");
    bt.set_body(i64, ir.ArrayType(i8, 0));
    self._bytes_struct_type = bt;
    return bt;
}

impl NaIRGenPass._is_bytes_value(v: ir.Value) -> bool {
    if self._bytes_struct_type is None {
        return False;
    }
    return (
        isinstance(v.type, ir.PointerType) and v.type.pointee == self._bytes_struct_type
    );
}

impl NaIRGenPass._bytes_len_val(bv: ir.Value) -> ir.Value {
    i32 = ir.IntType(32);
    len_ptr = self.builder.gep(
        bv, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="by.len.ptr"
    );
    return self.builder.load(len_ptr, name="by.len");
}

impl NaIRGenPass._bytes_data_ptr(bv: ir.Value) -> ir.Value {
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    arr_ptr = self.builder.gep(
        bv, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="by.data"
    );
    return self.builder.bitcast(arr_ptr, i8.as_pointer(), name="by.data.i8");
}

impl NaIRGenPass._bytes_alloc(n: ir.Value) -> ir.Value {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    bt = self._get_bytes_struct_type();
    n = self._coerce_type(n, i64);
    total = self.builder.add(n, ir.Constant(i64, 8), name="by.total");
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    _alloc_fn = self.rc_alloc_fn;
    assert _alloc_fn is not None , "rc helpers are emitted before allocation";
    raw = self._rc_call_with_ctx(_alloc_fn, [total], op="bytes", loc="", name="by.raw");
    self._emit_set_type_tag(self.builder, raw, "bytes");
    bv = self.builder.bitcast(raw, bt.as_pointer(), name="by.obj");
    len_ptr = self.builder.gep(
        bv, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="by.len.set"
    );
    self.builder.store(n, len_ptr);
    self._mark_owned(bv);
    return bv;
}

impl NaIRGenPass._bytes_from_raw(src: ir.Value, n: ir.Value) -> ir.Value {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    bv = self._bytes_alloc(n);
    dst = self._bytes_data_ptr(bv);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    self.builder.call(memcpy_fn, [dst, src, n]);
    return bv;
}

impl NaIRGenPass._make_global_bytes(data: bytes) -> ir.Value {
    i64 = ir.IntType(64);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    n = len(data);
    arr_type = ir.ArrayType(i8, n);
    struct_type = ir.LiteralStructType([i64, i64, i64, arr_type]);
    c_arr = ir.Constant(arr_type, bytearray(data));
    struct_val = ir.Constant(
        struct_type,
        [
            ir.Constant(i64, 0x7FFFFFFFFFFFFFFF),
            ir.Constant(i64, 0),
            ir.Constant(i64, n),
            c_arr
        ]
    );
    gv = ir.GlobalVariable(
        self.llvm_module, struct_type, name=f".bytes.{self._str_count}"
    );
    self._str_count = self._str_count + 1;
    gv.linkage = "private";
    gv.global_constant = True;
    gv.initializer = struct_val;
    bt = self._get_bytes_struct_type();
    payload = self.builder.gep(
        gv, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="by.lit"
    );
    return self.builder.bitcast(payload, bt.as_pointer(), name="by.lit.obj");
}

impl NaIRGenPass._bytes_real_index(
    bv: ir.Value, idx: ir.Value, name_prefix: str
) -> ir.Value {
    i64 = ir.IntType(64);
    idx = self._coerce_type(idx, i64);
    length = self._bytes_len_val(bv);
    is_neg = self.builder.icmp_signed(
        "<", idx, ir.Constant(i64, 0), name=f"{name_prefix}.neg"
    );
    adj = self.builder.add(idx, length, name=f"{name_prefix}.adj");
    real_idx = self.builder.select(is_neg, adj, idx, name=f"{name_prefix}.idx");
    lo_bad = self.builder.icmp_signed(
        "<", real_idx, ir.Constant(i64, 0), name=f"{name_prefix}.lo"
    );
    hi_bad = self.builder.icmp_signed(">=", real_idx, length, name=f"{name_prefix}.hi");
    oob = self.builder.or_(lo_bad, hi_bad, name=f"{name_prefix}.oob");
    self._emit_runtime_raise(oob, "IndexError", "index out of range");
    return real_idx;
}

impl NaIRGenPass._codegen_bytes_index(
    bv: ir.Value, idx: ir.Value
) -> (ir.Value | None) {
    i64 = ir.IntType(64);
    real_idx = self._bytes_real_index(bv, idx, "by.idx");
    data = self._bytes_data_ptr(bv);
    bptr = self.builder.gep(data, [real_idx], name="by.bptr");
    byte = self.builder.load(bptr, name="by.byte");
    return self.builder.zext(byte, i64, name="by.byte.i64");
}

impl NaIRGenPass._codegen_bytes_index_set(
    bv: ir.Value, idx: ir.Value, value: ir.Value
) -> None {
    value = self._coerce_type(value, ir.IntType(64));
    byte_val = self.builder.trunc(value, ir.IntType(8), name="by.set.byte");
    real_idx = self._bytes_real_index(bv, idx, "by.set");
    data = self._bytes_data_ptr(bv);
    bptr = self.builder.gep(data, [real_idx], name="by.set.bptr");
    self.builder.store(byte_val, bptr);
}

impl NaIRGenPass._is_bytes_literal_target(target: uni.UniNode) -> bool {
    if isinstance(target?.lit_value, bytes) {
        return True;
    }
    if isinstance(target, uni.Name) and target.sym is not None {
        _init = target.sym.decl?.parent?.value;
        return isinstance(_init?.lit_value, bytes);
    }
    return False;
}

impl NaIRGenPass._codegen_bytes_slice(
    bv: ir.Value, slice_node: object
) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    src_len = self._bytes_len_val(bv);

    start_val: ir.Value = zero;
    if slice_node?.start is not None {
        _sv = self._codegen_expr(slice_node.start);
        if _sv is not None {
            v = self._coerce_type(_sv, i64);
            neg = self.builder.icmp_signed("<", v, zero, name="by.sl0.neg");
            v = self.builder.select(
                neg,
                self.builder.add(v, src_len, name="by.sl0.wrap"),
                v,
                name="by.sl0.w"
            );
            lo = self.builder.icmp_signed("<", v, zero, name="by.sl0.lo");
            v = self.builder.select(lo, zero, v, name="by.sl0.cl0");
            hi = self.builder.icmp_signed(">", v, src_len, name="by.sl0.hi");
            start_val = self.builder.select(hi, src_len, v, name="by.sl0.cln");
        }
    }

    stop_val: ir.Value = src_len;
    if slice_node?.stop is not None {
        _ev = self._codegen_expr(slice_node.stop);
        if _ev is not None {
            v = self._coerce_type(_ev, i64);
            neg = self.builder.icmp_signed("<", v, zero, name="by.sl1.neg");
            v = self.builder.select(
                neg,
                self.builder.add(v, src_len, name="by.sl1.wrap"),
                v,
                name="by.sl1.w"
            );
            lo = self.builder.icmp_signed("<", v, zero, name="by.sl1.lo");
            v = self.builder.select(lo, zero, v, name="by.sl1.cl0");
            hi = self.builder.icmp_signed(">", v, src_len, name="by.sl1.hi");
            stop_val = self.builder.select(hi, src_len, v, name="by.sl1.cln");
        }
    }
    raw_len = self.builder.sub(stop_val, start_val, name="by.sl.rawlen");
    neg_len = self.builder.icmp_signed("<", raw_len, zero, name="by.sl.neglen");
    slice_len = self.builder.select(neg_len, zero, raw_len, name="by.sl.len");
    new_b = self._bytes_alloc(slice_len);
    dst = self._bytes_data_ptr(new_b);
    src = self.builder.gep(self._bytes_data_ptr(bv), [start_val], name="by.sl.src");
    memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    self.builder.call(memcpy_fn, [dst, src, slice_len]);
    return new_b;
}

impl NaIRGenPass._emit_bytes_eq(
    left: ir.Value, right: ir.Value, negate: bool
) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    func = self.builder.basic_block.function;
    lnull = self.builder.icmp_unsigned(
        "==", left, ir.Constant(left.type, None), name="by.eq.lnull"
    );
    rnull = self.builder.icmp_unsigned(
        "==", right, ir.Constant(right.type, None), name="by.eq.rnull"
    );
    either_null = self.builder.or_(lnull, rnull, name="by.eq.enull");
    both_null = self.builder.and_(lnull, rnull, name="by.eq.bnull");
    entry_bb = self.builder.basic_block;
    live_bb = func.append_basic_block(name="by.eq.live");
    done_bb = func.append_basic_block(name="by.eq.done");

    self.builder.cbranch(either_null, done_bb, live_bb);
    self.builder.position_at_end(live_bb);
    llen = self._bytes_len_val(left);
    rlen = self._bytes_len_val(right);
    len_eq = self.builder.icmp_signed("==", llen, rlen, name="by.eq.len");

    minlen = self.builder.select(
        self.builder.icmp_signed("<", llen, rlen, name="by.eq.lt"),
        llen,
        rlen,
        name="by.eq.min"
    );
    memcmp_fn = self._get_or_declare_extern("memcmp", i32, [i8p, i8p, i64]);
    cmp = self.builder.call(
        memcmp_fn,
        [self._bytes_data_ptr(left), self._bytes_data_ptr(right), minlen],
        name="by.eq.memcmp"
    );
    data_eq = self.builder.icmp_signed(
        "==", cmp, ir.Constant(i32, 0), name="by.eq.data"
    );
    full_eq = self.builder.and_(len_eq, data_eq, name="by.eq.full");
    live_end_bb = self.builder.basic_block;
    self.builder.branch(done_bb);
    self.builder.position_at_end(done_bb);
    res = self.builder.phi(i1, name="by.eq");
    res.add_incoming(both_null, entry_bb);
    res.add_incoming(full_eq, live_end_bb);
    if negate {
        return self.builder.not_(res, name="by.ne");
    }
    return res;
}

impl NaIRGenPass._is_bytes_type(t: ir.Type) -> bool {
    if self._bytes_struct_type is None {
        return False;
    }
    return isinstance(t, ir.PointerType) and t.pointee == self._bytes_struct_type;
}

impl NaIRGenPass._emit_bytes_truthy(bv: ir.Value) -> ir.Value {
    return self.builder.icmp_unsigned(
        "!=", self._bytes_len_val(bv), ir.Constant(ir.IntType(64), 0), name="by.truthy"
    );
}

impl NaIRGenPass._emit_bytes_repeat(bv: ir.Value, count: ir.Value) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    n = self._coerce_type(count, i64);
    is_neg = self.builder.icmp_signed("<", n, ir.Constant(i64, 0), name="by.rep.neg");
    n = self.builder.select(is_neg, ir.Constant(i64, 0), n, name="by.rep.n");
    blen = self._bytes_len_val(bv);
    total = self.builder.mul(blen, n, name="by.rep.total");
    result = self._bytes_alloc(total);
    dst = self._bytes_data_ptr(result);
    src = self._bytes_data_ptr(bv);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    func = self.builder.basic_block.function;
    entry_bb = self.builder.basic_block;
    loop_bb = func.append_basic_block(name="by.rep.loop");
    body_bb = func.append_basic_block(name="by.rep.body");
    done_bb = func.append_basic_block(name="by.rep.done");
    self.builder.branch(loop_bb);
    self.builder.position_at_start(loop_bb);
    cnt = self.builder.phi(i64, name="by.rep.cnt");
    cnt.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = self.builder.icmp_unsigned(">=", cnt, n, name="by.rep.atend");
    self.builder.cbranch(at_end, done_bb, body_bb);
    self.builder.position_at_start(body_bb);
    off = self.builder.mul(cnt, blen, name="by.rep.off");
    d = self.builder.gep(dst, [off], name="by.rep.dst");
    self.builder.call(memcpy_fn, [d, src, blen]);
    next_cnt = self.builder.add(cnt, ir.Constant(i64, 1), name="by.rep.next");
    cnt.add_incoming(next_cnt, body_bb);
    self.builder.branch(loop_bb);
    self.builder.position_at_start(done_bb);
    return result;
}

impl NaIRGenPass._emit_bytes_contains(
    needle: ir.Value, haystack: ir.Value
) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    memmem_fn = self._get_or_declare_extern("memmem", i8p, [i8p, i64, i8p, i64]);
    _needle_len = self._bytes_len_val(needle);
    found = self.builder.call(
        memmem_fn,
        [
            self._bytes_data_ptr(haystack),
            self._bytes_len_val(haystack),
            self._bytes_data_ptr(needle),
            _needle_len
        ],
        name="by.in.memmem"
    );
    _hit = self.builder.icmp_unsigned(
        "!=", found, ir.Constant(i8p, None), name="by.in.found"
    );

    _empty = self.builder.icmp_signed(
        "==", _needle_len, ir.Constant(i64, 0), name="by.in.empty"
    );
    return self.builder.or_(_hit, _empty, name="by.in.res");
}

impl NaIRGenPass._emit_bytes_cmp(
    left: ir.Value, right: ir.Value, op_sym: str
) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);

    lnull = self.builder.icmp_unsigned(
        "==", left, ir.Constant(left.type, None), name="by.cmp.lnull"
    );
    rnull = self.builder.icmp_unsigned(
        "==", right, ir.Constant(right.type, None), name="by.cmp.rnull"
    );
    self._emit_runtime_raise(
        self.builder.or_(lnull, rnull, name="by.cmp.enull"),
        "TypeError",
        f"'{op_sym}' not supported between instances of 'bytes' and 'NoneType'"
    );
    llen = self._bytes_len_val(left);
    rlen = self._bytes_len_val(right);
    l_lt_r = self.builder.icmp_signed("<", llen, rlen, name="by.cmp.llt");
    l_gt_r = self.builder.icmp_signed(">", llen, rlen, name="by.cmp.lgt");
    minlen = self.builder.select(l_lt_r, llen, rlen, name="by.cmp.min");
    memcmp_fn = self._get_or_declare_extern("memcmp", i32, [i8p, i8p, ir.IntType(64)]);
    c = self.builder.call(
        memcmp_fn,
        [self._bytes_data_ptr(left), self._bytes_data_ptr(right), minlen],
        name="by.cmp.memcmp"
    );
    len_ord = self.builder.select(
        l_gt_r,
        ir.Constant(i32, 1),
        self.builder.select(
            l_lt_r, ir.Constant(i32, -1), ir.Constant(i32, 0), name="by.cmp.lo0"
        ),
        name="by.cmp.lenord"
    );
    c_nz = self.builder.icmp_signed("!=", c, ir.Constant(i32, 0), name="by.cmp.cnz");
    return self.builder.select(c_nz, c, len_ord, name="by.cmp.ord");
}

impl NaIRGenPass._emit_bytes_repr(bv: ir.Value) -> ir.Value {
    return self.builder.call(self._bytes_repr_fn(), [bv], name="by.repr");
}

impl NaIRGenPass._bytes_repr_fn -> ir.Function {
    if self._bytes_repr_function is not None {
        return self._bytes_repr_function;
    }
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    bt_ptr = self._get_bytes_struct_type().as_pointer();
    fnty = ir.FunctionType(i8p, [bt_ptr]);
    fn = ir.Function(self.llvm_module, fnty, name="__jac_bytes_repr");
    fn.linkage = "private";
    fn.args[0].name = "bv";
    bv = fn.args[0];
    entry_bb = fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb);
    SQ = ir.Constant(i8, 0x27);
    DQ = ir.Constant(i8, 0x22);
    BSL = ir.Constant(i8, 0x5C);

    blen = b.load(b.gep(bv, [ir.Constant(i32, 0), ir.Constant(i32, 0)]), name="r.len");
    data = b.bitcast(
        b.gep(bv, [ir.Constant(i32, 0), ir.Constant(i32, 1)]), i8p, name="r.data"
    );

    has_sq = b.alloca(i1, name="r.has.sq");
    has_dq = b.alloca(i1, name="r.has.dq");
    si = b.alloca(i64, name="r.si");
    b.store(ir.Constant(i1, 0), has_sq);
    b.store(ir.Constant(i1, 0), has_dq);
    b.store(ir.Constant(i64, 0), si);
    sc_cond = fn.append_basic_block("r.sc.cond");
    sc_body = fn.append_basic_block("r.sc.body");
    sc_done = fn.append_basic_block("r.sc.done");
    b.branch(sc_cond);
    b.position_at_end(sc_cond);
    sidx = b.load(si, name="r.sidx");
    b.cbranch(b.icmp_signed("<", sidx, blen, name="r.sc.go"), sc_body, sc_done);
    b.position_at_end(sc_body);
    sc = b.load(b.gep(data, [sidx], name="r.sc.ptr"), name="r.sc.ch");
    b.store(
        b.or_(b.load(has_sq), b.icmp_unsigned("==", sc, SQ, name="r.sc.isq")), has_sq
    );
    b.store(
        b.or_(b.load(has_dq), b.icmp_unsigned("==", sc, DQ, name="r.sc.idq")), has_dq
    );
    b.store(b.add(sidx, ir.Constant(i64, 1)), si);
    b.branch(sc_cond);
    b.position_at_end(sc_done);
    use_dq = b.and_(
        b.load(has_sq), b.not_(b.load(has_dq), name="r.no.dq"), name="r.use.dq"
    );
    quote = b.select(use_dq, DQ, SQ, name="r.quote");

    cap = b.add(b.mul(blen, ir.Constant(i64, 4)), ir.Constant(i64, 5), name="r.cap");
    buf = b.call(self.rc_alloc_fn, [cap], name="r.buf");
    b.store(ir.Constant(i8, 0x62), buf);
    b.store(quote, b.gep(buf, [ir.Constant(i64, 1)], name="r.q0"));
    oi = b.alloca(i64, name="r.oi");
    wi = b.alloca(i64, name="r.wi");
    b.store(ir.Constant(i64, 2), oi);
    b.store(ir.Constant(i64, 0), wi);

    w_cond = fn.append_basic_block("r.w.cond");
    w_body = fn.append_basic_block("r.w.body");
    w_done = fn.append_basic_block("r.w.done");
    b.branch(w_cond);
    b.position_at_end(w_cond);
    widx = b.load(wi, name="r.widx");
    b.cbranch(b.icmp_signed("<", widx, blen, name="r.w.go"), w_body, w_done);
    b.position_at_end(w_body);
    c = b.load(b.gep(data, [widx], name="r.c.ptr"), name="r.c");
    is_bsl = b.icmp_unsigned("==", c, BSL, name="r.is.bsl");
    is_q = b.icmp_unsigned("==", c, quote, name="r.is.q");
    is_tab = b.icmp_unsigned("==", c, ir.Constant(i8, 0x09), name="r.is.tab");
    is_nl = b.icmp_unsigned("==", c, ir.Constant(i8, 0x0A), name="r.is.nl");
    is_cr = b.icmp_unsigned("==", c, ir.Constant(i8, 0x0D), name="r.is.cr");
    ge_sp = b.icmp_unsigned(">=", c, ir.Constant(i8, 0x20), name="r.ge.sp");
    le_ti = b.icmp_unsigned("<=", c, ir.Constant(i8, 0x7E), name="r.le.ti");
    is_print = b.and_(ge_sp, le_ti, name="r.is.print");
    is_special = b.or_(is_bsl, is_q, name="r.is.special");
    is_ctrl = b.or_(b.or_(is_tab, is_nl, name="r.tn"), is_cr, name="r.is.ctrl");
    is_plain = b.and_(is_print, b.not_(is_special, name="r.not.sp"), name="r.is.plain");
    is_hex = b.not_(
        b.or_(b.or_(is_special, is_ctrl, name="r.sc1"), is_plain, name="r.sc2"),
        name="r.is.hex"
    );

    hi = b.lshr(c, ir.Constant(i8, 4), name="r.hi");
    lo = b.and_(c, ir.Constant(i8, 0x0F), name="r.lo");
    hi_lt = b.icmp_unsigned("<", hi, ir.Constant(i8, 10), name="r.hi.lt");
    lo_lt = b.icmp_unsigned("<", lo, ir.Constant(i8, 10), name="r.lo.lt");
    hi_hex = b.select(
        hi_lt,
        b.add(hi, ir.Constant(i8, 48)),
        b.add(hi, ir.Constant(i8, 87)),
        name="r.hi.x"
    );
    lo_hex = b.select(
        lo_lt,
        b.add(lo, ir.Constant(i8, 48)),
        b.add(lo, ir.Constant(i8, 87)),
        name="r.lo.x"
    );

    o0 = b.select(is_plain, c, BSL, name="r.o0");
    ctrl_ch = b.select(
        is_tab,
        ir.Constant(i8, 0x74),
        b.select(is_nl, ir.Constant(i8, 0x6E), ir.Constant(i8, 0x72), name="r.nr"),
        name="r.ctrl.ch"
    );
    special_ch = b.select(is_bsl, BSL, quote, name="r.special.ch");
    o1 = b.select(
        is_special,
        special_ch,
        b.select(is_ctrl, ctrl_ch, ir.Constant(i8, 0x78), name="r.o1.x"),
        name="r.o1"
    );
    klen = b.select(
        is_plain,
        ir.Constant(i64, 1),
        b.select(is_hex, ir.Constant(i64, 4), ir.Constant(i64, 2), name="r.k0"),
        name="r.klen"
    );

    oi_cur = b.load(oi, name="r.oi.cur");
    b.store(o0, b.gep(buf, [oi_cur], name="r.s0"));
    b.store(o1, b.gep(buf, [b.add(oi_cur, ir.Constant(i64, 1))], name="r.s1"));
    b.store(hi_hex, b.gep(buf, [b.add(oi_cur, ir.Constant(i64, 2))], name="r.s2"));
    b.store(lo_hex, b.gep(buf, [b.add(oi_cur, ir.Constant(i64, 3))], name="r.s3"));
    b.store(b.add(oi_cur, klen), oi);
    b.store(b.add(widx, ir.Constant(i64, 1)), wi);
    b.branch(w_cond);
    b.position_at_end(w_done);
    oi_end = b.load(oi, name="r.oi.end");
    b.store(quote, b.gep(buf, [oi_end], name="r.qc"));
    b.store(
        ir.Constant(i8, 0),
        b.gep(buf, [b.add(oi_end, ir.Constant(i64, 1))], name="r.nul")
    );
    b.ret(buf);
    self._bytes_repr_function = fn;
    return fn;
}

impl NaIRGenPass._emit_bytes_needle(
    needle: ir.Value
) -> (tuple[ir.Value, ir.Value, ir.Value] | None) {
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    if self._is_bytes_value(needle) {
        return (
            self._bytes_data_ptr(needle),
            self._bytes_len_val(needle),
            ir.Constant(i64, 0)
        );
    }
    if not isinstance(needle.type, ir.IntType) {
        return None;
    }
    byte = self._coerce_type(needle, i64);
    self._emit_runtime_raise(
        self.builder.icmp_unsigned(
            ">", byte, ir.Constant(i64, 255), name="by.nd.range"
        ),
        "ValueError",
        "byte must be in range(0, 256)"
    );
    return (ir.Constant(i8p, None), ir.Constant(i64, 1), byte);
}

impl NaIRGenPass._emit_bytes_search(
    target: ir.Value, args: list[ir.Value], mode: str, missing: str = ""
) -> (ir.Value | None) {
    i64 = ir.IntType(64);
    modes = {"find": 0, "rfind": 1, "count": 2};
    if not args or len(args) > 3 or mode not in modes {
        return None;
    }
    for bound in args[1:] {
        if not isinstance(bound.type, ir.IntType) {
            return None;
        }
    }
    parts = self._emit_bytes_needle(args[0]);
    if parts is None {
        return None;
    }
    (data, size, byte) = parts;
    start = self._coerce_type(args[1], i64) if len(args) > 1 else ir.Constant(i64, 0);
    end = self._coerce_type(args[2], i64)
        if len(args) > 2
        else self._bytes_len_val(target);
    result = self.builder.call(
        self._bytes_search_fn(),
        [target, data, size, byte, start, end, ir.Constant(i64, modes[mode])],
        name=f"by.{mode}"
    );
    if missing {
        self._emit_runtime_raise(
            self.builder.icmp_signed("<", result, ir.Constant(i64, 0), name="by.miss"),
            "ValueError",
            missing
        );
    }
    return result;
}

impl NaIRGenPass._bytes_search_fn -> ir.Function {
    if self._bytes_search_function is not None {
        return self._bytes_search_function;
    }
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);
    minus_one = ir.Constant(i64, -1);
    bt_ptr = self._get_bytes_struct_type().as_pointer();
    fnty = ir.FunctionType(i64, [bt_ptr, i8p, i64, i64, i64, i64, i64]);
    fn = ir.Function(self.llvm_module, fnty, name="__jac_bytes_search");
    fn.linkage = "private";
    (hay, needle, needle_len, byte, raw_start, raw_end, mode) = fn.args;
    for (arg, name) in zip(
        fn.args, ["hay", "needle", "needle_len", "byte", "start", "end", "mode"]
    ) {
        arg.name = name;
    }
    memmem_fn = self._get_or_declare_extern("memmem", i8p, [i8p, i64, i8p, i64]);
    memcmp_fn = self._get_or_declare_extern("memcmp", i32, [i8p, i8p, i64]);
    b = ir.IRBuilder(fn.append_basic_block("entry"));
    byte_slot = b.alloca(i8, name="s.byte");
    b.store(b.trunc(byte, i8), byte_slot);
    length = b.load(
        b.gep(hay, [ir.Constant(i32, 0), ir.Constant(i32, 0)]), name="s.len"
    );
    data = b.bitcast(
        b.gep(hay, [ir.Constant(i32, 0), ir.Constant(i32, 1)]), i8p, name="s.data"
    );
    is_byte = b.icmp_unsigned("==", needle, ir.Constant(i8p, None), name="s.isbyte");
    nd = b.select(is_byte, byte_slot, needle, name="s.nd");
    nd_len = b.select(is_byte, one, needle_len, name="s.ndlen");
    end_hi = b.select(
        b.icmp_signed(">", raw_end, length), length, raw_end, name="s.end.hi"
    );
    end_w = b.select(
        b.icmp_signed("<", end_hi, zero), b.add(end_hi, length), end_hi, name="s.end.w"
    );
    end = b.select(b.icmp_signed("<", end_w, zero), zero, end_w, name="s.end");
    start_w = b.select(
        b.icmp_signed("<", raw_start, zero),
        b.add(raw_start, length),
        raw_start,
        name="s.start.w"
    );
    start = b.select(b.icmp_signed("<", start_w, zero), zero, start_w, name="s.start");
    span = b.sub(end, start, name="s.span");
    empty = b.icmp_signed("==", nd_len, zero, name="s.empty");
    too_short = b.icmp_signed("<", span, nd_len, name="s.short");

    find_bb = fn.append_basic_block("find");
    find_scan = fn.append_basic_block("find.scan");
    rfind_bb = fn.append_basic_block("rfind");
    rfind_scan = fn.append_basic_block("rfind.scan");
    rfind_loop = fn.append_basic_block("rfind.loop");
    rfind_body = fn.append_basic_block("rfind.body");
    rfind_hit = fn.append_basic_block("rfind.hit");
    count_bb = fn.append_basic_block("count");
    count_scan = fn.append_basic_block("count.scan");
    count_loop = fn.append_basic_block("count.loop");
    count_probe = fn.append_basic_block("count.probe");
    count_hit = fn.append_basic_block("count.hit");
    miss_bb = fn.append_basic_block("miss");
    by_mode = b.switch(mode, count_bb);
    by_mode.add_case(ir.Constant(i64, 0), find_bb);
    by_mode.add_case(ir.Constant(i64, 1), rfind_bb);

    b.position_at_end(miss_bb);
    b.ret(minus_one);

    b.position_at_end(find_bb);
    empty_hit = fn.append_basic_block("find.empty");
    b.cbranch(too_short, miss_bb, empty_hit);
    b.position_at_end(empty_hit);
    empty_ret = fn.append_basic_block("find.empty.ret");
    b.cbranch(empty, empty_ret, find_scan);
    b.position_at_end(empty_ret);
    b.ret(start);
    b.position_at_end(find_scan);
    found = b.call(
        memmem_fn, [b.gep(data, [start]), span, nd, nd_len], name="find.ptr"
    );
    find_hit = fn.append_basic_block("find.hit");
    b.cbranch(b.icmp_unsigned("==", found, ir.Constant(i8p, None)), miss_bb, find_hit);
    b.position_at_end(find_hit);
    b.ret(b.sub(b.ptrtoint(found, i64), b.ptrtoint(data, i64), name="find.idx"));

    b.position_at_end(rfind_bb);
    rfind_nonempty = fn.append_basic_block("rfind.nonempty");
    rfind_empty = fn.append_basic_block("rfind.empty");
    b.cbranch(too_short, miss_bb, rfind_nonempty);
    b.position_at_end(rfind_nonempty);
    b.cbranch(empty, rfind_empty, rfind_scan);
    b.position_at_end(rfind_empty);
    b.ret(end);
    b.position_at_end(rfind_scan);
    first = b.sub(end, nd_len, name="rfind.first");
    b.branch(rfind_loop);
    b.position_at_end(rfind_loop);
    pos = b.phi(i64, name="rfind.pos");
    pos.add_incoming(first, rfind_scan);
    b.cbranch(b.icmp_signed("<", pos, start), miss_bb, rfind_body);
    b.position_at_end(rfind_body);
    window = b.gep(data, [pos], name="rfind.window");
    same = b.call(memcmp_fn, [window, nd, nd_len], name="rfind.cmp");
    pos.add_incoming(b.sub(pos, one, name="rfind.prev"), rfind_body);
    b.cbranch(b.icmp_signed("==", same, ir.Constant(i32, 0)), rfind_hit, rfind_loop);
    b.position_at_end(rfind_hit);
    b.ret(pos);

    b.position_at_end(count_bb);
    count_ok = fn.append_basic_block("count.ok");
    count_empty = fn.append_basic_block("count.empty");
    count_none = fn.append_basic_block("count.none");
    b.cbranch(b.icmp_signed("<", span, zero), count_none, count_ok);
    b.position_at_end(count_none);
    b.ret(zero);
    b.position_at_end(count_ok);
    b.cbranch(empty, count_empty, count_scan);
    b.position_at_end(count_empty);
    b.ret(b.add(span, one, name="count.slots"));
    b.position_at_end(count_scan);
    b.branch(count_loop);
    b.position_at_end(count_loop);
    cursor = b.phi(i64, name="count.cursor");
    total = b.phi(i64, name="count.total");
    cursor.add_incoming(start, count_scan);
    total.add_incoming(zero, count_scan);
    count_done = fn.append_basic_block("count.done");
    rest = b.sub(end, cursor, name="count.rest");
    b.cbranch(b.icmp_signed("<", rest, nd_len), count_done, count_probe);
    b.position_at_end(count_probe);
    hit = b.call(
        memmem_fn, [b.gep(data, [cursor]), rest, nd, nd_len], name="count.ptr"
    );
    b.cbranch(
        b.icmp_unsigned("==", hit, ir.Constant(i8p, None)), count_done, count_hit
    );
    b.position_at_end(count_hit);
    offset = b.sub(b.ptrtoint(hit, i64), b.ptrtoint(data, i64), name="count.at");
    cursor.add_incoming(b.add(offset, nd_len, name="count.next"), count_hit);
    total.add_incoming(b.add(total, one, name="count.inc"), count_hit);
    b.branch(count_loop);
    b.position_at_end(count_done);
    b.ret(total);

    self._bytes_search_function = fn;
    return fn;
}

impl NaIRGenPass._decode_literal(arg_node: (uni.UniNode | None)) -> (str | None) {
    if isinstance(arg_node, uni.MultiString) and len(arg_node.strings) == 1 {
        arg_node = arg_node.strings[0];
    }
    if not isinstance(arg_node, uni.String) {
        return None;
    }
    value: any = None;
    try {
        value = arg_node.lit_value;
    } except Exception {
        return None;
    }
    return value if isinstance(value, str) else None;
}

impl NaIRGenPass._private_cstr(data: bytes, name: str) -> ir.Value {
    i8 = ir.IntType(8);
    cdata = ir.Constant(ir.ArrayType(i8, len(data)), bytearray(data));
    gv = ir.GlobalVariable(
        self.llvm_module, cdata.type, name=f"{name}.{self._str_count}"
    );
    self._str_count = self._str_count + 1;
    gv.linkage = "private";
    gv.global_constant = True;
    gv.initializer = cdata;
    return gv.bitcast(i8.as_pointer());
}

impl NaIRGenPass._name_lookup_fn -> ir.Function {
    """Look `name` up in a table of `<tag byte><name>\\0` rows ended by a 0 tag.

    Returns the matching row's tag, or 0 when no row matches.
    """;
    if self._name_lookup_function is not None {
        return self._name_lookup_function;
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    fn = ir.Function(
        self.llvm_module, ir.FunctionType(i64, [i8p, i8p]), name="__jac_str_name_lookup"
    );
    fn.linkage = "private";
    (name, table) = fn.args;
    name.name = "name";
    table.name = "table";
    strcmp_fn = self._get_or_declare_extern("strcmp", i32, [i8p, i8p]);
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    entry_bb = fn.append_basic_block("entry");
    loop = fn.append_basic_block("loop");
    check_bb = fn.append_basic_block("check");
    miss = fn.append_basic_block("miss");
    found = fn.append_basic_block("found");
    none_bb = fn.append_basic_block("none");
    b = ir.IRBuilder(entry_bb);
    b.branch(loop);
    b.position_at_end(loop);
    row = b.phi(i8p, name="row");
    row.add_incoming(table, entry_bb);
    tag = b.zext(b.load(row), i64, name="tag");
    b.cbranch(b.icmp_unsigned("==", tag, ir.Constant(i64, 0)), none_bb, check_bb);
    b.position_at_end(none_bb);
    b.ret(ir.Constant(i64, 0));
    b.position_at_end(check_bb);
    row_name = b.gep(row, [ir.Constant(i64, 1)], name="row.name");
    same = b.call(strcmp_fn, [row_name, name], name="row.cmp");
    b.cbranch(b.icmp_signed("==", same, ir.Constant(i32, 0)), found, miss);
    b.position_at_end(found);
    b.ret(tag);
    b.position_at_end(miss);
    width = b.call(strlen_fn, [row_name], name="row.len");
    row.add_incoming(
        b.gep(row_name, [b.add(width, ir.Constant(i64, 1))], name="row.next"), miss
    );
    b.branch(loop);
    self._name_lookup_function = fn;
    return fn;
}

impl NaIRGenPass._codec_lookup_fn -> ir.Function {
    """Map a codec name to 0 (utf-8), 1 (latin-1) or 2 (ascii) at run time.

    The name is normalized the way `encodings.normalize_encoding` does it and
    looked up in CPython's alias table, a dotted name retrying with dots as
    underscores against the aliases only. Returns -1 for an unknown codec and
    -2 for a codec CPython knows that the native decoder does not implement.
    """;
    if self._codec_lookup_function is not None {
        return self._codec_lookup_function;
    }
    import encodings;
    import encodings.aliases;
    import pkgutil;
    supported = {"utf_8": 1, "latin_1": 2, "ascii": 3};
    aliases = encodings.aliases.aliases;
    alias_rows = bytearray();
    for key in sorted(aliases) {
        alias_rows += bytes([supported.get(aliases[key], 4)]) + key.encode() + b"\x00";
    }
    module_rows = bytearray();
    for mod in sorted(m.name for m in pkgutil.iter_modules(encodings.__path__)) {
        if mod != "aliases" and mod not in aliases {
            module_rows += bytes([supported.get(mod, 4)]) + mod.encode() + b"\x00";
        }
    }
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);
    fn = ir.Function(
        self.llvm_module, ir.FunctionType(i64, [i8p]), name="__jac_str_codec_id"
    );
    fn.linkage = "private";
    name = fn.args[0];
    name.name = "name";
    alias_table = self._private_cstr(bytes(alias_rows) + b"\x00", ".codec.aliases");
    module_table = self._private_cstr(bytes(module_rows) + b"\x00", ".codec.modules");
    lookup = self._name_lookup_fn();
    entry_bb = fn.append_basic_block("entry");
    loop = fn.append_basic_block("loop");
    classify = fn.append_basic_block("classify");
    keep = fn.append_basic_block("keep");
    write = fn.append_basic_block("write");
    skip_bb = fn.append_basic_block("skip");
    finish = fn.append_basic_block("finish");
    try_module = fn.append_basic_block("try.module");
    try_dotted = fn.append_basic_block("try.dotted");
    undot = fn.append_basic_block("undot");
    undot_body = fn.append_basic_block("undot.body");
    undot_done = fn.append_basic_block("undot.done");
    mapped = fn.append_basic_block("mapped");
    unknown = fn.append_basic_block("unknown");
    b = ir.IRBuilder(entry_bb);
    cap = 128;
    buf = b.bitcast(b.alloca(ir.ArrayType(i8, cap), name="norm"), i8p, name="norm.p");
    b.branch(loop);

    b.position_at_end(loop);
    pos = b.phi(i64, name="pos");
    out = b.phi(i64, name="out");
    punct = b.phi(ir.IntType(1), name="punct");
    dotted = b.phi(ir.IntType(1), name="dotted");
    pos.add_incoming(zero, entry_bb);
    out.add_incoming(zero, entry_bb);
    punct.add_incoming(ir.Constant(ir.IntType(1), 0), entry_bb);
    dotted.add_incoming(ir.Constant(ir.IntType(1), 0), entry_bb);
    ch = b.zext(b.load(b.gep(name, [pos])), i64, name="ch");
    b.cbranch(b.icmp_unsigned("==", ch, zero), finish, classify);

    b.position_at_end(classify);
    upper = b.and_(
        b.icmp_unsigned(">=", ch, ir.Constant(i64, 65)),
        b.icmp_unsigned("<=", ch, ir.Constant(i64, 90))
    );
    lower = b.select(upper, b.add(ch, ir.Constant(i64, 32)), ch, name="lower");
    alpha = b.and_(
        b.icmp_unsigned(">=", lower, ir.Constant(i64, 97)),
        b.icmp_unsigned("<=", lower, ir.Constant(i64, 122))
    );
    digit = b.and_(
        b.icmp_unsigned(">=", lower, ir.Constant(i64, 48)),
        b.icmp_unsigned("<=", lower, ir.Constant(i64, 57))
    );
    is_dot = b.icmp_unsigned("==", lower, ir.Constant(i64, 46), name="is.dot");
    b.cbranch(b.or_(b.or_(alpha, digit), is_dot), keep, skip_bb);

    b.position_at_end(skip_bb);
    pos.add_incoming(b.add(pos, one), skip_bb);
    out.add_incoming(out, skip_bb);
    punct.add_incoming(ir.Constant(ir.IntType(1), 1), skip_bb);
    dotted.add_incoming(dotted, skip_bb);
    b.branch(loop);

    b.position_at_end(keep);
    sep = b.and_(punct, b.icmp_unsigned(">", out, zero), name="sep");
    at_pos = b.add(out, b.zext(sep, i64), name="at");
    b.cbranch(b.icmp_unsigned(">=", at_pos, ir.Constant(i64, cap - 1)), unknown, write);

    b.position_at_end(write);
    b.store(ir.Constant(i8, 95), b.gep(buf, [out]));
    b.store(b.trunc(lower, i8), b.gep(buf, [at_pos]));
    pos.add_incoming(b.add(pos, one), write);
    out.add_incoming(b.add(at_pos, one), write);
    punct.add_incoming(ir.Constant(ir.IntType(1), 0), write);
    dotted.add_incoming(b.or_(dotted, is_dot), write);
    b.branch(loop);

    b.position_at_end(finish);
    b.store(ir.Constant(i8, 0), b.gep(buf, [out]));
    as_alias = b.call(lookup, [buf, alias_table], name="as.alias");
    b.cbranch(b.icmp_unsigned("!=", as_alias, zero), mapped, try_module);

    b.position_at_end(try_module);
    as_module = b.call(lookup, [buf, module_table], name="as.module");
    b.cbranch(b.icmp_unsigned("!=", as_module, zero), mapped, try_dotted);

    b.position_at_end(try_dotted);
    b.cbranch(dotted, undot, unknown);

    b.position_at_end(undot);
    idx = b.phi(i64, name="idx");
    idx.add_incoming(zero, try_dotted);
    b.cbranch(b.icmp_unsigned(">=", idx, out), undot_done, undot_body);
    b.position_at_end(undot_body);
    slot = b.gep(buf, [idx]);
    cur = b.load(slot);
    b.store(
        b.select(
            b.icmp_unsigned("==", cur, ir.Constant(i8, 46)), ir.Constant(i8, 95), cur
        ),
        slot
    );
    idx.add_incoming(b.add(idx, one), undot_body);
    b.branch(undot);
    b.position_at_end(undot_done);
    as_undotted = b.call(lookup, [buf, alias_table], name="as.undotted");
    b.cbranch(b.icmp_unsigned("!=", as_undotted, zero), mapped, unknown);

    b.position_at_end(unknown);
    b.ret(ir.Constant(i64, -1));

    b.position_at_end(mapped);
    tag = b.phi(i64, name="tag");
    tag.add_incoming(as_alias, finish);
    tag.add_incoming(as_module, try_module);
    tag.add_incoming(as_undotted, undot_done);
    b.ret(
        b.select(
            b.icmp_unsigned("==", tag, ir.Constant(i64, 4)),
            ir.Constant(i64, -2),
            b.sub(tag, one)
        )
    );
    self._codec_lookup_function = fn;
    return fn;
}

impl NaIRGenPass._bytes_decode_fn -> ir.Function {
    """Decode bytes as utf-8 (codec 0), latin-1 (1) or ascii (2), CPython style.

    Error handlers: 0 strict, 1 ignore, 2 replace, 3 backslashreplace,
    4 surrogateescape, 5 surrogatepass; any other id fails like strict and
    the caller picks the exception. A utf-8 error spans CPython's maximal
    invalid subpart, so `replace` writes one U+FFFD per subpart. Lone
    surrogates are stored as their three-byte encoding, as native strings
    hold them.

    With `measure` set nothing is kept: every write lands in the first bytes
    of `out`, a four-byte scratch buffer, and the result is the decoded
    length. Returns the length written, or -1 on an error the handler does not
    absorb, leaving start, end and a reason code in `info[0..2]`; `info[3]`
    counts the errors a handler absorbed.
    """;
    if self._bytes_decode_function is not None {
        return self._bytes_decode_function;
    }
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);
    fnty = ir.FunctionType(i64, [i8p, i64, i64, i64, i8p, i64, i64.as_pointer()]);
    fn = ir.Function(self.llvm_module, fnty, name="__jac_bytes_decode");
    fn.linkage = "private";
    (data, size, codec, errors, out, measure, info) = fn.args;
    for (arg, arg_name) in zip(
        fn.args, ["data", "size", "codec", "errors", "out", "measure", "info"]
    ) {
        arg.name = arg_name;
    }
    memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    b = ir.IRBuilder(fn.append_basic_block("entry"));
    entry_bb = b.block;
    measuring = b.icmp_unsigned("!=", measure, zero, name="measuring");
    absorbed = b.gep(info, [ir.Constant(i64, 3)], name="absorbed");
    b.store(zero, absorbed);

    loop = fn.append_basic_block("loop");
    done = fn.append_basic_block("done");
    body = fn.append_basic_block("body");
    plain = fn.append_basic_block("plain");
    high = fn.append_basic_block("high");
    latin = fn.append_basic_block("latin");
    ascii_bad = fn.append_basic_block("ascii.bad");
    utf8 = fn.append_basic_block("utf8");
    lead_ok = fn.append_basic_block("lead.ok");
    cont = fn.append_basic_block("cont");
    cont_have = fn.append_basic_block("cont.have");
    cont_check = fn.append_basic_block("cont.check");
    cont_next = fn.append_basic_block("cont.next");
    valid = fn.append_basic_block("valid");
    bad = fn.append_basic_block("bad");
    ignore = fn.append_basic_block("ignore");
    replace = fn.append_basic_block("replace");
    escape = fn.append_basic_block("escape");
    escape_body = fn.append_basic_block("escape.body");
    escape_done = fn.append_basic_block("escape.done");
    smuggle = fn.append_basic_block("smuggle");
    smuggle_body = fn.append_basic_block("smuggle.body");
    smuggle_done = fn.append_basic_block("smuggle.done");
    passthru = fn.append_basic_block("passthru");
    passthru_check = fn.append_basic_block("passthru.check");
    passthru_ok = fn.append_basic_block("passthru.ok");
    fail = fn.append_basic_block("fail");

    b.branch(loop);
    b.position_at_end(loop);
    pos = b.phi(i64, name="pos");
    written = b.phi(i64, name="written");
    pos.add_incoming(zero, entry_bb);
    written.add_incoming(zero, entry_bb);
    b.cbranch(b.icmp_signed(">=", pos, size), done, body);
    b.position_at_end(done);
    b.ret(written);

    b.position_at_end(body);
    ch = b.zext(b.load(b.gep(data, [pos])), i64, name="ch");
    pos_next = b.add(pos, one, name="pos.next");
    b.cbranch(b.icmp_unsigned("<", ch, ir.Constant(i64, 128)), plain, high);

    b.position_at_end(plain);
    base = b.select(measuring, zero, written, name="plain.at");
    b.store(b.trunc(ch, i8), b.gep(out, [base]));
    pos.add_incoming(pos_next, plain);
    written.add_incoming(b.add(written, one), plain);
    b.branch(loop);

    b.position_at_end(high);
    by_codec = b.switch(codec, ascii_bad);
    by_codec.add_case(ir.Constant(i64, 0), utf8);
    by_codec.add_case(ir.Constant(i64, 1), latin);

    b.position_at_end(latin);
    base = b.select(measuring, zero, written, name="latin.at");
    b.store(
        b.trunc(b.or_(b.lshr(ch, ir.Constant(i64, 6)), ir.Constant(i64, 0xC0)), i8),
        b.gep(out, [base])
    );
    b.store(
        b.trunc(b.or_(b.and_(ch, ir.Constant(i64, 0x3F)), ir.Constant(i64, 0x80)), i8),
        b.gep(out, [b.add(base, one)])
    );
    pos.add_incoming(pos_next, latin);
    written.add_incoming(b.add(written, ir.Constant(i64, 2)), latin);
    b.branch(loop);

    b.position_at_end(ascii_bad);
    b.branch(bad);

    b.position_at_end(utf8);
    need = b.select(
        b.icmp_unsigned("<", ch, ir.Constant(i64, 0xC2)),
        zero,
        b.select(
            b.icmp_unsigned("<", ch, ir.Constant(i64, 0xE0)),
            ir.Constant(i64, 2),
            b.select(
                b.icmp_unsigned("<", ch, ir.Constant(i64, 0xF0)),
                ir.Constant(i64, 3),
                b.select(
                    b.icmp_unsigned("<", ch, ir.Constant(i64, 0xF5)),
                    ir.Constant(i64, 4),
                    zero
                )
            )
        ),
        name="need"
    );
    b.cbranch(b.icmp_unsigned("==", need, zero), bad, lead_ok);

    b.position_at_end(lead_ok);
    lo = b.select(
        b.icmp_unsigned("==", ch, ir.Constant(i64, 0xE0)),
        ir.Constant(i64, 0xA0),
        b.select(
            b.icmp_unsigned("==", ch, ir.Constant(i64, 0xF0)),
            ir.Constant(i64, 0x90),
            ir.Constant(i64, 0x80)
        ),
        name="lo"
    );
    hi = b.select(
        b.icmp_unsigned("==", ch, ir.Constant(i64, 0xED)),
        ir.Constant(i64, 0x9F),
        b.select(
            b.icmp_unsigned("==", ch, ir.Constant(i64, 0xF4)),
            ir.Constant(i64, 0x8F),
            ir.Constant(i64, 0xBF)
        ),
        name="hi"
    );
    b.branch(cont);

    b.position_at_end(cont);
    step = b.phi(i64, name="step");
    step.add_incoming(one, lead_ok);
    b.cbranch(b.icmp_unsigned(">=", step, need), valid, cont_have);

    b.position_at_end(cont_have);
    at_pos = b.add(pos, step, name="cont.at");
    b.cbranch(b.icmp_signed(">=", at_pos, size), bad, cont_check);

    b.position_at_end(cont_check);
    nxt = b.zext(b.load(b.gep(data, [at_pos])), i64, name="cont.byte");
    first = b.icmp_unsigned("==", step, one);
    low = b.select(first, lo, ir.Constant(i64, 0x80));
    top = b.select(first, hi, ir.Constant(i64, 0xBF));
    b.cbranch(
        b.or_(b.icmp_unsigned("<", nxt, low), b.icmp_unsigned(">", nxt, top)),
        bad,
        cont_next
    );

    b.position_at_end(cont_next);
    step.add_incoming(b.add(step, one), cont_next);
    b.branch(cont);

    b.position_at_end(valid);
    base = b.select(measuring, zero, written, name="valid.at");
    b.call(memcpy_fn, [b.gep(out, [base]), b.gep(data, [pos]), need]);
    pos.add_incoming(b.add(pos, need), valid);
    written.add_incoming(b.add(written, need), valid);
    b.branch(loop);

    b.position_at_end(bad);
    end = b.phi(i64, name="bad.end");
    reason = b.phi(i64, name="bad.reason");
    end.add_incoming(pos_next, ascii_bad);
    reason.add_incoming(ir.Constant(i64, 3), ascii_bad);
    end.add_incoming(pos_next, utf8);
    reason.add_incoming(zero, utf8);
    end.add_incoming(size, cont_have);
    reason.add_incoming(ir.Constant(i64, 2), cont_have);
    end.add_incoming(at_pos, cont_check);
    reason.add_incoming(one, cont_check);
    b.store(b.add(b.load(absorbed), one), absorbed);
    by_handler = b.switch(errors, fail);
    by_handler.add_case(ir.Constant(i64, 1), ignore);
    by_handler.add_case(ir.Constant(i64, 2), replace);
    by_handler.add_case(ir.Constant(i64, 3), escape);
    by_handler.add_case(ir.Constant(i64, 4), smuggle);
    by_handler.add_case(ir.Constant(i64, 5), passthru);

    b.position_at_end(ignore);
    pos.add_incoming(end, ignore);
    written.add_incoming(written, ignore);
    b.branch(loop);

    b.position_at_end(replace);
    base = b.select(measuring, zero, written, name="replace.at");
    for (k, byte) in enumerate([0xEF, 0xBF, 0xBD]) {
        b.store(ir.Constant(i8, byte), b.gep(out, [b.add(base, ir.Constant(i64, k))]));
    }
    pos.add_incoming(end, replace);
    written.add_incoming(b.add(written, ir.Constant(i64, 3)), replace);
    b.branch(loop);

    b.position_at_end(escape);
    e_at = b.phi(i64, name="escape.at");
    e_out = b.phi(i64, name="escape.out");
    e_at.add_incoming(pos, bad);
    e_out.add_incoming(written, bad);
    b.cbranch(b.icmp_signed(">=", e_at, end), escape_done, escape_body);
    b.position_at_end(escape_body);
    raw = b.zext(b.load(b.gep(data, [e_at])), i64, name="escape.byte");
    base = b.select(measuring, zero, e_out, name="escape.base");
    digits: list[ir.Value] = [];
    for nibble in [
        b.lshr(raw, ir.Constant(i64, 4)),
        b.and_(raw, ir.Constant(i64, 15))
    ] {
        digits.append(
            b.add(
                nibble,
                b.select(
                    b.icmp_unsigned("<", nibble, ir.Constant(i64, 10)),
                    ir.Constant(i64, 48),
                    ir.Constant(i64, 87)
                )
            )
        );
    }
    for (k, val) in enumerate([ir.Constant(i64, 92), ir.Constant(i64, 120)] + digits) {
        b.store(b.trunc(val, i8), b.gep(out, [b.add(base, ir.Constant(i64, k))]));
    }
    e_at.add_incoming(b.add(e_at, one), escape_body);
    e_out.add_incoming(b.add(e_out, ir.Constant(i64, 4)), escape_body);
    b.branch(escape);
    b.position_at_end(escape_done);
    pos.add_incoming(end, escape_done);
    written.add_incoming(e_out, escape_done);
    b.branch(loop);

    b.position_at_end(smuggle);
    s_at = b.phi(i64, name="smuggle.at");
    s_out = b.phi(i64, name="smuggle.out");
    s_at.add_incoming(pos, bad);
    s_out.add_incoming(written, bad);
    b.cbranch(b.icmp_signed(">=", s_at, end), smuggle_done, smuggle_body);
    b.position_at_end(smuggle_body);
    raw = b.zext(b.load(b.gep(data, [s_at])), i64, name="smuggle.byte");
    base = b.select(measuring, zero, s_out, name="smuggle.base");
    lone = [
        ir.Constant(i64, 0xED),
        b.or_(b.and_(b.lshr(raw, ir.Constant(i64, 6)), one), ir.Constant(i64, 0xB2)),
        b.or_(b.and_(raw, ir.Constant(i64, 0x3F)), ir.Constant(i64, 0x80))
    ];
    for (k, val) in enumerate(lone) {
        b.store(b.trunc(val, i8), b.gep(out, [b.add(base, ir.Constant(i64, k))]));
    }
    s_at.add_incoming(b.add(s_at, one), smuggle_body);
    s_out.add_incoming(b.add(s_out, ir.Constant(i64, 3)), smuggle_body);
    b.branch(smuggle);
    b.position_at_end(smuggle_done);
    pos.add_incoming(end, smuggle_done);
    written.add_incoming(s_out, smuggle_done);
    b.branch(loop);

    b.position_at_end(passthru);
    b.cbranch(
        b.and_(
            b.icmp_unsigned("==", codec, zero),
            b.icmp_signed("<=", b.add(pos, ir.Constant(i64, 3)), size)
        ),
        passthru_check,
        fail
    );
    b.position_at_end(passthru_check);
    lead = b.zext(b.load(b.gep(data, [pos])), i64);
    mid = b.zext(b.load(b.gep(data, [b.add(pos, one)])), i64);
    last = b.zext(b.load(b.gep(data, [b.add(pos, ir.Constant(i64, 2))])), i64);
    is_surrogate = b.and_(
        b.and_(
            b.icmp_unsigned("==", lead, ir.Constant(i64, 0xED)),
            b.icmp_unsigned(">=", mid, ir.Constant(i64, 0xA0))
        ),
        b.and_(
            b.icmp_unsigned("<=", mid, ir.Constant(i64, 0xBF)),
            b.and_(
                b.icmp_unsigned(">=", last, ir.Constant(i64, 0x80)),
                b.icmp_unsigned("<=", last, ir.Constant(i64, 0xBF))
            )
        )
    );
    b.cbranch(is_surrogate, passthru_ok, fail);
    b.position_at_end(passthru_ok);
    base = b.select(measuring, zero, written, name="passthru.at");
    b.call(memcpy_fn, [b.gep(out, [base]), b.gep(data, [pos]), ir.Constant(i64, 3)]);
    pos.add_incoming(b.add(pos, ir.Constant(i64, 3)), passthru_ok);
    written.add_incoming(b.add(written, ir.Constant(i64, 3)), passthru_ok);
    b.branch(loop);

    b.position_at_end(fail);
    b.store(pos, b.gep(info, [zero]));
    b.store(end, b.gep(info, [one]));
    b.store(reason, b.gep(info, [ir.Constant(i64, 2)]));
    b.ret(ir.Constant(i64, -1));

    self._bytes_decode_function = fn;
    return fn;
}

impl NaIRGenPass._emit_bytes_decode(
    target: ir.Value,
    args: list[ir.Value],
    kwargs: dict[str, uni.UniNode],
    call_node: (uni.UniNode | None)
) -> (ir.Value | None) {
    """Lower `bytes.decode(encoding="utf-8", errors="strict")`.

    Literal arguments resolve at compile time; a literal naming a codec
    CPython knows but this decoder does not implement is left unlowered.
    Other arguments resolve at run time. Empty input decodes to "" without
    looking the codec up, as CPython does.
    """;
    import codecs;
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    handlers = {
        "strict": 0,
        "ignore": 1,
        "replace": 2,
        "backslashreplace": 3,
        "surrogateescape": 4,
        "surrogatepass": 5,
        "xmlcharrefreplace": 6,
        "namereplace": 6
    };
    unknown_handler = 7;
    if len(args) > 2
        or any(key not in ("encoding", "errors") for key in kwargs)
        or (args and "encoding" in kwargs)
        or (len(args) > 1 and "errors" in kwargs) {
        return None;
    }
    positional: list[uni.UniNode] = [];
    if isinstance(call_node, uni.FuncCall) {
        positional = [
            param
            for param in (call_node.params or [])
            if not isinstance(param, uni.KWPair)
        ];
    }
    specs: list[tuple[(str | None), (ir.Value | None)]] = [];
    for (idx, (key, fallback)) in enumerate(
        [("encoding", "utf-8"), ("errors", "strict")]
    ) {
        if idx < len(args) {
            arg_node = positional[idx] if len(positional) == len(args) else None;
            specs.append((self._decode_literal(arg_node), args[idx]));
        } elif key in kwargs {
            literal = self._decode_literal(kwargs[key]);
            value: (ir.Value | None) = None;
            if literal is None {
                raw = self._codegen_expr(kwargs[key]);
                if raw is None {
                    return None;
                }
                value = self._str_norm(raw);
            }
            specs.append((literal, value));
        } else {
            specs.append((fallback, None));
        }
    }
    ((enc_literal, enc_value), (err_literal, err_value)) = (specs[0], specs[1]);
    for (literal, value) in specs {
        if literal is None and (value is None or value.type != i8p) {
            return None;
        }
    }
    b = self.builder;
    codec: ir.Value = ir.Constant(i64, 0);
    errors: ir.Value = ir.Constant(i64, 0);
    data = self._bytes_data_ptr(target);
    n = self._bytes_len_val(target);
    nonempty = b.icmp_signed("!=", n, ir.Constant(i64, 0), name="dec.nonempty");
    if enc_literal is not None {
        codec_name: (str | None) = None;
        try {
            codec_name = codecs.lookup(enc_literal).name;
        } except LookupError {
            self._emit_runtime_raise(
                nonempty, "LookupError", f"unknown encoding: {enc_literal}"
            );
            codec_name = "utf-8";
        }
        codec_ids = {"utf-8": 0, "iso8859-1": 1, "ascii": 2};
        if codec_name not in codec_ids {
            return None;
        }
        codec = ir.Constant(i64, codec_ids[codec_name]);
    } elif enc_value is not None {
        codec = b.call(self._codec_lookup_fn(), [enc_value], name="dec.codec");
        fn = b.function;
        missing = fn.append_basic_block("dec.codec.missing");
        found = fn.append_basic_block("dec.codec.found");
        b.cbranch(
            b.and_(b.icmp_signed("<", codec, ir.Constant(i64, 0)), nonempty),
            missing,
            found
        );
        b.position_at_end(missing);
        size = b.add(
            self._call_str_len(b, enc_value), ir.Constant(i64, 96), name="dec.msg.size"
        );
        self._set_rc_ctx("bytes_decode", "");
        msg = self._str_alloc(b, size, name="dec.msg");
        self._clear_rc_ctx();
        unknown_bb = fn.append_basic_block("dec.codec.unknown");
        unsupported_bb = fn.append_basic_block("dec.codec.unsupported");
        b.cbranch(
            b.icmp_signed("==", codec, ir.Constant(i64, -1)), unknown_bb, unsupported_bb
        );
        snprintf_fn = self._get_or_declare_extern(
            "snprintf", ir.IntType(32), [i8p, i64, i8p], var_arg=True
        );
        for (block, exc, fmt) in [
            (unknown_bb, "LookupError", "unknown encoding: %s"),
            (
                unsupported_bb,
                "NotImplementedError",
                "native bytes.decode supports utf-8, latin-1 and ascii, not '%s'"
            )
        ] {
            b.position_at_end(block);
            written = b.call(
                snprintf_fn, [msg, size, self._make_global_string(fmt), enc_value]
            );
            self._str_finish(b, msg, b.sext(written, i64));
            self._emit_raise_value(exc, msg);
        }
        b.position_at_end(found);
    }
    if err_literal is not None {
        errors = ir.Constant(i64, handlers.get(err_literal, unknown_handler));
    } elif err_value is not None {
        table = bytearray();
        for (handler, hid) in handlers.items() {
            table += bytes([hid + 1]) + handler.encode() + b"\x00";
        }
        tag = b.call(
            self._name_lookup_fn(),
            [err_value, self._private_cstr(bytes(table) + b"\x00", ".decode.errors")],
            name="dec.errors.tag"
        );
        errors = b.select(
            b.icmp_unsigned("==", tag, ir.Constant(i64, 0)),
            ir.Constant(i64, unknown_handler),
            b.sub(tag, ir.Constant(i64, 1)),
            name="dec.errors"
        );
    }

    info = b.bitcast(
        self._stack_entry_alloca(ir.ArrayType(i64, 4), "dec.info"),
        i64.as_pointer(),
        name="dec.info.p"
    );
    scratch = b.bitcast(
        self._stack_entry_alloca(ir.ArrayType(i8, 4), "dec.scratch"),
        i8p,
        name="dec.scratch.p"
    );
    kernel = self._bytes_decode_fn();
    size = b.call(
        kernel,
        [data, n, codec, errors, scratch, ir.Constant(i64, 1), info],
        name="dec.size"
    );
    fn = b.function;
    failed_bb = fn.append_basic_block("dec.failed");
    ok_bb = fn.append_basic_block("dec.ok");
    b.cbranch(b.icmp_signed("<", size, ir.Constant(i64, 0)), failed_bb, ok_bb);
    b.position_at_end(failed_bb);
    self._emit_decode_failure(data, codec, errors, info, err_value, err_literal);

    b.position_at_end(ok_bb);
    self._set_rc_ctx("bytes_decode", "");
    new_str = self._str_alloc(b, b.add(size, ir.Constant(i64, 1)), name="dec.str");
    self._clear_rc_ctx();
    copy_bb = fn.append_basic_block("dec.copy");
    decode_bb = fn.append_basic_block("dec.decode");
    done_bb = fn.append_basic_block("dec.done");
    absorbed = b.load(b.gep(info, [ir.Constant(i64, 3)]), name="dec.absorbed");
    b.cbranch(
        b.and_(
            b.icmp_unsigned("==", absorbed, ir.Constant(i64, 0)),
            b.icmp_unsigned("==", size, n)
        ),
        copy_bb,
        decode_bb
    );
    b.position_at_end(copy_bb);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    b.call(memcpy_fn, [new_str, data, n]);
    b.branch(done_bb);
    b.position_at_end(decode_bb);
    b.call(kernel, [data, n, codec, errors, new_str, ir.Constant(i64, 0), info]);
    b.branch(done_bb);
    b.position_at_end(done_bb);
    self._str_finish(b, new_str, size);
    self._mark_owned(new_str);
    return new_str;
}

impl NaIRGenPass._emit_decode_failure(
    data: ir.Value,
    codec: ir.Value,
    errors: ir.Value,
    info: ir.Value,
    errors_name: (ir.Value | None),
    errors_literal: (str | None)
) -> None {
    """Raise what CPython raises when a decode error reaches its handler.

    Strict (and a surrogatepass that cannot apply) raises UnicodeDecodeError;
    an error handler that only encodes raises TypeError; an unknown handler
    name raises LookupError, which CPython also defers to the first error.
    """;
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    b = self.builder;
    fn = b.function;
    snprintf_fn = self._get_or_declare_extern(
        "snprintf", i32, [i8p, i64, i8p], var_arg=True
    );
    type_error = "don't know how to handle UnicodeDecodeError in error callback";
    decode_bb = fn.append_basic_block("dec.err.decode");
    if isinstance(errors, ir.Constant) {
        if errors.constant == 6 {
            self._emit_raise_value("TypeError", self._make_global_string(type_error));
            return;
        }
        if errors.constant == 7 {
            self._emit_raise_value(
                "LookupError",
                self._make_global_string(
                    f"unknown error handler name '{errors_literal}'"
                )
            );
            return;
        }
        b.branch(decode_bb);
    } elif errors_name is not None {
        type_bb = fn.append_basic_block("dec.err.type");
        lookup_bb = fn.append_basic_block("dec.err.lookup");
        by_handler = b.switch(errors, decode_bb);
        by_handler.add_case(ir.Constant(i64, 6), type_bb);
        by_handler.add_case(ir.Constant(i64, 7), lookup_bb);
        b.position_at_end(type_bb);
        self._emit_raise_value("TypeError", self._make_global_string(type_error));
        b.position_at_end(lookup_bb);
        size = b.add(
            self._call_str_len(b, errors_name),
            ir.Constant(i64, 40),
            name="dec.msg.size"
        );
        self._set_rc_ctx("bytes_decode", "");
        msg = self._str_alloc(b, size, name="dec.msg");
        self._clear_rc_ctx();
        written = b.call(
            snprintf_fn,
            [
                msg,
                size,
                self._make_global_string("unknown error handler name '%s'"),
                errors_name
            ]
        );
        self._str_finish(b, msg, b.sext(written, i64));
        self._emit_raise_value("LookupError", msg);
    } else {
        b.branch(decode_bb);
    }

    b.position_at_end(decode_bb);
    start = b.load(b.gep(info, [ir.Constant(i64, 0)]), name="dec.err.start");
    end = b.load(b.gep(info, [ir.Constant(i64, 1)]), name="dec.err.end");
    reason_id = b.load(b.gep(info, [ir.Constant(i64, 2)]), name="dec.err.reason");
    reasons = [
        "invalid start byte",
        "invalid continuation byte",
        "unexpected end of data",
        "ordinal not in range(128)"
    ];
    reason = self._make_global_string(reasons[3]);
    for rid in [2, 1, 0] {
        reason = b.select(
            b.icmp_unsigned("==", reason_id, ir.Constant(i64, rid)),
            self._make_global_string(reasons[rid]),
            reason
        );
    }
    codec_name = b.select(
        b.icmp_unsigned("==", codec, ir.Constant(i64, 2)),
        self._make_global_string("ascii"),
        self._make_global_string("utf-8"),
        name="dec.err.codec"
    );
    size = ir.Constant(i64, 160);
    self._set_rc_ctx("bytes_decode", "");
    msg = self._str_alloc(b, size, name="dec.msg");
    self._clear_rc_ctx();
    one_bb = fn.append_basic_block("dec.err.one");
    many_bb = fn.append_basic_block("dec.err.many");
    raise_bb = fn.append_basic_block("dec.err.raise");
    b.cbranch(
        b.icmp_signed("==", b.sub(end, start), ir.Constant(i64, 1)), one_bb, many_bb
    );
    b.position_at_end(one_bb);
    byte = b.zext(b.load(b.gep(data, [start])), i32, name="dec.err.byte");
    one_len = b.call(
        snprintf_fn,
        [
            msg,
            size,
            self._make_global_string(
                "'%s' codec can't decode byte 0x%02x in position %lld: %s"
            ),
            codec_name,
            byte,
            start,
            reason
        ]
    );
    b.branch(raise_bb);
    b.position_at_end(many_bb);
    many_len = b.call(
        snprintf_fn,
        [
            msg,
            size,
            self._make_global_string(
                "'%s' codec can't decode bytes in position %lld-%lld: %s"
            ),
            codec_name,
            start,
            b.sub(end, ir.Constant(i64, 1)),
            reason
        ]
    );
    b.branch(raise_bb);
    b.position_at_end(raise_bb);
    msg_len = b.phi(i32, name="dec.err.len");
    msg_len.add_incoming(one_len, one_bb);
    msg_len.add_incoming(many_len, many_bb);
    self._str_finish(b, msg, b.sext(msg_len, i64));
    self._emit_raise_value("UnicodeDecodeError", msg);
}
