impl NaIRGenPass._dict_key_spec(key_type: ir.Type) -> tuple {
    if isinstance(key_type, ir.DoubleType) {
        return ("f64", 0);
    }
    if self._is_bytes_type(key_type) {
        return ("bytes", 0);
    }
    if isinstance(key_type, ir.PointerType) {
        if isinstance(key_type.pointee, ir.LiteralStructType) {
            _sz = self._get_struct_size(key_type.pointee);
            return (f"tuple{_sz}", _sz);
        }
        return ("ptr", 0);
    }
    return ("i64", 0);
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
    return "i64";
}

impl NaIRGenPass._emit_dict_order_compact(
    b: ir.IRBuilder,
    fn: ir.Function,
    d_ptr: ir.Value,
    removed_slot: ir.Value,
    new_len: ir.Value,
    i32: ir.Type,
    i64: ir.Type,
    order_idx: int
) -> ir.IRBuilder {
    ord_a = b.load(
        b.gep(d_ptr, [ir.Constant(i32, 0), ir.Constant(i32, order_idx)], name="oc.orp"),
        name="oc.ord"
    );
    _idx = b.alloca(i64, name="oc.i");
    b.store(ir.Constant(i64, 0), _idx);
    _scan = fn.append_basic_block("oc.scan");
    _body = fn.append_basic_block("oc.body");
    _shift = fn.append_basic_block("oc.shift");
    _sbody = fn.append_basic_block("oc.sbody");
    _cont = fn.append_basic_block("oc.cont");
    b.branch(_scan);

    bs = ir.IRBuilder(_scan);
    _i = bs.load(_idx, name="oc.iv");

    bs.cbranch(bs.icmp_unsigned(">=", _i, new_len, name="oc.end"), _cont, _body);
    bb = ir.IRBuilder(_body);
    _cur = bb.load(bb.gep(ord_a, [_i], name="oc.cp"), name="oc.cur");
    _hit = bb.icmp_signed("==", _cur, removed_slot, name="oc.hit");
    bb.cbranch(
        _hit, _shift, self._emit_order_scan_incr_block(bb, _idx, _i, i64, fn, _scan)
    );

    bh = ir.IRBuilder(_shift);
    _j = bh.alloca(i64, name="oc.j");
    bh.store(_i, _j);
    bh.branch(_sbody);
    bsb = ir.IRBuilder(_sbody);
    _jv = bsb.load(_j, name="oc.jv");
    _more = bsb.icmp_unsigned("<", _jv, new_len, name="oc.smore");
    _do = fn.append_basic_block("oc.do");
    bsb.cbranch(_more, _do, _cont);
    bd = ir.IRBuilder(_do);
    _nx = bd.add(_jv, ir.Constant(i64, 1), name="oc.jn");
    _nv = bd.load(bd.gep(ord_a, [_nx], name="oc.srcp"), name="oc.src");
    bd.store(_nv, bd.gep(ord_a, [_jv], name="oc.dstp"));
    bd.store(_nx, _j);
    bd.branch(_sbody);
    return ir.IRBuilder(_cont);
}

impl NaIRGenPass._emit_order_scan_incr_block(
    b: ir.IRBuilder,
    idx_slot: ir.Value,
    i_cur: ir.Value,
    i64: ir.Type,
    fn: ir.Function,
    scan_bb: ir.Block
) -> ir.Block {
    _blk = fn.append_basic_block("oc.incr");
    _bi = ir.IRBuilder(_blk);
    _bi.store(_bi.add(i_cur, ir.Constant(i64, 1), name="oc.in"), idx_slot);
    _bi.branch(scan_bb);
    return _blk;
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
            _rel_fn_decl = self.llvm_module.get_global(_rel_fn_name);
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
        "get": core["get"],
        "len": len_fn,
        "contains": core["contains"],
        "get_key": core["get_key"],
        "get_val": core["get_val"],
        "remove": core["remove"],
        "pop": core["pop"],
        "find": core["find"],
        "clear": core["clear"],
        "key_type": key_type,
        "val_type": val_type
    };
}

impl NaIRGenPass._box_to_jacval(value: ir.Value) -> ir.Value {
    value = self._str_norm(value);
    b = self.builder;
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);

    if self?.jacval_type and value.type == self.jacval_type {
        return value;
    }
    jv_alloca = self._entry_alloca(self.jacval_type, "jacval");
    tag_ptr = b.gep(
        jv_alloca, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="jv.tag.ptr"
    );
    payload_ptr = b.gep(
        jv_alloca, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="jv.payload.ptr"
    );
    if isinstance(value.type, ir.IntType) and value.type.width == 1 {
        b.store(ir.Constant(i8, 7), tag_ptr);
        ext = b.zext(value, i64, name="jv.bext");
        b.store(ext, payload_ptr);
    } elif isinstance(value.type, ir.IntType) {
        b.store(ir.Constant(i8, 0), tag_ptr);
        if value.type.width == 64 {
            b.store(value, payload_ptr);
        } else {
            b.store(b.zext(value, i64, name="jv.iext"), payload_ptr);
        }
    } elif isinstance(value.type, ir.DoubleType) {
        b.store(ir.Constant(i8, 1), tag_ptr);
        payload = b.bitcast(value, i64, name="jv.f2i");
        b.store(payload, payload_ptr);
    } elif isinstance(value.type, ir.PointerType) {
        ptr_tag = 2;
        for (_, ltype) in self.list_types.items() {
            if value.type == ltype.as_pointer() {
                ptr_tag = 3;
                break;
            }
        }
        if ptr_tag == 2 {
            for (_, dtype) in self.dict_types.items() {
                if value.type == dtype.as_pointer() {
                    ptr_tag = 4;
                    break;
                }
            }
        }
        if ptr_tag == 2 {
            for (_, stype) in self.set_types.items() {
                if value.type == stype.as_pointer() {
                    ptr_tag = 5;
                    break;
                }
            }
        }
        if ptr_tag == 2 {
            for (_, structt) in self.struct_types.items() {
                if value.type == structt.as_pointer() {
                    ptr_tag = 6;
                    break;
                }
            }
        }
        payload = b.ptrtoint(value, i64, name="jv.p2i");
        if ptr_tag == 2 {
            is_null = b.icmp_unsigned(
                "==", payload, ir.Constant(i64, 0), name="jv.isnone"
            );
            none_or_str = b.select(
                is_null, ir.Constant(i8, 8), ir.Constant(i8, 2), name="jv.nonetag"
            );
            b.store(none_or_str, tag_ptr);
        } else {
            b.store(ir.Constant(i8, ptr_tag), tag_ptr);
        }
        b.store(payload, payload_ptr);
    } else {
        self.emit(E5092, kind="expression", name=f"`any` box of {value.type}");
        b.store(ir.Constant(i8, 0), tag_ptr);
        b.store(ir.Constant(i64, 0), payload_ptr);
    }
    return b.load(jv_alloca, name="jacval");
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
        return b.inttoptr(payload, target_type, name="jv.unbox.p");
    }

    self.emit(E5092, kind="expression", name=f"`any` unbox to {target_type}");
    return ir.Constant(target_type, None);
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
    if not nd.kv_pairs {
        _dk = self._dict_key_of(nd);
        _helpers = self.dict_helpers.get(_dk) if _dk is not None else None;
        if _helpers is not None {
            _empty_dv = self.builder.call(_helpers["new"], [], name="dict.empty");
            self._nogc_stamp_elem_drops(_empty_dv, self._nogc_type_arg_mangles(nd));
            return _empty_dv;
        }
        return None;
    }

    _dk_args = nd.type.private.type_args
        if (isinstance(nd, uni.Expr) and nd.type is not None)
        else [];
    _k_store = self._elem_storage_llvm(_dk_args[0]) if len(_dk_args) >= 2 else None;
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
    first_val = self._str_norm(self._codegen_expr(first_pair.value));
    if first_key is None or first_val is None {
        return None;
    }

    _own_dk = self._dict_key_of(nd);
    use_jacval = _own_dk is not None and _own_dk.endswith(":jacval");

    if _own_dk is not None and not use_jacval and _own_dk in self.dict_helpers {
        dict_key = _own_dk;
        helpers = self.dict_helpers[dict_key];
        key_type = helpers["key_type"];
        val_type = helpers["val_type"];
    } else {
        key_type = first_key.type;
        (key_type_name, key_size) = self._dict_key_spec(key_type);
        if use_jacval {
            val_type = self.jacval_type;
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

    _dict_new_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    dict_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_dict_new_loc, name="dict.new"
    );
    self._nogc_stamp_elem_drops(dict_val, self._nogc_type_arg_mangles(nd));
    _dinit_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";

    first_val = self._nogc_elem_prep(first_pair.value, first_val);
    if not use_jacval
        and self._reject_ptr_into_raw_slot(nd, first_val, val_type, "dict value") {
        return dict_val;
    }
    first_store_val = (
        self._box_to_jacval(first_val)
            if use_jacval
            else self._coerce_type(first_val, val_type)
    );
    self._rc_call_with_ctx(
        helpers["set"],
        [dict_val, self._coerce_type(first_key, key_type), first_store_val],
        op="dict_init",
        loc=_dinit_loc
    );

    if isinstance(first_key.type, ir.PointerType) and self._is_owned(first_key) {
        self._emit_rc_release_simple(first_key, op="dict_init", loc=_dinit_loc);
    }
    if isinstance(first_val.type, ir.PointerType) and self._is_owned(first_val) {
        self._emit_rc_release_simple(first_val, op="dict_init", loc=_dinit_loc);
    }

    for i in range(1, len(nd.kv_pairs)) {
        pair = nd.kv_pairs[i];
        k = self._codegen_expr(pair.key);
        v = self._codegen_expr(pair.value);
        if k is not None and v is not None {
            v = self._nogc_elem_prep(pair.value, v);
            if not use_jacval
                and self._reject_ptr_into_raw_slot(nd, v, val_type, "dict value") {
                return dict_val;
            }
            _orig_k = k;
            _orig_v = v;
            k = self._coerce_type(k, key_type);
            if use_jacval {
                v = self._box_to_jacval(v);
            } else {
                v = self._coerce_type(v, val_type);
            }
            self._rc_call_with_ctx(
                helpers["set"], [dict_val, k, v], op="dict_init", loc=_dinit_loc
            );

            if isinstance(_orig_k.type, ir.PointerType) and self._is_owned(_orig_k) {
                self._emit_rc_release_simple(_orig_k, op="dict_init", loc=_dinit_loc);
            }
            if isinstance(_orig_v.type, ir.PointerType) and self._is_owned(_orig_v) {
                self._emit_rc_release_simple(_orig_v, op="dict_init", loc=_dinit_loc);
            }
        }
    }

    return dict_val;
}

impl NaIRGenPass._codegen_dict_access(
    target_val: ir.Value, key_val: ir.Value, key_type_name: str, val_type_name: str
) -> (ir.Value | None) {
    dict_key = f"{key_type_name}:{val_type_name}";
    helpers = self.dict_helpers.get(dict_key);
    if helpers is None {
        return None;
    }
    key_type = helpers["key_type"];
    key_val = self._coerce_type(key_val, key_type);

    key_exists = self.builder.call(
        helpers["contains"], [target_val, key_val], name="dict.has"
    );
    not_exists = self.builder.not_(key_exists, name="dict.nokey");
    self._emit_runtime_raise(not_exists, "KeyError", "key not found");
    return self.builder.call(helpers["get"], [target_val, key_val], name="dict.get");
}

impl NaIRGenPass._codegen_dict_set(
    target_val: ir.Value,
    key_val: ir.Value,
    value: ir.Value,
    key_type_name: str,
    val_type_name: str
) -> None {
    dict_key = f"{key_type_name}:{val_type_name}";
    helpers = self.dict_helpers.get(dict_key);
    if helpers is None {
        return;
    }
    key_type = helpers["key_type"];
    val_type = helpers["val_type"];
    if self._reject_ptr_into_raw_slot(None, value, val_type, "dict value assignment") {
        return;
    }
    _orig_key = key_val;
    _orig_value = value;
    key_val = self._coerce_type(key_val, key_type);
    value = self._coerce_type(value, val_type);
    _dset_ctx_loc = getattr(
        _orig_value, 'jac_loc', f"{os.path.basename(self.ir_in.loc.mod_path)}:0"
    );
    self._rc_call_with_ctx(
        helpers["set"], [target_val, key_val, value], op="dict_set", loc=_dset_ctx_loc
    );

    if (
        isinstance(_orig_key.type, ir.PointerType)
        and isinstance(key_type, ir.PointerType)
        and self._is_owned(_orig_key)
    ) {
        self._emit_rc_release_simple(_orig_key, op="dict_set", loc=_dset_ctx_loc);
    }

    if (
        isinstance(_orig_value.type, ir.PointerType)
        and self._elem_kind(val_type) != "raw"
        and self._is_owned(_orig_value)
    ) {
        _dset_loc = getattr(
            _orig_value, 'jac_loc', f"{os.path.basename(self.ir_in.loc.mod_path)}:0"
        );
        self._emit_rc_release_simple(_orig_value, op="dict_set", loc=_dset_loc);
    }
}
