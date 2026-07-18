impl NaIRGenPass._emit_set_helpers(
    elem_type_name: str, elem_type: ir.Type, elem_size: int = 0
) -> None {
    if elem_type_name in self.set_helpers {
        return;
    }

    set_struct = self.llvm_module.context.get_identified_type(f"Set.{elem_type_name}");
    set_struct.set_body(ir.IntType(64), ir.IntType(64), elem_type.as_pointer());
    self.set_types[elem_type_name] = set_struct;
    set_ptr_type = set_struct.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);

    _rel_fn_decl_s = None;
    if not self._nogc_headerless() {
        _rel_fn_name_s = f"__rc_release_set_{elem_type_name}";
        _rel_fnty_s = ir.FunctionType(ir.VoidType(), [set_ptr_type]);
        try {
            _rel_fn_decl_s = self.llvm_module.get_global(_rel_fn_name_s);
        } except KeyError {
            _rel_fn_decl_s = ir.Function(
                self.llvm_module, _rel_fnty_s, name=_rel_fn_name_s
            );
            _rel_fn_decl_s.linkage = "private";
        }
    }

    new_fn = self._emit_container_new_fn(
        f"__set_new_{elem_type_name}", set_ptr_type, [elem_type], dtor_fn=_rel_fn_decl_s
    );

    add_fnty = ir.FunctionType(ir.VoidType(), [set_ptr_type, elem_type]);
    add_fn = ir.Function(
        self.llvm_module, add_fnty, name=f"__set_add_{elem_type_name}"
    );
    add_fn.linkage = "private";
    add_fn.args[0].name = "set";
    add_fn.args[1].name = "elem";
    entry_bb = add_fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb);
    s_arg = add_fn.args[0];
    e_arg = add_fn.args[1];
    len_p2 = b.gep(s_arg, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr");
    cap_p2 = b.gep(s_arg, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cap.ptr");
    elems_p2 = b.gep(
        s_arg, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="elems.ptr"
    );
    cur_len = b.load(len_p2, name="len");
    elems_arr = b.load(elems_p2, name="elems");

    (found_b, not_found_b, _) = self._emit_linear_search_loop(
        add_fn, b, e_arg, elems_arr, cur_len, elem_type, elem_size
    );

    found_b.ret_void();

    grow_bb = add_fn.append_basic_block("grow");
    append_bb = add_fn.append_basic_block("append");
    cur_cap = not_found_b.load(cap_p2, name="cap");
    need_grow = not_found_b.icmp_unsigned(">=", cur_len, cur_cap, name="need.grow");
    not_found_b.cbranch(need_grow, grow_bb, append_bb);

    b = ir.IRBuilder(grow_bb);
    self._emit_grow_array(b, elems_p2, elem_type, cur_len, cap_p2, cur_cap);
    b.branch(append_bb);

    b = ir.IRBuilder(append_bb);
    elems_arr_app = b.load(elems_p2, name="elems.app");
    cur_len_app = b.load(len_p2, name="len.app");
    elem_slot = b.gep(elems_arr_app, [cur_len_app], name="elem.slot");

    if isinstance(elem_type, ir.PointerType) {
        if self.rc_retain_fn is None {
            self._emit_rc_helpers();
        }
        _e_cast_sa = b.bitcast(
            e_arg, ir.IntType(8).as_pointer(), name="sadd_retain_cast"
        );
        b.call(self.rc_retain_fn, [_e_cast_sa]);
    }
    b.store(e_arg, elem_slot);
    new_len = b.add(cur_len_app, ir.Constant(i64, 1), name="new.len");
    b.store(new_len, len_p2);
    b.ret_void();

    contains_fnty = ir.FunctionType(ir.IntType(1), [set_ptr_type, elem_type]);
    contains_fn = ir.Function(
        self.llvm_module, contains_fnty, name=f"__set_contains_{elem_type_name}"
    );
    contains_fn.linkage = "private";
    contains_fn.args[0].name = "set";
    contains_fn.args[1].name = "elem";
    entry_bb_c = contains_fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb_c);
    len_pc = b.gep(
        contains_fn.args[0], [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr"
    );
    elems_pc = b.gep(
        contains_fn.args[0],
        [ir.Constant(i32, 0), ir.Constant(i32, 2)],
        name="elems.ptr"
    );
    len_c = b.load(len_pc, name="len");
    elems_c = b.load(elems_pc, name="elems");
    (found_b_c, not_found_b_c, _) = self._emit_linear_search_loop(
        contains_fn, b, contains_fn.args[1], elems_c, len_c, elem_type, elem_size
    );
    found_b_c.ret(ir.Constant(ir.IntType(1), 1));
    not_found_b_c.ret(ir.Constant(ir.IntType(1), 0));

    len_fn = self._emit_container_len_fn(f"__set_len_{elem_type_name}", set_ptr_type);

    if self._nogc_headerless() {
        self._emit_container_drop_fn(f"Set.{elem_type_name}");
    } else {
        release_fn = self._emit_container_release_fn(
            f"__rc_release_set_{elem_type_name}", set_ptr_type, [(2, elem_type)]
        );
        self.set_release_fns[elem_type_name] = release_fn;
    }

    self.set_helpers[elem_type_name] = {
        "new": new_fn,
        "add": add_fn,
        "contains": contains_fn,
        "len": len_fn,
        "elem_type": elem_type,
        "elem_size": elem_size
    };
}

impl NaIRGenPass._codegen_set_val(nd: uni.SetVal) -> (ir.Value | None) {
    if not nd.values {
        _sk = self._set_spec_of(nd);
        _helpers = self.set_helpers.get(_sk) if _sk is not None else None;
        if _helpers is not None {
            return self.builder.call(_helpers["new"], [], name="set.empty");
        }
        return None;
    }

    first_val = self._codegen_expr(nd.values[0]);
    if first_val is None {
        return None;
    }

    elem_type = first_val.type;
    elem_type_name = "i64";
    elem_size = 0;
    if isinstance(elem_type, ir.DoubleType) {
        elem_type_name = "f64";
    } elif isinstance(elem_type, ir.PointerType) {
        elem_type_name = "ptr";
        if isinstance(elem_type.pointee, ir.LiteralStructType) {
            elem_size = self._get_struct_size(elem_type.pointee);
            elem_type_name = f"tuple{elem_size}";
        }
    }

    self._emit_set_helpers(elem_type_name, elem_type, elem_size);
    helpers = self.set_helpers[elem_type_name];

    _set_new_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    set_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_set_new_loc, name="set.new"
    );
    _sinit_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";

    self._rc_call_with_ctx(
        helpers["add"], [set_val, first_val], op="set_init", loc=_sinit_loc
    );

    for i in range(1, len(nd.values)) {
        val = self._codegen_expr(nd.values[i]);
        if val is not None {
            _orig_sv = val;
            val = self._coerce_type(val, elem_type);
            self._rc_call_with_ctx(
                helpers["add"], [set_val, val], op="set_init", loc=_sinit_loc
            );

            if isinstance(_orig_sv.type, ir.PointerType) and self._is_owned(_orig_sv) {
                self._emit_rc_release_simple(_orig_sv, op="set_init", loc=_sinit_loc);
            }
        }
    }

    return set_val;
}
