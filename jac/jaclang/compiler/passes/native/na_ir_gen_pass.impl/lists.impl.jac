impl NaIRGenPass._emit_list_helpers(elem_type_name: str, elem_type: ir.Type) -> None {
    if elem_type_name in self.list_helpers {
        return;
    }

    if elem_type_name == "ptr" {
        elem_type = ir.IntType(8).as_pointer();
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
            _boxed_val = val;
            if elem_type_name == "ptr" and isinstance(val.type, ir.PointerType) {
                val = self.builder.bitcast(val, i8p, name="elem.cast");
            } else {
                val = self._coerce_type(val, elem_type);
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
    return self.builder.call(helpers["get"], [target_val, index_val], name="list.get");
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

impl NaIRGenPass._emit_any_str(jacval: ir.Value) -> ir.Value {
    b = self.builder;
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = i8.as_pointer();
    tag = b.extract_value(jacval, 0, name="anystr.tag");
    payload = b.extract_value(jacval, 1, name="anystr.payload");
    func = b.function;

    str_bb = func.append_basic_block(name="anystr.str");
    chk_bool_bb = func.append_basic_block(name="anystr.chk.bool");
    bool_bb = func.append_basic_block(name="anystr.bool");
    chk_float_bb = func.append_basic_block(name="anystr.chk.float");
    float_bb = func.append_basic_block(name="anystr.float");
    chk_none_bb = func.append_basic_block(name="anystr.chk.none");
    none_bb = func.append_basic_block(name="anystr.none");
    int_bb = func.append_basic_block(name="anystr.int");
    merge_bb = func.append_basic_block(name="anystr.end");

    is_str = b.icmp_unsigned("==", tag, ir.Constant(i8, 2), name="anystr.isstr");
    b.cbranch(is_str, str_bb, chk_bool_bb);
    b.position_at_end(chk_bool_bb);
    is_bool = b.icmp_unsigned("==", tag, ir.Constant(i8, 7), name="anystr.isbool");
    b.cbranch(is_bool, bool_bb, chk_float_bb);
    b.position_at_end(chk_float_bb);
    is_float = b.icmp_unsigned("==", tag, ir.Constant(i8, 1), name="anystr.isfloat");
    b.cbranch(is_float, float_bb, chk_none_bb);
    b.position_at_end(chk_none_bb);
    is_none = b.icmp_unsigned("==", tag, ir.Constant(i8, 8), name="anystr.isnone");
    b.cbranch(is_none, none_bb, int_bb);

    b.position_at_end(str_bb);
    str_null_bb = func.append_basic_block(name="anystr.str.null");
    str_copy_bb = func.append_basic_block(name="anystr.str.copy");
    is_null_str = b.icmp_unsigned(
        "==", payload, ir.Constant(i64, 0), name="anystr.strnull"
    );
    b.cbranch(is_null_str, str_null_bb, str_copy_bb);

    b.position_at_end(str_null_bb);
    str_null_res = self._make_global_string("", name_prefix=".anystr.empty");
    str_null_end = b.basic_block;
    b.branch(merge_bb);

    b.position_at_end(str_copy_bb);
    src_ptr = b.inttoptr(payload, i8p, name="anystr.sp");
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    src_len = b.call(strlen_fn, [src_ptr], name="anystr.strlen");
    copy_size = b.add(src_len, ir.Constant(i64, 1), name="anystr.strsize");
    str_buf = b.call(self.rc_alloc_fn, [copy_size], name="anystr.strcopy");
    strcpy_fn = self._get_or_declare_extern("strcpy", i8p, [i8p, i8p]);
    b.call(strcpy_fn, [str_buf, src_ptr], name="anystr.strcpy");
    str_res = str_buf;
    str_end = b.basic_block;
    b.branch(merge_bb);

    b.position_at_end(bool_bb);
    true_s = self._make_global_string("True", name_prefix=".anystr.true");
    false_s = self._make_global_string("False", name_prefix=".anystr.false");
    is_true = b.icmp_unsigned("!=", payload, ir.Constant(i64, 0), name="anystr.bnz");
    bool_res = b.select(is_true, true_s, false_s, name="anystr.bool.res");
    bool_end = b.basic_block;
    b.branch(merge_bb);

    b.position_at_end(float_bb);
    float_val = b.bitcast(payload, ir.DoubleType(), name="anystr.f");
    float_res = self._emit_float_repr(float_val);
    float_end = b.basic_block;
    b.branch(merge_bb);

    b.position_at_end(none_bb);
    none_res = self._make_global_string("None", name_prefix=".anystr.none");
    none_end = b.basic_block;
    b.branch(merge_bb);

    b.position_at_end(int_bb);
    int_buf = b.call(self.rc_alloc_fn, [ir.Constant(i64, 32)], name="anystr.ibuf");
    snprintf = self._get_or_declare_extern(
        "snprintf", i32, [i8p, i64, i8p], var_arg=True
    );
    int_fmt = self._get_snprintf_fmt("%ld");
    int_fmt_ptr = b.bitcast(int_fmt, i8p, name="anystr.fmt");
    b.call(
        snprintf,
        [int_buf, ir.Constant(i64, 32), int_fmt_ptr, payload],
        name="anystr.snprintf"
    );
    int_end = b.basic_block;
    b.branch(merge_bb);

    b.position_at_end(merge_bb);
    phi = b.phi(i8p, name="anystr.res");
    phi.add_incoming(str_res, str_end);
    phi.add_incoming(str_null_res, str_null_end);
    phi.add_incoming(bool_res, bool_end);
    phi.add_incoming(float_res, float_end);
    phi.add_incoming(none_res, none_end);
    phi.add_incoming(int_buf, int_end);

    return self._mark_owned(phi);
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
