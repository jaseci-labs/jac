obj NativeEmitCtx {
    has pass_ref: NaIRGenPass,
        type_key: str = "",
        call_kwargs: dict[str, UniNode] = {},
        arg_nodes: list[UniNode] = [],
        call_node: UniNode | None = None,
        receiver_node: UniNode | None = None;
}


def get_builder(p: NaIRGenPass) -> ir.IRBuilder;


class NativeIntEmitter(IntEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_bit_length(
        self: NativeIntEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_bit_count(
        self: NativeIntEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_to_bytes(
        self: NativeIntEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_as_integer_ratio(
        self: NativeIntEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_conjugate(
        self: NativeIntEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_from_bytes(
        self: NativeIntEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeFloatEmitter(FloatEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_is_integer(
        self: NativeFloatEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_as_integer_ratio(
        self: NativeFloatEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_conjugate(
        self: NativeFloatEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_hex(
        self: NativeFloatEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_fromhex(
        self: NativeFloatEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeBoolEmitter(NativeIntEmitter) {
    def emit_op_and(
        self: NativeBoolEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_or(
        self: NativeBoolEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_xor(
        self: NativeBoolEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeComplexEmitter(ComplexEmitter[(ir.Value, NativeEmitCtx)]) {
    def _load_parts(
        self: NativeComplexEmitter, ctx: NativeEmitCtx, val: ir.Value
    ) -> (tuple[ir.Value, ir.Value] | None);

    def _make_complex(
        self: NativeComplexEmitter, ctx: NativeEmitCtx, real: ir.Value, imag: ir.Value
    ) -> ir.Value;

    def emit_conjugate(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_add(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_sub(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_mul(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_truediv(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_pow(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_eq(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_ne(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_neg(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_pos(
        self: NativeComplexEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeStrEmitter(StrEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_capitalize(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_casefold(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_lower(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_upper(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def _emit_case_transform(
        self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, cfunc_name: str
    ) -> (ir.Value | None);

    def emit_title(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_swapcase(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_count(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_find(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rfind(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_index(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rindex(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def _emit_affix(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value],
        suffix: bool
    ) -> (ir.Value | None);

    def emit_startswith(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_endswith(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_replace(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_strip(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_lstrip(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rstrip(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_removeprefix(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_removesuffix(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_split(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rsplit(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_splitlines(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_join(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_partition(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rpartition(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_format(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_format_map(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_center(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_ljust(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rjust(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_zfill(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_expandtabs(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def _emit_char_test(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        cfunc_name: str,
        prefix: str,
        empty_is_true: bool = False
    ) -> (ir.Value | None);

    def emit_isalnum(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isalpha(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isascii(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isdecimal(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isdigit(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isidentifier(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_islower(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isnumeric(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isprintable(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isspace(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_istitle(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isupper(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_encode(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_decode(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_translate(
        self: NativeStrEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_maketrans(
        self: NativeStrEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeBytesEmitter(BytesEmitter[(ir.Value, NativeEmitCtx)]) {
    def _kernel_call(
        self: NativeBytesEmitter, ctx: NativeEmitCtx, name: str, values: list[ir.Value]
    ) -> (ir.Value | None);

    def _optional_bytes(
        self: NativeBytesEmitter, ctx: NativeEmitCtx, arg: ir.Value, target: ir.Value
    ) -> (tuple[ir.Value, ir.Value] | None);

    def _emit_strip(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value],
        which: int
    ) -> (ir.Value | None);

    def emit_decode(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_hex(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_fromhex(
        self: NativeBytesEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_count(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_find(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rfind(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_index(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rindex(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_startswith(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_endswith(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def _emit_affix(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value],
        suffix: bool
    ) -> (ir.Value | None);

    def emit_replace(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_strip(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_lstrip(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rstrip(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_removeprefix(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_removesuffix(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_split(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rsplit(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_splitlines(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_join(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_partition(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rpartition(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_capitalize(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_lower(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_upper(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_title(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_swapcase(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isalnum(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isalpha(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isascii(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isdigit(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_islower(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isspace(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_istitle(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isupper(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_center(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_ljust(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_rjust(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_zfill(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_expandtabs(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_translate(
        self: NativeBytesEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_maketrans(
        self: NativeBytesEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeListEmitter(ListEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_append(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_extend(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_insert(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_remove(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_pop(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def _emit_aos_pop(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value],
        elem_struct: ir.Type
    ) -> ir.Value;

    def _emit_aos_del_at(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        del_idx: ir.Value,
        elem_struct: ir.Type
    ) -> ir.Value;

    def _emit_aos_insert(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        insert_idx: ir.Value,
        insert_val: ir.Value,
        elem_struct: ir.Type
    ) -> ir.Value;

    def emit_del_at(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_clear(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_index(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_count(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_sort(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def _emit_value_sort(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        reverse: (ir.Value | None)
    ) -> (ir.Value | None);

    def _emit_key_sort(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        key_fn: ir.Function,
        reverse: (ir.Value | None),
        key_node: UniNode
    ) -> (ir.Value | None);

    def emit_reverse(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_copy(
        self: NativeListEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeDictEmitter(DictEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_get(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_keys(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_values(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_items(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_pop(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_remove(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_popitem(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_setdefault(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_update(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_clear(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_copy(
        self: NativeDictEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_fromkeys(
        self: NativeDictEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeSetEmitter(SetEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_add(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_remove(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_discard(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_pop(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_clear(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_union(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_intersection(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_difference(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_symmetric_difference(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_update(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_intersection_update(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_difference_update(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_symmetric_difference_update(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def _emit_set_elem_loop(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        src_set: ir.Value,
        prefix: str,
        body_cb: Callable[[ir.IRBuilder, ir.Value], None]
    ) -> None;

    def _emit_set_relation(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        iter_set: ir.Value,
        probe_set: ir.Value,
        prefix: str,
        chk: str,
        exit_on_hit: bool
    ) -> (ir.Value | None);

    def emit_issubset(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_issuperset(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isdisjoint(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_copy(
        self: NativeSetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeFrozensetEmitter(FrozensetEmitter[(ir.Value, NativeEmitCtx)]) {
    def _get_set_emitter(
        self: NativeFrozensetEmitter, ctx: NativeEmitCtx
    ) -> (NativeSetEmitter | None);

    def emit_union(
        self: NativeFrozensetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_intersection(
        self: NativeFrozensetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_difference(
        self: NativeFrozensetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_symmetric_difference(
        self: NativeFrozensetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_issubset(
        self: NativeFrozensetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_issuperset(
        self: NativeFrozensetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isdisjoint(
        self: NativeFrozensetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_copy(
        self: NativeFrozensetEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeTupleEmitter(TupleEmitter[(ir.Value, NativeEmitCtx)]) {
    def _get_struct_info(
        self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value
    ) -> (ir.LiteralStructType | None);

    def emit_count(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_index(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_add(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_mul(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_eq(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_ne(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_lt(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_gt(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_le(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_ge(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_contains(
        self: NativeTupleEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeRangeEmitter(RangeEmitter[(ir.Value, NativeEmitCtx)]) {
    def _load_range(
        self: NativeRangeEmitter, ctx: NativeEmitCtx, target: ir.Value
    ) -> (tuple[ir.Value, ir.Value, ir.Value] | None);

    def _in_range(
        self: NativeRangeEmitter,
        ctx: NativeEmitCtx,
        val: ir.Value,
        start: ir.Value,
        stop: ir.Value,
        step: ir.Value
    ) -> ir.Value;

    def emit_count(
        self: NativeRangeEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_index(
        self: NativeRangeEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_eq(
        self: NativeRangeEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_ne(
        self: NativeRangeEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_op_contains(
        self: NativeRangeEmitter,
        ctx: NativeEmitCtx,
        target: ir.Value,
        args: list[ir.Value]
    ) -> (ir.Value | None);
}


class NativeBuiltinEmitter(BuiltinEmitter[(ir.Value, NativeEmitCtx)]) {
    def emit_print(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_input(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_len(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_abs(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_round(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_min(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_max(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def _emit_extreme(
        self: NativeBuiltinEmitter,
        ctx: NativeEmitCtx,
        args: list[ir.Value],
        op: str,
        name: str
    ) -> (ir.Value | None);

    def emit_sum(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_sorted(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_reversed(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_enumerate(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_zip(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_map(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_filter(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_any(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_all(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_isinstance(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_issubclass(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_type(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_id(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_hash(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_repr(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_chr(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_ord(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def code_point_fn(self: NativeBuiltinEmitter, p: NaIRGenPass) -> ir.Function;
    def emit_hex(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_oct(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_bin(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_pow(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_pow_mod(
        self: NativeBuiltinEmitter,
        ctx: NativeEmitCtx,
        base: ir.Value,
        exp: ir.Value,
        mod: ir.Value
    ) -> (ir.Value | None);

    def emit_divmod(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_iter(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_next(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_callable(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_getattr(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_setattr(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_hasattr(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_delattr(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_vars(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_dir(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_open(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_format(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_ascii(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_str(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_int(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def _int_from_c_string(
        self: NativeBuiltinEmitter,
        ctx: NativeEmitCtx,
        text: ir.Value,
        base: (ir.Value | None) = None
    ) -> ir.Value;

    def _int_from_boxed(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, boxed: ir.Value
    ) -> ir.Value;

    def emit_float(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_bool(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_list(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_dict(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_set(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_tuple(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_frozenset(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_bytes(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_bytearray(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);

    def emit_complex(
        self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
    ) -> (ir.Value | None);
}
