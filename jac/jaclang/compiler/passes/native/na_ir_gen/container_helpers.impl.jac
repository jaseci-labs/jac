impl NaIRGenContainerHelpers._elem_kind(elem_type: ir.Type) -> str {
    if self?.jacval_type and elem_type == self.jacval_type {
        return "jacval";
    }
    if isinstance(elem_type, ir.PointerType) {
        return "rc_ptr";
    }
    return "raw";
}

impl NaIRGenContainerHelpers._container_layout_dense(data_types: list) -> dict {
    _fields = [(_i + 2, _dt) for (_i, _dt) in enumerate(data_types)];
    return {
        "kind": "dense",
        "data_fields": _fields,
        "elem_kinds": [self._elem_kind(_dt) for _dt in data_types],
        "ctrl_idx": -1,
        "used_idx": -1,
        "order_idx": -1,
        "drop_base": 2 + len(data_types)
    };
}

impl NaIRGenContainerHelpers._container_layout_hash(
    key_type: ir.Type, val_type: (ir.Type | None)
) -> dict {
    _fields = [(2, key_type)];
    _kinds = [self._elem_kind(key_type)];
    _next = 3;
    if val_type is not None {
        _fields.append((3, val_type));
        _kinds.append(self._elem_kind(val_type));
        _next = 4;
    }
    return {
        "kind": "hash",
        "data_fields": _fields,
        "elem_kinds": _kinds,
        "ctrl_idx": _next,
        "used_idx": _next + 1,
        "order_idx": _next + 2,
        "drop_base": _next + 3
    };
}

impl NaIRGenContainerHelpers._emit_jacval_retain_fn -> ir.Function {
    return self._emit_jacval_rc_fn("__jacval_retain", True);
}

impl NaIRGenContainerHelpers._emit_jacval_release_fn -> ir.Function {
    return self._emit_jacval_rc_fn("__jacval_release", False);
}

impl NaIRGenContainerHelpers._emit_jacval_rc_fn(
    fn_name: str, is_retain: bool
) -> ir.Function {
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    i8p = i8.as_pointer();
    try {
        _existing = self.llvm_module.get_global(fn_name);
        if isinstance(_existing, ir.Function) and _existing.blocks {
            return _existing;
        }
        fn = _existing;
    } except KeyError {
        fnty = ir.FunctionType(ir.VoidType(), [self.jacval_type]);
        fn = ir.Function(self.llvm_module, fnty, name=fn_name);
        fn.linkage = "private";
    }
    fn.args[0].name = "jv";
    if self.rc_retain_fn is None or self.rc_release_simple_fn is None {
        self._emit_rc_helpers();
    }
    entry_bb = fn.append_basic_block("entry");
    act_bb = fn.append_basic_block("act");
    done_bb = fn.append_basic_block("done");
    b = ir.IRBuilder(entry_bb);
    tag = b.extract_value(fn.args[0], 0, name="jv.tag");
    payload = b.extract_value(fn.args[0], 1, name="jv.payload");
    is_heap = b.and_(
        b.icmp_unsigned(">=", tag, ir.Constant(i8, 2), name="jv.ge2"),
        b.icmp_unsigned("<=", tag, ir.Constant(i8, 6), name="jv.le6"),
        name="jv.heap"
    );
    nonnull = b.icmp_unsigned("!=", payload, ir.Constant(i64, 0), name="jv.nn");
    b.cbranch(b.and_(is_heap, nonnull, name="jv.live"), act_bb, done_bb);
    ba = ir.IRBuilder(act_bb);
    ptr = ba.inttoptr(payload, i8p, name="jv.ptr");
    if is_retain {
        ba.call(self.rc_retain_fn, [ptr]);
    } else {
        ba.call(self.rc_release_simple_fn, [ptr]);
    }
    ba.branch(done_bb);
    ir.IRBuilder(done_bb).ret_void();
    return fn;
}

impl NaIRGenContainerHelpers._emit_elem_retain(
    b: ir.IRBuilder, elem_type: ir.Type, val: ir.Value
) -> None {
    _kind = self._elem_kind(elem_type);
    if _kind == "raw" or self._nogc_headerless() {
        return;
    }
    if _kind == "jacval" {
        b.call(self._emit_jacval_retain_fn(), [val]);
        return;
    }
    if self.rc_retain_fn is None {
        self._emit_rc_helpers();
    }
    b.call(
        self.rc_retain_fn,
        [b.bitcast(val, ir.IntType(8).as_pointer(), name="elem.retain.cast")]
    );
}

impl NaIRGenContainerHelpers._emit_elem_release(
    b: ir.IRBuilder, elem_type: ir.Type, val: ir.Value
) -> None {
    _kind = self._elem_kind(elem_type);
    if _kind == "raw" or self._nogc_headerless() {
        return;
    }
    if _kind == "jacval" {
        b.call(self._emit_jacval_release_fn(), [val]);
        return;
    }
    if self.rc_release_simple_fn is None {
        self._emit_rc_helpers();
    }
    b.call(
        self.rc_release_simple_fn,
        [b.bitcast(val, ir.IntType(8).as_pointer(), name="elem.release.cast")]
    );
}

impl NaIRGenContainerHelpers._reject_ptr_into_raw_slot(
    nd: (uni.UniNode | None), value: ir.Value, elem_type: ir.Type, what: str
) -> bool {
    if not isinstance(value.type, ir.PointerType) {
        return False;
    }
    if isinstance(value.type.pointee, ir.FunctionType) {
        return False;
    }
    if self._elem_kind(elem_type) != "raw" {
        return False;
    }
    if not isinstance(elem_type, ir.IntType) or elem_type.width < 64 {
        return False;
    }
    if nd is not None {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name=what,
            help_text="A pointer value cannot be stored into a scalar container slot: the container would hold a raw address invisible to memory management. Declare the container with a matching element type, or mix element types so it lowers to tagged storage."
        );
    } else {
        self.emit(E5092, kind="expression", name=what);
    }
    return True;
}

impl NaIRGenContainerHelpers._spread_operand(
    nd: (uni.UniNode | None)
) -> (uni.Expr | None) {
    if isinstance(nd, uni.UnaryExpr)
        and isinstance(nd.op, uni.Token)
        and nd.op.name == Tok.STAR_MUL {
        return nd.operand;
    }
    return None;
}

impl NaIRGenContainerHelpers._container_src_info(
    val: (ir.Value | None)
) -> (dict | None) {
    if val is None or not isinstance(val.type, ir.PointerType) {
        return None;
    }
    for (_lspec, _ltype) in self.list_types.items() {
        if _ltype.as_pointer() == val.type {
            _lhelpers = self.list_helpers.get(_lspec);
            if _lhelpers is not None {
                return {
                    "kind": "list",
                    "spec": _lspec,
                    "helpers": _lhelpers,
                    "value": val
                };
            }
        }
    }
    for (_sspec, _stype) in self.set_types.items() {
        if _stype.as_pointer() == val.type {
            _shelpers = self.set_helpers.get(_sspec);
            if _shelpers is not None {
                return {
                    "kind": "set",
                    "spec": _sspec,
                    "helpers": _shelpers,
                    "value": val
                };
            }
        }
    }
    return None;
}

impl NaIRGenContainerHelpers._spread_elem_storage(
    src_info: dict, operand: (uni.Expr | None)
) -> (ir.Type | None) {
    _erased = src_info["helpers"]["elem_type"];
    if src_info["kind"] != "list" or src_info["spec"] != "ptr" {
        return _erased;
    }
    _static = self._static_elem_llvm_of(operand);
    if _static is None {
        return None;
    }
    if isinstance(_static, ir.PointerType)
        and isinstance(_static.pointee, ir.LiteralStructType) {
        return _static;
    }
    return _erased;
}

impl NaIRGenContainerHelpers._reject_spread_slot_mismatch(
    nd: (uni.UniNode | None), src_elem: ir.Type, dest_elem: ir.Type, what: str
) -> bool {
    if src_elem == dest_elem {
        return False;
    }
    if isinstance(src_elem, ir.PointerType)
        and self._reject_ptr_into_raw_slot(
            nd, ir.Constant(src_elem, None), dest_elem, what
        ) {
        return True;
    }
    if self?.jacval_type
        and (src_elem == self.jacval_type or dest_elem == self.jacval_type) {
        return False;
    }
    _numeric = (ir.IntType, ir.DoubleType, ir.FloatType);
    if isinstance(src_elem, _numeric) and isinstance(dest_elem, _numeric) {
        return False;
    }
    if isinstance(src_elem, ir.PointerType) and isinstance(dest_elem, ir.PointerType) {
        return False;
    }
    self.emit(
        E5092,
        node_override=nd,
        kind="expression",
        name=what,
        help_text="A spread copies the source's elements into the display's own storage, so the two element types have to share a representation. Give the spread source the display's element type, or write the elements out."
    );
    return True;
}

impl NaIRGenContainerHelpers._emit_spread_copy(
    src: ir.Value,
    src_helpers: dict,
    dest: ir.Value,
    dest_helpers: dict,
    dest_kind: str,
    loc: str
) -> None {
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    _fn = self.builder.function;
    _loop_bb = _fn.append_basic_block("spread.loop");
    _body_bb = _fn.append_basic_block("spread.body");
    _done_bb = _fn.append_basic_block("spread.done");
    _len = self.builder.call(src_helpers["len"], [src], name="spread.len");
    _pre_bb = self.builder.block;
    self.builder.branch(_loop_bb);

    self._builder = ir.IRBuilder(_loop_bb);
    _idx = self.builder.phi(i64, name="spread.i");
    _idx.add_incoming(ir.Constant(i64, 0), _pre_bb);
    self.builder.cbranch(
        self.builder.icmp_unsigned(">=", _idx, _len, name="spread.atend"),
        _done_bb,
        _body_bb
    );

    self._builder = ir.IRBuilder(_body_bb);
    _elem = self.builder.call(src_helpers["get"], [src, _idx], name="spread.elem");
    _dest_elem = dest_helpers["elem_type"];
    if isinstance(_elem.type, ir.PointerType) and _dest_elem == i8p {
        _elem = self.builder.bitcast(_elem, i8p, name="spread.elem.cast");
    } else {
        _elem = self._coerce_type(_elem, _dest_elem);
    }
    if dest_kind == "set" {
        self._rc_call_with_ctx(
            dest_helpers["add"], [dest, _elem], op="set_init", loc=loc
        );
    } else {
        self._rc_call_with_ctx(
            dest_helpers["append"], [dest, _elem], op="list_init", loc=loc
        );
    }
    _next = self.builder.add(_idx, ir.Constant(i64, 1), name="spread.i1");
    _idx.add_incoming(_next, self.builder.block);
    self.builder.branch(_loop_bb);

    self._builder = ir.IRBuilder(_done_bb);
    if isinstance(src.type, ir.PointerType)
        and self._is_owned(src)
        and self._gc_mode() != "none" {
        self._emit_rc_release_simple(src, op="spread", loc=loc);
    }
}

impl NaIRGenContainerHelpers._container_managed_fields(layout: dict) -> list {
    _kinds = layout["elem_kinds"];
    return [
        (fi, dt, _kinds[_j])
        for (_j, (fi, dt)) in enumerate(layout["data_fields"])
        if _kinds[_j] != "raw"
    ];
}

impl NaIRGenContainerHelpers._container_struct_fields(layout: dict) -> list {
    i64 = ir.IntType(64);
    _fields = [i64, i64];
    for (_, _dt) in layout["data_fields"] {
        _fields.append(_dt.as_pointer());
    }
    if layout["kind"] == "hash" {
        _fields.append(ir.IntType(8).as_pointer());
        _fields.append(i64);
        _fields.append(i64.as_pointer());
    }
    if self._gc_mode() == "none" {
        for _ in range(len(layout["data_fields"])) {
            _fields.append(self._nogc_elem_drop_slot_ty());
        }
    }
    return _fields;
}

impl NaIRGenContainerHelpers._emit_live_slot_loop(
    fn: ir.Function,
    b: ir.IRBuilder,
    cont: ir.Value,
    layout: dict,
    tag: str,
    body_cb: object,
    fields: (list | None) = None
) -> ir.IRBuilder {
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    _is_hash = layout["kind"] == "hash";
    _fields = fields if fields is not None else layout["data_fields"];
    _arrs = [];
    for (_fi, _) in _fields {
        _arrs.append(
            b.load(
                b.gep(
                    cont,
                    [ir.Constant(i32, 0), ir.Constant(i32, _fi)],
                    name=f"{tag}.d{_fi}.p"
                ),
                name=f"{tag}.d{_fi}"
            )
        );
    }
    _bound_field = 1 if _is_hash else 0;
    _bound = b.load(
        b.gep(
            cont,
            [ir.Constant(i32, 0), ir.Constant(i32, _bound_field)],
            name=f"{tag}.bound.p"
        ),
        name=f"{tag}.bound"
    );
    _ctrl = None;
    if _is_hash {
        _ctrl = b.load(
            b.gep(
                cont,
                [ir.Constant(i32, 0), ir.Constant(i32, layout["ctrl_idx"])],
                name=f"{tag}.ctrl.p"
            ),
            name=f"{tag}.ctrl"
        );
    }
    _iv = b.alloca(i64, name=f"{tag}.i");
    b.store(ir.Constant(i64, 0), _iv);
    _cond_bb = fn.append_basic_block(f"{tag}.cond");
    _live_bb = fn.append_basic_block(f"{tag}.live");
    _next_bb = fn.append_basic_block(f"{tag}.next");
    _end_bb = fn.append_basic_block(f"{tag}.end");
    b.branch(_cond_bb);
    bc = ir.IRBuilder(_cond_bb);
    _i = bc.load(_iv, name=f"{tag}.iv");
    if _is_hash {
        _chk_bb = fn.append_basic_block(f"{tag}.chk");
        bc.cbranch(
            bc.icmp_unsigned(">=", _i, _bound, name=f"{tag}.done"), _end_bb, _chk_bb
        );
        bk = ir.IRBuilder(_chk_bb);
        _cb = bk.load(bk.gep(_ctrl, [_i], name=f"{tag}.cb.p"), name=f"{tag}.cb");
        bk.cbranch(
            bk.icmp_unsigned(">=", _cb, ir.Constant(i8, 0x80), name=f"{tag}.occ"),
            _live_bb,
            _next_bb
        );
    } else {
        bc.cbranch(
            bc.icmp_unsigned("<", _i, _bound, name=f"{tag}.more"), _live_bb, _end_bb
        );
    }
    bl = ir.IRBuilder(_live_bb);
    _elem_ptrs = [
        bl.gep(_arr, [_i], name=f"{tag}.e{_k}.p") for (_k, _arr) in enumerate(_arrs)
    ];
    bl = body_cb(bl, _i, _elem_ptrs);
    bl.branch(_next_bb);
    bn = ir.IRBuilder(_next_bb);
    bn.store(bn.add(_i, ir.Constant(i64, 1), name=f"{tag}.inc"), _iv);
    bn.branch(_cond_bb);
    return ir.IRBuilder(_end_bb);
}

impl NaIRGenContainerHelpers._emit_container_new_fn(
    fn_name: str, container_ptr_type: ir.Type, layout: dict, dtor_fn: object = None
) -> ir.Function {
    new_fnty = ir.FunctionType(container_ptr_type, []);
    new_fn = ir.Function(self.llvm_module, new_fnty, name=fn_name);
    new_fn.linkage = "private";
    bb = new_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    result = self._emit_rc_alloc_container(b, container_ptr_type, layout);
    container_ptr = result[0];

    if self._gc_mode() == "none" {
        _i32_nz = ir.IntType(32);
        _slot_ty_nz = self._nogc_elem_drop_slot_ty();
        for _j in range(len(layout["data_fields"])) {
            _slot_p_nz = b.gep(
                container_ptr,
                [
                    ir.Constant(_i32_nz, 0),
                    ir.Constant(_i32_nz, layout["drop_base"] + _j)
                ],
                name=f"edrop{_j}.init"
            );
            b.store(ir.Constant(_slot_ty_nz, None), _slot_p_nz);
        }
    }

    if self._nogc_headerless() {
        dtor_fn = None;
    }
    if dtor_fn is not None and self.rc_set_type_fn is not None {
        _dtor_name = dtor_fn?.name or str(dtor_fn);
        _type_name = _dtor_name[len("__rc_release_"):]
            if _dtor_name.startswith("__rc_release_")
            else "container";
        _cont_raw_i8 = b.bitcast(
            container_ptr, ir.IntType(8).as_pointer(), name="new.i8"
        );
        self._emit_set_type_tag(b, _cont_raw_i8, _type_name);
    }

    if dtor_fn is not None {
        _i8p_n = ir.IntType(8).as_pointer();
        _i64_n = ir.IntType(64);
        _i64p_n = _i64_n.as_pointer();
        _raw_n = b.bitcast(container_ptr, _i8p_n, name="new_raw");
        _dtor_slot_n = b.gep(
            _raw_n, [ir.Constant(_i64_n, HDR_DTOR_OFF)], name="dtor_slot"
        );
        _dtor_slot_i64_n = b.bitcast(_dtor_slot_n, _i64p_n, name="dtor_slot_i64");
        _dtor_i64_n = b.ptrtoint(dtor_fn, _i64_n, name="dtor_i64");
        b.store(_dtor_i64_n, _dtor_slot_i64_n);
    }

    _managed_fields = self._container_managed_fields(layout);
    _cont_type_name = self._container_type_name(dtor_fn);
    _cont_has_trace = False;
    if _managed_fields and self._gc_mode() == "cycles" {
        _cont_trace_fn = self._emit_container_trace_fn(
            f"__rc_trace_{_cont_type_name}", container_ptr_type, layout
        );
        _cont_has_trace = self._register_trace_pair(dtor_fn, _cont_trace_fn);
    }
    self._require_trace_fn(_cont_type_name, bool(_managed_fields), _cont_has_trace);
    b.ret(container_ptr);
    return new_fn;
}

impl NaIRGenContainerHelpers._container_type_name(dtor_fn: object) -> str {
    if dtor_fn is None {
        return "container";
    }
    _dtor_name = dtor_fn?.name or str(dtor_fn);
    if _dtor_name.startswith("__rc_release_") {
        return _dtor_name[len("__rc_release_"):];
    }
    return "container";
}

impl NaIRGenContainerHelpers._emit_container_trace_fn(
    trace_fn_name: str, container_ptr_type: ir.Type, layout: dict
) -> ir.Function {
    i8_ptr = ir.IntType(8).as_pointer();
    visitor_ptype = ir.FunctionType(ir.VoidType(), [i8_ptr]).as_pointer();
    trace_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr, i8_ptr]);

    try {
        _existing = self.llvm_module.get_global(trace_fn_name);
        if isinstance(_existing, ir.Function) and not _existing.blocks {
            trace_fn = _existing;
            trace_fn.linkage = "private";
        } else {
            trace_fn = ir.Function(self.llvm_module, trace_fnty, name=trace_fn_name);
            trace_fn.linkage = "private";
        }
    } except KeyError {
        trace_fn = ir.Function(self.llvm_module, trace_fnty, name=trace_fn_name);
        trace_fn.linkage = "private";
    }
    trace_fn.args[0].name = "obj";
    trace_fn.args[1].name = "vis";

    entry_bb = trace_fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb);
    _vis = b.bitcast(trace_fn.args[1], visitor_ptype, name="vis.fn");
    _cont = b.bitcast(trace_fn.args[0], container_ptr_type, name="cont.typed");
    _managed = self._container_managed_fields(layout);
    _fields = [(fi, dt) for (fi, dt, _k) in _managed];
    _kinds = [_k for (fi, dt, _k) in _managed];

    def _visit_slot(bl: ir.IRBuilder, i: ir.Value, elem_ptrs: list) -> ir.IRBuilder {
        i8 = ir.IntType(8);
        i64 = ir.IntType(64);
        for (_j, _ep) in enumerate(elem_ptrs) {
            _elem = bl.load(_ep, name="elem.val");
            if _kinds[_j] == "jacval" {
                _tag = bl.extract_value(_elem, 0, name="elem.jv.tag");
                _pl = bl.extract_value(_elem, 1, name="elem.jv.payload");
                _heap = bl.and_(
                    bl.icmp_unsigned(
                        ">=", _tag, ir.Constant(i8, 2), name="elem.jv.ge2"
                    ),
                    bl.icmp_unsigned(
                        "<=", _tag, ir.Constant(i8, 6), name="elem.jv.le6"
                    ),
                    name="elem.jv.heap"
                );
                _nn = bl.icmp_unsigned(
                    "!=", _pl, ir.Constant(i64, 0), name="elem.jv.nn"
                );
                _vis_bb = trace_fn.append_basic_block("trace.jv.vis");
                _skip_bb = trace_fn.append_basic_block("trace.jv.skip");
                bl.cbranch(bl.and_(_heap, _nn, name="elem.jv.live"), _vis_bb, _skip_bb);
                bv = ir.IRBuilder(_vis_bb);
                bv.call(_vis, [bv.inttoptr(_pl, i8_ptr, name="elem.jv.i8")]);
                bv.branch(_skip_bb);
                bl = ir.IRBuilder(_skip_bb);
            } else {
                bl.call(_vis, [bl.bitcast(_elem, i8_ptr, name="elem.i8")]);
            }
        }
        return bl;
    }
    b = self._emit_live_slot_loop(
        trace_fn, b, _cont, layout, "trace", _visit_slot, fields=_fields
    );
    b.ret_void();
    return trace_fn;
}

impl NaIRGenContainerHelpers._emit_container_len_fn(
    fn_name: str, container_ptr_type: ir.Type
) -> ir.Function {
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    len_fnty = ir.FunctionType(i64, [container_ptr_type]);
    len_fn = ir.Function(self.llvm_module, len_fnty, name=fn_name);
    len_fn.linkage = "private";
    len_fn.args[0].name = "container";
    bb = len_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    lp = b.gep(
        len_fn.args[0], [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr"
    );
    b.ret(b.load(lp, name="len"));
    return len_fn;
}

impl NaIRGenContainerHelpers._emit_container_release_fn(
    fn_name: str, container_ptr_type: ir.Type, layout: dict
) -> ir.Function {
    i32 = ir.IntType(32);
    i8_ptr = ir.IntType(8).as_pointer();
    release_fnty = ir.FunctionType(ir.VoidType(), [container_ptr_type]);

    try {
        _existing_fn = self.llvm_module.get_global(fn_name);
        if isinstance(_existing_fn, ir.Function) and not _existing_fn.blocks {
            release_fn = _existing_fn;
            release_fn.linkage = "private";
        } else {
            release_fn = ir.Function(self.llvm_module, release_fnty, name=fn_name);
            release_fn.linkage = "private";
        }
    } except KeyError {
        release_fn = ir.Function(self.llvm_module, release_fnty, name=fn_name);
        release_fn.linkage = "private";
    }
    release_fn.args[0].name = "container";
    i8 = ir.IntType(8);
    (b, done_bb) = self._emit_rc_destructor_preamble(release_fn, container_ptr_type);
    if self.rc_safe_free_fn is None or self.rc_release_simple_fn is None {
        self._emit_rc_helpers();
    }
    cont_arg = release_fn.args[0];
    _managed = self._container_managed_fields(layout);
    _fields = [(fi, dt) for (fi, dt, _k) in _managed];
    _kinds = [_k for (fi, dt, _k) in _managed];
    if _managed {
        _cycles_on = self._gc_mode() == "cycles";
        if _cycles_on and self.rc_collecting_gv is None {
            self._emit_rc_helpers();
        }
        rel_elems_bb = release_fn.append_basic_block("release_elems");
        post_elems_bb = release_fn.append_basic_block("post_elems");
        if _cycles_on {
            _cont_coll = b.load(self.rc_collecting_gv, name="cont.collecting");
            b.cbranch(
                b.icmp_unsigned(
                    "!=", _cont_coll, ir.Constant(i8, 0), name="cont.mid.coll"
                ),
                post_elems_bb,
                rel_elems_bb
            );
        } else {
            b.branch(rel_elems_bb);
        }
        b = ir.IRBuilder(rel_elems_bb);

        def _release_slot(
            bl: ir.IRBuilder, i: ir.Value, elem_ptrs: list
        ) -> ir.IRBuilder {
            for (_j, _ep) in enumerate(elem_ptrs) {
                _ev = bl.load(_ep, name="elem.val.rel");
                if _kinds[_j] == "jacval" {
                    bl.call(self._emit_jacval_release_fn(), [_ev]);
                } else {
                    bl.call(
                        self.rc_release_simple_fn,
                        [bl.bitcast(_ev, i8_ptr, name="elem.cast.rel")]
                    );
                }
            }
            return bl;
        }
        b = self._emit_live_slot_loop(
            release_fn, b, cont_arg, layout, "rel", _release_slot, fields=_fields
        );
        b.branch(post_elems_bb);
        b = ir.IRBuilder(post_elems_bb);
    }
    for (field_idx, _) in layout["data_fields"] {
        data_p = b.gep(
            cont_arg,
            [ir.Constant(i32, 0), ir.Constant(i32, field_idx)],
            name=f"data{field_idx}.ptr.f"
        );
        data_f = b.load(data_p, name=f"data{field_idx}.f");
        b.call(
            self.rc_safe_free_fn,
            [b.bitcast(data_f, i8_ptr, name=f"data{field_idx}.cast")]
        );
    }
    if layout["kind"] == "hash" {
        _ctrl_f = b.load(
            b.gep(
                cont_arg,
                [ir.Constant(i32, 0), ir.Constant(i32, layout["ctrl_idx"])],
                name="ctrl.ptr.f"
            ),
            name="ctrl.f"
        );
        b.call(self.rc_safe_free_fn, [_ctrl_f]);
        _order_f = b.load(
            b.gep(
                cont_arg,
                [ir.Constant(i32, 0), ir.Constant(i32, layout["order_idx"])],
                name="order.ptr.f"
            ),
            name="order.f"
        );
        b.call(self.rc_safe_free_fn, [b.bitcast(_order_f, i8_ptr, name="order.cast")]);
    }

    self._emit_release_header_free(release_fn, b, done_bb);
    return release_fn;
}

impl NaIRGenContainerHelpers._emit_release_header_free(
    release_fn: ir.Function, b: ir.IRBuilder, done_bb: ir.Block
) -> None {
    if self.rc_alloc_fn is None or self.rc_safe_free_fn is None {
        self._emit_rc_helpers();
    }
    _i8pc = ir.IntType(8).as_pointer();
    _i64c = ir.IntType(64);
    _i64_ptr_c = _i64c.as_pointer();
    _cont_i8 = b.bitcast(release_fn.args[0], _i8pc, name="cont.i8");
    _cont_raw = b.gep(
        _cont_i8, [ir.Constant(_i64c, HDR_ALLOC_ID_OFF)], name="cont.raw"
    );

    _cl_aid_ptr = b.bitcast(_cont_raw, _i64_ptr_c, name="cl.aid.ptr");
    _cl_aid_raw = b.load(_cl_aid_ptr, name="cl.aid.raw");
    _cl_aid = b.and_(_cl_aid_raw, ir.Constant(_i64c, 4294967295), name="cl.aid");
    _cl_tag_raw = b.gep(_cont_i8, [ir.Constant(_i64c, HDR_TAG_OFF)], name="cl.tag.raw");
    _cl_tag_pp = b.bitcast(_cl_tag_raw, _i8pc.as_pointer(), name="cl.tag.pp");
    _cl_tag = b.load(_cl_tag_pp, name="cl.tag");
    log_free_cont_bb = release_fn.append_basic_block("log_free_cont");
    actual_free_cont_bb = release_fn.append_basic_block("actual_free_cont");
    self._emit_live_list_remove(
        b, _cont_i8, _i8pc, _i64_ptr_c, log_free_cont_bb, log_free_cont_bb
    );
    self._emit_struct_free_log(
        release_fn,
        log_free_cont_bb,
        actual_free_cont_bb,
        _cont_i8,
        _cont_raw,
        _cl_aid,
        _cl_tag
    );
    b = ir.IRBuilder(actual_free_cont_bb);
    b.call(self.rc_safe_free_fn, [_cont_raw]);
    b.branch(done_bb);
    b = ir.IRBuilder(done_bb);
    b.ret_void();
}

impl NaIRGenContainerHelpers._emit_array_get_fn(
    fn_name: str, container_ptr_type: ir.Type, elem_type: ir.Type, data_field_idx: int
) -> ir.Function {
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    get_fnty = ir.FunctionType(elem_type, [container_ptr_type, i64]);
    get_fn = ir.Function(self.llvm_module, get_fnty, name=fn_name);
    get_fn.linkage = "private";
    get_fn.args[0].name = "container";
    get_fn.args[1].name = "index";
    bb = get_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    dp = b.gep(
        get_fn.args[0],
        [ir.Constant(i32, 0), ir.Constant(i32, data_field_idx)],
        name="data.ptr"
    );
    d = b.load(dp, name="data");
    ep = b.gep(d, [get_fn.args[1]], name="elem.ptr");
    b.ret(b.load(ep, name="elem"));
    return get_fn;
}

impl NaIRGenContainerHelpers._emit_key_comparison(
    b: ir.IRBuilder,
    key_type: ir.Type,
    stored_val: ir.Value,
    search_val: ir.Value,
    key_size: int = 0
) -> ir.Value {
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    if isinstance(key_type, ir.IntType) {
        return b.icmp_signed("==", stored_val, search_val, name="key.eq");
    } elif self._is_bytes_type(key_type) {
        _i32 = ir.IntType(32);
        _z0 = ir.Constant(_i32, 0);
        _z1 = ir.Constant(_i32, 1);
        llen = b.load(
            b.gep(stored_val, [_z0, _z0], name="key.by.llp"), name="key.by.ll"
        );
        rlen = b.load(
            b.gep(search_val, [_z0, _z0], name="key.by.rlp"), name="key.by.rl"
        );
        ldata = b.bitcast(
            b.gep(stored_val, [_z0, _z1], name="key.by.ldp"), i8_ptr, name="key.by.ld"
        );
        rdata = b.bitcast(
            b.gep(search_val, [_z0, _z1], name="key.by.rdp"), i8_ptr, name="key.by.rd"
        );
        minlen = b.select(
            b.icmp_signed("<", llen, rlen, name="key.by.lt"),
            llen,
            rlen,
            name="key.by.min"
        );
        memcmp_fn = self._get_or_declare_extern("memcmp", _i32, [i8_ptr, i8_ptr, i64]);
        cmpr = b.call(memcmp_fn, [ldata, rdata, minlen], name="key.by.cmp");
        len_eq = b.icmp_signed("==", llen, rlen, name="key.by.leneq");
        data_eq = b.icmp_signed("==", cmpr, _z0, name="key.by.dataeq");
        return b.and_(len_eq, data_eq, name="key.by.eq");
    } elif key_type == i8_ptr {
        cmp_result = self._call_str_cmp(b, stored_val, search_val, name="strcmp");
        return b.icmp_signed(
            "==", cmp_result, ir.Constant(ir.IntType(32), 0), name="key.eq"
        );
    } elif (
        isinstance(key_type, ir.PointerType)
        and key_size > 0
        and self._tuple_key_fields(key_type) is not None
    ) {
        _eq: any = None;
        for (_fi, _fk) in self._tuple_key_fields(key_type) {
            _sv = self._tuple_key_field_val(b, stored_val, _fi, _fk);
            _qv = self._tuple_key_field_val(b, search_val, _fi, _fk);
            if _fk == "str" or _fk == "jacstr" {
                _c = self._call_str_cmp(b, _sv, _qv, name=f"tk.sc{_fi}");
                _e = b.icmp_signed(
                    "==", _c, ir.Constant(ir.IntType(32), 0), name=f"tk.seq{_fi}"
                );
            } elif _fk == "f64" {
                _e = b.fcmp_ordered("==", _sv, _qv, name=f"tk.feq{_fi}");
            } elif _fk == "ptr" {
                _e = b.icmp_unsigned("==", _sv, _qv, name=f"tk.peq{_fi}");
            } else {
                _e = b.icmp_signed("==", _sv, _qv, name=f"tk.ieq{_fi}");
            }
            _eq = _e if _eq is None else b.and_(_eq, _e, name=f"tk.eq{_fi}");
        }
        return _eq;
    } elif isinstance(key_type, ir.PointerType) and key_size > 0 {
        memcmp_fn = self._get_or_declare_extern(
            "memcmp", ir.IntType(32), [i8_ptr, i8_ptr, i64]
        );
        key_i8 = b.bitcast(stored_val, i8_ptr, name="key.i8");
        arg_i8 = b.bitcast(search_val, i8_ptr, name="arg.i8");
        cmp_result = b.call(
            memcmp_fn, [key_i8, arg_i8, ir.Constant(i64, key_size)], name="memcmp"
        );
        return b.icmp_signed(
            "==", cmp_result, ir.Constant(ir.IntType(32), 0), name="key.eq"
        );
    } elif isinstance(key_type, ir.PointerType) {
        return b.icmp_unsigned("==", stored_val, search_val, name="key.eq");
    } elif isinstance(key_type, ir.DoubleType) {
        return b.fcmp_ordered("==", stored_val, search_val, name="key.eq");
    } else {
        return b.icmp_signed("==", stored_val, search_val, name="key.eq");
    }
}

impl NaIRGenContainerHelpers._emit_rc_alloc_container(
    b: ir.IRBuilder, container_ptr_type: ir.Type, layout: dict, initial_cap: int = 8
) -> tuple {
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    i8_ptr = ir.IntType(8).as_pointer();
    malloc_fn = self._get_or_declare_extern("malloc", i8_ptr, [i64]);

    null_ptr = ir.Constant(container_ptr_type, None);
    size_gep = b.gep(null_ptr, [ir.Constant(i32, 1)], name="sizeof");
    struct_size = b.ptrtoint(size_gep, i64, name="size");
    if self._nogc_headerless() {
        raw = b.call(malloc_fn, [struct_size], name="raw");
    } else {
        raw = b.call(self.rc_alloc_fn, [struct_size], name="raw");
    }
    container_ptr = b.bitcast(raw, container_ptr_type, name="container");

    len_p = b.gep(
        container_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr"
    );
    b.store(ir.Constant(i64, 0), len_p);

    cap_p = b.gep(
        container_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cap.ptr"
    );
    b.store(ir.Constant(i64, initial_cap), cap_p);

    data_ptrs = [];
    for (i, fpair) in enumerate(layout["data_fields"]) {
        (field_idx, dtype) = fpair;
        elem_null = ir.Constant(dtype.as_pointer(), None);
        elem_gep = b.gep(elem_null, [ir.Constant(i32, 1)], name=f"elem{i}.sizeof");
        elem_size = b.ptrtoint(elem_gep, i64, name=f"elem{i}.size");
        data_bytes = b.mul(
            ir.Constant(i64, initial_cap), elem_size, name=f"data{i}.bytes"
        );
        data_raw = b.call(malloc_fn, [data_bytes], name=f"data{i}.raw");
        data = b.bitcast(data_raw, dtype.as_pointer(), name=f"data{i}");
        data_p = b.gep(
            container_ptr,
            [ir.Constant(i32, 0), ir.Constant(i32, field_idx)],
            name=f"data{i}.ptr"
        );
        b.store(data, data_p);
        data_ptrs.append(data);
    }
    if layout["kind"] == "hash" {
        calloc_fn = self._get_or_declare_extern("calloc", i8_ptr, [i64, i64]);
        _ctrl0 = b.call(
            calloc_fn,
            [ir.Constant(i64, initial_cap), ir.Constant(i64, 1)],
            name="ctrl0"
        );
        b.store(
            _ctrl0,
            b.gep(
                container_ptr,
                [ir.Constant(i32, 0), ir.Constant(i32, layout["ctrl_idx"])],
                name="ctrl.ptr"
            )
        );
        b.store(
            ir.Constant(i64, 0),
            b.gep(
                container_ptr,
                [ir.Constant(i32, 0), ir.Constant(i32, layout["used_idx"])],
                name="used.ptr"
            )
        );
        _ord0 = b.call(malloc_fn, [ir.Constant(i64, initial_cap * 8)], name="order0");
        b.store(
            b.bitcast(_ord0, i64.as_pointer(), name="order0.p"),
            b.gep(
                container_ptr,
                [ir.Constant(i32, 0), ir.Constant(i32, layout["order_idx"])],
                name="order.ptr"
            )
        );
    }
    return tuple([container_ptr] + data_ptrs);
}

impl NaIRGenContainerHelpers._emit_grow_array(
    b: ir.IRBuilder,
    arr_ptr: ir.Value,
    elem_type: ir.Type,
    cur_len: ir.Value,
    cap_ptr: ir.Value,
    cur_cap: ir.Value
) -> ir.Value {
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    i8_ptr = ir.IntType(8).as_pointer();
    malloc_fn = self._get_or_declare_extern("malloc", i8_ptr, [i64]);
    free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8_ptr]);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8_ptr, [i8_ptr, i8_ptr, i64]);
    new_cap = b.mul(cur_cap, ir.Constant(i64, 2), name="new.cap");
    b.store(new_cap, cap_ptr);
    elem_null = ir.Constant(elem_type.as_pointer(), None);
    elem_gep = b.gep(elem_null, [ir.Constant(i32, 1)], name="elem.sizeof");
    elem_sz = b.ptrtoint(elem_gep, i64, name="elem.size");
    new_bytes = b.mul(new_cap, elem_sz, name="new.bytes");
    new_data_raw = b.call(malloc_fn, [new_bytes], name="new.data.raw");
    new_data = b.bitcast(new_data_raw, elem_type.as_pointer(), name="new.data");
    old_data = b.load(arr_ptr, name="old.data");
    old_bytes = b.mul(cur_len, elem_sz, name="old.bytes");
    old_i8 = b.bitcast(old_data, i8_ptr, name="old.i8");
    new_i8 = b.bitcast(new_data, i8_ptr, name="new.i8");
    b.call(memcpy_fn, [new_i8, old_i8, old_bytes]);
    if self._nogc_headerless() {
        _free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8_ptr]);
        b.call(_free_fn, [old_i8]);
    } else {
        if self.rc_safe_free_fn is None {
            self._emit_rc_helpers();
        }
        b.call(self.rc_safe_free_fn, [old_i8]);
    }
    b.store(new_data, arr_ptr);
    return new_data;
}

impl NaIRGenContainerHelpers._emit_rc_destructor_preamble(
    release_fn: ir.Function, ptr_type: ir.Type
) -> tuple {
    i8_ptr = ir.IntType(8).as_pointer();
    entry_bb = release_fn.append_basic_block("entry");
    free_bb = release_fn.append_basic_block("do_free");
    done_bb = release_fn.append_basic_block("done");
    b = ir.IRBuilder(entry_bb);

    is_null = b.icmp_unsigned(
        "==", release_fn.args[0], ir.Constant(ptr_type, None), name="is.null"
    );
    b.cbranch(is_null, done_bb, free_bb);

    free_builder = ir.IRBuilder(free_bb);
    return (free_builder, done_bb);
}

impl NaIRGenContainerHelpers._tuple_box_release_fn(
    struct_type: ir.LiteralStructType
) -> (ir.Function | None) {
    key = str(struct_type);
    _cached = self.tuple_release_fns.get(key);
    if _cached is not None {
        return _cached;
    }
    if self.rc_release_simple_fn is None or self.rc_safe_free_fn is None {
        self._emit_rc_helpers();
    }
    if self.rc_release_simple_fn is None or self.rc_safe_free_fn is None {
        return None;
    }
    i8 = ir.IntType(8);
    i8_ptr = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    struct_ptr_type = struct_type.as_pointer();
    release_fn = ir.Function(
        self.llvm_module,
        ir.FunctionType(ir.VoidType(), [struct_ptr_type]),
        name=f"__rc_release_tuple{len(self.tuple_release_fns)}"
    );
    release_fn.linkage = "private";
    release_fn.args[0].name = "tup";
    self.tuple_release_fns[key] = release_fn;

    (b, done_bb) = self._emit_rc_destructor_preamble(release_fn, struct_ptr_type);
    fields = self._tuple_managed_fields(struct_type);
    if fields {
        _cycles_on = self._gc_mode() == "cycles";
        if _cycles_on and self.rc_collecting_gv is None {
            self._emit_rc_helpers();
        }
        rel_bb = release_fn.append_basic_block("release_fields");
        post_bb = release_fn.append_basic_block("post_fields");
        if _cycles_on {
            _coll = b.load(self.rc_collecting_gv, name="tup.collecting");
            b.cbranch(
                b.icmp_unsigned("!=", _coll, ir.Constant(i8, 0), name="tup.mid.coll"),
                post_bb,
                rel_bb
            );
        } else {
            b.branch(rel_bb);
        }
        b = ir.IRBuilder(rel_bb);
        for (idx, is_opt) in fields {
            fptr = b.gep(
                release_fn.args[0],
                [ir.Constant(i32, 0), ir.Constant(i32, idx)],
                name=f"tup.f{idx}.p"
            );
            if is_opt {
                fptr = b.gep(
                    fptr,
                    [ir.Constant(i32, 0), ir.Constant(i32, 1)],
                    name=f"tup.f{idx}.pvp"
                );
            }
            fval = b.load(fptr, name=f"tup.f{idx}");
            self._emit_elem_release(b, fval.type, fval);
        }
        b.branch(post_bb);
        b = ir.IRBuilder(post_bb);
    }
    tup_i8 = b.bitcast(release_fn.args[0], i8_ptr, name="tup.i8");
    tup_raw = b.gep(tup_i8, [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name="tup.raw");
    free_bb = release_fn.append_basic_block("tup_free");
    self._emit_live_list_remove(b, tup_i8, i8_ptr, i64_ptr, free_bb, free_bb);
    b = ir.IRBuilder(free_bb);
    b.call(self.rc_safe_free_fn, [tup_raw]);
    b.branch(done_bb);
    b = ir.IRBuilder(done_bb);
    b.ret_void();
    return release_fn;
}

impl NaIRGenContainerHelpers._tuple_box_trace_fn(
    struct_type: ir.LiteralStructType
) -> (ir.Function | None) {
    if self._gc_mode() != "cycles" {
        return None;
    }
    key = str(struct_type);
    _cached = self.tuple_trace_fns.get(key);
    if _cached is not None {
        return _cached;
    }
    fields = self._tuple_managed_fields(struct_type);
    if not fields {
        return None;
    }
    i8_ptr = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    visitor_ptype = ir.FunctionType(ir.VoidType(), [i8_ptr]).as_pointer();
    trace_fn = ir.Function(
        self.llvm_module,
        ir.FunctionType(ir.VoidType(), [i8_ptr, i8_ptr]),
        name=f"__rc_trace_tuple{len(self.tuple_trace_fns)}"
    );
    trace_fn.linkage = "private";
    trace_fn.args[0].name = "obj";
    trace_fn.args[1].name = "vis";
    self.tuple_trace_fns[key] = trace_fn;

    entry_bb = trace_fn.append_basic_block("entry");
    done_bb = trace_fn.append_basic_block("done");
    b = ir.IRBuilder(entry_bb);
    _vis = b.bitcast(trace_fn.args[1], visitor_ptype, name="vis.fn");
    _obj = b.bitcast(trace_fn.args[0], struct_type.as_pointer(), name="obj.typed");
    for (idx, is_opt) in fields {
        fptr = b.gep(
            _obj, [ir.Constant(i32, 0), ir.Constant(i32, idx)], name=f"tr.f{idx}.p"
        );
        if is_opt {
            fptr = b.gep(
                fptr, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name=f"tr.f{idx}.pvp"
            );
        }
        fval = b.load(fptr, name=f"tr.f{idx}");
        b.call(_vis, [b.bitcast(fval, i8_ptr, name=f"tr.f{idx}.i8")]);
    }
    b.branch(done_bb);
    b = ir.IRBuilder(done_bb);
    b.ret_void();
    return trace_fn;
}

impl NaIRGenContainerHelpers._emit_tuple_box_lifecycle(
    raw: ir.Value, struct_type: ir.LiteralStructType
) -> None {
    rel_fn = self._tuple_box_release_fn(struct_type);
    if rel_fn is None {
        return;
    }
    i64 = ir.IntType(64);
    slot = self.builder.gep(
        raw, [ir.Constant(i64, HDR_DTOR_OFF)], name="tuple.dtor.slot"
    );
    slot_p = self.builder.bitcast(slot, i64.as_pointer(), name="tuple.dtor.p");
    self.builder.store(
        self.builder.ptrtoint(rel_fn, i64, name="tuple.dtor.i64"), slot_p
    );
    trace_fn = self._tuple_box_trace_fn(struct_type);
    has_trace = False;
    if trace_fn is not None {
        has_trace = self._register_trace_pair(rel_fn, trace_fn);
    }
    self._require_trace_fn("tuple", True, has_trace);
}
