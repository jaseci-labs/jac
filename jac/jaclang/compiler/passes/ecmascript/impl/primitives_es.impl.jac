impl ESIntEmitter.emit_bit_length(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("int", "bit_length", [target]);
}

impl ESIntEmitter.emit_bit_count(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("int", "bit_count", [target]);
}

impl ESIntEmitter.emit_to_bytes(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("int", "to_bytes", [target] + args);
}

impl ESIntEmitter.emit_as_integer_ratio(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "[" + target + ", 1]";
}

impl ESIntEmitter.emit_conjugate(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return target;
}

impl ESIntEmitter.emit_from_bytes(
    self: ESIntEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("int", "from_bytes", args);
}

impl ESIntEmitter.emit_op_add(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "+", args[0]);
}

impl ESIntEmitter.emit_op_sub(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "-", args[0]);
}

impl ESIntEmitter.emit_op_mul(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "*", args[0]);
}

impl ESIntEmitter.emit_op_truediv(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "/", args[0]);
}

impl ESIntEmitter.emit_op_floordiv(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Math.floor(" + target + " / " + args[0] + ")";
}

impl ESIntEmitter.emit_op_mod(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("int", "mod", [target, args[0]]);
}

impl ESIntEmitter.emit_op_pow(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "**", args[0]);
}

impl ESIntEmitter.emit_op_and(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "&", args[0]);
}

impl ESIntEmitter.emit_op_or(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "|", args[0]);
}

impl ESIntEmitter.emit_op_xor(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "^", args[0]);
}

impl ESIntEmitter.emit_op_lshift(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<<", args[0]);
}

impl ESIntEmitter.emit_op_rshift(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">>", args[0]);
}

impl ESIntEmitter.emit_op_eq(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "===", args[0]);
}

impl ESIntEmitter.emit_op_ne(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "!==", args[0]);
}

impl ESIntEmitter.emit_op_lt(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<", args[0]);
}

impl ESIntEmitter.emit_op_gt(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">", args[0]);
}

impl ESIntEmitter.emit_op_le(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<=", args[0]);
}

impl ESIntEmitter.emit_op_ge(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">=", args[0]);
}

impl ESIntEmitter.emit_op_neg(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "(-" + target + ")";
}

impl ESIntEmitter.emit_op_pos(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "(+" + target + ")";
}

impl ESIntEmitter.emit_op_invert(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "(~" + target + ")";
}

impl ESFloatEmitter.emit_is_integer(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Number.isInteger(" + target + ")";
}

impl ESFloatEmitter.emit_as_integer_ratio(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("float", "as_integer_ratio", [target]);
}

impl ESFloatEmitter.emit_conjugate(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return target;
}

impl ESFloatEmitter.emit_hex(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("float", "hex", [target]);
}

impl ESFloatEmitter.emit_fromhex(
    self: ESFloatEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("float", "fromhex", args);
}

impl ESFloatEmitter.emit_op_add(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "+", args[0]);
}

impl ESFloatEmitter.emit_op_sub(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "-", args[0]);
}

impl ESFloatEmitter.emit_op_mul(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "*", args[0]);
}

impl ESFloatEmitter.emit_op_truediv(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "/", args[0]);
}

impl ESFloatEmitter.emit_op_floordiv(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Math.floor(" + target + " / " + args[0] + ")";
}

impl ESFloatEmitter.emit_op_mod(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("float", "mod", [target, args[0]]);
}

impl ESFloatEmitter.emit_op_pow(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "**", args[0]);
}

impl ESFloatEmitter.emit_op_eq(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "===", args[0]);
}

impl ESFloatEmitter.emit_op_ne(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "!==", args[0]);
}

impl ESFloatEmitter.emit_op_lt(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<", args[0]);
}

impl ESFloatEmitter.emit_op_gt(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">", args[0]);
}

impl ESFloatEmitter.emit_op_le(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<=", args[0]);
}

impl ESFloatEmitter.emit_op_ge(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">=", args[0]);
}

impl ESFloatEmitter.emit_op_neg(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "(-" + target + ")";
}

impl ESFloatEmitter.emit_op_pos(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "(+" + target + ")";
}

impl ESComplexEmitter.emit_conjugate(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "conjugate", [target]);
}

impl ESComplexEmitter.emit_op_add(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "add", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_sub(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "sub", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_mul(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "mul", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_truediv(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "truediv", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_pow(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "pow", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_eq(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "eq", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_ne(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("complex", "eq", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_neg(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "neg", [target]);
}

impl ESComplexEmitter.emit_op_pos(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "pos", [target]);
}

impl ESBoolEmitter.emit_op_and(
    self: ESBoolEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Boolean(" + _binop(target, "&", args[0]) + ")";
}

impl ESBoolEmitter.emit_op_or(
    self: ESBoolEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Boolean(" + _binop(target, "|", args[0]) + ")";
}

impl ESBoolEmitter.emit_op_xor(
    self: ESBoolEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Boolean(" + _binop(target, "^", args[0]) + ")";
}

impl ESStrEmitter.emit_capitalize(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "capitalize", [target]);
}

impl ESStrEmitter.emit_casefold(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "toLowerCase", []);
}

impl ESStrEmitter.emit_lower(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "toLowerCase", []);
}

impl ESStrEmitter.emit_upper(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "toUpperCase", []);
}

impl ESStrEmitter.emit_title(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "title", [target]);
}

impl ESStrEmitter.emit_swapcase(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "swapcase", [target]);
}

impl ESStrEmitter.emit_count(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "count", [target] + args);
}

impl ESStrEmitter.emit_find(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) > 1 {
        return _rt("str", "find", [target] + args);
    }
    return _mcall(target, "indexOf", args);
}

impl ESStrEmitter.emit_rfind(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) > 1 {
        return _rt("str", "rfind", [target] + args);
    }
    return _mcall(target, "lastIndexOf", args);
}

impl ESStrEmitter.emit_index(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "index", [target] + args);
}

impl ESStrEmitter.emit_rindex(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "rindex", [target] + args);
}

impl ESStrEmitter.emit_startswith(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 1 {
        return _mcall(target, "startsWith", args);
    }
    return _rt("str", "startswith", [target] + args);
}

impl ESStrEmitter.emit_endswith(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 1 {
        return _mcall(target, "endsWith", args);
    }
    return _rt("str", "endswith", [target] + args);
}

impl ESStrEmitter.emit_replace(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 2 {
        return _mcall(target, "replaceAll", args);
    }
    return _rt("str", "replace", [target] + args);
}

impl ESStrEmitter.emit_strip(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "trim", []);
    }
    return _rt("str", "strip", [target] + args);
}

impl ESStrEmitter.emit_lstrip(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "trimStart", []);
    }
    return _rt("str", "lstrip", [target] + args);
}

impl ESStrEmitter.emit_rstrip(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "trimEnd", []);
    }
    return _rt("str", "rstrip", [target] + args);
}

impl ESStrEmitter.emit_removeprefix(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "removeprefix", [target] + args);
}

impl ESStrEmitter.emit_removesuffix(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "removesuffix", [target] + args);
}

impl ESStrEmitter.emit_split(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
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
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "rsplit", [target] + args);
}

impl ESStrEmitter.emit_splitlines(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "split", ["/\\r?\\n/"]);
    }
    return _rt("str", "splitlines", [target] + args);
}

impl ESStrEmitter.emit_join(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(args[0], "join", [target]);
}

impl ESStrEmitter.emit_partition(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "partition", [target] + args);
}

impl ESStrEmitter.emit_rpartition(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "rpartition", [target] + args);
}

impl ESStrEmitter.emit_format(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "format", [target] + args);
}

impl ESStrEmitter.emit_format_map(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "format_map", [target] + args);
}

impl ESStrEmitter.emit_center(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "center", [target] + args);
}

impl ESStrEmitter.emit_ljust(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 1 {
        return _mcall(target, "padEnd", args);
    }
    return _mcall(target, "padEnd", args);
}

impl ESStrEmitter.emit_rjust(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 1 {
        return _mcall(target, "padStart", args);
    }
    return _mcall(target, "padStart", args);
}

impl ESStrEmitter.emit_zfill(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "zfill", [target] + args);
}

impl ESStrEmitter.emit_expandtabs(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "expandtabs", [target] + args);
}

impl ESStrEmitter.emit_isalnum(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[a-zA-Z0-9]+$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isalpha(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[a-zA-Z]+$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isascii(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[\\x00-\\x7F]*$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isdecimal(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[0-9]+$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isdigit(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[0-9]+$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isidentifier(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(" + target + ")";
}

impl ESStrEmitter.emit_islower(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "("
        + target
        + " === "
        + target
        + ".toLowerCase() && "
        + target
        + " !== "
        + target
        + ".toUpperCase())";
}

impl ESStrEmitter.emit_isnumeric(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "isnumeric", [target]);
}

impl ESStrEmitter.emit_isprintable(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[\\x20-\\x7E]*$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isspace(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^\\s+$/.test(" + target + ")";
}

impl ESStrEmitter.emit_istitle(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "istitle", [target]);
}

impl ESStrEmitter.emit_isupper(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "("
        + target
        + " === "
        + target
        + ".toUpperCase() && "
        + target
        + " !== "
        + target
        + ".toLowerCase())";
}

impl ESStrEmitter.emit_encode(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "new TextEncoder().encode(" + target + ")";
}

impl ESStrEmitter.emit_translate(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "translate", [target] + args);
}

impl ESStrEmitter.emit_maketrans(
    self: ESStrEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("str", "maketrans", args);
}

impl ESStrEmitter.emit_op_add(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "+", args[0]);
}

impl ESStrEmitter.emit_op_mul(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "repeat", [args[0]]);
}

impl ESStrEmitter.emit_op_mod(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "mod", [target, args[0]]);
}

impl ESStrEmitter.emit_op_eq(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "===", args[0]);
}

impl ESStrEmitter.emit_op_ne(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "!==", args[0]);
}

impl ESStrEmitter.emit_op_lt(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<", args[0]);
}

impl ESStrEmitter.emit_op_gt(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">", args[0]);
}

impl ESStrEmitter.emit_op_le(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<=", args[0]);
}

impl ESStrEmitter.emit_op_ge(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">=", args[0]);
}

impl ESStrEmitter.emit_op_contains(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "includes", [args[0]]);
}

impl ESBytesEmitter.emit_decode(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "new TextDecoder("
        + (args[0] if len(args) > 0 else "")
        + ").decode("
        + target
        + ")";
}

impl ESBytesEmitter.emit_hex(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "hex", [target] + args);
}

impl ESBytesEmitter.emit_fromhex(
    self: ESBytesEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("bytes", "fromhex", args);
}

impl ESBytesEmitter.emit_count(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "count", [target] + args);
}

impl ESBytesEmitter.emit_find(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "find", [target] + args);
}

impl ESBytesEmitter.emit_rfind(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rfind", [target] + args);
}

impl ESBytesEmitter.emit_index(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "index", [target] + args);
}

impl ESBytesEmitter.emit_rindex(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rindex", [target] + args);
}

impl ESBytesEmitter.emit_startswith(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "startswith", [target] + args);
}

impl ESBytesEmitter.emit_endswith(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "endswith", [target] + args);
}

impl ESBytesEmitter.emit_replace(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "replace", [target] + args);
}

impl ESBytesEmitter.emit_strip(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "strip", [target] + args);
}

impl ESBytesEmitter.emit_lstrip(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "lstrip", [target] + args);
}

impl ESBytesEmitter.emit_rstrip(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rstrip", [target] + args);
}

impl ESBytesEmitter.emit_removeprefix(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "removeprefix", [target] + args);
}

impl ESBytesEmitter.emit_removesuffix(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "removesuffix", [target] + args);
}

impl ESBytesEmitter.emit_split(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "split", [target] + args);
}

impl ESBytesEmitter.emit_rsplit(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rsplit", [target] + args);
}

impl ESBytesEmitter.emit_splitlines(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "splitlines", [target] + args);
}

impl ESBytesEmitter.emit_join(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "join", [target] + args);
}

impl ESBytesEmitter.emit_partition(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "partition", [target] + args);
}

impl ESBytesEmitter.emit_rpartition(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rpartition", [target] + args);
}

impl ESBytesEmitter.emit_capitalize(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "capitalize", [target]);
}

impl ESBytesEmitter.emit_lower(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "lower", [target]);
}

impl ESBytesEmitter.emit_upper(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "upper", [target]);
}

impl ESBytesEmitter.emit_title(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "title", [target]);
}

impl ESBytesEmitter.emit_swapcase(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "swapcase", [target]);
}

impl ESBytesEmitter.emit_isalnum(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isalnum", [target]);
}

impl ESBytesEmitter.emit_isalpha(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isalpha", [target]);
}

impl ESBytesEmitter.emit_isascii(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isascii", [target]);
}

impl ESBytesEmitter.emit_isdigit(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isdigit", [target]);
}

impl ESBytesEmitter.emit_islower(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "islower", [target]);
}

impl ESBytesEmitter.emit_isspace(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isspace", [target]);
}

impl ESBytesEmitter.emit_istitle(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "istitle", [target]);
}

impl ESBytesEmitter.emit_isupper(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isupper", [target]);
}

impl ESBytesEmitter.emit_center(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "center", [target] + args);
}

impl ESBytesEmitter.emit_ljust(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "ljust", [target] + args);
}

impl ESBytesEmitter.emit_rjust(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rjust", [target] + args);
}

impl ESBytesEmitter.emit_zfill(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "zfill", [target] + args);
}

impl ESBytesEmitter.emit_expandtabs(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "expandtabs", [target] + args);
}

impl ESBytesEmitter.emit_translate(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "translate", [target] + args);
}

impl ESBytesEmitter.emit_maketrans(
    self: ESBytesEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("bytes", "maketrans", args);
}

impl ESBytesEmitter.emit_op_add(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "add", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_mul(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "mul", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_mod(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "mod", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_eq(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "eq", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_ne(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("bytes", "eq", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_lt(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "lt", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_gt(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "gt", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_le(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "le", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_ge(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "ge", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_contains(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "contains", [target, args[0]]);
}

impl ESListEmitter.emit_append(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "push", args);
}

impl ESListEmitter.emit_extend(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return target + ".push(..." + args[0] + ")";
}

impl ESListEmitter.emit_insert(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "splice", [args[0], "0", args[1]]);
}

impl ESListEmitter.emit_remove(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "remove", [target] + args);
}

impl ESListEmitter.emit_pop(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "pop", []);
    }
    return _mcall(target, "splice", [args[0], "1"]) + "[0]";
}

impl ESListEmitter.emit_clear(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return target + ".length = 0";
}

impl ESListEmitter.emit_index(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "index", [target] + args);
}

impl ESListEmitter.emit_count(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "count", [target] + args);
}

impl ESListEmitter.emit_sort(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "sort", []);
    }
    return _rt("list", "sort", [target] + args);
}

impl ESListEmitter.emit_reverse(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "reverse", []);
}

impl ESListEmitter.emit_copy(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "[..." + target + "]";
}

impl ESListEmitter.emit_op_add(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "[..." + target + ", ..." + args[0] + "]";
}

impl ESListEmitter.emit_op_mul(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "repeat", [target, args[0]]);
}

impl ESListEmitter.emit_op_eq(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "eq", [target, args[0]]);
}

impl ESListEmitter.emit_op_ne(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("list", "eq", [target, args[0]]);
}

impl ESListEmitter.emit_op_lt(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "lt", [target, args[0]]);
}

impl ESListEmitter.emit_op_gt(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "gt", [target, args[0]]);
}

impl ESListEmitter.emit_op_le(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "le", [target, args[0]]);
}

impl ESListEmitter.emit_op_ge(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "ge", [target, args[0]]);
}

impl ESListEmitter.emit_op_contains(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "includes", [args[0]]);
}

impl ESListEmitter.emit_op_iadd(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return target + ".push(..." + args[0] + ")";
}

impl ESListEmitter.emit_op_imul(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "imul", [target, args[0]]);
}

impl ESDictEmitter.emit_get(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("dict", "get", [target] + args);
}

impl ESDictEmitter.emit_keys(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Object.keys(" + target + ")";
}

impl ESDictEmitter.emit_values(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Object.values(" + target + ")";
}

impl ESDictEmitter.emit_items(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Object.entries(" + target + ")";
}

impl ESDictEmitter.emit_pop(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("dict", "pop", [target] + args);
}

impl ESDictEmitter.emit_popitem(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("dict", "popitem", [target]);
}

impl ESDictEmitter.emit_setdefault(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("dict", "setdefault", [target] + args);
}

impl ESDictEmitter.emit_update(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Object.assign(" + target + ", " + args[0] + ")";
}

impl ESDictEmitter.emit_clear(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("dict", "clear", [target]);
}

impl ESDictEmitter.emit_copy(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "{..." + target + "}";
}

impl ESDictEmitter.emit_fromkeys(
    self: ESDictEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("dict", "fromkeys", args);
}

impl ESDictEmitter.emit_op_or(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "{..." + target + ", ..." + args[0] + "}";
}

impl ESDictEmitter.emit_op_eq(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("dict", "eq", [target, args[0]]);
}

impl ESDictEmitter.emit_op_ne(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("dict", "eq", [target, args[0]]);
}

impl ESDictEmitter.emit_op_contains(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(args[0], "in", target);
}

impl ESDictEmitter.emit_op_ior(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Object.assign(" + target + ", " + args[0] + ")";
}

impl ESSetEmitter.emit_add(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "add", args);
}

impl ESSetEmitter.emit_remove(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "remove", [target] + args);
}

impl ESSetEmitter.emit_discard(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "delete", args);
}

impl ESSetEmitter.emit_pop(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "pop", [target]);
}

impl ESSetEmitter.emit_clear(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "clear", []);
}

impl ESSetEmitter.emit_union(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "union", [target] + args);
}

impl ESSetEmitter.emit_intersection(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection", [target] + args);
}

impl ESSetEmitter.emit_difference(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference", [target] + args);
}

impl ESSetEmitter.emit_symmetric_difference(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetricDifference", [target] + args);
}

impl ESSetEmitter.emit_update(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "update", [target] + args);
}

impl ESSetEmitter.emit_intersection_update(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection_update", [target] + args);
}

impl ESSetEmitter.emit_difference_update(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference_update", [target] + args);
}

impl ESSetEmitter.emit_symmetric_difference_update(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetric_difference_update", [target] + args);
}

impl ESSetEmitter.emit_issubset(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSubsetOf", [target] + args);
}

impl ESSetEmitter.emit_issuperset(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSupersetOf", [target] + args);
}

impl ESSetEmitter.emit_isdisjoint(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isDisjointFrom", [target] + args);
}

impl ESSetEmitter.emit_copy(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "new Set(" + target + ")";
}

impl ESSetEmitter.emit_op_or(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "union", [target, args[0]]);
}

impl ESSetEmitter.emit_op_and(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection", [target, args[0]]);
}

impl ESSetEmitter.emit_op_sub(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference", [target, args[0]]);
}

impl ESSetEmitter.emit_op_xor(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetricDifference", [target, args[0]]);
}

impl ESSetEmitter.emit_op_eq(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "eq", [target, args[0]]);
}

impl ESSetEmitter.emit_op_ne(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("set", "eq", [target, args[0]]);
}

impl ESSetEmitter.emit_op_le(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSubsetOf", [target, args[0]]);
}

impl ESSetEmitter.emit_op_lt(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "is_proper_subset", [target, args[0]]);
}

impl ESSetEmitter.emit_op_ge(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSupersetOf", [target, args[0]]);
}

impl ESSetEmitter.emit_op_gt(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "is_proper_superset", [target, args[0]]);
}

impl ESSetEmitter.emit_op_contains(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "has", [args[0]]);
}

impl ESSetEmitter.emit_op_ior(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "update", [target, args[0]]);
}

impl ESSetEmitter.emit_op_iand(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection_update", [target, args[0]]);
}

impl ESSetEmitter.emit_op_isub(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference_update", [target, args[0]]);
}

impl ESSetEmitter.emit_op_ixor(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetric_difference_update", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_union(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "union", [target] + args);
}

impl ESFrozensetEmitter.emit_intersection(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection", [target] + args);
}

impl ESFrozensetEmitter.emit_difference(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference", [target] + args);
}

impl ESFrozensetEmitter.emit_symmetric_difference(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetricDifference", [target] + args);
}

impl ESFrozensetEmitter.emit_issubset(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSubsetOf", [target] + args);
}

impl ESFrozensetEmitter.emit_issuperset(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSupersetOf", [target] + args);
}

impl ESFrozensetEmitter.emit_isdisjoint(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isDisjointFrom", [target] + args);
}

impl ESFrozensetEmitter.emit_copy(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "new Set(" + target + ")";
}

impl ESFrozensetEmitter.emit_op_or(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "union", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_and(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_sub(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_xor(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetricDifference", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_eq(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "eq", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_ne(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("set", "eq", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_le(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSubsetOf", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_lt(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "is_proper_subset", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_ge(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSupersetOf", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_gt(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "is_proper_superset", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_contains(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "has", [args[0]]);
}

impl ESTupleEmitter.emit_count(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "count", [target] + args);
}

impl ESTupleEmitter.emit_index(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "index", [target] + args);
}

impl ESTupleEmitter.emit_op_add(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "[..." + target + ", ..." + args[0] + "]";
}

impl ESTupleEmitter.emit_op_mul(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "repeat", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_eq(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "eq", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_ne(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("tuple", "eq", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_lt(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "lt", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_gt(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "gt", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_le(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "le", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_ge(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "ge", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_contains(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "includes", [args[0]]);
}

impl ESRangeEmitter.emit_count(
    self: ESRangeEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("range", "count", [target] + args);
}

impl ESRangeEmitter.emit_index(
    self: ESRangeEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("range", "index", [target] + args);
}

impl ESRangeEmitter.emit_op_eq(
    self: ESRangeEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("range", "eq", [target, args[0]]);
}

impl ESRangeEmitter.emit_op_ne(
    self: ESRangeEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("range", "eq", [target, args[0]]);
}

impl ESRangeEmitter.emit_op_contains(
    self: ESRangeEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("range", "contains", [target, args[0]]);
}

impl ESBuiltinEmitter.emit_print(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _fcall("console.log", args);
}

impl ESBuiltinEmitter.emit_input(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _fcall("prompt", args);
}

impl ESBuiltinEmitter.emit_len(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if not args {
        return None;
    }

    arg_type = (ctx.arg_type_names or [""])[0] if ctx.arg_type_names else "";
    if arg_type == "dict" {
        return "Object.keys(" + args[0] + ").length";
    }
    if arg_type in ("set", "frozenset") {
        return args[0] + ".size";
    }
    if arg_type in ("str", "list", "tuple", "bytes", "bytearray", "range") {
        return args[0] + ".length";
    }
    return _rt("builtin", "len", args);
}

impl ESBuiltinEmitter.emit_abs(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "Math.abs(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_round(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 1 {
        return "Math.round(" + args[0] + ")";
    }
    return _rt("builtin", "round", args);
}

impl ESBuiltinEmitter.emit_min(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _fcall("Math.min", args);
}

impl ESBuiltinEmitter.emit_max(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _fcall("Math.max", args);
}

impl ESBuiltinEmitter.emit_sum(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "sum", args);
}

impl ESBuiltinEmitter.emit_sorted(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "sorted", args);
}

impl ESBuiltinEmitter.emit_reversed(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "[..." + args[0] + "].reverse()";
}

impl ESBuiltinEmitter.emit_enumerate(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "enumerate", args);
}

impl ESBuiltinEmitter.emit_zip(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "zip", args);
}

impl ESBuiltinEmitter.emit_map(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 2 {
        return _one_arg_cb(args[0], args[1], "map", "_f(_v)");
    }
    return _rt("builtin", "map", args);
}

impl ESBuiltinEmitter.emit_filter(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 2 {
        return _one_arg_cb(args[0], args[1], "filter", "_f ? _f(_v) : _v");
    }
    return _rt("builtin", "filter", args);
}

impl ESBuiltinEmitter.emit_any(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _mcall(args[0], "some", ["Boolean"]);
}

impl ESBuiltinEmitter.emit_all(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _mcall(args[0], "every", ["Boolean"]);
}

impl ESBuiltinEmitter.emit_isinstance(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) != 2 {
        return None;
    }
    return _rt("builtin", "isinstance", args);
}

impl ESBuiltinEmitter.emit_issubclass(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) != 2 {
        return None;
    }
    return _rt("builtin", "issubclass", args);
}

impl ESBuiltinEmitter.emit_type(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "typeof " + args[0];
}

impl ESBuiltinEmitter.emit_id(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "id", args);
}

impl ESBuiltinEmitter.emit_jid(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "jid", args);
}

impl ESBuiltinEmitter.emit_new(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "Reflect.construct(undefined, [])";
    }
    cls = args[0];
    ctor_args = "[" + ", ".join(args[1:]) + "]";
    return "Reflect.construct(" + cls + ", " + ctor_args + ")";
}

impl ESBuiltinEmitter.emit_unsafe_html(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "unsafe_html", args);
}

impl ESBuiltinEmitter.emit_hash(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "hash", args);
}

impl ESBuiltinEmitter.emit_repr(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "repr", args);
}

impl ESBuiltinEmitter.emit_chr(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "String.fromCodePoint(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_ord(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return args[0] + ".codePointAt(0)";
}

impl ESBuiltinEmitter.emit_hex(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "'0x' + (" + args[0] + ").toString(16)";
}

impl ESBuiltinEmitter.emit_oct(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "'0o' + (" + args[0] + ").toString(8)";
}

impl ESBuiltinEmitter.emit_bin(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "'0b' + (" + args[0] + ").toString(2)";
}

impl ESBuiltinEmitter.emit_pow(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 2 {
        return args[0] + " ** " + args[1];
    }
    return _rt("builtin", "pow", args);
}

impl ESBuiltinEmitter.emit_divmod(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "[Math.floor("
        + args[0]
        + " / "
        + args[1]
        + "), "
        + args[0]
        + " % "
        + args[1]
        + "]";
}

impl ESBuiltinEmitter.emit_iter(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return args[0] + "[Symbol.iterator]()";
}

impl ESBuiltinEmitter.emit_next(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "next", args);
}

impl ESBuiltinEmitter.emit_callable(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "typeof " + args[0] + " === 'function'";
}

impl ESBuiltinEmitter.emit_getattr(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 2 {
        return args[0] + "[" + args[1] + "]";
    }
    return "(" + args[0] + "[" + args[1] + "] ?? " + args[2] + ")";
}

impl ESBuiltinEmitter.emit_setattr(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return args[0] + "[" + args[1] + "] = " + args[2];
}

impl ESBuiltinEmitter.emit_hasattr(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return args[1] + " in " + args[0];
}

impl ESBuiltinEmitter.emit_delattr(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "delete " + args[0] + "[" + args[1] + "]";
}

impl ESBuiltinEmitter.emit_vars(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "vars", args);
}

impl ESBuiltinEmitter.emit_dir(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _rt("builtin", "dir", []);
    }
    return "Object.getOwnPropertyNames(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_open(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "open", args);
}

impl ESBuiltinEmitter.emit_format(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "format", args);
}

impl ESBuiltinEmitter.emit_ascii(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "ascii", args);
}

impl ESBuiltinEmitter.emit_str(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return '""';
    }
    return "String(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_int(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "0";
    }

    return _rt("builtin", "int", args);
}

impl ESBuiltinEmitter.emit_float(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "0.0";
    }

    return _rt("builtin", "float", args);
}

impl ESBuiltinEmitter.emit_bool(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "false";
    }

    return _rt("builtin", "bool", args);
}

impl ESBuiltinEmitter.emit_list(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "[]";
    }

    return "Array.from(" + _rt("builtin", "iter", args) + ")";
}

impl ESBuiltinEmitter.emit_dict(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "{}";
    }

    return _rt("builtin", "dict", args);
}

impl ESBuiltinEmitter.emit_set(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "new Set()";
    }
    return "new Set(" + _rt("builtin", "iter", args) + ")";
}

impl ESBuiltinEmitter.emit_tuple(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "Object.freeze([])";
    }
    return "Object.freeze(Array.from(" + args[0] + "))";
}

impl ESBuiltinEmitter.emit_frozenset(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "Object.freeze(new Set())";
    }
    return "Object.freeze(new Set(" + args[0] + "))";
}

impl ESBuiltinEmitter.emit_bytes(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "new Uint8Array()";
    }
    return "new Uint8Array(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_complex(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "complex", args);
}

impl ESBuiltinEmitter.emit_range(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "range", args);
}

impl ESBuiltinEmitter.emit_slice(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "slice", args);
}

impl ESBuiltinEmitter.emit_bytearray(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "new Uint8Array()";
    }
    return "new Uint8Array(" + args[0] + ")";
}
