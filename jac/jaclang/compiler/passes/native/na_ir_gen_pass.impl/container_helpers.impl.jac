"""Shared helper methods for list/dict/set container codegen.

These extract common patterns that were previously duplicated across
lists.impl.jac, dicts.impl.jac, and sets.impl.jac.
"""

"""Emit an element/key comparison for container lookup.

Dispatches based on type:
- IntType: icmp_signed ==
- i8* (string): strcmp == 0
- PointerType with known size: memcmp == 0
- PointerType (unknown size): icmp_unsigned ==
- Fallback: icmp_signed ==

Returns an i1 value (true if equal).
"""
impl NaIRGenPass._emit_key_comparison(
    b: ir.IRBuilder,
    key_type: ir.Type,
    stored_val: ir.Value,
    search_val: ir.Value,
    key_size: int = 0
) -> ir.Value {
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    if isinstance(key_type, ir.IntType) {
        return b.icmp_signed("==", stored_val, search_val, name="key.eq");
    } elif key_type == i8_ptr {
        strcmp_fn = self._get_or_declare_extern(
            "strcmp", ir.IntType(32), [i8_ptr, i8_ptr]
        );
        cmp_result = b.call(strcmp_fn, [stored_val, search_val], name="strcmp");
        return b.icmp_signed(
            "==", cmp_result, ir.Constant(ir.IntType(32), 0), name="key.eq"
        );
    } elif isinstance(key_type, ir.PointerType) and key_size > 0 {
        memcmp_fn = self._get_or_declare_extern(
            "memcmp", ir.IntType(32), [i8_ptr, i8_ptr, i64]
        );
        key_i8 = b.bitcast(stored_val, i8_ptr, name="key.i8");
        arg_i8 = b.bitcast(search_val, i8_ptr, name="arg.i8");
        cmp_result = b.call(
            memcmp_fn, [key_i8, arg_i8, ir.Constant(i64, key_size)], name="memcmp"
        );
        return b.icmp_signed(
            "==", cmp_result, ir.Constant(ir.IntType(32), 0), name="key.eq"
        );
    } elif isinstance(key_type, ir.PointerType) {
        return b.icmp_unsigned("==", stored_val, search_val, name="key.eq");
    } else {
        return b.icmp_signed("==", stored_val, search_val, name="key.eq");
    }
}

"""Allocate an RC-managed container struct and its data arrays.

Args:
    b: IRBuilder positioned in the entry block of the constructor
    container_ptr_type: The pointer type of the container struct
    data_types: List of element types for the data arrays (1 for list/set, 2 for dict)
    initial_cap: Initial capacity (default 8)

Returns:
    (container_ptr, data_pointers...) tuple — the RC-allocated container
    and the stored data array pointers.
"""
impl NaIRGenPass._emit_rc_alloc_container(
    b: ir.IRBuilder,
    container_ptr_type: ir.Type,
    data_types: list,
    initial_cap: int = 8
) -> tuple {
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    i8_ptr = ir.IntType(8).as_pointer();
    malloc_fn = self._get_or_declare_extern("malloc", i8_ptr, [i64]);
    # Allocate container struct via rc_alloc
    null_ptr = ir.Constant(container_ptr_type, None);
    size_gep = b.gep(null_ptr, [ir.Constant(i32, 1)], name="sizeof");
    struct_size = b.ptrtoint(size_gep, i64, name="size");
    raw = b.call(self.rc_alloc_fn, [struct_size], name="raw");
    container_ptr = b.bitcast(raw, container_ptr_type, name="container");
    # len = 0
    len_p = b.gep(
        container_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr"
    );
    b.store(ir.Constant(i64, 0), len_p);
    # cap = initial_cap
    cap_p = b.gep(
        container_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cap.ptr"
    );
    b.store(ir.Constant(i64, initial_cap), cap_p);
    # Allocate data arrays
    data_ptrs = [];
    for (i, dtype) in enumerate(data_types) {
        field_idx = i + 2;  # fields 0=len, 1=cap, 2+=data
        elem_null = ir.Constant(dtype.as_pointer(), None);
        elem_gep = b.gep(elem_null, [ir.Constant(i32, 1)], name=f"elem{i}.sizeof");
        elem_size = b.ptrtoint(elem_gep, i64, name=f"elem{i}.size");
        data_bytes = b.mul(
            ir.Constant(i64, initial_cap), elem_size, name=f"data{i}.bytes"
        );
        data_raw = b.call(malloc_fn, [data_bytes], name=f"data{i}.raw");
        data = b.bitcast(data_raw, dtype.as_pointer(), name=f"data{i}");
        data_p = b.gep(
            container_ptr,
            [ir.Constant(i32, 0), ir.Constant(i32, field_idx)],
            name=f"data{i}.ptr"
        );
        b.store(data, data_p);
        data_ptrs.append(data);
    }
    return tuple([container_ptr] + data_ptrs);
}

"""Emit capacity-doubling grow logic for a data array.

Doubles capacity, mallocs new array, memcpys old data, frees old array,
stores new array back. Returns the new data pointer.

Args:
    b: IRBuilder positioned in the grow basic block
    arr_ptr: GEP pointer to the data array field in the container
    elem_type: Element type of the array
    cur_len: Current length (for memcpy size)
    cap_ptr: GEP pointer to the capacity field
    cur_cap: Current capacity value
"""
impl NaIRGenPass._emit_grow_array(
    b: ir.IRBuilder,
    arr_ptr: ir.Value,
    elem_type: ir.Type,
    cur_len: ir.Value,
    cap_ptr: ir.Value,
    cur_cap: ir.Value
) -> ir.Value {
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    i8_ptr = ir.IntType(8).as_pointer();
    malloc_fn = self._get_or_declare_extern("malloc", i8_ptr, [i64]);
    free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8_ptr]);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8_ptr, [i8_ptr, i8_ptr, i64]);
    new_cap = b.mul(cur_cap, ir.Constant(i64, 2), name="new.cap");
    b.store(new_cap, cap_ptr);
    elem_null = ir.Constant(elem_type.as_pointer(), None);
    elem_gep = b.gep(elem_null, [ir.Constant(i32, 1)], name="elem.sizeof");
    elem_sz = b.ptrtoint(elem_gep, i64, name="elem.size");
    new_bytes = b.mul(new_cap, elem_sz, name="new.bytes");
    new_data_raw = b.call(malloc_fn, [new_bytes], name="new.data.raw");
    new_data = b.bitcast(new_data_raw, elem_type.as_pointer(), name="new.data");
    old_data = b.load(arr_ptr, name="old.data");
    old_bytes = b.mul(cur_len, elem_sz, name="old.bytes");
    old_i8 = b.bitcast(old_data, i8_ptr, name="old.i8");
    new_i8 = b.bitcast(new_data, i8_ptr, name="new.i8");
    b.call(memcpy_fn, [new_i8, old_i8, old_bytes]);
    b.call(free_fn, [old_i8]);
    b.store(new_data, arr_ptr);
    return new_data;
}

"""Emit the standard RC destructor preamble: null-check, decrement, branch-if-zero.

Creates the basic block structure:
    entry -> dec -> (free_bb if zero, done_bb if nonzero)

Returns:
    (free_bb_builder, done_bb) — caller should emit cleanup in free_bb,
    then branch to done_bb and emit ret_void there.
"""
impl NaIRGenPass._emit_rc_destructor_preamble(
    release_fn: ir.Function, ptr_type: ir.Type
) -> tuple {
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    entry_bb = release_fn.append_basic_block("entry");
    dec_bb = release_fn.append_basic_block("dec");
    free_bb = release_fn.append_basic_block("do_free");
    done_bb = release_fn.append_basic_block("done");
    b = ir.IRBuilder(entry_bb);
    # Null check
    is_null = b.icmp_unsigned(
        "==", release_fn.args[0], ir.Constant(ptr_type, None), name="is.null"
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
    # Return builder positioned at free_bb and the done_bb for later use
    free_builder = ir.IRBuilder(free_bb);
    return (free_builder, done_bb);
}

"""Emit a loop that releases all pointer-typed elements in a container data array.

Iterates data[0..len-1] calling rc_release_simple on each element.
Used for list data, dict keys, dict vals, and set elems.

Args:
    b: IRBuilder positioned in the free block
    release_fn: The destructor function (to append basic blocks)
    container_arg: The container pointer argument (release_fn.args[0])
    data_field_idx: Struct field index of the data array (2 for list/set, 2 or 3 for dict)

Returns:
    Updated IRBuilder positioned after the loop.
"""
impl NaIRGenPass._emit_rc_release_elem_loop(
    b: ir.IRBuilder,
    release_fn: ir.Function,
    container_arg: ir.Value,
    data_field_idx: int
) -> ir.IRBuilder {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8_ptr = ir.IntType(8).as_pointer();
    # Load len and data array
    len_p = b.gep(
        container_arg, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr.rel"
    );
    cur_len = b.load(len_p, name="len.rel");
    data_p = b.gep(
        container_arg,
        [ir.Constant(i32, 0), ir.Constant(i32, data_field_idx)],
        name="data.ptr.rel"
    );
    data_arr = b.load(data_p, name="data.rel");
    # Loop: i = 0; while i < len { release(data[i]); i++ }
    loop_alloca = b.alloca(i64, name="loop.rel");
    b.store(ir.Constant(i64, 0), loop_alloca);
    lcond = release_fn.append_basic_block("loop.cond.rel");
    lbody = release_fn.append_basic_block("loop.body.rel");
    lend = release_fn.append_basic_block("loop.end.rel");
    b.branch(lcond);
    b = ir.IRBuilder(lcond);
    li = b.load(loop_alloca, name="li.rel");
    b.cbranch(b.icmp_unsigned("<", li, cur_len, name="cmp.rel"), lbody, lend);
    b = ir.IRBuilder(lbody);
    ep = b.gep(data_arr, [b.load(loop_alloca, name="li2.rel")], name="elem.ptr.rel");
    ev = b.load(ep, name="elem.val.rel");
    b.call(self.rc_release_simple_fn, [b.bitcast(ev, i8_ptr, name="elem.cast.rel")]);
    b.store(
        b.add(
            b.load(loop_alloca, name="li3.rel"), ir.Constant(i64, 1), name="inc.rel"
        ),
        loop_alloca
    );
    b.branch(lcond);
    return ir.IRBuilder(lend);
}
