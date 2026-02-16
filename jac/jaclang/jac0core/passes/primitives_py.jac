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
def _mcall(
    target: str, method: str, args: list[str]
) -> str {
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
    def emit_bit_length(target: str, args: list[str]) -> str {
        return _mcall(target, "bit_length", args);
    }

    def emit_bit_count(target: str, args: list[str]) -> str {
        return _mcall(target, "bit_count", args);
    }

    def emit_to_bytes(target: str, args: list[str]) -> str {
        return _mcall(target, "to_bytes", args);
    }

    def emit_as_integer_ratio(target: str, args: list[str]) -> str {
        return _mcall(target, "as_integer_ratio", args);
    }

    def emit_conjugate(target: str, args: list[str]) -> str {
        return _mcall(target, "conjugate", args);
    }

    def emit_from_bytes(args: list[str]) -> str {
        return _scall("int", "from_bytes", args);
    }
}

class PyFloatEmitter(FloatEmitter) {
    def emit_is_integer(target: str, args: list[str]) -> str {
        return _mcall(target, "is_integer", args);
    }

    def emit_as_integer_ratio(target: str, args: list[str]) -> str {
        return _mcall(target, "as_integer_ratio", args);
    }

    def emit_conjugate(target: str, args: list[str]) -> str {
        return _mcall(target, "conjugate", args);
    }

    def emit_hex(target: str, args: list[str]) -> str {
        return _mcall(target, "hex", args);
    }

    def emit_fromhex(args: list[str]) -> str {
        return _scall("float", "fromhex", args);
    }
}

class PyComplexEmitter(ComplexEmitter) {
    def emit_conjugate(target: str, args: list[str]) -> str {
        return _mcall(target, "conjugate", args);
    }
}

# =============================================================================
#  String Types
# =============================================================================
class PyStrEmitter(StrEmitter) {
    # Case conversion
    def emit_capitalize(target: str, args: list[str]) -> str {
        return _mcall(target, "capitalize", args);
    }

    def emit_casefold(target: str, args: list[str]) -> str {
        return _mcall(target, "casefold", args);
    }

    def emit_lower(target: str, args: list[str]) -> str {
        return _mcall(target, "lower", args);
    }

    def emit_upper(target: str, args: list[str]) -> str {
        return _mcall(target, "upper", args);
    }

    def emit_title(target: str, args: list[str]) -> str {
        return _mcall(target, "title", args);
    }

    def emit_swapcase(target: str, args: list[str]) -> str {
        return _mcall(target, "swapcase", args);
    }
    # Search
    def emit_count(target: str, args: list[str]) -> str {
        return _mcall(target, "count", args);
    }

    def emit_find(target: str, args: list[str]) -> str {
        return _mcall(target, "find", args);
    }

    def emit_rfind(target: str, args: list[str]) -> str {
        return _mcall(target, "rfind", args);
    }

    def emit_index(target: str, args: list[str]) -> str {
        return _mcall(target, "index", args);
    }

    def emit_rindex(target: str, args: list[str]) -> str {
        return _mcall(target, "rindex", args);
    }

    def emit_startswith(target: str, args: list[str]) -> str {
        return _mcall(target, "startswith", args);
    }

    def emit_endswith(target: str, args: list[str]) -> str {
        return _mcall(target, "endswith", args);
    }
    # Modification
    def emit_replace(target: str, args: list[str]) -> str {
        return _mcall(target, "replace", args);
    }

    def emit_strip(target: str, args: list[str]) -> str {
        return _mcall(target, "strip", args);
    }

    def emit_lstrip(target: str, args: list[str]) -> str {
        return _mcall(target, "lstrip", args);
    }

    def emit_rstrip(target: str, args: list[str]) -> str {
        return _mcall(target, "rstrip", args);
    }

    def emit_removeprefix(target: str, args: list[str]) -> str {
        return _mcall(target, "removeprefix", args);
    }

    def emit_removesuffix(target: str, args: list[str]) -> str {
        return _mcall(target, "removesuffix", args);
    }
    # Split and join
    def emit_split(target: str, args: list[str]) -> str {
        return _mcall(target, "split", args);
    }

    def emit_rsplit(target: str, args: list[str]) -> str {
        return _mcall(target, "rsplit", args);
    }

    def emit_splitlines(target: str, args: list[str]) -> str {
        return _mcall(target, "splitlines", args);
    }

    def emit_join(target: str, args: list[str]) -> str {
        return _mcall(target, "join", args);
    }

    def emit_partition(target: str, args: list[str]) -> str {
        return _mcall(target, "partition", args);
    }

    def emit_rpartition(target: str, args: list[str]) -> str {
        return _mcall(target, "rpartition", args);
    }
    # Formatting and alignment
    def emit_format(target: str, args: list[str]) -> str {
        return _mcall(target, "format", args);
    }

    def emit_format_map(target: str, args: list[str]) -> str {
        return _mcall(target, "format_map", args);
    }

    def emit_center(target: str, args: list[str]) -> str {
        return _mcall(target, "center", args);
    }

    def emit_ljust(target: str, args: list[str]) -> str {
        return _mcall(target, "ljust", args);
    }

    def emit_rjust(target: str, args: list[str]) -> str {
        return _mcall(target, "rjust", args);
    }

    def emit_zfill(target: str, args: list[str]) -> str {
        return _mcall(target, "zfill", args);
    }

    def emit_expandtabs(target: str, args: list[str]) -> str {
        return _mcall(target, "expandtabs", args);
    }
    # Character tests
    def emit_isalnum(target: str, args: list[str]) -> str {
        return _mcall(target, "isalnum", args);
    }

    def emit_isalpha(target: str, args: list[str]) -> str {
        return _mcall(target, "isalpha", args);
    }

    def emit_isascii(target: str, args: list[str]) -> str {
        return _mcall(target, "isascii", args);
    }

    def emit_isdecimal(target: str, args: list[str]) -> str {
        return _mcall(target, "isdecimal", args);
    }

    def emit_isdigit(target: str, args: list[str]) -> str {
        return _mcall(target, "isdigit", args);
    }

    def emit_isidentifier(target: str, args: list[str]) -> str {
        return _mcall(target, "isidentifier", args);
    }

    def emit_islower(target: str, args: list[str]) -> str {
        return _mcall(target, "islower", args);
    }

    def emit_isnumeric(target: str, args: list[str]) -> str {
        return _mcall(target, "isnumeric", args);
    }

    def emit_isprintable(target: str, args: list[str]) -> str {
        return _mcall(target, "isprintable", args);
    }

    def emit_isspace(target: str, args: list[str]) -> str {
        return _mcall(target, "isspace", args);
    }

    def emit_istitle(target: str, args: list[str]) -> str {
        return _mcall(target, "istitle", args);
    }

    def emit_isupper(target: str, args: list[str]) -> str {
        return _mcall(target, "isupper", args);
    }
    # Encoding
    def emit_encode(target: str, args: list[str]) -> str {
        return _mcall(target, "encode", args);
    }
    # Translation
    def emit_translate(target: str, args: list[str]) -> str {
        return _mcall(target, "translate", args);
    }

    def emit_maketrans(args: list[str]) -> str {
        return _scall("str", "maketrans", args);
    }
}

class PyBytesEmitter(BytesEmitter) {
    # Decoding
    def emit_decode(target: str, args: list[str]) -> str {
        return _mcall(target, "decode", args);
    }

    def emit_hex(target: str, args: list[str]) -> str {
        return _mcall(target, "hex", args);
    }

    def emit_fromhex(args: list[str]) -> str {
        return _scall("bytes", "fromhex", args);
    }
    # Search
    def emit_count(target: str, args: list[str]) -> str {
        return _mcall(target, "count", args);
    }

    def emit_find(target: str, args: list[str]) -> str {
        return _mcall(target, "find", args);
    }

    def emit_rfind(target: str, args: list[str]) -> str {
        return _mcall(target, "rfind", args);
    }

    def emit_index(target: str, args: list[str]) -> str {
        return _mcall(target, "index", args);
    }

    def emit_rindex(target: str, args: list[str]) -> str {
        return _mcall(target, "rindex", args);
    }

    def emit_startswith(target: str, args: list[str]) -> str {
        return _mcall(target, "startswith", args);
    }

    def emit_endswith(target: str, args: list[str]) -> str {
        return _mcall(target, "endswith", args);
    }
    # Modification
    def emit_replace(target: str, args: list[str]) -> str {
        return _mcall(target, "replace", args);
    }

    def emit_strip(target: str, args: list[str]) -> str {
        return _mcall(target, "strip", args);
    }

    def emit_lstrip(target: str, args: list[str]) -> str {
        return _mcall(target, "lstrip", args);
    }

    def emit_rstrip(target: str, args: list[str]) -> str {
        return _mcall(target, "rstrip", args);
    }

    def emit_removeprefix(target: str, args: list[str]) -> str {
        return _mcall(target, "removeprefix", args);
    }

    def emit_removesuffix(target: str, args: list[str]) -> str {
        return _mcall(target, "removesuffix", args);
    }
    # Split and join
    def emit_split(target: str, args: list[str]) -> str {
        return _mcall(target, "split", args);
    }

    def emit_rsplit(target: str, args: list[str]) -> str {
        return _mcall(target, "rsplit", args);
    }

    def emit_splitlines(target: str, args: list[str]) -> str {
        return _mcall(target, "splitlines", args);
    }

    def emit_join(target: str, args: list[str]) -> str {
        return _mcall(target, "join", args);
    }

    def emit_partition(target: str, args: list[str]) -> str {
        return _mcall(target, "partition", args);
    }

    def emit_rpartition(target: str, args: list[str]) -> str {
        return _mcall(target, "rpartition", args);
    }
    # Case (ASCII only)
    def emit_capitalize(target: str, args: list[str]) -> str {
        return _mcall(target, "capitalize", args);
    }

    def emit_lower(target: str, args: list[str]) -> str {
        return _mcall(target, "lower", args);
    }

    def emit_upper(target: str, args: list[str]) -> str {
        return _mcall(target, "upper", args);
    }

    def emit_title(target: str, args: list[str]) -> str {
        return _mcall(target, "title", args);
    }

    def emit_swapcase(target: str, args: list[str]) -> str {
        return _mcall(target, "swapcase", args);
    }
    # Character tests (ASCII only)
    def emit_isalnum(target: str, args: list[str]) -> str {
        return _mcall(target, "isalnum", args);
    }

    def emit_isalpha(target: str, args: list[str]) -> str {
        return _mcall(target, "isalpha", args);
    }

    def emit_isascii(target: str, args: list[str]) -> str {
        return _mcall(target, "isascii", args);
    }

    def emit_isdigit(target: str, args: list[str]) -> str {
        return _mcall(target, "isdigit", args);
    }

    def emit_islower(target: str, args: list[str]) -> str {
        return _mcall(target, "islower", args);
    }

    def emit_isspace(target: str, args: list[str]) -> str {
        return _mcall(target, "isspace", args);
    }

    def emit_istitle(target: str, args: list[str]) -> str {
        return _mcall(target, "istitle", args);
    }

    def emit_isupper(target: str, args: list[str]) -> str {
        return _mcall(target, "isupper", args);
    }
    # Alignment
    def emit_center(target: str, args: list[str]) -> str {
        return _mcall(target, "center", args);
    }

    def emit_ljust(target: str, args: list[str]) -> str {
        return _mcall(target, "ljust", args);
    }

    def emit_rjust(target: str, args: list[str]) -> str {
        return _mcall(target, "rjust", args);
    }

    def emit_zfill(target: str, args: list[str]) -> str {
        return _mcall(target, "zfill", args);
    }

    def emit_expandtabs(target: str, args: list[str]) -> str {
        return _mcall(target, "expandtabs", args);
    }
    # Translation
    def emit_translate(target: str, args: list[str]) -> str {
        return _mcall(target, "translate", args);
    }

    def emit_maketrans(args: list[str]) -> str {
        return _scall("bytes", "maketrans", args);
    }
}

# =============================================================================
#  Collection Types
# =============================================================================
class PyListEmitter(ListEmitter) {
    def emit_append(target: str, args: list[str]) -> str {
        return _mcall(target, "append", args);
    }

    def emit_extend(target: str, args: list[str]) -> str {
        return _mcall(target, "extend", args);
    }

    def emit_insert(target: str, args: list[str]) -> str {
        return _mcall(target, "insert", args);
    }

    def emit_remove(target: str, args: list[str]) -> str {
        return _mcall(target, "remove", args);
    }

    def emit_pop(target: str, args: list[str]) -> str {
        return _mcall(target, "pop", args);
    }

    def emit_clear(target: str, args: list[str]) -> str {
        return _mcall(target, "clear", args);
    }

    def emit_index(target: str, args: list[str]) -> str {
        return _mcall(target, "index", args);
    }

    def emit_count(target: str, args: list[str]) -> str {
        return _mcall(target, "count", args);
    }

    def emit_sort(target: str, args: list[str]) -> str {
        return _mcall(target, "sort", args);
    }

    def emit_reverse(target: str, args: list[str]) -> str {
        return _mcall(target, "reverse", args);
    }

    def emit_copy(target: str, args: list[str]) -> str {
        return _mcall(target, "copy", args);
    }
}

class PyDictEmitter(DictEmitter) {
    def emit_get(target: str, args: list[str]) -> str {
        return _mcall(target, "get", args);
    }

    def emit_keys(target: str, args: list[str]) -> str {
        return _mcall(target, "keys", args);
    }

    def emit_values(target: str, args: list[str]) -> str {
        return _mcall(target, "values", args);
    }

    def emit_items(target: str, args: list[str]) -> str {
        return _mcall(target, "items", args);
    }

    def emit_pop(target: str, args: list[str]) -> str {
        return _mcall(target, "pop", args);
    }

    def emit_popitem(target: str, args: list[str]) -> str {
        return _mcall(target, "popitem", args);
    }

    def emit_setdefault(target: str, args: list[str]) -> str {
        return _mcall(target, "setdefault", args);
    }

    def emit_update(target: str, args: list[str]) -> str {
        return _mcall(target, "update", args);
    }

    def emit_clear(target: str, args: list[str]) -> str {
        return _mcall(target, "clear", args);
    }

    def emit_copy(target: str, args: list[str]) -> str {
        return _mcall(target, "copy", args);
    }

    def emit_fromkeys(args: list[str]) -> str {
        return _scall("dict", "fromkeys", args);
    }
}

class PySetEmitter(SetEmitter) {
    # Mutation
    def emit_add(target: str, args: list[str]) -> str {
        return _mcall(target, "add", args);
    }

    def emit_remove(target: str, args: list[str]) -> str {
        return _mcall(target, "remove", args);
    }

    def emit_discard(target: str, args: list[str]) -> str {
        return _mcall(target, "discard", args);
    }

    def emit_pop(target: str, args: list[str]) -> str {
        return _mcall(target, "pop", args);
    }

    def emit_clear(target: str, args: list[str]) -> str {
        return _mcall(target, "clear", args);
    }
    # Set algebra
    def emit_union(target: str, args: list[str]) -> str {
        return _mcall(target, "union", args);
    }

    def emit_intersection(target: str, args: list[str]) -> str {
        return _mcall(target, "intersection", args);
    }

    def emit_difference(target: str, args: list[str]) -> str {
        return _mcall(target, "difference", args);
    }

    def emit_symmetric_difference(target: str, args: list[str]) -> str {
        return _mcall(target, "symmetric_difference", args);
    }
    # In-place set algebra
    def emit_update(target: str, args: list[str]) -> str {
        return _mcall(target, "update", args);
    }

    def emit_intersection_update(target: str, args: list[str]) -> str {
        return _mcall(target, "intersection_update", args);
    }

    def emit_difference_update(target: str, args: list[str]) -> str {
        return _mcall(target, "difference_update", args);
    }

    def emit_symmetric_difference_update(target: str, args: list[str]) -> str {
        return _mcall(target, "symmetric_difference_update", args);
    }
    # Tests
    def emit_issubset(target: str, args: list[str]) -> str {
        return _mcall(target, "issubset", args);
    }

    def emit_issuperset(target: str, args: list[str]) -> str {
        return _mcall(target, "issuperset", args);
    }

    def emit_isdisjoint(target: str, args: list[str]) -> str {
        return _mcall(target, "isdisjoint", args);
    }

    def emit_copy(target: str, args: list[str]) -> str {
        return _mcall(target, "copy", args);
    }
}

class PyFrozensetEmitter(FrozensetEmitter) {
    def emit_union(target: str, args: list[str]) -> str {
        return _mcall(target, "union", args);
    }

    def emit_intersection(target: str, args: list[str]) -> str {
        return _mcall(target, "intersection", args);
    }

    def emit_difference(target: str, args: list[str]) -> str {
        return _mcall(target, "difference", args);
    }

    def emit_symmetric_difference(target: str, args: list[str]) -> str {
        return _mcall(target, "symmetric_difference", args);
    }

    def emit_issubset(target: str, args: list[str]) -> str {
        return _mcall(target, "issubset", args);
    }

    def emit_issuperset(target: str, args: list[str]) -> str {
        return _mcall(target, "issuperset", args);
    }

    def emit_isdisjoint(target: str, args: list[str]) -> str {
        return _mcall(target, "isdisjoint", args);
    }

    def emit_copy(target: str, args: list[str]) -> str {
        return _mcall(target, "copy", args);
    }
}

class PyTupleEmitter(TupleEmitter) {
    def emit_count(target: str, args: list[str]) -> str {
        return _mcall(target, "count", args);
    }

    def emit_index(target: str, args: list[str]) -> str {
        return _mcall(target, "index", args);
    }
}

class PyRangeEmitter(RangeEmitter) {
    def emit_count(target: str, args: list[str]) -> str {
        return _mcall(target, "count", args);
    }

    def emit_index(target: str, args: list[str]) -> str {
        return _mcall(target, "index", args);
    }
}

# =============================================================================
#  Builtin Functions
# =============================================================================
class PyBuiltinEmitter(BuiltinEmitter) {
    def emit_print(args: list[str]) -> str {
        return _fcall("print", args);
    }

    def emit_input(args: list[str]) -> str {
        return _fcall("input", args);
    }

    def emit_len(args: list[str]) -> str {
        return _fcall("len", args);
    }

    def emit_abs(args: list[str]) -> str {
        return _fcall("abs", args);
    }

    def emit_round(args: list[str]) -> str {
        return _fcall("round", args);
    }

    def emit_min(args: list[str]) -> str {
        return _fcall("min", args);
    }

    def emit_max(args: list[str]) -> str {
        return _fcall("max", args);
    }

    def emit_sum(args: list[str]) -> str {
        return _fcall("sum", args);
    }

    def emit_sorted(args: list[str]) -> str {
        return _fcall("sorted", args);
    }

    def emit_reversed(args: list[str]) -> str {
        return _fcall("reversed", args);
    }

    def emit_enumerate(args: list[str]) -> str {
        return _fcall("enumerate", args);
    }

    def emit_zip(args: list[str]) -> str {
        return _fcall("zip", args);
    }

    def emit_map(args: list[str]) -> str {
        return _fcall("map", args);
    }

    def emit_filter(args: list[str]) -> str {
        return _fcall("filter", args);
    }

    def emit_any(args: list[str]) -> str {
        return _fcall("any", args);
    }

    def emit_all(args: list[str]) -> str {
        return _fcall("all", args);
    }

    def emit_isinstance(args: list[str]) -> str {
        return _fcall("isinstance", args);
    }

    def emit_issubclass(args: list[str]) -> str {
        return _fcall("issubclass", args);
    }

    def emit_type(args: list[str]) -> str {
        return _fcall("type", args);
    }

    def emit_id(args: list[str]) -> str {
        return _fcall("id", args);
    }

    def emit_hash(args: list[str]) -> str {
        return _fcall("hash", args);
    }

    def emit_repr(args: list[str]) -> str {
        return _fcall("repr", args);
    }

    def emit_chr(args: list[str]) -> str {
        return _fcall("chr", args);
    }

    def emit_ord(args: list[str]) -> str {
        return _fcall("ord", args);
    }

    def emit_hex(args: list[str]) -> str {
        return _fcall("hex", args);
    }

    def emit_oct(args: list[str]) -> str {
        return _fcall("oct", args);
    }

    def emit_bin(args: list[str]) -> str {
        return _fcall("bin", args);
    }

    def emit_pow(args: list[str]) -> str {
        return _fcall("pow", args);
    }

    def emit_divmod(args: list[str]) -> str {
        return _fcall("divmod", args);
    }

    def emit_iter(args: list[str]) -> str {
        return _fcall("iter", args);
    }

    def emit_next(args: list[str]) -> str {
        return _fcall("next", args);
    }

    def emit_callable(args: list[str]) -> str {
        return _fcall("callable", args);
    }

    def emit_getattr(args: list[str]) -> str {
        return _fcall("getattr", args);
    }

    def emit_setattr(args: list[str]) -> str {
        return _fcall("setattr", args);
    }

    def emit_hasattr(args: list[str]) -> str {
        return _fcall("hasattr", args);
    }

    def emit_delattr(args: list[str]) -> str {
        return _fcall("delattr", args);
    }

    def emit_vars(args: list[str]) -> str {
        return _fcall("vars", args);
    }

    def emit_dir(args: list[str]) -> str {
        return _fcall("dir", args);
    }

    def emit_open(args: list[str]) -> str {
        return _fcall("open", args);
    }

    def emit_format(args: list[str]) -> str {
        return _fcall("format", args);
    }

    def emit_ascii(args: list[str]) -> str {
        return _fcall("ascii", args);
    }

    # Type conversion builtins
    def emit_str(args: list[str]) -> str {
        return _fcall("str", args);
    }

    def emit_int(args: list[str]) -> str {
        return _fcall("int", args);
    }

    def emit_float(args: list[str]) -> str {
        return _fcall("float", args);
    }

    def emit_bool(args: list[str]) -> str {
        return _fcall("bool", args);
    }

    def emit_list(args: list[str]) -> str {
        return _fcall("list", args);
    }

    def emit_dict(args: list[str]) -> str {
        return _fcall("dict", args);
    }

    def emit_set(args: list[str]) -> str {
        return _fcall("set", args);
    }

    def emit_tuple(args: list[str]) -> str {
        return _fcall("tuple", args);
    }

    def emit_frozenset(args: list[str]) -> str {
        return _fcall("frozenset", args);
    }

    def emit_bytes(args: list[str]) -> str {
        return _fcall("bytes", args);
    }

    def emit_complex(args: list[str]) -> str {
        return _fcall("complex", args);
    }
}
