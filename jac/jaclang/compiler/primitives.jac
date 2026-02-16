"""Jac Primitive Codegen Interface.

Abstract emitter contracts for all Jac primitive type methods and builtin
functions. Each compilation backend (Python, ECMAScript, Native) must
provide an impl for every class defined here.

All methods receive pre-generated code fragments as strings and return
the generated output code as a string. The `target` parameter is the
generated expression for the object the method is called on. The `args`
parameter is the list of generated argument expressions.

Syntactic operations (indexing, slicing, iteration, arithmetic, comparison,
membership) are handled by each backend's expression codegen passes and
are not covered here — only user-callable named methods and builtin
functions are specified.
"""

# =============================================================================
#  Numeric Types
# =============================================================================
class IntEmitter {
    def emit_bit_length(target: str, args: list[str]) -> str abs;
    def emit_bit_count(target: str, args: list[str]) -> str abs;
    def emit_to_bytes(target: str, args: list[str]) -> str abs;
    def emit_as_integer_ratio(target: str, args: list[str]) -> str abs;
    def emit_conjugate(target: str, args: list[str]) -> str abs;
    def emit_from_bytes(args: list[str]) -> str abs;
}

class FloatEmitter {
    def emit_is_integer(target: str, args: list[str]) -> str abs;
    def emit_as_integer_ratio(target: str, args: list[str]) -> str abs;
    def emit_conjugate(target: str, args: list[str]) -> str abs;
    def emit_hex(target: str, args: list[str]) -> str abs;
    def emit_fromhex(args: list[str]) -> str abs;
}

class ComplexEmitter {
    def emit_conjugate(target: str, args: list[str]) -> str abs;
}

# =============================================================================
#  String Types
# =============================================================================
class StrEmitter {
    # Case conversion
    def emit_capitalize(target: str, args: list[str]) -> str abs;
    def emit_casefold(target: str, args: list[str]) -> str abs;
    def emit_lower(target: str, args: list[str]) -> str abs;
    def emit_upper(target: str, args: list[str]) -> str abs;
    def emit_title(target: str, args: list[str]) -> str abs;
    def emit_swapcase(target: str, args: list[str]) -> str abs;
    # Search
    def emit_count(target: str, args: list[str]) -> str abs;
    def emit_find(target: str, args: list[str]) -> str abs;
    def emit_rfind(target: str, args: list[str]) -> str abs;
    def emit_index(target: str, args: list[str]) -> str abs;
    def emit_rindex(target: str, args: list[str]) -> str abs;
    def emit_startswith(target: str, args: list[str]) -> str abs;
    def emit_endswith(target: str, args: list[str]) -> str abs;
    # Modification
    def emit_replace(target: str, args: list[str]) -> str abs;
    def emit_strip(target: str, args: list[str]) -> str abs;
    def emit_lstrip(target: str, args: list[str]) -> str abs;
    def emit_rstrip(target: str, args: list[str]) -> str abs;
    def emit_removeprefix(target: str, args: list[str]) -> str abs;
    def emit_removesuffix(target: str, args: list[str]) -> str abs;
    # Split and join
    def emit_split(target: str, args: list[str]) -> str abs;
    def emit_rsplit(target: str, args: list[str]) -> str abs;
    def emit_splitlines(target: str, args: list[str]) -> str abs;
    def emit_join(target: str, args: list[str]) -> str abs;
    def emit_partition(target: str, args: list[str]) -> str abs;
    def emit_rpartition(target: str, args: list[str]) -> str abs;
    # Formatting and alignment
    def emit_format(target: str, args: list[str]) -> str abs;
    def emit_format_map(target: str, args: list[str]) -> str abs;
    def emit_center(target: str, args: list[str]) -> str abs;
    def emit_ljust(target: str, args: list[str]) -> str abs;
    def emit_rjust(target: str, args: list[str]) -> str abs;
    def emit_zfill(target: str, args: list[str]) -> str abs;
    def emit_expandtabs(target: str, args: list[str]) -> str abs;
    # Character tests
    def emit_isalnum(target: str, args: list[str]) -> str abs;
    def emit_isalpha(target: str, args: list[str]) -> str abs;
    def emit_isascii(target: str, args: list[str]) -> str abs;
    def emit_isdecimal(target: str, args: list[str]) -> str abs;
    def emit_isdigit(target: str, args: list[str]) -> str abs;
    def emit_isidentifier(target: str, args: list[str]) -> str abs;
    def emit_islower(target: str, args: list[str]) -> str abs;
    def emit_isnumeric(target: str, args: list[str]) -> str abs;
    def emit_isprintable(target: str, args: list[str]) -> str abs;
    def emit_isspace(target: str, args: list[str]) -> str abs;
    def emit_istitle(target: str, args: list[str]) -> str abs;
    def emit_isupper(target: str, args: list[str]) -> str abs;
    # Encoding
    def emit_encode(target: str, args: list[str]) -> str abs;
    # Translation
    def emit_translate(target: str, args: list[str]) -> str abs;
    def emit_maketrans(args: list[str]) -> str abs;
}

class BytesEmitter {
    # Decoding
    def emit_decode(target: str, args: list[str]) -> str abs;
    def emit_hex(target: str, args: list[str]) -> str abs;
    def emit_fromhex(args: list[str]) -> str abs;
    # Search
    def emit_count(target: str, args: list[str]) -> str abs;
    def emit_find(target: str, args: list[str]) -> str abs;
    def emit_rfind(target: str, args: list[str]) -> str abs;
    def emit_index(target: str, args: list[str]) -> str abs;
    def emit_rindex(target: str, args: list[str]) -> str abs;
    def emit_startswith(target: str, args: list[str]) -> str abs;
    def emit_endswith(target: str, args: list[str]) -> str abs;
    # Modification
    def emit_replace(target: str, args: list[str]) -> str abs;
    def emit_strip(target: str, args: list[str]) -> str abs;
    def emit_lstrip(target: str, args: list[str]) -> str abs;
    def emit_rstrip(target: str, args: list[str]) -> str abs;
    def emit_removeprefix(target: str, args: list[str]) -> str abs;
    def emit_removesuffix(target: str, args: list[str]) -> str abs;
    # Split and join
    def emit_split(target: str, args: list[str]) -> str abs;
    def emit_rsplit(target: str, args: list[str]) -> str abs;
    def emit_splitlines(target: str, args: list[str]) -> str abs;
    def emit_join(target: str, args: list[str]) -> str abs;
    def emit_partition(target: str, args: list[str]) -> str abs;
    def emit_rpartition(target: str, args: list[str]) -> str abs;
    # Case (ASCII only)
    def emit_capitalize(target: str, args: list[str]) -> str abs;
    def emit_lower(target: str, args: list[str]) -> str abs;
    def emit_upper(target: str, args: list[str]) -> str abs;
    def emit_title(target: str, args: list[str]) -> str abs;
    def emit_swapcase(target: str, args: list[str]) -> str abs;
    # Character tests (ASCII only)
    def emit_isalnum(target: str, args: list[str]) -> str abs;
    def emit_isalpha(target: str, args: list[str]) -> str abs;
    def emit_isascii(target: str, args: list[str]) -> str abs;
    def emit_isdigit(target: str, args: list[str]) -> str abs;
    def emit_islower(target: str, args: list[str]) -> str abs;
    def emit_isspace(target: str, args: list[str]) -> str abs;
    def emit_istitle(target: str, args: list[str]) -> str abs;
    def emit_isupper(target: str, args: list[str]) -> str abs;
    # Alignment
    def emit_center(target: str, args: list[str]) -> str abs;
    def emit_ljust(target: str, args: list[str]) -> str abs;
    def emit_rjust(target: str, args: list[str]) -> str abs;
    def emit_zfill(target: str, args: list[str]) -> str abs;
    def emit_expandtabs(target: str, args: list[str]) -> str abs;
    # Translation
    def emit_translate(target: str, args: list[str]) -> str abs;
    def emit_maketrans(args: list[str]) -> str abs;
}

# =============================================================================
#  Collection Types
# =============================================================================
class ListEmitter {
    def emit_append(target: str, args: list[str]) -> str abs;
    def emit_extend(target: str, args: list[str]) -> str abs;
    def emit_insert(target: str, args: list[str]) -> str abs;
    def emit_remove(target: str, args: list[str]) -> str abs;
    def emit_pop(target: str, args: list[str]) -> str abs;
    def emit_clear(target: str, args: list[str]) -> str abs;
    def emit_index(target: str, args: list[str]) -> str abs;
    def emit_count(target: str, args: list[str]) -> str abs;
    def emit_sort(target: str, args: list[str]) -> str abs;
    def emit_reverse(target: str, args: list[str]) -> str abs;
    def emit_copy(target: str, args: list[str]) -> str abs;
}

class DictEmitter {
    def emit_get(target: str, args: list[str]) -> str abs;
    def emit_keys(target: str, args: list[str]) -> str abs;
    def emit_values(target: str, args: list[str]) -> str abs;
    def emit_items(target: str, args: list[str]) -> str abs;
    def emit_pop(target: str, args: list[str]) -> str abs;
    def emit_popitem(target: str, args: list[str]) -> str abs;
    def emit_setdefault(target: str, args: list[str]) -> str abs;
    def emit_update(target: str, args: list[str]) -> str abs;
    def emit_clear(target: str, args: list[str]) -> str abs;
    def emit_copy(target: str, args: list[str]) -> str abs;
    def emit_fromkeys(args: list[str]) -> str abs;
}

class SetEmitter {
    # Mutation
    def emit_add(target: str, args: list[str]) -> str abs;
    def emit_remove(target: str, args: list[str]) -> str abs;
    def emit_discard(target: str, args: list[str]) -> str abs;
    def emit_pop(target: str, args: list[str]) -> str abs;
    def emit_clear(target: str, args: list[str]) -> str abs;
    # Set algebra (return new set)
    def emit_union(target: str, args: list[str]) -> str abs;
    def emit_intersection(target: str, args: list[str]) -> str abs;
    def emit_difference(target: str, args: list[str]) -> str abs;
    def emit_symmetric_difference(target: str, args: list[str]) -> str abs;
    # In-place set algebra
    def emit_update(target: str, args: list[str]) -> str abs;
    def emit_intersection_update(target: str, args: list[str]) -> str abs;
    def emit_difference_update(target: str, args: list[str]) -> str abs;
    def emit_symmetric_difference_update(target: str, args: list[str]) -> str abs;
    # Tests
    def emit_issubset(target: str, args: list[str]) -> str abs;
    def emit_issuperset(target: str, args: list[str]) -> str abs;
    def emit_isdisjoint(target: str, args: list[str]) -> str abs;
    def emit_copy(target: str, args: list[str]) -> str abs;
}

class FrozensetEmitter {
    def emit_union(target: str, args: list[str]) -> str abs;
    def emit_intersection(target: str, args: list[str]) -> str abs;
    def emit_difference(target: str, args: list[str]) -> str abs;
    def emit_symmetric_difference(target: str, args: list[str]) -> str abs;
    def emit_issubset(target: str, args: list[str]) -> str abs;
    def emit_issuperset(target: str, args: list[str]) -> str abs;
    def emit_isdisjoint(target: str, args: list[str]) -> str abs;
    def emit_copy(target: str, args: list[str]) -> str abs;
}

class TupleEmitter {
    def emit_count(target: str, args: list[str]) -> str abs;
    def emit_index(target: str, args: list[str]) -> str abs;
}

class RangeEmitter {
    def emit_count(target: str, args: list[str]) -> str abs;
    def emit_index(target: str, args: list[str]) -> str abs;
}

# =============================================================================
#  Builtin Functions
# =============================================================================
class BuiltinEmitter {
    def emit_print(args: list[str]) -> str abs;
    def emit_input(args: list[str]) -> str abs;
    def emit_len(args: list[str]) -> str abs;
    def emit_abs(args: list[str]) -> str abs;
    def emit_round(args: list[str]) -> str abs;
    def emit_min(args: list[str]) -> str abs;
    def emit_max(args: list[str]) -> str abs;
    def emit_sum(args: list[str]) -> str abs;
    def emit_sorted(args: list[str]) -> str abs;
    def emit_reversed(args: list[str]) -> str abs;
    def emit_enumerate(args: list[str]) -> str abs;
    def emit_zip(args: list[str]) -> str abs;
    def emit_map(args: list[str]) -> str abs;
    def emit_filter(args: list[str]) -> str abs;
    def emit_any(args: list[str]) -> str abs;
    def emit_all(args: list[str]) -> str abs;
    def emit_isinstance(args: list[str]) -> str abs;
    def emit_issubclass(args: list[str]) -> str abs;
    def emit_type(args: list[str]) -> str abs;
    def emit_id(args: list[str]) -> str abs;
    def emit_hash(args: list[str]) -> str abs;
    def emit_repr(args: list[str]) -> str abs;
    def emit_chr(args: list[str]) -> str abs;
    def emit_ord(args: list[str]) -> str abs;
    def emit_hex(args: list[str]) -> str abs;
    def emit_oct(args: list[str]) -> str abs;
    def emit_bin(args: list[str]) -> str abs;
    def emit_pow(args: list[str]) -> str abs;
    def emit_divmod(args: list[str]) -> str abs;
    def emit_iter(args: list[str]) -> str abs;
    def emit_next(args: list[str]) -> str abs;
    def emit_callable(args: list[str]) -> str abs;
    def emit_getattr(args: list[str]) -> str abs;
    def emit_setattr(args: list[str]) -> str abs;
    def emit_hasattr(args: list[str]) -> str abs;
    def emit_delattr(args: list[str]) -> str abs;
    def emit_vars(args: list[str]) -> str abs;
    def emit_dir(args: list[str]) -> str abs;
    def emit_open(args: list[str]) -> str abs;
    def emit_format(args: list[str]) -> str abs;
    def emit_ascii(args: list[str]) -> str abs;
    # Type conversion builtins
    def emit_str(args: list[str]) -> str abs;
    def emit_int(args: list[str]) -> str abs;
    def emit_float(args: list[str]) -> str abs;
    def emit_bool(args: list[str]) -> str abs;
    def emit_list(args: list[str]) -> str abs;
    def emit_dict(args: list[str]) -> str abs;
    def emit_set(args: list[str]) -> str abs;
    def emit_tuple(args: list[str]) -> str abs;
    def emit_frozenset(args: list[str]) -> str abs;
    def emit_bytes(args: list[str]) -> str abs;
    def emit_complex(args: list[str]) -> str abs;
}
