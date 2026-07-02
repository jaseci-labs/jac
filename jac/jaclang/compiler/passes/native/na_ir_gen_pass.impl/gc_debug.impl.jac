import from jaclang.compiler.passes.native.llvm { ir }
import os;

impl NaIRGenPass._emit_rc_debug_globals -> None {
    i8 = ir.IntType(8);
    i8_ptr = i8.as_pointer();
    i32 = ir.IntType(32);

    rc_debug_gv = ir.GlobalVariable(self.llvm_module, i8, name="__rc_debug");
    rc_debug_gv.linkage = "weak";
    rc_debug_gv.initializer = ir.Constant(i8, 0);
    self.rc_debug_gv = rc_debug_gv;

    en_fnty = ir.FunctionType(ir.VoidType(), []);
    en_fn = self._define_function("__rc_debug_enable", en_fnty);
    en_fn.linkage = "weak_odr";
    en_bb = en_fn.append_basic_block("entry");
    _b_en = ir.IRBuilder(en_bb);
    _b_en.store(ir.Constant(i8, 1), rc_debug_gv);
    _fmt_on = self._get_fmt_string("--- debug ON ---");
    _fmt_on_ptr = _b_en.gep(
        _fmt_on, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="en.fmt"
    );
    _b_en.call(self._get_printf(), [_fmt_on_ptr]);
    _b_en.ret_void();

    dis_fn = self._define_function("__rc_debug_disable", en_fnty);
    dis_fn.linkage = "weak_odr";
    dis_bb = dis_fn.append_basic_block("entry");
    _b_dis = ir.IRBuilder(dis_bb);
    _b_dis.store(ir.Constant(i8, 0), rc_debug_gv);
    _fmt_off = self._get_fmt_string("--- debug OFF ---");
    _fmt_off_ptr = _b_dis.gep(
        _fmt_off, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="dis.fmt"
    );
    _b_dis.call(self._get_printf(), [_fmt_off_ptr]);
    _b_dis.ret_void();

    ctx_op_gv = ir.GlobalVariable(self.llvm_module, i8_ptr, name="__rc_ctx_op");
    ctx_op_gv.linkage = "weak";
    ctx_op_gv.initializer = ir.Constant(i8_ptr, None);
    self.rc_ctx_op_gv = ctx_op_gv;

    ctx_loc_gv = ir.GlobalVariable(self.llvm_module, i8_ptr, name="__rc_ctx_loc");
    ctx_loc_gv.linkage = "weak";
    ctx_loc_gv.initializer = ir.Constant(i8_ptr, None);
    self.rc_ctx_loc_gv = ctx_loc_gv;

    live_head_gv = ir.GlobalVariable(self.llvm_module, i8_ptr, name="__rc_live_head");
    live_head_gv.linkage = "weak";
    live_head_gv.initializer = ir.Constant(i8_ptr, None);
    self.rc_live_head_gv = live_head_gv;
}

impl NaIRGenPass._emit_ctx_load(b: ir.IRBuilder) -> tuple {
    i8_ptr = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    _op_raw = b.load(self.rc_ctx_op_gv, name="ctx.op.raw");
    _loc_raw = b.load(self.rc_ctx_loc_gv, name="ctx.loc.raw");
    _empty_gv = self._get_snprintf_fmt("");
    _empty_gep = b.gep(
        _empty_gv, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ctx.empty"
    );
    _op_null = b.icmp_unsigned(
        "==", _op_raw, ir.Constant(i8_ptr, None), name="ctx.op.null"
    );
    _loc_null = b.icmp_unsigned(
        "==", _loc_raw, ir.Constant(i8_ptr, None), name="ctx.loc.null"
    );
    _op = b.select(_op_null, _empty_gep, _op_raw, name="ctx.op");
    _loc = b.select(_loc_null, _empty_gep, _loc_raw, name="ctx.loc");
    return (_op, _loc);
}

impl NaIRGenPass._emit_live_node_insert(
    b: ir.IRBuilder, aid: ir.Value, user: ir.Value, tag_raw: ir.Value
) -> None {
    if not self._rc_debug_codegen {
        return;
    }
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    _node_size = ir.Constant(i64, LIVE_NODE_SIZE);
    _node_raw = b.call(self.malloc_fn, [_node_size], name="live.node");
    _nid_slot = b.bitcast(_node_raw, i64_ptr, name="n.id.slot");
    b.store(aid, _nid_slot);
    _nptr_slot = b.gep(
        _node_raw, [ir.Constant(i64, LIVE_NODE_USER_OFF)], name="n.ptr.slot"
    );
    _nptr_slot_pp = b.bitcast(_nptr_slot, i8_ptr.as_pointer(), name="n.ptr.pp");
    b.store(user, _nptr_slot_pp);
    _ntag_slot = b.gep(
        _node_raw, [ir.Constant(i64, LIVE_NODE_TAG_OFF)], name="n.tag.slot"
    );
    _ntag_slot_pp = b.bitcast(_ntag_slot, i8_ptr.as_pointer(), name="n.tag.pp");
    b.store(tag_raw, _ntag_slot_pp);

    _nrc_slot = b.gep(
        _node_raw, [ir.Constant(i64, LIVE_NODE_RC_OFF)], name="n.rc.slot"
    );
    _nrc_slot_i64 = b.bitcast(_nrc_slot, i64_ptr, name="n.rc.i64");
    b.store(ir.Constant(i64, 1), _nrc_slot_i64);
    _nnxt_slot = b.gep(
        _node_raw, [ir.Constant(i64, LIVE_NODE_NEXT_OFF)], name="n.next.slot"
    );
    _nnxt_slot_pp = b.bitcast(_nnxt_slot, i8_ptr.as_pointer(), name="n.next.pp");
    _old_head = b.load(self.rc_live_head_gv, name="old.head");
    b.store(_old_head, _nnxt_slot_pp);
    b.store(_node_raw, self.rc_live_head_gv);
}

impl NaIRGenPass._emit_alloc_log_bb(
    func: ir.Function,
    ret_bb: ir.Block,
    aid: ir.Value,
    user: ir.Value,
    size_arg: ir.Value,
    tag_raw: ir.Value
) -> ir.Block {
    i32 = ir.IntType(32);
    log_bb = func.append_basic_block("log_alloc");
    b = ir.IRBuilder(log_bb);
    (_op, _loc) = self._emit_ctx_load(b);
    _fmt = self._get_fmt_string(
        "RC MALLOC  id=%-4lld ptr=%p  bytes=%lld  type=%-12s  op=%-12s  at=%s"
    );
    _fmt_ptr = b.gep(
        _fmt, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="alloc.fmt"
    );
    b.call(self._get_printf(), [_fmt_ptr, aid, user, size_arg, tag_raw, _op, _loc]);
    b.branch(ret_bb);
    return log_bb;
}

impl NaIRGenPass._emit_retain_log_bb(
    func: ir.Function,
    done_bb: ir.Block,
    ptr: ir.Value,
    old_rc: ir.Value,
    new_rc: ir.Value
) -> ir.Block {
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    i32 = ir.IntType(32);
    log_bb = func.append_basic_block("log_retain");
    b = ir.IRBuilder(log_bb);

    _aid_slot = b.gep(ptr, [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name="ret.aid.slot");
    _aid_ptr = b.bitcast(_aid_slot, i64_ptr, name="ret.aid.ptr");
    _aid_raw = b.load(_aid_ptr, name="ret.aid.raw");
    _aid = b.and_(_aid_raw, ir.Constant(i64, 4294967295), name="ret.aid");

    _tag_slot = b.gep(ptr, [ir.Constant(i64, HDR_TAG_OFF)], name="ret.tag.slot");
    _tag_ptr = b.bitcast(_tag_slot, i8_ptr.as_pointer(), name="ret.tag.ptr");
    _tag = b.load(_tag_ptr, name="ret.tag");

    (_op, _loc) = self._emit_ctx_load(b);
    _fmt = self._get_fmt_string(
        "RC RETAIN  id=%-4lld ptr=%p  rc=%lld->%lld  type=%-12s  op=%-12s  at=%s"
    );
    _fmt_ptr = b.gep(_fmt, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ret.fmt");
    b.call(self._get_printf(), [_fmt_ptr, _aid, ptr, old_rc, new_rc, _tag, _op, _loc]);

    _ur_scan_bb = func.append_basic_block("ur.scan");
    _ur_check_bb = func.append_basic_block("ur.check");
    _ur_body_bb = func.append_basic_block("ur.body");
    _ur_next_bb = func.append_basic_block("ur.next");
    _ur_upd_bb = func.append_basic_block("ur.upd");
    b.branch(_ur_scan_bb);
    b = ir.IRBuilder(_ur_scan_bb);
    _ur_head = b.load(self.rc_live_head_gv, name="ur.head");
    b.branch(_ur_check_bb);
    b = ir.IRBuilder(_ur_check_bb);
    _ur_cur = b.phi(i8_ptr, name="ur.cur");
    _ur_cur.add_incoming(_ur_head, _ur_scan_bb);
    _ur_end = b.icmp_unsigned("==", _ur_cur, ir.Constant(i8_ptr, None), name="ur.end");
    b.cbranch(_ur_end, done_bb, _ur_body_bb);
    b = ir.IRBuilder(_ur_body_bb);
    _ur_nptr_off = b.gep(
        _ur_cur, [ir.Constant(i64, LIVE_NODE_USER_OFF)], name="ur.nptr.off"
    );
    _ur_nptr_pp = b.bitcast(_ur_nptr_off, i8_ptr.as_pointer(), name="ur.nptr.pp");
    _ur_node_ptr = b.load(_ur_nptr_pp, name="ur.node.ptr");
    _ur_eq = b.icmp_unsigned("==", _ur_node_ptr, ptr, name="ur.eq");
    b.cbranch(_ur_eq, _ur_upd_bb, _ur_next_bb);
    b = ir.IRBuilder(_ur_upd_bb);
    _ur_rc_off = b.gep(_ur_cur, [ir.Constant(i64, LIVE_NODE_RC_OFF)], name="ur.rc.off");
    _ur_rc_pp = b.bitcast(_ur_rc_off, i64_ptr, name="ur.rc.pp");
    b.store(new_rc, _ur_rc_pp);
    b.branch(done_bb);
    b = ir.IRBuilder(_ur_next_bb);
    _ur_nxt_off = b.gep(
        _ur_cur, [ir.Constant(i64, LIVE_NODE_NEXT_OFF)], name="ur.nxt.off"
    );
    _ur_nxt_pp = b.bitcast(_ur_nxt_off, i8_ptr.as_pointer(), name="ur.nxt.pp");
    _ur_nxt = b.load(_ur_nxt_pp, name="ur.nxt");
    _ur_cur.add_incoming(_ur_nxt, _ur_next_bb);
    b.branch(_ur_check_bb);
    return log_bb;
}

impl NaIRGenPass._emit_dbl_free_log_bb(
    func: ir.Function, done_bb: ir.Block, ptr: ir.Value
) -> ir.Block {
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    i32 = ir.IntType(32);
    log_bb = func.append_basic_block("log_dbl_free");
    b = ir.IRBuilder(log_bb);
    _aid_slot = b.gep(ptr, [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name="dbl.aid.slot");
    _aid_ptr = b.bitcast(_aid_slot, i64_ptr, name="dbl.aid.ptr");
    _aid_raw = b.load(_aid_ptr, name="dbl.aid.raw");
    _aid = b.and_(_aid_raw, ir.Constant(i64, 4294967295), name="dbl.aid");
    _tag_slot = b.gep(ptr, [ir.Constant(i64, HDR_TAG_OFF)], name="dbl.tag.slot");
    _tag_ptr = b.bitcast(_tag_slot, i8_ptr.as_pointer(), name="dbl.tag.ptr");
    _tag = b.load(_tag_ptr, name="dbl.tag");
    (_op, _loc) = self._emit_ctx_load(b);
    _fmt = self._get_fmt_string(
        "RC DOUBLE-FREE id=%-4lld ptr=%p  type=%-12s  rc=0 !!!  op=%-12s  at=%s"
    );
    _fmt_ptr = b.gep(_fmt, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="df.fmt");
    b.call(self._get_printf(), [_fmt_ptr, _aid, ptr, _tag, _op, _loc]);
    b.branch(done_bb);
    return log_bb;
}

impl NaIRGenPass._emit_release_log_bb(
    func: ir.Function,
    done_bb: ir.Block,
    ptr: ir.Value,
    old_rc: ir.Value,
    new_rc: ir.Value
) -> ir.Block {
    i8_ptr = ir.IntType(8).as_pointer();
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    i32 = ir.IntType(32);
    dbg_rel_bb = func.append_basic_block("dbg_rel_check");
    log_rel_bb = func.append_basic_block("log_release");
    b = ir.IRBuilder(dbg_rel_bb);
    dbg_flag2 = b.load(self.rc_debug_gv, name="rc.dbg2");
    b.cbranch(
        b.icmp_unsigned("!=", dbg_flag2, ir.Constant(i8, 0), name="dbg.on2"),
        log_rel_bb,
        done_bb
    );
    b = ir.IRBuilder(log_rel_bb);
    _aid_slot = b.gep(ptr, [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name="rel.aid.slot");
    _aid_ptr = b.bitcast(_aid_slot, i64_ptr, name="rel.aid.ptr");
    _aid_raw = b.load(_aid_ptr, name="rel.aid.raw");
    _aid = b.and_(_aid_raw, ir.Constant(i64, 4294967295), name="rel.aid");
    _tag_slot = b.gep(ptr, [ir.Constant(i64, HDR_TAG_OFF)], name="rel.tag.slot");
    _tag_ptr = b.bitcast(_tag_slot, i8_ptr.as_pointer(), name="rel.tag.ptr");
    _tag = b.load(_tag_ptr, name="rel.tag");
    (_op, _loc) = self._emit_ctx_load(b);
    _fmt = self._get_fmt_string(
        "RC RELEASE id=%-4lld ptr=%p  rc=%lld->%lld  type=%-12s  op=%-12s  at=%s"
    );
    _fmt_ptr = b.gep(_fmt, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="rel.fmt");
    b.call(self._get_printf(), [_fmt_ptr, _aid, ptr, old_rc, new_rc, _tag, _op, _loc]);
    b.branch(done_bb);
    return dbg_rel_bb;
}

impl NaIRGenPass._emit_raw_free_bbs(
    func: ir.Function, done_bb: ir.Block, ptr: ir.Value
) -> ir.Block {
    i8_ptr = ir.IntType(8).as_pointer();
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    i32 = ir.IntType(32);
    log_free_bb = func.append_basic_block("log_free_raw");
    log_raw_bb = func.append_basic_block("log_raw");
    live_rm_bb = func.append_basic_block("live_rm");
    actual_free_bb = func.append_basic_block("actual_free");

    b = ir.IRBuilder(log_free_bb);
    dbg_flag3 = b.load(self.rc_debug_gv, name="rc.dbg3");
    b.cbranch(
        b.icmp_unsigned("!=", dbg_flag3, ir.Constant(i8, 0), name="dbg.on3"),
        log_raw_bb,
        live_rm_bb
    );

    b = ir.IRBuilder(log_raw_bb);

    _triple = str(self.llvm_module.triple or "").lower();
    _raw_msz = b.gep(ptr, [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name="raw.msz");
    if "wasm" in _triple {
        _msz = ir.Constant(i64, 0);
    } else {
        _is_darwin = ("darwin" in _triple)
        or ("apple" in _triple)
        or ("macos" in _triple)
        or ("ios" in _triple);
        _msz_sym = "malloc_size" if _is_darwin else "malloc_usable_size";
        _msz_fn = self._get_or_declare_extern(_msz_sym, i64, [i8_ptr]);
        _msz = b.call(_msz_fn, [_raw_msz], name="msz");
    }
    _aid_slot = b.gep(ptr, [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name="fr.aid.slot");
    _aid_ptr = b.bitcast(_aid_slot, i64_ptr, name="fr.aid.ptr");
    _aid_raw = b.load(_aid_ptr, name="fr.aid.raw");
    _aid = b.and_(_aid_raw, ir.Constant(i64, 4294967295), name="fr.aid");
    _tag_slot = b.gep(ptr, [ir.Constant(i64, HDR_TAG_OFF)], name="fr.tag.slot");
    _tag_ptr = b.bitcast(_tag_slot, i8_ptr.as_pointer(), name="fr.tag.ptr");
    _tag = b.load(_tag_ptr, name="fr.tag");
    (_op, _loc) = self._emit_ctx_load(b);
    _fmt = self._get_fmt_string(
        "RC FREE    id=%-4lld ptr=%p  bytes=%lld  type=%-12s  op=%-12s  at=%s"
    );
    _fmt_ptr = b.gep(_fmt, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="free.fmt");
    b.call(self._get_printf(), [_fmt_ptr, _aid, ptr, _msz, _tag, _op, _loc]);
    b.branch(live_rm_bb);

    b = ir.IRBuilder(live_rm_bb);
    self._emit_live_list_remove(b, ptr, i8_ptr, i64_ptr, done_bb, actual_free_bb);

    b = ir.IRBuilder(actual_free_bb);
    _raw_for_free = b.gep(
        ptr, [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name="raw.for.free"
    );
    b.call(self.rc_safe_free_fn, [_raw_for_free]);
    b.branch(done_bb);
    return log_free_bb;
}

impl NaIRGenPass._emit_struct_free_log(
    func: ir.Function,
    log_free_struct_bb: ir.Block,
    actual_free_struct_bb: ir.Block,
    obj_i8: ir.Value,
    obj_raw: ir.Value,
    aid: ir.Value,
    tag: ir.Value
) -> None {
    i8 = ir.IntType(8);
    i8_ptr = i8.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    log_struct_line_bb = func.append_basic_block("log_struct_line");

    b = ir.IRBuilder(log_free_struct_bb);
    dbg_flag_s = b.load(self.rc_debug_gv, name="rc.dbg.s");
    b.cbranch(
        b.icmp_unsigned("!=", dbg_flag_s, ir.Constant(i8, 0), name="dbg.on.s"),
        log_struct_line_bb,
        actual_free_struct_bb
    );

    b = ir.IRBuilder(log_struct_line_bb);

    _triple = str(self.llvm_module.triple or "").lower();
    if "wasm" in _triple {
        _msz2 = ir.Constant(i64, 0);
    } else {
        _is_darwin = ("darwin" in _triple)
        or ("apple" in _triple)
        or ("macos" in _triple)
        or ("ios" in _triple);
        _msz_sym = "malloc_size" if _is_darwin else "malloc_usable_size";
        _msz_fn = self._get_or_declare_extern(_msz_sym, i64, [i8_ptr]);
        _msz2 = b.call(_msz_fn, [obj_raw], name="msz2");
    }
    (_op, _loc) = self._emit_ctx_load(b);
    _fmt_sf = self._get_fmt_string(
        "RC FREE    id=%-4lld ptr=%p  bytes=%lld  type=%-12s  op=%-12s  at=%s"
    );
    _fmt_sf_ptr = b.gep(
        _fmt_sf, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="sf.fmt"
    );
    b.call(self._get_printf(), [_fmt_sf_ptr, aid, obj_i8, _msz2, tag, _op, _loc]);
    b.branch(actual_free_struct_bb);
}

impl NaIRGenPass._set_rc_ctx(op: str, loc: str) -> None {
    if self.rc_ctx_op_gv is None {
        self._emit_rc_helpers();
    }
    _i32c = ir.IntType(32);
    if op and self.rc_ctx_op_gv is not None {
        _op_gv = self._get_snprintf_fmt(op);
        _op_gep = self.builder.gep(
            _op_gv, [ir.Constant(_i32c, 0), ir.Constant(_i32c, 0)], name="sctx.op.gep"
        );
        self.builder.store(_op_gep, self.rc_ctx_op_gv);
    }
    if loc and self.rc_ctx_loc_gv is not None {
        _loc_gv = self._get_snprintf_fmt(loc);
        _loc_gep = self.builder.gep(
            _loc_gv, [ir.Constant(_i32c, 0), ir.Constant(_i32c, 0)], name="sctx.loc.gep"
        );
        self.builder.store(_loc_gep, self.rc_ctx_loc_gv);
    }
}

impl NaIRGenPass._clear_rc_ctx -> None {
    if self.rc_ctx_op_gv is None {
        return;
    }
    i8_ptr = ir.IntType(8).as_pointer();
    self.builder.store(ir.Constant(i8_ptr, None), self.rc_ctx_op_gv);
    self.builder.store(ir.Constant(i8_ptr, None), self.rc_ctx_loc_gv);
}

impl NaIRGenPass._emit_live_list_remove(
    b: ir.IRBuilder,
    target_ptr: ir.Value,
    i8_ptr: ir.Type,
    i64_ptr: ir.Type,
    done_bb: ir.Block,
    free_bb: ir.Block
) -> None {
    if not self._rc_debug_codegen {
        b.branch(free_bb);
        return;
    }
    func = b.function;
    scan_bb = func.append_basic_block("live.scan");
    check_bb = func.append_basic_block("live.check");
    match_bb = func.append_basic_block("live.match");
    unlink_bb = func.append_basic_block("live.unlink");
    next_bb = func.append_basic_block("live.next");
    b.branch(scan_bb);
    b2 = ir.IRBuilder(scan_bb);
    head = b2.load(self.rc_live_head_gv, name="lrm.head");
    b2.branch(check_bb);
    b2 = ir.IRBuilder(check_bb);

    cur_phi = b2.phi(i8_ptr, name="lrm.cur");
    prev_phi = b2.phi(i8_ptr, name="lrm.prev");
    cur_phi.add_incoming(head, scan_bb);
    prev_phi.add_incoming(ir.Constant(i8_ptr, None), scan_bb);
    is_end = b2.icmp_unsigned("==", cur_phi, ir.Constant(i8_ptr, None), name="lrm.end");
    b2.cbranch(is_end, free_bb, match_bb);
    b2 = ir.IRBuilder(match_bb);
    nptr_off = b2.gep(
        cur_phi, [ir.Constant(ir.IntType(64), LIVE_NODE_USER_OFF)], name="nptr.off"
    );
    nptr_pp = b2.bitcast(nptr_off, i8_ptr.as_pointer(), name="nptr.pp");
    node_ptr = b2.load(nptr_pp, name="node.ptr");
    is_match = b2.icmp_unsigned("==", node_ptr, target_ptr, name="lrm.eq");
    b2.cbranch(is_match, unlink_bb, next_bb);
    b2 = ir.IRBuilder(unlink_bb);

    nnxt_off = b2.gep(
        cur_phi, [ir.Constant(ir.IntType(64), LIVE_NODE_NEXT_OFF)], name="nnxt.off"
    );
    nnxt_pp = b2.bitcast(nnxt_off, i8_ptr.as_pointer(), name="nnxt.pp");
    nxt_node = b2.load(nnxt_pp, name="nxt.node");

    prev_null_bb = func.append_basic_block("live.prev.null");
    prev_set_bb = func.append_basic_block("live.prev.set");
    after_unlink = func.append_basic_block("live.after.unlink");
    is_prev_null = b2.icmp_unsigned(
        "==", prev_phi, ir.Constant(i8_ptr, None), name="prev.null"
    );
    b2.cbranch(is_prev_null, prev_null_bb, prev_set_bb);
    b3 = ir.IRBuilder(prev_null_bb);
    b3.store(nxt_node, self.rc_live_head_gv);
    b3.branch(after_unlink);
    b3 = ir.IRBuilder(prev_set_bb);
    prev_nxt_off = b3.gep(
        prev_phi, [ir.Constant(ir.IntType(64), LIVE_NODE_NEXT_OFF)], name="pnxt.off"
    );
    prev_nxt_pp = b3.bitcast(prev_nxt_off, i8_ptr.as_pointer(), name="pnxt.pp");
    b3.store(nxt_node, prev_nxt_pp);
    b3.branch(after_unlink);
    b3 = ir.IRBuilder(after_unlink);
    b3.call(self.rc_safe_free_fn, [cur_phi]);
    b3.branch(free_bb);
    b2 = ir.IRBuilder(next_bb);
    nnxt_off2 = b2.gep(
        cur_phi, [ir.Constant(ir.IntType(64), LIVE_NODE_NEXT_OFF)], name="nnxt2.off"
    );
    nnxt_pp2 = b2.bitcast(nnxt_off2, i8_ptr.as_pointer(), name="nnxt2.pp");
    nxt2 = b2.load(nnxt_pp2, name="nxt2");
    cur_phi.add_incoming(nxt2, next_bb);
    prev_phi.add_incoming(cur_phi, next_bb);
    b2.branch(check_bb);
}

impl NaIRGenPass._emit_rc_live_dump -> None {
    if self.rc_live_head_gv is None or not self._rc_debug_codegen {
        return;
    }
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    i32 = ir.IntType(32);
    i8 = ir.IntType(8);
    b = self.builder;
    func = b.function;

    dbg_on_bb = func.append_basic_block("dump.dbg.on");
    scan_bb = func.append_basic_block("dump.scan");
    check_bb = func.append_basic_block("dump.check");
    body_bb = func.append_basic_block("dump.body");
    next_bb = func.append_basic_block("dump.next");
    after_bb = func.append_basic_block("dump.after");
    dbg_flag = b.load(self.rc_debug_gv, name="dump.dbg");
    b.cbranch(
        b.icmp_unsigned("!=", dbg_flag, ir.Constant(i8, 0), name="dump.on"),
        dbg_on_bb,
        after_bb
    );
    b = ir.IRBuilder(dbg_on_bb);
    _hdr = self._get_fmt_string("--- RC LIVE OBJECTS at exit ---");
    _hdr_ptr = b.gep(_hdr, [ir.Constant(i32, 0), ir.Constant(i32, 0)]);
    b.call(self._get_printf(), [_hdr_ptr]);
    b.branch(scan_bb);
    b = ir.IRBuilder(scan_bb);
    head = b.load(self.rc_live_head_gv, name="dump.head");
    b.branch(check_bb);
    b = ir.IRBuilder(check_bb);
    cur = b.phi(i8_ptr, name="dump.cur");
    cur.add_incoming(head, scan_bb);
    is_end = b.icmp_unsigned("==", cur, ir.Constant(i8_ptr, None), name="dump.end");
    b.cbranch(is_end, after_bb, body_bb);
    b = ir.IRBuilder(body_bb);

    id_ptr = b.bitcast(cur, i64_ptr, name="dump.id.ptr");
    node_id = b.load(id_ptr, name="dump.id");
    uptr_off = b.gep(cur, [ir.Constant(i64, LIVE_NODE_USER_OFF)], name="dump.uptr.off");
    uptr_pp = b.bitcast(uptr_off, i8_ptr.as_pointer(), name="dump.uptr.pp");
    user_ptr = b.load(uptr_pp, name="dump.uptr");

    rc_slot = b.gep(user_ptr, [ir.Constant(i64, HDR_RC_OFF)], name="dump.rc.slot");
    rc_ptr_c = b.bitcast(rc_slot, i64_ptr, name="dump.rc.ptr");
    rc_val = b.load(rc_ptr_c, name="dump.rc");

    ttag_off = b.gep(cur, [ir.Constant(i64, LIVE_NODE_TAG_OFF)], name="dump.ttag.off");
    ttag_pp = b.bitcast(ttag_off, i8_ptr.as_pointer(), name="dump.ttag.pp");
    ttag = b.load(ttag_pp, name="dump.ttag");
    _fmt_live = self._get_fmt_string("id=%-4lld ptr=%p  rc=%-4lld type=%s  <- LEAK");
    _fmt_live_ptr = b.gep(_fmt_live, [ir.Constant(i32, 0), ir.Constant(i32, 0)]);
    b.call(self._get_printf(), [_fmt_live_ptr, node_id, user_ptr, rc_val, ttag]);
    b.branch(next_bb);
    b = ir.IRBuilder(next_bb);
    nxt_off = b.gep(cur, [ir.Constant(i64, LIVE_NODE_NEXT_OFF)], name="dump.nxt.off");
    nxt_pp = b.bitcast(nxt_off, i8_ptr.as_pointer(), name="dump.nxt.pp");
    nxt = b.load(nxt_pp, name="dump.nxt");
    cur.add_incoming(nxt, next_bb);
    b.branch(check_bb);
    b = ir.IRBuilder(after_bb);
    self._builder = b;
}
