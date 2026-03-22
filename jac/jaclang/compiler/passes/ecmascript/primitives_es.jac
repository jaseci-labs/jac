"""ECMAScript backend primitive emitter implementations.

Maps Jac primitive methods and operators to their JavaScript equivalents.
Where no direct JS equivalent exists, calls are emitted to the Jac JS
runtime library (_jac.str.partition, _jac.list.remove, etc.).

Each emitter is a stateless singleton; backend context is passed per-call
via ESEmitCtx.
"""

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
obj ESEmitCtx {
    """ES emission context — carries the JS code generator."""
    has unparser: object;
}

# --- Helpers -----------------------------------------------------------------
def _mcall(target: str, method: str, args: list[str]) -> str {
    """Emit target.method(arg1, arg2, ...).""";
    if len(args) > 0 {
        return target + "." + method + "(" + ", ".join(args) + ")";
    }
    return target + "." + method + "()";
}

def _fcall(name: str, args: list[str]) -> str {
    """Emit name(arg1, arg2, ...).""";
    if len(args) > 0 {
        return name + "(" + ", ".join(args) + ")";
    }
    return name + "()";
}

def _rt(ns: str, method: str, args: list[str]) -> str {
    """Emit a Jac JS runtime helper call: _jac.ns.method(args).""";
    if len(args) > 0 {
        return "_jac." + ns + "." + method + "(" + ", ".join(args) + ")";
    }
    return "_jac." + ns + "." + method + "()";
}

def _binop(left: str, op: str, right: str) -> str {
    """Emit (left op right) with parens for safety.""";
    return "(" + left + " " + op + " " + right + ")";
}


# =============================================================================
#  Numeric Types
# =============================================================================
class ESIntEmitter(IntEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_bit_length(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_bit_count(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_to_bytes(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_as_integer_ratio(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_conjugate(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_from_bytes(
        self: ESIntEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);
    # --- Arithmetic operators ---
    def emit_op_add(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_sub(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_mul(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_truediv(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_floordiv(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_mod(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_pow(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Bitwise operators ---
    def emit_op_and(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_or(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_xor(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_lshift(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_rshift(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # --- Comparison operators ---
    def emit_op_eq(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ne(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_lt(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_gt(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_le(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ge(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Unary operators ---
    def emit_op_neg(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_pos(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_invert(
        self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

class ESFloatEmitter(FloatEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_is_integer(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_as_integer_ratio(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_conjugate(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_hex(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_fromhex(
        self: ESFloatEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);
    # --- Arithmetic operators ---
    def emit_op_add(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_sub(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_mul(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_truediv(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_floordiv(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_mod(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_pow(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Comparison operators ---
    def emit_op_eq(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ne(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_lt(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_gt(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_le(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ge(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Unary operators ---
    def emit_op_neg(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_pos(
        self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

class ESComplexEmitter(ComplexEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_conjugate(
        self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # --- Arithmetic operators ---
    def emit_op_add(
        self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_sub(
        self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_mul(
        self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_truediv(
        self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_pow(
        self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Comparison operators ---
    def emit_op_eq(
        self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ne(
        self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Unary operators ---
    def emit_op_neg(
        self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_pos(
        self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

class ESBoolEmitter(ESIntEmitter) {
    """Bool-specific emitter.

    Inherits all int operations but overrides bitwise operators so that
    ``True & False`` yields ``false`` (boolean) rather than ``0`` (number)
    in the JS output, matching Python semantics where bool & bool → bool.
    """
    # Override bitwise ops to return boolean
    def emit_op_and(
        self: ESBoolEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_or(
        self: ESBoolEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_xor(
        self: ESBoolEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

# =============================================================================
#  String Types
# =============================================================================
class ESStrEmitter(StrEmitter[(str, ESEmitCtx)]) {
    # Case conversion
    def emit_capitalize(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_casefold(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_lower(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_upper(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_title(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_swapcase(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Search
    def emit_count(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_find(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_rfind(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_index(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_rindex(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_startswith(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_endswith(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Modification
    def emit_replace(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_strip(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_lstrip(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_rstrip(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_removeprefix(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_removesuffix(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Split and join
    def emit_split(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_rsplit(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_splitlines(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_join(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_partition(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_rpartition(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Formatting and alignment
    def emit_format(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_format_map(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_center(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_ljust(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_rjust(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_zfill(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_expandtabs(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Character tests
    def emit_isalnum(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isalpha(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isascii(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isdecimal(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isdigit(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isidentifier(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_islower(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isnumeric(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isprintable(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isspace(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_istitle(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isupper(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Encoding
    def emit_encode(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # Translation
    def emit_translate(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_maketrans(
        self: ESStrEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);
    # --- Arithmetic operators ---
    def emit_op_add(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_mul(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_mod(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Comparison operators ---
    def emit_op_eq(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ne(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_lt(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_gt(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_le(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ge(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Membership operators ---
    def emit_op_contains(
        self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

class ESBytesEmitter(BytesEmitter[(str, ESEmitCtx)]) {
    # Decoding
    def emit_decode(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_hex(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_fromhex(
        self: ESBytesEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);
    # Search
    def emit_count(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_find(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_rfind(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_index(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_rindex(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_startswith(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_endswith(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Modification
    def emit_replace(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_strip(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_lstrip(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_rstrip(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_removeprefix(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_removesuffix(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Split and join
    def emit_split(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_rsplit(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_splitlines(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_join(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_partition(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_rpartition(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Case (ASCII only)
    def emit_capitalize(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_lower(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_upper(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_title(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_swapcase(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Character tests (ASCII only)
    def emit_isalnum(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isalpha(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isascii(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isdigit(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_islower(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isspace(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_istitle(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isupper(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Alignment
    def emit_center(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_ljust(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_rjust(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_zfill(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_expandtabs(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Translation
    def emit_translate(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_maketrans(
        self: ESBytesEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);
    # --- Arithmetic operators ---
    def emit_op_add(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_mul(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_mod(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Comparison operators ---
    def emit_op_eq(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ne(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_lt(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_gt(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_le(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ge(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Membership operators ---
    def emit_op_contains(
        self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

# =============================================================================
#  Collection Types
# =============================================================================
class ESListEmitter(ListEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_append(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_extend(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_insert(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_remove(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_pop(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_clear(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_index(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_count(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_sort(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_reverse(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_copy(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Arithmetic operators ---
    def emit_op_add(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_mul(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Comparison operators ---
    def emit_op_eq(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ne(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_lt(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_gt(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_le(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ge(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Membership operators ---
    def emit_op_contains(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # --- In-place operators ---
    def emit_op_iadd(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_imul(
        self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

class ESDictEmitter(DictEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_get(
        self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_keys(
        self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_values(
        self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_items(
        self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_pop(
        self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_popitem(
        self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_setdefault(
        self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_update(
        self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_clear(
        self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_copy(
        self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_fromkeys(
        self: ESDictEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);
    # --- Bitwise operators (dict merge) ---
    def emit_op_or(
        self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Comparison operators ---
    def emit_op_eq(
        self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ne(
        self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Membership operators ---
    def emit_op_contains(
        self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # --- In-place operators ---
    def emit_op_ior(
        self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

class ESSetEmitter(SetEmitter[(str, ESEmitCtx)]) {
    # --- Named methods (mutation) ---
    def emit_add(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_remove(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_discard(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_pop(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_clear(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Named methods (set algebra) ---
    def emit_union(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_intersection(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_difference(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_symmetric_difference(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # --- Named methods (in-place set algebra) ---
    def emit_update(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_intersection_update(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_difference_update(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_symmetric_difference_update(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # --- Named methods (tests) ---
    def emit_issubset(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_issuperset(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isdisjoint(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_copy(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Set algebra operators ---
    def emit_op_or(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_and(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_sub(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_xor(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Comparison operators (subset/superset) ---
    def emit_op_eq(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ne(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_le(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_lt(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ge(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_gt(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Membership operators ---
    def emit_op_contains(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # --- In-place operators ---
    def emit_op_ior(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_iand(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_isub(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ixor(
        self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

class ESFrozensetEmitter(FrozensetEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_union(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_intersection(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_difference(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_symmetric_difference(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_issubset(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_issuperset(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isdisjoint(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_copy(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Set algebra operators ---
    def emit_op_or(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_and(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_sub(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_xor(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Comparison operators (subset/superset) ---
    def emit_op_eq(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ne(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_le(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_lt(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ge(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_gt(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Membership operators ---
    def emit_op_contains(
        self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

class ESTupleEmitter(TupleEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_count(
        self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_index(
        self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Arithmetic operators ---
    def emit_op_add(
        self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_mul(
        self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Comparison operators ---
    def emit_op_eq(
        self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ne(
        self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_lt(
        self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_gt(
        self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_le(
        self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ge(
        self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Membership operators ---
    def emit_op_contains(
        self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

class ESRangeEmitter(RangeEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_count(
        self: ESRangeEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_index(
        self: ESRangeEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Comparison operators ---
    def emit_op_eq(
        self: ESRangeEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ne(
        self: ESRangeEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
    # --- Membership operators ---
    def emit_op_contains(
        self: ESRangeEmitter, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

# =============================================================================
#  Builtin Functions
# =============================================================================
class ESBuiltinEmitter(BuiltinEmitter[(str, ESEmitCtx)]) {
    def emit_print(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_input(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_len(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_abs(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_round(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_min(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_max(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_sum(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_sorted(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_reversed(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_enumerate(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_zip(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_map(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_filter(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_any(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_all(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_isinstance(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_issubclass(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_type(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_id(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_hash(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_repr(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_chr(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_ord(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_hex(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_oct(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_bin(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_pow(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_divmod(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_iter(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_next(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_callable(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_getattr(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_setattr(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_hasattr(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_delattr(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_vars(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_dir(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_open(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_format(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_ascii(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);
    # Type conversion builtins
    def emit_str(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_int(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_float(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_bool(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_list(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_dict(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_set(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_tuple(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_frozenset(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_bytes(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_complex(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_range(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_slice(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);

    def emit_bytearray(
        self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
    ) -> (str | None);
}
