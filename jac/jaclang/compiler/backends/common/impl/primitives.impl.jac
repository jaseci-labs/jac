impl IntEmitter.method_names(self: IntEmitter) -> list[str] {
    return [
        "bit_length",
        "bit_count",
        "to_bytes",
        "as_integer_ratio",
        "conjugate",
        "op_add",
        "op_sub",
        "op_mul",
        "op_truediv",
        "op_floordiv",
        "op_mod",
        "op_pow",
        "op_and",
        "op_or",
        "op_xor",
        "op_lshift",
        "op_rshift",
        "op_eq",
        "op_ne",
        "op_lt",
        "op_gt",
        "op_le",
        "op_ge",
        "op_neg",
        "op_pos",
        "op_invert"
    ];
}

impl IntEmitter.static_names(self: IntEmitter) -> list[str] {
    return ["from_bytes"];
}

impl IntEmitter.dispatch(
    self: IntEmitter, name: str, ctx: C, target: V, args: list[V]
) -> (V | None) {
    if name == "bit_length" {
        return self.emit_bit_length(ctx, target, args);
    }
    if name == "bit_count" {
        return self.emit_bit_count(ctx, target, args);
    }
    if name == "to_bytes" {
        return self.emit_to_bytes(ctx, target, args);
    }
    if name == "as_integer_ratio" {
        return self.emit_as_integer_ratio(ctx, target, args);
    }
    if name == "conjugate" {
        return self.emit_conjugate(ctx, target, args);
    }
    if name == "op_add" {
        return self.emit_op_add(ctx, target, args);
    }
    if name == "op_sub" {
        return self.emit_op_sub(ctx, target, args);
    }
    if name == "op_mul" {
        return self.emit_op_mul(ctx, target, args);
    }
    if name == "op_truediv" {
        return self.emit_op_truediv(ctx, target, args);
    }
    if name == "op_floordiv" {
        return self.emit_op_floordiv(ctx, target, args);
    }
    if name == "op_mod" {
        return self.emit_op_mod(ctx, target, args);
    }
    if name == "op_pow" {
        return self.emit_op_pow(ctx, target, args);
    }
    if name == "op_and" {
        return self.emit_op_and(ctx, target, args);
    }
    if name == "op_or" {
        return self.emit_op_or(ctx, target, args);
    }
    if name == "op_xor" {
        return self.emit_op_xor(ctx, target, args);
    }
    if name == "op_lshift" {
        return self.emit_op_lshift(ctx, target, args);
    }
    if name == "op_rshift" {
        return self.emit_op_rshift(ctx, target, args);
    }
    if name == "op_eq" {
        return self.emit_op_eq(ctx, target, args);
    }
    if name == "op_ne" {
        return self.emit_op_ne(ctx, target, args);
    }
    if name == "op_lt" {
        return self.emit_op_lt(ctx, target, args);
    }
    if name == "op_gt" {
        return self.emit_op_gt(ctx, target, args);
    }
    if name == "op_le" {
        return self.emit_op_le(ctx, target, args);
    }
    if name == "op_ge" {
        return self.emit_op_ge(ctx, target, args);
    }
    if name == "op_neg" {
        return self.emit_op_neg(ctx, target, args);
    }
    if name == "op_pos" {
        return self.emit_op_pos(ctx, target, args);
    }
    if name == "op_invert" {
        return self.emit_op_invert(ctx, target, args);
    }
    return None;
}

impl IntEmitter.dispatch_static(
    self: IntEmitter, name: str, ctx: C, args: list[V]
) -> (V | None) {
    if name == "from_bytes" {
        return self.emit_from_bytes(ctx, args);
    }
    return None;
}

impl FloatEmitter.method_names(self: FloatEmitter) -> list[str] {
    return [
        "is_integer",
        "as_integer_ratio",
        "conjugate",
        "hex",
        "op_add",
        "op_sub",
        "op_mul",
        "op_truediv",
        "op_floordiv",
        "op_mod",
        "op_pow",
        "op_eq",
        "op_ne",
        "op_lt",
        "op_gt",
        "op_le",
        "op_ge",
        "op_neg",
        "op_pos"
    ];
}

impl FloatEmitter.static_names(self: FloatEmitter) -> list[str] {
    return ["fromhex"];
}

impl FloatEmitter.dispatch(
    self: FloatEmitter, name: str, ctx: C, target: V, args: list[V]
) -> (V | None) {
    if name == "is_integer" {
        return self.emit_is_integer(ctx, target, args);
    }
    if name == "as_integer_ratio" {
        return self.emit_as_integer_ratio(ctx, target, args);
    }
    if name == "conjugate" {
        return self.emit_conjugate(ctx, target, args);
    }
    if name == "hex" {
        return self.emit_hex(ctx, target, args);
    }
    if name == "op_add" {
        return self.emit_op_add(ctx, target, args);
    }
    if name == "op_sub" {
        return self.emit_op_sub(ctx, target, args);
    }
    if name == "op_mul" {
        return self.emit_op_mul(ctx, target, args);
    }
    if name == "op_truediv" {
        return self.emit_op_truediv(ctx, target, args);
    }
    if name == "op_floordiv" {
        return self.emit_op_floordiv(ctx, target, args);
    }
    if name == "op_mod" {
        return self.emit_op_mod(ctx, target, args);
    }
    if name == "op_pow" {
        return self.emit_op_pow(ctx, target, args);
    }
    if name == "op_eq" {
        return self.emit_op_eq(ctx, target, args);
    }
    if name == "op_ne" {
        return self.emit_op_ne(ctx, target, args);
    }
    if name == "op_lt" {
        return self.emit_op_lt(ctx, target, args);
    }
    if name == "op_gt" {
        return self.emit_op_gt(ctx, target, args);
    }
    if name == "op_le" {
        return self.emit_op_le(ctx, target, args);
    }
    if name == "op_ge" {
        return self.emit_op_ge(ctx, target, args);
    }
    if name == "op_neg" {
        return self.emit_op_neg(ctx, target, args);
    }
    if name == "op_pos" {
        return self.emit_op_pos(ctx, target, args);
    }
    return None;
}

impl FloatEmitter.dispatch_static(
    self: FloatEmitter, name: str, ctx: C, args: list[V]
) -> (V | None) {
    if name == "fromhex" {
        return self.emit_fromhex(ctx, args);
    }
    return None;
}

impl ComplexEmitter.method_names(self: ComplexEmitter) -> list[str] {
    return [
        "conjugate",
        "op_add",
        "op_sub",
        "op_mul",
        "op_truediv",
        "op_pow",
        "op_eq",
        "op_ne",
        "op_neg",
        "op_pos"
    ];
}

impl ComplexEmitter.static_names(self: ComplexEmitter) -> list[str] {
    return [];
}

impl ComplexEmitter.dispatch(
    self: ComplexEmitter, name: str, ctx: C, target: V, args: list[V]
) -> (V | None) {
    if name == "conjugate" {
        return self.emit_conjugate(ctx, target, args);
    }
    if name == "op_add" {
        return self.emit_op_add(ctx, target, args);
    }
    if name == "op_sub" {
        return self.emit_op_sub(ctx, target, args);
    }
    if name == "op_mul" {
        return self.emit_op_mul(ctx, target, args);
    }
    if name == "op_truediv" {
        return self.emit_op_truediv(ctx, target, args);
    }
    if name == "op_pow" {
        return self.emit_op_pow(ctx, target, args);
    }
    if name == "op_eq" {
        return self.emit_op_eq(ctx, target, args);
    }
    if name == "op_ne" {
        return self.emit_op_ne(ctx, target, args);
    }
    if name == "op_neg" {
        return self.emit_op_neg(ctx, target, args);
    }
    if name == "op_pos" {
        return self.emit_op_pos(ctx, target, args);
    }
    return None;
}

impl ComplexEmitter.dispatch_static(
    self: ComplexEmitter, name: str, ctx: C, args: list[V]
) -> (V | None) {
    return None;
}

impl StrEmitter.method_names(self: StrEmitter) -> list[str] {
    return [
        "capitalize",
        "casefold",
        "lower",
        "upper",
        "title",
        "swapcase",
        "count",
        "find",
        "rfind",
        "index",
        "rindex",
        "startswith",
        "endswith",
        "replace",
        "strip",
        "lstrip",
        "rstrip",
        "removeprefix",
        "removesuffix",
        "split",
        "rsplit",
        "splitlines",
        "join",
        "partition",
        "rpartition",
        "format",
        "format_map",
        "center",
        "ljust",
        "rjust",
        "zfill",
        "expandtabs",
        "isalnum",
        "isalpha",
        "isascii",
        "isdecimal",
        "isdigit",
        "isidentifier",
        "islower",
        "isnumeric",
        "isprintable",
        "isspace",
        "istitle",
        "isupper",
        "encode",
        "translate",
        "op_add",
        "op_mul",
        "op_mod",
        "op_eq",
        "op_ne",
        "op_lt",
        "op_gt",
        "op_le",
        "op_ge",
        "op_contains"
    ];
}

impl StrEmitter.static_names(self: StrEmitter) -> list[str] {
    return ["maketrans"];
}

impl StrEmitter.dispatch(
    self: StrEmitter, name: str, ctx: C, target: V, args: list[V]
) -> (V | None) {
    if name == "capitalize" {
        return self.emit_capitalize(ctx, target, args);
    }
    if name == "casefold" {
        return self.emit_casefold(ctx, target, args);
    }
    if name == "lower" {
        return self.emit_lower(ctx, target, args);
    }
    if name == "upper" {
        return self.emit_upper(ctx, target, args);
    }
    if name == "title" {
        return self.emit_title(ctx, target, args);
    }
    if name == "swapcase" {
        return self.emit_swapcase(ctx, target, args);
    }
    if name == "count" {
        return self.emit_count(ctx, target, args);
    }
    if name == "find" {
        return self.emit_find(ctx, target, args);
    }
    if name == "rfind" {
        return self.emit_rfind(ctx, target, args);
    }
    if name == "index" {
        return self.emit_index(ctx, target, args);
    }
    if name == "rindex" {
        return self.emit_rindex(ctx, target, args);
    }
    if name == "startswith" {
        return self.emit_startswith(ctx, target, args);
    }
    if name == "endswith" {
        return self.emit_endswith(ctx, target, args);
    }
    if name == "replace" {
        return self.emit_replace(ctx, target, args);
    }
    if name == "strip" {
        return self.emit_strip(ctx, target, args);
    }
    if name == "lstrip" {
        return self.emit_lstrip(ctx, target, args);
    }
    if name == "rstrip" {
        return self.emit_rstrip(ctx, target, args);
    }
    if name == "removeprefix" {
        return self.emit_removeprefix(ctx, target, args);
    }
    if name == "removesuffix" {
        return self.emit_removesuffix(ctx, target, args);
    }
    if name == "split" {
        return self.emit_split(ctx, target, args);
    }
    if name == "rsplit" {
        return self.emit_rsplit(ctx, target, args);
    }
    if name == "splitlines" {
        return self.emit_splitlines(ctx, target, args);
    }
    if name == "join" {
        return self.emit_join(ctx, target, args);
    }
    if name == "partition" {
        return self.emit_partition(ctx, target, args);
    }
    if name == "rpartition" {
        return self.emit_rpartition(ctx, target, args);
    }
    if name == "format" {
        return self.emit_format(ctx, target, args);
    }
    if name == "format_map" {
        return self.emit_format_map(ctx, target, args);
    }
    if name == "center" {
        return self.emit_center(ctx, target, args);
    }
    if name == "ljust" {
        return self.emit_ljust(ctx, target, args);
    }
    if name == "rjust" {
        return self.emit_rjust(ctx, target, args);
    }
    if name == "zfill" {
        return self.emit_zfill(ctx, target, args);
    }
    if name == "expandtabs" {
        return self.emit_expandtabs(ctx, target, args);
    }
    if name == "isalnum" {
        return self.emit_isalnum(ctx, target, args);
    }
    if name == "isalpha" {
        return self.emit_isalpha(ctx, target, args);
    }
    if name == "isascii" {
        return self.emit_isascii(ctx, target, args);
    }
    if name == "isdecimal" {
        return self.emit_isdecimal(ctx, target, args);
    }
    if name == "isdigit" {
        return self.emit_isdigit(ctx, target, args);
    }
    if name == "isidentifier" {
        return self.emit_isidentifier(ctx, target, args);
    }
    if name == "islower" {
        return self.emit_islower(ctx, target, args);
    }
    if name == "isnumeric" {
        return self.emit_isnumeric(ctx, target, args);
    }
    if name == "isprintable" {
        return self.emit_isprintable(ctx, target, args);
    }
    if name == "isspace" {
        return self.emit_isspace(ctx, target, args);
    }
    if name == "istitle" {
        return self.emit_istitle(ctx, target, args);
    }
    if name == "isupper" {
        return self.emit_isupper(ctx, target, args);
    }
    if name == "encode" {
        return self.emit_encode(ctx, target, args);
    }
    if name == "translate" {
        return self.emit_translate(ctx, target, args);
    }
    if name == "op_add" {
        return self.emit_op_add(ctx, target, args);
    }
    if name == "op_mul" {
        return self.emit_op_mul(ctx, target, args);
    }
    if name == "op_mod" {
        return self.emit_op_mod(ctx, target, args);
    }
    if name == "op_eq" {
        return self.emit_op_eq(ctx, target, args);
    }
    if name == "op_ne" {
        return self.emit_op_ne(ctx, target, args);
    }
    if name == "op_lt" {
        return self.emit_op_lt(ctx, target, args);
    }
    if name == "op_gt" {
        return self.emit_op_gt(ctx, target, args);
    }
    if name == "op_le" {
        return self.emit_op_le(ctx, target, args);
    }
    if name == "op_ge" {
        return self.emit_op_ge(ctx, target, args);
    }
    if name == "op_contains" {
        return self.emit_op_contains(ctx, target, args);
    }
    return None;
}

impl StrEmitter.dispatch_static(
    self: StrEmitter, name: str, ctx: C, args: list[V]
) -> (V | None) {
    if name == "maketrans" {
        return self.emit_maketrans(ctx, args);
    }
    return None;
}

impl BytesEmitter.method_names(self: BytesEmitter) -> list[str] {
    return [
        "decode",
        "hex",
        "count",
        "find",
        "rfind",
        "index",
        "rindex",
        "startswith",
        "endswith",
        "replace",
        "strip",
        "lstrip",
        "rstrip",
        "removeprefix",
        "removesuffix",
        "split",
        "rsplit",
        "splitlines",
        "join",
        "partition",
        "rpartition",
        "capitalize",
        "lower",
        "upper",
        "title",
        "swapcase",
        "isalnum",
        "isalpha",
        "isascii",
        "isdigit",
        "islower",
        "isspace",
        "istitle",
        "isupper",
        "center",
        "ljust",
        "rjust",
        "zfill",
        "expandtabs",
        "translate",
        "op_add",
        "op_mul",
        "op_mod",
        "op_eq",
        "op_ne",
        "op_lt",
        "op_gt",
        "op_le",
        "op_ge",
        "op_contains"
    ];
}

impl BytesEmitter.static_names(self: BytesEmitter) -> list[str] {
    return ["fromhex", "maketrans"];
}

impl BytesEmitter.dispatch(
    self: BytesEmitter, name: str, ctx: C, target: V, args: list[V]
) -> (V | None) {
    if name == "decode" {
        return self.emit_decode(ctx, target, args);
    }
    if name == "hex" {
        return self.emit_hex(ctx, target, args);
    }
    if name == "count" {
        return self.emit_count(ctx, target, args);
    }
    if name == "find" {
        return self.emit_find(ctx, target, args);
    }
    if name == "rfind" {
        return self.emit_rfind(ctx, target, args);
    }
    if name == "index" {
        return self.emit_index(ctx, target, args);
    }
    if name == "rindex" {
        return self.emit_rindex(ctx, target, args);
    }
    if name == "startswith" {
        return self.emit_startswith(ctx, target, args);
    }
    if name == "endswith" {
        return self.emit_endswith(ctx, target, args);
    }
    if name == "replace" {
        return self.emit_replace(ctx, target, args);
    }
    if name == "strip" {
        return self.emit_strip(ctx, target, args);
    }
    if name == "lstrip" {
        return self.emit_lstrip(ctx, target, args);
    }
    if name == "rstrip" {
        return self.emit_rstrip(ctx, target, args);
    }
    if name == "removeprefix" {
        return self.emit_removeprefix(ctx, target, args);
    }
    if name == "removesuffix" {
        return self.emit_removesuffix(ctx, target, args);
    }
    if name == "split" {
        return self.emit_split(ctx, target, args);
    }
    if name == "rsplit" {
        return self.emit_rsplit(ctx, target, args);
    }
    if name == "splitlines" {
        return self.emit_splitlines(ctx, target, args);
    }
    if name == "join" {
        return self.emit_join(ctx, target, args);
    }
    if name == "partition" {
        return self.emit_partition(ctx, target, args);
    }
    if name == "rpartition" {
        return self.emit_rpartition(ctx, target, args);
    }
    if name == "capitalize" {
        return self.emit_capitalize(ctx, target, args);
    }
    if name == "lower" {
        return self.emit_lower(ctx, target, args);
    }
    if name == "upper" {
        return self.emit_upper(ctx, target, args);
    }
    if name == "title" {
        return self.emit_title(ctx, target, args);
    }
    if name == "swapcase" {
        return self.emit_swapcase(ctx, target, args);
    }
    if name == "isalnum" {
        return self.emit_isalnum(ctx, target, args);
    }
    if name == "isalpha" {
        return self.emit_isalpha(ctx, target, args);
    }
    if name == "isascii" {
        return self.emit_isascii(ctx, target, args);
    }
    if name == "isdigit" {
        return self.emit_isdigit(ctx, target, args);
    }
    if name == "islower" {
        return self.emit_islower(ctx, target, args);
    }
    if name == "isspace" {
        return self.emit_isspace(ctx, target, args);
    }
    if name == "istitle" {
        return self.emit_istitle(ctx, target, args);
    }
    if name == "isupper" {
        return self.emit_isupper(ctx, target, args);
    }
    if name == "center" {
        return self.emit_center(ctx, target, args);
    }
    if name == "ljust" {
        return self.emit_ljust(ctx, target, args);
    }
    if name == "rjust" {
        return self.emit_rjust(ctx, target, args);
    }
    if name == "zfill" {
        return self.emit_zfill(ctx, target, args);
    }
    if name == "expandtabs" {
        return self.emit_expandtabs(ctx, target, args);
    }
    if name == "translate" {
        return self.emit_translate(ctx, target, args);
    }
    if name == "op_add" {
        return self.emit_op_add(ctx, target, args);
    }
    if name == "op_mul" {
        return self.emit_op_mul(ctx, target, args);
    }
    if name == "op_mod" {
        return self.emit_op_mod(ctx, target, args);
    }
    if name == "op_eq" {
        return self.emit_op_eq(ctx, target, args);
    }
    if name == "op_ne" {
        return self.emit_op_ne(ctx, target, args);
    }
    if name == "op_lt" {
        return self.emit_op_lt(ctx, target, args);
    }
    if name == "op_gt" {
        return self.emit_op_gt(ctx, target, args);
    }
    if name == "op_le" {
        return self.emit_op_le(ctx, target, args);
    }
    if name == "op_ge" {
        return self.emit_op_ge(ctx, target, args);
    }
    if name == "op_contains" {
        return self.emit_op_contains(ctx, target, args);
    }
    return None;
}

impl BytesEmitter.dispatch_static(
    self: BytesEmitter, name: str, ctx: C, args: list[V]
) -> (V | None) {
    if name == "fromhex" {
        return self.emit_fromhex(ctx, args);
    }
    if name == "maketrans" {
        return self.emit_maketrans(ctx, args);
    }
    return None;
}

impl ListEmitter.method_names(self: ListEmitter) -> list[str] {
    return [
        "append",
        "extend",
        "insert",
        "remove",
        "pop",
        "clear",
        "index",
        "count",
        "sort",
        "reverse",
        "copy",
        "op_add",
        "op_mul",
        "op_eq",
        "op_ne",
        "op_lt",
        "op_gt",
        "op_le",
        "op_ge",
        "op_contains",
        "op_iadd",
        "op_imul"
    ];
}

impl ListEmitter.static_names(self: ListEmitter) -> list[str] {
    return [];
}

impl ListEmitter.dispatch(
    self: ListEmitter, name: str, ctx: C, target: V, args: list[V]
) -> (V | None) {
    if name == "append" {
        return self.emit_append(ctx, target, args);
    }
    if name == "extend" {
        return self.emit_extend(ctx, target, args);
    }
    if name == "insert" {
        return self.emit_insert(ctx, target, args);
    }
    if name == "remove" {
        return self.emit_remove(ctx, target, args);
    }
    if name == "pop" {
        return self.emit_pop(ctx, target, args);
    }
    if name == "clear" {
        return self.emit_clear(ctx, target, args);
    }
    if name == "index" {
        return self.emit_index(ctx, target, args);
    }
    if name == "count" {
        return self.emit_count(ctx, target, args);
    }
    if name == "sort" {
        return self.emit_sort(ctx, target, args);
    }
    if name == "reverse" {
        return self.emit_reverse(ctx, target, args);
    }
    if name == "copy" {
        return self.emit_copy(ctx, target, args);
    }
    if name == "op_add" {
        return self.emit_op_add(ctx, target, args);
    }
    if name == "op_mul" {
        return self.emit_op_mul(ctx, target, args);
    }
    if name == "op_eq" {
        return self.emit_op_eq(ctx, target, args);
    }
    if name == "op_ne" {
        return self.emit_op_ne(ctx, target, args);
    }
    if name == "op_lt" {
        return self.emit_op_lt(ctx, target, args);
    }
    if name == "op_gt" {
        return self.emit_op_gt(ctx, target, args);
    }
    if name == "op_le" {
        return self.emit_op_le(ctx, target, args);
    }
    if name == "op_ge" {
        return self.emit_op_ge(ctx, target, args);
    }
    if name == "op_contains" {
        return self.emit_op_contains(ctx, target, args);
    }
    if name == "op_iadd" {
        return self.emit_op_iadd(ctx, target, args);
    }
    if name == "op_imul" {
        return self.emit_op_imul(ctx, target, args);
    }
    return None;
}

impl ListEmitter.dispatch_static(
    self: ListEmitter, name: str, ctx: C, args: list[V]
) -> (V | None) {
    return None;
}

impl DictEmitter.method_names(self: DictEmitter) -> list[str] {
    return [
        "get",
        "keys",
        "values",
        "items",
        "pop",
        "popitem",
        "setdefault",
        "update",
        "clear",
        "copy",
        "op_or",
        "op_eq",
        "op_ne",
        "op_contains",
        "op_ior"
    ];
}

impl DictEmitter.static_names(self: DictEmitter) -> list[str] {
    return ["fromkeys"];
}

impl DictEmitter.dispatch(
    self: DictEmitter, name: str, ctx: C, target: V, args: list[V]
) -> (V | None) {
    if name == "get" {
        return self.emit_get(ctx, target, args);
    }
    if name == "keys" {
        return self.emit_keys(ctx, target, args);
    }
    if name == "values" {
        return self.emit_values(ctx, target, args);
    }
    if name == "items" {
        return self.emit_items(ctx, target, args);
    }
    if name == "pop" {
        return self.emit_pop(ctx, target, args);
    }
    if name == "popitem" {
        return self.emit_popitem(ctx, target, args);
    }
    if name == "setdefault" {
        return self.emit_setdefault(ctx, target, args);
    }
    if name == "update" {
        return self.emit_update(ctx, target, args);
    }
    if name == "clear" {
        return self.emit_clear(ctx, target, args);
    }
    if name == "copy" {
        return self.emit_copy(ctx, target, args);
    }
    if name == "op_or" {
        return self.emit_op_or(ctx, target, args);
    }
    if name == "op_eq" {
        return self.emit_op_eq(ctx, target, args);
    }
    if name == "op_ne" {
        return self.emit_op_ne(ctx, target, args);
    }
    if name == "op_contains" {
        return self.emit_op_contains(ctx, target, args);
    }
    if name == "op_ior" {
        return self.emit_op_ior(ctx, target, args);
    }
    return None;
}

impl DictEmitter.dispatch_static(
    self: DictEmitter, name: str, ctx: C, args: list[V]
) -> (V | None) {
    if name == "fromkeys" {
        return self.emit_fromkeys(ctx, args);
    }
    return None;
}

impl SetEmitter.method_names(self: SetEmitter) -> list[str] {
    return [
        "add",
        "remove",
        "discard",
        "pop",
        "clear",
        "union",
        "intersection",
        "difference",
        "symmetric_difference",
        "update",
        "intersection_update",
        "difference_update",
        "symmetric_difference_update",
        "issubset",
        "issuperset",
        "isdisjoint",
        "copy",
        "op_or",
        "op_and",
        "op_sub",
        "op_xor",
        "op_eq",
        "op_ne",
        "op_le",
        "op_lt",
        "op_ge",
        "op_gt",
        "op_contains",
        "op_ior",
        "op_iand",
        "op_isub",
        "op_ixor"
    ];
}

impl SetEmitter.static_names(self: SetEmitter) -> list[str] {
    return [];
}

impl SetEmitter.dispatch(
    self: SetEmitter, name: str, ctx: C, target: V, args: list[V]
) -> (V | None) {
    if name == "add" {
        return self.emit_add(ctx, target, args);
    }
    if name == "remove" {
        return self.emit_remove(ctx, target, args);
    }
    if name == "discard" {
        return self.emit_discard(ctx, target, args);
    }
    if name == "pop" {
        return self.emit_pop(ctx, target, args);
    }
    if name == "clear" {
        return self.emit_clear(ctx, target, args);
    }
    if name == "union" {
        return self.emit_union(ctx, target, args);
    }
    if name == "intersection" {
        return self.emit_intersection(ctx, target, args);
    }
    if name == "difference" {
        return self.emit_difference(ctx, target, args);
    }
    if name == "symmetric_difference" {
        return self.emit_symmetric_difference(ctx, target, args);
    }
    if name == "update" {
        return self.emit_update(ctx, target, args);
    }
    if name == "intersection_update" {
        return self.emit_intersection_update(ctx, target, args);
    }
    if name == "difference_update" {
        return self.emit_difference_update(ctx, target, args);
    }
    if name == "symmetric_difference_update" {
        return self.emit_symmetric_difference_update(ctx, target, args);
    }
    if name == "issubset" {
        return self.emit_issubset(ctx, target, args);
    }
    if name == "issuperset" {
        return self.emit_issuperset(ctx, target, args);
    }
    if name == "isdisjoint" {
        return self.emit_isdisjoint(ctx, target, args);
    }
    if name == "copy" {
        return self.emit_copy(ctx, target, args);
    }
    if name == "op_or" {
        return self.emit_op_or(ctx, target, args);
    }
    if name == "op_and" {
        return self.emit_op_and(ctx, target, args);
    }
    if name == "op_sub" {
        return self.emit_op_sub(ctx, target, args);
    }
    if name == "op_xor" {
        return self.emit_op_xor(ctx, target, args);
    }
    if name == "op_eq" {
        return self.emit_op_eq(ctx, target, args);
    }
    if name == "op_ne" {
        return self.emit_op_ne(ctx, target, args);
    }
    if name == "op_le" {
        return self.emit_op_le(ctx, target, args);
    }
    if name == "op_lt" {
        return self.emit_op_lt(ctx, target, args);
    }
    if name == "op_ge" {
        return self.emit_op_ge(ctx, target, args);
    }
    if name == "op_gt" {
        return self.emit_op_gt(ctx, target, args);
    }
    if name == "op_contains" {
        return self.emit_op_contains(ctx, target, args);
    }
    if name == "op_ior" {
        return self.emit_op_ior(ctx, target, args);
    }
    if name == "op_iand" {
        return self.emit_op_iand(ctx, target, args);
    }
    if name == "op_isub" {
        return self.emit_op_isub(ctx, target, args);
    }
    if name == "op_ixor" {
        return self.emit_op_ixor(ctx, target, args);
    }
    return None;
}

impl SetEmitter.dispatch_static(
    self: SetEmitter, name: str, ctx: C, args: list[V]
) -> (V | None) {
    return None;
}

impl FrozensetEmitter.method_names(self: FrozensetEmitter) -> list[str] {
    return [
        "union",
        "intersection",
        "difference",
        "symmetric_difference",
        "issubset",
        "issuperset",
        "isdisjoint",
        "copy",
        "op_or",
        "op_and",
        "op_sub",
        "op_xor",
        "op_eq",
        "op_ne",
        "op_le",
        "op_lt",
        "op_ge",
        "op_gt",
        "op_contains"
    ];
}

impl FrozensetEmitter.static_names(self: FrozensetEmitter) -> list[str] {
    return [];
}

impl FrozensetEmitter.dispatch(
    self: FrozensetEmitter, name: str, ctx: C, target: V, args: list[V]
) -> (V | None) {
    if name == "union" {
        return self.emit_union(ctx, target, args);
    }
    if name == "intersection" {
        return self.emit_intersection(ctx, target, args);
    }
    if name == "difference" {
        return self.emit_difference(ctx, target, args);
    }
    if name == "symmetric_difference" {
        return self.emit_symmetric_difference(ctx, target, args);
    }
    if name == "issubset" {
        return self.emit_issubset(ctx, target, args);
    }
    if name == "issuperset" {
        return self.emit_issuperset(ctx, target, args);
    }
    if name == "isdisjoint" {
        return self.emit_isdisjoint(ctx, target, args);
    }
    if name == "copy" {
        return self.emit_copy(ctx, target, args);
    }
    if name == "op_or" {
        return self.emit_op_or(ctx, target, args);
    }
    if name == "op_and" {
        return self.emit_op_and(ctx, target, args);
    }
    if name == "op_sub" {
        return self.emit_op_sub(ctx, target, args);
    }
    if name == "op_xor" {
        return self.emit_op_xor(ctx, target, args);
    }
    if name == "op_eq" {
        return self.emit_op_eq(ctx, target, args);
    }
    if name == "op_ne" {
        return self.emit_op_ne(ctx, target, args);
    }
    if name == "op_le" {
        return self.emit_op_le(ctx, target, args);
    }
    if name == "op_lt" {
        return self.emit_op_lt(ctx, target, args);
    }
    if name == "op_ge" {
        return self.emit_op_ge(ctx, target, args);
    }
    if name == "op_gt" {
        return self.emit_op_gt(ctx, target, args);
    }
    if name == "op_contains" {
        return self.emit_op_contains(ctx, target, args);
    }
    return None;
}

impl FrozensetEmitter.dispatch_static(
    self: FrozensetEmitter, name: str, ctx: C, args: list[V]
) -> (V | None) {
    return None;
}

impl TupleEmitter.method_names(self: TupleEmitter) -> list[str] {
    return [
        "count",
        "index",
        "op_add",
        "op_mul",
        "op_eq",
        "op_ne",
        "op_lt",
        "op_gt",
        "op_le",
        "op_ge",
        "op_contains"
    ];
}

impl TupleEmitter.static_names(self: TupleEmitter) -> list[str] {
    return [];
}

impl TupleEmitter.dispatch(
    self: TupleEmitter, name: str, ctx: C, target: V, args: list[V]
) -> (V | None) {
    if name == "count" {
        return self.emit_count(ctx, target, args);
    }
    if name == "index" {
        return self.emit_index(ctx, target, args);
    }
    if name == "op_add" {
        return self.emit_op_add(ctx, target, args);
    }
    if name == "op_mul" {
        return self.emit_op_mul(ctx, target, args);
    }
    if name == "op_eq" {
        return self.emit_op_eq(ctx, target, args);
    }
    if name == "op_ne" {
        return self.emit_op_ne(ctx, target, args);
    }
    if name == "op_lt" {
        return self.emit_op_lt(ctx, target, args);
    }
    if name == "op_gt" {
        return self.emit_op_gt(ctx, target, args);
    }
    if name == "op_le" {
        return self.emit_op_le(ctx, target, args);
    }
    if name == "op_ge" {
        return self.emit_op_ge(ctx, target, args);
    }
    if name == "op_contains" {
        return self.emit_op_contains(ctx, target, args);
    }
    return None;
}

impl TupleEmitter.dispatch_static(
    self: TupleEmitter, name: str, ctx: C, args: list[V]
) -> (V | None) {
    return None;
}

impl RangeEmitter.method_names(self: RangeEmitter) -> list[str] {
    return ["count", "index", "op_eq", "op_ne", "op_contains"];
}

impl RangeEmitter.static_names(self: RangeEmitter) -> list[str] {
    return [];
}

impl RangeEmitter.dispatch(
    self: RangeEmitter, name: str, ctx: C, target: V, args: list[V]
) -> (V | None) {
    if name == "count" {
        return self.emit_count(ctx, target, args);
    }
    if name == "index" {
        return self.emit_index(ctx, target, args);
    }
    if name == "op_eq" {
        return self.emit_op_eq(ctx, target, args);
    }
    if name == "op_ne" {
        return self.emit_op_ne(ctx, target, args);
    }
    if name == "op_contains" {
        return self.emit_op_contains(ctx, target, args);
    }
    return None;
}

impl RangeEmitter.dispatch_static(
    self: RangeEmitter, name: str, ctx: C, args: list[V]
) -> (V | None) {
    return None;
}

impl BuiltinEmitter.method_names(self: BuiltinEmitter) -> list[str] {
    return [];
}

impl BuiltinEmitter.static_names(self: BuiltinEmitter) -> list[str] {
    return [
        "print",
        "input",
        "len",
        "abs",
        "round",
        "min",
        "max",
        "sum",
        "sorted",
        "reversed",
        "enumerate",
        "zip",
        "map",
        "filter",
        "any",
        "all",
        "isinstance",
        "issubclass",
        "type",
        "id",
        "hash",
        "repr",
        "chr",
        "ord",
        "hex",
        "oct",
        "bin",
        "pow",
        "divmod",
        "iter",
        "next",
        "callable",
        "getattr",
        "setattr",
        "hasattr",
        "delattr",
        "vars",
        "dir",
        "open",
        "format",
        "ascii",
        "str",
        "int",
        "float",
        "bool",
        "list",
        "dict",
        "set",
        "tuple",
        "frozenset",
        "bytes",
        "complex",
        "range",
        "slice",
        "bytearray"
    ];
}

impl BuiltinEmitter.dispatch(
    self: BuiltinEmitter, name: str, ctx: C, target: V, args: list[V]
) -> (V | None) {
    return None;
}

impl BuiltinEmitter.dispatch_static(
    self: BuiltinEmitter, name: str, ctx: C, args: list[V]
) -> (V | None) {
    if name == "print" {
        return self.emit_print(ctx, args);
    }
    if name == "input" {
        return self.emit_input(ctx, args);
    }
    if name == "len" {
        return self.emit_len(ctx, args);
    }
    if name == "abs" {
        return self.emit_abs(ctx, args);
    }
    if name == "round" {
        return self.emit_round(ctx, args);
    }
    if name == "min" {
        return self.emit_min(ctx, args);
    }
    if name == "max" {
        return self.emit_max(ctx, args);
    }
    if name == "sum" {
        return self.emit_sum(ctx, args);
    }
    if name == "sorted" {
        return self.emit_sorted(ctx, args);
    }
    if name == "reversed" {
        return self.emit_reversed(ctx, args);
    }
    if name == "enumerate" {
        return self.emit_enumerate(ctx, args);
    }
    if name == "zip" {
        return self.emit_zip(ctx, args);
    }
    if name == "map" {
        return self.emit_map(ctx, args);
    }
    if name == "filter" {
        return self.emit_filter(ctx, args);
    }
    if name == "any" {
        return self.emit_any(ctx, args);
    }
    if name == "all" {
        return self.emit_all(ctx, args);
    }
    if name == "isinstance" {
        return self.emit_isinstance(ctx, args);
    }
    if name == "issubclass" {
        return self.emit_issubclass(ctx, args);
    }
    if name == "type" {
        return self.emit_type(ctx, args);
    }
    if name == "id" {
        return self.emit_id(ctx, args);
    }
    if name == "hash" {
        return self.emit_hash(ctx, args);
    }
    if name == "repr" {
        return self.emit_repr(ctx, args);
    }
    if name == "chr" {
        return self.emit_chr(ctx, args);
    }
    if name == "ord" {
        return self.emit_ord(ctx, args);
    }
    if name == "hex" {
        return self.emit_hex(ctx, args);
    }
    if name == "oct" {
        return self.emit_oct(ctx, args);
    }
    if name == "bin" {
        return self.emit_bin(ctx, args);
    }
    if name == "pow" {
        return self.emit_pow(ctx, args);
    }
    if name == "divmod" {
        return self.emit_divmod(ctx, args);
    }
    if name == "iter" {
        return self.emit_iter(ctx, args);
    }
    if name == "next" {
        return self.emit_next(ctx, args);
    }
    if name == "callable" {
        return self.emit_callable(ctx, args);
    }
    if name == "getattr" {
        return self.emit_getattr(ctx, args);
    }
    if name == "setattr" {
        return self.emit_setattr(ctx, args);
    }
    if name == "hasattr" {
        return self.emit_hasattr(ctx, args);
    }
    if name == "delattr" {
        return self.emit_delattr(ctx, args);
    }
    if name == "vars" {
        return self.emit_vars(ctx, args);
    }
    if name == "dir" {
        return self.emit_dir(ctx, args);
    }
    if name == "open" {
        return self.emit_open(ctx, args);
    }
    if name == "format" {
        return self.emit_format(ctx, args);
    }
    if name == "ascii" {
        return self.emit_ascii(ctx, args);
    }
    if name == "str" {
        return self.emit_str(ctx, args);
    }
    if name == "int" {
        return self.emit_int(ctx, args);
    }
    if name == "float" {
        return self.emit_float(ctx, args);
    }
    if name == "bool" {
        return self.emit_bool(ctx, args);
    }
    if name == "list" {
        return self.emit_list(ctx, args);
    }
    if name == "dict" {
        return self.emit_dict(ctx, args);
    }
    if name == "set" {
        return self.emit_set(ctx, args);
    }
    if name == "tuple" {
        return self.emit_tuple(ctx, args);
    }
    if name == "frozenset" {
        return self.emit_frozenset(ctx, args);
    }
    if name == "bytes" {
        return self.emit_bytes(ctx, args);
    }
    if name == "complex" {
        return self.emit_complex(ctx, args);
    }
    if name == "range" {
        return self.emit_range(ctx, args);
    }
    if name == "slice" {
        return self.emit_slice(ctx, args);
    }
    if name == "bytearray" {
        return self.emit_bytearray(ctx, args);
    }
    return None;
}
