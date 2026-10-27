def _u8_is_cont(b: ir.IRBuilder, byte: ir.Value, name: str) -> ir.Value;

def _u8_is_start(b: ir.IRBuilder, s: ir.Value, i: ir.Value, name: str) -> ir.Value;

def _u8_store_cursor(
    b: ir.IRBuilder, slot: ir.Value, values: list[ir.Value], name: str
) -> None;

impl NaIRGenPass._emit_utf8_helpers -> None {
    if self.utf8_cplen_fn is not None {
        return;
    }
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    if self.str_isascii_fn is None {
        self._emit_str_len_helpers();
    }
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);
    neg_one = ir.Constant(i64, -1);

    lat_fn = self._define_function(
        "__jac_utf8_cp_len_at", ir.FunctionType(i64, [i8p, i64, i64])
    );
    lat_fn.linkage = "private";
    (l_s, l_n, l_off) = (lat_fn.args[0], lat_fn.args[1], lat_fn.args[2]);
    _l_entry = lat_fn.append_basic_block("entry");
    _l_zero = lat_fn.append_basic_block("zero");
    _l_start = lat_fn.append_basic_block("start");
    _l_chk = lat_fn.append_basic_block("chk");
    _l_look = lat_fn.append_basic_block("look");
    _l_more = lat_fn.append_basic_block("more");
    _l_done = lat_fn.append_basic_block("done");
    b = ir.IRBuilder(_l_entry);
    b.cbranch(b.icmp_signed("<", l_off, l_n, name="u8la.inb"), _l_start, _l_zero);
    b = ir.IRBuilder(_l_zero);
    b.ret(zero);
    b = ir.IRBuilder(_l_start);
    b.branch(_l_chk);
    b = ir.IRBuilder(_l_chk);
    l_w = b.phi(i64, name="u8la.w");
    l_w.add_incoming(one, _l_start);
    l_pos = b.add(l_off, l_w, name="u8la.pos");
    b.cbranch(b.icmp_signed("<", l_pos, l_n, name="u8la.go"), _l_look, _l_done);
    b = ir.IRBuilder(_l_look);
    l_c = _u8_is_cont(
        b, b.load(b.gep(l_s, [l_pos], name="u8la.p"), name="u8la.b"), "u8la.cont"
    );
    b.cbranch(l_c, _l_more, _l_done);
    b = ir.IRBuilder(_l_more);
    l_w.add_incoming(b.add(l_w, one, name="u8la.w1"), _l_more);
    b.branch(_l_chk);
    b = ir.IRBuilder(_l_done);
    b.ret(l_w);
    self.utf8_cp_len_at_fn = lat_fn;

    starts_fn = self._define_function(
        "__jac_utf8_starts", ir.FunctionType(i64, [i8p, i64, i64])
    );
    starts_fn.linkage = "private";
    (c_s, c_lo, c_hi) = (starts_fn.args[0], starts_fn.args[1], starts_fn.args[2]);
    _c_entry = starts_fn.append_basic_block("entry");
    _c_chk = starts_fn.append_basic_block("chk");
    _c_body = starts_fn.append_basic_block("body");
    _c_done = starts_fn.append_basic_block("done");
    b = ir.IRBuilder(_c_entry);
    b.branch(_c_chk);
    b = ir.IRBuilder(_c_chk);
    c_i = b.phi(i64, name="u8st.i");
    c_i.add_incoming(c_lo, _c_entry);
    c_c = b.phi(i64, name="u8st.c");
    c_c.add_incoming(zero, _c_entry);
    b.cbranch(b.icmp_signed("<", c_i, c_hi, name="u8st.go"), _c_body, _c_done);
    b = ir.IRBuilder(_c_body);
    c_st = _u8_is_start(b, c_s, c_i, "u8st.start");
    c_c.add_incoming(
        b.add(c_c, b.zext(c_st, i64, name="u8st.inc"), name="u8st.c1"), _c_body
    );
    c_i.add_incoming(b.add(c_i, one, name="u8st.i1"), _c_body);
    b.branch(_c_chk);
    b = ir.IRBuilder(_c_done);
    b.ret(c_c);

    seek_fn = self._define_function(
        "__jac_utf8_seek", ir.FunctionType(i64, [i8p, i64, i64, i64, i64])
    );
    seek_fn.linkage = "private";
    (o_s, o_n, o_k0, o_off0, o_k) = (
        seek_fn.args[0],
        seek_fn.args[1],
        seek_fn.args[2],
        seek_fn.args[3],
        seek_fn.args[4]
    );
    _o_entry = seek_fn.append_basic_block("entry");
    _o_chk = seek_fn.append_basic_block("chk");
    _o_body = seek_fn.append_basic_block("body");
    _o_found = seek_fn.append_basic_block("found");
    _o_cont = seek_fn.append_basic_block("cont");
    _o_done = seek_fn.append_basic_block("done");
    b = ir.IRBuilder(_o_entry);
    b.branch(_o_chk);
    b = ir.IRBuilder(_o_chk);
    o_i = b.phi(i64, name="u8sk.i");
    o_i.add_incoming(o_off0, _o_entry);
    o_c = b.phi(i64, name="u8sk.c");
    o_c.add_incoming(o_k0, _o_entry);
    b.cbranch(b.icmp_signed("<", o_i, o_n, name="u8sk.go"), _o_body, _o_done);
    b = ir.IRBuilder(_o_body);
    o_st = _u8_is_start(b, o_s, o_i, "u8sk.start");
    b.cbranch(
        b.and_(o_st, b.icmp_signed("==", o_c, o_k, name="u8sk.eq"), name="u8sk.hit"),
        _o_found,
        _o_cont
    );
    b = ir.IRBuilder(_o_found);
    b.ret(o_i);
    b = ir.IRBuilder(_o_cont);
    o_c.add_incoming(
        b.add(o_c, b.zext(o_st, i64, name="u8sk.inc"), name="u8sk.c1"), _o_cont
    );
    o_i.add_incoming(b.add(o_i, one, name="u8sk.i1"), _o_cont);
    b.branch(_o_chk);
    b = ir.IRBuilder(_o_done);
    b.ret(o_n);

    prev_fn = self._define_function(
        "__jac_utf8_prev", ir.FunctionType(i64, [i8p, i64])
    );
    prev_fn.linkage = "private";
    (p_s, p_off) = (prev_fn.args[0], prev_fn.args[1]);
    _p_entry = prev_fn.append_basic_block("entry");
    _p_neg = prev_fn.append_basic_block("before");
    _p_start = prev_fn.append_basic_block("start");
    _p_chk = prev_fn.append_basic_block("chk");
    _p_look = prev_fn.append_basic_block("look");
    _p_step = prev_fn.append_basic_block("step");
    _p_done = prev_fn.append_basic_block("done");
    b = ir.IRBuilder(_p_entry);
    b.cbranch(b.icmp_signed("<=", p_off, zero, name="u8pv.atz"), _p_neg, _p_start);
    b = ir.IRBuilder(_p_neg);
    b.ret(neg_one);
    b = ir.IRBuilder(_p_start);
    p_first = b.sub(p_off, one, name="u8pv.p0");
    b.branch(_p_chk);
    b = ir.IRBuilder(_p_chk);
    p_p = b.phi(i64, name="u8pv.p");
    p_p.add_incoming(p_first, _p_start);
    b.cbranch(b.icmp_signed("<=", p_p, zero, name="u8pv.zero"), _p_done, _p_look);
    b = ir.IRBuilder(_p_look);
    p_c = _u8_is_cont(
        b, b.load(b.gep(p_s, [p_p], name="u8pv.bp"), name="u8pv.b"), "u8pv.cont"
    );
    b.cbranch(p_c, _p_step, _p_done);
    b = ir.IRBuilder(_p_step);
    p_p.add_incoming(b.sub(p_p, one, name="u8pv.p1"), _p_step);
    b.branch(_p_chk);
    b = ir.IRBuilder(_p_done);
    b.ret(p_p);
    self.utf8_prev_fn = prev_fn;

    back_fn = self._define_function(
        "__jac_utf8_seek_back", ir.FunctionType(i64, [i8p, i64, i64, i64])
    );
    back_fn.linkage = "private";
    (r_s, r_k0, r_off0, r_k) = (
        back_fn.args[0],
        back_fn.args[1],
        back_fn.args[2],
        back_fn.args[3]
    );
    _r_entry = back_fn.append_basic_block("entry");
    _r_chk = back_fn.append_basic_block("chk");
    _r_step = back_fn.append_basic_block("step");
    _r_done = back_fn.append_basic_block("done");
    b = ir.IRBuilder(_r_entry);
    b.branch(_r_chk);
    b = ir.IRBuilder(_r_chk);
    r_p = b.phi(i64, name="u8sb.p");
    r_p.add_incoming(r_off0, _r_entry);
    r_c = b.phi(i64, name="u8sb.c");
    r_c.add_incoming(r_k0, _r_entry);
    b.cbranch(
        b.and_(
            b.icmp_signed(">", r_c, r_k, name="u8sb.more"),
            b.icmp_signed(">", r_p, zero, name="u8sb.room"),
            name="u8sb.go"
        ),
        _r_step,
        _r_done
    );
    b = ir.IRBuilder(_r_step);
    r_p.add_incoming(b.call(prev_fn, [r_s, r_p], name="u8sb.p1"), _r_step);
    r_c.add_incoming(b.sub(r_c, one, name="u8sb.c1"), _r_step);
    b.branch(_r_chk);
    b = ir.IRBuilder(_r_done);
    b.ret(r_p);

    cur_fn = None if self._nogc_headerless() else self._utf8_cursor_fn();
    (f_total, f_k, f_off) = (
        ir.Constant(i64, UTF8_CURSOR_TOTAL),
        ir.Constant(i64, UTF8_CURSOR_K),
        ir.Constant(i64, UTF8_CURSOR_OFF)
    );

    cplen_fn = self._define_function(
        "__jac_utf8_cplen", ir.FunctionType(i64, [i8p, i8p, i64, i1])
    );
    cplen_fn.linkage = "private";
    (l_base, l_s, l_n, l_ascii) = (
        cplen_fn.args[0],
        cplen_fn.args[1],
        cplen_fn.args[2],
        cplen_fn.args[3]
    );
    _l_entry = cplen_fn.append_basic_block("entry");
    _l_fast = cplen_fn.append_basic_block("ascii");
    _l_plain = cplen_fn.append_basic_block("plain");
    b = ir.IRBuilder(_l_fast);
    b.ret(l_n);
    b = ir.IRBuilder(_l_plain);
    b.ret(b.call(starts_fn, [l_s, zero, l_n], name="u8cp.scan"));
    b = ir.IRBuilder(_l_entry);
    if cur_fn is None {
        b.cbranch(l_ascii, _l_fast, _l_plain);
    } else {
        _l_look = cplen_fn.append_basic_block("look");
        _l_cached = cplen_fn.append_basic_block("cached");
        _l_known = cplen_fn.append_basic_block("known");
        _l_count = cplen_fn.append_basic_block("count");
        b.cbranch(l_ascii, _l_fast, _l_look);
        b = ir.IRBuilder(_l_look);
        l_cur = b.call(cur_fn, [l_base, l_s, l_n], name="u8cp.cur");
        b.cbranch(
            b.icmp_unsigned(
                "==", l_cur, ir.Constant(l_cur.type, None), name="u8cp.nocur"
            ),
            _l_plain,
            _l_cached
        );
        b = ir.IRBuilder(_l_cached);
        l_total = b.load(b.gep(l_cur, [f_total], name="u8cp.tp"), name="u8cp.total");
        b.cbranch(
            b.icmp_signed(">=", l_total, zero, name="u8cp.has"), _l_known, _l_count
        );
        b = ir.IRBuilder(_l_known);
        b.ret(l_total);
        b = ir.IRBuilder(_l_count);
        l_at = b.load(b.gep(l_cur, [f_off], name="u8cp.op"), name="u8cp.off");
        l_sum = b.add(
            b.load(b.gep(l_cur, [f_k], name="u8cp.kp"), name="u8cp.k"),
            b.call(starts_fn, [l_s, l_at, l_n], name="u8cp.rest"),
            name="u8cp.sum"
        );
        b.store(l_sum, b.gep(l_cur, [f_total], name="u8cp.tset"));
        b.ret(l_sum);
    }
    self.utf8_cplen_fn = cplen_fn;

    off_fn = self._define_function(
        "__jac_utf8_cp_off", ir.FunctionType(i64, [i8p, i8p, i64, i64, i1])
    );
    off_fn.linkage = "private";
    (o_base, o_s, o_n, o_k, o_ascii) = (
        off_fn.args[0],
        off_fn.args[1],
        off_fn.args[2],
        off_fn.args[3],
        off_fn.args[4]
    );
    _o_entry = off_fn.append_basic_block("entry");
    _o_fast = off_fn.append_basic_block("ascii");
    _o_plain = off_fn.append_basic_block("plain");
    b = ir.IRBuilder(_o_entry);
    o_kp = b.select(
        b.icmp_signed("<", o_k, zero, name="u8of.kneg"), zero, o_k, name="u8of.kpos"
    );
    b = ir.IRBuilder(_o_fast);
    b.ret(
        b.select(
            b.icmp_signed("<", o_kp, o_n, name="u8of.klt"), o_kp, o_n, name="u8of.kmin"
        )
    );
    b = ir.IRBuilder(_o_plain);
    b.ret(b.call(seek_fn, [o_s, o_n, zero, zero, o_kp], name="u8of.scan"));
    b = ir.IRBuilder(_o_entry);
    if cur_fn is None {
        b.cbranch(o_ascii, _o_fast, _o_plain);
    } else {
        _o_look = off_fn.append_basic_block("look");
        _o_cached = off_fn.append_basic_block("cached");
        _o_end = off_fn.append_basic_block("end");
        _o_pick = off_fn.append_basic_block("pick");
        _o_back = off_fn.append_basic_block("back");
        _o_fwd = off_fn.append_basic_block("fwd");
        _o_join = off_fn.append_basic_block("join");
        _o_save = off_fn.append_basic_block("save");
        _o_out = off_fn.append_basic_block("out");
        b.cbranch(o_ascii, _o_fast, _o_look);
        b = ir.IRBuilder(_o_look);
        o_cur = b.call(cur_fn, [o_base, o_s, o_n], name="u8of.cur");
        b.cbranch(
            b.icmp_unsigned(
                "==", o_cur, ir.Constant(o_cur.type, None), name="u8of.nocur"
            ),
            _o_plain,
            _o_cached
        );
        b = ir.IRBuilder(_o_cached);
        o_total = b.load(b.gep(o_cur, [f_total], name="u8of.tp"), name="u8of.total");
        o_ck = b.load(b.gep(o_cur, [f_k], name="u8of.kp"), name="u8of.ck");
        o_co = b.load(b.gep(o_cur, [f_off], name="u8of.op"), name="u8of.co");
        o_known = b.icmp_signed(">=", o_total, zero, name="u8of.known");
        b.cbranch(
            b.and_(
                o_known,
                b.icmp_signed(">=", o_kp, o_total, name="u8of.past"),
                name="u8of.atend"
            ),
            _o_end,
            _o_pick
        );
        b = ir.IRBuilder(_o_end);
        b.ret(o_n);
        b = ir.IRBuilder(_o_pick);
        (o_ak, o_ao, o_backward) = self._utf8_pick_anchor(
            b, o_kp, (o_ck, o_total), (o_ck, o_co), (o_total, o_n), o_known, "u8of"
        );
        b.cbranch(o_backward, _o_back, _o_fwd);
        b = ir.IRBuilder(_o_back);
        o_rb = b.call(back_fn, [o_s, o_ak, o_ao, o_kp], name="u8of.rb");
        b.branch(_o_join);
        b = ir.IRBuilder(_o_fwd);
        o_rf = b.call(seek_fn, [o_s, o_n, o_ak, o_ao, o_kp], name="u8of.rf");
        b.branch(_o_join);
        b = ir.IRBuilder(_o_join);
        o_r = b.phi(i64, name="u8of.r");
        o_r.add_incoming(o_rb, _o_back);
        o_r.add_incoming(o_rf, _o_fwd);
        b.cbranch(
            b.and_(
                b.icmp_signed(">", o_r, zero, name="u8of.r.pos"),
                b.icmp_signed("<", o_r, o_n, name="u8of.r.in"),
                name="u8of.r.mid"
            ),
            _o_save,
            _o_out
        );
        b = ir.IRBuilder(_o_save);
        b.store(o_kp, b.gep(o_cur, [f_k], name="u8of.kset"));
        b.store(o_r, b.gep(o_cur, [f_off], name="u8of.oset"));
        b.branch(_o_out);
        b = ir.IRBuilder(_o_out);
        b.ret(o_r);
    }
    self.utf8_cp_off_fn = off_fn;

    cnt_fn = self._define_function(
        "__jac_utf8_cp_count", ir.FunctionType(i64, [i8p, i8p, i64, i64, i1])
    );
    cnt_fn.linkage = "private";
    (q_base, q_s, q_n, q_upto, q_ascii) = (
        cnt_fn.args[0],
        cnt_fn.args[1],
        cnt_fn.args[2],
        cnt_fn.args[3],
        cnt_fn.args[4]
    );
    _q_entry = cnt_fn.append_basic_block("entry");
    _q_fast = cnt_fn.append_basic_block("ascii");
    _q_plain = cnt_fn.append_basic_block("plain");
    b = ir.IRBuilder(_q_entry);
    q_lo = b.select(
        b.icmp_signed("<", q_upto, zero, name="u8cn.neg"), zero, q_upto, name="u8cn.lo"
    );
    q_u = b.select(
        b.icmp_signed(">", q_lo, q_n, name="u8cn.over"), q_n, q_lo, name="u8cn.u"
    );
    b = ir.IRBuilder(_q_fast);
    b.ret(q_u);
    b = ir.IRBuilder(_q_plain);
    b.ret(b.call(starts_fn, [q_s, zero, q_u], name="u8cn.scan"));
    b = ir.IRBuilder(_q_entry);
    if cur_fn is None {
        b.cbranch(q_ascii, _q_fast, _q_plain);
    } else {
        _q_look = cnt_fn.append_basic_block("look");
        _q_cached = cnt_fn.append_basic_block("cached");
        _q_end = cnt_fn.append_basic_block("end");
        _q_pick = cnt_fn.append_basic_block("pick");
        _q_back = cnt_fn.append_basic_block("back");
        _q_fwd = cnt_fn.append_basic_block("fwd");
        _q_join = cnt_fn.append_basic_block("join");
        _q_save = cnt_fn.append_basic_block("save");
        _q_out = cnt_fn.append_basic_block("out");
        b.cbranch(q_ascii, _q_fast, _q_look);
        b = ir.IRBuilder(_q_look);
        q_cur = b.call(cur_fn, [q_base, q_s, q_n], name="u8cn.cur");
        b.cbranch(
            b.icmp_unsigned(
                "==", q_cur, ir.Constant(q_cur.type, None), name="u8cn.nocur"
            ),
            _q_plain,
            _q_cached
        );
        b = ir.IRBuilder(_q_cached);
        q_total = b.load(b.gep(q_cur, [f_total], name="u8cn.tp"), name="u8cn.total");
        q_ck = b.load(b.gep(q_cur, [f_k], name="u8cn.kp"), name="u8cn.ck");
        q_co = b.load(b.gep(q_cur, [f_off], name="u8cn.op"), name="u8cn.co");
        q_known = b.icmp_signed(">=", q_total, zero, name="u8cn.known");
        b.cbranch(
            b.and_(
                q_known,
                b.icmp_signed("==", q_u, q_n, name="u8cn.whole"),
                name="u8cn.atend"
            ),
            _q_end,
            _q_pick
        );
        b = ir.IRBuilder(_q_end);
        b.ret(q_total);
        b = ir.IRBuilder(_q_pick);
        (q_ak, q_ao, q_backward) = self._utf8_pick_anchor(
            b, q_u, (q_co, q_n), (q_ck, q_co), (q_total, q_n), q_known, "u8cn"
        );
        b.cbranch(q_backward, _q_back, _q_fwd);
        b = ir.IRBuilder(_q_back);
        q_rb = b.sub(
            q_ak,
            b.call(starts_fn, [q_s, q_u, q_ao], name="u8cn.span.b"),
            name="u8cn.rb"
        );
        b.branch(_q_join);
        b = ir.IRBuilder(_q_fwd);
        q_rf = b.add(
            q_ak,
            b.call(starts_fn, [q_s, q_ao, q_u], name="u8cn.span.f"),
            name="u8cn.rf"
        );
        b.branch(_q_join);
        b = ir.IRBuilder(_q_join);
        q_r = b.phi(i64, name="u8cn.r");
        q_r.add_incoming(q_rb, _q_back);
        q_r.add_incoming(q_rf, _q_fwd);
        b.cbranch(
            b.and_(
                b.icmp_signed(">", q_u, zero, name="u8cn.u.pos"),
                b.icmp_signed("<", q_u, q_n, name="u8cn.u.in"),
                name="u8cn.u.mid"
            ),
            _q_save,
            _q_out
        );
        b = ir.IRBuilder(_q_save);
        b.store(q_r, b.gep(q_cur, [f_k], name="u8cn.kset"));
        b.store(q_u, b.gep(q_cur, [f_off], name="u8cn.oset"));
        b.branch(_q_out);
        b = ir.IRBuilder(_q_out);
        b.ret(q_r);
    }
    self.utf8_cp_count_fn = cnt_fn;

    adv_fn = self._define_function(
        "__jac_utf8_advance", ir.FunctionType(i64, [i8p, i64, i64, i64, i1])
    );
    adv_fn.linkage = "private";
    (v_s, v_n, v_off, v_delta, v_ascii) = (
        adv_fn.args[0],
        adv_fn.args[1],
        adv_fn.args[2],
        adv_fn.args[3],
        adv_fn.args[4]
    );
    _v_entry = adv_fn.append_basic_block("entry");
    _v_fast = adv_fn.append_basic_block("ascii");
    _v_loop = adv_fn.append_basic_block("loop");
    _v_fchk = adv_fn.append_basic_block("fwdchk");
    _v_fwd = adv_fn.append_basic_block("fwd");
    _v_bchk = adv_fn.append_basic_block("backchk");
    _v_bedge = adv_fn.append_basic_block("backedge");
    _v_back = adv_fn.append_basic_block("back");
    _v_out = adv_fn.append_basic_block("out");
    _v_before = adv_fn.append_basic_block("before");
    b = ir.IRBuilder(_v_entry);
    b.cbranch(v_ascii, _v_fast, _v_loop);
    b = ir.IRBuilder(_v_fast);
    v_sum = b.add(v_off, v_delta, name="u8adv.sum");
    v_fo = b.select(
        b.icmp_signed(
            ">=", v_delta, b.sub(v_n, v_off, name="u8adv.room"), name="u8adv.over"
        ),
        v_n,
        v_sum,
        name="u8adv.fwd"
    );
    v_bo = b.select(
        b.icmp_signed(
            "<=", v_delta, b.sub(neg_one, v_off, name="u8adv.lim"), name="u8adv.under"
        ),
        neg_one,
        v_sum,
        name="u8adv.bwd"
    );
    b.ret(
        b.select(
            b.icmp_signed(">", v_delta, zero, name="u8adv.dpos"),
            v_fo,
            v_bo,
            name="u8adv.res"
        )
    );
    b = ir.IRBuilder(_v_loop);
    v_o = b.phi(i64, name="u8adv.off");
    v_o.add_incoming(v_off, _v_entry);
    v_r = b.phi(i64, name="u8adv.rem");
    v_r.add_incoming(v_delta, _v_entry);
    b.cbranch(b.icmp_signed(">", v_r, zero, name="u8adv.pos"), _v_fchk, _v_bchk);
    b = ir.IRBuilder(_v_fchk);
    b.cbranch(b.icmp_signed("<", v_o, v_n, name="u8adv.inb"), _v_fwd, _v_out);
    b = ir.IRBuilder(_v_fwd);
    v_w = b.call(lat_fn, [v_s, v_n, v_o], name="u8adv.w");
    v_o.add_incoming(b.add(v_o, v_w, name="u8adv.off.f"), _v_fwd);
    v_r.add_incoming(b.sub(v_r, one, name="u8adv.rem.f"), _v_fwd);
    b.branch(_v_loop);
    b = ir.IRBuilder(_v_bchk);
    b.cbranch(b.icmp_signed("<", v_r, zero, name="u8adv.neg"), _v_bedge, _v_out);
    b = ir.IRBuilder(_v_bedge);
    b.cbranch(b.icmp_signed("<=", v_o, zero, name="u8adv.atz"), _v_before, _v_back);
    b = ir.IRBuilder(_v_back);
    v_o.add_incoming(b.call(prev_fn, [v_s, v_o], name="u8adv.off.b"), _v_back);
    v_r.add_incoming(b.add(v_r, one, name="u8adv.rem.b"), _v_back);
    b.branch(_v_loop);
    b = ir.IRBuilder(_v_out);
    b.ret(v_o);
    b = ir.IRBuilder(_v_before);
    b.ret(neg_one);
    self.utf8_advance_fn = adv_fn;

    gat_fn = self._define_function(
        "__jac_utf8_gather",
        ir.FunctionType(i64, [i8p, i64, i64, i64, i64, i1, i8p, i64])
    );
    gat_fn.linkage = "private";
    (g_s, g_n, g_start, g_stop, g_step, g_ascii, g_out, g_cap) = (
        gat_fn.args[0],
        gat_fn.args[1],
        gat_fn.args[2],
        gat_fn.args[3],
        gat_fn.args[4],
        gat_fn.args[5],
        gat_fn.args[6],
        gat_fn.args[7]
    );
    g_memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    _g_entry = gat_fn.append_basic_block("entry");
    _g_chk = gat_fn.append_basic_block("chk");
    _g_body = gat_fn.append_basic_block("body");
    _g_copy = gat_fn.append_basic_block("copy");
    _g_step = gat_fn.append_basic_block("step");
    _g_done = gat_fn.append_basic_block("done");
    b = ir.IRBuilder(_g_entry);
    g_fwd = b.icmp_signed(">", g_step, zero, name="u8g.fwd");
    g_has_out = b.icmp_unsigned("!=", g_out, ir.Constant(i8p, None), name="u8g.out");
    b.branch(_g_chk);
    b = ir.IRBuilder(_g_chk);
    g_i = b.phi(i64, name="u8g.i");
    g_i.add_incoming(g_start, _g_entry);
    g_k = b.phi(i64, name="u8g.k");
    g_k.add_incoming(zero, _g_entry);
    g_go = b.and_(
        b.select(
            g_fwd,
            b.icmp_signed("<", g_i, g_stop, name="u8g.lt"),
            b.icmp_signed(">", g_i, g_stop, name="u8g.gt"),
            name="u8g.inrange"
        ),
        b.and_(
            b.icmp_signed(">=", g_i, zero, name="u8g.ge0"),
            b.icmp_signed("<", g_i, g_n, name="u8g.ltn"),
            name="u8g.inb"
        ),
        name="u8g.go"
    );
    b.cbranch(g_go, _g_body, _g_done);
    b = ir.IRBuilder(_g_body);
    g_w = b.call(lat_fn, [g_s, g_n, g_i], name="u8g.w");
    g_k1 = b.add(g_k, g_w, name="u8g.k1");
    b.cbranch(b.icmp_signed(">", g_k1, g_cap, name="u8g.full"), _g_done, _g_copy);
    b = ir.IRBuilder(_g_copy);
    _g_write = gat_fn.append_basic_block("write");
    b.cbranch(g_has_out, _g_write, _g_step);
    b = ir.IRBuilder(_g_write);
    b.call(
        g_memcpy,
        [b.gep(g_out, [g_k], name="u8g.dst"), b.gep(g_s, [g_i], name="u8g.src"), g_w]
    );
    b.branch(_g_step);
    b = ir.IRBuilder(_g_step);
    g_k.add_incoming(g_k1, _g_step);
    g_i.add_incoming(
        b.call(adv_fn, [g_s, g_n, g_i, g_step, g_ascii], name="u8g.next"), _g_step
    );
    b.branch(_g_chk);
    b = ir.IRBuilder(_g_done);
    b.ret(g_k);
    self.utf8_gather_fn = gat_fn;

    dec_fn = self._define_function(
        "__jac_utf8_decode", ir.FunctionType(i64, [i8p, i64])
    );
    dec_fn.linkage = "private";
    (d_s, d_n) = (dec_fn.args[0], dec_fn.args[1]);
    _d_entry = dec_fn.append_basic_block("entry");
    _d_bad = dec_fn.append_basic_block("bad");
    _d_lead = dec_fn.append_basic_block("lead");
    _d_ascii = dec_fn.append_basic_block("ascii");
    _d_wide = dec_fn.append_basic_block("wide");
    b = ir.IRBuilder(_d_entry);
    b.cbranch(b.icmp_signed("<=", d_n, zero, name="u8d.empty"), _d_bad, _d_lead);
    b = ir.IRBuilder(_d_bad);
    b.ret(neg_one);
    b = ir.IRBuilder(_d_lead);
    d_lb = b.zext(b.load(d_s, name="u8d.b0"), i64, name="u8d.lead");
    b.cbranch(
        self._emit_u8_lone_ascii(b, d_s, d_n, zero, d_lb, name="u8d.isasc"),
        _d_ascii,
        _d_wide
    );
    b = ir.IRBuilder(_d_ascii);
    b.ret(d_lb);
    b = ir.IRBuilder(_d_wide);
    d_w = b.call(lat_fn, [d_s, d_n, zero], name="u8d.w");
    d_exp: ir.Value = ir.Constant(i64, 0);
    d_mask: ir.Value = ir.Constant(i64, 0);
    d_min: ir.Value = ir.Constant(i64, 0);
    for (lim, width, mask, least) in [
        (0xF5, 4, 0x07, 0x10000),
        (0xF0, 3, 0x0F, 0x800),
        (0xE0, 2, 0x1F, 0x80),
        (0xC2, 0, 0, 0)
    ] {
        d_lt = b.icmp_unsigned("<", d_lb, ir.Constant(i64, lim), name=f"u8d.lt{lim}");
        d_exp = b.select(d_lt, ir.Constant(i64, width), d_exp, name=f"u8d.exp{lim}");
        d_mask = b.select(d_lt, ir.Constant(i64, mask), d_mask, name=f"u8d.mask{lim}");
        d_min = b.select(d_lt, ir.Constant(i64, least), d_min, name=f"u8d.min{lim}");
    }
    d_cp = b.and_(d_lb, d_mask, name="u8d.cp0");
    for k in range(1, 4) {
        d_has = b.icmp_signed("<", ir.Constant(i64, k), d_w, name=f"u8d.has{k}");
        d_at = b.select(d_has, ir.Constant(i64, k), zero, name=f"u8d.at{k}");
        d_byte = b.zext(
            b.load(b.gep(d_s, [d_at], name=f"u8d.p{k}"), name=f"u8d.b{k}"),
            i64,
            name=f"u8d.v{k}"
        );
        d_cp = b.select(
            d_has,
            b.or_(
                b.shl(d_cp, ir.Constant(i64, 6), name=f"u8d.sh{k}"),
                b.and_(d_byte, ir.Constant(i64, 0x3F), name=f"u8d.lo{k}"),
                name=f"u8d.or{k}"
            ),
            d_cp,
            name=f"u8d.cp{k}"
        );
    }
    d_bad = b.or_(
        b.or_(
            b.icmp_signed("!=", d_w, d_exp, name="u8d.shape"),
            b.icmp_signed("<", d_cp, d_min, name="u8d.overlong"),
            name="u8d.bad1"
        ),
        b.icmp_signed(">", d_cp, ir.Constant(i64, 0x10FFFF), name="u8d.big"),
        name="u8d.bad"
    );
    b.ret(b.select(d_bad, neg_one, d_cp, name="u8d.res"));
    self.utf8_decode_fn = dec_fn;

    malloc_fn = self._get_or_declare_extern("malloc", i8p, [i64]);
    memset_fn = self._get_or_declare_extern("memset", i8p, [i8p, i32, i64]);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    pages_ty = ir.ArrayType(i64, 4352);
    pages_gv = ir.GlobalVariable(self.llvm_module, pages_ty, name="__jac_cp_pages");
    pages_gv.linkage = "private";
    pages_gv.initializer = ir.Constant(pages_ty, None);
    pages_gv.align = 8;
    lock_gv = ir.GlobalVariable(self.llvm_module, i64, name="__jac_cp_pages_lock");
    lock_gv.linkage = "private";
    lock_gv.initializer = zero;
    lock_gv.align = 8;
    int_fn = self._define_function(
        "__jac_utf8_intern", ir.FunctionType(i8p, [i64, i8p, i64])
    );
    int_fn.linkage = "private";
    (t_cp, t_src, t_w) = (int_fn.args[0], int_fn.args[1], int_fn.args[2]);
    _t_entry = int_fn.append_basic_block("entry");
    _t_look = int_fn.append_basic_block("look");
    _t_hit = int_fn.append_basic_block("hit");
    _t_lock = int_fn.append_basic_block("lock");
    _t_held = int_fn.append_basic_block("held");
    _t_mkpage = int_fn.append_basic_block("page.new");
    _t_page = int_fn.append_basic_block("page");
    _t_mk = int_fn.append_basic_block("char.new");
    _t_done = int_fn.append_basic_block("done");
    b = ir.IRBuilder(_t_entry);
    t_slot = b.gep(
        pages_gv,
        [ir.Constant(i32, 0), b.lshr(t_cp, ir.Constant(i64, 8), name="u8i.hi")],
        name="u8i.pslot"
    );
    t_lo = b.and_(t_cp, ir.Constant(i64, 255), name="u8i.lo");
    t_pg = b.load_atomic(t_slot, "acquire", 8, name="u8i.pg");
    b.cbranch(b.icmp_unsigned("==", t_pg, zero, name="u8i.nopage"), _t_lock, _t_look);
    b = ir.IRBuilder(_t_look);
    t_ent = b.load_atomic(
        b.gep(
            b.inttoptr(t_pg, i64.as_pointer(), name="u8i.pp0"), [t_lo], name="u8i.es0"
        ),
        "acquire",
        8,
        name="u8i.ent0"
    );
    b.cbranch(b.icmp_unsigned("==", t_ent, zero, name="u8i.miss0"), _t_lock, _t_hit);
    b = ir.IRBuilder(_t_hit);
    b.ret(b.inttoptr(t_ent, i8p, name="u8i.char0"));
    b = ir.IRBuilder(_t_lock);
    t_busy = b.atomic_rmw("xchg", lock_gv, one, ordering="acquire", name="u8i.lock");
    b.cbranch(b.icmp_unsigned("!=", t_busy, zero, name="u8i.busy"), _t_lock, _t_held);
    b = ir.IRBuilder(_t_held);
    t_pg1 = b.load_atomic(t_slot, "acquire", 8, name="u8i.pg1");
    b.cbranch(
        b.icmp_unsigned("==", t_pg1, zero, name="u8i.nopage1"), _t_mkpage, _t_page
    );
    b = ir.IRBuilder(_t_mkpage);
    t_np = b.call(malloc_fn, [ir.Constant(i64, 2048)], name="u8i.np");
    b.call(memset_fn, [t_np, ir.Constant(i32, 0), ir.Constant(i64, 2048)]);
    t_npi = b.ptrtoint(t_np, i64, name="u8i.npi");
    b.store_atomic(t_npi, t_slot, "release", 8);
    b.branch(_t_page);
    b = ir.IRBuilder(_t_page);
    t_pgv = b.phi(i64, name="u8i.page");
    t_pgv.add_incoming(t_pg1, _t_held);
    t_pgv.add_incoming(t_npi, _t_mkpage);
    t_eslot = b.gep(
        b.inttoptr(t_pgv, i64.as_pointer(), name="u8i.pp"), [t_lo], name="u8i.eslot"
    );
    t_ent1 = b.load_atomic(t_eslot, "acquire", 8, name="u8i.ent");
    b.cbranch(b.icmp_unsigned("==", t_ent1, zero, name="u8i.miss"), _t_mk, _t_done);
    b = ir.IRBuilder(_t_mk);
    t_buf = b.call(
        malloc_fn,
        [b.add(t_w, ir.Constant(i64, HDR_TOTAL + 1), name="u8i.size")],
        name="u8i.buf"
    );
    t_words = b.bitcast(t_buf, i64.as_pointer(), name="u8i.words");
    for (idx, word) in enumerate(
        [
            ir.Constant(i64, 0),
            ir.Constant(i64, 0),
            ir.Constant(i64, RC_SENTINEL),
            b.or_(
                b.shl(t_w, ir.Constant(i64, STR_LEN_TAG_SHIFT), name="u8i.lshl"),
                ir.Constant(i64, STR_LEN_TAG_BIT),
                name="u8i.tag"
            )
        ]
    ) {
        b.store(word, b.gep(t_words, [ir.Constant(i64, idx)], name=f"u8i.w{idx}"));
    }
    t_data = b.gep(t_buf, [ir.Constant(i64, HDR_TOTAL)], name="u8i.data");
    b.call(memcpy_fn, [t_data, t_src, t_w]);
    b.store(ir.Constant(i8, 0), b.gep(t_data, [t_w], name="u8i.nul"));
    t_di = b.ptrtoint(t_data, i64, name="u8i.di");
    b.store_atomic(t_di, t_eslot, "release", 8);
    b.branch(_t_done);
    b = ir.IRBuilder(_t_done);
    t_res = b.phi(i64, name="u8i.res");
    t_res.add_incoming(t_ent1, _t_page);
    t_res.add_incoming(t_di, _t_mk);
    b.store_atomic(zero, lock_gv, "release", 8);
    b.ret(b.inttoptr(t_res, i8p, name="u8i.char"));

    fffd_ty = ir.ArrayType(i8, 4);
    fffd_gv = ir.GlobalVariable(self.llvm_module, fffd_ty, name="__jac_utf8_fffd");
    fffd_gv.linkage = "private";
    fffd_gv.global_constant = True;
    fffd_gv.initializer = ir.Constant(fffd_ty, bytearray(b"\xef\xbf\xbd\x00"));
    at_fn = self._define_function(
        "__jac_utf8_char_at", ir.FunctionType(i8p, [i8p, i64, i64])
    );
    at_fn.linkage = "private";
    (a_s, a_n, a_off) = (at_fn.args[0], at_fn.args[1], at_fn.args[2]);
    _a_entry = at_fn.append_basic_block("entry");
    _a_ascii = at_fn.append_basic_block("ascii");
    _a_wide = at_fn.append_basic_block("wide");
    b = ir.IRBuilder(_a_entry);
    a_p = b.gep(a_s, [a_off], name="u8at.p");
    a_bv = b.zext(b.load(a_p, name="u8at.b"), i64, name="u8at.bv");
    b.cbranch(
        self._emit_u8_lone_ascii(b, a_s, a_n, a_off, a_bv, name="u8at.isasc"),
        _a_ascii,
        _a_wide
    );
    b = ir.IRBuilder(_a_ascii);
    b.ret(
        b.gep(
            self._get_char_cache_gv(),
            [ir.Constant(i32, 0), a_bv, ir.Constant(i32, 2), ir.Constant(i32, 0)],
            name="u8at.cached"
        )
    );
    b = ir.IRBuilder(_a_wide);
    a_rest = b.sub(a_n, a_off, name="u8at.rest");
    a_w = b.call(lat_fn, [a_s, a_n, a_off], name="u8at.w");
    a_cp = b.call(dec_fn, [a_p, a_rest], name="u8at.cp");
    a_bad = b.icmp_signed("<", a_cp, zero, name="u8at.bad");
    b.ret(
        b.call(
            int_fn,
            [
                b.select(a_bad, ir.Constant(i64, 0xFFFD), a_cp, name="u8at.key"),
                b.select(
                    a_bad,
                    b.gep(
                        fffd_gv,
                        [ir.Constant(i32, 0), ir.Constant(i32, 0)],
                        name="u8at.fffd"
                    ),
                    a_p,
                    name="u8at.src"
                ),
                b.select(a_bad, ir.Constant(i64, 3), a_w, name="u8at.width")
            ],
            name="u8at.char"
        )
    );
    self.utf8_char_at_fn = at_fn;

    memcmp_fn = self._get_or_declare_extern("memcmp", i32, [i8p, i8p, i64]);
    in_fn = self._define_function(
        "__jac_utf8_unit_in", ir.FunctionType(i1, [i8p, i64, i8p, i64])
    );
    in_fn.linkage = "private";
    (u_set, u_setn, u_unit, u_w) = (
        in_fn.args[0],
        in_fn.args[1],
        in_fn.args[2],
        in_fn.args[3]
    );
    _u_entry = in_fn.append_basic_block("entry");
    _u_chk = in_fn.append_basic_block("chk");
    _u_body = in_fn.append_basic_block("body");
    _u_cmp = in_fn.append_basic_block("cmp");
    _u_next = in_fn.append_basic_block("next");
    _u_yes = in_fn.append_basic_block("yes");
    _u_no = in_fn.append_basic_block("no");
    b = ir.IRBuilder(_u_entry);
    b.branch(_u_chk);
    b = ir.IRBuilder(_u_chk);
    u_j = b.phi(i64, name="u8in.j");
    u_j.add_incoming(zero, _u_entry);
    b.cbranch(b.icmp_signed("<", u_j, u_setn, name="u8in.more"), _u_body, _u_no);
    b = ir.IRBuilder(_u_body);
    u_cw = b.call(lat_fn, [u_set, u_setn, u_j], name="u8in.cw");
    b.cbranch(b.icmp_signed("==", u_cw, u_w, name="u8in.same"), _u_cmp, _u_next);
    b = ir.IRBuilder(_u_cmp);
    u_eq = b.icmp_signed(
        "==",
        b.call(
            memcmp_fn,
            [b.gep(u_set, [u_j], name="u8in.at"), u_unit, u_w],
            name="u8in.cmp"
        ),
        ir.Constant(i32, 0),
        name="u8in.eq"
    );
    b.cbranch(u_eq, _u_yes, _u_next);
    b = ir.IRBuilder(_u_next);
    u_j.add_incoming(b.add(u_j, u_cw, name="u8in.j1"), _u_next);
    b.branch(_u_chk);
    b = ir.IRBuilder(_u_yes);
    b.ret(ir.Constant(i1, 1));
    b = ir.IRBuilder(_u_no);
    b.ret(ir.Constant(i1, 0));
    self.utf8_unit_in_fn = in_fn;
}

impl NaIRGenPass._call_utf8_cplen(
    b: ir.IRBuilder,
    ptr: ir.Value,
    nbytes: ir.Value,
    ascii: ir.Value,
    name: str = "u8.cplen",
    base: (ir.Value | None) = None
) -> ir.Value {
    self._emit_utf8_helpers();
    nbytes = self._coerce_type(nbytes, ir.IntType(64));
    return b.call(
        self.utf8_cplen_fn,
        [self._utf8_base_arg(b, base), ptr, nbytes, ascii],
        name=name
    );
}

impl NaIRGenPass._call_utf8_cp_off(
    b: ir.IRBuilder,
    ptr: ir.Value,
    nbytes: ir.Value,
    cp_index: ir.Value,
    ascii: ir.Value,
    name: str = "u8.cpoff",
    base: (ir.Value | None) = None
) -> ir.Value {
    self._emit_utf8_helpers();
    nbytes = self._coerce_type(nbytes, ir.IntType(64));
    cp_index = self._coerce_type(cp_index, ir.IntType(64));
    return b.call(
        self.utf8_cp_off_fn,
        [self._utf8_base_arg(b, base), ptr, nbytes, cp_index, ascii],
        name=name
    );
}

impl NaIRGenPass._call_utf8_cp_count(
    b: ir.IRBuilder,
    ptr: ir.Value,
    nbytes: ir.Value,
    upto: ir.Value,
    ascii: ir.Value,
    name: str = "u8.cpcount",
    base: (ir.Value | None) = None
) -> ir.Value {
    self._emit_utf8_helpers();
    i64 = ir.IntType(64);
    return b.call(
        self.utf8_cp_count_fn,
        [
            self._utf8_base_arg(b, base),
            ptr,
            self._coerce_type(nbytes, i64),
            self._coerce_type(upto, i64),
            ascii
        ],
        name=name
    );
}

impl NaIRGenPass._utf8_base_arg(b: ir.IRBuilder, base: (ir.Value | None)) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    if base is None or self._nogc_headerless() {
        return ir.Constant(i8p, None);
    }
    return base if base.type == i8p else b.bitcast(base, i8p, name="u8.base");
}

impl NaIRGenPass._call_utf8_cp_len_at(
    b: ir.IRBuilder,
    ptr: ir.Value,
    nbytes: ir.Value,
    off: ir.Value,
    name: str = "u8.cplenat"
) -> ir.Value {
    self._emit_utf8_helpers();
    nbytes = self._coerce_type(nbytes, ir.IntType(64));
    off = self._coerce_type(off, ir.IntType(64));
    return b.call(self.utf8_cp_len_at_fn, [ptr, nbytes, off], name=name);
}

impl NaIRGenPass._call_utf8_char_at(
    b: ir.IRBuilder,
    ptr: ir.Value,
    nbytes: ir.Value,
    off: ir.Value,
    name: str = "u8.char"
) -> ir.Value {
    self._emit_utf8_helpers();
    nbytes = self._coerce_type(nbytes, ir.IntType(64));
    off = self._coerce_type(off, ir.IntType(64));
    return b.call(self.utf8_char_at_fn, [ptr, nbytes, off], name=name);
}

impl NaIRGenPass._call_utf8_prev(
    b: ir.IRBuilder, ptr: ir.Value, off: ir.Value, name: str = "u8.prev"
) -> ir.Value {
    self._emit_utf8_helpers();
    off = self._coerce_type(off, ir.IntType(64));
    return b.call(self.utf8_prev_fn, [ptr, off], name=name);
}

impl NaIRGenPass._call_utf8_advance(
    b: ir.IRBuilder,
    ptr: ir.Value,
    nbytes: ir.Value,
    off: ir.Value,
    delta: ir.Value,
    ascii: ir.Value,
    name: str = "u8.adv"
) -> ir.Value {
    self._emit_utf8_helpers();
    nbytes = self._coerce_type(nbytes, ir.IntType(64));
    off = self._coerce_type(off, ir.IntType(64));
    delta = self._coerce_type(delta, ir.IntType(64));
    return b.call(self.utf8_advance_fn, [ptr, nbytes, off, delta, ascii], name=name);
}

impl NaIRGenPass._call_utf8_gather(
    b: ir.IRBuilder,
    ptr: ir.Value,
    nbytes: ir.Value,
    start: ir.Value,
    stop: ir.Value,
    step: ir.Value,
    ascii: ir.Value,
    out: ir.Value,
    cap: ir.Value,
    name: str = "u8.gather"
) -> ir.Value {
    self._emit_utf8_helpers();
    i64 = ir.IntType(64);
    return b.call(
        self.utf8_gather_fn,
        [
            ptr,
            self._coerce_type(nbytes, i64),
            self._coerce_type(start, i64),
            self._coerce_type(stop, i64),
            self._coerce_type(step, i64),
            ascii,
            out,
            self._coerce_type(cap, i64)
        ],
        name=name
    );
}

impl NaIRGenPass._call_utf8_decode(
    b: ir.IRBuilder, ptr: ir.Value, nbytes: ir.Value, name: str = "u8.decode"
) -> ir.Value {
    self._emit_utf8_helpers();
    nbytes = self._coerce_type(nbytes, ir.IntType(64));
    return b.call(self.utf8_decode_fn, [ptr, nbytes], name=name);
}

impl NaIRGenPass._call_utf8_unit_in(
    b: ir.IRBuilder,
    charset: ir.Value,
    charset_len: ir.Value,
    unit: ir.Value,
    width: ir.Value,
    name: str = "u8.unitin"
) -> ir.Value {
    self._emit_utf8_helpers();
    charset_len = self._coerce_type(charset_len, ir.IntType(64));
    width = self._coerce_type(width, ir.IntType(64));
    return b.call(self.utf8_unit_in_fn, [charset, charset_len, unit, width], name=name);
}

impl NaIRGenPass._emit_wrap_clamp(
    b: ir.IRBuilder,
    value: ir.Value,
    length: ir.Value,
    lo: ir.Value,
    hi: ir.Value,
    name: str = "wc"
) -> ir.Value {
    i64 = ir.IntType(64);
    value = self._coerce_type(value, i64);
    value = b.select(
        b.icmp_signed("<", value, ir.Constant(i64, 0), name=f"{name}.neg"),
        b.add(value, length, name=f"{name}.wrap"),
        value,
        name=f"{name}.w"
    );
    value = b.select(
        b.icmp_signed("<", value, lo, name=f"{name}.lo"), lo, value, name=f"{name}.cl"
    );
    return b.select(
        b.icmp_signed(">", value, hi, name=f"{name}.hi"), hi, value, name=f"{name}.ch"
    );
}

impl _u8_is_cont(b: ir.IRBuilder, byte: ir.Value, name: str) -> ir.Value {
    i64 = ir.IntType(64);
    return b.icmp_unsigned(
        "==",
        b.and_(
            b.zext(byte, i64, name=f"{name}.z"),
            ir.Constant(i64, 0xC0),
            name=f"{name}.m"
        ),
        ir.Constant(i64, 0x80),
        name=name
    );
}

impl _u8_is_start(b: ir.IRBuilder, s: ir.Value, i: ir.Value, name: str) -> ir.Value {
    i64 = ir.IntType(64);
    byte = b.load(b.gep(s, [i], name=f"{name}.p"), name=f"{name}.b");
    return b.or_(
        b.icmp_unsigned("==", i, ir.Constant(i64, 0), name=f"{name}.first"),
        b.not_(_u8_is_cont(b, byte, f"{name}.cont"), name=f"{name}.lead"),
        name=name
    );
}

impl NaIRGenPass._emit_u8_lone_ascii(
    b: ir.IRBuilder,
    s: ir.Value,
    n: ir.Value,
    off: ir.Value,
    byte: ir.Value,
    name: str = "u8.lone"
) -> ir.Value {
    i64 = ir.IntType(64);
    n = self._coerce_type(n, i64);
    off = self._coerce_type(off, i64);
    nxt = b.add(off, ir.Constant(i64, 1), name=f"{name}.nxt");
    inside = b.icmp_signed("<", nxt, n, name=f"{name}.has");
    follow = b.load(
        b.gep(s, [b.select(inside, nxt, off, name=f"{name}.at")], name=f"{name}.p"),
        name=f"{name}.b"
    );
    return b.and_(
        b.icmp_unsigned("<", byte, ir.Constant(i64, 0x80), name=f"{name}.low"),
        b.not_(
            b.and_(inside, _u8_is_cont(b, follow, f"{name}.cont"), name=f"{name}.tail"),
            name=f"{name}.alone"
        ),
        name=name
    );
}

impl NaIRGenPass._utf8_cursor_state -> tuple[
    ir.Function,
    ir.Function,
    ir.GlobalVariable
] {
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    if "__jac_utf8_tls_get" not in self.extern_funcs {
        drop_fn = ir.Function(
            self.llvm_module,
            ir.FunctionType(ir.VoidType(), [i8p]),
            name="__jac_utf8_tls_free"
        );
        drop_fn.linkage = "linkonce_odr";
        db = ir.IRBuilder(drop_fn.append_basic_block("entry"));
        db.call(
            self._get_or_declare_extern("free", ir.VoidType(), [i8p]), [drop_fn.args[0]]
        );
        db.ret_void();
        self._emit_tls_slot(
            "__jac_utf8_tls", "__jac_utf8_tls_get", "__jac_utf8_tls_set", drop_fn
        );
    }
    existing = self.llvm_module.globals.get("__jac_utf8_epoch");
    if isinstance(existing, ir.GlobalVariable) {
        epoch = existing;
    } else {
        epoch = ir.GlobalVariable(self.llvm_module, i64, name="__jac_utf8_epoch");
        epoch.linkage = "weak";
        epoch.initializer = ir.Constant(i64, 0);
        epoch.align = 8;
    }
    return (
        self.extern_funcs["__jac_utf8_tls_get"],
        self.extern_funcs["__jac_utf8_tls_set"],
        epoch
    );
}

impl NaIRGenPass._utf8_cursor_keyed(b: ir.IRBuilder, base: ir.Value) -> ir.Value {
    i64 = ir.IntType(64);
    i64p = i64.as_pointer();
    fn = b.function;
    heap_bb = fn.append_basic_block("u8k.heap");
    tag_bb = fn.append_basic_block("u8k.tag");
    done_bb = fn.append_basic_block("u8k.done");
    start_bb = b.block;
    rc = b.load(
        b.bitcast(
            b.gep(base, [ir.Constant(i64, HDR_RC_OFF)], name="u8k.rc.slot"),
            i64p,
            name="u8k.rc.p"
        ),
        name="u8k.rc"
    );
    b.cbranch(
        b.icmp_unsigned("==", rc, ir.Constant(i64, RC_SENTINEL), name="u8k.static"),
        done_bb,
        heap_bb
    );
    b.position_at_end(heap_bb);
    b.cbranch(self._emit_magic_check(b, base, name_prefix="u8k.mc"), tag_bb, done_bb);
    b.position_at_end(tag_bb);
    keyed = self._utf8_cursor_tag_keyed(
        b,
        b.load(
            b.bitcast(
                b.gep(base, [ir.Constant(i64, HDR_DTOR_OFF)], name="u8k.dt.slot"),
                i64p,
                name="u8k.dt.p"
            ),
            name="u8k.dv"
        ),
        "u8k"
    );
    b.branch(done_bb);
    b.position_at_end(done_bb);
    res = b.phi(ir.IntType(1), name="u8k.ok");
    res.add_incoming(ir.Constant(ir.IntType(1), 0), start_bb);
    res.add_incoming(ir.Constant(ir.IntType(1), 0), heap_bb);
    res.add_incoming(keyed, tag_bb);
    return res;
}

impl NaIRGenPass._utf8_cursor_tag_keyed(
    b: ir.IRBuilder, tag: ir.Value, name: str
) -> ir.Value {
    i64 = ir.IntType(64);
    return b.and_(
        b.icmp_unsigned(
            "==",
            b.and_(
                tag,
                ir.Constant(i64, STR_LEN_TAG_BIT | STR_ASCII_TAG_BIT),
                name=f"{name}.bits"
            ),
            ir.Constant(i64, STR_LEN_TAG_BIT),
            name=f"{name}.wide"
        ),
        b.icmp_unsigned(
            ">=",
            b.lshr(
                b.and_(tag, ir.Constant(i64, STR_LEN_PAYLOAD_MASK), name=f"{name}.pay"),
                ir.Constant(i64, STR_LEN_TAG_SHIFT),
                name=f"{name}.len"
            ),
            ir.Constant(i64, UTF8_CURSOR_MIN_BYTES),
            name=f"{name}.long"
        ),
        name=f"{name}.keyed"
    );
}

impl NaIRGenPass._utf8_cursor_fn -> ir.Function {
    if "__jac_utf8_cursor" in self.extern_funcs {
        return self.extern_funcs["__jac_utf8_cursor"];
    }
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i64p = i64.as_pointer();
    zero = ir.Constant(i64, 0);
    (get_fn, set_fn, epoch) = self._utf8_cursor_state();
    malloc_fn = self._get_or_declare_extern("malloc", i8p, [i64]);
    memset_fn = self._get_or_declare_extern("memset", i8p, [i8p, i32, i64]);
    block_bytes = ir.Constant(i64, 8 * (1 + UTF8_CURSOR_WAYS * UTF8_CURSOR_WORDS));
    fn = self._define_function(
        "__jac_utf8_cursor", ir.FunctionType(i64p, [i8p, i8p, i64])
    );
    fn.linkage = "private";
    self.extern_funcs["__jac_utf8_cursor"] = fn;
    (base, s, n) = (fn.args[0], fn.args[1], fn.args[2]);
    b = ir.IRBuilder(fn.append_basic_block("entry"));
    none_bb = fn.append_basic_block("none");
    probe_bb = fn.append_basic_block("probe");
    tls_bb = fn.append_basic_block("tls");
    make_bb = fn.append_basic_block("make");
    init_bb = fn.append_basic_block("init");
    have_bb = fn.append_basic_block("have");
    b.cbranch(
        b.or_(
            b.icmp_unsigned("==", base, ir.Constant(i8p, None), name="u8c.null"),
            b.icmp_signed(
                "<", n, ir.Constant(i64, UTF8_CURSOR_MIN_BYTES), name="u8c.short"
            ),
            name="u8c.skip"
        ),
        none_bb,
        probe_bb
    );
    b.position_at_end(none_bb);
    b.ret(ir.Constant(i64p, None));
    b.position_at_end(probe_bb);
    b.cbranch(self._utf8_cursor_keyed(b, base), tls_bb, none_bb);
    b.position_at_end(tls_bb);
    held = b.call(get_fn, [], name="u8c.held");
    b.cbranch(b.icmp_unsigned("==", held, zero, name="u8c.fresh"), make_bb, have_bb);
    b.position_at_end(make_bb);
    made = b.call(malloc_fn, [block_bytes], name="u8c.made");
    b.cbranch(
        b.icmp_unsigned("==", made, ir.Constant(i8p, None), name="u8c.oom"),
        none_bb,
        init_bb
    );
    b.position_at_end(init_bb);
    b.call(memset_fn, [made, ir.Constant(i32, 0), block_bytes]);
    made_i = b.ptrtoint(made, i64, name="u8c.made.i");
    b.call(set_fn, [made_i]);
    b.branch(have_bb);
    b.position_at_end(have_bb);
    blk_i = b.phi(i64, name="u8c.blk.i");
    blk_i.add_incoming(held, tls_bb);
    blk_i.add_incoming(made_i, init_bb);
    blk = b.inttoptr(blk_i, i64p, name="u8c.blk");
    now = b.load_atomic(epoch, "acquire", 8, name="u8c.epoch");
    tick = b.add(b.load(blk, name="u8c.clock"), ir.Constant(i64, 1), name="u8c.tick");
    b.store(tick, blk);
    base_i = b.ptrtoint(base, i64, name="u8c.base.i");
    s_i = b.ptrtoint(s, i64, name="u8c.s.i");
    fresh = [base_i, s_i, n, now, ir.Constant(i64, -1), zero, zero, tick];
    used_at = ir.Constant(i64, UTF8_CURSOR_USED);
    oldest_way: ir.Value = zero;
    oldest_use: ir.Value = zero;
    for way in range(UTF8_CURSOR_WAYS) {
        slot = b.gep(
            blk, [ir.Constant(i64, 1 + way * UTF8_CURSOR_WORDS)], name=f"u8c.e{way}"
        );
        held_key = [
            b.load(
                b.gep(slot, [ir.Constant(i64, idx)], name=f"u8c.e{way}.p{idx}"),
                name=f"u8c.e{way}.f{idx}"
            ) for idx in [UTF8_CURSOR_BASE, UTF8_CURSOR_DATA, UTF8_CURSOR_LEN]
        ];
        same = b.and_(
            b.and_(
                b.icmp_unsigned("==", held_key[0], base_i, name=f"u8c.e{way}.sb"),
                b.icmp_unsigned("==", held_key[1], s_i, name=f"u8c.e{way}.sd"),
                name=f"u8c.e{way}.bd"
            ),
            b.icmp_signed("==", held_key[2], n, name=f"u8c.e{way}.sn"),
            name=f"u8c.e{way}.same"
        );
        used = b.load(
            b.gep(slot, [used_at], name=f"u8c.e{way}.up"), name=f"u8c.e{way}.u"
        );
        if way == 0 {
            oldest_use = used;
        } else {
            older = b.icmp_unsigned("<", used, oldest_use, name=f"u8c.e{way}.older");
            oldest_way = b.select(
                older, ir.Constant(i64, way), oldest_way, name=f"u8c.e{way}.lru"
            );
            oldest_use = b.select(older, used, oldest_use, name=f"u8c.e{way}.lru.u");
        }
        hit_bb = fn.append_basic_block(f"hit{way}");
        stale_bb = fn.append_basic_block(f"stale{way}");
        live_bb = fn.append_basic_block(f"live{way}");
        next_bb = fn.append_basic_block(f"next{way}");
        b.cbranch(same, hit_bb, next_bb);
        b.position_at_end(hit_bb);
        b.cbranch(
            b.icmp_signed(
                "==",
                b.load(
                    b.gep(
                        slot,
                        [ir.Constant(i64, UTF8_CURSOR_EPOCH)],
                        name=f"u8c.e{way}.ep"
                    ),
                    name=f"u8c.e{way}.e"
                ),
                now,
                name=f"u8c.e{way}.cur"
            ),
            live_bb,
            stale_bb
        );
        b.position_at_end(live_bb);
        b.store(tick, b.gep(slot, [used_at], name=f"u8c.e{way}.touch"));
        b.ret(slot);
        b.position_at_end(stale_bb);
        _u8_store_cursor(b, slot, fresh, f"u8c.r{way}");
        b.ret(slot);
        b.position_at_end(next_bb);
    }
    victim = b.gep(
        blk,
        [
            b.add(
                b.mul(
                    oldest_way, ir.Constant(i64, UTF8_CURSOR_WORDS), name="u8c.way.at"
                ),
                ir.Constant(i64, 1),
                name="u8c.way.word"
            )
        ],
        name="u8c.victim"
    );
    _u8_store_cursor(b, victim, fresh, "u8c.new");
    b.ret(victim);
    return fn;
}

impl NaIRGenPass._utf8_forget_fn -> ir.Function {
    if "__jac_utf8_forget" in self.extern_funcs {
        return self.extern_funcs["__jac_utf8_forget"];
    }
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    i64p = i64.as_pointer();
    zero = ir.Constant(i64, 0);
    (get_fn, _, epoch) = self._utf8_cursor_state();
    fn = self._define_function(
        "__jac_utf8_forget", ir.FunctionType(ir.VoidType(), [i8p])
    );
    fn.linkage = "private";
    fn.attributes.add("noinline");
    self.extern_funcs["__jac_utf8_forget"] = fn;
    b = ir.IRBuilder(fn.append_basic_block("entry"));
    patch_bb = fn.append_basic_block("patch");
    done_bb = fn.append_basic_block("done");
    before = b.atomic_rmw(
        "add", epoch, ir.Constant(i64, 1), ordering="seq_cst", name="u8f.before"
    );
    held = b.call(get_fn, [], name="u8f.held");
    b.cbranch(b.icmp_unsigned("==", held, zero, name="u8f.none"), done_bb, patch_bb);
    b.position_at_end(patch_bb);
    blk = b.inttoptr(held, i64p, name="u8f.blk");
    gone = b.ptrtoint(fn.args[0], i64, name="u8f.gone");
    after = b.add(before, ir.Constant(i64, 1), name="u8f.after");
    for way in range(UTF8_CURSOR_WAYS) {
        at = 1 + way * UTF8_CURSOR_WORDS;
        base_p = b.gep(
            blk, [ir.Constant(i64, at + UTF8_CURSOR_BASE)], name=f"u8f.e{way}.bp"
        );
        epoch_p = b.gep(
            blk, [ir.Constant(i64, at + UTF8_CURSOR_EPOCH)], name=f"u8f.e{way}.ep"
        );
        held_base = b.load(base_p, name=f"u8f.e{way}.b");
        held_epoch = b.load(epoch_p, name=f"u8f.e{way}.e");
        mine = b.icmp_unsigned("==", held_base, gone, name=f"u8f.e{way}.mine");
        b.store(b.select(mine, zero, held_base, name=f"u8f.e{way}.b1"), base_p);
        used_p = b.gep(
            blk, [ir.Constant(i64, at + UTF8_CURSOR_USED)], name=f"u8f.e{way}.up"
        );
        b.store(
            b.select(
                mine, zero, b.load(used_p, name=f"u8f.e{way}.u"), name=f"u8f.e{way}.u1"
            ),
            used_p
        );
        b.store(
            b.select(
                b.and_(
                    b.not_(mine, name=f"u8f.e{way}.other"),
                    b.icmp_signed("==", held_epoch, before, name=f"u8f.e{way}.last"),
                    name=f"u8f.e{way}.keep"
                ),
                after,
                held_epoch,
                name=f"u8f.e{way}.e1"
            ),
            epoch_p
        );
    }
    b.branch(done_bb);
    b.position_at_end(done_bb);
    b.ret_void();
    return fn;
}

impl NaIRGenPass._utf8_forget_on_free(b: ir.IRBuilder, ptr: ir.Value) -> ir.IRBuilder {
    i64 = ir.IntType(64);
    fn = b.function;
    tell_bb = fn.append_basic_block("u8f.tell");
    cont_bb = fn.append_basic_block("u8f.cont");
    tag = b.load(
        b.bitcast(
            b.gep(ptr, [ir.Constant(i64, HDR_DTOR_OFF)], name="u8f.dt.slot"),
            i64.as_pointer(),
            name="u8f.dt.p"
        ),
        name="u8f.dv"
    );
    b.cbranch(self._utf8_cursor_tag_keyed(b, tag, "u8f"), tell_bb, cont_bb);
    b.position_at_end(tell_bb);
    b.call(self._utf8_forget_fn(), [ptr]);
    b.branch(cont_bb);
    b.position_at_end(cont_bb);
    return b;
}

impl NaIRGenPass._utf8_pick_anchor(
    b: ir.IRBuilder,
    want: ir.Value,
    spots: tuple[ir.Value, ir.Value],
    cursor: tuple[ir.Value, ir.Value],
    tail: tuple[ir.Value, ir.Value],
    known: ir.Value,
    name: str
) -> tuple[ir.Value, ir.Value, ir.Value] {
    (at_cur, at_end) = spots;
    (cur_k, cur_off) = cursor;
    (total, n) = tail;
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    ahead = b.icmp_signed(">=", want, at_cur, name=f"{name}.ahead");
    d_cur = b.select(
        ahead,
        b.sub(want, at_cur, name=f"{name}.d.fwd"),
        b.sub(at_cur, want, name=f"{name}.d.back"),
        name=f"{name}.d.cur"
    );
    d_end = b.select(
        known,
        b.sub(at_end, want, name=f"{name}.d.tail"),
        ir.Constant(i64, 0x7FFFFFFFFFFFFFFF),
        name=f"{name}.d.end"
    );
    use_cur = b.and_(
        b.icmp_signed("<=", d_cur, want, name=f"{name}.c.near"),
        b.icmp_signed("<=", d_cur, d_end, name=f"{name}.c.nearer"),
        name=f"{name}.use.cur"
    );
    use_end = b.and_(
        b.not_(use_cur, name=f"{name}.not.cur"),
        b.icmp_signed("<", d_end, want, name=f"{name}.e.near"),
        name=f"{name}.use.end"
    );
    return (
        b.select(
            use_cur,
            cur_k,
            b.select(use_end, total, zero, name=f"{name}.k.far"),
            name=f"{name}.ak"
        ),
        b.select(
            use_cur,
            cur_off,
            b.select(use_end, n, zero, name=f"{name}.o.far"),
            name=f"{name}.ao"
        ),
        b.select(
            use_cur, b.not_(ahead, name=f"{name}.behind"), use_end, name=f"{name}.back"
        )
    );
}

impl _u8_store_cursor(
    b: ir.IRBuilder, slot: ir.Value, values: list[ir.Value], name: str
) -> None {
    for (idx, value) in enumerate(values) {
        b.store(
            value,
            b.gep(slot, [ir.Constant(ir.IntType(64), idx)], name=f"{name}.w{idx}")
        );
    }
}
