class IntEmitter[V, C] {
    def emit_bit_length(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_bit_count(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_to_bytes(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_as_integer_ratio(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_conjugate(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_from_bytes(self: IntEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_op_add(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_sub(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_mul(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_truediv(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_floordiv(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_mod(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_pow(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_and(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_or(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_xor(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_lshift(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_rshift(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_eq(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ne(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_lt(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_gt(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_le(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ge(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_neg(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_pos(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_invert(
        self: IntEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;
}

class FloatEmitter[V, C] {
    def emit_is_integer(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_as_integer_ratio(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_conjugate(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_hex(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_fromhex(self: FloatEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_op_add(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_sub(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_mul(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_truediv(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_floordiv(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_mod(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_pow(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_eq(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ne(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_lt(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_gt(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_le(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ge(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_neg(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_pos(
        self: FloatEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;
}

class ComplexEmitter[V, C] {
    def emit_conjugate(
        self: ComplexEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_add(
        self: ComplexEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_sub(
        self: ComplexEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_mul(
        self: ComplexEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_truediv(
        self: ComplexEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_pow(
        self: ComplexEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_eq(
        self: ComplexEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ne(
        self: ComplexEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_neg(
        self: ComplexEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_pos(
        self: ComplexEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;
}

class StrEmitter[V, C] {
    def emit_capitalize(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_casefold(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_lower(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_upper(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_title(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_swapcase(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_count(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_find(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_rfind(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_index(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_rindex(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_startswith(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_endswith(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_replace(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_strip(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_lstrip(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_rstrip(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_removeprefix(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_removesuffix(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_split(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_rsplit(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_splitlines(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_join(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_partition(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_rpartition(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_format(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_format_map(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_center(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_ljust(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_rjust(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_zfill(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_expandtabs(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isalnum(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isalpha(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isascii(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isdecimal(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isdigit(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isidentifier(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_islower(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isnumeric(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isprintable(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isspace(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_istitle(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isupper(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_encode(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_translate(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_maketrans(self: StrEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_op_add(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_mul(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_mod(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_eq(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ne(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_lt(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_gt(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_le(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ge(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_contains(
        self: StrEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;
}

class BytesEmitter[V, C] {
    def emit_decode(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_hex(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_fromhex(self: BytesEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_count(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_find(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_rfind(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_index(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_rindex(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_startswith(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_endswith(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_replace(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_strip(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_lstrip(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_rstrip(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_removeprefix(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_removesuffix(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_split(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_rsplit(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_splitlines(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_join(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_partition(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_rpartition(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_capitalize(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_lower(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_upper(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_title(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_swapcase(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isalnum(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isalpha(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isascii(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isdigit(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_islower(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isspace(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_istitle(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isupper(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_center(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_ljust(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_rjust(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_zfill(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_expandtabs(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_translate(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_maketrans(self: BytesEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_op_add(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_mul(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_mod(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_eq(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ne(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_lt(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_gt(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_le(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ge(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_contains(
        self: BytesEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;
}

class ListEmitter[V, C] {
    def emit_append(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_extend(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_insert(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_remove(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_pop(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_clear(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_index(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_count(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_sort(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_reverse(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_copy(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_add(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_mul(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_eq(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ne(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_lt(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_gt(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_le(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ge(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_contains(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_iadd(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_imul(
        self: ListEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;
}

class DictEmitter[V, C] {
    def emit_get(
        self: DictEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_keys(
        self: DictEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_values(
        self: DictEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_items(
        self: DictEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_pop(
        self: DictEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_popitem(
        self: DictEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_setdefault(
        self: DictEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_update(
        self: DictEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_clear(
        self: DictEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_copy(
        self: DictEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_fromkeys(self: DictEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_op_or(
        self: DictEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_eq(
        self: DictEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ne(
        self: DictEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_contains(
        self: DictEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ior(
        self: DictEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;
}

class SetEmitter[V, C] {
    def emit_add(self: SetEmitter, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_remove(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_discard(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_pop(self: SetEmitter, ctx: C, target: V, args: list[V]) -> (V | None) abs;
    def emit_clear(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_union(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_intersection(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_difference(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_symmetric_difference(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_update(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_intersection_update(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_difference_update(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_symmetric_difference_update(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_issubset(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_issuperset(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isdisjoint(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_copy(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_or(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_and(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_sub(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_xor(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_eq(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ne(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_le(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_lt(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ge(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_gt(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_contains(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ior(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_iand(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_isub(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ixor(
        self: SetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;
}

class FrozensetEmitter[V, C] {
    def emit_union(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_intersection(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_difference(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_symmetric_difference(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_issubset(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_issuperset(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_isdisjoint(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_copy(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_or(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_and(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_sub(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_xor(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_eq(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ne(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_le(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_lt(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ge(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_gt(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_contains(
        self: FrozensetEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;
}

class TupleEmitter[V, C] {
    def emit_count(
        self: TupleEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_index(
        self: TupleEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_add(
        self: TupleEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_mul(
        self: TupleEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_eq(
        self: TupleEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ne(
        self: TupleEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_lt(
        self: TupleEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_gt(
        self: TupleEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_le(
        self: TupleEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ge(
        self: TupleEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_contains(
        self: TupleEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;
}

class RangeEmitter[V, C] {
    def emit_count(
        self: RangeEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_index(
        self: RangeEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_eq(
        self: RangeEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_ne(
        self: RangeEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_op_contains(
        self: RangeEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;
}

class BuiltinEmitter[V, C] {
    def emit_print(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_input(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_len(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_abs(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_round(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_min(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_max(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_sum(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_sorted(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_reversed(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_enumerate(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_zip(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_map(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_filter(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_any(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_all(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_isinstance(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_issubclass(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_type(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_id(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_hash(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_repr(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_chr(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_ord(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_hex(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_oct(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_bin(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_pow(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_divmod(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_iter(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_next(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_callable(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_getattr(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_setattr(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_hasattr(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_delattr(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_vars(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_dir(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_open(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_format(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_ascii(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_str(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_int(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_float(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_bool(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_list(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_dict(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_set(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_tuple(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_frozenset(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_bytes(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_complex(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_range(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_slice(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
    def emit_bytearray(self: BuiltinEmitter, ctx: C, args: list[V]) -> (V | None) abs;
}

class ExceptionEmitter[V, C] {
    def emit_create(
        self: ExceptionEmitter, ctx: C, type_name: str, args: list[V]
    ) -> (V | None) abs;

    def emit_match(
        self: ExceptionEmitter, ctx: C, exc_obj: V, type_name: str
    ) -> (V | None) abs;

    def emit_raise(self: ExceptionEmitter, ctx: C, exc_obj: V) -> (V | None) abs;
    def emit_reraise(self: ExceptionEmitter, ctx: C) -> (V | None) abs;
    def emit_raise_from(
        self: ExceptionEmitter, ctx: C, exc_obj: V, cause_obj: V
    ) -> (V | None) abs;

    def emit_get_message(
        self: ExceptionEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_get_args(
        self: ExceptionEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_get_cause(
        self: ExceptionEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_get_context(
        self: ExceptionEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_get_traceback(
        self: ExceptionEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_with_traceback(
        self: ExceptionEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_str(
        self: ExceptionEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;

    def emit_repr(
        self: ExceptionEmitter, ctx: C, target: V, args: list[V]
    ) -> (V | None) abs;
}
