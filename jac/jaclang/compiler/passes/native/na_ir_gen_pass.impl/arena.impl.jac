glob ARENA_CTRL_SIZE: int = 40,
     ARENA_CHUNK_HDR: int = 16,
     ARENA_CHUNK_DEFAULT: int = 32768,
     ARENA_DTOR_ENTRY: int = 24;

impl NaIRGenPass._emit_arena_helpers -> None {
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
    for (_off, _nm) in ((8, "off"), (16, "cap"), (32, "cnt")) {
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

    b = ir.IRBuilder(_grow);
    _want = b.add(_size, ir.Constant(i64, ARENA_CHUNK_HDR + 15), name="want.pad");
    _want = b.and_(_want, ir.Constant(i64, -16), name="want");
    _small = b.icmp_unsigned(
        "<", _want, ir.Constant(i64, ARENA_CHUNK_DEFAULT), name="small"
    );
    _csize = b.select(
        _small, ir.Constant(i64, ARENA_CHUNK_DEFAULT), _want, name="csize"
    );
    _chunk = b.call(_malloc, [_csize], name="chunk");
    b.store(_chunk0, b.bitcast(_chunk, i8pp, name="chunk.prev.p"));
    b.store(
        _hdl,
        b.bitcast(
            b.gep(_chunk, [ir.Constant(i64, 8)], name="chunk.rgn.s"),
            i8pp,
            name="chunk.rgn.p"
        )
    );
    b.store(_chunk, _chunk_slot);
    b.store(ir.Constant(i64, ARENA_CHUNK_HDR), _off_slot);
    b.store(_csize, _cap_slot);
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
    _d_body = _drop_fn.append_basic_block("body");
    _dt_head = _drop_fn.append_basic_block("dtor.head");
    _dt_body = _drop_fn.append_basic_block("dtor.body");
    _ck_head = _drop_fn.append_basic_block("chunk.head");
    _ck_body = _drop_fn.append_basic_block("chunk.body");
    _d_done = _drop_fn.append_basic_block("done");
    b = ir.IRBuilder(_d_entry);
    _dhdl = _drop_fn.args[0];
    b.cbranch(
        b.icmp_unsigned("==", _dhdl, ir.Constant(i8p, None), name="hdl.null"),
        _d_done,
        _d_body
    );
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
    b = ir.IRBuilder(_ck_body);
    _ck = b.load(_cur, name="ck");
    b.cbranch(
        b.icmp_unsigned("==", _ck, ir.Constant(i8p, None), name="ck.end"),
        _d_done,
        _ck_loop
    );
    b = ir.IRBuilder(_ck_loop);
    _prev = b.load(b.bitcast(_ck, i8pp, name="ck.prev.p"), name="ck.prev");
    b.call(_free, [_ck]);
    b.store(_prev, _cur);
    b.branch(_ck_body);
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


impl NaIRGenPass._register_region_handle_var(
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

impl NaIRGenPass._region_alloc(size: ir.Value, name: str = "region.alloc") -> ir.Value {
    self._emit_arena_helpers();
    size = self._coerce_type(size, ir.IntType(64));
    self.rc_region_allocs += 1;
    return self.builder.call(
        self.region_alloc_fn, [self.region_stack[-1], size], name=name
    );
}

impl NaIRGenPass._region_log_dtor_if_needed(obj_i8: ir.Value, type_name: str) -> None {
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

impl NaIRGenPass._emit_region_handle_drop(alloca: object, var_name: str) -> None {
    self._emit_arena_helpers();
    _val = self.builder.load(alloca, name=f"region.drop.{var_name}");
    _i8p = ir.IntType(8).as_pointer();
    _cast = self.builder.bitcast(_val, _i8p, name=f"region.drop.{var_name}.i8");
    self.builder.call(self.region_drop_fn, [_cast]);
    self.builder.store(ir.Constant(alloca.type.pointee, None), alloca);
}

impl NaIRGenPass._emit_struct_drop_fields_fn(type_name: str) -> (ir.Function | None) {
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
    opaque_fields = self.struct_field_opaque.get(type_name, set());
    _ptr_fields = [
        (fname, ftype)
        for (fname, ftype) in field_types.items()
        if fname not in opaque_fields
        and isinstance(ftype, ir.PointerType)
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
