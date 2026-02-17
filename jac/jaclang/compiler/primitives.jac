"""Jac Primitive Codegen Interface.

Generic abstract emitter contracts for all Jac primitive type methods and
builtin functions, parameterized on value type V and context type C.

Each compilation backend (Python, ECMAScript, Native) must subclass every
emitter class here, binding V and C to its own types:
  - ES:     V = str,      C = ESEmitCtx
  - Native: V = ir.Value,  C = NativeEmitCtx

All methods receive a backend-specific context `ctx: C`, a target
expression `target: V` (the object the method is called on), and a list
of argument expressions `args: list[V]`. Static methods and builtin
functions omit the target parameter.

Returning None signals that this backend has not yet implemented the
operation, allowing the dispatch layer to fall back gracefully.

Syntactic operations (indexing, slicing, iteration, arithmetic, comparison,
membership) are handled by each backend's expression codegen passes and
are not covered here — only user-callable named methods and builtin
functions are specified.
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
    def emit_bit_length(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_bit_count(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_to_bytes(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_as_integer_ratio(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_conjugate(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_from_bytes(self, ctx: C, args: list[V]) -> (V | None) abs;
}

class FloatEmitter(Generic[(V, C)]) {
    def emit_is_integer(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_as_integer_ratio(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_conjugate(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_hex(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_fromhex(self, ctx: C, args: list[V]) -> (V | None) abs;
}

class ComplexEmitter(Generic[(V, C)]) {
    def emit_conjugate(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
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
}

# =============================================================================
#  Collection Types
# =============================================================================
class ListEmitter(Generic[
    (V, C)
]) {
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
}

class DictEmitter(Generic[(V, C)]) {
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
}

class SetEmitter(Generic[(V, C)]) {
    # Mutation
    def emit_add(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_remove(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_discard(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_pop(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_clear(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # Set algebra (return new set)
    def emit_union(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_intersection(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_difference(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_symmetric_difference(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    # In-place set algebra
    def emit_update(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_intersection_update(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_difference_update(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_symmetric_difference_update(
        self, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;
    # Tests
    def emit_issubset(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_issuperset(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isdisjoint(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_copy(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
}

class FrozensetEmitter(Generic[(V, C)]) {
    def emit_union(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_intersection(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_difference(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_symmetric_difference(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_issubset(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_issuperset(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_isdisjoint(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_copy(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
}

class TupleEmitter(Generic[(V, C)]) {
    def emit_count(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_index(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
}

class RangeEmitter(Generic[(V, C)]) {
    def emit_count(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_index(self, ctx: C, target: V, args: list[V]) -> (V | None) abs;
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
}
