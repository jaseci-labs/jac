impl NaIRGenPass._codegen_int_pow(base: ir.Value, exp: ir.Value) -> ir.Value {
    i64 = ir.IntType(64);
    func = self.builder.function;

    result_alloca = self._entry_alloca(i64, "pow.result");
    counter_alloca = self._entry_alloca(i64, "pow.counter");
    self.builder.store(ir.Constant(i64, 1), result_alloca);
    self.builder.store(ir.Constant(i64, 0), counter_alloca);

    cond_bb = func.append_basic_block(name="pow.cond");
    body_bb = func.append_basic_block(name="pow.body");
    end_bb = func.append_basic_block(name="pow.end");
    self.builder.branch(cond_bb);

    self.builder.position_at_end(cond_bb);
    counter = self.builder.load(counter_alloca, name="pow.i");
    cmp = self.builder.icmp_signed("<", counter, exp, name="pow.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);

    self.builder.position_at_end(body_bb);
    cur_result = self.builder.load(result_alloca, name="pow.cur");
    new_result = self.builder.mul(cur_result, base, name="pow.mul");
    self.builder.store(new_result, result_alloca);
    cur_counter = self.builder.load(counter_alloca, name="pow.ci");
    next_counter = self.builder.add(cur_counter, ir.Constant(i64, 1), name="pow.inc");
    self.builder.store(next_counter, counter_alloca);
    self.builder.branch(cond_bb);

    self.builder.position_at_end(end_bb);
    return self.builder.load(result_alloca, name="pow.final");
}

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

    dict_struct = self.llvm_module.context.get_identified_type(
        f"Dict.{key_type_name}.{val_type_name}"
    );
    dict_struct.set_body(
        ir.IntType(64), ir.IntType(64), key_type.as_pointer(), val_type.as_pointer()
    );
    self.dict_types[dict_key] = dict_struct;
    dict_ptr_type = dict_struct.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    i8_ptr = ir.IntType(8).as_pointer();
    malloc_fn = self._get_or_declare_extern("malloc", i8_ptr, [i64]);
    free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8_ptr]);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8_ptr, [i8_ptr, i8_ptr, i64]);

    _rel_fn_name_d = f"__rc_release_dict_{dict_key.replace(':', '_')}";
    _rel_fnty_d = ir.FunctionType(ir.VoidType(), [dict_ptr_type]);
    try {
        _rel_fn_decl_d = self.llvm_module.get_global(_rel_fn_name_d);
    } except KeyError {
        _rel_fn_decl_d = ir.Function(
            self.llvm_module, _rel_fnty_d, name=_rel_fn_name_d
        );
        _rel_fn_decl_d.linkage = "private";
    }

    new_fn = self._emit_container_new_fn(
        f"__dict_new_{key_type_name}_{val_type_name}",
        dict_ptr_type,
        [key_type, val_type],
        dtor_fn=_rel_fn_decl_d
    );

    set_fnty = ir.FunctionType(ir.VoidType(), [dict_ptr_type, key_type, val_type]);
    set_fn = ir.Function(
        self.llvm_module, set_fnty, name=f"__dict_set_{key_type_name}_{val_type_name}"
    );
    set_fn.linkage = "private";
    set_fn.args[0].name = "dict";
    set_fn.args[1].name = "key";
    set_fn.args[2].name = "val";
    entry_bb = set_fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb);
    d_arg = set_fn.args[0];
    k_arg = set_fn.args[1];
    v_arg = set_fn.args[2];

    len_p2 = b.gep(d_arg, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr");
    cap_p2 = b.gep(d_arg, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cap.ptr");
    keys_p2 = b.gep(d_arg, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="keys.ptr");
    vals_p2 = b.gep(d_arg, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vals.ptr");
    cur_len = b.load(len_p2, name="len");
    keys_arr = b.load(keys_p2, name="keys");
    vals_arr = b.load(vals_p2, name="vals");

    (found_b, not_found_b, idx_alloca) = self._emit_linear_search_loop(
        set_fn, b, k_arg, keys_arr, cur_len, key_type, _key_sz
    );

    idx_found = found_b.load(idx_alloca, name="idx.found");
    val_ptr_found = found_b.gep(vals_arr, [idx_found], name="val.ptr.found");

    if isinstance(val_type, ir.PointerType) {
        if self.rc_retain_fn is None {
            self._emit_rc_helpers();
        }
        _i8pd = ir.IntType(8).as_pointer();
        _new_vcast_d = found_b.bitcast(v_arg, _i8pd, name="dset_retain_cast");
        found_b.call(self.rc_retain_fn, [_new_vcast_d]);
        _old_vval_d = found_b.load(val_ptr_found, name="dset_old_val");
        found_b.store(v_arg, val_ptr_found);
        _old_vcast_d = found_b.bitcast(_old_vval_d, _i8pd, name="dset_old_cast");
        found_b.call(self.rc_release_simple_fn, [_old_vcast_d]);
    } else {
        found_b.store(v_arg, val_ptr_found);
    }
    found_b.ret_void();

    grow_bb = set_fn.append_basic_block("grow");
    append_bb = set_fn.append_basic_block("append");
    cur_cap = not_found_b.load(cap_p2, name="cap");
    need_grow = not_found_b.icmp_unsigned(">=", cur_len, cur_cap, name="need.grow");
    not_found_b.cbranch(need_grow, grow_bb, append_bb);

    b = ir.IRBuilder(grow_bb);
    self._emit_grow_array(b, keys_p2, key_type, cur_len, cap_p2, cur_cap);

    new_cap = b.load(cap_p2, name="new.cap.reload");

    val_null2 = ir.Constant(val_type.as_pointer(), None);
    val_gep2 = b.gep(val_null2, [ir.Constant(i32, 1)], name="val.sizeof");
    val_sz = b.ptrtoint(val_gep2, i64, name="val.size");
    new_vals_bytes = b.mul(new_cap, val_sz, name="new.vals.bytes");
    new_vals_raw = b.call(malloc_fn, [new_vals_bytes], name="new.vals.raw");
    new_vals = b.bitcast(new_vals_raw, val_type.as_pointer(), name="new.vals");
    old_vals = b.load(vals_p2, name="old.vals");
    old_vals_bytes = b.mul(cur_len, val_sz, name="old.vals.bytes");
    old_vals_i8 = b.bitcast(old_vals, i8_ptr, name="old.vals.i8");
    new_vals_i8 = b.bitcast(new_vals, i8_ptr, name="new.vals.i8");
    b.call(memcpy_fn, [new_vals_i8, old_vals_i8, old_vals_bytes]);
    if self.rc_safe_free_fn is None {
        self._emit_rc_helpers();
    }
    b.call(self.rc_safe_free_fn, [old_vals_i8]);
    b.store(new_vals, vals_p2);
    b.branch(append_bb);

    b = ir.IRBuilder(append_bb);
    keys_arr_app = b.load(keys_p2, name="keys.app");
    vals_arr_app = b.load(vals_p2, name="vals.app");
    cur_len_app = b.load(len_p2, name="len.app");
    key_slot = b.gep(keys_arr_app, [cur_len_app], name="key.slot");
    val_slot = b.gep(vals_arr_app, [cur_len_app], name="val.slot");

    _i8pd2 = ir.IntType(8).as_pointer();
    if isinstance(key_type, ir.PointerType) {
        if self.rc_retain_fn is None {
            self._emit_rc_helpers();
        }
        _k_cast_d = b.bitcast(k_arg, _i8pd2, name="dapp_kret_cast");
        b.call(self.rc_retain_fn, [_k_cast_d]);
    }
    if isinstance(val_type, ir.PointerType) {
        if self.rc_retain_fn is None {
            self._emit_rc_helpers();
        }
        _v_cast_d = b.bitcast(v_arg, _i8pd2, name="dapp_vret_cast");
        b.call(self.rc_retain_fn, [_v_cast_d]);
    }
    b.store(k_arg, key_slot);
    b.store(v_arg, val_slot);
    new_len = b.add(cur_len_app, ir.Constant(i64, 1), name="new.len");
    b.store(new_len, len_p2);
    b.ret_void();

    get_fnty = ir.FunctionType(val_type, [dict_ptr_type, key_type]);
    get_fn = ir.Function(
        self.llvm_module, get_fnty, name=f"__dict_get_{key_type_name}_{val_type_name}"
    );
    get_fn.linkage = "private";
    get_fn.args[0].name = "dict";
    get_fn.args[1].name = "key";
    entry_bb_g = get_fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb_g);
    d_arg_g = get_fn.args[0];
    k_arg_g = get_fn.args[1];
    len_pg = b.gep(d_arg_g, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr");
    keys_pg = b.gep(
        d_arg_g, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="keys.ptr"
    );
    vals_pg = b.gep(
        d_arg_g, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vals.ptr"
    );
    len_g = b.load(len_pg, name="len");
    keys_g = b.load(keys_pg, name="keys");
    vals_g = b.load(vals_pg, name="vals");
    (found_b_g, not_found_b_g, idx_alloca_g) = self._emit_linear_search_loop(
        get_fn, b, k_arg_g, keys_g, len_g, key_type, _key_sz
    );

    idx_fg = found_b_g.load(idx_alloca_g, name="idx.found");
    val_ptr_fg = found_b_g.gep(vals_g, [idx_fg], name="val.ptr");
    result_g = found_b_g.load(val_ptr_fg, name="result");
    found_b_g.ret(result_g);

    if isinstance(val_type, ir.PointerType) {
        not_found_b_g.ret(ir.Constant(val_type, None));
    } elif val_type?.elements and val_type.elements {
        zero_elems = [ir.Constant(e, 0) for e in val_type.elements];
        not_found_b_g.ret(ir.Constant(val_type, zero_elems));
    } else {
        not_found_b_g.ret(ir.Constant(val_type, 0));
    }

    len_fn = self._emit_container_len_fn(
        f"__dict_len_{key_type_name}_{val_type_name}", dict_ptr_type
    );

    contains_fnty = ir.FunctionType(ir.IntType(1), [dict_ptr_type, key_type]);
    contains_fn = ir.Function(
        self.llvm_module,
        contains_fnty,
        name=f"__dict_contains_{key_type_name}_{val_type_name}"
    );
    contains_fn.linkage = "private";
    contains_fn.args[0].name = "dict";
    contains_fn.args[1].name = "key";
    entry_bb_c = contains_fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb_c);
    len_pc = b.gep(
        contains_fn.args[0], [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr"
    );
    keys_pc = b.gep(
        contains_fn.args[0], [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="keys.ptr"
    );
    len_c = b.load(len_pc, name="len");
    keys_c = b.load(keys_pc, name="keys");
    (found_b_c, not_found_b_c, _) = self._emit_linear_search_loop(
        contains_fn, b, contains_fn.args[1], keys_c, len_c, key_type, _key_sz
    );
    found_b_c.ret(ir.Constant(ir.IntType(1), 1));
    not_found_b_c.ret(ir.Constant(ir.IntType(1), 0));

    get_key_fn = self._emit_array_get_fn(
        f"__dict_get_key_{key_type_name}_{val_type_name}", dict_ptr_type, key_type, 2
    );

    get_val_fn = self._emit_array_get_fn(
        f"__dict_get_val_{key_type_name}_{val_type_name}", dict_ptr_type, val_type, 3
    );

    release_fn = self._emit_container_release_fn(
        f"__rc_release_dict_{dict_key.replace(':', '_')}",
        dict_ptr_type,
        [(2, key_type), (3, val_type)]
    );
    self.dict_release_fns[dict_key] = release_fn;

    self.dict_helpers[dict_key] = {
        "new": new_fn,
        "set": set_fn,
        "get": get_fn,
        "len": len_fn,
        "contains": contains_fn,
        "get_key": get_key_fn,
        "get_val": get_val_fn,
        "key_type": key_type,
        "val_type": val_type
    };
}

impl NaIRGenPass._box_to_jacval(value: ir.Value) -> ir.Value {
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

    self.emit(E5090, kind="expression", name=f"`any` unbox to {target_type}");
    return ir.Constant(target_type, None);
}

impl NaIRGenPass._codegen_dict_val(nd: uni.DictVal) -> (ir.Value | None) {
    if not nd.kv_pairs {
        _dk = self._dict_key_of(nd);
        _helpers = self.dict_helpers.get(_dk) if _dk is not None else None;
        if _helpers is not None {
            return self.builder.call(_helpers["new"], [], name="dict.empty");
        }
        return None;
    }

    first_pair = nd.kv_pairs[0];
    first_key = self._codegen_expr(first_pair.key);
    first_val = self._codegen_expr(first_pair.value);
    if first_key is None or first_val is None {
        return None;
    }

    _own_dk = self._dict_key_of(nd);
    use_jacval = _own_dk is not None and _own_dk.endswith(":jacval");

    key_type = first_key.type;
    (key_type_name, key_size) = self._dict_key_spec(key_type);
    if use_jacval {
        val_type = self.jacval_type;
        val_type_name = "jacval";
    } else {
        val_type = first_val.type;
        val_type_name = "i64";
        if isinstance(val_type, ir.DoubleType) {
            val_type_name = "f64";
        } elif isinstance(val_type, ir.PointerType) {
            val_type_name = "ptr";
        }
    }
    dict_key = f"{key_type_name}:{val_type_name}";

    self._emit_dict_helpers(key_type_name, val_type_name, key_type, val_type, key_size);
    helpers = self.dict_helpers[dict_key];

    _dict_new_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    dict_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_dict_new_loc, name="dict.new"
    );
    _dinit_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";

    first_store_val = self._box_to_jacval(first_val) if use_jacval else first_val;
    self._rc_call_with_ctx(
        helpers["set"],
        [dict_val, first_key, first_store_val],
        op="dict_init",
        loc=_dinit_loc
    );

    if use_jacval and isinstance(first_val.type, ir.PointerType) {
        self._emit_rc_retain(first_val, op="dict_init", loc=_dinit_loc);
    }

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

            if use_jacval and isinstance(_orig_v.type, ir.PointerType) {
                self._emit_rc_retain(_orig_v, op="dict_init", loc=_dinit_loc);
            }

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
    _orig_value = value;
    key_val = self._coerce_type(key_val, key_type);
    value = self._coerce_type(value, val_type);
    _dset_ctx_loc = getattr(
        _orig_value, 'jac_loc', f"{os.path.basename(self.ir_in.loc.mod_path)}:0"
    );
    self._rc_call_with_ctx(
        helpers["set"], [target_val, key_val, value], op="dict_set", loc=_dset_ctx_loc
    );

    if isinstance(val_type, ir.PointerType) and self._is_owned(_orig_value) {
        _dset_loc = getattr(
            _orig_value, 'jac_loc', f"{os.path.basename(self.ir_in.loc.mod_path)}:0"
        );
        self._emit_rc_release_simple(_orig_value, op="dict_set", loc=_dset_loc);
    }
}
