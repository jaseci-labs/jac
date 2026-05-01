"""List type codegen and helper emission."""
"""Emit LLVM IR helper functions for a list with given element type."""
impl NaIRGenPass._emit_list_helpers(elem_type_name: str, elem_type: ir.Type) -> None {
    if elem_type_name in self.list_helpers {
        return;
    }
    # For "ptr" variant, always use i8* so all pointer types are interchangeable
    if elem_type_name == "ptr" {
        elem_type = ir.IntType(8).as_pointer();
    }
    # Create list struct type: { i64 len, i64 cap, elem_type* data }
    list_struct = self.llvm_module.context.get_identified_type(
        f"List.{elem_type_name}"
    );
    list_struct.set_body(ir.IntType(64), ir.IntType(64), elem_type.as_pointer());
    self.list_types[elem_type_name] = list_struct;
    list_ptr_type = list_struct.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    # --- Forward-declare __rc_release_list_T so new_fn can reference its address
    #     as the dtor_fn_ptr stored in every list allocation header.
    _rel_fn_name = f"__rc_release_list_{elem_type_name}";
    _rel_fnty = ir.FunctionType(ir.VoidType(), [list_ptr_type]);
    try {
        _rel_fn_decl = self.llvm_module.get_global(_rel_fn_name);
    } except KeyError {
        _rel_fn_decl = ir.Function(self.llvm_module, _rel_fnty, name=_rel_fn_name);
        _rel_fn_decl.linkage = "private";
    }
    # --- __list_new_T: create an empty list with capacity 8 ---
    new_fn = self._emit_container_new_fn(
        f"__list_new_{elem_type_name}", list_ptr_type, [elem_type], dtor_fn=_rel_fn_decl
    );
    # --- __list_append_T: append an element, growing if needed ---
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
    # Grow block
    b.position_at_end(grow_bb);
    data_p_g = b.gep(
        l_arg, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.ptr.g"
    );
    self._emit_grow_array(b, data_p_g, elem_type, cur_len, cap_p2, cur_cap);
    b.branch(store_bb);
    # Store block
    b.position_at_end(store_bb);
    data_p_s = b.gep(
        l_arg, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.ptr.s"
    );
    cur_data = b.load(data_p_s, name="data");
    slot = b.gep(cur_data, [cur_len], name="slot");
    # retain the element before storing so the list holds a reference.
    # The destructor (_emit_rc_release_elem_loop) will release each element on free.
    if isinstance(elem_type, ir.PointerType) {
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
    # --- __list_get_T: return data[index] ---
    get_fn = self._emit_array_get_fn(
        f"__list_get_{elem_type_name}", list_ptr_type, elem_type, 2
    );
    # --- __list_set_T: data[index] = val ---
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
    # retain-new, release-old for pointer element types
    if isinstance(elem_type, ir.PointerType) {
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
    # --- __list_len_T: return len field ---
    len_fn = self._emit_container_len_fn(f"__list_len_{elem_type_name}", list_ptr_type);
    # --- __rc_release_list_T: type-specific destructor ---
    release_fn = self._emit_container_release_fn(
        f"__rc_release_list_{elem_type_name}", list_ptr_type, [(2, elem_type)]
    );
    self.list_release_fns[elem_type_name] = release_fn;
    # Store helpers
    self.list_helpers[elem_type_name] = {
        "new": new_fn,
        "append": append_fn,
        "get": get_fn,
        "set": set_fn,
        "len": len_fn,
        "elem_type": elem_type
    };
}

"""Generate code for a list literal [a, b, c, ...]."""
impl NaIRGenPass._codegen_list_val(nd: uni.ListVal) -> (ir.Value | None) {
    if not nd.values {
        # Empty list: infer type from context
        elem_type_name = "i64";
        # 1. Check the type hint set by assignment/field context
        if self._list_type_hint is not None {
            elem_type_name = self._list_type_hint;
        } elif self.builder and self.builder.function {
            # 2. Fallback: infer from function return type
            ret_type = self.builder.function.return_value.type;
            if isinstance(ret_type, ir.PointerType) {
                # Check if it's a list pointer type
                for (tn, lt) in self.list_types.items() {
                    if lt.as_pointer() == ret_type {
                        elem_type_name = tn;
                        break;
                    }
                }
            }
        }
        # Ensure helpers exist for this elem type
        if elem_type_name == "ptr" {
            self._emit_list_helpers("ptr", ir.IntType(8).as_pointer());
        } elif elem_type_name == "f64" {
            self._emit_list_helpers("f64", ir.DoubleType());
        } else {
            self._emit_list_helpers("i64", ir.IntType(64));
        }
        helpers = self.list_helpers.get(elem_type_name);
        if helpers is not None {
            _empty_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
                if nd.loc
                else 0}";
            _empty = self._rc_call_with_ctx(
                helpers["new"], [], op="new", loc=_empty_loc, name="list.empty"
            );
            self._mark_owned(_empty);
            return _empty;
        }
        return None;
    }
    # Codegen first element to determine type
    first_val = self._codegen_expr(nd.values[0]);
    if first_val is None {
        return None;
    }
    # Box value tuples to pointers for container storage
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
    }
    # Ensure helpers exist
    self._emit_list_helpers(elem_type_name, elem_type);
    helpers = self.list_helpers[elem_type_name];
    i8p = ir.IntType(8).as_pointer();
    # Create new list
    _list_new_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    list_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_list_new_loc, name="list.new"
    );
    # Append first element (bitcast pointers to i8* for ptr lists)
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
    # if the original element was owned (fresh alloc/fn-call result),
    # __list_append_ptr retained it → release caller's owned ref.
    if isinstance(first_val.type, ir.PointerType) and self._is_owned(first_val) {
        self._emit_rc_release_simple(first_val, op="list_init", loc=_linit_loc);
    }
    # Append remaining elements
    for i in range(1, len(nd.values)) {
        val = self._codegen_expr(nd.values[i]);
        if val is not None {
            _orig_val = val;
            val = self._box_value_tuple(val, loc=_linit_loc);
            _boxed_val = val;  # Save post-box, pre-bitcast for check
            if elem_type_name == "ptr" and isinstance(val.type, ir.PointerType) {
                val = self.builder.bitcast(val, i8p, name="elem.cast");
            } else {
                val = self._coerce_type(val, elem_type);
            }
            self._rc_call_with_ctx(
                helpers["append"], [list_val, val], op="list_init", loc=_linit_loc
            );
            # release owned ref after append retained it.
            # Use _boxed_val (post-box, pre-bitcast) since _box_value_tuple marks
            # the new heap ptr as is_owned — the pre-box struct value is never marked.
            if isinstance(_boxed_val.type, ir.PointerType)
            and self._is_owned(_boxed_val) {
                self._emit_rc_release_simple(
                    _boxed_val, op="list_init", loc=_linit_loc
                );
            }
        }
    }
    # List literal is a fresh allocation — mark as owned so callers don't double-retain.
    self._mark_owned(list_val);
    return list_val;
}

"""Get element at index from a list (with IndexError bounds check)."""
impl NaIRGenPass._codegen_index(
    target_val: ir.Value, index_val: ir.Value, elem_type_name: str
) -> (ir.Value | None) {
    helpers = self.list_helpers.get(elem_type_name);
    if helpers is None {
        return None;
    }
    i64 = ir.IntType(64);
    index_val = self._coerce_type(index_val, i64);
    # IndexError: check index < 0
    is_neg = self.builder.icmp_signed(
        "<", index_val, ir.Constant(i64, 0), name="idx.neg.chk"
    );
    self._emit_runtime_raise(is_neg, "IndexError", "list index out of range");
    # IndexError: check index >= len
    len_val = self.builder.call(helpers["len"], [target_val], name="list.len.chk");
    is_oob = self.builder.icmp_signed(">=", index_val, len_val, name="idx.oob.chk");
    self._emit_runtime_raise(is_oob, "IndexError", "list index out of range");
    return self.builder.call(helpers["get"], [target_val, index_val], name="list.get");
}

"""Set element at index in a list (with IndexError bounds check)."""
impl NaIRGenPass._codegen_index_set(
    target_val: ir.Value, index_val: ir.Value, value: ir.Value, elem_type_name: str
) -> None {
    helpers = self.list_helpers.get(elem_type_name);
    if helpers is None {
        return;
    }
    i64 = ir.IntType(64);
    index_val = self._coerce_type(index_val, i64);
    # IndexError: check index < 0
    is_neg = self.builder.icmp_signed(
        "<", index_val, ir.Constant(i64, 0), name="setidx.neg.chk"
    );
    self._emit_runtime_raise(
        is_neg, "IndexError", "list assignment index out of range"
    );
    # IndexError: check index >= len
    len_val = self.builder.call(helpers["len"], [target_val], name="list.setlen.chk");
    is_oob = self.builder.icmp_signed(">=", index_val, len_val, name="setidx.oob.chk");
    self._emit_runtime_raise(
        is_oob, "IndexError", "list assignment index out of range"
    );
    elem_type = helpers["elem_type"];
    # Save jac_loc before coerce — coerce_type propagates is_owned across
    # bitcasts but does not propagate the loc attribute.
    _lset_ctx_loc = getattr(
        value, 'jac_loc', f"{os.path.basename(self.ir_in.loc.mod_path)}:0"
    );
    value = self._coerce_type(value, elem_type);
    self._rc_call_with_ctx(
        helpers["set"], [target_val, index_val, value], op="list_set", loc=_lset_ctx_loc
    );
    # if value was owned (function-call result), release our rc=1 ref.
    # __list_set_T already retained the new element; release caller's ownership.
    if isinstance(elem_type, ir.PointerType) and self._is_owned(value) {
        self._emit_rc_release_simple(value, op="list_set", loc=_lset_ctx_loc);
    }
}
# ─── Phase 5: Inheritance and Vtables ────────────────────────
