"""Length-aware `bytes` type for the native backend (#6404 Track 0).

A `bytes` value is a pointer to a single rc_alloc'd block laid out as

    { i64 len, [len x i8] data }

so embedded NUL bytes survive and `len()` is exact — unlike the
null-terminated `str` (i8*) it used to alias. The distinct LLVM struct type
also keeps every type-driven dispatch (len / index / slice / == / encode /
decode / from_bytes) from confusing bytes with str. The block carries no
nested pointers, so the default free dtor (dtor=0) reclaims it.
"""

"""Get or create the identified `jacbytes` struct type { i64 len, [0 x i8] }.

The trailing zero-length array is a flexible member: the actual data lives in
the bytes allocated past the i64 header, indexed via _bytes_data_ptr.
"""
impl NaIRGenPass._get_bytes_struct_type -> ir.Type {
    if self._bytes_struct_type is not None {
        return self._bytes_struct_type;
    }
    i64 = ir.IntType(64);
    i8 = ir.IntType(8);
    bt = self.llvm_module.context.get_identified_type("jacbytes");
    bt.set_body(i64, ir.ArrayType(i8, 0));
    self._bytes_struct_type = bt;
    return bt;
}

"""True iff `v` is a pointer to the jacbytes struct."""
impl NaIRGenPass._is_bytes_value(v: ir.Value) -> bool {
    if self._bytes_struct_type is None {
        return False;
    }
    return (
        isinstance(v.type, ir.PointerType) and v.type.pointee == self._bytes_struct_type
    );
}

"""Load the i64 length of a bytes value."""
impl NaIRGenPass._bytes_len_val(bv: ir.Value) -> ir.Value {
    i32 = ir.IntType(32);
    len_ptr = self.builder.gep(
        bv, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="by.len.ptr"
    );
    return self.builder.load(len_ptr, name="by.len");
}

"""i8* to the first data byte of a bytes value."""
impl NaIRGenPass._bytes_data_ptr(bv: ir.Value) -> ir.Value {
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    arr_ptr = self.builder.gep(
        bv, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="by.data"
    );
    return self.builder.bitcast(arr_ptr, i8.as_pointer(), name="by.data.i8");
}

"""Allocate an uninitialized bytes value of `n` data bytes (len field set).

The caller owns the result (rc=1). Header + data are one rc-managed block.
"""
impl NaIRGenPass._bytes_alloc(n: ir.Value) -> ir.Value {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    bt = self._get_bytes_struct_type();
    n = self._coerce_type(n, i64);
    total = self.builder.add(n, ir.Constant(i64, 8), name="by.total");
    raw = self._rc_call_with_ctx(
        self.rc_alloc_fn, [total], op="bytes", loc="", name="by.raw"
    );
    self._emit_set_type_tag(self.builder, raw, "bytes");
    bv = self.builder.bitcast(raw, bt.as_pointer(), name="by.obj");
    len_ptr = self.builder.gep(
        bv, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="by.len.set"
    );
    self.builder.store(n, len_ptr);
    self._mark_owned(bv);
    return bv;
}

"""Build a fresh bytes value copying `n` bytes from i8* `src`."""
impl NaIRGenPass._bytes_from_raw(src: ir.Value, n: ir.Value) -> ir.Value {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    bv = self._bytes_alloc(n);
    dst = self._bytes_data_ptr(bv);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    self.builder.call(memcpy_fn, [dst, src, n]);
    return bv;
}

"""Emit a bytes literal as a static global with a sentinel RC header.

Layout { i64 RC_SENTINEL, i64 dtor=0, i64 len, [N x i8] data } mirrors
_make_global_string: ptr-16 holds the sentinel so retain/release skip it, and
the returned pointer (to the len field) reinterprets as a jacbytes*.
"""
impl NaIRGenPass._make_global_bytes(data: bytes) -> ir.Value {
    i64 = ir.IntType(64);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    n = len(data);
    arr_type = ir.ArrayType(i8, n);
    struct_type = ir.LiteralStructType([i64, i64, i64, arr_type]);
    c_arr = ir.Constant(arr_type, bytearray(data));
    struct_val = ir.Constant(
        struct_type,
        [
            ir.Constant(i64, 0x7FFFFFFFFFFFFFFF),
            ir.Constant(i64, 0),
            ir.Constant(i64, n),
            c_arr
        ]
    );
    gv = ir.GlobalVariable(
        self.llvm_module, struct_type, name=f".bytes.{self._str_count}"
    );
    self._str_count = self._str_count + 1;
    gv.linkage = "private";
    gv.global_constant = True;
    gv.initializer = struct_val;
    bt = self._get_bytes_struct_type();
    payload = self.builder.gep(
        gv, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="by.lit"
    );
    return self.builder.bitcast(payload, bt.as_pointer(), name="by.lit.obj");
}

"""bytes[i] -> int (the unsigned byte value). Negative indices wrap; an
out-of-range index raises IndexError (CPython parity)."""
impl NaIRGenPass._codegen_bytes_index(
    bv: ir.Value, idx: ir.Value
) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    idx = self._coerce_type(idx, i64);
    length = self._bytes_len_val(bv);
    is_neg = self.builder.icmp_signed("<", idx, ir.Constant(i64, 0), name="by.idx.neg");
    adj = self.builder.add(idx, length, name="by.idx.adj");
    real_idx = self.builder.select(is_neg, adj, idx, name="by.idx");
    # Bounds: real_idx < 0 or real_idx >= len -> IndexError.
    lo_bad = self.builder.icmp_signed(
        "<", real_idx, ir.Constant(i64, 0), name="by.idx.lo"
    );
    hi_bad = self.builder.icmp_signed(">=", real_idx, length, name="by.idx.hi");
    oob = self.builder.or_(lo_bad, hi_bad, name="by.idx.oob");
    self._emit_runtime_raise(oob, "IndexError", "index out of range");
    data = self._bytes_data_ptr(bv);
    bptr = self.builder.gep(data, [real_idx], name="by.bptr");
    byte = self.builder.load(bptr, name="by.byte");
    return self.builder.zext(byte, i64, name="by.byte.i64");
}

"""bytes[start:stop:step] -> new bytes. step=1 only (the parser surface);
start/stop default and clamp to [0, len] with Python negative-index semantics."""
impl NaIRGenPass._codegen_bytes_slice(
    bv: ir.Value, slice_node: object
) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    src_len = self._bytes_len_val(bv);
    # start: default 0; negative wraps by len; clamp to [0, len].
    start_val: ir.Value = zero;
    if slice_node?.start is not None {
        _sv = self._codegen_expr(slice_node.start);
        if _sv is not None {
            v = self._coerce_type(_sv, i64);
            neg = self.builder.icmp_signed("<", v, zero, name="by.sl0.neg");
            v = self.builder.select(
                neg,
                self.builder.add(v, src_len, name="by.sl0.wrap"),
                v,
                name="by.sl0.w"
            );
            lo = self.builder.icmp_signed("<", v, zero, name="by.sl0.lo");
            v = self.builder.select(lo, zero, v, name="by.sl0.cl0");
            hi = self.builder.icmp_signed(">", v, src_len, name="by.sl0.hi");
            start_val = self.builder.select(hi, src_len, v, name="by.sl0.cln");
        }
    }
    # stop: default len; negative wraps by len; clamp to [0, len].
    stop_val: ir.Value = src_len;
    if slice_node?.stop is not None {
        _ev = self._codegen_expr(slice_node.stop);
        if _ev is not None {
            v = self._coerce_type(_ev, i64);
            neg = self.builder.icmp_signed("<", v, zero, name="by.sl1.neg");
            v = self.builder.select(
                neg,
                self.builder.add(v, src_len, name="by.sl1.wrap"),
                v,
                name="by.sl1.w"
            );
            lo = self.builder.icmp_signed("<", v, zero, name="by.sl1.lo");
            v = self.builder.select(lo, zero, v, name="by.sl1.cl0");
            hi = self.builder.icmp_signed(">", v, src_len, name="by.sl1.hi");
            stop_val = self.builder.select(hi, src_len, v, name="by.sl1.cln");
        }
    }
    raw_len = self.builder.sub(stop_val, start_val, name="by.sl.rawlen");
    neg_len = self.builder.icmp_signed("<", raw_len, zero, name="by.sl.neglen");
    slice_len = self.builder.select(neg_len, zero, raw_len, name="by.sl.len");
    new_b = self._bytes_alloc(slice_len);
    dst = self._bytes_data_ptr(new_b);
    src = self.builder.gep(self._bytes_data_ptr(bv), [start_val], name="by.sl.src");
    memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    self.builder.call(memcpy_fn, [dst, src, slice_len]);
    return new_b;
}

"""bytes == bytes / bytes != bytes -> i1. Equal lengths AND memcmp == 0."""
impl NaIRGenPass._emit_bytes_eq(
    left: ir.Value, right: ir.Value, negate: bool
) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    func = self.builder.basic_block.function;
    llen = self._bytes_len_val(left);
    rlen = self._bytes_len_val(right);
    len_eq = self.builder.icmp_signed("==", llen, rlen, name="by.eq.len");
    cmp_bb = func.append_basic_block(name="by.eq.cmp");
    done_bb = func.append_basic_block(name="by.eq.done");
    entry_bb = self.builder.basic_block;
    self.builder.cbranch(len_eq, cmp_bb, done_bb);
    # Lengths match: memcmp the data.
    self.builder.position_at_end(cmp_bb);
    memcmp_fn = self._get_or_declare_extern("memcmp", i32, [i8p, i8p, i64]);
    cmp = self.builder.call(
        memcmp_fn,
        [self._bytes_data_ptr(left), self._bytes_data_ptr(right), llen],
        name="by.eq.memcmp"
    );
    data_eq = self.builder.icmp_signed(
        "==", cmp, ir.Constant(i32, 0), name="by.eq.data"
    );
    self.builder.branch(done_bb);
    self.builder.position_at_end(done_bb);
    res = self.builder.phi(ir.IntType(1), name="by.eq");
    res.add_incoming(ir.Constant(ir.IntType(1), 0), entry_bb);
    res.add_incoming(data_eq, cmp_bb);
    if negate {
        return self.builder.not_(res, name="by.ne");
    }
    return res;
}
