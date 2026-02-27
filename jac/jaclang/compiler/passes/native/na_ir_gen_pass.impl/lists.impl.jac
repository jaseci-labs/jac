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
    list_struct = self.llvm_module.context.get_identified_type(f"List.{elem_type_name}");
    list_struct.set_body(ir.IntType(64), ir.IntType(64), elem_type.as_pointer());
    self.list_types[elem_type_name] = list_struct;
    list_ptr_type = list_struct.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    i8_ptr = ir.IntType(8).as_pointer();
    malloc_fn = self._get_or_declare_extern("malloc", i8_ptr, [i64]);
    free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8_ptr]);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8_ptr, [i8_ptr, i8_ptr, i64]);
    # --- __list_new_T: create an empty list with capacity 8 ---
    new_fnty = ir.FunctionType(list_ptr_type, []);
    new_fn = ir.Function(
        self.llvm_module, new_fnty, name=f"__list_new_{elem_type_name}"
    );
    new_fn.linkage = "private";
    bb = new_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    # Allocate list struct via rc_alloc (RC-managed)
    null_ptr = ir.Constant(list_ptr_type, None);
    size_gep = b.gep(null_ptr, [ir.Constant(i32, 1)], name="sizeof");
    struct_size = b.ptrtoint(size_gep, i64, name="size");
    raw = b.call(self.rc_alloc_fn, [struct_size], name="raw");
    list_ptr = b.bitcast(raw, list_ptr_type, name="list");
    # len = 0
    len_p = b.gep(list_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr");
    b.store(ir.Constant(i64, 0), len_p);
    # cap = 8
    cap_p = b.gep(list_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cap.ptr");
    b.store(ir.Constant(i64, 8), cap_p);
    # Allocate data: 8 * sizeof(elem) via plain malloc (internal, not RC-managed)
    elem_null = ir.Constant(elem_type.as_pointer(), None);
    elem_gep = b.gep(elem_null, [ir.Constant(i32, 1)], name="elem.sizeof");
    elem_size = b.ptrtoint(elem_gep, i64, name="elem.size");
    data_bytes = b.mul(ir.Constant(i64, 8), elem_size, name="data.bytes");
    data_raw = b.call(malloc_fn, [data_bytes], name="data.raw");
    data = b.bitcast(data_raw, elem_type.as_pointer(), name="data");
    data_p = b.gep(
        list_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.ptr"
    );
    b.store(data, data_p);
    b.ret(list_ptr);
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
    new_cap = b.mul(cur_cap, ir.Constant(i64, 2), name="new.cap");
    b.store(new_cap, cap_p2);
    elem_null2 = ir.Constant(elem_type.as_pointer(), None);
    elem_gep2 = b.gep(elem_null2, [ir.Constant(i32, 1)], name="elem.sizeof");
    elem_sz = b.ptrtoint(elem_gep2, i64, name="elem.size");
    new_bytes = b.mul(new_cap, elem_sz, name="new.bytes");
    new_data_raw = b.call(malloc_fn, [new_bytes], name="new.data.raw");
    new_data = b.bitcast(new_data_raw, elem_type.as_pointer(), name="new.data");
    data_p_g = b.gep(
        l_arg, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.ptr.g"
    );
    old_data = b.load(data_p_g, name="old.data");
    old_bytes = b.mul(cur_len, elem_sz, name="old.bytes");
    old_i8 = b.bitcast(old_data, i8_ptr, name="old.i8");
    new_i8 = b.bitcast(new_data, i8_ptr, name="new.i8");
    b.call(memcpy_fn, [new_i8, old_i8, old_bytes]);
    # Free old data array (plain malloc'd, not RC-managed)
    b.call(free_fn, [old_i8]);
    b.store(new_data, data_p_g);
    b.branch(store_bb);
    # Store block
    b.position_at_end(store_bb);
    data_p_s = b.gep(
        l_arg, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.ptr.s"
    );
    cur_data = b.load(data_p_s, name="data");
    slot = b.gep(cur_data, [cur_len], name="slot");
    b.store(v_arg, slot);
    new_len = b.add(cur_len, ir.Constant(i64, 1), name="new.len");
    b.store(new_len, len_p2);
    b.ret_void();
    # --- __list_get_T: return data[index] ---
    get_fnty = ir.FunctionType(elem_type, [list_ptr_type, i64]);
    get_fn = ir.Function(
        self.llvm_module, get_fnty, name=f"__list_get_{elem_type_name}"
    );
    get_fn.linkage = "private";
    get_fn.args[0].name = "list";
    get_fn.args[1].name = "index";
    bb_g = get_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb_g);
    dp = b.gep(
        get_fn.args[0], [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.ptr"
    );
    d = b.load(dp, name="data");
    ep = b.gep(d, [get_fn.args[1]], name="elem.ptr");
    elem_val = b.load(ep, name="elem");
    b.ret(elem_val);
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
    b.store(set_fn.args[2], ep2);
    b.ret_void();
    # --- __list_len_T: return len field ---
    len_fnty = ir.FunctionType(i64, [list_ptr_type]);
    len_fn = ir.Function(
        self.llvm_module, len_fnty, name=f"__list_len_{elem_type_name}"
    );
    len_fn.linkage = "private";
    len_fn.args[0].name = "list";
    bb_l = len_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb_l);
    lp = b.gep(
        len_fn.args[0], [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr"
    );
    length = b.load(lp, name="len");
    b.ret(length);
    # --- __rc_release_list_T: type-specific destructor ---
    release_fnty = ir.FunctionType(ir.VoidType(), [list_ptr_type]);
    release_fn = ir.Function(
        self.llvm_module, release_fnty, name=f"__rc_release_list_{elem_type_name}"
    );
    release_fn.linkage = "private";
    release_fn.args[0].name = "list";
    entry_bb = release_fn.append_basic_block("entry");
    dec_bb = release_fn.append_basic_block("dec");
    free_bb = release_fn.append_basic_block("do_free");
    done_bb = release_fn.append_basic_block("done");
    b = ir.IRBuilder(entry_bb);
    # Null check
    is_null = b.icmp_unsigned(
        "==", release_fn.args[0], ir.Constant(list_ptr_type, None), name="is.null"
    );
    b.cbranch(is_null, done_bb, dec_bb);
    # Decrement refcount
    b = ir.IRBuilder(dec_bb);
    raw_ptr = b.bitcast(release_fn.args[0], i8_ptr, name="raw.cast");
    rc_raw = b.gep(raw_ptr, [ir.Constant(i64, -8)], name="rc.raw");
    rc_ptr_r = b.bitcast(rc_raw, ir.IntType(64).as_pointer(), name="rc.ptr");
    old_rc = b.load(rc_ptr_r, name="old.rc");
    new_rc = b.sub(old_rc, ir.Constant(i64, 1), name="new.rc");
    b.store(new_rc, rc_ptr_r);
    is_zero = b.icmp_unsigned("==", new_rc, ir.Constant(i64, 0), name="is.zero");
    b.cbranch(is_zero, free_bb, done_bb);
    # Free block: release elements if pointer, free data, free struct
    b = ir.IRBuilder(free_bb);
    is_ptr_elem = isinstance(elem_type, ir.PointerType);
    if is_ptr_elem {
        # Loop over data[0..len-1] and rc_release_simple each element
        len_p_r = b.gep(
            release_fn.args[0],
            [ir.Constant(i32, 0), ir.Constant(i32, 0)],
            name="len.ptr.r"
        );
        cur_len_r = b.load(len_p_r, name="len.r");
        data_p_r = b.gep(
            release_fn.args[0],
            [ir.Constant(i32, 0), ir.Constant(i32, 2)],
            name="data.ptr.r"
        );
        data_r = b.load(data_p_r, name="data.r");
        # Loop: i = 0; while i < len { release(data[i]); i++ }
        loop_alloca = b.alloca(i64, name="loop.i");
        b.store(ir.Constant(i64, 0), loop_alloca);
        loop_cond_bb = release_fn.append_basic_block("loop.cond");
        loop_body_bb = release_fn.append_basic_block("loop.body");
        loop_end_bb = release_fn.append_basic_block("loop.end");
        b.branch(loop_cond_bb);
        b = ir.IRBuilder(loop_cond_bb);
        loop_i = b.load(loop_alloca, name="i");
        cmp = b.icmp_unsigned("<", loop_i, cur_len_r, name="cmp");
        b.cbranch(cmp, loop_body_bb, loop_end_bb);
        b = ir.IRBuilder(loop_body_bb);
        elem_ptr = b.gep(data_r, [b.load(loop_alloca, name="i2")], name="elem.ptr");
        elem_val = b.load(elem_ptr, name="elem.val");
        elem_cast = b.bitcast(elem_val, i8_ptr, name="elem.cast");
        b.call(self.rc_release_simple_fn, [elem_cast]);
        inc_i = b.add(b.load(loop_alloca, name="i3"), ir.Constant(i64, 1), name="inc");
        b.store(inc_i, loop_alloca);
        b.branch(loop_cond_bb);
        b = ir.IRBuilder(loop_end_bb);
    }
    # Free data array (plain malloc'd)
    data_p_f = b.gep(
        release_fn.args[0],
        [ir.Constant(i32, 0), ir.Constant(i32, 2)],
        name="data.ptr.f"
    );
    data_f = b.load(data_p_f, name="data.f");
    data_f_i8 = b.bitcast(data_f, i8_ptr, name="data.f.i8");
    b.call(free_fn, [data_f_i8]);
    # Free list struct (RC header is at ptr-8)
    b.call(free_fn, [rc_raw]);
    b.branch(done_bb);
    b = ir.IRBuilder(done_bb);
    b.ret_void();
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
            return self.builder.call(helpers["new"], [], name="list.empty");
        }
        return None;
    }
    # Codegen first element to determine type
    first_val = self._codegen_expr(nd.values[0]);
    if first_val is None {
        return None;
    }
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
    list_val = self.builder.call(helpers["new"], [], name="list.new");
    # Append first element (bitcast pointers to i8* for ptr lists)
    append_val = first_val;
    if elem_type_name == "ptr" and isinstance(first_val.type, ir.PointerType) {
        append_val = self.builder.bitcast(first_val, i8p, name="elem.cast");
    }
    self.builder.call(helpers["append"], [list_val, append_val]);
    # Append remaining elements
    for i in range(1, len(nd.values)) {
        val = self._codegen_expr(nd.values[i]);
        if val is not None {
            if elem_type_name == "ptr" and isinstance(val.type, ir.PointerType) {
                val = self.builder.bitcast(val, i8p, name="elem.cast");
            } else {
                val = self._coerce_type(val, elem_type);
            }
            self.builder.call(helpers["append"], [list_val, val]);
        }
    }
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
    self._emit_runtime_raise(is_neg, "IndexError", "list assignment index out of range");
    # IndexError: check index >= len
    len_val = self.builder.call(helpers["len"], [target_val], name="list.setlen.chk");
    is_oob = self.builder.icmp_signed(">=", index_val, len_val, name="setidx.oob.chk");
    self._emit_runtime_raise(is_oob, "IndexError", "list assignment index out of range");
    elem_type = helpers["elem_type"];
    value = self._coerce_type(value, elem_type);
    self.builder.call(helpers["set"], [target_val, index_val, value]);
}
# ─── Phase 5: Inheritance and Vtables ────────────────────────
