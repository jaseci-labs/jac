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

"""bytes == bytes / bytes != bytes -> i1: equal lengths AND memcmp == 0.

Null-safe (#6751): a `bytes | None` operand may be a null `%"jacbytes"*` at
runtime. CPython `None == b"x"` is `False` and `None == None` is `True`, so a
null operand follows identity semantics (equal iff BOTH null) and the data is
dereferenced only on the both-non-null path -- never loading through null."""
impl NaIRGenPass._emit_bytes_eq(
    left: ir.Value, right: ir.Value, negate: bool
) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    func = self.builder.basic_block.function;
    lnull = self.builder.icmp_unsigned(
        "==", left, ir.Constant(left.type, None), name="by.eq.lnull"
    );
    rnull = self.builder.icmp_unsigned(
        "==", right, ir.Constant(right.type, None), name="by.eq.rnull"
    );
    either_null = self.builder.or_(lnull, rnull, name="by.eq.enull");
    both_null = self.builder.and_(lnull, rnull, name="by.eq.bnull");
    entry_bb = self.builder.basic_block;
    live_bb = func.append_basic_block(name="by.eq.live");
    done_bb = func.append_basic_block(name="by.eq.done");
    # Either null -> done with `both_null`; else deref-safe value compare.
    self.builder.cbranch(either_null, done_bb, live_bb);
    self.builder.position_at_end(live_bb);
    llen = self._bytes_len_val(left);
    rlen = self._bytes_len_val(right);
    len_eq = self.builder.icmp_signed("==", llen, rlen, name="by.eq.len");
    # memcmp over min(len) is safe even when lengths differ; full equality also
    # requires equal length, so AND the two (no inner branch needed).
    minlen = self.builder.select(
        self.builder.icmp_signed("<", llen, rlen, name="by.eq.lt"),
        llen,
        rlen,
        name="by.eq.min"
    );
    memcmp_fn = self._get_or_declare_extern("memcmp", i32, [i8p, i8p, i64]);
    cmp = self.builder.call(
        memcmp_fn,
        [self._bytes_data_ptr(left), self._bytes_data_ptr(right), minlen],
        name="by.eq.memcmp"
    );
    data_eq = self.builder.icmp_signed(
        "==", cmp, ir.Constant(i32, 0), name="by.eq.data"
    );
    full_eq = self.builder.and_(len_eq, data_eq, name="by.eq.full");
    live_end_bb = self.builder.basic_block;
    self.builder.branch(done_bb);
    self.builder.position_at_end(done_bb);
    res = self.builder.phi(i1, name="by.eq");
    res.add_incoming(both_null, entry_bb);
    res.add_incoming(full_eq, live_end_bb);
    if negate {
        return self.builder.not_(res, name="by.ne");
    }
    return res;
}

# ─── #6749: the remaining bytes ops, all length-aware on jacbytes* ───
"""True iff `t` is the jacbytes struct pointer type (a *type*, not a value —
used where only the LLVM type is in hand, e.g. dict key comparison)."""
impl NaIRGenPass._is_bytes_type(t: ir.Type) -> bool {
    if self._bytes_struct_type is None {
        return False;
    }
    return isinstance(t, ir.PointerType) and t.pointee == self._bytes_struct_type;
}

"""bytes truthiness -> i1: non-empty is truthy. A bytes value is never a null
pointer, so (like list/dict/set) the test is len != 0, NOT a null check."""
impl NaIRGenPass._emit_bytes_truthy(bv: ir.Value) -> ir.Value {
    return self.builder.icmp_unsigned(
        "!=", self._bytes_len_val(bv), ir.Constant(ir.IntType(64), 0), name="by.truthy"
    );
}

"""bytes * int (or int * bytes) -> a fresh bytes repeated `count` times.
A negative/zero count yields empty (CPython parity). Mirrors the concat path:
allocate len*count and loop-memcpy the data region. _bytes_alloc marks the
result owned (rc=1), so the caller owns it."""
impl NaIRGenPass._emit_bytes_repeat(bv: ir.Value, count: ir.Value) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    n = self._coerce_type(count, i64);
    is_neg = self.builder.icmp_signed("<", n, ir.Constant(i64, 0), name="by.rep.neg");
    n = self.builder.select(is_neg, ir.Constant(i64, 0), n, name="by.rep.n");
    blen = self._bytes_len_val(bv);
    total = self.builder.mul(blen, n, name="by.rep.total");
    result = self._bytes_alloc(total);
    dst = self._bytes_data_ptr(result);
    src = self._bytes_data_ptr(bv);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    func = self.builder.basic_block.function;
    entry_bb = self.builder.basic_block;
    loop_bb = func.append_basic_block(name="by.rep.loop");
    body_bb = func.append_basic_block(name="by.rep.body");
    done_bb = func.append_basic_block(name="by.rep.done");
    self.builder.branch(loop_bb);
    self.builder.position_at_start(loop_bb);
    cnt = self.builder.phi(i64, name="by.rep.cnt");
    cnt.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = self.builder.icmp_unsigned(">=", cnt, n, name="by.rep.atend");
    self.builder.cbranch(at_end, done_bb, body_bb);
    self.builder.position_at_start(body_bb);
    off = self.builder.mul(cnt, blen, name="by.rep.off");
    d = self.builder.gep(dst, [off], name="by.rep.dst");
    self.builder.call(memcpy_fn, [d, src, blen]);
    next_cnt = self.builder.add(cnt, ir.Constant(i64, 1), name="by.rep.next");
    cnt.add_incoming(next_cnt, body_bb);
    self.builder.branch(loop_bb);
    self.builder.position_at_start(done_bb);
    return result;
}

"""`needle in haystack` for bytes -> i1. Length-aware via memmem, so it sees
past embedded NULs (strstr would stop at the first one) and treats an empty
needle as present (CPython parity)."""
impl NaIRGenPass._emit_bytes_contains(
    needle: ir.Value, haystack: ir.Value
) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    memmem_fn = self._get_or_declare_extern("memmem", i8p, [i8p, i64, i8p, i64]);
    found = self.builder.call(
        memmem_fn,
        [
            self._bytes_data_ptr(haystack),
            self._bytes_len_val(haystack),
            self._bytes_data_ptr(needle),
            self._bytes_len_val(needle)
        ],
        name="by.in.memmem"
    );
    return self.builder.icmp_unsigned(
        "!=", found, ir.Constant(i8p, None), name="by.in.found"
    );
}

"""3-way lexicographic comparison of two bytes (CPython unsigned-byte order):
returns i32 <0 / 0 / >0 like memcmp, with a length tiebreak when one is a
prefix of the other. The caller compares the result to 0 with the operator's
predicate — the same shape the strcmp path uses for str ordering.

Null-safe (#6751): ordering a `bytes | None` against bytes when the operand is
None raises TypeError (CPython parity: `op_sym` is unsupported between bytes
and NoneType), which also avoids dereferencing the null before the compare.
`op_sym` is the source operator ('<' / '>' / '<=' / '>=') so the message names
the operator the user actually wrote."""
impl NaIRGenPass._emit_bytes_cmp(
    left: ir.Value, right: ir.Value, op_sym: str
) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    # Raise (not deref) if either operand is None/null.
    lnull = self.builder.icmp_unsigned(
        "==", left, ir.Constant(left.type, None), name="by.cmp.lnull"
    );
    rnull = self.builder.icmp_unsigned(
        "==", right, ir.Constant(right.type, None), name="by.cmp.rnull"
    );
    self._emit_runtime_raise(
        self.builder.or_(lnull, rnull, name="by.cmp.enull"),
        "TypeError",
        f"'{op_sym}' not supported between instances of 'bytes' and 'NoneType'"
    );
    llen = self._bytes_len_val(left);
    rlen = self._bytes_len_val(right);
    l_lt_r = self.builder.icmp_signed("<", llen, rlen, name="by.cmp.llt");
    l_gt_r = self.builder.icmp_signed(">", llen, rlen, name="by.cmp.lgt");
    minlen = self.builder.select(l_lt_r, llen, rlen, name="by.cmp.min");
    memcmp_fn = self._get_or_declare_extern("memcmp", i32, [i8p, i8p, ir.IntType(64)]);
    c = self.builder.call(
        memcmp_fn,
        [self._bytes_data_ptr(left), self._bytes_data_ptr(right), minlen],
        name="by.cmp.memcmp"
    );
    len_ord = self.builder.select(
        l_gt_r,
        ir.Constant(i32, 1),
        self.builder.select(
            l_lt_r, ir.Constant(i32, -1), ir.Constant(i32, 0), name="by.cmp.lo0"
        ),
        name="by.cmp.lenord"
    );
    c_nz = self.builder.icmp_signed("!=", c, ir.Constant(i32, 0), name="by.cmp.cnz");
    return self.builder.select(c_nz, c, len_ord, name="by.cmp.ord");
}

"""str(bytes) -> the CPython b'...' repr as an i8* string. Delegates to a
single per-module helper function so the (non-trivial) escaping logic is
emitted once rather than at every call site."""
impl NaIRGenPass._emit_bytes_repr(bv: ir.Value) -> ir.Value {
    return self.builder.call(self._bytes_repr_fn(), [bv], name="by.repr");
}

"""Build (once) `i8* __jac_bytes_repr(jacbytes*)` producing CPython's bytes
repr: a `b`-prefixed quoted literal with `\\t`/`\\n`/`\\r`/`\\\\`/`\\xNN`
escapes, single-quoted unless the data has a `'` but no `\"` (then
double-quoted). The data loop is branchless: it computes up to four output
bytes per input byte via selects and writes them into a worst-case
(4*len + 5) rc-allocated buffer; stray trailing bytes are overwritten by the
closing quote and NUL."""
impl NaIRGenPass._bytes_repr_fn -> ir.Function {
    if self._bytes_repr_function is not None {
        return self._bytes_repr_function;
    }
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    bt_ptr = self._get_bytes_struct_type().as_pointer();
    fnty = ir.FunctionType(i8p, [bt_ptr]);
    fn = ir.Function(self.llvm_module, fnty, name="__jac_bytes_repr");
    fn.linkage = "private";
    fn.args[0].name = "bv";
    bv = fn.args[0];
    entry_bb = fn.append_basic_block("entry");
    b = ir.IRBuilder(entry_bb);
    SQ = ir.Constant(i8, 0x27);  # '
    DQ = ir.Constant(i8, 0x22);  # "
    BSL = ir.Constant(i8, 0x5C);  # \
    # len / data of the bytes value.
    blen = b.load(b.gep(bv, [ir.Constant(i32, 0), ir.Constant(i32, 0)]), name="r.len");
    data = b.bitcast(
        b.gep(bv, [ir.Constant(i32, 0), ir.Constant(i32, 1)]), i8p, name="r.data"
    );
    # ── pass 1: quote selection — scan for ' and " ──
    has_sq = b.alloca(i1, name="r.has.sq");
    has_dq = b.alloca(i1, name="r.has.dq");
    si = b.alloca(i64, name="r.si");
    b.store(ir.Constant(i1, 0), has_sq);
    b.store(ir.Constant(i1, 0), has_dq);
    b.store(ir.Constant(i64, 0), si);
    sc_cond = fn.append_basic_block("r.sc.cond");
    sc_body = fn.append_basic_block("r.sc.body");
    sc_done = fn.append_basic_block("r.sc.done");
    b.branch(sc_cond);
    b.position_at_end(sc_cond);
    sidx = b.load(si, name="r.sidx");
    b.cbranch(b.icmp_signed("<", sidx, blen, name="r.sc.go"), sc_body, sc_done);
    b.position_at_end(sc_body);
    sc = b.load(b.gep(data, [sidx], name="r.sc.ptr"), name="r.sc.ch");
    b.store(
        b.or_(b.load(has_sq), b.icmp_unsigned("==", sc, SQ, name="r.sc.isq")), has_sq
    );
    b.store(
        b.or_(b.load(has_dq), b.icmp_unsigned("==", sc, DQ, name="r.sc.idq")), has_dq
    );
    b.store(b.add(sidx, ir.Constant(i64, 1)), si);
    b.branch(sc_cond);
    b.position_at_end(sc_done);
    use_dq = b.and_(
        b.load(has_sq), b.not_(b.load(has_dq), name="r.no.dq"), name="r.use.dq"
    );
    quote = b.select(use_dq, DQ, SQ, name="r.quote");
    # ── buffer: worst case 4 bytes per input + b, open/close quote, NUL ──
    cap = b.add(b.mul(blen, ir.Constant(i64, 4)), ir.Constant(i64, 5), name="r.cap");
    buf = b.call(self.rc_alloc_fn, [cap], name="r.buf");
    b.store(ir.Constant(i8, 0x62), buf);  # 'b'
    b.store(quote, b.gep(buf, [ir.Constant(i64, 1)], name="r.q0"));
    oi = b.alloca(i64, name="r.oi");
    wi = b.alloca(i64, name="r.wi");
    b.store(ir.Constant(i64, 2), oi);
    b.store(ir.Constant(i64, 0), wi);
    # ── pass 2: write each byte's escape form (branchless per byte) ──
    w_cond = fn.append_basic_block("r.w.cond");
    w_body = fn.append_basic_block("r.w.body");
    w_done = fn.append_basic_block("r.w.done");
    b.branch(w_cond);
    b.position_at_end(w_cond);
    widx = b.load(wi, name="r.widx");
    b.cbranch(b.icmp_signed("<", widx, blen, name="r.w.go"), w_body, w_done);
    b.position_at_end(w_body);
    c = b.load(b.gep(data, [widx], name="r.c.ptr"), name="r.c");
    is_bsl = b.icmp_unsigned("==", c, BSL, name="r.is.bsl");
    is_q = b.icmp_unsigned("==", c, quote, name="r.is.q");
    is_tab = b.icmp_unsigned("==", c, ir.Constant(i8, 0x09), name="r.is.tab");
    is_nl = b.icmp_unsigned("==", c, ir.Constant(i8, 0x0A), name="r.is.nl");
    is_cr = b.icmp_unsigned("==", c, ir.Constant(i8, 0x0D), name="r.is.cr");
    ge_sp = b.icmp_unsigned(">=", c, ir.Constant(i8, 0x20), name="r.ge.sp");
    le_ti = b.icmp_unsigned("<=", c, ir.Constant(i8, 0x7E), name="r.le.ti");
    is_print = b.and_(ge_sp, le_ti, name="r.is.print");
    is_special = b.or_(is_bsl, is_q, name="r.is.special");
    is_ctrl = b.or_(b.or_(is_tab, is_nl, name="r.tn"), is_cr, name="r.is.ctrl");
    is_plain = b.and_(is_print, b.not_(is_special, name="r.not.sp"), name="r.is.plain");
    is_hex = b.not_(
        b.or_(b.or_(is_special, is_ctrl, name="r.sc1"), is_plain, name="r.sc2"),
        name="r.is.hex"
    );
    # nibble -> ascii hex (lowercase): d<10 ? '0'+d : 'a'-10+d
    hi = b.lshr(c, ir.Constant(i8, 4), name="r.hi");
    lo = b.and_(c, ir.Constant(i8, 0x0F), name="r.lo");
    hi_lt = b.icmp_unsigned("<", hi, ir.Constant(i8, 10), name="r.hi.lt");
    lo_lt = b.icmp_unsigned("<", lo, ir.Constant(i8, 10), name="r.lo.lt");
    hi_hex = b.select(
        hi_lt,
        b.add(hi, ir.Constant(i8, 48)),
        b.add(hi, ir.Constant(i8, 87)),
        name="r.hi.x"
    );
    lo_hex = b.select(
        lo_lt,
        b.add(lo, ir.Constant(i8, 48)),
        b.add(lo, ir.Constant(i8, 87)),
        name="r.lo.x"
    );
    # o0: plain -> c, else '\' ; o1: special -> (\ or quote), ctrl -> t/n/r, hex -> 'x'
    o0 = b.select(is_plain, c, BSL, name="r.o0");
    ctrl_ch = b.select(
        is_tab,
        ir.Constant(i8, 0x74),  # t
        b.select(is_nl, ir.Constant(i8, 0x6E), ir.Constant(i8, 0x72), name="r.nr"),
        name="r.ctrl.ch"
    );  # n / r
    special_ch = b.select(is_bsl, BSL, quote, name="r.special.ch");
    o1 = b.select(
        is_special,
        special_ch,
        b.select(is_ctrl, ctrl_ch, ir.Constant(i8, 0x78), name="r.o1.x"),  # 'x'
        name="r.o1"
    );
    klen = b.select(
        is_plain,
        ir.Constant(i64, 1),
        b.select(is_hex, ir.Constant(i64, 4), ir.Constant(i64, 2), name="r.k0"),
        name="r.klen"
    );
    # Unconditional stores of all four candidate bytes; oi advances by klen so
    # unused trailing bytes are overwritten next iteration / by the closing
    # quote+NUL (buffer is sized for the 4-byte worst case).
    oi_cur = b.load(oi, name="r.oi.cur");
    b.store(o0, b.gep(buf, [oi_cur], name="r.s0"));
    b.store(o1, b.gep(buf, [b.add(oi_cur, ir.Constant(i64, 1))], name="r.s1"));
    b.store(hi_hex, b.gep(buf, [b.add(oi_cur, ir.Constant(i64, 2))], name="r.s2"));
    b.store(lo_hex, b.gep(buf, [b.add(oi_cur, ir.Constant(i64, 3))], name="r.s3"));
    b.store(b.add(oi_cur, klen), oi);
    b.store(b.add(widx, ir.Constant(i64, 1)), wi);
    b.branch(w_cond);
    b.position_at_end(w_done);
    oi_end = b.load(oi, name="r.oi.end");
    b.store(quote, b.gep(buf, [oi_end], name="r.qc"));
    b.store(
        ir.Constant(i8, 0),
        b.gep(buf, [b.add(oi_end, ir.Constant(i64, 1))], name="r.nul")
    );
    b.ret(buf);
    self._bytes_repr_function = fn;
    return fn;
}
