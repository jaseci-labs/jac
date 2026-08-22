glob ARENA_CTRL_SIZE: int = 112,
     ARENA_CHUNK_HDR: int = 16,
     ARENA_CHUNK_DEFAULT: int = 32768,
     ARENA_DTOR_ENTRY: int = 24,
     ARENA_RUN_HDR: int = 16,
     ARENA_RUN_PAGES: int = 4,
     ARENA_RUNS_OFF: int = 80,
     ARENA_FREEPG_OFF: int = 88,
     ARENA_LOCK_OFF: int = 96;

impl NaIRGenArena._emit_arena_helpers -> None {
    if self.arena_helpers_emitted {
        return;
    }
    self.arena_helpers_emitted = True;
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i8pp = i8p.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i64p = i64.as_pointer();
    _malloc = self._get_or_declare_extern("malloc", i8p, [i64]);

    _arena_magic_base = (HDR_MAGIC + 1) * 4294967296;
    _free = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
    _dtor_fnty_ptr = ir.FunctionType(ir.VoidType(), [i8p]).as_pointer();

    _new_fn = self._define_function("__jac_region_new", ir.FunctionType(i8p, []));
    _new_fn.linkage = "private";
    b = ir.IRBuilder(_new_fn.append_basic_block("entry"));
    raw = b.call(_malloc, [ir.Constant(i64, HDR_TOTAL + ARENA_CTRL_SIZE)], name="raw");
    b.store(
        ir.Constant(i64, HDR_MAGIC_SHIFT_BASE), b.bitcast(raw, i64p, name="rgn.aid.p")
    );
    _tag_gv = self._get_snprintf_fmt("Region");
    _tag = b.gep(_tag_gv, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="rgn.tag");
    b.store(
        _tag,
        b.bitcast(
            b.gep(raw, [ir.Constant(i64, HDR_TOTAL + HDR_TAG_OFF)], name="rgn.tag.s"),
            i8pp,
            name="rgn.tag.p"
        )
    );
    b.store(
        ir.Constant(i64, RC_SENTINEL),
        b.bitcast(
            b.gep(raw, [ir.Constant(i64, HDR_TOTAL + HDR_RC_OFF)], name="rgn.rc.s"),
            i64p,
            name="rgn.rc.p"
        )
    );
    b.store(
        ir.Constant(i64, 0),
        b.bitcast(
            b.gep(raw, [ir.Constant(i64, HDR_TOTAL + HDR_DTOR_OFF)], name="rgn.dt.s"),
            i64p,
            name="rgn.dt.p"
        )
    );
    hdl = b.gep(raw, [ir.Constant(i64, HDR_TOTAL)], name="hdl");
    b.store(ir.Constant(i8p, None), b.bitcast(hdl, i8pp, name="rgn.chunk.p"));
    for _poff in (40, 56, 64, ARENA_RUNS_OFF, ARENA_FREEPG_OFF) {
        b.store(
            ir.Constant(i8p, None),
            b.bitcast(
                b.gep(hdl, [ir.Constant(i64, _poff)], name=f"rgn.p{_poff}.s"),
                i8pp,
                name=f"rgn.p{_poff}.p"
            )
        );
    }
    for (_off, _nm) in (
        (8, "off"),
        (16, "cap"),
        (32, "cnt"),
        (48, "kids"),
        (72, "flags"),
        (ARENA_LOCK_OFF, "lock")
    ) {
        b.store(
            ir.Constant(i64, 0),
            b.bitcast(
                b.gep(hdl, [ir.Constant(i64, _off)], name=f"rgn.{_nm}.s"),
                i64p,
                name=f"rgn.{_nm}.p"
            )
        );
    }
    b.store(
        ir.Constant(i8p, None),
        b.bitcast(
            b.gep(hdl, [ir.Constant(i64, 24)], name="rgn.dtl.s"), i8pp, name="rgn.dtl.p"
        )
    );
    b.ret(hdl);
    self.region_new_fn = _new_fn;

    _raw_fn = self._define_function(
        "__jac_region_raw", ir.FunctionType(i8p, [i8p, i64])
    );
    _raw_fn.linkage = "private";
    _raw_fn.args[0].name = "hdl";
    _raw_fn.args[1].name = "size";
    _entry = _raw_fn.append_basic_block("entry");
    _grow = _raw_fn.append_basic_block("grow");
    _ready = _raw_fn.append_basic_block("ready");
    b = ir.IRBuilder(_entry);
    _hdl = _raw_fn.args[0];
    _size = b.add(_raw_fn.args[1], ir.Constant(i64, 15), name="sz.pad");
    _size = b.and_(_size, ir.Constant(i64, -16), name="sz");
    _size_slot = b.alloca(i64, name="sz.slot");
    b.store(_size, _size_slot);
    _chunk_slot = b.bitcast(_hdl, i8pp, name="chunk.slot");
    _off_slot = b.bitcast(
        b.gep(_hdl, [ir.Constant(i64, 8)], name="off.s"), i64p, name="off.slot"
    );
    _cap_slot = b.bitcast(
        b.gep(_hdl, [ir.Constant(i64, 16)], name="cap.s"), i64p, name="cap.slot"
    );
    _chunk0 = b.load(_chunk_slot, name="chunk0");
    _off0 = b.load(_off_slot, name="off0");
    _cap0 = b.load(_cap_slot, name="cap0");
    _need = b.add(_off0, _size, name="need");
    _no_chunk = b.icmp_unsigned("==", _chunk0, ir.Constant(i8p, None), name="no.chunk");
    _over = b.icmp_unsigned(">", _need, _cap0, name="over");
    b.cbranch(b.or_(_no_chunk, _over, name="must.grow"), _grow, _ready);

    _draw_lock = _raw_fn.append_basic_block("raw.draw.lock");
    _draw_pop = _raw_fn.append_basic_block("raw.draw.pop");
    _draw_take = _raw_fn.append_basic_block("raw.draw.take");
    _draw_fill = _raw_fn.append_basic_block("raw.draw.fill");
    _grow_malloc = _raw_fn.append_basic_block("raw.grow.malloc");
    _grow_init = _raw_fn.append_basic_block("raw.grow.init");
    b = ir.IRBuilder(_grow);
    _want = b.add(_size, ir.Constant(i64, ARENA_CHUNK_HDR + 15), name="want.pad");
    _want = b.and_(_want, ir.Constant(i64, -16), name="want");
    _small = b.icmp_unsigned(
        "<", _want, ir.Constant(i64, ARENA_CHUNK_DEFAULT), name="small"
    );
    _csize = b.select(
        _small, ir.Constant(i64, ARENA_CHUNK_DEFAULT), _want, name="csize"
    );
    _chunk_tmp = b.alloca(i8p, name="chunk.tmp");
    _cap_tmp = b.alloca(i64, name="cap.tmp");
    _flag_tmp = b.alloca(i64, name="flag.tmp");
    b.store(_csize, _cap_tmp);
    b.store(ir.Constant(i64, 0), _flag_tmp);
    _parent = b.load(
        b.bitcast(
            b.gep(_hdl, [ir.Constant(i64, 40)], name="raw.par.s"),
            i8pp,
            name="raw.par.p"
        ),
        name="raw.par"
    );
    _has_par = b.icmp_unsigned(
        "!=", _parent, ir.Constant(i8p, None), name="raw.haspar"
    );
    b.cbranch(b.and_(_small, _has_par, name="raw.candraw"), _draw_lock, _grow_malloc);

    b = ir.IRBuilder(_draw_lock);
    _lk_slot = b.bitcast(
        b.gep(_parent, [ir.Constant(i64, ARENA_LOCK_OFF)], name="raw.lk.s"),
        i64p,
        name="raw.lk.p"
    );
    _lk_old = b.atomic_rmw(
        "xchg", _lk_slot, ir.Constant(i64, 1), ordering="acquire", name="raw.lk.old"
    );
    b.cbranch(
        b.icmp_unsigned("!=", _lk_old, ir.Constant(i64, 0), name="raw.lk.busy"),
        _draw_lock,
        _draw_pop
    );
    b = ir.IRBuilder(_draw_pop);
    _fp_slot = b.bitcast(
        b.gep(_parent, [ir.Constant(i64, ARENA_FREEPG_OFF)], name="raw.fp.s"),
        i8pp,
        name="raw.fp.p"
    );
    _fp_head = b.load(_fp_slot, name="raw.fp.head");
    b.cbranch(
        b.icmp_unsigned("==", _fp_head, ir.Constant(i8p, None), name="raw.fp.empty"),
        _draw_fill,
        _draw_take
    );
    b = ir.IRBuilder(_draw_take);
    b.store(
        b.load(b.bitcast(_fp_head, i8pp, name="raw.fp.nx.p"), name="raw.fp.nx"),
        _fp_slot
    );
    b.atomic_rmw(
        "xchg", _lk_slot, ir.Constant(i64, 0), ordering="release", name="raw.lk.rel"
    );
    b.store(_fp_head, _chunk_tmp);
    b.store(ir.Constant(i64, ARENA_CHUNK_DEFAULT), _cap_tmp);
    b.store(ir.Constant(i64, 1), _flag_tmp);
    b.branch(_grow_init);

    b = ir.IRBuilder(_draw_fill);
    _run = b.call(
        _malloc,
        [ir.Constant(i64, ARENA_RUN_HDR + ARENA_RUN_PAGES * ARENA_CHUNK_DEFAULT)],
        name="raw.run"
    );
    _rl_slot = b.bitcast(
        b.gep(_parent, [ir.Constant(i64, ARENA_RUNS_OFF)], name="raw.rl.s"),
        i8pp,
        name="raw.rl.p"
    );
    b.store(
        b.load(_rl_slot, name="raw.rl.head"), b.bitcast(_run, i8pp, name="raw.run.nx")
    );
    b.store(_run, _rl_slot);
    for _pg in range(1, ARENA_RUN_PAGES) {
        _pg_ptr = b.gep(
            _run,
            [ir.Constant(i64, ARENA_RUN_HDR + _pg * ARENA_CHUNK_DEFAULT)],
            name=f"raw.pg{_pg}"
        );
        b.store(
            b.load(_fp_slot, name=f"raw.pg{_pg}.old"),
            b.bitcast(_pg_ptr, i8pp, name=f"raw.pg{_pg}.nx")
        );
        b.store(_pg_ptr, _fp_slot);
    }
    b.atomic_rmw(
        "xchg", _lk_slot, ir.Constant(i64, 0), ordering="release", name="raw.lk.rel2"
    );
    b.store(b.gep(_run, [ir.Constant(i64, ARENA_RUN_HDR)], name="raw.pg0"), _chunk_tmp);
    b.store(ir.Constant(i64, ARENA_CHUNK_DEFAULT), _cap_tmp);
    b.store(ir.Constant(i64, 1), _flag_tmp);
    b.branch(_grow_init);

    b = ir.IRBuilder(_grow_malloc);
    b.store(b.call(_malloc, [_csize], name="chunk"), _chunk_tmp);
    b.branch(_grow_init);

    b = ir.IRBuilder(_grow_init);
    _chunk = b.load(_chunk_tmp, name="chunk.new");
    b.store(_chunk0, b.bitcast(_chunk, i8pp, name="chunk.prev.p"));

    _rgn_word = b.or_(
        b.ptrtoint(_hdl, i64, name="chunk.rgn.i"),
        b.load(_flag_tmp, name="chunk.flag"),
        name="chunk.rgn.w"
    );
    b.store(
        b.inttoptr(_rgn_word, i8p, name="chunk.rgn.v"),
        b.bitcast(
            b.gep(_chunk, [ir.Constant(i64, 8)], name="chunk.rgn.s"),
            i8pp,
            name="chunk.rgn.p"
        )
    );
    b.store(_chunk, _chunk_slot);
    b.store(ir.Constant(i64, ARENA_CHUNK_HDR), _off_slot);
    b.store(b.load(_cap_tmp, name="cap.new"), _cap_slot);
    b.branch(_ready);

    b = ir.IRBuilder(_ready);
    _chunk_r = b.load(_chunk_slot, name="chunk.r");
    _off_r = b.load(_off_slot, name="off.r");
    _sz_r = b.load(_size_slot, name="sz.r");
    _ptr = b.gep(_chunk_r, [_off_r], name="bump");
    b.store(b.add(_off_r, _sz_r, name="off.next"), _off_slot);
    _cnt_slot = b.bitcast(
        b.gep(_hdl, [ir.Constant(i64, 32)], name="cnt.s"), i64p, name="cnt.slot"
    );
    b.store(
        b.add(b.load(_cnt_slot, name="cnt"), ir.Constant(i64, 1), name="cnt.next"),
        _cnt_slot
    );
    b.ret(_ptr);

    _alloc_fn = self._define_function(
        "__jac_region_alloc", ir.FunctionType(i8p, [i8p, i64])
    );
    _alloc_fn.linkage = "private";
    _alloc_fn.args[0].name = "hdl";
    _alloc_fn.args[1].name = "size";
    b = ir.IRBuilder(_alloc_fn.append_basic_block("entry"));
    _total = b.add(_alloc_fn.args[1], ir.Constant(i64, HDR_TOTAL), name="total");
    _araw = b.call(_raw_fn, [_alloc_fn.args[0], _total], name="raw");
    b.store(
        ir.Constant(i64, _arena_magic_base), b.bitcast(_araw, i64p, name="ar.aid.p")
    );
    _atag_gv = self._get_snprintf_fmt("arena");
    _atag = b.gep(_atag_gv, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ar.tag");
    b.store(
        _atag,
        b.bitcast(
            b.gep(_araw, [ir.Constant(i64, HDR_TOTAL + HDR_TAG_OFF)], name="ar.tag.s"),
            i8pp,
            name="ar.tag.p"
        )
    );
    b.store(
        ir.Constant(i64, RC_SENTINEL),
        b.bitcast(
            b.gep(_araw, [ir.Constant(i64, HDR_TOTAL + HDR_RC_OFF)], name="ar.rc.s"),
            i64p,
            name="ar.rc.p"
        )
    );
    b.store(
        b.ptrtoint(_alloc_fn.args[0], i64, name="ar.hdl.i64"),
        b.bitcast(
            b.gep(_araw, [ir.Constant(i64, HDR_TOTAL + HDR_DTOR_OFF)], name="ar.dt.s"),
            i64p,
            name="ar.dt.p"
        )
    );
    b.ret(b.gep(_araw, [ir.Constant(i64, HDR_TOTAL)], name="obj"));
    self.region_alloc_fn = _alloc_fn;

    _log_fn = self._define_function(
        "__jac_region_log_dtor", ir.FunctionType(ir.VoidType(), [i8p, i8p, i8p])
    );
    _log_fn.linkage = "private";
    _log_fn.args[0].name = "hdl";
    _log_fn.args[1].name = "obj";
    _log_fn.args[2].name = "fn";
    b = ir.IRBuilder(_log_fn.append_basic_block("entry"));
    _ent = b.call(
        _raw_fn, [_log_fn.args[0], ir.Constant(i64, ARENA_DTOR_ENTRY)], name="ent"
    );
    _dtl_slot = b.bitcast(
        b.gep(_log_fn.args[0], [ir.Constant(i64, 24)], name="dtl.s"),
        i8pp,
        name="dtl.slot"
    );
    b.store(b.load(_dtl_slot, name="dtl.head"), b.bitcast(_ent, i8pp, name="ent.nx"));
    b.store(
        _log_fn.args[1],
        b.bitcast(b.gep(_ent, [ir.Constant(i64, 8)], name="ent.obj.s"), i8pp)
    );
    b.store(
        _log_fn.args[2],
        b.bitcast(b.gep(_ent, [ir.Constant(i64, 16)], name="ent.fn.s"), i8pp)
    );
    b.store(_ent, _dtl_slot);
    b.ret_void();
    self.region_log_dtor_fn = _log_fn;

    _drop_fn = self._define_function(
        "__jac_region_drop", ir.FunctionType(ir.VoidType(), [i8p])
    );
    _drop_fn.linkage = "private";
    _drop_fn.args[0].name = "hdl";
    _d_entry = _drop_fn.append_basic_block("entry");
    _d_route = _drop_fn.append_basic_block("route");
    _d_defer = _drop_fn.append_basic_block("defer");
    _d_route2 = _drop_fn.append_basic_block("route2");
    _mg_entry = _drop_fn.append_basic_block("merge");
    _mg_ck_walk = _drop_fn.append_basic_block("merge.ck.walk");
    _mg_ck_next = _drop_fn.append_basic_block("merge.ck.next");
    _mg_ck_done = _drop_fn.append_basic_block("merge.ck.done");
    _mg_ck_first = _drop_fn.append_basic_block("merge.ck.first");
    _mg_ck_ins = _drop_fn.append_basic_block("merge.ck.insert");
    _mg_dl = _drop_fn.append_basic_block("merge.dtl");
    _mg_dl_walk = _drop_fn.append_basic_block("merge.dtl.walk");
    _mg_dl_next = _drop_fn.append_basic_block("merge.dtl.next");
    _mg_dl_done = _drop_fn.append_basic_block("merge.dtl.done");
    _mg_ml = _drop_fn.append_basic_block("merge.mlist");
    _mg_ml_walk = _drop_fn.append_basic_block("merge.mlist.walk");
    _mg_ml_next = _drop_fn.append_basic_block("merge.mlist.next");
    _mg_ml_done = _drop_fn.append_basic_block("merge.mlist.done");
    _mg_fin = _drop_fn.append_basic_block("merge.fin");
    _mg_casc = _drop_fn.append_basic_block("merge.cascade");
    _mg_ret = _drop_fn.append_basic_block("merge.ret");
    _d_body = _drop_fn.append_basic_block("body");
    _dt_head = _drop_fn.append_basic_block("dtor.head");
    _dt_body = _drop_fn.append_basic_block("dtor.body");
    _ck_head = _drop_fn.append_basic_block("chunk.head");
    _ck_body = _drop_fn.append_basic_block("chunk.body");
    _md_head = _drop_fn.append_basic_block("merged.head");
    _md_body = _drop_fn.append_basic_block("merged.body");
    _d_done = _drop_fn.append_basic_block("done");
    b = ir.IRBuilder(_d_entry);
    _dhdl = _drop_fn.args[0];
    b.cbranch(
        b.icmp_unsigned("==", _dhdl, ir.Constant(i8p, None), name="hdl.null"),
        _d_done,
        _d_route
    );

    b = ir.IRBuilder(_d_route);
    _kids_slot = b.bitcast(
        b.gep(_dhdl, [ir.Constant(i64, 48)], name="kids.s"), i64p, name="kids.p"
    );
    _flags_slot = b.bitcast(
        b.gep(_dhdl, [ir.Constant(i64, 72)], name="flags.s"), i64p, name="flags.p"
    );
    _kids = b.load(_kids_slot, name="kids");
    b.cbranch(
        b.icmp_signed(">", _kids, ir.Constant(i64, 0), name="has.kids"),
        _d_defer,
        _d_route2
    );

    b = ir.IRBuilder(_d_defer);
    b.store(
        b.or_(b.load(_flags_slot, name="flags"), ir.Constant(i64, 1), name="flags.z"),
        _flags_slot
    );
    b.ret_void();

    b = ir.IRBuilder(_d_route2);
    _par = b.load(
        b.bitcast(
            b.gep(_dhdl, [ir.Constant(i64, 40)], name="par.s"), i8pp, name="par.p"
        ),
        name="par"
    );
    b.cbranch(
        b.icmp_unsigned("==", _par, ir.Constant(i8p, None), name="par.null"),
        _d_body,
        _mg_entry
    );

    b = ir.IRBuilder(_mg_entry);
    _mg_t = b.alloca(i8p, name="mg.t");
    _mg_ch = b.load(b.bitcast(_dhdl, i8pp, name="mg.ch.p"), name="mg.ch");
    b.store(_mg_ch, _mg_t);
    b.cbranch(
        b.icmp_unsigned("==", _mg_ch, ir.Constant(i8p, None), name="mg.ch.null"),
        _mg_dl,
        _mg_ck_walk
    );
    b = ir.IRBuilder(_mg_ck_walk);
    _mg_tv = b.load(_mg_t, name="mg.tv");
    _mg_tn = b.load(b.bitcast(_mg_tv, i8pp, name="mg.tn.p"), name="mg.tn");
    b.cbranch(
        b.icmp_unsigned("==", _mg_tn, ir.Constant(i8p, None), name="mg.tail"),
        _mg_ck_done,
        _mg_ck_next
    );
    b = ir.IRBuilder(_mg_ck_next);
    b.store(_mg_tn, _mg_t);
    b.branch(_mg_ck_walk);
    b = ir.IRBuilder(_mg_ck_done);
    _mg_ph = b.load(b.bitcast(_par, i8pp, name="mg.ph.p"), name="mg.ph");
    b.cbranch(
        b.icmp_unsigned("==", _mg_ph, ir.Constant(i8p, None), name="mg.ph.null"),
        _mg_ck_first,
        _mg_ck_ins
    );
    b = ir.IRBuilder(_mg_ck_first);
    b.store(_mg_ch, b.bitcast(_par, i8pp, name="mg.ph.set"));
    b.branch(_mg_dl);
    b = ir.IRBuilder(_mg_ck_ins);
    _mg_old = b.load(b.bitcast(_mg_ph, i8pp, name="mg.old.p"), name="mg.old");
    _mg_tail = b.load(_mg_t, name="mg.tail.v");
    b.store(_mg_old, b.bitcast(_mg_tail, i8pp, name="mg.tail.link"));
    b.store(_mg_ch, b.bitcast(_mg_ph, i8pp, name="mg.ph.link"));
    b.branch(_mg_dl);

    b = ir.IRBuilder(_mg_dl);
    _mg_d = b.alloca(i8p, name="mg.d");
    _mg_dh = b.load(
        b.bitcast(
            b.gep(_dhdl, [ir.Constant(i64, 24)], name="mg.dl.s"), i8pp, name="mg.dl.p"
        ),
        name="mg.dh"
    );
    b.store(_mg_dh, _mg_d);
    b.cbranch(
        b.icmp_unsigned("==", _mg_dh, ir.Constant(i8p, None), name="mg.dl.null"),
        _mg_ml,
        _mg_dl_walk
    );
    b = ir.IRBuilder(_mg_dl_walk);
    _mg_dv = b.load(_mg_d, name="mg.dv");
    _mg_dn = b.load(b.bitcast(_mg_dv, i8pp, name="mg.dn.p"), name="mg.dn");
    b.cbranch(
        b.icmp_unsigned("==", _mg_dn, ir.Constant(i8p, None), name="mg.dtail"),
        _mg_dl_done,
        _mg_dl_next
    );
    b = ir.IRBuilder(_mg_dl_next);
    b.store(_mg_dn, _mg_d);
    b.branch(_mg_dl_walk);
    b = ir.IRBuilder(_mg_dl_done);
    _mg_pdl_slot = b.bitcast(
        b.gep(_par, [ir.Constant(i64, 24)], name="mg.pdl.s"), i8pp, name="mg.pdl.p"
    );
    _mg_dtail = b.load(_mg_d, name="mg.dtail.v");
    b.store(
        b.load(_mg_pdl_slot, name="mg.pdl"),
        b.bitcast(_mg_dtail, i8pp, name="mg.dtail.link")
    );
    b.store(_mg_dh, _mg_pdl_slot);
    b.branch(_mg_ml);

    b = ir.IRBuilder(_mg_ml);
    _mg_lk = _drop_fn.append_basic_block("merge.lock");
    _mg_rn_walk = _drop_fn.append_basic_block("merge.run.walk");
    _mg_rn_done = _drop_fn.append_basic_block("merge.run.done");
    _mg_fp_chk = _drop_fn.append_basic_block("merge.fp.check");
    _mg_fp_walk = _drop_fn.append_basic_block("merge.fp.walk");
    _mg_fp_done = _drop_fn.append_basic_block("merge.fp.done");
    _mg_ml_cont = _drop_fn.append_basic_block("merge.mlist.cont");
    _mg_r = b.alloca(i8p, name="mg.rn");
    _mg_f = b.alloca(i8p, name="mg.fp");
    _mg_crn_slot = b.bitcast(
        b.gep(_dhdl, [ir.Constant(i64, ARENA_RUNS_OFF)], name="mg.crn.s"),
        i8pp,
        name="mg.crn.p"
    );
    _mg_prn_slot = b.bitcast(
        b.gep(_par, [ir.Constant(i64, ARENA_RUNS_OFF)], name="mg.prn.s"),
        i8pp,
        name="mg.prn.p"
    );
    _mg_cfp_slot = b.bitcast(
        b.gep(_dhdl, [ir.Constant(i64, ARENA_FREEPG_OFF)], name="mg.cfp.s"),
        i8pp,
        name="mg.cfp.p"
    );
    _mg_pfp_slot = b.bitcast(
        b.gep(_par, [ir.Constant(i64, ARENA_FREEPG_OFF)], name="mg.pfp.s"),
        i8pp,
        name="mg.pfp.p"
    );
    _mg_plk_slot = b.bitcast(
        b.gep(_par, [ir.Constant(i64, ARENA_LOCK_OFF)], name="mg.plk.s"),
        i64p,
        name="mg.plk.p"
    );
    b.branch(_mg_lk);

    b = ir.IRBuilder(_mg_lk);
    _mg_lko = b.atomic_rmw(
        "xchg", _mg_plk_slot, ir.Constant(i64, 1), ordering="acquire", name="mg.lk.old"
    );
    _mg_rn_ck = _drop_fn.append_basic_block("merge.run.check");
    b.cbranch(
        b.icmp_unsigned("!=", _mg_lko, ir.Constant(i64, 0), name="mg.lk.busy"),
        _mg_lk,
        _mg_rn_ck
    );
    b = ir.IRBuilder(_mg_rn_ck);
    _mg_crn = b.load(_mg_crn_slot, name="mg.crn");
    b.store(_mg_crn, _mg_r);
    b.cbranch(
        b.icmp_unsigned("==", _mg_crn, ir.Constant(i8p, None), name="mg.crn.null"),
        _mg_fp_chk,
        _mg_rn_walk
    );
    b = ir.IRBuilder(_mg_rn_walk);
    _mg_rv = b.load(_mg_r, name="mg.rv");
    _mg_rn2 = b.load(b.bitcast(_mg_rv, i8pp, name="mg.rn.nx.p"), name="mg.rn.nx");
    _mg_rn_step = _drop_fn.append_basic_block("merge.run.step");
    b.cbranch(
        b.icmp_unsigned("==", _mg_rn2, ir.Constant(i8p, None), name="mg.rn.tail"),
        _mg_rn_done,
        _mg_rn_step
    );
    b = ir.IRBuilder(_mg_rn_step);
    b.store(_mg_rn2, _mg_r);
    b.branch(_mg_rn_walk);
    b = ir.IRBuilder(_mg_rn_done);
    _mg_rtail = b.load(_mg_r, name="mg.rtail");
    b.store(
        b.load(_mg_prn_slot, name="mg.prn"),
        b.bitcast(_mg_rtail, i8pp, name="mg.rtail.link")
    );
    b.store(_mg_crn, _mg_prn_slot);
    b.branch(_mg_fp_chk);
    b = ir.IRBuilder(_mg_fp_chk);
    _mg_cfp = b.load(_mg_cfp_slot, name="mg.cfp");
    b.store(_mg_cfp, _mg_f);
    b.cbranch(
        b.icmp_unsigned("==", _mg_cfp, ir.Constant(i8p, None), name="mg.cfp.null"),
        _mg_ml_cont,
        _mg_fp_walk
    );
    b = ir.IRBuilder(_mg_fp_walk);
    _mg_fv = b.load(_mg_f, name="mg.fv");
    _mg_fn2 = b.load(b.bitcast(_mg_fv, i8pp, name="mg.fp.nx.p"), name="mg.fp.nx");
    _mg_fp_step = _drop_fn.append_basic_block("merge.fp.step");
    b.cbranch(
        b.icmp_unsigned("==", _mg_fn2, ir.Constant(i8p, None), name="mg.fp.tail"),
        _mg_fp_done,
        _mg_fp_step
    );
    b = ir.IRBuilder(_mg_fp_step);
    b.store(_mg_fn2, _mg_f);
    b.branch(_mg_fp_walk);
    b = ir.IRBuilder(_mg_fp_done);
    _mg_ftail = b.load(_mg_f, name="mg.ftail");
    b.store(
        b.load(_mg_pfp_slot, name="mg.pfp"),
        b.bitcast(_mg_ftail, i8pp, name="mg.ftail.link")
    );
    b.store(_mg_cfp, _mg_pfp_slot);
    b.branch(_mg_ml_cont);
    b = ir.IRBuilder(_mg_ml_cont);
    b.atomic_rmw(
        "xchg", _mg_plk_slot, ir.Constant(i64, 0), ordering="release", name="mg.lk.rel"
    );
    _mg_pcnt_slot = b.bitcast(
        b.gep(_par, [ir.Constant(i64, 32)], name="mg.pcnt.s"), i64p, name="mg.pcnt.p"
    );
    _mg_ccnt = b.load(
        b.bitcast(
            b.gep(_dhdl, [ir.Constant(i64, 32)], name="mg.ccnt.s"),
            i64p,
            name="mg.ccnt.p"
        ),
        name="mg.ccnt"
    );
    b.store(
        b.add(b.load(_mg_pcnt_slot, name="mg.pcnt"), _mg_ccnt, name="mg.cnt.sum"),
        _mg_pcnt_slot
    );
    _mg_m = b.alloca(i8p, name="mg.m");
    _mg_cml_slot = b.bitcast(
        b.gep(_dhdl, [ir.Constant(i64, 56)], name="mg.cml.s"), i8pp, name="mg.cml.p"
    );
    _mg_pml_slot = b.bitcast(
        b.gep(_par, [ir.Constant(i64, 56)], name="mg.pml.s"), i8pp, name="mg.pml.p"
    );
    _mg_cm = b.load(_mg_cml_slot, name="mg.cm");
    b.store(_mg_cm, _mg_m);
    b.cbranch(
        b.icmp_unsigned("==", _mg_cm, ir.Constant(i8p, None), name="mg.cml.null"),
        _mg_fin,
        _mg_ml_walk
    );
    b = ir.IRBuilder(_mg_ml_walk);
    _mg_mv = b.load(_mg_m, name="mg.mv");
    _mg_mn = b.load(
        b.bitcast(
            b.gep(_mg_mv, [ir.Constant(i64, 64)], name="mg.mn.s"), i8pp, name="mg.mn.p"
        ),
        name="mg.mn"
    );
    b.cbranch(
        b.icmp_unsigned("==", _mg_mn, ir.Constant(i8p, None), name="mg.mtail"),
        _mg_ml_done,
        _mg_ml_next
    );
    b = ir.IRBuilder(_mg_ml_next);
    b.store(_mg_mn, _mg_m);
    b.branch(_mg_ml_walk);
    b = ir.IRBuilder(_mg_ml_done);
    _mg_mtail = b.load(_mg_m, name="mg.mtail.v");
    b.store(
        b.load(_mg_pml_slot, name="mg.pml"),
        b.bitcast(
            b.gep(_mg_mtail, [ir.Constant(i64, 64)], name="mg.mtail.s"),
            i8pp,
            name="mg.mtail.link"
        )
    );
    b.store(_mg_cm, _mg_pml_slot);
    b.store(ir.Constant(i8p, None), _mg_cml_slot);
    b.branch(_mg_fin);

    b = ir.IRBuilder(_mg_fin);
    b.store(
        b.load(_mg_pml_slot, name="mg.pml2"),
        b.bitcast(
            b.gep(_dhdl, [ir.Constant(i64, 64)], name="mg.sib.s"), i8pp, name="mg.sib.p"
        )
    );
    b.store(_dhdl, _mg_pml_slot);
    _mg_pk_slot = b.bitcast(
        b.gep(_par, [ir.Constant(i64, 48)], name="mg.pk.s"), i64p, name="mg.pk.p"
    );
    _mg_pk1 = b.sub(
        b.load(_mg_pk_slot, name="mg.pk"), ir.Constant(i64, 1), name="mg.pk1"
    );
    b.store(_mg_pk1, _mg_pk_slot);
    _mg_pfl = b.load(
        b.bitcast(
            b.gep(_par, [ir.Constant(i64, 72)], name="mg.pfl.s"), i64p, name="mg.pfl.p"
        ),
        name="mg.pfl"
    );
    _mg_zomb = b.icmp_unsigned(
        "!=",
        b.and_(_mg_pfl, ir.Constant(i64, 1), name="mg.pfl.z"),
        ir.Constant(i64, 0),
        name="mg.is.z"
    );
    _mg_last = b.icmp_signed("==", _mg_pk1, ir.Constant(i64, 0), name="mg.last.kid");
    b.cbranch(b.and_(_mg_zomb, _mg_last, name="mg.casc"), _mg_casc, _mg_ret);
    b = ir.IRBuilder(_mg_casc);
    b.store(
        ir.Constant(i64, 0),
        b.bitcast(
            b.gep(_par, [ir.Constant(i64, 72)], name="mg.pfl.clr.s"),
            i64p,
            name="mg.pfl.clr.p"
        )
    );
    b.call(_drop_fn, [_par]);
    b.branch(_mg_ret);
    b = ir.IRBuilder(_mg_ret);
    b.ret_void();

    b = ir.IRBuilder(_d_body);
    _died_fn = self.func_symtab.get("osp_region_died");
    if (_died_fn is not None) and (self._osp_ensure_fn is not None) {
        b.call(self._osp_ensure_fn, []);
        _died_argty = _died_fn.function_type.args[0];
        _rgn_i64 = b.ptrtoint(_dhdl, i64, name="rgn.died.i64");
        if _died_argty != i64 {
            _rgn_i64 = b.bitcast(_rgn_i64, _died_argty, name="rgn.died.arg");
        }
        b.call(_died_fn, [_rgn_i64]);
    }
    _cur = b.alloca(i8p, name="cur");
    _mrg = b.alloca(i8p, name="mrg");
    b.store(
        b.load(
            b.bitcast(
                b.gep(_dhdl, [ir.Constant(i64, 56)], name="ml.s"), i8pp, name="ml.p"
            ),
            name="ml.head"
        ),
        _mrg
    );
    b.store(
        b.load(
            b.bitcast(
                b.gep(_dhdl, [ir.Constant(i64, 24)], name="dtl.s"), i8pp, name="dtl.p"
            ),
            name="dtl.head"
        ),
        _cur
    );
    b.branch(_dt_head);
    b = ir.IRBuilder(_dt_head);
    _c = b.load(_cur, name="c");
    b.cbranch(
        b.icmp_unsigned("==", _c, ir.Constant(i8p, None), name="dtl.end"),
        _ck_head,
        _dt_body
    );
    b = ir.IRBuilder(_dt_body);
    _obj = b.load(
        b.bitcast(b.gep(_c, [ir.Constant(i64, 8)], name="e.obj.s"), i8pp), name="e.obj"
    );
    _fnp = b.load(
        b.bitcast(b.gep(_c, [ir.Constant(i64, 16)], name="e.fn.s"), i8pp), name="e.fn"
    );
    b.call(b.bitcast(_fnp, _dtor_fnty_ptr, name="e.fn.t"), [_obj]);
    b.store(b.load(b.bitcast(_c, i8pp, name="e.nx.p"), name="e.nx"), _cur);
    b.branch(_dt_head);
    b = ir.IRBuilder(_ck_head);
    b.store(b.load(b.bitcast(_dhdl, i8pp, name="ck.head.p"), name="ck.head"), _cur);
    b.branch(_ck_body);
    _ck_loop = _drop_fn.append_basic_block("chunk.loop");
    _ck_free = _drop_fn.append_basic_block("chunk.free");
    _ck_next = _drop_fn.append_basic_block("chunk.next");
    _run_head = _drop_fn.append_basic_block("run.head");
    _run_body = _drop_fn.append_basic_block("run.body");
    b = ir.IRBuilder(_ck_body);
    _ck = b.load(_cur, name="ck");
    b.cbranch(
        b.icmp_unsigned("==", _ck, ir.Constant(i8p, None), name="ck.end"),
        _run_head,
        _ck_loop
    );
    b = ir.IRBuilder(_ck_loop);
    _prev = b.load(b.bitcast(_ck, i8pp, name="ck.prev.p"), name="ck.prev");
    _ck_rgn = b.ptrtoint(
        b.load(
            b.bitcast(
                b.gep(_ck, [ir.Constant(i64, 8)], name="ck.rgn.s"),
                i8pp,
                name="ck.rgn.p"
            ),
            name="ck.rgn"
        ),
        i64,
        name="ck.rgn.w"
    );
    _ck_runres = b.and_(_ck_rgn, ir.Constant(i64, 1), name="ck.runres");
    b.cbranch(
        b.icmp_unsigned("!=", _ck_runres, ir.Constant(i64, 0), name="ck.inrun"),
        _ck_next,
        _ck_free
    );
    b = ir.IRBuilder(_ck_free);
    b.call(_free, [_ck]);
    b.branch(_ck_next);
    b = ir.IRBuilder(_ck_next);
    b.store(_prev, _cur);
    b.branch(_ck_body);
    b = ir.IRBuilder(_run_head);
    _rn = b.load(
        b.bitcast(
            b.gep(_dhdl, [ir.Constant(i64, ARENA_RUNS_OFF)], name="run.s"),
            i8pp,
            name="run.p"
        ),
        name="run.h"
    );
    _rn_cur = b.alloca(i8p, name="run.cur");
    b.store(_rn, _rn_cur);
    _run_loop = _drop_fn.append_basic_block("run.loop");
    b.branch(_run_loop);
    b = ir.IRBuilder(_run_loop);
    _rn_c = b.load(_rn_cur, name="run.c");
    b.cbranch(
        b.icmp_unsigned("==", _rn_c, ir.Constant(i8p, None), name="run.end"),
        _md_head,
        _run_body
    );
    b = ir.IRBuilder(_run_body);
    _rn_nx = b.load(b.bitcast(_rn_c, i8pp, name="run.nx.p"), name="run.nx");
    b.call(_free, [_rn_c]);
    b.store(_rn_nx, _rn_cur);
    b.branch(_run_loop);
    b = ir.IRBuilder(_md_head);
    _md_m = b.load(_mrg, name="md.m");
    b.cbranch(
        b.icmp_unsigned("==", _md_m, ir.Constant(i8p, None), name="md.end"),
        _d_done,
        _md_body
    );
    b = ir.IRBuilder(_md_body);
    _md_next = b.load(
        b.bitcast(
            b.gep(_md_m, [ir.Constant(i64, 64)], name="md.nx.s"), i8pp, name="md.nx.p"
        ),
        name="md.nx"
    );
    if (_died_fn is not None) and (self._osp_ensure_fn is not None) {
        _md_argty = _died_fn.function_type.args[0];
        _md_i64 = b.ptrtoint(_md_m, i64, name="md.died.i64");
        if _md_argty != i64 {
            _md_i64 = b.bitcast(_md_i64, _md_argty, name="md.died.arg");
        }
        b.call(_died_fn, [_md_i64]);
    }
    b.call(_free, [b.gep(_md_m, [ir.Constant(i64, -HDR_TOTAL)], name="md.base")]);
    b.store(_md_next, _mrg);
    b.branch(_md_head);
    b = ir.IRBuilder(_d_done);
    _base_bb = _drop_fn.append_basic_block("free.base");
    _end_bb = _drop_fn.append_basic_block("end");
    b.cbranch(
        b.icmp_unsigned("==", _dhdl, ir.Constant(i8p, None), name="hdl.null2"),
        _end_bb,
        _base_bb
    );
    b = ir.IRBuilder(_base_bb);
    b.call(_free, [b.gep(_dhdl, [ir.Constant(i64, -HDR_TOTAL)], name="base")]);
    b.branch(_end_bb);
    b = ir.IRBuilder(_end_bb);
    b.ret_void();
    self.region_drop_fn = _drop_fn;

    _part_fn = self._define_function(
        "__jac_region_partition", ir.FunctionType(i8p, [i8p])
    );
    _part_fn.linkage = "private";
    _part_fn.args[0].name = "parent";
    b = ir.IRBuilder(_part_fn.append_basic_block("entry"));
    _pt_child = b.call(_new_fn, [], name="pt.child");
    b.store(
        _part_fn.args[0],
        b.bitcast(
            b.gep(_pt_child, [ir.Constant(i64, 40)], name="pt.par.s"),
            i8pp,
            name="pt.par.p"
        )
    );
    _pt_k_slot = b.bitcast(
        b.gep(_part_fn.args[0], [ir.Constant(i64, 48)], name="pt.k.s"),
        i64p,
        name="pt.k.p"
    );
    b.store(
        b.add(b.load(_pt_k_slot, name="pt.k"), ir.Constant(i64, 1), name="pt.k1"),
        _pt_k_slot
    );
    b.ret(_pt_child);
    self.region_partition_fn = _part_fn;

    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    _aa_fn = self._define_function(
        "__jac_osp_anchor_alloc", ir.FunctionType(i8p, [i8p, i64, i8p])
    );
    _aa_fn.linkage = "private";
    _aa_fn.args[0].name = "anchor";
    _aa_fn.args[1].name = "size";
    _aa_fn.args[2].name = "dtor";
    _aa_entry = _aa_fn.append_basic_block("entry");
    _aa_magic = _aa_fn.append_basic_block("check.magic");
    _aa_hdl = _aa_fn.append_basic_block("load.hdl");
    _aa_arena = _aa_fn.append_basic_block("arena");
    _aa_log = _aa_fn.append_basic_block("log.dtor");
    _aa_ret_a = _aa_fn.append_basic_block("ret.arena");
    _aa_managed = _aa_fn.append_basic_block("managed");
    b = ir.IRBuilder(_aa_entry);
    _anchor = _aa_fn.args[0];
    b.cbranch(
        b.icmp_unsigned("==", _anchor, ir.Constant(i8p, None), name="an.null"),
        _aa_managed,
        _aa_magic
    );
    b = ir.IRBuilder(_aa_magic);
    _aid = b.load(
        b.bitcast(
            b.gep(_anchor, [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name="an.aid.s"),
            i64p,
            name="an.aid.p"
        ),
        name="an.aid"
    );
    _hi = b.lshr(_aid, ir.Constant(i64, 32), name="an.hi");
    _hi = b.and_(_hi, ir.Constant(i64, 0xFFFF), name="an.hi.m");
    b.cbranch(
        b.icmp_unsigned("==", _hi, ir.Constant(i64, HDR_MAGIC + 1), name="an.arena"),
        _aa_hdl,
        _aa_managed
    );
    b = ir.IRBuilder(_aa_hdl);
    _hdl_i64 = b.load(
        b.bitcast(
            b.gep(_anchor, [ir.Constant(i64, HDR_DTOR_OFF)], name="an.hdl.s"),
            i64p,
            name="an.hdl.p"
        ),
        name="an.hdl.i64"
    );
    b.cbranch(
        b.icmp_unsigned("==", _hdl_i64, ir.Constant(i64, 0), name="an.hdl.null"),
        _aa_managed,
        _aa_arena
    );
    b = ir.IRBuilder(_aa_arena);
    _an_hdl = b.inttoptr(_hdl_i64, i8p, name="an.hdl");
    _an_obj = b.call(_alloc_fn, [_an_hdl, _aa_fn.args[1]], name="an.obj");
    b.cbranch(
        b.icmp_unsigned(
            "==", _aa_fn.args[2], ir.Constant(i8p, None), name="an.dtor.null"
        ),
        _aa_ret_a,
        _aa_log
    );
    b = ir.IRBuilder(_aa_log);
    b.call(_log_fn, [_an_hdl, _an_obj, _aa_fn.args[2]]);
    b.branch(_aa_ret_a);
    b = ir.IRBuilder(_aa_ret_a);
    b.ret(_an_obj);
    b = ir.IRBuilder(_aa_managed);
    b.ret(b.call(self.rc_alloc_fn, [_aa_fn.args[1]], name="an.rc"));
    self.osp_anchor_alloc_fn = _aa_fn;

    _rh_fn = self._define_function(
        "__jac_region_handle_of", ir.FunctionType(i64, [i8p])
    );
    _rh_fn.linkage = "private";
    _rh_fn.args[0].name = "obj";
    _rh_entry = _rh_fn.append_basic_block("entry");
    _rh_magic = _rh_fn.append_basic_block("check.magic");
    _rh_load = _rh_fn.append_basic_block("load.hdl");
    _rh_zero = _rh_fn.append_basic_block("zero");
    b = ir.IRBuilder(_rh_entry);
    _rh_obj = _rh_fn.args[0];
    b.cbranch(
        b.icmp_unsigned("==", _rh_obj, ir.Constant(i8p, None), name="rh.null"),
        _rh_zero,
        _rh_magic
    );
    b = ir.IRBuilder(_rh_magic);
    _rh_aid = b.load(
        b.bitcast(
            b.gep(_rh_obj, [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name="rh.aid.s"),
            i64p,
            name="rh.aid.p"
        ),
        name="rh.aid"
    );
    _rh_hi = b.lshr(_rh_aid, ir.Constant(i64, 32), name="rh.hi");
    _rh_hi = b.and_(_rh_hi, ir.Constant(i64, 0xFFFF), name="rh.hi.m");
    b.cbranch(
        b.icmp_unsigned("==", _rh_hi, ir.Constant(i64, HDR_MAGIC + 1), name="rh.arena"),
        _rh_load,
        _rh_zero
    );
    b = ir.IRBuilder(_rh_load);
    b.ret(
        b.load(
            b.bitcast(
                b.gep(_rh_obj, [ir.Constant(i64, HDR_DTOR_OFF)], name="rh.hdl.s"),
                i64p,
                name="rh.hdl.p"
            ),
            name="rh.hdl"
        )
    );
    b = ir.IRBuilder(_rh_zero);
    b.ret(ir.Constant(i64, 0));
    self.region_handle_of_fn = _rh_fn;
}


impl NaIRGenArena._try_partition_sugar_assign(nd: uni.Assignment) -> bool {
    if len(nd.target) != 1 or not isinstance(nd.target[0], uni.TupleVal) {
        return False;
    }
    _call = nd.value;
    if not isinstance(_call, uni.FuncCall) {
        return False;
    }
    _tr = _call.target;
    if not (
        isinstance(_tr, uni.AtomTrailer)
        and isinstance(_tr.right, uni.Name)
        and _tr.right.sym_name == "partition"
        and (_call.params or [])
    ) {
        return False;
    }
    _recv_nm = _tr.target;
    _recv_name = _recv_nm.sym_name if isinstance(_recv_nm, uni.Name) else None;
    if not (
        self._type_key_of(_tr.target) == "Region"
        or (_recv_name is not None and _recv_name in self.region_handle_vars)
    ) {
        return False;
    }
    self._emit_arena_helpers();
    _recv = self._codegen_expr(_tr.target);
    if _recv is None or self.region_partition_fn is None {
        return False;
    }
    _i8p = ir.IntType(8).as_pointer();
    if _recv.type != _i8p {
        _recv = self.builder.bitcast(_recv, _i8p, name="partn.hdl");
    }
    for tgt in nd.target[0].values {
        if not isinstance(tgt, uni.Name) {
            continue;
        }
        _child = self.builder.call(
            self.region_partition_fn, [_recv], name="region.partn"
        );
        _slot = self.local_vars.get(tgt.sym_name);
        if _slot is None {
            _slot = self._entry_alloca(_i8p, tgt.sym_name);
            self.local_vars[tgt.sym_name] = _slot;
        }
        self.builder.store(_child, _slot);
        self.region_handle_vars.add(tgt.sym_name);
    }
    return True;
}

impl NaIRGenArena._register_region_handle_var(
    nd: uni.Assignment, var_name: str
) -> None {
    _tgt = nd.target[0]
        if (len(nd.target) == 1 and isinstance(nd.target[0], uni.Name))
        else None;
    if _tgt is None or _tgt.sym is None or not _tgt.sym.na_region_handle {
        return;
    }
    self.region_handle_vars.add(var_name);
    if isinstance(nd.value, uni.Name)
        and nd.value.sym is not None
        and nd.value.sym.na_region_handle
        and nd.value.sym_name != var_name {
        self.region_handle_vars.discard(nd.value.sym_name);
    }
}

impl NaIRGenArena._region_alloc(
    size: ir.Value, name: str = "region.alloc"
) -> ir.Value {
    self._emit_arena_helpers();
    size = self._coerce_type(size, ir.IntType(64));
    self.rc_region_allocs += 1;
    return self.builder.call(
        self.region_alloc_fn, [self.region_stack[-1], size], name=name
    );
}

impl NaIRGenArena._region_log_dtor_if_needed(obj_i8: ir.Value, type_name: str) -> None {
    _fields_fn = self._emit_struct_drop_fields_fn(type_name);
    if _fields_fn is None {
        return;
    }
    self._emit_arena_helpers();
    _fn_i8 = self.builder.bitcast(
        _fields_fn, ir.IntType(8).as_pointer(), name="dtor.fn.i8"
    );
    self.builder.call(self.region_log_dtor_fn, [self.region_stack[-1], obj_i8, _fn_i8]);
}

impl NaIRGenArena._open_anon_region(gidx: int) -> None {
    self._emit_arena_helpers();
    if self.region_new_fn is None {
        return;
    }
    _i8p = ir.IntType(8).as_pointer();
    _arena = self.builder.call(self.region_new_fn, [], name="region.anon");
    _synth = f".region.anon.{gidx}";
    _slot = self._entry_alloca(_i8p, _synth);
    self.builder.store(_arena, _slot);
    self.local_vars[_synth] = _slot;
    self.region_handle_vars.add(_synth);
    self.region_stack.append(_arena);
    self.anon_region_active[gidx] = _synth;
}

impl NaIRGenArena._close_anon_region(gidx: int) -> None {
    _synth = self.anon_region_active.pop(gidx, None);
    if _synth is None {
        return;
    }
    if self.region_stack {
        self.region_stack.pop();
    }
    if self.builder.block.is_terminated {
        return;
    }
    _names = list(self.ir_in.anon_region_locals.get(gidx, []));
    self._emit_loop_iter_cleanup(_names, loc=f"anon.region.{gidx}");
    self._emit_region_handle_drop(self.local_vars[_synth], _synth);
}

impl NaIRGenArena._emit_region_handle_drop(alloca: object, var_name: str) -> None {
    self._emit_arena_helpers();
    _val = self.builder.load(alloca, name=f"region.drop.{var_name}");
    _i8p = ir.IntType(8).as_pointer();
    _cast = self.builder.bitcast(_val, _i8p, name=f"region.drop.{var_name}.i8");
    self.builder.call(self.region_drop_fn, [_cast]);
    self.builder.store(ir.Constant(alloca.type.pointee, None), alloca);
}

impl NaIRGenArena._emit_struct_drop_fields_fn(type_name: str) -> (ir.Function | None) {
    if type_name in self.struct_drop_fields_fns {
        return self.struct_drop_fields_fns[type_name];
    }
    struct_type = self.struct_types.get(type_name);
    if struct_type is None {
        return None;
    }
    _hook = self.struct_drop_hooks.get(type_name)
        or self.func_symtab.get(f"{type_name}.drop");
    field_types = self.struct_field_types.get(type_name, {});
    field_indices = self.struct_field_indices.get(type_name, {});
    foreign_fields = self.struct_field_foreign.get(type_name, set());
    _ptr_fields = [
        (fname, ftype)
        for (fname, ftype) in field_types.items()
        if fname not in foreign_fields
            and (
                isinstance(ftype, ir.PointerType)
                or self._opt_ptr_payload_of(ftype) is not None
            )
            and field_indices.get(fname, -1) >= 0
    ];
    if _hook is None and not _ptr_fields {
        return None;
    }
    if self.rc_release_simple_fn is None {
        self._emit_rc_helpers();
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    fnty = ir.FunctionType(ir.VoidType(), [i8p]);
    fn = ir.Function(self.llvm_module, fnty, name=f"__drop_fields_{type_name}");
    fn.linkage = "private";
    fn.args[0].name = "self";
    self.struct_drop_fields_fns[type_name] = fn;

    entry_bb = fn.append_basic_block("entry");
    body_bb = fn.append_basic_block("body");
    done_bb = fn.append_basic_block("done");
    b = ir.IRBuilder(entry_bb);
    is_null = b.icmp_unsigned(
        "==", fn.args[0], ir.Constant(i8p, None), name="dropf.null"
    );
    b.cbranch(is_null, done_bb, body_bb);

    b.position_at_end(body_bb);
    _dobj = b.bitcast(fn.args[0], struct_type.as_pointer(), name="dropf.obj");
    if _hook is not None {
        self.struct_drop_hooks[type_name] = _hook;
        b.call(_hook, [_dobj]);
    }
    for (fname, ftype) in _ptr_fields {
        idx = field_indices.get(fname, -1);
        fp = b.gep(
            _dobj, [ir.Constant(i32, 0), ir.Constant(i32, idx)], name=f"dropf.{fname}.p"
        );
        if self._opt_ptr_payload_of(ftype) is not None {
            fp = b.gep(
                fp,
                [ir.Constant(i32, 0), ir.Constant(i32, 1)],
                name=f"dropf.{fname}.pvp"
            );
            fv = b.load(fp, name=f"dropf.{fname}.pv");
            b.call(
                self.rc_release_simple_fn,
                [b.bitcast(fv, i8p, name=f"dropf.{fname}.pv.i8")]
            );
            continue;
        }
        fv = b.load(fp, name=f"dropf.{fname}");
        if isinstance(fv.type.pointee, ir.FunctionType) {
            continue;
        }
        fv_i8 = b.bitcast(fv, i8p, name=f"dropf.{fname}.i8");
        b.call(self.rc_release_simple_fn, [fv_i8]);
    }
    b.branch(done_bb);

    b.position_at_end(done_bb);
    b.ret_void();
    return fn;
}
