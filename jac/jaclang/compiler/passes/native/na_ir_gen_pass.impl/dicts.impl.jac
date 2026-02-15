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
    key_type_name: str, val_type_name: str, key_type: ir.Type, val_type: ir.Type
) -> None {
    dict_key = f"{key_type_name}:{val_type_name}";
    if dict_key in self.dict_helpers {
        return;
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
    gc_malloc = self._get_or_declare_extern("GC_malloc", i8_ptr, [i64]);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8_ptr, [i8_ptr, i8_ptr, i64]);
    # --- __dict_new: create an empty dict with capacity 8 ---
    new_fnty = ir.FunctionType(dict_ptr_type, []);
    new_fn = ir.Function(
        self.llvm_module, new_fnty, name=f"__dict_new_{key_type_name}_{val_type_name}"
    );
    new_fn.linkage = "private";
    bb = new_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    # Allocate dict struct
    null_ptr = ir.Constant(dict_ptr_type, None);
    size_gep = b.gep(null_ptr, [ir.Constant(i32, 1)], name="sizeof");
    struct_size = b.ptrtoint(size_gep, i64, name="size");
    raw = b.call(gc_malloc, [struct_size], name="raw");
    dict_ptr = b.bitcast(raw, dict_ptr_type, name="dict");
    # len = 0
    len_p = b.gep(dict_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr");
    b.store(ir.Constant(i64, 0), len_p);
    # cap = 8
    cap_p = b.gep(dict_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cap.ptr");
    b.store(ir.Constant(i64, 8), cap_p);
    # Allocate keys: 8 * sizeof(key)
    key_null = ir.Constant(key_type.as_pointer(), None);
    key_gep = b.gep(key_null, [ir.Constant(i32, 1)], name="key.sizeof");
    key_size = b.ptrtoint(key_gep, i64, name="key.size");
    keys_bytes = b.mul(ir.Constant(i64, 8), key_size, name="keys.bytes");
    keys_raw = b.call(gc_malloc, [keys_bytes], name="keys.raw");
    keys = b.bitcast(keys_raw, key_type.as_pointer(), name="keys");
    keys_p = b.gep(
        dict_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="keys.ptr"
    );
    b.store(keys, keys_p);
    # Allocate vals: 8 * sizeof(val)
    val_null = ir.Constant(val_type.as_pointer(), None);
    val_gep = b.gep(val_null, [ir.Constant(i32, 1)], name="val.sizeof");
    val_size = b.ptrtoint(val_gep, i64, name="val.size");
    vals_bytes = b.mul(ir.Constant(i64, 8), val_size, name="vals.bytes");
    vals_raw = b.call(gc_malloc, [vals_bytes], name="vals.raw");
    vals = b.bitcast(vals_raw, val_type.as_pointer(), name="vals");
    vals_p = b.gep(
        dict_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="vals.ptr"
    );
    b.store(vals, vals_p);
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
    # Compare keys - use strcmp for string keys (i8*)
    if isinstance(key_type, ir.IntType) {
        key_eq = b.icmp_signed("==", key_val, k_arg, name="key.eq");
    } elif key_type == i8_ptr {
        # String comparison using strcmp
        strcmp_fn = self._get_or_declare_extern(
            "strcmp", ir.IntType(32), [i8_ptr, i8_ptr]
        );
        cmp_result = b.call(strcmp_fn, [key_val, k_arg], name="strcmp");
        key_eq = b.icmp_signed(
            "==", cmp_result, ir.Constant(ir.IntType(32), 0), name="key.eq"
        );
    } elif isinstance(key_type, ir.PointerType) {
        key_eq = b.icmp_unsigned("==", key_val, k_arg, name="key.eq");
    } else {
        key_eq = b.icmp_signed("==", key_val, k_arg, name="key.eq");
    }
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
    # Grow block
    b.position_at_end(grow_bb);
    new_cap = b.mul(cur_cap, ir.Constant(i64, 2), name="new.cap");
    b.store(new_cap, cap_p2);
    # Reallocate keys
    key_null2 = ir.Constant(key_type.as_pointer(), None);
    key_gep2 = b.gep(key_null2, [ir.Constant(i32, 1)], name="key.sizeof");
    key_sz = b.ptrtoint(key_gep2, i64, name="key.size");
    new_keys_bytes = b.mul(new_cap, key_sz, name="new.keys.bytes");
    new_keys_raw = b.call(gc_malloc, [new_keys_bytes], name="new.keys.raw");
    new_keys = b.bitcast(new_keys_raw, key_type.as_pointer(), name="new.keys");
    old_keys_bytes = b.mul(cur_len, key_sz, name="old.keys.bytes");
    old_keys_i8 = b.bitcast(keys_arr, i8_ptr, name="old.keys.i8");
    new_keys_i8 = b.bitcast(new_keys, i8_ptr, name="new.keys.i8");
    b.call(memcpy_fn, [new_keys_i8, old_keys_i8, old_keys_bytes]);
    b.store(new_keys, keys_p2);
    # Reallocate vals
    val_null2 = ir.Constant(val_type.as_pointer(), None);
    val_gep2 = b.gep(val_null2, [ir.Constant(i32, 1)], name="val.sizeof");
    val_sz = b.ptrtoint(val_gep2, i64, name="val.size");
    new_vals_bytes = b.mul(new_cap, val_sz, name="new.vals.bytes");
    new_vals_raw = b.call(gc_malloc, [new_vals_bytes], name="new.vals.raw");
    new_vals = b.bitcast(new_vals_raw, val_type.as_pointer(), name="new.vals");
    old_vals_bytes = b.mul(cur_len, val_sz, name="old.vals.bytes");
    old_vals_i8 = b.bitcast(vals_arr, i8_ptr, name="old.vals.i8");
    new_vals_i8 = b.bitcast(new_vals, i8_ptr, name="new.vals.i8");
    b.call(memcpy_fn, [new_vals_i8, old_vals_i8, old_vals_bytes]);
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
    # Use strcmp for string keys
    if isinstance(key_type, ir.IntType) {
        key_eq_g = b.icmp_signed("==", key_val_g, k_arg_g, name="key.eq");
    } elif key_type == i8_ptr {
        strcmp_fn = self._get_or_declare_extern(
            "strcmp", ir.IntType(32), [i8_ptr, i8_ptr]
        );
        cmp_result_g = b.call(strcmp_fn, [key_val_g, k_arg_g], name="strcmp");
        key_eq_g = b.icmp_signed(
            "==", cmp_result_g, ir.Constant(ir.IntType(32), 0), name="key.eq"
        );
    } elif isinstance(key_type, ir.PointerType) {
        key_eq_g = b.icmp_unsigned("==", key_val_g, k_arg_g, name="key.eq");
    } else {
        key_eq_g = b.icmp_signed("==", key_val_g, k_arg_g, name="key.eq");
    }
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
    # Use strcmp for string keys
    if isinstance(key_type, ir.IntType) {
        key_eq_c = b.icmp_signed("==", key_val_c, k_arg_c, name="key.eq");
    } elif key_type == i8_ptr {
        strcmp_fn = self._get_or_declare_extern(
            "strcmp", ir.IntType(32), [i8_ptr, i8_ptr]
        );
        cmp_result_c = b.call(strcmp_fn, [key_val_c, k_arg_c], name="strcmp");
        key_eq_c = b.icmp_signed(
            "==", cmp_result_c, ir.Constant(ir.IntType(32), 0), name="key.eq"
        );
    } elif isinstance(key_type, ir.PointerType) {
        key_eq_c = b.icmp_unsigned("==", key_val_c, k_arg_c, name="key.eq");
    } else {
        key_eq_c = b.icmp_signed("==", key_val_c, k_arg_c, name="key.eq");
    }
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
    # Store helpers
    self.dict_helpers[dict_key] = {
        "new": new_fn,
        "set": set_fn,
        "get": get_fn,
        "len": len_fn,
        "contains": contains_fn,
        "get_key": get_key_fn,
        "key_type": key_type,
        "val_type": val_type
    };
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
    # Determine type names
    key_type = first_key.type;
    val_type = first_val.type;
    key_type_name = "i64";
    val_type_name = "i64";
    if isinstance(key_type, ir.DoubleType) {
        key_type_name = "f64";
    } elif isinstance(key_type, ir.PointerType) {
        key_type_name = "ptr";
    }
    if isinstance(val_type, ir.DoubleType) {
        val_type_name = "f64";
    } elif isinstance(val_type, ir.PointerType) {
        val_type_name = "ptr";
    }
    dict_key = f"{key_type_name}:{val_type_name}";
    # Ensure helpers exist
    self._emit_dict_helpers(key_type_name, val_type_name, key_type, val_type);
    helpers = self.dict_helpers[dict_key];
    # Create new dict
    dict_val = self.builder.call(helpers["new"], [], name="dict.new");
    # Add first pair
    self.builder.call(helpers["set"], [dict_val, first_key, first_val]);
    # Add remaining pairs
    for i in range(1, len(nd.kv_pairs)) {
        pair = nd.kv_pairs[i];
        k = self._codegen_expr(pair.key);
        v = self._codegen_expr(pair.value);
        if k is not None and v is not None {
            k = self._coerce_type(k, key_type);
            v = self._coerce_type(v, val_type);
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
