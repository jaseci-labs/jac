impl NaIRGenPass._peer_dict_key -> (str | None) {
    """Dict layout an empty display should adopt from the operand beside it.

    Set only where one branch's container answers for the other's: a ternary
    arm and the right operand of `or`/`and`. An empty `{}` has no entries to
    infer from, so `h.tbl or {}` would otherwise pick its own flavour, and
    the phi would erase both branches to `i8*`.
    """;
    _pt = self._peer_container_ty;
    if _pt is None or not isinstance(_pt, ir.PointerType) {
        return None;
    }
    for (_spec, _dt) in self.dict_types.items() {
        if _dt.as_pointer() == _pt {
            return _spec;
        }
    }
    return None;
}

impl NaIRGenPass._unwrap_opt_container(val: ir.Value) -> ir.Value {
    _pay = self._opt_payload_of(val.type);
    if _pay is None or not isinstance(_pay, ir.PointerType) {
        return val;
    }
    return self._coerce_type(val, _pay);
}

impl NaIRGenPass._dict_val_spec(val_type: ir.Type) -> str {
    if isinstance(val_type, ir.DoubleType) {
        return "f64";
    }
    if self?.jacval_type and val_type == self.jacval_type {
        return "jacval";
    }
    if isinstance(val_type, ir.PointerType) {
        _pointee = val_type.pointee;
        if isinstance(_pointee, ir.IdentifiedStructType) and _pointee.name {
            return "ptr_" + str(_pointee.name).replace(".", "_");
        }
        return "ptr";
    }
    if isinstance(val_type, ir.IntType) and val_type.width != 64 {
        return f"i{val_type.width}";
    }
    return "i64";
}

impl NaIRGenPass._emit_dict_helpers(
    key_type_name: str,
    val_type_name: str,
    key_type: ir.Type,
    val_type: ir.Type,
    key_size: int = 0
) -> None {
    dict_key = f"{key_type_name}:{val_type_name}";

    if dict_key in self.dict_helpers {
        return;
    }

    if val_type_name == "ptr" and isinstance(val_type, ir.PointerType) {
        val_type = ir.IntType(8).as_pointer();
    }

    _key_sz: int = int(key_size);
    if _key_sz == 0 and isinstance(key_type, ir.PointerType) {
        _pointee = key_type?.pointee;
        if _pointee is not None and isinstance(_pointee, ir.LiteralStructType) {
            _key_sz = self._get_struct_size(_pointee);
        }
    }

    _safe = dict_key.replace(":", "_");
    _struct_name = f"Dict.{key_type_name}.{val_type_name}";
    layout = self._container_layout_hash(key_type, val_type);
    dict_struct = self.llvm_module.context.get_identified_type(_struct_name);
    if not dict_struct.elements {
        dict_struct.set_body(*self._container_struct_fields(layout));
    }
    self.dict_types[dict_key] = dict_struct;
    self.container_layouts[_struct_name] = layout;
    dict_ptr_type = dict_struct.as_pointer();

    _rel_fn_decl = None;
    _rel_fn_name = f"__rc_release_dict_{_safe}";
    if not self._nogc_headerless() {
        _rel_fnty = ir.FunctionType(ir.VoidType(), [dict_ptr_type]);
        try {
            _found = self.llvm_module.get_global(_rel_fn_name);
            _rel_fn_decl = _found if isinstance(_found, ir.Function) else None;
        } except KeyError {
            _rel_fn_decl = ir.Function(self.llvm_module, _rel_fnty, name=_rel_fn_name);
            _rel_fn_decl.linkage = "private";
        }
    }

    new_fn = self._emit_container_new_fn(
        f"__dict_new_{_safe}", dict_ptr_type, layout, dtor_fn=_rel_fn_decl
    );

    core = self._emit_hash_core_helpers(
        "dict",
        dict_key,
        dict_ptr_type,
        key_type,
        val_type,
        key_type_name,
        _key_sz,
        layout
    );

    len_fn = self._emit_container_len_fn(f"__dict_len_{_safe}", dict_ptr_type);

    if self._nogc_headerless() {
        self._emit_container_drop_fn(_struct_name);
    } else {
        release_fn = self._emit_container_release_fn(
            _rel_fn_name, dict_ptr_type, layout
        );
        self.dict_release_fns[dict_key] = release_fn;
    }

    self.dict_helpers[dict_key] = {
        "new": new_fn,
        "set": core["insert"],
        "set_ph": core["insert_ph"],
        "get": core["get"],
        "get_ph": core["get_ph"],
        "lookup": core["lookup"],
        "len": len_fn,
        "contains": core["contains"],
        "contains_ph": core["contains_ph"],
        "get_key": core["get_key"],
        "get_val": core["get_val"],
        "remove": core["remove"],
        "remove_ph": core["remove_ph"],
        "pop": core["pop"],
        "pop_ph": core["pop_ph"],
        "find": core["find"],
        "clear": core["clear"],
        "key_type": key_type,
        "val_type": val_type
    };
}

impl NaIRGenPass._box_to_jacval(value: ir.Value) -> ir.Value {
    value = self._str_norm(value);
    if self.jacval_type is not None and value.type == self.jacval_type {
        return value;
    }
    b = self.builder;
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    tag: ir.Value = ir.Constant(i8, 8);
    payload: ir.Value = ir.Constant(i64, 0);
    if isinstance(value.type, ir.IntType) and value.type.width == 1 {
        tag = ir.Constant(i8, 7);
        payload = b.zext(value, i64, name="jv.bext");
    } elif isinstance(value.type, ir.IntType) {
        tag = ir.Constant(i8, 0);
        if value.type.width == 64 {
            payload = value;
        } elif value?.jac_signed {
            payload = b.sext(value, i64, name="jv.iext");
        } else {
            payload = b.zext(value, i64, name="jv.iext");
        }
    } elif isinstance(value.type, ir.DoubleType) {
        tag = ir.Constant(i8, 1);
        payload = b.bitcast(value, i64, name="jv.f2i");
    } elif isinstance(value.type, ir.PointerType) {
        payload = b.ptrtoint(value, i64, name="jv.p2i");
        tag = b.select(
            b.icmp_unsigned("==", payload, ir.Constant(i64, 0), name="jv.isnone"),
            ir.Constant(i8, 8),
            ir.Constant(i8, self._jacval_pointer_tag(value.type)),
            name="jv.nonetag"
        );
    } elif self._opt_payload_of(value.type) is not None {
        inner = self._box_to_jacval(b.extract_value(value, 1, name="jv.optpay"));
        absent = b.icmp_unsigned(
            "==",
            b.extract_value(value, 0, name="jv.optflag"),
            ir.Constant(i8, 0),
            name="jv.opt.isnone"
        );
        tag = b.select(
            absent,
            ir.Constant(i8, 8),
            b.extract_value(inner, 0, name="jv.opt.itag"),
            name="jv.opt.tag"
        );
        payload = b.select(
            absent,
            ir.Constant(i64, 0),
            b.extract_value(inner, 1, name="jv.opt.ipay"),
            name="jv.opt.pay"
        );
    } elif not isinstance(value.type, ir.VoidType) {
        self.emit(E5092, kind="expression", name=f"`any` box of {value.type}");
        tag = ir.Constant(i8, 0);
    }
    boxed = b.insert_value(
        ir.Constant(self.jacval_type, None), tag, 0, name="jacval.tag"
    );
    return b.insert_value(boxed, payload, 1, name="jacval");
}

impl NaIRGenPass._ellipsis_jacval -> (ir.Value | None) {
    if not self?.jacval_type {
        return None;
    }
    return ir.Constant(
        self.jacval_type,
        [
            ir.Constant(ir.IntType(8), JACVAL_ELLIPSIS_TAG),
            ir.Constant(ir.IntType(64), 0)
        ]
    );
}

impl NaIRGenPass._jacval_pointer_tag(pointer_type: ir.Type) -> int {
    for (families, tag) in (
        (self.list_types, 3),
        (self.dict_types, 4),
        (self.set_types, 5),
        (self.struct_types, 6)
    ) {
        for family in families.values() {
            if pointer_type == family.as_pointer() {
                return tag;
            }
        }
    }
    return 2;
}

impl NaIRGenPass._unbox_from_jacval(jv: ir.Value, target_type: ir.Type) -> ir.Value {
    b = self.builder;
    i64 = ir.IntType(64);
    payload = b.extract_value(jv, 1, name="jv.unbox.payload");
    if isinstance(target_type, ir.IntType) {
        if target_type.width == 64 {
            return payload;
        }
        if target_type.width == 1 {
            return b.icmp_unsigned(
                "!=", payload, ir.Constant(i64, 0), name="jv.unbox.bool"
            );
        }
        return b.trunc(payload, target_type, name="jv.unbox.itrunc");
    }
    if isinstance(target_type, ir.DoubleType) {
        return b.bitcast(payload, target_type, name="jv.unbox.f");
    }
    if isinstance(target_type, ir.FloatType) {
        _d = b.bitcast(payload, ir.DoubleType(), name="jv.unbox.f64");
        return b.fptrunc(_d, target_type, name="jv.unbox.f32");
    }
    if isinstance(target_type, ir.PointerType) {
        _viewed = self._unbox_any_container(jv, target_type);
        if _viewed is not None {
            return _viewed;
        }
        return b.inttoptr(payload, target_type, name="jv.unbox.p");
    }

    self.emit(E5092, kind="expression", name=f"`any` unbox to {target_type}");
    return ir.Constant(target_type, None);
}

impl NaIRGenPass._any_view_target(target_type: ir.Type) -> (tuple[str, str] | None) {
    """The container-of-`any` family a pointer unbox target names, if any.

    `("list", "")` for `list[any]`, `("dict", K)` for a `dict[K, any]` whose
    keys hash as spec `K`. Those are the targets whose element slots hold
    boxed values, so a typed container arriving through `any` cannot be
    reinterpreted as one: its slots hold raw payloads.
    """;
    if not self?.jacval_type or not isinstance(target_type, ir.PointerType) {
        return None;
    }
    _lt = self.list_types.get("jacval");
    if _lt is not None and target_type == _lt.as_pointer() {
        return ("list", "");
    }
    for (_dk, _dt) in self.dict_types.items() {
        if _dk.endswith(":jacval") and target_type == _dt.as_pointer() {
            return ("dict", _dk[:-len(":jacval")]);
        }
    }
    return None;
}

impl NaIRGenPass._unbox_any_container(
    jv: ir.Value, target_type: ir.Type
) -> (ir.Value | None) {
    """Unbox an `any` into a container of `any`, converting a typed one.

    The box records only the heap kind, so a `dict[str, int]` passed as
    `any` and narrowed to `dict[str, any]` would otherwise be read with its
    `i64` slots taken for boxed values. `_any_view_fn` reads the allocation
    header's type tag instead: a container already of the target family is
    returned as is, a typed one is copied into a fresh container of the
    target family with every element boxed, and one it cannot convert is a
    `TypeError`. The copy is parked in a hidden local of the current
    function, released when that local is overwritten or at scope exit, so
    the result stays a borrow like every other unbox. A headerless build has
    no tag to read and refuses the site.
    """;
    if self._any_view_target(target_type) is None {
        return None;
    }
    if self._nogc_headerless() {
        self.emit(
            E5092,
            kind="expression",
            name=f"`any` unbox to {target_type}",
            help_text="A container reaching a container of `any` through `any` is converted by reading its allocation header's type tag, and a headerless build has none. Annotate the value with its concrete container type instead."
        );
        return None;
    }
    _fn = self._any_view_fn(target_type);
    if _fn is None {
        return None;
    }
    b = self.builder;
    _res = b.call(_fn, [jv], name="jv.view");
    _payload = b.extract_value(jv, 1, name="jv.view.payload");
    if not self._binding_function_active() {
        return _res;
    }
    _null = ir.Constant(target_type, None);
    _failed = b.and_(
        b.icmp_unsigned("==", _res, _null, name="jv.view.null"),
        b.icmp_unsigned(
            "!=", _payload, ir.Constant(ir.IntType(64), 0), name="jv.view.some"
        ),
        name="jv.view.failed"
    );
    self._emit_runtime_raise(
        _failed,
        "TypeError",
        "container elements cannot be viewed as any: unsupported element or key type"
    );
    b = self.builder;
    _raw = b.inttoptr(_payload, target_type, name="jv.view.raw");
    _fresh = b.icmp_unsigned("!=", _res, _raw, name="jv.view.fresh");
    _name = f"any.view.{self._loop_coll_seq}";
    self._loop_coll_seq += 1;
    _slot = self._entry_alloca(target_type, _name);
    self.local_vars[_name] = _slot;
    self._emit_rc_release_typed(
        self.builder.load(_slot, name=f"{_name}.old"), op="any_view"
    );
    self.builder.store(
        self.builder.select(_fresh, _res, _null, name=f"{_name}.keep"), _slot
    );
    return _res;
}

impl NaIRGenPass._binding_function_active -> bool {
    """Do the current bindings belong to the function being emitted into?

    False while a helper body is built on a swapped builder: a hidden local
    registered then would be an alloca of the helper that the enclosing
    function's scope exit loads.
    """;
    if self._builder is None {
        return False;
    }
    _fn = self.builder.function;
    for _slot in self.local_vars.values() {
        _blk = _slot?.parent;
        if isinstance(_blk, ir.Block) {
            return _blk.parent is _fn;
        }
    }
    return False;
}

impl NaIRGenPass._heap_ref_jacval_tag_fn -> ir.Function {
    """`__jac_heap_ref_jvtag(p)`: the `any` tag a bare heap reference boxes to.

    A container whose slots are plain pointers (`list[str]`,
    `list[list[int]]`, `dict[str, Item]`) has erased which heap kind each
    slot holds, so boxing one of its elements reads the kind back out of the
    allocation header's type tag, the stamp `isinstance` reads. Null is
    None; a string without an allocated header is `str`.
    """;
    _name = "__jac_heap_ref_jvtag";
    _cached = self.extern_funcs.get(_name);
    if _cached is not None {
        return _cached;
    }
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = i8.as_pointer();
    fn = ir.Function(self.llvm_module, ir.FunctionType(i8, [i8p]), name=_name);
    fn.linkage = "private";
    fn.args[0].name = "p";
    self.extern_funcs[_name] = fn;
    _p = fn.args[0];
    b = ir.IRBuilder(fn.append_basic_block("entry"));
    _none_bb = fn.append_basic_block("none");
    _hdr_bb = fn.append_basic_block("hdr");
    _tag_bb = fn.append_basic_block("tag");
    _str_bb = fn.append_basic_block("str");
    _obj_bb = fn.append_basic_block("obj");
    b.cbranch(b.icmp_unsigned("==", _p, ir.Constant(i8p, None)), _none_bb, _hdr_bb);
    ir.IRBuilder(_none_bb).ret(ir.Constant(i8, 8));
    ir.IRBuilder(_str_bb).ret(ir.Constant(i8, 2));
    ir.IRBuilder(_obj_bb).ret(ir.Constant(i8, 6));
    bh = ir.IRBuilder(_hdr_bb);
    bh.cbranch(self._emit_magic_check(bh, _p, name_prefix="hrt.mc"), _tag_bb, _str_bb);
    bt = ir.IRBuilder(_tag_bb);
    _tag = bt.load(
        bt.bitcast(
            bt.gep(_p, [ir.Constant(i64, HDR_TAG_OFF)], name="hrt.tag.slot"),
            i8p.as_pointer()
        ),
        name="hrt.tag"
    );
    _cmp_bb = fn.append_basic_block("cmp");
    bt.cbranch(bt.icmp_unsigned("==", _tag, ir.Constant(i8p, None)), _str_bb, _cmp_bb);
    bc = ir.IRBuilder(_cmp_bb);
    strncmp = self._get_or_declare_extern("strncmp", i32, [i8p, i8p, i64]);
    strcmp = self._get_or_declare_extern("strcmp", i32, [i8p, i8p]);
    for (_text, _exact, _jt) in (
        ("list_", False, 3),
        ("dict_", False, 4),
        ("set_", False, 5),
        ("str", True, 2),
        ("bytes", True, 2)
    ) {
        _lit = bc.gep(
            self._get_snprintf_fmt(_text),
            [ir.Constant(i32, 0), ir.Constant(i32, 0)],
            name="hrt.lit"
        );
        _res = bc.call(strcmp, [_tag, _lit], name="hrt.cmp")
            if _exact
            else bc.call(
                strncmp, [_tag, _lit, ir.Constant(i64, len(_text))], name="hrt.cmp"
            );
        _hit_bb = fn.append_basic_block(f"hit.{_jt}");
        _next_bb = fn.append_basic_block("next");
        bc.cbranch(bc.icmp_signed("==", _res, ir.Constant(i32, 0)), _hit_bb, _next_bb);
        ir.IRBuilder(_hit_bb).ret(ir.Constant(i8, _jt));
        bc = ir.IRBuilder(_next_bb);
    }
    bc.branch(_obj_bb);
    return fn;
}

impl NaIRGenPass._any_view_fn(target_type: ir.Type) -> (ir.Function | None) {
    """`__jac_any_view_<family>(jv)`: a boxed container as the target family.

    Returns the payload unchanged when it is not a live container the header
    can speak for (None, a scalar, no tag) or already is the target family;
    a fresh, owned copy with each element boxed when its tag names a typed
    family of the same kind (and, for a dict, the same key spec), or when it
    is an empty container of the kind whatever its family; null when it
    names anything else. Element slots of a pointer family box through
    `__jac_heap_ref_jvtag`, since the slot type no longer says which heap
    kind it holds.
    """;
    _tgt = self._any_view_target(target_type);
    if _tgt is None {
        return None;
    }
    (kind, key_spec) = _tgt;
    _tgt_tag = "list_jacval" if kind == "list" else f"dict_{key_spec}_jacval";
    _name = f"__jac_any_view_{_tgt_tag}";
    _cached = self.extern_funcs.get(_name);
    if _cached is not None {
        return _cached;
    }
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = i8.as_pointer();
    _scalars: list[tuple[str, ir.Type]] = [
        ("i64", i64),
        ("f64", ir.DoubleType()),
        ("ptr", i8p)
    ];
    _sources: list[tuple[str, bool, str, dict[str, any], ir.Type]] = [];
    if kind == "list" {
        self._emit_list_helpers("jacval", self.jacval_type);
        _dst_h = self.list_helpers["jacval"];
        for (_spec, _et) in _scalars {
            self._emit_list_helpers(_spec, _et);
            _sources.append(
                (
                    f"list_{_spec}",
                    True,
                    _spec,
                    self.list_helpers[_spec],
                    self.list_types[_spec].as_pointer()
                )
            );
        }
    } else {
        _dst_h = self.dict_helpers[f"{key_spec}:jacval"];
        _key_type = _dst_h["key_type"];
        _key_size = self._hash_key_spec(_key_type)[1];
        for (_spec, _vt) in _scalars + [("i1", ir.IntType(1))] {
            self._emit_dict_helpers(key_spec, _spec, _key_type, _vt, _key_size);
            _sources.append(
                (
                    f"dict_{key_spec}_{_spec}",
                    _spec != "ptr",
                    _spec,
                    self.dict_helpers[f"{key_spec}:{_spec}"],
                    self.dict_types[f"{key_spec}:{_spec}"].as_pointer()
                )
            );
        }
    }
    _tag_fn = self._heap_ref_jacval_tag_fn();
    strcmp = self._get_or_declare_extern("strcmp", i32, [i8p, i8p]);
    strncmp = self._get_or_declare_extern("strncmp", i32, [i8p, i8p, i64]);
    fn = ir.Function(
        self.llvm_module, ir.FunctionType(target_type, [self.jacval_type]), name=_name
    );
    fn.linkage = "private";
    fn.args[0].name = "jv";
    self.extern_funcs[_name] = fn;
    b = ir.IRBuilder(fn.append_basic_block("entry"));
    _jtag = b.extract_value(fn.args[0], 0, name="view.jtag");
    _payload = b.extract_value(fn.args[0], 1, name="view.payload");
    _raw = b.inttoptr(_payload, i8p, name="view.raw");
    _as_is = b.inttoptr(_payload, target_type, name="view.as_is");
    _heap = b.or_(
        b.icmp_unsigned("==", _jtag, ir.Constant(i8, 3)),
        b.or_(
            b.icmp_unsigned("==", _jtag, ir.Constant(i8, 4)),
            b.icmp_unsigned("==", _jtag, ir.Constant(i8, 5))
        ),
        name="view.heap"
    );
    _as_is_bb = fn.append_basic_block("as_is");
    _hdr_bb = fn.append_basic_block("hdr");
    b.cbranch(
        b.and_(
            _heap,
            b.icmp_unsigned("!=", _payload, ir.Constant(i64, 0)),
            name="view.inspect"
        ),
        _hdr_bb,
        _as_is_bb
    );
    ir.IRBuilder(_as_is_bb).ret(_as_is);
    bh = ir.IRBuilder(_hdr_bb);
    _tag_bb = fn.append_basic_block("tag");
    bh.cbranch(
        self._emit_magic_check(bh, _raw, name_prefix="view.mc"), _tag_bb, _as_is_bb
    );
    bt = ir.IRBuilder(_tag_bb);
    _tag = bt.load(
        bt.bitcast(
            bt.gep(_raw, [ir.Constant(i64, HDR_TAG_OFF)], name="view.tag.slot"),
            i8p.as_pointer()
        ),
        name="view.tag"
    );
    _cmp_bb = fn.append_basic_block("cmp");
    bt.cbranch(
        bt.icmp_unsigned("==", _tag, ir.Constant(i8p, None)), _as_is_bb, _cmp_bb
    );
    bc = ir.IRBuilder(_cmp_bb);

    def _tag_is(bl: ir.IRBuilder, text: str, exact: bool) -> ir.Value {
        _lit = bl.gep(
            self._get_snprintf_fmt(text),
            [ir.Constant(i32, 0), ir.Constant(i32, 0)],
            name="view.lit"
        );
        _r = bl.call(strcmp, [_tag, _lit], name="view.cmp")
            if exact
            else bl.call(
                strncmp, [_tag, _lit, ir.Constant(i64, len(text))], name="view.cmp"
            );
        return bl.icmp_signed("==", _r, ir.Constant(i32, 0));
    }
    _next_bb = fn.append_basic_block("next");
    bc.cbranch(_tag_is(bc, _tgt_tag, True), _as_is_bb, _next_bb);
    bc = ir.IRBuilder(_next_bb);
    _empty_bb = fn.append_basic_block("empty");
    _next_bb = fn.append_basic_block("next");
    bc.cbranch(
        bc.and_(
            _tag_is(bc, f"{kind}_", False),
            bc.icmp_signed(
                "==",
                bc.load(bc.bitcast(_raw, i64.as_pointer()), name="view.len0"),
                ir.Constant(i64, 0)
            ),
            name="view.empty"
        ),
        _empty_bb,
        _next_bb
    );
    be = ir.IRBuilder(_empty_bb);
    be.ret(be.call(_dst_h["new"], [], name="view.fresh"));
    bc = ir.IRBuilder(_next_bb);
    _saved = self._builder;
    for (_text, _exact, _spec, _src_h, _src_ty) in _sources {
        _conv_bb = fn.append_basic_block(f"from.{_spec}");
        _next_bb = fn.append_basic_block("next");
        bc.cbranch(_tag_is(bc, _text, _exact), _conv_bb, _next_bb);
        bc = ir.IRBuilder(_next_bb);
        bv = ir.IRBuilder(_conv_bb);
        _src = bv.bitcast(_raw, _src_ty, name="view.src");
        _out = bv.call(_dst_h["new"], [], name="view.out");
        _n = bv.call(_src_h["len"], [_src], name="view.len");
        _loop_bb = fn.append_basic_block(f"loop.{_spec}");
        _body_bb = fn.append_basic_block(f"body.{_spec}");
        _done_bb = fn.append_basic_block(f"done.{_spec}");
        _pre_bb = bv.block;
        bv.branch(_loop_bb);
        bl = ir.IRBuilder(_loop_bb);
        _i = bl.phi(i64, name="view.i");
        _i.add_incoming(ir.Constant(i64, 0), _pre_bb);
        bl.cbranch(bl.icmp_signed("<", _i, _n, name="view.more"), _body_bb, _done_bb);
        bb = ir.IRBuilder(_body_bb);
        _elem = bb.call(
            _src_h["get_val" if kind == "dict" else "get"], [_src, _i], name="view.elem"
        );
        self._builder = bb;
        _boxed = self._box_to_jacval(_elem);
        bb = self._builder;
        if _spec == "ptr" {
            _boxed = bb.insert_value(
                _boxed,
                bb.call(_tag_fn, [_elem], name="view.etag"),
                0,
                name="view.boxed"
            );
        }
        if kind == "dict" {
            bb.call(
                _dst_h["set"],
                [_out, bb.call(_src_h["get_key"], [_src, _i], name="view.key"), _boxed]
            );
        } else {
            bb.call(_dst_h["append"], [_out, _boxed]);
        }
        _i.add_incoming(bb.add(_i, ir.Constant(i64, 1), name="view.i1"), bb.block);
        bb.branch(_loop_bb);
        ir.IRBuilder(_done_bb).ret(_out);
    }
    self._builder = _saved;
    bc.ret(ir.Constant(target_type, None));
    return fn;
}

impl NaIRGenPass._dict_key_reconcile(
    dk: (str | None), val: (ir.Value | None)
) -> (str | None) {
    if val is None {
        return dk;
    }
    if dk is not None {
        _st = self.dict_types.get(dk);
        if _st is not None and val.type == _st.as_pointer() {
            return dk;
        }
    }
    _info = self._infer_dict_type(val);
    if _info is not None {
        return f"{_info[0]}:{_info[1]}";
    }
    return dk;
}

impl NaIRGenPass._codegen_dict_val(nd: uni.DictVal) -> (ir.Value | None) {
    if any(pair.key is None for pair in nd.kv_pairs) {
        return self._codegen_dict_unpack(nd);
    }
    if not nd.kv_pairs {
        _dk = self._peer_dict_key() or self._dict_key_of(nd);
        _helpers = self.dict_helpers.get(_dk) if _dk is not None else None;
        if _helpers is not None {
            _empty_dv = self.builder.call(_helpers["new"], [], name="dict.empty");
            self._nogc_stamp_elem_drops(_empty_dv, self._nogc_type_arg_mangles(nd));
            return _empty_dv;
        }
        return None;
    }

    _dk_args = nd.type.private.type_args
        if (
            isinstance(nd, uni.Expr)
            and isinstance(nd.type, ClassType)
            and nd.type.private is not None
        )
        else [];
    _k_store = self._elem_storage_llvm(_dk_args[0])
        if (_dk_args is not None and len(_dk_args) >= 2)
        else None;
    if _k_store is not None and self?.jacval_type and _k_store == self.jacval_type {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name="dict with mixed key types",
            help_text="Native dicts hash a single concrete key type; a dict whose keys mix representations has no native storage. Use one key type (for example str) and keep the mixing on the value side."
        );
        return None;
    }

    first_pair = nd.kv_pairs[0];
    first_key = self._codegen_expr(first_pair.key);
    first_val = self._str_norm_optional(self._codegen_expr(first_pair.value));
    if first_key is None or first_val is None {
        return None;
    }

    _own_dk = self._dict_key_of(nd);
    use_jacval = _own_dk is not None and _own_dk.endswith(":jacval");

    if _own_dk is not None and not use_jacval and _own_dk in self.dict_helpers {
        dict_key = _own_dk;
        helpers = self.dict_helpers[dict_key];
    } else {
        key_type = first_key.type;
        (key_type_name, key_size) = self._hash_key_spec(key_type);
        if use_jacval {
            val_type: ir.Type = self.jacval_type;
            val_type_name = "jacval";
        } else {
            val_type = first_val.type;
            val_type_name = self._dict_val_spec(val_type);
        }
        dict_key = f"{key_type_name}:{val_type_name}";
        self._emit_dict_helpers(
            key_type_name, val_type_name, key_type, val_type, key_size
        );
        helpers = self.dict_helpers[dict_key];
    }

    key_type = helpers["key_type"];
    val_type = helpers["val_type"];

    semantic_val_type = self._lower_type(_dk_args[1])
        if _dk_args is not None and len(_dk_args) >= 2
        else None;
    tuple_value_type = semantic_val_type.pointee
        if isinstance(semantic_val_type, ir.PointerType)
            and isinstance(semantic_val_type.pointee, ir.LiteralStructType)
        else None;

    _dict_new_loc = f"{os.path.basename(self.module.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    dict_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_dict_new_loc, name="dict.new"
    );
    self._nogc_stamp_elem_drops(dict_val, self._nogc_type_arg_mangles(nd));
    _dinit_loc = f"{os.path.basename(self.module.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";

    if tuple_value_type is not None {
        first_val = self._coerce_tuple_to_struct(first_val, tuple_value_type);
    }
    first_val = self._nogc_elem_prep(first_pair.value, first_val);
    if first_val is None {
        return None;
    }
    if not use_jacval
        and self._reject_ptr_into_raw_slot(nd, first_val, val_type, "dict value") {
        return dict_val;
    }
    first_store_key = self._coerce_type(first_key, key_type);
    first_store_val = self._coerce_type(first_val, val_type);
    (_set_fn, _kh) = self._static_key_op(helpers, "set", first_pair.key);
    _set_args = [dict_val, first_store_key, first_store_val];
    if _kh is not None {
        _set_args.append(_kh);
    }
    self._rc_call_with_ctx(_set_fn, _set_args, op="dict_init", loc=_dinit_loc);

    self._release_owned_args([first_store_key, first_store_val], op="dict_init");

    for i in range(1, len(nd.kv_pairs)) {
        pair = nd.kv_pairs[i];
        k = self._codegen_expr(pair.key);
        v = self._codegen_expr(pair.value);
        if k is not None and v is not None {
            if tuple_value_type is not None {
                v = self._coerce_tuple_to_struct(v, tuple_value_type);
            }
            v = self._nogc_elem_prep(pair.value, v);
            if v is None {
                return None;
            }
            if not use_jacval
                and self._reject_ptr_into_raw_slot(nd, v, val_type, "dict value") {
                return dict_val;
            }
            k = self._coerce_type(k, key_type);
            v = self._coerce_type(v, val_type);
            (_set_fn, _kh) = self._static_key_op(helpers, "set", pair.key);
            _set_args = [dict_val, k, v];
            if _kh is not None {
                _set_args.append(_kh);
            }
            self._rc_call_with_ctx(_set_fn, _set_args, op="dict_init", loc=_dinit_loc);

            self._release_owned_args([k, v], op="dict_init");
        }
    }

    return dict_val;
}

impl NaIRGenPass._codegen_dict_unpack(nd: uni.DictVal) -> (ir.Value | None) {
    dict_key = self._dict_key_of(nd);
    if dict_key is None {
        return None;
    }
    helpers = self.dict_helpers.get(dict_key);
    emitter = self._ensure_emitters().get("dict");
    if helpers is None or not isinstance(emitter, NativeDictEmitter) {
        return None;
    }
    ctx = NativeEmitCtx(pass_ref=self, type_key=dict_key);
    result = self._rc_call_with_ctx(helpers["new"], [], op="new", name="dict.unpack");
    self._nogc_stamp_elem_drops(result, self._nogc_type_arg_mangles(nd));
    args = nd.type.private.type_args
        if isinstance(nd.type, ClassType) and nd.type.private is not None
        else [];
    semantic_value = self._lower_type(args[1]) if args and len(args) >= 2 else None;
    tuple_type = semantic_value.pointee
        if isinstance(semantic_value, ir.PointerType)
            and isinstance(semantic_value.pointee, ir.LiteralStructType)
        else None;
    for pair in nd.kv_pairs {
        if pair.key is None {
            other = self._codegen_expr(pair.value);
            if other is None {
                return None;
            }
            if other.type != result.type {
                self.emit(
                    E5092,
                    node_override=pair.value,
                    kind="expression",
                    name="dictionary unpack with incompatible storage"
                );
                return None;
            }
            emitter.emit_update(ctx, result, [other]);
            self._release_owned_args([other], op="dict_unpack");
        } else {
            key = self._codegen_expr(pair.key);
            value = self._str_norm_optional(self._codegen_expr(pair.value));
            if key is None or value is None {
                return None;
            }
            if tuple_type is not None {
                value = self._coerce_tuple_to_struct(value, tuple_type);
            }
            value = self._nogc_elem_prep(pair.value, value);
            if value is None {
                return None;
            }
            if not dict_key.endswith(":jacval")
                and self._reject_ptr_into_raw_slot(
                    nd, value, helpers["val_type"], "dict value"
                ) {
                return None;
            }
            key = self._coerce_type(key, helpers["key_type"]);
            value = self._coerce_type(value, helpers["val_type"]);
            (set_fn, hash_value) = self._static_key_op(helpers, "set", pair.key);
            setter_args = [result, key, value];
            if hash_value is not None {
                setter_args.append(hash_value);
            }
            self._rc_call_with_ctx(set_fn, setter_args, op="dict_init");
            self._release_owned_args([key, value], op="dict_init");
        }
    }
    return result;
}

impl NaIRGenPass._codegen_dict_access(
    target_val: ir.Value,
    key_val: ir.Value,
    key_type_name: str,
    val_type_name: str,
    key_node: (uni.UniNode | None) = None,
    collection: (uni.UniNode | None) = None
) -> (ir.Value | None) {
    dict_key = f"{key_type_name}:{val_type_name}";
    helpers = self.dict_helpers.get(dict_key);
    if helpers is None {
        return None;
    }
    target_val = self._unwrap_opt_container(target_val);
    key_type = helpers["key_type"];
    key_val = self._coerce_type(key_val, key_type);

    (_has_fn, _kh) = self._static_key_op(helpers, "contains", key_node);
    _has_args = [target_val, key_val];
    if _kh is not None {
        _has_args.append(_kh);
    }
    key_exists = self.builder.call(_has_fn, _has_args, name="dict.has");
    not_exists = self.builder.not_(key_exists, name="dict.nokey");
    (_get_fn, _gh) = self._static_key_op(helpers, "get", key_node);
    _get_args = [target_val, key_val];
    if _gh is not None {
        _get_args.append(_gh);
    }
    borrowed = self._restore_dict_read(
        self.builder.call(_get_fn, _get_args, name="dict.get"), collection
    );
    self._release_owned_args([key_val], op="dict_get");
    result = self._finish_borrowed_read(target_val, borrowed);
    self._emit_runtime_raise(not_exists, "KeyError", "key not found");
    return result;
}

impl NaIRGenPass._codegen_dict_set(
    target_val: ir.Value,
    key_val: ir.Value,
    value: ir.Value,
    key_type_name: str,
    val_type_name: str,
    key_node: (uni.UniNode | None) = None
) -> None {
    dict_key = f"{key_type_name}:{val_type_name}";
    helpers = self.dict_helpers.get(dict_key);
    if helpers is None {
        return;
    }
    target_val = self._unwrap_opt_container(target_val);
    key_type = helpers["key_type"];
    val_type = helpers["val_type"];
    if self._reject_ptr_into_raw_slot(None, value, val_type, "dict value assignment") {
        return;
    }
    _orig_value = value;
    key_val = self._coerce_type(key_val, key_type);
    value = self._coerce_type(value, val_type);
    _dset_ctx_loc = getattr(
        _orig_value, 'jac_loc', f"{os.path.basename(self.module.loc.mod_path)}:0"
    );
    (_set_fn, _kh) = self._static_key_op(helpers, "set", key_node);
    _set_args = [target_val, key_val, value];
    if _kh is not None {
        _set_args.append(_kh);
    }
    self._rc_call_with_ctx(_set_fn, _set_args, op="dict_set", loc=_dset_ctx_loc);

    self._release_owned_args([key_val, value], op="dict_set");
}

impl NaIRGenPass._emit_dict_eq(
    left: ir.Value, right: ir.Value, dict_key: str, val_ty: (TypeBase | None)
) -> (ir.Value | None) {
    fn = self._dict_eq_fn(dict_key, val_ty);
    if fn is None {
        return None;
    }
    return self.builder.call(fn, [left, right], name="dict.eq");
}

impl NaIRGenPass._dict_eq_fn(
    dict_key: str, val_ty: (TypeBase | None)
) -> (ir.Function | None) {
    """Python's dictionary equality for one dictionary layout.

    Two dictionaries are equal when they hold the same keys, each mapped to
    equal values; insertion order plays no part. With equal sizes that is:
    every key of the left is found in the right (through the right's own
    hash), and the two values under it compare equal. Values are compared
    under the dictionary's checked value type, so a nested container or an
    archetype with its own `__eq__` is compared as Python would, not by
    address.
    """;
    helpers = self.dict_helpers.get(dict_key);
    dict_struct = self.dict_types.get(dict_key);
    if helpers is None or dict_struct is None {
        return None;
    }
    cache_key = f"dict[{dict_key}]:{self._mangled_of(val_ty) or ''}";
    cached = self._eq_fns.get(cache_key);
    if cached is not None {
        return cached;
    }
    pty = dict_struct.as_pointer();
    i64 = ir.IntType(64);
    fn = self._eq_fn_new(cache_key, pty, pty);
    saved = self._builder;
    try {
        (true_bb, false_bb) = self._eq_fn_prologue(fn);
        b = self.builder;
        (a, o) = (fn.args[0], fn.args[1]);
        la = b.call(helpers["len"], [a], name="deq.la");
        lb = b.call(helpers["len"], [o], name="deq.lb");
        pre_bb = b.basic_block;
        loop_bb = fn.append_basic_block("deq.loop");
        body_bb = fn.append_basic_block("deq.body");
        cmp_bb = fn.append_basic_block("deq.cmp");
        next_bb = fn.append_basic_block("deq.next");
        b.cbranch(b.icmp_unsigned("==", la, lb, name="deq.leq"), loop_bb, false_bb);
        b.position_at_end(loop_bb);
        i = b.phi(i64, name="deq.i");
        i.add_incoming(ir.Constant(i64, 0), pre_bb);
        b.cbranch(b.icmp_signed(">=", i, la, name="deq.end"), true_bb, body_bb);
        b.position_at_end(body_bb);
        k = b.call(helpers["get_key"], [a, i], name="deq.k");
        va = b.call(helpers["get_val"], [a, i], name="deq.va");
        slot = b.call(helpers["lookup"], [o, k], name="deq.slot");
        b.cbranch(
            b.icmp_unsigned("==", slot, ir.Constant(slot.type, None), name="deq.miss"),
            false_bb,
            cmp_bb
        );
        b.position_at_end(cmp_bb);
        vb = b.load(slot, name="deq.vb");
        _veq = self._emit_comparison(
            Tok.EE,
            va,
            vb,
            isinstance(va.type, (ir.DoubleType, ir.FloatType)),
            key_ret=val_ty
        );
        if _veq is None {
            self.ctx.emit(
                E5090,
                kind="comparison",
                name="dictionary value",
                help_text="This dictionary value does not lower to a comparable representation."
            );
            b.branch(false_bb);
        } else {
            b.cbranch(self._to_bool(_veq), next_bb, false_bb);
        }
        b.position_at_end(next_bb);
        i.add_incoming(b.add(i, ir.Constant(i64, 1), name="deq.i.next"), next_bb);
        b.branch(loop_bb);
    } finally {
        self._builder = saved;
    }
    return fn;
}
