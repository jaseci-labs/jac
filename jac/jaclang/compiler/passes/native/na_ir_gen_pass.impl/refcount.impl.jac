"""Reference counting infrastructure for native memory management.

Emits LLVM IR helper functions for RC allocation, retain, and release.
Replaces Boehm GC (GC_malloc) with a self-contained refcount scheme.

Memory layout (32-byte header):
  [ i64 alloc_id | i8* type_tag | i64 refcount | i64 dtor_fn_ptr | user data ... ]
  ^                                                                 ^
  malloc'd ptr (raw, ptr-32)                   user-visible ptr (ptr+0)

  ptr-32  alloc_id    — monotonic counter, unique per allocation
  ptr-24  type_tag    — i8* pointer to static type-name string (e.g. "Move")
  ptr-16  RC counter  — starts at 1 (UNCHANGED OFFSET)
  ptr-8   dtor_fn_ptr — 0 = plain free (UNCHANGED OFFSET)
  ptr+0   user data

The dtor_fn_ptr field (at user_ptr-8) holds a function pointer cast to i64.
For plain allocations (strings, boxed tuples) it is 0 — freed directly by
__rc_release_simple. For containers and structs it is set to the typed
destructor function. When __rc_release_simple decrements the refcount to zero
it calls dtor_fn(ptr) if non-zero; the typed destructor is responsible for
releasing children AND freeing the struct itself.

Static strings use a sentinel refcount (INT64_MAX) embedded in a global
constant struct { i64 sentinel, i64 dtor(=0), [N x i8] data }. The retain/release
helpers skip operations when the sentinel is detected, so static strings are
never freed or modified.

See jac-bun/docs/GC_Enh.md for the full enhancement plan.
"""

# RC_SENTINEL, HDR_*, LIVE_NODE_*, and HDR_MAGIC* layout constants live in
# na_ir_gen_pass.jac so they're shared with gc_debug.impl.jac.
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

    # Emit debug-only globals: __rc_debug, __rc_debug_enable/disable,
    # __rc_ctx_op, __rc_ctx_loc, __rc_live_head.
    self._emit_rc_debug_globals();

    # --- GC on/off switch ---
    # __rc_gc_disabled (i8, internal): 0 = RC active (default), 1 = no-op all
    # retain/release calls.  When disabled, every allocation still gets a header
    # (rc=1, dtor=0) but retain/release are no-ops → memory is never freed.
    # Use this mode to compare "with RC overhead" vs "without" in benchmarks.
    # Toggle via __rc_gc_disable() / __rc_gc_enable(), or set JAC_NO_GC=1 env var.
    rc_gc_disabled_gv = ir.GlobalVariable(
        self.llvm_module, i8, name="__rc_gc_disabled"
    );
    rc_gc_disabled_gv.linkage = "internal";
    rc_gc_disabled_gv.initializer = ir.Constant(i8, 0);
    self.rc_gc_disabled_gv = rc_gc_disabled_gv;
    # __rc_gc_disable() -> void
    dis_gc_fnty = ir.FunctionType(ir.VoidType(), []);
    dis_gc_fn = ir.Function(self.llvm_module, dis_gc_fnty, name="__rc_gc_disable");
    dis_gc_fn.linkage = "internal";
    _bb_dis_gc = dis_gc_fn.append_basic_block("entry");
    _b_dis_gc = ir.IRBuilder(_bb_dis_gc);
    _b_dis_gc.store(ir.Constant(i8, 1), rc_gc_disabled_gv);
    _b_dis_gc.ret_void();
    self.rc_gc_disable_fn = dis_gc_fn;
    # __rc_gc_enable() -> void
    en_gc_fn = ir.Function(self.llvm_module, dis_gc_fnty, name="__rc_gc_enable");
    en_gc_fn.linkage = "internal";
    _bb_en_gc = en_gc_fn.append_basic_block("entry");
    _b_en_gc = ir.IRBuilder(_bb_en_gc);
    _b_en_gc.store(ir.Constant(i8, 0), rc_gc_disabled_gv);
    _b_en_gc.ret_void();
    self.rc_gc_enable_fn = en_gc_fn;

    # Pre-declare all libc functions that the compiler uses internally.
    # This must happen BEFORE _process_clib_imports so that user imports
    # of the same names (e.g. `import from "libc" { def memcpy(...); }`)
    # find the correctly-typed declarations in extern_funcs and reuse them
    # instead of creating conflicting declarations with user types.
    self._get_or_declare_extern("memcpy", i8_ptr, [i8_ptr, i8_ptr, i64]);
    self._get_or_declare_extern("strlen", i64, [i8_ptr]);
    self._get_or_declare_extern("strcmp", i32, [i8_ptr, i8_ptr]);
    self._get_or_declare_extern("strncmp", i32, [i8_ptr, i8_ptr, i64]);
    self._get_or_declare_extern("memcmp", i32, [i8_ptr, i8_ptr, i64]);
    self._get_or_declare_extern("calloc", i8_ptr, [i64, i64]);
    self._get_or_declare_extern("fopen", i8_ptr, [i8_ptr, i8_ptr]);
    self._get_or_declare_extern("fclose", i32, [i8_ptr]);
    self._get_or_declare_extern("fread", i64, [i8_ptr, i64, i64, i8_ptr]);
    self._get_or_declare_extern("fwrite", i64, [i8_ptr, i64, i64, i8_ptr]);
    self._get_or_declare_extern("fgets", i8_ptr, [i8_ptr, i32, i8_ptr]);
    self._get_or_declare_extern("fflush", i32, [i8_ptr]);
    self._get_or_declare_extern("ftell", i64, [i8_ptr]);
    self._get_or_declare_extern("fseek", i32, [i8_ptr, i64, i32]);

    # --- Monotonic allocation ID counter ---
    # Incremented atomically for every __rc_alloc call.  Stored at ptr-32.
    alloc_id_gv = ir.GlobalVariable(
        self.llvm_module, i64, name="__rc_alloc_id_counter"
    );
    alloc_id_gv.linkage = "internal";
    alloc_id_gv.initializer = ir.Constant(i64, 0);
    self.rc_alloc_id_gv = alloc_id_gv;

    # --- Static tag strings used by __rc_alloc and __rc_set_type ---
    _raw_tag_str = self._get_snprintf_fmt("raw");
    _raw_tag_gep = ir.GlobalVariable.__new__(ir.GlobalVariable);
    self._rc_raw_tag_gv = _raw_tag_str;  # reuse fmt-string global as tag

    # --- __rc_alloc(i64 size) -> i8* ---
    # 32-byte header: [alloc_id | type_tag_ptr | refcount | dtor_fn_ptr]
    # Allocates (size + 32 + 15) & ~15 bytes (16-byte aligned).
    # ptr-32 = alloc_id (i64)
    # ptr-24 = type_tag (i8*, default = "raw")
    # ptr-16 = RC = 1  (OFFSET UNCHANGED)
    # ptr-8  = dtor = 0 (OFFSET UNCHANGED)
    # ptr+0  = user data
    alloc_fnty = ir.FunctionType(i8_ptr, [i64]);
    alloc_fn = ir.Function(self.llvm_module, alloc_fnty, name="__rc_alloc");
    alloc_fn.linkage = "private";
    alloc_fn.args[0].name = "size";
    entry_bb = alloc_fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb);
    total = b.add(alloc_fn.args[0], ir.Constant(i64, HDR_TOTAL), name="total");
    total = b.add(total, ir.Constant(i64, 15), name="total.pad");
    total = b.and_(total, ir.Constant(i64, -16), name="total.align");
    raw = b.call(self.malloc_fn, [total], name="raw");
    # Write alloc_id at raw+0 (ptr-HDR_TOTAL): atomic fetch-and-increment.
    # Upper 32 bits encode HDR_MAGIC so retain/release can detect external
    # (ctypes-passed) pointers and skip them safely.
    # Stored value = (HDR_MAGIC << 32) | (alloc_id & 0xFFFFFFFF).
    _aid_old = b.atomic_rmw(
        "add", alloc_id_gv, ir.Constant(i64, 1), ordering="monotonic"
    );
    _aid_ptr = b.bitcast(raw, i64_ptr, name="aid.ptr");
    _magic_base = ir.Constant(i64, HDR_MAGIC_SHIFT_BASE);
    _aid_lo32 = b.and_(
        _aid_old, ir.Constant(i64, 4294967295), name="aid.lo"
    );  # & 0xFFFFFFFF
    _aid_magic = b.or_(_magic_base, _aid_lo32, name="aid.magic");
    b.store(_aid_magic, _aid_ptr);
    # Write type_tag ptr "raw" at raw+8 (ptr-24, i.e. HDR_TAG_OFF from user)
    _tag_raw = b.gep(
        _raw_tag_str, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="tag.raw"
    );
    _tag_slot = b.gep(
        raw, [ir.Constant(i64, HDR_TOTAL + HDR_TAG_OFF)], name="tag.slot"
    );
    _tag_slot_ptr = b.bitcast(_tag_slot, i8_ptr.as_pointer(), name="tag.slot.ptr");
    b.store(_tag_raw, _tag_slot_ptr);
    # Write RC=1 at raw+(HDR_TOTAL+HDR_RC_OFF), i.e. user_ptr + HDR_RC_OFF
    rc_raw = b.gep(raw, [ir.Constant(i64, HDR_TOTAL + HDR_RC_OFF)], name="rc.raw");
    rc_ptr = b.bitcast(rc_raw, i64_ptr, name="rc.ptr");
    b.store(ir.Constant(i64, 1), rc_ptr);
    # Write dtor=0 at raw+(HDR_TOTAL+HDR_DTOR_OFF), i.e. user_ptr + HDR_DTOR_OFF
    dtor_raw = b.gep(
        raw, [ir.Constant(i64, HDR_TOTAL + HDR_DTOR_OFF)], name="dtor.raw"
    );
    dtor_ptr_slot = b.bitcast(dtor_raw, i64_ptr, name="dtor.slot");
    b.store(ir.Constant(i64, 0), dtor_ptr_slot);
    # user pointer = raw+HDR_TOTAL
    user = b.gep(raw, [ir.Constant(i64, HDR_TOTAL)], name="user");
    # Add to live-objects list (non-RC malloc node)
    self._emit_live_node_insert(b, _aid_old, user, _tag_raw);
    # Debug: conditionally log the malloc
    ret_bb = alloc_fn.append_basic_block("ret");
    log_alloc_bb = self._emit_alloc_log_bb(
        alloc_fn, ret_bb, _aid_old, user, alloc_fn.args[0], _tag_raw
    );
    dbg_flag_a = b.load(self.rc_debug_gv, name="rc.dbg.a");
    b.cbranch(
        b.icmp_unsigned("!=", dbg_flag_a, ir.Constant(i8, 0), name="dbg.on.a"),
        log_alloc_bb,
        ret_bb
    );
    b = ir.IRBuilder(ret_bb);
    b.ret(user);
    self.rc_alloc_fn = alloc_fn;

    # --- __rc_set_type(i8* ptr, i8* tag) -> void ---
    # Stores tag at ptr-24 (type_tag slot in 32-byte header).
    # Also updates the type_tag field in the live-objects node for this ptr.
    # Called from _codegen_instantiation, _box_value_tuple, etc.
    set_type_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr, i8_ptr]);
    set_type_fn = ir.Function(self.llvm_module, set_type_fnty, name="__rc_set_type");
    set_type_fn.linkage = "internal";
    set_type_fn.args[0].name = "ptr";
    set_type_fn.args[1].name = "tag";
    _st_bb = set_type_fn.append_basic_block("entry");
    _st_b = ir.IRBuilder(_st_bb);
    # null check
    _st_null = _st_b.icmp_unsigned(
        "==", set_type_fn.args[0], ir.Constant(i8_ptr, None), name="st.null"
    );
    _st_done_bb = set_type_fn.append_basic_block("done");
    _st_work_bb = set_type_fn.append_basic_block("work");
    _st_b.cbranch(_st_null, _st_done_bb, _st_work_bb);
    _st_b = ir.IRBuilder(_st_work_bb);
    _st_tag_slot = _st_b.gep(
        set_type_fn.args[0], [ir.Constant(i64, HDR_TAG_OFF)], name="tag.slot"
    );
    _st_tag_slot_pp = _st_b.bitcast(
        _st_tag_slot, i8_ptr.as_pointer(), name="tag.slot.pp"
    );
    _st_b.store(set_type_fn.args[1], _st_tag_slot_pp);
    # Phase R2: live-list walk only emitted when debug codegen is on.
    if not self._rc_debug_codegen {
        _st_b.branch(_st_done_bb);
        _st_b = ir.IRBuilder(_st_done_bb);
        _st_b.ret_void();
        self.rc_set_type_fn = set_type_fn;
        # Skip the rest of the function body (live-list walk).
    }
    if self._rc_debug_codegen {
        # Walk live list to update node's tag field too
        _st_scan_bb = set_type_fn.append_basic_block("scan");
        _st_check_bb = set_type_fn.append_basic_block("check");
        _st_match_bb = set_type_fn.append_basic_block("match");
        _st_next_bb = set_type_fn.append_basic_block("next");
        _st_b.branch(_st_scan_bb);
        _st_b = ir.IRBuilder(_st_scan_bb);
        _st_cur = _st_b.load(self.rc_live_head_gv, name="st.cur");
        _st_b.branch(_st_check_bb);
        _st_b = ir.IRBuilder(_st_check_bb);
        _st_cur_phi = _st_b.phi(i8_ptr, name="cur");
        _st_cur_phi.add_incoming(_st_cur, _st_scan_bb);
        _st_is_end = _st_b.icmp_unsigned(
            "==", _st_cur_phi, ir.Constant(i8_ptr, None), name="end"
        );
        _st_b.cbranch(_st_is_end, _st_done_bb, _st_match_bb);
        _st_b = ir.IRBuilder(_st_match_bb);
        _st_nptr_slot = _st_b.gep(
            _st_cur_phi, [ir.Constant(i64, LIVE_NODE_USER_OFF)], name="nptr.slot"
        );
        _st_nptr_pp = _st_b.bitcast(_st_nptr_slot, i8_ptr.as_pointer(), name="nptr.pp");
        _st_node_ptr = _st_b.load(_st_nptr_pp, name="node.ptr");
        _st_eq = _st_b.icmp_unsigned(
            "==", _st_node_ptr, set_type_fn.args[0], name="eq"
        );
        _st_upd_bb = set_type_fn.append_basic_block("upd");
        _st_b.cbranch(_st_eq, _st_upd_bb, _st_next_bb);
        _st_b = ir.IRBuilder(_st_upd_bb);
        _st_ntag_slot = _st_b.gep(
            _st_cur_phi, [ir.Constant(i64, LIVE_NODE_TAG_OFF)], name="ntag.slot"
        );
        _st_ntag_pp = _st_b.bitcast(_st_ntag_slot, i8_ptr.as_pointer(), name="ntag.pp");
        _st_b.store(set_type_fn.args[1], _st_ntag_pp);
        _st_b.branch(_st_done_bb);
        _st_b = ir.IRBuilder(_st_next_bb);
        _st_nnxt_slot = _st_b.gep(
            _st_cur_phi, [ir.Constant(i64, LIVE_NODE_NEXT_OFF)], name="nnxt.slot"
        );
        _st_nnxt_pp = _st_b.bitcast(_st_nnxt_slot, i8_ptr.as_pointer(), name="nnxt.pp");
        _st_next_node = _st_b.load(_st_nnxt_pp, name="next.node");
        _st_cur_phi.add_incoming(_st_next_node, _st_next_bb);
        _st_b.branch(_st_check_bb);
        _st_b = ir.IRBuilder(_st_done_bb);
        _st_b.ret_void();
        self.rc_set_type_fn = set_type_fn;
    }

    # --- __rc_retain(i8* ptr) -> void ---
    # Null check, sentinel check, then increment refcount at ptr-16
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
    # Null → done; else check GC-disabled flag.
    gc_dis_check_bb = retain_fn.append_basic_block("gc_dis_check");
    b.cbranch(is_null, done_bb, gc_dis_check_bb);
    # GC-disabled → done (no-op); else proceed to sentinel check.
    b = ir.IRBuilder(gc_dis_check_bb);
    gc_dis_flag_r = b.load(self.rc_gc_disabled_gv, name="gc.dis.r");
    b.cbranch(
        b.icmp_unsigned("!=", gc_dis_flag_r, ir.Constant(i8, 0), name="gc.dis.on.r"),
        done_bb,
        check_bb
    );
    # Sentinel check FIRST (reads ptr-16, safe for static 16-byte-header strings):
    # if refcount == RC_SENTINEL → static/immortal string → done immediately.
    # This must come before the magic check so we never read ptr-32 on a static string
    # (which only has a 16-byte header — ptr-32 would be before the struct).
    b = ir.IRBuilder(check_bb);
    raw_ptr = b.gep(retain_fn.args[0], [ir.Constant(i64, HDR_RC_OFF)], name="raw");
    rc_ptr = b.bitcast(raw_ptr, i64_ptr, name="rc.ptr");
    old_rc = b.load(rc_ptr, name="old.rc");
    is_static = b.icmp_unsigned(
        "==", old_rc, ir.Constant(i64, RC_SENTINEL), name="is.static"
    );
    magic_check_bb_r = retain_fn.append_basic_block("magic_check");
    b.cbranch(is_static, done_bb, magic_check_bb_r);
    # Magic check (skips ctypes/external pointers that lack an RC header).
    # Only reached for non-sentinel pointers.
    b = ir.IRBuilder(magic_check_bb_r);
    _mc_ok_r = self._emit_magic_check(b, retain_fn.args[0], name_prefix="mc.r");
    b.cbranch(_mc_ok_r, do_bb, done_bb);
    b = ir.IRBuilder(do_bb);
    # atomic fetch-and-add so concurrent threads cannot race on the refcount.
    # Returns the old value; new_rc = old + 1 (used only for debug logging).
    b.atomic_rmw("add", rc_ptr, ir.Constant(i64, 1), ordering="monotonic");
    new_rc = b.add(old_rc, ir.Constant(i64, 1), name="new.rc");
    log_retain_bb = self._emit_retain_log_bb(
        retain_fn, done_bb, retain_fn.args[0], old_rc, new_rc
    );
    dbg_flag = b.load(self.rc_debug_gv, name="rc.dbg");
    b.cbranch(
        b.icmp_unsigned("!=", dbg_flag, ir.Constant(i8, 0), name="dbg.on"),
        log_retain_bb,
        done_bb
    );
    b = ir.IRBuilder(done_bb);
    b.ret_void();
    self.rc_retain_fn = retain_fn;

    # --- __rc_release_simple(i8* ptr) -> void ---
    # Null check, sentinel check, decrement refcount (at ptr-16).
    # When new_rc == 0:
    #   - check_dtor: if dtor_fn_ptr (ptr-8) non-zero → call typed dtor (logs [Arch]+free)
    #   - bare path: log [raw] then free(ptr-32).
    release_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);
    release_fn = ir.Function(
        self.llvm_module, release_fnty, name="__rc_release_simple"
    );
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
    gc_dis_check_bb_rel = release_fn.append_basic_block("gc_dis_check");
    b.cbranch(is_null, done_bb, gc_dis_check_bb_rel);
    b = ir.IRBuilder(gc_dis_check_bb_rel);
    gc_dis_flag_rel = b.load(self.rc_gc_disabled_gv, name="gc.dis.rel");
    magic_check_bb_rel = release_fn.append_basic_block("magic_check");
    b.cbranch(
        b.icmp_unsigned(
            "!=", gc_dis_flag_rel, ir.Constant(i8, 0), name="gc.dis.on.rel"
        ),
        done_bb,
        check_bb
    );
    # Sentinel check FIRST (reads ptr-16, safe for static 16-byte-header strings):
    # static strings have layout {sentinel, dtor, data} so ptr-16 == RC_SENTINEL.
    # Must come before magic check to avoid reading ptr-32 on static strings.
    b = ir.IRBuilder(check_bb);
    # RC counter is at ptr+HDR_RC_OFF (unchanged offset in both 16- and 32-byte header)
    rc_slot = b.gep(release_fn.args[0], [ir.Constant(i64, HDR_RC_OFF)], name="rc.slot");
    rc_ptr = b.bitcast(rc_slot, i64_ptr, name="rc.ptr");
    old_rc = b.load(rc_ptr, name="old.rc");
    is_static = b.icmp_unsigned(
        "==", old_rc, ir.Constant(i64, RC_SENTINEL), name="is.static"
    );
    dblchk_bb = release_fn.append_basic_block("dbl_free_check");
    check_dtor_bb = release_fn.append_basic_block("check_dtor");
    call_dtor_bb = release_fn.append_basic_block("call_dtor");
    b.cbranch(is_static, done_bb, magic_check_bb_rel);
    # Magic check (skips ctypes/external pointers that lack an RC header).
    # Only reached for non-sentinel pointers.
    b = ir.IRBuilder(magic_check_bb_rel);
    _mc_ok_rel = self._emit_magic_check(b, release_fn.args[0], name_prefix="mc.rel");
    # raw pointer (for free) is at ptr+HDR_ALLOC_ID_OFF — safe only after magic check passes
    raw_ptr = b.gep(
        release_fn.args[0], [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name="raw"
    );
    b.cbranch(_mc_ok_rel, dblchk_bb, done_bb);
    # Double-free guard
    b = ir.IRBuilder(dblchk_bb);
    is_dbl = b.icmp_unsigned("==", old_rc, ir.Constant(i64, 0), name="is.dbl.free");
    log_dbl_free_bb = self._emit_dbl_free_log_bb(
        release_fn, done_bb, release_fn.args[0]
    );
    b.cbranch(is_dbl, log_dbl_free_bb, do_bb);
    b = ir.IRBuilder(do_bb);
    b.atomic_rmw("sub", rc_ptr, ir.Constant(i64, 1), ordering="acq_rel");
    new_rc = b.sub(old_rc, ir.Constant(i64, 1), name="new.rc");
    is_zero = b.icmp_unsigned("==", old_rc, ir.Constant(i64, 1), name="is.zero");
    dbg_rel_bb = self._emit_release_log_bb(
        release_fn, done_bb, release_fn.args[0], old_rc, new_rc
    );
    log_free_bb = self._emit_raw_free_bbs(release_fn, done_bb, release_fn.args[0]);
    b.cbranch(is_zero, check_dtor_bb, dbg_rel_bb);
    b = ir.IRBuilder(check_dtor_bb);
    dtor_raw = b.gep(
        release_fn.args[0], [ir.Constant(i64, HDR_DTOR_OFF)], name="dtor.raw"
    );
    dtor_slot = b.bitcast(dtor_raw, i64_ptr, name="dtor.slot");
    dtor_val = b.load(dtor_slot, name="dtor.val");
    is_dtor_zero = b.icmp_unsigned(
        "==", dtor_val, ir.Constant(i64, 0), name="dtor.zero"
    );
    b.cbranch(is_dtor_zero, log_free_bb, call_dtor_bb);
    # call_dtor: typed dtor handles element release + its own free.
    # After the dtor returns, remove the (now-freed) ptr from the live list so
    # the exit dump does not report a false LEAK with rc=0.
    b = ir.IRBuilder(call_dtor_bb);
    dtor_fnty = ir.FunctionType(ir.VoidType(), [i8_ptr]);
    dtor_fn_i8 = b.inttoptr(dtor_val, i8_ptr, name="dtor.i8");
    dtor_fn_ptr = b.bitcast(dtor_fn_i8, dtor_fnty.as_pointer(), name="dtor.fn");
    b.call(dtor_fn_ptr, [release_fn.args[0]]);
    post_dtor_live_rm_bb = release_fn.append_basic_block("post_dtor_live_rm");
    b.branch(post_dtor_live_rm_bb);
    # Remove the live-list node for this ptr. Pass done_bb as free_bb so we
    # do NOT call free() a second time (the dtor already freed the allocation).
    b = ir.IRBuilder(post_dtor_live_rm_bb);
    self._emit_live_list_remove(
        b, release_fn.args[0], i8_ptr, i64_ptr, done_bb, done_bb
    );
    b = ir.IRBuilder(done_bb);
    b.ret_void();
    self.rc_release_simple_fn = release_fn;
}

"""Call an RC-aware function (rc_alloc, container append/set/etc.) with
op/loc context attribution stored to __rc_ctx_op/__rc_ctx_loc for the
duration of the call. Cleared afterward so subsequent RC ops don't
inherit stale attribution. Uses self.builder.
"""
impl NaIRGenPass._rc_call_with_ctx(
    fn: ir.Function, args: list, op: str, loc: str = "", name: str = ""
) -> ir.Value {
    self._set_rc_ctx(op, loc);
    result = self.builder.call(fn, args, name=name);
    self._clear_rc_ctx();
    return result;
}

"""Mark an ir.Value as owned (rc=1, caller must release on drop).

Stores `is_owned = True` on the ir.Value instance so subsequent transforms
(bitcast, coerce_type) can propagate the marker to the new ir.Value they
produce. Returns the input value for fluent chaining.
"""
impl NaIRGenPass._mark_owned(val: ir.Value) -> ir.Value {
    val.is_owned = True;
    return val;
}

"""Test whether `val` was previously marked owned via _mark_owned()."""
impl NaIRGenPass._is_owned(val: ir.Value) -> bool {
    return bool(getattr(val, 'is_owned', False));
}

"""Emit IR that loads the upper 32 bits of the alloc_id field at
ptr+HDR_ALLOC_ID_OFF and compares them against HDR_MAGIC. Returns the i1
boolean comparison result. Used by retain/release to skip externally-owned
pointers (e.g. ctypes-passed buffers) that lack an RC header.
"""
impl NaIRGenPass._emit_magic_check(
    b: ir.IRBuilder, ptr: ir.Value, name_prefix: str = "mc"
) -> ir.Value {
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    _slot = b.gep(
        ptr, [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name=f"{name_prefix}.slot"
    );
    _ptr = b.bitcast(_slot, i64_ptr, name=f"{name_prefix}.ptr");
    _val = b.load(_ptr, name=f"{name_prefix}.val");
    _hi = b.lshr(_val, ir.Constant(i64, 32), name=f"{name_prefix}.hi");
    return b.icmp_unsigned(
        "==", _hi, ir.Constant(i64, HDR_MAGIC), name=f"{name_prefix}.ok"
    );
}

"""Stamp a type-tag string onto an RC-managed allocation header.

Writes `type_name` into the type_tag slot at ptr_i8-24 (and updates the
matching live-list node when debug tracking is on) via the runtime
__rc_set_type helper. No-op when the helper has not been emitted (e.g.
debug codegen disabled). `ptr_i8` MUST already be an i8* — callers
bitcast typed pointers before invoking this helper.
"""
impl NaIRGenPass._emit_set_type_tag(
    b: ir.IRBuilder, ptr_i8: ir.Value, type_name: str
) -> None {
    if self.rc_set_type_fn is None {
        return;
    }
    _i32 = ir.IntType(32);
    _tag_gv = self._get_snprintf_fmt(type_name);
    _tag_gep = b.gep(
        _tag_gv, [ir.Constant(_i32, 0), ir.Constant(_i32, 0)], name="tag.gep"
    );
    b.call(self.rc_set_type_fn, [ptr_i8, _tag_gep]);
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

"""Emit rc_retain call for a pointer value.

op: short string identifying the source-level operation (e.g. "assign", "return").
    Stored to __rc_ctx_op before the call so the retain log can show it.
loc: "filename:line" string baked at compile time. Stored to __rc_ctx_loc.
"""
impl NaIRGenPass._emit_rc_retain(ptr: ir.Value, op: str = "", loc: str = "") -> None {
    if self.rc_retain_fn is None {
        self._emit_rc_helpers();
    }
    if not isinstance(ptr.type, ir.PointerType) {
        return;
    }
    # Function pointers are code addresses, not RC heap objects — skip.
    if isinstance(ptr.type.pointee, ir.FunctionType) {
        return;
    }
    i8_ptr = ir.IntType(8).as_pointer();
    self._set_rc_ctx(op, loc);
    cast = self.builder.bitcast(ptr, i8_ptr, name="rc.retain.cast");
    self.builder.call(self.rc_retain_fn, [cast]);
    # Clear ctx so subsequent allocations don't inherit this op/at.
    self._clear_rc_ctx();
}

"""Emit rc_release_simple call for a pointer value (no child cleanup).

op: short string identifying the source-level operation (e.g. "scope_exit", "assign").
    Stored to __rc_ctx_op before the call so the release log can show it.
loc: "filename:line" string baked at compile time. Stored to __rc_ctx_loc.
"""
impl NaIRGenPass._emit_rc_release_simple(
    ptr: ir.Value, op: str = "", loc: str = ""
) -> None {
    if self.rc_release_simple_fn is None {
        self._emit_rc_helpers();
    }
    if not isinstance(ptr.type, ir.PointerType) {
        return;
    }
    # Function pointers are code addresses, not RC heap objects — skip.
    if isinstance(ptr.type.pointee, ir.FunctionType) {
        return;
    }
    i8_ptr = ir.IntType(8).as_pointer();
    self._set_rc_ctx(op, loc);
    cast = self.builder.bitcast(ptr, i8_ptr, name="rc.release.cast");
    self.builder.call(self.rc_release_simple_fn, [cast]);
    # Clear ctx so subsequent allocations don't inherit this op/at.
    self._clear_rc_ctx();
}


impl NaIRGenPass._emit_rc_release_typed(
    val: ir.Value, op: str = "", loc: str = ""
) -> None {
    self._emit_rc_release_simple(val, op=op, loc=loc);
}

"""Release all pointer-typed local variables (scope cleanup).

Called before function return or scope exit. Skips `skip_var` to
support ownership transfer on return. Nulls each alloca after releasing
so double-cleanup calls (e.g. explicit return inside a branch + implicit
end-of-function terminator) are safe — releasing null is a no-op.
"""
impl NaIRGenPass._emit_scope_cleanup(
    skip_var: (str | None) = None, ret_val: object = None, loc: str = ""
) -> None {
    if self.builder is None {
        return;
    }
    for (var_name, alloca) in self.local_vars.items() {
        if var_name == "self" {
            continue;
        }
        # Parameters are borrowed from the caller — the caller owns them,
        # so the callee must not release them on scope exit.
        if var_name in self.param_vars {
            continue;
        }
        # alloca.type is a pointer to the stored type (e.g. i8** for a string local)
        if isinstance(alloca.type, ir.PointerType)
        and isinstance(alloca.type.pointee, ir.PointerType) {
            val = self.builder.load(alloca, name=f"cleanup.{var_name}");
            if var_name == skip_var {
                # Ownership transferred to caller — null the alloca so any
                # subsequent cleanup pass (implicit terminator) skips it.
                self.builder.store(ir.Constant(alloca.type.pointee, None), alloca);
            } else {
                # Release and null so idempotent on re-entry.
                self._emit_rc_release_typed(val, op="scope_exit", loc=loc);
                self.builder.store(ir.Constant(alloca.type.pointee, None), alloca);
            }
        }
    }
}

"""Release pointer-typed locals introduced inside a loop body and null
their alloca slots.  Called before back-edge / continue / break branches
so an early `return` from a later iteration cannot leak the previous
iteration's value held in a still-live alloca.

`saved_locals` is the snapshot of `self.local_vars.keys()` taken before
the loop body was codegen'd — any local present now but not in the
snapshot was declared inside the body.
"""
impl NaIRGenPass._emit_loop_iter_cleanup(saved_locals: object, loc: str = "") -> None {
    if self.builder is None or self.builder.block.is_terminated {
        return;
    }
    for var_name in list(self.local_vars.keys()) {
        if var_name in saved_locals {
            continue;
        }
        if var_name == "self" or var_name in self.param_vars {
            continue;
        }
        alloca = self.local_vars[var_name];
        if (
            isinstance(alloca.type, ir.PointerType)
            and isinstance(alloca.type.pointee, ir.PointerType)
        ) {
            val = self.builder.load(alloca, name=f"iter.cleanup.{var_name}");
            self._emit_rc_release_typed(val, op="iter_end", loc=loc);
            self.builder.store(ir.Constant(alloca.type.pointee, None), alloca);
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
    _strdup_loc = getattr(ptr, 'jac_loc', '');
    self._set_rc_ctx("strdup", _strdup_loc);
    new_str = self._rc_alloc(alloc_size, name="rc.str.raw");
    self._clear_rc_ctx();
    # Copy the string data (including null terminator)
    memcpy_fn = self._get_or_declare_extern("memcpy", i8_ptr, [i8_ptr, i8_ptr, i64]);
    self.builder.call(memcpy_fn, [new_str, ptr, alloc_size]);
    self._emit_set_type_tag(self.builder, new_str, "str");
    # RC: caller owns this freshly-allocated string (rc=1). Skip extra RETAIN on assign.
    self._mark_owned(new_str);
    return new_str;
}

"""Emit a per-archetype RC destructor: __rc_release_ArchName.

Called by __rc_release_simple via the dtor_fn_ptr when refcount hits zero.
At call time the refcount is already zero — this function does NOT decrement.
It releases all pointer-typed fields then frees the struct allocation itself.
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
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    # Create the destructor function
    release_fnty = ir.FunctionType(ir.VoidType(), [struct_ptr_type]);
    release_fn = ir.Function(
        self.llvm_module, release_fnty, name=f"__rc_release_{arch_name}"
    );
    release_fn.linkage = "private";
    release_fn.args[0].name = "obj";
    # Preamble: just a null check (rc is already 0 when called via dtor_ptr)
    (b, done_bb) = self._emit_rc_destructor_preamble(release_fn, struct_ptr_type);
    # Release all pointer-typed fields
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
    # Free the struct allocation: malloc'd block starts at obj+HDR_ALLOC_ID_OFF
    obj_cast = b.bitcast(release_fn.args[0], i8_ptr, name="obj.i8");
    obj_raw = b.gep(obj_cast, [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name="obj.raw");
    # Read alloc_id (HDR_ALLOC_ID_OFF) and type_tag (HDR_TAG_OFF) for log; strip magic
    _sf_aid_ptr = b.bitcast(obj_raw, i64_ptr, name="sf.aid.ptr");
    _sf_aid_raw = b.load(_sf_aid_ptr, name="sf.aid.raw");
    _sf_aid = b.and_(
        _sf_aid_raw, ir.Constant(ir.IntType(64), 4294967295), name="sf.aid"
    );  # strip magic
    _sf_tag_slot = b.gep(obj_cast, [ir.Constant(i64, HDR_TAG_OFF)], name="sf.tag.slot");
    _sf_tag_ptr = b.bitcast(_sf_tag_slot, i8_ptr.as_pointer(), name="sf.tag.ptr");
    _sf_tag = b.load(_sf_tag_ptr, name="sf.tag");
    # Remove from live-objects list, then log and free
    log_free_struct_bb = release_fn.append_basic_block("log_free_struct");
    actual_free_struct_bb = release_fn.append_basic_block("actual_free_struct");
    self._emit_live_list_remove(
        b, obj_cast, i8_ptr, i64_ptr, log_free_struct_bb, log_free_struct_bb
    );
    self._emit_struct_free_log(
        release_fn,
        log_free_struct_bb,
        actual_free_struct_bb,
        obj_cast,
        obj_raw,
        _sf_aid,
        _sf_tag
    );
    b = ir.IRBuilder(actual_free_struct_bb);
    b.call(self.free_fn, [obj_raw]);
    b.branch(done_bb);
    b = ir.IRBuilder(done_bb);
    b.ret_void();
    self.struct_release_fns[arch_name] = release_fn;
}
