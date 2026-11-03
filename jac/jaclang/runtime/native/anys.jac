import from c {
    def strlen(p: ptr[u8]) -> i64;  def strcmp(a: ptr[u8], b: ptr[u8]) -> i32;  def malloc(
        n: int
    ) -> int;  def calloc(n: int, size: int) -> int;  def free(p: int) -> None;
}

glob ANY_TAG_INT: int = 0,
     ANY_TAG_FLOAT: int = 1,
     ANY_TAG_STR: int = 2,
     ANY_TAG_LIST: int = 3,
     ANY_TAG_DICT: int = 4,
     ANY_TAG_SET: int = 5,
     ANY_TAG_OBJ: int = 6,
     ANY_TAG_BOOL: int = 7,
     ANY_TAG_NONE: int = 8,
     ANY_TAG_ENUM: int = 9,
     ANY_TAG_ELLIPSIS: int = 10,
     LIST_LEN: int = 0,
     HDR_TAG_BACK: int = 24,
     ANY_TAG_FIRST_REF: int = 2,
     ANY_TAG_LAST_REF: int = 6,
     BOX_TAG: int = 0,
     BOX_PAYLOAD: int = 8,
     BOX_SIZE: int = 16,
     HDR_DTOR_BACK: int = 8,
     HDR_TOTAL: int = 32;

def:pub __jac_rt_any_retain(tag: int, payload: int);

def:pub __jac_rt_any_release(tag: int, payload: int);

def:pub __jac_rt_any_drop(tag: int, payload: int);

def:pub __jac_rt_any_box(tag: int, payload: int) -> int;

def:pub __jac_rt_any_box_hold(box: int);

def:pub __jac_rt_any_truthy(tag: int, payload: int) -> bool;

def:pub __jac_rt_any_len(tag: int, payload: int) -> int;

def _is_buffer(tag: int, payload: int) -> bool;

def:pub __jac_rt_any_str(tag: int, payload: int) -> ptr[u8];

def:pub __jac_rt_type_name(o: int) -> ptr[u8];

def:pub __jac_rt_any_type_name(tag: int, payload: int) -> ptr[u8];

def:pub __jac_rt_any_isa(tag: int, payload: int, name: ptr[u8]) -> bool;

def:pub __jac_rt_cstr_eq(a: ptr[u8], b: ptr[u8]) -> bool;

def:pub __jac_rt_str_from_cstr(text: ptr[u8]) -> ptr[u8];

def:pub __jac_rt_class_name(text: ptr[u8]) -> ptr[u8];

def _holds_ref(tag: int) -> bool;

def _box_drop(box: ptr[u8]);

glob KIND_INT: int = 0,
     KIND_FLOAT: int = 1,
     KIND_BOOL: int = 2,
     KIND_STR: int = 3,
     KIND_REF: int = 4,
     KIND_TUPLE: int = 5,
     KIND_ANY: int = 6,
     KIND_UINT: int = 7,
     KIND_NULL: int = 8,
     LIST_DATA: int = 16,
     LIST_KIND: int = 24,
     DICT_KEY_KIND: int = 56,
     DICT_VAL_KIND: int = 64,
     DICT_LEN_AT: int = 0,
     TUPLE_KINDS: int = 8,
     BYTES_DATA: int = 8,
     BYTEARRAY_DATA: int = 16,
     SLOT: int = 8,
     WALK_COLL: int = 0,
     WALK_INDEX: int = 8,
     WALK_MODE: int = 16,
     WALK_SIZE: int = 24,
     WALK_LIST: int = 0,
     WALK_KEYS: int = 1,
     WALK_TUPLE: int = 2,
     WALK_STR: int = 3,
     WALK_BYTES: int = 4,
     WALK_BYTEARRAY: int = 5,
     ORDER_LT: int = 0,
     ORDER_LE: int = 1,
     ORDER_GT: int = 2,
     ORDER_GE: int = 3,
     TEXT_STR: int = 0,
     TEXT_REPR: int = 1,
     THUNK_OBJECT: int = 0,
     THUNK_MODE: int = 8,
     THUNK_RESULT: int = 16,
     THUNK_FRAME: int = 24,
     TEXT_REG_INITIAL: int = 64,
     ENUM_DESC: int = 0,
     ENUM_VALUE: int = 8,
     ENUM_NEXT: int = 16,
     ENUM_SIZE: int = 24,
     DESC_NEXT: int = 0,
     DESC_NAME: int = 8,
     DESC_TEXT: int = 16,
     DESC_BOXES: int = 24,
     DESC_SIZE: int = 32,
     KIND_DESC_MIN: int = 256,
     INT_FLOAT_EDGE: float = 9.223372036854775808e18,
     ARITH_ADD: int = 0,
     ARITH_SUB: int = 1,
     ARITH_MUL: int = 2,
     ARITH_DIV: int = 3,
     ARITH_FLOOR: int = 4,
     ARITH_MOD: int = 5;

def:pub __jac_rt_elem_tag(bits: int, kind: int) -> int;

def:pub __jac_rt_elem_payload(bits: int, kind: int) -> int;

def:pub __jac_rt_elem_box(bits: int, kind: int) -> int;

def:pub __jac_rt_any_iter(tag: int, payload: int) -> int;

def:pub __jac_rt_any_repr(tag: int, payload: int) -> ptr[u8];

def:pub __jac_rt_any_equal(ta: int, pa: int, tb: int, pb: int) -> bool;

def:pub __jac_rt_any_order(ta: int, pa: int, tb: int, pb: int, op: int) -> bool;

def:pub __jac_rt_any_contains(
    tag: int, payload: int, itag: int, ipayload: int
) -> bool;

def:pub __jac_rt_text_register(dtor: int, thunk: int);

def:pub __jac_rt_enum_desc(name: ptr[u8], text: int) -> int;

def:pub __jac_rt_enum_intern(desc: int, value: int) -> int;

def:pub __jac_rt_enum_box(desc: int, value: int) -> int;

def _enum_name(box: int) -> ptr[u8];

def:pub __jac_rt_class_tag(name: ptr[u8]) -> int;

def:pub __jac_rt_ref_swap(slot: int, value: int);

def:pub __jac_rt_any_binary(op: int, ta: int, pa: int, tb: int, pb: int) -> int;

def:pub __jac_rt_any_negate(tag: int, payload: int) -> int;

def:pub __jac_rt_dict_convert(
    tag: int, payload: int, key_kind: int, val_kind: int
) -> int;

def:pub __jac_rt_any_bind(
    tag: int,
    payload: int,
    want: int,
    first: int,
    first_family: int,
    second: int,
    second_family: int,
    label: ptr[u8]
) -> int;

def _bind_kind(have: int, want: int) -> bool;

def _bind_elem(bits: int, kind: int, family: int) -> bool;

def _bind_refuse(label: ptr[u8]);

def _bind_list(payload: int, kind: int, family: int, label: ptr[u8]) -> int;

def _bind_dict(
    payload: int,
    want: int,
    key_kind: int,
    key_family: int,
    val_kind: int,
    val_family: int,
    label: ptr[u8]
) -> int;

def _kind_bits(bits: int, have: int, want: int) -> int;

def:pub __jac_rt_any_getitem(tag: int, payload: int, ktag: int, kpayload: int) -> int;

def _box_owned(tag: int, payload: int) -> int;

def _seq_join(a: int, at: bool, b: int, bt: bool) -> int;

def _seq_repeat(a: int, is_tup: bool, times: int) -> int;

def _join_into(made: int, src: int, src_kind: int, kind: int);

def _unsupported(op: int, ta: int, pa: int, tb: int, pb: int);

def:pub __jac_rt_enum_value(tag: int, payload: int) -> int;

def:pub __jac_rt_any_enum_is(tag: int, payload: int, name: ptr[u8]) -> bool;

def:pub __jac_rt_any_same(ta: int, pa: int, tb: int, pb: int) -> bool;

def _enum_text(sb: int, box: int, mode: int);

def _ref_tag(o: int) -> int;

def _type_is(o: int, name: ptr[u8]) -> bool;

def _is_tuple(tag: int, payload: int) -> bool;

def _is_number(tag: int) -> bool;

def _as_float(tag: int, payload: int) -> float;

def _seq_bits(p: int, i: int, is_tup: bool) -> int;

def _seq_kind(p: int, i: int, is_tup: bool) -> int;

def _walk_mode(tag: int, payload: int) -> int;

def _not_iterable(tag: int, payload: int) -> ptr[u8];

def _walk_next(state: ptr[u8], out: ptr[u8]) -> bool;

def _walk_drop(state: ptr[u8]);

def _sb_cstr(sb: int, text: ptr[u8]);

def _sb_owned(sb: int, text: ptr[u8]);

def _any_text(sb: int, tag: int, payload: int, mode: int);

def _elem_text(sb: int, bits: int, kind: int);

def _seq_text(sb: int, p: int, is_tup: bool);

def _map_text(sb: int, d: int, with_values: bool);

def _obj_text(sb: int, o: int, mode: int);

def _text_find(dtor: int) -> int;

def _text_put(keys: int, vals: int, mask: int, dtor: int, thunk: int);

def _elem_equal(x: int, kx: int, y: int, ky: int) -> bool;

def _uint_equal(x: int, kx: int, y: int, ky: int) -> bool;

def _seq_equal(a: int, at: bool, b: int, bt: bool) -> bool;

def _map_find(d: int, tag: int, payload: int) -> int;

def _map_equal(a: int, b: int, with_values: bool) -> bool;

def _buffer_data(o: int) -> int;

def _buffer_len(o: int) -> int;

def _unordered(ta: int, pa: int, tb: int, pb: int, op: int);

def _any_less(ta: int, pa: int, tb: int, pb: int, or_equal: bool, op: int) -> bool;

def _seq_less(a: int, at: bool, b: int, bt: bool, or_equal: bool, op: int) -> bool;
