impl NaIRGenPass._emit_list_helpers(elem_type_name: str, elem_type: ir.Type) -> None {
    if elem_type_name in self.list_helpers {
        return;
    }

    if elem_type_name == "ptr" {
        elem_type = ir.IntType(8).as_pointer();
    }
    if elem_type_name == "i64" and isinstance(elem_type, ir.IntType) {
        elem_type = ir.IntType(64);
    }

    list_struct = self.llvm_module.context.get_identified_type(
        f"List.{elem_type_name}"
    );
    list_struct.set_body(ir.IntType(64), ir.IntType(64), elem_type.as_pointer());
    self.list_types[elem_type_name] = list_struct;
    list_ptr_type = list_struct.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);

    _rel_fn_decl = None;
    if not self._nogc_headerless() {
        _rel_fn_name = f"__rc_release_list_{elem_type_name}";
        _rel_fnty = ir.FunctionType(ir.VoidType(), [list_ptr_type]);
        try {
            _rel_fn_decl = self.llvm_module.get_global(_rel_fn_name);
        } except KeyError {
            _rel_fn_decl = ir.Function(self.llvm_module, _rel_fnty, name=_rel_fn_name);
            _rel_fn_decl.linkage = "private";
        }
    }

    new_fn = self._emit_container_new_fn(
        f"__list_new_{elem_type_name}", list_ptr_type, [elem_type], dtor_fn=_rel_fn_decl
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

    if isinstance(elem_type, ir.PointerType) and not self._nogc_headerless() {
        if self.rc_retain_fn is None {
            self._emit_rc_helpers();
        }
        v_cast = b.bitcast(
            v_arg, ir.IntType(8).as_pointer(), name="append.retain.cast"
        );
        b.call(self.rc_retain_fn, [v_cast]);
    }
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

    if isinstance(elem_type, ir.PointerType) and not self._nogc_headerless() {
        if self.rc_retain_fn is None {
            self._emit_rc_helpers();
        }
        _i8p_s = ir.IntType(8).as_pointer();
        _new_c_s = b.bitcast(set_fn.args[2], _i8p_s, name="lset_retain_cast");
        b.call(self.rc_retain_fn, [_new_c_s]);
        _old_v_s = b.load(ep2, name="lset_old_val");
        b.store(set_fn.args[2], ep2);
        _old_c_s = b.bitcast(_old_v_s, _i8p_s, name="lset_old_cast");
        b.call(self.rc_release_simple_fn, [_old_c_s]);
    } else {
        b.store(set_fn.args[2], ep2);
    }
    b.ret_void();

    len_fn = self._emit_container_len_fn(f"__list_len_{elem_type_name}", list_ptr_type);

    if self._nogc_headerless() {
        self._emit_container_drop_fn(f"List.{elem_type_name}");
    } else {
        release_fn = self._emit_container_release_fn(
            f"__rc_release_list_{elem_type_name}", list_ptr_type, [(2, elem_type)]
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

impl NaIRGenPass._codegen_list_val(nd: uni.ListVal) -> (ir.Value | None) {
    self._pending_list_elem_struct = None;
    if not nd.values {
        elem_type_name = "i64";
        _own_spec = self._elem_spec_of(nd);
        if _own_spec is not None {
            elem_type_name = _own_spec;
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

            return self._rc_call_with_ctx(
                helpers["new"], [], op="new", loc=_empty_loc, name="list.empty"
            );
        }
        return None;
    }

    _decl_elem = self._list_elem_llvm_of(nd);
    _clos_elem = self._closure_struct_of(_decl_elem)
        if _decl_elem is not None
        else None;

    first_val = self._codegen_expr(nd.values[0]);
    if first_val is None {
        return None;
    }

    first_val = self._box_value_tuple(
        first_val,
        loc=f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
            if nd.loc
            else 0}"
    );
    if _clos_elem is not None and first_val.type != _decl_elem {
        first_val = self._coerce_type(first_val, _decl_elem);
    }
    elem_type = first_val.type;
    elem_type_name = "i64";
    if isinstance(elem_type, ir.DoubleType) {
        elem_type_name = "f64";
    } elif isinstance(elem_type, ir.PointerType) {
        elem_type_name = "ptr";
    } elif self?.jacval_type and elem_type == self.jacval_type {
        elem_type_name = "jacval";
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

    append_val = first_val;
    if elem_type_name == "ptr" and isinstance(first_val.type, ir.PointerType) {
        append_val = self.builder.bitcast(first_val, i8p, name="elem.cast");
    } else {
        append_val = self._coerce_type(append_val, helpers["elem_type"]);
    }
    _linit_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    self._rc_call_with_ctx(
        helpers["append"], [list_val, append_val], op="list_init", loc=_linit_loc
    );

    if isinstance(first_val.type, ir.PointerType) and self._is_owned(first_val) {
        self._emit_rc_release_simple(first_val, op="list_init", loc=_linit_loc);
    }

    for i in range(1, len(nd.values)) {
        val = self._codegen_expr(nd.values[i]);
        if val is not None {
            if self._pending_list_elem_struct is not None
            and isinstance(self._pending_list_elem_struct, ir.PointerType)
            and isinstance(
                self._pending_list_elem_struct.pointee, ir.LiteralStructType
            ) {
                val = self._coerce_tuple_to_struct(
                    val, self._pending_list_elem_struct.pointee
                );
            }
            _orig_val = val;
            val = self._box_value_tuple(val, loc=_linit_loc);
            if _clos_elem is not None and val.type != _decl_elem {
                val = self._coerce_type(val, _decl_elem);
            }
            _boxed_val = val;
            if elem_type_name == "ptr" and isinstance(val.type, ir.PointerType) {
                val = self.builder.bitcast(val, i8p, name="elem.cast");
            } else {
                val = self._coerce_type(val, helpers["elem_type"]);
            }
            self._rc_call_with_ctx(
                helpers["append"], [list_val, val], op="list_init", loc=_linit_loc
            );

            if isinstance(_boxed_val.type, ir.PointerType)
            and self._is_owned(_boxed_val) {
                self._emit_rc_release_simple(
                    _boxed_val, op="list_init", loc=_linit_loc
                );
            }
        }
    }

    return list_val;
}

impl NaIRGenPass._codegen_index(
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

impl NaIRGenPass._codegen_any_subscript(
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

impl NaIRGenPass._codegen_any_len(jacval: ir.Value) -> ir.Value {
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
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    sp = b.inttoptr(payload, i8p, name="anylen.sp");
    sl = b.call(strlen_fn, [sp], name="anylen.strlen");
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

impl NaIRGenPass._codegen_index_set(
    target_val: ir.Value, index_val: ir.Value, value: ir.Value, elem_type_name: str
) -> None {
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
    value = self._coerce_type(value, elem_type);
    self._rc_call_with_ctx(
        helpers["set"], [target_val, index_val, value], op="list_set", loc=_lset_ctx_loc
    );

    if isinstance(elem_type, ir.PointerType) and self._is_owned(value) {
        self._emit_rc_release_simple(value, op="list_set", loc=_lset_ctx_loc);
    }
}
