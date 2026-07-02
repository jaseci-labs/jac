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

    collect_fnty = ir.FunctionType(ir.VoidType(), []);
    collect_fn = ir.Function(
        self.llvm_module, collect_fnty, name="__rc_collect_cycles"
    );
    collect_fn.linkage = "internal";
    self.rc_collect_cycles_fn = collect_fn;

    realloc_fn = self._get_or_declare_extern("realloc", i8_ptr, [i8_ptr, i64]);

    push_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);
    push_fn = ir.Function(self.llvm_module, push_fnty, name="__rc_push_root");
    push_fn.linkage = "internal";
    push_fn.args[0].name = "ptr";
    self.rc_push_root_fn = push_fn;

    pr_entry = push_fn.append_basic_block("entry");
    pr_grow = push_fn.append_basic_block("grow");
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
    b.cbranch(
        b.icmp_unsigned(
            "!=", b.load(collecting_gv, name="coll"), ir.Constant(i8, 0), name="coff"
        ),
        pr_done,
        pr_trigger
    );

    b = ir.IRBuilder(pr_trigger);
    b.call(collect_fn, []);
    b.branch(pr_done);

    b = ir.IRBuilder(pr_done);
    b.ret_void();

    self._emit_rc_collect_cycles();
}

impl NaIRGenPass._emit_rc_collect_cycles -> None {
    i8 = ir.IntType(8);
    i8_ptr = i8.as_pointer();
    i8_ptr_ptr = i8_ptr.as_pointer();
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();

    trace_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr, i8_ptr]);
    trace_fn_ptype = trace_fnty.as_pointer();
    phase_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);

    mark_gray_fn = ir.Function(self.llvm_module, phase_fnty, name="__rc_mark_gray");
    mark_gray_fn.linkage = "internal";
    mg_vis_fn = ir.Function(
        self.llvm_module, phase_fnty, name="__rc_mark_gray_visitor"
    );
    mg_vis_fn.linkage = "internal";
    scan_fn = ir.Function(self.llvm_module, phase_fnty, name="__rc_scan");
    scan_fn.linkage = "internal";
    scan_vis_fn = ir.Function(self.llvm_module, phase_fnty, name="__rc_scan_visitor");
    scan_vis_fn.linkage = "internal";
    scan_black_fn = ir.Function(self.llvm_module, phase_fnty, name="__rc_scan_black");
    scan_black_fn.linkage = "internal";
    sb_vis_fn = ir.Function(
        self.llvm_module, phase_fnty, name="__rc_scan_black_visitor"
    );
    sb_vis_fn.linkage = "internal";
    cw_fn = ir.Function(self.llvm_module, phase_fnty, name="__rc_collect_white");
    cw_fn.linkage = "internal";
    cw_vis_fn = ir.Function(
        self.llvm_module, phase_fnty, name="__rc_collect_white_visitor"
    );
    cw_vis_fn.linkage = "internal";

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
    mg_call = mark_gray_fn.append_basic_block("call");
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
    _mg_csp = b.gep(
        mark_gray_fn.args[0], [ir.Constant(i64, HDR_COLOR_OFF)], name="csp"
    );
    _mg_cb = b.load(_mg_csp, name="cb");
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
    b.store(
        b.or_(
            b.and_(_mg_cb, ir.Constant(i8, 0xFC), name="clr"),
            ir.Constant(i8, RC_COLOR_GRAY),
            name="ngray"
        ),
        _mg_csp
    );
    _mg_ti = b.load(
        b.bitcast(
            b.gep(mark_gray_fn.args[0], [ir.Constant(i64, HDR_TRACE_OFF)], name="tsp"),
            i64_ptr,
            name="tptr"
        ),
        name="ti"
    );
    b.cbranch(
        b.icmp_unsigned("==", _mg_ti, ir.Constant(i64, 0), name="tnull"),
        mg_done,
        mg_call
    );
    b = ir.IRBuilder(mg_call);
    b.call(
        b.inttoptr(_mg_ti, trace_fn_ptype, name="tfn"),
        [mark_gray_fn.args[0], b.bitcast(mg_vis_fn, i8_ptr, name="vis")]
    );
    b.branch(mg_done);
    b = ir.IRBuilder(mg_done);
    b.ret_void();

    sb_vis_fn.args[0].name = "child";
    sbv_null = sb_vis_fn.append_basic_block("null");
    sbv_work = sb_vis_fn.append_basic_block("work");
    sbv_done = sb_vis_fn.append_basic_block("done");

    b = ir.IRBuilder(sbv_null);
    b.cbranch(
        b.icmp_unsigned(
            "==", sb_vis_fn.args[0], ir.Constant(i8_ptr, None), name="null"
        ),
        sbv_done,
        sbv_work
    );
    b = ir.IRBuilder(sbv_work);
    b.call(scan_black_fn, [sb_vis_fn.args[0]]);
    b.branch(sbv_done);
    b = ir.IRBuilder(sbv_done);
    b.ret_void();

    scan_black_fn.args[0].name = "obj";
    sb_null = scan_black_fn.append_basic_block("null");
    sb_check = scan_black_fn.append_basic_block("check");
    sb_set = scan_black_fn.append_basic_block("set");
    sb_incr = scan_black_fn.append_basic_block("incr");
    sb_trace = scan_black_fn.append_basic_block("trace");
    sb_call = scan_black_fn.append_basic_block("call");
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
    _sb_csp = b.gep(
        scan_black_fn.args[0], [ir.Constant(i64, HDR_COLOR_OFF)], name="csp"
    );
    _sb_cb = b.load(_sb_csp, name="cb");
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
    b.store(
        b.or_(
            b.and_(_sb_cb, ir.Constant(i8, 0xFC), name="clr"),
            ir.Constant(i8, RC_COLOR_BLACK),
            name="nblack"
        ),
        _sb_csp
    );
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
    _sb_ti = b.load(
        b.bitcast(
            b.gep(scan_black_fn.args[0], [ir.Constant(i64, HDR_TRACE_OFF)], name="tsp"),
            i64_ptr,
            name="tptr"
        ),
        name="ti"
    );
    b.cbranch(
        b.icmp_unsigned("==", _sb_ti, ir.Constant(i64, 0), name="tnull"),
        sb_done,
        sb_call
    );
    b = ir.IRBuilder(sb_call);
    b.call(
        b.inttoptr(_sb_ti, trace_fn_ptype, name="tfn"),
        [scan_black_fn.args[0], b.bitcast(sb_vis_fn, i8_ptr, name="vis")]
    );
    b.branch(sb_done);
    b = ir.IRBuilder(sb_done);
    b.ret_void();

    scan_vis_fn.args[0].name = "child";
    sv_null = scan_vis_fn.append_basic_block("null");
    sv_work = scan_vis_fn.append_basic_block("work");
    sv_done = scan_vis_fn.append_basic_block("done");

    b = ir.IRBuilder(sv_null);
    b.cbranch(
        b.icmp_unsigned(
            "==", scan_vis_fn.args[0], ir.Constant(i8_ptr, None), name="null"
        ),
        sv_done,
        sv_work
    );
    b = ir.IRBuilder(sv_work);
    b.call(scan_fn, [scan_vis_fn.args[0]]);
    b.branch(sv_done);
    b = ir.IRBuilder(sv_done);
    b.ret_void();

    scan_fn.args[0].name = "obj";
    sc_null = scan_fn.append_basic_block("null");
    sc_check = scan_fn.append_basic_block("check");
    sc_rc = scan_fn.append_basic_block("rc_check");
    sc_dosb = scan_fn.append_basic_block("do_scan_black");
    sc_white = scan_fn.append_basic_block("mark_white");
    sc_call = scan_fn.append_basic_block("call_trace");
    sc_done = scan_fn.append_basic_block("done");

    b = ir.IRBuilder(sc_null);
    b.cbranch(
        b.icmp_unsigned("==", scan_fn.args[0], ir.Constant(i8_ptr, None), name="null"),
        sc_done,
        sc_check
    );
    b = ir.IRBuilder(sc_check);
    _sc_csp = b.gep(scan_fn.args[0], [ir.Constant(i64, HDR_COLOR_OFF)], name="csp");
    _sc_cb = b.load(_sc_csp, name="cb");
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
    b.store(
        b.or_(
            b.and_(_sc_cb, ir.Constant(i8, 0xFC), name="clr"),
            ir.Constant(i8, RC_COLOR_WHITE),
            name="nwhite"
        ),
        _sc_csp
    );
    _sc_ti = b.load(
        b.bitcast(
            b.gep(scan_fn.args[0], [ir.Constant(i64, HDR_TRACE_OFF)], name="tsp"),
            i64_ptr,
            name="tptr"
        ),
        name="ti"
    );
    b.cbranch(
        b.icmp_unsigned("==", _sc_ti, ir.Constant(i64, 0), name="tnull"),
        sc_done,
        sc_call
    );
    b = ir.IRBuilder(sc_call);
    b.call(
        b.inttoptr(_sc_ti, trace_fn_ptype, name="tfn"),
        [scan_fn.args[0], b.bitcast(scan_vis_fn, i8_ptr, name="vis")]
    );
    b.branch(sc_done);
    b = ir.IRBuilder(sc_done);
    b.ret_void();

    cw_vis_fn.args[0].name = "child";
    cwv_null = cw_vis_fn.append_basic_block("null");
    cwv_work = cw_vis_fn.append_basic_block("work");
    cwv_done = cw_vis_fn.append_basic_block("done");

    b = ir.IRBuilder(cwv_null);
    b.cbranch(
        b.icmp_unsigned(
            "==", cw_vis_fn.args[0], ir.Constant(i8_ptr, None), name="null"
        ),
        cwv_done,
        cwv_work
    );
    b = ir.IRBuilder(cwv_work);
    b.call(cw_fn, [cw_vis_fn.args[0]]);
    b.branch(cwv_done);
    b = ir.IRBuilder(cwv_done);
    b.ret_void();

    cw_fn.args[0].name = "obj";
    cw_null = cw_fn.append_basic_block("null");
    cw_check = cw_fn.append_basic_block("check");
    cw_set = cw_fn.append_basic_block("set");
    cw_call = cw_fn.append_basic_block("call_trace");
    cw_free = cw_fn.append_basic_block("free_raw");
    cw_done = cw_fn.append_basic_block("done");

    b = ir.IRBuilder(cw_null);
    b.cbranch(
        b.icmp_unsigned("==", cw_fn.args[0], ir.Constant(i8_ptr, None), name="null"),
        cw_done,
        cw_check
    );
    b = ir.IRBuilder(cw_check);
    _cw_csp = b.gep(cw_fn.args[0], [ir.Constant(i64, HDR_COLOR_OFF)], name="csp");
    _cw_cb = b.load(_cw_csp, name="cb");
    b.cbranch(
        b.icmp_unsigned(
            "==",
            b.and_(_cw_cb, ir.Constant(i8, 3), name="col"),
            ir.Constant(i8, RC_COLOR_WHITE),
            name="is.white"
        ),
        cw_set,
        cw_done
    );
    b = ir.IRBuilder(cw_set);
    b.store(ir.Constant(i8, RC_COLOR_BLACK), _cw_csp);
    _cw_ti = b.load(
        b.bitcast(
            b.gep(cw_fn.args[0], [ir.Constant(i64, HDR_TRACE_OFF)], name="tsp"),
            i64_ptr,
            name="tptr"
        ),
        name="ti"
    );
    b.cbranch(
        b.icmp_unsigned("==", _cw_ti, ir.Constant(i64, 0), name="tnull"),
        cw_free,
        cw_call
    );
    b = ir.IRBuilder(cw_call);
    b.call(
        b.inttoptr(_cw_ti, trace_fn_ptype, name="tfn"),
        [cw_fn.args[0], b.bitcast(cw_vis_fn, i8_ptr, name="vis")]
    );
    b.branch(cw_free);
    b = ir.IRBuilder(cw_free);
    b.call(
        self.free_fn,
        [b.gep(cw_fn.args[0], [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name="raw")]
    );
    b.branch(cw_done);
    b = ir.IRBuilder(cw_done);
    b.ret_void();

    collect_fn = self.rc_collect_cycles_fn;

    cc_entry = collect_fn.append_basic_block("entry");
    cc_start = collect_fn.append_basic_block("start");
    cc_p1pre = collect_fn.append_basic_block("p1pre");
    cc_p1hdr = collect_fn.append_basic_block("p1hdr");
    cc_p1body = collect_fn.append_basic_block("p1body");
    cc_p2pre = collect_fn.append_basic_block("p2pre");
    cc_p2hdr = collect_fn.append_basic_block("p2hdr");
    cc_p2body = collect_fn.append_basic_block("p2body");
    cc_p3pre = collect_fn.append_basic_block("p3pre");
    cc_p3hdr = collect_fn.append_basic_block("p3hdr");
    cc_p3body = collect_fn.append_basic_block("p3body");
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
    b.cbranch(
        b.icmp_unsigned("==", _cc_count, ir.Constant(i64, 0), name="empty"),
        cc_finish,
        cc_p1pre
    );

    b = ir.IRBuilder(cc_p1pre);
    _cc_buf1 = b.load(self.rc_roots_buf_gv, name="buf1");
    b.branch(cc_p1hdr);

    b = ir.IRBuilder(cc_p1hdr);
    _p1i = b.phi(i64, name="p1i");
    _p1i.add_incoming(ir.Constant(i64, 0), cc_p1pre);
    b.cbranch(
        b.icmp_unsigned(">=", _p1i, _cc_count, name="p1done"), cc_p2pre, cc_p1body
    );

    b = ir.IRBuilder(cc_p1body);
    _p1slot = b.gep(
        _cc_buf1, [b.mul(_p1i, ir.Constant(i64, 8), name="p1off")], name="p1slot"
    );
    b.call(
        mark_gray_fn,
        [b.load(b.bitcast(_p1slot, i8_ptr_ptr, name="p1pp"), name="p1obj")]
    );
    _p1next = b.add(_p1i, ir.Constant(i64, 1), name="p1next");
    _p1i.add_incoming(_p1next, cc_p1body);
    b.branch(cc_p1hdr);

    b = ir.IRBuilder(cc_p2pre);
    _cc_buf2 = b.load(self.rc_roots_buf_gv, name="buf2");
    b.branch(cc_p2hdr);

    b = ir.IRBuilder(cc_p2hdr);
    _p2i = b.phi(i64, name="p2i");
    _p2i.add_incoming(ir.Constant(i64, 0), cc_p2pre);
    b.cbranch(
        b.icmp_unsigned(">=", _p2i, _cc_count, name="p2done"), cc_p3pre, cc_p2body
    );

    b = ir.IRBuilder(cc_p2body);
    _p2slot = b.gep(
        _cc_buf2, [b.mul(_p2i, ir.Constant(i64, 8), name="p2off")], name="p2slot"
    );
    b.call(
        scan_fn, [b.load(b.bitcast(_p2slot, i8_ptr_ptr, name="p2pp"), name="p2obj")]
    );
    _p2next = b.add(_p2i, ir.Constant(i64, 1), name="p2next");
    _p2i.add_incoming(_p2next, cc_p2body);
    b.branch(cc_p2hdr);

    b = ir.IRBuilder(cc_p3pre);
    _cc_buf3 = b.load(self.rc_roots_buf_gv, name="buf3");
    b.branch(cc_p3hdr);

    b = ir.IRBuilder(cc_p3hdr);
    _p3i = b.phi(i64, name="p3i");
    _p3i.add_incoming(ir.Constant(i64, 0), cc_p3pre);
    b.cbranch(
        b.icmp_unsigned(">=", _p3i, _cc_count, name="p3done"), cc_finish, cc_p3body
    );

    b = ir.IRBuilder(cc_p3body);
    _p3slot = b.gep(
        _cc_buf3, [b.mul(_p3i, ir.Constant(i64, 8), name="p3off")], name="p3slot"
    );
    _p3obj = b.load(b.bitcast(_p3slot, i8_ptr_ptr, name="p3pp"), name="p3obj");
    _p3csp = b.gep(_p3obj, [ir.Constant(i64, HDR_COLOR_OFF)], name="p3csp");
    _p3cb = b.load(_p3csp, name="p3cb");
    b.store(b.and_(_p3cb, ir.Constant(i8, 0xFB), name="p3clr"), _p3csp);
    b.call(cw_fn, [_p3obj]);
    _p3next = b.add(_p3i, ir.Constant(i64, 1), name="p3next");
    _p3i.add_incoming(_p3next, cc_p3body);
    b.branch(cc_p3hdr);

    b = ir.IRBuilder(cc_finish);
    b.store(ir.Constant(i64, 0), self.rc_roots_count_gv);
    b.store(ir.Constant(i8, 0), self.rc_collecting_gv);
    b.branch(cc_done);

    b = ir.IRBuilder(cc_done);
    b.ret_void();
}
