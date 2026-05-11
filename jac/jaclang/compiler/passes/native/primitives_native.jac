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
import type from jaclang.compiler.passes.native.na_ir_gen_pass { NaIRGenPass }

# --- Context ----------------------------------------------------------------
obj NativeEmitCtx {
    """Native emission — provides typed access to LLVM infrastructure.

    Created per dispatch call with the appropriate type_key.
    """
    has pass_ref: NaIRGenPass,
        type_key: str = "";
}


"""Get the LLVM IR builder from the pass, asserting it is set."""
def get_builder(p: NaIRGenPass) -> ir.IRBuilder {
    b = p.builder;
    assert b is not None , "Builder should be set in pass_ref";
    return b;
}


# =============================================================================
#  Numeric Types
# =============================================================================
class NativeIntEmitter(IntEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_bit_length(
        self: NativeIntEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_bit_count(
        self: NativeIntEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_to_bytes(
        self: NativeIntEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_as_integer_ratio(
        self: NativeIntEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_conjugate(
        self: NativeIntEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_from_bytes(
        self: NativeIntEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeFloatEmitter(FloatEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_is_integer(
        self: NativeFloatEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_as_integer_ratio(
        self: NativeFloatEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_conjugate(
        self: NativeFloatEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_hex(
        self: NativeFloatEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_fromhex(
        self: NativeFloatEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeBoolEmitter(NativeIntEmitter) {
    """Bool-specific emitter.

    Inherits all int operations but overrides bitwise operators so that
    True & False yields False (bool i1) rather than 0 (i64), matching
    Python semantics where bool & bool -> bool.
    """
    def emit_op_and(
        self: NativeBoolEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_or(
        self: NativeBoolEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_xor(
        self: NativeBoolEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeComplexEmitter(ComplexEmitter[(ir.Value, NativeEmitCtx)]) {
    """Helper: load real and imag from a JacComplex pointer."""
    def _load_parts(
        self: NativeComplexEmitter, ctx: NativeEmitCtx, val: ir.Value
    ) -> (tuple | None);

    """Helper: create a new JacComplex from real and imag f64 values."""
    def _make_complex(
        self: NativeComplexEmitter, ctx: NativeEmitCtx, real: ir.Value, imag: ir.Value
    ) -> ir.Value;

    def emit_conjugate(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_add(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_sub(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_mul(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_truediv(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_pow(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_eq(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_ne(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_neg(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_pos(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);
}


# =============================================================================
#  String Types
# =============================================================================
class NativeStrEmitter(StrEmitter[(ir.Value, NativeEmitCtx)]) {
    # Case conversion
    def emit_capitalize(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_casefold(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_lower(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_upper(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def _emit_case_transform(
        self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, cfunc_name: str
    ) -> (ir.Value | None);

    def emit_title(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_swapcase(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    # Search
    def emit_count(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_find(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rfind(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_index(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rindex(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_startswith(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_endswith(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    # Modification
    def emit_replace(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_strip(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_lstrip(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rstrip(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_removeprefix(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_removesuffix(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    # Split and join
    def emit_split(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rsplit(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_splitlines(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_join(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_partition(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rpartition(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    # Formatting and alignment
    def emit_format(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_format_map(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_center(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_ljust(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rjust(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_zfill(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_expandtabs(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    # Character tests
    """Helper: loop over chars, call C ctype function, return 1 if all pass."""
    def _emit_char_test(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        cfunc_name: str,
        prefix: str,
        empty_is_true: bool = False
    ) -> (ir.Value | None);

    def emit_isalnum(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isalpha(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isascii(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isdecimal(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isdigit(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isidentifier(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_islower(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isnumeric(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isprintable(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isspace(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_istitle(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isupper(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    # Encoding
    def emit_encode(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    # Translation
    def emit_translate(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_maketrans(
        self: NativeStrEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeBytesEmitter(BytesEmitter[(ir.Value, NativeEmitCtx)]) {
    # Decoding
    def emit_decode(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_hex(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_fromhex(
        self: NativeBytesEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Search
    def emit_count(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_find(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rfind(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_index(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rindex(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_startswith(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_endswith(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    # Modification
    def emit_replace(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_strip(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_lstrip(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rstrip(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_removeprefix(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_removesuffix(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    # Split and join
    def emit_split(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rsplit(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_splitlines(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_join(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_partition(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rpartition(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    # Case (ASCII only)
    def emit_capitalize(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_lower(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_upper(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_title(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_swapcase(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    # Character tests (ASCII only)
    def emit_isalnum(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isalpha(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isascii(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isdigit(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_islower(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isspace(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_istitle(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isupper(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    # Alignment
    def emit_center(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_ljust(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rjust(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_zfill(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_expandtabs(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    # Translation
    def emit_translate(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_maketrans(
        self: NativeBytesEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}


# =============================================================================
#  Collection Types
# =============================================================================
class NativeListEmitter(ListEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_append(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_extend(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_insert(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_remove(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_pop(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_del_at(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None) {
        # del list[idx]: shift elements from idx+1 leftward, then decrement length.
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
        del_idx = args[0];
        # release element at del_idx before shifting
        if isinstance(helpers["elem_type"], ir.PointerType) {
            if p.rc_release_simple_fn is None {
                p._emit_rc_helpers();
            }
            _i8p_da = ir.IntType(8).as_pointer();
            _da_elem = b.call(helpers["get"], [target, del_idx], name="delat_rel_elem");
            _da_cast = b.bitcast(_da_elem, _i8p_da, name="delat_rel_cast");
            b.call(p.rc_release_simple_fn, [_da_cast]);
        }
        len_ptr = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="delat.len.ptr"
        );
        cur_len = b.load(len_ptr, name="delat.len");
        func = b.basic_block.function;
        entry_bb = b.basic_block;
        # shift_start = del_idx + 1, computed in entry_bb before branch
        shift_start = b.add(del_idx, ir.Constant(i64, 1), name="delat.start");
        loop_bb = func.append_basic_block(name="delat.loop");
        body_bb = func.append_basic_block(name="delat.body");
        done_bb = func.append_basic_block(name="delat.done");
        b.branch(loop_bb);
        b.position_at_start(loop_bb);
        si = b.phi(i64, name="delat.si");
        si.add_incoming(shift_start, entry_bb);
        at_end = b.icmp_unsigned(">=", si, cur_len, name="delat.end");
        b.cbranch(at_end, done_bb, body_bb);
        b.position_at_start(body_bb);
        prev = b.sub(si, ir.Constant(i64, 1), name="delat.prev");
        if isinstance(helpers["elem_type"], ir.PointerType) {
            # Raw GEP+store: avoid spurious retain/release from __list_set_ptr during shift.
            _sh_dpp = b.gep(
                target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="sh_dpp"
            );
            _sh_da = b.load(_sh_dpp, name="sh_da");
            _sh_src = b.gep(_sh_da, [si], name="sh_src");
            _sh_val = b.load(_sh_src, name="sh_val");
            _sh_dst = b.gep(_sh_da, [prev], name="sh_dst");
            b.store(_sh_val, _sh_dst);
        } else {
            val = b.call(helpers["get"], [target, si], name="delat.val");
            b.call(helpers["set"], [target, prev, val]);
        }
        next_si = b.add(si, ir.Constant(i64, 1), name="delat.next");
        si.add_incoming(next_si, body_bb);
        b.branch(loop_bb);
        b.position_at_start(done_bb);
        new_len = b.sub(cur_len, ir.Constant(i64, 1), name="delat.newlen");
        b.store(new_len, len_ptr);
        return ir.Constant(i64, 0);
    }

    def emit_clear(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_index(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_count(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_sort(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_reverse(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_copy(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeDictEmitter(DictEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_get(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_keys(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_values(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_items(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_pop(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_remove(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_popitem(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_setdefault(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_update(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_clear(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_copy(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_fromkeys(
        self: NativeDictEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeSetEmitter(SetEmitter[(ir.Value, NativeEmitCtx)]) {
    # Mutation
    def emit_add(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_remove(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_discard(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_pop(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_clear(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    # Set algebra
    def _emit_set_iterate(
        self: NativeSetEmitter, ctx: NativeEmitCtx, source: ir.Value, prefix: str
    ) -> tuple;

    def emit_union(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_intersection(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_difference(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_symmetric_difference(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    # In-place set algebra
    def emit_update(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_intersection_update(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_difference_update(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_symmetric_difference_update(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    # Tests
    def emit_issubset(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_issuperset(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isdisjoint(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_copy(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeFrozensetEmitter(FrozensetEmitter[(ir.Value, NativeEmitCtx)]) {
    """Frozenset emitter — delegates to set emitter since frozenset uses same LLVM type."""
    def _get_set_emitter(
        self: NativeFrozensetEmitter, ctx: NativeEmitCtx
    ) -> (object | None);

    def emit_union(
        self: NativeFrozensetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_intersection(
        self: NativeFrozensetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_difference(
        self: NativeFrozensetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_symmetric_difference(
        self: NativeFrozensetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_issubset(
        self: NativeFrozensetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_issuperset(
        self: NativeFrozensetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isdisjoint(
        self: NativeFrozensetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_copy(
        self: NativeFrozensetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeTupleEmitter(TupleEmitter[(ir.Value, NativeEmitCtx)]) {
    """Helper: get struct type and element count from context."""
    def _get_struct_info(
        self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value
    ) -> (object | None);

    def emit_count(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_index(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_add(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_mul(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_eq(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_ne(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_lt(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_gt(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_le(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_ge(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_contains(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeRangeEmitter(RangeEmitter[(ir.Value, NativeEmitCtx)]) {
    """Helper: load start, stop, step from JacRange pointer."""
    def _load_range(
        self: NativeRangeEmitter, ctx: NativeEmitCtx, target: ir.Value
    ) -> (tuple | None);

    """Helper: check if val is in range(start, stop, step)."""
    def _in_range(
        self: NativeRangeEmitter,
        ctx: NativeEmitCtx,
        val: ir.Value,
        start: ir.Value,
        stop: ir.Value,
        step: ir.Value
    ) -> ir.Value;

    def emit_count(
        self: NativeRangeEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_index(
        self: NativeRangeEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_eq(
        self: NativeRangeEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_ne(
        self: NativeRangeEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_contains(
        self: NativeRangeEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);
}


# =============================================================================
#  Builtin Functions
# =============================================================================
class NativeBuiltinEmitter(BuiltinEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_print(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_input(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_len(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_abs(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_round(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_min(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_max(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_sum(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_sorted(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_reversed(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_enumerate(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_zip(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_map(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_filter(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_any(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_all(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isinstance(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_issubclass(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_type(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        return None;
    }

    def emit_id(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        if not args {
            return None;
        }
        arg_val = args[0];
        p = ctx.pass_ref;
        b = get_builder(p);
        i64 = ir.IntType(64);
        if isinstance(arg_val.type, ir.PointerType) {
            return b.ptrtoint(arg_val, i64, name="id.ptr");
        }
        if isinstance(arg_val.type, ir.IntType) {
            return p._coerce_type(arg_val, i64);
        }
        return None;
    }

    def emit_hash(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        if not args {
            return None;
        }
        arg_val = args[0];
        p = ctx.pass_ref;
        b = get_builder(p);
        i64 = ir.IntType(64);
        # int hash = identity
        if isinstance(arg_val.type, ir.IntType) {
            return p._coerce_type(arg_val, i64);
        }
        # string hash = djb2
        i8p = ir.IntType(8).as_pointer();
        if isinstance(arg_val.type, ir.PointerType) and arg_val.type == i8p {
            i8 = ir.IntType(8);
            func = b.basic_block.function;
            entry_bb = b.basic_block;
            loop_bb = func.append_basic_block(name="hash.loop");
            body_bb = func.append_basic_block(name="hash.body");
            done_bb = func.append_basic_block(name="hash.done");
            b.branch(loop_bb);
            b.position_at_start(loop_bb);
            h = b.phi(i64, name="hash.h");
            h.add_incoming(ir.Constant(i64, 5381), entry_bb);
            idx = b.phi(i64, name="hash.idx");
            idx.add_incoming(ir.Constant(i64, 0), entry_bb);
            cp = b.gep(arg_val, [idx], name="hash.cp");
            ch = b.load(cp, name="hash.ch");
            is_zero = b.icmp_unsigned("==", ch, ir.Constant(i8, 0), name="hash.end");
            b.cbranch(is_zero, done_bb, body_bb);
            b.position_at_start(body_bb);
            ch_ext = b.zext(ch, i64, name="hash.chext");
            h_shl5 = b.shl(h, ir.Constant(i64, 5), name="hash.shl5");
            h_plus_h = b.add(h_shl5, h, name="hash.mul33");
            h_next = b.add(h_plus_h, ch_ext, name="hash.next");
            next_idx = b.add(idx, ir.Constant(i64, 1), name="hash.nextidx");
            h.add_incoming(h_next, body_bb);
            idx.add_incoming(next_idx, body_bb);
            b.branch(loop_bb);
            b.position_at_start(done_bb);
            return h;
        }
        return None;
    }

    def emit_repr(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        if not args {
            return None;
        }
        arg_val = args[0];
        p = ctx.pass_ref;
        b = get_builder(p);
        i8p = ir.IntType(8).as_pointer();
        i64 = ir.IntType(64);
        rc_alloc_fn = p.rc_alloc_fn;
        buf_ptr = b.call(rc_alloc_fn, [ir.Constant(i64, 64)], name="repr.buf");
        snprintf = p._get_or_declare_extern(
            "snprintf", ir.IntType(32), [i8p, i64, i8p], var_arg=True
        );
        if isinstance(arg_val.type, ir.IntType) {
            fmt = p._get_snprintf_fmt("%ld");
            fmt_ptr = b.bitcast(fmt, i8p, name="repr.fmt.ptr");
            coerced = p._coerce_type(arg_val, i64);
            b.call(snprintf, [buf_ptr, ir.Constant(i64, 64), fmt_ptr, coerced]);
            return buf_ptr;
        }
        if isinstance(arg_val.type, ir.DoubleType) {
            fmt = p._get_snprintf_fmt("%g");
            fmt_ptr = b.bitcast(fmt, i8p, name="repr.fmt.ptr");
            b.call(snprintf, [buf_ptr, ir.Constant(i64, 64), fmt_ptr, arg_val]);
            return buf_ptr;
        }
        if isinstance(arg_val.type, ir.PointerType) and arg_val.type == i8p {
            fmt = p._get_snprintf_fmt("'%s'");
            fmt_ptr = b.bitcast(fmt, i8p, name="repr.fmt.ptr");
            b.call(snprintf, [buf_ptr, ir.Constant(i64, 64), fmt_ptr, arg_val]);
            return buf_ptr;
        }
        return None;
    }

    def emit_chr(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        if not args {
            return None;
        }
        arg_val = args[0];
        p = ctx.pass_ref;
        b = get_builder(p);
        i8 = ir.IntType(8);
        i64 = ir.IntType(64);
        rc_alloc_fn = p.rc_alloc_fn;
        buf = b.call(rc_alloc_fn, [ir.Constant(i64, 2)], name="chr.buf");
        byte_val = b.trunc(arg_val, i8, name="chr.byte");
        b.store(byte_val, buf);
        null_ptr = b.gep(buf, [ir.Constant(i64, 1)], name="chr.null_ptr");
        b.store(ir.Constant(i8, 0), null_ptr);
        return buf;
    }

    def emit_ord(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        if not args {
            return None;
        }
        arg_val = args[0];
        b = ctx.pass_ref.builder;
        byte_val = b.load(arg_val, name="ord.byte");
        return b.zext(byte_val, ir.IntType(64), name="ord.val");
    }

    def emit_hex(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = get_builder(p);
        i8p = ir.IntType(8).as_pointer();
        i64 = ir.IntType(64);
        rc_alloc_fn = p.rc_alloc_fn;
        snprintf = p._get_or_declare_extern(
            "snprintf", ir.IntType(32), [i8p, i64, i8p], var_arg=True
        );
        buf = b.call(rc_alloc_fn, [ir.Constant(i64, 32)], name="hex.buf");
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

    def emit_oct(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = get_builder(p);
        i8p = ir.IntType(8).as_pointer();
        i64 = ir.IntType(64);
        rc_alloc_fn = p.rc_alloc_fn;
        snprintf = p._get_or_declare_extern(
            "snprintf", ir.IntType(32), [i8p, i64, i8p], var_arg=True
        );
        buf = b.call(rc_alloc_fn, [ir.Constant(i64, 32)], name="oct.buf");
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

    def emit_bin(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        if not args {
            return None;
        }
        p = ctx.pass_ref;
        b = get_builder(p);
        i8 = ir.IntType(8);
        i8p = i8.as_pointer();
        i64 = ir.IntType(64);
        rc_alloc_fn = p.rc_alloc_fn;
        snprintf = p._get_or_declare_extern(
            "snprintf", ir.IntType(32), [i8p, i64, i8p], var_arg=True
        );
        # Allocate buffer: "0b" + up to 64 digits + sign + null = 68
        buf = b.call(rc_alloc_fn, [ir.Constant(i64, 68)], name="bin.buf");
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
            b.add(bit, ir.Constant(i64, 48), name="bin.digit.val"), i8, name="bin.digit"
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

    def emit_pow(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None) {
        if len(args) < 2 {
            return None;
        }
        p = ctx.pass_ref;
        base = args[0];
        exp = args[1];
        if isinstance(base.type, ir.IntType) and isinstance(exp.type, ir.IntType) {
            return p._codegen_int_pow(base, exp);
        }
        if isinstance(base.type, ir.DoubleType)
        and isinstance(exp.type, ir.DoubleType) {
            pow_fn = p._get_or_declare_extern(
                "pow", ir.DoubleType(), [ir.DoubleType(), ir.DoubleType()]
            );
            return get_builder(p).call(pow_fn, [base, exp], name="pow.result");
        }
        return None;
    }

    def emit_divmod(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_iter(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_next(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_callable(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_getattr(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_setattr(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_hasattr(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_delattr(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_vars(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_dir(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_open(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_format(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_ascii(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Type conversion builtins
    def emit_str(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_int(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_float(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_bool(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_list(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_dict(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_set(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_tuple(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_frozenset(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_bytes(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_bytearray(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_complex(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}
