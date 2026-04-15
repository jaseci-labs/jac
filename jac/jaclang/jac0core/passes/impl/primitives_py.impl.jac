"""Implementation for Python backend primitive emitters."""

# =============================================================================
#  Numeric Types
# =============================================================================
impl PyIntEmitter.emit_bit_length(target: str, args: list[str]) -> str {
    return _mcall(target, "bit_length", args);
}

impl PyIntEmitter.emit_bit_count(target: str, args: list[str]) -> str {
    return _mcall(target, "bit_count", args);
}

impl PyIntEmitter.emit_to_bytes(target: str, args: list[str]) -> str {
    return _mcall(target, "to_bytes", args);
}

impl PyIntEmitter.emit_as_integer_ratio(target: str, args: list[str]) -> str {
    return _mcall(target, "as_integer_ratio", args);
}

impl PyIntEmitter.emit_conjugate(target: str, args: list[str]) -> str {
    return _mcall(target, "conjugate", args);
}

impl PyIntEmitter.emit_from_bytes(args: list[str]) -> str {
    return _scall("int", "from_bytes", args);
}

impl PyFloatEmitter.emit_is_integer(target: str, args: list[str]) -> str {
    return _mcall(target, "is_integer", args);
}

impl PyFloatEmitter.emit_as_integer_ratio(target: str, args: list[str]) -> str {
    return _mcall(target, "as_integer_ratio", args);
}

impl PyFloatEmitter.emit_conjugate(target: str, args: list[str]) -> str {
    return _mcall(target, "conjugate", args);
}

impl PyFloatEmitter.emit_hex(target: str, args: list[str]) -> str {
    return _mcall(target, "hex", args);
}

impl PyFloatEmitter.emit_fromhex(args: list[str]) -> str {
    return _scall("float", "fromhex", args);
}

impl PyComplexEmitter.emit_conjugate(target: str, args: list[str]) -> str {
    return _mcall(target, "conjugate", args);
}

# =============================================================================
#  String Types
# =============================================================================

# Case conversion
impl PyStrEmitter.emit_capitalize(target: str, args: list[str]) -> str {
    return _mcall(target, "capitalize", args);
}

impl PyStrEmitter.emit_casefold(target: str, args: list[str]) -> str {
    return _mcall(target, "casefold", args);
}

impl PyStrEmitter.emit_lower(target: str, args: list[str]) -> str {
    return _mcall(target, "lower", args);
}

impl PyStrEmitter.emit_upper(target: str, args: list[str]) -> str {
    return _mcall(target, "upper", args);
}

impl PyStrEmitter.emit_title(target: str, args: list[str]) -> str {
    return _mcall(target, "title", args);
}

impl PyStrEmitter.emit_swapcase(target: str, args: list[str]) -> str {
    return _mcall(target, "swapcase", args);
}

# Search
impl PyStrEmitter.emit_count(target: str, args: list[str]) -> str {
    return _mcall(target, "count", args);
}

impl PyStrEmitter.emit_find(target: str, args: list[str]) -> str {
    return _mcall(target, "find", args);
}

impl PyStrEmitter.emit_rfind(target: str, args: list[str]) -> str {
    return _mcall(target, "rfind", args);
}

impl PyStrEmitter.emit_index(target: str, args: list[str]) -> str {
    return _mcall(target, "index", args);
}

impl PyStrEmitter.emit_rindex(target: str, args: list[str]) -> str {
    return _mcall(target, "rindex", args);
}

impl PyStrEmitter.emit_startswith(target: str, args: list[str]) -> str {
    return _mcall(target, "startswith", args);
}

impl PyStrEmitter.emit_endswith(target: str, args: list[str]) -> str {
    return _mcall(target, "endswith", args);
}

# Modification
impl PyStrEmitter.emit_replace(target: str, args: list[str]) -> str {
    return _mcall(target, "replace", args);
}

impl PyStrEmitter.emit_strip(target: str, args: list[str]) -> str {
    return _mcall(target, "strip", args);
}

impl PyStrEmitter.emit_lstrip(target: str, args: list[str]) -> str {
    return _mcall(target, "lstrip", args);
}

impl PyStrEmitter.emit_rstrip(target: str, args: list[str]) -> str {
    return _mcall(target, "rstrip", args);
}

impl PyStrEmitter.emit_removeprefix(target: str, args: list[str]) -> str {
    return _mcall(target, "removeprefix", args);
}

impl PyStrEmitter.emit_removesuffix(target: str, args: list[str]) -> str {
    return _mcall(target, "removesuffix", args);
}

# Split and join
impl PyStrEmitter.emit_split(target: str, args: list[str]) -> str {
    return _mcall(target, "split", args);
}

impl PyStrEmitter.emit_rsplit(target: str, args: list[str]) -> str {
    return _mcall(target, "rsplit", args);
}

impl PyStrEmitter.emit_splitlines(target: str, args: list[str]) -> str {
    return _mcall(target, "splitlines", args);
}

impl PyStrEmitter.emit_join(target: str, args: list[str]) -> str {
    return _mcall(target, "join", args);
}

impl PyStrEmitter.emit_partition(target: str, args: list[str]) -> str {
    return _mcall(target, "partition", args);
}

impl PyStrEmitter.emit_rpartition(target: str, args: list[str]) -> str {
    return _mcall(target, "rpartition", args);
}

# Formatting and alignment
impl PyStrEmitter.emit_format(target: str, args: list[str]) -> str {
    return _mcall(target, "format", args);
}

impl PyStrEmitter.emit_format_map(target: str, args: list[str]) -> str {
    return _mcall(target, "format_map", args);
}

impl PyStrEmitter.emit_center(target: str, args: list[str]) -> str {
    return _mcall(target, "center", args);
}

impl PyStrEmitter.emit_ljust(target: str, args: list[str]) -> str {
    return _mcall(target, "ljust", args);
}

impl PyStrEmitter.emit_rjust(target: str, args: list[str]) -> str {
    return _mcall(target, "rjust", args);
}

impl PyStrEmitter.emit_zfill(target: str, args: list[str]) -> str {
    return _mcall(target, "zfill", args);
}

impl PyStrEmitter.emit_expandtabs(target: str, args: list[str]) -> str {
    return _mcall(target, "expandtabs", args);
}

# Character tests
impl PyStrEmitter.emit_isalnum(target: str, args: list[str]) -> str {
    return _mcall(target, "isalnum", args);
}

impl PyStrEmitter.emit_isalpha(target: str, args: list[str]) -> str {
    return _mcall(target, "isalpha", args);
}

impl PyStrEmitter.emit_isascii(target: str, args: list[str]) -> str {
    return _mcall(target, "isascii", args);
}

impl PyStrEmitter.emit_isdecimal(target: str, args: list[str]) -> str {
    return _mcall(target, "isdecimal", args);
}

impl PyStrEmitter.emit_isdigit(target: str, args: list[str]) -> str {
    return _mcall(target, "isdigit", args);
}

impl PyStrEmitter.emit_isidentifier(target: str, args: list[str]) -> str {
    return _mcall(target, "isidentifier", args);
}

impl PyStrEmitter.emit_islower(target: str, args: list[str]) -> str {
    return _mcall(target, "islower", args);
}

impl PyStrEmitter.emit_isnumeric(target: str, args: list[str]) -> str {
    return _mcall(target, "isnumeric", args);
}

impl PyStrEmitter.emit_isprintable(target: str, args: list[str]) -> str {
    return _mcall(target, "isprintable", args);
}

impl PyStrEmitter.emit_isspace(target: str, args: list[str]) -> str {
    return _mcall(target, "isspace", args);
}

impl PyStrEmitter.emit_istitle(target: str, args: list[str]) -> str {
    return _mcall(target, "istitle", args);
}

impl PyStrEmitter.emit_isupper(target: str, args: list[str]) -> str {
    return _mcall(target, "isupper", args);
}

# Encoding
impl PyStrEmitter.emit_encode(target: str, args: list[str]) -> str {
    return _mcall(target, "encode", args);
}

# Translation
impl PyStrEmitter.emit_translate(target: str, args: list[str]) -> str {
    return _mcall(target, "translate", args);
}

impl PyStrEmitter.emit_maketrans(args: list[str]) -> str {
    return _scall("str", "maketrans", args);
}

# --- PyBytesEmitter ---

# Decoding
impl PyBytesEmitter.emit_decode(target: str, args: list[str]) -> str {
    return _mcall(target, "decode", args);
}

impl PyBytesEmitter.emit_hex(target: str, args: list[str]) -> str {
    return _mcall(target, "hex", args);
}

impl PyBytesEmitter.emit_fromhex(args: list[str]) -> str {
    return _scall("bytes", "fromhex", args);
}

# Search
impl PyBytesEmitter.emit_count(target: str, args: list[str]) -> str {
    return _mcall(target, "count", args);
}

impl PyBytesEmitter.emit_find(target: str, args: list[str]) -> str {
    return _mcall(target, "find", args);
}

impl PyBytesEmitter.emit_rfind(target: str, args: list[str]) -> str {
    return _mcall(target, "rfind", args);
}

impl PyBytesEmitter.emit_index(target: str, args: list[str]) -> str {
    return _mcall(target, "index", args);
}

impl PyBytesEmitter.emit_rindex(target: str, args: list[str]) -> str {
    return _mcall(target, "rindex", args);
}

impl PyBytesEmitter.emit_startswith(target: str, args: list[str]) -> str {
    return _mcall(target, "startswith", args);
}

impl PyBytesEmitter.emit_endswith(target: str, args: list[str]) -> str {
    return _mcall(target, "endswith", args);
}

# Modification
impl PyBytesEmitter.emit_replace(target: str, args: list[str]) -> str {
    return _mcall(target, "replace", args);
}

impl PyBytesEmitter.emit_strip(target: str, args: list[str]) -> str {
    return _mcall(target, "strip", args);
}

impl PyBytesEmitter.emit_lstrip(target: str, args: list[str]) -> str {
    return _mcall(target, "lstrip", args);
}

impl PyBytesEmitter.emit_rstrip(target: str, args: list[str]) -> str {
    return _mcall(target, "rstrip", args);
}

impl PyBytesEmitter.emit_removeprefix(target: str, args: list[str]) -> str {
    return _mcall(target, "removeprefix", args);
}

impl PyBytesEmitter.emit_removesuffix(target: str, args: list[str]) -> str {
    return _mcall(target, "removesuffix", args);
}

# Split and join
impl PyBytesEmitter.emit_split(target: str, args: list[str]) -> str {
    return _mcall(target, "split", args);
}

impl PyBytesEmitter.emit_rsplit(target: str, args: list[str]) -> str {
    return _mcall(target, "rsplit", args);
}

impl PyBytesEmitter.emit_splitlines(target: str, args: list[str]) -> str {
    return _mcall(target, "splitlines", args);
}

impl PyBytesEmitter.emit_join(target: str, args: list[str]) -> str {
    return _mcall(target, "join", args);
}

impl PyBytesEmitter.emit_partition(target: str, args: list[str]) -> str {
    return _mcall(target, "partition", args);
}

impl PyBytesEmitter.emit_rpartition(target: str, args: list[str]) -> str {
    return _mcall(target, "rpartition", args);
}

# Case (ASCII only)
impl PyBytesEmitter.emit_capitalize(target: str, args: list[str]) -> str {
    return _mcall(target, "capitalize", args);
}

impl PyBytesEmitter.emit_lower(target: str, args: list[str]) -> str {
    return _mcall(target, "lower", args);
}

impl PyBytesEmitter.emit_upper(target: str, args: list[str]) -> str {
    return _mcall(target, "upper", args);
}

impl PyBytesEmitter.emit_title(target: str, args: list[str]) -> str {
    return _mcall(target, "title", args);
}

impl PyBytesEmitter.emit_swapcase(target: str, args: list[str]) -> str {
    return _mcall(target, "swapcase", args);
}

# Character tests (ASCII only)
impl PyBytesEmitter.emit_isalnum(target: str, args: list[str]) -> str {
    return _mcall(target, "isalnum", args);
}

impl PyBytesEmitter.emit_isalpha(target: str, args: list[str]) -> str {
    return _mcall(target, "isalpha", args);
}

impl PyBytesEmitter.emit_isascii(target: str, args: list[str]) -> str {
    return _mcall(target, "isascii", args);
}

impl PyBytesEmitter.emit_isdigit(target: str, args: list[str]) -> str {
    return _mcall(target, "isdigit", args);
}

impl PyBytesEmitter.emit_islower(target: str, args: list[str]) -> str {
    return _mcall(target, "islower", args);
}

impl PyBytesEmitter.emit_isspace(target: str, args: list[str]) -> str {
    return _mcall(target, "isspace", args);
}

impl PyBytesEmitter.emit_istitle(target: str, args: list[str]) -> str {
    return _mcall(target, "istitle", args);
}

impl PyBytesEmitter.emit_isupper(target: str, args: list[str]) -> str {
    return _mcall(target, "isupper", args);
}

# Alignment
impl PyBytesEmitter.emit_center(target: str, args: list[str]) -> str {
    return _mcall(target, "center", args);
}

impl PyBytesEmitter.emit_ljust(target: str, args: list[str]) -> str {
    return _mcall(target, "ljust", args);
}

impl PyBytesEmitter.emit_rjust(target: str, args: list[str]) -> str {
    return _mcall(target, "rjust", args);
}

impl PyBytesEmitter.emit_zfill(target: str, args: list[str]) -> str {
    return _mcall(target, "zfill", args);
}

impl PyBytesEmitter.emit_expandtabs(target: str, args: list[str]) -> str {
    return _mcall(target, "expandtabs", args);
}

# Translation
impl PyBytesEmitter.emit_translate(target: str, args: list[str]) -> str {
    return _mcall(target, "translate", args);
}

impl PyBytesEmitter.emit_maketrans(args: list[str]) -> str {
    return _scall("bytes", "maketrans", args);
}

# =============================================================================
#  Collection Types
# =============================================================================
impl PyListEmitter.emit_append(target: str, args: list[str]) -> str {
    return _mcall(target, "append", args);
}

impl PyListEmitter.emit_extend(target: str, args: list[str]) -> str {
    return _mcall(target, "extend", args);
}

impl PyListEmitter.emit_insert(target: str, args: list[str]) -> str {
    return _mcall(target, "insert", args);
}

impl PyListEmitter.emit_remove(target: str, args: list[str]) -> str {
    return _mcall(target, "remove", args);
}

impl PyListEmitter.emit_pop(target: str, args: list[str]) -> str {
    return _mcall(target, "pop", args);
}

impl PyListEmitter.emit_clear(target: str, args: list[str]) -> str {
    return _mcall(target, "clear", args);
}

impl PyListEmitter.emit_index(target: str, args: list[str]) -> str {
    return _mcall(target, "index", args);
}

impl PyListEmitter.emit_count(target: str, args: list[str]) -> str {
    return _mcall(target, "count", args);
}

impl PyListEmitter.emit_sort(target: str, args: list[str]) -> str {
    return _mcall(target, "sort", args);
}

impl PyListEmitter.emit_reverse(target: str, args: list[str]) -> str {
    return _mcall(target, "reverse", args);
}

impl PyListEmitter.emit_copy(target: str, args: list[str]) -> str {
    return _mcall(target, "copy", args);
}

impl PyDictEmitter.emit_get(target: str, args: list[str]) -> str {
    return _mcall(target, "get", args);
}

impl PyDictEmitter.emit_keys(target: str, args: list[str]) -> str {
    return _mcall(target, "keys", args);
}

impl PyDictEmitter.emit_values(target: str, args: list[str]) -> str {
    return _mcall(target, "values", args);
}

impl PyDictEmitter.emit_items(target: str, args: list[str]) -> str {
    return _mcall(target, "items", args);
}

impl PyDictEmitter.emit_pop(target: str, args: list[str]) -> str {
    return _mcall(target, "pop", args);
}

impl PyDictEmitter.emit_popitem(target: str, args: list[str]) -> str {
    return _mcall(target, "popitem", args);
}

impl PyDictEmitter.emit_setdefault(target: str, args: list[str]) -> str {
    return _mcall(target, "setdefault", args);
}

impl PyDictEmitter.emit_update(target: str, args: list[str]) -> str {
    return _mcall(target, "update", args);
}

impl PyDictEmitter.emit_clear(target: str, args: list[str]) -> str {
    return _mcall(target, "clear", args);
}

impl PyDictEmitter.emit_copy(target: str, args: list[str]) -> str {
    return _mcall(target, "copy", args);
}

impl PyDictEmitter.emit_fromkeys(args: list[str]) -> str {
    return _scall("dict", "fromkeys", args);
}

# Mutation
impl PySetEmitter.emit_add(target: str, args: list[str]) -> str {
    return _mcall(target, "add", args);
}

impl PySetEmitter.emit_remove(target: str, args: list[str]) -> str {
    return _mcall(target, "remove", args);
}

impl PySetEmitter.emit_discard(target: str, args: list[str]) -> str {
    return _mcall(target, "discard", args);
}

impl PySetEmitter.emit_pop(target: str, args: list[str]) -> str {
    return _mcall(target, "pop", args);
}

impl PySetEmitter.emit_clear(target: str, args: list[str]) -> str {
    return _mcall(target, "clear", args);
}

# Set algebra
impl PySetEmitter.emit_union(target: str, args: list[str]) -> str {
    return _mcall(target, "union", args);
}

impl PySetEmitter.emit_intersection(target: str, args: list[str]) -> str {
    return _mcall(target, "intersection", args);
}

impl PySetEmitter.emit_difference(target: str, args: list[str]) -> str {
    return _mcall(target, "difference", args);
}

impl PySetEmitter.emit_symmetric_difference(target: str, args: list[str]) -> str {
    return _mcall(target, "symmetric_difference", args);
}

# In-place set algebra
impl PySetEmitter.emit_update(target: str, args: list[str]) -> str {
    return _mcall(target, "update", args);
}

impl PySetEmitter.emit_intersection_update(target: str, args: list[str]) -> str {
    return _mcall(target, "intersection_update", args);
}

impl PySetEmitter.emit_difference_update(target: str, args: list[str]) -> str {
    return _mcall(target, "difference_update", args);
}

impl PySetEmitter.emit_symmetric_difference_update(
    target: str, args: list[str]
) -> str {
    return _mcall(target, "symmetric_difference_update", args);
}

# Tests
impl PySetEmitter.emit_issubset(target: str, args: list[str]) -> str {
    return _mcall(target, "issubset", args);
}

impl PySetEmitter.emit_issuperset(target: str, args: list[str]) -> str {
    return _mcall(target, "issuperset", args);
}

impl PySetEmitter.emit_isdisjoint(target: str, args: list[str]) -> str {
    return _mcall(target, "isdisjoint", args);
}

impl PySetEmitter.emit_copy(target: str, args: list[str]) -> str {
    return _mcall(target, "copy", args);
}

impl PyFrozensetEmitter.emit_union(target: str, args: list[str]) -> str {
    return _mcall(target, "union", args);
}

impl PyFrozensetEmitter.emit_intersection(target: str, args: list[str]) -> str {
    return _mcall(target, "intersection", args);
}

impl PyFrozensetEmitter.emit_difference(target: str, args: list[str]) -> str {
    return _mcall(target, "difference", args);
}

impl PyFrozensetEmitter.emit_symmetric_difference(target: str, args: list[str]) -> str {
    return _mcall(target, "symmetric_difference", args);
}

impl PyFrozensetEmitter.emit_issubset(target: str, args: list[str]) -> str {
    return _mcall(target, "issubset", args);
}

impl PyFrozensetEmitter.emit_issuperset(target: str, args: list[str]) -> str {
    return _mcall(target, "issuperset", args);
}

impl PyFrozensetEmitter.emit_isdisjoint(target: str, args: list[str]) -> str {
    return _mcall(target, "isdisjoint", args);
}

impl PyFrozensetEmitter.emit_copy(target: str, args: list[str]) -> str {
    return _mcall(target, "copy", args);
}

impl PyTupleEmitter.emit_count(target: str, args: list[str]) -> str {
    return _mcall(target, "count", args);
}

impl PyTupleEmitter.emit_index(target: str, args: list[str]) -> str {
    return _mcall(target, "index", args);
}

impl PyRangeEmitter.emit_count(target: str, args: list[str]) -> str {
    return _mcall(target, "count", args);
}

impl PyRangeEmitter.emit_index(target: str, args: list[str]) -> str {
    return _mcall(target, "index", args);
}

# =============================================================================
#  Builtin Functions
# =============================================================================
impl PyBuiltinEmitter.emit_print(args: list[str]) -> str {
    return _fcall("print", args);
}

impl PyBuiltinEmitter.emit_input(args: list[str]) -> str {
    return _fcall("input", args);
}

impl PyBuiltinEmitter.emit_len(args: list[str]) -> str {
    return _fcall("len", args);
}

impl PyBuiltinEmitter.emit_abs(args: list[str]) -> str {
    return _fcall("abs", args);
}

impl PyBuiltinEmitter.emit_round(args: list[str]) -> str {
    return _fcall("round", args);
}

impl PyBuiltinEmitter.emit_min(args: list[str]) -> str {
    return _fcall("min", args);
}

impl PyBuiltinEmitter.emit_max(args: list[str]) -> str {
    return _fcall("max", args);
}

impl PyBuiltinEmitter.emit_sum(args: list[str]) -> str {
    return _fcall("sum", args);
}

impl PyBuiltinEmitter.emit_sorted(args: list[str]) -> str {
    return _fcall("sorted", args);
}

impl PyBuiltinEmitter.emit_reversed(args: list[str]) -> str {
    return _fcall("reversed", args);
}

impl PyBuiltinEmitter.emit_enumerate(args: list[str]) -> str {
    return _fcall("enumerate", args);
}

impl PyBuiltinEmitter.emit_zip(args: list[str]) -> str {
    return _fcall("zip", args);
}

impl PyBuiltinEmitter.emit_map(args: list[str]) -> str {
    return _fcall("map", args);
}

impl PyBuiltinEmitter.emit_filter(args: list[str]) -> str {
    return _fcall("filter", args);
}

impl PyBuiltinEmitter.emit_any(args: list[str]) -> str {
    return _fcall("any", args);
}

impl PyBuiltinEmitter.emit_all(args: list[str]) -> str {
    return _fcall("all", args);
}

impl PyBuiltinEmitter.emit_isinstance(args: list[str]) -> str {
    return _fcall("isinstance", args);
}

impl PyBuiltinEmitter.emit_issubclass(args: list[str]) -> str {
    return _fcall("issubclass", args);
}

impl PyBuiltinEmitter.emit_type(args: list[str]) -> str {
    return _fcall("type", args);
}

impl PyBuiltinEmitter.emit_id(args: list[str]) -> str {
    return _fcall("id", args);
}

impl PyBuiltinEmitter.emit_hash(args: list[str]) -> str {
    return _fcall("hash", args);
}

impl PyBuiltinEmitter.emit_repr(args: list[str]) -> str {
    return _fcall("repr", args);
}

impl PyBuiltinEmitter.emit_chr(args: list[str]) -> str {
    return _fcall("chr", args);
}

impl PyBuiltinEmitter.emit_ord(args: list[str]) -> str {
    return _fcall("ord", args);
}

impl PyBuiltinEmitter.emit_hex(args: list[str]) -> str {
    return _fcall("hex", args);
}

impl PyBuiltinEmitter.emit_oct(args: list[str]) -> str {
    return _fcall("oct", args);
}

impl PyBuiltinEmitter.emit_bin(args: list[str]) -> str {
    return _fcall("bin", args);
}

impl PyBuiltinEmitter.emit_pow(args: list[str]) -> str {
    return _fcall("pow", args);
}

impl PyBuiltinEmitter.emit_divmod(args: list[str]) -> str {
    return _fcall("divmod", args);
}

impl PyBuiltinEmitter.emit_iter(args: list[str]) -> str {
    return _fcall("iter", args);
}

impl PyBuiltinEmitter.emit_next(args: list[str]) -> str {
    return _fcall("next", args);
}

impl PyBuiltinEmitter.emit_callable(args: list[str]) -> str {
    return _fcall("callable", args);
}

impl PyBuiltinEmitter.emit_getattr(args: list[str]) -> str {
    return _fcall("getattr", args);
}

impl PyBuiltinEmitter.emit_setattr(args: list[str]) -> str {
    return _fcall("setattr", args);
}

impl PyBuiltinEmitter.emit_hasattr(args: list[str]) -> str {
    return _fcall("hasattr", args);
}

impl PyBuiltinEmitter.emit_delattr(args: list[str]) -> str {
    return _fcall("delattr", args);
}

impl PyBuiltinEmitter.emit_vars(args: list[str]) -> str {
    return _fcall("vars", args);
}

impl PyBuiltinEmitter.emit_dir(args: list[str]) -> str {
    return _fcall("dir", args);
}

impl PyBuiltinEmitter.emit_open(args: list[str]) -> str {
    return _fcall("open", args);
}

impl PyBuiltinEmitter.emit_format(args: list[str]) -> str {
    return _fcall("format", args);
}

impl PyBuiltinEmitter.emit_ascii(args: list[str]) -> str {
    return _fcall("ascii", args);
}

# Type conversion builtins
impl PyBuiltinEmitter.emit_str(args: list[str]) -> str {
    return _fcall("str", args);
}

impl PyBuiltinEmitter.emit_int(args: list[str]) -> str {
    return _fcall("int", args);
}

impl PyBuiltinEmitter.emit_float(args: list[str]) -> str {
    return _fcall("float", args);
}

impl PyBuiltinEmitter.emit_bool(args: list[str]) -> str {
    return _fcall("bool", args);
}

impl PyBuiltinEmitter.emit_list(args: list[str]) -> str {
    return _fcall("list", args);
}

impl PyBuiltinEmitter.emit_dict(args: list[str]) -> str {
    return _fcall("dict", args);
}

impl PyBuiltinEmitter.emit_set(args: list[str]) -> str {
    return _fcall("set", args);
}

impl PyBuiltinEmitter.emit_tuple(args: list[str]) -> str {
    return _fcall("tuple", args);
}

impl PyBuiltinEmitter.emit_frozenset(args: list[str]) -> str {
    return _fcall("frozenset", args);
}

impl PyBuiltinEmitter.emit_bytes(args: list[str]) -> str {
    return _fcall("bytes", args);
}

impl PyBuiltinEmitter.emit_complex(args: list[str]) -> str {
    return _fcall("complex", args);
}
