"""Native (LLVM) backend primitive emitter implementations.

All methods emit calls to the Jac native runtime library. The runtime
functions follow the naming convention _jac_<type>_<method> and are
linked at compile time from the Jac native runtime (libjac_rt).
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
def _rt(
    prefix: str, method: str, args: list[str]
) -> str {
    """Emit a call to the native runtime: _jac_<prefix>_<method>(args).""";
    name = "_jac_" + prefix + "_" + method;
    if len(args) > 0 {
        return name + "(" + ", ".join(args) + ")";
    }
    return name + "()";
}

# =============================================================================
#  Numeric Types
# =============================================================================
class NativeIntEmitter(IntEmitter) {
    def emit_bit_length(target: str, args: list[str]) -> str {
        return _rt("int", "bit_length", [target]);
    }

    def emit_bit_count(target: str, args: list[str]) -> str {
        return _rt("int", "bit_count", [target]);
    }

    def emit_to_bytes(target: str, args: list[str]) -> str {
        return _rt("int", "to_bytes", [target] + args);
    }

    def emit_as_integer_ratio(target: str, args: list[str]) -> str {
        return _rt("int", "as_integer_ratio", [target]);
    }

    def emit_conjugate(target: str, args: list[str]) -> str {
        return target;
    }

    def emit_from_bytes(args: list[str]) -> str {
        return _rt("int", "from_bytes", args);
    }
}

class NativeFloatEmitter(FloatEmitter) {
    def emit_is_integer(target: str, args: list[str]) -> str {
        return _rt("float", "is_integer", [target]);
    }

    def emit_as_integer_ratio(target: str, args: list[str]) -> str {
        return _rt("float", "as_integer_ratio", [target]);
    }

    def emit_conjugate(target: str, args: list[str]) -> str {
        return target;
    }

    def emit_hex(target: str, args: list[str]) -> str {
        return _rt("float", "hex", [target]);
    }

    def emit_fromhex(args: list[str]) -> str {
        return _rt("float", "fromhex", args);
    }
}

class NativeComplexEmitter(ComplexEmitter) {
    def emit_conjugate(target: str, args: list[str]) -> str {
        return _rt("complex", "conjugate", [target]);
    }
}

# =============================================================================
#  String Types
# =============================================================================
class NativeStrEmitter(StrEmitter) {
    # Case conversion
    def emit_capitalize(target: str, args: list[str]) -> str {
        return _rt("str", "capitalize", [target]);
    }

    def emit_casefold(target: str, args: list[str]) -> str {
        return _rt("str", "casefold", [target]);
    }

    def emit_lower(target: str, args: list[str]) -> str {
        return _rt("str", "lower", [target]);
    }

    def emit_upper(target: str, args: list[str]) -> str {
        return _rt("str", "upper", [target]);
    }

    def emit_title(target: str, args: list[str]) -> str {
        return _rt("str", "title", [target]);
    }

    def emit_swapcase(target: str, args: list[str]) -> str {
        return _rt("str", "swapcase", [target]);
    }
    # Search
    def emit_count(target: str, args: list[str]) -> str {
        return _rt("str", "count", [target] + args);
    }

    def emit_find(target: str, args: list[str]) -> str {
        return _rt("str", "find", [target] + args);
    }

    def emit_rfind(target: str, args: list[str]) -> str {
        return _rt("str", "rfind", [target] + args);
    }

    def emit_index(target: str, args: list[str]) -> str {
        return _rt("str", "index", [target] + args);
    }

    def emit_rindex(target: str, args: list[str]) -> str {
        return _rt("str", "rindex", [target] + args);
    }

    def emit_startswith(target: str, args: list[str]) -> str {
        return _rt("str", "startswith", [target] + args);
    }

    def emit_endswith(target: str, args: list[str]) -> str {
        return _rt("str", "endswith", [target] + args);
    }
    # Modification
    def emit_replace(target: str, args: list[str]) -> str {
        return _rt("str", "replace", [target] + args);
    }

    def emit_strip(target: str, args: list[str]) -> str {
        return _rt("str", "strip", [target] + args);
    }

    def emit_lstrip(target: str, args: list[str]) -> str {
        return _rt("str", "lstrip", [target] + args);
    }

    def emit_rstrip(target: str, args: list[str]) -> str {
        return _rt("str", "rstrip", [target] + args);
    }

    def emit_removeprefix(target: str, args: list[str]) -> str {
        return _rt("str", "removeprefix", [target] + args);
    }

    def emit_removesuffix(target: str, args: list[str]) -> str {
        return _rt("str", "removesuffix", [target] + args);
    }
    # Split and join
    def emit_split(target: str, args: list[str]) -> str {
        return _rt("str", "split", [target] + args);
    }

    def emit_rsplit(target: str, args: list[str]) -> str {
        return _rt("str", "rsplit", [target] + args);
    }

    def emit_splitlines(target: str, args: list[str]) -> str {
        return _rt("str", "splitlines", [target] + args);
    }

    def emit_join(target: str, args: list[str]) -> str {
        return _rt("str", "join", [target] + args);
    }

    def emit_partition(target: str, args: list[str]) -> str {
        return _rt("str", "partition", [target] + args);
    }

    def emit_rpartition(target: str, args: list[str]) -> str {
        return _rt("str", "rpartition", [target] + args);
    }
    # Formatting and alignment
    def emit_format(target: str, args: list[str]) -> str {
        return _rt("str", "format", [target] + args);
    }

    def emit_format_map(target: str, args: list[str]) -> str {
        return _rt("str", "format_map", [target] + args);
    }

    def emit_center(target: str, args: list[str]) -> str {
        return _rt("str", "center", [target] + args);
    }

    def emit_ljust(target: str, args: list[str]) -> str {
        return _rt("str", "ljust", [target] + args);
    }

    def emit_rjust(target: str, args: list[str]) -> str {
        return _rt("str", "rjust", [target] + args);
    }

    def emit_zfill(target: str, args: list[str]) -> str {
        return _rt("str", "zfill", [target] + args);
    }

    def emit_expandtabs(target: str, args: list[str]) -> str {
        return _rt("str", "expandtabs", [target] + args);
    }
    # Character tests
    def emit_isalnum(target: str, args: list[str]) -> str {
        return _rt("str", "isalnum", [target]);
    }

    def emit_isalpha(target: str, args: list[str]) -> str {
        return _rt("str", "isalpha", [target]);
    }

    def emit_isascii(target: str, args: list[str]) -> str {
        return _rt("str", "isascii", [target]);
    }

    def emit_isdecimal(target: str, args: list[str]) -> str {
        return _rt("str", "isdecimal", [target]);
    }

    def emit_isdigit(target: str, args: list[str]) -> str {
        return _rt("str", "isdigit", [target]);
    }

    def emit_isidentifier(target: str, args: list[str]) -> str {
        return _rt("str", "isidentifier", [target]);
    }

    def emit_islower(target: str, args: list[str]) -> str {
        return _rt("str", "islower", [target]);
    }

    def emit_isnumeric(target: str, args: list[str]) -> str {
        return _rt("str", "isnumeric", [target]);
    }

    def emit_isprintable(target: str, args: list[str]) -> str {
        return _rt("str", "isprintable", [target]);
    }

    def emit_isspace(target: str, args: list[str]) -> str {
        return _rt("str", "isspace", [target]);
    }

    def emit_istitle(target: str, args: list[str]) -> str {
        return _rt("str", "istitle", [target]);
    }

    def emit_isupper(target: str, args: list[str]) -> str {
        return _rt("str", "isupper", [target]);
    }
    # Encoding
    def emit_encode(target: str, args: list[str]) -> str {
        return _rt("str", "encode", [target] + args);
    }
    # Translation
    def emit_translate(target: str, args: list[str]) -> str {
        return _rt("str", "translate", [target] + args);
    }

    def emit_maketrans(args: list[str]) -> str {
        return _rt("str", "maketrans", args);
    }
}

class NativeBytesEmitter(BytesEmitter) {
    # Decoding
    def emit_decode(target: str, args: list[str]) -> str {
        return _rt("bytes", "decode", [target] + args);
    }

    def emit_hex(target: str, args: list[str]) -> str {
        return _rt("bytes", "hex", [target] + args);
    }

    def emit_fromhex(args: list[str]) -> str {
        return _rt("bytes", "fromhex", args);
    }
    # Search
    def emit_count(target: str, args: list[str]) -> str {
        return _rt("bytes", "count", [target] + args);
    }

    def emit_find(target: str, args: list[str]) -> str {
        return _rt("bytes", "find", [target] + args);
    }

    def emit_rfind(target: str, args: list[str]) -> str {
        return _rt("bytes", "rfind", [target] + args);
    }

    def emit_index(target: str, args: list[str]) -> str {
        return _rt("bytes", "index", [target] + args);
    }

    def emit_rindex(target: str, args: list[str]) -> str {
        return _rt("bytes", "rindex", [target] + args);
    }

    def emit_startswith(target: str, args: list[str]) -> str {
        return _rt("bytes", "startswith", [target] + args);
    }

    def emit_endswith(target: str, args: list[str]) -> str {
        return _rt("bytes", "endswith", [target] + args);
    }
    # Modification
    def emit_replace(target: str, args: list[str]) -> str {
        return _rt("bytes", "replace", [target] + args);
    }

    def emit_strip(target: str, args: list[str]) -> str {
        return _rt("bytes", "strip", [target] + args);
    }

    def emit_lstrip(target: str, args: list[str]) -> str {
        return _rt("bytes", "lstrip", [target] + args);
    }

    def emit_rstrip(target: str, args: list[str]) -> str {
        return _rt("bytes", "rstrip", [target] + args);
    }

    def emit_removeprefix(target: str, args: list[str]) -> str {
        return _rt("bytes", "removeprefix", [target] + args);
    }

    def emit_removesuffix(target: str, args: list[str]) -> str {
        return _rt("bytes", "removesuffix", [target] + args);
    }
    # Split and join
    def emit_split(target: str, args: list[str]) -> str {
        return _rt("bytes", "split", [target] + args);
    }

    def emit_rsplit(target: str, args: list[str]) -> str {
        return _rt("bytes", "rsplit", [target] + args);
    }

    def emit_splitlines(target: str, args: list[str]) -> str {
        return _rt("bytes", "splitlines", [target] + args);
    }

    def emit_join(target: str, args: list[str]) -> str {
        return _rt("bytes", "join", [target] + args);
    }

    def emit_partition(target: str, args: list[str]) -> str {
        return _rt("bytes", "partition", [target] + args);
    }

    def emit_rpartition(target: str, args: list[str]) -> str {
        return _rt("bytes", "rpartition", [target] + args);
    }
    # Case (ASCII only)
    def emit_capitalize(target: str, args: list[str]) -> str {
        return _rt("bytes", "capitalize", [target]);
    }

    def emit_lower(target: str, args: list[str]) -> str {
        return _rt("bytes", "lower", [target]);
    }

    def emit_upper(target: str, args: list[str]) -> str {
        return _rt("bytes", "upper", [target]);
    }

    def emit_title(target: str, args: list[str]) -> str {
        return _rt("bytes", "title", [target]);
    }

    def emit_swapcase(target: str, args: list[str]) -> str {
        return _rt("bytes", "swapcase", [target]);
    }
    # Character tests (ASCII only)
    def emit_isalnum(target: str, args: list[str]) -> str {
        return _rt("bytes", "isalnum", [target]);
    }

    def emit_isalpha(target: str, args: list[str]) -> str {
        return _rt("bytes", "isalpha", [target]);
    }

    def emit_isascii(target: str, args: list[str]) -> str {
        return _rt("bytes", "isascii", [target]);
    }

    def emit_isdigit(target: str, args: list[str]) -> str {
        return _rt("bytes", "isdigit", [target]);
    }

    def emit_islower(target: str, args: list[str]) -> str {
        return _rt("bytes", "islower", [target]);
    }

    def emit_isspace(target: str, args: list[str]) -> str {
        return _rt("bytes", "isspace", [target]);
    }

    def emit_istitle(target: str, args: list[str]) -> str {
        return _rt("bytes", "istitle", [target]);
    }

    def emit_isupper(target: str, args: list[str]) -> str {
        return _rt("bytes", "isupper", [target]);
    }
    # Alignment
    def emit_center(target: str, args: list[str]) -> str {
        return _rt("bytes", "center", [target] + args);
    }

    def emit_ljust(target: str, args: list[str]) -> str {
        return _rt("bytes", "ljust", [target] + args);
    }

    def emit_rjust(target: str, args: list[str]) -> str {
        return _rt("bytes", "rjust", [target] + args);
    }

    def emit_zfill(target: str, args: list[str]) -> str {
        return _rt("bytes", "zfill", [target] + args);
    }

    def emit_expandtabs(target: str, args: list[str]) -> str {
        return _rt("bytes", "expandtabs", [target] + args);
    }
    # Translation
    def emit_translate(target: str, args: list[str]) -> str {
        return _rt("bytes", "translate", [target] + args);
    }

    def emit_maketrans(args: list[str]) -> str {
        return _rt("bytes", "maketrans", args);
    }
}

# =============================================================================
#  Collection Types
# =============================================================================
class NativeListEmitter(ListEmitter) {
    def emit_append(target: str, args: list[str]) -> str {
        return _rt("list", "append", [target] + args);
    }

    def emit_extend(target: str, args: list[str]) -> str {
        return _rt("list", "extend", [target] + args);
    }

    def emit_insert(target: str, args: list[str]) -> str {
        return _rt("list", "insert", [target] + args);
    }

    def emit_remove(target: str, args: list[str]) -> str {
        return _rt("list", "remove", [target] + args);
    }

    def emit_pop(target: str, args: list[str]) -> str {
        return _rt("list", "pop", [target] + args);
    }

    def emit_clear(target: str, args: list[str]) -> str {
        return _rt("list", "clear", [target]);
    }

    def emit_index(target: str, args: list[str]) -> str {
        return _rt("list", "index", [target] + args);
    }

    def emit_count(target: str, args: list[str]) -> str {
        return _rt("list", "count", [target] + args);
    }

    def emit_sort(target: str, args: list[str]) -> str {
        return _rt("list", "sort", [target] + args);
    }

    def emit_reverse(target: str, args: list[str]) -> str {
        return _rt("list", "reverse", [target]);
    }

    def emit_copy(target: str, args: list[str]) -> str {
        return _rt("list", "copy", [target]);
    }
}

class NativeDictEmitter(DictEmitter) {
    def emit_get(target: str, args: list[str]) -> str {
        return _rt("dict", "get", [target] + args);
    }

    def emit_keys(target: str, args: list[str]) -> str {
        return _rt("dict", "keys", [target]);
    }

    def emit_values(target: str, args: list[str]) -> str {
        return _rt("dict", "values", [target]);
    }

    def emit_items(target: str, args: list[str]) -> str {
        return _rt("dict", "items", [target]);
    }

    def emit_pop(target: str, args: list[str]) -> str {
        return _rt("dict", "pop", [target] + args);
    }

    def emit_popitem(target: str, args: list[str]) -> str {
        return _rt("dict", "popitem", [target]);
    }

    def emit_setdefault(target: str, args: list[str]) -> str {
        return _rt("dict", "setdefault", [target] + args);
    }

    def emit_update(target: str, args: list[str]) -> str {
        return _rt("dict", "update", [target] + args);
    }

    def emit_clear(target: str, args: list[str]) -> str {
        return _rt("dict", "clear", [target]);
    }

    def emit_copy(target: str, args: list[str]) -> str {
        return _rt("dict", "copy", [target]);
    }

    def emit_fromkeys(args: list[str]) -> str {
        return _rt("dict", "fromkeys", args);
    }
}

class NativeSetEmitter(SetEmitter) {
    # Mutation
    def emit_add(target: str, args: list[str]) -> str {
        return _rt("set", "add", [target] + args);
    }

    def emit_remove(target: str, args: list[str]) -> str {
        return _rt("set", "remove", [target] + args);
    }

    def emit_discard(target: str, args: list[str]) -> str {
        return _rt("set", "discard", [target] + args);
    }

    def emit_pop(target: str, args: list[str]) -> str {
        return _rt("set", "pop", [target]);
    }

    def emit_clear(target: str, args: list[str]) -> str {
        return _rt("set", "clear", [target]);
    }
    # Set algebra
    def emit_union(target: str, args: list[str]) -> str {
        return _rt("set", "union", [target] + args);
    }

    def emit_intersection(target: str, args: list[str]) -> str {
        return _rt("set", "intersection", [target] + args);
    }

    def emit_difference(target: str, args: list[str]) -> str {
        return _rt("set", "difference", [target] + args);
    }

    def emit_symmetric_difference(target: str, args: list[str]) -> str {
        return _rt("set", "symmetric_difference", [target] + args);
    }
    # In-place set algebra
    def emit_update(target: str, args: list[str]) -> str {
        return _rt("set", "update", [target] + args);
    }

    def emit_intersection_update(target: str, args: list[str]) -> str {
        return _rt("set", "intersection_update", [target] + args);
    }

    def emit_difference_update(target: str, args: list[str]) -> str {
        return _rt("set", "difference_update", [target] + args);
    }

    def emit_symmetric_difference_update(target: str, args: list[str]) -> str {
        return _rt("set", "symmetric_difference_update", [target] + args);
    }
    # Tests
    def emit_issubset(target: str, args: list[str]) -> str {
        return _rt("set", "issubset", [target] + args);
    }

    def emit_issuperset(target: str, args: list[str]) -> str {
        return _rt("set", "issuperset", [target] + args);
    }

    def emit_isdisjoint(target: str, args: list[str]) -> str {
        return _rt("set", "isdisjoint", [target] + args);
    }

    def emit_copy(target: str, args: list[str]) -> str {
        return _rt("set", "copy", [target]);
    }
}

class NativeFrozensetEmitter(FrozensetEmitter) {
    def emit_union(target: str, args: list[str]) -> str {
        return _rt("frozenset", "union", [target] + args);
    }

    def emit_intersection(target: str, args: list[str]) -> str {
        return _rt("frozenset", "intersection", [target] + args);
    }

    def emit_difference(target: str, args: list[str]) -> str {
        return _rt("frozenset", "difference", [target] + args);
    }

    def emit_symmetric_difference(target: str, args: list[str]) -> str {
        return _rt("frozenset", "symmetric_difference", [target] + args);
    }

    def emit_issubset(target: str, args: list[str]) -> str {
        return _rt("frozenset", "issubset", [target] + args);
    }

    def emit_issuperset(target: str, args: list[str]) -> str {
        return _rt("frozenset", "issuperset", [target] + args);
    }

    def emit_isdisjoint(target: str, args: list[str]) -> str {
        return _rt("frozenset", "isdisjoint", [target] + args);
    }

    def emit_copy(target: str, args: list[str]) -> str {
        return _rt("frozenset", "copy", [target]);
    }
}

class NativeTupleEmitter(TupleEmitter) {
    def emit_count(target: str, args: list[str]) -> str {
        return _rt("tuple", "count", [target] + args);
    }

    def emit_index(target: str, args: list[str]) -> str {
        return _rt("tuple", "index", [target] + args);
    }
}

class NativeRangeEmitter(RangeEmitter) {
    def emit_count(target: str, args: list[str]) -> str {
        return _rt("range", "count", [target] + args);
    }

    def emit_index(target: str, args: list[str]) -> str {
        return _rt("range", "index", [target] + args);
    }
}

# =============================================================================
#  Builtin Functions
# =============================================================================
class NativeBuiltinEmitter(BuiltinEmitter) {
    def emit_print(args: list[str]) -> str {
        return _rt("builtin", "print", args);
    }

    def emit_input(args: list[str]) -> str {
        return _rt("builtin", "input", args);
    }

    def emit_len(args: list[str]) -> str {
        return _rt("builtin", "len", args);
    }

    def emit_abs(args: list[str]) -> str {
        return _rt("builtin", "abs", args);
    }

    def emit_round(args: list[str]) -> str {
        return _rt("builtin", "round", args);
    }

    def emit_min(args: list[str]) -> str {
        return _rt("builtin", "min", args);
    }

    def emit_max(args: list[str]) -> str {
        return _rt("builtin", "max", args);
    }

    def emit_sum(args: list[str]) -> str {
        return _rt("builtin", "sum", args);
    }

    def emit_sorted(args: list[str]) -> str {
        return _rt("builtin", "sorted", args);
    }

    def emit_reversed(args: list[str]) -> str {
        return _rt("builtin", "reversed", args);
    }

    def emit_enumerate(args: list[str]) -> str {
        return _rt("builtin", "enumerate", args);
    }

    def emit_zip(args: list[str]) -> str {
        return _rt("builtin", "zip", args);
    }

    def emit_map(args: list[str]) -> str {
        return _rt("builtin", "map", args);
    }

    def emit_filter(args: list[str]) -> str {
        return _rt("builtin", "filter", args);
    }

    def emit_any(args: list[str]) -> str {
        return _rt("builtin", "any", args);
    }

    def emit_all(args: list[str]) -> str {
        return _rt("builtin", "all", args);
    }

    def emit_isinstance(args: list[str]) -> str {
        return _rt("builtin", "isinstance", args);
    }

    def emit_issubclass(args: list[str]) -> str {
        return _rt("builtin", "issubclass", args);
    }

    def emit_type(args: list[str]) -> str {
        return _rt("builtin", "type", args);
    }

    def emit_id(args: list[str]) -> str {
        return _rt("builtin", "id", args);
    }

    def emit_hash(args: list[str]) -> str {
        return _rt("builtin", "hash", args);
    }

    def emit_repr(args: list[str]) -> str {
        return _rt("builtin", "repr", args);
    }

    def emit_chr(args: list[str]) -> str {
        return _rt("builtin", "chr", args);
    }

    def emit_ord(args: list[str]) -> str {
        return _rt("builtin", "ord", args);
    }

    def emit_hex(args: list[str]) -> str {
        return _rt("builtin", "hex", args);
    }

    def emit_oct(args: list[str]) -> str {
        return _rt("builtin", "oct", args);
    }

    def emit_bin(args: list[str]) -> str {
        return _rt("builtin", "bin", args);
    }

    def emit_pow(args: list[str]) -> str {
        return _rt("builtin", "pow", args);
    }

    def emit_divmod(args: list[str]) -> str {
        return _rt("builtin", "divmod", args);
    }

    def emit_iter(args: list[str]) -> str {
        return _rt("builtin", "iter", args);
    }

    def emit_next(args: list[str]) -> str {
        return _rt("builtin", "next", args);
    }

    def emit_callable(args: list[str]) -> str {
        return _rt("builtin", "callable", args);
    }

    def emit_getattr(args: list[str]) -> str {
        return _rt("builtin", "getattr", args);
    }

    def emit_setattr(args: list[str]) -> str {
        return _rt("builtin", "setattr", args);
    }

    def emit_hasattr(args: list[str]) -> str {
        return _rt("builtin", "hasattr", args);
    }

    def emit_delattr(args: list[str]) -> str {
        return _rt("builtin", "delattr", args);
    }

    def emit_vars(args: list[str]) -> str {
        return _rt("builtin", "vars", args);
    }

    def emit_dir(args: list[str]) -> str {
        return _rt("builtin", "dir", args);
    }

    def emit_open(args: list[str]) -> str {
        return _rt("builtin", "open", args);
    }

    def emit_format(args: list[str]) -> str {
        return _rt("builtin", "format", args);
    }

    def emit_ascii(args: list[str]) -> str {
        return _rt("builtin", "ascii", args);
    }

    # Type conversion builtins
    def emit_str(args: list[str]) -> str {
        return _rt("builtin", "str", args);
    }

    def emit_int(args: list[str]) -> str {
        return _rt("builtin", "int", args);
    }

    def emit_float(args: list[str]) -> str {
        return _rt("builtin", "float", args);
    }

    def emit_bool(args: list[str]) -> str {
        return _rt("builtin", "bool", args);
    }

    def emit_list(args: list[str]) -> str {
        return _rt("builtin", "list", args);
    }

    def emit_dict(args: list[str]) -> str {
        return _rt("builtin", "dict", args);
    }

    def emit_set(args: list[str]) -> str {
        return _rt("builtin", "set", args);
    }

    def emit_tuple(args: list[str]) -> str {
        return _rt("builtin", "tuple", args);
    }

    def emit_frozenset(args: list[str]) -> str {
        return _rt("builtin", "frozenset", args);
    }

    def emit_bytes(args: list[str]) -> str {
        return _rt("builtin", "bytes", args);
    }

    def emit_complex(args: list[str]) -> str {
        return _rt("builtin", "complex", args);
    }
}
