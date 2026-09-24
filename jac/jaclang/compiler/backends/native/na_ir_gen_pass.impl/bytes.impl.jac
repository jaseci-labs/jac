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
