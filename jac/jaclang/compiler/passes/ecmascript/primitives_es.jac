"""ECMAScript backend primitive emitter implementations.

Maps Jac primitive methods to their JavaScript equivalents. Where no direct
JS equivalent exists, calls are emitted to the Jac JS runtime library
(_jac.str.partition, _jac.list.remove, etc.).
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

# =============================================================================
#  Numeric Types
# =============================================================================
class ESIntEmitter(IntEmitter) {
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
        return "[" + target + ", 1]";
    }

    def emit_conjugate(target: str, args: list[str]) -> str {
        return target;
    }

    def emit_from_bytes(args: list[str]) -> str {
        return _rt("int", "from_bytes", args);
    }
}

class ESFloatEmitter(FloatEmitter) {
    def emit_is_integer(target: str, args: list[str]) -> str {
        return "Number.isInteger(" + target + ")";
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

class ESComplexEmitter(ComplexEmitter) {
    def emit_conjugate(target: str, args: list[str]) -> str {
        return _rt("complex", "conjugate", [target]);
    }
}

# =============================================================================
#  String Types
# =============================================================================
class ESStrEmitter(StrEmitter) {
    # Case conversion
    def emit_capitalize(target: str, args: list[str]) -> str {
        return _rt("str", "capitalize", [target]);
    }

    def emit_casefold(target: str, args: list[str]) -> str {
        return _mcall(target, "toLowerCase", []);
    }

    def emit_lower(target: str, args: list[str]) -> str {
        return _mcall(target, "toLowerCase", []);
    }

    def emit_upper(target: str, args: list[str]) -> str {
        return _mcall(target, "toUpperCase", []);
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
        if len(args) > 1 {
            return _rt("str", "find", [target] + args);
        }
        return _mcall(target, "indexOf", args);
    }

    def emit_rfind(target: str, args: list[str]) -> str {
        if len(args) > 1 {
            return _rt("str", "rfind", [target] + args);
        }
        return _mcall(target, "lastIndexOf", args);
    }

    def emit_index(target: str, args: list[str]) -> str {
        return _rt("str", "index", [target] + args);
    }

    def emit_rindex(target: str, args: list[str]) -> str {
        return _rt("str", "rindex", [target] + args);
    }

    def emit_startswith(target: str, args: list[str]) -> str {
        if len(args) == 1 {
            return _mcall(target, "startsWith", args);
        }
        return _rt("str", "startswith", [target] + args);
    }

    def emit_endswith(target: str, args: list[str]) -> str {
        if len(args) == 1 {
            return _mcall(target, "endsWith", args);
        }
        return _rt("str", "endswith", [target] + args);
    }

    # Modification
    def emit_replace(target: str, args: list[str]) -> str {
        if len(args) == 2 {
            return _mcall(target, "replaceAll", args);
        }
        return _rt("str", "replace", [target] + args);
    }

    def emit_strip(target: str, args: list[str]) -> str {
        if len(args) == 0 {
            return _mcall(target, "trim", []);
        }
        return _rt("str", "strip", [target] + args);
    }

    def emit_lstrip(target: str, args: list[str]) -> str {
        if len(args) == 0 {
            return _mcall(target, "trimStart", []);
        }
        return _rt("str", "lstrip", [target] + args);
    }

    def emit_rstrip(target: str, args: list[str]) -> str {
        if len(args) == 0 {
            return _mcall(target, "trimEnd", []);
        }
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
        if len(args) == 0 {
            return _rt("str", "split", [target]);
        }
        if len(args) == 1 {
            return _mcall(target, "split", args);
        }
        return _rt("str", "split", [target] + args);
    }

    def emit_rsplit(target: str, args: list[str]) -> str {
        return _rt("str", "rsplit", [target] + args);
    }

    def emit_splitlines(target: str, args: list[str]) -> str {
        if len(args) == 0 {
            return _mcall(target, "split", ["/\\r?\\n/"]);
        }
        return _rt("str", "splitlines", [target] + args);
    }

    def emit_join(target: str, args: list[str]) -> str {
        # Python: separator.join(iterable) → JS: array.join(separator)
        return _mcall(args[0], "join", [target]);
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
        if len(args) == 1 {
            return _mcall(target, "padEnd", args);
        }
        return _mcall(target, "padEnd", args);
    }

    def emit_rjust(target: str, args: list[str]) -> str {
        if len(args) == 1 {
            return _mcall(target, "padStart", args);
        }
        return _mcall(target, "padStart", args);
    }

    def emit_zfill(target: str, args: list[str]) -> str {
        return _rt("str", "zfill", [target] + args);
    }

    def emit_expandtabs(target: str, args: list[str]) -> str {
        return _rt("str", "expandtabs", [target] + args);
    }

    # Character tests
    def emit_isalnum(target: str, args: list[str]) -> str {
        return "/^[a-zA-Z0-9]+$/.test(" + target + ")";
    }

    def emit_isalpha(target: str, args: list[str]) -> str {
        return "/^[a-zA-Z]+$/.test(" + target + ")";
    }

    def emit_isascii(target: str, args: list[str]) -> str {
        return "/^[\\x00-\\x7F]*$/.test(" + target + ")";
    }

    def emit_isdecimal(target: str, args: list[str]) -> str {
        return "/^[0-9]+$/.test(" + target + ")";
    }

    def emit_isdigit(target: str, args: list[str]) -> str {
        return "/^[0-9]+$/.test(" + target + ")";
    }

    def emit_isidentifier(target: str, args: list[str]) -> str {
        return "/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(" + target + ")";
    }

    def emit_islower(target: str, args: list[str]) -> str {
        return "(" + target + " === " + target + ".toLowerCase() && " + target + " !== " + target + ".toUpperCase())";
    }

    def emit_isnumeric(target: str, args: list[str]) -> str {
        return _rt("str", "isnumeric", [target]);
    }

    def emit_isprintable(target: str, args: list[str]) -> str {
        return "/^[\\x20-\\x7E]*$/.test(" + target + ")";
    }

    def emit_isspace(target: str, args: list[str]) -> str {
        return "/^\\s+$/.test(" + target + ")";
    }

    def emit_istitle(target: str, args: list[str]) -> str {
        return _rt("str", "istitle", [target]);
    }

    def emit_isupper(target: str, args: list[str]) -> str {
        return "(" + target + " === " + target + ".toUpperCase() && " + target + " !== " + target + ".toLowerCase())";
    }

    # Encoding
    def emit_encode(target: str, args: list[str]) -> str {
        return "new TextEncoder().encode(" + target + ")";
    }

    # Translation
    def emit_translate(target: str, args: list[str]) -> str {
        return _rt("str", "translate", [target] + args);
    }

    def emit_maketrans(args: list[str]) -> str {
        return _rt("str", "maketrans", args);
    }
}

class ESBytesEmitter(BytesEmitter) {
    # Decoding
    def emit_decode(target: str, args: list[str]) -> str {
        return "new TextDecoder(" + (args[0] if len(args) > 0 else "") + ").decode(" + target + ")";
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
class ESListEmitter(ListEmitter) {
    def emit_append(target: str, args: list[str]) -> str {
        return _mcall(target, "push", args);
    }

    def emit_extend(target: str, args: list[str]) -> str {
        return target + ".push(..." + args[0] + ")";
    }

    def emit_insert(target: str, args: list[str]) -> str {
        return _mcall(target, "splice", [args[0], "0", args[1]]);
    }

    def emit_remove(target: str, args: list[str]) -> str {
        return _rt("list", "remove", [target] + args);
    }

    def emit_pop(target: str, args: list[str]) -> str {
        if len(args) == 0 {
            return _mcall(target, "pop", []);
        }
        return _mcall(target, "splice", [args[0], "1"]) + "[0]";
    }

    def emit_clear(target: str, args: list[str]) -> str {
        return target + ".length = 0";
    }

    def emit_index(target: str, args: list[str]) -> str {
        if len(args) == 1 {
            return _mcall(target, "indexOf", args);
        }
        return _rt("list", "index", [target] + args);
    }

    def emit_count(target: str, args: list[str]) -> str {
        return _rt("list", "count", [target] + args);
    }

    def emit_sort(target: str, args: list[str]) -> str {
        if len(args) == 0 {
            return _mcall(target, "sort", []);
        }
        return _rt("list", "sort", [target] + args);
    }

    def emit_reverse(target: str, args: list[str]) -> str {
        return _mcall(target, "reverse", []);
    }

    def emit_copy(target: str, args: list[str]) -> str {
        return "[..." + target + "]";
    }
}

class ESDictEmitter(DictEmitter) {
    def emit_get(target: str, args: list[str]) -> str {
        if len(args) == 1 {
            return target + "[" + args[0] + "] ?? undefined";
        }
        return target + "[" + args[0] + "] ?? " + args[1];
    }

    def emit_keys(target: str, args: list[str]) -> str {
        return "Object.keys(" + target + ")";
    }

    def emit_values(target: str, args: list[str]) -> str {
        return "Object.values(" + target + ")";
    }

    def emit_items(target: str, args: list[str]) -> str {
        return "Object.entries(" + target + ")";
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
        return "Object.assign(" + target + ", " + args[0] + ")";
    }

    def emit_clear(target: str, args: list[str]) -> str {
        return _rt("dict", "clear", [target]);
    }

    def emit_copy(target: str, args: list[str]) -> str {
        return "{..." + target + "}";
    }

    def emit_fromkeys(args: list[str]) -> str {
        return _rt("dict", "fromkeys", args);
    }
}

class ESSetEmitter(SetEmitter) {
    # Mutation
    def emit_add(target: str, args: list[str]) -> str {
        return _mcall(target, "add", args);
    }

    def emit_remove(target: str, args: list[str]) -> str {
        return _rt("set", "remove", [target] + args);
    }

    def emit_discard(target: str, args: list[str]) -> str {
        return _mcall(target, "delete", args);
    }

    def emit_pop(target: str, args: list[str]) -> str {
        return _rt("set", "pop", [target]);
    }

    def emit_clear(target: str, args: list[str]) -> str {
        return _mcall(target, "clear", []);
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
        return _mcall(target, "symmetricDifference", args);
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
        return _mcall(target, "isSubsetOf", args);
    }

    def emit_issuperset(target: str, args: list[str]) -> str {
        return _mcall(target, "isSupersetOf", args);
    }

    def emit_isdisjoint(target: str, args: list[str]) -> str {
        return _mcall(target, "isDisjointFrom", args);
    }

    def emit_copy(target: str, args: list[str]) -> str {
        return "new Set(" + target + ")";
    }
}

class ESFrozensetEmitter(FrozensetEmitter) {
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
        return _mcall(target, "symmetricDifference", args);
    }

    def emit_issubset(target: str, args: list[str]) -> str {
        return _mcall(target, "isSubsetOf", args);
    }

    def emit_issuperset(target: str, args: list[str]) -> str {
        return _mcall(target, "isSupersetOf", args);
    }

    def emit_isdisjoint(target: str, args: list[str]) -> str {
        return _mcall(target, "isDisjointFrom", args);
    }

    def emit_copy(target: str, args: list[str]) -> str {
        return "new Set(" + target + ")";
    }
}

class ESTupleEmitter(TupleEmitter) {
    # JS arrays used as tuples
    def emit_count(target: str, args: list[str]) -> str {
        return _rt("tuple", "count", [target] + args);
    }

    def emit_index(target: str, args: list[str]) -> str {
        if len(args) == 1 {
            return _mcall(target, "indexOf", args);
        }
        return _rt("tuple", "index", [target] + args);
    }
}

class ESRangeEmitter(RangeEmitter) {
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
class ESBuiltinEmitter(BuiltinEmitter) {
    def emit_print(args: list[str]) -> str {
        return _fcall("console.log", args);
    }

    def emit_input(args: list[str]) -> str {
        return _fcall("prompt", args);
    }

    def emit_len(args: list[str]) -> str {
        return args[0] + ".length";
    }

    def emit_abs(args: list[str]) -> str {
        return "Math.abs(" + args[0] + ")";
    }

    def emit_round(args: list[str]) -> str {
        if len(args) == 1 {
            return "Math.round(" + args[0] + ")";
        }
        return _rt("builtin", "round", args);
    }

    def emit_min(args: list[str]) -> str {
        return _fcall("Math.min", args);
    }

    def emit_max(args: list[str]) -> str {
        return _fcall("Math.max", args);
    }

    def emit_sum(args: list[str]) -> str {
        return _rt("builtin", "sum", args);
    }

    def emit_sorted(args: list[str]) -> str {
        return _rt("builtin", "sorted", args);
    }

    def emit_reversed(args: list[str]) -> str {
        return "[..." + args[0] + "].reverse()";
    }

    def emit_enumerate(args: list[str]) -> str {
        return _rt("builtin", "enumerate", args);
    }

    def emit_zip(args: list[str]) -> str {
        return _rt("builtin", "zip", args);
    }

    def emit_map(args: list[str]) -> str {
        if len(args) == 2 {
            return _mcall(args[1], "map", [args[0]]);
        }
        return _rt("builtin", "map", args);
    }

    def emit_filter(args: list[str]) -> str {
        if len(args) == 2 {
            return _mcall(args[1], "filter", [args[0]]);
        }
        return _rt("builtin", "filter", args);
    }

    def emit_any(args: list[str]) -> str {
        return _mcall(args[0], "some", ["Boolean"]);
    }

    def emit_all(args: list[str]) -> str {
        return _mcall(args[0], "every", ["Boolean"]);
    }

    def emit_isinstance(args: list[str]) -> str {
        return args[0] + " instanceof " + args[1];
    }

    def emit_issubclass(args: list[str]) -> str {
        return _rt("builtin", "issubclass", args);
    }

    def emit_type(args: list[str]) -> str {
        return "typeof " + args[0];
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
        return "String.fromCodePoint(" + args[0] + ")";
    }

    def emit_ord(args: list[str]) -> str {
        return args[0] + ".codePointAt(0)";
    }

    def emit_hex(args: list[str]) -> str {
        return "'0x' + " + args[0] + ".toString(16)";
    }

    def emit_oct(args: list[str]) -> str {
        return "'0o' + " + args[0] + ".toString(8)";
    }

    def emit_bin(args: list[str]) -> str {
        return "'0b' + " + args[0] + ".toString(2)";
    }

    def emit_pow(args: list[str]) -> str {
        if len(args) == 2 {
            return args[0] + " ** " + args[1];
        }
        return _rt("builtin", "pow", args);
    }

    def emit_divmod(args: list[str]) -> str {
        return "[Math.floor(" + args[0] + " / " + args[1] + "), " + args[0] + " % " + args[
            1
        ] + "]";
    }

    def emit_iter(args: list[str]) -> str {
        return args[0] + "[Symbol.iterator]()";
    }

    def emit_next(args: list[str]) -> str {
        return _rt("builtin", "next", args);
    }

    def emit_callable(args: list[str]) -> str {
        return "typeof " + args[0] + " === 'function'";
    }

    def emit_getattr(args: list[str]) -> str {
        if len(args) == 2 {
            return args[0] + "[" + args[1] + "]";
        }
        return args[0] + "[" + args[1] + "] ?? " + args[2];
    }

    def emit_setattr(args: list[str]) -> str {
        return args[0] + "[" + args[1] + "] = " + args[2];
    }

    def emit_hasattr(args: list[str]) -> str {
        return args[1] + " in " + args[0];
    }

    def emit_delattr(args: list[str]) -> str {
        return "delete " + args[0] + "[" + args[1] + "]";
    }

    def emit_vars(args: list[str]) -> str {
        return _rt("builtin", "vars", args);
    }

    def emit_dir(args: list[str]) -> str {
        if len(args) == 0 {
            return _rt("builtin", "dir", []);
        }
        return "Object.getOwnPropertyNames(" + args[0] + ")";
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
        if len(args) == 0 {
            return '""';
        }
        return "String(" + args[0] + ")";
    }

    def emit_int(args: list[str]) -> str {
        if len(args) == 0 {
            return "0";
        }
        if len(args) == 1 {
            return "parseInt(" + args[0] + ")";
        }
        return "parseInt(" + args[0] + ", " + args[1] + ")";
    }

    def emit_float(args: list[str]) -> str {
        if len(args) == 0 {
            return "0.0";
        }
        return "parseFloat(" + args[0] + ")";
    }

    def emit_bool(args: list[str]) -> str {
        if len(args) == 0 {
            return "false";
        }
        return "Boolean(" + args[0] + ")";
    }

    def emit_list(args: list[str]) -> str {
        if len(args) == 0 {
            return "[]";
        }
        return "Array.from(" + args[0] + ")";
    }

    def emit_dict(args: list[str]) -> str {
        if len(args) == 0 {
            return "{}";
        }
        return "Object.fromEntries(" + args[0] + ")";
    }

    def emit_set(args: list[str]) -> str {
        if len(args) == 0 {
            return "new Set()";
        }
        return "new Set(" + args[0] + ")";
    }

    def emit_tuple(args: list[str]) -> str {
        if len(args) == 0 {
            return "Object.freeze([])";
        }
        return "Object.freeze(Array.from(" + args[0] + "))";
    }

    def emit_frozenset(args: list[str]) -> str {
        if len(args) == 0 {
            return "Object.freeze(new Set())";
        }
        return "Object.freeze(new Set(" + args[0] + "))";
    }

    def emit_bytes(args: list[str]) -> str {
        if len(args) == 0 {
            return "new Uint8Array()";
        }
        return "new Uint8Array(" + args[0] + ")";
    }

    def emit_complex(args: list[str]) -> str {
        return _rt("builtin", "complex", args);
    }
}
