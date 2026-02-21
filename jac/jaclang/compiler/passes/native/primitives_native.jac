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

    def emit_conjugate(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
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
        return None;
    }

    def emit_as_integer_ratio(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_conjugate(
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
        return None;
    }

    def emit_casefold(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
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
        return None;
    }

    def emit_swapcase(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
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
        return None;
    }

    def emit_strip(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return ctx.pass_ref._codegen_str_strip(target);
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

    # Character tests
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

    def emit_isdecimal(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_isdigit(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_isidentifier(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_islower(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_isnumeric(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_isprintable(
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
        return None;
    }

    def emit_insert(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_remove(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
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
        return None;
    }

    def emit_sort(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
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
        return None;
    }

    def emit_keys(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_values(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_items(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_pop(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
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
        return None;
    }

    def emit_clear(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_copy(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
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
        return None;
    }

    def emit_discard(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_pop(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_clear(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    # Set algebra
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
        return None;
    }

    def emit_oct(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
    }

    def emit_bin(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
        return None;
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
            fmt = p._get_fmt_string("%ld");
        } elif isinstance(arg_val.type, ir.DoubleType) {
            fmt = p._get_fmt_string("%g");
        } else {
            fmt = p._get_fmt_string("%ld");
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
        return None;
    }

    def emit_bool(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None) {
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
