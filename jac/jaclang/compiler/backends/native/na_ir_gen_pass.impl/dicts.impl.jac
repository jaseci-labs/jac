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
        self.ctx.emit(E5092, kind="expression", name=f"`any` box of {value.type}");
        tag = ir.Constant(i8, 0);
    }
    boxed = b.insert_value(
        ir.Constant(self.jacval_type, None), tag, 0, name="jacval.tag"
    );
    return b.insert_value(boxed, payload, 1, name="jacval");
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
        return b.inttoptr(payload, target_type, name="jv.unbox.p");
    }

    self.ctx.emit(E5092, kind="expression", name=f"`any` unbox to {target_type}");
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
        self.ctx.emit(
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
                self.ctx.emit(
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
