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
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_bit_count(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_to_bytes(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_as_integer_ratio(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_conjugate(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_from_bytes(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_sub(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_mul(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_truediv(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_floordiv(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_mod(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_pow(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Bitwise operators ---
    def emit_op_and(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_or(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_xor(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_lshift(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_rshift(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_lt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_gt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_le(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ge(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Unary operators ---
    def emit_op_neg(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_pos(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_invert(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

class ESFloatEmitter(FloatEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_is_integer(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_as_integer_ratio(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_conjugate(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_hex(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_fromhex(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_sub(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_mul(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_truediv(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_floordiv(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_mod(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_pow(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_lt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_gt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_le(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ge(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Unary operators ---
    def emit_op_neg(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_pos(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

class ESComplexEmitter(ComplexEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_conjugate(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_sub(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_mul(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_truediv(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_pow(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Unary operators ---
    def emit_op_neg(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_pos(
        self, ctx: ESEmitCtx, target: str, args: list[str]
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
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_or(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_xor(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

# =============================================================================
#  String Types
# =============================================================================
class ESStrEmitter(StrEmitter[(str, ESEmitCtx)]) {
    # Case conversion
    def emit_capitalize(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_casefold(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_lower(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_upper(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_title(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_swapcase(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Search
    def emit_count(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_find(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_rfind(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_index(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_rindex(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_startswith(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_endswith(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Modification
    def emit_replace(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_strip(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_lstrip(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_rstrip(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_removeprefix(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_removesuffix(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Split and join
    def emit_split(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_rsplit(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_splitlines(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_join(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_partition(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_rpartition(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Formatting and alignment
    def emit_format(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_format_map(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_center(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_ljust(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_rjust(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_zfill(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_expandtabs(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Character tests
    def emit_isalnum(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isalpha(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isascii(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isdecimal(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isdigit(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isidentifier(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_islower(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isnumeric(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isprintable(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isspace(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_istitle(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isupper(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Encoding
    def emit_encode(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # Translation
    def emit_translate(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_maketrans(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_mul(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_mod(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_lt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_gt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_le(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ge(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Membership operators ---
    def emit_op_contains(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

class ESBytesEmitter(BytesEmitter[(str, ESEmitCtx)]) {
    # Decoding
    def emit_decode(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_hex(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_fromhex(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    # Search
    def emit_count(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_find(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_rfind(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_index(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_rindex(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_startswith(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_endswith(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Modification
    def emit_replace(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_strip(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_lstrip(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_rstrip(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_removeprefix(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_removesuffix(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Split and join
    def emit_split(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_rsplit(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_splitlines(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_join(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_partition(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_rpartition(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Case (ASCII only)
    def emit_capitalize(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_lower(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_upper(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_title(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_swapcase(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Character tests (ASCII only)
    def emit_isalnum(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isalpha(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isascii(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isdigit(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_islower(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isspace(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_istitle(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isupper(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Alignment
    def emit_center(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_ljust(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_rjust(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_zfill(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_expandtabs(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # Translation
    def emit_translate(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_maketrans(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_mul(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_mod(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_lt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_gt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_le(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ge(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Membership operators ---
    def emit_op_contains(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

# =============================================================================
#  Collection Types
# =============================================================================
class ESListEmitter(ListEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_append(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_extend(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_insert(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_remove(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_pop(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_clear(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_index(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_count(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_sort(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_reverse(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_copy(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_mul(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_lt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_gt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_le(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ge(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Membership operators ---
    def emit_op_contains(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # --- In-place operators ---
    def emit_op_iadd(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_imul(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

class ESDictEmitter(DictEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_get(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_keys(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_values(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_items(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_pop(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_popitem(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_setdefault(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_update(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_clear(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_copy(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_fromkeys(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    # --- Bitwise operators (dict merge) ---
    def emit_op_or(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Membership operators ---
    def emit_op_contains(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # --- In-place operators ---
    def emit_op_ior(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

class ESSetEmitter(SetEmitter[(str, ESEmitCtx)]) {
    # --- Named methods (mutation) ---
    def emit_add(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_remove(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_discard(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_pop(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_clear(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Named methods (set algebra) ---
    def emit_union(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_intersection(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_difference(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_symmetric_difference(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # --- Named methods (in-place set algebra) ---
    def emit_update(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_intersection_update(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_difference_update(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_symmetric_difference_update(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # --- Named methods (tests) ---
    def emit_issubset(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_issuperset(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isdisjoint(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_copy(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Set algebra operators ---
    def emit_op_or(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_and(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_sub(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_xor(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Comparison operators (subset/superset) ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_le(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_lt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ge(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_gt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Membership operators ---
    def emit_op_contains(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    # --- In-place operators ---
    def emit_op_ior(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_iand(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_isub(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_op_ixor(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

class ESFrozensetEmitter(FrozensetEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_union(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_intersection(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_difference(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_symmetric_difference(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_issubset(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_issuperset(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_isdisjoint(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);

    def emit_copy(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Set algebra operators ---
    def emit_op_or(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_and(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_sub(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_xor(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Comparison operators (subset/superset) ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_le(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_lt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ge(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_gt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Membership operators ---
    def emit_op_contains(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

class ESTupleEmitter(TupleEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_count(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_index(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_mul(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_lt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_gt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_le(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ge(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Membership operators ---
    def emit_op_contains(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

class ESRangeEmitter(RangeEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_count(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_index(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None);
    # --- Membership operators ---
    def emit_op_contains(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None);
}

# =============================================================================
#  Builtin Functions
# =============================================================================
class ESBuiltinEmitter(BuiltinEmitter[(str, ESEmitCtx)]) {
    def emit_print(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_input(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_len(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_abs(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_round(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_min(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_max(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_sum(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_sorted(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_reversed(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_enumerate(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_zip(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_map(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_filter(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_any(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_all(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_isinstance(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_issubclass(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_type(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_id(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_hash(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_repr(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_chr(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_ord(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_hex(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_oct(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_bin(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_pow(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_divmod(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_iter(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_next(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_callable(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_getattr(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_setattr(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_hasattr(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_delattr(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_vars(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_dir(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_open(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_format(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_ascii(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    # Type conversion builtins
    def emit_str(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_int(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_float(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_bool(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_list(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_dict(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_set(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_tuple(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_frozenset(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_bytes(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_complex(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_range(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_slice(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
    def emit_bytearray(self, ctx: ESEmitCtx, args: list[str]) -> (str | None);
}
