"""Native (LLVM) backend primitive emitter implementations.

Each emitter is a stateless singleton; backend context is passed per-call
via NativeEmitCtx, which provides typed access to the LLVM builder and
pass infrastructure.

All methods currently return None, meaning the dispatch layer falls through
to the existing inline codegen in the pass impl files. As inline codegen is
extracted into emitter methods, they will return ir.Value results instead.
"""

import from llvmlite { ir }
import from jaclang.compiler.primitives {
    IntEmitter,
    FloatEmitter,
    ComplexEmitter,
    StrEmitter,
    BytesEmitter,
    ListEmitter,
    DictEmitter,
    SetEmitter,
    FrozensetEmitter,
    TupleEmitter,
    RangeEmitter,
    BuiltinEmitter
}

# --- Context ----------------------------------------------------------------
class NativeEmitCtx {
    """Native emission — provides typed access to LLVM infrastructure.

    Created per dispatch call with the appropriate type_key.
    """
    has pass_ref: object,
        type_key: str = "";

    def init(self, pass_ref: object, type_key: str = "") {
        self.pass_ref = pass_ref;
        self.type_key = type_key;
    }
}

# =============================================================================
#  Numeric Types
# =============================================================================
class NativeIntEmitter(IntEmitter[
    (ir.Value, NativeEmitCtx)
]) {
    def emit_bit_length(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_bit_count(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_to_bytes(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_as_integer_ratio(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_bit_length(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # bit_length: number of bits needed to represent abs(target), excluding sign and leading zeros
        # 0.bit_length() == 0, 1.bit_length() == 1, 255.bit_length() == 8
        p = ctx.pass_ref;
        b = p.builder;
        i64 = ir.IntType(64);
        zero = ir.Constant(i64, 0);
        one = ir.Constant(i64, 1);
        # abs(target)
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

    def emit_bit_count(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # bit_count: number of ones in the binary representation (popcount)
        p = ctx.pass_ref;
        b = p.builder;
        i64 = ir.IntType(64);
        zero = ir.Constant(i64, 0);
        one = ir.Constant(i64, 1);
        # Use abs value for negative numbers (Python counts bits of magnitude)
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

    def emit_conjugate(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # conjugate of an integer is itself
        return target;
    }

    def emit_from_bytes(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }
}

class NativeFloatEmitter(FloatEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_is_integer(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # is_integer: True if float has no fractional part
        p = ctx.pass_ref;
        b = p.builder;
        i64 = ir.IntType(64);
        # Convert to int and back, compare
        truncated = b.fptosi(target, i64, name="isint.trunc");
        roundtripped = b.sitofp(truncated, ir.DoubleType(), name="isint.rt");
        is_eq = b.fcmp_ordered("==", target, roundtripped, name="isint.eq");
        return b.zext(is_eq, i64, name="isint.result");
    }

    def emit_as_integer_ratio(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_conjugate(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # conjugate of a float is itself
        return target;
    }

    def emit_hex(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_fromhex(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }
}

class NativeComplexEmitter(ComplexEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_conjugate(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }
}

# =============================================================================
#  String Types
# =============================================================================
class NativeStrEmitter(StrEmitter[
    (ir.Value, NativeEmitCtx)
]) {
    # Case conversion
    def emit_capitalize(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # Capitalize: uppercase first char, lowercase the rest
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        toupper_fn = p._get_or_declare_extern("toupper", i32, [i32]);
        tolower_fn = p._get_or_declare_extern("tolower", i32, [i32]);
        slen = b.call(strlen_fn, [target], name="cap.len");
        alloc_size = b.add(slen, ir.Constant(i64, 1), name="cap.alloc.sz");
        result = b.call(gc_malloc, [alloc_size], name="cap.buf");
        is_empty = b.icmp_unsigned("==", slen, ir.Constant(i64, 0), name="cap.empty");
        func = b.basic_block.function;
        entry_bb = b.basic_block;
        first_bb = func.append_basic_block(name="cap.first");
        loop_bb = func.append_basic_block(name="cap.loop");
        body_bb = func.append_basic_block(name="cap.body");
        done_bb = func.append_basic_block(name="cap.done");
        b.cbranch(is_empty, done_bb, first_bb);
        # Uppercase the first character
        b.position_at_start(first_bb);
        first_ch = b.load(target, name="cap.first.ch");
        first_i32 = b.zext(first_ch, i32, name="cap.first.i32");
        upper_ch = b.call(toupper_fn, [first_i32], name="cap.first.upper");
        upper_i8 = b.trunc(upper_ch, i8, name="cap.first.i8");
        b.store(upper_i8, result);
        b.branch(loop_bb);
        # Lowercase remaining characters
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
        null_ptr = b.gep(result, [slen], name="cap.null.ptr");
        b.store(ir.Constant(i8, 0), null_ptr);
        return result;
    }

    def emit_casefold(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # casefold is equivalent to lower for ASCII
        return self._emit_case_transform(ctx, target, "tolower");
    }

    def emit_lower(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return self._emit_case_transform(ctx, target, "tolower");
    }

    def emit_upper(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return self._emit_case_transform(ctx, target, "toupper");
    }

    def _emit_case_transform(
        self, ctx: NativeEmitCtx, target: ir.Value, cfunc_name: str
    ) -> (ir.Value | None) {
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        slen = b.call(strlen_fn, [target], name="case.len");
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        alloc_size = b.add(slen, ir.Constant(i64, 1), name="case.alloc.sz");
        result = b.call(gc_malloc, [alloc_size], name="case.buf");
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
        null_ptr = b.gep(result, [slen], name="case.null.ptr");
        b.store(ir.Constant(i8, 0), null_ptr);
        return result;
    }

    def emit_title(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # title: uppercase first char of each word, lowercase rest
        # Word boundary = after non-alpha character
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        toupper_fn = p._get_or_declare_extern("toupper", i32, [i32]);
        tolower_fn = p._get_or_declare_extern("tolower", i32, [i32]);
        isalpha_fn = p._get_or_declare_extern("isalpha", i32, [i32]);
        slen = b.call(strlen_fn, [target], name="title.len");
        alloc_size = b.add(slen, ir.Constant(i64, 1), name="title.alloc");
        result = b.call(gc_malloc, [alloc_size], name="title.buf");
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
            is_alpha_bool,
            ir.Constant(i64, 0),
            ir.Constant(i64, 1),
            name="title.newbnd"
        );
        next_idx = b.add(idx, ir.Constant(i64, 1), name="title.next");
        idx.add_incoming(next_idx, body_bb);
        at_boundary.add_incoming(new_boundary, body_bb);
        b.branch(loop_bb);
        b.position_at_start(done_bb);
        null_ptr = b.gep(result, [slen], name="title.null.ptr");
        b.store(ir.Constant(i8, 0), null_ptr);
        return result;
    }

    def emit_swapcase(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # Swapcase: toupper if lower, tolower if upper
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        toupper_fn = p._get_or_declare_extern("toupper", i32, [i32]);
        tolower_fn = p._get_or_declare_extern("tolower", i32, [i32]);
        islower_fn = p._get_or_declare_extern("islower", i32, [i32]);
        isupper_fn = p._get_or_declare_extern("isupper", i32, [i32]);
        slen = b.call(strlen_fn, [target], name="swap.len");
        alloc_size = b.add(slen, ir.Constant(i64, 1), name="swap.alloc.sz");
        result = b.call(gc_malloc, [alloc_size], name="swap.buf");
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
        is_low_bool = b.icmp_signed(
            "!=", is_low, ir.Constant(i32, 0), name="swap.islo"
        );
        upper_ch = b.call(toupper_fn, [ch_i32], name="swap.upper");
        is_up = b.call(isupper_fn, [ch_i32], name="swap.isup");
        is_up_bool = b.icmp_signed(
            "!=", is_up, ir.Constant(i32, 0), name="swap.isup.b"
        );
        lower_ch = b.call(tolower_fn, [ch_i32], name="swap.lower");
        # If lower -> use upper, elif upper -> use lower, else keep original
        pick1 = b.select(is_up_bool, lower_ch, ch_i32, name="swap.pick1");
        pick2 = b.select(is_low_bool, upper_ch, pick1, name="swap.pick2");
        out_i8 = b.trunc(pick2, i8, name="swap.out");
        dst_ptr = b.gep(result, [idx], name="swap.dst.ptr");
        b.store(out_i8, dst_ptr);
        next_idx = b.add(idx, ir.Constant(i64, 1), name="swap.next");
        idx.add_incoming(next_idx, body_bb);
        b.branch(loop_bb);
        b.position_at_start(done_bb);
        null_ptr = b.gep(result, [slen], name="swap.null.ptr");
        b.store(ir.Constant(i8, 0), null_ptr);
        return result;
    }

    # Search
    def emit_count(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # Count non-overlapping occurrences of substring using strstr loop
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
        i8p = ir.IntType(8).as_pointer();
        i64 = ir.IntType(64);
        strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        sub_len = b.call(strlen_fn, [args[0]], name="cnt.sub.len");
        null_ptr = ir.Constant(i8p, None);
        func = b.basic_block.function;
        entry_bb = b.basic_block;
        loop_bb = func.append_basic_block(name="cnt.loop");
        found_bb = func.append_basic_block(name="cnt.found");
        done_bb = func.append_basic_block(name="cnt.done");
        b.branch(loop_bb);
        b.position_at_start(loop_bb);
        cur_ptr = b.phi(i8p, name="cnt.cur");
        count = b.phi(i64, name="cnt.count");
        cur_ptr.add_incoming(target, entry_bb);
        count.add_incoming(ir.Constant(i64, 0), entry_bb);
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
        return count;
    }

    def emit_find(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
        i8p = ir.IntType(8).as_pointer();
        i64 = ir.IntType(64);
        strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
        found = b.call(strstr_fn, [target, args[0]], name="find.ptr");
        null_ptr = ir.Constant(i8p, None);
        is_null = b.icmp_unsigned("==", found, null_ptr, name="find.null");
        target_int = b.ptrtoint(target, i64, name="find.tgt.int");
        found_int = b.ptrtoint(found, i64, name="find.fnd.int");
        diff = b.sub(found_int, target_int, name="find.diff");
        return b.select(is_null, ir.Constant(i64, -1), diff, name="find.result");
    }

    def emit_rfind(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # rfind: find last occurrence of substring, return index or -1
        # Empty substring returns len(target) matching Python semantics
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
        i8p = ir.IntType(8).as_pointer();
        i64 = ir.IntType(64);
        strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        slen = b.call(strlen_fn, [target], name="rfind.slen");
        sub_len = b.call(strlen_fn, [args[0]], name="rfind.sub.len");
        null_ptr = ir.Constant(i8p, None);
        target_int = b.ptrtoint(target, i64, name="rfind.tgt.int");
        func = b.basic_block.function;
        entry_bb = b.basic_block;
        # Handle empty substring: return len(target)
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

    def emit_index(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # index: like find but raises ValueError if not found
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
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

    def emit_rindex(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # rindex: like rfind but raises ValueError if not found
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
        i64 = ir.IntType(64);
        # Reuse rfind logic
        rfind_result = self.emit_rfind(ctx, target, args);
        if rfind_result is None {
            return None;
        }
        is_neg = b.icmp_signed(
            "<", rfind_result, ir.Constant(i64, 0), name="rindex.neg"
        );
        p._emit_runtime_raise(is_neg, "ValueError", "substring not found");
        return rfind_result;
    }

    def emit_startswith(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
        i8p = ir.IntType(8).as_pointer();
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        strncmp_fn = p._get_or_declare_extern("strncmp", i32, [i8p, i8p, i64]);
        prefix_len = b.call(strlen_fn, [args[0]], name="sw.pfx.len");
        cmp = b.call(strncmp_fn, [target, args[0], prefix_len], name="sw.cmp");
        is_zero = b.icmp_signed("==", cmp, ir.Constant(i32, 0), name="sw.eq");
        return b.zext(is_zero, i64, name="sw.result");
    }

    def emit_endswith(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
        i8p = ir.IntType(8).as_pointer();
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        strcmp_fn = p._get_or_declare_extern("strcmp", i32, [i8p, i8p]);
        target_len = b.call(strlen_fn, [target], name="ew.tgt.len");
        suffix_len = b.call(strlen_fn, [args[0]], name="ew.sfx.len");
        too_long = b.icmp_unsigned(">", suffix_len, target_len, name="ew.toolong");
        offset = b.sub(target_len, suffix_len, name="ew.offset");
        end_ptr = b.gep(target, [offset], name="ew.end.ptr");
        cmp = b.call(strcmp_fn, [end_ptr, args[0]], name="ew.cmp");
        is_match = b.icmp_signed("==", cmp, ir.Constant(i32, 0), name="ew.match");
        match_i64 = b.zext(is_match, i64, name="ew.match.i64");
        return b.select(too_long, ir.Constant(i64, 0), match_i64, name="ew.result");
    }

    # Modification
    def emit_replace(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # replace(old, new): replace all occurrences
        if len(args) < 2 {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
        old_str = args[0];
        new_str = args[1];
        target_len = b.call(strlen_fn, [target], name="repl.tgt.len");
        old_len = b.call(strlen_fn, [old_str], name="repl.old.len");
        new_len = b.call(strlen_fn, [new_str], name="repl.new.len");
        # Worst-case allocation: every char replaced
        generous_factor = b.add(new_len, ir.Constant(i64, 1), name="repl.factor");
        generous_size = b.mul(target_len, generous_factor, name="repl.generous");
        alloc_size = b.add(generous_size, ir.Constant(i64, 1), name="repl.alloc");
        result = b.call(gc_malloc, [alloc_size], name="repl.buf");
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
        src.add_incoming(target, entry_bb);
        dst_off.add_incoming(ir.Constant(i64, 0), entry_bb);
        found = b.call(strstr_fn, [src, old_str], name="repl.found.ptr");
        is_null = b.icmp_unsigned("==", found, null_ptr, name="repl.null");
        b.cbranch(is_null, notfound_bb, found_bb);
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
        src.add_incoming(next_src, found_bb);
        dst_off.add_incoming(dst_off3, found_bb);
        b.branch(loop_bb);
        b.position_at_start(notfound_bb);
        remain_len = b.call(strlen_fn, [src], name="repl.remain.len");
        dst_ptr3 = b.gep(result, [dst_off], name="repl.dst.ptr3");
        b.call(memcpy_fn, [dst_ptr3, src, remain_len]);
        final_len = b.add(dst_off, remain_len, name="repl.final.len");
        null_term = b.gep(result, [final_len], name="repl.null.term");
        b.store(ir.Constant(i8, 0), null_term);
        b.branch(done_bb);
        b.position_at_start(done_bb);
        return result;
    }

    def emit_strip(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return ctx.pass_ref._codegen_str_strip(target);
    }

    def emit_lstrip(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # lstrip: skip leading whitespace, return new string
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        isspace_fn = p._get_or_declare_extern("isspace", i32, [i32]);
        strcpy_fn = p._get_or_declare_extern("strcpy", i8p, [i8p, i8p]);
        slen = b.call(strlen_fn, [target], name="lstrip.len");
        func = b.basic_block.function;
        entry_bb = b.basic_block;
        loop_bb = func.append_basic_block(name="lstrip.loop");
        body_bb = func.append_basic_block(name="lstrip.body");
        done_bb = func.append_basic_block(name="lstrip.done");
        b.branch(loop_bb);
        b.position_at_start(loop_bb);
        idx = b.phi(i64, name="lstrip.idx");
        idx.add_incoming(ir.Constant(i64, 0), entry_bb);
        at_end = b.icmp_unsigned(">=", idx, slen, name="lstrip.atend");
        b.cbranch(at_end, done_bb, body_bb);
        b.position_at_start(body_bb);
        ch_ptr = b.gep(target, [idx], name="lstrip.ch.ptr");
        ch = b.load(ch_ptr, name="lstrip.ch");
        ch_i32 = b.zext(ch, i32, name="lstrip.ch.i32");
        is_sp = b.call(isspace_fn, [ch_i32], name="lstrip.issp");
        is_sp_bool = b.icmp_signed(
            "!=", is_sp, ir.Constant(i32, 0), name="lstrip.issp.b"
        );
        next_idx = b.add(idx, ir.Constant(i64, 1), name="lstrip.next");
        idx.add_incoming(next_idx, body_bb);
        b.cbranch(is_sp_bool, loop_bb, done_bb);
        b.position_at_start(done_bb);
        start = b.phi(i64, name="lstrip.start");
        start.add_incoming(idx, loop_bb);
        start.add_incoming(idx, body_bb);
        new_len = b.sub(slen, start, name="lstrip.newlen");
        alloc_size = b.add(new_len, ir.Constant(i64, 1), name="lstrip.alloc");
        result = b.call(gc_malloc, [alloc_size], name="lstrip.buf");
        start_ptr = b.gep(target, [start], name="lstrip.start.ptr");
        b.call(strcpy_fn, [result, start_ptr]);
        return result;
    }

    def emit_rstrip(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # rstrip: remove trailing whitespace
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        isspace_fn = p._get_or_declare_extern("isspace", i32, [i32]);
        memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
        slen = b.call(strlen_fn, [target], name="rstrip.len");
        func = b.basic_block.function;
        entry_bb = b.basic_block;
        loop_bb = func.append_basic_block(name="rstrip.loop");
        body_bb = func.append_basic_block(name="rstrip.body");
        done_bb = func.append_basic_block(name="rstrip.done");
        b.branch(loop_bb);
        b.position_at_start(loop_bb);
        end = b.phi(i64, name="rstrip.end");
        end.add_incoming(slen, entry_bb);
        is_zero = b.icmp_unsigned("==", end, ir.Constant(i64, 0), name="rstrip.iszero");
        b.cbranch(is_zero, done_bb, body_bb);
        b.position_at_start(body_bb);
        prev = b.sub(end, ir.Constant(i64, 1), name="rstrip.prev");
        ch_ptr = b.gep(target, [prev], name="rstrip.ch.ptr");
        ch = b.load(ch_ptr, name="rstrip.ch");
        ch_i32 = b.zext(ch, i32, name="rstrip.ch.i32");
        is_sp = b.call(isspace_fn, [ch_i32], name="rstrip.issp");
        is_sp_bool = b.icmp_signed(
            "!=", is_sp, ir.Constant(i32, 0), name="rstrip.issp.b"
        );
        end.add_incoming(prev, body_bb);
        b.cbranch(is_sp_bool, loop_bb, done_bb);
        b.position_at_start(done_bb);
        final_end = b.phi(i64, name="rstrip.final.end");
        final_end.add_incoming(end, loop_bb);
        final_end.add_incoming(end, body_bb);
        alloc_size = b.add(final_end, ir.Constant(i64, 1), name="rstrip.alloc");
        result = b.call(gc_malloc, [alloc_size], name="rstrip.buf");
        b.call(memcpy_fn, [result, target, final_end]);
        null_ptr = b.gep(result, [final_end], name="rstrip.null.ptr");
        b.store(ir.Constant(i8, 0), null_ptr);
        return result;
    }

    def emit_removeprefix(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        strncmp_fn = p._get_or_declare_extern("strncmp", i32, [i8p, i8p, i64]);
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        strcpy_fn = p._get_or_declare_extern("strcpy", i8p, [i8p, i8p]);
        prefix_len = b.call(strlen_fn, [args[0]], name="rmpfx.pfx.len");
        target_len = b.call(strlen_fn, [target], name="rmpfx.tgt.len");
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
        # Matched: return target + prefix_len
        b.position_at_start(match_bb);
        rest_len = b.sub(target_len, prefix_len, name="rmpfx.rest.len");
        alloc_m = b.add(rest_len, ir.Constant(i64, 1), name="rmpfx.alloc.m");
        result_m = b.call(gc_malloc, [alloc_m], name="rmpfx.buf.m");
        rest_ptr = b.gep(target, [prefix_len], name="rmpfx.rest.ptr");
        b.call(strcpy_fn, [result_m, rest_ptr]);
        b.branch(done_bb);
        # Not matched: return copy of original
        b.position_at_start(nomatch_bb);
        alloc_n = b.add(target_len, ir.Constant(i64, 1), name="rmpfx.alloc.n");
        result_n = b.call(gc_malloc, [alloc_n], name="rmpfx.buf.n");
        b.call(strcpy_fn, [result_n, target]);
        b.branch(done_bb);
        b.position_at_start(done_bb);
        result_phi = b.phi(i8p, name="rmpfx.result");
        result_phi.add_incoming(result_m, match_bb);
        result_phi.add_incoming(result_n, nomatch_bb);
        return result_phi;
    }

    def emit_removesuffix(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        strcmp_fn = p._get_or_declare_extern("strcmp", i32, [i8p, i8p]);
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
        suffix_len = b.call(strlen_fn, [args[0]], name="rmsfx.sfx.len");
        target_len = b.call(strlen_fn, [target], name="rmsfx.tgt.len");
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
        cmp = b.call(strcmp_fn, [end_ptr, args[0]], name="rmsfx.cmp");
        is_match = b.icmp_signed("==", cmp, ir.Constant(i32, 0), name="rmsfx.eq");
        b.cbranch(is_match, match_bb, nomatch_bb);
        # Matched: copy without suffix
        b.position_at_start(match_bb);
        new_len = b.sub(target_len, suffix_len, name="rmsfx.newlen");
        alloc_m = b.add(new_len, ir.Constant(i64, 1), name="rmsfx.alloc.m");
        result_m = b.call(gc_malloc, [alloc_m], name="rmsfx.buf.m");
        b.call(memcpy_fn, [result_m, target, new_len]);
        null_ptr_m = b.gep(result_m, [new_len], name="rmsfx.null.m");
        b.store(ir.Constant(i8, 0), null_ptr_m);
        b.branch(done_bb);
        # Not matched: copy original
        b.position_at_start(nomatch_bb);
        alloc_n = b.add(target_len, ir.Constant(i64, 1), name="rmsfx.alloc.n");
        result_n = b.call(gc_malloc, [alloc_n], name="rmsfx.buf.n");
        b.call(memcpy_fn, [result_n, target, target_len]);
        null_ptr_n = b.gep(result_n, [target_len], name="rmsfx.null.n");
        b.store(ir.Constant(i8, 0), null_ptr_n);
        b.branch(done_bb);
        b.position_at_start(done_bb);
        result_phi = b.phi(i8p, name="rmsfx.result");
        result_phi.add_incoming(result_m, match_bb);
        result_phi.add_incoming(result_n, nomatch_bb);
        return result_phi;
    }

    # Split and join
    def emit_split(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        if args {
            return ctx.pass_ref._codegen_str_split(target, args[0]);
        }
        return None;
    }

    def emit_rsplit(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_splitlines(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_join(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # join(list): concatenate list elements with separator (target)
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i64 = ir.IntType(64);
        zero = ir.Constant(i64, 0);
        one = ir.Constant(i64, 1);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
        # Ensure list helpers for "ptr" (string list)
        p._emit_list_helpers("ptr", i8p);
        lhelpers = p.list_helpers.get("ptr");
        if lhelpers is None {
            return None;
        }
        the_list = args[0];
        sep_len = b.call(strlen_fn, [target], name="jn.seplen");
        list_len = b.call(lhelpers["len"], [the_list], name="jn.listlen");
        func = b.basic_block.function;
        # Check if list is empty
        is_empty = b.icmp_unsigned("==", list_len, zero, name="jn.isempty");
        empty_bb = func.append_basic_block(name="jn.empty");
        pass1_bb = func.append_basic_block(name="jn.pass1");
        done_bb = func.append_basic_block(name="jn.done");
        b.cbranch(is_empty, empty_bb, pass1_bb);
        # Empty list: return empty string
        b.position_at_start(empty_bb);
        empty_buf = b.call(gc_malloc, [one], name="jn.empty.buf");
        b.store(ir.Constant(i8, 0), empty_buf);
        b.branch(done_bb);
        # Pass 1: compute total length
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
        elen = b.call(strlen_fn, [elem], name="jn.p1.elen");
        new_total = b.add(p1_total, elen, name="jn.p1.ntot");
        next_p1 = b.add(p1_idx, one, name="jn.p1.next");
        p1_idx.add_incoming(next_p1, body1_bb);
        p1_total.add_incoming(new_total, body1_bb);
        b.branch(loop1_bb);
        # Calculate total with separators
        b.position_at_start(pass2_start);
        total_phi = b.phi(i64, name="jn.total");
        total_phi.add_incoming(p1_total, loop1_bb);
        sep_count = b.sub(list_len, one, name="jn.sepcount");
        sep_total = b.mul(sep_len, sep_count, name="jn.septotal");
        grand_total = b.add(total_phi, sep_total, name="jn.grand");
        alloc_sz = b.add(grand_total, one, name="jn.alloc");
        buf = b.call(gc_malloc, [alloc_sz], name="jn.buf");
        # Pass 2: copy elements with separator
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
        elen2 = b.call(strlen_fn, [elem2], name="jn.p2.elen");
        dst2 = b.gep(buf, [p2_off], name="jn.p2.dst");
        b.call(memcpy_fn, [dst2, elem2, elen2]);
        off_after_elem = b.add(p2_off, elen2, name="jn.p2.off2");
        b.branch(sep_check);
        # Check if need separator
        b.position_at_start(sep_check);
        next_p2 = b.add(p2_idx, one, name="jn.p2.next");
        is_last = b.icmp_unsigned(">=", next_p2, list_len, name="jn.p2.islast");
        b.cbranch(is_last, next_iter, sep_copy);
        b.position_at_start(sep_copy);
        sep_dst = b.gep(buf, [off_after_elem], name="jn.p2.sepdst");
        b.call(memcpy_fn, [sep_dst, target, sep_len]);
        off_after_sep = b.add(off_after_elem, sep_len, name="jn.p2.off3");
        b.branch(next_iter);
        # Merge offset
        b.position_at_start(next_iter);
        merged_off = b.phi(i64, name="jn.p2.moff");
        merged_off.add_incoming(off_after_elem, sep_check);
        merged_off.add_incoming(off_after_sep, sep_copy);
        p2_idx.add_incoming(next_p2, next_iter);
        p2_off.add_incoming(merged_off, next_iter);
        b.branch(loop2_bb);
        # Null-terminate
        b.position_at_start(copy_done);
        final_off = b.phi(i64, name="jn.final.off");
        final_off.add_incoming(p2_off, loop2_bb);
        null_p = b.gep(buf, [final_off], name="jn.null");
        b.store(ir.Constant(i8, 0), null_p);
        b.branch(done_bb);
        # Done
        b.position_at_start(done_bb);
        result = b.phi(i8p, name="jn.result");
        result.add_incoming(empty_buf, empty_bb);
        result.add_incoming(buf, copy_done);
        return result;
    }

    def emit_partition(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_rpartition(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    # Formatting and alignment
    def emit_format(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_format_map(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_center(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # center(width): center string, pad with spaces on both sides
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
        memset_fn = p._get_or_declare_extern("memset", i8p, [i8p, ir.IntType(32), i64]);
        slen = b.call(strlen_fn, [target], name="center.len");
        width = args[0];
        needs_pad = b.icmp_unsigned("<", slen, width, name="center.needspad");
        func = b.basic_block.function;
        pad_bb = func.append_basic_block(name="center.pad");
        nopad_bb = func.append_basic_block(name="center.nopad");
        done_bb = func.append_basic_block(name="center.done");
        b.cbranch(needs_pad, pad_bb, nopad_bb);
        # Pad case: match CPython formula: left = marg//2 + (marg & width & 1)
        b.position_at_start(pad_bb);
        total_pad = b.sub(width, slen, name="center.totalpad");
        half = b.udiv(total_pad, ir.Constant(i64, 2), name="center.half");
        tp_and_w = b.and_(total_pad, width, name="center.tpw");
        adj = b.and_(tp_and_w, ir.Constant(i64, 1), name="center.adj");
        left_pad = b.add(half, adj, name="center.lpad");
        right_pad = b.sub(total_pad, left_pad, name="center.rpad");
        alloc_pad = b.add(width, ir.Constant(i64, 1), name="center.alloc");
        buf_pad = b.call(gc_malloc, [alloc_pad], name="center.buf");
        # Fill left padding with spaces
        b.call(memset_fn, [buf_pad, ir.Constant(ir.IntType(32), 32), left_pad]);
        # Copy string after left padding
        str_ptr = b.gep(buf_pad, [left_pad], name="center.str.ptr");
        b.call(memcpy_fn, [str_ptr, target, slen]);
        # Fill right padding with spaces
        right_ptr = b.gep(str_ptr, [slen], name="center.rpad.ptr");
        b.call(memset_fn, [right_ptr, ir.Constant(ir.IntType(32), 32), right_pad]);
        # Null terminate
        null_pad = b.gep(buf_pad, [width], name="center.null");
        b.store(ir.Constant(i8, 0), null_pad);
        b.branch(done_bb);
        # No pad: return copy
        b.position_at_start(nopad_bb);
        alloc_nopad = b.add(slen, ir.Constant(i64, 1), name="center.alloc.np");
        buf_nopad = b.call(gc_malloc, [alloc_nopad], name="center.buf.np");
        b.call(memcpy_fn, [buf_nopad, target, slen]);
        null_nopad = b.gep(buf_nopad, [slen], name="center.null.np");
        b.store(ir.Constant(i8, 0), null_nopad);
        b.branch(done_bb);
        b.position_at_start(done_bb);
        result = b.phi(i8p, name="center.result");
        result.add_incoming(buf_pad, pad_bb);
        result.add_incoming(buf_nopad, nopad_bb);
        return result;
    }

    def emit_ljust(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # ljust(width): left-justify, pad with spaces on right
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
        memset_fn = p._get_or_declare_extern("memset", i8p, [i8p, ir.IntType(32), i64]);
        slen = b.call(strlen_fn, [target], name="ljust.len");
        width = args[0];
        needs_pad = b.icmp_unsigned("<", slen, width, name="ljust.needspad");
        func = b.basic_block.function;
        pad_bb = func.append_basic_block(name="ljust.pad");
        nopad_bb = func.append_basic_block(name="ljust.nopad");
        done_bb = func.append_basic_block(name="ljust.done");
        b.cbranch(needs_pad, pad_bb, nopad_bb);
        # Pad case: copy string + fill spaces
        b.position_at_start(pad_bb);
        alloc_pad = b.add(width, ir.Constant(i64, 1), name="ljust.alloc");
        buf_pad = b.call(gc_malloc, [alloc_pad], name="ljust.buf");
        b.call(memcpy_fn, [buf_pad, target, slen]);
        pad_ptr = b.gep(buf_pad, [slen], name="ljust.pad.ptr");
        pad_len = b.sub(width, slen, name="ljust.pad.len");
        b.call(memset_fn, [pad_ptr, ir.Constant(ir.IntType(32), 32), pad_len]);
        null_pad = b.gep(buf_pad, [width], name="ljust.null");
        b.store(ir.Constant(i8, 0), null_pad);
        b.branch(done_bb);
        # No pad: return copy
        b.position_at_start(nopad_bb);
        alloc_nopad = b.add(slen, ir.Constant(i64, 1), name="ljust.alloc.np");
        buf_nopad = b.call(gc_malloc, [alloc_nopad], name="ljust.buf.np");
        b.call(memcpy_fn, [buf_nopad, target, slen]);
        null_nopad = b.gep(buf_nopad, [slen], name="ljust.null.np");
        b.store(ir.Constant(i8, 0), null_nopad);
        b.branch(done_bb);
        b.position_at_start(done_bb);
        result = b.phi(i8p, name="ljust.result");
        result.add_incoming(buf_pad, pad_bb);
        result.add_incoming(buf_nopad, nopad_bb);
        return result;
    }

    def emit_rjust(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # rjust(width): right-justify, pad with spaces on left
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
        memset_fn = p._get_or_declare_extern("memset", i8p, [i8p, ir.IntType(32), i64]);
        slen = b.call(strlen_fn, [target], name="rjust.len");
        width = args[0];
        needs_pad = b.icmp_unsigned("<", slen, width, name="rjust.needspad");
        func = b.basic_block.function;
        pad_bb = func.append_basic_block(name="rjust.pad");
        nopad_bb = func.append_basic_block(name="rjust.nopad");
        done_bb = func.append_basic_block(name="rjust.done");
        b.cbranch(needs_pad, pad_bb, nopad_bb);
        b.position_at_start(pad_bb);
        alloc_pad = b.add(width, ir.Constant(i64, 1), name="rjust.alloc");
        buf_pad = b.call(gc_malloc, [alloc_pad], name="rjust.buf");
        pad_len = b.sub(width, slen, name="rjust.pad.len");
        b.call(memset_fn, [buf_pad, ir.Constant(ir.IntType(32), 32), pad_len]);
        str_dst = b.gep(buf_pad, [pad_len], name="rjust.str.dst");
        b.call(memcpy_fn, [str_dst, target, slen]);
        null_pad = b.gep(buf_pad, [width], name="rjust.null");
        b.store(ir.Constant(i8, 0), null_pad);
        b.branch(done_bb);
        b.position_at_start(nopad_bb);
        alloc_nopad = b.add(slen, ir.Constant(i64, 1), name="rjust.alloc.np");
        buf_nopad = b.call(gc_malloc, [alloc_nopad], name="rjust.buf.np");
        b.call(memcpy_fn, [buf_nopad, target, slen]);
        null_nopad = b.gep(buf_nopad, [slen], name="rjust.null.np");
        b.store(ir.Constant(i8, 0), null_nopad);
        b.branch(done_bb);
        b.position_at_start(done_bb);
        result = b.phi(i8p, name="rjust.result");
        result.add_incoming(buf_pad, pad_bb);
        result.add_incoming(buf_nopad, nopad_bb);
        return result;
    }

    def emit_zfill(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # zfill(width): pad with '0' on left, keeping sign char
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
        memset_fn = p._get_or_declare_extern("memset", i8p, [i8p, ir.IntType(32), i64]);
        slen = b.call(strlen_fn, [target], name="zfill.len");
        width = args[0];
        needs_pad = b.icmp_unsigned("<", slen, width, name="zfill.needspad");
        func = b.basic_block.function;
        pad_bb = func.append_basic_block(name="zfill.pad");
        nopad_bb = func.append_basic_block(name="zfill.nopad");
        done_bb = func.append_basic_block(name="zfill.done");
        b.cbranch(needs_pad, pad_bb, nopad_bb);
        # Pad case: check for sign char
        b.position_at_start(pad_bb);
        alloc_pad = b.add(width, ir.Constant(i64, 1), name="zfill.alloc");
        buf_pad = b.call(gc_malloc, [alloc_pad], name="zfill.buf");
        first_ch = b.load(target, name="zfill.first");
        is_plus = b.icmp_unsigned(
            "==", first_ch, ir.Constant(i8, 43), name="zfill.plus"
        );
        is_minus = b.icmp_unsigned(
            "==", first_ch, ir.Constant(i8, 45), name="zfill.minus"
        );
        has_sign = b.or_(is_plus, is_minus, name="zfill.hassign");
        pad_len = b.sub(width, slen, name="zfill.pad.len");
        # If sign: write sign char first, then zeros, then rest of string
        sign_off = b.select(
            has_sign, ir.Constant(i64, 1), ir.Constant(i64, 0), name="zfill.soff"
        );
        # Store sign char at position 0 if present
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
        null_pad = b.gep(buf_pad, [width], name="zfill.null");
        b.store(ir.Constant(i8, 0), null_pad);
        b.branch(done_bb);
        # No pad: return copy
        b.position_at_start(nopad_bb);
        alloc_nopad = b.add(slen, ir.Constant(i64, 1), name="zfill.alloc.np");
        buf_nopad = b.call(gc_malloc, [alloc_nopad], name="zfill.buf.np");
        b.call(memcpy_fn, [buf_nopad, target, slen]);
        null_nopad = b.gep(buf_nopad, [slen], name="zfill.null.np");
        b.store(ir.Constant(i8, 0), null_nopad);
        b.branch(done_bb);
        b.position_at_start(done_bb);
        result = b.phi(i8p, name="zfill.result");
        result.add_incoming(buf_pad, merge_bb);
        result.add_incoming(buf_nopad, nopad_bb);
        return result;
    }

    def emit_expandtabs(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # expandtabs(tabsize=8): replace tabs with spaces to next tab stop
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i64 = ir.IntType(64);
        zero = ir.Constant(i64, 0);
        one = ir.Constant(i64, 1);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        slen = b.call(strlen_fn, [target], name="et.len");
        # tabsize: default 8 if no args
        if args {
            tabsize = args[0];
        } else {
            tabsize = ir.Constant(i64, 8);
        }
        # Worst case allocation: every char is a tab → slen * max(tabsize, 1) + 1
        ts_or_one = b.select(
            b.icmp_unsigned("==", tabsize, zero), one, tabsize, name="et.ts1"
        );
        worst = b.mul(slen, ts_or_one, name="et.worst");
        alloc_sz = b.add(worst, one, name="et.alloc");
        buf = b.call(gc_malloc, [alloc_sz], name="et.buf");
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
        # Main loop header with phi nodes
        b.position_at_start(loop_bb);
        si = b.phi(i64, name="et.si");
        di = b.phi(i64, name="et.di");
        col = b.phi(i64, name="et.col");
        si.add_incoming(zero, entry_bb);
        di.add_incoming(zero, entry_bb);
        col.add_incoming(zero, entry_bb);
        # Load current char
        cp = b.gep(target, [si], name="et.cp");
        ch = b.load(cp, name="et.ch");
        is_end = b.icmp_unsigned("==", ch, ir.Constant(i8, 0), name="et.end");
        b.cbranch(is_end, done_bb, check_tab);
        # Check if tab char (0x09)
        b.position_at_start(check_tab);
        is_tab = b.icmp_unsigned("==", ch, ir.Constant(i8, 9), name="et.istab");
        b.cbranch(is_tab, do_tab, check_nl);
        # Tab: calculate spaces = tabsize - (col % tabsize), min 1
        b.position_at_start(do_tab);
        is_ts_zero = b.icmp_unsigned("==", tabsize, zero, name="et.ts0");
        # If tabsize==0, spaces=0; else spaces = tabsize - (col % tabsize)
        col_mod = b.urem(col, ts_or_one, name="et.colmod");
        spaces_calc = b.sub(tabsize, col_mod, name="et.spcalc");
        spaces = b.select(is_ts_zero, zero, spaces_calc, name="et.spaces");
        b.branch(tab_loop);
        # Tab fill loop
        b.position_at_start(tab_loop);
        ti = b.phi(i64, name="et.ti");
        di_t = b.phi(i64, name="et.di.t");
        ti.add_incoming(zero, do_tab);
        di_t.add_incoming(di, do_tab);
        ti_done = b.icmp_unsigned(">=", ti, spaces, name="et.tidone");
        b.cbranch(ti_done, tab_done, tab_write);
        # Write one space
        b.position_at_start(tab_write);
        dp = b.gep(buf, [di_t], name="et.dp.tw");
        b.store(ir.Constant(i8, 32), dp);
        next_ti = b.add(ti, one, name="et.nti");
        next_di_t = b.add(di_t, one, name="et.ndi.t");
        ti.add_incoming(next_ti, tab_write);
        di_t.add_incoming(next_di_t, tab_write);
        b.branch(tab_loop);
        # After tab fill
        b.position_at_start(tab_done);
        new_col_tab = b.add(col, spaces, name="et.col.tab");
        next_si_tab = b.add(si, one, name="et.si.tab");
        b.branch(next_bb);
        # Check newline/carriage return
        b.position_at_start(check_nl);
        is_nl = b.icmp_unsigned("==", ch, ir.Constant(i8, 10), name="et.isnl");
        is_cr = b.icmp_unsigned("==", ch, ir.Constant(i8, 13), name="et.iscr");
        is_line_end = b.or_(is_nl, is_cr, name="et.isle");
        b.cbranch(is_line_end, do_nl, do_char);
        # Newline: copy char, reset column to 0
        b.position_at_start(do_nl);
        dp_nl = b.gep(buf, [di], name="et.dp.nl");
        b.store(ch, dp_nl);
        next_di_nl = b.add(di, one, name="et.ndi.nl");
        next_si_nl = b.add(si, one, name="et.si.nl");
        b.branch(next_bb);
        # Normal char: copy and increment column
        b.position_at_start(do_char);
        dp_ch = b.gep(buf, [di], name="et.dp.ch");
        b.store(ch, dp_ch);
        next_di_ch = b.add(di, one, name="et.ndi.ch");
        next_col_ch = b.add(col, one, name="et.col.ch");
        next_si_ch = b.add(si, one, name="et.si.ch");
        b.branch(next_bb);
        # Merge block for next iteration
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
        # Done: null-terminate
        b.position_at_start(done_bb);
        done_di = b.phi(i64, name="et.done.di");
        done_di.add_incoming(di, loop_bb);
        null_p = b.gep(buf, [done_di], name="et.null");
        b.store(ir.Constant(i8, 0), null_p);
        return buf;
    }

    # Character tests
    def _emit_char_test(
        self,
        ctx: NativeEmitCtx,
        target: ir.Value,
        cfunc_name: str,
        prefix: str,
        empty_is_true: bool = False
    ) -> (ir.Value | None) {
        """Helper: loop over chars, call C ctype function, return 1 if all pass."""
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        test_fn = p._get_or_declare_extern(cfunc_name, i32, [i32]);
        slen = b.call(strlen_fn, [target], name=f"{prefix}.len");
        is_empty = b.icmp_unsigned(
            "==", slen, ir.Constant(i64, 0), name=f"{prefix}.empty"
        );
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

    def emit_isalnum(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return self._emit_char_test(ctx, target, "isalnum", "isalnum");
    }

    def emit_isalpha(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return self._emit_char_test(ctx, target, "isalpha", "isalpha");
    }

    def emit_isascii(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # isascii: empty string returns True, check each char < 128
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        slen = b.call(strlen_fn, [target], name="isascii.len");
        is_empty = b.icmp_unsigned(
            "==", slen, ir.Constant(i64, 0), name="isascii.empty"
        );
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

    def emit_isdecimal(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return self._emit_char_test(ctx, target, "isdigit", "isdecimal");
    }

    def emit_isdigit(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return self._emit_char_test(ctx, target, "isdigit", "isdigit");
    }

    def emit_isidentifier(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # isidentifier: non-empty, first char is alpha/underscore, rest are alnum/underscore
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        isalpha_fn = p._get_or_declare_extern("isalpha", i32, [i32]);
        isalnum_fn = p._get_or_declare_extern("isalnum", i32, [i32]);
        slen = b.call(strlen_fn, [target], name="isid.len");
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
        # Check first char: must be alpha or underscore
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
        # Loop remaining chars
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

    def emit_islower(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # islower: at least one cased char, all cased chars are lowercase
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        isupper_fn = p._get_or_declare_extern("isupper", i32, [i32]);
        isalpha_fn = p._get_or_declare_extern("isalpha", i32, [i32]);
        slen = b.call(strlen_fn, [target], name="islower.len");
        is_empty = b.icmp_unsigned(
            "==", slen, ir.Constant(i64, 0), name="islower.empty"
        );
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

    def emit_isnumeric(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return self._emit_char_test(ctx, target, "isdigit", "isnumeric");
    }

    def emit_isprintable(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return self._emit_char_test(
            ctx, target, "isprint", "isprintable", empty_is_true=True
        );
    }

    def emit_isspace(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return self._emit_char_test(ctx, target, "isspace", "isspace");
    }

    def emit_istitle(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # istitle: uppercase chars follow non-cased, lowercase follow cased
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        isupper_fn = p._get_or_declare_extern("isupper", i32, [i32]);
        islower_fn = p._get_or_declare_extern("islower", i32, [i32]);
        isalpha_fn = p._get_or_declare_extern("isalpha", i32, [i32]);
        slen = b.call(strlen_fn, [target], name="istitle.len");
        is_empty = b.icmp_unsigned(
            "==", slen, ir.Constant(i64, 0), name="istitle.empty"
        );
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
        is_up_bool = b.icmp_signed(
            "!=", is_up, ir.Constant(i32, 0), name="istitle.upbool"
        );
        is_lo = b.call(islower_fn, [ch_i32], name="istitle.islo");
        is_lo_bool = b.icmp_signed(
            "!=", is_lo, ir.Constant(i32, 0), name="istitle.lobool"
        );
        is_al = b.call(isalpha_fn, [ch_i32], name="istitle.isal");
        is_al_bool = b.icmp_signed(
            "!=", is_al, ir.Constant(i32, 0), name="istitle.albool"
        );
        prev_was_cased = b.icmp_unsigned(
            "!=", prev_cased, ir.Constant(i64, 0), name="istitle.pwc"
        );
        upper_after_cased = b.and_(is_up_bool, prev_was_cased, name="istitle.uac");
        not_prev_cased = b.not_(prev_was_cased, name="istitle.npc");
        lower_after_noncased = b.and_(is_lo_bool, not_prev_cased, name="istitle.lanc");
        bad = b.or_(upper_after_cased, lower_after_noncased, name="istitle.bad");
        next_idx = b.add(idx, ir.Constant(i64, 1), name="istitle.next");
        new_prev = b.select(
            is_al_bool,
            ir.Constant(i64, 1),
            ir.Constant(i64, 0),
            name="istitle.newprev"
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

    def emit_isupper(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # isupper: at least one cased char, all cased chars are uppercase
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
        islower_fn = p._get_or_declare_extern("islower", i32, [i32]);
        isalpha_fn = p._get_or_declare_extern("isalpha", i32, [i32]);
        slen = b.call(strlen_fn, [target], name="isupper.len");
        is_empty = b.icmp_unsigned(
            "==", slen, ir.Constant(i64, 0), name="isupper.empty"
        );
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
        is_low_bool = b.icmp_signed(
            "!=", is_low, ir.Constant(i32, 0), name="isupper.islo"
        );
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

    # Encoding
    def emit_encode(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    # Translation
    def emit_translate(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_maketrans(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }
}

class NativeBytesEmitter(BytesEmitter[(ir.Value, NativeEmitCtx)]) {
    # Decoding
    def emit_decode(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_hex(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_fromhex(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    # Search
    def emit_count(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_find(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_rfind(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_index(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_rindex(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_startswith(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_endswith(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    # Modification
    def emit_replace(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_strip(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_lstrip(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_rstrip(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_removeprefix(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_removesuffix(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    # Split and join
    def emit_split(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_rsplit(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_splitlines(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_join(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_partition(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_rpartition(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    # Case (ASCII only)
    def emit_capitalize(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_lower(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_upper(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_title(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_swapcase(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    # Character tests (ASCII only)
    def emit_isalnum(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_isalpha(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_isascii(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_isdigit(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_islower(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_isspace(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_istitle(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_isupper(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    # Alignment
    def emit_center(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_ljust(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_rjust(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_zfill(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_expandtabs(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    # Translation
    def emit_translate(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_maketrans(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }
}

# =============================================================================
#  Collection Types
# =============================================================================
class NativeListEmitter(ListEmitter[
    (ir.Value, NativeEmitCtx)
]) {
    def emit_append(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        p = ctx.pass_ref;
        helpers = p.list_helpers.get(ctx.type_key);
        if helpers is None or not args {
            return None;
        }
        val = p._coerce_type(args[0], helpers["elem_type"]);
        p.builder.call(helpers["append"], [target, val]);
        return ir.Constant(ir.IntType(64), 0);
    }

    def emit_extend(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # extend: iterate source list, append each element
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        helpers = p.list_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        src = args[0];
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
        elem = b.call(helpers["get"], [src, idx], name="ext.elem");
        b.call(helpers["append"], [target, elem]);
        next_idx = b.add(idx, ir.Constant(i64, 1), name="ext.next");
        idx.add_incoming(next_idx, body_bb);
        b.branch(loop_bb);
        b.position_at_start(done_bb);
        return ir.Constant(i64, 0);
    }

    def emit_insert(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # insert(index, value): shift elements right, set at index
        if len(args) < 2 {
            return None;
        }
        p = ctx.pass_ref;
        helpers = p.list_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        insert_idx = args[0];
        insert_val = p._coerce_type(args[1], helpers["elem_type"]);
        # First append a dummy to grow the list
        b.call(helpers["append"], [target, insert_val]);
        # Get the new length
        len_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ins.len.ptr"
        );
        new_len = b.load(len_ptr, name="ins.newlen");
        last_idx = b.sub(new_len, ir.Constant(i64, 1), name="ins.last");
        # Shift elements right from end to insert_idx
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
        # Set the value at insert_idx
        b.call(helpers["set"], [target, insert_idx, insert_val]);
        return ir.Constant(i64, 0);
    }

    def emit_remove(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # remove(value): find first occurrence, shift left, decrease length
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        helpers = p.list_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
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
        # Find loop: search for first occurrence
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
        # Found: shift elements left from found_idx+1
        b.position_at_start(found_bb);
        shift_start = b.add(fi, ir.Constant(i64, 1), name="rem.shstart");
        b.branch(shift_bb);
        b.position_at_start(shift_bb);
        si = b.phi(i64, name="rem.si");
        si.add_incoming(shift_start, found_bb);
        shift_end = b.icmp_unsigned(">=", si, list_len, name="rem.shend");
        b.cbranch(shift_end, done_bb, shift_body);
        b.position_at_start(shift_body);
        val = b.call(helpers["get"], [target, si], name="rem.val");
        prev = b.sub(si, ir.Constant(i64, 1), name="rem.prev");
        b.call(helpers["set"], [target, prev, val]);
        next_si = b.add(si, ir.Constant(i64, 1), name="rem.nextsi");
        si.add_incoming(next_si, shift_body);
        b.branch(shift_bb);
        # Done: decrease length (only if found)
        b.position_at_start(done_bb);
        # PHI must be at top of block
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

    def emit_pop(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        p = ctx.pass_ref;
        helpers = p.list_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        len_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="pop.len.ptr"
        );
        cur_len = b.load(len_ptr, name="pop.len");
        new_len = b.sub(cur_len, ir.Constant(i64, 1), name="pop.newlen");
        last_val = b.call(helpers["get"], [target, new_len], name="pop.val");
        b.store(new_len, len_ptr);
        return last_val;
    }

    def emit_clear(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        p = ctx.pass_ref;
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        len_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="clear.len.ptr"
        );
        b.store(ir.Constant(i64, 0), len_ptr);
        return ir.Constant(i64, 0);
    }

    def emit_index(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        helpers = p.list_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
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
        return result;
    }

    def emit_count(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        helpers = p.list_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
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

    def emit_sort(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # sort(): in-place bubble sort
        p = ctx.pass_ref;
        helpers = p.list_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        zero = ir.Constant(i64, 0);
        one = ir.Constant(i64, 1);
        elem_type = helpers["elem_type"];
        len_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="sort.len.ptr"
        );
        list_len = b.load(len_ptr, name="sort.len");
        func = b.basic_block.function;
        entry_bb = b.basic_block;
        # Outer loop: i from 0 to len-1
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
        b.branch(outer_bb);
        # Outer loop header
        b.position_at_start(outer_bb);
        oi = b.phi(i64, name="sort.oi");
        oi.add_incoming(zero, entry_bb);
        outer_end = b.icmp_unsigned(">=", oi, len_m1, name="sort.oend");
        b.cbranch(outer_end, done_bb, inner_start);
        # Compute inner limit: len - i - 1
        b.position_at_start(inner_start);
        inner_limit = b.sub(len_m1, oi, name="sort.ilimit");
        b.branch(inner_bb);
        # Inner loop header
        b.position_at_start(inner_bb);
        ji = b.phi(i64, name="sort.ji");
        ji.add_incoming(zero, inner_start);
        inner_end = b.icmp_unsigned(">=", ji, inner_limit, name="sort.iend");
        b.cbranch(inner_end, outer_next, inner_body);
        # Inner body: compare adjacent elements
        b.position_at_start(inner_body);
        j1 = b.add(ji, one, name="sort.j1");
        ej = b.call(helpers["get"], [target, ji], name="sort.ej");
        ej1 = b.call(helpers["get"], [target, j1], name="sort.ej1");
        # Compare based on element type
        if isinstance(elem_type, ir.DoubleType) {
            needs_swap = b.fcmp_ordered(">", ej, ej1, name="sort.gt");
        } elif isinstance(elem_type, ir.PointerType) {
            strcmp_fn = p._get_or_declare_extern(
                "strcmp", ir.IntType(32), [elem_type, elem_type]
            );
            cmp_result = b.call(strcmp_fn, [ej, ej1], name="sort.cmp");
            needs_swap = b.icmp_signed(
                ">", cmp_result, ir.Constant(ir.IntType(32), 0), name="sort.gt"
            );
        } else {
            needs_swap = b.icmp_signed(">", ej, ej1, name="sort.gt");
        }
        b.cbranch(needs_swap, swap_bb, no_swap);
        # Swap
        b.position_at_start(swap_bb);
        b.call(helpers["set"], [target, ji, ej1]);
        b.call(helpers["set"], [target, j1, ej]);
        b.branch(inner_next);
        b.position_at_start(no_swap);
        b.branch(inner_next);
        # Inner next
        b.position_at_start(inner_next);
        next_ji = b.add(ji, one, name="sort.nji");
        ji.add_incoming(next_ji, inner_next);
        b.branch(inner_bb);
        # Outer next
        b.position_at_start(outer_next);
        next_oi = b.add(oi, one, name="sort.noi");
        oi.add_incoming(next_oi, outer_next);
        b.branch(outer_bb);
        b.position_at_start(done_bb);
        return ir.Constant(i64, 0);
    }

    def emit_reverse(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        p = ctx.pass_ref;
        helpers = p.list_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
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

    def emit_copy(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        p = ctx.pass_ref;
        helpers = p.list_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
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
}

class NativeDictEmitter(DictEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_get(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # get(key, default=None): return value for key, or default if missing
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        helpers = p.dict_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i64 = ir.IntType(64);
        key = args[0];
        found_i1 = b.call(helpers["contains"], [target, key], name="dget.found");
        func = b.basic_block.function;
        found_bb = func.append_basic_block(name="dget.yes");
        notfound_bb = func.append_basic_block(name="dget.no");
        done_bb = func.append_basic_block(name="dget.done");
        b.cbranch(found_i1, found_bb, notfound_bb);
        # Found: get the value
        b.position_at_start(found_bb);
        val = b.call(helpers["get"], [target, key], name="dget.val");
        b.branch(done_bb);
        # Not found: use default or zero
        b.position_at_start(notfound_bb);
        val_type = helpers["val_type"];
        if len(args) >= 2 {
            default_val = p._coerce_type(args[1], val_type);
        } elif isinstance(val_type, ir.PointerType) {
            default_val = ir.Constant(val_type, None);
        } else {
            default_val = ir.Constant(val_type, 0);
        }
        b.branch(done_bb);
        # Merge
        b.position_at_start(done_bb);
        result = b.phi(val_type, name="dget.result");
        result.add_incoming(val, found_bb);
        result.add_incoming(default_val, notfound_bb);
        return result;
    }

    def emit_keys(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # keys(): return list of all keys
        p = ctx.pass_ref;
        helpers = p.dict_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        # Determine key type name from type_key ("key_type:val_type")
        key_type = helpers["key_type"];
        if isinstance(key_type, ir.PointerType) {
            kt_name = "ptr";
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
        b.call(lhelpers["append"], [new_list, key]);
        next_idx = b.add(idx, ir.Constant(i64, 1), name="dkeys.next");
        idx.add_incoming(next_idx, body_bb);
        b.branch(loop_bb);
        b.position_at_start(done_bb);
        return new_list;
    }

    def emit_values(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # values(): return list of all values
        p = ctx.pass_ref;
        helpers = p.dict_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        # Determine val type name
        val_type = helpers["val_type"];
        if isinstance(val_type, ir.PointerType) {
            vt_name = "ptr";
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
        b.call(lhelpers["append"], [new_list, val]);
        next_idx = b.add(idx, ir.Constant(i64, 1), name="dvals.next");
        idx.add_incoming(next_idx, body_bb);
        b.branch(loop_bb);
        b.position_at_start(done_bb);
        return new_list;
    }

    def emit_items(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_pop(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # pop(key, default=None): remove key and return value, or default/KeyError
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        helpers = p.dict_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        key = args[0];
        val_type = helpers["val_type"];
        key_type = helpers["key_type"];
        has_default = len(args) >= 2;
        # Check if key exists
        found_i1 = b.call(helpers["contains"], [target, key], name="dpop.found");
        func = b.basic_block.function;
        found_bb = func.append_basic_block(name="dpop.yes");
        notfound_bb = func.append_basic_block(name="dpop.no");
        done_bb = func.append_basic_block(name="dpop.done");
        b.cbranch(found_i1, found_bb, notfound_bb);
        # Found: get value, then find index and shift arrays
        b.position_at_start(found_bb);
        saved_val = b.call(helpers["get"], [target, key], name="dpop.val");
        # Find the index of the key via linear search
        len_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="dpop.len.ptr"
        );
        keys_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="dpop.keys.ptr"
        );
        vals_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="dpop.vals.ptr"
        );
        dict_len = b.load(len_ptr, name="dpop.len");
        keys_arr = b.load(keys_ptr, name="dpop.keys");
        vals_arr = b.load(vals_ptr, name="dpop.vals");
        new_len = b.sub(dict_len, ir.Constant(i64, 1), name="dpop.newlen");
        # Search for key index
        search_bb = func.append_basic_block(name="dpop.search");
        search_body = func.append_basic_block(name="dpop.search.body");
        search_found = func.append_basic_block(name="dpop.search.found");
        b.branch(search_bb);
        b.position_at_start(search_bb);
        si = b.phi(i64, name="dpop.si");
        si.add_incoming(ir.Constant(i64, 0), found_bb);
        si_end = b.icmp_unsigned(">=", si, dict_len, name="dpop.si.end");
        b.cbranch(si_end, search_found, search_body);
        b.position_at_start(search_body);
        kp = b.gep(keys_arr, [si], name="dpop.kp");
        kv = b.load(kp, name="dpop.kv");
        i8p = ir.IntType(8).as_pointer();
        if isinstance(key_type, ir.IntType) {
            keq = b.icmp_signed("==", kv, key, name="dpop.keq");
        } elif key_type == i8p {
            strcmp_fn = p._get_or_declare_extern("strcmp", ir.IntType(32), [i8p, i8p]);
            cmp_result = b.call(strcmp_fn, [kv, key], name="dpop.strcmp");
            keq = b.icmp_signed(
                "==", cmp_result, ir.Constant(ir.IntType(32), 0), name="dpop.keq"
            );
        } else {
            keq = b.icmp_unsigned("==", kv, key, name="dpop.keq");
        }
        next_si = b.add(si, ir.Constant(i64, 1), name="dpop.nsi");
        si.add_incoming(next_si, search_body);
        b.cbranch(keq, search_found, search_bb);
        # Found index: shift elements left from si to end
        b.position_at_start(search_found);
        found_idx = b.phi(i64, name="dpop.fidx");
        found_idx.add_incoming(si, search_body);
        found_idx.add_incoming(dict_len, search_bb);
        shift_bb = func.append_basic_block(name="dpop.shift");
        shift_body_bb = func.append_basic_block(name="dpop.shift.body");
        shift_done = func.append_basic_block(name="dpop.shift.done");
        b.branch(shift_bb);
        b.position_at_start(shift_bb);
        ji = b.phi(i64, name="dpop.ji");
        ji.add_incoming(found_idx, search_found);
        ji_end = b.icmp_unsigned(">=", ji, new_len, name="dpop.ji.end");
        b.cbranch(ji_end, shift_done, shift_body_bb);
        b.position_at_start(shift_body_bb);
        next_ji = b.add(ji, ir.Constant(i64, 1), name="dpop.nji");
        # Shift key
        src_kp = b.gep(keys_arr, [next_ji], name="dpop.src.kp");
        skv = b.load(src_kp, name="dpop.skv");
        dst_kp = b.gep(keys_arr, [ji], name="dpop.dst.kp");
        b.store(skv, dst_kp);
        # Shift val
        src_vp = b.gep(vals_arr, [next_ji], name="dpop.src.vp");
        svv = b.load(src_vp, name="dpop.svv");
        dst_vp = b.gep(vals_arr, [ji], name="dpop.dst.vp");
        b.store(svv, dst_vp);
        ji.add_incoming(next_ji, shift_body_bb);
        b.branch(shift_bb);
        b.position_at_start(shift_done);
        b.store(new_len, len_ptr);
        b.branch(done_bb);
        # Not found
        b.position_at_start(notfound_bb);
        if has_default {
            default_val = p._coerce_type(args[1], val_type);
        } else {
            p._emit_runtime_raise(
                ir.Constant(ir.IntType(1), 1), "KeyError", "key not found"
            );
            if isinstance(val_type, ir.PointerType) {
                default_val = ir.Constant(val_type, None);
            } else {
                default_val = ir.Constant(val_type, 0);
            }
        }
        b.branch(done_bb);
        # Merge
        b.position_at_start(done_bb);
        result = b.phi(val_type, name="dpop.result");
        result.add_incoming(saved_val, shift_done);
        result.add_incoming(default_val, notfound_bb);
        return result;
    }

    def emit_popitem(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_setdefault(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_update(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # update(other): merge all key-value pairs from other into target
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        helpers = p.dict_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
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

    def emit_clear(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # clear: set length to 0
        p = ctx.pass_ref;
        helpers = p.dict_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        len_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="dclear.len.ptr"
        );
        b.store(ir.Constant(i64, 0), len_ptr);
        return ir.Constant(i64, 0);
    }

    def emit_copy(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # copy: create new dict, copy all key-value pairs
        p = ctx.pass_ref;
        helpers = p.dict_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
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

    def emit_fromkeys(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }
}

class NativeSetEmitter(SetEmitter[(ir.Value, NativeEmitCtx)]) {
    # Mutation
    def emit_add(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        p = ctx.pass_ref;
        helpers = p.set_helpers.get(ctx.type_key);
        if helpers is None or not args {
            return None;
        }
        val = p._coerce_type(args[0], helpers["elem_type"]);
        p.builder.call(helpers["add"], [target, val]);
        return ir.Constant(ir.IntType(64), 0);
    }

    def emit_remove(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # remove: like discard but raises KeyError if element not found
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        helpers = p.set_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        elem_type = helpers["elem_type"];
        search_val = p._coerce_type(args[0], elem_type);
        len_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="srem.len.ptr"
        );
        elems_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="srem.elems.ptr"
        );
        set_len = b.load(len_ptr, name="srem.len");
        elems_arr = b.load(elems_ptr, name="srem.elems");
        func = b.basic_block.function;
        entry_bb = b.basic_block;
        loop_bb = func.append_basic_block(name="srem.loop");
        check_bb = func.append_basic_block(name="srem.check");
        notfound_bb = func.append_basic_block(name="srem.notfound");
        found_bb = func.append_basic_block(name="srem.found");
        shift_bb = func.append_basic_block(name="srem.shift");
        shift_body = func.append_basic_block(name="srem.shift.body");
        shift_done = func.append_basic_block(name="srem.shift.done");
        done_bb = func.append_basic_block(name="srem.done");
        b.branch(loop_bb);
        # Search loop
        b.position_at_start(loop_bb);
        idx = b.phi(i64, name="srem.idx");
        idx.add_incoming(ir.Constant(i64, 0), entry_bb);
        at_end = b.icmp_unsigned(">=", idx, set_len, name="srem.atend");
        b.cbranch(at_end, notfound_bb, check_bb);
        b.position_at_start(check_bb);
        ep = b.gep(elems_arr, [idx], name="srem.ep");
        ev = b.load(ep, name="srem.ev");
        if isinstance(elem_type, ir.IntType) {
            eq = b.icmp_signed("==", ev, search_val, name="srem.eq");
        } else {
            eq = b.icmp_unsigned("==", ev, search_val, name="srem.eq");
        }
        next_idx = b.add(idx, ir.Constant(i64, 1), name="srem.next");
        b.cbranch(eq, found_bb, loop_bb);
        idx.add_incoming(next_idx, check_bb);
        # Not found: raise KeyError
        b.position_at_start(notfound_bb);
        p._emit_runtime_raise(
            ir.Constant(ir.IntType(1), 1), "KeyError", "element not in set"
        );
        b.branch(done_bb);
        # Found: shift remaining elements left
        b.position_at_start(found_bb);
        new_len = b.sub(set_len, ir.Constant(i64, 1), name="srem.newlen");
        b.store(new_len, len_ptr);
        b.branch(shift_bb);
        b.position_at_start(shift_bb);
        si = b.phi(i64, name="srem.si");
        si.add_incoming(idx, found_bb);
        si_end = b.icmp_unsigned(">=", si, new_len, name="srem.siend");
        b.cbranch(si_end, shift_done, shift_body);
        b.position_at_start(shift_body);
        next_si = b.add(si, ir.Constant(i64, 1), name="srem.nsi");
        src_p = b.gep(elems_arr, [next_si], name="srem.srcp");
        sv = b.load(src_p, name="srem.sv");
        dst_p = b.gep(elems_arr, [si], name="srem.dstp");
        b.store(sv, dst_p);
        si.add_incoming(next_si, shift_body);
        b.branch(shift_bb);
        b.position_at_start(shift_done);
        b.branch(done_bb);
        b.position_at_start(done_bb);
        return ir.Constant(i64, 0);
    }

    def emit_discard(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # discard: remove element if present (no error if absent)
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        helpers = p.set_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        elem_type = helpers["elem_type"];
        search_val = p._coerce_type(args[0], elem_type);
        len_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="disc.len.ptr"
        );
        elems_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="disc.elems.ptr"
        );
        set_len = b.load(len_ptr, name="disc.len");
        elems_arr = b.load(elems_ptr, name="disc.elems");
        func = b.basic_block.function;
        entry_bb = b.basic_block;
        loop_bb = func.append_basic_block(name="disc.loop");
        check_bb = func.append_basic_block(name="disc.check");
        found_bb = func.append_basic_block(name="disc.found");
        shift_bb = func.append_basic_block(name="disc.shift");
        shift_body = func.append_basic_block(name="disc.shift.body");
        shift_done = func.append_basic_block(name="disc.shift.done");
        done_bb = func.append_basic_block(name="disc.done");
        b.branch(loop_bb);
        b.position_at_start(loop_bb);
        idx = b.phi(i64, name="disc.idx");
        idx.add_incoming(ir.Constant(i64, 0), entry_bb);
        at_end = b.icmp_unsigned(">=", idx, set_len, name="disc.atend");
        b.cbranch(at_end, done_bb, check_bb);
        b.position_at_start(check_bb);
        ep = b.gep(elems_arr, [idx], name="disc.ep");
        ev = b.load(ep, name="disc.ev");
        if isinstance(elem_type, ir.IntType) {
            eq = b.icmp_signed("==", ev, search_val, name="disc.eq");
        } else {
            eq = b.icmp_unsigned("==", ev, search_val, name="disc.eq");
        }
        next_idx = b.add(idx, ir.Constant(i64, 1), name="disc.next");
        b.cbranch(eq, found_bb, loop_bb);
        idx.add_incoming(next_idx, check_bb);
        # Found: shift remaining elements left
        b.position_at_start(found_bb);
        new_len = b.sub(set_len, ir.Constant(i64, 1), name="disc.newlen");
        b.store(new_len, len_ptr);
        b.branch(shift_bb);
        b.position_at_start(shift_bb);
        si = b.phi(i64, name="disc.si");
        si.add_incoming(idx, found_bb);
        si_end = b.icmp_unsigned(">=", si, new_len, name="disc.siend");
        b.cbranch(si_end, shift_done, shift_body);
        b.position_at_start(shift_body);
        next_si = b.add(si, ir.Constant(i64, 1), name="disc.nsi");
        src_p = b.gep(elems_arr, [next_si], name="disc.srcp");
        sv = b.load(src_p, name="disc.sv");
        dst_p = b.gep(elems_arr, [si], name="disc.dstp");
        b.store(sv, dst_p);
        si.add_incoming(next_si, shift_body);
        b.branch(shift_bb);
        b.position_at_start(shift_done);
        b.branch(done_bb);
        b.position_at_start(done_bb);
        return ir.Constant(i64, 0);
    }

    def emit_pop(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # pop: remove and return an arbitrary element, raise KeyError if empty
        p = ctx.pass_ref;
        helpers = p.set_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        len_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="spop.len.ptr"
        );
        elems_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="spop.elems.ptr"
        );
        set_len = b.load(len_ptr, name="spop.len");
        # Raise KeyError if empty
        is_empty = b.icmp_unsigned(
            "==", set_len, ir.Constant(i64, 0), name="spop.empty"
        );
        p._emit_runtime_raise(is_empty, "KeyError", "pop from an empty set");
        # Pop last element (arbitrary choice, O(1))
        new_len = b.sub(set_len, ir.Constant(i64, 1), name="spop.newlen");
        elems_arr = b.load(elems_ptr, name="spop.elems");
        last_ep = b.gep(elems_arr, [new_len], name="spop.last.ptr");
        last_val = b.load(last_ep, name="spop.last.val");
        b.store(new_len, len_ptr);
        return last_val;
    }

    def emit_clear(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # clear: set length to 0
        p = ctx.pass_ref;
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        len_ptr = b.gep(
            target,
            [ir.Constant(i32, 0), ir.Constant(i32, 0)],
            name="set.clear.len.ptr"
        );
        b.store(ir.Constant(i64, 0), len_ptr);
        return ir.Constant(i64, 0);
    }

    # Set algebra
    def _emit_set_iterate(
        self, ctx: NativeEmitCtx, source: ir.Value, prefix: str
    ) -> tuple {
        # Helper: set up iteration over a set, returns (helpers, b, i32, i64, set_len, elems_arr, entry_bb, loop_bb, body_bb, done_bb, idx, elem)
        p = ctx.pass_ref;
        helpers = p.set_helpers.get(ctx.type_key);
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        len_ptr = b.gep(
            source,
            [ir.Constant(i32, 0), ir.Constant(i32, 0)],
            name=f"{prefix}.len.ptr"
        );
        elems_ptr = b.gep(
            source,
            [ir.Constant(i32, 0), ir.Constant(i32, 2)],
            name=f"{prefix}.elems.ptr"
        );
        set_len = b.load(len_ptr, name=f"{prefix}.len");
        elems_arr = b.load(elems_ptr, name=f"{prefix}.elems");
        func = b.basic_block.function;
        entry_bb = b.basic_block;
        loop_bb = func.append_basic_block(name=f"{prefix}.loop");
        body_bb = func.append_basic_block(name=f"{prefix}.body");
        done_bb = func.append_basic_block(name=f"{prefix}.done");
        b.branch(loop_bb);
        b.position_at_start(loop_bb);
        idx = b.phi(i64, name=f"{prefix}.idx");
        idx.add_incoming(ir.Constant(i64, 0), entry_bb);
        at_end = b.icmp_unsigned(">=", idx, set_len, name=f"{prefix}.atend");
        b.cbranch(at_end, done_bb, body_bb);
        b.position_at_start(body_bb);
        ep = b.gep(elems_arr, [idx], name=f"{prefix}.ep");
        ev = b.load(ep, name=f"{prefix}.ev");
        return (helpers, b, i64, idx, ev, entry_bb, loop_bb, body_bb, done_bb);
    }

    def emit_union(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # union(other): new set with all elements from both
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        helpers = p.set_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        new_set = b.call(helpers["new"], [], name="sunion.new");
        # Copy all from self
        len1_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="su.l1.ptr"
        );
        e1_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="su.e1.ptr"
        );
        len1 = b.load(len1_ptr, name="su.len1");
        elems1 = b.load(e1_ptr, name="su.elems1");
        func = b.basic_block.function;
        entry1 = b.basic_block;
        loop1 = func.append_basic_block(name="su.loop1");
        body1 = func.append_basic_block(name="su.body1");
        mid_bb = func.append_basic_block(name="su.mid");
        b.branch(loop1);
        b.position_at_start(loop1);
        i1 = b.phi(i64, name="su.i1");
        i1.add_incoming(ir.Constant(i64, 0), entry1);
        end1 = b.icmp_unsigned(">=", i1, len1, name="su.end1");
        b.cbranch(end1, mid_bb, body1);
        b.position_at_start(body1);
        ep1 = b.gep(elems1, [i1], name="su.ep1");
        ev1 = b.load(ep1, name="su.ev1");
        b.call(helpers["add"], [new_set, ev1]);
        n1 = b.add(i1, ir.Constant(i64, 1), name="su.n1");
        i1.add_incoming(n1, body1);
        b.branch(loop1);
        # Copy all from other
        b.position_at_start(mid_bb);
        other = args[0];
        len2_ptr = b.gep(
            other, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="su.l2.ptr"
        );
        e2_ptr = b.gep(
            other, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="su.e2.ptr"
        );
        len2 = b.load(len2_ptr, name="su.len2");
        elems2 = b.load(e2_ptr, name="su.elems2");
        loop2 = func.append_basic_block(name="su.loop2");
        body2 = func.append_basic_block(name="su.body2");
        done_bb = func.append_basic_block(name="su.done");
        b.branch(loop2);
        b.position_at_start(loop2);
        i2 = b.phi(i64, name="su.i2");
        i2.add_incoming(ir.Constant(i64, 0), mid_bb);
        end2 = b.icmp_unsigned(">=", i2, len2, name="su.end2");
        b.cbranch(end2, done_bb, body2);
        b.position_at_start(body2);
        ep2 = b.gep(elems2, [i2], name="su.ep2");
        ev2 = b.load(ep2, name="su.ev2");
        b.call(helpers["add"], [new_set, ev2]);
        n2 = b.add(i2, ir.Constant(i64, 1), name="su.n2");
        i2.add_incoming(n2, body2);
        b.branch(loop2);
        b.position_at_start(done_bb);
        return new_set;
    }

    def emit_intersection(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # intersection(other): new set with elements in both self and other
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        helpers = p.set_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        new_set = b.call(helpers["new"], [], name="sinter.new");
        other = args[0];
        # Iterate self
        len_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="si.len.ptr"
        );
        elems_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="si.elems.ptr"
        );
        set_len = b.load(len_ptr, name="si.len");
        elems_arr = b.load(elems_ptr, name="si.elems");
        func = b.basic_block.function;
        entry_bb = b.basic_block;
        loop_bb = func.append_basic_block(name="si.loop");
        body_bb = func.append_basic_block(name="si.body");
        add_bb = func.append_basic_block(name="si.add");
        skip_bb = func.append_basic_block(name="si.skip");
        done_bb = func.append_basic_block(name="si.done");
        b.branch(loop_bb);
        b.position_at_start(loop_bb);
        idx = b.phi(i64, name="si.idx");
        idx.add_incoming(ir.Constant(i64, 0), entry_bb);
        at_end = b.icmp_unsigned(">=", idx, set_len, name="si.atend");
        b.cbranch(at_end, done_bb, body_bb);
        b.position_at_start(body_bb);
        ep = b.gep(elems_arr, [idx], name="si.ep");
        ev = b.load(ep, name="si.ev");
        in_other = b.call(helpers["contains"], [other, ev], name="si.inother");
        b.cbranch(in_other, add_bb, skip_bb);
        b.position_at_start(add_bb);
        b.call(helpers["add"], [new_set, ev]);
        b.branch(skip_bb);
        b.position_at_start(skip_bb);
        next_idx = b.add(idx, ir.Constant(i64, 1), name="si.next");
        idx.add_incoming(next_idx, skip_bb);
        b.branch(loop_bb);
        b.position_at_start(done_bb);
        return new_set;
    }

    def emit_difference(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # difference(other): new set with elements in self but not in other
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        helpers = p.set_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        new_set = b.call(helpers["new"], [], name="sdiff.new");
        other = args[0];
        len_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="sd.len.ptr"
        );
        elems_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="sd.elems.ptr"
        );
        set_len = b.load(len_ptr, name="sd.len");
        elems_arr = b.load(elems_ptr, name="sd.elems");
        func = b.basic_block.function;
        entry_bb = b.basic_block;
        loop_bb = func.append_basic_block(name="sd.loop");
        body_bb = func.append_basic_block(name="sd.body");
        add_bb = func.append_basic_block(name="sd.add");
        skip_bb = func.append_basic_block(name="sd.skip");
        done_bb = func.append_basic_block(name="sd.done");
        b.branch(loop_bb);
        b.position_at_start(loop_bb);
        idx = b.phi(i64, name="sd.idx");
        idx.add_incoming(ir.Constant(i64, 0), entry_bb);
        at_end = b.icmp_unsigned(">=", idx, set_len, name="sd.atend");
        b.cbranch(at_end, done_bb, body_bb);
        b.position_at_start(body_bb);
        ep = b.gep(elems_arr, [idx], name="sd.ep");
        ev = b.load(ep, name="sd.ev");
        in_other = b.call(helpers["contains"], [other, ev], name="sd.inother");
        # Add if NOT in other
        not_in = b.icmp_unsigned(
            "==", in_other, ir.Constant(ir.IntType(1), 0), name="sd.notin"
        );
        b.cbranch(not_in, add_bb, skip_bb);
        b.position_at_start(add_bb);
        b.call(helpers["add"], [new_set, ev]);
        b.branch(skip_bb);
        b.position_at_start(skip_bb);
        next_idx = b.add(idx, ir.Constant(i64, 1), name="sd.next");
        idx.add_incoming(next_idx, skip_bb);
        b.branch(loop_bb);
        b.position_at_start(done_bb);
        return new_set;
    }

    def emit_symmetric_difference(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    # In-place set algebra
    def emit_update(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_intersection_update(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_difference_update(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_symmetric_difference_update(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    # Tests
    def emit_issubset(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # issubset(other): return 1 if all elements of self are in other
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        helpers = p.set_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        other = args[0];
        len_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ssub.len.ptr"
        );
        elems_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="ssub.elems.ptr"
        );
        set_len = b.load(len_ptr, name="ssub.len");
        elems_arr = b.load(elems_ptr, name="ssub.elems");
        func = b.basic_block.function;
        entry_bb = b.basic_block;
        loop_bb = func.append_basic_block(name="ssub.loop");
        body_bb = func.append_basic_block(name="ssub.body");
        false_bb = func.append_basic_block(name="ssub.false");
        done_bb = func.append_basic_block(name="ssub.done");
        b.branch(loop_bb);
        b.position_at_start(loop_bb);
        idx = b.phi(i64, name="ssub.idx");
        idx.add_incoming(ir.Constant(i64, 0), entry_bb);
        at_end = b.icmp_unsigned(">=", idx, set_len, name="ssub.atend");
        b.cbranch(at_end, done_bb, body_bb);
        b.position_at_start(body_bb);
        ep = b.gep(elems_arr, [idx], name="ssub.ep");
        ev = b.load(ep, name="ssub.ev");
        in_other = b.call(helpers["contains"], [other, ev], name="ssub.inother");
        next_idx = b.add(idx, ir.Constant(i64, 1), name="ssub.next");
        idx.add_incoming(next_idx, body_bb);
        b.cbranch(in_other, loop_bb, false_bb);
        b.position_at_start(false_bb);
        b.branch(done_bb);
        b.position_at_start(done_bb);
        result = b.phi(i64, name="ssub.result");
        result.add_incoming(ir.Constant(i64, 1), loop_bb);
        result.add_incoming(ir.Constant(i64, 0), false_bb);
        return result;
    }

    def emit_issuperset(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # issuperset(other): return 1 if all elements of other are in self
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        helpers = p.set_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        other = args[0];
        # Iterate OTHER, check each in SELF
        len_ptr = b.gep(
            other, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ssup.len.ptr"
        );
        elems_ptr = b.gep(
            other, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="ssup.elems.ptr"
        );
        other_len = b.load(len_ptr, name="ssup.len");
        elems_arr = b.load(elems_ptr, name="ssup.elems");
        func = b.basic_block.function;
        entry_bb = b.basic_block;
        loop_bb = func.append_basic_block(name="ssup.loop");
        body_bb = func.append_basic_block(name="ssup.body");
        false_bb = func.append_basic_block(name="ssup.false");
        done_bb = func.append_basic_block(name="ssup.done");
        b.branch(loop_bb);
        b.position_at_start(loop_bb);
        idx = b.phi(i64, name="ssup.idx");
        idx.add_incoming(ir.Constant(i64, 0), entry_bb);
        at_end = b.icmp_unsigned(">=", idx, other_len, name="ssup.atend");
        b.cbranch(at_end, done_bb, body_bb);
        b.position_at_start(body_bb);
        ep = b.gep(elems_arr, [idx], name="ssup.ep");
        ev = b.load(ep, name="ssup.ev");
        in_self = b.call(helpers["contains"], [target, ev], name="ssup.inself");
        next_idx = b.add(idx, ir.Constant(i64, 1), name="ssup.next");
        idx.add_incoming(next_idx, body_bb);
        b.cbranch(in_self, loop_bb, false_bb);
        b.position_at_start(false_bb);
        b.branch(done_bb);
        b.position_at_start(done_bb);
        result = b.phi(i64, name="ssup.result");
        result.add_incoming(ir.Constant(i64, 1), loop_bb);
        result.add_incoming(ir.Constant(i64, 0), false_bb);
        return result;
    }

    def emit_isdisjoint(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # isdisjoint(other): return 1 if no elements in common
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        helpers = p.set_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        other = args[0];
        len_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="sdisj.len.ptr"
        );
        elems_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="sdisj.elems.ptr"
        );
        set_len = b.load(len_ptr, name="sdisj.len");
        elems_arr = b.load(elems_ptr, name="sdisj.elems");
        func = b.basic_block.function;
        entry_bb = b.basic_block;
        loop_bb = func.append_basic_block(name="sdisj.loop");
        body_bb = func.append_basic_block(name="sdisj.body");
        found_bb = func.append_basic_block(name="sdisj.found");
        done_bb = func.append_basic_block(name="sdisj.done");
        b.branch(loop_bb);
        b.position_at_start(loop_bb);
        idx = b.phi(i64, name="sdisj.idx");
        idx.add_incoming(ir.Constant(i64, 0), entry_bb);
        at_end = b.icmp_unsigned(">=", idx, set_len, name="sdisj.atend");
        b.cbranch(at_end, done_bb, body_bb);
        b.position_at_start(body_bb);
        ep = b.gep(elems_arr, [idx], name="sdisj.ep");
        ev = b.load(ep, name="sdisj.ev");
        in_other = b.call(helpers["contains"], [other, ev], name="sdisj.inother");
        next_idx = b.add(idx, ir.Constant(i64, 1), name="sdisj.next");
        idx.add_incoming(next_idx, body_bb);
        # If found in other, not disjoint
        b.cbranch(in_other, found_bb, loop_bb);
        b.position_at_start(found_bb);
        b.branch(done_bb);
        b.position_at_start(done_bb);
        result = b.phi(i64, name="sdisj.result");
        result.add_incoming(ir.Constant(i64, 1), loop_bb);
        result.add_incoming(ir.Constant(i64, 0), found_bb);
        return result;
    }

    def emit_copy(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        # copy: create new set and add all elements
        p = ctx.pass_ref;
        helpers = p.set_helpers.get(ctx.type_key);
        if helpers is None {
            return None;
        }
        b = p.builder;
        i32 = ir.IntType(32);
        i64 = ir.IntType(64);
        new_set = b.call(helpers["new"], [], name="scopy.new");
        len_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="scopy.len.ptr"
        );
        elems_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="scopy.elems.ptr"
        );
        set_len = b.load(len_ptr, name="scopy.len");
        elems_arr = b.load(elems_ptr, name="scopy.elems");
        func = b.basic_block.function;
        entry_bb = b.basic_block;
        loop_bb = func.append_basic_block(name="scopy.loop");
        body_bb = func.append_basic_block(name="scopy.body");
        done_bb = func.append_basic_block(name="scopy.done");
        b.branch(loop_bb);
        b.position_at_start(loop_bb);
        idx = b.phi(i64, name="scopy.idx");
        idx.add_incoming(ir.Constant(i64, 0), entry_bb);
        at_end = b.icmp_unsigned(">=", idx, set_len, name="scopy.atend");
        b.cbranch(at_end, done_bb, body_bb);
        b.position_at_start(body_bb);
        ep = b.gep(elems_arr, [idx], name="scopy.ep");
        ev = b.load(ep, name="scopy.ev");
        b.call(helpers["add"], [new_set, ev]);
        next_idx = b.add(idx, ir.Constant(i64, 1), name="scopy.next");
        idx.add_incoming(next_idx, body_bb);
        b.branch(loop_bb);
        b.position_at_start(done_bb);
        return new_set;
    }
}

class NativeFrozensetEmitter(FrozensetEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_union(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_intersection(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_difference(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_symmetric_difference(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_issubset(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_issuperset(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_isdisjoint(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_copy(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }
}

class NativeTupleEmitter(TupleEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_count(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_index(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }
}

class NativeRangeEmitter(RangeEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_count(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_index(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }
}

# =============================================================================
#  Builtin Functions
# =============================================================================
class NativeBuiltinEmitter(BuiltinEmitter[
    (ir.Value, NativeEmitCtx)
]) {
    def emit_print(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_input(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_len(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_abs(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        if not args {
            return None;
        }
        arg_val = args[0];
        b = ctx.pass_ref.builder;
        i64 = ir.IntType(64);
        if isinstance(arg_val.type, ir.IntType) {
            zero = ir.Constant(i64, 0);
            is_neg = b.icmp_signed("<", arg_val, zero, name="abs.neg");
            negated = b.sub(zero, arg_val, name="abs.negate");
            return b.select(is_neg, negated, arg_val, name="abs.result");
        }
        if isinstance(arg_val.type, ir.DoubleType) {
            fabs_fn = ctx.pass_ref._get_or_declare_extern(
                "fabs", ir.DoubleType(), [ir.DoubleType()]
            );
            return b.call(fabs_fn, [arg_val], name="abs.fresult");
        }
        return None;
    }

    def emit_round(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        if not args {
            return None;
        }
        arg_val = args[0];
        p = ctx.pass_ref;
        b = p.builder;
        i64 = ir.IntType(64);
        if isinstance(arg_val.type, ir.DoubleType) {
            round_fn = p._get_or_declare_extern(
                "round", ir.DoubleType(), [ir.DoubleType()]
            );
            rounded = b.call(round_fn, [arg_val], name="round.f");
            return b.fptosi(rounded, i64, name="round.result");
        }
        # int rounds to itself
        if isinstance(arg_val.type, ir.IntType) {
            return arg_val;
        }
        return None;
    }

    def emit_min(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
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

    def emit_max(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
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

    def emit_sum(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_sorted(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_reversed(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_enumerate(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_zip(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_map(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_filter(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_any(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_all(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_isinstance(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_issubclass(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_type(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_id(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_hash(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_repr(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_chr(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        if not args {
            return None;
        }
        arg_val = args[0];
        p = ctx.pass_ref;
        b = p.builder;
        i8p = ir.IntType(8).as_pointer();
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [ir.IntType(64)]);
        str_ptr = b.call(gc_malloc, [ir.Constant(ir.IntType(64), 2)], name="chr.buf");
        byte_val = b.trunc(arg_val, ir.IntType(8), name="chr.byte");
        b.store(byte_val, str_ptr);
        idx1_ptr = b.gep(
            str_ptr, [ir.Constant(ir.IntType(64), 1)], name="chr.null.ptr"
        );
        b.store(ir.Constant(ir.IntType(8), 0), idx1_ptr);
        return str_ptr;
    }

    def emit_ord(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        if not args {
            return None;
        }
        arg_val = args[0];
        b = ctx.pass_ref.builder;
        byte_val = b.load(arg_val, name="ord.byte");
        return b.zext(byte_val, ir.IntType(64), name="ord.val");
    }

    def emit_hex(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
        i8p = ir.IntType(8).as_pointer();
        i64 = ir.IntType(64);
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        snprintf = p._get_or_declare_extern(
            "snprintf", ir.IntType(32), [i8p, i64, i8p], var_arg=True
        );
        buf = b.call(gc_malloc, [ir.Constant(i64, 32)], name="hex.buf");
        # Check if negative
        arg_val = args[0];
        zero = ir.Constant(i64, 0);
        is_neg = b.icmp_signed("<", arg_val, zero, name="hex.neg");
        abs_val = b.sub(zero, arg_val, name="hex.abs");
        pos_val = b.select(is_neg, abs_val, arg_val, name="hex.pos");
        fmt_pos = p._get_snprintf_fmt("0x%lx");
        fmt_neg = p._get_snprintf_fmt("-0x%lx");
        fmt_pos_ptr = b.bitcast(fmt_pos, i8p, name="hex.fmt.pos");
        fmt_neg_ptr = b.bitcast(fmt_neg, i8p, name="hex.fmt.neg");
        fmt = b.select(is_neg, fmt_neg_ptr, fmt_pos_ptr, name="hex.fmt");
        b.call(
            snprintf, [buf, ir.Constant(i64, 32), fmt, pos_val], name="hex.snprintf"
        );
        return buf;
    }

    def emit_oct(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
        i8p = ir.IntType(8).as_pointer();
        i64 = ir.IntType(64);
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        snprintf = p._get_or_declare_extern(
            "snprintf", ir.IntType(32), [i8p, i64, i8p], var_arg=True
        );
        buf = b.call(gc_malloc, [ir.Constant(i64, 32)], name="oct.buf");
        arg_val = args[0];
        zero = ir.Constant(i64, 0);
        is_neg = b.icmp_signed("<", arg_val, zero, name="oct.neg");
        abs_val = b.sub(zero, arg_val, name="oct.abs");
        pos_val = b.select(is_neg, abs_val, arg_val, name="oct.pos");
        fmt_pos = p._get_snprintf_fmt("0o%lo");
        fmt_neg = p._get_snprintf_fmt("-0o%lo");
        fmt_pos_ptr = b.bitcast(fmt_pos, i8p, name="oct.fmt.pos");
        fmt_neg_ptr = b.bitcast(fmt_neg, i8p, name="oct.fmt.neg");
        fmt = b.select(is_neg, fmt_neg_ptr, fmt_pos_ptr, name="oct.fmt");
        b.call(
            snprintf, [buf, ir.Constant(i64, 32), fmt, pos_val], name="oct.snprintf"
        );
        return buf;
    }

    def emit_bin(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = p.builder;
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i64 = ir.IntType(64);
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [i64]);
        snprintf = p._get_or_declare_extern(
            "snprintf", ir.IntType(32), [i8p, i64, i8p], var_arg=True
        );
        # Allocate buffer: "0b" + up to 64 digits + sign + null = 68
        buf = b.call(gc_malloc, [ir.Constant(i64, 68)], name="bin.buf");
        arg_val = args[0];
        zero = ir.Constant(i64, 0);
        is_neg = b.icmp_signed("<", arg_val, zero, name="bin.neg");
        abs_val = b.sub(zero, arg_val, name="bin.abs");
        pos_val = b.select(is_neg, abs_val, arg_val, name="bin.pos");
        is_zero = b.icmp_signed("==", arg_val, zero, name="bin.iszero");
        func = b.basic_block.function;
        entry_bb = b.basic_block;
        zero_bb = func.append_basic_block(name="bin.zero");
        prefix_bb = func.append_basic_block(name="bin.prefix");
        loop_bb = func.append_basic_block(name="bin.loop");
        body_bb = func.append_basic_block(name="bin.body");
        reverse_bb = func.append_basic_block(name="bin.reverse");
        done_bb = func.append_basic_block(name="bin.done");
        b.cbranch(is_zero, zero_bb, prefix_bb);
        # Zero case: "0b0"
        b.position_at_start(zero_bb);
        fmt_zero = p._get_snprintf_fmt("0b0");
        fmt_zero_ptr = b.bitcast(fmt_zero, i8p, name="bin.fmt.zero");
        b.call(
            snprintf, [buf, ir.Constant(i64, 68), fmt_zero_ptr], name="bin.zero.snp"
        );
        b.branch(done_bb);
        # Write prefix: "-0b" or "0b"
        b.position_at_start(prefix_bb);
        neg_ch = ir.Constant(i8, 45);  # '-'
        zero_ch = ir.Constant(i8, 48);  # '0'
        b_ch = ir.Constant(i8, 98);  # 'b'
        # Write sign if negative
        start_off_val = b.select(
            is_neg, ir.Constant(i64, 1), ir.Constant(i64, 0), name="bin.start"
        );
        neg_ptr = b.gep(buf, [ir.Constant(i64, 0)], name="bin.neg.ptr");
        b.store(b.select(is_neg, neg_ch, zero_ch, name="bin.first.ch"), neg_ptr);
        zero_ptr = b.gep(buf, [start_off_val], name="bin.zero.ptr");
        b.store(zero_ch, zero_ptr);
        b_off = b.add(start_off_val, ir.Constant(i64, 1), name="bin.b.off");
        b_ptr = b.gep(buf, [b_off], name="bin.b.ptr");
        b.store(b_ch, b_ptr);
        digit_start = b.add(b_off, ir.Constant(i64, 1), name="bin.digit.start");
        b.branch(loop_bb);
        # Extract digits (reverse order)
        b.position_at_start(loop_bb);
        val = b.phi(i64, name="bin.val");
        off = b.phi(i64, name="bin.off");
        val.add_incoming(pos_val, prefix_bb);
        off.add_incoming(digit_start, prefix_bb);
        is_done = b.icmp_unsigned("==", val, ir.Constant(i64, 0), name="bin.done.chk");
        b.cbranch(is_done, reverse_bb, body_bb);
        b.position_at_start(body_bb);
        bit = b.and_(val, ir.Constant(i64, 1), name="bin.bit");
        digit = b.trunc(
            b.add(bit, ir.Constant(i64, 48), name="bin.digit.val"),
            i8,
            name="bin.digit"
        );
        digit_ptr = b.gep(buf, [off], name="bin.digit.ptr");
        b.store(digit, digit_ptr);
        new_val = b.lshr(val, ir.Constant(i64, 1), name="bin.new.val");
        new_off = b.add(off, ir.Constant(i64, 1), name="bin.new.off");
        val.add_incoming(new_val, body_bb);
        off.add_incoming(new_off, body_bb);
        b.branch(loop_bb);
        # Reverse the digit portion and null-terminate
        b.position_at_start(reverse_bb);
        null_ptr = b.gep(buf, [off], name="bin.null.ptr");
        b.store(ir.Constant(i8, 0), null_ptr);
        # Reverse digits between digit_start and off-1
        rev_entry = b.basic_block;
        rev_loop = func.append_basic_block(name="bin.rev.loop");
        rev_body = func.append_basic_block(name="bin.rev.body");
        rev_done = func.append_basic_block(name="bin.rev.done");
        end_idx = b.sub(off, ir.Constant(i64, 1), name="bin.end.idx");
        b.branch(rev_loop);
        b.position_at_start(rev_loop);
        lo = b.phi(i64, name="bin.rev.lo");
        hi = b.phi(i64, name="bin.rev.hi");
        lo.add_incoming(digit_start, rev_entry);
        hi.add_incoming(end_idx, rev_entry);
        need_swap = b.icmp_signed("<", lo, hi, name="bin.rev.need");
        b.cbranch(need_swap, rev_body, rev_done);
        b.position_at_start(rev_body);
        lo_ptr = b.gep(buf, [lo], name="bin.rev.lo.ptr");
        hi_ptr = b.gep(buf, [hi], name="bin.rev.hi.ptr");
        lo_ch = b.load(lo_ptr, name="bin.rev.lo.ch");
        hi_ch = b.load(hi_ptr, name="bin.rev.hi.ch");
        b.store(hi_ch, lo_ptr);
        b.store(lo_ch, hi_ptr);
        next_lo = b.add(lo, ir.Constant(i64, 1), name="bin.rev.next.lo");
        next_hi = b.sub(hi, ir.Constant(i64, 1), name="bin.rev.next.hi");
        lo.add_incoming(next_lo, rev_body);
        hi.add_incoming(next_hi, rev_body);
        b.branch(rev_loop);
        b.position_at_start(rev_done);
        b.branch(done_bb);
        b.position_at_start(done_bb);
        return buf;
    }

    def emit_pow(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        if len(args) < 2 {
            return None;
        }
        p = ctx.pass_ref;
        base = args[0];
        exp = args[1];
        if isinstance(base.type, ir.IntType) and isinstance(exp.type, ir.IntType) {
            return p._codegen_int_pow(base, exp);
        }
        if isinstance(base.type, ir.DoubleType) and isinstance(exp.type, ir.DoubleType) {
            pow_fn = p._get_or_declare_extern(
                "pow", ir.DoubleType(), [ir.DoubleType(), ir.DoubleType()]
            );
            return p.builder.call(pow_fn, [base, exp], name="pow.result");
        }
        return None;
    }

    def emit_divmod(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_iter(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_next(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_callable(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_getattr(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_setattr(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_hasattr(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_delattr(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_vars(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_dir(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_open(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_format(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_ascii(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    # Type conversion builtins
    def emit_str(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        if not args {
            return None;
        }
        arg_val = args[0];
        p = ctx.pass_ref;
        b = p.builder;
        i8p = ir.IntType(8).as_pointer();
        gc_malloc = p._get_or_declare_extern("GC_malloc", i8p, [ir.IntType(64)]);
        buf_ptr = b.call(gc_malloc, [ir.Constant(ir.IntType(64), 32)], name="str.buf");
        snprintf = p._get_or_declare_extern(
            "snprintf", ir.IntType(32), [i8p, ir.IntType(64), i8p], var_arg=True
        );
        if isinstance(arg_val.type, ir.IntType) {
            fmt = p._get_snprintf_fmt("%ld");
        } elif isinstance(arg_val.type, ir.DoubleType) {
            fmt = p._get_snprintf_fmt("%g");
        } else {
            fmt = p._get_snprintf_fmt("%ld");
        }
        fmt_ptr = b.bitcast(fmt, i8p, name="str.fmt.ptr");
        b.call(
            snprintf,
            [buf_ptr, ir.Constant(ir.IntType(64), 32), fmt_ptr, arg_val],
            name="str.snprintf"
        );
        return buf_ptr;
    }

    def emit_int(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        if not args {
            return None;
        }
        arg_val = args[0];
        p = ctx.pass_ref;
        b = p.builder;
        i8p = ir.IntType(8).as_pointer();
        i64 = ir.IntType(64);
        i32 = ir.IntType(32);
        strtol_fn = p._get_or_declare_extern(
            "strtol", i64, [i8p, i8p.as_pointer(), i32]
        );
        endptr_alloca = b.alloca(i8p, name="endptr");
        result_val = b.call(
            strtol_fn,
            [arg_val, endptr_alloca, ir.Constant(i32, 10)],
            name="strtol.result"
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

    def emit_float(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        if not args {
            return None;
        }
        arg_val = args[0];
        p = ctx.pass_ref;
        b = p.builder;
        i8p = ir.IntType(8).as_pointer();
        i32 = ir.IntType(32);
        # String to float via strtod
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
        # Int to float
        if isinstance(arg_val.type, ir.IntType) {
            return b.sitofp(arg_val, ir.DoubleType(), name="float.from.int");
        }
        return None;
    }

    def emit_bool(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        if not args {
            return None;
        }
        arg_val = args[0];
        p = ctx.pass_ref;
        b = p.builder;
        i64 = ir.IntType(64);
        if isinstance(arg_val.type, ir.IntType) {
            # bool(int): nonzero is truthy
            is_nonzero = b.icmp_signed(
                "!=", arg_val, ir.Constant(i64, 0), name="bool.nz"
            );
            return b.zext(is_nonzero, i64, name="bool.result");
        }
        if isinstance(arg_val.type, ir.DoubleType) {
            # bool(float): non-zero is truthy
            is_nonzero = b.fcmp_ordered(
                "!=", arg_val, ir.Constant(ir.DoubleType(), 0.0), name="bool.fnz"
            );
            return b.zext(is_nonzero, i64, name="bool.fresult");
        }
        if isinstance(arg_val.type, ir.PointerType) {
            # bool(str): non-empty is truthy
            i8p = ir.IntType(8).as_pointer();
            if arg_val.type == i8p {
                strlen_fn = p._get_or_declare_extern("strlen", i64, [i8p]);
                slen = b.call(strlen_fn, [arg_val], name="bool.slen");
                is_nonempty = b.icmp_unsigned(
                    "!=", slen, ir.Constant(i64, 0), name="bool.nonempty"
                );
                return b.zext(is_nonempty, i64, name="bool.sresult");
            }
        }
        return None;
    }

    def emit_list(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_dict(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_set(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_tuple(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_frozenset(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_bytes(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_complex(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }
}
