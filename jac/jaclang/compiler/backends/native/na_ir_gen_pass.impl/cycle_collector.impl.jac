import from jaclang.compiler.backends.native.llvm { ir }


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
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    phase_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);
    vis_fn = ir.Function(self.llvm_module, phase_fnty, name=name);
    vis_fn.linkage = "internal";
    vis_fn.args[0].name = "child";

    v_null = vis_fn.append_basic_block("null");
    v_sent = vis_fn.append_basic_block("sent");
    v_work = vis_fn.append_basic_block("work");
    v_done = vis_fn.append_basic_block("done");

    b = ir.IRBuilder(v_null);
    b.cbranch(
        b.icmp_unsigned("==", vis_fn.args[0], ir.Constant(i8_ptr, None), name="null"),
        v_done,
        v_sent
    );

    b = ir.IRBuilder(v_sent);
    _vs_rc = b.load(
        b.bitcast(
            b.gep(vis_fn.args[0], [ir.Constant(i64, HDR_RC_OFF)], name="rsp"),
            i64_ptr,
            name="rptr"
        ),
        name="rc"
    );
    b.cbranch(
        b.icmp_unsigned("==", _vs_rc, ir.Constant(i64, RC_SENTINEL), name="sent"),
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
    sb_vis_fn = ir.Function(
        self.llvm_module, phase_fnty, name="__rc_scan_black_visitor"
    );
    sb_vis_fn.linkage = "internal";
    sb_vis_fn.args[0].name = "child";
    sbv_null = sb_vis_fn.append_basic_block("null");
    sbv_work = sb_vis_fn.append_basic_block("work");
    sbv_incr = sb_vis_fn.append_basic_block("incr");
    sbv_recurse = sb_vis_fn.append_basic_block("recurse");
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
    _sbv_rp = b.bitcast(
        b.gep(sb_vis_fn.args[0], [ir.Constant(i64, HDR_RC_OFF)], name="rslot"),
        i64_ptr,
        name="rptr"
    );
    _sbv_rc = b.load(_sbv_rp, name="rc");
    b.cbranch(
        b.icmp_unsigned("==", _sbv_rc, ir.Constant(i64, RC_SENTINEL), name="sent"),
        sbv_done,
        sbv_incr
    );
    b = ir.IRBuilder(sbv_incr);
    b.store(b.add(_sbv_rc, ir.Constant(i64, 1), name="nrc"), _sbv_rp);
    (_sbv_csp, _sbv_cb) = self._emit_rc_color_load(b, sb_vis_fn.args[0]);
    b.cbranch(
        b.icmp_unsigned(
            "==",
            b.and_(_sbv_cb, ir.Constant(i8, 3), name="col"),
            ir.Constant(i8, RC_COLOR_BLACK),
            name="is.black"
        ),
        sbv_done,
        sbv_recurse
    );
    b = ir.IRBuilder(sbv_recurse);
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
    b.branch(sb_trace);
    b = ir.IRBuilder(sb_incr);
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
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    cw_vis_fn = ir.Function(
        self.llvm_module, phase_fnty, name="__rc_collect_white_visitor"
    );
    cw_vis_fn.linkage = "internal";
    cw_vis_fn.args[0].name = "child";
    cwv_null = cw_vis_fn.append_basic_block("null");
    cwv_work = cw_vis_fn.append_basic_block("work");
    cwv_color = cw_vis_fn.append_basic_block("color");
    cwv_white = cw_vis_fn.append_basic_block("white");
    cwv_live = cw_vis_fn.append_basic_block("live");
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
    _cwv_rp = b.bitcast(
        b.gep(cw_vis_fn.args[0], [ir.Constant(i64, HDR_RC_OFF)], name="rslot"),
        i64_ptr,
        name="rptr"
    );
    _cwv_rc = b.load(_cwv_rp, name="rc");
    b.cbranch(
        b.icmp_unsigned("==", _cwv_rc, ir.Constant(i64, RC_SENTINEL), name="sent"),
        cwv_done,
        cwv_color
    );
    b = ir.IRBuilder(cwv_color);
    (_cwv_csp, _cwv_cb) = self._emit_rc_color_load(b, cw_vis_fn.args[0]);
    b.cbranch(
        b.icmp_unsigned(
            "==",
            b.and_(_cwv_cb, ir.Constant(i8, 3), name="col"),
            ir.Constant(i8, RC_COLOR_WHITE),
            name="is.white"
        ),
        cwv_white,
        cwv_live
    );
    b = ir.IRBuilder(cwv_white);
    b.call(cw_fn, [cw_vis_fn.args[0]]);
    b.branch(cwv_done);
    b = ir.IRBuilder(cwv_live);
    b.store(b.add(_cwv_rc, ir.Constant(i64, 1), name="nrc"), _cwv_rp);
    b.branch(cwv_done);
    b = ir.IRBuilder(cwv_done);
    b.ret_void();

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

    _cw_zero = b.icmp_unsigned(
        "==", dtor_val, ir.Constant(i64, 0), name="cw.dtor.zero"
    );
    _cw_len = b.icmp_unsigned(
        "!=",
        b.and_(dtor_val, ir.Constant(i64, STR_LEN_TAG_BIT), name="cw.dtor.lowbit"),
        ir.Constant(i64, 0),
        name="cw.dtor.is.len"
    );
    b.cbranch(b.or_(_cw_zero, _cw_len, name="cw.dtor.skip"), raw_free_bb, call_dtor_bb);

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
    assert collect_fn is not None , "the cycle collector is emitted before its blocks are built";

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
    work = collect_fn.append_basic_block(f"{prefix}work");
    incr = collect_fn.append_basic_block(f"{prefix}incr");
    b.cbranch(
        b.icmp_unsigned("==", optr, ir.Constant(i8_ptr, None), name=f"{prefix}null"),
        incr,
        work
    );
    b = ir.IRBuilder(work);
    if clear_purple {
        (csp, cb) = self._emit_rc_color_load(b, optr);
        self._emit_rc_clear_buffered(b, csp);
    }
    b.call(phase_fn, [optr]);
    b.branch(incr);
    b = ir.IRBuilder(incr);
    nxt = b.add(idx, ir.Constant(i64, 1), name=f"{prefix}next");
    idx.add_incoming(nxt, incr);
    b.branch(hdr);

    return pre;
}

impl NaIRGenPass._emit_rc_collect_loop(
    mark_gray_fn: ir.Function, scan_fn: ir.Function, collect_white_fn: ir.Function
) -> None {
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);

    collect_fn = self.rc_collect_cycles_fn;
    assert collect_fn is not None , "the cycle collector is emitted before its blocks are built";

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

impl NaIRGenPass._emit_rc_trace_registry -> None {
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();

    reg_gvs: list[ir.GlobalVariable] = [];
    for (gname, gty, ginit) in [
        ("__rc_treg_keys", i64_ptr, ir.Constant(i64_ptr, None)),
        ("__rc_treg_vals", i64_ptr, ir.Constant(i64_ptr, None)),
        ("__rc_treg_cap", i64, ir.Constant(i64, 0)),
        ("__rc_treg_count", i64, ir.Constant(i64, 0))
    ] {
        gv = ir.GlobalVariable(self.llvm_module, gty, name=gname);
        gv.linkage = "weak";
        gv.initializer = ginit;
        reg_gvs.append(gv);
    }
    keys_gv = reg_gvs[0];
    vals_gv = reg_gvs[1];
    cap_gv = reg_gvs[2];
    count_gv = reg_gvs[3];
    calloc_fn = self._get_or_declare_extern("calloc", i8_ptr, [i64, i64]);
    free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8_ptr]);

    put_fn = ir.Function(
        self.llvm_module,
        ir.FunctionType(ir.VoidType(), [i64_ptr, i64_ptr, i64, i64, i64]),
        name="__rc_treg_put"
    );
    put_fn.linkage = "internal";
    (p_keys, p_vals, p_mask, p_key, p_val) = put_fn.args;
    p_entry = put_fn.append_basic_block("entry");
    p_loop = put_fn.append_basic_block("loop");
    p_store = put_fn.append_basic_block("store");
    p_next = put_fn.append_basic_block("next");
    b = ir.IRBuilder(p_entry);
    _start = b.and_(
        b.xor(
            b.lshr(p_key, ir.Constant(i64, 4), name="h.a"),
            b.lshr(p_key, ir.Constant(i64, 17), name="h.b"),
            name="h"
        ),
        p_mask,
        name="h.idx"
    );
    b.branch(p_loop);
    b = ir.IRBuilder(p_loop);
    _i = b.phi(i64, name="i");
    _i.add_incoming(_start, p_entry);
    _kp = b.gep(p_keys, [_i], name="kp");
    _k = b.load(_kp, name="k");
    b.cbranch(
        b.or_(
            b.icmp_unsigned("==", _k, ir.Constant(i64, 0), name="empty"),
            b.icmp_unsigned("==", _k, p_key, name="same"),
            name="free"
        ),
        p_store,
        p_next
    );
    b = ir.IRBuilder(p_next);
    _i.add_incoming(
        b.and_(b.add(_i, ir.Constant(i64, 1)), p_mask, name="i.next"), p_next
    );
    b.branch(p_loop);
    b = ir.IRBuilder(p_store);
    b.store(p_key, _kp);
    b.store(p_val, b.gep(p_vals, [_i], name="vp"));
    b.ret_void();

    ins_fn = ir.Function(
        self.llvm_module,
        ir.FunctionType(ir.VoidType(), [i64, i64]),
        name="__rc_treg_insert"
    );
    ins_fn.linkage = "internal";
    (i_key, i_val) = ins_fn.args;
    i_entry = ins_fn.append_basic_block("entry");
    i_grow = ins_fn.append_basic_block("grow");
    i_move = ins_fn.append_basic_block("move");
    i_move_one = ins_fn.append_basic_block("move.one");
    i_move_next = ins_fn.append_basic_block("move.next");
    i_moved = ins_fn.append_basic_block("moved");
    i_put = ins_fn.append_basic_block("put");
    b = ir.IRBuilder(i_entry);
    _cap = b.load(cap_gv, name="cap");
    _cnt = b.load(count_gv, name="cnt");
    b.cbranch(
        b.icmp_unsigned(
            ">=",
            b.mul(b.add(_cnt, ir.Constant(i64, 1)), ir.Constant(i64, 2)),
            _cap,
            name="full"
        ),
        i_grow,
        i_put
    );
    b = ir.IRBuilder(i_grow);
    _ncap = b.select(
        b.icmp_unsigned("==", _cap, ir.Constant(i64, 0), name="none"),
        ir.Constant(i64, 1024),
        b.shl(_cap, ir.Constant(i64, 1)),
        name="ncap"
    );
    _nkeys = b.bitcast(
        b.call(calloc_fn, [_ncap, ir.Constant(i64, 8)]), i64_ptr, name="nkeys"
    );
    _nvals = b.bitcast(
        b.call(calloc_fn, [_ncap, ir.Constant(i64, 8)]), i64_ptr, name="nvals"
    );
    _nmask = b.sub(_ncap, ir.Constant(i64, 1), name="nmask");
    _okeys = b.load(keys_gv, name="okeys");
    _ovals = b.load(vals_gv, name="ovals");
    b.branch(i_move);
    b = ir.IRBuilder(i_move);
    _j = b.phi(i64, name="j");
    _j.add_incoming(ir.Constant(i64, 0), i_grow);
    b.cbranch(b.icmp_unsigned("<", _j, _cap, name="more"), i_move_one, i_moved);
    b = ir.IRBuilder(i_move_one);
    _ok = b.load(b.gep(_okeys, [_j]), name="ok");
    _ov = b.load(b.gep(_ovals, [_j]), name="ov");
    _put_bb = ins_fn.append_basic_block("move.put");
    b.cbranch(b.icmp_unsigned("==", _ok, ir.Constant(i64, 0)), i_move_next, _put_bb);
    b = ir.IRBuilder(_put_bb);
    b.call(put_fn, [_nkeys, _nvals, _nmask, _ok, _ov]);
    b.branch(i_move_next);
    b = ir.IRBuilder(i_move_next);
    _j.add_incoming(b.add(_j, ir.Constant(i64, 1), name="j.next"), i_move_next);
    b.branch(i_move);
    b = ir.IRBuilder(i_moved);
    b.call(free_fn, [b.bitcast(_okeys, i8_ptr)]);
    b.call(free_fn, [b.bitcast(_ovals, i8_ptr)]);
    b.store(_nkeys, keys_gv);
    b.store(_nvals, vals_gv);
    b.store(_ncap, cap_gv);
    b.branch(i_put);
    b = ir.IRBuilder(i_put);
    b.call(
        put_fn,
        [
            b.load(keys_gv, name="keys"),
            b.load(vals_gv, name="vals"),
            b.sub(b.load(cap_gv, name="cap2"), ir.Constant(i64, 1), name="mask"),
            i_key,
            i_val
        ]
    );
    b.store(b.add(b.load(count_gv, name="cnt2"), ir.Constant(i64, 1)), count_gv);
    b.ret_void();

    find_fn = ir.Function(
        self.llvm_module, ir.FunctionType(i64, [i64]), name="__rc_treg_find"
    );
    find_fn.linkage = "internal";
    f_key = find_fn.args[0];
    f_entry = find_fn.append_basic_block("entry");
    f_loop = find_fn.append_basic_block("loop");
    f_hit = find_fn.append_basic_block("hit");
    f_check = find_fn.append_basic_block("check");
    f_next = find_fn.append_basic_block("next");
    f_miss = find_fn.append_basic_block("miss");
    f_probe = find_fn.append_basic_block("probe");
    b = ir.IRBuilder(f_entry);
    _fcap = b.load(cap_gv, name="cap");
    b.cbranch(b.icmp_unsigned("==", _fcap, ir.Constant(i64, 0)), f_miss, f_probe);
    b = ir.IRBuilder(f_probe);
    _fmask = b.sub(_fcap, ir.Constant(i64, 1), name="mask");
    _fkeys = b.load(keys_gv, name="keys");
    _fstart = b.and_(
        b.xor(
            b.lshr(f_key, ir.Constant(i64, 4), name="h.a"),
            b.lshr(f_key, ir.Constant(i64, 17), name="h.b"),
            name="h"
        ),
        _fmask,
        name="h.idx"
    );
    b.branch(f_loop);
    b = ir.IRBuilder(f_loop);
    _fi = b.phi(i64, name="i");
    _fi.add_incoming(_fstart, f_probe);
    _fk = b.load(b.gep(_fkeys, [_fi]), name="k");
    b.cbranch(b.icmp_unsigned("==", _fk, f_key), f_hit, f_check);
    b = ir.IRBuilder(f_check);
    b.cbranch(b.icmp_unsigned("==", _fk, ir.Constant(i64, 0)), f_miss, f_next);
    b = ir.IRBuilder(f_next);
    _fi.add_incoming(b.and_(b.add(_fi, ir.Constant(i64, 1)), _fmask), f_next);
    b.branch(f_loop);
    b = ir.IRBuilder(f_hit);
    b.ret(b.load(b.gep(b.load(vals_gv), [_fi]), name="v"));
    b = ir.IRBuilder(f_miss);
    b.ret(ir.Constant(i64, 0));
    self.rc_treg_find_fn = find_fn;
}

impl NaIRGenPass._rc_treg_register -> ir.Function {
    if self.rc_treg_register_fn is None {
        fn = ir.Function(
            self.llvm_module,
            ir.FunctionType(ir.VoidType(), []),
            name="__rc_treg_register"
        );
        fn.linkage = "internal";
        self.rc_treg_register_fn = fn;
        if self.rc_treg_final {
            self._fill_rc_treg_register();
        }
    }
    return self.rc_treg_register_fn;
}

impl NaIRGenPass._fill_rc_treg_register -> None {
    fn = self.rc_treg_register_fn;
    if fn is None or fn.blocks {
        return;
    }
    i64 = ir.IntType(64);
    b = ir.IRBuilder(fn.append_basic_block("entry"));
    if self.rc_trace_pairs {
        if self.rc_treg_find_fn is None {
            self._emit_rc_trace_registry();
        }
        _ins = self.llvm_module.globals.get("__rc_treg_insert");
        for (_key, _pair) in self.rc_trace_pairs.items() {
            (_dtor_fn, _trace_fn) = _pair;
            b.call(
                _ins,
                [
                    b.ptrtoint(_dtor_fn, i64, name=f"rd.{_key}"),
                    b.ptrtoint(_trace_fn, i64, name=f"rt.{_key}")
                ]
            );
        }
    }
    b.ret_void();
}
