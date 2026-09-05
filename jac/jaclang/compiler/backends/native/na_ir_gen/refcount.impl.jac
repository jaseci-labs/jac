glob _NOGC_OSP_ENGINE_STRUCTS: tuple = (
         "Slot",
         "Plan",
         "WalkerDesc",
         "NodeDesc",
         "WalkScope",
         "OspRuntime",
         "Frame",
         "OspEngine",
         "OspGraph",
         "Adj",
         "EdgeRow"
     ),
     _NOGC_CONTAINER_DROP_OPS: tuple = (
         "scope_exit",
         "field_set",
         "iter_end",
         "overwrite",
         "fori_coll",
         "binop_lhs",
         "binop_rhs",
         "binop_list",
         "for_reset",
         "call_arg",
         "list_method_arg",
         "last_use",
         "del_stmt"
     ),
     _NOGC_TEMP_FREE_OPS: tuple = (
         "binop_lhs",
         "binop_rhs",
         "binop_list",
         "str_rhs",
         "ba_aug"
     );

impl NaIRGenRefcount._gc_mode -> str {
    _mode = getattr(self.prog.options, "na_gc_mode", "cycles");
    if _mode not in ("cycles", "rc", "none") {
        return "cycles";
    }
    return _mode;
}

impl NaIRGenRefcount._emit_rc_helpers -> None {
    if self._nogc_headerless() {
        i8_ptr_hl = ir.IntType(8).as_pointer();
        i64_hl = ir.IntType(64);
        self.malloc_fn = self._get_or_declare_extern("malloc", i8_ptr_hl, [i64_hl]);
        self.free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8_ptr_hl]);
        if self.rc_alloc_fn is None {
            _ha_fnty = ir.FunctionType(i8_ptr_hl, [i64_hl]);
            _ha_fn = self._define_function("__jac_halloc", _ha_fnty);
            _ha_fn.linkage = "private";
            _ha_fn.args[0].name = "size";
            _ha_bb = _ha_fn.append_basic_block("entry");
            _ha_b = ir.IRBuilder(_ha_bb);
            _ha_raw = _ha_b.call(self.malloc_fn, [_ha_fn.args[0]], name="raw");
            _ha_b.ret(_ha_raw);
            self.rc_alloc_fn = _ha_fn;
        }
        return;
    }
    if self.rc_helpers_emitted {
        return;
    }
    self.rc_helpers_emitted = True;
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

    if self._rc_debug_codegen {
        log_alloc_bb = self._emit_alloc_log_bb(
            alloc_fn, ret_bb, _aid_old, user, alloc_fn.args[0], _tag_raw
        );
        dbg_flag_a = b.load(self.rc_debug_gv, name="rc.dbg.a");
        b.cbranch(
            b.icmp_unsigned("!=", dbg_flag_a, ir.Constant(i8, 0), name="dbg.on.a"),
            log_alloc_bb,
            ret_bb
        );
    } else {
        b.branch(ret_bb);
    }
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

    _rmw_old_r = b.atomic_rmw(
        "add", rc_ptr, ir.Constant(i64, 1), ordering="monotonic", name="rmw.old"
    );
    new_rc = b.add(_rmw_old_r, ir.Constant(i64, 1), name="new.rc");
    if self._rc_debug_codegen {
        log_retain_bb = self._emit_retain_log_bb(
            retain_fn, done_bb, retain_fn.args[0], old_rc, new_rc
        );
        dbg_flag = b.load(self.rc_debug_gv, name="rc.dbg");
        b.cbranch(
            b.icmp_unsigned("!=", dbg_flag, ir.Constant(i8, 0), name="dbg.on"),
            log_retain_bb,
            done_bb
        );
    } else {
        b.branch(done_bb);
    }
    b = ir.IRBuilder(done_bb);
    b.ret_void();
    self.rc_retain_fn = retain_fn;

    release_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr, ir.IntType(1)]);
    release_fn = ir.Function(self.llvm_module, release_fnty, name="__rc_release_impl");
    release_fn.linkage = "private";
    release_fn.args[0].name = "ptr";
    release_fn.args[1].name = "may_cycle";
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

    _rmw_old = b.atomic_rmw(
        "sub", rc_ptr, ir.Constant(i64, 1), ordering="acq_rel", name="rmw.old"
    );
    new_rc = b.sub(_rmw_old, ir.Constant(i64, 1), name="new.rc");
    is_zero = b.icmp_unsigned("==", _rmw_old, ir.Constant(i64, 1), name="is.zero");
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
                b.or_(
                    b.icmp_unsigned(
                        "!=", _cy_dis_flag, ir.Constant(i8, 0), name="cy.dis"
                    ),
                    b.icmp_unsigned(
                        "!=", _cy_coll_flag, ir.Constant(i8, 0), name="cy.coll"
                    ),
                    name="cy.skip.gc"
                ),
                b.icmp_unsigned(
                    "==", _cy_cyc_flag, ir.Constant(i8, 0), name="cy.cyc.off"
                ),
                name="cy.skip.flags"
            ),
            b.icmp_unsigned(
                "==",
                release_fn.args[1],
                ir.Constant(ir.IntType(1), 0),
                name="cy.acyclic"
            ),
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
    is_dtor_len = b.icmp_unsigned(
        "!=",
        b.and_(dtor_val, ir.Constant(i64, STR_LEN_TAG_BIT), name="dtor.lowbit"),
        ir.Constant(i64, 0),
        name="dtor.is.len"
    );
    b.cbranch(
        b.or_(is_dtor_zero, is_dtor_len, name="dtor.skip"), log_free_bb, call_dtor_bb
    );

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
    self.rc_release_impl_fn = release_fn;
    _pub_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);
    _pub_fn = ir.Function(self.llvm_module, _pub_fnty, name="__rc_release_simple");
    _pub_fn.linkage = "private";
    _pub_fn.args[0].name = "ptr";
    _pub_bb = _pub_fn.append_basic_block("entry");
    _pub_b = ir.IRBuilder(_pub_bb);
    _pub_b.call(release_fn, [_pub_fn.args[0], ir.Constant(ir.IntType(1), 1)]);
    _pub_b.ret_void();
    self.rc_release_simple_fn = _pub_fn;
}

impl NaIRGenRefcount._rc_call_with_ctx(
    fn: ir.Function, args: list, op: str, loc: str = "", name: str = ""
) -> ir.Value {
    self._set_rc_ctx(op, loc);
    result = self.builder.call(fn, args, name=name);
    self._clear_rc_ctx();
    return result;
}

impl NaIRGenRefcount._mark_owned(val: ir.Value) -> ir.Value {
    val.is_owned = True;
    return val;
}

impl NaIRGenRefcount._is_owned(val: ir.Value) -> bool {
    return bool(getattr(val, 'is_owned', False));
}

impl NaIRGenRefcount._opt_result_owned(val: ir.Value, expr: object) -> bool {
    if self._is_owned(val) {
        return True;
    }
    if self._opt_ptr_payload_of(val.type) is None {
        return False;
    }
    import from jaclang.compiler.passes.rc_facts_pass { Ownership, result_ownership }
    return isinstance(expr, uni.Expr) and result_ownership(expr) == Ownership.OWNED;
}

impl NaIRGenRefcount._can_native_move_lower(nd: object) -> bool {
    if not isinstance(nd, uni.Assignment) or not nd.na_move_lowerable {
        return False;
    }
    rhs = nd.value;
    if not isinstance(rhs, uni.Name) {
        return False;
    }
    if rhs.value in self.closure_cell_handles {
        return False;
    }
    src_alloca = self.local_vars.get(rhs.value);
    if src_alloca is None {
        return False;
    }
    _mv_desc_slot = (
        self._nogc_headerless()
        and self._str_desc_ty is not None
        and isinstance(src_alloca.type, ir.PointerType)
        and src_alloca.type.pointee == self._str_desc_ty
    );
    if not (
        isinstance(src_alloca.type, ir.PointerType)
        and isinstance(src_alloca.type.pointee, ir.PointerType)
    )
        and not _mv_desc_slot {
        return False;
    }
    self.builder.store(ir.Constant(src_alloca.type.pointee, None), src_alloca);
    self.rc_ops_elided += 1;
    return True;
}

impl NaIRGenRefcount._release_owned_operands(
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

impl NaIRGenRefcount._release_owned_args(
    call_args: list, op: str = "call_arg"
) -> None {
    for _arg in call_args {
        if isinstance(_arg.type, ir.PointerType) and self._is_owned(_arg) {
            self._emit_rc_release_simple(_arg, op=op, loc="");
        } elif (
            self?.jacval_type is not None
            and _arg.type == self.jacval_type
            and self._is_owned(_arg)
        ) {
            self.builder.call(self._emit_jacval_release_fn(), [_arg]);
        }
    }
}

impl NaIRGenRefcount._emit_magic_check(
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

impl NaIRGenRefcount._emit_str_len_helpers -> None {
    if self.str_len_fn is not None {
        return;
    }
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    i8 = ir.IntType(8);
    i8_ptr = i8.as_pointer();
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8_ptr]);
    _headerless = self._nogc_headerless();

    len_fn = self._define_function("__jac_str_len", ir.FunctionType(i64, [i8_ptr]));
    len_fn.linkage = "private";
    len_fn.args[0].name = "s";
    _l_entry = len_fn.append_basic_block("entry");
    b = ir.IRBuilder(_l_entry);
    if _headerless {
        _l_null = b.icmp_unsigned(
            "==", len_fn.args[0], ir.Constant(i8_ptr, None), name="sl.null"
        );
        _l_zero = len_fn.append_basic_block("zero");
        _l_slow0 = len_fn.append_basic_block("slow");
        b.cbranch(_l_null, _l_zero, _l_slow0);
        b = ir.IRBuilder(_l_zero);
        b.ret(ir.Constant(i64, 0));
        b = ir.IRBuilder(_l_slow0);
        b.ret(b.call(strlen_fn, [len_fn.args[0]], name="sl.strlen"));
    } else {
        _l_zero = len_fn.append_basic_block("zero");
        _l_sent = len_fn.append_basic_block("check.sentinel");
        _l_magic = len_fn.append_basic_block("check.magic");
        _l_hdr = len_fn.append_basic_block("hdr");
        _l_fast = len_fn.append_basic_block("fast");
        _l_slow = len_fn.append_basic_block("slow");
        _l_null = b.icmp_unsigned(
            "==", len_fn.args[0], ir.Constant(i8_ptr, None), name="sl.null"
        );
        b.cbranch(_l_null, _l_zero, _l_sent);
        b = ir.IRBuilder(_l_zero);
        b.ret(ir.Constant(i64, 0));
        b = ir.IRBuilder(_l_sent);
        _l_rc_slot = b.gep(
            len_fn.args[0], [ir.Constant(i64, HDR_RC_OFF)], name="sl.rc.slot"
        );
        _l_rc = b.load(b.bitcast(_l_rc_slot, i64_ptr, name="sl.rc.p"), name="sl.rc");
        _l_static = b.icmp_unsigned(
            "==", _l_rc, ir.Constant(i64, RC_SENTINEL), name="sl.static"
        );
        b.cbranch(_l_static, _l_hdr, _l_magic);
        b = ir.IRBuilder(_l_magic);
        _l_mc = self._emit_magic_check(b, len_fn.args[0], name_prefix="sl.mc");
        b.cbranch(_l_mc, _l_hdr, _l_slow);
        b = ir.IRBuilder(_l_hdr);
        _l_dt_slot = b.gep(
            len_fn.args[0], [ir.Constant(i64, HDR_DTOR_OFF)], name="sl.dt.slot"
        );
        _l_dv = b.load(b.bitcast(_l_dt_slot, i64_ptr, name="sl.dt.p"), name="sl.dv");
        _l_odd = b.and_(_l_dv, ir.Constant(i64, STR_LEN_TAG_BIT), name="sl.odd");
        b.cbranch(
            b.icmp_unsigned("!=", _l_odd, ir.Constant(i64, 0), name="sl.has.len"),
            _l_fast,
            _l_slow
        );
        b = ir.IRBuilder(_l_fast);
        b.ret(b.lshr(_l_dv, ir.Constant(i64, STR_LEN_TAG_SHIFT), name="sl.len"));
        b = ir.IRBuilder(_l_slow);
        b.ret(b.call(strlen_fn, [len_fn.args[0]], name="sl.strlen"));
    }
    self.str_len_fn = len_fn;

    tr_fn = self._define_function(
        "__jac_str_truthy", ir.FunctionType(ir.IntType(1), [i8_ptr])
    );
    tr_fn.linkage = "private";
    tr_fn.args[0].name = "s";
    _t_entry = tr_fn.append_basic_block("entry");
    tb = ir.IRBuilder(_t_entry);
    if _headerless {
        tb.ret(
            tb.icmp_unsigned(
                "!=", tr_fn.args[0], ir.Constant(i8_ptr, None), name="st.nn"
            )
        );
    } else {
        _t_zero = tr_fn.append_basic_block("zero");
        _t_sent = tr_fn.append_basic_block("check.sentinel");
        _t_magic = tr_fn.append_basic_block("check.magic");
        _t_hdr = tr_fn.append_basic_block("hdr");
        _t_len = tr_fn.append_basic_block("stamped");
        _t_obj = tr_fn.append_basic_block("object");
        _t_cstr = tr_fn.append_basic_block("cstr");
        _t_null = tb.icmp_unsigned(
            "==", tr_fn.args[0], ir.Constant(i8_ptr, None), name="st.null"
        );
        tb.cbranch(_t_null, _t_zero, _t_sent);
        tb = ir.IRBuilder(_t_zero);
        tb.ret(ir.Constant(ir.IntType(1), 0));
        tb = ir.IRBuilder(_t_sent);
        _t_rc_slot = tb.gep(
            tr_fn.args[0], [ir.Constant(i64, HDR_RC_OFF)], name="st.rc.slot"
        );
        _t_rc = tb.load(tb.bitcast(_t_rc_slot, i64_ptr, name="st.rc.p"), name="st.rc");
        _t_static = tb.icmp_unsigned(
            "==", _t_rc, ir.Constant(i64, RC_SENTINEL), name="st.static"
        );
        tb.cbranch(_t_static, _t_hdr, _t_magic);
        tb = ir.IRBuilder(_t_magic);
        _t_mc = self._emit_magic_check(tb, tr_fn.args[0], name_prefix="st.mc");
        tb.cbranch(_t_mc, _t_hdr, _t_cstr);
        tb = ir.IRBuilder(_t_hdr);
        _t_dt_slot = tb.gep(
            tr_fn.args[0], [ir.Constant(i64, HDR_DTOR_OFF)], name="st.dt.slot"
        );
        _t_dv = tb.load(tb.bitcast(_t_dt_slot, i64_ptr, name="st.dt.p"), name="st.dv");
        _t_odd = tb.and_(_t_dv, ir.Constant(i64, STR_LEN_TAG_BIT), name="st.odd");
        tb.cbranch(
            tb.icmp_unsigned("!=", _t_odd, ir.Constant(i64, 0), name="st.has.len"),
            _t_len,
            _t_obj
        );
        tb = ir.IRBuilder(_t_len);
        tb.ret(
            tb.icmp_unsigned(
                "!=",
                tb.lshr(_t_dv, ir.Constant(i64, STR_LEN_TAG_SHIFT), name="st.len"),
                ir.Constant(i64, 0),
                name="st.len.nz"
            )
        );
        tb = ir.IRBuilder(_t_obj);
        tb.ret(ir.Constant(ir.IntType(1), 1));
        tb = ir.IRBuilder(_t_cstr);
        tb.ret(
            tb.icmp_unsigned(
                "!=",
                tb.call(strlen_fn, [tr_fn.args[0]], name="st.strlen"),
                ir.Constant(i64, 0),
                name="st.strlen.nz"
            )
        );
    }
    self.str_truthy_fn = tr_fn;
    self._emit_str_stamp_and_new();
}

impl NaIRGenRefcount._emit_str_stamp_and_new -> None {
    i8 = ir.IntType(8);
    i8_ptr = i8.as_pointer();
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    _headerless = self._nogc_headerless();
    stamp_fn = self._define_function(
        "__jac_str_stamp", ir.FunctionType(ir.VoidType(), [i8_ptr, i64])
    );
    stamp_fn.linkage = "private";
    stamp_fn.args[0].name = "s";
    stamp_fn.args[1].name = "n";
    _s_entry = stamp_fn.append_basic_block("entry");
    _s_done = stamp_fn.append_basic_block("done");
    b = ir.IRBuilder(_s_entry);
    if _headerless {
        b.branch(_s_done);
    } else {
        _s_magic = stamp_fn.append_basic_block("check.magic");
        _s_store = stamp_fn.append_basic_block("store");
        _s_null = b.icmp_unsigned(
            "==", stamp_fn.args[0], ir.Constant(i8_ptr, None), name="ss.null"
        );
        b.cbranch(_s_null, _s_done, _s_magic);
        b = ir.IRBuilder(_s_magic);
        _s_mc = self._emit_magic_check(b, stamp_fn.args[0], name_prefix="ss.mc");
        b.cbranch(_s_mc, _s_store, _s_done);
        b = ir.IRBuilder(_s_store);
        _s_enc = b.or_(
            b.shl(stamp_fn.args[1], ir.Constant(i64, STR_LEN_TAG_SHIFT), name="ss.shl"),
            ir.Constant(i64, STR_LEN_TAG_BIT),
            name="ss.enc"
        );
        _s_slot = b.gep(
            stamp_fn.args[0], [ir.Constant(i64, HDR_DTOR_OFF)], name="ss.slot"
        );
        b.store(_s_enc, b.bitcast(_s_slot, i64_ptr, name="ss.slot.p"));
        b.branch(_s_done);
    }
    b = ir.IRBuilder(_s_done);
    b.ret_void();
    self.str_stamp_fn = stamp_fn;

    memcpy_fn = self._get_or_declare_extern("memcpy", i8_ptr, [i8_ptr, i8_ptr, i64]);
    new_fn = self._define_function(
        "__jac_str_new", ir.FunctionType(i8_ptr, [i8_ptr, i64])
    );
    new_fn.linkage = "weak_odr";
    new_fn.args[0].name = "data";
    new_fn.args[1].name = "n";
    _n_entry = new_fn.append_basic_block("entry");
    b = ir.IRBuilder(_n_entry);
    _n_null = b.icmp_unsigned(
        "==", new_fn.args[0], ir.Constant(i8_ptr, None), name="sn.null"
    );
    _n_len = b.select(_n_null, ir.Constant(i64, 0), new_fn.args[1], name="sn.n");
    _n_size = b.add(_n_len, ir.Constant(i64, 1), name="sn.size");
    _n_buf = b.call(self.rc_alloc_fn, [_n_size], name="sn.buf");
    _n_copy = new_fn.append_basic_block("copy");
    _n_fin = new_fn.append_basic_block("finish");
    b.cbranch(
        b.icmp_unsigned("==", _n_len, ir.Constant(i64, 0), name="sn.empty"),
        _n_fin,
        _n_copy
    );
    b = ir.IRBuilder(_n_copy);
    b.call(memcpy_fn, [_n_buf, new_fn.args[0], _n_len]);
    b.branch(_n_fin);
    b = ir.IRBuilder(_n_fin);
    _n_end = b.gep(_n_buf, [_n_len], name="sn.end");
    b.store(ir.Constant(i8, 0), _n_end);
    if not _headerless {
        if self.rc_set_type_fn is not None {
            _i32n = ir.IntType(32);
            _n_tag_gv = self._get_snprintf_fmt("str");
            _n_tag = b.gep(
                _n_tag_gv, [ir.Constant(_i32n, 0), ir.Constant(_i32n, 0)], name="sn.tag"
            );
            b.call(self.rc_set_type_fn, [_n_buf, _n_tag]);
        }
        b.call(stamp_fn, [_n_buf, _n_len]);
    }
    b.ret(_n_buf);
    self.str_new_fn = new_fn;
}

impl NaIRGenRefcount._call_str_len(
    b: ir.IRBuilder, ptr: ir.Value, name: str = "s.len"
) -> ir.Value {
    if self.str_len_fn is None {
        self._emit_str_len_helpers();
    }
    return b.call(self.str_len_fn, [ptr], name=name);
}

impl NaIRGenRefcount._call_str_truthy(
    b: ir.IRBuilder, ptr: ir.Value, name: str = "s.truthy"
) -> ir.Value {
    if self.str_truthy_fn is None {
        self._emit_str_len_helpers();
    }
    return b.call(self.str_truthy_fn, [ptr], name=name);
}

impl NaIRGenRefcount._stamp_str_len(
    b: ir.IRBuilder, ptr: ir.Value, len_val: ir.Value
) -> None {
    if self._nogc_headerless() {
        return;
    }
    if self.str_stamp_fn is None {
        self._emit_str_len_helpers();
    }
    b.call(self.str_stamp_fn, [ptr, len_val]);
}

impl NaIRGenRefcount._emit_str_cmp_helper -> None {
    if self.str_cmp_fn is not None {
        return;
    }
    i8_ptr = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    strcmp_fn = self._get_or_declare_extern("strcmp", i32, [i8_ptr, i8_ptr]);
    cmp_fn = self._define_function(
        "__jac_str_cmp", ir.FunctionType(i32, [i8_ptr, i8_ptr])
    );
    cmp_fn.linkage = "private";
    cmp_fn.args[0].name = "a";
    cmp_fn.args[1].name = "b";
    _c_entry = cmp_fn.append_basic_block("entry");
    _c_same = cmp_fn.append_basic_block("same");
    _c_anull = cmp_fn.append_basic_block("check.a");
    _c_alt = cmp_fn.append_basic_block("a.null");
    _c_bnull = cmp_fn.append_basic_block("check.b");
    _c_bgt = cmp_fn.append_basic_block("b.null");
    _c_body = cmp_fn.append_basic_block("body");
    b = ir.IRBuilder(_c_entry);
    b.cbranch(
        b.icmp_unsigned("==", cmp_fn.args[0], cmp_fn.args[1], name="sc.same"),
        _c_same,
        _c_anull
    );
    b = ir.IRBuilder(_c_same);
    b.ret(ir.Constant(i32, 0));
    b = ir.IRBuilder(_c_anull);
    b.cbranch(
        b.icmp_unsigned("==", cmp_fn.args[0], ir.Constant(i8_ptr, None), name="sc.an"),
        _c_alt,
        _c_bnull
    );
    b = ir.IRBuilder(_c_alt);
    b.ret(ir.Constant(i32, -1));
    b = ir.IRBuilder(_c_bnull);
    b.cbranch(
        b.icmp_unsigned("==", cmp_fn.args[1], ir.Constant(i8_ptr, None), name="sc.bn"),
        _c_bgt,
        _c_body
    );
    b = ir.IRBuilder(_c_bgt);
    b.ret(ir.Constant(i32, 1));
    b = ir.IRBuilder(_c_body);
    b.ret(b.call(strcmp_fn, [cmp_fn.args[0], cmp_fn.args[1]], name="sc.cmp"));
    self.str_cmp_fn = cmp_fn;
}

impl NaIRGenRefcount._call_str_cmp(
    b: ir.IRBuilder, lhs: ir.Value, rhs: ir.Value, name: str = "s.cmp"
) -> ir.Value {
    if self.str_cmp_fn is None {
        self._emit_str_cmp_helper();
    }
    return b.call(self.str_cmp_fn, [lhs, rhs], name=name);
}

impl NaIRGenRefcount._emit_str_dup_helper -> None {
    if self.str_dup_fn is not None {
        return;
    }
    if self.str_len_fn is None {
        self._emit_str_len_helpers();
    }
    i8_ptr = ir.IntType(8).as_pointer();
    dup_fn = self._define_function("__jac_str_dup", ir.FunctionType(i8_ptr, [i8_ptr]));
    dup_fn.linkage = "private";
    dup_fn.args[0].name = "s";
    _d_entry = dup_fn.append_basic_block("entry");
    _d_null = dup_fn.append_basic_block("null");
    _d_copy = dup_fn.append_basic_block("copy");
    b = ir.IRBuilder(_d_entry);
    b.cbranch(
        b.icmp_unsigned(
            "==", dup_fn.args[0], ir.Constant(i8_ptr, None), name="sd.null"
        ),
        _d_null,
        _d_copy
    );
    b = ir.IRBuilder(_d_null);
    b.ret(ir.Constant(i8_ptr, None));
    b = ir.IRBuilder(_d_copy);
    _d_len = b.call(self.str_len_fn, [dup_fn.args[0]], name="sd.len");
    b.ret(b.call(self.str_new_fn, [dup_fn.args[0], _d_len], name="sd.new"));
    self.str_dup_fn = dup_fn;
}

impl NaIRGenRefcount._call_str_dup(
    b: ir.IRBuilder, ptr: ir.Value, name: str = "s.dup"
) -> ir.Value {
    if self.str_dup_fn is None {
        self._emit_str_dup_helper();
    }
    return b.call(self.str_dup_fn, [ptr], name=name);
}

impl NaIRGenRefcount._emit_str_len_raw_helper -> None {
    if self.str_len_raw_fn is not None {
        return;
    }
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8_ptr]);
    raw_fn = self._define_function("__jac_str_len_raw", ir.FunctionType(i64, [i8_ptr]));
    raw_fn.linkage = "private";
    raw_fn.args[0].name = "p";
    _r_entry = raw_fn.append_basic_block("entry");
    _r_zero = raw_fn.append_basic_block("zero");
    _r_scan = raw_fn.append_basic_block("scan");
    b = ir.IRBuilder(_r_entry);
    b.cbranch(
        b.icmp_unsigned(
            "==", raw_fn.args[0], ir.Constant(i8_ptr, None), name="sr.null"
        ),
        _r_zero,
        _r_scan
    );
    b = ir.IRBuilder(_r_zero);
    b.ret(ir.Constant(i64, 0));
    b = ir.IRBuilder(_r_scan);
    b.ret(b.call(strlen_fn, [raw_fn.args[0]], name="sr.strlen"));
    self.str_len_raw_fn = raw_fn;
}

impl NaIRGenRefcount._call_str_len_raw(
    b: ir.IRBuilder, ptr: ir.Value, name: str = "s.rlen"
) -> ir.Value {
    if self.str_len_raw_fn is None {
        self._emit_str_len_raw_helper();
    }
    return b.call(self.str_len_raw_fn, [ptr], name=name);
}

impl NaIRGenRefcount._str_desc_type -> ir.Type {
    if self._str_desc_ty is not None {
        return self._str_desc_ty;
    }
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    st = self.llvm_module.context.get_identified_type("JacStr");
    st.set_body(
        *[
            i64 if fname == "len" else i8p
            for fname in JACSTR_DESC_FIELDS[self._str_desc_kind()]
        ]
    );
    self._str_desc_ty = st;
    return st;
}

impl NaIRGenRefcount._str_desc_kind -> str {
    return "jacstr2" if self._nogc_headerless() else "jacstr3";
}

impl NaIRGenRefcount._emit_str_desc_helpers -> None {
    if self.str_wrap_fn is not None {
        return;
    }
    if self.str_len_fn is None {
        self._emit_str_len_helpers();
    }
    if self.str_len_raw_fn is None {
        self._emit_str_len_raw_helper();
    }
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    desc = self._str_desc_type();
    _hl = self._nogc_headerless();
    _dfields = JACSTR_DESC_FIELDS[self._str_desc_kind()];
    _di = _dfields.index("data");
    _li = _dfields.index("len");
    _z = ir.Constant(i32, 0);
    for (fname, len_fn) in (
        ("__jac_str_wrap", self.str_len_fn),
        ("__jac_str_wrap_raw", self.str_len_raw_fn)
    ) {
        wf = self._define_function(fname, ir.FunctionType(desc, [i8p]));
        wf.linkage = "private";
        wf.args[0].name = "s";
        wb = ir.IRBuilder(wf.append_basic_block("entry"));
        wlen = wb.call(len_fn, [wf.args[0]], name="w.len");
        slot = wb.alloca(desc, name="w.slot");
        if not _hl {
            wb.store(
                wf.args[0], wb.gep(slot, [_z, ir.Constant(i32, 0)], name="w.root")
            );
        }
        wb.store(wf.args[0], wb.gep(slot, [_z, ir.Constant(i32, _di)], name="w.data"));
        wb.store(wlen, wb.gep(slot, [_z, ir.Constant(i32, _li)], name="w.lenp"));
        wb.ret(wb.load(slot, name="w.desc"));
        if fname == "__jac_str_wrap" {
            self.str_wrap_fn = wf;
        } else {
            self.str_wrap_raw_fn = wf;
        }
    }
    uf = self._define_function("__jac_str_unwrap", ir.FunctionType(i8p, [desc]));
    uf.linkage = "private";
    uf.args[0].name = "d";
    _u_entry = uf.append_basic_block("entry");
    _u_null = uf.append_basic_block("null");
    _u_probe = uf.append_basic_block("probe");
    _u_pass = uf.append_basic_block("pass");
    _u_copy = uf.append_basic_block("copy");
    ub = ir.IRBuilder(_u_entry);
    _u_data = ub.extract_value(uf.args[0], _di, name="u.data");
    _u_len = ub.extract_value(uf.args[0], _li, name="u.len");
    ub.cbranch(
        ub.icmp_unsigned("==", _u_data, ir.Constant(i8p, None), name="u.isnull"),
        _u_null,
        _u_probe
    );
    ub = ir.IRBuilder(_u_null);
    ub.ret(ir.Constant(i8p, None));
    ub = ir.IRBuilder(_u_probe);
    _u_end = ub.load(ub.gep(_u_data, [_u_len], name="u.endp"), name="u.end");
    ub.cbranch(
        ub.icmp_unsigned("==", _u_end, ir.Constant(i8, 0), name="u.hasnul"),
        _u_pass,
        _u_copy
    );
    ub = ir.IRBuilder(_u_pass);
    ub.ret(_u_data);
    ub = ir.IRBuilder(_u_copy);
    ub.ret(ub.call(self.str_new_fn, [_u_data, _u_len], name="u.copy"));
    self.str_unwrap_fn = uf;
}

impl NaIRGenRefcount._str_norm(val: ir.Value | None) -> (ir.Value | None) {
    if val is None or self._str_desc_ty is None or val.type != self._str_desc_ty {
        return val;
    }
    if self.str_unwrap_fn is None {
        self._emit_str_desc_helpers();
    }
    _normed = self.builder.call(self.str_unwrap_fn, [val], name="s.norm");
    if self._is_owned(val) {
        self._mark_owned(_normed);
    }
    return _normed;
}

impl NaIRGenRefcount._str_arg(val: ir.Value | None) -> (ir.Value | None) {
    val = self._str_norm(val);
    if val is not None
        and self._opt_ptr_payload_of(val.type) == ir.IntType(8).as_pointer() {
        return self._coerce_type(val, ir.IntType(8).as_pointer());
    }
    return val;
}

impl NaIRGenRefcount._membrane_str_out(b: ir.IRBuilder, val: ir.Value) -> ir.Value {
    if self.str_unwrap_fn is None {
        self._emit_str_desc_helpers();
    }
    d = b.call(self.str_wrap_fn, [val], name="mem.out.wrap");
    return b.call(self.str_unwrap_fn, [d], name="mem.out");
}

impl NaIRGenRefcount._membrane_str_in(b: ir.IRBuilder, val: ir.Value) -> ir.Value {
    if self.str_unwrap_fn is None {
        self._emit_str_desc_helpers();
    }
    d = b.call(self.str_wrap_raw_fn, [val], name="mem.in.wrap");
    return b.call(self.str_unwrap_fn, [d], name="mem.in");
}

impl NaIRGenRefcount._str_alloc(
    b: ir.IRBuilder, size: ir.Value, name: str = "s.buf"
) -> ir.Value {
    _saved = self._builder;
    self._builder = b;
    _buf = self._rc_alloc(size, name=name);
    self._emit_set_type_tag(b, _buf, "str");
    self._builder = _saved;
    return _buf;
}

impl NaIRGenRefcount._str_finish(
    b: ir.IRBuilder, buf: ir.Value, len_val: ir.Value
) -> None {
    _end = b.gep(buf, [len_val], name="s.end");
    b.store(ir.Constant(ir.IntType(8), 0), _end);
    self._stamp_str_len(b, buf, len_val);
}

impl NaIRGenRefcount._emit_set_type_tag(
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

impl NaIRGenRefcount._rc_alloc(size: ir.Value, name: str = "rc.alloc") -> ir.Value {
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    size = self._coerce_type(size, ir.IntType(64));
    return self.builder.call(self.rc_alloc_fn, [size], name=name);
}

impl NaIRGenRefcount._emit_rc_retain(
    ptr: ir.Value, op: str = "", loc: str = ""
) -> None {
    if self._gc_mode() == "none" {
        return;
    }
    if self._nogc_osp_skip(ptr) {
        return;
    }
    if self.rc_retain_fn is None {
        self._emit_rc_helpers();
    }
    if self._str_desc_ty is not None and ptr.type == self._str_desc_ty {
        ptr = self.builder.extract_value(ptr, 0, name="rc.desc.root");
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

impl NaIRGenRefcount._nogc_owned_world -> bool {
    if not self._nogc_headerless() {
        return False;
    }
    _opts = self.prog.options;
    if bool(getattr(_opts, "kernel_unit", False)) {
        return False;
    }
    try {
        return bool(_opts.nogc_enforced_for(self.ir_in.name));
    } except Exception {
        return False;
    }
}

impl NaIRGenRefcount._rc_unwrap_optional(val: ir.Value) -> ir.Value {
    if isinstance(val.type, ir.PointerType) {
        return val;
    }
    if self._opt_ptr_payload_of(val.type) is None {
        return val;
    }
    return self.builder.extract_value(val, 1, name="rc.opt.pv");
}

impl NaIRGenRefcount._nogc_drop_op_active(op: str) -> bool {
    if op not in _NOGC_CONTAINER_DROP_OPS {
        return False;
    }
    if op == "field_set" {
        return self._nogc_owned_world();
    }
    return True;
}

impl NaIRGenRefcount._emit_rc_release_simple(
    ptr: ir.Value, op: str = "", loc: str = ""
) -> None {
    _rls_owned = self._is_owned(ptr);
    if self._str_desc_ty is not None and ptr.type == self._str_desc_ty {
        ptr = self.builder.extract_value(ptr, 0, name="rc.desc.root");
    }
    if self._nogc_headerless() {
        if not self._nogc_osp_skip(ptr)
            and not (
                self._nogc_drop_op_active(op)
                and self._nogc_emit_drop(ptr, op=op, loc=loc)
            ) {
            if _rls_owned
                and op in _NOGC_TEMP_FREE_OPS
                and isinstance(ptr.type, ir.PointerType) {
                self._nogc_str_free_owned(ptr);
            } else {
                self._nogc_free_scratch(ptr, op);
            }
        }
        return;
    }
    if self._gc_mode() == "none" {
        return;
    }
    if self._nogc_osp_skip(ptr) {
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


impl NaIRGenRefcount._emit_rc_release_typed(
    val: ir.Value, op: str = "", loc: str = ""
) -> None {
    _rlt_owned = self._is_owned(val);
    if self._str_desc_ty is not None and val.type == self._str_desc_ty {
        val = self.builder.extract_value(val, 0, name="rc.desc.root");
    }
    if self._nogc_headerless() {
        if not self._nogc_osp_skip(val)
            and not (
                self._nogc_drop_op_active(op)
                and self._nogc_emit_drop(val, op=op, loc=loc)
            ) {
            if _rlt_owned
                and op in _NOGC_TEMP_FREE_OPS
                and isinstance(val.type, ir.PointerType) {
                self._nogc_str_free_owned(val);
            } else {
                self._nogc_free_scratch(val, op);
            }
        }
        return;
    }
    if self._gc_mode() == "none" {
        return;
    }
    if self._nogc_osp_skip(val) {
        return;
    }
    _tn = self._struct_ptr_pointee_name(val);
    if (
        _tn is not None
        and self._arch_is_acyclic(_tn)
        and self.rc_release_impl_fn is not None
        and isinstance(val.type, ir.PointerType)
    ) {
        _rt_i8 = self.builder.bitcast(
            val, ir.IntType(8).as_pointer(), name="rel.acyc.i8"
        );
        self.builder.call(
            self.rc_release_impl_fn, [_rt_i8, ir.Constant(ir.IntType(1), 0)]
        );
        self.rc_releases_emitted += 1;
        return;
    }
    self._emit_rc_release_simple(val, op=op, loc=loc);
}

impl NaIRGenRefcount._arch_is_acyclic(arch_name: str) -> bool {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    lay = get_layout_registry(self.ir_in, self.prog).get_layout(arch_name);
    return lay is not None and lay.is_acyclic;
}

impl NaIRGenRefcount._arch_is_osp_name(arch_name: str) -> bool {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    lay = get_layout_registry(self.ir_in, self.prog).get_layout(arch_name);
    return lay is not None and lay.is_osp;
}

impl NaIRGenRefcount._arch_is_walker_name(arch_name: str) -> bool {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    lay = get_layout_registry(self.ir_in, self.prog).get_layout(arch_name);
    return lay is not None and lay.arch_type == "walker";
}

impl NaIRGenRefcount._nogc_headerless -> bool {
    return getattr(self.ir_in.gen, "nogc_enforced", False)
        and self._gc_mode() == "none";
}

impl NaIRGenRefcount._emit_struct_drop_fn(type_name: str) -> (ir.Function | None) {
    if type_name in self.struct_drop_fns {
        return self.struct_drop_fns[type_name];
    }
    struct_type = self.struct_types.get(type_name);
    if struct_type is None {
        return None;
    }
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    fnty = ir.FunctionType(ir.VoidType(), [i8p]);
    fn = ir.Function(self.llvm_module, fnty, name=f"__drop_{type_name}");
    fn.linkage = "private";
    fn.args[0].name = "self";
    self.struct_drop_fns[type_name] = fn;

    entry_bb = fn.append_basic_block("entry");
    owns_bb = fn.append_basic_block("region.check");
    body_bb = fn.append_basic_block("body");
    done_bb = fn.append_basic_block("done");
    b = ir.IRBuilder(entry_bb);
    is_null = b.icmp_unsigned(
        "==", fn.args[0], ir.Constant(i8p, None), name="drop.null"
    );
    b.cbranch(is_null, done_bb, owns_bb);

    b.position_at_end(owns_bb);
    _owned = b.call(
        self._region_kernel_fn("__jac_region_owns"),
        [b.ptrtoint(fn.args[0], i64, name="drop.i64")],
        name="drop.owns"
    );
    b.cbranch(
        b.icmp_signed("!=", _owned, ir.Constant(i64, 0), name="drop.in.region"),
        done_bb,
        body_bb
    );

    b.position_at_end(body_bb);
    _dobj = b.bitcast(fn.args[0], struct_type.as_pointer(), name="drop.obj");
    self._emit_nogc_field_drops(b, type_name, _dobj);
    free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
    b.call(free_fn, [fn.args[0]]);
    b.branch(done_bb);

    b.position_at_end(done_bb);
    b.ret_void();
    return fn;
}

impl NaIRGenRefcount._emit_nogc_field_drops(
    b: ir.IRBuilder, type_name: str, _dobj: ir.Value
) -> None {
    i8p = ir.IntType(8).as_pointer();
    _hook = self._drop_hook_for(type_name);
    if _hook is not None {
        b.call(_hook, [_dobj]);
    }
    field_types = self.struct_field_types.get(type_name, {});
    field_indices = self.struct_field_indices.get(type_name, {});
    foreign_fields = self.struct_field_foreign.get(type_name, set());
    borrow_fields = self.struct_field_borrow.get(type_name, set());
    i32 = ir.IntType(32);
    for (fname, ftype) in field_types.items() {
        if fname in borrow_fields {
            continue;
        }
        if fname in self.struct_field_inline.get(type_name, set()) {
            _in_idx = field_indices.get(fname, -1);
            _in_name = getattr(ftype, "name", "") or "";
            _in_dropf = self._emit_struct_drop_fields_fn(_in_name)
                if _in_name
                else None;
            if _in_dropf is not None and _in_idx >= 0 {
                _in_fp = b.gep(
                    _dobj,
                    [ir.Constant(i32, 0), ir.Constant(i32, _in_idx)],
                    name=f"drop.{fname}.p"
                );
                b.call(_in_dropf, [b.bitcast(_in_fp, i8p, name=f"drop.{fname}.i8")]);
            }
            continue;
        }
        if fname in foreign_fields {
            continue;
        }
        _opt_payload = self._opt_ptr_payload_of(ftype);
        if _opt_payload is not None and not self._nogc_owned_world() {
            continue;
        }
        _ptr_ty = _opt_payload if _opt_payload is not None else ftype;
        if not isinstance(_ptr_ty, ir.PointerType) {
            continue;
        }
        idx = field_indices.get(fname, -1);
        if idx < 0 {
            continue;
        }
        _fld_drop = self._nogc_drop_fn_for(_ptr_ty, type_name);
        if _fld_drop is None {
            continue;
        }
        fp = b.gep(
            _dobj, [ir.Constant(i32, 0), ir.Constant(i32, idx)], name=f"drop.{fname}.p"
        );
        fv = b.load(fp, name=f"drop.{fname}");
        if _opt_payload is not None {
            fv = b.extract_value(fv, 1, name=f"drop.{fname}.pv");
        }
        fv_i8 = b.bitcast(fv, i8p, name=f"drop.{fname}.i8");
        b.call(_fld_drop, [fv_i8]);
    }
}

impl NaIRGenRefcount._drop_hook_for(type_name: str) -> (ir.Function | None) {
    _hook = self.struct_drop_hooks.get(type_name)
        or self.func_symtab.get(f"{type_name}.drop");
    if _hook is not None {
        self.struct_drop_hooks[type_name] = _hook;
        return _hook;
    }
    _arch = self.arch_ast_map.get(type_name);
    if _arch is None or _arch.body is None {
        return None;
    }
    for _ab in _arch.get_all_sub_nodes(uni.Ability) {
        if _ab.find_parent_of_type(uni.Archetype) is not _arch
            or _ab.name_ref is None {
            continue;
        }
        if _ab.name_ref.sym_name != "drop" {
            continue;
        }
        self._forward_declare_method(type_name, _ab);
        _hook = self.func_symtab.get(f"{type_name}.drop");
        if _hook is not None {
            self.struct_drop_hooks[type_name] = _hook;
        }
        return _hook;
    }
    return None;
}

impl NaIRGenRefcount._nogc_drop_fn_for(
    ptr_ty: ir.PointerType, self_type: str = ""
) -> (ir.Function | None) {
    _pname = getattr(ptr_ty.pointee, "name", "") or "";
    if _pname in self.struct_types or (_pname and _pname == self_type) {
        return self._emit_struct_drop_fn(_pname);
    }
    if _pname.startswith("List.")
        or _pname.startswith("Dict.")
        or _pname.startswith("Set.") {
        return self._emit_container_drop_fn(_pname);
    }
    return None;
}

impl NaIRGenRefcount._emit_container_drop_fn(cont_name: str) -> (ir.Function | None) {
    if cont_name in self.container_drop_fns {
        return self.container_drop_fns[cont_name];
    }
    layout = self.container_layouts.get(cont_name);
    if layout is None {
        return None;
    }
    _struct = None;
    try {
        _struct = self.llvm_module.context.get_identified_type(cont_name);
    } except Exception {
        return None;
    }
    if _struct is None or not _struct?.elements {
        return None;
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    fnty = ir.FunctionType(ir.VoidType(), [i8p]);
    _safe = cont_name.replace(".", "_");
    fn = ir.Function(self.llvm_module, fnty, name=f"__drop_{_safe}");
    fn.linkage = "private";
    fn.args[0].name = "self";
    self.container_drop_fns[cont_name] = fn;

    entry_bb = fn.append_basic_block("entry");
    body_bb = fn.append_basic_block("body");
    done_bb = fn.append_basic_block("done");
    b = ir.IRBuilder(entry_bb);
    is_null = b.icmp_unsigned(
        "==", fn.args[0], ir.Constant(i8p, None), name="drop.null"
    );
    b.cbranch(is_null, done_bb, body_bb);

    b = ir.IRBuilder(body_bb);
    cont = b.bitcast(fn.args[0], _struct.as_pointer(), name="drop.cont");
    free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
    _elems = list(_struct.elements);
    _has_slots = layout["drop_base"] < len(_elems);
    for (_bk, _fpair) in enumerate(layout["data_fields"]) {
        (_fi, _fty) = _fpair;
        _fkind = layout["elem_kinds"][_bk];
        dp = b.gep(
            cont, [ir.Constant(i32, 0), ir.Constant(i32, _fi)], name=f"drop.data{_fi}.p"
        );
        dv = b.load(dp, name=f"drop.data{_fi}");
        if _has_slots and _fkind != "raw" {
            _si = layout["drop_base"] + _bk;
            _sp = b.gep(
                cont,
                [ir.Constant(i32, 0), ir.Constant(i32, _si)],
                name=f"edrop{_fi}.slot.p"
            );
            _sfn = b.load(_sp, name=f"edrop{_fi}.slot");
            _have = b.icmp_unsigned(
                "!=", _sfn, ir.Constant(_elems[_si], None), name=f"edrop{_fi}.have"
            );
            _walk_bb = fn.append_basic_block(f"edrop{_fi}.walk");
            _next_bb = fn.append_basic_block(f"edrop{_fi}.next");
            b.cbranch(_have, _walk_bb, _next_bb);
            bw = ir.IRBuilder(_walk_bb);

            def _drop_slot(
                bl: ir.IRBuilder, i: ir.Value, elem_ptrs: list
            ) -> ir.IRBuilder {
                if _fkind == "jacval" {
                    bl.call(
                        _sfn,
                        [bl.bitcast(elem_ptrs[0], i8p, name=f"edrop{_fi}.slot.i8")]
                    );
                } else {
                    _ev = bl.load(elem_ptrs[0], name=f"edrop{_fi}.elem");
                    bl.call(_sfn, [bl.bitcast(_ev, i8p, name=f"edrop{_fi}.elem.i8")]);
                }
                return bl;
            }
            bw = self._emit_live_slot_loop(
                fn, bw, cont, layout, f"edrop{_fi}", _drop_slot, fields=[_fpair]
            );
            bw.branch(_next_bb);
            b = ir.IRBuilder(_next_bb);
        }
        b.call(free_fn, [b.bitcast(dv, i8p, name=f"drop.data{_fi}.i8")]);
    }
    if layout["kind"] == "hash" {
        ctrl_v = b.load(
            b.gep(
                cont,
                [ir.Constant(i32, 0), ir.Constant(i32, layout["ctrl_idx"])],
                name="drop.ctrl.p"
            ),
            name="drop.ctrl"
        );
        b.call(free_fn, [ctrl_v]);
        order_v = b.load(
            b.gep(
                cont,
                [ir.Constant(i32, 0), ir.Constant(i32, layout["order_idx"])],
                name="drop.ord.p"
            ),
            name="drop.ord"
        );
        b.call(free_fn, [b.bitcast(order_v, i8p, name="drop.ord.i8")]);
    }
    b.call(free_fn, [fn.args[0]]);
    b.branch(done_bb);

    b = ir.IRBuilder(done_bb);
    b.ret_void();
    return fn;
}

impl NaIRGenRefcount._nogc_elem_drop_slot_ty -> ir.Type {
    return ir.FunctionType(ir.VoidType(), [ir.IntType(8).as_pointer()]).as_pointer();
}

impl NaIRGenRefcount._nogc_type_arg_mangles_of_str(m: str) -> list {
    _open = m.find("[");
    if _open < 0 or not m.endswith("]") {
        return [];
    }
    _inner = m[_open + 1:-1];
    _args: list = [];
    _depth = 0;
    _cur = "";
    for _ch in _inner {
        if _ch == "[" {
            _depth += 1;
        } elif _ch == "]" {
            _depth -= 1;
        }
        if _ch == "," and _depth == 0 {
            _args.append(_cur.strip());
            _cur = "";
        } else {
            _cur += _ch;
        }
    }
    if _cur.strip() {
        _args.append(_cur.strip());
    }
    return _args;
}

impl NaIRGenRefcount._nogc_type_arg_mangles(expr: uni.UniNode | None) -> list {
    _m = "";
    try {
        _m = expr.type.mangle() if (expr is not None and expr.type is not None) else "";
    } except Exception {
        return [];
    }
    _open = _m.find("[");
    if _open < 0 or not _m.endswith("]") {
        return [];
    }
    _inner = _m[_open + 1:-1];
    _args: list = [];
    _depth = 0;
    _cur = "";
    for _ch in _inner {
        if _ch == "[" {
            _depth += 1;
        } elif _ch == "]" {
            _depth -= 1;
        }
        if _ch == "," and _depth == 0 {
            _args.append(_cur.strip());
            _cur = "";
        } else {
            _cur += _ch;
        }
    }
    if _cur.strip() {
        _args.append(_cur.strip());
    }
    return _args;
}

impl NaIRGenRefcount._drop_spec_for_mangle(mangle: str) -> (tuple | None) {
    if mangle == "int" or mangle == "bool" {
        return ("i64", ir.IntType(64));
    }
    if mangle == "float" {
        return ("f64", ir.DoubleType());
    }
    if mangle == "str"
        or mangle in self.struct_types
        or mangle.startswith("list[")
        or mangle.startswith("dict[")
        or mangle.startswith("set[") {
        return ("ptr", ir.IntType(8).as_pointer());
    }
    return None;
}

impl NaIRGenRefcount._drop_fn_for(mangle: str) -> (ir.Function | None) {
    if mangle in self.drop_fn_registry {
        return self.drop_fn_registry[mangle];
    }
    i8p = ir.IntType(8).as_pointer();
    _fn: (ir.Function | None) = None;
    if mangle in _NOGC_OSP_ENGINE_STRUCTS {
        return None;
    }
    if mangle in self.struct_types and self._arch_is_osp_name(mangle) {
        return None;
    }
    if mangle == "str" {
        _fn = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
    } elif "|" in mangle or mangle == "any" {
        _fn = self._emit_jacval_slot_drop_fn(mangle);
    } elif mangle in self.struct_types {
        _fn = self._emit_struct_drop_fn(mangle);
    } elif mangle.startswith("list[") and mangle.endswith("]") {
        _inner = self._drop_spec_for_mangle(mangle[5:-1]);
        if _inner is not None {
            self._emit_list_helpers(_inner[0], _inner[1]);
            _fn = self._emit_container_drop_fn(f"List.{_inner[0]}");
        }
    } elif mangle.startswith("set[") and mangle.endswith("]") {
        _inner = self._drop_spec_for_mangle(mangle[4:-1]);
        if _inner is not None {
            _fn = self._emit_container_drop_fn(f"Set.{_inner[0]}");
        }
    } elif mangle.startswith("dict[") and mangle.endswith("]") {
        _kv = self._nogc_type_arg_mangles_of_str(mangle);
        if len(_kv) == 2 {
            _ks = self._drop_spec_for_mangle(_kv[0]);
            _vs = self._drop_spec_for_mangle(_kv[1]);
            if _ks is not None and _vs is not None {
                _fn = self._emit_container_drop_fn(f"Dict.{_ks[0]}.{_vs[0]}");
            }
        }
    }
    if _fn is not None {
        self.drop_fn_registry[mangle] = _fn;
    }
    return _fn;
}

impl NaIRGenRefcount._nogc_stamp_elem_drops(
    cont: ir.Value | None, elem_mangles: list
) -> None {
    if cont is None or self._gc_mode() != "none" {
        return;
    }
    i32 = ir.IntType(32);
    _slot_ty = self._nogc_elem_drop_slot_ty();
    _cont_struct = cont.type?.pointee;
    _cont_name = getattr(_cont_struct, "name", "") or "";
    _layout = self.container_layouts.get(_cont_name);
    if _layout is None {
        return;
    }
    _base = _layout["drop_base"];
    _slot_specs: list = [
        (_base + _k, elem_mangles[_k])
        for _k in range(len(_layout["data_fields"]))
        if _k < len(elem_mangles)
    ];
    for (_idx, _em) in _slot_specs {
        _drop_target = self._drop_fn_for(_em);
        if _drop_target is None {
            continue;
        }
        _fn_cast = self.builder.bitcast(_drop_target, _slot_ty, name="edrop.stamp.fn");
        _sp = self.builder.gep(
            cont, [ir.Constant(i32, 0), ir.Constant(i32, _idx)], name="edrop.stamp.p"
        );
        self.builder.store(_fn_cast, _sp);
    }
}

impl NaIRGenRefcount._emit_jacval_slot_drop_fn(
    elem_mangle: str
) -> (ir.Function | None) {
    _key = f"jacval:{elem_mangle}";
    if _key in self.container_drop_fns {
        return self.container_drop_fns[_key];
    }
    import from jaclang.compiler.frontend.codeinfo { native_safe_sym }
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    _members = [_m.strip() for _m in elem_mangle.split("|")];
    _list_drops: list = [];
    _struct_drops: list = [];
    for _m in _members {
        if _m == "list[int]" {
            self._emit_list_helpers("i64", i64);
            _cand = self._emit_container_drop_fn("List.i64");
            if _cand is not None and _cand not in _list_drops {
                _list_drops.append(_cand);
            }
        } elif _m == "list[float]" {
            self._emit_list_helpers("f64", ir.DoubleType());
            _cand = self._emit_container_drop_fn("List.f64");
            if _cand is not None and _cand not in _list_drops {
                _list_drops.append(_cand);
            }
        } elif _m in self.struct_types {
            _cand = self._emit_struct_drop_fn(_m);
            if _cand is not None and _cand not in _struct_drops {
                _struct_drops.append(_cand);
            }
        }
    }
    _list_drop = _list_drops[0] if len(_list_drops) == 1 else None;
    _struct_drop = _struct_drops[0] if len(_struct_drops) == 1 else None;
    fnty = ir.FunctionType(ir.VoidType(), [i8p]);
    fn = ir.Function(
        self.llvm_module, fnty, name=f"__jacval_drop_{native_safe_sym(elem_mangle)}"
    );
    fn.linkage = "private";
    fn.args[0].name = "slot";
    self.container_drop_fns[_key] = fn;
    entry_bb = fn.append_basic_block("entry");
    done_bb = fn.append_basic_block("done");
    b = ir.IRBuilder(entry_bb);
    slot = b.bitcast(fn.args[0], self.jacval_type.as_pointer(), name="jvd.slot");
    tag = b.load(
        b.gep(slot, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="jvd.tag.p"),
        name="jvd.tag"
    );
    payload = b.load(
        b.gep(slot, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="jvd.pl.p"),
        name="jvd.pl"
    );
    live_bb = fn.append_basic_block("live");
    b.cbranch(
        b.icmp_unsigned("!=", payload, ir.Constant(i64, 0), name="jvd.nn"),
        live_bb,
        done_bb
    );
    b = ir.IRBuilder(live_bb);
    free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
    str_bb = fn.append_basic_block("str");
    chk_list_bb = fn.append_basic_block("chk.list");
    b.cbranch(
        b.icmp_unsigned("==", tag, ir.Constant(i8, 2), name="jvd.isstr"),
        str_bb,
        chk_list_bb
    );
    bs = ir.IRBuilder(str_bb);
    bs.call(free_fn, [bs.inttoptr(payload, i8p, name="jvd.str")]);
    bs.branch(done_bb);
    b = ir.IRBuilder(chk_list_bb);
    if _list_drop is not None {
        list_bb = fn.append_basic_block("list");
        chk_obj_bb = fn.append_basic_block("chk.obj");
        b.cbranch(
            b.icmp_unsigned("==", tag, ir.Constant(i8, 3), name="jvd.islist"),
            list_bb,
            chk_obj_bb
        );
        bl = ir.IRBuilder(list_bb);
        bl.call(_list_drop, [bl.inttoptr(payload, i8p, name="jvd.list")]);
        bl.branch(done_bb);
        b = ir.IRBuilder(chk_obj_bb);
    }
    if _struct_drop is not None {
        obj_bb = fn.append_basic_block("obj");
        fall_bb = fn.append_basic_block("fall");
        b.cbranch(
            b.icmp_unsigned("==", tag, ir.Constant(i8, 6), name="jvd.isobj"),
            obj_bb,
            fall_bb
        );
        bo = ir.IRBuilder(obj_bb);
        bo.call(_struct_drop, [bo.inttoptr(payload, i8p, name="jvd.obj")]);
        bo.branch(done_bb);
        b = ir.IRBuilder(fall_bb);
    }
    b.branch(done_bb);
    ir.IRBuilder(done_bb).ret_void();
    return fn;
}

impl NaIRGenRefcount._is_move_site(expr: uni.UniNode | None) -> bool {
    if not isinstance(expr, uni.Name) {
        return False;
    }
    _eid = id(expr);
    return _eid in self.ir_in.own_move_sites or _eid in self.ir_in.rc_move_in;
}

impl NaIRGenRefcount._nogc_consume_local(
    expr: uni.UniNode | None, owned_only: bool = True
) -> bool {
    if owned_only and not self._nogc_owned_world() {
        return False;
    }
    if not self._nogc_headerless() or not self._is_move_site(expr) {
        return False;
    }
    _slot = self.local_vars.get(expr.sym_name);
    if _slot is None or not isinstance(_slot.type, ir.PointerType) {
        return False;
    }
    _slot_ty = _slot.type.pointee;
    _movable = (
        isinstance(_slot_ty, ir.PointerType)
        or (self._str_desc_ty is not None and _slot_ty == self._str_desc_ty)
        or self._opt_ptr_payload_of(_slot_ty) is not None
    );
    if not _movable {
        return False;
    }
    self.builder.store(ir.Constant(_slot_ty, None), _slot);
    return True;
}

impl NaIRGenRefcount._nogc_elem_prep(
    expr: uni.UniNode | None, val: ir.Value | None
) -> (ir.Value | None) {
    if val is None or self._gc_mode() != "none" {
        return val;
    }
    if self._str_desc_ty is not None and val.type == self._str_desc_ty {
        if self._is_owned(val) or isinstance(expr, uni.FString) {
            return val;
        }
        if self._nogc_consume_local(expr, owned_only=False) {
            return val;
        }
        if self.str_new_fn is None {
            self._emit_str_len_helpers();
        }
        _ep_hl = self._nogc_headerless();
        _ep_data = self.builder.extract_value(
            val, 0 if _ep_hl else 1, name="elem.prep.data"
        );
        _ep_len = self.builder.extract_value(
            val, 1 if _ep_hl else 2, name="elem.prep.len"
        );
        _ep_copy = self.builder.call(
            self.str_new_fn, [_ep_data, _ep_len], name="elem.prep.copy"
        );
        self._mark_owned(_ep_copy);
        return _ep_copy;
    }
    if not (
        isinstance(val.type, ir.PointerType)
        and isinstance(val.type.pointee, ir.IntType)
        and val.type.pointee.width == 8
    ) {
        if isinstance(val.type, ir.PointerType)
            and isinstance(expr, uni.Name)
            and expr.sym_name in self.local_vars
            and expr.sym_name not in self.param_vars
            and not self._nogc_consume_local(expr, owned_only=False) {
            self.nogc_no_free_vars.add(expr.sym_name);
        }
        return val;
    }
    if isinstance(expr, uni.FString) {
        return val;
    }
    if isinstance(expr, uni.AtomTrailer) and isinstance(expr.right, uni.IndexSlice) {
        _bm = "";
        try {
            _bm = expr.target.type.mangle() if expr.target.type is not None else "";
        } except Exception {
            _bm = "";
        }
        if _bm == "str" {
            return val;
        }
    }
    if self._nogc_consume_local(expr, owned_only=False) {
        return val;
    }
    return self._rc_strdup(val, name="elem.copy");
}

impl NaIRGenRefcount._nogc_emit_drop(
    val: ir.Value, op: str = "", loc: str = ""
) -> bool {
    if not isinstance(val.type, ir.PointerType) {
        return False;
    }
    _tn = self._struct_ptr_pointee_name(val);
    if _tn is not None and _tn in _NOGC_OSP_ENGINE_STRUCTS {
        return True;
    }
    _fn: (ir.Function | None) = None;
    if _tn is not None and _tn in self.struct_types {
        _fn = self._emit_struct_drop_fn(_tn);
    } else {
        _pointee = val.type?.pointee;
        _pname = getattr(_pointee, "name", "") or "";
        if _pname.startswith("List.")
            or _pname.startswith("Dict.")
            or _pname.startswith("Set.") {
            _fn = self._emit_container_drop_fn(_pname);
        }
    }
    if _fn is None {
        return False;
    }
    i8p = ir.IntType(8).as_pointer();
    v_i8 = self.builder.bitcast(val, i8p, name="drop.cast");
    self.builder.call(_fn, [v_i8]);
    return True;
}

impl NaIRGenRefcount._nogc_free_scratch(val: ir.Value, op: str) -> None {
    if op
        not in (
            "print_tmp",
            "fstr_obj_tmp",
            "mstr_old",
            "mstr_val",
            "fstring",
            "str_index"
        ) {
        return;
    }
    if not isinstance(val.type, ir.PointerType) {
        return;
    }
    i8p = ir.IntType(8).as_pointer();
    _free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
    _v_i8 = self.builder.bitcast(val, i8p, name="scratch.free.cast");
    self.builder.call(_free_fn, [_v_i8]);
}

impl NaIRGenRefcount._nogc_osp_skip(val: ir.Value) -> bool {
    if not getattr(self.ir_in.gen, "nogc_enforced", False) {
        return False;
    }
    import os;
    if os.path.basename(self.ir_in.loc.mod_path or "").startswith("osp_core_") {
        return True;
    }
    _tn = self._struct_ptr_pointee_name(val);
    if _tn is None {
        return False;
    }
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    lay = get_layout_registry(self.ir_in, self.prog).get_layout(_tn);
    return lay is not None and lay.is_osp;
}

impl NaIRGenRefcount._nogc_opt_slots_owned -> bool {
    return not self._nogc_headerless() or self._nogc_owned_world();
}

impl NaIRGenRefcount._emit_scope_cleanup(
    skip_var: (str | None) = None, ret_val: object = None, loc: str = ""
) -> None {
    if self._builder is None {
        return;
    }
    self._emit_region_leaves(len(self.region_open_stack));
    _region_handles: list = [];
    for (var_name, alloca) in self.local_vars.items() {
        if var_name == "self" and not self._self_owned {
            continue;
        }

        if var_name in self.param_vars {
            continue;
        }
        if var_name in self.nogc_no_free_vars {
            continue;
        }
        if var_name in self.closure_cell_handles {
            continue;
        }

        if self._nogc_headerless()
            and self._str_desc_ty is not None
            and isinstance(alloca.type, ir.PointerType)
            and alloca.type.pointee == self._str_desc_ty {
            if var_name == skip_var {
                self.builder.store(ir.Constant(alloca.type.pointee, None), alloca);
            } elif var_name in self.nogc_owned_str_vars {
                val = self.builder.load(alloca, name=f"cleanup.{var_name}");
                self._nogc_str_free_owned(val);
                self.builder.store(ir.Constant(alloca.type.pointee, None), alloca);
            }
            continue;
        }
        if var_name in self.region_handle_vars
            and isinstance(alloca.type, ir.PointerType)
            and self._opt_ptr_payload_of(alloca.type.pointee) is not None {
            if var_name != skip_var {
                _region_handles.append((var_name, alloca));
            }
            continue;
        }
        if isinstance(alloca.type, ir.PointerType)
            and self._opt_ptr_payload_of(alloca.type.pointee) is not None {
            if var_name == skip_var {
                self.builder.store(ir.Constant(alloca.type.pointee, None), alloca);
            } elif self._nogc_opt_slots_owned() {
                val = self._rc_unwrap_optional(
                    self.builder.load(alloca, name=f"cleanup.{var_name}")
                );
                self._emit_rc_release_simple(val, op="scope_exit", loc=loc);
                self.builder.store(ir.Constant(alloca.type.pointee, None), alloca);
            }
            continue;
        }
        if isinstance(alloca.type, ir.PointerType)
            and isinstance(alloca.type.pointee, ir.PointerType) {
            if var_name in self.region_handle_vars {
                if var_name != skip_var {
                    _region_handles.append((var_name, alloca));
                }
                continue;
            }
            val = self.builder.load(alloca, name=f"cleanup.{var_name}");
            if var_name == skip_var {
                self.builder.store(ir.Constant(alloca.type.pointee, None), alloca);
            } else {
                self._emit_rc_release_typed(val, op="scope_exit", loc=loc);
                self.builder.store(ir.Constant(alloca.type.pointee, None), alloca);
            }
        }
    }
    for (var_name, cell) in self.closure_cell_handles.items() {
        if isinstance(cell.type, ir.PointerType) {
            self._emit_rc_release_typed(cell, op="scope_exit", loc=loc);
        }
    }
    for (var_name, alloca) in _region_handles {
        self._emit_region_handle_drop(alloca, var_name);
    }
}

impl NaIRGenRefcount._emit_loop_iter_cleanup(body_locals: list, loc: str = "") -> None {
    if self._builder is None or self._builder.block.is_terminated {
        return;
    }
    _region_handles: list = [];
    for var_name in body_locals {
        if var_name == "self" or var_name in self.param_vars {
            continue;
        }
        if var_name in self.nogc_no_free_vars {
            continue;
        }
        if var_name in self.closure_cell_handles {
            continue;
        }
        alloca = self.local_vars.get(var_name);
        if alloca is None {
            continue;
        }
        if self._nogc_headerless()
            and self._str_desc_ty is not None
            and isinstance(alloca.type, ir.PointerType)
            and alloca.type.pointee == self._str_desc_ty {
            if var_name in self.nogc_owned_str_vars {
                val = self.builder.load(alloca, name=f"iter.cleanup.{var_name}");
                self._nogc_str_free_owned(val);
                self.builder.store(ir.Constant(alloca.type.pointee, None), alloca);
            }
            continue;
        }
        if var_name in self.region_handle_vars
            and isinstance(alloca.type, ir.PointerType)
            and self._opt_ptr_payload_of(alloca.type.pointee) is not None {
            _region_handles.append((var_name, alloca));
            continue;
        }
        if isinstance(alloca.type, ir.PointerType)
            and self._opt_ptr_payload_of(alloca.type.pointee) is not None {
            if self._nogc_opt_slots_owned() {
                val = self._rc_unwrap_optional(
                    self.builder.load(alloca, name=f"iter.cleanup.{var_name}")
                );
                self._emit_rc_release_simple(val, op="iter_end", loc=loc);
                self.builder.store(ir.Constant(alloca.type.pointee, None), alloca);
            }
            continue;
        }
        if (
            isinstance(alloca.type, ir.PointerType)
            and isinstance(alloca.type.pointee, ir.PointerType)
        ) {
            if var_name in self.region_handle_vars {
                _region_handles.append((var_name, alloca));
                continue;
            }
            val = self.builder.load(alloca, name=f"iter.cleanup.{var_name}");
            self._emit_rc_release_typed(val, op="iter_end", loc=loc);
            self.builder.store(ir.Constant(alloca.type.pointee, None), alloca);
        }
    }
    for (var_name, alloca) in _region_handles {
        self._emit_region_handle_drop(alloca, var_name);
    }
}

impl NaIRGenRefcount._bind_loop_coll_slot(val: ir.Value) -> (str | None) {
    if not isinstance(val.type, ir.PointerType) {
        return None;
    }
    _name = f"for.coll.{self._loop_coll_seq}";
    self._loop_coll_seq += 1;
    _slot = self._entry_alloca(val.type, _name);
    self.local_vars[_name] = _slot;
    self.builder.store(val, _slot);
    return _name;
}

impl NaIRGenRefcount._release_loop_coll_slot(
    var_name: str, op: str = "", loc: str = ""
) -> None {
    _slot = self.local_vars.get(var_name);
    if _slot is None {
        return;
    }
    _val = self.builder.load(_slot, name=f"{var_name}.end");
    self._mark_owned(_val);
    self._emit_rc_release_simple(_val, op=op, loc=loc);
    self.builder.store(ir.Constant(_slot.type.pointee, None), _slot);
}

impl NaIRGenRefcount._rc_strdup(ptr: ir.Value, name: str = "rc.str") -> ir.Value {
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);

    slen = self._call_str_len(self.builder, ptr, name="str.len");

    alloc_size = self.builder.add(slen, ir.Constant(i64, 1), name="str.alloc.size");
    _strdup_loc = getattr(ptr, 'jac_loc', '');
    self._set_rc_ctx("strdup", _strdup_loc);
    new_str = self._rc_alloc(alloc_size, name="rc.str.raw");
    self._clear_rc_ctx();

    memcpy_fn = self._get_or_declare_extern("memcpy", i8_ptr, [i8_ptr, i8_ptr, i64]);
    self.builder.call(memcpy_fn, [new_str, ptr, alloc_size]);
    self._emit_set_type_tag(self.builder, new_str, "str");
    self._stamp_str_len(self.builder, new_str, slen);

    self._mark_owned(new_str);
    return new_str;
}

impl NaIRGenRefcount._emit_struct_release_fn(arch_name: str) -> None {
    if self._nogc_headerless() {
        self._emit_struct_drop_fn(arch_name);
        return;
    }
    if arch_name in self.struct_release_fns {
        return;
    }
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None {
        return;
    }
    field_types = self.struct_field_types.get(arch_name, {});
    field_indices = self.struct_field_indices.get(arch_name, {});
    foreign_fields = self.struct_field_foreign.get(arch_name, set());
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

    _hook = self._drop_hook_for(arch_name);
    if _hook is not None {
        b.call(_hook, [release_fn.args[0]]);
    }

    if self._pyb_base_of(arch_name) is not None {
        b.call(
            self._pyb_helper("drop_owner"),
            [b.ptrtoint(release_fn.args[0], i64, name="pyb.owner")]
        );
    }

    _has_ref_fields = any(
        (isinstance(_ft, ir.PointerType) or self._opt_ptr_payload_of(_ft) is not None)
            and _fn not in foreign_fields
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
            if fname in foreign_fields {
                continue;
            }
            idx = field_indices.get(fname, -1);
            if idx < 0 {
                continue;
            }
            if isinstance(ftype, ir.PointerType) {
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
            } elif self._opt_ptr_payload_of(ftype) is not None {
                field_ptr = b.gep(
                    release_fn.args[0],
                    [ir.Constant(i32, 0), ir.Constant(i32, idx)],
                    name=f"field.{fname}.ptr"
                );
                pv_ptr = b.gep(
                    field_ptr,
                    [ir.Constant(i32, 0), ir.Constant(i32, 1)],
                    name=f"field.{fname}.pvp"
                );
                pv_val = b.load(pv_ptr, name=f"field.{fname}.pv");
                b.call(
                    self.rc_release_simple_fn,
                    [b.bitcast(pv_val, i8_ptr, name=f"field.{fname}.pv.cast")]
                );
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

impl NaIRGenRefcount._emit_str_cmp3_helper -> None {
    if self.str_cmp3_fn is not None {
        return;
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    memcmp_fn = self._get_or_declare_extern("memcmp", i32, [i8p, i8p, i64]);
    fn = self._define_function(
        "__jac_str_cmp3", ir.FunctionType(i32, [i8p, i64, i8p, i64])
    );
    fn.linkage = "private";
    fn.args[0].name = "a";
    fn.args[1].name = "al";
    fn.args[2].name = "b";
    fn.args[3].name = "bl";
    _entry = fn.append_basic_block("entry");
    _cmp_bb = fn.append_basic_block("cmp");
    _retr_bb = fn.append_basic_block("retr");
    _tie_bb = fn.append_basic_block("tie");
    b = ir.IRBuilder(_entry);
    _al = fn.args[1];
    _bl = fn.args[3];
    _n = b.select(b.icmp_signed("<", _al, _bl, name="c3.min.p"), _al, _bl, name="c3.n");
    b.cbranch(
        b.icmp_signed(">", _n, ir.Constant(i64, 0), name="c3.has"), _cmp_bb, _tie_bb
    );
    b = ir.IRBuilder(_cmp_bb);
    _r = b.call(memcmp_fn, [fn.args[0], fn.args[2], _n], name="c3.memcmp");
    b.cbranch(
        b.icmp_signed("!=", _r, ir.Constant(i32, 0), name="c3.ne"), _retr_bb, _tie_bb
    );
    b = ir.IRBuilder(_retr_bb);
    b.ret(_r);
    b = ir.IRBuilder(_tie_bb);
    _gt = b.zext(b.icmp_signed(">", _al, _bl, name="c3.gt"), i32, name="c3.gt32");
    _lt = b.zext(b.icmp_signed("<", _al, _bl, name="c3.lt"), i32, name="c3.lt32");
    b.ret(b.sub(_gt, _lt, name="c3.sign"));
    self.str_cmp3_fn = fn;
}

impl NaIRGenRefcount._call_str_cmp3(
    b: ir.IRBuilder,
    l_data: ir.Value,
    l_len: ir.Value,
    r_data: ir.Value,
    r_len: ir.Value,
    name: str = "s.cmp3"
) -> ir.Value {
    if self.str_cmp3_fn is None {
        self._emit_str_cmp3_helper();
    }
    return b.call(self.str_cmp3_fn, [l_data, l_len, r_data, r_len], name=name);
}

impl NaIRGenRefcount._str_cmp_parts_of(val: ir.Value) -> (tuple | None) {
    if self._str_desc_ty is not None and val.type == self._str_desc_ty {
        _hl = self._nogc_headerless();
        _d = self.builder.extract_value(val, 0 if _hl else 1, name="scmp.data");
        _l = self.builder.extract_value(val, 1 if _hl else 2, name="scmp.len");
        return (_d, _l);
    }
    if val.type == ir.IntType(8).as_pointer() {
        return (val, self._call_str_len(self.builder, val, name="scmp.rawlen"));
    }
    return None;
}

impl NaIRGenRefcount._nogc_str_free_owned(val: ir.Value) -> None {
    _d = val;
    if self._str_desc_ty is not None and val.type == self._str_desc_ty {
        _d = self.builder.extract_value(val, 0, name="osf.data");
    }
    if not isinstance(_d.type, ir.PointerType) {
        return;
    }
    i8p = ir.IntType(8).as_pointer();
    _free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
    self.builder.call(_free_fn, [self.builder.bitcast(_d, i8p, name="osf.cast")]);
}
