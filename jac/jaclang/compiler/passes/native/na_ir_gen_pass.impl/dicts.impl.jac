"""Dictionary type codegen and operations."""
"""Integer power operation using loop-based exponentiation."""
impl NaIRGenPass._codegen_int_pow(base: ir.Value, exp: ir.Value) -> ir.Value {
    # Simple loop-based integer exponentiation
    # result = 1; for i in range(exp): result *= base
    i64 = ir.IntType(64);
    func = self.builder.function;
    # Allocate result and counter
    result_alloca = self._entry_alloca(i64, "pow.result");
    counter_alloca = self._entry_alloca(i64, "pow.counter");
    self.builder.store(ir.Constant(i64, 1), result_alloca);
    self.builder.store(ir.Constant(i64, 0), counter_alloca);
    # Basic blocks
    cond_bb = func.append_basic_block(name="pow.cond");
    body_bb = func.append_basic_block(name="pow.body");
    end_bb = func.append_basic_block(name="pow.end");
    self.builder.branch(cond_bb);
    # Condition: counter < exp
    self.builder.position_at_end(cond_bb);
    counter = self.builder.load(counter_alloca, name="pow.i");
    cmp = self.builder.icmp_signed("<", counter, exp, name="pow.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);
    # Body: result *= base; counter++
    self.builder.position_at_end(body_bb);
    cur_result = self.builder.load(result_alloca, name="pow.cur");
    new_result = self.builder.mul(cur_result, base, name="pow.mul");
    self.builder.store(new_result, result_alloca);
    cur_counter = self.builder.load(counter_alloca, name="pow.ci");
    next_counter = self.builder.add(cur_counter, ir.Constant(i64, 1), name="pow.inc");
    self.builder.store(next_counter, counter_alloca);
    self.builder.branch(cond_bb);
    # End: return result
    self.builder.position_at_end(end_bb);
    return self.builder.load(result_alloca, name="pow.final");
}

"""Emit LLVM IR helper functions for a dictionary with given key/value types.

Uses a simple linear-search dictionary: {len, cap, keys*, vals*}
This is O(n) for lookups but sufficient for small dictionaries.
"""
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
    # Auto-detect key_size for tuple/struct pointer keys
    _key_sz: int = int(key_size);
    if _key_sz == 0 and isinstance(key_type, ir.PointerType) {
        _pointee = getattr(key_type, "pointee", None);
        if _pointee is not None and isinstance(_pointee, ir.LiteralStructType) {
            _key_sz = self._get_struct_size(_pointee);
        }
    }
    # Create dict struct type: { i64 len, i64 cap, key_type* keys, val_type* vals }
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
    # --- __dict_new: create an empty dict with capacity 8 ---
    new_fnty = ir.FunctionType(dict_ptr_type, []);
    new_fn = ir.Function(
        self.llvm_module, new_fnty, name=f"__dict_new_{key_type_name}_{val_type_name}"
    );
    new_fn.linkage = "private";
    bb = new_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    (dict_ptr, _, _) = self._emit_rc_alloc_container(
        b, dict_ptr_type, [key_type, val_type]
    );
    b.ret(dict_ptr);
    # --- __dict_set: set key=value (linear search, grow if needed) ---
    set_fnty = ir.FunctionType(ir.VoidType(), [dict_ptr_type, key_type, val_type]);
    set_fn = ir.Function(
        self.llvm_module, set_fnty, name=f"__dict_set_{key_type_name}_{val_type_name}"
    );
    set_fn.linkage = "private";
    set_fn.args[0].name = "dict";
    set_fn.args[1].name = "key";
    set_fn.args[2].name = "val";
    entry_bb = set_fn.append_basic_block("entry");
    loop_cond_bb = set_fn.append_basic_block("loop.cond");
    loop_body_bb = set_fn.append_basic_block("loop.body");
    incr_bb = set_fn.append_basic_block("incr");
    found_bb = set_fn.append_basic_block("found");
    not_found_bb = set_fn.append_basic_block("not.found");
    grow_bb = set_fn.append_basic_block("grow");
    append_bb = set_fn.append_basic_block("append");
    b = ir.IRBuilder(entry_bb);
    d_arg = set_fn.args[0];
    k_arg = set_fn.args[1];
    v_arg = set_fn.args[2];
    # Load len, cap, keys, vals
    len_p2 = b.gep(d_arg, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr");
    cap_p2 = b.gep(d_arg, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cap.ptr");
    keys_p2 = b.gep(d_arg, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="keys.ptr");
    vals_p2 = b.gep(d_arg, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vals.ptr");
    cur_len = b.load(len_p2, name="len");
    keys_arr = b.load(keys_p2, name="keys");
    vals_arr = b.load(vals_p2, name="vals");
    # Allocate loop index
    idx_alloca = b.alloca(i64, name="idx");
    b.store(ir.Constant(i64, 0), idx_alloca);
    b.branch(loop_cond_bb);
    # Loop condition: idx < len
    b.position_at_end(loop_cond_bb);
    idx = b.load(idx_alloca, name="idx");
    cmp = b.icmp_signed("<", idx, cur_len, name="cmp");
    b.cbranch(cmp, loop_body_bb, not_found_bb);
    # Loop body: compare key
    b.position_at_end(loop_body_bb);
    idx_body = b.load(idx_alloca, name="idx.body");
    key_ptr = b.gep(keys_arr, [idx_body], name="key.ptr");
    key_val = b.load(key_ptr, name="key.val");
    key_eq = self._emit_key_comparison(b, key_type, key_val, k_arg, _key_sz);
    b.cbranch(key_eq, found_bb, incr_bb);
    # Increment block
    b.position_at_end(incr_bb);
    idx_incr = b.load(idx_alloca, name="idx.incr");
    next_idx = b.add(idx_incr, ir.Constant(i64, 1), name="next.idx");
    b.store(next_idx, idx_alloca);
    b.branch(loop_cond_bb);
    # Found: update existing value
    b.position_at_end(found_bb);
    idx_found = b.load(idx_alloca, name="idx.found");
    val_ptr_found = b.gep(vals_arr, [idx_found], name="val.ptr.found");
    b.store(v_arg, val_ptr_found);
    b.ret_void();
    # Not found: check capacity and append
    b.position_at_end(not_found_bb);
    cur_cap = b.load(cap_p2, name="cap");
    need_grow = b.icmp_unsigned(">=", cur_len, cur_cap, name="need.grow");
    b.cbranch(need_grow, grow_bb, append_bb);
    # Grow block: grow both keys and vals arrays
    b.position_at_end(grow_bb);
    self._emit_grow_array(b, keys_p2, key_type, cur_len, cap_p2, cur_cap);
    # Reload cap after first grow (cap_p2 was updated)
    new_cap = b.load(cap_p2, name="new.cap.reload");
    # Grow vals — pass new_cap directly via a manual grow since cap is already doubled
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
    b.call(free_fn, [old_vals_i8]);
    b.store(new_vals, vals_p2);
    b.branch(append_bb);
    # Append block
    b.position_at_end(append_bb);
    # Reload keys/vals after possible grow
    keys_arr_app = b.load(keys_p2, name="keys.app");
    vals_arr_app = b.load(vals_p2, name="vals.app");
    cur_len_app = b.load(len_p2, name="len.app");
    key_slot = b.gep(keys_arr_app, [cur_len_app], name="key.slot");
    val_slot = b.gep(vals_arr_app, [cur_len_app], name="val.slot");
    b.store(k_arg, key_slot);
    b.store(v_arg, val_slot);
    new_len = b.add(cur_len_app, ir.Constant(i64, 1), name="new.len");
    b.store(new_len, len_p2);
    b.ret_void();
    # --- __dict_get: return value for key (linear search) ---
    get_fnty = ir.FunctionType(val_type, [dict_ptr_type, key_type]);
    get_fn = ir.Function(
        self.llvm_module, get_fnty, name=f"__dict_get_{key_type_name}_{val_type_name}"
    );
    get_fn.linkage = "private";
    get_fn.args[0].name = "dict";
    get_fn.args[1].name = "key";
    entry_bb_g = get_fn.append_basic_block("entry");
    loop_cond_g = get_fn.append_basic_block("loop.cond");
    loop_body_g = get_fn.append_basic_block("loop.body");
    incr_g = get_fn.append_basic_block("incr");
    found_g = get_fn.append_basic_block("found");
    not_found_g = get_fn.append_basic_block("not.found");
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
    idx_alloca_g = b.alloca(i64, name="idx");
    b.store(ir.Constant(i64, 0), idx_alloca_g);
    b.branch(loop_cond_g);
    # Loop cond
    b.position_at_end(loop_cond_g);
    idx_g = b.load(idx_alloca_g, name="idx");
    cmp_g = b.icmp_signed("<", idx_g, len_g, name="cmp");
    b.cbranch(cmp_g, loop_body_g, not_found_g);
    # Loop body - compare key, don't increment here
    b.position_at_end(loop_body_g);
    idx_bg = b.load(idx_alloca_g, name="idx.body");
    key_ptr_g = b.gep(keys_g, [idx_bg], name="key.ptr");
    key_val_g = b.load(key_ptr_g, name="key.val");
    key_eq_g = self._emit_key_comparison(b, key_type, key_val_g, k_arg_g, _key_sz);
    b.cbranch(key_eq_g, found_g, incr_g);
    # Increment block - only reached when not found
    b.position_at_end(incr_g);
    idx_incr = b.load(idx_alloca_g, name="idx.incr");
    next_idx_g = b.add(idx_incr, ir.Constant(i64, 1), name="next.idx");
    b.store(next_idx_g, idx_alloca_g);
    b.branch(loop_cond_g);
    # Found - idx_alloca still has the found index
    b.position_at_end(found_g);
    idx_fg = b.load(idx_alloca_g, name="idx.found");
    val_ptr_fg = b.gep(vals_g, [idx_fg], name="val.ptr");
    result_g = b.load(val_ptr_fg, name="result");
    b.ret(result_g);
    # Not found: return zero/null
    b.position_at_end(not_found_g);
    if isinstance(val_type, ir.PointerType) {
        b.ret(ir.Constant(val_type, None));
    } elif val_type?.elements and val_type.elements {
        # Struct type (e.g. JacVal): return zeroed struct
        zero_elems = [ir.Constant(e, 0) for e in val_type.elements];
        b.ret(ir.Constant(val_type, zero_elems));
    } else {
        b.ret(ir.Constant(val_type, 0));
    }
    # --- __dict_len: return len field ---
    len_fnty = ir.FunctionType(i64, [dict_ptr_type]);
    len_fn = ir.Function(
        self.llvm_module, len_fnty, name=f"__dict_len_{key_type_name}_{val_type_name}"
    );
    len_fn.linkage = "private";
    len_fn.args[0].name = "dict";
    bb_l = len_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb_l);
    lp = b.gep(
        len_fn.args[0], [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr"
    );
    length = b.load(lp, name="len");
    b.ret(length);
    # --- __dict_contains: return 1 if key exists, 0 otherwise ---
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
    loop_cond_c = contains_fn.append_basic_block("loop.cond");
    loop_body_c = contains_fn.append_basic_block("loop.body");
    found_c = contains_fn.append_basic_block("found");
    not_found_c = contains_fn.append_basic_block("not.found");
    b = ir.IRBuilder(entry_bb_c);
    d_arg_c = contains_fn.args[0];
    k_arg_c = contains_fn.args[1];
    len_pc = b.gep(d_arg_c, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr");
    keys_pc = b.gep(
        d_arg_c, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="keys.ptr"
    );
    len_c = b.load(len_pc, name="len");
    keys_c = b.load(keys_pc, name="keys");
    idx_alloca_c = b.alloca(i64, name="idx");
    b.store(ir.Constant(i64, 0), idx_alloca_c);
    b.branch(loop_cond_c);
    b.position_at_end(loop_cond_c);
    idx_c = b.load(idx_alloca_c, name="idx");
    cmp_c = b.icmp_signed("<", idx_c, len_c, name="cmp");
    b.cbranch(cmp_c, loop_body_c, not_found_c);
    b.position_at_end(loop_body_c);
    idx_bc = b.load(idx_alloca_c, name="idx.body");
    key_ptr_c = b.gep(keys_c, [idx_bc], name="key.ptr");
    key_val_c = b.load(key_ptr_c, name="key.val");
    key_eq_c = self._emit_key_comparison(b, key_type, key_val_c, k_arg_c, _key_sz);
    b.cbranch(key_eq_c, found_c, loop_cond_c);
    b.position_before(b.block.terminator);
    next_idx_c = b.add(idx_bc, ir.Constant(i64, 1), name="next.idx");
    b.store(next_idx_c, idx_alloca_c);
    b.position_at_end(found_c);
    b.ret(ir.Constant(ir.IntType(1), 1));
    b.position_at_end(not_found_c);
    b.ret(ir.Constant(ir.IntType(1), 0));
    # --- __dict_get_key: return key at index i (for iteration) ---
    get_key_fnty = ir.FunctionType(key_type, [dict_ptr_type, i64]);
    get_key_fn = ir.Function(
        self.llvm_module,
        get_key_fnty,
        name=f"__dict_get_key_{key_type_name}_{val_type_name}"
    );
    get_key_fn.linkage = "private";
    get_key_fn.args[0].name = "dict";
    get_key_fn.args[1].name = "idx";
    bb_gk = get_key_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb_gk);
    d_arg_gk = get_key_fn.args[0];
    idx_arg_gk = get_key_fn.args[1];
    keys_ptr_gk = b.gep(
        d_arg_gk, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="keys.ptr"
    );
    keys_arr_gk = b.load(keys_ptr_gk, name="keys");
    key_elem_ptr = b.gep(keys_arr_gk, [idx_arg_gk], name="key.elem.ptr");
    key_result = b.load(key_elem_ptr, name="key.result");
    b.ret(key_result);
    # --- __dict_get_val: return val at index i (for .items() iteration) ---
    get_val_fnty = ir.FunctionType(val_type, [dict_ptr_type, i64]);
    get_val_fn = ir.Function(
        self.llvm_module,
        get_val_fnty,
        name=f"__dict_get_val_{key_type_name}_{val_type_name}"
    );
    get_val_fn.linkage = "private";
    get_val_fn.args[0].name = "dict";
    get_val_fn.args[1].name = "idx";
    bb_gv = get_val_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb_gv);
    d_arg_gv = get_val_fn.args[0];
    idx_arg_gv = get_val_fn.args[1];
    vals_ptr_gv = b.gep(
        d_arg_gv, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vals.ptr"
    );
    vals_arr_gv = b.load(vals_ptr_gv, name="vals");
    val_elem_ptr = b.gep(vals_arr_gv, [idx_arg_gv], name="val.elem.ptr");
    val_result = b.load(val_elem_ptr, name="val.result");
    b.ret(val_result);
    # --- __rc_release_dict_K_V: type-specific destructor ---
    release_fnty = ir.FunctionType(ir.VoidType(), [dict_ptr_type]);
    release_fn = ir.Function(
        self.llvm_module,
        release_fnty,
        name=f"__rc_release_dict_{dict_key.replace(':', '_')}"
    );
    release_fn.linkage = "private";
    release_fn.args[0].name = "dict";
    (b, done_bb) = self._emit_rc_destructor_preamble(release_fn, dict_ptr_type);
    # Release pointer-typed keys if applicable (field index 2)
    if isinstance(key_type, ir.PointerType) {
        b = self._emit_rc_release_elem_loop(b, release_fn, release_fn.args[0], 2);
    }
    # Release pointer-typed vals if applicable (field index 3)
    if isinstance(val_type, ir.PointerType) {
        b = self._emit_rc_release_elem_loop(b, release_fn, release_fn.args[0], 3);
    }
    # Free keys array
    keys_p_f = b.gep(
        release_fn.args[0],
        [ir.Constant(i32, 0), ir.Constant(i32, 2)],
        name="keys.ptr.f"
    );
    keys_f = b.load(keys_p_f, name="keys.f");
    b.call(free_fn, [b.bitcast(keys_f, i8_ptr, name="keys.cast")]);
    # Free vals array
    vals_p_f = b.gep(
        release_fn.args[0],
        [ir.Constant(i32, 0), ir.Constant(i32, 3)],
        name="vals.ptr.f"
    );
    vals_f = b.load(vals_p_f, name="vals.f");
    b.call(free_fn, [b.bitcast(vals_f, i8_ptr, name="vals.cast")]);
    # Skip: bump allocator arena memory cannot be freed individually.
    b.branch(done_bb);
    b = ir.IRBuilder(done_bb);
    b.ret_void();
    self.dict_release_fns[dict_key] = release_fn;
    # Store helpers
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

"""Box any value into a JacVal tagged union {i8 tag, i64 payload}.

Tag 0 = int (i64 stored directly)
Tag 1 = float (f64 bitcast to i64)
Tag 2 = str (i8* ptrtoint to i64)
Tag 3 = list pointer (any List.T* ptrtoint to i64)
Tag 4 = dict pointer (any Dict.K:V* ptrtoint to i64)
Tag 5 = set pointer  (any Set.T* ptrtoint to i64)
"""
impl NaIRGenPass._box_to_jacval(value: ir.Value) -> ir.Value {
    b = self.builder;
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    jv_alloca = self._entry_alloca(self.jacval_type, "jacval");
    tag_ptr = b.gep(
        jv_alloca, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="jv.tag.ptr"
    );
    payload_ptr = b.gep(
        jv_alloca, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="jv.payload.ptr"
    );
    if isinstance(value.type, ir.IntType) and value.type.width == 1 {
        # bool (i1) → box as int (tag 0) via zero-extension
        b.store(ir.Constant(i8, 0), tag_ptr);
        ext = b.zext(value, i64, name="jv.bext");
        b.store(ext, payload_ptr);
    } elif isinstance(value.type, ir.IntType) {
        # Any integer width → zero/sign-extend to i64, tag 0
        b.store(ir.Constant(i8, 0), tag_ptr);
        if value.type.width == 64 {
            b.store(value, payload_ptr);
        } else {
            b.store(b.zext(value, i64, name="jv.iext"), payload_ptr);
        }
    } elif isinstance(value.type, ir.DoubleType) {
        # float → bitcast f64 to i64, tag 1
        b.store(ir.Constant(i8, 1), tag_ptr);
        payload = b.bitcast(value, i64, name="jv.f2i");
        b.store(payload, payload_ptr);
    } elif isinstance(value.type, ir.PointerType) {
        # Determine whether this is a list, dict, set, or plain string pointer.
        ptr_tag = 2;  # default: str (tag 2)
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
        b.store(ir.Constant(i8, ptr_tag), tag_ptr);
        payload = b.ptrtoint(value, i64, name="jv.p2i");
        b.store(payload, payload_ptr);
    } else {
        # Unknown type: store zero int
        b.store(ir.Constant(i8, 0), tag_ptr);
        b.store(ir.Constant(i64, 0), payload_ptr);
    }
    return b.load(jv_alloca, name="jacval");
}

"""Generate code for a dict literal {k1: v1, k2: v2, ...}."""
impl NaIRGenPass._codegen_dict_val(nd: uni.DictVal) -> (ir.Value | None) {
    if not nd.kv_pairs {
        # Empty dict: need type hint
        return None;
    }
    # Get first key-value pair to determine types
    first_pair = nd.kv_pairs[0];
    first_key = self._codegen_expr(first_pair.key);
    first_val = self._codegen_expr(first_pair.value);
    if first_key is None or first_val is None {
        return None;
    }
    # Check if we should box values into JacVal (dict[str, any])
    use_jacval = self._dict_val_type_hint == "jacval";
    # Determine type names
    key_type = first_key.type;
    key_type_name = "i64";
    key_size = 0;
    if isinstance(key_type, ir.DoubleType) {
        key_type_name = "f64";
    } elif isinstance(key_type, ir.PointerType) {
        key_type_name = "ptr";
        # Check if key is a tuple (pointer to LiteralStructType)
        if isinstance(key_type.pointee, ir.LiteralStructType) {
            key_size = self._get_struct_size(key_type.pointee);
            key_type_name = f"tuple{key_size}";
        }
    }
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
    # Ensure helpers exist
    self._emit_dict_helpers(key_type_name, val_type_name, key_type, val_type, key_size);
    helpers = self.dict_helpers[dict_key];
    # Create new dict
    dict_val = self.builder.call(helpers["new"], [], name="dict.new");
    # Add first pair (box if needed)
    first_store_val = self._box_to_jacval(first_val) if use_jacval else first_val;
    self.builder.call(helpers["set"], [dict_val, first_key, first_store_val]);
    # Add remaining pairs
    for i in range(1, len(nd.kv_pairs)) {
        pair = nd.kv_pairs[i];
        k = self._codegen_expr(pair.key);
        v = self._codegen_expr(pair.value);
        if k is not None and v is not None {
            k = self._coerce_type(k, key_type);
            if use_jacval {
                v = self._box_to_jacval(v);
            } else {
                v = self._coerce_type(v, val_type);
            }
            self.builder.call(helpers["set"], [dict_val, k, v]);
        }
    }
    return dict_val;
}

"""Get value from dictionary by key (with KeyError check)."""
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
    # KeyError: check if key exists before accessing
    key_exists = self.builder.call(
        helpers["contains"], [target_val, key_val], name="dict.has"
    );
    not_exists = self.builder.not_(key_exists, name="dict.nokey");
    self._emit_runtime_raise(not_exists, "KeyError", "key not found");
    return self.builder.call(helpers["get"], [target_val, key_val], name="dict.get");
}

"""Set value in dictionary by key."""
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
    key_val = self._coerce_type(key_val, key_type);
    value = self._coerce_type(value, val_type);
    self.builder.call(helpers["set"], [target_val, key_val, value]);
}
