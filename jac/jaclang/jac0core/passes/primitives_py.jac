"""Python backend primitive emitter implementations.

Pass-through implementations — Python method names and semantics match
the Jac primitive spec directly, so most methods simply forward the call.
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

# --- Helpers -----------------------------------------------------------------
def _mcall(target: str, method: str, args: list[str]) -> str {
    """Emit target.method(arg1, arg2, ...).""";
    if len(args) > 0 {
        return target + "." + method + "(" + ", ".join(args) + ")";
    }
    return target + "." + method + "()";
}

def _scall(cls: str, method: str, args: list[str]) -> str {
    """Emit ClassName.method(arg1, arg2, ...) for static/class methods.""";
    if len(args) > 0 {
        return cls + "." + method + "(" + ", ".join(args) + ")";
    }
    return cls + "." + method + "()";
}

def _fcall(name: str, args: list[str]) -> str {
    """Emit name(arg1, arg2, ...) for builtin functions.""";
    if len(args) > 0 {
        return name + "(" + ", ".join(args) + ")";
    }
    return name + "()";
}

# =============================================================================
#  Numeric Types
# =============================================================================
class PyIntEmitter(IntEmitter) {
    static def emit_bit_length(target: str, args: list[str]) -> str;
    static def emit_bit_count(target: str, args: list[str]) -> str;
    static def emit_to_bytes(target: str, args: list[str]) -> str;
    static def emit_as_integer_ratio(target: str, args: list[str]) -> str;
    static def emit_conjugate(target: str, args: list[str]) -> str;
    static def emit_from_bytes(args: list[str]) -> str;
}

class PyFloatEmitter(FloatEmitter) {
    static def emit_is_integer(target: str, args: list[str]) -> str;
    static def emit_as_integer_ratio(target: str, args: list[str]) -> str;
    static def emit_conjugate(target: str, args: list[str]) -> str;
    static def emit_hex(target: str, args: list[str]) -> str;
    static def emit_fromhex(args: list[str]) -> str;
}

class PyComplexEmitter(ComplexEmitter) {
    static def emit_conjugate(target: str, args: list[str]) -> str;
}

# =============================================================================
#  String Types
# =============================================================================
class PyStrEmitter(StrEmitter) {
    # Case conversion
    static def emit_capitalize(target: str, args: list[str]) -> str;
    static def emit_casefold(target: str, args: list[str]) -> str;
    static def emit_lower(target: str, args: list[str]) -> str;
    static def emit_upper(target: str, args: list[str]) -> str;
    static def emit_title(target: str, args: list[str]) -> str;
    static def emit_swapcase(target: str, args: list[str]) -> str;
    # Search
    static def emit_count(target: str, args: list[str]) -> str;
    static def emit_find(target: str, args: list[str]) -> str;
    static def emit_rfind(target: str, args: list[str]) -> str;
    static def emit_index(target: str, args: list[str]) -> str;
    static def emit_rindex(target: str, args: list[str]) -> str;
    static def emit_startswith(target: str, args: list[str]) -> str;
    static def emit_endswith(target: str, args: list[str]) -> str;
    # Modification
    static def emit_replace(target: str, args: list[str]) -> str;
    static def emit_strip(target: str, args: list[str]) -> str;
    static def emit_lstrip(target: str, args: list[str]) -> str;
    static def emit_rstrip(target: str, args: list[str]) -> str;
    static def emit_removeprefix(target: str, args: list[str]) -> str;
    static def emit_removesuffix(target: str, args: list[str]) -> str;
    # Split and join
    static def emit_split(target: str, args: list[str]) -> str;
    static def emit_rsplit(target: str, args: list[str]) -> str;
    static def emit_splitlines(target: str, args: list[str]) -> str;
    static def emit_join(target: str, args: list[str]) -> str;
    static def emit_partition(target: str, args: list[str]) -> str;
    static def emit_rpartition(target: str, args: list[str]) -> str;
    # Formatting and alignment
    static def emit_format(target: str, args: list[str]) -> str;
    static def emit_format_map(target: str, args: list[str]) -> str;
    static def emit_center(target: str, args: list[str]) -> str;
    static def emit_ljust(target: str, args: list[str]) -> str;
    static def emit_rjust(target: str, args: list[str]) -> str;
    static def emit_zfill(target: str, args: list[str]) -> str;
    static def emit_expandtabs(target: str, args: list[str]) -> str;
    # Character tests
    static def emit_isalnum(target: str, args: list[str]) -> str;
    static def emit_isalpha(target: str, args: list[str]) -> str;
    static def emit_isascii(target: str, args: list[str]) -> str;
    static def emit_isdecimal(target: str, args: list[str]) -> str;
    static def emit_isdigit(target: str, args: list[str]) -> str;
    static def emit_isidentifier(target: str, args: list[str]) -> str;
    static def emit_islower(target: str, args: list[str]) -> str;
    static def emit_isnumeric(target: str, args: list[str]) -> str;
    static def emit_isprintable(target: str, args: list[str]) -> str;
    static def emit_isspace(target: str, args: list[str]) -> str;
    static def emit_istitle(target: str, args: list[str]) -> str;
    static def emit_isupper(target: str, args: list[str]) -> str;
    # Encoding
    static def emit_encode(target: str, args: list[str]) -> str;
    # Translation
    static def emit_translate(target: str, args: list[str]) -> str;
    static def emit_maketrans(args: list[str]) -> str;
}

class PyBytesEmitter(BytesEmitter) {
    # Decoding
    static def emit_decode(target: str, args: list[str]) -> str;
    static def emit_hex(target: str, args: list[str]) -> str;
    static def emit_fromhex(args: list[str]) -> str;
    # Search
    static def emit_count(target: str, args: list[str]) -> str;
    static def emit_find(target: str, args: list[str]) -> str;
    static def emit_rfind(target: str, args: list[str]) -> str;
    static def emit_index(target: str, args: list[str]) -> str;
    static def emit_rindex(target: str, args: list[str]) -> str;
    static def emit_startswith(target: str, args: list[str]) -> str;
    static def emit_endswith(target: str, args: list[str]) -> str;
    # Modification
    static def emit_replace(target: str, args: list[str]) -> str;
    static def emit_strip(target: str, args: list[str]) -> str;
    static def emit_lstrip(target: str, args: list[str]) -> str;
    static def emit_rstrip(target: str, args: list[str]) -> str;
    static def emit_removeprefix(target: str, args: list[str]) -> str;
    static def emit_removesuffix(target: str, args: list[str]) -> str;
    # Split and join
    static def emit_split(target: str, args: list[str]) -> str;
    static def emit_rsplit(target: str, args: list[str]) -> str;
    static def emit_splitlines(target: str, args: list[str]) -> str;
    static def emit_join(target: str, args: list[str]) -> str;
    static def emit_partition(target: str, args: list[str]) -> str;
    static def emit_rpartition(target: str, args: list[str]) -> str;
    # Case (ASCII only)
    static def emit_capitalize(target: str, args: list[str]) -> str;
    static def emit_lower(target: str, args: list[str]) -> str;
    static def emit_upper(target: str, args: list[str]) -> str;
    static def emit_title(target: str, args: list[str]) -> str;
    static def emit_swapcase(target: str, args: list[str]) -> str;
    # Character tests (ASCII only)
    static def emit_isalnum(target: str, args: list[str]) -> str;
    static def emit_isalpha(target: str, args: list[str]) -> str;
    static def emit_isascii(target: str, args: list[str]) -> str;
    static def emit_isdigit(target: str, args: list[str]) -> str;
    static def emit_islower(target: str, args: list[str]) -> str;
    static def emit_isspace(target: str, args: list[str]) -> str;
    static def emit_istitle(target: str, args: list[str]) -> str;
    static def emit_isupper(target: str, args: list[str]) -> str;
    # Alignment
    static def emit_center(target: str, args: list[str]) -> str;
    static def emit_ljust(target: str, args: list[str]) -> str;
    static def emit_rjust(target: str, args: list[str]) -> str;
    static def emit_zfill(target: str, args: list[str]) -> str;
    static def emit_expandtabs(target: str, args: list[str]) -> str;
    # Translation
    static def emit_translate(target: str, args: list[str]) -> str;
    static def emit_maketrans(args: list[str]) -> str;
}

# =============================================================================
#  Collection Types
# =============================================================================
class PyListEmitter(ListEmitter) {
    static def emit_append(target: str, args: list[str]) -> str;
    static def emit_extend(target: str, args: list[str]) -> str;
    static def emit_insert(target: str, args: list[str]) -> str;
    static def emit_remove(target: str, args: list[str]) -> str;
    static def emit_pop(target: str, args: list[str]) -> str;
    static def emit_clear(target: str, args: list[str]) -> str;
    static def emit_index(target: str, args: list[str]) -> str;
    static def emit_count(target: str, args: list[str]) -> str;
    static def emit_sort(target: str, args: list[str]) -> str;
    static def emit_reverse(target: str, args: list[str]) -> str;
    static def emit_copy(target: str, args: list[str]) -> str;
}

class PyDictEmitter(DictEmitter) {
    static def emit_get(target: str, args: list[str]) -> str;
    static def emit_keys(target: str, args: list[str]) -> str;
    static def emit_values(target: str, args: list[str]) -> str;
    static def emit_items(target: str, args: list[str]) -> str;
    static def emit_pop(target: str, args: list[str]) -> str;
    static def emit_popitem(target: str, args: list[str]) -> str;
    static def emit_setdefault(target: str, args: list[str]) -> str;
    static def emit_update(target: str, args: list[str]) -> str;
    static def emit_clear(target: str, args: list[str]) -> str;
    static def emit_copy(target: str, args: list[str]) -> str;
    static def emit_fromkeys(args: list[str]) -> str;
}

class PySetEmitter(SetEmitter) {
    # Mutation
    static def emit_add(target: str, args: list[str]) -> str;
    static def emit_remove(target: str, args: list[str]) -> str;
    static def emit_discard(target: str, args: list[str]) -> str;
    static def emit_pop(target: str, args: list[str]) -> str;
    static def emit_clear(target: str, args: list[str]) -> str;
    # Set algebra
    static def emit_union(target: str, args: list[str]) -> str;
    static def emit_intersection(target: str, args: list[str]) -> str;
    static def emit_difference(target: str, args: list[str]) -> str;
    static def emit_symmetric_difference(target: str, args: list[str]) -> str;
    # In-place set algebra
    static def emit_update(target: str, args: list[str]) -> str;
    static def emit_intersection_update(target: str, args: list[str]) -> str;
    static def emit_difference_update(target: str, args: list[str]) -> str;
    static def emit_symmetric_difference_update(target: str, args: list[str]) -> str;
    # Tests
    static def emit_issubset(target: str, args: list[str]) -> str;
    static def emit_issuperset(target: str, args: list[str]) -> str;
    static def emit_isdisjoint(target: str, args: list[str]) -> str;
    static def emit_copy(target: str, args: list[str]) -> str;
}

class PyFrozensetEmitter(FrozensetEmitter) {
    static def emit_union(target: str, args: list[str]) -> str;
    static def emit_intersection(target: str, args: list[str]) -> str;
    static def emit_difference(target: str, args: list[str]) -> str;
    static def emit_symmetric_difference(target: str, args: list[str]) -> str;
    static def emit_issubset(target: str, args: list[str]) -> str;
    static def emit_issuperset(target: str, args: list[str]) -> str;
    static def emit_isdisjoint(target: str, args: list[str]) -> str;
    static def emit_copy(target: str, args: list[str]) -> str;
}

class PyTupleEmitter(TupleEmitter) {
    static def emit_count(target: str, args: list[str]) -> str;
    static def emit_index(target: str, args: list[str]) -> str;
}

class PyRangeEmitter(RangeEmitter) {
    static def emit_count(target: str, args: list[str]) -> str;
    static def emit_index(target: str, args: list[str]) -> str;
}

# =============================================================================
#  Builtin Functions
# =============================================================================
class PyBuiltinEmitter(BuiltinEmitter) {
    static def emit_print(args: list[str]) -> str;
    static def emit_input(args: list[str]) -> str;
    static def emit_len(args: list[str]) -> str;
    static def emit_abs(args: list[str]) -> str;
    static def emit_round(args: list[str]) -> str;
    static def emit_min(args: list[str]) -> str;
    static def emit_max(args: list[str]) -> str;
    static def emit_sum(args: list[str]) -> str;
    static def emit_sorted(args: list[str]) -> str;
    static def emit_reversed(args: list[str]) -> str;
    static def emit_enumerate(args: list[str]) -> str;
    static def emit_zip(args: list[str]) -> str;
    static def emit_map(args: list[str]) -> str;
    static def emit_filter(args: list[str]) -> str;
    static def emit_any(args: list[str]) -> str;
    static def emit_all(args: list[str]) -> str;
    static def emit_isinstance(args: list[str]) -> str;
    static def emit_issubclass(args: list[str]) -> str;
    static def emit_type(args: list[str]) -> str;
    static def emit_id(args: list[str]) -> str;
    static def emit_hash(args: list[str]) -> str;
    static def emit_repr(args: list[str]) -> str;
    static def emit_chr(args: list[str]) -> str;
    static def emit_ord(args: list[str]) -> str;
    static def emit_hex(args: list[str]) -> str;
    static def emit_oct(args: list[str]) -> str;
    static def emit_bin(args: list[str]) -> str;
    static def emit_pow(args: list[str]) -> str;
    static def emit_divmod(args: list[str]) -> str;
    static def emit_iter(args: list[str]) -> str;
    static def emit_next(args: list[str]) -> str;
    static def emit_callable(args: list[str]) -> str;
    static def emit_getattr(args: list[str]) -> str;
    static def emit_setattr(args: list[str]) -> str;
    static def emit_hasattr(args: list[str]) -> str;
    static def emit_delattr(args: list[str]) -> str;
    static def emit_vars(args: list[str]) -> str;
    static def emit_dir(args: list[str]) -> str;
    static def emit_open(args: list[str]) -> str;
    static def emit_format(args: list[str]) -> str;
    static def emit_ascii(args: list[str]) -> str;
    # Type conversion builtins
    static def emit_str(args: list[str]) -> str;
    static def emit_int(args: list[str]) -> str;
    static def emit_float(args: list[str]) -> str;
    static def emit_bool(args: list[str]) -> str;
    static def emit_list(args: list[str]) -> str;
    static def emit_dict(args: list[str]) -> str;
    static def emit_set(args: list[str]) -> str;
    static def emit_tuple(args: list[str]) -> str;
    static def emit_frozenset(args: list[str]) -> str;
    static def emit_bytes(args: list[str]) -> str;
    static def emit_complex(args: list[str]) -> str;
}
