"""Implementation of ECMAScript primitive emitters."""

# --- Named methods ---
impl ESIntEmitter.emit_bit_length(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("int", "bit_length", [target]);
}

impl ESIntEmitter.emit_bit_count(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("int", "bit_count", [target]);
}

impl ESIntEmitter.emit_to_bytes(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("int", "to_bytes", [target] + args);
}

impl ESIntEmitter.emit_as_integer_ratio(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "[" + target + ", 1]";
}

impl ESIntEmitter.emit_conjugate(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return target;
}

impl ESIntEmitter.emit_from_bytes(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("int", "from_bytes", args);
}

# --- Arithmetic operators ---
impl ESIntEmitter.emit_op_add(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "+", args[0]);
}

impl ESIntEmitter.emit_op_sub(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "-", args[0]);
}

impl ESIntEmitter.emit_op_mul(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "*", args[0]);
}

impl ESIntEmitter.emit_op_truediv(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "/", args[0]);
}

impl ESIntEmitter.emit_op_floordiv(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Math.floor(" + target + " / " + args[0] + ")";
}

impl ESIntEmitter.emit_op_mod(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    # Python modulo semantics: result has same sign as divisor
    return _rt("int", "mod", [target, args[0]]);
}

impl ESIntEmitter.emit_op_pow(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "**", args[0]);
}

# --- Bitwise operators ---
impl ESIntEmitter.emit_op_and(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "&", args[0]);
}

impl ESIntEmitter.emit_op_or(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "|", args[0]);
}

impl ESIntEmitter.emit_op_xor(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "^", args[0]);
}

impl ESIntEmitter.emit_op_lshift(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<<", args[0]);
}

impl ESIntEmitter.emit_op_rshift(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">>", args[0]);
}

# --- Comparison operators ---
impl ESIntEmitter.emit_op_eq(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "===", args[0]);
}

impl ESIntEmitter.emit_op_ne(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "!==", args[0]);
}

impl ESIntEmitter.emit_op_lt(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<", args[0]);
}

impl ESIntEmitter.emit_op_gt(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">", args[0]);
}

impl ESIntEmitter.emit_op_le(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<=", args[0]);
}

impl ESIntEmitter.emit_op_ge(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">=", args[0]);
}

# --- Unary operators ---
impl ESIntEmitter.emit_op_neg(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "(-" + target + ")";
}

impl ESIntEmitter.emit_op_pos(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "(+" + target + ")";
}

impl ESIntEmitter.emit_op_invert(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "(~" + target + ")";
}

# --- Named methods ---
impl ESFloatEmitter.emit_is_integer(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Number.isInteger(" + target + ")";
}

impl ESFloatEmitter.emit_as_integer_ratio(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("float", "as_integer_ratio", [target]);
}

impl ESFloatEmitter.emit_conjugate(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return target;
}

impl ESFloatEmitter.emit_hex(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("float", "hex", [target]);
}

impl ESFloatEmitter.emit_fromhex(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("float", "fromhex", args);
}

# --- Arithmetic operators ---
impl ESFloatEmitter.emit_op_add(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "+", args[0]);
}

impl ESFloatEmitter.emit_op_sub(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "-", args[0]);
}

impl ESFloatEmitter.emit_op_mul(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "*", args[0]);
}

impl ESFloatEmitter.emit_op_truediv(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "/", args[0]);
}

impl ESFloatEmitter.emit_op_floordiv(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Math.floor(" + target + " / " + args[0] + ")";
}

impl ESFloatEmitter.emit_op_mod(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    # Python modulo semantics: result has same sign as divisor
    return _rt("float", "mod", [target, args[0]]);
}

impl ESFloatEmitter.emit_op_pow(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "**", args[0]);
}

# --- Comparison operators ---
impl ESFloatEmitter.emit_op_eq(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "===", args[0]);
}

impl ESFloatEmitter.emit_op_ne(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "!==", args[0]);
}

impl ESFloatEmitter.emit_op_lt(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<", args[0]);
}

impl ESFloatEmitter.emit_op_gt(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">", args[0]);
}

impl ESFloatEmitter.emit_op_le(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<=", args[0]);
}

impl ESFloatEmitter.emit_op_ge(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">=", args[0]);
}

# --- Unary operators ---
impl ESFloatEmitter.emit_op_neg(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "(-" + target + ")";
}

impl ESFloatEmitter.emit_op_pos(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "(+" + target + ")";
}

# --- Named methods ---
impl ESComplexEmitter.emit_conjugate(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "conjugate", [target]);
}

# --- Arithmetic operators ---
impl ESComplexEmitter.emit_op_add(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "add", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_sub(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "sub", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_mul(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "mul", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_truediv(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "truediv", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_pow(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "pow", [target, args[0]]);
}

# --- Comparison operators ---
impl ESComplexEmitter.emit_op_eq(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "eq", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_ne(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("complex", "eq", [target, args[0]]);
}

# --- Unary operators ---
impl ESComplexEmitter.emit_op_neg(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "neg", [target]);
}

impl ESComplexEmitter.emit_op_pos(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "pos", [target]);
}

# Override bitwise ops to return boolean
impl ESBoolEmitter.emit_op_and(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Boolean(" + _binop(target, "&", args[0]) + ")";
}

impl ESBoolEmitter.emit_op_or(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Boolean(" + _binop(target, "|", args[0]) + ")";
}

impl ESBoolEmitter.emit_op_xor(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Boolean(" + _binop(target, "^", args[0]) + ")";
}

# Case conversion
impl ESStrEmitter.emit_capitalize(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "capitalize", [target]);
}

impl ESStrEmitter.emit_casefold(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "toLowerCase", []);
}

impl ESStrEmitter.emit_lower(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "toLowerCase", []);
}

impl ESStrEmitter.emit_upper(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "toUpperCase", []);
}

impl ESStrEmitter.emit_title(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "title", [target]);
}

impl ESStrEmitter.emit_swapcase(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "swapcase", [target]);
}

# Search
impl ESStrEmitter.emit_count(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "count", [target] + args);
}

impl ESStrEmitter.emit_find(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) > 1 {
        return _rt("str", "find", [target] + args);
    }
    return _mcall(target, "indexOf", args);
}

impl ESStrEmitter.emit_rfind(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) > 1 {
        return _rt("str", "rfind", [target] + args);
    }
    return _mcall(target, "lastIndexOf", args);
}

impl ESStrEmitter.emit_index(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "index", [target] + args);
}

impl ESStrEmitter.emit_rindex(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "rindex", [target] + args);
}

impl ESStrEmitter.emit_startswith(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 1 {
        return _mcall(target, "startsWith", args);
    }
    return _rt("str", "startswith", [target] + args);
}

impl ESStrEmitter.emit_endswith(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 1 {
        return _mcall(target, "endsWith", args);
    }
    return _rt("str", "endswith", [target] + args);
}

# Modification
impl ESStrEmitter.emit_replace(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 2 {
        return _mcall(target, "replaceAll", args);
    }
    return _rt("str", "replace", [target] + args);
}

impl ESStrEmitter.emit_strip(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "trim", []);
    }
    return _rt("str", "strip", [target] + args);
}

impl ESStrEmitter.emit_lstrip(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "trimStart", []);
    }
    return _rt("str", "lstrip", [target] + args);
}

impl ESStrEmitter.emit_rstrip(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "trimEnd", []);
    }
    return _rt("str", "rstrip", [target] + args);
}

impl ESStrEmitter.emit_removeprefix(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "removeprefix", [target] + args);
}

impl ESStrEmitter.emit_removesuffix(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "removesuffix", [target] + args);
}

# Split and join
impl ESStrEmitter.emit_split(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _rt("str", "split", [target]);
    }
    if len(args) == 1 {
        return _mcall(target, "split", args);
    }
    return _rt("str", "split", [target] + args);
}

impl ESStrEmitter.emit_rsplit(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "rsplit", [target] + args);
}

impl ESStrEmitter.emit_splitlines(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "split", ["/\\r?\\n/"]);
    }
    return _rt("str", "splitlines", [target] + args);
}

impl ESStrEmitter.emit_join(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    # Python: separator.join(iterable) → JS: array.join(separator)
    return _mcall(args[0], "join", [target]);
}

impl ESStrEmitter.emit_partition(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "partition", [target] + args);
}

impl ESStrEmitter.emit_rpartition(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "rpartition", [target] + args);
}

# Formatting and alignment
impl ESStrEmitter.emit_format(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "format", [target] + args);
}

impl ESStrEmitter.emit_format_map(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "format_map", [target] + args);
}

impl ESStrEmitter.emit_center(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "center", [target] + args);
}

impl ESStrEmitter.emit_ljust(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 1 {
        return _mcall(target, "padEnd", args);
    }
    return _mcall(target, "padEnd", args);
}

impl ESStrEmitter.emit_rjust(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 1 {
        return _mcall(target, "padStart", args);
    }
    return _mcall(target, "padStart", args);
}

impl ESStrEmitter.emit_zfill(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "zfill", [target] + args);
}

impl ESStrEmitter.emit_expandtabs(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "expandtabs", [target] + args);
}

# Character tests
impl ESStrEmitter.emit_isalnum(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[a-zA-Z0-9]+$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isalpha(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[a-zA-Z]+$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isascii(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[\\x00-\\x7F]*$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isdecimal(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[0-9]+$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isdigit(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[0-9]+$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isidentifier(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(" + target + ")";
}

impl ESStrEmitter.emit_islower(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "(" + target + " === " + target + ".toLowerCase() && " + target + " !== " + target + ".toUpperCase())";
}

impl ESStrEmitter.emit_isnumeric(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "isnumeric", [target]);
}

impl ESStrEmitter.emit_isprintable(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[\\x20-\\x7E]*$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isspace(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^\\s+$/.test(" + target + ")";
}

impl ESStrEmitter.emit_istitle(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "istitle", [target]);
}

impl ESStrEmitter.emit_isupper(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "(" + target + " === " + target + ".toUpperCase() && " + target + " !== " + target + ".toLowerCase())";
}

# Encoding
impl ESStrEmitter.emit_encode(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "new TextEncoder().encode(" + target + ")";
}

# Translation
impl ESStrEmitter.emit_translate(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "translate", [target] + args);
}

impl ESStrEmitter.emit_maketrans(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("str", "maketrans", args);
}

# --- Arithmetic operators ---
impl ESStrEmitter.emit_op_add(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "+", args[0]);
}

impl ESStrEmitter.emit_op_mul(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "repeat", [args[0]]);
}

impl ESStrEmitter.emit_op_mod(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "mod", [target, args[0]]);
}

# --- Comparison operators ---
impl ESStrEmitter.emit_op_eq(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "===", args[0]);
}

impl ESStrEmitter.emit_op_ne(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "!==", args[0]);
}

impl ESStrEmitter.emit_op_lt(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<", args[0]);
}

impl ESStrEmitter.emit_op_gt(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">", args[0]);
}

impl ESStrEmitter.emit_op_le(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<=", args[0]);
}

impl ESStrEmitter.emit_op_ge(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">=", args[0]);
}

# --- Membership operators ---
impl ESStrEmitter.emit_op_contains(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "includes", [args[0]]);
}

# Decoding
impl ESBytesEmitter.emit_decode(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "new TextDecoder(" + (args[0] if len(args) > 0 else "") + ").decode(" + target + ")";
}

impl ESBytesEmitter.emit_hex(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "hex", [target] + args);
}

impl ESBytesEmitter.emit_fromhex(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("bytes", "fromhex", args);
}

# Search
impl ESBytesEmitter.emit_count(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "count", [target] + args);
}

impl ESBytesEmitter.emit_find(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "find", [target] + args);
}

impl ESBytesEmitter.emit_rfind(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rfind", [target] + args);
}

impl ESBytesEmitter.emit_index(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "index", [target] + args);
}

impl ESBytesEmitter.emit_rindex(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rindex", [target] + args);
}

impl ESBytesEmitter.emit_startswith(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "startswith", [target] + args);
}

impl ESBytesEmitter.emit_endswith(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "endswith", [target] + args);
}

# Modification
impl ESBytesEmitter.emit_replace(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "replace", [target] + args);
}

impl ESBytesEmitter.emit_strip(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "strip", [target] + args);
}

impl ESBytesEmitter.emit_lstrip(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "lstrip", [target] + args);
}

impl ESBytesEmitter.emit_rstrip(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rstrip", [target] + args);
}

impl ESBytesEmitter.emit_removeprefix(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "removeprefix", [target] + args);
}

impl ESBytesEmitter.emit_removesuffix(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "removesuffix", [target] + args);
}

# Split and join
impl ESBytesEmitter.emit_split(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "split", [target] + args);
}

impl ESBytesEmitter.emit_rsplit(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rsplit", [target] + args);
}

impl ESBytesEmitter.emit_splitlines(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "splitlines", [target] + args);
}

impl ESBytesEmitter.emit_join(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "join", [target] + args);
}

impl ESBytesEmitter.emit_partition(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "partition", [target] + args);
}

impl ESBytesEmitter.emit_rpartition(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rpartition", [target] + args);
}

# Case (ASCII only)
impl ESBytesEmitter.emit_capitalize(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "capitalize", [target]);
}

impl ESBytesEmitter.emit_lower(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "lower", [target]);
}

impl ESBytesEmitter.emit_upper(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "upper", [target]);
}

impl ESBytesEmitter.emit_title(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "title", [target]);
}

impl ESBytesEmitter.emit_swapcase(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "swapcase", [target]);
}

# Character tests (ASCII only)
impl ESBytesEmitter.emit_isalnum(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isalnum", [target]);
}

impl ESBytesEmitter.emit_isalpha(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isalpha", [target]);
}

impl ESBytesEmitter.emit_isascii(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isascii", [target]);
}

impl ESBytesEmitter.emit_isdigit(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isdigit", [target]);
}

impl ESBytesEmitter.emit_islower(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "islower", [target]);
}

impl ESBytesEmitter.emit_isspace(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isspace", [target]);
}

impl ESBytesEmitter.emit_istitle(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "istitle", [target]);
}

impl ESBytesEmitter.emit_isupper(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isupper", [target]);
}

# Alignment
impl ESBytesEmitter.emit_center(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "center", [target] + args);
}

impl ESBytesEmitter.emit_ljust(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "ljust", [target] + args);
}

impl ESBytesEmitter.emit_rjust(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rjust", [target] + args);
}

impl ESBytesEmitter.emit_zfill(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "zfill", [target] + args);
}

impl ESBytesEmitter.emit_expandtabs(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "expandtabs", [target] + args);
}

# Translation
impl ESBytesEmitter.emit_translate(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "translate", [target] + args);
}

impl ESBytesEmitter.emit_maketrans(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("bytes", "maketrans", args);
}

# --- Arithmetic operators ---
impl ESBytesEmitter.emit_op_add(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "add", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_mul(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "mul", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_mod(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "mod", [target, args[0]]);
}

# --- Comparison operators ---
impl ESBytesEmitter.emit_op_eq(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "eq", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_ne(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("bytes", "eq", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_lt(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "lt", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_gt(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "gt", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_le(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "le", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_ge(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "ge", [target, args[0]]);
}

# --- Membership operators ---
impl ESBytesEmitter.emit_op_contains(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "contains", [target, args[0]]);
}

# --- Named methods ---
impl ESListEmitter.emit_append(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "push", args);
}

impl ESListEmitter.emit_extend(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return target + ".push(..." + args[0] + ")";
}

impl ESListEmitter.emit_insert(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "splice", [args[0], "0", args[1]]);
}

impl ESListEmitter.emit_remove(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "remove", [target] + args);
}

impl ESListEmitter.emit_pop(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "pop", []);
    }
    return _mcall(target, "splice", [args[0], "1"]) + "[0]";
}

impl ESListEmitter.emit_clear(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return target + ".length = 0";
}

impl ESListEmitter.emit_index(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "index", [target] + args);
}

impl ESListEmitter.emit_count(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "count", [target] + args);
}

impl ESListEmitter.emit_sort(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "sort", []);
    }
    return _rt("list", "sort", [target] + args);
}

impl ESListEmitter.emit_reverse(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "reverse", []);
}

impl ESListEmitter.emit_copy(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "[..." + target + "]";
}

# --- Arithmetic operators ---
impl ESListEmitter.emit_op_add(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "[..." + target + ", ..." + args[0] + "]";
}

impl ESListEmitter.emit_op_mul(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "repeat", [target, args[0]]);
}

# --- Comparison operators ---
impl ESListEmitter.emit_op_eq(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "eq", [target, args[0]]);
}

impl ESListEmitter.emit_op_ne(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("list", "eq", [target, args[0]]);
}

impl ESListEmitter.emit_op_lt(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "lt", [target, args[0]]);
}

impl ESListEmitter.emit_op_gt(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "gt", [target, args[0]]);
}

impl ESListEmitter.emit_op_le(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "le", [target, args[0]]);
}

impl ESListEmitter.emit_op_ge(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "ge", [target, args[0]]);
}

# --- Membership operators ---
impl ESListEmitter.emit_op_contains(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "includes", [args[0]]);
}

# --- In-place operators ---
impl ESListEmitter.emit_op_iadd(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    # list += other is extend in-place (mutates), not concat+reassign
    return target + ".push(..." + args[0] + ")";
}

impl ESListEmitter.emit_op_imul(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "imul", [target, args[0]]);
}

# --- Named methods ---
impl ESDictEmitter.emit_get(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 1 {
        return target + "[" + args[0] + "] ?? undefined";
    }
    return target + "[" + args[0] + "] ?? " + args[1];
}

impl ESDictEmitter.emit_keys(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Object.keys(" + target + ")";
}

impl ESDictEmitter.emit_values(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Object.values(" + target + ")";
}

impl ESDictEmitter.emit_items(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Object.entries(" + target + ")";
}

impl ESDictEmitter.emit_pop(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("dict", "pop", [target] + args);
}

impl ESDictEmitter.emit_popitem(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("dict", "popitem", [target]);
}

impl ESDictEmitter.emit_setdefault(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("dict", "setdefault", [target] + args);
}

impl ESDictEmitter.emit_update(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Object.assign(" + target + ", " + args[0] + ")";
}

impl ESDictEmitter.emit_clear(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("dict", "clear", [target]);
}

impl ESDictEmitter.emit_copy(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "{..." + target + "}";
}

impl ESDictEmitter.emit_fromkeys(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("dict", "fromkeys", args);
}

# --- Bitwise operators (dict merge) ---
impl ESDictEmitter.emit_op_or(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "{..." + target + ", ..." + args[0] + "}";
}

# --- Comparison operators ---
impl ESDictEmitter.emit_op_eq(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("dict", "eq", [target, args[0]]);
}

impl ESDictEmitter.emit_op_ne(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("dict", "eq", [target, args[0]]);
}

# --- Membership operators ---
impl ESDictEmitter.emit_op_contains(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(args[0], "in", target);
}

# --- In-place operators ---
impl ESDictEmitter.emit_op_ior(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Object.assign(" + target + ", " + args[0] + ")";
}

# --- Named methods (mutation) ---
impl ESSetEmitter.emit_add(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "add", args);
}

impl ESSetEmitter.emit_remove(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "remove", [target] + args);
}

impl ESSetEmitter.emit_discard(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "delete", args);
}

impl ESSetEmitter.emit_pop(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "pop", [target]);
}

impl ESSetEmitter.emit_clear(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "clear", []);
}

# --- Named methods (set algebra) ---
impl ESSetEmitter.emit_union(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "union", [target] + args);
}

impl ESSetEmitter.emit_intersection(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection", [target] + args);
}

impl ESSetEmitter.emit_difference(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference", [target] + args);
}

impl ESSetEmitter.emit_symmetric_difference(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetricDifference", [target] + args);
}

# --- Named methods (in-place set algebra) ---
impl ESSetEmitter.emit_update(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "update", [target] + args);
}

impl ESSetEmitter.emit_intersection_update(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection_update", [target] + args);
}

impl ESSetEmitter.emit_difference_update(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference_update", [target] + args);
}

impl ESSetEmitter.emit_symmetric_difference_update(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetric_difference_update", [target] + args);
}

# --- Named methods (tests) ---
impl ESSetEmitter.emit_issubset(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSubsetOf", [target] + args);
}

impl ESSetEmitter.emit_issuperset(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSupersetOf", [target] + args);
}

impl ESSetEmitter.emit_isdisjoint(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isDisjointFrom", [target] + args);
}

impl ESSetEmitter.emit_copy(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "new Set(" + target + ")";
}

# --- Set algebra operators ---
impl ESSetEmitter.emit_op_or(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "union", [target, args[0]]);
}

impl ESSetEmitter.emit_op_and(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection", [target, args[0]]);
}

impl ESSetEmitter.emit_op_sub(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference", [target, args[0]]);
}

impl ESSetEmitter.emit_op_xor(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetricDifference", [target, args[0]]);
}

# --- Comparison operators (subset/superset) ---
impl ESSetEmitter.emit_op_eq(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "eq", [target, args[0]]);
}

impl ESSetEmitter.emit_op_ne(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("set", "eq", [target, args[0]]);
}

impl ESSetEmitter.emit_op_le(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSubsetOf", [target, args[0]]);
}

impl ESSetEmitter.emit_op_lt(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "is_proper_subset", [target, args[0]]);
}

impl ESSetEmitter.emit_op_ge(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSupersetOf", [target, args[0]]);
}

impl ESSetEmitter.emit_op_gt(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "is_proper_superset", [target, args[0]]);
}

# --- Membership operators ---
impl ESSetEmitter.emit_op_contains(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "has", [args[0]]);
}

# --- In-place operators ---
impl ESSetEmitter.emit_op_ior(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "update", [target, args[0]]);
}

impl ESSetEmitter.emit_op_iand(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection_update", [target, args[0]]);
}

impl ESSetEmitter.emit_op_isub(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference_update", [target, args[0]]);
}

impl ESSetEmitter.emit_op_ixor(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetric_difference_update", [target, args[0]]);
}

# --- Named methods ---
impl ESFrozensetEmitter.emit_union(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "union", [target] + args);
}

impl ESFrozensetEmitter.emit_intersection(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection", [target] + args);
}

impl ESFrozensetEmitter.emit_difference(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference", [target] + args);
}

impl ESFrozensetEmitter.emit_symmetric_difference(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetricDifference", [target] + args);
}

impl ESFrozensetEmitter.emit_issubset(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSubsetOf", [target] + args);
}

impl ESFrozensetEmitter.emit_issuperset(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSupersetOf", [target] + args);
}

impl ESFrozensetEmitter.emit_isdisjoint(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isDisjointFrom", [target] + args);
}

impl ESFrozensetEmitter.emit_copy(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "new Set(" + target + ")";
}

# --- Set algebra operators ---
impl ESFrozensetEmitter.emit_op_or(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "union", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_and(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_sub(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_xor(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetricDifference", [target, args[0]]);
}

# --- Comparison operators (subset/superset) ---
impl ESFrozensetEmitter.emit_op_eq(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "eq", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_ne(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("set", "eq", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_le(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSubsetOf", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_lt(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "is_proper_subset", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_ge(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSupersetOf", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_gt(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "is_proper_superset", [target, args[0]]);
}

# --- Membership operators ---
impl ESFrozensetEmitter.emit_op_contains(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "has", [args[0]]);
}

# --- Named methods ---
impl ESTupleEmitter.emit_count(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "count", [target] + args);
}

impl ESTupleEmitter.emit_index(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "index", [target] + args);
}

# --- Arithmetic operators ---
impl ESTupleEmitter.emit_op_add(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "[..." + target + ", ..." + args[0] + "]";
}

impl ESTupleEmitter.emit_op_mul(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "repeat", [target, args[0]]);
}

# --- Comparison operators ---
impl ESTupleEmitter.emit_op_eq(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "eq", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_ne(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("tuple", "eq", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_lt(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "lt", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_gt(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "gt", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_le(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "le", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_ge(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "ge", [target, args[0]]);
}

# --- Membership operators ---
impl ESTupleEmitter.emit_op_contains(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "includes", [args[0]]);
}

# --- Named methods ---
impl ESRangeEmitter.emit_count(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("range", "count", [target] + args);
}

impl ESRangeEmitter.emit_index(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("range", "index", [target] + args);
}

# --- Comparison operators ---
impl ESRangeEmitter.emit_op_eq(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("range", "eq", [target, args[0]]);
}

impl ESRangeEmitter.emit_op_ne(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("range", "eq", [target, args[0]]);
}

# --- Membership operators ---
impl ESRangeEmitter.emit_op_contains(
    self, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("range", "contains", [target, args[0]]);
}

impl ESBuiltinEmitter.emit_print(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _fcall("console.log", args);
}

impl ESBuiltinEmitter.emit_input(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _fcall("prompt", args);
}

impl ESBuiltinEmitter.emit_len(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return args[0] + ".length";
}

impl ESBuiltinEmitter.emit_abs(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return "Math.abs(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_round(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 1 {
        return "Math.round(" + args[0] + ")";
    }
    return _rt("builtin", "round", args);
}

impl ESBuiltinEmitter.emit_min(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return _fcall("Math.min", args);
}

impl ESBuiltinEmitter.emit_max(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return _fcall("Math.max", args);
}

impl ESBuiltinEmitter.emit_sum(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return _rt("builtin", "sum", args);
}

impl ESBuiltinEmitter.emit_sorted(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "sorted", args);
}

impl ESBuiltinEmitter.emit_reversed(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "[..." + args[0] + "].reverse()";
}

impl ESBuiltinEmitter.emit_enumerate(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "enumerate", args);
}

impl ESBuiltinEmitter.emit_zip(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return _rt("builtin", "zip", args);
}

impl ESBuiltinEmitter.emit_map(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    if len(args) == 2 {
        return _mcall(args[1], "map", [args[0]]);
    }
    return _rt("builtin", "map", args);
}

impl ESBuiltinEmitter.emit_filter(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 2 {
        return _mcall(args[1], "filter", [args[0]]);
    }
    return _rt("builtin", "filter", args);
}

impl ESBuiltinEmitter.emit_any(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return _mcall(args[0], "some", ["Boolean"]);
}

impl ESBuiltinEmitter.emit_all(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return _mcall(args[0], "every", ["Boolean"]);
}

impl ESBuiltinEmitter.emit_isinstance(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return args[0] + " instanceof " + args[1];
}

impl ESBuiltinEmitter.emit_issubclass(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "issubclass", args);
}

impl ESBuiltinEmitter.emit_type(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return "typeof " + args[0];
}

impl ESBuiltinEmitter.emit_id(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return _rt("builtin", "id", args);
}

impl ESBuiltinEmitter.emit_jid(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return _rt("builtin", "jid", args);
}

impl ESBuiltinEmitter.emit_hash(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return _rt("builtin", "hash", args);
}

impl ESBuiltinEmitter.emit_repr(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return _rt("builtin", "repr", args);
}

impl ESBuiltinEmitter.emit_chr(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return "String.fromCodePoint(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_ord(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return args[0] + ".codePointAt(0)";
}

impl ESBuiltinEmitter.emit_hex(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return "'0x' + (" + args[0] + ").toString(16)";
}

impl ESBuiltinEmitter.emit_oct(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return "'0o' + (" + args[0] + ").toString(8)";
}

impl ESBuiltinEmitter.emit_bin(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return "'0b' + (" + args[0] + ").toString(2)";
}

impl ESBuiltinEmitter.emit_pow(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    if len(args) == 2 {
        return args[0] + " ** " + args[1];
    }
    return _rt("builtin", "pow", args);
}

impl ESBuiltinEmitter.emit_divmod(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "[Math.floor(" + args[0] + " / " + args[1] + "), " + args[0] + " % " + args[
        1
    ] + "]";
}

impl ESBuiltinEmitter.emit_iter(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return args[0] + "[Symbol.iterator]()";
}

impl ESBuiltinEmitter.emit_next(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return _rt("builtin", "next", args);
}

impl ESBuiltinEmitter.emit_callable(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "typeof " + args[0] + " === 'function'";
}

impl ESBuiltinEmitter.emit_getattr(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 2 {
        return args[0] + "[" + args[1] + "]";
    }
    return args[0] + "[" + args[1] + "] ?? " + args[2];
}

impl ESBuiltinEmitter.emit_setattr(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return args[0] + "[" + args[1] + "] = " + args[2];
}

impl ESBuiltinEmitter.emit_hasattr(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return args[1] + " in " + args[0];
}

impl ESBuiltinEmitter.emit_delattr(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "delete " + args[0] + "[" + args[1] + "]";
}

impl ESBuiltinEmitter.emit_vars(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return _rt("builtin", "vars", args);
}

impl ESBuiltinEmitter.emit_dir(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    if len(args) == 0 {
        return _rt("builtin", "dir", []);
    }
    return "Object.getOwnPropertyNames(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_open(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    return _rt("builtin", "open", args);
}

impl ESBuiltinEmitter.emit_format(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "format", args);
}

impl ESBuiltinEmitter.emit_ascii(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "ascii", args);
}

# Type conversion builtins
impl ESBuiltinEmitter.emit_str(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    if len(args) == 0 {
        return '""';
    }
    return "String(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_int(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
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

impl ESBuiltinEmitter.emit_float(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "0.0";
    }
    return "parseFloat(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_bool(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    if len(args) == 0 {
        return "false";
    }
    # Use runtime helper for Python truthiness semantics:
    # Python: bool([]) → False, bool({}) → False, bool(set()) → False
    # JS:     Boolean([]) → true,  Boolean({}) → true
    return _rt("builtin", "bool", args);
}

impl ESBuiltinEmitter.emit_list(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    if len(args) == 0 {
        return "[]";
    }
    return "Array.from(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_dict(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    if len(args) == 0 {
        return "{}";
    }
    return "Object.fromEntries(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_set(self, ctx: ESEmitCtx, args: list[str]) -> (str | None) {
    if len(args) == 0 {
        return "new Set()";
    }
    return "new Set(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_tuple(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "Object.freeze([])";
    }
    return "Object.freeze(Array.from(" + args[0] + "))";
}

impl ESBuiltinEmitter.emit_frozenset(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "Object.freeze(new Set())";
    }
    return "Object.freeze(new Set(" + args[0] + "))";
}

impl ESBuiltinEmitter.emit_bytes(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "new Uint8Array()";
    }
    return "new Uint8Array(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_complex(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "complex", args);
}

impl ESBuiltinEmitter.emit_range(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "range", args);
}

impl ESBuiltinEmitter.emit_slice(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "slice", args);
}

impl ESBuiltinEmitter.emit_bytearray(
    self, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "new Uint8Array()";
    }
    return "new Uint8Array(" + args[0] + ")";
}
