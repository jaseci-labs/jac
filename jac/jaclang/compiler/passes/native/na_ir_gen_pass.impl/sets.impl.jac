"""Set type codegen and operations."""
"""Emit LLVM IR helper functions for a set with given element type.

Uses a simple linear-search set: {len, cap, elems*}
This is O(n) for lookups but sufficient for small sets.

For pointer types with known size (e.g., tuples), uses memcmp for comparison.
"""
impl NaIRGenPass._emit_set_helpers(
    elem_type_name: str, elem_type: ir.Type, elem_size: int = 0
) -> None {
    if elem_type_name in self.set_helpers {
        return;
    }
    # Create set struct type: { i64 len, i64 cap, elem_type* elems }
    set_struct = self.llvm_module.context.get_identified_type(f"Set.{elem_type_name}");
    set_struct.set_body(ir.IntType(64), ir.IntType(64), elem_type.as_pointer());
    self.set_types[elem_type_name] = set_struct;
    set_ptr_type = set_struct.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    i8_ptr = ir.IntType(8).as_pointer();
    gc_malloc = self._get_or_declare_extern("GC_malloc", i8_ptr, [i64]);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8_ptr, [i8_ptr, i8_ptr, i64]);
    # --- __set_new: create an empty set with capacity 8 ---
    new_fnty = ir.FunctionType(set_ptr_type, []);
    new_fn = ir.Function(
        self.llvm_module, new_fnty, name=f"__set_new_{elem_type_name}"
    );
    new_fn.linkage = "private";
    bb = new_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    # Allocate set struct
    null_ptr = ir.Constant(set_ptr_type, None);
    size_gep = b.gep(null_ptr, [ir.Constant(i32, 1)], name="sizeof");
    struct_size = b.ptrtoint(size_gep, i64, name="size");
    raw = b.call(gc_malloc, [struct_size], name="raw");
    set_ptr = b.bitcast(raw, set_ptr_type, name="set");
    # len = 0
    len_p = b.gep(set_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr");
    b.store(ir.Constant(i64, 0), len_p);
    # cap = 8
    cap_p = b.gep(set_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cap.ptr");
    b.store(ir.Constant(i64, 8), cap_p);
    # Allocate elems: 8 * sizeof(elem)
    elem_null = ir.Constant(elem_type.as_pointer(), None);
    elem_gep = b.gep(elem_null, [ir.Constant(i32, 1)], name="elem.sizeof");
    elem_sizeof_val = b.ptrtoint(elem_gep, i64, name="elem.size");
    elems_bytes = b.mul(ir.Constant(i64, 8), elem_sizeof_val, name="elems.bytes");
    elems_raw = b.call(gc_malloc, [elems_bytes], name="elems.raw");
    elems = b.bitcast(elems_raw, elem_type.as_pointer(), name="elems");
    elems_p = b.gep(
        set_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="elems.ptr"
    );
    b.store(elems, elems_p);
    b.ret(set_ptr);
    # --- __set_add: add element if not already present ---
    add_fnty = ir.FunctionType(ir.VoidType(), [set_ptr_type, elem_type]);
    add_fn = ir.Function(
        self.llvm_module, add_fnty, name=f"__set_add_{elem_type_name}"
    );
    add_fn.linkage = "private";
    add_fn.args[0].name = "set";
    add_fn.args[1].name = "elem";
    entry_bb = add_fn.append_basic_block("entry");
    loop_cond_bb = add_fn.append_basic_block("loop.cond");
    loop_body_bb = add_fn.append_basic_block("loop.body");
    found_bb = add_fn.append_basic_block("found");
    not_found_bb = add_fn.append_basic_block("not.found");
    grow_bb = add_fn.append_basic_block("grow");
    append_bb = add_fn.append_basic_block("append");
    b = ir.IRBuilder(entry_bb);
    s_arg = add_fn.args[0];
    e_arg = add_fn.args[1];
    # Load len, cap, elems
    len_p2 = b.gep(s_arg, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr");
    cap_p2 = b.gep(s_arg, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cap.ptr");
    elems_p2 = b.gep(
        s_arg, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="elems.ptr"
    );
    cur_len = b.load(len_p2, name="len");
    elems_arr = b.load(elems_p2, name="elems");
    # Allocate loop index
    idx_alloca = b.alloca(i64, name="idx");
    b.store(ir.Constant(i64, 0), idx_alloca);
    b.branch(loop_cond_bb);
    # Loop condition: idx < len
    b.position_at_end(loop_cond_bb);
    idx = b.load(idx_alloca, name="idx");
    cmp = b.icmp_signed("<", idx, cur_len, name="cmp");
    b.cbranch(cmp, loop_body_bb, not_found_bb);
    # Loop body: compare element
    b.position_at_end(loop_body_bb);
    idx_body = b.load(idx_alloca, name="idx.body");
    elem_ptr = b.gep(elems_arr, [idx_body], name="elem.ptr");
    elem_val = b.load(elem_ptr, name="elem.val");
    # Compare elements - use strcmp for strings, memcmp for tuples, etc.
    if isinstance(elem_type, ir.IntType) {
        elem_eq = b.icmp_signed("==", elem_val, e_arg, name="elem.eq");
    } elif elem_type == i8_ptr {
        strcmp_fn = self._get_or_declare_extern(
            "strcmp", ir.IntType(32), [i8_ptr, i8_ptr]
        );
        cmp_result = b.call(strcmp_fn, [elem_val, e_arg], name="strcmp");
        elem_eq = b.icmp_signed(
            "==", cmp_result, ir.Constant(ir.IntType(32), 0), name="elem.eq"
        );
    } elif isinstance(elem_type, ir.PointerType) and elem_size > 0 {
        # Pointer with known size (e.g., tuples) - use memcmp
        memcmp_fn = self._get_or_declare_extern(
            "memcmp", ir.IntType(32), [i8_ptr, i8_ptr, i64]
        );
        elem_i8 = b.bitcast(elem_val, i8_ptr, name="elem.i8");
        arg_i8 = b.bitcast(e_arg, i8_ptr, name="arg.i8");
        cmp_result = b.call(
            memcmp_fn, [elem_i8, arg_i8, ir.Constant(i64, elem_size)], name="memcmp"
        );
        elem_eq = b.icmp_signed(
            "==", cmp_result, ir.Constant(ir.IntType(32), 0), name="elem.eq"
        );
    } elif isinstance(elem_type, ir.PointerType) {
        elem_eq = b.icmp_unsigned("==", elem_val, e_arg, name="elem.eq");
    } else {
        elem_eq = b.icmp_signed("==", elem_val, e_arg, name="elem.eq");
    }
    b.cbranch(elem_eq, found_bb, loop_cond_bb);
    # Increment index before next iteration
    b.position_before(b.block.terminator);
    next_idx = b.add(idx_body, ir.Constant(i64, 1), name="next.idx");
    b.store(next_idx, idx_alloca);
    # Found: already exists, return
    b.position_at_end(found_bb);
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
    elem_null2 = ir.Constant(elem_type.as_pointer(), None);
    elem_gep2 = b.gep(elem_null2, [ir.Constant(i32, 1)], name="elem.sizeof");
    elem_sz = b.ptrtoint(elem_gep2, i64, name="elem.size");
    new_elems_bytes = b.mul(new_cap, elem_sz, name="new.elems.bytes");
    new_elems_raw = b.call(gc_malloc, [new_elems_bytes], name="new.elems.raw");
    new_elems = b.bitcast(new_elems_raw, elem_type.as_pointer(), name="new.elems");
    old_elems_bytes = b.mul(cur_len, elem_sz, name="old.elems.bytes");
    old_elems_i8 = b.bitcast(elems_arr, i8_ptr, name="old.elems.i8");
    new_elems_i8 = b.bitcast(new_elems, i8_ptr, name="new.elems.i8");
    b.call(memcpy_fn, [new_elems_i8, old_elems_i8, old_elems_bytes]);
    b.store(new_elems, elems_p2);
    b.branch(append_bb);
    # Append block
    b.position_at_end(append_bb);
    # Reload elems after possible grow
    elems_arr_app = b.load(elems_p2, name="elems.app");
    cur_len_app = b.load(len_p2, name="len.app");
    elem_slot = b.gep(elems_arr_app, [cur_len_app], name="elem.slot");
    b.store(e_arg, elem_slot);
    new_len = b.add(cur_len_app, ir.Constant(i64, 1), name="new.len");
    b.store(new_len, len_p2);
    b.ret_void();
    # --- __set_contains: return 1 if element exists, 0 otherwise ---
    contains_fnty = ir.FunctionType(ir.IntType(1), [set_ptr_type, elem_type]);
    contains_fn = ir.Function(
        self.llvm_module, contains_fnty, name=f"__set_contains_{elem_type_name}"
    );
    contains_fn.linkage = "private";
    contains_fn.args[0].name = "set";
    contains_fn.args[1].name = "elem";
    entry_bb_c = contains_fn.append_basic_block("entry");
    loop_cond_c = contains_fn.append_basic_block("loop.cond");
    loop_body_c = contains_fn.append_basic_block("loop.body");
    found_c = contains_fn.append_basic_block("found");
    not_found_c = contains_fn.append_basic_block("not.found");
    b = ir.IRBuilder(entry_bb_c);
    s_arg_c = contains_fn.args[0];
    e_arg_c = contains_fn.args[1];
    len_pc = b.gep(s_arg_c, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr");
    elems_pc = b.gep(
        s_arg_c, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="elems.ptr"
    );
    len_c = b.load(len_pc, name="len");
    elems_c = b.load(elems_pc, name="elems");
    idx_alloca_c = b.alloca(i64, name="idx");
    b.store(ir.Constant(i64, 0), idx_alloca_c);
    b.branch(loop_cond_c);
    b.position_at_end(loop_cond_c);
    idx_c = b.load(idx_alloca_c, name="idx");
    cmp_c = b.icmp_signed("<", idx_c, len_c, name="cmp");
    b.cbranch(cmp_c, loop_body_c, not_found_c);
    b.position_at_end(loop_body_c);
    idx_bc = b.load(idx_alloca_c, name="idx.body");
    elem_ptr_c = b.gep(elems_c, [idx_bc], name="elem.ptr");
    elem_val_c = b.load(elem_ptr_c, name="elem.val");
    # Use strcmp for strings, memcmp for tuples, etc.
    if isinstance(elem_type, ir.IntType) {
        elem_eq_c = b.icmp_signed("==", elem_val_c, e_arg_c, name="elem.eq");
    } elif elem_type == i8_ptr {
        strcmp_fn = self._get_or_declare_extern(
            "strcmp", ir.IntType(32), [i8_ptr, i8_ptr]
        );
        cmp_result_c = b.call(strcmp_fn, [elem_val_c, e_arg_c], name="strcmp");
        elem_eq_c = b.icmp_signed(
            "==", cmp_result_c, ir.Constant(ir.IntType(32), 0), name="elem.eq"
        );
    } elif isinstance(elem_type, ir.PointerType) and elem_size > 0 {
        # Pointer with known size (e.g., tuples) - use memcmp
        memcmp_fn = self._get_or_declare_extern(
            "memcmp", ir.IntType(32), [i8_ptr, i8_ptr, i64]
        );
        elem_i8_c = b.bitcast(elem_val_c, i8_ptr, name="elem.i8");
        arg_i8_c = b.bitcast(e_arg_c, i8_ptr, name="arg.i8");
        cmp_result_c = b.call(
            memcmp_fn,
            [elem_i8_c, arg_i8_c, ir.Constant(i64, elem_size)],
            name="memcmp"
        );
        elem_eq_c = b.icmp_signed(
            "==", cmp_result_c, ir.Constant(ir.IntType(32), 0), name="elem.eq"
        );
    } elif isinstance(elem_type, ir.PointerType) {
        elem_eq_c = b.icmp_unsigned("==", elem_val_c, e_arg_c, name="elem.eq");
    } else {
        elem_eq_c = b.icmp_signed("==", elem_val_c, e_arg_c, name="elem.eq");
    }
    b.cbranch(elem_eq_c, found_c, loop_cond_c);
    b.position_before(b.block.terminator);
    next_idx_c = b.add(idx_bc, ir.Constant(i64, 1), name="next.idx");
    b.store(next_idx_c, idx_alloca_c);
    b.position_at_end(found_c);
    b.ret(ir.Constant(ir.IntType(1), 1));
    b.position_at_end(not_found_c);
    b.ret(ir.Constant(ir.IntType(1), 0));
    # --- __set_len: return len field ---
    len_fnty = ir.FunctionType(i64, [set_ptr_type]);
    len_fn = ir.Function(
        self.llvm_module, len_fnty, name=f"__set_len_{elem_type_name}"
    );
    len_fn.linkage = "private";
    len_fn.args[0].name = "set";
    bb_l = len_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb_l);
    lp = b.gep(
        len_fn.args[0], [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr"
    );
    length = b.load(lp, name="len");
    b.ret(length);
    # Store helpers
    self.set_helpers[elem_type_name] = {
        "new": new_fn,
        "add": add_fn,
        "contains": contains_fn,
        "len": len_fn,
        "elem_type": elem_type,
        "elem_size": elem_size
    };
}

"""Generate code for a set literal {a, b, c, ...}."""
impl NaIRGenPass._codegen_set_val(nd: uni.SetVal) -> (ir.Value | None) {
    if not nd.values {
        # Empty set: need type hint
        return None;
    }
    # Get first element to determine type
    first_val = self._codegen_expr(nd.values[0]);
    if first_val is None {
        return None;
    }
    # Determine type name and size for pointer types (e.g., tuples)
    elem_type = first_val.type;
    elem_type_name = "i64";
    elem_size = 0;
    if isinstance(elem_type, ir.DoubleType) {
        elem_type_name = "f64";
    } elif isinstance(elem_type, ir.PointerType) {
        elem_type_name = "ptr";
        # Check if this is a tuple (pointer to LiteralStructType)
        if isinstance(elem_type.pointee, ir.LiteralStructType) {
            elem_size = self._get_struct_size(elem_type.pointee);
            elem_type_name = f"tuple{elem_size}";
        }
    }
    # Ensure helpers exist
    self._emit_set_helpers(elem_type_name, elem_type, elem_size);
    helpers = self.set_helpers[elem_type_name];
    # Create new set
    set_val = self.builder.call(helpers["new"], [], name="set.new");
    # Add first element
    self.builder.call(helpers["add"], [set_val, first_val]);
    # Add remaining elements
    for i in range(1, len(nd.values)) {
        val = self._codegen_expr(nd.values[i]);
        if val is not None {
            val = self._coerce_type(val, elem_type);
            self.builder.call(helpers["add"], [set_val, val]);
        }
    }
    return set_val;
}

"""Check if element is in set."""
impl NaIRGenPass._codegen_set_contains(
    set_val: ir.Value, elem_val: ir.Value, elem_type_name: str
) -> (ir.Value | None) {
    helpers = self.set_helpers.get(elem_type_name);
    if helpers is None {
        return None;
    }
    elem_type = helpers["elem_type"];
    elem_val = self._coerce_type(elem_val, elem_type);
    return self.builder.call(
        helpers["contains"], [set_val, elem_val], name="set.contains"
    );
}

"""Add element to set."""
impl NaIRGenPass._codegen_set_add(
    set_val: ir.Value, elem_val: ir.Value, elem_type_name: str
) -> None {
    helpers = self.set_helpers.get(elem_type_name);
    if helpers is None {
        return;
    }
    elem_type = helpers["elem_type"];
    elem_val = self._coerce_type(elem_val, elem_type);
    self.builder.call(helpers["add"], [set_val, elem_val]);
}
