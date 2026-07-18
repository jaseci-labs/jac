import from jaclang.compiler.passes.native.llvm { ir }

impl NaIRGenPass._emit_rc_roots_globals -> None {
    i8 = ir.IntType(8);
    i8_ptr = i8.as_pointer();
    i8_ptr_ptr = i8_ptr.as_pointer();
    i64 = ir.IntType(64);

    roots_buf_gv = ir.GlobalVariable(self.llvm_module, i8_ptr, name="__rc_roots_buf");
    roots_buf_gv.linkage = "weak";
    roots_buf_gv.initializer = ir.Constant(i8_ptr, None);
    self.rc_roots_buf_gv = roots_buf_gv;

    roots_cap_gv = ir.GlobalVariable(self.llvm_module, i64, name="__rc_roots_cap");
    roots_cap_gv.linkage = "weak";
    roots_cap_gv.initializer = ir.Constant(i64, 0);
    self.rc_roots_cap_gv = roots_cap_gv;

    roots_count_gv = ir.GlobalVariable(self.llvm_module, i64, name="__rc_roots_count");
    roots_count_gv.linkage = "weak";
    roots_count_gv.initializer = ir.Constant(i64, 0);
    self.rc_roots_count_gv = roots_count_gv;

    collecting_gv = ir.GlobalVariable(self.llvm_module, i8, name="__rc_collecting");
    collecting_gv.linkage = "weak";
    collecting_gv.initializer = ir.Constant(i8, 0);
    self.rc_collecting_gv = collecting_gv;

    cycles_enabled_gv = ir.GlobalVariable(
        self.llvm_module, i8, name="__rc_cycles_enabled"
    );
    cycles_enabled_gv.linkage = "weak";
    cycles_enabled_gv.initializer = ir.Constant(i8, 0);
    self.rc_cycles_enabled_gv = cycles_enabled_gv;

    collect_fnty = ir.FunctionType(ir.VoidType(), []);
    collect_fn = ir.Function(
        self.llvm_module, collect_fnty, name="__rc_collect_cycles"
    );
    collect_fn.linkage = "internal";
    self.rc_collect_cycles_fn = collect_fn;

    lookup_fnty = ir.FunctionType(i64, [i64]);
    lookup_fn = ir.Function(self.llvm_module, lookup_fnty, name="__rc_trace_lookup");
    lookup_fn.linkage = "internal";
    self.rc_trace_lookup_fn = lookup_fn;

    realloc_fn = self._get_or_declare_extern("realloc", i8_ptr, [i8_ptr, i64]);

    push_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);
    push_fn = ir.Function(self.llvm_module, push_fnty, name="__rc_push_root");
    push_fn.linkage = "internal";
    push_fn.args[0].name = "ptr";
    self.rc_push_root_fn = push_fn;

    pr_entry = push_fn.append_basic_block("entry");
    pr_grow = push_fn.append_basic_block("grow");
    pr_grow_ok = push_fn.append_basic_block("grow_ok");
    pr_store = push_fn.append_basic_block("store");
    pr_chk_thresh = push_fn.append_basic_block("chk_thresh");
    pr_trigger = push_fn.append_basic_block("trigger");
    pr_done = push_fn.append_basic_block("done");

    b = ir.IRBuilder(pr_entry);
    _cnt = b.load(roots_count_gv, name="cnt");
    _cap = b.load(roots_cap_gv, name="cap");
    b.cbranch(b.icmp_unsigned(">=", _cnt, _cap, name="full"), pr_grow, pr_store);

    b = ir.IRBuilder(pr_grow);
    _czero = b.icmp_unsigned("==", _cap, ir.Constant(i64, 0), name="czero");
    _ncap = b.select(
        _czero, ir.Constant(i64, 256), b.shl(_cap, ir.Constant(i64, 1)), name="ncap"
    );
    _obuf = b.load(roots_buf_gv, name="obuf");
    _nbuf = b.call(
        realloc_fn,
        [_obuf, b.mul(_ncap, ir.Constant(i64, 8), name="nbytes")],
        name="nbuf"
    );

    b.cbranch(
        b.icmp_signed("==", _nbuf, ir.Constant(i8_ptr, None), name="nbuf.null"),
        pr_done,
        pr_grow_ok
    );

    b = ir.IRBuilder(pr_grow_ok);
    b.store(_nbuf, roots_buf_gv);
    b.store(_ncap, roots_cap_gv);
    b.branch(pr_store);

    b = ir.IRBuilder(pr_store);
    _cnt2 = b.load(roots_count_gv, name="cnt2");
    _buf = b.load(roots_buf_gv, name="buf");
    _slot = b.gep(_buf, [b.mul(_cnt2, ir.Constant(i64, 8), name="soff")], name="slot");
    b.store(push_fn.args[0], b.bitcast(_slot, i8_ptr_ptr, name="slotpp"));
    _cnt3 = b.add(_cnt2, ir.Constant(i64, 1), name="cnt3");
    b.store(_cnt3, roots_count_gv);
    b.cbranch(
        b.icmp_unsigned(
            ">=", _cnt3, ir.Constant(i64, RC_CYCLE_THRESHOLD), name="thresh"
        ),
        pr_chk_thresh,
        pr_done
    );

    b = ir.IRBuilder(pr_chk_thresh);
    _pr_collecting = b.icmp_unsigned(
        "!=", b.load(collecting_gv, name="coll"), ir.Constant(i8, 0), name="coff"
    );
    _pr_disabled = b.icmp_unsigned(
        "==",
        b.load(cycles_enabled_gv, name="cyc.en"),
        ir.Constant(i8, 0),
        name="cyc.off"
    );
    b.cbranch(b.or_(_pr_collecting, _pr_disabled, name="pr.skip"), pr_done, pr_trigger);

    b = ir.IRBuilder(pr_trigger);
    b.call(collect_fn, []);
    b.branch(pr_done);

    b = ir.IRBuilder(pr_done);
    b.ret_void();
}

impl NaIRGenPass._emit_rc_color_load(
    b: ir.IRBuilder, obj_i8: ir.Value
) -> tuple[ir.Value, ir.Value] {
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    _slot = b.gep(obj_i8, [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name="csp.raw");
    csp = b.bitcast(_slot, i64_ptr, name="csp");
    _word = b.load(csp, name="cword");
    _field = b.lshr(_word, ir.Constant(i64, RC_COLOR_SHIFT), name="cfield");
    cb = b.trunc(b.and_(_field, ir.Constant(i64, 7), name="cbits"), i8, name="cb");
    return (csp, cb);
}

impl NaIRGenPass._emit_rc_color_store(
    b: ir.IRBuilder, csp: ir.Value, cb: ir.Value, color: int
) -> None {
    i64 = ir.IntType(64);
    _word = b.load(csp, name="csw");
    _cleared = b.and_(_word, ir.Constant(i64, ~(3 << RC_COLOR_SHIFT)), name="csw.clr");
    b.store(
        b.or_(_cleared, ir.Constant(i64, color << RC_COLOR_SHIFT), name="csw.new"), csp
    );
}

impl NaIRGenPass._emit_rc_color_reset(b: ir.IRBuilder, csp: ir.Value) -> None {
    i64 = ir.IntType(64);
    _word = b.load(csp, name="crw");
    b.store(
        b.and_(_word, ir.Constant(i64, ~(7 << RC_COLOR_SHIFT)), name="crw.new"), csp
    );
}

impl NaIRGenPass._emit_rc_clear_buffered(b: ir.IRBuilder, csp: ir.Value) -> None {
    i64 = ir.IntType(64);
    _word = b.load(csp, name="cbw");
    b.store(
        b.and_(
            _word,
            ir.Constant(i64, ~(RC_BUFFERED_BIT << RC_COLOR_SHIFT)),
            name="cbw.new"
        ),
        csp
    );
}

impl NaIRGenPass._emit_rc_is_buffered(
    b: ir.IRBuilder, obj_i8: ir.Value, name_prefix: str = "buf"
) -> ir.Value {
    i8 = ir.IntType(8);
    (_csp, _cb) = self._emit_rc_color_load(b, obj_i8);
    return b.icmp_unsigned(
        "!=",
        b.and_(_cb, ir.Constant(i8, RC_BUFFERED_BIT), name=f"{name_prefix}.bit"),
        ir.Constant(i8, 0),
        name=f"{name_prefix}.set"
    );
}

impl NaIRGenPass._emit_rc_trace_dispatch(
    fn: ir.Function,
    b: ir.IRBuilder,
    obj_i8: ir.Value,
    visitor_fn: ir.Function,
    done_block: ir.Block
) -> None {
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    trace_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr, i8_ptr]);
    trace_fn_ptype = trace_fnty.as_pointer();

    lookup_block = fn.append_basic_block("trace_lookup");
    call_block = fn.append_basic_block("trace_call");
    _di = b.load(
        b.bitcast(
            b.gep(obj_i8, [ir.Constant(i64, HDR_DTOR_OFF)], name="tdsp"),
            i64_ptr,
            name="tdptr"
        ),
        name="tdi"
    );
    b.cbranch(
        b.icmp_unsigned("==", _di, ir.Constant(i64, 0), name="tdnull"),
        done_block,
        lookup_block
    );

    lb = ir.IRBuilder(lookup_block);
    _ti = lb.call(self.rc_trace_lookup_fn, [_di], name="ti");
    lb.cbranch(
        lb.icmp_unsigned("==", _ti, ir.Constant(i64, 0), name="tnull"),
        done_block,
        call_block
    );

    cb = ir.IRBuilder(call_block);
    cb.call(
        cb.inttoptr(_ti, trace_fn_ptype, name="tfn"),
        [obj_i8, cb.bitcast(visitor_fn, i8_ptr, name="vis")]
    );
    cb.branch(done_block);
}

impl NaIRGenPass._emit_rc_simple_visitor(
    name: str, phase_fn: ir.Function
) -> ir.Function {
    i8_ptr = ir.IntType(8).as_pointer();
    phase_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);
    vis_fn = ir.Function(self.llvm_module, phase_fnty, name=name);
    vis_fn.linkage = "internal";
    vis_fn.args[0].name = "child";

    v_null = vis_fn.append_basic_block("null");
    v_work = vis_fn.append_basic_block("work");
    v_done = vis_fn.append_basic_block("done");

    b = ir.IRBuilder(v_null);
    b.cbranch(
        b.icmp_unsigned("==", vis_fn.args[0], ir.Constant(i8_ptr, None), name="null"),
        v_done,
        v_work
    );
    b = ir.IRBuilder(v_work);
    b.call(phase_fn, [vis_fn.args[0]]);
    b.branch(v_done);
    b = ir.IRBuilder(v_done);
    b.ret_void();

    return vis_fn;
}

impl NaIRGenPass._emit_rc_mark_gray_phase -> ir.Function {
    i8 = ir.IntType(8);
    i8_ptr = i8.as_pointer();
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    phase_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);

    mark_gray_fn = ir.Function(self.llvm_module, phase_fnty, name="__rc_mark_gray");
    mark_gray_fn.linkage = "internal";
    mg_vis_fn = ir.Function(
        self.llvm_module, phase_fnty, name="__rc_mark_gray_visitor"
    );
    mg_vis_fn.linkage = "internal";

    mg_vis_fn.args[0].name = "child";
    mgv_null = mg_vis_fn.append_basic_block("null");
    mgv_work = mg_vis_fn.append_basic_block("work");
    mgv_decr = mg_vis_fn.append_basic_block("decr");
    mgv_done = mg_vis_fn.append_basic_block("done");

    b = ir.IRBuilder(mgv_null);
    b.cbranch(
        b.icmp_unsigned(
            "==", mg_vis_fn.args[0], ir.Constant(i8_ptr, None), name="null"
        ),
        mgv_done,
        mgv_work
    );
    b = ir.IRBuilder(mgv_work);
    _mgv_rp = b.bitcast(
        b.gep(mg_vis_fn.args[0], [ir.Constant(i64, HDR_RC_OFF)], name="rslot"),
        i64_ptr,
        name="rptr"
    );
    _mgv_rc = b.load(_mgv_rp, name="rc");
    b.cbranch(
        b.icmp_unsigned("==", _mgv_rc, ir.Constant(i64, RC_SENTINEL), name="sent"),
        mgv_done,
        mgv_decr
    );
    b = ir.IRBuilder(mgv_decr);
    b.store(b.sub(_mgv_rc, ir.Constant(i64, 1), name="nrc"), _mgv_rp);
    b.call(mark_gray_fn, [mg_vis_fn.args[0]]);
    b.branch(mgv_done);
    b = ir.IRBuilder(mgv_done);
    b.ret_void();

    mark_gray_fn.args[0].name = "obj";
    mg_null = mark_gray_fn.append_basic_block("null");
    mg_check = mark_gray_fn.append_basic_block("check");
    mg_set = mark_gray_fn.append_basic_block("set");
    mg_done = mark_gray_fn.append_basic_block("done");

    b = ir.IRBuilder(mg_null);
    b.cbranch(
        b.icmp_unsigned(
            "==", mark_gray_fn.args[0], ir.Constant(i8_ptr, None), name="null"
        ),
        mg_done,
        mg_check
    );
    b = ir.IRBuilder(mg_check);
    (_mg_csp, _mg_cb) = self._emit_rc_color_load(b, mark_gray_fn.args[0]);
    b.cbranch(
        b.icmp_unsigned(
            "==",
            b.and_(_mg_cb, ir.Constant(i8, 3), name="col"),
            ir.Constant(i8, RC_COLOR_GRAY),
            name="is.gray"
        ),
        mg_done,
        mg_set
    );
    b = ir.IRBuilder(mg_set);
    self._emit_rc_color_store(b, _mg_csp, _mg_cb, RC_COLOR_GRAY);
    self._emit_rc_trace_dispatch(
        mark_gray_fn, b, mark_gray_fn.args[0], mg_vis_fn, mg_done
    );
    b = ir.IRBuilder(mg_done);
    b.ret_void();

    return mark_gray_fn;
}

impl NaIRGenPass._emit_rc_scan_black_phase -> ir.Function {
    i8 = ir.IntType(8);
    i8_ptr = i8.as_pointer();
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    phase_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);

    scan_black_fn = ir.Function(self.llvm_module, phase_fnty, name="__rc_scan_black");
    scan_black_fn.linkage = "internal";
    sb_vis_fn = self._emit_rc_simple_visitor("__rc_scan_black_visitor", scan_black_fn);

    scan_black_fn.args[0].name = "obj";
    sb_null = scan_black_fn.append_basic_block("null");
    sb_check = scan_black_fn.append_basic_block("check");
    sb_set = scan_black_fn.append_basic_block("set");
    sb_incr = scan_black_fn.append_basic_block("incr");
    sb_trace = scan_black_fn.append_basic_block("trace");
    sb_done = scan_black_fn.append_basic_block("done");

    b = ir.IRBuilder(sb_null);
    b.cbranch(
        b.icmp_unsigned(
            "==", scan_black_fn.args[0], ir.Constant(i8_ptr, None), name="null"
        ),
        sb_done,
        sb_check
    );
    b = ir.IRBuilder(sb_check);
    (_sb_csp, _sb_cb) = self._emit_rc_color_load(b, scan_black_fn.args[0]);
    b.cbranch(
        b.icmp_unsigned(
            "==",
            b.and_(_sb_cb, ir.Constant(i8, 3), name="col"),
            ir.Constant(i8, RC_COLOR_BLACK),
            name="is.black"
        ),
        sb_done,
        sb_set
    );
    b = ir.IRBuilder(sb_set);
    self._emit_rc_color_store(b, _sb_csp, _sb_cb, RC_COLOR_BLACK);
    _sb_rp = b.bitcast(
        b.gep(scan_black_fn.args[0], [ir.Constant(i64, HDR_RC_OFF)], name="rsp"),
        i64_ptr,
        name="rptr"
    );
    _sb_rc = b.load(_sb_rp, name="rc");
    b.cbranch(
        b.icmp_unsigned("==", _sb_rc, ir.Constant(i64, RC_SENTINEL), name="sent"),
        sb_trace,
        sb_incr
    );
    b = ir.IRBuilder(sb_incr);
    b.store(b.add(_sb_rc, ir.Constant(i64, 1), name="nrc"), _sb_rp);
    b.branch(sb_trace);
    b = ir.IRBuilder(sb_trace);
    self._emit_rc_trace_dispatch(
        scan_black_fn, b, scan_black_fn.args[0], sb_vis_fn, sb_done
    );
    b = ir.IRBuilder(sb_done);
    b.ret_void();

    return scan_black_fn;
}

impl NaIRGenPass._emit_rc_scan_phase(scan_black_fn: ir.Function) -> ir.Function {
    i8 = ir.IntType(8);
    i8_ptr = i8.as_pointer();
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    phase_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);

    scan_fn = ir.Function(self.llvm_module, phase_fnty, name="__rc_scan");
    scan_fn.linkage = "internal";
    scan_vis_fn = self._emit_rc_simple_visitor("__rc_scan_visitor", scan_fn);

    scan_fn.args[0].name = "obj";
    sc_null = scan_fn.append_basic_block("null");
    sc_check = scan_fn.append_basic_block("check");
    sc_rc = scan_fn.append_basic_block("rc_check");
    sc_dosb = scan_fn.append_basic_block("do_scan_black");
    sc_white = scan_fn.append_basic_block("mark_white");
    sc_done = scan_fn.append_basic_block("done");

    b = ir.IRBuilder(sc_null);
    b.cbranch(
        b.icmp_unsigned("==", scan_fn.args[0], ir.Constant(i8_ptr, None), name="null"),
        sc_done,
        sc_check
    );
    b = ir.IRBuilder(sc_check);
    (_sc_csp, _sc_cb) = self._emit_rc_color_load(b, scan_fn.args[0]);
    b.cbranch(
        b.icmp_unsigned(
            "==",
            b.and_(_sc_cb, ir.Constant(i8, 3), name="col"),
            ir.Constant(i8, RC_COLOR_GRAY),
            name="is.gray"
        ),
        sc_rc,
        sc_done
    );
    b = ir.IRBuilder(sc_rc);
    _sc_rc = b.load(
        b.bitcast(
            b.gep(scan_fn.args[0], [ir.Constant(i64, HDR_RC_OFF)], name="rsp"),
            i64_ptr,
            name="rptr"
        ),
        name="rc"
    );
    b.cbranch(
        b.icmp_unsigned(">", _sc_rc, ir.Constant(i64, 0), name="live"),
        sc_dosb,
        sc_white
    );
    b = ir.IRBuilder(sc_dosb);
    b.call(scan_black_fn, [scan_fn.args[0]]);
    b.branch(sc_done);
    b = ir.IRBuilder(sc_white);
    self._emit_rc_color_store(b, _sc_csp, _sc_cb, RC_COLOR_WHITE);
    self._emit_rc_trace_dispatch(scan_fn, b, scan_fn.args[0], scan_vis_fn, sc_done);
    b = ir.IRBuilder(sc_done);
    b.ret_void();

    return scan_fn;
}

impl NaIRGenPass._emit_rc_collect_white_phase -> ir.Function {
    i8 = ir.IntType(8);
    i8_ptr = i8.as_pointer();
    phase_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);

    cw_fn = ir.Function(self.llvm_module, phase_fnty, name="__rc_collect_white");
    cw_fn.linkage = "internal";
    cw_vis_fn = self._emit_rc_simple_visitor("__rc_collect_white_visitor", cw_fn);

    cw_fn.args[0].name = "obj";
    cw_null = cw_fn.append_basic_block("null");
    cw_check = cw_fn.append_basic_block("check");
    cw_set = cw_fn.append_basic_block("set");
    cw_done = cw_fn.append_basic_block("done");

    b = ir.IRBuilder(cw_null);
    b.cbranch(
        b.icmp_unsigned("==", cw_fn.args[0], ir.Constant(i8_ptr, None), name="null"),
        cw_done,
        cw_check
    );
    b = ir.IRBuilder(cw_check);
    (_cw_csp, _cw_cb) = self._emit_rc_color_load(b, cw_fn.args[0]);

    _cw_is_white = b.icmp_unsigned(
        "==",
        b.and_(_cw_cb, ir.Constant(i8, 3), name="col"),
        ir.Constant(i8, RC_COLOR_WHITE),
        name="is.white"
    );
    _cw_unbuffered = b.icmp_unsigned(
        "==",
        b.and_(_cw_cb, ir.Constant(i8, RC_BUFFERED_BIT), name="buf.bit"),
        ir.Constant(i8, 0),
        name="unbuffered"
    );
    b.cbranch(b.and_(_cw_is_white, _cw_unbuffered, name="cw.reclaim"), cw_set, cw_done);
    b = ir.IRBuilder(cw_set);

    self._emit_rc_color_reset(b, _cw_csp);

    cw_reclaim = self._emit_rc_collect_white_reclaim(cw_fn, cw_done, cw_fn.args[0]);
    self._emit_rc_trace_dispatch(cw_fn, b, cw_fn.args[0], cw_vis_fn, cw_reclaim);

    b = ir.IRBuilder(cw_done);
    b.ret_void();

    return cw_fn;
}

impl NaIRGenPass._emit_rc_collect_white_reclaim(
    fn: ir.Function, done_bb: ir.Block, ptr: ir.Value
) -> ir.Block {
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();

    reclaim_bb = fn.append_basic_block("cw_reclaim");
    call_dtor_bb = fn.append_basic_block("cw_call_dtor");
    raw_free_bb = self._emit_raw_free_bbs(fn, done_bb, ptr);

    b = ir.IRBuilder(reclaim_bb);
    dtor_slot = b.bitcast(
        b.gep(ptr, [ir.Constant(i64, HDR_DTOR_OFF)], name="cw.dtor.raw"),
        i64_ptr,
        name="cw.dtor.slot"
    );
    dtor_val = b.load(dtor_slot, name="cw.dtor.val");

    b.cbranch(
        b.icmp_unsigned("==", dtor_val, ir.Constant(i64, 0), name="cw.dtor.zero"),
        raw_free_bb,
        call_dtor_bb
    );

    b = ir.IRBuilder(call_dtor_bb);
    dtor_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);
    dtor_fn_ptr = b.bitcast(
        b.inttoptr(dtor_val, i8_ptr, name="cw.dtor.i8"),
        dtor_fnty.as_pointer(),
        name="cw.dtor.fn"
    );
    b.call(dtor_fn_ptr, [ptr]);
    b.branch(done_bb);

    return reclaim_bb;
}

impl NaIRGenPass._emit_rc_root_pass(
    prefix: str,
    count: ir.Value,
    next_bb: ir.Block,
    phase_fn: ir.Function,
    clear_purple: bool
) -> ir.Block {
    i8 = ir.IntType(8);
    i8_ptr = i8.as_pointer();
    i8_ptr_ptr = i8_ptr.as_pointer();
    i64 = ir.IntType(64);
    collect_fn = self.rc_collect_cycles_fn;

    pre = collect_fn.append_basic_block(f"{prefix}pre");
    hdr = collect_fn.append_basic_block(f"{prefix}hdr");
    body = collect_fn.append_basic_block(f"{prefix}body");

    b = ir.IRBuilder(pre);
    buf = b.load(self.rc_roots_buf_gv, name=f"{prefix}buf");
    b.branch(hdr);

    b = ir.IRBuilder(hdr);
    idx = b.phi(i64, name=f"{prefix}i");
    idx.add_incoming(ir.Constant(i64, 0), pre);
    b.cbranch(b.icmp_unsigned(">=", idx, count, name=f"{prefix}done"), next_bb, body);

    b = ir.IRBuilder(body);
    slot = b.gep(
        buf,
        [b.mul(idx, ir.Constant(i64, 8), name=f"{prefix}off")],
        name=f"{prefix}slot"
    );
    optr = b.load(b.bitcast(slot, i8_ptr_ptr, name=f"{prefix}pp"), name=f"{prefix}obj");
    if clear_purple {
        (csp, cb) = self._emit_rc_color_load(b, optr);
        self._emit_rc_clear_buffered(b, csp);
    }
    b.call(phase_fn, [optr]);
    nxt = b.add(idx, ir.Constant(i64, 1), name=f"{prefix}next");
    idx.add_incoming(nxt, body);
    b.branch(hdr);

    return pre;
}

impl NaIRGenPass._emit_rc_collect_loop(
    mark_gray_fn: ir.Function, scan_fn: ir.Function, collect_white_fn: ir.Function
) -> None {
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);

    collect_fn = self.rc_collect_cycles_fn;

    cc_entry = collect_fn.append_basic_block("entry");
    cc_start = collect_fn.append_basic_block("start");
    cc_finish = collect_fn.append_basic_block("finish");
    cc_done = collect_fn.append_basic_block("done");

    b = ir.IRBuilder(cc_entry);
    b.cbranch(
        b.icmp_unsigned(
            "!=",
            b.load(self.rc_collecting_gv, name="coll"),
            ir.Constant(i8, 0),
            name="reentr"
        ),
        cc_done,
        cc_start
    );

    b = ir.IRBuilder(cc_start);
    b.store(ir.Constant(i8, 1), self.rc_collecting_gv);
    _cc_count = b.load(self.rc_roots_count_gv, name="count");

    p3pre = self._emit_rc_root_pass(
        "cc_p3", _cc_count, cc_finish, collect_white_fn, True
    );
    p2pre = self._emit_rc_root_pass("cc_p2", _cc_count, p3pre, scan_fn, False);
    p1pre = self._emit_rc_root_pass("cc_p1", _cc_count, p2pre, mark_gray_fn, False);
    b.cbranch(
        b.icmp_unsigned("==", _cc_count, ir.Constant(i64, 0), name="empty"),
        cc_finish,
        p1pre
    );

    b = ir.IRBuilder(cc_finish);
    b.store(ir.Constant(i64, 0), self.rc_roots_count_gv);
    b.store(ir.Constant(i8, 0), self.rc_collecting_gv);
    b.branch(cc_done);

    b = ir.IRBuilder(cc_done);
    b.ret_void();
}

impl NaIRGenPass._emit_rc_collect_cycles -> None {
    mark_gray_fn = self._emit_rc_mark_gray_phase();
    scan_black_fn = self._emit_rc_scan_black_phase();
    scan_fn = self._emit_rc_scan_phase(scan_black_fn);
    collect_white_fn = self._emit_rc_collect_white_phase();
    self._emit_rc_collect_loop(mark_gray_fn, scan_fn, collect_white_fn);
}
