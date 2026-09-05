impl NativeIntEmitter.emit_to_bytes(
    self: NativeIntEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if len(args) < 2 {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    zero64 = ir.Constant(i64, 0);
    one64 = ir.Constant(i64, 1);
    eight64 = ir.Constant(i64, 8);
    mask_ff = ir.Constant(i64, 0xFF);
    length = p._coerce_type(args[0], i64);
    byteorder = args[1];

    bv = p._bytes_alloc(length);
    buf = p._bytes_data_ptr(bv);

    big_str = p._make_global_string("big");
    cmp_res = p._call_str_cmp(b, byteorder, big_str, name="tb.cmp");
    is_big = b.icmp_signed("==", cmp_res, ir.Constant(i32, 0), name="tb.isbig");

    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="tb.loop");
    body_bb = func.append_basic_block(name="tb.body");
    done_bb = func.append_basic_block(name="tb.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="tb.idx");
    idx.add_incoming(zero64, entry_bb);
    at_end = b.icmp_unsigned(">=", idx, length, name="tb.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);

    shift_amt = b.mul(idx, eight64, name="tb.shift");
    shifted = b.lshr(target, shift_amt, name="tb.shifted");
    byte_val = b.and_(shifted, mask_ff, name="tb.byte");
    byte_i8 = b.trunc(byte_val, i8, name="tb.i8");

    big_pos = b.sub(b.sub(length, one64, name="tb.lm1"), idx, name="tb.bigpos");
    store_pos = b.select(is_big, big_pos, idx, name="tb.pos");
    byte_ptr = b.gep(buf, [store_pos], name="tb.ptr");
    b.store(byte_i8, byte_ptr);
    next_idx = b.add(idx, one64, name="tb.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return bv;
}

impl NativeIntEmitter.emit_as_integer_ratio(
    self: NativeIntEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    one = ir.Constant(i64, 1);
    tuple_type = ir.LiteralStructType([i64, i64]);
    null_ptr = ir.Constant(tuple_type.as_pointer(), None);
    size_gep = b.gep(null_ptr, [ir.Constant(i32, 1)], name="iair.sizeof.gep");
    size = b.ptrtoint(size_gep, i64, name="iair.sizeof");
    p._set_rc_ctx("as_integer_ratio", "");
    raw_ptr = b.call(p.rc_alloc_fn, [size], name="iair.alloc");
    p._clear_rc_ctx();
    tuple_ptr = b.bitcast(raw_ptr, tuple_type.as_pointer(), name="iair.ptr");
    n_ptr = b.gep(
        tuple_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="iair.n.ptr"
    );
    d_ptr = b.gep(
        tuple_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="iair.d.ptr"
    );
    b.store(target, n_ptr);
    b.store(one, d_ptr);
    tkey = "i64.i64";
    if tkey not in p.tuple_types {
        p.tuple_types[tkey] = tuple_type;
    }
    return tuple_ptr;
}

impl NativeIntEmitter.emit_bit_length(
    self: NativeIntEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);

    is_neg = b.icmp_signed("<", target, zero, name="bitlen.neg");
    neg_val = b.sub(zero, target, name="bitlen.abs");
    abs_val = b.select(is_neg, neg_val, target, name="bitlen.absv");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="bitlen.loop");
    body_bb = func.append_basic_block(name="bitlen.body");
    done_bb = func.append_basic_block(name="bitlen.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    val = b.phi(i64, name="bitlen.val");
    count = b.phi(i64, name="bitlen.count");
    val.add_incoming(abs_val, entry_bb);
    count.add_incoming(zero, entry_bb);
    is_zero = b.icmp_unsigned("==", val, zero, name="bitlen.iszero");
    b.cbranch(is_zero, done_bb, body_bb);
    b.position_at_start(body_bb);
    new_val = b.lshr(val, one, name="bitlen.shr");
    new_count = b.add(count, one, name="bitlen.inc");
    val.add_incoming(new_val, body_bb);
    count.add_incoming(new_count, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return count;
}

impl NativeIntEmitter.emit_bit_count(
    self: NativeIntEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);

    is_neg = b.icmp_signed("<", target, zero, name="bitcnt.neg");
    neg_val = b.sub(zero, target, name="bitcnt.abs");
    abs_val = b.select(is_neg, neg_val, target, name="bitcnt.absv");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="bitcnt.loop");
    body_bb = func.append_basic_block(name="bitcnt.body");
    done_bb = func.append_basic_block(name="bitcnt.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    val = b.phi(i64, name="bitcnt.val");
    count = b.phi(i64, name="bitcnt.count");
    val.add_incoming(abs_val, entry_bb);
    count.add_incoming(zero, entry_bb);
    is_zero = b.icmp_unsigned("==", val, zero, name="bitcnt.iszero");
    b.cbranch(is_zero, done_bb, body_bb);
    b.position_at_start(body_bb);
    bit = b.and_(val, one, name="bitcnt.bit");
    new_count = b.add(count, bit, name="bitcnt.inc");
    new_val = b.lshr(val, one, name="bitcnt.shr");
    val.add_incoming(new_val, body_bb);
    count.add_incoming(new_count, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return count;
}

impl NativeIntEmitter.emit_conjugate(
    self: NativeIntEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return target;
}

impl NativeIntEmitter.emit_from_bytes(
    self: NativeIntEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if len(args) < 2 {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    zero64 = ir.Constant(i64, 0);
    one64 = ir.Constant(i64, 1);
    eight64 = ir.Constant(i64, 8);
    bytes_obj = args[0];
    byteorder = args[1];

    if p._is_bytes_value(bytes_obj) {
        length = p._bytes_len_val(bytes_obj);
        bytes_ptr = p._bytes_data_ptr(bytes_obj);
    } else {
        length = p._call_str_len(b, bytes_obj, name="fb.len");
        bytes_ptr = bytes_obj;
    }

    big_str = p._make_global_string("big");
    cmp_res = p._call_str_cmp(b, byteorder, big_str, name="fb.cmp");
    is_big = b.icmp_signed("==", cmp_res, ir.Constant(i32, 0), name="fb.isbig");

    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="fb.loop");
    body_bb = func.append_basic_block(name="fb.body");
    done_bb = func.append_basic_block(name="fb.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="fb.idx");
    result = b.phi(i64, name="fb.result");
    idx.add_incoming(zero64, entry_bb);
    result.add_incoming(zero64, entry_bb);
    at_end = b.icmp_unsigned(">=", idx, length, name="fb.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);

    byte_ptr = b.gep(bytes_ptr, [idx], name="fb.bptr");
    byte_val = b.load(byte_ptr, name="fb.byte");
    byte_i64 = b.zext(byte_val, i64, name="fb.ext");

    big_shift_idx = b.sub(b.sub(length, one64, name="fb.lm1"), idx, name="fb.bidx");
    shift_idx = b.select(is_big, big_shift_idx, idx, name="fb.sidx");
    shift_amt = b.mul(shift_idx, eight64, name="fb.shift");
    shifted = b.shl(byte_i64, shift_amt, name="fb.shifted");
    new_result = b.or_(result, shifted, name="fb.accum");
    next_idx = b.add(idx, one64, name="fb.next");
    idx.add_incoming(next_idx, body_bb);
    result.add_incoming(new_result, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return result;
}

impl NativeFloatEmitter.emit_is_integer(
    self: NativeFloatEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    assert b is not None , "Builder should be set in pass_ref";

    truncated = b.fptosi(target, i64, name="isint.trunc");
    roundtripped = b.sitofp(truncated, ir.DoubleType(), name="isint.rt");
    is_eq = b.fcmp_ordered("==", target, roundtripped, name="isint.eq");
    return b.zext(is_eq, i64, name="isint.result");
}

impl NativeFloatEmitter.emit_as_integer_ratio(
    self: NativeFloatEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    f64 = ir.DoubleType();
    func = b.basic_block.function;

    floor_fn = p._get_or_declare_extern("floor", f64, [f64]);

    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="fair.loop");
    body_bb = func.append_basic_block(name="fair.body");
    done_bb = func.append_basic_block(name="fair.done");
    two = ir.Constant(f64, 2.0);
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    num_phi = b.phi(f64, name="fair.num");
    den_phi = b.phi(i64, name="fair.den");
    num_phi.add_incoming(target, entry_bb);
    den_phi.add_incoming(ir.Constant(i64, 1), entry_bb);
    floored = b.call(floor_fn, [num_phi], name="fair.floor");
    is_int = b.fcmp_ordered("==", num_phi, floored, name="fair.isint");
    b.cbranch(is_int, done_bb, body_bb);
    b.position_at_start(body_bb);
    new_num = b.fmul(num_phi, two, name="fair.num2");
    new_den = b.mul(den_phi, ir.Constant(i64, 2), name="fair.den2");
    num_phi.add_incoming(new_num, body_bb);
    den_phi.add_incoming(new_den, body_bb);
    b.branch(loop_bb);

    b.position_at_start(done_bb);
    numer = b.fptosi(num_phi, i64, name="fair.numer");
    tuple_type = ir.LiteralStructType([i64, i64]);
    null_ptr = ir.Constant(tuple_type.as_pointer(), None);
    size_gep = b.gep(null_ptr, [ir.Constant(i32, 1)], name="fair.sizeof.gep");
    size = b.ptrtoint(size_gep, i64, name="fair.sizeof");
    p._set_rc_ctx("as_integer_ratio", "");
    raw_ptr = b.call(p.rc_alloc_fn, [size], name="fair.alloc");
    p._clear_rc_ctx();
    tuple_ptr = b.bitcast(raw_ptr, tuple_type.as_pointer(), name="fair.ptr");
    n_ptr = b.gep(
        tuple_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="fair.n.ptr"
    );
    d_ptr = b.gep(
        tuple_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="fair.d.ptr"
    );
    b.store(numer, n_ptr);
    b.store(den_phi, d_ptr);
    tkey = "i64.i64";
    if tkey not in p.tuple_types {
        p.tuple_types[tkey] = tuple_type;
    }
    return tuple_ptr;
}

impl NativeFloatEmitter.emit_conjugate(
    self: NativeFloatEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return target;
}

impl NativeFloatEmitter.emit_hex(
    self: NativeFloatEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    buf_size = ir.Constant(i64, 64);
    p._set_rc_ctx("float_hex", "");
    buf = p._str_alloc(b, buf_size, name="fhex.buf");
    p._clear_rc_ctx();
    fmt = p._make_global_string("%a");
    snprintf = p._get_or_declare_extern("snprintf", i32, [i8p, i64, i8p], var_arg=True);
    fhex_n32 = b.call(snprintf, [buf, buf_size, fmt, target], name="fhex.len");
    p._str_finish(b, buf, b.sext(fhex_n32, i64, name="fhex.len64"));
    return buf;
}

impl NativeFloatEmitter.emit_fromhex(
    self: NativeFloatEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    f64 = ir.DoubleType();
    i8p = ir.IntType(8).as_pointer();
    strtod_fn = p._get_or_declare_extern("strtod", f64, [i8p, i8p.as_pointer()]);
    null_ptr = ir.Constant(i8p.as_pointer(), None);
    result = b.call(strtod_fn, [args[0], null_ptr], name="fhex.result");
    return result;
}

impl NativeBoolEmitter.emit_op_and(
    self: NativeBoolEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i1 = ir.IntType(1);
    lhs = p._coerce_type(target, i1) if target.type != i1 else target;
    rhs = p._coerce_type(args[0], i1) if args[0].type != i1 else args[0];
    return b.and_(lhs, rhs, name="bool.and");
}

impl NativeBoolEmitter.emit_op_or(
    self: NativeBoolEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i1 = ir.IntType(1);
    lhs = p._coerce_type(target, i1) if target.type != i1 else target;
    rhs = p._coerce_type(args[0], i1) if args[0].type != i1 else args[0];
    return b.or_(lhs, rhs, name="bool.or");
}

impl NativeBoolEmitter.emit_op_xor(
    self: NativeBoolEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i1 = ir.IntType(1);
    lhs = p._coerce_type(target, i1) if target.type != i1 else target;
    rhs = p._coerce_type(args[0], i1) if args[0].type != i1 else args[0];
    return b.xor(lhs, rhs, name="bool.xor");
}

impl NativeComplexEmitter._load_parts(
    self: NativeComplexEmitter, ctx: NativeEmitCtx, val: ir.Value
) -> (tuple | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    z0 = ir.Constant(i32, 0);
    z1 = ir.Constant(i32, 1);
    r = b.load(b.gep(val, [z0, z0], name="cx.rp"), name="cx.r");
    im = b.load(b.gep(val, [z0, z1], name="cx.ip"), name="cx.i");
    return (r, im);
}

impl NativeComplexEmitter._make_complex(
    self: NativeComplexEmitter, ctx: NativeEmitCtx, real: ir.Value, imag: ir.Value
) -> ir.Value {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    z0 = ir.Constant(i32, 0);
    z1 = ir.Constant(i32, 1);
    ctype = p.complex_struct_type;
    p._set_rc_ctx("complex_new", "");
    raw = b.call(p.rc_alloc_fn, [ir.Constant(i64, 16)], name="cx.raw");
    p._clear_rc_ctx();
    ptr = b.bitcast(raw, ctype.as_pointer(), name="cx.ptr");
    b.store(real, b.gep(ptr, [z0, z0], name="cx.srp"));
    b.store(imag, b.gep(ptr, [z0, z1], name="cx.sip"));
    return ptr;
}

impl NativeComplexEmitter.emit_conjugate(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    parts = self._load_parts(ctx, target);
    if parts is None {
        return None;
    }
    (r, im) = parts;
    ni = ctx.pass_ref.builder.fneg(im, name="conj.ni");
    return self._make_complex(ctx, r, ni);
}

impl NativeComplexEmitter.emit_op_add(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeComplexEmitter.emit_op_sub(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeComplexEmitter.emit_op_mul(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeComplexEmitter.emit_op_truediv(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeComplexEmitter.emit_op_pow(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeComplexEmitter.emit_op_eq(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeComplexEmitter.emit_op_ne(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeComplexEmitter.emit_op_neg(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeComplexEmitter.emit_op_pos(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeStrEmitter.emit_capitalize(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    toupper_fn = p._get_or_declare_extern("toupper", i32, [i32]);
    tolower_fn = p._get_or_declare_extern("tolower", i32, [i32]);
    slen = p._call_str_len(b, target, name="cap.len");
    alloc_size = b.add(slen, ir.Constant(i64, 1), name="cap.alloc.sz");
    p._set_rc_ctx("capitalize", "");
    result = p._str_alloc(b, alloc_size, name="cap.buf");
    p._clear_rc_ctx();
    is_empty = b.icmp_unsigned("==", slen, ir.Constant(i64, 0), name="cap.empty");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    first_bb = func.append_basic_block(name="cap.first");
    loop_bb = func.append_basic_block(name="cap.loop");
    body_bb = func.append_basic_block(name="cap.body");
    done_bb = func.append_basic_block(name="cap.done");
    b.cbranch(is_empty, done_bb, first_bb);

    b.position_at_start(first_bb);
    first_ch = b.load(target, name="cap.first.ch");
    first_i32 = b.zext(first_ch, i32, name="cap.first.i32");
    upper_ch = b.call(toupper_fn, [first_i32], name="cap.first.upper");
    upper_i8 = b.trunc(upper_ch, i8, name="cap.first.i8");
    b.store(upper_i8, result);
    b.branch(loop_bb);

    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="cap.idx");
    idx.add_incoming(ir.Constant(i64, 1), first_bb);
    cond = b.icmp_unsigned("<", idx, slen, name="cap.cond");
    b.cbranch(cond, body_bb, done_bb);
    b.position_at_start(body_bb);
    src_ptr = b.gep(target, [idx], name="cap.src.ptr");
    ch = b.load(src_ptr, name="cap.ch");
    ch_i32 = b.zext(ch, i32, name="cap.ch.i32");
    lower_ch = b.call(tolower_fn, [ch_i32], name="cap.lower");
    lower_i8 = b.trunc(lower_ch, i8, name="cap.lower.i8");
    dst_ptr = b.gep(result, [idx], name="cap.dst.ptr");
    b.store(lower_i8, dst_ptr);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="cap.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    p._str_finish(b, result, slen);
    return result;
}

impl NativeStrEmitter.emit_casefold(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_case_transform(ctx, target, "tolower");
}

impl NativeStrEmitter.emit_lower(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_case_transform(ctx, target, "tolower");
}

impl NativeStrEmitter.emit_upper(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_case_transform(ctx, target, "toupper");
}

impl NativeStrEmitter._emit_case_transform(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, cfunc_name: str
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    slen = p._call_str_len(b, target, name="case.len");
    alloc_size = b.add(slen, ir.Constant(i64, 1), name="case.alloc.sz");
    p._set_rc_ctx("upper_lower", "");
    result = p._str_alloc(b, alloc_size, name="case.buf");
    p._clear_rc_ctx();
    transform_fn = p._get_or_declare_extern(cfunc_name, i32, [i32]);
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="case.loop");
    body_bb = func.append_basic_block(name="case.body");
    done_bb = func.append_basic_block(name="case.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="case.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    cond = b.icmp_unsigned("<", idx, slen, name="case.cond");
    b.cbranch(cond, body_bb, done_bb);
    b.position_at_start(body_bb);
    src_ptr = b.gep(target, [idx], name="case.src.ptr");
    ch = b.load(src_ptr, name="case.ch");
    ch_i32 = b.zext(ch, i32, name="case.ch.i32");
    transformed = b.call(transform_fn, [ch_i32], name="case.transformed");
    ch_out = b.trunc(transformed, i8, name="case.ch.out");
    dst_ptr = b.gep(result, [idx], name="case.dst.ptr");
    b.store(ch_out, dst_ptr);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="case.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    p._str_finish(b, result, slen);
    return result;
}

impl NativeStrEmitter.emit_title(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    toupper_fn = p._get_or_declare_extern("toupper", i32, [i32]);
    tolower_fn = p._get_or_declare_extern("tolower", i32, [i32]);
    isalpha_fn = p._get_or_declare_extern("isalpha", i32, [i32]);
    slen = p._call_str_len(b, target, name="title.len");
    alloc_size = b.add(slen, ir.Constant(i64, 1), name="title.alloc");
    p._set_rc_ctx("title", "");
    result = p._str_alloc(b, alloc_size, name="title.buf");
    p._clear_rc_ctx();
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="title.loop");
    body_bb = func.append_basic_block(name="title.body");
    done_bb = func.append_basic_block(name="title.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="title.idx");
    at_boundary = b.phi(i64, name="title.boundary");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_boundary.add_incoming(ir.Constant(i64, 1), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, slen, name="title.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    src_ptr = b.gep(target, [idx], name="title.src.ptr");
    ch = b.load(src_ptr, name="title.ch");
    ch_i32 = b.zext(ch, i32, name="title.ch.i32");
    is_alpha = b.call(isalpha_fn, [ch_i32], name="title.isalpha");
    is_alpha_bool = b.icmp_signed(
        "!=", is_alpha, ir.Constant(i32, 0), name="title.isalp"
    );
    is_boundary = b.icmp_unsigned(
        "!=", at_boundary, ir.Constant(i64, 0), name="title.isbnd"
    );
    upper_ch = b.call(toupper_fn, [ch_i32], name="title.upper");
    lower_ch = b.call(tolower_fn, [ch_i32], name="title.lower");
    should_upper = b.and_(is_boundary, is_alpha_bool, name="title.shup");
    pick1 = b.select(should_upper, upper_ch, ch_i32, name="title.pick1");
    should_lower = b.and_(
        b.not_(is_boundary, name="title.notbnd"), is_alpha_bool, name="title.shlo"
    );
    pick2 = b.select(should_lower, lower_ch, pick1, name="title.pick2");
    out_i8 = b.trunc(pick2, i8, name="title.out");
    dst_ptr = b.gep(result, [idx], name="title.dst.ptr");
    b.store(out_i8, dst_ptr);
    new_boundary = b.select(
        is_alpha_bool, ir.Constant(i64, 0), ir.Constant(i64, 1), name="title.newbnd"
    );
    next_idx = b.add(idx, ir.Constant(i64, 1), name="title.next");
    idx.add_incoming(next_idx, body_bb);
    at_boundary.add_incoming(new_boundary, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    p._str_finish(b, result, slen);
    return result;
}

impl NativeStrEmitter.emit_swapcase(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    toupper_fn = p._get_or_declare_extern("toupper", i32, [i32]);
    tolower_fn = p._get_or_declare_extern("tolower", i32, [i32]);
    islower_fn = p._get_or_declare_extern("islower", i32, [i32]);
    isupper_fn = p._get_or_declare_extern("isupper", i32, [i32]);
    slen = p._call_str_len(b, target, name="swap.len");
    alloc_size = b.add(slen, ir.Constant(i64, 1), name="swap.alloc.sz");
    p._set_rc_ctx("swapcase", "");
    result = p._str_alloc(b, alloc_size, name="swap.buf");
    p._clear_rc_ctx();
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="swap.loop");
    body_bb = func.append_basic_block(name="swap.body");
    done_bb = func.append_basic_block(name="swap.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="swap.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    cond = b.icmp_unsigned("<", idx, slen, name="swap.cond");
    b.cbranch(cond, body_bb, done_bb);
    b.position_at_start(body_bb);
    src_ptr = b.gep(target, [idx], name="swap.src.ptr");
    ch = b.load(src_ptr, name="swap.ch");
    ch_i32 = b.zext(ch, i32, name="swap.ch.i32");
    is_low = b.call(islower_fn, [ch_i32], name="swap.islow");
    is_low_bool = b.icmp_signed("!=", is_low, ir.Constant(i32, 0), name="swap.islo");
    upper_ch = b.call(toupper_fn, [ch_i32], name="swap.upper");
    is_up = b.call(isupper_fn, [ch_i32], name="swap.isup");
    is_up_bool = b.icmp_signed("!=", is_up, ir.Constant(i32, 0), name="swap.isup.b");
    lower_ch = b.call(tolower_fn, [ch_i32], name="swap.lower");

    pick1 = b.select(is_up_bool, lower_ch, ch_i32, name="swap.pick1");
    pick2 = b.select(is_low_bool, upper_ch, pick1, name="swap.pick2");
    out_i8 = b.trunc(pick2, i8, name="swap.out");
    dst_ptr = b.gep(result, [idx], name="swap.dst.ptr");
    b.store(out_i8, dst_ptr);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="swap.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    p._str_finish(b, result, slen);
    return result;
}

impl NativeStrEmitter.emit_count(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
    sub_len = p._call_str_len(b, args[0], name="cnt.sub.len");
    null_ptr = ir.Constant(i8p, None);
    func = b.basic_block.function;
    empty_bb = func.append_basic_block(name="cnt.empty");
    scan_bb = func.append_basic_block(name="cnt.scan");
    loop_bb = func.append_basic_block(name="cnt.loop");
    found_bb = func.append_basic_block(name="cnt.found");
    done_bb = func.append_basic_block(name="cnt.done");

    is_empty = b.icmp_unsigned("==", sub_len, ir.Constant(i64, 0), name="cnt.isempty");
    b.cbranch(is_empty, empty_bb, scan_bb);
    b.position_at_start(empty_bb);
    tgt_len = p._call_str_len(b, target, name="cnt.tgt.len");
    empty_count = b.add(tgt_len, ir.Constant(i64, 1), name="cnt.empty.n");
    b.branch(done_bb);
    b.position_at_start(scan_bb);
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    cur_ptr = b.phi(i8p, name="cnt.cur");
    count = b.phi(i64, name="cnt.count");
    cur_ptr.add_incoming(target, scan_bb);
    count.add_incoming(ir.Constant(i64, 0), scan_bb);
    found = b.call(strstr_fn, [cur_ptr, args[0]], name="cnt.found.ptr");
    is_null = b.icmp_unsigned("==", found, null_ptr, name="cnt.null");
    b.cbranch(is_null, done_bb, found_bb);
    b.position_at_start(found_bb);
    new_count = b.add(count, ir.Constant(i64, 1), name="cnt.inc");
    found_int = b.ptrtoint(found, i64, name="cnt.fnd.int");
    next_int = b.add(found_int, sub_len, name="cnt.next.int");
    next_ptr = b.inttoptr(next_int, i8p, name="cnt.next.ptr");
    cur_ptr.add_incoming(next_ptr, found_bb);
    count.add_incoming(new_count, found_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    result = b.phi(i64, name="cnt.result");
    result.add_incoming(empty_count, empty_bb);
    result.add_incoming(count, loop_bb);
    return result;
}

impl NativeStrEmitter.emit_find(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
    search_from = target;
    if len(args) >= 2 {
        slen = p._call_str_len(b, target, name="find.slen");
        start = p._coerce_type(args[1], i64);
        neg = b.icmp_signed("<", start, ir.Constant(i64, 0), name="find.st.neg");
        wrapped = b.add(start, slen, name="find.st.wrap");
        start = b.select(neg, wrapped, start, name="find.st.pos");
        below = b.icmp_signed("<", start, ir.Constant(i64, 0), name="find.st.lo");
        start = b.select(below, ir.Constant(i64, 0), start, name="find.st.lo.c");
        above = b.icmp_signed(">", start, slen, name="find.st.hi");
        start = b.select(above, slen, start, name="find.st.hi.c");
        search_from = b.gep(target, [start], name="find.from");
    }
    found = b.call(strstr_fn, [search_from, args[0]], name="find.ptr");
    null_ptr = ir.Constant(i8p, None);
    is_null = b.icmp_unsigned("==", found, null_ptr, name="find.null");
    target_int = b.ptrtoint(target, i64, name="find.tgt.int");
    found_int = b.ptrtoint(found, i64, name="find.fnd.int");
    diff = b.sub(found_int, target_int, name="find.diff");
    return b.select(is_null, ir.Constant(i64, -1), diff, name="find.result");
}

impl NativeStrEmitter.emit_rfind(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
    slen = p._call_str_len(b, target, name="rfind.slen");
    sub_len = p._call_str_len(b, args[0], name="rfind.sub.len");
    null_ptr = ir.Constant(i8p, None);
    target_int = b.ptrtoint(target, i64, name="rfind.tgt.int");
    func = b.basic_block.function;
    entry_bb = b.basic_block;

    empty_bb = func.append_basic_block(name="rfind.empty");
    search_bb = func.append_basic_block(name="rfind.search");
    loop_bb = func.append_basic_block(name="rfind.loop");
    found_bb = func.append_basic_block(name="rfind.found");
    done_bb = func.append_basic_block(name="rfind.done");
    is_empty = b.icmp_unsigned(
        "==", sub_len, ir.Constant(i64, 0), name="rfind.isempty"
    );
    b.cbranch(is_empty, empty_bb, search_bb);
    b.position_at_start(empty_bb);
    b.branch(done_bb);
    b.position_at_start(search_bb);
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    cur_ptr = b.phi(i8p, name="rfind.cur");
    last_pos = b.phi(i64, name="rfind.last");
    cur_ptr.add_incoming(target, search_bb);
    last_pos.add_incoming(ir.Constant(i64, -1), search_bb);
    found = b.call(strstr_fn, [cur_ptr, args[0]], name="rfind.found.ptr");
    is_null = b.icmp_unsigned("==", found, null_ptr, name="rfind.null");
    b.cbranch(is_null, done_bb, found_bb);
    b.position_at_start(found_bb);
    found_int = b.ptrtoint(found, i64, name="rfind.fnd.int");
    new_pos = b.sub(found_int, target_int, name="rfind.pos");
    next_int = b.add(found_int, sub_len, name="rfind.next.int");
    next_ptr = b.inttoptr(next_int, i8p, name="rfind.next.ptr");
    cur_ptr.add_incoming(next_ptr, found_bb);
    last_pos.add_incoming(new_pos, found_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    result = b.phi(i64, name="rfind.result");
    result.add_incoming(slen, empty_bb);
    result.add_incoming(last_pos, loop_bb);
    return result;
}

impl NativeStrEmitter.emit_index(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
    found = b.call(strstr_fn, [target, args[0]], name="index.ptr");
    null_ptr = ir.Constant(i8p, None);
    is_null = b.icmp_unsigned("==", found, null_ptr, name="index.null");
    p._emit_runtime_raise(is_null, "ValueError", "substring not found");
    target_int = b.ptrtoint(target, i64, name="index.tgt.int");
    found_int = b.ptrtoint(found, i64, name="index.fnd.int");
    return b.sub(found_int, target_int, name="index.result");
}

impl NativeStrEmitter.emit_rindex(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);

    rfind_result = self.emit_rfind(ctx, target, args);
    if rfind_result is None {
        return None;
    }
    is_neg = b.icmp_signed("<", rfind_result, ir.Constant(i64, 0), name="rindex.neg");
    p._emit_runtime_raise(is_neg, "ValueError", "substring not found");
    return rfind_result;
}

impl NativeStrEmitter.emit_startswith(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    strncmp_fn = p._get_or_declare_extern("strncmp", i32, [i8p, i8p, i64]);
    prefix_len = p._call_str_len(b, args[0], name="sw.pfx.len");
    cmp = b.call(strncmp_fn, [target, args[0], prefix_len], name="sw.cmp");
    is_zero = b.icmp_signed("==", cmp, ir.Constant(i32, 0), name="sw.eq");
    return b.zext(is_zero, i64, name="sw.result");
}

impl NativeStrEmitter.emit_endswith(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    target_len = p._call_str_len(b, target, name="ew.tgt.len");
    suffix_len = p._call_str_len(b, args[0], name="ew.sfx.len");
    too_long = b.icmp_unsigned(">", suffix_len, target_len, name="ew.toolong");
    offset = b.sub(target_len, suffix_len, name="ew.offset");
    end_ptr = b.gep(target, [offset], name="ew.end.ptr");
    cmp = p._call_str_cmp(b, end_ptr, args[0], name="ew.cmp");
    is_match = b.icmp_signed("==", cmp, ir.Constant(i32, 0), name="ew.match");
    match_i64 = b.zext(is_match, i64, name="ew.match.i64");
    return b.select(too_long, ir.Constant(i64, 0), match_i64, name="ew.result");
}

impl NativeStrEmitter.emit_replace(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if len(args) < 2 {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    old_str = args[0];
    new_str = args[1];

    count_val: ir.Value = ir.Constant(i64, -1) if len(args) < 3 else args[2];
    target_len = p._call_str_len(b, target, name="repl.tgt.len");
    old_len = p._call_str_len(b, old_str, name="repl.old.len");
    new_len = p._call_str_len(b, new_str, name="repl.new.len");

    generous_factor = b.add(new_len, ir.Constant(i64, 1), name="repl.factor");
    generous_size = b.mul(target_len, generous_factor, name="repl.generous");
    alloc_size = b.add(generous_size, ir.Constant(i64, 1), name="repl.alloc");
    p._set_rc_ctx("replace", "");
    result = p._str_alloc(b, alloc_size, name="repl.buf");
    p._clear_rc_ctx();
    null_ptr = ir.Constant(i8p, None);
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="repl.loop");
    found_bb = func.append_basic_block(name="repl.found");
    notfound_bb = func.append_basic_block(name="repl.notfound");
    done_bb = func.append_basic_block(name="repl.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    src = b.phi(i8p, name="repl.src");
    dst_off = b.phi(i64, name="repl.dst.off");
    remaining = b.phi(i64, name="repl.remaining");
    src.add_incoming(target, entry_bb);
    dst_off.add_incoming(ir.Constant(i64, 0), entry_bb);
    remaining.add_incoming(count_val, entry_bb);

    count_exhausted = b.icmp_signed(
        "==", remaining, ir.Constant(i64, 0), name="repl.exhausted"
    );
    found = b.call(strstr_fn, [src, old_str], name="repl.found.ptr");
    is_null = b.icmp_unsigned("==", found, null_ptr, name="repl.null");
    no_replace = b.or_(count_exhausted, is_null, name="repl.no.repl");
    b.cbranch(no_replace, notfound_bb, found_bb);
    b.position_at_start(found_bb);
    src_int = b.ptrtoint(src, i64, name="repl.src.int");
    found_int = b.ptrtoint(found, i64, name="repl.fnd.int");
    prefix_len = b.sub(found_int, src_int, name="repl.pfx.len");
    dst_ptr = b.gep(result, [dst_off], name="repl.dst.ptr");
    b.call(memcpy_fn, [dst_ptr, src, prefix_len]);
    dst_off2 = b.add(dst_off, prefix_len, name="repl.off2");
    dst_ptr2 = b.gep(result, [dst_off2], name="repl.dst.ptr2");
    b.call(memcpy_fn, [dst_ptr2, new_str, new_len]);
    dst_off3 = b.add(dst_off2, new_len, name="repl.off3");
    next_src_int = b.add(found_int, old_len, name="repl.next.int");
    next_src = b.inttoptr(next_src_int, i8p, name="repl.next.src");

    next_remaining = b.sub(remaining, ir.Constant(i64, 1), name="repl.next.rem");
    src.add_incoming(next_src, found_bb);
    dst_off.add_incoming(dst_off3, found_bb);
    remaining.add_incoming(next_remaining, found_bb);
    b.branch(loop_bb);
    b.position_at_start(notfound_bb);
    remain_len = p._call_str_len_raw(b, src, name="repl.remain.len");
    dst_ptr3 = b.gep(result, [dst_off], name="repl.dst.ptr3");
    b.call(memcpy_fn, [dst_ptr3, src, remain_len]);
    final_len = b.add(dst_off, remain_len, name="repl.final.len");
    p._str_finish(b, result, final_len);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    return result;
}

impl NativeStrEmitter.emit_strip(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    charset = args[0] if args else None;
    return ctx.pass_ref._codegen_str_strip_chars(target, charset, True, True);
}

impl NativeStrEmitter.emit_lstrip(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    charset = args[0] if args else None;
    return ctx.pass_ref._codegen_str_strip_chars(target, charset, True, False);
}

impl NativeStrEmitter.emit_rstrip(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    charset = args[0] if args else None;
    return ctx.pass_ref._codegen_str_strip_chars(target, charset, False, True);
}

impl NativeStrEmitter.emit_removeprefix(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    strncmp_fn = p._get_or_declare_extern("strncmp", i32, [i8p, i8p, i64]);
    strcpy_fn = p._get_or_declare_extern("strcpy", i8p, [i8p, i8p]);
    prefix_len = p._call_str_len(b, args[0], name="rmpfx.pfx.len");
    target_len = p._call_str_len(b, target, name="rmpfx.tgt.len");
    too_long = b.icmp_unsigned(">", prefix_len, target_len, name="rmpfx.toolong");
    func = b.basic_block.function;
    check_bb = func.append_basic_block(name="rmpfx.check");
    match_bb = func.append_basic_block(name="rmpfx.match");
    nomatch_bb = func.append_basic_block(name="rmpfx.nomatch");
    done_bb = func.append_basic_block(name="rmpfx.done");
    b.cbranch(too_long, nomatch_bb, check_bb);
    b.position_at_start(check_bb);
    cmp = b.call(strncmp_fn, [target, args[0], prefix_len], name="rmpfx.cmp");
    is_match = b.icmp_signed("==", cmp, ir.Constant(i32, 0), name="rmpfx.eq");
    b.cbranch(is_match, match_bb, nomatch_bb);

    b.position_at_start(match_bb);
    rest_len = b.sub(target_len, prefix_len, name="rmpfx.rest.len");
    alloc_m = b.add(rest_len, ir.Constant(i64, 1), name="rmpfx.alloc.m");
    p._set_rc_ctx("removeprefix", "");
    result_m = p._str_alloc(b, alloc_m, name="rmpfx.buf.m");
    p._clear_rc_ctx();
    rest_ptr = b.gep(target, [prefix_len], name="rmpfx.rest.ptr");
    b.call(strcpy_fn, [result_m, rest_ptr]);
    p._str_finish(b, result_m, rest_len);
    b.branch(done_bb);

    b.position_at_start(nomatch_bb);
    alloc_n = b.add(target_len, ir.Constant(i64, 1), name="rmpfx.alloc.n");
    p._set_rc_ctx("removeprefix", "");
    result_n = p._str_alloc(b, alloc_n, name="rmpfx.buf.n");
    p._clear_rc_ctx();
    b.call(strcpy_fn, [result_n, target]);
    p._str_finish(b, result_n, target_len);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result_phi = b.phi(i8p, name="rmpfx.result");
    result_phi.add_incoming(result_m, match_bb);
    result_phi.add_incoming(result_n, nomatch_bb);
    return result_phi;
}

impl NativeStrEmitter.emit_removesuffix(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    suffix_len = p._call_str_len(b, args[0], name="rmsfx.sfx.len");
    target_len = p._call_str_len(b, target, name="rmsfx.tgt.len");
    too_long = b.icmp_unsigned(">", suffix_len, target_len, name="rmsfx.toolong");
    func = b.basic_block.function;
    check_bb = func.append_basic_block(name="rmsfx.check");
    match_bb = func.append_basic_block(name="rmsfx.match");
    nomatch_bb = func.append_basic_block(name="rmsfx.nomatch");
    done_bb = func.append_basic_block(name="rmsfx.done");
    b.cbranch(too_long, nomatch_bb, check_bb);
    b.position_at_start(check_bb);
    offset = b.sub(target_len, suffix_len, name="rmsfx.offset");
    end_ptr = b.gep(target, [offset], name="rmsfx.end.ptr");
    cmp = p._call_str_cmp(b, end_ptr, args[0], name="rmsfx.cmp");
    is_match = b.icmp_signed("==", cmp, ir.Constant(i32, 0), name="rmsfx.eq");
    b.cbranch(is_match, match_bb, nomatch_bb);

    b.position_at_start(match_bb);
    new_len = b.sub(target_len, suffix_len, name="rmsfx.newlen");
    alloc_m = b.add(new_len, ir.Constant(i64, 1), name="rmsfx.alloc.m");
    p._set_rc_ctx("removesuffix", "");
    result_m = p._str_alloc(b, alloc_m, name="rmsfx.buf.m");
    p._clear_rc_ctx();
    b.call(memcpy_fn, [result_m, target, new_len]);
    p._str_finish(b, result_m, new_len);
    b.branch(done_bb);

    b.position_at_start(nomatch_bb);
    alloc_n = b.add(target_len, ir.Constant(i64, 1), name="rmsfx.alloc.n");
    p._set_rc_ctx("removesuffix", "");
    result_n = p._str_alloc(b, alloc_n, name="rmsfx.buf.n");
    p._clear_rc_ctx();
    b.call(memcpy_fn, [result_n, target, target_len]);
    p._str_finish(b, result_n, target_len);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result_phi = b.phi(i8p, name="rmsfx.result");
    result_phi.add_incoming(result_m, match_bb);
    result_phi.add_incoming(result_n, nomatch_bb);
    return result_phi;
}

impl NativeStrEmitter.emit_split(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if args {
        return ctx.pass_ref._codegen_str_split(target, args[0]);
    }
    return None;
}

impl NativeStrEmitter.emit_rsplit(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if args {
        return ctx.pass_ref._codegen_str_split(target, args[0]);
    }
    return None;
}

impl NativeStrEmitter.emit_splitlines(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    nl_sep = p._make_global_string("\n", name_prefix=".nl.sep");
    return p._codegen_str_split(target, nl_sep);
}

impl NativeStrEmitter.emit_join(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);

    p._emit_list_helpers("ptr", i8p);
    lhelpers = p.list_helpers.get("ptr");
    if lhelpers is None {
        return None;
    }
    the_list = args[0];
    sep_len = p._call_str_len(b, target, name="jn.seplen");
    list_len = b.call(lhelpers["len"], [the_list], name="jn.listlen");
    func = b.basic_block.function;

    is_empty = b.icmp_unsigned("==", list_len, zero, name="jn.isempty");
    empty_bb = func.append_basic_block(name="jn.empty");
    pass1_bb = func.append_basic_block(name="jn.pass1");
    done_bb = func.append_basic_block(name="jn.done");
    b.cbranch(is_empty, empty_bb, pass1_bb);

    b.position_at_start(empty_bb);
    p._set_rc_ctx("join", "");
    empty_buf = p._str_alloc(b, one, name="jn.empty.buf");
    p._clear_rc_ctx();
    p._str_finish(b, empty_buf, zero);
    b.branch(done_bb);

    b.position_at_start(pass1_bb);
    entry_p1 = b.basic_block;
    loop1_bb = func.append_basic_block(name="jn.len.loop");
    body1_bb = func.append_basic_block(name="jn.len.body");
    pass2_start = func.append_basic_block(name="jn.p2start");
    b.branch(loop1_bb);
    b.position_at_start(loop1_bb);
    p1_idx = b.phi(i64, name="jn.p1.idx");
    p1_total = b.phi(i64, name="jn.p1.total");
    p1_idx.add_incoming(zero, entry_p1);
    p1_total.add_incoming(zero, entry_p1);
    p1_end = b.icmp_unsigned(">=", p1_idx, list_len, name="jn.p1.end");
    b.cbranch(p1_end, pass2_start, body1_bb);
    b.position_at_start(body1_bb);
    elem = b.call(lhelpers["get"], [the_list, p1_idx], name="jn.p1.elem");
    elen = p._call_str_len(b, elem, name="jn.p1.elen");
    new_total = b.add(p1_total, elen, name="jn.p1.ntot");
    next_p1 = b.add(p1_idx, one, name="jn.p1.next");
    p1_idx.add_incoming(next_p1, body1_bb);
    p1_total.add_incoming(new_total, body1_bb);
    b.branch(loop1_bb);

    b.position_at_start(pass2_start);
    total_phi = b.phi(i64, name="jn.total");
    total_phi.add_incoming(p1_total, loop1_bb);
    sep_count = b.sub(list_len, one, name="jn.sepcount");
    sep_total = b.mul(sep_len, sep_count, name="jn.septotal");
    grand_total = b.add(total_phi, sep_total, name="jn.grand");
    alloc_sz = b.add(grand_total, one, name="jn.alloc");
    p._set_rc_ctx("join", "");
    buf = p._str_alloc(b, alloc_sz, name="jn.buf");
    p._clear_rc_ctx();

    entry_p2 = b.basic_block;
    loop2_bb = func.append_basic_block(name="jn.cp.loop");
    body2_bb = func.append_basic_block(name="jn.cp.body");
    sep_check = func.append_basic_block(name="jn.cp.sep");
    sep_copy = func.append_basic_block(name="jn.cp.sepcopy");
    next_iter = func.append_basic_block(name="jn.cp.next");
    copy_done = func.append_basic_block(name="jn.cp.done");
    b.branch(loop2_bb);
    b.position_at_start(loop2_bb);
    p2_idx = b.phi(i64, name="jn.p2.idx");
    p2_off = b.phi(i64, name="jn.p2.off");
    p2_idx.add_incoming(zero, entry_p2);
    p2_off.add_incoming(zero, entry_p2);
    p2_end = b.icmp_unsigned(">=", p2_idx, list_len, name="jn.p2.end");
    b.cbranch(p2_end, copy_done, body2_bb);
    b.position_at_start(body2_bb);
    elem2 = b.call(lhelpers["get"], [the_list, p2_idx], name="jn.p2.elem");
    elen2 = p._call_str_len(b, elem2, name="jn.p2.elen");
    dst2 = b.gep(buf, [p2_off], name="jn.p2.dst");
    b.call(memcpy_fn, [dst2, elem2, elen2]);
    off_after_elem = b.add(p2_off, elen2, name="jn.p2.off2");
    b.branch(sep_check);

    b.position_at_start(sep_check);
    next_p2 = b.add(p2_idx, one, name="jn.p2.next");
    is_last = b.icmp_unsigned(">=", next_p2, list_len, name="jn.p2.islast");
    b.cbranch(is_last, next_iter, sep_copy);
    b.position_at_start(sep_copy);
    sep_dst = b.gep(buf, [off_after_elem], name="jn.p2.sepdst");
    b.call(memcpy_fn, [sep_dst, target, sep_len]);
    off_after_sep = b.add(off_after_elem, sep_len, name="jn.p2.off3");
    b.branch(next_iter);

    b.position_at_start(next_iter);
    merged_off = b.phi(i64, name="jn.p2.moff");
    merged_off.add_incoming(off_after_elem, sep_check);
    merged_off.add_incoming(off_after_sep, sep_copy);
    p2_idx.add_incoming(next_p2, next_iter);
    p2_off.add_incoming(merged_off, next_iter);
    b.branch(loop2_bb);

    b.position_at_start(copy_done);
    final_off = b.phi(i64, name="jn.final.off");
    final_off.add_incoming(p2_off, loop2_bb);
    p._str_finish(b, buf, final_off);
    b.branch(done_bb);

    b.position_at_start(done_bb);
    result = b.phi(i8p, name="jn.result");
    result.add_incoming(empty_buf, empty_bb);
    result.add_incoming(buf, copy_done);
    return result;
}

impl NativeStrEmitter.emit_partition(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    sep_val = args[0];
    strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    p._emit_list_helpers("ptr", i8p);
    lh = p.list_helpers.get("ptr");
    if lh is None {
        return None;
    }
    result_list = b.call(lh["new"], [], name="part.list");
    sep_len = p._call_str_len(b, sep_val, name="part.seplen");
    str_len = p._call_str_len(b, target, name="part.strlen");
    found_ptr = b.call(strstr_fn, [target, sep_val], name="part.found");
    null_i8p = ir.Constant(i8p, None);
    is_found = b.icmp_unsigned("!=", found_ptr, null_i8p, name="part.isfound");
    func = b.basic_block.function;
    found_bb = func.append_basic_block(name="part.yes");
    notfound_bb = func.append_basic_block(name="part.no");
    merge_bb = func.append_basic_block(name="part.merge");
    b.cbranch(is_found, found_bb, notfound_bb);

    b.position_at_start(found_bb);
    base_int = b.ptrtoint(target, i64, name="part.base");
    found_int = b.ptrtoint(found_ptr, i64, name="part.fint");
    before_len = b.sub(found_int, base_int, name="part.blen");
    before_alloc = b.add(before_len, ir.Constant(i64, 1), name="part.balloc");
    before_ptr = p._str_alloc(b, before_alloc, name="part.before");
    b.call(memcpy_fn, [before_ptr, target, before_len]);
    p._str_finish(b, before_ptr, before_len);
    after_off = b.add(before_len, sep_len, name="part.aoff");
    after_len = b.sub(str_len, after_off, name="part.alen");
    after_alloc = b.add(after_len, ir.Constant(i64, 1), name="part.aalloc");
    after_ptr = p._str_alloc(b, after_alloc, name="part.after");
    after_src = b.gep(target, [after_off], name="part.asrc");
    b.call(memcpy_fn, [after_ptr, after_src, after_len]);
    p._str_finish(b, after_ptr, after_len);
    b.call(lh["append"], [result_list, before_ptr]);
    b.call(lh["append"], [result_list, sep_val]);
    b.call(lh["append"], [result_list, after_ptr]);
    b.branch(merge_bb);

    b.position_at_start(notfound_bb);
    empty1 = p._str_alloc(b, ir.Constant(i64, 1), name="part.e1");
    p._str_finish(b, empty1, ir.Constant(i64, 0));
    empty2 = p._str_alloc(b, ir.Constant(i64, 1), name="part.e2");
    p._str_finish(b, empty2, ir.Constant(i64, 0));
    b.call(lh["append"], [result_list, target]);
    b.call(lh["append"], [result_list, empty1]);
    b.call(lh["append"], [result_list, empty2]);
    b.branch(merge_bb);
    b.position_at_start(merge_bb);
    return result_list;
}

impl NativeStrEmitter.emit_rpartition(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    sep_val = args[0];
    strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    p._emit_list_helpers("ptr", i8p);
    lh = p.list_helpers.get("ptr");
    if lh is None {
        return None;
    }
    result_list = b.call(lh["new"], [], name="rpart.list");
    sep_len = p._call_str_len(b, sep_val, name="rpart.seplen");
    str_len = p._call_str_len(b, target, name="rpart.strlen");

    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="rpart.loop");
    body_bb = func.append_basic_block(name="rpart.body");
    done_bb = func.append_basic_block(name="rpart.done");
    found_bb = func.append_basic_block(name="rpart.yes");
    notfound_bb = func.append_basic_block(name="rpart.no");
    merge_bb = func.append_basic_block(name="rpart.merge");

    last_match_alloca = b.alloca(i8p, name="rpart.last");
    b.store(ir.Constant(i8p, None), last_match_alloca);
    cur_alloca = b.alloca(i8p, name="rpart.cur");
    b.store(target, cur_alloca);
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    cur_ptr = b.load(cur_alloca, name="rpart.curp");
    found_ptr = b.call(strstr_fn, [cur_ptr, sep_val], name="rpart.found");
    null_i8p = ir.Constant(i8p, None);
    is_found = b.icmp_unsigned("!=", found_ptr, null_i8p, name="rpart.isf");
    b.cbranch(is_found, body_bb, done_bb);
    b.position_at_start(body_bb);
    b.store(found_ptr, last_match_alloca);
    next_ptr = b.gep(found_ptr, [ir.Constant(i64, 1)], name="rpart.next");
    b.store(next_ptr, cur_alloca);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    last_match = b.load(last_match_alloca, name="rpart.last.v");
    is_any = b.icmp_unsigned("!=", last_match, null_i8p, name="rpart.isany");
    b.cbranch(is_any, found_bb, notfound_bb);

    b.position_at_start(found_bb);
    base_int = b.ptrtoint(target, i64, name="rpart.base");
    last_int = b.ptrtoint(last_match, i64, name="rpart.lint");
    before_len = b.sub(last_int, base_int, name="rpart.blen");
    before_alloc = b.add(before_len, ir.Constant(i64, 1), name="rpart.balloc");
    before_ptr = p._str_alloc(b, before_alloc, name="rpart.before");
    b.call(memcpy_fn, [before_ptr, target, before_len]);
    p._str_finish(b, before_ptr, before_len);
    after_off = b.add(before_len, sep_len, name="rpart.aoff");
    after_len = b.sub(str_len, after_off, name="rpart.alen");
    after_alloc = b.add(after_len, ir.Constant(i64, 1), name="rpart.aalloc");
    after_ptr = p._str_alloc(b, after_alloc, name="rpart.after");
    after_src = b.gep(target, [after_off], name="rpart.asrc");
    b.call(memcpy_fn, [after_ptr, after_src, after_len]);
    p._str_finish(b, after_ptr, after_len);
    b.call(lh["append"], [result_list, before_ptr]);
    b.call(lh["append"], [result_list, sep_val]);
    b.call(lh["append"], [result_list, after_ptr]);
    b.branch(merge_bb);

    b.position_at_start(notfound_bb);
    empty1 = p._str_alloc(b, ir.Constant(i64, 1), name="rpart.e1");
    p._str_finish(b, empty1, ir.Constant(i64, 0));
    empty2 = p._str_alloc(b, ir.Constant(i64, 1), name="rpart.e2");
    p._str_finish(b, empty2, ir.Constant(i64, 0));
    b.call(lh["append"], [result_list, empty1]);
    b.call(lh["append"], [result_list, empty2]);
    b.call(lh["append"], [result_list, target]);
    b.branch(merge_bb);
    b.position_at_start(merge_bb);
    return result_list;
}

impl NativeStrEmitter.emit_format(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return target;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    snprintf_fn = p._get_or_declare_extern(
        "snprintf", i32, [i8p, i64, i8p], var_arg=True
    );
    placeholder = p._make_global_string("{}");
    ph_len = ir.Constant(i64, 2);
    null_ptr = ir.Constant(i8p, None);

    str_args: list[ir.Value] = [];
    for arg in args {
        if isinstance(arg.type, ir.IntType) and arg.type.width > 1 {
            buf = p._str_alloc(b, ir.Constant(i64, 32), name="fmt.ibuf");
            fmt_s = p._make_global_string("%ld");
            ibuf_n32 = b.call(
                snprintf_fn, [buf, ir.Constant(i64, 32), fmt_s, arg], name="fmt.ibuf.n"
            );
            p._str_finish(b, buf, b.sext(ibuf_n32, i64, name="fmt.ibuf.n64"));
            str_args.append(buf);
        } elif isinstance(arg.type, ir.DoubleType) {
            str_args.append(p._emit_float_repr(arg));
        } else {
            str_args.append(arg);
        }
    }

    current = target;
    for i in range(len(str_args)) {
        arg_str = str_args[i];
        arg_len = p._call_str_len(b, arg_str, name=f"fmt.a{i}.len");
        cur_len = p._call_str_len(b, current, name=f"fmt.c{i}.len");

        alloc_sz = b.add(
            b.sub(cur_len, ph_len, name=f"fmt.sub{i}"),
            b.add(arg_len, ir.Constant(i64, 1), name=f"fmt.aln{i}"),
            name=f"fmt.alloc{i}"
        );
        result = p._str_alloc(b, alloc_sz, name=f"fmt.res{i}");

        found = b.call(strstr_fn, [current, placeholder], name=f"fmt.fnd{i}");
        is_null = b.icmp_unsigned("==", found, null_ptr, name=f"fmt.null{i}");
        func = b.basic_block.function;
        replace_bb = func.append_basic_block(name=f"fmt.repl{i}");
        skip_bb = func.append_basic_block(name=f"fmt.skip{i}");
        merge_bb = func.append_basic_block(name=f"fmt.merge{i}");
        b.cbranch(is_null, skip_bb, replace_bb);

        b.position_at_start(replace_bb);
        cur_int = b.ptrtoint(current, i64, name=f"fmt.ci{i}");
        fnd_int = b.ptrtoint(found, i64, name=f"fmt.fi{i}");
        pfx_len = b.sub(fnd_int, cur_int, name=f"fmt.pfx{i}");
        b.call(memcpy_fn, [result, current, pfx_len]);
        dst2 = b.gep(result, [pfx_len], name=f"fmt.d2.{i}");
        b.call(memcpy_fn, [dst2, arg_str, arg_len]);
        dst3_off = b.add(pfx_len, arg_len, name=f"fmt.d3o{i}");
        dst3 = b.gep(result, [dst3_off], name=f"fmt.d3.{i}");
        sfx_start_int = b.add(fnd_int, ph_len, name=f"fmt.sfxi{i}");
        sfx_start = b.inttoptr(sfx_start_int, i8p, name=f"fmt.sfx{i}");
        sfx_len = p._call_str_len_raw(b, sfx_start, name=f"fmt.slen{i}");
        b.call(memcpy_fn, [dst3, sfx_start, sfx_len]);
        total_len = b.add(dst3_off, sfx_len, name=f"fmt.tlen{i}");
        p._str_finish(b, result, total_len);
        b.branch(merge_bb);

        b.position_at_start(skip_bb);

        b.call(memcpy_fn, [result, current, cur_len]);
        p._str_finish(b, result, cur_len);
        b.branch(merge_bb);
        b.position_at_start(merge_bb);
        current = result;
    }
    return current;
}

impl NativeStrEmitter.emit_format_map(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeStrEmitter.emit_center(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    memset_fn = p._get_or_declare_extern("memset", i8p, [i8p, ir.IntType(32), i64]);
    slen = p._call_str_len(b, target, name="center.len");
    width = args[0];
    needs_pad = b.icmp_unsigned("<", slen, width, name="center.needspad");
    func = b.basic_block.function;
    pad_bb = func.append_basic_block(name="center.pad");
    nopad_bb = func.append_basic_block(name="center.nopad");
    done_bb = func.append_basic_block(name="center.done");
    b.cbranch(needs_pad, pad_bb, nopad_bb);

    b.position_at_start(pad_bb);
    total_pad = b.sub(width, slen, name="center.totalpad");
    half = b.udiv(total_pad, ir.Constant(i64, 2), name="center.half");
    tp_and_w = b.and_(total_pad, width, name="center.tpw");
    adj = b.and_(tp_and_w, ir.Constant(i64, 1), name="center.adj");
    left_pad = b.add(half, adj, name="center.lpad");
    right_pad = b.sub(total_pad, left_pad, name="center.rpad");
    alloc_pad = b.add(width, ir.Constant(i64, 1), name="center.alloc");
    buf_pad = p._str_alloc(b, alloc_pad, name="center.buf");

    b.call(memset_fn, [buf_pad, ir.Constant(ir.IntType(32), 32), left_pad]);

    str_ptr = b.gep(buf_pad, [left_pad], name="center.str.ptr");
    b.call(memcpy_fn, [str_ptr, target, slen]);

    right_ptr = b.gep(str_ptr, [slen], name="center.rpad.ptr");
    b.call(memset_fn, [right_ptr, ir.Constant(ir.IntType(32), 32), right_pad]);

    p._str_finish(b, buf_pad, width);
    b.branch(done_bb);

    b.position_at_start(nopad_bb);
    alloc_nopad = b.add(slen, ir.Constant(i64, 1), name="center.alloc.np");
    buf_nopad = p._str_alloc(b, alloc_nopad, name="center.buf.np");
    b.call(memcpy_fn, [buf_nopad, target, slen]);
    p._str_finish(b, buf_nopad, slen);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result = b.phi(i8p, name="center.result");
    result.add_incoming(buf_pad, pad_bb);
    result.add_incoming(buf_nopad, nopad_bb);
    return result;
}

impl NativeStrEmitter.emit_ljust(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    memset_fn = p._get_or_declare_extern("memset", i8p, [i8p, ir.IntType(32), i64]);
    slen = p._call_str_len(b, target, name="ljust.len");
    width = args[0];
    needs_pad = b.icmp_unsigned("<", slen, width, name="ljust.needspad");
    func = b.basic_block.function;
    pad_bb = func.append_basic_block(name="ljust.pad");
    nopad_bb = func.append_basic_block(name="ljust.nopad");
    done_bb = func.append_basic_block(name="ljust.done");
    b.cbranch(needs_pad, pad_bb, nopad_bb);

    b.position_at_start(pad_bb);
    alloc_pad = b.add(width, ir.Constant(i64, 1), name="ljust.alloc");
    buf_pad = p._str_alloc(b, alloc_pad, name="ljust.buf");
    b.call(memcpy_fn, [buf_pad, target, slen]);
    pad_ptr = b.gep(buf_pad, [slen], name="ljust.pad.ptr");
    pad_len = b.sub(width, slen, name="ljust.pad.len");
    b.call(memset_fn, [pad_ptr, ir.Constant(ir.IntType(32), 32), pad_len]);
    p._str_finish(b, buf_pad, width);
    b.branch(done_bb);

    b.position_at_start(nopad_bb);
    alloc_nopad = b.add(slen, ir.Constant(i64, 1), name="ljust.alloc.np");
    buf_nopad = p._str_alloc(b, alloc_nopad, name="ljust.buf.np");
    b.call(memcpy_fn, [buf_nopad, target, slen]);
    p._str_finish(b, buf_nopad, slen);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result = b.phi(i8p, name="ljust.result");
    result.add_incoming(buf_pad, pad_bb);
    result.add_incoming(buf_nopad, nopad_bb);
    return result;
}

impl NativeStrEmitter.emit_rjust(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    memset_fn = p._get_or_declare_extern("memset", i8p, [i8p, ir.IntType(32), i64]);
    slen = p._call_str_len(b, target, name="rjust.len");
    width = args[0];
    needs_pad = b.icmp_unsigned("<", slen, width, name="rjust.needspad");
    func = b.basic_block.function;
    pad_bb = func.append_basic_block(name="rjust.pad");
    nopad_bb = func.append_basic_block(name="rjust.nopad");
    done_bb = func.append_basic_block(name="rjust.done");
    b.cbranch(needs_pad, pad_bb, nopad_bb);
    b.position_at_start(pad_bb);
    alloc_pad = b.add(width, ir.Constant(i64, 1), name="rjust.alloc");
    buf_pad = p._str_alloc(b, alloc_pad, name="rjust.buf");
    pad_len = b.sub(width, slen, name="rjust.pad.len");
    b.call(memset_fn, [buf_pad, ir.Constant(ir.IntType(32), 32), pad_len]);
    str_dst = b.gep(buf_pad, [pad_len], name="rjust.str.dst");
    b.call(memcpy_fn, [str_dst, target, slen]);
    p._str_finish(b, buf_pad, width);
    b.branch(done_bb);
    b.position_at_start(nopad_bb);
    alloc_nopad = b.add(slen, ir.Constant(i64, 1), name="rjust.alloc.np");
    buf_nopad = p._str_alloc(b, alloc_nopad, name="rjust.buf.np");
    b.call(memcpy_fn, [buf_nopad, target, slen]);
    p._str_finish(b, buf_nopad, slen);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result = b.phi(i8p, name="rjust.result");
    result.add_incoming(buf_pad, pad_bb);
    result.add_incoming(buf_nopad, nopad_bb);
    return result;
}

impl NativeStrEmitter.emit_zfill(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    memset_fn = p._get_or_declare_extern("memset", i8p, [i8p, ir.IntType(32), i64]);
    slen = p._call_str_len(b, target, name="zfill.len");
    width = args[0];
    needs_pad = b.icmp_unsigned("<", slen, width, name="zfill.needspad");
    func = b.basic_block.function;
    pad_bb = func.append_basic_block(name="zfill.pad");
    nopad_bb = func.append_basic_block(name="zfill.nopad");
    done_bb = func.append_basic_block(name="zfill.done");
    b.cbranch(needs_pad, pad_bb, nopad_bb);

    b.position_at_start(pad_bb);
    alloc_pad = b.add(width, ir.Constant(i64, 1), name="zfill.alloc");
    buf_pad = p._str_alloc(b, alloc_pad, name="zfill.buf");
    first_ch = b.load(target, name="zfill.first");
    is_plus = b.icmp_unsigned("==", first_ch, ir.Constant(i8, 43), name="zfill.plus");
    is_minus = b.icmp_unsigned("==", first_ch, ir.Constant(i8, 45), name="zfill.minus");
    has_sign = b.or_(is_plus, is_minus, name="zfill.hassign");
    pad_len = b.sub(width, slen, name="zfill.pad.len");

    sign_off = b.select(
        has_sign, ir.Constant(i64, 1), ir.Constant(i64, 0), name="zfill.soff"
    );

    sign_bb = func.append_basic_block(name="zfill.sign");
    nosign_bb = func.append_basic_block(name="zfill.nosign");
    merge_bb = func.append_basic_block(name="zfill.merge");
    b.cbranch(has_sign, sign_bb, nosign_bb);
    b.position_at_start(sign_bb);
    b.store(first_ch, buf_pad);
    b.call(
        memset_fn,
        [
            b.gep(buf_pad, [ir.Constant(i64, 1)], name="zfill.z1"),
            ir.Constant(ir.IntType(32), 48),
            pad_len
        ]
    );
    src_rest = b.gep(target, [ir.Constant(i64, 1)], name="zfill.src.rest");
    rest_len = b.sub(slen, ir.Constant(i64, 1), name="zfill.rest.len");
    dst_rest = b.gep(
        buf_pad,
        [b.add(pad_len, ir.Constant(i64, 1), name="zfill.doff")],
        name="zfill.dst.rest"
    );
    b.call(memcpy_fn, [dst_rest, src_rest, rest_len]);
    b.branch(merge_bb);
    b.position_at_start(nosign_bb);
    b.call(memset_fn, [buf_pad, ir.Constant(ir.IntType(32), 48), pad_len]);
    dst_nosign = b.gep(buf_pad, [pad_len], name="zfill.dst.ns");
    b.call(memcpy_fn, [dst_nosign, target, slen]);
    b.branch(merge_bb);
    b.position_at_start(merge_bb);
    p._str_finish(b, buf_pad, width);
    b.branch(done_bb);

    b.position_at_start(nopad_bb);
    alloc_nopad = b.add(slen, ir.Constant(i64, 1), name="zfill.alloc.np");
    buf_nopad = p._str_alloc(b, alloc_nopad, name="zfill.buf.np");
    b.call(memcpy_fn, [buf_nopad, target, slen]);
    p._str_finish(b, buf_nopad, slen);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result = b.phi(i8p, name="zfill.result");
    result.add_incoming(buf_pad, merge_bb);
    result.add_incoming(buf_nopad, nopad_bb);
    return result;
}

impl NativeStrEmitter.emit_expandtabs(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);
    slen = p._call_str_len(b, target, name="et.len");

    if args {
        tabsize = args[0];
    } else {
        tabsize = ir.Constant(i64, 8);
    }

    ts_or_one = b.select(
        b.icmp_unsigned("==", tabsize, zero), one, tabsize, name="et.ts1"
    );
    worst = b.mul(slen, ts_or_one, name="et.worst");
    alloc_sz = b.add(worst, one, name="et.alloc");
    buf = p._str_alloc(b, alloc_sz, name="et.buf");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="et.loop");
    check_tab = func.append_basic_block(name="et.check.tab");
    do_tab = func.append_basic_block(name="et.do.tab");
    tab_loop = func.append_basic_block(name="et.tab.loop");
    tab_write = func.append_basic_block(name="et.tab.write");
    tab_done = func.append_basic_block(name="et.tab.done");
    check_nl = func.append_basic_block(name="et.check.nl");
    do_nl = func.append_basic_block(name="et.do.nl");
    do_char = func.append_basic_block(name="et.do.char");
    next_bb = func.append_basic_block(name="et.next");
    done_bb = func.append_basic_block(name="et.done");
    b.branch(loop_bb);

    b.position_at_start(loop_bb);
    si = b.phi(i64, name="et.si");
    di = b.phi(i64, name="et.di");
    col = b.phi(i64, name="et.col");
    si.add_incoming(zero, entry_bb);
    di.add_incoming(zero, entry_bb);
    col.add_incoming(zero, entry_bb);

    cp = b.gep(target, [si], name="et.cp");
    ch = b.load(cp, name="et.ch");
    is_end = b.icmp_unsigned("==", ch, ir.Constant(i8, 0), name="et.end");
    b.cbranch(is_end, done_bb, check_tab);

    b.position_at_start(check_tab);
    is_tab = b.icmp_unsigned("==", ch, ir.Constant(i8, 9), name="et.istab");
    b.cbranch(is_tab, do_tab, check_nl);

    b.position_at_start(do_tab);
    is_ts_zero = b.icmp_unsigned("==", tabsize, zero, name="et.ts0");

    col_mod = b.urem(col, ts_or_one, name="et.colmod");
    spaces_calc = b.sub(tabsize, col_mod, name="et.spcalc");
    spaces = b.select(is_ts_zero, zero, spaces_calc, name="et.spaces");
    b.branch(tab_loop);

    b.position_at_start(tab_loop);
    ti = b.phi(i64, name="et.ti");
    di_t = b.phi(i64, name="et.di.t");
    ti.add_incoming(zero, do_tab);
    di_t.add_incoming(di, do_tab);
    ti_done = b.icmp_unsigned(">=", ti, spaces, name="et.tidone");
    b.cbranch(ti_done, tab_done, tab_write);

    b.position_at_start(tab_write);
    dp = b.gep(buf, [di_t], name="et.dp.tw");
    b.store(ir.Constant(i8, 32), dp);
    next_ti = b.add(ti, one, name="et.nti");
    next_di_t = b.add(di_t, one, name="et.ndi.t");
    ti.add_incoming(next_ti, tab_write);
    di_t.add_incoming(next_di_t, tab_write);
    b.branch(tab_loop);

    b.position_at_start(tab_done);
    new_col_tab = b.add(col, spaces, name="et.col.tab");
    next_si_tab = b.add(si, one, name="et.si.tab");
    b.branch(next_bb);

    b.position_at_start(check_nl);
    is_nl = b.icmp_unsigned("==", ch, ir.Constant(i8, 10), name="et.isnl");
    is_cr = b.icmp_unsigned("==", ch, ir.Constant(i8, 13), name="et.iscr");
    is_line_end = b.or_(is_nl, is_cr, name="et.isle");
    b.cbranch(is_line_end, do_nl, do_char);

    b.position_at_start(do_nl);
    dp_nl = b.gep(buf, [di], name="et.dp.nl");
    b.store(ch, dp_nl);
    next_di_nl = b.add(di, one, name="et.ndi.nl");
    next_si_nl = b.add(si, one, name="et.si.nl");
    b.branch(next_bb);

    b.position_at_start(do_char);
    dp_ch = b.gep(buf, [di], name="et.dp.ch");
    b.store(ch, dp_ch);
    next_di_ch = b.add(di, one, name="et.ndi.ch");
    next_col_ch = b.add(col, one, name="et.col.ch");
    next_si_ch = b.add(si, one, name="et.si.ch");
    b.branch(next_bb);

    b.position_at_start(next_bb);
    new_si = b.phi(i64, name="et.new.si");
    new_di = b.phi(i64, name="et.new.di");
    new_col = b.phi(i64, name="et.new.col");
    new_si.add_incoming(next_si_tab, tab_done);
    new_si.add_incoming(next_si_nl, do_nl);
    new_si.add_incoming(next_si_ch, do_char);
    new_di.add_incoming(di_t, tab_done);
    new_di.add_incoming(next_di_nl, do_nl);
    new_di.add_incoming(next_di_ch, do_char);
    new_col.add_incoming(new_col_tab, tab_done);
    new_col.add_incoming(zero, do_nl);
    new_col.add_incoming(next_col_ch, do_char);
    b.branch(loop_bb);
    si.add_incoming(new_si, next_bb);
    di.add_incoming(new_di, next_bb);
    col.add_incoming(new_col, next_bb);

    b.position_at_start(done_bb);
    done_di = b.phi(i64, name="et.done.di");
    done_di.add_incoming(di, loop_bb);
    p._str_finish(b, buf, done_di);
    return buf;
}

impl NativeStrEmitter._emit_char_test(
    self: NativeStrEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    cfunc_name: str,
    prefix: str,
    empty_is_true: bool = False
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    test_fn = p._get_or_declare_extern(cfunc_name, i32, [i32]);
    slen = p._call_str_len(b, target, name=f"{prefix}.len");
    is_empty = b.icmp_unsigned("==", slen, ir.Constant(i64, 0), name=f"{prefix}.empty");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name=f"{prefix}.loop");
    body_bb = func.append_basic_block(name=f"{prefix}.body");
    fail_bb = func.append_basic_block(name=f"{prefix}.fail");
    pass_bb = func.append_basic_block(name=f"{prefix}.pass");
    done_bb = func.append_basic_block(name=f"{prefix}.done");
    if empty_is_true {
        b.cbranch(is_empty, pass_bb, loop_bb);
    } else {
        b.cbranch(is_empty, fail_bb, loop_bb);
    }
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name=f"{prefix}.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, slen, name=f"{prefix}.atend");
    b.cbranch(at_end, pass_bb, body_bb);
    b.position_at_start(body_bb);
    ch_ptr = b.gep(target, [idx], name=f"{prefix}.ch.ptr");
    ch = b.load(ch_ptr, name=f"{prefix}.ch");
    ch_i32 = b.zext(ch, i32, name=f"{prefix}.ch.i32");
    result = b.call(test_fn, [ch_i32], name=f"{prefix}.test");
    is_ok = b.icmp_signed("!=", result, ir.Constant(i32, 0), name=f"{prefix}.ok");
    next_idx = b.add(idx, ir.Constant(i64, 1), name=f"{prefix}.next");
    idx.add_incoming(next_idx, body_bb);
    b.cbranch(is_ok, loop_bb, fail_bb);
    b.position_at_start(fail_bb);
    b.branch(done_bb);
    b.position_at_start(pass_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result_phi = b.phi(i64, name=f"{prefix}.final");
    result_phi.add_incoming(ir.Constant(i64, 0), fail_bb);
    result_phi.add_incoming(ir.Constant(i64, 1), pass_bb);
    return result_phi;
}

impl NativeStrEmitter.emit_isalnum(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_char_test(ctx, target, "isalnum", "isalnum");
}

impl NativeStrEmitter.emit_isalpha(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_char_test(ctx, target, "isalpha", "isalpha");
}

impl NativeStrEmitter.emit_isascii(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    slen = p._call_str_len(b, target, name="isascii.len");
    is_empty = b.icmp_unsigned("==", slen, ir.Constant(i64, 0), name="isascii.empty");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="isascii.loop");
    body_bb = func.append_basic_block(name="isascii.body");
    fail_bb = func.append_basic_block(name="isascii.fail");
    pass_bb = func.append_basic_block(name="isascii.pass");
    done_bb = func.append_basic_block(name="isascii.done");
    b.cbranch(is_empty, pass_bb, loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="isascii.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, slen, name="isascii.atend");
    b.cbranch(at_end, pass_bb, body_bb);
    b.position_at_start(body_bb);
    ch_ptr = b.gep(target, [idx], name="isascii.ch.ptr");
    ch = b.load(ch_ptr, name="isascii.ch");
    ch_ext = b.zext(ch, i64, name="isascii.ch.ext");
    is_ok = b.icmp_unsigned("<", ch_ext, ir.Constant(i64, 128), name="isascii.ok");
    next_idx = b.add(idx, ir.Constant(i64, 1), name="isascii.next");
    idx.add_incoming(next_idx, body_bb);
    b.cbranch(is_ok, loop_bb, fail_bb);
    b.position_at_start(fail_bb);
    b.branch(done_bb);
    b.position_at_start(pass_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result_phi = b.phi(i64, name="isascii.final");
    result_phi.add_incoming(ir.Constant(i64, 0), fail_bb);
    result_phi.add_incoming(ir.Constant(i64, 1), pass_bb);
    return result_phi;
}

impl NativeStrEmitter.emit_isdecimal(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_char_test(ctx, target, "isdigit", "isdecimal");
}

impl NativeStrEmitter.emit_isdigit(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_char_test(ctx, target, "isdigit", "isdigit");
}

impl NativeStrEmitter.emit_isidentifier(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    isalpha_fn = p._get_or_declare_extern("isalpha", i32, [i32]);
    isalnum_fn = p._get_or_declare_extern("isalnum", i32, [i32]);
    slen = p._call_str_len(b, target, name="isid.len");
    is_empty = b.icmp_unsigned("==", slen, ir.Constant(i64, 0), name="isid.empty");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    first_bb = func.append_basic_block(name="isid.first");
    loop_bb = func.append_basic_block(name="isid.loop");
    body_bb = func.append_basic_block(name="isid.body");
    fail_bb = func.append_basic_block(name="isid.fail");
    pass_bb = func.append_basic_block(name="isid.pass");
    done_bb = func.append_basic_block(name="isid.done");
    b.cbranch(is_empty, fail_bb, first_bb);

    b.position_at_start(first_bb);
    first_ch = b.load(target, name="isid.first.ch");
    first_i32 = b.zext(first_ch, i32, name="isid.first.i32");
    is_alpha = b.call(isalpha_fn, [first_i32], name="isid.first.alpha");
    is_alpha_ok = b.icmp_signed(
        "!=", is_alpha, ir.Constant(i32, 0), name="isid.first.aok"
    );
    is_underscore = b.icmp_unsigned(
        "==", first_ch, ir.Constant(i8, 95), name="isid.first.under"
    );
    first_ok = b.or_(is_alpha_ok, is_underscore, name="isid.first.ok");
    b.cbranch(first_ok, loop_bb, fail_bb);

    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="isid.idx");
    idx.add_incoming(ir.Constant(i64, 1), first_bb);
    at_end = b.icmp_unsigned(">=", idx, slen, name="isid.atend");
    b.cbranch(at_end, pass_bb, body_bb);
    b.position_at_start(body_bb);
    ch_ptr = b.gep(target, [idx], name="isid.ch.ptr");
    ch = b.load(ch_ptr, name="isid.ch");
    ch_i32 = b.zext(ch, i32, name="isid.ch.i32");
    is_an = b.call(isalnum_fn, [ch_i32], name="isid.isalnum");
    is_an_ok = b.icmp_signed("!=", is_an, ir.Constant(i32, 0), name="isid.an.ok");
    is_under = b.icmp_unsigned("==", ch, ir.Constant(i8, 95), name="isid.under");
    ch_ok = b.or_(is_an_ok, is_under, name="isid.ch.ok");
    next_idx = b.add(idx, ir.Constant(i64, 1), name="isid.next");
    idx.add_incoming(next_idx, body_bb);
    b.cbranch(ch_ok, loop_bb, fail_bb);
    b.position_at_start(fail_bb);
    b.branch(done_bb);
    b.position_at_start(pass_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result_phi = b.phi(i64, name="isid.final");
    result_phi.add_incoming(ir.Constant(i64, 0), fail_bb);
    result_phi.add_incoming(ir.Constant(i64, 1), pass_bb);
    return result_phi;
}

impl NativeStrEmitter.emit_islower(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    isupper_fn = p._get_or_declare_extern("isupper", i32, [i32]);
    isalpha_fn = p._get_or_declare_extern("isalpha", i32, [i32]);
    slen = p._call_str_len(b, target, name="islower.len");
    is_empty = b.icmp_unsigned("==", slen, ir.Constant(i64, 0), name="islower.empty");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="islower.loop");
    body_bb = func.append_basic_block(name="islower.body");
    fail_bb = func.append_basic_block(name="islower.fail");
    check_bb = func.append_basic_block(name="islower.check");
    done_bb = func.append_basic_block(name="islower.done");
    b.cbranch(is_empty, fail_bb, loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="islower.idx");
    has_cased = b.phi(i64, name="islower.hascased");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    has_cased.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, slen, name="islower.atend");
    b.cbranch(at_end, check_bb, body_bb);
    b.position_at_start(body_bb);
    ch_ptr = b.gep(target, [idx], name="islower.ch.ptr");
    ch = b.load(ch_ptr, name="islower.ch");
    ch_i32 = b.zext(ch, i32, name="islower.ch.i32");
    is_upper = b.call(isupper_fn, [ch_i32], name="islower.isupper");
    is_upper_bool = b.icmp_signed(
        "!=", is_upper, ir.Constant(i32, 0), name="islower.isup"
    );
    next_idx = b.add(idx, ir.Constant(i64, 1), name="islower.next");
    is_alpha = b.call(isalpha_fn, [ch_i32], name="islower.isalpha");
    is_alpha_bool = b.icmp_signed(
        "!=", is_alpha, ir.Constant(i32, 0), name="islower.isalp"
    );
    new_cased = b.select(
        is_alpha_bool, ir.Constant(i64, 1), has_cased, name="islower.newcased"
    );
    idx.add_incoming(next_idx, body_bb);
    has_cased.add_incoming(new_cased, body_bb);
    b.cbranch(is_upper_bool, fail_bb, loop_bb);
    b.position_at_start(check_bb);
    has_any = b.icmp_unsigned(
        "!=", has_cased, ir.Constant(i64, 0), name="islower.hasany"
    );
    b.cbranch(has_any, done_bb, fail_bb);
    b.position_at_start(fail_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result_phi = b.phi(i64, name="islower.final");
    result_phi.add_incoming(ir.Constant(i64, 1), check_bb);
    result_phi.add_incoming(ir.Constant(i64, 0), fail_bb);
    return result_phi;
}

impl NativeStrEmitter.emit_isnumeric(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_char_test(ctx, target, "isdigit", "isnumeric");
}

impl NativeStrEmitter.emit_isprintable(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_char_test(
        ctx, target, "isprint", "isprintable", empty_is_true=True
    );
}

impl NativeStrEmitter.emit_isspace(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_char_test(ctx, target, "isspace", "isspace");
}

impl NativeStrEmitter.emit_istitle(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    isupper_fn = p._get_or_declare_extern("isupper", i32, [i32]);
    islower_fn = p._get_or_declare_extern("islower", i32, [i32]);
    isalpha_fn = p._get_or_declare_extern("isalpha", i32, [i32]);
    slen = p._call_str_len(b, target, name="istitle.len");
    is_empty = b.icmp_unsigned("==", slen, ir.Constant(i64, 0), name="istitle.empty");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="istitle.loop");
    body_bb = func.append_basic_block(name="istitle.body");
    fail_bb = func.append_basic_block(name="istitle.fail");
    check_bb = func.append_basic_block(name="istitle.check");
    done_bb = func.append_basic_block(name="istitle.done");
    b.cbranch(is_empty, fail_bb, loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="istitle.idx");
    prev_cased = b.phi(i64, name="istitle.prevcased");
    has_cased = b.phi(i64, name="istitle.hascased");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    prev_cased.add_incoming(ir.Constant(i64, 0), entry_bb);
    has_cased.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, slen, name="istitle.atend");
    b.cbranch(at_end, check_bb, body_bb);
    b.position_at_start(body_bb);
    ch_ptr = b.gep(target, [idx], name="istitle.ch.ptr");
    ch = b.load(ch_ptr, name="istitle.ch");
    ch_i32 = b.zext(ch, i32, name="istitle.ch.i32");
    is_up = b.call(isupper_fn, [ch_i32], name="istitle.isup");
    is_up_bool = b.icmp_signed("!=", is_up, ir.Constant(i32, 0), name="istitle.upbool");
    is_lo = b.call(islower_fn, [ch_i32], name="istitle.islo");
    is_lo_bool = b.icmp_signed("!=", is_lo, ir.Constant(i32, 0), name="istitle.lobool");
    is_al = b.call(isalpha_fn, [ch_i32], name="istitle.isal");
    is_al_bool = b.icmp_signed("!=", is_al, ir.Constant(i32, 0), name="istitle.albool");
    prev_was_cased = b.icmp_unsigned(
        "!=", prev_cased, ir.Constant(i64, 0), name="istitle.pwc"
    );
    upper_after_cased = b.and_(is_up_bool, prev_was_cased, name="istitle.uac");
    not_prev_cased = b.not_(prev_was_cased, name="istitle.npc");
    lower_after_noncased = b.and_(is_lo_bool, not_prev_cased, name="istitle.lanc");
    bad = b.or_(upper_after_cased, lower_after_noncased, name="istitle.bad");
    next_idx = b.add(idx, ir.Constant(i64, 1), name="istitle.next");
    new_prev = b.select(
        is_al_bool, ir.Constant(i64, 1), ir.Constant(i64, 0), name="istitle.newprev"
    );
    new_has = b.select(
        is_al_bool, ir.Constant(i64, 1), has_cased, name="istitle.newhas"
    );
    idx.add_incoming(next_idx, body_bb);
    prev_cased.add_incoming(new_prev, body_bb);
    has_cased.add_incoming(new_has, body_bb);
    b.cbranch(bad, fail_bb, loop_bb);
    b.position_at_start(check_bb);
    has_any = b.icmp_unsigned(
        "!=", has_cased, ir.Constant(i64, 0), name="istitle.hasany"
    );
    b.cbranch(has_any, done_bb, fail_bb);
    b.position_at_start(fail_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result_phi = b.phi(i64, name="istitle.final");
    result_phi.add_incoming(ir.Constant(i64, 1), check_bb);
    result_phi.add_incoming(ir.Constant(i64, 0), fail_bb);
    return result_phi;
}

impl NativeStrEmitter.emit_isupper(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    islower_fn = p._get_or_declare_extern("islower", i32, [i32]);
    isalpha_fn = p._get_or_declare_extern("isalpha", i32, [i32]);
    slen = p._call_str_len(b, target, name="isupper.len");
    is_empty = b.icmp_unsigned("==", slen, ir.Constant(i64, 0), name="isupper.empty");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="isupper.loop");
    body_bb = func.append_basic_block(name="isupper.body");
    fail_bb = func.append_basic_block(name="isupper.fail");
    check_bb = func.append_basic_block(name="isupper.check");
    done_bb = func.append_basic_block(name="isupper.done");
    b.cbranch(is_empty, fail_bb, loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="isupper.idx");
    has_cased = b.phi(i64, name="isupper.hascased");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    has_cased.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, slen, name="isupper.atend");
    b.cbranch(at_end, check_bb, body_bb);
    b.position_at_start(body_bb);
    ch_ptr = b.gep(target, [idx], name="isupper.ch.ptr");
    ch = b.load(ch_ptr, name="isupper.ch");
    ch_i32 = b.zext(ch, i32, name="isupper.ch.i32");
    is_low = b.call(islower_fn, [ch_i32], name="isupper.islow");
    is_low_bool = b.icmp_signed("!=", is_low, ir.Constant(i32, 0), name="isupper.islo");
    next_idx = b.add(idx, ir.Constant(i64, 1), name="isupper.next");
    is_alpha = b.call(isalpha_fn, [ch_i32], name="isupper.isalpha");
    is_alpha_bool = b.icmp_signed(
        "!=", is_alpha, ir.Constant(i32, 0), name="isupper.isalp"
    );
    new_cased = b.select(
        is_alpha_bool, ir.Constant(i64, 1), has_cased, name="isupper.newcased"
    );
    idx.add_incoming(next_idx, body_bb);
    has_cased.add_incoming(new_cased, body_bb);
    b.cbranch(is_low_bool, fail_bb, loop_bb);
    b.position_at_start(check_bb);
    has_any = b.icmp_unsigned(
        "!=", has_cased, ir.Constant(i64, 0), name="isupper.hasany"
    );
    b.cbranch(has_any, done_bb, fail_bb);
    b.position_at_start(fail_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result_phi = b.phi(i64, name="isupper.final");
    result_phi.add_incoming(ir.Constant(i64, 1), check_bb);
    result_phi.add_incoming(ir.Constant(i64, 0), fail_bb);
    return result_phi;
}

impl NativeStrEmitter.emit_encode(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    n = p._call_str_len(b, target, name="enc.len");
    return p._bytes_from_raw(target, n);
}

impl NativeStrEmitter.emit_decode(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return target;
}

impl NativeStrEmitter.emit_translate(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeStrEmitter.emit_maketrans(
    self: NativeStrEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_decode(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    n = p._bytes_len_val(target);
    alloc_sz = b.add(n, ir.Constant(i64, 1), name="dec.alloc");
    p._set_rc_ctx("bytes_decode", "");
    new_str = p._str_alloc(b, alloc_sz, name="dec.str");
    p._clear_rc_ctx();
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    b.call(memcpy_fn, [new_str, p._bytes_data_ptr(target), n]);
    dec_end = b.gep(new_str, [n], name="dec.end");
    b.store(ir.Constant(ir.IntType(8), 0), dec_end);

    p._stamp_str_len(b, new_str, p._call_str_len_raw(b, new_str, name="dec.len"));
    p._mark_owned(new_str);
    return new_str;
}

impl NativeBytesEmitter.emit_hex(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_fromhex(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_count(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_find(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_rfind(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_index(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_rindex(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_startswith(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_endswith(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_replace(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_strip(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_lstrip(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_rstrip(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_removeprefix(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_removesuffix(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_split(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_rsplit(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_splitlines(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_join(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_partition(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_rpartition(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_capitalize(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_lower(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_upper(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_title(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_swapcase(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_isalnum(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_isalpha(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_isascii(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_isdigit(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_islower(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_isspace(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_istitle(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_isupper(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_center(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_ljust(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_rjust(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_zfill(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_expandtabs(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_translate(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_maketrans(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeListEmitter.emit_append(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None or not args {
        return None;
    }

    _boxed_val = p._box_value_tuple(p._wrap_fn_as_closure_value(args[0]));
    if p._reject_ptr_into_raw_slot(
        None, _boxed_val, helpers["elem_type"], "list append"
    ) {
        return ir.Constant(ir.IntType(64), 0);
    }
    val = p._coerce_type(_boxed_val, helpers["elem_type"]);

    _append_loc = getattr(args[0], 'jac_loc', "");
    p._rc_call_with_ctx(helpers["append"], [target, val], op="append", loc=_append_loc);

    if isinstance(_boxed_val.type, ir.PointerType)
        and p._is_owned(_boxed_val)
        and not p._nogc_headerless() {
        p._emit_rc_release_simple(_boxed_val, op="append", loc=_append_loc);
    }
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeListEmitter.emit_extend(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    src = args[0];
    if p._opt_payload_of(src.type) is not None {
        src = p._coerce_type(src, target.type);
    }
    if not isinstance(src.type, ir.PointerType) or src.type.is_opaque {
        return None;
    }
    if not isinstance(src.type.pointee, ir.BaseStructType) {
        src = p._coerce_type(src, target.type);
        if not isinstance(src.type, ir.PointerType)
            or src.type.is_opaque
            or not isinstance(src.type.pointee, ir.BaseStructType) {
            return None;
        }
    }
    src_len_ptr = b.gep(
        src, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ext.src.len.ptr"
    );
    src_len = b.load(src_len_ptr, name="ext.src.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="ext.loop");
    body_bb = func.append_basic_block(name="ext.body");
    done_bb = func.append_basic_block(name="ext.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="ext.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, src_len, name="ext.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    src_helpers = helpers;
    if src.type != target.type {
        for (_sk, _sty) in p.list_types.items() {
            if src.type == _sty.as_pointer() {
                _sh = p.list_helpers.get(_sk);
                if _sh is not None {
                    src_helpers = _sh;
                }
                break;
            }
        }
    }
    elem = b.call(src_helpers["get"], [src, idx], name="ext.elem");
    if elem.type != helpers["elem_type"] {
        elem = p._coerce_type(elem, helpers["elem_type"]);
    }
    b.call(helpers["append"], [target, elem]);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="ext.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return ir.Constant(i64, 0);
}

impl NativeListEmitter.emit_insert(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if len(args) < 2 {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    insert_idx = args[0];
    _ins_orig = args[1];
    _ins_wrapped = p._wrap_fn_as_closure_value(_ins_orig);
    if p._reject_ptr_into_raw_slot(
        None, _ins_wrapped, helpers["elem_type"], "list insert"
    ) {
        return ir.Constant(i64, 0);
    }
    insert_val = p._coerce_type(_ins_wrapped, helpers["elem_type"]);

    b.call(helpers["append"], [target, insert_val]);

    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ins.len.ptr"
    );
    new_len = b.load(len_ptr, name="ins.newlen");
    last_idx = b.sub(new_len, ir.Constant(i64, 1), name="ins.last");

    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="ins.loop");
    body_bb = func.append_basic_block(name="ins.body");
    done_bb = func.append_basic_block(name="ins.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    si = b.phi(i64, name="ins.si");
    si.add_incoming(last_idx, entry_bb);
    at_pos = b.icmp_signed("<=", si, insert_idx, name="ins.atpos");
    b.cbranch(at_pos, done_bb, body_bb);
    b.position_at_start(body_bb);
    prev = b.sub(si, ir.Constant(i64, 1), name="ins.prev");
    prev_val = b.call(helpers["get"], [target, prev], name="ins.pval");
    b.call(helpers["set"], [target, si, prev_val]);
    si.add_incoming(prev, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);

    b.call(helpers["set"], [target, insert_idx, insert_val]);
    if _ins_wrapped is not _ins_orig {
        p._emit_rc_release_simple(_ins_wrapped, op="list_insert_wrap", loc="");
    }
    return ir.Constant(i64, 0);
}

impl NativeListEmitter.emit_remove(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None or p._elem_kind(helpers["elem_type"]) == "jacval" {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    search_val = p._coerce_type(args[0], helpers["elem_type"]);
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="rem.len.ptr"
    );
    list_len = b.load(len_ptr, name="rem.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    find_bb = func.append_basic_block(name="rem.find");
    find_body = func.append_basic_block(name="rem.find.body");
    found_bb = func.append_basic_block(name="rem.found");
    shift_bb = func.append_basic_block(name="rem.shift");
    shift_body = func.append_basic_block(name="rem.shift.body");
    done_bb = func.append_basic_block(name="rem.done");
    b.branch(find_bb);

    b.position_at_start(find_bb);
    fi = b.phi(i64, name="rem.fi");
    fi.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", fi, list_len, name="rem.atend");
    b.cbranch(at_end, done_bb, find_body);
    b.position_at_start(find_body);
    elem = b.call(helpers["get"], [target, fi], name="rem.elem");
    eq = b.icmp_signed("==", elem, search_val, name="rem.eq");
    next_fi = b.add(fi, ir.Constant(i64, 1), name="rem.nextfi");
    fi.add_incoming(next_fi, find_body);
    b.cbranch(eq, found_bb, find_bb);

    b.position_at_start(found_bb);

    if isinstance(helpers["elem_type"], ir.PointerType) {
        if p.rc_release_simple_fn is None {
            p._emit_rc_helpers();
        }
        _i8p_lr = ir.IntType(8).as_pointer();
        _lr_elem = b.call(helpers["get"], [target, fi], name="rem_rel_elem");
        _lr_cast = b.bitcast(_lr_elem, _i8p_lr, name="rem_rel_cast");
        b.call(p.rc_release_simple_fn, [_lr_cast]);
    }
    shift_start = b.add(fi, ir.Constant(i64, 1), name="rem.shstart");
    b.branch(shift_bb);
    b.position_at_start(shift_bb);
    si = b.phi(i64, name="rem.si");
    si.add_incoming(shift_start, found_bb);
    shift_end = b.icmp_unsigned(">=", si, list_len, name="rem.shend");
    b.cbranch(shift_end, done_bb, shift_body);
    b.position_at_start(shift_body);
    prev = b.sub(si, ir.Constant(i64, 1), name="rem.prev");
    if isinstance(helpers["elem_type"], ir.PointerType) {
        _sh_dpp = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="sh_dpp"
        );
        _sh_da = b.load(_sh_dpp, name="sh_da");
        _sh_src = b.gep(_sh_da, [si], name="sh_src");
        _sh_val = b.load(_sh_src, name="sh_val");
        _sh_dst = b.gep(_sh_da, [prev], name="sh_dst");
        b.store(_sh_val, _sh_dst);
    } else {
        val = b.call(helpers["get"], [target, si], name="rem.val");
        b.call(helpers["set"], [target, prev, val]);
    }
    next_si = b.add(si, ir.Constant(i64, 1), name="rem.nextsi");
    si.add_incoming(next_si, shift_body);
    b.branch(shift_bb);

    b.position_at_start(done_bb);

    found_phi = b.phi(i64, name="rem.found");
    found_phi.add_incoming(ir.Constant(i64, 0), find_bb);
    found_phi.add_incoming(ir.Constant(i64, 1), shift_bb);
    was_found = b.icmp_unsigned(
        "!=", found_phi, ir.Constant(i64, 0), name="rem.wasfound"
    );
    new_len = b.sub(list_len, ir.Constant(i64, 1), name="rem.newlen");
    final_len = b.select(was_found, new_len, list_len, name="rem.finallen");
    b.store(final_len, len_ptr);
    return ir.Constant(i64, 0);
}

impl NativeListEmitter.emit_pop(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="pop.len.ptr"
    );
    cur_len = b.load(len_ptr, name="pop.len");
    new_len = b.sub(cur_len, ir.Constant(i64, 1), name="pop.newlen");

    pop_idx = new_len;
    if args {
        raw_idx = p._coerce_type(args[0], i64);
        is_neg = b.icmp_signed("<", raw_idx, ir.Constant(i64, 0), name="pop.idx.neg");
        adj_idx = b.add(raw_idx, cur_len, name="pop.idx.adj");
        pop_idx = b.select(is_neg, adj_idx, raw_idx, name="pop.idx");
    }
    popped = b.call(helpers["get"], [target, pop_idx], name="pop.val");

    is_ptr = p._elem_kind(helpers["elem_type"]) != "raw";
    func = b.basic_block.function;
    shift_start = b.add(pop_idx, ir.Constant(i64, 1), name="pop.shstart");
    shift_bb = func.append_basic_block(name="pop.shift");
    shift_body = func.append_basic_block(name="pop.shift.body");
    done_bb = func.append_basic_block(name="pop.shift.done");
    entry_bb = b.basic_block;
    b.branch(shift_bb);
    b.position_at_start(shift_bb);
    si = b.phi(i64, name="pop.si");
    si.add_incoming(shift_start, entry_bb);
    at_end = b.icmp_unsigned(">=", si, cur_len, name="pop.shend");
    b.cbranch(at_end, done_bb, shift_body);
    b.position_at_start(shift_body);
    prev = b.sub(si, ir.Constant(i64, 1), name="pop.prev");
    if is_ptr {
        _dpp = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="pop.dpp"
        );
        _da = b.load(_dpp, name="pop.da");
        _src = b.gep(_da, [si], name="pop.src");
        _val = b.load(_src, name="pop.shval");
        _dst = b.gep(_da, [prev], name="pop.dst");
        b.store(_val, _dst);
    } else {
        _v = b.call(helpers["get"], [target, si], name="pop.shval");
        b.call(helpers["set"], [target, prev, _v]);
    }
    next_si = b.add(si, ir.Constant(i64, 1), name="pop.nextsi");
    si.add_incoming(next_si, shift_body);
    b.branch(shift_bb);
    b.position_at_start(done_bb);
    b.store(new_len, len_ptr);
    if is_ptr {
        p._mark_owned(popped);
    }
    return popped;
}

impl NativeListEmitter.emit_clear(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    helpers = p.list_helpers.get(ctx.type_key);
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="clear.len.ptr"
    );

    if helpers is not None
        and p._elem_kind(helpers["elem_type"]) != "raw"
        and not p._nogc_headerless() {
        _cur_len_c = b.load(len_ptr, name="clr_len");
        _data_pp_c = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="clr_data_pp"
        );
        _data_arr_c = b.load(_data_pp_c, name="clr_data");
        _func_c = b.basic_block.function;
        _clr_loop_bb = _func_c.append_basic_block("clr_loop");
        _clr_body_bb = _func_c.append_basic_block("clr_body");
        _clr_end_bb = _func_c.append_basic_block("clr_end");
        _clr_i_a = p._entry_alloca(i64, "clr_i");
        b.store(ir.Constant(i64, 0), _clr_i_a);
        b.branch(_clr_loop_bb);

        p.builder.position_at_end(_clr_loop_bb);
        b = p.builder;
        _li_c = b.load(_clr_i_a, name="clr_li");
        _clr_cmp = b.icmp_unsigned(">=", _li_c, _cur_len_c, name="clr_done");
        b.cbranch(_clr_cmp, _clr_end_bb, _clr_body_bb);

        p.builder.position_at_end(_clr_body_bb);
        b = p.builder;
        _li2_c = b.load(_clr_i_a, name="clr_li2");
        _ep_c = b.gep(_data_arr_c, [_li2_c], name="clr_ep");
        _ev_c = b.load(_ep_c, name="clr_ev");
        p._emit_elem_release(b, helpers["elem_type"], _ev_c);
        _li3_c = b.load(_clr_i_a, name="clr_li3");
        _ni_c = b.add(_li3_c, ir.Constant(i64, 1), name="clr_ni");
        b.store(_ni_c, _clr_i_a);
        b.branch(_clr_loop_bb);

        p.builder.position_at_end(_clr_end_bb);
        b = p.builder;
    }
    b.store(ir.Constant(i64, 0), len_ptr);
    return ir.Constant(i64, 0);
}

impl NativeListEmitter.emit_index(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None or p._elem_kind(helpers["elem_type"]) == "jacval" {
        return None;
    }
    b = get_builder(p);
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    search_val = p._coerce_type(args[0], helpers["elem_type"]);
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="idx.len.ptr"
    );
    list_len = b.load(len_ptr, name="idx.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="idx.loop");
    check_bb = func.append_basic_block(name="idx.check");
    found_bb = func.append_basic_block(name="idx.found");
    done_bb = func.append_basic_block(name="idx.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="idx.i");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, list_len, name="idx.atend");
    b.cbranch(at_end, done_bb, check_bb);
    b.position_at_start(check_bb);
    elem = b.call(helpers["get"], [target, idx], name="idx.elem");
    eq = b.icmp_signed("==", elem, search_val, name="idx.eq");
    next_idx = b.add(idx, ir.Constant(i64, 1), name="idx.next");
    b.cbranch(eq, found_bb, loop_bb);
    idx.add_incoming(next_idx, check_bb);
    b.position_at_start(found_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result = b.phi(i64, name="idx.result");
    result.add_incoming(ir.Constant(i64, -1), loop_bb);
    result.add_incoming(idx, found_bb);

    miss = b.icmp_signed("==", result, ir.Constant(i64, -1), name="idx.miss");
    p._emit_runtime_raise(miss, "ValueError", "list.index(x): x not in list");
    return result;
}

impl NativeListEmitter.emit_count(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None or p._elem_kind(helpers["elem_type"]) == "jacval" {
        return None;
    }
    b = get_builder(p);
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    search_val = p._coerce_type(args[0], helpers["elem_type"]);
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="cnt.len.ptr"
    );
    list_len = b.load(len_ptr, name="cnt.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="cnt.loop");
    body_bb = func.append_basic_block(name="cnt.body");
    inc_bb = func.append_basic_block(name="cnt.inc");
    done_bb = func.append_basic_block(name="cnt.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="cnt.idx");
    count = b.phi(i64, name="cnt.count");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    count.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, list_len, name="cnt.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    elem = b.call(helpers["get"], [target, idx], name="cnt.elem");
    eq = b.icmp_signed("==", elem, search_val, name="cnt.eq");
    next_idx = b.add(idx, ir.Constant(i64, 1), name="cnt.next");
    b.cbranch(eq, inc_bb, loop_bb);
    idx.add_incoming(next_idx, body_bb);
    count.add_incoming(count, body_bb);
    b.position_at_start(inc_bb);
    new_count = b.add(count, ir.Constant(i64, 1), name="cnt.inc");
    next_idx2 = b.add(idx, ir.Constant(i64, 1), name="cnt.next2");
    idx.add_incoming(next_idx2, inc_bb);
    count.add_incoming(new_count, inc_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return count;
}

impl NativeListEmitter.emit_sort(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None or p._elem_kind(helpers["elem_type"]) == "jacval" {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);
    elem_type = helpers["elem_type"];

    _kw = ctx?.call_kwargs or {};
    _key_node = _kw.get("key");
    _rev_node = _kw.get("reverse");
    _unknown_kw = [
        k
        for k in _kw.keys()
        if k not in ("key", "reverse")
    ];
    if _unknown_kw {
        p.emit(
            E5092,
            node_override=_key_node or _rev_node,
            kind="sort keyword argument",
            name=", ".join(_unknown_kw)
        );
        return None;
    }
    key_fn: (ir.Function | None) = None;
    if _key_node is not None {
        _key_val = p._codegen_expr(_key_node);
        _key_caps = p._pending_lambda_captures;
        p._pending_lambda_captures = None;
        if (
            not isinstance(_key_val, ir.Function)
            or _key_caps is not None
            or len(_key_val.args) != 1
        ) {
            p.emit(
                E5092,
                node_override=_key_node,
                kind="sort key",
                name="key= (only a capture-free single-parameter lambda works)"
            );
            return None;
        }
        key_fn = _key_val;
    }
    rev_i1: (ir.Value | None) = None;
    if _rev_node is not None {
        _rev_val = p._codegen_expr(_rev_node);
        if _rev_val is not None {
            rev_i1 = p._to_bool(_rev_val);
        }
    }
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="sort.len.ptr"
    );
    list_len = b.load(len_ptr, name="sort.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;

    outer_bb = func.append_basic_block(name="sort.outer");
    inner_start = func.append_basic_block(name="sort.inner.start");
    inner_bb = func.append_basic_block(name="sort.inner");
    inner_body = func.append_basic_block(name="sort.inner.body");
    swap_bb = func.append_basic_block(name="sort.swap");
    no_swap = func.append_basic_block(name="sort.noswap");
    inner_next = func.append_basic_block(name="sort.inner.next");
    outer_next = func.append_basic_block(name="sort.outer.next");
    done_bb = func.append_basic_block(name="sort.done");
    len_m1 = b.sub(list_len, one, name="sort.lenm1");
    trivial = b.icmp_unsigned("<=", list_len, one, name="sort.trivial");
    b.cbranch(trivial, done_bb, outer_bb);

    b.position_at_start(outer_bb);
    oi = b.phi(i64, name="sort.oi");
    oi.add_incoming(zero, entry_bb);
    outer_end = b.icmp_unsigned(">=", oi, len_m1, name="sort.oend");
    b.cbranch(outer_end, done_bb, inner_start);

    b.position_at_start(inner_start);
    inner_limit = b.sub(len_m1, oi, name="sort.ilimit");
    b.branch(inner_bb);

    b.position_at_start(inner_bb);
    ji = b.phi(i64, name="sort.ji");
    ji.add_incoming(zero, inner_start);
    inner_end = b.icmp_unsigned(">=", ji, inner_limit, name="sort.iend");
    b.cbranch(inner_end, outer_next, inner_body);

    b.position_at_start(inner_body);
    j1 = b.add(ji, one, name="sort.j1");
    ej = b.call(helpers["get"], [target, ji], name="sort.ej");
    ej1 = b.call(helpers["get"], [target, j1], name="sort.ej1");

    (cj, cj1) = (ej, ej1);
    cmp_type = elem_type;
    if key_fn is not None {
        _kp_type = key_fn.args[0].type;
        cj = b.call(key_fn, [p._coerce_type(ej, _kp_type)], name="sort.kj");
        cj1 = b.call(key_fn, [p._coerce_type(ej1, _kp_type)], name="sort.kj1");
        cmp_type = key_fn.function_type.return_type;
    }
    if isinstance(cmp_type, ir.DoubleType) {
        cmp_gt = b.fcmp_ordered(">", cj, cj1, name="sort.gt");
        cmp_lt = b.fcmp_ordered("<", cj, cj1, name="sort.lt");
    } elif isinstance(cmp_type, ir.PointerType) {
        _i8p_cmp = ir.IntType(8).as_pointer();
        cmp_result = p._call_str_cmp(
            b,
            b.bitcast(cj, _i8p_cmp, name="sort.cj.cast"),
            b.bitcast(cj1, _i8p_cmp, name="sort.cj1.cast"),
            name="sort.cmp"
        );
        cmp_gt = b.icmp_signed(
            ">", cmp_result, ir.Constant(ir.IntType(32), 0), name="sort.gt"
        );
        cmp_lt = b.icmp_signed(
            "<", cmp_result, ir.Constant(ir.IntType(32), 0), name="sort.lt"
        );
    } else {
        cmp_gt = b.icmp_signed(">", cj, cj1, name="sort.gt");
        cmp_lt = b.icmp_signed("<", cj, cj1, name="sort.lt");
    }

    needs_swap = cmp_gt
        if rev_i1 is None
        else b.select(rev_i1, cmp_lt, cmp_gt, name="sort.dir");
    b.cbranch(needs_swap, swap_bb, no_swap);

    b.position_at_start(swap_bb);
    b.call(helpers["set"], [target, ji, ej1]);
    b.call(helpers["set"], [target, j1, ej]);
    b.branch(inner_next);
    b.position_at_start(no_swap);
    b.branch(inner_next);

    b.position_at_start(inner_next);
    next_ji = b.add(ji, one, name="sort.nji");
    ji.add_incoming(next_ji, inner_next);
    b.branch(inner_bb);

    b.position_at_start(outer_next);
    next_oi = b.add(oi, one, name="sort.noi");
    oi.add_incoming(next_oi, outer_next);
    b.branch(outer_bb);
    b.position_at_start(done_bb);
    return ir.Constant(i64, 0);
}

impl NativeListEmitter.emit_reverse(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="rev.len.ptr"
    );
    list_len = b.load(len_ptr, name="rev.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="rev.loop");
    body_bb = func.append_basic_block(name="rev.body");
    done_bb = func.append_basic_block(name="rev.done");
    j_init = b.sub(list_len, ir.Constant(i64, 1), name="rev.j.init");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    i_phi = b.phi(i64, name="rev.i");
    j_phi = b.phi(i64, name="rev.j");
    i_phi.add_incoming(ir.Constant(i64, 0), entry_bb);
    j_phi.add_incoming(j_init, entry_bb);
    cond = b.icmp_signed("<", i_phi, j_phi, name="rev.cond");
    b.cbranch(cond, body_bb, done_bb);
    b.position_at_start(body_bb);
    val_i = b.call(helpers["get"], [target, i_phi], name="rev.val.i");
    val_j = b.call(helpers["get"], [target, j_phi], name="rev.val.j");
    b.call(helpers["set"], [target, i_phi, val_j]);
    b.call(helpers["set"], [target, j_phi, val_i]);
    next_i = b.add(i_phi, ir.Constant(i64, 1), name="rev.next.i");
    next_j = b.sub(j_phi, ir.Constant(i64, 1), name="rev.next.j");
    i_phi.add_incoming(next_i, body_bb);
    j_phi.add_incoming(next_j, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return ir.Constant(i64, 0);
}

impl NativeListEmitter.emit_copy(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    new_list = b.call(helpers["new"], [], name="copy.new");
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="copy.len.ptr"
    );
    src_len = b.load(len_ptr, name="copy.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="copy.loop");
    body_bb = func.append_basic_block(name="copy.body");
    done_bb = func.append_basic_block(name="copy.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="copy.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, src_len, name="copy.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    elem = b.call(helpers["get"], [target, idx], name="copy.elem");
    b.call(helpers["append"], [new_list, elem]);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="copy.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return new_list;
}

impl NativeDictEmitter.emit_get(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i64 = ir.IntType(64);
    key = args[0];
    found_i1 = b.call(helpers["contains"], [target, key], name="dget.found");
    func = b.basic_block.function;
    found_bb = func.append_basic_block(name="dget.yes");
    notfound_bb = func.append_basic_block(name="dget.no");
    done_bb = func.append_basic_block(name="dget.done");
    b.cbranch(found_i1, found_bb, notfound_bb);

    val_type = helpers["val_type"];

    wrap_optional = (len(args) < 2) and (not isinstance(val_type, ir.PointerType));
    result_type = p._jac_optional_type(val_type) if wrap_optional else val_type;

    b.position_at_start(found_bb);
    val = b.call(helpers["get"], [target, key], name="dget.val");
    if wrap_optional {
        _tagged = b.insert_value(
            ir.Constant(result_type, None),
            ir.Constant(ir.IntType(8), 1),
            0,
            name="dget.some.tag"
        );
        val = b.insert_value(_tagged, val, 1, name="dget.some");
    }
    b.branch(done_bb);

    b.position_at_start(notfound_bb);
    if wrap_optional {
        default_val: ir.Value = ir.Constant(result_type, None);
    } elif len(args) >= 2 {
        default_val = p._coerce_type(args[1], val_type);
    } else {
        default_val = ir.Constant(val_type, None);
    }
    b.branch(done_bb);

    b.position_at_start(done_bb);
    result = b.phi(result_type, name="dget.result");
    result.add_incoming(val, found_bb);
    result.add_incoming(default_val, notfound_bb);
    if isinstance(val_type, ir.PointerType) {
        if p.rc_retain_fn is None {
            p._emit_rc_helpers();
        }
        _res_cast = b.bitcast(result, ir.IntType(8).as_pointer(), name="dget.ret.cast");
        b.call(p.rc_retain_fn, [_res_cast]);
    }
    return result;
}

impl NativeDictEmitter.emit_keys(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);

    key_type = helpers["key_type"];
    if isinstance(key_type, ir.PointerType) {
        kt_name = "ptr";
        key_type = ir.IntType(8).as_pointer();
    } elif isinstance(key_type, ir.DoubleType) {
        kt_name = "f64";
    } else {
        kt_name = "i64";
    }
    p._emit_list_helpers(kt_name, key_type);
    lhelpers = p.list_helpers.get(kt_name);
    if lhelpers is None {
        return None;
    }
    new_list = b.call(lhelpers["new"], [], name="dkeys.list");
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="dkeys.len.ptr"
    );
    dict_len = b.load(len_ptr, name="dkeys.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="dkeys.loop");
    body_bb = func.append_basic_block(name="dkeys.body");
    done_bb = func.append_basic_block(name="dkeys.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="dkeys.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, dict_len, name="dkeys.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    key = b.call(helpers["get_key"], [target, idx], name="dkeys.key");
    key = p._cast_to_list_elem(b, key, lhelpers["elem_type"], "dkeys.key");
    b.call(lhelpers["append"], [new_list, key]);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="dkeys.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return new_list;
}

impl NativeDictEmitter.emit_values(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);

    val_type = helpers["val_type"];
    if isinstance(val_type, ir.PointerType) {
        vt_name = "ptr";
        val_type = ir.IntType(8).as_pointer();
    } elif isinstance(val_type, ir.DoubleType) {
        vt_name = "f64";
    } else {
        vt_name = "i64";
    }
    p._emit_list_helpers(vt_name, val_type);
    lhelpers = p.list_helpers.get(vt_name);
    if lhelpers is None {
        return None;
    }
    new_list = b.call(lhelpers["new"], [], name="dvals.list");
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="dvals.len.ptr"
    );
    dict_len = b.load(len_ptr, name="dvals.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="dvals.loop");
    body_bb = func.append_basic_block(name="dvals.body");
    done_bb = func.append_basic_block(name="dvals.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="dvals.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, dict_len, name="dvals.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    key = b.call(helpers["get_key"], [target, idx], name="dvals.key");
    val = b.call(helpers["get"], [target, key], name="dvals.val");
    val = p._cast_to_list_elem(b, val, lhelpers["elem_type"], "dvals.val");
    b.call(lhelpers["append"], [new_list, val]);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="dvals.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return new_list;
}

impl NativeDictEmitter.emit_items(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    key_type = helpers["key_type"];
    val_type = helpers["val_type"];

    tuple_type = ir.LiteralStructType([key_type, val_type]);

    kt_str = "i8p"
        if isinstance(key_type, ir.PointerType)
        else ("f64" if isinstance(key_type, ir.DoubleType) else "i64");
    vt_str = "i8p"
        if isinstance(val_type, ir.PointerType)
        else ("f64" if isinstance(val_type, ir.DoubleType) else "i64");
    tkey = f"{kt_str}.{vt_str}";
    if tkey not in p.tuple_types {
        p.tuple_types[tkey] = tuple_type;
    }

    p._emit_list_helpers("ptr", i8p);
    lhelpers = p.list_helpers.get("ptr");
    if lhelpers is None {
        return None;
    }
    new_list = b.call(lhelpers["new"], [], name="ditems.list");

    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ditems.len.ptr"
    );
    dict_len = b.load(len_ptr, name="ditems.len");

    null_ptr = ir.Constant(tuple_type.as_pointer(), None);
    size_gep = b.gep(null_ptr, [ir.Constant(i32, 1)], name="ditems.sizeof.gep");
    tup_size = b.ptrtoint(size_gep, i64, name="ditems.sizeof");

    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="ditems.loop");
    body_bb = func.append_basic_block(name="ditems.body");
    done_bb = func.append_basic_block(name="ditems.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="ditems.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, dict_len, name="ditems.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);

    key = b.call(helpers["get_key"], [target, idx], name="ditems.key");
    val = b.call(helpers["get"], [target, key], name="ditems.val");

    raw = b.call(p.rc_alloc_fn, [tup_size], name="ditems.alloc");
    tup_ptr = b.bitcast(raw, tuple_type.as_pointer(), name="ditems.tup");
    k_ptr = b.gep(
        tup_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ditems.k.ptr"
    );
    v_ptr = b.gep(
        tup_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="ditems.v.ptr"
    );
    b.store(key, k_ptr);
    b.store(val, v_ptr);

    tup_i8p = b.bitcast(tup_ptr, i8p, name="ditems.i8p");
    b.call(lhelpers["append"], [new_list, tup_i8p]);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="ditems.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return new_list;
}

impl NativeDictEmitter.emit_pop(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    key = args[0];
    val_type = helpers["val_type"];
    has_default = len(args) >= 2;

    func = b.basic_block.function;
    found_bb = func.append_basic_block(name="dpop.yes");
    notfound_bb = func.append_basic_block(name="dpop.no");
    done_bb = func.append_basic_block(name="dpop.done");

    found_i1 = b.call(helpers["contains"], [target, key], name="dpop.found");
    b.cbranch(found_i1, found_bb, notfound_bb);

    b.position_at_start(found_bb);
    popped_val = b.call(helpers["pop"], [target, key], name="dpop.val");
    _found_pred = b.basic_block;
    b.branch(done_bb);

    b.position_at_start(notfound_bb);
    if has_default {
        default_val = p._coerce_type(args[1], val_type);
    } else {
        p._emit_runtime_raise(
            ir.Constant(ir.IntType(1), 1), "KeyError", "key not found"
        );
        if p._elem_kind(val_type) != "raw" {
            default_val = ir.Constant(val_type, None);
        } else {
            default_val = ir.Constant(val_type, 0);
        }
    }
    _notfound_pred = b.basic_block;
    b.branch(done_bb);

    b.position_at_start(done_bb);
    result = b.phi(val_type, name="dpop.result");
    result.add_incoming(popped_val, _found_pred);
    result.add_incoming(default_val, _notfound_pred);
    return result;
}

impl NativeDictEmitter.emit_remove(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    key = args[0];
    found_i1 = b.call(helpers["contains"], [target, key], name="drem.has");
    _not_found = b.not_(found_i1, name="drem.miss");
    p._emit_runtime_raise(_not_found, "KeyError", "key not found");
    b.call(helpers["remove"], [target, key]);
    return None;
}

impl NativeDictEmitter.emit_popitem(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    key_type = helpers["key_type"];
    val_type = helpers["val_type"];

    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="dpi.len.ptr"
    );
    dict_len = b.load(len_ptr, name="dpi.len");

    is_empty = b.icmp_signed("==", dict_len, ir.Constant(i64, 0), name="dpi.empty");
    p._emit_runtime_raise(is_empty, "KeyError", "popitem(): dictionary is empty");

    last_idx = b.sub(dict_len, ir.Constant(i64, 1), name="dpi.last");
    last_key = b.call(helpers["get_key"], [target, last_idx], name="dpi.key");

    last_key_out = last_key;
    if isinstance(key_type, ir.PointerType) {
        _i8p_pi = ir.IntType(8).as_pointer();
        if p._nogc_headerless() {
            if (
                isinstance(key_type.pointee, ir.IntType) and key_type.pointee.width == 8
            ) {
                _key_copy = p._call_str_dup(
                    b, b.bitcast(last_key, _i8p_pi, name="dpi.k.src"), name="dpi.k.copy"
                );
                last_key_out = b.bitcast(_key_copy, key_type, name="dpi.k.out");
            }
        } else {
            if p.rc_retain_fn is None {
                p._emit_rc_helpers();
            }
            b.call(p.rc_retain_fn, [b.bitcast(last_key, _i8p_pi, name="dpi.k.ret")]);
        }
    }

    last_val = b.call(helpers["pop"], [target, last_key], name="dpi.val");

    tuple_type = ir.LiteralStructType([key_type, val_type]);
    null_ptr = ir.Constant(tuple_type.as_pointer(), None);
    size_gep = b.gep(null_ptr, [ir.Constant(i32, 1)], name="dpi.sizeof.gep");
    size = b.ptrtoint(size_gep, i64, name="dpi.sizeof");
    raw_ptr = b.call(p.rc_alloc_fn, [size], name="dpi.alloc");
    tuple_ptr = b.bitcast(raw_ptr, tuple_type.as_pointer(), name="dpi.ptr");
    k_ptr = b.gep(
        tuple_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="dpi.k.ptr"
    );
    v_ptr = b.gep(
        tuple_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="dpi.v.ptr"
    );
    b.store(last_key_out, k_ptr);
    b.store(last_val, v_ptr);

    kt_str = "i8p"
        if isinstance(key_type, ir.PointerType)
        else ("f64" if isinstance(key_type, ir.DoubleType) else "i64");
    vt_str = "i8p"
        if isinstance(val_type, ir.PointerType)
        else ("f64" if isinstance(val_type, ir.DoubleType) else "i64");
    tkey = f"{kt_str}.{vt_str}";
    if tkey not in p.tuple_types {
        p.tuple_types[tkey] = tuple_type;
    }
    return tuple_ptr;
}

impl NativeDictEmitter.emit_setdefault(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i64 = ir.IntType(64);
    key = args[0];
    val_type = helpers["val_type"];
    if len(args) >= 2 {
        default_val = args[1];
    } elif p._elem_kind(val_type) != "raw" {
        default_val = ir.Constant(val_type, None);
    } else {
        return None;
    }

    found = b.call(helpers["contains"], [target, key], name="sdef.found");
    func = b.basic_block.function;
    found_bb = func.append_basic_block(name="sdef.yes");
    notfound_bb = func.append_basic_block(name="sdef.no");
    done_bb = func.append_basic_block(name="sdef.done");
    b.cbranch(found, found_bb, notfound_bb);

    b.position_at_start(found_bb);
    existing = b.call(helpers["get"], [target, key], name="sdef.existing");
    b.branch(done_bb);

    b.position_at_start(notfound_bb);
    b.call(helpers["set"], [target, key, default_val]);
    b.branch(done_bb);

    b.position_at_start(done_bb);
    result = b.phi(val_type, name="sdef.result");
    result.add_incoming(existing, found_bb);
    result.add_incoming(default_val, notfound_bb);
    return result;
}

impl NativeDictEmitter.emit_update(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    other = args[0];
    len_ptr = b.gep(
        other, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="dupd.len.ptr"
    );
    other_len = b.load(len_ptr, name="dupd.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="dupd.loop");
    body_bb = func.append_basic_block(name="dupd.body");
    done_bb = func.append_basic_block(name="dupd.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="dupd.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, other_len, name="dupd.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    key = b.call(helpers["get_key"], [other, idx], name="dupd.key");
    val = b.call(helpers["get"], [other, key], name="dupd.val");
    b.call(helpers["set"], [target, key, val]);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="dupd.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return ir.Constant(i64, 0);
}

impl NativeDictEmitter.emit_clear(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);

    b.call(helpers["clear"], [target]);
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeDictEmitter.emit_copy(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    new_dict = b.call(helpers["new"], [], name="dcopy.new");
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="dcopy.len.ptr"
    );
    dict_len = b.load(len_ptr, name="dcopy.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="dcopy.loop");
    body_bb = func.append_basic_block(name="dcopy.body");
    done_bb = func.append_basic_block(name="dcopy.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="dcopy.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, dict_len, name="dcopy.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    key = b.call(helpers["get_key"], [target, idx], name="dcopy.key");
    val = b.call(helpers["get"], [target, key], name="dcopy.val");
    b.call(helpers["set"], [new_dict, key, val]);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="dcopy.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return new_dict;
}

impl NativeDictEmitter.emit_fromkeys(
    self: NativeDictEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeSetEmitter.emit_add(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None or not args {
        return None;
    }
    if p._reject_ptr_into_raw_slot(None, args[0], helpers["elem_type"], "set add") {
        return ir.Constant(ir.IntType(64), 0);
    }
    val = p._coerce_type(args[0], helpers["elem_type"]);
    get_builder(p).call(helpers["add"], [target, val]);

    if isinstance(val.type, ir.PointerType)
        and p._is_owned(val)
        and not p._nogc_headerless() {
        _b_sa = get_builder(p);
        _i8p_sa = ir.IntType(8).as_pointer();
        _rc_sa = _b_sa.bitcast(val, _i8p_sa, name="sadd_own_rel_cast");
        if p.rc_release_simple_fn is None {
            p._emit_rc_helpers();
        }
        _b_sa.call(p.rc_release_simple_fn, [_rc_sa]);
    }
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeSetEmitter._emit_set_elem_loop(
    self: NativeSetEmitter,
    ctx: NativeEmitCtx,
    src_set: ir.Value,
    prefix: str,
    body_cb: object
) -> None {
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return;
    }
    b = get_builder(p);
    i64 = ir.IntType(64);
    n = b.call(helpers["len"], [src_set], name=f"{prefix}.len");
    iv = b.alloca(i64, name=f"{prefix}.i");
    b.store(ir.Constant(i64, 0), iv);
    func = b.basic_block.function;
    loop_bb = func.append_basic_block(name=f"{prefix}.loop");
    body_bb = func.append_basic_block(name=f"{prefix}.body");
    done_bb = func.append_basic_block(name=f"{prefix}.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.load(iv, name=f"{prefix}.idx");
    at_end = b.icmp_unsigned(">=", idx, n, name=f"{prefix}.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    idx_b = b.load(iv, name=f"{prefix}.idx.b");
    ev = b.call(helpers["get"], [src_set, idx_b], name=f"{prefix}.ev");
    body_cb(b, ev);
    b.store(b.add(idx_b, ir.Constant(i64, 1), name=f"{prefix}.next"), iv);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
}

impl NativeSetEmitter.emit_remove(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    search_val = p._coerce_type(args[0], helpers["elem_type"]);
    _has_e = b.call(helpers["contains"], [target, search_val], name="srem.has");
    miss = b.not_(_has_e, name="srem.miss");
    p._emit_runtime_raise(miss, "KeyError", "element not in set");
    b = get_builder(p);
    b.call(helpers["remove"], [target, search_val]);
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeSetEmitter.emit_discard(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    search_val = p._coerce_type(args[0], helpers["elem_type"]);
    b.call(helpers["remove"], [target, search_val]);
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeSetEmitter.emit_pop(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    elem_type = helpers["elem_type"];
    set_len = b.call(helpers["len"], [target], name="spop.len");
    is_empty = b.icmp_unsigned("==", set_len, ir.Constant(i64, 0), name="spop.empty");
    p._emit_runtime_raise(is_empty, "KeyError", "pop from an empty set");
    b = get_builder(p);
    last_idx = b.sub(set_len, ir.Constant(i64, 1), name="spop.last");
    last_val = b.call(helpers["get"], [target, last_idx], name="spop.val");
    out_val = last_val;
    if isinstance(elem_type, ir.PointerType) {
        if p._nogc_headerless() {
            if isinstance(elem_type.pointee, ir.IntType)
                and elem_type.pointee.width == 8 {
                _sdup = p._get_or_declare_extern("strdup", i8p, [i8p]);
                out_val = b.call(
                    _sdup, [b.bitcast(last_val, i8p, name="spop.src")], name="spop.dup"
                );
                out_val = b.bitcast(out_val, elem_type, name="spop.copy");
            }
        } else {
            if p.rc_retain_fn is None {
                p._emit_rc_helpers();
            }
            b.call(p.rc_retain_fn, [b.bitcast(last_val, i8p, name="spop.keep")]);
        }
    }
    b.call(helpers["remove"], [target, last_val]);
    return out_val;
}

impl NativeSetEmitter.emit_clear(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    b.call(helpers["clear"], [target]);
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeSetEmitter.emit_union(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    new_set = b.call(helpers["new"], [], name="sunion.new");

    def _add_elem(b2: ir.IRBuilder, ev: ir.Value) {
        b2.call(helpers["add"], [new_set, ev]);
    }
    self._emit_set_elem_loop(ctx, target, "su.a", _add_elem);
    self._emit_set_elem_loop(ctx, args[0], "su.b", _add_elem);
    return new_set;
}

impl NativeSetEmitter.emit_intersection(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    new_set = b.call(helpers["new"], [], name="sinter.new");
    other = args[0];

    def _keep_common(b2: ir.IRBuilder, ev: ir.Value) {
        func = b2.basic_block.function;
        hit = b2.call(helpers["contains"], [other, ev], name="si.inother");
        add_bb = func.append_basic_block(name="si.add");
        skip_bb = func.append_basic_block(name="si.skip");
        b2.cbranch(hit, add_bb, skip_bb);
        b2.position_at_start(add_bb);
        b2.call(helpers["add"], [new_set, ev]);
        b2.branch(skip_bb);
        b2.position_at_start(skip_bb);
    }
    self._emit_set_elem_loop(ctx, target, "si", _keep_common);
    return new_set;
}

impl NativeSetEmitter.emit_difference(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    new_set = b.call(helpers["new"], [], name="sdiff.new");
    other = args[0];

    def _keep_missing(b2: ir.IRBuilder, ev: ir.Value) {
        func = b2.basic_block.function;
        hit = b2.call(helpers["contains"], [other, ev], name="sd.inother");
        add_bb = func.append_basic_block(name="sd.add");
        skip_bb = func.append_basic_block(name="sd.skip");
        b2.cbranch(hit, skip_bb, add_bb);
        b2.position_at_start(add_bb);
        b2.call(helpers["add"], [new_set, ev]);
        b2.branch(skip_bb);
        b2.position_at_start(skip_bb);
    }
    self._emit_set_elem_loop(ctx, target, "sd", _keep_missing);
    return new_set;
}

impl NativeSetEmitter.emit_symmetric_difference(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    new_set = b.call(helpers["new"], [], name="ssymd.new");
    other = args[0];

    def _only_in(probe: ir.Value, prefix: str) -> object {
        def _cb(b2: ir.IRBuilder, ev: ir.Value) {
            func = b2.basic_block.function;
            hit = b2.call(helpers["contains"], [probe, ev], name=f"{prefix}.in");
            add_bb = func.append_basic_block(name=f"{prefix}.add");
            skip_bb = func.append_basic_block(name=f"{prefix}.skip");
            b2.cbranch(hit, skip_bb, add_bb);
            b2.position_at_start(add_bb);
            b2.call(helpers["add"], [new_set, ev]);
            b2.branch(skip_bb);
            b2.position_at_start(skip_bb);
        }
        return _cb;
    }
    self._emit_set_elem_loop(ctx, target, "ssymd.a", _only_in(other, "ssymd.a"));
    self._emit_set_elem_loop(ctx, other, "ssymd.b", _only_in(target, "ssymd.b"));
    return new_set;
}

impl NativeSetEmitter.emit_update(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }

    def _add_elem(b2: ir.IRBuilder, ev: ir.Value) {
        b2.call(helpers["add"], [target, ev]);
    }
    self._emit_set_elem_loop(ctx, args[0], "supd", _add_elem);
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeSetEmitter.emit_intersection_update(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    kept = self.emit_intersection(ctx, target, [args[0]]);
    if kept is None {
        return None;
    }
    b = get_builder(p);
    b.call(helpers["clear"], [target]);

    def _re_add(b2: ir.IRBuilder, ev: ir.Value) {
        b2.call(helpers["add"], [target, ev]);
    }
    self._emit_set_elem_loop(ctx, kept, "siupd", _re_add);
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeSetEmitter.emit_difference_update(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    kept = self.emit_difference(ctx, target, [args[0]]);
    if kept is None {
        return None;
    }
    b = get_builder(p);
    b.call(helpers["clear"], [target]);

    def _re_add(b2: ir.IRBuilder, ev: ir.Value) {
        b2.call(helpers["add"], [target, ev]);
    }
    self._emit_set_elem_loop(ctx, kept, "sdupd", _re_add);
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeSetEmitter.emit_symmetric_difference_update(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    result = self.emit_symmetric_difference(ctx, target, [args[0]]);
    if result is None {
        return None;
    }
    b = get_builder(p);
    b.call(helpers["clear"], [target]);

    def _re_add(b2: ir.IRBuilder, ev: ir.Value) {
        b2.call(helpers["add"], [target, ev]);
    }
    self._emit_set_elem_loop(ctx, result, "ssdupd", _re_add);
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeSetEmitter._emit_set_relation(
    self: NativeSetEmitter,
    ctx: NativeEmitCtx,
    iter_set: ir.Value,
    probe_set: ir.Value,
    prefix: str,
    chk: str,
    exit_on_hit: bool
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i64 = ir.IntType(64);
    res_a = b.alloca(i64, name=f"{prefix}.res");
    b.store(ir.Constant(i64, 1), res_a);

    def _probe(b2: ir.IRBuilder, ev: ir.Value) {
        func = b2.basic_block.function;
        hit = b2.call(helpers["contains"], [probe_set, ev], name=f"{prefix}.{chk}");
        fail_bb = func.append_basic_block(name=f"{prefix}.fail");
        keep_bb = func.append_basic_block(name=f"{prefix}.keep");
        if exit_on_hit {
            b2.cbranch(hit, fail_bb, keep_bb);
        } else {
            b2.cbranch(hit, keep_bb, fail_bb);
        }
        b2.position_at_start(fail_bb);
        b2.store(ir.Constant(i64, 0), res_a);
        b2.branch(keep_bb);
        b2.position_at_start(keep_bb);
    }
    self._emit_set_elem_loop(ctx, iter_set, prefix, _probe);
    b = get_builder(p);
    return b.load(res_a, name=f"{prefix}.result");
}

impl NativeSetEmitter.emit_issubset(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    return self._emit_set_relation(ctx, target, args[0], "ssub", "inother", False);
}

impl NativeSetEmitter.emit_issuperset(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    return self._emit_set_relation(ctx, args[0], target, "ssup", "inself", False);
}

impl NativeSetEmitter.emit_isdisjoint(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    return self._emit_set_relation(ctx, target, args[0], "sdisj", "inother", True);
}

impl NativeSetEmitter.emit_copy(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    new_set = b.call(helpers["new"], [], name="scopy.new");

    def _add_elem(b2: ir.IRBuilder, ev: ir.Value) {
        b2.call(helpers["add"], [new_set, ev]);
    }
    self._emit_set_elem_loop(ctx, target, "scopy", _add_elem);
    return new_set;
}

impl NativeFrozensetEmitter._get_set_emitter(
    self: NativeFrozensetEmitter, ctx: NativeEmitCtx
) -> (NativeSetEmitter | None) {
    regs = ctx.pass_ref._native_emitters;
    se = regs.get("set") if regs is not None else None;
    return se if isinstance(se, NativeSetEmitter) else None;
}

impl NativeFrozensetEmitter.emit_union(
    self: NativeFrozensetEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    se = self._get_set_emitter(ctx);
    return se.emit_union(ctx, target, args) if se is not None else None;
}

impl NativeFrozensetEmitter.emit_intersection(
    self: NativeFrozensetEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    se = self._get_set_emitter(ctx);
    return se.emit_intersection(ctx, target, args) if se is not None else None;
}

impl NativeFrozensetEmitter.emit_difference(
    self: NativeFrozensetEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    se = self._get_set_emitter(ctx);
    return se.emit_difference(ctx, target, args) if se is not None else None;
}

impl NativeFrozensetEmitter.emit_symmetric_difference(
    self: NativeFrozensetEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    se = self._get_set_emitter(ctx);
    return se.emit_symmetric_difference(ctx, target, args) if se is not None else None;
}

impl NativeFrozensetEmitter.emit_issubset(
    self: NativeFrozensetEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    se = self._get_set_emitter(ctx);
    return se.emit_issubset(ctx, target, args) if se is not None else None;
}

impl NativeFrozensetEmitter.emit_issuperset(
    self: NativeFrozensetEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    se = self._get_set_emitter(ctx);
    return se.emit_issuperset(ctx, target, args) if se is not None else None;
}

impl NativeFrozensetEmitter.emit_isdisjoint(
    self: NativeFrozensetEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    se = self._get_set_emitter(ctx);
    return se.emit_isdisjoint(ctx, target, args) if se is not None else None;
}

impl NativeFrozensetEmitter.emit_copy(
    self: NativeFrozensetEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    se = self._get_set_emitter(ctx);
    return se.emit_copy(ctx, target, args) if se is not None else None;
}

impl NativeTupleEmitter._get_struct_info(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value
) -> (ir.LiteralStructType | None) {
    if isinstance(target.type, ir.PointerType)
        and isinstance(target.type.pointee, ir.LiteralStructType) {
        return target.type.pointee;
    }

    p = ctx.pass_ref;
    st = p.tuple_types.get(ctx.type_key);
    return st;
}

impl NativeTupleEmitter.emit_count(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    st = self._get_struct_info(ctx, target);
    if st is None or not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    n = len(st.elements);
    count: ir.Value = ir.Constant(i64, 0);
    val = args[0];
    for i in range(n) {
        ep = b.gep(
            target,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), i)],
            name=f"tc.{i}.ptr"
        );
        elem = b.load(ep, name=f"tc.{i}");
        val_c = p._coerce_type(val, elem.type);
        if isinstance(elem.type, ir.IntType) {
            eq = b.icmp_signed("==", val_c, elem, name=f"tc.{i}.eq");
        } elif isinstance(elem.type, ir.DoubleType) {
            eq = b.fcmp_ordered("==", val_c, elem, name=f"tc.{i}.eq");
        } else {
            return None;
        }
        inc = b.zext(eq, i64, name=f"tc.{i}.inc");
        count = b.add(count, inc, name=f"tc.{i}.cnt");
    }
    return count;
}

impl NativeTupleEmitter.emit_index(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    st = self._get_struct_info(ctx, target);
    if st is None or not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    n = len(st.elements);
    val = args[0];

    result: ir.Value = ir.Constant(i64, -1);
    for i in range(n - 1, -1, -1) {
        ep = b.gep(
            target,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), i)],
            name=f"ti.{i}.ptr"
        );
        elem = b.load(ep, name=f"ti.{i}");
        val_c = p._coerce_type(val, elem.type);
        if isinstance(elem.type, ir.IntType) {
            eq = b.icmp_signed("==", val_c, elem, name=f"ti.{i}.eq");
        } elif isinstance(elem.type, ir.DoubleType) {
            eq = b.fcmp_ordered("==", val_c, elem, name=f"ti.{i}.eq");
        } else {
            return None;
        }
        result = b.select(eq, ir.Constant(i64, i), result, name=f"ti.{i}.sel");
    }
    return result;
}

impl NativeTupleEmitter.emit_op_add(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeTupleEmitter.emit_op_mul(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeTupleEmitter.emit_op_eq(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeTupleEmitter.emit_op_ne(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeTupleEmitter.emit_op_lt(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeTupleEmitter.emit_op_gt(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeTupleEmitter.emit_op_le(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeTupleEmitter.emit_op_ge(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeTupleEmitter.emit_op_contains(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeRangeEmitter._load_range(
    self: NativeRangeEmitter, ctx: NativeEmitCtx, target: ir.Value
) -> (tuple | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    z0 = ir.Constant(i32, 0);
    start = b.load(
        b.gep(target, [z0, ir.Constant(i32, 0)], name="rng.sp"), name="rng.start"
    );
    stop = b.load(
        b.gep(target, [z0, ir.Constant(i32, 1)], name="rng.ep"), name="rng.stop"
    );
    step = b.load(
        b.gep(target, [z0, ir.Constant(i32, 2)], name="rng.tp"), name="rng.step"
    );
    return (start, stop, step);
}

impl NativeRangeEmitter._in_range(
    self: NativeRangeEmitter,
    ctx: NativeEmitCtx,
    val: ir.Value,
    start: ir.Value,
    stop: ir.Value,
    step: ir.Value
) -> ir.Value {
    b = ctx.pass_ref.builder;
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    diff = b.sub(val, start, name="rin.diff");
    rem = b.srem(diff, step, name="rin.rem");
    rem_zero = b.icmp_signed("==", rem, ir.Constant(i64, 0), name="rin.remz");
    step_pos = b.icmp_signed(">", step, ir.Constant(i64, 0), name="rin.spos");
    ge_start = b.icmp_signed(">=", val, start, name="rin.ges");
    lt_stop = b.icmp_signed("<", val, stop, name="rin.lts");
    pos_ok = b.and_(ge_start, lt_stop, name="rin.pok");
    le_start = b.icmp_signed("<=", val, start, name="rin.les");
    gt_stop = b.icmp_signed(">", val, stop, name="rin.gts");
    neg_ok = b.and_(le_start, gt_stop, name="rin.nok");
    bounds = b.select(step_pos, pos_ok, neg_ok, name="rin.bounds");
    return b.and_(rem_zero, bounds, name="rin.found");
}

impl NativeRangeEmitter.emit_count(
    self: NativeRangeEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    parts = self._load_range(ctx, target);
    if parts is None or not args {
        return None;
    }
    (start, stop, step) = parts;
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    val = p._coerce_type(args[0], i64);
    found = self._in_range(ctx, val, start, stop, step);
    return b.zext(found, i64, name="rng.count");
}

impl NativeRangeEmitter.emit_index(
    self: NativeRangeEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    parts = self._load_range(ctx, target);
    if parts is None or not args {
        return None;
    }
    (start, stop, step) = parts;
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    val = p._coerce_type(args[0], i64);
    diff = b.sub(val, start, name="ri.diff");
    idx = b.sdiv(diff, step, name="ri.idx");
    return idx;
}

impl NativeRangeEmitter.emit_op_eq(
    self: NativeRangeEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeRangeEmitter.emit_op_ne(
    self: NativeRangeEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeRangeEmitter.emit_op_contains(
    self: NativeRangeEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_print(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_input(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_len(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_abs(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    arg_val = args[0];
    b = ctx.pass_ref.builder;
    if isinstance(arg_val.type, ir.IntType) {
        if arg_val.type.width == 1 {
            return arg_val;
        }
        if ctx.arg_nodes and ctx.pass_ref._is_sized_node(ctx.arg_nodes[0]) {
            return ctx.pass_ref._emit_checked_abs(arg_val);
        }
        _zero = ir.Constant(arg_val.type, 0);
        _is_neg = b.icmp_signed("<", arg_val, _zero, name="abs.neg");
        _negv = b.neg(arg_val, name="abs.negv");
        return b.select(_is_neg, _negv, arg_val, name="abs");
    }
    if isinstance(arg_val.type, ir.DoubleType) {
        fabs_fn = ctx.pass_ref._get_or_declare_extern(
            "fabs", ir.DoubleType(), [ir.DoubleType()]
        );
        return b.call(fabs_fn, [arg_val], name="abs.fresult");
    }
    if isinstance(arg_val.type, ir.FloatType) {
        fabsf_fn = ctx.pass_ref._get_or_declare_extern(
            "fabsf", ir.FloatType(), [ir.FloatType()]
        );
        return b.call(fabsf_fn, [arg_val], name="abs.f32result");
    }
    return None;
}

impl NativeBuiltinEmitter.emit_round(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    arg_val = args[0];
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    if isinstance(arg_val.type, ir.DoubleType) {
        round_fn = p._get_or_declare_extern(
            "round", ir.DoubleType(), [ir.DoubleType()]
        );
        rounded = b.call(round_fn, [arg_val], name="round.f");
        return b.fptosi(rounded, i64, name="round.result");
    }

    if isinstance(arg_val.type, ir.IntType) {
        return arg_val;
    }
    return None;
}

impl NativeBuiltinEmitter.emit_min(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if len(args) < 2 {
        return None;
    }
    b = ctx.pass_ref.builder;
    a = args[0];
    v = args[1];
    if isinstance(a.type, ir.IntType) and isinstance(v.type, ir.IntType) {
        cmp = b.icmp_signed("<", a, v, name="min.cmp");
        return b.select(cmp, a, v, name="min.result");
    }
    if isinstance(a.type, ir.DoubleType) and isinstance(v.type, ir.DoubleType) {
        cmp = b.fcmp_ordered("<", a, v, name="min.fcmp");
        return b.select(cmp, a, v, name="min.fresult");
    }
    return None;
}

impl NativeBuiltinEmitter.emit_max(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if len(args) < 2 {
        return None;
    }
    b = ctx.pass_ref.builder;
    a = args[0];
    v = args[1];
    if isinstance(a.type, ir.IntType) and isinstance(v.type, ir.IntType) {
        cmp = b.icmp_signed(">", a, v, name="max.cmp");
        return b.select(cmp, a, v, name="max.result");
    }
    if isinstance(a.type, ir.DoubleType) and isinstance(v.type, ir.DoubleType) {
        cmp = b.fcmp_ordered(">", a, v, name="max.fcmp");
        return b.select(cmp, a, v, name="max.fresult");
    }
    return None;
}

impl NativeBuiltinEmitter.emit_sum(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    list_val = args[0];

    helpers: (dict | None) = None;
    elem_key: (str | None) = None;
    for (lk, lt) in p.list_types.items() {
        if list_val.type == lt.as_pointer() {
            helpers = p.list_helpers.get(lk);
            elem_key = lk;
            break;
        }
    }
    if helpers is None {
        return None;
    }
    list_len = b.call(helpers["len"], [list_val], name="sum.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="sum.loop");
    body_bb = func.append_basic_block(name="sum.body");
    done_bb = func.append_basic_block(name="sum.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="sum.idx");
    acc = b.phi(i64, name="sum.acc");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    acc.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, list_len, name="sum.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    elem = b.call(helpers["get"], [list_val, idx], name="sum.elem");
    new_acc = b.add(acc, elem, name="sum.add");
    next_idx = b.add(idx, ir.Constant(i64, 1), name="sum.next");
    idx.add_incoming(next_idx, body_bb);
    acc.add_incoming(new_acc, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return acc;
}

impl NativeBuiltinEmitter.emit_sorted(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    list_val = args[0];

    helpers: (dict | None) = None;
    elem_key: (str | None) = None;
    for (lk, lt) in p.list_types.items() {
        if list_val.type == lt.as_pointer() {
            helpers = p.list_helpers.get(lk);
            elem_key = lk;
            break;
        }
    }
    if helpers is None {
        return None;
    }
    _le = p._native_emitters.get("list") if p?._native_emitters else None;
    if not isinstance(_le, NativeListEmitter) {
        return None;
    }
    _ctx2 = ctx.__class__(
        pass_ref=p, type_key=elem_key or "", call_kwargs=(ctx?.call_kwargs or {})
    );

    sorted_copy = _le.emit_copy(_ctx2, list_val, []);
    if sorted_copy is None {
        return None;
    }
    if _le.emit_sort(_ctx2, sorted_copy, []) is None and (ctx?.call_kwargs or {}) {
        return None;
    }
    return sorted_copy;
}

impl NativeBuiltinEmitter.emit_reversed(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    list_val = args[0];

    helpers: (dict | None) = None;
    elem_key: (str | None) = None;
    for (lk, lt) in p.list_types.items() {
        if list_val.type == lt.as_pointer() {
            helpers = p.list_helpers.get(lk);
            elem_key = lk;
            break;
        }
    }
    if helpers is None {
        return None;
    }
    _le = p._native_emitters.get("list") if p?._native_emitters else None;
    if not isinstance(_le, NativeListEmitter) {
        return None;
    }
    _ctx2 = ctx.__class__(pass_ref=p, type_key=elem_key or "");

    rev_copy = _le.emit_copy(_ctx2, list_val, []);
    if rev_copy is None {
        return None;
    }
    _le.emit_reverse(_ctx2, rev_copy, []);
    return rev_copy;
}

impl NativeBuiltinEmitter.emit_enumerate(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_zip(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_map(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_filter(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_any(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    list_val = args[0];
    helpers: (dict | None) = None;
    for (lk, lt) in p.list_types.items() {
        if list_val.type == lt.as_pointer() {
            helpers = p.list_helpers.get(lk);
            break;
        }
    }
    if helpers is None {
        return None;
    }
    list_len = b.call(helpers["len"], [list_val], name="any.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="any.loop");
    body_bb = func.append_basic_block(name="any.body");
    found_bb = func.append_basic_block(name="any.found");
    done_bb = func.append_basic_block(name="any.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="any.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, list_len, name="any.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    elem = b.call(helpers["get"], [list_val, idx], name="any.elem");
    is_true = p._to_bool(elem);
    if not (isinstance(is_true.type, ir.IntType) and is_true.type.width == 1) {
        return None;
    }
    body_end = b.basic_block;
    next_idx = b.add(idx, ir.Constant(i64, 1), name="any.next");
    idx.add_incoming(next_idx, body_end);
    b.cbranch(is_true, found_bb, loop_bb);
    b.position_at_start(found_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result = b.phi(i64, name="any.result");
    result.add_incoming(ir.Constant(i64, 0), loop_bb);
    result.add_incoming(ir.Constant(i64, 1), found_bb);
    return result;
}

impl NativeBuiltinEmitter.emit_all(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    list_val = args[0];
    helpers: (dict | None) = None;
    for (lk, lt) in p.list_types.items() {
        if list_val.type == lt.as_pointer() {
            helpers = p.list_helpers.get(lk);
            break;
        }
    }
    if helpers is None {
        return None;
    }
    list_len = b.call(helpers["len"], [list_val], name="all.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="all.loop");
    body_bb = func.append_basic_block(name="all.body");
    false_bb = func.append_basic_block(name="all.false");
    done_bb = func.append_basic_block(name="all.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="all.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, list_len, name="all.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    elem = b.call(helpers["get"], [list_val, idx], name="all.elem");
    is_true = p._to_bool(elem);
    if not (isinstance(is_true.type, ir.IntType) and is_true.type.width == 1) {
        return None;
    }
    body_end = b.basic_block;
    next_idx = b.add(idx, ir.Constant(i64, 1), name="all.next");
    idx.add_incoming(next_idx, body_end);
    b.cbranch(is_true, loop_bb, false_bb);
    b.position_at_start(false_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result = b.phi(i64, name="all.result");
    result.add_incoming(ir.Constant(i64, 1), loop_bb);
    result.add_incoming(ir.Constant(i64, 0), false_bb);
    return result;
}

impl NativeBuiltinEmitter.emit_isinstance(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_divmod(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if len(args) < 2 {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    a = args[0];
    v = args[1];
    if isinstance(a.type, ir.IntType) and isinstance(v.type, ir.IntType) {
        izero = ir.Constant(i64, 0);
        is_zero = b.icmp_signed("==", v, izero, name="divmod.zero.chk");
        p._emit_runtime_raise(
            is_zero, "ZeroDivisionError", "integer division or modulo by zero"
        );
        (quot, rem) = p._codegen_int_floor_divmod(a, v);

        tuple_type = ir.LiteralStructType([i64, i64]);
        null_ptr = ir.Constant(tuple_type.as_pointer(), None);
        size_gep = b.gep(
            null_ptr, [ir.Constant(ir.IntType(32), 1)], name="divmod.sizeof.gep"
        );
        size = b.ptrtoint(size_gep, i64, name="divmod.sizeof");
        raw_ptr = b.call(p.rc_alloc_fn, [size], name="divmod.alloc");
        tuple_ptr = b.bitcast(raw_ptr, tuple_type.as_pointer(), name="divmod.ptr");

        q_ptr = b.gep(
            tuple_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)],
            name="divmod.q.ptr"
        );
        r_ptr = b.gep(
            tuple_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 1)],
            name="divmod.r.ptr"
        );
        b.store(quot, q_ptr);
        b.store(rem, r_ptr);

        tkey = f"Tuple.2.i64.i64";
        if tkey not in p.tuple_types {
            p.tuple_types[tkey] = tuple_type;
        }
        return tuple_ptr;
    }
    return None;
}

impl NativeBuiltinEmitter.emit_iter(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_next(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_callable(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_getattr(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_setattr(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_hasattr(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_delattr(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_vars(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_dir(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_open(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_format(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if len(args) < 2 {
        return None;
    }
    arg_val = args[0];
    spec_val = args[1];
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    rc_alloc_fn = p.rc_alloc_fn;
    snprintf = p._get_or_declare_extern(
        "snprintf", ir.IntType(32), [i8p, i64, i8p], var_arg=True
    );

    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    spec_len = p._call_str_len(b, spec_val, name="fmt.speclen");

    fmt_size = b.add(spec_len, ir.Constant(i64, 2), name="fmt.fmtsz");
    fmt_buf = b.call(rc_alloc_fn, [fmt_size], name="fmt.fmtbuf");

    b.store(ir.Constant(ir.IntType(8), 37), fmt_buf);

    fmt_rest = b.gep(fmt_buf, [ir.Constant(i64, 1)], name="fmt.rest");
    copy_len = b.add(spec_len, ir.Constant(i64, 1), name="fmt.copylen");
    b.call(memcpy_fn, [fmt_rest, spec_val, copy_len]);

    if isinstance(arg_val.type, ir.IntType) and arg_val.type.width == 1 {
        arg_val = b.zext(arg_val, i64, name="fmt.arg.zext");
    } elif isinstance(arg_val.type, ir.IntType) and arg_val.type.width != 64 {
        arg_val = b.sext(arg_val, i64, name="fmt.arg.sext");
    }
    need32 = b.call(
        snprintf,
        [ir.Constant(i8p, None), ir.Constant(i64, 0), fmt_buf, arg_val],
        name="fmt.need"
    );
    need = b.sext(need32, i64, name="fmt.need64");
    buf_size = b.add(need, ir.Constant(i64, 1), name="fmt.size");
    buf_ptr = p._str_alloc(b, buf_size, name="fmt.buf");
    b.call(snprintf, [buf_ptr, buf_size, fmt_buf, arg_val]);
    p._str_finish(b, buf_ptr, need);
    p._emit_rc_release_simple(fmt_buf, op="fmt_tmp", loc="");
    return buf_ptr;
}

impl NativeBuiltinEmitter.emit_ascii(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return self.emit_repr(ctx, args);
}

impl NativeBuiltinEmitter.emit_str(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    arg_val = args[0];
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();

    if p._is_bytes_value(arg_val) {
        return p._emit_bytes_repr(arg_val);
    }

    if isinstance(arg_val.type, ir.IntType) and arg_val.type.width == 1 {
        true_s = p._make_global_string("True", name_prefix=".str.true");
        false_s = p._make_global_string("False", name_prefix=".str.false");
        return b.select(arg_val, true_s, false_s, name="str.bool");
    }

    if isinstance(arg_val.type, ir.PointerType) {
        if arg_val.type != i8p {
            obj_s = p._emit_obj_str(arg_val);
            if obj_s is not None {
                return obj_s;
            }
            cont_s = p._emit_container_repr(arg_val, ctx.type_key or None);
            if cont_s is not None {
                return cont_s;
            }
            identity = b.bitcast(arg_val, i8p, name="str.identity");
            p._emit_rc_retain(identity, op="builtin_str_id");
            return identity;
        }

        none_s = p._make_global_string("None", name_prefix=".str.none");
        is_null = b.icmp_unsigned(
            "==", arg_val, ir.Constant(i8p, None), name="str.isnone"
        );
        result = b.select(is_null, none_s, arg_val, name="str.ornone");
        p._emit_rc_retain(result, op="builtin_str_id");
        return result;
    }

    if isinstance(arg_val.type, ir.DoubleType) {
        return p._emit_float_repr(arg_val);
    }

    if p?.jacval_type and arg_val.type == p.jacval_type {
        _jv_fn = p._str_jacval_fn();
        if _jv_fn is not None {
            return b.call(_jv_fn, [arg_val], name="str.jacval");
        }
    }
    if isinstance(arg_val.type, ir.LiteralStructType) {
        cont_s = p._emit_container_repr(arg_val, ctx.type_key or None);
        if cont_s is not None {
            return cont_s;
        }
    }
    buf_ptr = p._str_alloc(b, ir.Constant(ir.IntType(64), 32), name="str.buf");
    snprintf = p._get_or_declare_extern(
        "snprintf", ir.IntType(32), [i8p, ir.IntType(64), i8p], var_arg=True
    );

    fmt = p._get_snprintf_fmt("%ld");
    fmt_ptr = b.bitcast(fmt, i8p, name="str.fmt.ptr");
    str_n32 = b.call(
        snprintf,
        [buf_ptr, ir.Constant(ir.IntType(64), 32), fmt_ptr, arg_val],
        name="str.snprintf"
    );
    p._str_finish(b, buf_ptr, b.sext(str_n32, ir.IntType(64), name="str.len64"));
    return buf_ptr;
}

impl NativeBuiltinEmitter.emit_int(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    arg_val = args[0];
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);

    if isinstance(arg_val.type, ir.IntType) {
        if arg_val.type.width == 64 {
            return arg_val;
        }
        _src_node = ctx.arg_nodes[0] if ctx.arg_nodes else None;
        if arg_val.type.width > 1 and not p._is_unsigned_node(_src_node) {
            return b.sext(arg_val, i64, name="int.from.int");
        }
        return b.zext(arg_val, i64, name="int.from.int");
    }

    if isinstance(arg_val.type, ir.FloatType) {
        arg_val = b.fpext(arg_val, ir.DoubleType(), name="int.from.f32");
    }
    if isinstance(arg_val.type, ir.DoubleType) {
        return b.fptosi(arg_val, i64, name="int.from.float");
    }

    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    strtol_fn = p._get_or_declare_extern("strtol", i64, [i8p, i8p.as_pointer(), i32]);
    endptr_alloca = b.alloca(i8p, name="endptr");
    result_val = b.call(
        strtol_fn, [arg_val, endptr_alloca, ir.Constant(i32, 10)], name="strtol.result"
    );
    endptr_val = b.load(endptr_alloca, name="endptr.val");
    no_parse = b.icmp_unsigned("==", endptr_val, arg_val, name="int.noparse");
    p._emit_runtime_raise(no_parse, "ValueError", "invalid literal for int()");
    end_char = b.load(endptr_val, name="end.char");
    has_trail = b.icmp_unsigned(
        "!=", end_char, ir.Constant(ir.IntType(8), 0), name="int.trail"
    );
    p._emit_runtime_raise(has_trail, "ValueError", "invalid literal for int()");
    return result_val;
}

impl NativeBuiltinEmitter.emit_float(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    arg_val = args[0];
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);

    if isinstance(arg_val.type, ir.PointerType) {
        strtod_fn = p._get_or_declare_extern(
            "strtod", ir.DoubleType(), [i8p, i8p.as_pointer()]
        );
        endptr_alloca = b.alloca(i8p, name="float.endptr");
        result = b.call(strtod_fn, [arg_val, endptr_alloca], name="float.result");
        endptr_val = b.load(endptr_alloca, name="float.endptr.val");
        no_parse = b.icmp_unsigned("==", endptr_val, arg_val, name="float.noparse");
        p._emit_runtime_raise(
            no_parse, "ValueError", "could not convert string to float"
        );
        return result;
    }

    if isinstance(arg_val.type, ir.IntType) {
        _src_node = ctx.arg_nodes[0] if ctx.arg_nodes else None;
        if arg_val.type.width == 1 or p._is_unsigned_node(_src_node) {
            return b.uitofp(arg_val, ir.DoubleType(), name="float.from.uint");
        }
        return b.sitofp(arg_val, ir.DoubleType(), name="float.from.int");
    }
    if isinstance(arg_val.type, ir.DoubleType) {
        return arg_val;
    }
    if isinstance(arg_val.type, ir.FloatType) {
        return b.fpext(arg_val, ir.DoubleType(), name="float.from.f32");
    }
    return None;
}

impl NativeBuiltinEmitter.emit_bool(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    arg_val = args[0];
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    if isinstance(arg_val.type, ir.IntType) {
        is_nonzero = b.icmp_signed("!=", arg_val, ir.Constant(i64, 0), name="bool.nz");
        return b.zext(is_nonzero, i64, name="bool.result");
    }
    if isinstance(arg_val.type, ir.DoubleType) {
        is_nonzero = b.fcmp_ordered(
            "!=", arg_val, ir.Constant(ir.DoubleType(), 0.0), name="bool.fnz"
        );
        return b.zext(is_nonzero, i64, name="bool.fresult");
    }
    if isinstance(arg_val.type, ir.PointerType) {
        i8p = ir.IntType(8).as_pointer();
        if arg_val.type == i8p {
            slen = p._call_str_len(b, arg_val, name="bool.slen");
            is_nonempty = b.icmp_unsigned(
                "!=", slen, ir.Constant(i64, 0), name="bool.nonempty"
            );
            return b.zext(is_nonempty, i64, name="bool.sresult");
        }

        if p._is_bytes_value(arg_val) {
            return b.zext(p._emit_bytes_truthy(arg_val), i64, name="bool.byresult");
        }
    }

    return b.zext(p._to_bool(arg_val), i64, name="bool.result");
}

impl NativeBuiltinEmitter.emit_list(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    val = args[0];
    _opt_pl = p._opt_payload_of(val.type);
    if _opt_pl is not None {
        val = b.extract_value(val, 1, name="l.opt.payload");
    }

    for (sk, shelpers) in p.set_helpers.items() {
        stype = p.set_types.get(sk);
        if stype is not None and val.type == stype.as_pointer() {
            p._emit_list_helpers(sk, shelpers["elem_type"]);
            lhelpers = p.list_helpers.get(sk);
            if lhelpers is None {
                return None;
            }
            new_list = b.call(lhelpers["new"], [], name="l2l.new");
            set_len = b.call(shelpers["len"], [val], name="l2l.slen");
            func = b.basic_block.function;
            entry_bb = b.basic_block;
            loop_bb = func.append_basic_block(name="l2l.loop");
            body_bb = func.append_basic_block(name="l2l.body");
            done_bb = func.append_basic_block(name="l2l.done");
            b.branch(loop_bb);
            b.position_at_start(loop_bb);
            idx = b.phi(i64, name="l2l.idx");
            idx.add_incoming(ir.Constant(i64, 0), entry_bb);
            at_end = b.icmp_unsigned(">=", idx, set_len, name="l2l.end");
            b.cbranch(at_end, done_bb, body_bb);
            b.position_at_start(body_bb);
            elem = b.call(shelpers["get"], [val, idx], name="l2l.elem");
            b.call(lhelpers["append"], [new_list, elem]);
            nidx = b.add(idx, ir.Constant(i64, 1), name="l2l.nidx");
            idx.add_incoming(nidx, body_bb);
            b.branch(loop_bb);
            b.position_at_start(done_bb);
            return new_list;
        }
    }

    for (lk, lhelpers) in p.list_helpers.items() {
        ltype = p.list_types.get(lk);
        if ltype is not None and val.type == ltype.as_pointer() {
            _le = p?._native_emitters?.get("list");
            if not isinstance(_le, NativeListEmitter) {
                return None;
            }
            _ctx2 = ctx.__class__(pass_ref=p, type_key=lk);
            return _le.emit_copy(_ctx2, val, []);
        }
    }
    _vp_nm = getattr(val.type.pointee, "name", "")
        if isinstance(val.type, ir.PointerType)
        else "";
    if isinstance(_vp_nm, str) and _vp_nm.startswith("List.") {
        p._emit_list_helpers("ptr", ir.IntType(8).as_pointer());
        _lt_ptr = p.list_types.get("ptr");
        _le3 = p?._native_emitters?.get("list");
        if _lt_ptr is not None and isinstance(_le3, NativeListEmitter) {
            _lv = b.bitcast(val, _lt_ptr.as_pointer(), name="l.union.cast");
            _ctx3 = ctx.__class__(pass_ref=p, type_key="ptr");
            return _le3.emit_copy(_ctx3, _lv, []);
        }
    }
    return None;
}

impl NativeBuiltinEmitter.emit_dict(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    if not args {
        p._emit_dict_helpers(
            "ptr", "i64", ir.IntType(8).as_pointer(), ir.IntType(64), 0
        );
        helpers = p.dict_helpers.get("ptr:i64");
        if helpers is None {
            return None;
        }
        return b.call(helpers["new"], [], name="dctor.new");
    }

    val = args[0];
    for (dk, dhelpers) in p.dict_helpers.items() {
        dtype = p.dict_types.get(dk);
        if dtype is not None and val.type == dtype.as_pointer() {
            _de = p?._native_emitters?.get("dict");
            if not isinstance(_de, NativeDictEmitter) {
                return None;
            }
            _ctx2 = ctx.__class__(pass_ref=p, type_key=dk);
            return _de.emit_copy(_ctx2, val, []);
        }
    }
    return None;
}

impl NativeBuiltinEmitter.emit_set(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    val = args[0];

    for (lk, lhelpers) in p.list_helpers.items() {
        ltype = p.list_types.get(lk);
        if ltype is not None and val.type == ltype.as_pointer() {
            p._emit_set_helpers(lk, lhelpers["elem_type"]);
            shelpers = p.set_helpers.get(lk);
            if shelpers is None {
                return None;
            }
            new_set = b.call(shelpers["new"], [], name="l2s.new");
            list_len = b.call(lhelpers["len"], [val], name="l2s.llen");
            func = b.basic_block.function;
            entry_bb = b.basic_block;
            loop_bb = func.append_basic_block(name="l2s.loop");
            body_bb = func.append_basic_block(name="l2s.body");
            done_bb = func.append_basic_block(name="l2s.done");
            b.branch(loop_bb);
            b.position_at_start(loop_bb);
            idx = b.phi(i64, name="l2s.idx");
            idx.add_incoming(ir.Constant(i64, 0), entry_bb);
            at_end = b.icmp_unsigned(">=", idx, list_len, name="l2s.end");
            b.cbranch(at_end, done_bb, body_bb);
            b.position_at_start(body_bb);
            elem = b.call(lhelpers["get"], [val, idx], name="l2s.elem");
            b.call(shelpers["add"], [new_set, elem]);
            nidx = b.add(idx, ir.Constant(i64, 1), name="l2s.nidx");
            idx.add_incoming(nidx, body_bb);
            b.branch(loop_bb);
            b.position_at_start(done_bb);
            return new_set;
        }
    }

    for (sk, shelpers) in p.set_helpers.items() {
        stype = p.set_types.get(sk);
        if stype is not None and val.type == stype.as_pointer() {
            _se = p?._native_emitters?.get("set");
            if not isinstance(_se, NativeSetEmitter) {
                return None;
            }
            _ctx2 = ctx.__class__(pass_ref=p, type_key=sk);
            return _se.emit_copy(_ctx2, val, []);
        }
    }
    return None;
}

impl NativeBuiltinEmitter.emit_tuple(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_frozenset(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return self.emit_set(ctx, args);
}

impl NativeBuiltinEmitter.emit_bytes(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    val = args[0];
    if ("u8" in p.list_types and val.type == p.list_types["u8"].as_pointer()) {
        _src = p._bytearray_src_of(val);
        if _src is not None {
            return p._bytes_from_raw(_src[0], _src[1]);
        }
    }
    for (lk, lhelpers) in p.list_helpers.items() {
        ltype = p.list_types.get(lk);
        if ltype is not None and val.type == ltype.as_pointer() {
            list_len = b.call(lhelpers["len"], [val], name="bytes.len");
            bv = p._bytes_alloc(list_len);
            data = p._bytes_data_ptr(bv);
            func = b.basic_block.function;
            entry_bb = b.basic_block;
            loop_bb = func.append_basic_block(name="bytes.loop");
            body_bb = func.append_basic_block(name="bytes.body");
            done_bb = func.append_basic_block(name="bytes.done");
            b.branch(loop_bb);
            b.position_at_start(loop_bb);
            idx = b.phi(i64, name="bytes.idx");
            idx.add_incoming(ir.Constant(i64, 0), entry_bb);
            at_end = b.icmp_unsigned(">=", idx, list_len, name="bytes.end");
            b.cbranch(at_end, done_bb, body_bb);
            b.position_at_start(body_bb);
            elem = b.call(lhelpers["get"], [val, idx], name="bytes.elem");
            byte_val = b.trunc(elem, i8, name="bytes.trunc");
            bp = b.gep(data, [idx], name="bytes.bp");
            b.store(byte_val, bp);
            nidx = b.add(idx, ir.Constant(i64, 1), name="bytes.nidx");
            idx.add_incoming(nidx, body_bb);
            b.branch(loop_bb);
            b.position_at_start(done_bb);
            return bv;
        }
    }
    return None;
}

impl NativeBuiltinEmitter.emit_bytearray(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    p._ensure_bytearray_type();
    fns = p._bytearray_runtime_fns();
    buf = p._rc_call_with_ctx(
        p.list_helpers["u8"]["new"], [], op="new", loc="", name="ba.new"
    );
    if not args {
        return buf;
    }
    a0 = args[0];
    if isinstance(a0.type, ir.IntType) {
        n = p._coerce_type(a0, i64);
        b.call(fns["reserve"], [buf, n], name="");
        data_p = b.gep(
            buf, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="ba.z.data.p"
        );
        data = b.load(data_p, name="ba.z.data");
        b.call(fns["memset"], [data, ir.Constant(i32, 0), n], name="");
        len_p = b.gep(
            buf, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ba.z.len.p"
        );
        b.store(n, len_p);
        return buf;
    }
    src = p._bytearray_src_of(a0);
    if src is not None {
        b.call(fns["extend_raw"], [buf, src[0], src[1]], name="");
        return buf;
    }

    _bv = self.emit_bytes(ctx, [a0]);
    if _bv is not None and p._is_bytes_value(_bv) {
        _bsrc = p._bytearray_src_of(_bv);
        if _bsrc is not None {
            b.call(fns["extend_raw"], [buf, _bsrc[0], _bsrc[1]], name="");
            p._emit_rc_release_simple(_bv, op="ba_ctor_list", loc="");
            return buf;
        }
    }
    return None;
}

impl NativeBuiltinEmitter.emit_complex(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}
