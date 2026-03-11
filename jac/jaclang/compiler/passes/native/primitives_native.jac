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
obj NativeEmitCtx {
    """Native emission — provides typed access to LLVM infrastructure.

    Created per dispatch call with the appropriate type_key.
    """
    has pass_ref: object,
        type_key: str = "";
}


# =============================================================================
#  Numeric Types
# =============================================================================
class NativeIntEmitter(IntEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_bit_length(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_bit_count(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_to_bytes(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_as_integer_ratio(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_bit_length(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_bit_count(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_conjugate(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_from_bytes(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeFloatEmitter(FloatEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_is_integer(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_as_integer_ratio(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_conjugate(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_hex(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_fromhex(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeBoolEmitter(NativeIntEmitter) {
    """Bool-specific emitter.

    Inherits all int operations but overrides bitwise operators so that
    True & False yields False (bool i1) rather than 0 (i64), matching
    Python semantics where bool & bool -> bool.
    """
    def emit_op_and(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_or(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_xor(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeBoolEmitter(NativeIntEmitter) {
    """Bool-specific emitter.

    Inherits all int operations but overrides bitwise operators so that
    True & False yields False (bool i1) rather than 0 (i64), matching
    Python semantics where bool & bool -> bool.
    """
    def emit_op_and(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_or(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_xor(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeComplexEmitter(ComplexEmitter[(ir.Value, NativeEmitCtx)]) {
    """Helper: load real and imag from a JacComplex pointer."""
    def _load_parts(self, ctx: NativeEmitCtx, val: ir.Value) -> (tuple | None);

    """Helper: create a new JacComplex from real and imag f64 values."""
    def _make_complex(
        self, ctx: NativeEmitCtx, real: ir.Value, imag: ir.Value
    ) -> ir.Value;

    def emit_conjugate(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_add(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_sub(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_mul(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_truediv(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_pow(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_eq(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_ne(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_neg(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_pos(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);
}


# =============================================================================
#  String Types
# =============================================================================
class NativeStrEmitter(StrEmitter[(ir.Value, NativeEmitCtx)]) {
    # Case conversion
    def emit_capitalize(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_casefold(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_lower(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_upper(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def _emit_case_transform(
        self, ctx: NativeEmitCtx, target: ir.Value, cfunc_name: str
    ) -> (ir.Value | None);

    def emit_title(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_swapcase(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Search
    def emit_count(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_find(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rfind(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_index(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rindex(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_startswith(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_endswith(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Modification
    def emit_replace(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_strip(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_lstrip(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rstrip(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_removeprefix(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_removesuffix(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Split and join
    def emit_split(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rsplit(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_splitlines(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_join(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_partition(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rpartition(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Formatting and alignment
    def emit_format(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_format_map(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_center(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_ljust(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rjust(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_zfill(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_expandtabs(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Character tests
    """Helper: loop over chars, call C ctype function, return 1 if all pass."""
    def _emit_char_test(
        self,
        ctx: NativeEmitCtx,
        target: ir.Value,
        cfunc_name: str,
        prefix: str,
        empty_is_true: bool = False
    ) -> (ir.Value | None);

    def emit_isalnum(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isalpha(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isascii(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isdecimal(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isdigit(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isidentifier(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_islower(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isnumeric(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isprintable(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isspace(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_istitle(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isupper(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Encoding
    def emit_encode(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Translation
    def emit_translate(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_maketrans(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeBytesEmitter(BytesEmitter[(ir.Value, NativeEmitCtx)]) {
    # Decoding
    def emit_decode(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_hex(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_fromhex(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Search
    def emit_count(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_find(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rfind(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_index(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rindex(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_startswith(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_endswith(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Modification
    def emit_replace(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_strip(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_lstrip(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rstrip(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_removeprefix(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_removesuffix(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Split and join
    def emit_split(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rsplit(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_splitlines(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_join(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_partition(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rpartition(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Case (ASCII only)
    def emit_capitalize(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_lower(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_upper(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_title(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_swapcase(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Character tests (ASCII only)
    def emit_isalnum(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isalpha(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isascii(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isdigit(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_islower(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isspace(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_istitle(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isupper(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Alignment
    def emit_center(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_ljust(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rjust(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_zfill(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_expandtabs(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Translation
    def emit_translate(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_maketrans(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}


# =============================================================================
#  Collection Types
# =============================================================================
class NativeListEmitter(ListEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_append(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_extend(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_insert(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_remove(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_pop(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_clear(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_index(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_count(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_sort(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_reverse(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_copy(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeDictEmitter(DictEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_get(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_keys(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_values(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_items(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_pop(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_remove(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_popitem(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_setdefault(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_update(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_clear(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_copy(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_fromkeys(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeSetEmitter(SetEmitter[(ir.Value, NativeEmitCtx)]) {
    # Mutation
    def emit_add(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_remove(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_discard(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_pop(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_clear(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Set algebra
    def _emit_set_iterate(
        self, ctx: NativeEmitCtx, source: ir.Value, prefix: str
    ) -> tuple;

    def emit_union(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_intersection(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_difference(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_symmetric_difference(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    # In-place set algebra
    def emit_update(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_intersection_update(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_difference_update(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_symmetric_difference_update(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    # Tests
    def emit_issubset(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_issuperset(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isdisjoint(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_copy(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeFrozensetEmitter(FrozensetEmitter[(ir.Value, NativeEmitCtx)]) {
    """Frozenset emitter — delegates to set emitter since frozenset uses same LLVM type."""
    def _get_set_emitter(self, ctx: NativeEmitCtx) -> (object | None);

    def emit_union(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_intersection(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_difference(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_symmetric_difference(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_issubset(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_issuperset(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isdisjoint(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_copy(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeTupleEmitter(TupleEmitter[(ir.Value, NativeEmitCtx)]) {
    """Helper: get struct type and element count from context."""
    def _get_struct_info(
        self, ctx: NativeEmitCtx, target: ir.Value
    ) -> (object | None);

    def emit_count(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_index(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_add(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_mul(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_eq(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_ne(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_lt(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_gt(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_le(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_ge(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_contains(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeRangeEmitter(RangeEmitter[(ir.Value, NativeEmitCtx)]) {
    """Helper: load start, stop, step from JacRange pointer."""
    def _load_range(self, ctx: NativeEmitCtx, target: ir.Value) -> (tuple | None);

    """Helper: check if val is in range(start, stop, step)."""
    def _in_range(
        self,
        ctx: NativeEmitCtx,
        val: ir.Value,
        start: ir.Value,
        stop: ir.Value,
        step: ir.Value
    ) -> ir.Value;

    def emit_count(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_index(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_eq(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_ne(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_contains(
        self, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
    ) -> (ir.Value | None);
}


# =============================================================================
#  Builtin Functions
# =============================================================================
class NativeBuiltinEmitter(BuiltinEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_print(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_input(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_len(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_abs(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_round(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_min(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_max(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_sum(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_sorted(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_reversed(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_enumerate(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_zip(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_map(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_filter(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_any(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_all(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_isinstance(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_issubclass(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_type(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_id(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_hash(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_repr(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_chr(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_ord(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_hex(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_oct(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_bin(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_pow(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_divmod(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_iter(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_next(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_callable(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_getattr(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_setattr(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_hasattr(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_delattr(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_vars(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_dir(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_open(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_format(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_ascii(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    # Type conversion builtins
    def emit_str(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_int(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_float(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_bool(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_list(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_dict(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_set(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_tuple(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_frozenset(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_bytes(self, ctx: NativeEmitCtx, args: list[ir.Value]) -> (ir.Value | None);
    def emit_bytearray(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_complex(
        self, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}
