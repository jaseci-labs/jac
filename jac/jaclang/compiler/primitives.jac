"""Jac Primitive Codegen Interface.

Generic abstract emitter contracts for all Jac primitive type methods,
operator semantics, and builtin functions, parameterized on value type V
and context type C.

Each compilation backend (Python, ECMAScript, Native) must subclass every
emitter class here, binding V and C to its own types:
  - ES:     V = str,      C = ESEmitCtx
  - Native: V = ir.Value,  C = NativeEmitCtx

Named methods receive a backend-specific context `ctx: C`, a target
expression `target: V` (the object the method is called on), and a list
of argument expressions `args: list[V]`. Static methods and builtin
functions omit the target parameter.

Operator methods (emit_op_*) follow the same signature: target is the
left-hand operand and args[0] is the right-hand operand for binary ops.
For unary ops, target is the sole operand and args is empty. For
membership tests (emit_op_contains), target is the container (right-hand
side of `in`) and args[0] is the element being tested.

In-place operator methods (emit_op_iadd, etc.) are provided for mutable
types where in-place mutation differs from create-and-reassign.

Returning None signals that this backend has not yet implemented the
operation, allowing the dispatch layer to fall back gracefully.
"""

import from typing { TypeVar, Generic }

glob V = TypeVar('V'),
     C = TypeVar('C');

# =============================================================================
#  Numeric Types
# =============================================================================
class IntEmitter(Generic[
    (V, C)
]) {
    # --- Named methods ---
    def emit_bit_length(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_bit_count(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_to_bytes(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_as_integer_ratio(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_conjugate(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_from_bytes(self, ctx: C, args: list[V]) -> (V | None) abs;
    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # +

    def emit_op_sub(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # -

    def emit_op_mul(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # *

    def emit_op_truediv(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # /

    def emit_op_floordiv(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # //

    def emit_op_mod(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # %

    def emit_op_pow(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # **

    # --- Bitwise operators ---
    def emit_op_and(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # &

    def emit_op_or(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # |

    def emit_op_xor(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # ^

    def emit_op_lshift(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # <<

    def emit_op_rshift(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # >>

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # ==

    def emit_op_ne(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # !=

    def emit_op_lt(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # <

    def emit_op_gt(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # >

    def emit_op_le(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # <=

    def emit_op_ge(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # >=

    # --- Unary operators ---
    def emit_op_neg(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # -x

    def emit_op_pos(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # +x

    def emit_op_invert(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # ~x

}

class FloatEmitter(Generic[(V, C)]) {
    # --- Named methods ---
    def emit_is_integer(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_as_integer_ratio(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_conjugate(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_hex(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_fromhex(self, ctx: C, args: list[V]) -> (V | None) abs;
    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # +

    def emit_op_sub(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # -

    def emit_op_mul(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # *

    def emit_op_truediv(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # /

    def emit_op_floordiv(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # //

    def emit_op_mod(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # %

    def emit_op_pow(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # **

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # ==

    def emit_op_ne(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # !=

    def emit_op_lt(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # <

    def emit_op_gt(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # >

    def emit_op_le(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # <=

    def emit_op_ge(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # >=

    # --- Unary operators ---
    def emit_op_neg(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # -x

    def emit_op_pos(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # +x

}

class ComplexEmitter(Generic[(V, C)]) {
    # --- Named methods ---
    def emit_conjugate(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # +

    def emit_op_sub(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # -

    def emit_op_mul(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # *

    def emit_op_truediv(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # /

    def emit_op_pow(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # **

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # ==

    def emit_op_ne(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # !=

    # --- Unary operators ---
    def emit_op_neg(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # -x

    def emit_op_pos(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # +x

}

# =============================================================================
#  String Types
# =============================================================================
class StrEmitter(Generic[
    (V, C)
]) {
    # Case conversion
    def emit_capitalize(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_casefold(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_lower(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_upper(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_title(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_swapcase(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # Search
    def emit_count(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_find(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_rfind(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_index(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_rindex(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_startswith(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_endswith(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # Modification
    def emit_replace(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_strip(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_lstrip(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_rstrip(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_removeprefix(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_removesuffix(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # Split and join
    def emit_split(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_rsplit(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_splitlines(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_join(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_partition(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_rpartition(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # Formatting and alignment
    def emit_format(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_format_map(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_center(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_ljust(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_rjust(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_zfill(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_expandtabs(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # Character tests
    def emit_isalnum(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isalpha(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isascii(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isdecimal(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isdigit(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isidentifier(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_islower(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isnumeric(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isprintable(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isspace(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_istitle(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isupper(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # Encoding
    def emit_encode(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # Translation
    def emit_translate(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_maketrans(self, ctx: C, args: list[V]) -> (V | None) abs;
    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # +  (concatenation)

    def emit_op_mul(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # *  (repetition)

    def emit_op_mod(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # %  (printf formatting)

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # ==

    def emit_op_ne(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # !=

    def emit_op_lt(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # <  (lexicographic)

    def emit_op_gt(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # >

    def emit_op_le(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # <=

    def emit_op_ge(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # >=

    # --- Membership operators ---
    def emit_op_contains(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # in (substring test)

}

class BytesEmitter(Generic[(V, C)]) {
    # Decoding
    def emit_decode(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_hex(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_fromhex(self, ctx: C, args: list[V]) -> (V | None) abs;
    # Search
    def emit_count(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_find(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_rfind(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_index(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_rindex(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_startswith(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_endswith(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # Modification
    def emit_replace(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_strip(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_lstrip(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_rstrip(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_removeprefix(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_removesuffix(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # Split and join
    def emit_split(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_rsplit(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_splitlines(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_join(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_partition(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_rpartition(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # Case (ASCII only)
    def emit_capitalize(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_lower(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_upper(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_title(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_swapcase(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # Character tests (ASCII only)
    def emit_isalnum(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isalpha(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isascii(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isdigit(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_islower(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isspace(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_istitle(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isupper(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # Alignment
    def emit_center(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_ljust(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_rjust(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_zfill(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_expandtabs(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # Translation
    def emit_translate(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_maketrans(self, ctx: C, args: list[V]) -> (V | None) abs;
    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # +  (concatenation)

    def emit_op_mul(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # *  (repetition)

    def emit_op_mod(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # %  (printf formatting)

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # ==

    def emit_op_ne(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # !=

    def emit_op_lt(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # <  (lexicographic)

    def emit_op_gt(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # >

    def emit_op_le(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # <=

    def emit_op_ge(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # >=

    # --- Membership operators ---
    def emit_op_contains(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # in (byte membership)

}

# =============================================================================
#  Collection Types
# =============================================================================
class ListEmitter(Generic[
    (V, C)
]) {
    # --- Named methods ---
    def emit_append(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_extend(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_insert(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_remove(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_pop(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_clear(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_index(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_count(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_sort(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_reverse(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_copy(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # +  (concatenation)

    def emit_op_mul(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # *  (repetition)

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # == (structural)

    def emit_op_ne(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # !=

    def emit_op_lt(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # <  (lexicographic)

    def emit_op_gt(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # >

    def emit_op_le(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # <=

    def emit_op_ge(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # >=

    # --- Membership operators ---
    def emit_op_contains(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # in

    # --- In-place operators ---
    def emit_op_iadd(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # += (extend in-place)

    def emit_op_imul(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # *= (repeat in-place)

}

class DictEmitter(Generic[(V, C)]) {
    # --- Named methods ---
    def emit_get(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_keys(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_values(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_items(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_pop(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_popitem(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_setdefault(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_update(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_clear(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_copy(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_fromkeys(self, ctx: C, args: list[V]) -> (V | None) abs;
    # --- Bitwise operators (dict merge, Python 3.9+) ---
    def emit_op_or(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # |  (merge)

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # == (structural)

    def emit_op_ne(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # !=

    # --- Membership operators ---
    def emit_op_contains(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # in (key membership)

    # --- In-place operators ---
    def emit_op_ior(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # |= (update in-place)

}

class SetEmitter(Generic[(V, C)]) {
    # --- Named methods (mutation) ---
    def emit_add(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_remove(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_discard(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_pop(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_clear(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # --- Named methods (set algebra, return new set) ---
    def emit_union(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_intersection(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_difference(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_symmetric_difference(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # --- Named methods (in-place set algebra) ---
    def emit_update(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_intersection_update(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_difference_update(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_symmetric_difference_update(
        self, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;
    # --- Named methods (tests) ---
    def emit_issubset(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_issuperset(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isdisjoint(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_copy(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # --- Set algebra operators ---
    def emit_op_or(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # |  (union)

    def emit_op_and(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # &  (intersection)

    def emit_op_sub(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # -  (difference)

    def emit_op_xor(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # ^  (symmetric difference)

    # --- Comparison operators (subset/superset) ---
    def emit_op_eq(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # == (set equality)

    def emit_op_ne(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # !=

    def emit_op_le(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # <= (subset)

    def emit_op_lt(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # <  (proper subset)

    def emit_op_ge(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # >= (superset)

    def emit_op_gt(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # >  (proper superset)

    # --- Membership operators ---
    def emit_op_contains(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # in

    # --- In-place operators ---
    def emit_op_ior(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # |= (update)

    def emit_op_iand(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # &= (intersection_update)

    def emit_op_isub(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # -= (difference_update)

    def emit_op_ixor(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # ^= (symmetric_difference_update)

}

class FrozensetEmitter(Generic[(V, C)]) {
    # --- Named methods ---
    def emit_union(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_intersection(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_difference(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_symmetric_difference(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_issubset(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_issuperset(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isdisjoint(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_copy(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # --- Set algebra operators ---
    def emit_op_or(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # |  (union)

    def emit_op_and(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # &  (intersection)

    def emit_op_sub(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # -  (difference)

    def emit_op_xor(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # ^  (symmetric difference)

    # --- Comparison operators (subset/superset) ---
    def emit_op_eq(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # == (set equality)

    def emit_op_ne(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # !=

    def emit_op_le(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # <= (subset)

    def emit_op_lt(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # <  (proper subset)

    def emit_op_ge(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # >= (superset)

    def emit_op_gt(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # >  (proper superset)

    # --- Membership operators ---
    def emit_op_contains(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # in

}

class TupleEmitter(Generic[(V, C)]) {
    # --- Named methods ---
    def emit_count(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_index(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # +  (concatenation)

    def emit_op_mul(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # *  (repetition)

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # == (structural)

    def emit_op_ne(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # !=

    def emit_op_lt(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # <  (lexicographic)

    def emit_op_gt(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # >

    def emit_op_le(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # <=

    def emit_op_ge(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # >=

    # --- Membership operators ---
    def emit_op_contains(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # in

}

class RangeEmitter(Generic[(V, C)]) {
    # --- Named methods ---
    def emit_count(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_index(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # --- Comparison operators ---
    def emit_op_eq(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # ==

    def emit_op_ne(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # !=

    # --- Membership operators ---
    def emit_op_contains(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;  # in

}

# =============================================================================
#  Builtin Functions
# =============================================================================
class BuiltinEmitter(Generic[
    (V, C)
]) {
    def emit_print(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_input(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_len(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_abs(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_round(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_min(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_max(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_sum(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_sorted(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_reversed(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_enumerate(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_zip(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_map(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_filter(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_any(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_all(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_isinstance(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_issubclass(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_type(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_id(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_hash(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_repr(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_chr(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_ord(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_hex(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_oct(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_bin(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_pow(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_divmod(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_iter(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_next(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_callable(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_getattr(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_setattr(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_hasattr(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_delattr(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_vars(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_dir(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_open(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_format(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_ascii(self, ctx: C, args: list[V]) -> (V | None) abs;
    # Type conversion builtins
    def emit_str(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_int(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_float(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_bool(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_list(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_dict(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_set(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_tuple(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_frozenset(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_bytes(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_complex(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_range(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_slice(self, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_bytearray(self, ctx: C, args: list[V]) -> (V | None) abs;
}
