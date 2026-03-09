"""Reference counting infrastructure for native memory management.

Emits LLVM IR helper functions for RC allocation, retain, and release.
Replaces Boehm GC (GC_malloc) with a self-contained refcount scheme.

Memory layout: [ i64 refcount | ... user data ... ]
               ^               ^
               malloc'd ptr    user-visible ptr (returned by rc_alloc)

Static strings use a sentinel refcount (INT64_MAX) embedded in a global
constant struct { i64 sentinel, [N x i8] data }. The retain/release helpers
skip operations when the sentinel is detected, so static strings are never
freed or modified.
"""

# Sentinel refcount value for static (immortal) strings.
# INT64_MAX = 0x7FFFFFFFFFFFFFFF — never reaches 0 even if accidentally decremented.
glob RC_SENTINEL: int = 0x7FFFFFFFFFFFFFFF;

"""Emit core RC helper functions: __rc_alloc, __rc_retain, __rc_release_simple.

Called once at the start of transform(). Also declares malloc and free.
"""
impl NaIRGenPass._emit_rc_helpers -> None {
    i8 = ir.IntType(8);
    i8_ptr = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();

    # Declare malloc and free as extern functions
    self.malloc_fn = self._get_or_declare_extern("malloc", i8_ptr, [i64]);
    self.free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8_ptr]);

    # --- Bump allocator arena globals ---
    # Uses chained arenas: when one fills up, a new one is malloc'd.
    # Arena size chosen to balance page-fault cost vs fragmentation.
    ARENA_SIZE = 128 * 1024 * 1024;  # 128 MB per arena
    arena_base_gv = ir.GlobalVariable(self.llvm_module, i8_ptr, name="__jac_arena_base");
    arena_base_gv.linkage = "private";
    arena_base_gv.initializer = ir.Constant(i8_ptr, None);
    arena_offset_gv = ir.GlobalVariable(self.llvm_module, i64, name="__jac_arena_off");
    arena_offset_gv.linkage = "private";
    arena_offset_gv.initializer = ir.Constant(i64, 0);
    arena_size_const = ir.Constant(i64, ARENA_SIZE);

    # --- __rc_alloc(i64 size) -> i8* ---
    # Bump allocator with chained arenas (128MB each).
    # Flow: entry → try_bump → bump_ok (fast path)
    #                        → need_arena → check_size → alloc_arena → try_bump (retry)
    #                                                   → fallback (oversized)
    alloc_fnty = ir.FunctionType(i8_ptr, [i64]);
    alloc_fn = ir.Function(self.llvm_module, alloc_fnty, name="__rc_alloc");
    alloc_fn.linkage = "private";
    alloc_fn.args[0].name = "size";
    entry_bb = alloc_fn.append_basic_block("entry");
    try_bb = alloc_fn.append_basic_block("try_bump");
    bump_ok_bb = alloc_fn.append_basic_block("bump_ok");
    need_bb = alloc_fn.append_basic_block("need_arena");
    alloc_bb = alloc_fn.append_basic_block("alloc_arena");
    fallback_bb = alloc_fn.append_basic_block("fallback");
    # Entry: compute aligned total
    b = ir.IRBuilder(entry_bb);
    total = b.add(alloc_fn.args[0], ir.Constant(i64, 8), name="total");
    total = b.add(total, ir.Constant(i64, 15), name="total.pad");
    total = b.and_(total, ir.Constant(i64, -16), name="total.align");
    b.branch(try_bb);
    # Try bump: check arena exists and has space
    b = ir.IRBuilder(try_bb);
    cur_base = b.load(arena_base_gv, name="cur.base");
    cur_off = b.load(arena_offset_gv, name="cur.off");
    new_off = b.add(cur_off, total, name="new.off");
    is_null = b.icmp_unsigned(
        "==", cur_base, ir.Constant(i8_ptr, None), name="no.arena"
    );
    no_space = b.icmp_unsigned(">=", new_off, arena_size_const, name="no.space");
    need_arena = b.or_(is_null, no_space, name="need.arena");
    b.cbranch(need_arena, need_bb, bump_ok_bb);
    # Need arena: check if request fits in an arena at all
    b = ir.IRBuilder(need_bb);
    too_big = b.icmp_unsigned(">", total, arena_size_const, name="too.big");
    b.cbranch(too_big, fallback_bb, alloc_bb);
    # Alloc arena: malloc fresh 128MB chunk, reset offset, retry
    b = ir.IRBuilder(alloc_bb);
    new_arena = b.call(self.malloc_fn, [arena_size_const], name="new.arena");
    b.store(new_arena, arena_base_gv);
    b.store(ir.Constant(i64, 0), arena_offset_gv);
    b.branch(try_bb);
    # Bump OK: fast path — advance offset, store refcount, return
    b = ir.IRBuilder(bump_ok_bb);
    b.store(new_off, arena_offset_gv);
    raw = b.gep(cur_base, [cur_off], name="bump.raw");
    rc_ptr = b.bitcast(raw, i64_ptr, name="rc.ptr");
    b.store(ir.Constant(i64, 1), rc_ptr);
    user = b.gep(raw, [ir.Constant(i64, 8)], name="user");
    b.ret(user);
    # Fallback: regular malloc for oversized allocations
    b = ir.IRBuilder(fallback_bb);
    fb_raw = b.call(self.malloc_fn, [total], name="fb.raw");
    fb_rc_ptr = b.bitcast(fb_raw, i64_ptr, name="fb.rc.ptr");
    b.store(ir.Constant(i64, 1), fb_rc_ptr);
    fb_user = b.gep(fb_raw, [ir.Constant(i64, 8)], name="fb.user");
    b.ret(fb_user);
    self.rc_alloc_fn = alloc_fn;

    # --- __rc_retain(i8* ptr) -> void ---
    # Null check, sentinel check, then increment refcount at ptr-8
    retain_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);
    retain_fn = ir.Function(self.llvm_module, retain_fnty, name="__rc_retain");
    retain_fn.linkage = "private";
    retain_fn.args[0].name = "ptr";
    entry_bb = retain_fn.append_basic_block("entry");
    check_bb = retain_fn.append_basic_block("check_sentinel");
    do_bb = retain_fn.append_basic_block("do_retain");
    done_bb = retain_fn.append_basic_block("done");
    b = ir.IRBuilder(entry_bb);
    is_null = b.icmp_unsigned(
        "==", retain_fn.args[0], ir.Constant(i8_ptr, None), name="is.null"
    );
    b.cbranch(is_null, done_bb, check_bb);
    # Check sentinel: if refcount == RC_SENTINEL, skip
    b = ir.IRBuilder(check_bb);
    raw_ptr = b.gep(retain_fn.args[0], [ir.Constant(i64, -8)], name="raw");
    rc_ptr = b.bitcast(raw_ptr, i64_ptr, name="rc.ptr");
    old_rc = b.load(rc_ptr, name="old.rc");
    is_static = b.icmp_unsigned(
        "==", old_rc, ir.Constant(i64, RC_SENTINEL), name="is.static"
    );
    b.cbranch(is_static, done_bb, do_bb);
    b = ir.IRBuilder(do_bb);
    new_rc = b.add(old_rc, ir.Constant(i64, 1), name="new.rc");
    b.store(new_rc, rc_ptr);
    b.branch(done_bb);
    b = ir.IRBuilder(done_bb);
    b.ret_void();
    self.rc_retain_fn = retain_fn;

    # --- __rc_release_simple(i8* ptr) -> void ---
    # Null check, sentinel check, decrement refcount. No free (bump allocator).
    # When proper retain/release balancing is implemented, this will need
    # arena-aware freeing. For now, all RC memory is bump-allocated and leaked.
    release_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);
    release_fn = ir.Function(self.llvm_module, release_fnty, name="__rc_release_simple");
    release_fn.linkage = "private";
    release_fn.args[0].name = "ptr";
    entry_bb = release_fn.append_basic_block("entry");
    check_bb = release_fn.append_basic_block("check_sentinel");
    do_bb = release_fn.append_basic_block("do_release");
    done_bb = release_fn.append_basic_block("done");
    b = ir.IRBuilder(entry_bb);
    is_null = b.icmp_unsigned(
        "==", release_fn.args[0], ir.Constant(i8_ptr, None), name="is.null"
    );
    b.cbranch(is_null, done_bb, check_bb);
    # Check sentinel: if refcount == RC_SENTINEL, skip (static/immortal)
    b = ir.IRBuilder(check_bb);
    raw_ptr = b.gep(release_fn.args[0], [ir.Constant(i64, -8)], name="raw");
    rc_ptr = b.bitcast(raw_ptr, i64_ptr, name="rc.ptr");
    old_rc = b.load(rc_ptr, name="old.rc");
    is_static = b.icmp_unsigned(
        "==", old_rc, ir.Constant(i64, RC_SENTINEL), name="is.static"
    );
    b.cbranch(is_static, done_bb, do_bb);
    b = ir.IRBuilder(do_bb);
    new_rc = b.sub(old_rc, ir.Constant(i64, 1), name="new.rc");
    b.store(new_rc, rc_ptr);
    b.branch(done_bb);
    b = ir.IRBuilder(done_bb);
    b.ret_void();
    self.rc_release_simple_fn = release_fn;
}

"""Allocate RC-managed memory. Returns i8* with refcount=1."""
impl NaIRGenPass._rc_alloc(size: ir.Value, name: str = "rc.alloc") -> ir.Value {
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    size = self._coerce_type(size, ir.IntType(64));
    return self.builder.call(self.rc_alloc_fn, [size], name=name);
}

"""Allocate RC-managed memory and bitcast to target pointer type."""
impl NaIRGenPass._rc_alloc_typed(
    size: ir.Value, target_type: ir.Type, name: str = "rc.ptr"
) -> ir.Value {
    raw = self._rc_alloc(size, name="rc.raw");
    return self.builder.bitcast(raw, target_type, name=name);
}

"""Emit rc_retain call for a pointer value."""
impl NaIRGenPass._emit_rc_retain(ptr: ir.Value) -> None {
    if self.rc_retain_fn is None {
        self._emit_rc_helpers();
    }
    if not isinstance(ptr.type, ir.PointerType) {
        return;
    }
    i8_ptr = ir.IntType(8).as_pointer();
    cast = self.builder.bitcast(ptr, i8_ptr, name="rc.retain.cast");
    self.builder.call(self.rc_retain_fn, [cast]);
}

"""Emit rc_release_simple call for a pointer value (no child cleanup)."""
impl NaIRGenPass._emit_rc_release_simple(ptr: ir.Value) -> None {
    if self.rc_release_simple_fn is None {
        self._emit_rc_helpers();
    }
    if not isinstance(ptr.type, ir.PointerType) {
        return;
    }
    i8_ptr = ir.IntType(8).as_pointer();
    cast = self.builder.bitcast(ptr, i8_ptr, name="rc.release.cast");
    self.builder.call(self.rc_release_simple_fn, [cast]);
}

"""Emit type-specific rc_release for a value based on its LLVM type.

Dispatches to per-type destructors for containers and structs,
falls back to rc_release_simple for strings and unknown pointer types.

NOTE: Currently disabled (early return). Without full retain-on-store
semantics, releasing locals/containers at scope exit causes use-after-free
when pointers are shared (e.g. Move.from_pos = Piece.pos). All allocations
leak until proper retain/release balancing is implemented.
"""
impl NaIRGenPass._emit_rc_release_typed(val: ir.Value) -> None {
    return;
    if not isinstance(val.type, ir.PointerType) {
        return;
    }
    # Check if it's a known list type
    for (elem_name, list_type) in self.list_types.items() {
        if val.type == list_type.as_pointer() {
            release_fn = self.list_release_fns.get(elem_name);
            if release_fn is not None {
                self.builder.call(release_fn, [val]);
                return;
            }
        }
    }
    # Check if it's a known dict type
    for (dict_key, dict_type) in self.dict_types.items() {
        if val.type == dict_type.as_pointer() {
            release_fn = self.dict_release_fns.get(dict_key);
            if release_fn is not None {
                self.builder.call(release_fn, [val]);
                return;
            }
        }
    }
    # Check if it's a known set type
    for (elem_name, set_type) in self.set_types.items() {
        if val.type == set_type.as_pointer() {
            release_fn = self.set_release_fns.get(elem_name);
            if release_fn is not None {
                self.builder.call(release_fn, [val]);
                return;
            }
        }
    }
    # Check if it's a known struct type
    type_name = self._infer_type_name(val);
    if type_name is not None {
        release_fn = self.struct_release_fns.get(type_name);
        if release_fn is not None {
            self.builder.call(release_fn, [val]);
            return;
        }
    }
    # Default: simple release (strings, unknown pointer types)
    self._emit_rc_release_simple(val);
}

"""Release all pointer-typed local variables (scope cleanup).

Called before function return or scope exit. Skips `skip_var` to
support ownership transfer on return.
"""
impl NaIRGenPass._emit_scope_cleanup(skip_var: (str | None) = None) -> None {
    if self.builder is None {
        return;
    }
    for (var_name, alloca) in self.local_vars.items() {
        if var_name == skip_var or var_name == "self" {
            continue;
        }
        # alloca.type is a pointer to the stored type (e.g. i8** for a string local)
        if isinstance(alloca.type, ir.PointerType)
        and isinstance(alloca.type.pointee, ir.PointerType) {
            val = self.builder.load(alloca, name=f"cleanup.{var_name}");
            self._emit_rc_release_typed(val);
        }
    }
}

"""Copy a C string into an RC-managed allocation (like strdup but with RC header).

Returns an RC-managed i8* with refcount=1 containing a copy of the input string.
"""
impl NaIRGenPass._rc_strdup(ptr: ir.Value, name: str = "rc.str") -> ir.Value {
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    # Get string length
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8_ptr]);
    slen = self.builder.call(strlen_fn, [ptr], name="str.len");
    # Allocate len+1 bytes via rc_alloc
    alloc_size = self.builder.add(slen, ir.Constant(i64, 1), name="str.alloc.size");
    new_str = self._rc_alloc(alloc_size, name="rc.str.raw");
    # Copy the string data (including null terminator)
    memcpy_fn = self._get_or_declare_extern("memcpy", i8_ptr, [i8_ptr, i8_ptr, i64]);
    self.builder.call(memcpy_fn, [new_str, ptr, alloc_size]);
    return new_str;
}

"""Emit a per-archetype RC destructor: __rc_release_ArchName.

Decrements refcount, and if zero, releases all pointer-typed fields
then frees the struct. Called from _emit_rc_release_typed dispatch.
"""
impl NaIRGenPass._emit_struct_release_fn(arch_name: str) -> None {
    if arch_name in self.struct_release_fns {
        return;
    }
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None {
        return;
    }
    field_types = self.struct_field_types.get(arch_name, {});
    field_indices = self.struct_field_indices.get(arch_name, {});
    struct_ptr_type = struct_type.as_pointer();
    i8_ptr = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    # Create the destructor function
    release_fnty = ir.FunctionType(ir.VoidType(), [struct_ptr_type]);
    release_fn = ir.Function(
        self.llvm_module, release_fnty, name=f"__rc_release_{arch_name}"
    );
    release_fn.linkage = "private";
    release_fn.args[0].name = "obj";
    (b, done_bb) = self._emit_rc_destructor_preamble(release_fn, struct_ptr_type);
    for (fname, ftype) in field_types.items() {
        if isinstance(ftype, ir.PointerType) {
            idx = field_indices.get(fname, -1);
            if idx >= 0 {
                field_ptr = b.gep(
                    release_fn.args[0],
                    [ir.Constant(i32, 0), ir.Constant(i32, idx)],
                    name=f"field.{fname}.ptr"
                );
                field_val = b.load(field_ptr, name=f"field.{fname}.val");
                b.call(
                    self.rc_release_simple_fn,
                    [b.bitcast(field_val, i8_ptr, name=f"field.{fname}.cast")]
                );
            }
        }
    }
    # Skip free: bump allocator arena memory cannot be freed individually.
    # Memory is reclaimed when the process exits.
    b.branch(done_bb);
    b = ir.IRBuilder(done_bb);
    b.ret_void();
    self.struct_release_fns[arch_name] = release_fn;
}
