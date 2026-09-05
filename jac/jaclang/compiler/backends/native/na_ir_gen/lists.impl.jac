impl NaIRGenLists._emit_list_helpers(elem_type_name: str, elem_type: ir.Type) -> None {
    if elem_type_name in self.list_helpers {
        return;
    }

    if elem_type_name == "ptr" {
        elem_type = ir.IntType(8).as_pointer();
    }
    if elem_type_name == "i64" and isinstance(elem_type, ir.IntType) {
        elem_type = ir.IntType(64);
    }

    _list_layout = self._container_layout_dense([elem_type]);
    list_struct = self.llvm_module.context.get_identified_type(
        f"List.{elem_type_name}"
    );
    if not list_struct.elements {
        list_struct.set_body(*self._container_struct_fields(_list_layout));
    }
    self.list_types[elem_type_name] = list_struct;
    self.container_layouts[f"List.{elem_type_name}"] = _list_layout;
    list_ptr_type = list_struct.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);

    _rel_fn_decl = None;
    if not self._nogc_headerless() {
        _rel_fn_name = f"__rc_release_list_{elem_type_name}";
        _rel_fnty = ir.FunctionType(ir.VoidType(), [list_ptr_type]);
        try {
            _found = self.llvm_module.get_global(_rel_fn_name);
            _rel_fn_decl = _found if isinstance(_found, ir.Function) else None;
        } except KeyError {
            _rel_fn_decl = ir.Function(self.llvm_module, _rel_fnty, name=_rel_fn_name);
            _rel_fn_decl.linkage = "private";
        }
    }

    new_fn = self._emit_container_new_fn(
        f"__list_new_{elem_type_name}",
        list_ptr_type,
        _list_layout,
        dtor_fn=_rel_fn_decl
    );

    append_fnty = ir.FunctionType(ir.VoidType(), [list_ptr_type, elem_type]);
    append_fn = ir.Function(
        self.llvm_module, append_fnty, name=f"__list_append_{elem_type_name}"
    );
    append_fn.linkage = "private";
    append_fn.args[0].name = "list";
    append_fn.args[1].name = "val";
    entry_bb = append_fn.append_basic_block("entry");
    grow_bb = append_fn.append_basic_block("grow");
    store_bb = append_fn.append_basic_block("store");
    b = ir.IRBuilder(entry_bb);
    l_arg = append_fn.args[0];
    v_arg = append_fn.args[1];
    len_p2 = b.gep(l_arg, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr");
    cap_p2 = b.gep(l_arg, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cap.ptr");
    cur_len = b.load(len_p2, name="len");
    cur_cap = b.load(cap_p2, name="cap");
    need_grow = b.icmp_unsigned(">=", cur_len, cur_cap, name="need.grow");
    b.cbranch(need_grow, grow_bb, store_bb);

    b.position_at_end(grow_bb);
    data_p_g = b.gep(
        l_arg, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.ptr.g"
    );
    self._emit_grow_array(b, data_p_g, elem_type, cur_len, cap_p2, cur_cap);
    b.branch(store_bb);

    b.position_at_end(store_bb);
    data_p_s = b.gep(
        l_arg, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.ptr.s"
    );
    cur_data = b.load(data_p_s, name="data");
    slot = b.gep(cur_data, [cur_len], name="slot");

    self._emit_elem_retain(b, elem_type, v_arg);
    b.store(v_arg, slot);
    new_len = b.add(cur_len, ir.Constant(i64, 1), name="new.len");
    b.store(new_len, len_p2);
    b.ret_void();

    get_fn = self._emit_array_get_fn(
        f"__list_get_{elem_type_name}", list_ptr_type, elem_type, 2
    );

    set_fnty = ir.FunctionType(ir.VoidType(), [list_ptr_type, i64, elem_type]);
    set_fn = ir.Function(
        self.llvm_module, set_fnty, name=f"__list_set_{elem_type_name}"
    );
    set_fn.linkage = "private";
    set_fn.args[0].name = "list";
    set_fn.args[1].name = "index";
    set_fn.args[2].name = "val";
    bb_s = set_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb_s);
    dp2 = b.gep(
        set_fn.args[0], [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.ptr"
    );
    d2 = b.load(dp2, name="data");
    ep2 = b.gep(d2, [set_fn.args[1]], name="elem.ptr");

    if self._elem_kind(elem_type) != "raw" and not self._nogc_headerless() {
        self._emit_elem_retain(b, elem_type, set_fn.args[2]);
        _old_v_s = b.load(ep2, name="lset_old_val");
        b.store(set_fn.args[2], ep2);
        self._emit_elem_release(b, elem_type, _old_v_s);
    } else {
        b.store(set_fn.args[2], ep2);
    }
    b.ret_void();

    len_fn = self._emit_container_len_fn(f"__list_len_{elem_type_name}", list_ptr_type);

    if self._nogc_headerless() {
        self._emit_container_drop_fn(f"List.{elem_type_name}");
    } else {
        release_fn = self._emit_container_release_fn(
            f"__rc_release_list_{elem_type_name}", list_ptr_type, _list_layout
        );
        self.list_release_fns[elem_type_name] = release_fn;
    }

    self.list_helpers[elem_type_name] = {
        "new": new_fn,
        "append": append_fn,
        "get": get_fn,
        "set": set_fn,
        "len": len_fn,
        "elem_type": elem_type
    };
}

impl NaIRGenLists._cast_to_list_elem(
    b: any, val: ir.Value, elem_type: ir.Type, name: str
) -> ir.Value {
    if val.type == elem_type {
        return val;
    }
    if isinstance(val.type, ir.PointerType) and isinstance(elem_type, ir.PointerType) {
        return b.bitcast(val, elem_type, name=f"{name}.cast");
    }
    return val;
}

impl NaIRGenLists._reflavor_list(
    val: ir.Value, src_spec: str, dst_spec: str
) -> (ir.Value | None) {
    if self._builder is None or self.builder.function is None {
        return None;
    }
    _src_h = self.list_helpers.get(src_spec);
    _dst_h = self.list_helpers.get(dst_spec);
    if _src_h is None or _dst_h is None {
        return None;
    }
    _out = self.builder.call(_dst_h["new"], [], name=f"list.{dst_spec}.reflavor");
    self._emit_spread_copy(val, _src_h, _out, _dst_h, "list", "list_reflavor");
    return self._mark_owned(_out);
}

impl NaIRGenLists._spec_from_list_slot_type(t: (ir.Type | None)) -> (str | None) {
    if t is None {
        return None;
    }

    _pl = self._opt_payload_of(t);
    if _pl is not None {
        return self._spec_from_list_slot_type(_pl);
    }
    if not isinstance(t, ir.PointerType) {
        return None;
    }
    for (spec, lt) in self.list_types.items() {
        if lt.as_pointer() == t {
            return spec;
        }
    }
    return None;
}

impl NaIRGenLists._empty_list_dest_spec(nd: uni.ListVal) -> (str | None) {
    _child: uni.UniNode = nd;
    _dp = nd.parent;
    while (
        (isinstance(_dp, uni.CfgExpr) and _dp.expr is _child)
        or (
            isinstance(_dp, uni.IfElseExpr)
            and (_dp.value is _child or _dp.else_value is _child)
        )
    ) {
        _child = _dp;
        _dp = _dp.parent;
    }
    if isinstance(_dp, uni.ReturnStmt) and _dp.expr is _child {
        if self._builder is not None and self._builder.function is not None {
            return self._spec_from_list_slot_type(
                self._builder.function.function_type.return_type
            );
        }
        return None;
    }
    if isinstance(_dp, uni.HasVar) and _dp.value is _child {
        _hv_spec = self._spec_from_list_slot_type(self._resolve_field_type(_dp));
        if self._na_debug_on() {
            import sys;
            _hv_nm = _dp.name.value if _dp.name else "?";
            sys.stderr.write(
                f"NA_DEBUG empty-list dest hasvar={_hv_nm} spec={_hv_spec}\n"
            );
        }
        return _hv_spec;
    }
    if isinstance(_dp, uni.Assignment) and _dp.value is _child {
        for _tgt in (_dp.target or []) {
            if not isinstance(_tgt, uni.AtomTrailer) {
                _spec = self._elem_spec_of(_tgt);
                if _spec is not None {
                    return _spec;
                }
            }
            if isinstance(_tgt, uni.AtomTrailer) and _tgt.is_attr {
                _cls = self._struct_name_of(_tgt.target);
                _fld = self._get_name(_tgt.right);
                if _cls is not None and _fld is not None {
                    _spec = self._spec_from_list_slot_type(
                        self.struct_field_types.get(_cls, {}).get(_fld)
                    );
                    if _spec is not None {
                        return _spec;
                    }
                }
            }

            _tn = self._get_name(_tgt)
                if not isinstance(_tgt, uni.AtomTrailer)
                else None;
            if _tn is not None {
                _slot = self.local_vars.get(_tn);
                if _slot is not None and isinstance(_slot.type, ir.PointerType) {
                    _spec = self._spec_from_list_slot_type(_slot.type.pointee);
                    if _spec is not None {
                        return _spec;
                    }
                }
            }
        }
    }
    if isinstance(_dp, uni.KWPair) and _dp.value is _child {
        _fc = _dp.parent;
        if isinstance(_fc, uni.FuncCall) {
            _cn = self._get_name(_fc.target);
            if _cn is None or _cn not in self.struct_types {
                _cn = self._struct_name_of(_fc);
            }
            _kn = _dp.key.sym_name if _dp.key is not None else None;
            if _cn is not None and _kn is not None {
                return self._spec_from_list_slot_type(
                    self.struct_field_types.get(_cn, {}).get(_kn)
                );
            }
        }
    }
    return None;
}

impl NaIRGenLists._codegen_list_val(nd: uni.ListVal) -> (ir.Value | None) {
    self._pending_list_elem_struct = None;
    if not nd.values {
        elem_type_name = "";
        _decl_par = nd.parent;
        _bare_list_decl = False;
        if isinstance(_decl_par, (uni.Assignment, uni.HasVar))
            and _decl_par.value is nd
            and _decl_par.type_tag is not None {
            _lt_tag = _decl_par.type_tag.tag;
            _lt_name: (str | None) = None;
            if isinstance(_lt_tag, uni.Name) {
                _lt_name = _lt_tag.value;
            } elif uni?.BuiltinType and isinstance(_lt_tag, uni.BuiltinType) {
                _lt_name = _lt_tag.value;
            }
            _bare_list_decl = _lt_name == "list";
        }
        _own_spec = self._elem_spec_of(nd);
        _dest_spec = self._empty_list_dest_spec(nd);
        if _dest_spec is None {
            _dest_spec = self._spec_from_container_ptr(self._peer_container_ty);
        }
        if (
            _dest_spec is not None
            and _dest_spec != "jacval"
            and (_own_spec is None or _own_spec == "jacval")
        ) {
            _own_spec = _dest_spec;
        }
        if _own_spec is not None {
            elem_type_name = _own_spec;
        } elif _bare_list_decl {
            elem_type_name = "i64";
        } elif self._builder and self._builder.function {
            ret_type = self.builder.function.return_value.type;
            if isinstance(ret_type, ir.PointerType) {
                for (tn, lt) in self.list_types.items() {
                    if lt.as_pointer() == ret_type {
                        elem_type_name = tn;
                        break;
                    }
                }
            }
        }
        if not elem_type_name {
            elem_type_name = "jacval" if self?.jacval_type else "i64";
        }

        if elem_type_name == "ptr" {
            self._emit_list_helpers("ptr", ir.IntType(8).as_pointer());
        } elif elem_type_name == "f64" {
            self._emit_list_helpers("f64", ir.DoubleType());
        } elif elem_type_name == "jacval" and self?.jacval_type {
            self._emit_list_helpers("jacval", self.jacval_type);
        } else {
            self._emit_list_helpers("i64", ir.IntType(64));
        }
        helpers = self.list_helpers.get(elem_type_name);
        if helpers is not None {
            _empty_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                if nd.loc
                else 0}";

            _empty_new = self._rc_call_with_ctx(
                helpers["new"], [], op="new", loc=_empty_loc, name="list.empty"
            );
            self._nogc_stamp_elem_drops(_empty_new, self._nogc_type_arg_mangles(nd));
            return _empty_new;
        }
        return None;
    }

    _decl_elem = self._list_elem_llvm_of(nd);
    _clos_elem = self._closure_struct_of(_decl_elem)
        if _decl_elem is not None
        else None;

    _first_spread = self._spread_operand(nd.values[0]);
    first_val: (ir.Value | None) = None;
    _first_src_info: (dict | None) = None;
    if _first_spread is not None {
        _first_src_info = self._container_src_info(
            self._str_norm(self._codegen_expr(_first_spread))
        );
        if _first_src_info is None {
            self.emit(
                E5092,
                node_override=nd.values[0],
                kind="expression",
                name="spread in a list display",
                help_text="A `*` spread is copied element by element out of a native list or set; this operand lowered to neither. Give it a lowerable list or set type, or write the elements out."
            );
            return None;
        }
    } else {
        first_val = self._str_norm(self._codegen_expr(nd.values[0]));
        if first_val is None {
            return None;
        }
        first_val = self._wrap_fn_as_closure_value(first_val);
        first_val = self._box_value_tuple(
            first_val,
            loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                if nd.loc
                else 0}"
        );
        if _clos_elem is not None
            and _decl_elem is not None
            and first_val.type != _decl_elem {
            first_val = self._coerce_type(first_val, _decl_elem);
        }
    }
    _lit_spec = self._elem_spec_of(nd);
    if _lit_spec == "jacval" and self?.jacval_type {
        elem_type = self.jacval_type;
        elem_type_name = "jacval";
    } elif _lit_spec in ("i64", "f64")
        and _decl_elem is not None
        and isinstance(_decl_elem, (ir.IntType, ir.DoubleType)) {
        elem_type = _decl_elem;
        elem_type_name = _lit_spec or "i64";
    } else {
        elem_type = first_val.type
            if first_val is not None
            else _first_src_info["helpers"]["elem_type"];
        elem_type_name = "i64";
        if isinstance(elem_type, ir.DoubleType) {
            elem_type_name = "f64";
        } elif isinstance(elem_type, ir.PointerType) {
            elem_type_name = "ptr";
        } elif self?.jacval_type and elem_type == self.jacval_type {
            elem_type_name = "jacval";
        }
    }

    if isinstance(elem_type, ir.PointerType)
        and isinstance(elem_type.pointee, ir.LiteralStructType) {
        self._pending_list_elem_struct = elem_type;
    }

    self._emit_list_helpers(elem_type_name, elem_type);
    helpers = self.list_helpers[elem_type_name];
    i8p = ir.IntType(8).as_pointer();

    _list_new_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    list_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_list_new_loc, name="list.new"
    );
    self._nogc_stamp_elem_drops(list_val, self._nogc_type_arg_mangles(nd));

    _linit_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    if first_val is None {
        if self._reject_spread_slot_mismatch(
            nd.values[0],
            _first_src_info["helpers"]["elem_type"],
            helpers["elem_type"],
            "list element"
        ) {
            return None;
        }
        self._emit_spread_copy(
            _first_src_info["value"],
            _first_src_info["helpers"],
            list_val,
            helpers,
            "list",
            _linit_loc
        );
    } else {
        first_val = self._nogc_elem_prep(nd.values[0], first_val);
        if first_val is None {
            return None;
        }
        if self._reject_ptr_into_raw_slot(
            nd, first_val, helpers["elem_type"], "list element"
        ) {
            return list_val;
        }
        append_val = first_val;
        if elem_type_name == "ptr" and isinstance(first_val.type, ir.PointerType) {
            append_val = self.builder.bitcast(first_val, i8p, name="elem.cast");
        } else {
            append_val = self._coerce_type(append_val, helpers["elem_type"]);
        }
        self._rc_call_with_ctx(
            helpers["append"], [list_val, append_val], op="list_init", loc=_linit_loc
        );
        if isinstance(first_val.type, ir.PointerType)
            and self._is_owned(first_val)
            and self._gc_mode() != "none" {
            self._emit_rc_release_simple(first_val, op="list_init", loc=_linit_loc);
        }
    }

    for i in range(1, len(nd.values)) {
        _spread_op = self._spread_operand(nd.values[i]);
        if _spread_op is not None {
            _src_info = self._container_src_info(
                self._str_norm(self._codegen_expr(_spread_op))
            );
            if _src_info is None {
                self.emit(
                    E5092,
                    node_override=nd.values[i],
                    kind="expression",
                    name="spread in a list display",
                    help_text="A `*` spread is copied element by element out of a native list or set; this operand lowered to neither. Give it a lowerable list or set type, or write the elements out."
                );
                return None;
            }
            if self._reject_spread_slot_mismatch(
                nd.values[i],
                _src_info["helpers"]["elem_type"],
                helpers["elem_type"],
                "list element"
            ) {
                return None;
            }
            self._emit_spread_copy(
                _src_info["value"],
                _src_info["helpers"],
                list_val,
                helpers,
                "list",
                _linit_loc
            );
            continue;
        }
        val = self._str_norm(self._codegen_expr(nd.values[i]));
        if val is None {
            self.emit(
                E5092,
                node_override=nd.values[i],
                kind="expression",
                name="list element",
                help_text="This element of the list display did not lower, so the list would have been built without it. Move the expression out of the display, or move the enclosing code to a @sv/Python context."
            );
            return None;
        }
        if self._pending_list_elem_struct is not None
            and isinstance(self._pending_list_elem_struct, ir.PointerType)
            and isinstance(
                self._pending_list_elem_struct.pointee, ir.LiteralStructType
            ) {
            val = self._coerce_tuple_to_struct(
                val, self._pending_list_elem_struct.pointee
            );
        }
        val = self._wrap_fn_as_closure_value(val);
        _orig_val = val;
        val = self._box_value_tuple(val, loc=_linit_loc);
        if _clos_elem is not None
            and _decl_elem is not None
            and val.type != _decl_elem {
            val = self._coerce_type(val, _decl_elem);
        }
        val = self._nogc_elem_prep(nd.values[i], val);
        if val is None {
            return None;
        }
        _boxed_val = val;
        if self._reject_ptr_into_raw_slot(
            nd, val, helpers["elem_type"], "list element"
        ) {
            return list_val;
        }
        if elem_type_name == "ptr" and isinstance(val.type, ir.PointerType) {
            val = self.builder.bitcast(val, i8p, name="elem.cast");
        } else {
            val = self._coerce_type(val, helpers["elem_type"]);
        }
        self._rc_call_with_ctx(
            helpers["append"], [list_val, val], op="list_init", loc=_linit_loc
        );

        if isinstance(_boxed_val.type, ir.PointerType)
            and self._is_owned(_boxed_val)
            and self._gc_mode() != "none" {
            self._emit_rc_release_simple(_boxed_val, op="list_init", loc=_linit_loc);
        }
    }

    return list_val;
}

impl NaIRGenLists._codegen_index(
    target_val: ir.Value, index_val: ir.Value, elem_type_name: str
) -> (ir.Value | None) {
    helpers = self.list_helpers.get(elem_type_name);
    if helpers is None {
        return None;
    }
    i64 = ir.IntType(64);
    index_val = self._coerce_type(index_val, i64);

    len_val = self.builder.call(helpers["len"], [target_val], name="list.len.chk");
    is_neg = self.builder.icmp_signed(
        "<", index_val, ir.Constant(i64, 0), name="idx.neg.chk"
    );
    adjusted = self.builder.add(index_val, len_val, name="idx.adj");
    index_val = self.builder.select(is_neg, adjusted, index_val, name="idx.norm");
    below = self.builder.icmp_signed(
        "<", index_val, ir.Constant(i64, 0), name="idx.below"
    );
    above = self.builder.icmp_signed(">=", index_val, len_val, name="idx.oob.chk");
    is_oob = self.builder.or_(below, above, name="idx.range.chk");
    self._emit_runtime_raise(is_oob, "IndexError", "list index out of range");
    _got = self.builder.call(helpers["get"], [target_val, index_val], name="list.get");
    if elem_type_name == "u8" {
        return self.builder.zext(_got, i64, name="ba.get.zext");
    }
    return _got;
}

impl NaIRGenLists._codegen_any_subscript(
    jacval: ir.Value, key_val: ir.Value
) -> (ir.Value | None) {
    if not self?.jacval_type {
        return None;
    }
    i8p = ir.IntType(8).as_pointer();
    if key_val.type == i8p {
        self._emit_dict_helpers("ptr", "jacval", i8p, self.jacval_type);
        d = self._unbox_from_jacval(jacval, self.dict_types["ptr:jacval"].as_pointer());
        return self._codegen_dict_access(d, key_val, "ptr", "jacval");
    }
    if isinstance(key_val.type, ir.IntType) {
        self._emit_list_helpers("jacval", self.jacval_type);
        l = self._unbox_from_jacval(jacval, self.list_types["jacval"].as_pointer());
        return self._codegen_index(l, key_val, "jacval");
    }
    return None;
}

impl NaIRGenLists._codegen_any_len(jacval: ir.Value) -> ir.Value {
    b = self.builder;
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    i8p = i8.as_pointer();
    tag = b.extract_value(jacval, 0, name="anylen.tag");
    payload = b.extract_value(jacval, 1, name="anylen.payload");
    is_str = b.icmp_unsigned("==", tag, ir.Constant(i8, 2), name="anylen.isstr");
    func = b.function;
    str_bb = func.append_basic_block(name="anylen.str");
    cont_bb = func.append_basic_block(name="anylen.cont");
    merge_bb = func.append_basic_block(name="anylen.end");
    b.cbranch(is_str, str_bb, cont_bb);
    b.position_at_end(str_bb);
    sp = b.inttoptr(payload, i8p, name="anylen.sp");
    sl = self._call_str_len(b, sp, name="anylen.strlen");
    b.branch(merge_bb);
    b.position_at_end(cont_bb);
    lp = b.inttoptr(payload, i64.as_pointer(), name="anylen.lp");
    cl = b.load(lp, name="anylen.contlen");
    b.branch(merge_bb);
    b.position_at_end(merge_bb);
    phi = b.phi(i64, name="anylen");
    phi.add_incoming(sl, str_bb);
    phi.add_incoming(cl, cont_bb);
    return phi;
}

impl NaIRGenLists._codegen_index_set(
    target_val: ir.Value, index_val: ir.Value, value: ir.Value, elem_type_name: str
) -> None {
    _normed = self._str_norm(value);
    if _normed is None {
        return;
    }
    value = _normed;
    value = self._wrap_fn_as_closure_value(value);
    helpers = self.list_helpers.get(elem_type_name);
    if helpers is None {
        return;
    }
    i64 = ir.IntType(64);
    index_val = self._coerce_type(index_val, i64);

    len_val = self.builder.call(helpers["len"], [target_val], name="list.setlen.chk");
    is_neg = self.builder.icmp_signed(
        "<", index_val, ir.Constant(i64, 0), name="setidx.neg.chk"
    );
    adjusted = self.builder.add(index_val, len_val, name="setidx.adj");
    index_val = self.builder.select(is_neg, adjusted, index_val, name="setidx.norm");
    below = self.builder.icmp_signed(
        "<", index_val, ir.Constant(i64, 0), name="setidx.below"
    );
    above = self.builder.icmp_signed(">=", index_val, len_val, name="setidx.oob.chk");
    is_oob = self.builder.or_(below, above, name="setidx.range.chk");
    self._emit_runtime_raise(
        is_oob, "IndexError", "list assignment index out of range"
    );
    elem_type = helpers["elem_type"];

    _lset_ctx_loc = getattr(
        value, 'jac_loc', f"{os.path.basename(self.ir_in.loc.mod_path)}:0"
    );

    if self._reject_ptr_into_raw_slot(
        None, value, elem_type, "list element assignment"
    ) {
        return;
    }
    _orig_value = value;
    _val_was_owned = self._is_owned(value);
    value = self._coerce_type(value, elem_type);
    self._rc_call_with_ctx(
        helpers["set"], [target_val, index_val, value], op="list_set", loc=_lset_ctx_loc
    );

    if (
        isinstance(_orig_value.type, ir.PointerType)
        and _val_was_owned
        and self._elem_kind(elem_type) != "raw"
    ) {
        self._emit_rc_release_simple(_orig_value, op="list_set", loc=_lset_ctx_loc);
    }
}

impl NaIRGenLists._emit_aos_list_helpers(tname: str) -> ir.Type {
    _spec = f"aos.{tname}";
    if _spec in self.list_types {
        return self.list_types[_spec];
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    _t_struct = self.struct_types[tname];
    _tp = _t_struct.as_pointer();
    st = self.llvm_module.context.get_identified_type(f"List.aos.{tname}");
    st.set_body(i64, i64, _tp);
    self.list_types[_spec] = st;
    self.container_layouts[f"List.aos.{tname}"] = {
        "kind": "aos",
        "data_fields": [(2, _t_struct)],
        "elem_kinds": ["raw"],
        "ctrl_idx": -1,
        "used_idx": -1,
        "order_idx": -1,
        "drop_base": 3
    };
    _stp = st.as_pointer();
    _malloc = self._get_or_declare_extern("malloc", i8p, [i64]);
    _free = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
    _memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    _z = ir.Constant(i32, 0);

    new_fn = self._define_function(
        f"__list_new_aos_{tname}", ir.FunctionType(_stp, [])
    );
    new_fn.linkage = "private";
    b = ir.IRBuilder(new_fn.append_basic_block("entry"));
    _szT = b.ptrtoint(
        b.gep(ir.Constant(_tp, None), [ir.Constant(i32, 1)], name="szT.p"),
        i64,
        name="szT"
    );
    _szSelf = b.ptrtoint(
        b.gep(ir.Constant(_stp, None), [ir.Constant(i32, 1)], name="szS.p"),
        i64,
        name="szS"
    );
    _selfp = b.bitcast(
        b.call(_malloc, [_szSelf], name="aos.self8"), _stp, name="aos.self"
    );
    b.store(
        ir.Constant(i64, 0), b.gep(_selfp, [_z, ir.Constant(i32, 0)], name="aos.len")
    );
    b.store(
        ir.Constant(i64, 8), b.gep(_selfp, [_z, ir.Constant(i32, 1)], name="aos.cap")
    );
    _buf0 = b.call(
        _malloc, [b.mul(ir.Constant(i64, 8), _szT, name="aos.b0.sz")], name="aos.b0"
    );
    b.store(
        b.bitcast(_buf0, _tp, name="aos.b0.t"),
        b.gep(_selfp, [_z, ir.Constant(i32, 2)], name="aos.data")
    );
    b.ret(_selfp);

    append_fn = self._define_function(
        f"__list_append_aos_{tname}", ir.FunctionType(ir.VoidType(), [_stp, _tp])
    );
    append_fn.linkage = "private";
    _a_entry = append_fn.append_basic_block("entry");
    _a_grow = append_fn.append_basic_block("grow");
    _a_store = append_fn.append_basic_block("store");
    b = ir.IRBuilder(_a_entry);
    _a_szT = b.ptrtoint(
        b.gep(ir.Constant(_tp, None), [ir.Constant(i32, 1)], name="a.szT.p"),
        i64,
        name="a.szT"
    );
    _a_len_p = b.gep(append_fn.args[0], [_z, ir.Constant(i32, 0)], name="a.len.p");
    _a_cap_p = b.gep(append_fn.args[0], [_z, ir.Constant(i32, 1)], name="a.cap.p");
    _a_data_p = b.gep(append_fn.args[0], [_z, ir.Constant(i32, 2)], name="a.data.p");
    _a_len = b.load(_a_len_p, name="a.len");
    _a_cap = b.load(_a_cap_p, name="a.cap");
    b.cbranch(b.icmp_signed(">=", _a_len, _a_cap, name="a.full"), _a_grow, _a_store);
    b = ir.IRBuilder(_a_grow);
    _g_ncap = b.mul(_a_cap, ir.Constant(i64, 2), name="a.ncap");
    _g_new = b.call(_malloc, [b.mul(_g_ncap, _a_szT, name="a.nsz")], name="a.nbuf");
    _g_old = b.load(_a_data_p, name="a.old");
    b.call(
        _memcpy,
        [
            _g_new,
            b.bitcast(_g_old, i8p, name="a.old8"),
            b.mul(_a_len, _a_szT, name="a.copysz")
        ]
    );
    b.call(_free, [b.bitcast(_g_old, i8p, name="a.old8f")]);
    b.store(b.bitcast(_g_new, _tp, name="a.nbuf.t"), _a_data_p);
    b.store(_g_ncap, _a_cap_p);
    b.branch(_a_store);
    b = ir.IRBuilder(_a_store);
    _s_data = b.load(_a_data_p, name="a.data");
    _s_dst = b.gep(_s_data, [_a_len], name="a.dst");
    b.call(
        _memcpy,
        [
            b.bitcast(_s_dst, i8p, name="a.dst8"),
            b.bitcast(append_fn.args[1], i8p, name="a.src8"),
            _a_szT
        ]
    );
    b.call(_free, [b.bitcast(append_fn.args[1], i8p, name="a.shell8")]);
    b.store(b.add(_a_len, ir.Constant(i64, 1), name="a.len1"), _a_len_p);
    b.ret_void();

    get_fn = self._define_function(
        f"__list_get_aos_{tname}", ir.FunctionType(_tp, [_stp, i64])
    );
    get_fn.linkage = "private";
    b = ir.IRBuilder(get_fn.append_basic_block("entry"));
    _g_data = b.load(
        b.gep(get_fn.args[0], [_z, ir.Constant(i32, 2)], name="g.data.p"), name="g.data"
    );
    b.ret(b.gep(_g_data, [get_fn.args[1]], name="g.elem"));

    set_fn = self._define_function(
        f"__list_set_aos_{tname}", ir.FunctionType(ir.VoidType(), [_stp, i64, _tp])
    );
    set_fn.linkage = "private";
    b = ir.IRBuilder(set_fn.append_basic_block("entry"));
    _st_szT = b.ptrtoint(
        b.gep(ir.Constant(_tp, None), [ir.Constant(i32, 1)], name="s.szT.p"),
        i64,
        name="s.szT"
    );
    _st_data = b.load(
        b.gep(set_fn.args[0], [_z, ir.Constant(i32, 2)], name="s.data.p"), name="s.data"
    );
    _st_slot = b.gep(_st_data, [set_fn.args[1]], name="s.slot");
    _fields_fn = self._emit_struct_drop_fields_fn(tname);
    if _fields_fn is not None {
        b.call(_fields_fn, [b.bitcast(_st_slot, i8p, name="s.slot8")]);
    }
    b.call(
        _memcpy,
        [
            b.bitcast(_st_slot, i8p, name="s.slot8b"),
            b.bitcast(set_fn.args[2], i8p, name="s.src8"),
            _st_szT
        ]
    );
    b.call(_free, [b.bitcast(set_fn.args[2], i8p, name="s.shell8")]);
    b.ret_void();

    len_fn = self._define_function(
        f"__list_len_aos_{tname}", ir.FunctionType(i64, [_stp])
    );
    len_fn.linkage = "private";
    b = ir.IRBuilder(len_fn.append_basic_block("entry"));
    b.ret(
        b.load(
            b.gep(len_fn.args[0], [_z, ir.Constant(i32, 0)], name="l.len.p"),
            name="l.len"
        )
    );

    drop_fn = ir.Function(
        self.llvm_module,
        ir.FunctionType(ir.VoidType(), [i8p]),
        name=f"__drop_List_aos_{tname}"
    );
    drop_fn.linkage = "private";
    drop_fn.args[0].name = "self";
    _d_entry = drop_fn.append_basic_block("entry");
    _d_prep = drop_fn.append_basic_block("prep");
    _d_done = drop_fn.append_basic_block("done");
    b = ir.IRBuilder(_d_entry);
    _d_null = b.icmp_unsigned(
        "==", drop_fn.args[0], ir.Constant(i8p, None), name="d.null"
    );
    b.cbranch(_d_null, _d_done, _d_prep);
    b = ir.IRBuilder(_d_prep);
    _d_selfp = b.bitcast(drop_fn.args[0], _stp, name="d.self");
    _d_fields = self._emit_struct_drop_fields_fn(tname);

    def _aos_drop_elem(bl: ir.IRBuilder, i: ir.Value, elem_ptrs: list) -> ir.IRBuilder {
        if _d_fields is not None {
            bl.call(_d_fields, [bl.bitcast(elem_ptrs[0], i8p, name="d.elem8")]);
        }
        return bl;
    }
    b = self._emit_live_slot_loop(
        drop_fn,
        b,
        _d_selfp,
        self.container_layouts[f"List.aos.{tname}"],
        "d",
        _aos_drop_elem
    );
    _d_data = b.load(
        b.gep(_d_selfp, [_z, ir.Constant(i32, 2)], name="d.data.p"), name="d.data"
    );
    b.call(_free, [b.bitcast(_d_data, i8p, name="d.data8")]);
    b.call(_free, [drop_fn.args[0]]);
    b.branch(_d_done);
    b = ir.IRBuilder(_d_done);
    b.ret_void();
    self.container_drop_fns[f"List.aos.{tname}"] = drop_fn;

    self.list_helpers[_spec] = {
        "new": new_fn,
        "append": append_fn,
        "get": get_fn,
        "set": set_fn,
        "len": len_fn,
        "elem_type": _tp
    };
    return st;
}
