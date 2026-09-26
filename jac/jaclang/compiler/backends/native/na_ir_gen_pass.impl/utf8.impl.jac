impl NaIRGenPass._emit_utf8_helpers -> None {
    if self.utf8_cplen_fn is not None {
        return;
    }
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    memcmp_fn = self._get_or_declare_extern("memcmp", i32, [i8p, i8p, i64]);

    width_fn = self._define_function(
        "__jac_utf8_width", ir.FunctionType(i64, [i64, i64])
    );
    width_fn.linkage = "private";
    width_fn.args[0].name = "lead";
    width_fn.args[1].name = "remaining";
    wb = ir.IRBuilder(width_fn.append_basic_block("entry"));
    lead = width_fn.args[0];
    remaining = width_fn.args[1];
    one = ir.Constant(i64, 1);
    two = ir.Constant(i64, 2);
    three = ir.Constant(i64, 3);
    four = ir.Constant(i64, 4);
    raw = wb.select(
        wb.icmp_unsigned("<", lead, ir.Constant(i64, 0x80)),
        one,
        wb.select(
            wb.icmp_unsigned("<", lead, ir.Constant(i64, 0xC0)),
            one,
            wb.select(
                wb.icmp_unsigned("<", lead, ir.Constant(i64, 0xE0)),
                two,
                wb.select(
                    wb.icmp_unsigned("<", lead, ir.Constant(i64, 0xF0)),
                    three,
                    wb.select(
                        wb.icmp_unsigned("<", lead, ir.Constant(i64, 0xF8)), four, one
                    )
                )
            )
        ),
        name="w.raw"
    );
    wb.ret(
        wb.select(wb.icmp_signed(">", raw, remaining), remaining, raw, name="w.clamped")
    );
    self.utf8_width_fn = width_fn;

    cplen_fn = self._define_function(
        "__jac_utf8_cplen", ir.FunctionType(i64, [i8p, i64])
    );
    cplen_fn.linkage = "private";
    cplen_fn.args[0].name = "s";
    cplen_fn.args[1].name = "blen";
    cb = ir.IRBuilder(cplen_fn.append_basic_block("entry"));
    i_alloca = cb.alloca(i64, name="cp.i");
    n_alloca = cb.alloca(i64, name="cp.n");
    cb.store(ir.Constant(i64, 0), i_alloca);
    cb.store(ir.Constant(i64, 0), n_alloca);
    cond_bb = cplen_fn.append_basic_block("cond");
    body_bb = cplen_fn.append_basic_block("body");
    done_bb = cplen_fn.append_basic_block("done");
    cb.branch(cond_bb);
    cb = ir.IRBuilder(cond_bb);
    cur_i = cb.load(i_alloca, name="cp.cur");
    cb.cbranch(cb.icmp_signed("<", cur_i, cplen_fn.args[1]), body_bb, done_bb);
    cb = ir.IRBuilder(body_bb);
    lead_ptr = cb.gep(cplen_fn.args[0], [cur_i], name="cp.lead.p");
    lead_v = cb.zext(cb.load(lead_ptr), i64, name="cp.lead");
    width_v = cb.call(
        self.utf8_width_fn, [lead_v, cb.sub(cplen_fn.args[1], cur_i)], name="cp.w"
    );
    step_v = cb.select(
        cb.icmp_signed("<", width_v, ir.Constant(i64, 1)),
        ir.Constant(i64, 1),
        width_v,
        name="cp.step"
    );
    cb.store(cb.add(cur_i, step_v), i_alloca);
    cb.store(cb.add(cb.load(n_alloca), ir.Constant(i64, 1)), n_alloca);
    cb.branch(cond_bb);
    cb = ir.IRBuilder(done_bb);
    cb.ret(cb.load(n_alloca, name="cp.count"));
    self.utf8_cplen_fn = cplen_fn;

    boff_fn = self._define_function(
        "__jac_utf8_cp_to_boff", ir.FunctionType(i64, [i8p, i64, i64])
    );
    boff_fn.linkage = "private";
    boff_fn.args[0].name = "s";
    boff_fn.args[1].name = "blen";
    boff_fn.args[2].name = "cp.idx";
    ob = ir.IRBuilder(boff_fn.append_basic_block("entry"));
    oi_alloca = ob.alloca(i64, name="bo.i");
    on_alloca = ob.alloca(i64, name="bo.n");
    ob.store(ir.Constant(i64, 0), oi_alloca);
    ob.store(ir.Constant(i64, 0), on_alloca);
    ocond_bb = boff_fn.append_basic_block("cond");
    ocheck_bb = boff_fn.append_basic_block("check");
    obody_bb = boff_fn.append_basic_block("body");
    ohit_bb = boff_fn.append_basic_block("hit");
    oend_bb = boff_fn.append_basic_block("at_end");
    ob.branch(ocond_bb);
    ob = ir.IRBuilder(ocond_bb);
    ocur_i = ob.load(oi_alloca, name="bo.cur");
    ocur_n = ob.load(on_alloca, name="bo.cpn");
    ob.cbranch(ob.icmp_signed(">=", ocur_n, boff_fn.args[2]), ohit_bb, ocheck_bb);
    ob = ir.IRBuilder(ocheck_bb);
    ob.cbranch(ob.icmp_signed("<", ocur_i, boff_fn.args[1]), obody_bb, oend_bb);
    ob = ir.IRBuilder(obody_bb);
    olead_ptr = ob.gep(boff_fn.args[0], [ocur_i], name="bo.lead.p");
    olead_v = ob.zext(ob.load(olead_ptr), i64, name="bo.lead");
    owidth_v = ob.call(
        self.utf8_width_fn, [olead_v, ob.sub(boff_fn.args[1], ocur_i)], name="bo.w"
    );
    ostep_v = ob.select(
        ob.icmp_signed("<", owidth_v, ir.Constant(i64, 1)),
        ir.Constant(i64, 1),
        owidth_v,
        name="bo.step"
    );
    ob.store(ob.add(ocur_i, ostep_v), oi_alloca);
    ob.store(ob.add(ocur_n, ir.Constant(i64, 1)), on_alloca);
    ob.branch(ocond_bb);
    ob = ir.IRBuilder(ohit_bb);
    ob.ret(ocur_i);
    ob = ir.IRBuilder(oend_bb);
    ob.ret(boff_fn.args[1]);
    self.utf8_cp_to_boff_fn = boff_fn;

    at_fn = self._define_function("__jac_utf8_cp_at", ir.FunctionType(i64, [i8p, i64]));
    at_fn.linkage = "private";
    at_fn.args[0].name = "s";
    at_fn.args[1].name = "blen";
    ab = ir.IRBuilder(at_fn.append_basic_block("entry"));
    lead_p = ab.gep(at_fn.args[0], [ir.Constant(i64, 0)], name="ca.lead.p");
    lead_v = ab.zext(ab.load(lead_p), i64, name="ca.lead");
    ascii_bb = at_fn.append_basic_block("ascii");
    wide_bb = at_fn.append_basic_block("wide");
    ab.cbranch(
        ab.icmp_unsigned("<", lead_v, ir.Constant(i64, 0x80)), ascii_bb, wide_bb
    );
    ab = ir.IRBuilder(ascii_bb);
    ab.ret(lead_v);
    ab = ir.IRBuilder(wide_bb);
    width_v = ab.call(self.utf8_width_fn, [lead_v, at_fn.args[1]], name="ca.w");
    fallback_bb = at_fn.append_basic_block("fallback");
    prep_bb = at_fn.append_basic_block("prep");
    ab.cbranch(ab.icmp_signed(">", width_v, ir.Constant(i64, 1)), prep_bb, fallback_bb);
    ab = ir.IRBuilder(fallback_bb);
    ab.ret(lead_v);
    ab = ir.IRBuilder(prep_bb);
    mask_v = ab.select(
        ab.icmp_signed("==", width_v, ir.Constant(i64, 2)),
        ir.Constant(i64, 0x1F),
        ab.select(
            ab.icmp_signed("==", width_v, ir.Constant(i64, 3)),
            ir.Constant(i64, 0x0F),
            ir.Constant(i64, 0x07),
            name="ca.mask23"
        ),
        name="ca.mask"
    );
    cp_alloca = ab.alloca(i64, name="ca.cp");
    k_alloca = ab.alloca(i64, name="ca.k");
    ab.store(ab.and_(lead_v, mask_v, name="ca.head"), cp_alloca);
    ab.store(ir.Constant(i64, 1), k_alloca);
    kcond_bb = at_fn.append_basic_block("kcond");
    kbody_bb = at_fn.append_basic_block("kbody");
    kdone_bb = at_fn.append_basic_block("kdone");
    ab.branch(kcond_bb);
    ab = ir.IRBuilder(kcond_bb);
    cur_k = ab.load(k_alloca, name="ca.curk");
    ab.cbranch(ab.icmp_signed("<", cur_k, width_v), kbody_bb, kdone_bb);
    ab = ir.IRBuilder(kbody_bb);
    cont_p = ab.gep(at_fn.args[0], [cur_k], name="ca.cont.p");
    cont_v = ab.zext(ab.load(cont_p), i64, name="ca.cont");
    is_cont = ab.icmp_unsigned(
        "==",
        ab.and_(cont_v, ir.Constant(i64, 0xC0), name="ca.cont.bits"),
        ir.Constant(i64, 0x80),
        name="ca.is.cont"
    );
    stop_bb = at_fn.append_basic_block("kstop");
    ab.cbranch(is_cont, stop_bb, kdone_bb);
    ab = ir.IRBuilder(stop_bb);
    cur_cp = ab.load(cp_alloca, name="ca.curcp");
    ab.store(
        ab.or_(
            ab.shl(cur_cp, ir.Constant(i64, 6), name="ca.shl"),
            ab.and_(cont_v, ir.Constant(i64, 0x3F), name="ca.low6"),
            name="ca.accum"
        ),
        cp_alloca
    );
    ab.store(ab.add(cur_k, ir.Constant(i64, 1)), k_alloca);
    ab.branch(kcond_bb);
    ab = ir.IRBuilder(kdone_bb);
    ab.ret(ab.load(cp_alloca, name="ca.result"));
    self.utf8_cp_at_fn = at_fn;

    find_fn = self._define_function(
        "__jac_str_find_b", ir.FunctionType(i64, [i8p, i64, i8p, i64, i64, i64])
    );
    find_fn.linkage = "private";
    find_fn.args[0].name = "hay";
    find_fn.args[1].name = "hlen";
    find_fn.args[2].name = "needle";
    find_fn.args[3].name = "nlen";
    find_fn.args[4].name = "from.b";
    find_fn.args[5].name = "to.b";
    fb = ir.IRBuilder(find_fn.append_basic_block("entry"));
    hay = find_fn.args[0];
    hlen = find_fn.args[1];
    needle = find_fn.args[2];
    nlen = find_fn.args[3];
    from_b = find_fn.args[4];
    to_b = find_fn.args[5];
    neg_one = ir.Constant(i64, -1);
    to_eff = fb.select(fb.icmp_signed(">", to_b, hlen), hlen, to_b, name="fb.to.eff");
    fempty_bb = find_fn.append_basic_block("empty");
    fscan_bb = find_fn.append_basic_block("scan");
    fcheck_bb = find_fn.append_basic_block("check");
    fbody_bb = find_fn.append_basic_block("probe");
    fhit_bb = find_fn.append_basic_block("hit");
    fmiss_bb = find_fn.append_basic_block("miss");
    fb.cbranch(fb.icmp_signed("==", nlen, ir.Constant(i64, 0)), fempty_bb, fscan_bb);
    fb = ir.IRBuilder(fempty_bb);
    fb.ret(
        fb.select(
            fb.icmp_signed("<=", from_b, to_eff), from_b, neg_one, name="fb.empty"
        )
    );
    fb = ir.IRBuilder(fscan_bb);
    pos_alloca = fb.alloca(i64, name="fb.pos");
    fb.store(from_b, pos_alloca);
    limit = fb.sub(to_eff, nlen, name="fb.limit");
    fb.cbranch(fb.icmp_signed("<=", from_b, limit), fcheck_bb, fmiss_bb);
    fb = ir.IRBuilder(fcheck_bb);
    cur_pos = fb.load(pos_alloca, name="fb.cur");
    fb.cbranch(fb.icmp_signed(">", cur_pos, limit), fmiss_bb, fbody_bb);
    fb = ir.IRBuilder(fbody_bb);
    probe_p = fb.gep(hay, [cur_pos], name="fb.probe.p");
    cmp_v = fb.call(memcmp_fn, [probe_p, needle, nlen], name="fb.cmp");
    hit_v = fb.icmp_signed("==", cmp_v, ir.Constant(i32, 0), name="fb.eq");
    fnext_bb = find_fn.append_basic_block("next");
    fb.cbranch(hit_v, fhit_bb, fnext_bb);
    fb = ir.IRBuilder(fnext_bb);
    fb.store(fb.add(cur_pos, ir.Constant(i64, 1)), pos_alloca);
    fb.branch(fcheck_bb);
    fb = ir.IRBuilder(fhit_bb);
    fb.ret(cur_pos);
    fb = ir.IRBuilder(fmiss_bb);
    fb.ret(neg_one);
    self.str_find_b_fn = find_fn;

    rfind_fn = self._define_function(
        "__jac_str_rfind_b", ir.FunctionType(i64, [i8p, i64, i8p, i64, i64, i64])
    );
    rfind_fn.linkage = "private";
    rfind_fn.args[0].name = "hay";
    rfind_fn.args[1].name = "hlen";
    rfind_fn.args[2].name = "needle";
    rfind_fn.args[3].name = "nlen";
    rfind_fn.args[4].name = "from.b";
    rfind_fn.args[5].name = "to.b";
    rb = ir.IRBuilder(rfind_fn.append_basic_block("entry"));
    rhay = rfind_fn.args[0];
    rhlen = rfind_fn.args[1];
    rneedle = rfind_fn.args[2];
    rnlen = rfind_fn.args[3];
    rfrom_b = rfind_fn.args[4];
    rto_b = rfind_fn.args[5];
    rto_eff = rb.select(
        rb.icmp_signed(">", rto_b, rhlen), rhlen, rto_b, name="rb.to.eff"
    );
    rempty_bb = rfind_fn.append_basic_block("empty");
    rscan_bb = rfind_fn.append_basic_block("scan");
    rcheck_bb = rfind_fn.append_basic_block("check");
    rbody_bb = rfind_fn.append_basic_block("probe");
    rhit_bb = rfind_fn.append_basic_block("hit");
    rmiss_bb = rfind_fn.append_basic_block("miss");
    rb.cbranch(rb.icmp_signed("==", rnlen, ir.Constant(i64, 0)), rempty_bb, rscan_bb);
    rb = ir.IRBuilder(rempty_bb);
    rb.ret(
        rb.select(
            rb.icmp_signed("<=", rfrom_b, rto_eff), rto_eff, neg_one, name="rb.empty"
        )
    );
    rb = ir.IRBuilder(rscan_bb);
    rpos_alloca = rb.alloca(i64, name="rb.pos");
    first_pos = rb.sub(rto_eff, rnlen, name="rb.first");
    rb.store(first_pos, rpos_alloca);
    rb.cbranch(rb.icmp_signed(">=", first_pos, rfrom_b), rcheck_bb, rmiss_bb);
    rb = ir.IRBuilder(rcheck_bb);
    rcur_pos = rb.load(rpos_alloca, name="rb.cur");
    rb.cbranch(rb.icmp_signed("<", rcur_pos, rfrom_b), rmiss_bb, rbody_bb);
    rb = ir.IRBuilder(rbody_bb);
    rprobe_p = rb.gep(rhay, [rcur_pos], name="rb.probe.p");
    rcmp_v = rb.call(memcmp_fn, [rprobe_p, rneedle, rnlen], name="rb.cmp");
    rhit_v = rb.icmp_signed("==", rcmp_v, ir.Constant(i32, 0), name="rb.eq");
    rnext_bb = rfind_fn.append_basic_block("prev");
    rb.cbranch(rhit_v, rhit_bb, rnext_bb);
    rb = ir.IRBuilder(rnext_bb);
    rb.store(rb.sub(rcur_pos, ir.Constant(i64, 1)), rpos_alloca);
    rb.branch(rcheck_bb);
    rb = ir.IRBuilder(rhit_bb);
    rb.ret(rcur_pos);
    rb = ir.IRBuilder(rmiss_bb);
    rb.ret(neg_one);
    self.str_rfind_b_fn = rfind_fn;
}

impl NaIRGenPass._call_utf8_cplen(
    b: ir.IRBuilder, ptr: ir.Value, blen: ir.Value, name: str = "s.cplen"
) -> ir.Value {
    if self.utf8_cplen_fn is None {
        self._emit_utf8_helpers();
    }
    return b.call(self.utf8_cplen_fn, [ptr, blen], name=name);
}

impl NaIRGenPass._call_utf8_cp_to_boff(
    b: ir.IRBuilder,
    ptr: ir.Value,
    blen: ir.Value,
    cp_idx: ir.Value,
    name: str = "cp.boff"
) -> ir.Value {
    if self.utf8_cp_to_boff_fn is None {
        self._emit_utf8_helpers();
    }
    return b.call(self.utf8_cp_to_boff_fn, [ptr, blen, cp_idx], name=name);
}

impl NaIRGenPass._call_utf8_cp_at(
    b: ir.IRBuilder, ptr: ir.Value, blen: ir.Value, name: str = "cp.at"
) -> ir.Value {
    if self.utf8_cp_at_fn is None {
        self._emit_utf8_helpers();
    }
    return b.call(self.utf8_cp_at_fn, [ptr, blen], name=name);
}

impl NaIRGenPass._call_str_find_b(
    b: ir.IRBuilder,
    hay: ir.Value,
    hlen: ir.Value,
    needle: ir.Value,
    nlen: ir.Value,
    from_b: ir.Value,
    to_b: ir.Value,
    name: str = "find.b"
) -> ir.Value {
    if self.str_find_b_fn is None {
        self._emit_utf8_helpers();
    }
    return b.call(
        self.str_find_b_fn, [hay, hlen, needle, nlen, from_b, to_b], name=name
    );
}

impl NaIRGenPass._call_str_rfind_b(
    b: ir.IRBuilder,
    hay: ir.Value,
    hlen: ir.Value,
    needle: ir.Value,
    nlen: ir.Value,
    from_b: ir.Value,
    to_b: ir.Value,
    name: str = "rfind.b"
) -> ir.Value {
    if self.str_rfind_b_fn is None {
        self._emit_utf8_helpers();
    }
    return b.call(
        self.str_rfind_b_fn, [hay, hlen, needle, nlen, from_b, to_b], name=name
    );
}

impl NaIRGenPass._call_utf8_width(
    b: ir.IRBuilder, lead: ir.Value, remaining: ir.Value, name: str = "cp.w"
) -> ir.Value {
    if self.utf8_width_fn is None {
        self._emit_utf8_helpers();
    }
    return b.call(self.utf8_width_fn, [lead, remaining], name=name);
}

impl NaIRGenPass._emit_norm_cp_region(
    b: ir.IRBuilder,
    data: ir.Value,
    blen: ir.Value,
    cplen: ir.Value,
    bounds: list[ir.Value | None]
) -> (ir.Value, ir.Value) {
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    raw_start = self._coerce_type(bounds[0], i64) if bounds[0] is not None else zero;
    raw_end = self._coerce_type(bounds[1], i64) if bounds[1] is not None else cplen;
    start = b.select(
        b.icmp_signed("<", raw_start, zero),
        b.add(raw_start, cplen, name="rg.s.wrap"),
        raw_start,
        name="rg.s"
    );
    start = b.select(b.icmp_signed("<", start, zero), zero, start, name="rg.s.lo");
    start = b.select(b.icmp_signed(">", start, cplen), cplen, start, name="rg.s.hi");
    end = b.select(
        b.icmp_signed("<", raw_end, zero),
        b.add(raw_end, cplen, name="rg.e.wrap"),
        raw_end,
        name="rg.e"
    );
    end = b.select(b.icmp_signed("<", end, zero), zero, end, name="rg.e.lo");
    end = b.select(b.icmp_signed(">", end, cplen), cplen, end, name="rg.e.hi");
    start_b = self._call_utf8_cp_to_boff(b, data, blen, start, name="rg.s.b");
    end_b = self._call_utf8_cp_to_boff(b, data, blen, end, name="rg.e.b");
    return (start_b, end_b);
}

impl NaIRGenPass._emit_one_char_str(
    cp: ir.Value, b: (ir.IRBuilder | None) = None
) -> ir.Value {
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    point = self._coerce_type(cp, i64);
    if b is None {
        b = self.builder;
    }
    func = b.basic_block.function;
    ascii_bb = func.append_basic_block("chr1.ascii");
    wide_bb = func.append_basic_block("chr1.wide");
    done_bb = func.append_basic_block("chr1.done");
    b.cbranch(b.icmp_unsigned("<", point, ir.Constant(i64, 128)), ascii_bb, wide_bb);
    b.position_at_end(ascii_bb);
    cached = b.bitcast(
        b.gep(
            self._get_char_cache_gv(),
            [
                ir.Constant(ir.IntType(32), 0),
                point,
                ir.Constant(ir.IntType(32), 2),
                ir.Constant(ir.IntType(32), 0)
            ],
            name="chr1.cached"
        ),
        i8.as_pointer(),
        name="chr1.cached.str"
    );
    ascii_end = b.basic_block;
    b.branch(done_bb);
    b.position_at_end(wide_bb);
    self._set_rc_ctx("chr1", "");
    buf = self._str_alloc(b, ir.Constant(i64, 5), name="chr1.buf");
    self._clear_rc_ctx();
    width = b.select(
        b.icmp_unsigned("<", point, ir.Constant(i64, 2048)),
        ir.Constant(i64, 2),
        b.select(
            b.icmp_unsigned("<", point, ir.Constant(i64, 65536)),
            ir.Constant(i64, 3),
            ir.Constant(i64, 4),
            name="chr1.width.wide"
        ),
        name="chr1.width"
    );
    lead_prefix = b.select(
        b.icmp_signed("==", width, ir.Constant(i64, 2)),
        ir.Constant(i64, 192),
        b.select(
            b.icmp_signed("==", width, ir.Constant(i64, 3)),
            ir.Constant(i64, 224),
            ir.Constant(i64, 240),
            name="chr1.lead.wide"
        ),
        name="chr1.lead.prefix"
    );
    continuation = b.sub(width, ir.Constant(i64, 1), name="chr1.cont");
    lead = b.or_(
        lead_prefix,
        b.lshr(point, b.mul(continuation, ir.Constant(i64, 6)), name="chr1.lead.bits"),
        name="chr1.lead"
    );
    b.store(b.trunc(lead, i8, name="chr1.lead.byte"), buf);
    for offset in range(1, 4) {
        position = ir.Constant(i64, offset);
        shift = b.select(
            b.icmp_unsigned("<", position, width, name=f"chr1.in.{offset}"),
            b.mul(
                b.sub(continuation, position, name=f"chr1.rest.{offset}"),
                ir.Constant(i64, 6),
                name=f"chr1.shift.{offset}"
            ),
            ir.Constant(i64, 0),
            name=f"chr1.bits.{offset}"
        );
        payload = b.and_(
            b.lshr(point, shift, name=f"chr1.part.{offset}"),
            ir.Constant(i64, 63),
            name=f"chr1.low.{offset}"
        );
        b.store(
            b.trunc(
                b.or_(payload, ir.Constant(i64, 128), name=f"chr1.byte.{offset}"),
                i8,
                name=f"chr1.contb.{offset}"
            ),
            b.gep(buf, [position], name=f"chr1.slot.{offset}")
        );
    }
    self._str_finish(b, buf, width);
    wide_end = b.basic_block;
    b.branch(done_bb);
    b.position_at_end(done_bb);
    result = b.phi(i8.as_pointer(), name="chr1.result");
    result.add_incoming(cached, ascii_end);
    result.add_incoming(buf, wide_end);
    return self._mark_owned(result);
}

impl NaIRGenPass._emit_decode_cp(
    data: ir.Value, byte_off: ir.Value, blen: ir.Value, b: (ir.IRBuilder | None) = None
) -> (ir.Value, ir.Value) {
    if b is None {
        b = self.builder;
    }
    i64 = ir.IntType(64);
    remaining = b.sub(blen, byte_off, name="dec.rem");
    char_ptr = b.gep(data, [byte_off], name="dec.at.p");
    lead_v = b.zext(b.load(char_ptr), i64, name="dec.lead");
    width_v = self._call_utf8_width(b, lead_v, remaining, name="dec.w");
    width_v = b.select(
        b.icmp_signed("<", width_v, ir.Constant(i64, 1)),
        ir.Constant(i64, 1),
        width_v,
        name="dec.w.min"
    );
    cp_v = self._call_utf8_cp_at(b, char_ptr, remaining, name="dec.cp");
    return (cp_v, width_v);
}

impl NaIRGenPass._codegen_str_char_at(
    data: ir.Value, byte_off: ir.Value, blen: ir.Value, b: (ir.IRBuilder | None) = None
) -> (ir.Value, ir.Value) {
    (cp_v, width_v) = self._emit_decode_cp(data, byte_off, blen, b=b);
    return (self._emit_one_char_str(cp_v, b=b), width_v);
}

impl NaIRGenPass._emit_cp_in_charset(
    cp: ir.Value, charset: ir.Value, charset_blen: ir.Value
) -> ir.Value {
    b = self.builder;
    i1 = ir.IntType(1);
    i64 = ir.IntType(64);
    func = b.basic_block.function;

    i_alloca = self._entry_alloca(i64, "sc.i");
    b.store(ir.Constant(i64, 0), i_alloca);
    cond_bb = func.append_basic_block("sc.cond");
    body_bb = func.append_basic_block("sc.body");
    next_bb = func.append_basic_block("sc.next");
    yes_bb = func.append_basic_block("sc.yes");
    no_bb = func.append_basic_block("sc.no");
    join_bb = func.append_basic_block("sc.join");
    b.branch(cond_bb);
    b.position_at_end(cond_bb);
    cur_i = b.load(i_alloca, name="sc.cur");
    b.cbranch(b.icmp_signed("<", cur_i, charset_blen), body_bb, no_bb);
    b.position_at_end(body_bb);
    (set_cp, set_w) = self._emit_decode_cp(charset, cur_i, charset_blen, b=b);
    is_eq = b.icmp_signed("==", set_cp, cp, name="sc.eq");
    b.cbranch(is_eq, yes_bb, next_bb);
    b.position_at_end(next_bb);
    b.store(b.add(cur_i, set_w, name="sc.next.i"), i_alloca);
    b.branch(cond_bb);
    b.position_at_end(yes_bb);
    b.branch(join_bb);
    b.position_at_end(no_bb);
    b.branch(join_bb);
    b.position_at_end(join_bb);
    result = b.phi(i1, name="sc.result");
    result.add_incoming(ir.Constant(i1, 1), yes_bb);
    result.add_incoming(ir.Constant(i1, 0), no_bb);
    return result;
}
