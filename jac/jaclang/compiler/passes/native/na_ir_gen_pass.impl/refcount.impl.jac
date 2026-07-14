impl NaIRGenPass._gc_mode -> str {
    _mode = getattr(self.prog._compile_options, "na_gc_mode", "cycles");
    if _mode not in ("cycles", "rc", "none") {
        return "cycles";
    }
    return _mode;
}

impl NaIRGenPass._emit_rc_helpers -> None {
    i8 = ir.IntType(8);
    i8_ptr = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    _cycles_on = self._gc_mode() == "cycles";

    self.malloc_fn = self._get_or_declare_extern("malloc", i8_ptr, [i64]);
    self.free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8_ptr]);

    self._emit_rc_debug_globals();
    if _cycles_on {
        self._emit_rc_roots_globals();
    }

    rc_gc_disabled_gv = ir.GlobalVariable(
        self.llvm_module, i8, name="__rc_gc_disabled"
    );
    rc_gc_disabled_gv.linkage = "weak";
    rc_gc_disabled_gv.initializer = ir.Constant(i8, 0);
    self.rc_gc_disabled_gv = rc_gc_disabled_gv;

    dis_gc_fnty = ir.FunctionType(ir.VoidType(), []);
    dis_gc_fn = self._define_function("__rc_gc_disable", dis_gc_fnty);
    dis_gc_fn.linkage = "internal";
    _bb_dis_gc = dis_gc_fn.append_basic_block("entry");
    _b_dis_gc = ir.IRBuilder(_bb_dis_gc);
    _b_dis_gc.store(ir.Constant(i8, 1), rc_gc_disabled_gv);
    _b_dis_gc.ret_void();
    self.rc_gc_disable_fn = dis_gc_fn;

    en_gc_fn = self._define_function("__rc_gc_enable", dis_gc_fnty);
    en_gc_fn.linkage = "internal";
    _bb_en_gc = en_gc_fn.append_basic_block("entry");
    _b_en_gc = ir.IRBuilder(_bb_en_gc);
    _b_en_gc.store(ir.Constant(i8, 0), rc_gc_disabled_gv);
    _b_en_gc.ret_void();
    self.rc_gc_enable_fn = en_gc_fn;

    if _cycles_on {
        en_cyc_fn = self._define_function("__rc_cycles_enable", dis_gc_fnty);
        en_cyc_fn.linkage = "internal";
        _bb_en_cyc = en_cyc_fn.append_basic_block("entry");
        _b_en_cyc = ir.IRBuilder(_bb_en_cyc);
        _b_en_cyc.store(ir.Constant(i8, 1), self.rc_cycles_enabled_gv);
        _b_en_cyc.ret_void();
        self.rc_cycles_enable_fn = en_cyc_fn;
    }

    sf_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);
    sf_fn = self._define_function("__rc_safe_free", sf_fnty);
    sf_fn.linkage = "internal";
    sf_fn.args[0].name = "ptr";
    _sf_entry = sf_fn.append_basic_block("entry");
    _sf_do = sf_fn.append_basic_block("do_free");
    _sf_done = sf_fn.append_basic_block("done");
    _sf_b = ir.IRBuilder(_sf_entry);
    _sf_flag = _sf_b.load(rc_gc_disabled_gv, name="sf.gc.dis");
    _sf_dis = _sf_b.icmp_unsigned("!=", _sf_flag, ir.Constant(i8, 0), name="sf.dis");
    _sf_b.cbranch(_sf_dis, _sf_done, _sf_do);
    _sf_b = ir.IRBuilder(_sf_do);
    _sf_b.call(self.free_fn, [sf_fn.args[0]]);
    _sf_b.branch(_sf_done);
    _sf_b = ir.IRBuilder(_sf_done);
    _sf_b.ret_void();
    self.rc_safe_free_fn = sf_fn;

    if _cycles_on {
        self._emit_rc_collect_cycles();
    }

    self._get_or_declare_extern("memcpy", i8_ptr, [i8_ptr, i8_ptr, i64]);
    self._get_or_declare_extern("strlen", i64, [i8_ptr]);
    self._get_or_declare_extern("strcmp", i32, [i8_ptr, i8_ptr]);
    self._get_or_declare_extern("strncmp", i32, [i8_ptr, i8_ptr, i64]);
    self._get_or_declare_extern("memcmp", i32, [i8_ptr, i8_ptr, i64]);
    self._get_or_declare_extern("calloc", i8_ptr, [i64, i64]);
    self._get_or_declare_extern("fopen", i8_ptr, [i8_ptr, i8_ptr]);
    self._get_or_declare_extern("fclose", i32, [i8_ptr]);
    self._get_or_declare_extern("fread", i64, [i8_ptr, i64, i64, i8_ptr]);
    self._get_or_declare_extern("fwrite", i64, [i8_ptr, i64, i64, i8_ptr]);
    self._get_or_declare_extern("fgets", i8_ptr, [i8_ptr, i32, i8_ptr]);
    self._get_or_declare_extern("fflush", i32, [i8_ptr]);
    self._get_or_declare_extern("ftell", i64, [i8_ptr]);
    self._get_or_declare_extern("fseek", i32, [i8_ptr, i64, i32]);

    alloc_id_gv = ir.GlobalVariable(
        self.llvm_module, i64, name="__rc_alloc_id_counter"
    );
    alloc_id_gv.linkage = "weak";
    alloc_id_gv.initializer = ir.Constant(i64, 0);
    self.rc_alloc_id_gv = alloc_id_gv;

    _raw_tag_str = self._get_snprintf_fmt("raw");
    _raw_tag_gep = ir.GlobalVariable.__new__(ir.GlobalVariable);
    self._rc_raw_tag_gv = _raw_tag_str;

    alloc_fnty = ir.FunctionType(i8_ptr, [i64]);
    alloc_fn = self._define_function("__rc_alloc", alloc_fnty);
    alloc_fn.linkage = "private";
    alloc_fn.args[0].name = "size";
    entry_bb = alloc_fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb);
    total = b.add(alloc_fn.args[0], ir.Constant(i64, HDR_TOTAL), name="total");
    total = b.add(total, ir.Constant(i64, 15), name="total.pad");
    total = b.and_(total, ir.Constant(i64, -16), name="total.align");
    raw = b.call(self.malloc_fn, [total], name="raw");

    _aid_old = b.atomic_rmw(
        "add", alloc_id_gv, ir.Constant(i64, 1), ordering="monotonic"
    );
    _aid_ptr = b.bitcast(raw, i64_ptr, name="aid.ptr");
    _magic_base = ir.Constant(i64, HDR_MAGIC_SHIFT_BASE);
    _aid_lo32 = b.and_(_aid_old, ir.Constant(i64, 4294967295), name="aid.lo");
    _aid_magic = b.or_(_magic_base, _aid_lo32, name="aid.magic");
    b.store(_aid_magic, _aid_ptr);

    _tag_raw = b.gep(
        _raw_tag_str, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="tag.raw"
    );
    _tag_slot = b.gep(
        raw, [ir.Constant(i64, HDR_TOTAL + HDR_TAG_OFF)], name="tag.slot"
    );
    _tag_slot_ptr = b.bitcast(_tag_slot, i8_ptr.as_pointer(), name="tag.slot.ptr");
    b.store(_tag_raw, _tag_slot_ptr);

    rc_raw = b.gep(raw, [ir.Constant(i64, HDR_TOTAL + HDR_RC_OFF)], name="rc.raw");
    rc_ptr = b.bitcast(rc_raw, i64_ptr, name="rc.ptr");
    b.store(ir.Constant(i64, 1), rc_ptr);

    dtor_raw = b.gep(
        raw, [ir.Constant(i64, HDR_TOTAL + HDR_DTOR_OFF)], name="dtor.raw"
    );
    dtor_ptr_slot = b.bitcast(dtor_raw, i64_ptr, name="dtor.slot");
    b.store(ir.Constant(i64, 0), dtor_ptr_slot);

    user = b.gep(raw, [ir.Constant(i64, HDR_TOTAL)], name="user");

    self._emit_live_node_insert(b, _aid_old, user, _tag_raw);

    ret_bb = alloc_fn.append_basic_block("ret");
    log_alloc_bb = self._emit_alloc_log_bb(
        alloc_fn, ret_bb, _aid_old, user, alloc_fn.args[0], _tag_raw
    );
    dbg_flag_a = b.load(self.rc_debug_gv, name="rc.dbg.a");
    b.cbranch(
        b.icmp_unsigned("!=", dbg_flag_a, ir.Constant(i8, 0), name="dbg.on.a"),
        log_alloc_bb,
        ret_bb
    );
    b = ir.IRBuilder(ret_bb);
    b.ret(user);
    self.rc_alloc_fn = alloc_fn;

    set_type_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr, i8_ptr]);
    set_type_fn = self._define_function("__rc_set_type", set_type_fnty);
    set_type_fn.linkage = "internal";
    set_type_fn.args[0].name = "ptr";
    set_type_fn.args[1].name = "tag";
    _st_bb = set_type_fn.append_basic_block("entry");
    _st_b = ir.IRBuilder(_st_bb);

    _st_null = _st_b.icmp_unsigned(
        "==", set_type_fn.args[0], ir.Constant(i8_ptr, None), name="st.null"
    );
    _st_done_bb = set_type_fn.append_basic_block("done");
    _st_work_bb = set_type_fn.append_basic_block("work");
    _st_b.cbranch(_st_null, _st_done_bb, _st_work_bb);
    _st_b = ir.IRBuilder(_st_work_bb);
    _st_tag_slot = _st_b.gep(
        set_type_fn.args[0], [ir.Constant(i64, HDR_TAG_OFF)], name="tag.slot"
    );
    _st_tag_slot_pp = _st_b.bitcast(
        _st_tag_slot, i8_ptr.as_pointer(), name="tag.slot.pp"
    );
    _st_b.store(set_type_fn.args[1], _st_tag_slot_pp);

    if not self._rc_debug_codegen {
        _st_b.branch(_st_done_bb);
        _st_b = ir.IRBuilder(_st_done_bb);
        _st_b.ret_void();
        self.rc_set_type_fn = set_type_fn;
    }
    if self._rc_debug_codegen {
        _st_scan_bb = set_type_fn.append_basic_block("scan");
        _st_check_bb = set_type_fn.append_basic_block("check");
        _st_match_bb = set_type_fn.append_basic_block("match");
        _st_next_bb = set_type_fn.append_basic_block("next");
        _st_b.branch(_st_scan_bb);
        _st_b = ir.IRBuilder(_st_scan_bb);
        _st_cur = _st_b.load(self.rc_live_head_gv, name="st.cur");
        _st_b.branch(_st_check_bb);
        _st_b = ir.IRBuilder(_st_check_bb);
        _st_cur_phi = _st_b.phi(i8_ptr, name="cur");
        _st_cur_phi.add_incoming(_st_cur, _st_scan_bb);
        _st_is_end = _st_b.icmp_unsigned(
            "==", _st_cur_phi, ir.Constant(i8_ptr, None), name="end"
        );
        _st_b.cbranch(_st_is_end, _st_done_bb, _st_match_bb);
        _st_b = ir.IRBuilder(_st_match_bb);
        _st_nptr_slot = _st_b.gep(
            _st_cur_phi, [ir.Constant(i64, LIVE_NODE_USER_OFF)], name="nptr.slot"
        );
        _st_nptr_pp = _st_b.bitcast(_st_nptr_slot, i8_ptr.as_pointer(), name="nptr.pp");
        _st_node_ptr = _st_b.load(_st_nptr_pp, name="node.ptr");
        _st_eq = _st_b.icmp_unsigned(
            "==", _st_node_ptr, set_type_fn.args[0], name="eq"
        );
        _st_upd_bb = set_type_fn.append_basic_block("upd");
        _st_b.cbranch(_st_eq, _st_upd_bb, _st_next_bb);
        _st_b = ir.IRBuilder(_st_upd_bb);
        _st_ntag_slot = _st_b.gep(
            _st_cur_phi, [ir.Constant(i64, LIVE_NODE_TAG_OFF)], name="ntag.slot"
        );
        _st_ntag_pp = _st_b.bitcast(_st_ntag_slot, i8_ptr.as_pointer(), name="ntag.pp");
        _st_b.store(set_type_fn.args[1], _st_ntag_pp);
        _st_b.branch(_st_done_bb);
        _st_b = ir.IRBuilder(_st_next_bb);
        _st_nnxt_slot = _st_b.gep(
            _st_cur_phi, [ir.Constant(i64, LIVE_NODE_NEXT_OFF)], name="nnxt.slot"
        );
        _st_nnxt_pp = _st_b.bitcast(_st_nnxt_slot, i8_ptr.as_pointer(), name="nnxt.pp");
        _st_next_node = _st_b.load(_st_nnxt_pp, name="next.node");
        _st_cur_phi.add_incoming(_st_next_node, _st_next_bb);
        _st_b.branch(_st_check_bb);
        _st_b = ir.IRBuilder(_st_done_bb);
        _st_b.ret_void();
        self.rc_set_type_fn = set_type_fn;
    }

    retain_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);
    retain_fn = self._define_function("__rc_retain", retain_fnty);
    retain_fn.linkage = "private";
    retain_fn.args[0].name = "ptr";
    entry_bb = retain_fn.append_basic_block("entry");
    check_bb = retain_fn.append_basic_block("check_sentinel");
    do_bb = retain_fn.append_basic_block("do_retain");
    done_bb = retain_fn.append_basic_block("done");
    b = ir.IRBuilder(entry_bb);
    is_null = b.icmp_unsigned(
        "==", retain_fn.args[0], ir.Constant(i8_ptr, None), name="is.null"
    );

    gc_dis_check_bb = retain_fn.append_basic_block("gc_dis_check");
    b.cbranch(is_null, done_bb, gc_dis_check_bb);

    b = ir.IRBuilder(gc_dis_check_bb);
    gc_dis_flag_r = b.load(self.rc_gc_disabled_gv, name="gc.dis.r");
    b.cbranch(
        b.icmp_unsigned("!=", gc_dis_flag_r, ir.Constant(i8, 0), name="gc.dis.on.r"),
        done_bb,
        check_bb
    );

    b = ir.IRBuilder(check_bb);
    raw_ptr = b.gep(retain_fn.args[0], [ir.Constant(i64, HDR_RC_OFF)], name="raw");
    rc_ptr = b.bitcast(raw_ptr, i64_ptr, name="rc.ptr");
    old_rc = b.load(rc_ptr, name="old.rc");
    is_static = b.icmp_unsigned(
        "==", old_rc, ir.Constant(i64, RC_SENTINEL), name="is.static"
    );
    magic_check_bb_r = retain_fn.append_basic_block("magic_check");
    b.cbranch(is_static, done_bb, magic_check_bb_r);

    b = ir.IRBuilder(magic_check_bb_r);
    _mc_ok_r = self._emit_magic_check(b, retain_fn.args[0], name_prefix="mc.r");
    b.cbranch(_mc_ok_r, do_bb, done_bb);
    b = ir.IRBuilder(do_bb);

    b.atomic_rmw("add", rc_ptr, ir.Constant(i64, 1), ordering="monotonic");
    new_rc = b.add(old_rc, ir.Constant(i64, 1), name="new.rc");
    log_retain_bb = self._emit_retain_log_bb(
        retain_fn, done_bb, retain_fn.args[0], old_rc, new_rc
    );
    dbg_flag = b.load(self.rc_debug_gv, name="rc.dbg");
    b.cbranch(
        b.icmp_unsigned("!=", dbg_flag, ir.Constant(i8, 0), name="dbg.on"),
        log_retain_bb,
        done_bb
    );
    b = ir.IRBuilder(done_bb);
    b.ret_void();
    self.rc_retain_fn = retain_fn;

    release_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);
    release_fn = ir.Function(
        self.llvm_module, release_fnty, name="__rc_release_simple"
    );
    release_fn.linkage = "private";
    release_fn.args[0].name = "ptr";
    entry_bb = release_fn.append_basic_block("entry");
    check_bb = release_fn.append_basic_block("check_sentinel");
    do_bb = release_fn.append_basic_block("do_release");
    done_bb = release_fn.append_basic_block("done");
    b = ir.IRBuilder(entry_bb);
    is_null = b.icmp_unsigned(
        "==", release_fn.args[0], ir.Constant(i8_ptr, None), name="is.null"
    );
    gc_dis_check_bb_rel = release_fn.append_basic_block("gc_dis_check");
    b.cbranch(is_null, done_bb, gc_dis_check_bb_rel);
    b = ir.IRBuilder(gc_dis_check_bb_rel);
    gc_dis_flag_rel = b.load(self.rc_gc_disabled_gv, name="gc.dis.rel");
    magic_check_bb_rel = release_fn.append_basic_block("magic_check");
    b.cbranch(
        b.icmp_unsigned(
            "!=", gc_dis_flag_rel, ir.Constant(i8, 0), name="gc.dis.on.rel"
        ),
        done_bb,
        check_bb
    );

    b = ir.IRBuilder(check_bb);

    rc_slot = b.gep(release_fn.args[0], [ir.Constant(i64, HDR_RC_OFF)], name="rc.slot");
    rc_ptr = b.bitcast(rc_slot, i64_ptr, name="rc.ptr");
    old_rc = b.load(rc_ptr, name="old.rc");
    is_static = b.icmp_unsigned(
        "==", old_rc, ir.Constant(i64, RC_SENTINEL), name="is.static"
    );
    dblchk_bb = release_fn.append_basic_block("dbl_free_check");
    check_dtor_bb = release_fn.append_basic_block("check_dtor");
    call_dtor_bb = release_fn.append_basic_block("call_dtor");
    b.cbranch(is_static, done_bb, magic_check_bb_rel);

    b = ir.IRBuilder(magic_check_bb_rel);
    _mc_ok_rel = self._emit_magic_check(b, release_fn.args[0], name_prefix="mc.rel");

    raw_ptr = b.gep(
        release_fn.args[0], [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name="raw"
    );
    b.cbranch(_mc_ok_rel, dblchk_bb, done_bb);

    b = ir.IRBuilder(dblchk_bb);
    is_dbl = b.icmp_unsigned("==", old_rc, ir.Constant(i64, 0), name="is.dbl.free");
    log_dbl_free_bb = self._emit_dbl_free_log_bb(
        release_fn, done_bb, release_fn.args[0]
    );
    b.cbranch(is_dbl, log_dbl_free_bb, do_bb);
    b = ir.IRBuilder(do_bb);
    b.atomic_rmw("sub", rc_ptr, ir.Constant(i64, 1), ordering="acq_rel");
    new_rc = b.sub(old_rc, ir.Constant(i64, 1), name="new.rc");
    is_zero = b.icmp_unsigned("==", old_rc, ir.Constant(i64, 1), name="is.zero");
    dbg_rel_bb = self._emit_release_log_bb(
        release_fn, done_bb, release_fn.args[0], old_rc, new_rc
    );
    log_free_bb = self._emit_raw_free_bbs(release_fn, done_bb, release_fn.args[0]);
    if _cycles_on {
        cycle_check_bb = release_fn.append_basic_block("cycle_check");
        b.cbranch(is_zero, check_dtor_bb, cycle_check_bb);

        b = ir.IRBuilder(cycle_check_bb);
        _cy_dis_flag = b.load(self.rc_gc_disabled_gv, name="cy.dis.flag");
        _cy_coll_flag = b.load(self.rc_collecting_gv, name="cy.coll.flag");

        _cy_cyc_flag = b.load(self.rc_cycles_enabled_gv, name="cy.cyc.flag");
        _cy_skip = b.or_(
            b.or_(
                b.icmp_unsigned("!=", _cy_dis_flag, ir.Constant(i8, 0), name="cy.dis"),
                b.icmp_unsigned(
                    "!=", _cy_coll_flag, ir.Constant(i8, 0), name="cy.coll"
                ),
                name="cy.skip.gc"
            ),
            b.icmp_unsigned("==", _cy_cyc_flag, ir.Constant(i8, 0), name="cy.cyc.off"),
            name="cy.skip"
        );
        color_check_bb = release_fn.append_basic_block("color_check");
        b.cbranch(_cy_skip, dbg_rel_bb, color_check_bb);

        b = ir.IRBuilder(color_check_bb);
        (_cy_csp, _cy_cb) = self._emit_rc_color_load(b, release_fn.args[0]);
        _cy_color = b.and_(_cy_cb, ir.Constant(i8, 3), name="cy.color");
        _cy_is_purple = b.icmp_unsigned(
            "==", _cy_color, ir.Constant(i8, RC_COLOR_PURPLE), name="cy.is.purple"
        );
        set_root_bb = release_fn.append_basic_block("set_root");
        b.cbranch(_cy_is_purple, dbg_rel_bb, set_root_bb);

        b = ir.IRBuilder(set_root_bb);
        _cy_word = b.load(_cy_csp, name="cy.word");
        _cy_new_word = b.or_(
            b.and_(
                _cy_word, ir.Constant(i64, ~(7 << RC_COLOR_SHIFT)), name="cy.clear.bits"
            ),
            ir.Constant(i64, (RC_COLOR_PURPLE | RC_BUFFERED_BIT) << RC_COLOR_SHIFT),
            name="cy.new.word"
        );
        b.store(_cy_new_word, _cy_csp);
        if self.rc_push_root_fn is not None {
            b.call(self.rc_push_root_fn, [release_fn.args[0]]);
        }
        b.branch(dbg_rel_bb);
    } else {
        b.cbranch(is_zero, check_dtor_bb, dbg_rel_bb);
    }
    b = ir.IRBuilder(check_dtor_bb);

    if _cycles_on {
        _cd_is_buffered = self._emit_rc_is_buffered(
            b, release_fn.args[0], name_prefix="cd"
        );
        reclaim_bb = release_fn.append_basic_block("do_reclaim");
        b.cbranch(_cd_is_buffered, dbg_rel_bb, reclaim_bb);

        b = ir.IRBuilder(reclaim_bb);
    }
    dtor_raw = b.gep(
        release_fn.args[0], [ir.Constant(i64, HDR_DTOR_OFF)], name="dtor.raw"
    );
    dtor_slot = b.bitcast(dtor_raw, i64_ptr, name="dtor.slot");
    dtor_val = b.load(dtor_slot, name="dtor.val");
    is_dtor_zero = b.icmp_unsigned(
        "==", dtor_val, ir.Constant(i64, 0), name="dtor.zero"
    );
    b.cbranch(is_dtor_zero, log_free_bb, call_dtor_bb);

    b = ir.IRBuilder(call_dtor_bb);
    dtor_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);
    dtor_fn_i8 = b.inttoptr(dtor_val, i8_ptr, name="dtor.i8");
    dtor_fn_ptr = b.bitcast(dtor_fn_i8, dtor_fnty.as_pointer(), name="dtor.fn");
    b.call(dtor_fn_ptr, [release_fn.args[0]]);
    post_dtor_live_rm_bb = release_fn.append_basic_block("post_dtor_live_rm");
    b.branch(post_dtor_live_rm_bb);

    b = ir.IRBuilder(post_dtor_live_rm_bb);
    self._emit_live_list_remove(
        b, release_fn.args[0], i8_ptr, i64_ptr, done_bb, done_bb
    );
    b = ir.IRBuilder(done_bb);
    b.ret_void();
    self.rc_release_simple_fn = release_fn;
}

impl NaIRGenPass._rc_call_with_ctx(
    fn: ir.Function, args: list, op: str, loc: str = "", name: str = ""
) -> ir.Value {
    self._set_rc_ctx(op, loc);
    result = self.builder.call(fn, args, name=name);
    self._clear_rc_ctx();
    return result;
}

impl NaIRGenPass._mark_owned(val: ir.Value) -> ir.Value {
    val.is_owned = True;
    return val;
}

impl NaIRGenPass._is_owned(val: ir.Value) -> bool {
    return bool(getattr(val, 'is_owned', False));
}

impl NaIRGenPass._can_native_move_lower(nd: object) -> bool {
    if not isinstance(nd, uni.Assignment) or not nd.na_move_lowerable {
        return False;
    }
    rhs = nd.value;
    if not isinstance(rhs, uni.Name) {
        return False;
    }
    src_alloca = self.local_vars.get(rhs.value);
    if src_alloca is None {
        return False;
    }
    if not (
        isinstance(src_alloca.type, ir.PointerType)
        and isinstance(src_alloca.type.pointee, ir.PointerType)
    ) {
        return False;
    }
    self.builder.store(ir.Constant(src_alloca.type.pointee, None), src_alloca);
    self.rc_ops_elided += 1;
    return True;
}

impl NaIRGenPass._release_owned_operands(
    left_orig: ir.Value, right_orig: ir.Value, op: str = ""
) -> None {
    if isinstance(left_orig.type, ir.PointerType) and self._is_owned(left_orig) {
        self._emit_rc_release_simple(
            left_orig, op=op, loc=getattr(left_orig, 'jac_loc', '')
        );
    }
    if isinstance(right_orig.type, ir.PointerType) and self._is_owned(right_orig) {
        self._emit_rc_release_simple(
            right_orig, op=op, loc=getattr(right_orig, 'jac_loc', '')
        );
    }
}

impl NaIRGenPass._release_owned_args(call_args: list, op: str = "call_arg") -> None {
    for _arg in call_args {
        if isinstance(_arg.type, ir.PointerType) and self._is_owned(_arg) {
            self._emit_rc_release_simple(_arg, op=op, loc="");
        }
    }
}

impl NaIRGenPass._emit_magic_check(
    b: ir.IRBuilder, ptr: ir.Value, name_prefix: str = "mc"
) -> ir.Value {
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    _slot = b.gep(
        ptr, [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name=f"{name_prefix}.slot"
    );
    _ptr = b.bitcast(_slot, i64_ptr, name=f"{name_prefix}.ptr");
    _val = b.load(_ptr, name=f"{name_prefix}.val");
    _hi = b.lshr(_val, ir.Constant(i64, 32), name=f"{name_prefix}.hi");
    _hi = b.and_(_hi, ir.Constant(i64, 0xFFFF), name=f"{name_prefix}.hi.magic");
    return b.icmp_unsigned(
        "==", _hi, ir.Constant(i64, HDR_MAGIC), name=f"{name_prefix}.ok"
    );
}

impl NaIRGenPass._emit_set_type_tag(
    b: ir.IRBuilder, ptr_i8: ir.Value, type_name: str
) -> None {
    if self.rc_set_type_fn is None {
        return;
    }
    _i32 = ir.IntType(32);
    _tag_gv = self._get_snprintf_fmt(type_name);
    _tag_gep = b.gep(
        _tag_gv, [ir.Constant(_i32, 0), ir.Constant(_i32, 0)], name="tag.gep"
    );
    b.call(self.rc_set_type_fn, [ptr_i8, _tag_gep]);
}

impl NaIRGenPass._rc_alloc(size: ir.Value, name: str = "rc.alloc") -> ir.Value {
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    size = self._coerce_type(size, ir.IntType(64));
    return self.builder.call(self.rc_alloc_fn, [size], name=name);
}

impl NaIRGenPass._emit_rc_retain(ptr: ir.Value, op: str = "", loc: str = "") -> None {
    if self._gc_mode() == "none" {
        return;
    }
    if self.rc_retain_fn is None {
        self._emit_rc_helpers();
    }
    if not isinstance(ptr.type, ir.PointerType) {
        return;
    }

    if isinstance(ptr.type.pointee, ir.FunctionType) {
        return;
    }

    self.rc_retains_emitted += 1;
    i8_ptr = ir.IntType(8).as_pointer();
    self._set_rc_ctx(op, loc);
    cast = self.builder.bitcast(ptr, i8_ptr, name="rc.retain.cast");
    self.builder.call(self.rc_retain_fn, [cast]);

    self._clear_rc_ctx();
}

impl NaIRGenPass._emit_rc_release_simple(
    ptr: ir.Value, op: str = "", loc: str = ""
) -> None {
    if self._gc_mode() == "none" {
        return;
    }
    if self.rc_release_simple_fn is None {
        self._emit_rc_helpers();
    }
    if not isinstance(ptr.type, ir.PointerType) {
        return;
    }

    if isinstance(ptr.type.pointee, ir.FunctionType) {
        return;
    }

    self.rc_releases_emitted += 1;
    i8_ptr = ir.IntType(8).as_pointer();
    self._set_rc_ctx(op, loc);
    cast = self.builder.bitcast(ptr, i8_ptr, name="rc.release.cast");
    self.builder.call(self.rc_release_simple_fn, [cast]);

    self._clear_rc_ctx();
}


impl NaIRGenPass._emit_rc_release_typed(
    val: ir.Value, op: str = "", loc: str = ""
) -> None {
    self._emit_rc_release_simple(val, op=op, loc=loc);
}

impl NaIRGenPass._emit_scope_cleanup(
    skip_var: (str | None) = None, ret_val: object = None, loc: str = ""
) -> None {
    if self._builder is None {
        return;
    }
    for (var_name, alloca) in self.local_vars.items() {
        if var_name == "self" {
            continue;
        }

        if var_name in self.param_vars {
            continue;
        }

        if isinstance(alloca.type, ir.PointerType)
        and isinstance(alloca.type.pointee, ir.PointerType) {
            val = self.builder.load(alloca, name=f"cleanup.{var_name}");
            if var_name == skip_var {
                self.builder.store(ir.Constant(alloca.type.pointee, None), alloca);
            } else {
                self._emit_rc_release_typed(val, op="scope_exit", loc=loc);
                self.builder.store(ir.Constant(alloca.type.pointee, None), alloca);
            }
        }
    }
}

impl NaIRGenPass._emit_loop_iter_cleanup(body_locals: list, loc: str = "") -> None {
    if self._builder is None or self._builder.block.is_terminated {
        return;
    }
    for var_name in body_locals {
        if var_name == "self" or var_name in self.param_vars {
            continue;
        }
        alloca = self.local_vars.get(var_name);
        if alloca is None {
            continue;
        }
        if (
            isinstance(alloca.type, ir.PointerType)
            and isinstance(alloca.type.pointee, ir.PointerType)
        ) {
            val = self.builder.load(alloca, name=f"iter.cleanup.{var_name}");
            self._emit_rc_release_typed(val, op="iter_end", loc=loc);
            self.builder.store(ir.Constant(alloca.type.pointee, None), alloca);
        }
    }
}

impl NaIRGenPass._rc_strdup(ptr: ir.Value, name: str = "rc.str") -> ir.Value {
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);

    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8_ptr]);
    slen = self.builder.call(strlen_fn, [ptr], name="str.len");

    alloc_size = self.builder.add(slen, ir.Constant(i64, 1), name="str.alloc.size");
    _strdup_loc = getattr(ptr, 'jac_loc', '');
    self._set_rc_ctx("strdup", _strdup_loc);
    new_str = self._rc_alloc(alloc_size, name="rc.str.raw");
    self._clear_rc_ctx();

    memcpy_fn = self._get_or_declare_extern("memcpy", i8_ptr, [i8_ptr, i8_ptr, i64]);
    self.builder.call(memcpy_fn, [new_str, ptr, alloc_size]);
    self._emit_set_type_tag(self.builder, new_str, "str");

    self._mark_owned(new_str);
    return new_str;
}

impl NaIRGenPass._emit_struct_release_fn(arch_name: str) -> None {
    if arch_name in self.struct_release_fns {
        return;
    }
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None {
        return;
    }
    field_types = self.struct_field_types.get(arch_name, {});
    field_indices = self.struct_field_indices.get(arch_name, {});
    opaque_fields = self.struct_field_opaque.get(arch_name, set());
    struct_ptr_type = struct_type.as_pointer();
    i8_ptr = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();

    release_fnty = ir.FunctionType(ir.VoidType(), [struct_ptr_type]);
    release_fn = ir.Function(
        self.llvm_module, release_fnty, name=f"__rc_release_{arch_name}"
    );
    release_fn.linkage = "private";
    release_fn.args[0].name = "obj";

    i8 = ir.IntType(8);
    (b, done_bb) = self._emit_rc_destructor_preamble(release_fn, struct_ptr_type);

    _has_ref_fields = any(
        isinstance(_ft, ir.PointerType)
        and _fn not in opaque_fields
        and field_indices.get(_fn, -1) >= 0 for (_fn, _ft) in field_types.items()
    );
    if _has_ref_fields {
        _cycles_on = self._gc_mode() == "cycles";
        if _cycles_on and self.rc_collecting_gv is None {
            self._emit_rc_helpers();
        }
        rel_fields_bb = release_fn.append_basic_block("release_fields");
        post_fields_bb = release_fn.append_basic_block("post_fields");
        if _cycles_on {
            _rel_coll = b.load(self.rc_collecting_gv, name="rel.collecting");
            b.cbranch(
                b.icmp_unsigned(
                    "!=", _rel_coll, ir.Constant(i8, 0), name="rel.mid.coll"
                ),
                post_fields_bb,
                rel_fields_bb
            );
        } else {
            b.branch(rel_fields_bb);
        }
        b = ir.IRBuilder(rel_fields_bb);
        for (fname, ftype) in field_types.items() {
            if fname in opaque_fields {
                continue;
            }
            if isinstance(ftype, ir.PointerType) {
                idx = field_indices.get(fname, -1);
                if idx >= 0 {
                    field_ptr = b.gep(
                        release_fn.args[0],
                        [ir.Constant(i32, 0), ir.Constant(i32, idx)],
                        name=f"field.{fname}.ptr"
                    );
                    field_val = b.load(field_ptr, name=f"field.{fname}.val");
                    b.call(
                        self.rc_release_simple_fn,
                        [b.bitcast(field_val, i8_ptr, name=f"field.{fname}.cast")]
                    );
                }
            }
        }
        b.branch(post_fields_bb);
        b = ir.IRBuilder(post_fields_bb);
    }

    obj_cast = b.bitcast(release_fn.args[0], i8_ptr, name="obj.i8");
    obj_raw = b.gep(obj_cast, [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name="obj.raw");

    _sf_aid_ptr = b.bitcast(obj_raw, i64_ptr, name="sf.aid.ptr");
    _sf_aid_raw = b.load(_sf_aid_ptr, name="sf.aid.raw");
    _sf_aid = b.and_(
        _sf_aid_raw, ir.Constant(ir.IntType(64), 4294967295), name="sf.aid"
    );
    _sf_tag_slot = b.gep(obj_cast, [ir.Constant(i64, HDR_TAG_OFF)], name="sf.tag.slot");
    _sf_tag_ptr = b.bitcast(_sf_tag_slot, i8_ptr.as_pointer(), name="sf.tag.ptr");
    _sf_tag = b.load(_sf_tag_ptr, name="sf.tag");

    log_free_struct_bb = release_fn.append_basic_block("log_free_struct");
    actual_free_struct_bb = release_fn.append_basic_block("actual_free_struct");
    self._emit_live_list_remove(
        b, obj_cast, i8_ptr, i64_ptr, log_free_struct_bb, log_free_struct_bb
    );
    self._emit_struct_free_log(
        release_fn,
        log_free_struct_bb,
        actual_free_struct_bb,
        obj_cast,
        obj_raw,
        _sf_aid,
        _sf_tag
    );
    b = ir.IRBuilder(actual_free_struct_bb);
    b.call(self.rc_safe_free_fn, [obj_raw]);
    b.branch(done_bb);
    b = ir.IRBuilder(done_bb);
    b.ret_void();
    self.struct_release_fns[arch_name] = release_fn;
}
