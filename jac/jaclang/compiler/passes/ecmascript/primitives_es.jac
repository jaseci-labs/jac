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
class ESEmitCtx {
    """ES emission context — carries the JS code generator."""
    has unparser: object;

    def init(self, unparser: object) {
        self.unparser = unparser;
    }
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

def _binop(left: str, op: str, right: str) -> str {
    """Emit (left op right) with parens for safety.""";
    return "(" + left + " " + op + " " + right + ")";
}

# =============================================================================
#  Numeric Types
# =============================================================================
class ESIntEmitter(IntEmitter[
    (str, ESEmitCtx)
]) {
    # --- Named methods ---
    def emit_bit_length(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("int", "bit_length", [target]);
    }

    def emit_bit_count(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("int", "bit_count", [target]);
    }

    def emit_to_bytes(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("int", "to_bytes", [target] + args);
    }

    def emit_as_integer_ratio(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return "[" + target + ", 1]";
    }

    def emit_conjugate(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return target;
    }

    def emit_from_bytes(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("int", "from_bytes", args);
    }

    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "+", args[0]);
    }

    def emit_op_sub(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "-", args[0]);
    }

    def emit_op_mul(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "*", args[0]);
    }

    def emit_op_truediv(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _binop(target, "/", args[0]);
    }

    def emit_op_floordiv(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return "Math.floor(" + target + " / " + args[0] + ")";
    }

    def emit_op_mod(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        # Python modulo semantics: result has same sign as divisor
        return _rt("int", "mod", [target, args[0]]);
    }

    def emit_op_pow(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "**", args[0]);
    }

    # --- Bitwise operators ---
    def emit_op_and(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "&", args[0]);
    }

    def emit_op_or(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "|", args[0]);
    }

    def emit_op_xor(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "^", args[0]);
    }

    def emit_op_lshift(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _binop(target, "<<", args[0]);
    }

    def emit_op_rshift(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _binop(target, ">>", args[0]);
    }

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "===", args[0]);
    }

    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "!==", args[0]);
    }

    def emit_op_lt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "<", args[0]);
    }

    def emit_op_gt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, ">", args[0]);
    }

    def emit_op_le(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "<=", args[0]);
    }

    def emit_op_ge(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, ">=", args[0]);
    }

    # --- Unary operators ---
    def emit_op_neg(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "(-" + target + ")";
    }

    def emit_op_pos(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "(+" + target + ")";
    }

    def emit_op_invert(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return "(~" + target + ")";
    }
}

class ESFloatEmitter(FloatEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_is_integer(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return "Number.isInteger(" + target + ")";
    }

    def emit_as_integer_ratio(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("float", "as_integer_ratio", [target]);
    }

    def emit_conjugate(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return target;
    }

    def emit_hex(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("float", "hex", [target]);
    }

    def emit_fromhex(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("float", "fromhex", args);
    }

    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "+", args[0]);
    }

    def emit_op_sub(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "-", args[0]);
    }

    def emit_op_mul(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "*", args[0]);
    }

    def emit_op_truediv(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _binop(target, "/", args[0]);
    }

    def emit_op_floordiv(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return "Math.floor(" + target + " / " + args[0] + ")";
    }

    def emit_op_mod(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        # Python modulo semantics: result has same sign as divisor
        return _rt("float", "mod", [target, args[0]]);
    }

    def emit_op_pow(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "**", args[0]);
    }

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "===", args[0]);
    }

    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "!==", args[0]);
    }

    def emit_op_lt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "<", args[0]);
    }

    def emit_op_gt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, ">", args[0]);
    }

    def emit_op_le(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "<=", args[0]);
    }

    def emit_op_ge(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, ">=", args[0]);
    }

    # --- Unary operators ---
    def emit_op_neg(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "(-" + target + ")";
    }

    def emit_op_pos(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "(+" + target + ")";
    }
}

class ESComplexEmitter(ComplexEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_conjugate(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("complex", "conjugate", [target]);
    }

    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("complex", "add", [target, args[0]]);
    }

    def emit_op_sub(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("complex", "sub", [target, args[0]]);
    }

    def emit_op_mul(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("complex", "mul", [target, args[0]]);
    }

    def emit_op_truediv(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("complex", "truediv", [target, args[0]]);
    }

    def emit_op_pow(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("complex", "pow", [target, args[0]]);
    }

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("complex", "eq", [target, args[0]]);
    }

    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "!" + _rt("complex", "eq", [target, args[0]]);
    }

    # --- Unary operators ---
    def emit_op_neg(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("complex", "neg", [target]);
    }

    def emit_op_pos(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("complex", "pos", [target]);
    }
}

class ESBoolEmitter(ESIntEmitter) {
    """Bool-specific emitter.

    Inherits all int operations but overrides bitwise operators so that
    ``True & False`` yields ``false`` (boolean) rather than ``0`` (number)
    in the JS output, matching Python semantics where bool & bool → bool.
    """
    # Override bitwise ops to return boolean
    def emit_op_and(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "Boolean(" + _binop(target, "&", args[0]) + ")";
    }

    def emit_op_or(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "Boolean(" + _binop(target, "|", args[0]) + ")";
    }

    def emit_op_xor(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "Boolean(" + _binop(target, "^", args[0]) + ")";
    }
}

# =============================================================================
#  String Types
# =============================================================================
class ESStrEmitter(StrEmitter[
    (str, ESEmitCtx)
]) {
    # Case conversion
    def emit_capitalize(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("str", "capitalize", [target]);
    }

    def emit_casefold(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "toLowerCase", []);
    }

    def emit_lower(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "toLowerCase", []);
    }

    def emit_upper(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "toUpperCase", []);
    }

    def emit_title(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("str", "title", [target]);
    }

    def emit_swapcase(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("str", "swapcase", [target]);
    }

    # Search
    def emit_count(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("str", "count", [target] + args);
    }

    def emit_find(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        if len(args) > 1 {
            return _rt("str", "find", [target] + args);
        }
        return _mcall(target, "indexOf", args);
    }

    def emit_rfind(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        if len(args) > 1 {
            return _rt("str", "rfind", [target] + args);
        }
        return _mcall(target, "lastIndexOf", args);
    }

    def emit_index(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("str", "index", [target] + args);
    }

    def emit_rindex(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("str", "rindex", [target] + args);
    }

    def emit_startswith(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        if len(args) == 1 {
            return _mcall(target, "startsWith", args);
        }
        return _rt("str", "startswith", [target] + args);
    }

    def emit_endswith(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        if len(args) == 1 {
            return _mcall(target, "endsWith", args);
        }
        return _rt("str", "endswith", [target] + args);
    }

    # Modification
    def emit_replace(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        if len(args) == 2 {
            return _mcall(target, "replaceAll", args);
        }
        return _rt("str", "replace", [target] + args);
    }

    def emit_strip(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return _mcall(target, "trim", []);
        }
        return _rt("str", "strip", [target] + args);
    }

    def emit_lstrip(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return _mcall(target, "trimStart", []);
        }
        return _rt("str", "lstrip", [target] + args);
    }

    def emit_rstrip(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return _mcall(target, "trimEnd", []);
        }
        return _rt("str", "rstrip", [target] + args);
    }

    def emit_removeprefix(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("str", "removeprefix", [target] + args);
    }

    def emit_removesuffix(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("str", "removesuffix", [target] + args);
    }

    # Split and join
    def emit_split(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return _rt("str", "split", [target]);
        }
        if len(args) == 1 {
            return _mcall(target, "split", args);
        }
        return _rt("str", "split", [target] + args);
    }

    def emit_rsplit(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("str", "rsplit", [target] + args);
    }

    def emit_splitlines(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        if len(args) == 0 {
            return _mcall(target, "split", ["/\\r?\\n/"]);
        }
        return _rt("str", "splitlines", [target] + args);
    }

    def emit_join(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        # Python: separator.join(iterable) → JS: array.join(separator)
        return _mcall(args[0], "join", [target]);
    }

    def emit_partition(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("str", "partition", [target] + args);
    }

    def emit_rpartition(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("str", "rpartition", [target] + args);
    }

    # Formatting and alignment
    def emit_format(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("str", "format", [target] + args);
    }

    def emit_format_map(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("str", "format_map", [target] + args);
    }

    def emit_center(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("str", "center", [target] + args);
    }

    def emit_ljust(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        if len(args) == 1 {
            return _mcall(target, "padEnd", args);
        }
        return _mcall(target, "padEnd", args);
    }

    def emit_rjust(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        if len(args) == 1 {
            return _mcall(target, "padStart", args);
        }
        return _mcall(target, "padStart", args);
    }

    def emit_zfill(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("str", "zfill", [target] + args);
    }

    def emit_expandtabs(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("str", "expandtabs", [target] + args);
    }

    # Character tests
    def emit_isalnum(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return "/^[a-zA-Z0-9]+$/.test(" + target + ")";
    }

    def emit_isalpha(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return "/^[a-zA-Z]+$/.test(" + target + ")";
    }

    def emit_isascii(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return "/^[\\x00-\\x7F]*$/.test(" + target + ")";
    }

    def emit_isdecimal(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return "/^[0-9]+$/.test(" + target + ")";
    }

    def emit_isdigit(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return "/^[0-9]+$/.test(" + target + ")";
    }

    def emit_isidentifier(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return "/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(" + target + ")";
    }

    def emit_islower(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return "(" + target + " === " + target + ".toLowerCase() && " + target + " !== " + target + ".toUpperCase())";
    }

    def emit_isnumeric(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("str", "isnumeric", [target]);
    }

    def emit_isprintable(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return "/^[\\x20-\\x7E]*$/.test(" + target + ")";
    }

    def emit_isspace(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return "/^\\s+$/.test(" + target + ")";
    }

    def emit_istitle(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("str", "istitle", [target]);
    }

    def emit_isupper(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return "(" + target + " === " + target + ".toUpperCase() && " + target + " !== " + target + ".toLowerCase())";
    }

    # Encoding
    def emit_encode(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "new TextEncoder().encode(" + target + ")";
    }

    # Translation
    def emit_translate(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("str", "translate", [target] + args);
    }

    def emit_maketrans(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("str", "maketrans", args);
    }

    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "+", args[0]);
    }

    def emit_op_mul(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "repeat", [args[0]]);
    }

    def emit_op_mod(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("str", "mod", [target, args[0]]);
    }

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "===", args[0]);
    }

    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "!==", args[0]);
    }

    def emit_op_lt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "<", args[0]);
    }

    def emit_op_gt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, ">", args[0]);
    }

    def emit_op_le(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, "<=", args[0]);
    }

    def emit_op_ge(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _binop(target, ">=", args[0]);
    }

    # --- Membership operators ---
    def emit_op_contains(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "includes", [args[0]]);
    }
}

class ESBytesEmitter(BytesEmitter[(str, ESEmitCtx)]) {
    # Decoding
    def emit_decode(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "new TextDecoder(" + (args[0] if len(args) > 0 else "") + ").decode(" + target + ")";
    }

    def emit_hex(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "hex", [target] + args);
    }

    def emit_fromhex(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("bytes", "fromhex", args);
    }

    # Search
    def emit_count(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "count", [target] + args);
    }

    def emit_find(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "find", [target] + args);
    }

    def emit_rfind(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "rfind", [target] + args);
    }

    def emit_index(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "index", [target] + args);
    }

    def emit_rindex(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "rindex", [target] + args);
    }

    def emit_startswith(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "startswith", [target] + args);
    }

    def emit_endswith(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "endswith", [target] + args);
    }
    # Modification
    def emit_replace(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "replace", [target] + args);
    }

    def emit_strip(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "strip", [target] + args);
    }

    def emit_lstrip(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "lstrip", [target] + args);
    }

    def emit_rstrip(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "rstrip", [target] + args);
    }

    def emit_removeprefix(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "removeprefix", [target] + args);
    }

    def emit_removesuffix(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "removesuffix", [target] + args);
    }
    # Split and join
    def emit_split(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "split", [target] + args);
    }

    def emit_rsplit(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "rsplit", [target] + args);
    }

    def emit_splitlines(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "splitlines", [target] + args);
    }

    def emit_join(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "join", [target] + args);
    }

    def emit_partition(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "partition", [target] + args);
    }

    def emit_rpartition(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "rpartition", [target] + args);
    }
    # Case (ASCII only)
    def emit_capitalize(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "capitalize", [target]);
    }

    def emit_lower(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "lower", [target]);
    }

    def emit_upper(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "upper", [target]);
    }

    def emit_title(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "title", [target]);
    }

    def emit_swapcase(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "swapcase", [target]);
    }
    # Character tests (ASCII only)
    def emit_isalnum(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "isalnum", [target]);
    }

    def emit_isalpha(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "isalpha", [target]);
    }

    def emit_isascii(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "isascii", [target]);
    }

    def emit_isdigit(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "isdigit", [target]);
    }

    def emit_islower(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "islower", [target]);
    }

    def emit_isspace(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "isspace", [target]);
    }

    def emit_istitle(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "istitle", [target]);
    }

    def emit_isupper(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "isupper", [target]);
    }
    # Alignment
    def emit_center(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "center", [target] + args);
    }

    def emit_ljust(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "ljust", [target] + args);
    }

    def emit_rjust(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "rjust", [target] + args);
    }

    def emit_zfill(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "zfill", [target] + args);
    }

    def emit_expandtabs(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "expandtabs", [target] + args);
    }
    # Translation
    def emit_translate(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "translate", [target] + args);
    }

    def emit_maketrans(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("bytes", "maketrans", args);
    }

    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "add", [target, args[0]]);
    }

    def emit_op_mul(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "mul", [target, args[0]]);
    }

    def emit_op_mod(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "mod", [target, args[0]]);
    }

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "eq", [target, args[0]]);
    }

    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "!" + _rt("bytes", "eq", [target, args[0]]);
    }

    def emit_op_lt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "lt", [target, args[0]]);
    }

    def emit_op_gt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "gt", [target, args[0]]);
    }

    def emit_op_le(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "le", [target, args[0]]);
    }

    def emit_op_ge(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("bytes", "ge", [target, args[0]]);
    }

    # --- Membership operators ---
    def emit_op_contains(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("bytes", "contains", [target, args[0]]);
    }
}

# =============================================================================
#  Collection Types
# =============================================================================
class ESListEmitter(ListEmitter[
    (str, ESEmitCtx)
]) {
    # --- Named methods ---
    def emit_append(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "push", args);
    }

    def emit_extend(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return target + ".push(..." + args[0] + ")";
    }

    def emit_insert(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "splice", [args[0], "0", args[1]]);
    }

    def emit_remove(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("list", "remove", [target] + args);
    }

    def emit_pop(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return _mcall(target, "pop", []);
        }
        return _mcall(target, "splice", [args[0], "1"]) + "[0]";
    }

    def emit_clear(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return target + ".length = 0";
    }

    def emit_index(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        if len(args) == 1 {
            return _mcall(target, "indexOf", args);
        }
        return _rt("list", "index", [target] + args);
    }

    def emit_count(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("list", "count", [target] + args);
    }

    def emit_sort(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return _mcall(target, "sort", []);
        }
        return _rt("list", "sort", [target] + args);
    }

    def emit_reverse(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "reverse", []);
    }

    def emit_copy(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "[..." + target + "]";
    }

    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "[..." + target + ", ..." + args[0] + "]";
    }

    def emit_op_mul(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("list", "repeat", [target, args[0]]);
    }

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("list", "eq", [target, args[0]]);
    }

    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "!" + _rt("list", "eq", [target, args[0]]);
    }

    def emit_op_lt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("list", "lt", [target, args[0]]);
    }

    def emit_op_gt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("list", "gt", [target, args[0]]);
    }

    def emit_op_le(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("list", "le", [target, args[0]]);
    }

    def emit_op_ge(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("list", "ge", [target, args[0]]);
    }

    # --- Membership operators ---
    def emit_op_contains(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "includes", [args[0]]);
    }

    # --- In-place operators ---
    def emit_op_iadd(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        # list += other is extend in-place (mutates), not concat+reassign
        return target + ".push(..." + args[0] + ")";
    }

    def emit_op_imul(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("list", "imul", [target, args[0]]);
    }
}

class ESDictEmitter(DictEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_get(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        if len(args) == 1 {
            return target + "[" + args[0] + "] ?? undefined";
        }
        return target + "[" + args[0] + "] ?? " + args[1];
    }

    def emit_keys(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "Object.keys(" + target + ")";
    }

    def emit_values(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "Object.values(" + target + ")";
    }

    def emit_items(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "Object.entries(" + target + ")";
    }

    def emit_pop(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("dict", "pop", [target] + args);
    }

    def emit_popitem(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("dict", "popitem", [target]);
    }

    def emit_setdefault(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("dict", "setdefault", [target] + args);
    }

    def emit_update(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "Object.assign(" + target + ", " + args[0] + ")";
    }

    def emit_clear(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("dict", "clear", [target]);
    }

    def emit_copy(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "{..." + target + "}";
    }

    def emit_fromkeys(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("dict", "fromkeys", args);
    }

    # --- Bitwise operators (dict merge) ---
    def emit_op_or(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "{..." + target + ", ..." + args[0] + "}";
    }

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("dict", "eq", [target, args[0]]);
    }

    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "!" + _rt("dict", "eq", [target, args[0]]);
    }

    # --- Membership operators ---
    def emit_op_contains(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _binop(args[0], "in", target);
    }

    # --- In-place operators ---
    def emit_op_ior(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "Object.assign(" + target + ", " + args[0] + ")";
    }
}

class ESSetEmitter(SetEmitter[(str, ESEmitCtx)]) {
    # --- Named methods (mutation) ---
    def emit_add(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "add", args);
    }

    def emit_remove(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("set", "remove", [target] + args);
    }

    def emit_discard(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "delete", args);
    }

    def emit_pop(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("set", "pop", [target]);
    }

    def emit_clear(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "clear", []);
    }

    # --- Named methods (set algebra) ---
    def emit_union(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "union", args);
    }

    def emit_intersection(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "intersection", args);
    }

    def emit_difference(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "difference", args);
    }

    def emit_symmetric_difference(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "symmetricDifference", args);
    }

    # --- Named methods (in-place set algebra) ---
    def emit_update(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("set", "update", [target] + args);
    }

    def emit_intersection_update(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("set", "intersection_update", [target] + args);
    }

    def emit_difference_update(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("set", "difference_update", [target] + args);
    }

    def emit_symmetric_difference_update(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("set", "symmetric_difference_update", [target] + args);
    }

    # --- Named methods (tests) ---
    def emit_issubset(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "isSubsetOf", args);
    }

    def emit_issuperset(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "isSupersetOf", args);
    }

    def emit_isdisjoint(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "isDisjointFrom", args);
    }

    def emit_copy(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "new Set(" + target + ")";
    }

    # --- Set algebra operators ---
    def emit_op_or(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "union", [args[0]]);
    }

    def emit_op_and(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "intersection", [args[0]]);
    }

    def emit_op_sub(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "difference", [args[0]]);
    }

    def emit_op_xor(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "symmetricDifference", [args[0]]);
    }

    # --- Comparison operators (subset/superset) ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("set", "eq", [target, args[0]]);
    }

    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "!" + _rt("set", "eq", [target, args[0]]);
    }

    def emit_op_le(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "isSubsetOf", [args[0]]);
    }

    def emit_op_lt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("set", "is_proper_subset", [target, args[0]]);
    }

    def emit_op_ge(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "isSupersetOf", [args[0]]);
    }

    def emit_op_gt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("set", "is_proper_superset", [target, args[0]]);
    }

    # --- Membership operators ---
    def emit_op_contains(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "has", [args[0]]);
    }

    # --- In-place operators ---
    def emit_op_ior(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("set", "update", [target, args[0]]);
    }

    def emit_op_iand(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("set", "intersection_update", [target, args[0]]);
    }

    def emit_op_isub(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("set", "difference_update", [target, args[0]]);
    }

    def emit_op_ixor(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("set", "symmetric_difference_update", [target, args[0]]);
    }
}

class ESFrozensetEmitter(FrozensetEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_union(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "union", args);
    }

    def emit_intersection(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "intersection", args);
    }

    def emit_difference(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "difference", args);
    }

    def emit_symmetric_difference(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "symmetricDifference", args);
    }

    def emit_issubset(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "isSubsetOf", args);
    }

    def emit_issuperset(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "isSupersetOf", args);
    }

    def emit_isdisjoint(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "isDisjointFrom", args);
    }

    def emit_copy(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "new Set(" + target + ")";
    }

    # --- Set algebra operators ---
    def emit_op_or(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "union", [args[0]]);
    }

    def emit_op_and(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "intersection", [args[0]]);
    }

    def emit_op_sub(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "difference", [args[0]]);
    }

    def emit_op_xor(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "symmetricDifference", [args[0]]);
    }

    # --- Comparison operators (subset/superset) ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("set", "eq", [target, args[0]]);
    }

    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "!" + _rt("set", "eq", [target, args[0]]);
    }

    def emit_op_le(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "isSubsetOf", [args[0]]);
    }

    def emit_op_lt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("set", "is_proper_subset", [target, args[0]]);
    }

    def emit_op_ge(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _mcall(target, "isSupersetOf", [args[0]]);
    }

    def emit_op_gt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("set", "is_proper_superset", [target, args[0]]);
    }

    # --- Membership operators ---
    def emit_op_contains(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "has", [args[0]]);
    }
}

class ESTupleEmitter(TupleEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_count(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("tuple", "count", [target] + args);
    }

    def emit_index(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        if len(args) == 1 {
            return _mcall(target, "indexOf", args);
        }
        return _rt("tuple", "index", [target] + args);
    }

    # --- Arithmetic operators ---
    def emit_op_add(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "[..." + target + ", ..." + args[0] + "]";
    }

    def emit_op_mul(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("tuple", "repeat", [target, args[0]]);
    }

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("tuple", "eq", [target, args[0]]);
    }

    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "!" + _rt("tuple", "eq", [target, args[0]]);
    }

    def emit_op_lt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("tuple", "lt", [target, args[0]]);
    }

    def emit_op_gt(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("tuple", "gt", [target, args[0]]);
    }

    def emit_op_le(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("tuple", "le", [target, args[0]]);
    }

    def emit_op_ge(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("tuple", "ge", [target, args[0]]);
    }

    # --- Membership operators ---
    def emit_op_contains(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _mcall(target, "includes", [args[0]]);
    }
}

class ESRangeEmitter(RangeEmitter[(str, ESEmitCtx)]) {
    # --- Named methods ---
    def emit_count(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("range", "count", [target] + args);
    }

    def emit_index(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("range", "index", [target] + args);
    }

    # --- Comparison operators ---
    def emit_op_eq(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return _rt("range", "eq", [target, args[0]]);
    }

    def emit_op_ne(self, ctx: ESEmitCtx, target: str, args: list[str]) -> (str | None) {
        return "!" + _rt("range", "eq", [target, args[0]]);
    }

    # --- Membership operators ---
    def emit_op_contains(
        self, ctx: ESEmitCtx, target: str, args: list[str]
    ) -> (str | None) {
        return _rt("range", "contains", [target, args[0]]);
    }
}

# =============================================================================
#  Builtin Functions
# =============================================================================
class ESBuiltinEmitter(BuiltinEmitter[
    (str, ESEmitCtx)
]) {
    def emit_print(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _fcall("console.log", args);
    }

    def emit_input(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _fcall("prompt", args);
    }

    def emit_len(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return args[0] + ".length";
    }

    def emit_abs(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return "Math.abs(" + args[0] + ")";
    }

    def emit_round(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        if len(args) == 1 {
            return "Math.round(" + args[0] + ")";
        }
        return _rt("builtin", "round", args);
    }

    def emit_min(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _fcall("Math.min", args);
    }

    def emit_max(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _fcall("Math.max", args);
    }

    def emit_sum(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("builtin", "sum", args);
    }

    def emit_sorted(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("builtin", "sorted", args);
    }

    def emit_reversed(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return "[..." + args[0] + "].reverse()";
    }

    def emit_enumerate(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("builtin", "enumerate", args);
    }

    def emit_zip(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("builtin", "zip", args);
    }

    def emit_map(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        if len(args) == 2 {
            return _mcall(args[1], "map", [args[0]]);
        }
        return _rt("builtin", "map", args);
    }

    def emit_filter(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        if len(args) == 2 {
            return _mcall(args[1], "filter", [args[0]]);
        }
        return _rt("builtin", "filter", args);
    }

    def emit_any(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _mcall(args[0], "some", ["Boolean"]);
    }

    def emit_all(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _mcall(args[0], "every", ["Boolean"]);
    }

    def emit_isinstance(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return args[0] + " instanceof " + args[1];
    }

    def emit_issubclass(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("builtin", "issubclass", args);
    }

    def emit_type(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return "typeof " + args[0];
    }

    def emit_id(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("builtin", "id", args);
    }

    def emit_hash(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("builtin", "hash", args);
    }

    def emit_repr(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("builtin", "repr", args);
    }

    def emit_chr(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return "String.fromCodePoint(" + args[0] + ")";
    }

    def emit_ord(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return args[0] + ".codePointAt(0)";
    }

    def emit_hex(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return "'0x' + (" + args[0] + ").toString(16)";
    }

    def emit_oct(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return "'0o' + (" + args[0] + ").toString(8)";
    }

    def emit_bin(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return "'0b' + (" + args[0] + ").toString(2)";
    }

    def emit_pow(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        if len(args) == 2 {
            return args[0] + " ** " + args[1];
        }
        return _rt("builtin", "pow", args);
    }

    def emit_divmod(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return "[Math.floor(" + args[0] + " / " + args[1] + "), " + args[0] + " % " + args[
            1
        ] + "]";
    }

    def emit_iter(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return args[0] + "[Symbol.iterator]()";
    }

    def emit_next(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("builtin", "next", args);
    }

    def emit_callable(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return "typeof " + args[0] + " === 'function'";
    }

    def emit_getattr(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        if len(args) == 2 {
            return args[0] + "[" + args[1] + "]";
        }
        return args[0] + "[" + args[1] + "] ?? " + args[2];
    }

    def emit_setattr(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return args[0] + "[" + args[1] + "] = " + args[2];
    }

    def emit_hasattr(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return args[1] + " in " + args[0];
    }

    def emit_delattr(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return "delete " + args[0] + "[" + args[1] + "]";
    }

    def emit_vars(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("builtin", "vars", args);
    }

    def emit_dir(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return _rt("builtin", "dir", []);
        }
        return "Object.getOwnPropertyNames(" + args[0] + ")";
    }

    def emit_open(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("builtin", "open", args);
    }

    def emit_format(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("builtin", "format", args);
    }

    def emit_ascii(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("builtin", "ascii", args);
    }

    # Type conversion builtins
    def emit_str(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return '""';
        }
        return "String(" + args[0] + ")";
    }

    def emit_int(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return "0";
        }
        if len(args) == 1 {
            # Use Math.trunc(Number(x)) instead of parseInt(x) to correctly
            # handle booleans (parseInt(false) → NaN, Number(false) → 0)
            # and floats (int(3.14) → 3).
            return "Math.trunc(Number(" + args[0] + "))";
        }
        return "parseInt(" + args[0] + ", " + args[1] + ")";
    }

    def emit_float(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return "0.0";
        }
        return "parseFloat(" + args[0] + ")";
    }

    def emit_bool(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return "false";
        }
        # Use runtime helper for Python truthiness semantics:
        # Python: bool([]) → False, bool({}) → False, bool(set()) → False
        # JS:     Boolean([]) → true,  Boolean({}) → true
        return _rt("builtin", "bool", args);
    }

    def emit_list(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return "[]";
        }
        return "Array.from(" + args[0] + ")";
    }

    def emit_dict(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return "{}";
        }
        return "Object.fromEntries(" + args[0] + ")";
    }

    def emit_set(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return "new Set()";
        }
        return "new Set(" + args[0] + ")";
    }

    def emit_tuple(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return "Object.freeze([])";
        }
        return "Object.freeze(Array.from(" + args[0] + "))";
    }

    def emit_frozenset(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return "Object.freeze(new Set())";
        }
        return "Object.freeze(new Set(" + args[0] + "))";
    }

    def emit_bytes(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return "new Uint8Array()";
        }
        return "new Uint8Array(" + args[0] + ")";
    }

    def emit_complex(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("builtin", "complex", args);
    }

    def emit_range(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("builtin", "range", args);
    }

    def emit_slice(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        return _rt("builtin", "slice", args);
    }

    def emit_bytearray(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
        if len(args) == 0 {
            return "new Uint8Array()";
        }
        return "new Uint8Array(" + args[0] + ")";
    }
}
