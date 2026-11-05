impl _holds_ref(tag: int) -> bool {
    return (tag >= ANY_TAG_FIRST_REF and tag <= ANY_TAG_LAST_REF)
        or tag == ANY_TAG_ENUM;
}

impl __jac_rt_enum_desc(name: ptr[u8], text: int) -> int {
    head_at = __global_block("__jac_rt_enum_descs", 8);
    entry_at = __mem_load_i64(head_at);
    while entry_at != 0 {
        if __jac_rt_cstr_eq(ptr[u8](__mem_load_i64(entry_at + DESC_NAME)), name) {
            if __mem_load_i64(entry_at + DESC_TEXT) == 0 {
                __mem_store_i64(entry_at + DESC_TEXT, text);
            }
            return entry_at;
        }
        entry_at = __mem_load_i64(entry_at + DESC_NEXT);
    }
    entry_at = calloc(1, DESC_SIZE);
    __mem_store_i64(entry_at + DESC_NEXT, __mem_load_i64(head_at));
    __mem_store_i64(entry_at + DESC_NAME, int(name));
    __mem_store_i64(entry_at + DESC_TEXT, text);
    __mem_store_i64(head_at, entry_at);
    return entry_at;
}

impl __jac_rt_enum_intern(desc: int, value: int) -> int {
    box = __mem_load_i64(desc + DESC_BOXES);
    while box != 0 {
        if __mem_load_i64(box + ENUM_VALUE) == value {
            return box;
        }
        box = __mem_load_i64(box + ENUM_NEXT);
    }
    box = __jac_rt_alloc(ENUM_SIZE);
    __jac_rt_set_type(box, int(ptr[u8]("enum")));
    __mem_store_i64(box + ENUM_DESC, desc);
    __mem_store_i64(box + ENUM_VALUE, value);
    __mem_store_i64(box + ENUM_NEXT, __mem_load_i64(desc + DESC_BOXES));
    __mem_store_i64(desc + DESC_BOXES, box);
    return box;
}

impl __jac_rt_enum_box(desc: int, value: int) -> int {
    box = __jac_rt_enum_intern(desc, value);
    __jac_rt_retain(box);
    return box;
}

impl _enum_name(box: int) -> ptr[u8] {
    return ptr[u8](__mem_load_i64(__mem_load_i64(box + ENUM_DESC) + DESC_NAME));
}

impl __jac_rt_enum_value(tag: int, payload: int) -> int {
    if tag == ANY_TAG_ENUM and payload != 0 {
        return __mem_load_i64(payload + ENUM_VALUE);
    }
    return payload;
}

impl __jac_rt_any_enum_is(tag: int, payload: int, name: ptr[u8]) -> bool {
    return tag == ANY_TAG_ENUM
        and payload != 0
        and __jac_rt_cstr_eq(_enum_name(payload), name);
}

impl __jac_rt_any_same(ta: int, pa: int, tb: int, pb: int) -> bool {
    if ta != tb {
        return False;
    }
    if ta == ANY_TAG_ENUM {
        return __jac_rt_any_equal(ta, pa, tb, pb);
    }
    return pa == pb;
}

impl _enum_text(sb: int, box: int, mode: int) {
    thunk = __mem_load_i64(__mem_load_i64(box + ENUM_DESC) + DESC_TEXT);
    if thunk != 0 {
        frame = malloc(THUNK_FRAME);
        __mem_store_i64(frame + THUNK_OBJECT, __mem_load_i64(box + ENUM_VALUE));
        __mem_store_i64(frame + THUNK_MODE, mode);
        __mem_store_i64(frame + THUNK_RESULT, 0);
        __mem_call_dtor(thunk, frame);
        text = __mem_load_i64(frame + THUNK_RESULT);
        free(frame);
        if text != 0 {
            _sb_owned(sb, ptr[u8](text));
            return;
        }
    }
    _sb_owned(sb, __jac_rt_class_name(_enum_name(box)));
    _sb_cstr(sb, ptr[u8]("."));
    __jac_rt_sb_int(sb, __mem_load_i64(box + ENUM_VALUE));
}

impl __jac_rt_any_retain(tag: int, payload: int) {
    if payload != 0 and _holds_ref(tag) {
        __jac_rt_retain(payload);
    }
}

impl __jac_rt_any_drop(tag: int, payload: int) {
    __jac_rt_any_release(tag, payload);
}

impl __jac_rt_any_release(tag: int, payload: int) {
    if payload != 0 and _holds_ref(tag) {
        __jac_rt_release(payload);
    }
}

impl __jac_rt_any_box(tag: int, payload: int) -> int {
    box = __jac_rt_alloc(BOX_SIZE);
    __jac_rt_set_type(box, int(ptr[u8]("any")));
    __mem_store_i64(box + BOX_TAG, tag);
    __mem_store_i64(box + BOX_PAYLOAD, payload);
    __jac_rt_any_retain(tag, payload);
    __mem_store_i64(box - HDR_DTOR_BACK, int(_box_drop));
    flag = __global_block("__jac_rt_box_traced", 1);
    if int(__mem_load_i8(flag)) == 0 {
        __jac_rt_trace_register(int(_box_drop), int(_box_trace));
        __mem_store_i8(flag, i8(1));
    }
    return box;
}

impl __jac_rt_any_box_hold(box: int) {
    if box != 0 {
        __jac_rt_any_retain(
            __mem_load_i64(box + BOX_TAG), __mem_load_i64(box + BOX_PAYLOAD)
        );
    }
}

impl _box_drop(box: ptr[u8]) {
    at = int(box);
    tag = __mem_load_i64(at + BOX_TAG);
    collecting = int(__mem_load_i8(__global_block("__rc_collecting", 1))) != 0;
    if not (collecting and _box_traced_tag(tag)) {
        __jac_rt_any_release(tag, __mem_load_i64(at + BOX_PAYLOAD));
    }
    __jac_rt_free_block(at - HDR_TOTAL);
}

impl _box_traced_tag(tag: int) -> bool {
    return tag >= ANY_TAG_LIST and tag <= ANY_TAG_OBJ;
}

impl _box_trace(box: int, visit_fn: int) {
    payload = __mem_load_i64(box + BOX_PAYLOAD);
    if payload != 0 and _box_traced_tag(__mem_load_i64(box + BOX_TAG)) {
        __mem_call_dtor(visit_fn, payload);
    }
}

impl __jac_rt_any_truthy(tag: int, payload: int) -> bool {
    if tag == ANY_TAG_NONE {
        return False;
    }
    if tag == ANY_TAG_ELLIPSIS {
        return True;
    }
    if tag == ANY_TAG_INT or tag == ANY_TAG_BOOL {
        return payload != 0;
    }
    if tag == ANY_TAG_FLOAT {
        return __bits_float(payload) != 0.0;
    }
    if tag == ANY_TAG_STR {
        return payload != 0 and __jac_rt_str_size(ptr[u8](payload)) != 0;
    }
    if tag == ANY_TAG_LIST {
        return __mem_load_i64(payload + LIST_LEN) != 0;
    }
    if tag == ANY_TAG_DICT or tag == ANY_TAG_SET {
        return __jac_rt_dict_len(payload) != 0;
    }
    if _is_buffer(tag, payload) or _is_tuple(tag, payload) {
        return __mem_load_i64(payload) != 0;
    }
    return True;
}

impl _is_buffer(tag: int, payload: int) -> bool {
    return __jac_rt_any_isa(tag, payload, ptr[u8]("bytes"))
        or __jac_rt_any_isa(tag, payload, ptr[u8]("bytearray"));
}

impl __jac_rt_any_len(tag: int, payload: int) -> int {
    if tag == ANY_TAG_STR {
        return __jac_rt_str_cp_total(
            ptr[u8](payload), ptr[u8](payload), __jac_rt_str_size(ptr[u8](payload))
        );
    }
    if tag == ANY_TAG_LIST {
        return __mem_load_i64(payload + LIST_LEN);
    }
    if tag == ANY_TAG_DICT or tag == ANY_TAG_SET {
        return __jac_rt_dict_len(payload);
    }
    if _is_buffer(tag, payload) or _is_tuple(tag, payload) {
        return __mem_load_i64(payload);
    }
    raise TypeError("object has no len()");
}

impl __jac_rt_vtable_find(table: int, selector: int) -> int {
    selectors = __mem_load_i64(table + VTABLE_SELECTORS_OFF);
    i = 0;
    while True {
        seen = __mem_load_i64(selectors + i * 8);
        if seen == 0 {
            return 0;
        }
        if seen == selector or __jac_rt_cstr_eq(ptr[u8](seen), ptr[u8](selector)) {
            return __mem_load_i64(table + VTABLE_METHODS_OFF + i * 8);
        }
        i += 1;
    }
    return 0;
}

impl __jac_rt_field_at(
    remap: int, base: int, index: int, fallback: int, holder: int
) -> int {
    i = 0;
    while True {
        seen = __mem_load_i64(remap + i * 16);
        if seen == 0 {
            return fallback;
        }
        if seen == base {
            offset = __mem_load_i64(__mem_load_i64(remap + i * 16 + 8) + index * 8);
            return fallback if offset < 0 else holder + offset;
        }
        i += 1;
    }
    return fallback;
}

impl __jac_rt_type_name(o: int) -> ptr[u8] {
    return ptr[u8](__mem_load_i64(o - HDR_TAG_BACK));
}

impl __jac_rt_any_type_name(tag: int, payload: int) -> ptr[u8] {
    if tag == ANY_TAG_INT {
        return ptr[u8]("int");
    }
    if tag == ANY_TAG_FLOAT {
        return ptr[u8]("float");
    }
    if tag == ANY_TAG_STR {
        return ptr[u8]("str");
    }
    if tag == ANY_TAG_LIST {
        return ptr[u8]("list");
    }
    if tag == ANY_TAG_DICT {
        return ptr[u8]("dict");
    }
    if tag == ANY_TAG_SET {
        return ptr[u8]("set");
    }
    if tag == ANY_TAG_OBJ and payload != 0 {
        return __jac_rt_type_name(payload);
    }
    if tag == ANY_TAG_BOOL {
        return ptr[u8]("bool");
    }
    if tag == ANY_TAG_ENUM and payload != 0 {
        return _enum_name(payload);
    }
    if tag == ANY_TAG_ELLIPSIS {
        return ptr[u8]("ellipsis");
    }
    return ptr[u8]("NoneType");
}

impl __jac_rt_any_isa(tag: int, payload: int, name: ptr[u8]) -> bool {
    return tag == ANY_TAG_OBJ
        and payload != 0
        and __jac_rt_cstr_eq(__jac_rt_type_name(payload), name);
}

impl _class_isa_bucket(cls: int, base: int) -> int {
    table = __global_block("__jac_rt_class_lineage", 4096);
    return table + (((cls >> 4) ^ (base >> 4) ^ (cls >> 13)) & 511) * 8;
}

impl __jac_rt_class_isa_add(cls: int, base: int) {
    if __jac_rt_class_isa(cls, base) {
        return;
    }
    head = _class_isa_bucket(cls, base);
    cell = int(malloc(24));
    __mem_store_i64(cell, __mem_load_i64(head));
    __mem_store_i64(cell + 8, cls);
    __mem_store_i64(cell + 16, base);
    __mem_store_i64(head, cell);
}

impl __jac_rt_class_isa(cls: int, base: int) -> bool {
    if cls == base {
        return True;
    }
    cell = __mem_load_i64(_class_isa_bucket(cls, base));
    while cell != 0 {
        if __mem_load_i64(cell + 8) == cls and __mem_load_i64(cell + 16) == base {
            return True;
        }
        cell = __mem_load_i64(cell);
    }
    return False;
}

impl __jac_rt_any_isa_class(tag: int, payload: int, cls: int) -> bool {
    return tag == ANY_TAG_OBJ
        and payload != 0
        and __jac_rt_class_isa(int(__jac_rt_type_name(payload)), cls);
}

impl __jac_rt_cstr_eq(a: ptr[u8], b: ptr[u8]) -> bool {
    if int(a) == int(b) {
        return True;
    }
    if int(a) == 0 or int(b) == 0 {
        return False;
    }
    return strcmp(a, b) == i32(0);
}

impl __jac_rt_class_name(text: ptr[u8]) -> ptr[u8] {
    if int(text) == 0 {
        return __jac_rt_str_new(text, 0);
    }
    size = int(strlen(text));
    at = 0;
    while at < size and (int(__mem_load_i8(int(text) + at)) & 255) != 36 {
        at += 1;
    }
    return __jac_rt_str_new(text, at);
}

impl __jac_rt_str_from_cstr(text: ptr[u8]) -> ptr[u8] {
    if int(text) == 0 {
        return __jac_rt_str_new(text, 0);
    }
    return __jac_rt_str_new(text, int(strlen(text)));
}

impl _type_is(o: int, name: ptr[u8]) -> bool {
    return o != 0 and __jac_rt_cstr_eq(__jac_rt_type_name(o), name);
}

impl _ref_tag(o: int) -> int {
    if o == 0 {
        return ANY_TAG_NONE;
    }
    if _type_is(o, ptr[u8]("list")) {
        return ANY_TAG_LIST;
    }
    if _type_is(o, ptr[u8]("dict")) {
        return ANY_TAG_DICT;
    }
    if _type_is(o, ptr[u8]("set")) {
        return ANY_TAG_SET;
    }
    if _type_is(o, ptr[u8]("enum")) {
        return ANY_TAG_ENUM;
    }
    return ANY_TAG_OBJ;
}

impl _is_tuple(tag: int, payload: int) -> bool {
    return tag == ANY_TAG_OBJ and _type_is(payload, ptr[u8]("tuple"));
}

impl _is_number(tag: int) -> bool {
    return tag == ANY_TAG_INT or tag == ANY_TAG_BOOL or tag == ANY_TAG_FLOAT;
}

impl _as_float(tag: int, payload: int) -> float {
    if tag == ANY_TAG_FLOAT {
        return __bits_float(payload);
    }
    return float(payload);
}

impl __jac_rt_elem_tag(bits: int, kind: int) -> int {
    if kind == KIND_NULL {
        return ANY_TAG_NONE;
    }
    if kind >= KIND_DESC_MIN {
        return ANY_TAG_ENUM;
    }
    if kind == KIND_FLOAT {
        return ANY_TAG_FLOAT;
    }
    if kind == KIND_BOOL {
        return ANY_TAG_BOOL;
    }
    if kind == KIND_STR {
        if bits == 0 {
            return ANY_TAG_NONE;
        }
        return ANY_TAG_STR;
    }
    if kind == KIND_ANY {
        if bits == 0 {
            return ANY_TAG_NONE;
        }
        return __mem_load_i64(bits + BOX_TAG);
    }
    if kind == KIND_REF or kind == KIND_TUPLE {
        return _ref_tag(bits);
    }
    return ANY_TAG_INT;
}

impl __jac_rt_elem_payload(bits: int, kind: int) -> int {
    if kind >= KIND_DESC_MIN {
        return __jac_rt_enum_intern(kind, bits);
    }
    if kind == KIND_ANY and bits != 0 {
        return __mem_load_i64(bits + BOX_PAYLOAD);
    }
    return bits;
}

impl __jac_rt_elem_box(bits: int, kind: int) -> int {
    if kind == KIND_ANY and bits != 0 {
        __jac_rt_retain(bits);
        return bits;
    }
    return __jac_rt_any_box(
        __jac_rt_elem_tag(bits, kind), __jac_rt_elem_payload(bits, kind)
    );
}

impl __jac_rt_any_as_kind(bits: int, kind: int) -> int {
    tag = __jac_rt_elem_tag(bits, KIND_ANY);
    fits = False;
    if kind == KIND_INT or kind == KIND_UINT {
        fits = tag == ANY_TAG_INT or tag == ANY_TAG_BOOL;
    } elif kind == KIND_FLOAT {
        fits = tag == ANY_TAG_FLOAT;
    } elif kind == KIND_BOOL {
        fits = tag == ANY_TAG_BOOL;
    } elif kind == KIND_NULL {
        fits = tag == ANY_TAG_NONE;
    } elif kind == KIND_STR {
        fits = tag == ANY_TAG_STR or tag == ANY_TAG_NONE;
    } elif kind == KIND_REF {
        fits = tag == ANY_TAG_NONE
            or tag == ANY_TAG_LIST
            or tag == ANY_TAG_DICT
            or tag == ANY_TAG_SET
            or tag == ANY_TAG_OBJ
            or tag == ANY_TAG_ENUM;
    }
    if not fits {
        raise TypeError(
            "a container with typed elements cannot hold this value through an `any` view"
        );
    }
    return __jac_rt_elem_payload(bits, KIND_ANY);
}

impl _seq_bits(p: int, i: int, is_tup: bool) -> int {
    if is_tup {
        return __mem_load_i64(
            p + TUPLE_KINDS + (__mem_load_i64(p + LIST_LEN) + i) * SLOT
        );
    }
    return __mem_load_i64(__mem_load_i64(p + LIST_DATA) + i * SLOT);
}

impl _seq_kind(p: int, i: int, is_tup: bool) -> int {
    if is_tup {
        return __mem_load_i64(p + TUPLE_KINDS + i * SLOT);
    }
    return __jac_rt_list_kind(p);
}

impl _walk_mode(tag: int, payload: int) -> int {
    if tag == ANY_TAG_LIST {
        return WALK_LIST;
    }
    if tag == ANY_TAG_DICT or tag == ANY_TAG_SET {
        return WALK_KEYS;
    }
    if tag == ANY_TAG_STR {
        return WALK_STR;
    }
    if _is_tuple(tag, payload) {
        return WALK_TUPLE;
    }
    if tag == ANY_TAG_OBJ and _type_is(payload, ptr[u8]("bytes")) {
        return WALK_BYTES;
    }
    if tag == ANY_TAG_OBJ and _type_is(payload, ptr[u8]("bytearray")) {
        return WALK_BYTEARRAY;
    }
    if tag == ANY_TAG_OBJ and _type_is(payload, ptr[u8]("range")) {
        return WALK_RANGE;
    }
    raise TypeError(_not_iterable(tag, payload));
}

impl _not_iterable(tag: int, payload: int) -> ptr[u8] {
    sb = __jac_rt_sb_new(48);
    _sb_cstr(sb, ptr[u8]("'"));
    _sb_owned(sb, __jac_rt_class_name(__jac_rt_any_type_name(tag, payload)));
    _sb_cstr(sb, ptr[u8]("' object is not iterable"));
    return __jac_rt_sb_finish(sb);
}

impl __jac_rt_any_iter(tag: int, payload: int) -> int {
    if tag == ANY_TAG_OBJ and _type_is(payload, ptr[u8]("iterator")) {
        __jac_rt_retain(payload);
        return payload;
    }
    mode = _walk_mode(tag, payload);
    state = __jac_rt_alloc(WALK_SIZE);
    __jac_rt_set_type(state, int(ptr[u8]("iterator_state")));
    __jac_rt_retain(payload);
    __mem_store_i64(state + WALK_COLL, payload);
    __mem_store_i64(state + WALK_INDEX, -1 if mode == WALK_KEYS else 0);
    __mem_store_i64(state + WALK_MODE, mode);
    __mem_store_i64(state - HDR_DTOR_BACK, int(_walk_drop));
    it = __jac_rt_iter_new(int(_walk_next), state);
    __jac_rt_release(state);
    return it;
}

impl _walk_drop(state: ptr[u8]) {
    at = int(state);
    __jac_rt_release(__mem_load_i64(at + WALK_COLL));
    __jac_rt_free_block(at - HDR_TOTAL);
}

impl _walk_next(state: ptr[u8], out: ptr[u8]) -> bool {
    at = int(state);
    coll = __mem_load_i64(at + WALK_COLL);
    index = __mem_load_i64(at + WALK_INDEX);
    mode = __mem_load_i64(at + WALK_MODE);
    if mode == WALK_KEYS {
        cursor = __jac_rt_dict_next(coll, index);
        if cursor < 0 {
            return False;
        }
        __mem_store_i64(
            int(out),
            __jac_rt_elem_box(
                __jac_rt_dict_key_at(coll, cursor), __mem_load_i64(coll + DICT_KEY_KIND)
            )
        );
        __mem_store_i64(at + WALK_INDEX, cursor);
        return True;
    }
    if mode == WALK_STR {
        size = __jac_rt_str_size(ptr[u8](coll));
        if index >= size {
            return False;
        }
        width = __jac_rt_utf8_width(ptr[u8](coll), size, index);
        piece = __jac_rt_str_new(ptr[u8](coll + index), width);
        __mem_store_i64(int(out), __jac_rt_any_box(ANY_TAG_STR, int(piece)));
        __jac_rt_release(int(piece));
        __mem_store_i64(at + WALK_INDEX, index + width);
        return True;
    }
    if mode == WALK_RANGE {
        if index >= __jac_rt_range_len(coll) {
            return False;
        }
        value = __mem_load_i64(coll) + index * __mem_load_i64(coll + 16);
        __mem_store_i64(int(out), __jac_rt_any_box(ANY_TAG_INT, value));
        __mem_store_i64(at + WALK_INDEX, index + 1);
        return True;
    }
    if mode == WALK_BYTES or mode == WALK_BYTEARRAY {
        if index >= __mem_load_i64(coll) {
            return False;
        }
        data = _buffer_data(coll);
        byte = int(__mem_load_i8(data + index)) & 255;
        __mem_store_i64(int(out), __jac_rt_any_box(ANY_TAG_INT, byte));
        __mem_store_i64(at + WALK_INDEX, index + 1);
        return True;
    }
    is_tup = mode == WALK_TUPLE;
    if index >= __mem_load_i64(coll + LIST_LEN) {
        return False;
    }
    __mem_store_i64(
        int(out),
        __jac_rt_elem_box(
            _seq_bits(coll, index, is_tup), _seq_kind(coll, index, is_tup)
        )
    );
    __mem_store_i64(at + WALK_INDEX, index + 1);
    return True;
}

impl _sb_cstr(sb: int, text: ptr[u8]) {
    __jac_rt_sb_add(sb, text, int(strlen(text)));
}

impl _sb_owned(sb: int, text: ptr[u8]) {
    __jac_rt_sb_add(sb, text, __jac_rt_str_size(text));
    __jac_rt_release(int(text));
}

impl __jac_rt_any_str(tag: int, payload: int) -> ptr[u8] {
    if tag == ANY_TAG_STR {
        __jac_rt_retain(payload);
        return ptr[u8](payload);
    }
    sb = __jac_rt_sb_new(32);
    _any_text(sb, tag, payload, TEXT_STR);
    return __jac_rt_sb_finish(sb);
}

impl __jac_rt_any_repr(tag: int, payload: int) -> ptr[u8] {
    sb = __jac_rt_sb_new(32);
    _any_text(sb, tag, payload, TEXT_REPR);
    return __jac_rt_sb_finish(sb);
}

impl _any_text(sb: int, tag: int, payload: int, mode: int) {
    if tag == ANY_TAG_INT {
        __jac_rt_sb_int(sb, payload);
        return;
    }
    if tag == ANY_TAG_BOOL {
        _sb_cstr(sb, ptr[u8]("True") if payload != 0 else ptr[u8]("False"));
        return;
    }
    if tag == ANY_TAG_FLOAT {
        _sb_owned(sb, __jac_rt_float_repr(__bits_float(payload)));
        return;
    }
    if tag == ANY_TAG_ELLIPSIS {
        _sb_cstr(sb, ptr[u8]("Ellipsis"));
        return;
    }
    if tag == ANY_TAG_NONE or payload == 0 {
        _sb_cstr(sb, ptr[u8]("None"));
        return;
    }
    if tag == ANY_TAG_STR {
        size = __jac_rt_str_size(ptr[u8](payload));
        if mode == TEXT_STR {
            __jac_rt_sb_add(sb, ptr[u8](payload), size);
        } else {
            _sb_owned(sb, __jac_rt_str_repr(ptr[u8](payload), size));
        }
        return;
    }
    if tag == ANY_TAG_LIST {
        _seq_text(sb, payload, False);
        return;
    }
    if tag == ANY_TAG_DICT or tag == ANY_TAG_SET {
        _map_text(sb, payload, tag == ANY_TAG_DICT);
        return;
    }
    if tag == ANY_TAG_ENUM {
        _enum_text(sb, payload, mode);
        return;
    }
    _obj_text(sb, payload, mode);
}

impl _elem_text(sb: int, bits: int, kind: int) {
    _any_text(
        sb, __jac_rt_elem_tag(bits, kind), __jac_rt_elem_payload(bits, kind), TEXT_REPR
    );
}

impl _seq_text(sb: int, p: int, is_tup: bool) {
    depth = __jac_rt_repr_enter(p);
    if depth < 0 {
        _sb_cstr(sb, ptr[u8]("(...)") if is_tup else ptr[u8]("[...]"));
        return;
    }
    n = __mem_load_i64(p + LIST_LEN);
    _sb_cstr(sb, ptr[u8]("(") if is_tup else ptr[u8]("["));
    i = 0;
    while i < n {
        if i > 0 {
            _sb_cstr(sb, ptr[u8](", "));
        }
        _elem_text(sb, _seq_bits(p, i, is_tup), _seq_kind(p, i, is_tup));
        i += 1;
    }
    if is_tup and n == 1 {
        _sb_cstr(sb, ptr[u8](","));
    }
    _sb_cstr(sb, ptr[u8](")") if is_tup else ptr[u8]("]"));
    __jac_rt_repr_leave(depth);
}

impl _map_text(sb: int, d: int, with_values: bool) {
    if __jac_rt_dict_len(d) == 0 {
        _sb_cstr(sb, ptr[u8]("{}") if with_values else ptr[u8]("set()"));
        return;
    }
    depth = __jac_rt_repr_enter(d);
    if depth < 0 {
        _sb_cstr(sb, ptr[u8]("{...}") if with_values else ptr[u8]("set(...)"));
        return;
    }
    key_kind = __mem_load_i64(d + DICT_KEY_KIND);
    val_kind = __mem_load_i64(d + DICT_VAL_KIND);
    _sb_cstr(sb, ptr[u8]("{"));
    first = True;
    at = __jac_rt_dict_next(d, -1);
    while at >= 0 {
        if not first {
            _sb_cstr(sb, ptr[u8](", "));
        }
        first = False;
        _elem_text(sb, __jac_rt_dict_key_at(d, at), key_kind);
        if with_values {
            _sb_cstr(sb, ptr[u8](": "));
            _elem_text(sb, __jac_rt_dict_val_at(d, at), val_kind);
        }
        at = __jac_rt_dict_next(d, at);
    }
    _sb_cstr(sb, ptr[u8]("}"));
    __jac_rt_repr_leave(depth);
}

impl _obj_text(sb: int, o: int, mode: int) {
    if _type_is(o, ptr[u8]("tuple")) {
        _seq_text(sb, o, True);
        return;
    }
    if _type_is(o, ptr[u8]("bytes")) {
        _sb_owned(sb, __jac_rt_bytes_repr(ptr[u8](_buffer_data(o)), _buffer_len(o)));
        return;
    }
    if _type_is(o, ptr[u8]("bytearray")) {
        _sb_cstr(sb, ptr[u8]("bytearray("));
        _sb_owned(sb, __jac_rt_bytes_repr(ptr[u8](_buffer_data(o)), _buffer_len(o)));
        _sb_cstr(sb, ptr[u8](")"));
        return;
    }
    thunk = _text_find(__mem_load_i64(o - HDR_DTOR_BACK));
    if thunk != 0 {
        frame = malloc(THUNK_FRAME);
        __mem_store_i64(frame + THUNK_OBJECT, o);
        __mem_store_i64(frame + THUNK_MODE, mode);
        __mem_store_i64(frame + THUNK_RESULT, 0);
        __mem_call_dtor(thunk, frame);
        text = __mem_load_i64(frame + THUNK_RESULT);
        free(frame);
        if text != 0 {
            _sb_owned(sb, ptr[u8](text));
            return;
        }
    }
    name = __jac_rt_class_name(__jac_rt_type_name(o));
    _sb_owned(sb, __jac_rt_obj_text(name, o));
    __jac_rt_release(int(name));
}

impl _text_find(dtor: int) -> int {
    cap = __mem_load_i64(__global_block("__jac_rt_text_cap", 8));
    if cap == 0 or dtor == 0 {
        return 0;
    }
    keys = __mem_load_i64(__global_block("__jac_rt_text_keys", 8));
    vals = __mem_load_i64(__global_block("__jac_rt_text_vals", 8));
    mask = cap - 1;
    i = (dtor >> 4) & mask;
    while True {
        held = __mem_load_i64(keys + i * SLOT);
        if held == dtor {
            return __mem_load_i64(vals + i * SLOT);
        }
        if held == 0 {
            return 0;
        }
        i = (i + 1) & mask;
    }
    return 0;
}

impl _text_put(keys: int, vals: int, mask: int, dtor: int, thunk: int) {
    i = (dtor >> 4) & mask;
    while True {
        held = __mem_load_i64(keys + i * SLOT);
        if held == 0 or held == dtor {
            __mem_store_i64(keys + i * SLOT, dtor);
            __mem_store_i64(vals + i * SLOT, thunk);
            return;
        }
        i = (i + 1) & mask;
    }
}

impl __jac_rt_text_register(dtor: int, thunk: int) {
    cap_at = __global_block("__jac_rt_text_cap", 8);
    count_at = __global_block("__jac_rt_text_count", 8);
    keys_at = __global_block("__jac_rt_text_keys", 8);
    vals_at = __global_block("__jac_rt_text_vals", 8);
    cap = __mem_load_i64(cap_at);
    if (__mem_load_i64(count_at) + 1) * 2 >= cap {
        grown = TEXT_REG_INITIAL if cap == 0 else cap * 2;
        fresh_keys = calloc(grown, SLOT);
        fresh_vals = calloc(grown, SLOT);
        old_keys = __mem_load_i64(keys_at);
        old_vals = __mem_load_i64(vals_at);
        j = 0;
        while j < cap {
            key = __mem_load_i64(old_keys + j * SLOT);
            if key != 0 {
                _text_put(
                    fresh_keys,
                    fresh_vals,
                    grown - 1,
                    key,
                    __mem_load_i64(old_vals + j * SLOT)
                );
            }
            j += 1;
        }
        free(old_keys);
        free(old_vals);
        __mem_store_i64(keys_at, fresh_keys);
        __mem_store_i64(vals_at, fresh_vals);
        __mem_store_i64(cap_at, grown);
        cap = grown;
    }
    _text_put(__mem_load_i64(keys_at), __mem_load_i64(vals_at), cap - 1, dtor, thunk);
    __mem_store_i64(count_at, __mem_load_i64(count_at) + 1);
}

impl _buffer_data(o: int) -> int {
    if _type_is(o, ptr[u8]("bytearray")) {
        return __mem_load_i64(o + BYTEARRAY_DATA);
    }
    return o + BYTES_DATA;
}

impl _buffer_len(o: int) -> int {
    return __mem_load_i64(o);
}

impl _elem_equal(x: int, kx: int, y: int, ky: int) -> bool {
    if (kx == KIND_UINT and x < 0) or (ky == KIND_UINT and y < 0) {
        return _uint_equal(x, kx, y, ky);
    }
    return __jac_rt_any_equal(
        __jac_rt_elem_tag(x, kx),
        __jac_rt_elem_payload(x, kx),
        __jac_rt_elem_tag(y, ky),
        __jac_rt_elem_payload(y, ky)
    );
}

impl __jac_rt_any_equal(ta: int, pa: int, tb: int, pb: int) -> bool {
    if _is_number(ta) and _is_number(tb) {
        if ta != ANY_TAG_FLOAT and tb != ANY_TAG_FLOAT {
            return pa == pb;
        }
        if ta == ANY_TAG_FLOAT and tb == ANY_TAG_FLOAT {
            return __bits_float(pa) == __bits_float(pb);
        }
        whole = pb if ta == ANY_TAG_FLOAT else pa;
        part = __bits_float(pa) if ta == ANY_TAG_FLOAT else __bits_float(pb);
        if part != part or part >= INT_FLOAT_EDGE or part < 0.0 - INT_FLOAT_EDGE {
            return False;
        }
        if part != float(int(part)) {
            return False;
        }
        return int(part) == whole;
    }
    if ta != tb {
        return False;
    }
    if ta == ANY_TAG_NONE or pa == pb {
        return True;
    }
    if pa == 0 or pb == 0 {
        return False;
    }
    if ta == ANY_TAG_STR {
        an = __jac_rt_str_size(ptr[u8](pa));
        return an == __jac_rt_str_size(ptr[u8](pb))
            and __jac_rt_str_cmp(ptr[u8](pa), an, ptr[u8](pb), an) == 0;
    }
    if ta == ANY_TAG_LIST {
        return _seq_equal(pa, False, pb, False);
    }
    if ta == ANY_TAG_DICT or ta == ANY_TAG_SET {
        return _map_equal(pa, pb, ta == ANY_TAG_DICT);
    }
    if ta == ANY_TAG_ENUM {
        return __mem_load_i64(pa + ENUM_VALUE) == __mem_load_i64(pb + ENUM_VALUE)
            and __jac_rt_cstr_eq(_enum_name(pa), _enum_name(pb));
    }
    if ta != ANY_TAG_OBJ {
        return False;
    }
    if _is_tuple(ta, pa) and _is_tuple(tb, pb) {
        return _seq_equal(pa, True, pb, True);
    }
    if _is_buffer(ta, pa) and _is_buffer(tb, pb) {
        an = _buffer_len(pa);
        return an == _buffer_len(pb)
            and __jac_rt_str_cmp(
                ptr[u8](_buffer_data(pa)), an, ptr[u8](_buffer_data(pb)), an
            )
                == 0;
    }
    return False;
}

impl _seq_equal(a: int, at: bool, b: int, bt: bool) -> bool {
    n = __mem_load_i64(a + LIST_LEN);
    if n != __mem_load_i64(b + LIST_LEN) {
        return False;
    }
    i = 0;
    while i < n {
        if not _elem_equal(
            _seq_bits(a, i, at),
            _seq_kind(a, i, at),
            _seq_bits(b, i, bt),
            _seq_kind(b, i, bt)
        ) {
            return False;
        }
        i += 1;
    }
    return True;
}

impl _map_find(d: int, tag: int, payload: int) -> int {
    kind = __mem_load_i64(d + DICT_KEY_KIND);
    at = __jac_rt_dict_next(d, -1);
    while at >= 0 {
        bits = __jac_rt_dict_key_at(d, at);
        if __jac_rt_any_equal(
            __jac_rt_elem_tag(bits, kind),
            __jac_rt_elem_payload(bits, kind),
            tag,
            payload
        ) {
            return at;
        }
        at = __jac_rt_dict_next(d, at);
    }
    return -1;
}

impl _map_equal(a: int, b: int, with_values: bool) -> bool {
    if __jac_rt_dict_len(a) != __jac_rt_dict_len(b) {
        return False;
    }
    key_kind = __mem_load_i64(a + DICT_KEY_KIND);
    val_a = __mem_load_i64(a + DICT_VAL_KIND);
    val_b = __mem_load_i64(b + DICT_VAL_KIND);
    at = __jac_rt_dict_next(a, -1);
    while at >= 0 {
        bits = __jac_rt_dict_key_at(a, at);
        found = -1;
        if key_kind == __mem_load_i64(b + DICT_KEY_KIND)
            and key_kind != KIND_FLOAT
            and key_kind != KIND_BOOL {
            found = __jac_rt_dict_find(b, bits, key_kind);
        } else {
            found = _map_find(
                b,
                __jac_rt_elem_tag(bits, key_kind),
                __jac_rt_elem_payload(bits, key_kind)
            );
        }
        if found < 0 {
            return False;
        }
        if with_values
            and not _elem_equal(
                __jac_rt_dict_val_at(a, at),
                val_a,
                __jac_rt_dict_val_at(b, found),
                val_b
            ) {
            return False;
        }
        at = __jac_rt_dict_next(a, at);
    }
    return True;
}

impl __jac_rt_any_contains(tag: int, payload: int, itag: int, ipayload: int) -> bool {
    if tag == ANY_TAG_STR {
        if itag != ANY_TAG_STR {
            raise TypeError("'in <string>' requires string as left operand");
        }
        return __jac_rt_str_contains(
            ptr[u8](payload),
            __jac_rt_str_size(ptr[u8](payload)),
            ptr[u8](ipayload),
            __jac_rt_str_size(ptr[u8](ipayload))
        );
    }
    if tag == ANY_TAG_DICT or tag == ANY_TAG_SET {
        kind = __mem_load_i64(payload + DICT_KEY_KIND);
        if kind == KIND_STR and itag == ANY_TAG_STR {
            return __jac_rt_dict_find(payload, ipayload, kind) >= 0;
        }
        if kind == KIND_INT and (itag == ANY_TAG_INT or itag == ANY_TAG_BOOL) {
            return __jac_rt_dict_find(payload, ipayload, kind) >= 0;
        }
        return _map_find(payload, itag, ipayload) >= 0;
    }
    if tag == ANY_TAG_OBJ and _is_buffer(tag, payload) {
        data = _buffer_data(payload);
        size = _buffer_len(payload);
        if itag == ANY_TAG_INT or itag == ANY_TAG_BOOL {
            return __jac_rt_bytes_has(ptr[u8](data), size, ipayload);
        }
        if itag == ANY_TAG_OBJ and _is_buffer(itag, ipayload) {
            return __jac_rt_str_contains(
                ptr[u8](data),
                size,
                ptr[u8](_buffer_data(ipayload)),
                _buffer_len(ipayload)
            );
        }
        raise TypeError("a bytes-like object is required");
    }
    is_tup = _is_tuple(tag, payload);
    if tag != ANY_TAG_LIST and not is_tup {
        raise TypeError(_not_iterable(tag, payload));
    }
    n = __mem_load_i64(payload + LIST_LEN);
    i = 0;
    while i < n {
        bits = _seq_bits(payload, i, is_tup);
        kind = _seq_kind(payload, i, is_tup);
        if __jac_rt_any_equal(
            __jac_rt_elem_tag(bits, kind),
            __jac_rt_elem_payload(bits, kind),
            itag,
            ipayload
        ) {
            return True;
        }
        i += 1;
    }
    return False;
}

impl _unordered(ta: int, pa: int, tb: int, pb: int, op: int) {
    sb = __jac_rt_sb_new(64);
    if op == ORDER_LT {
        _sb_cstr(sb, ptr[u8]("'<'"));
    } elif op == ORDER_LE {
        _sb_cstr(sb, ptr[u8]("'<='"));
    } elif op == ORDER_GT {
        _sb_cstr(sb, ptr[u8]("'>'"));
    } else {
        _sb_cstr(sb, ptr[u8]("'>='"));
    }
    _sb_cstr(sb, ptr[u8](" not supported between instances of '"));
    first_tag = tb if op == ORDER_GT or op == ORDER_GE else ta;
    first = pb if op == ORDER_GT or op == ORDER_GE else pa;
    second_tag = ta if op == ORDER_GT or op == ORDER_GE else tb;
    second = pa if op == ORDER_GT or op == ORDER_GE else pb;
    _sb_owned(sb, __jac_rt_class_name(__jac_rt_any_type_name(first_tag, first)));
    _sb_cstr(sb, ptr[u8]("' and '"));
    _sb_owned(sb, __jac_rt_class_name(__jac_rt_any_type_name(second_tag, second)));
    _sb_cstr(sb, ptr[u8]("'"));
    raise TypeError(__jac_rt_sb_finish(sb));
}

impl __jac_rt_any_order(ta: int, pa: int, tb: int, pb: int, op: int) -> bool {
    if op == ORDER_GT or op == ORDER_GE {
        return _any_less(tb, pb, ta, pa, op == ORDER_GE, op);
    }
    return _any_less(ta, pa, tb, pb, op == ORDER_LE, op);
}

impl _any_less(ta: int, pa: int, tb: int, pb: int, or_equal: bool, op: int) -> bool {
    if _is_number(ta) and _is_number(tb) {
        if ta != ANY_TAG_FLOAT and tb != ANY_TAG_FLOAT {
            return pa < pb or (or_equal and pa == pb);
        }
        fa = _as_float(ta, pa);
        fb = _as_float(tb, pb);
        return fa < fb or (or_equal and fa == fb);
    }
    if ta == ANY_TAG_STR and tb == ANY_TAG_STR {
        order = __jac_rt_str_cmp(
            ptr[u8](pa),
            __jac_rt_str_size(ptr[u8](pa)),
            ptr[u8](pb),
            __jac_rt_str_size(ptr[u8](pb))
        );
        return order < 0 or (or_equal and order == 0);
    }
    if ta == ANY_TAG_LIST and tb == ANY_TAG_LIST {
        return _seq_less(pa, False, pb, False, or_equal, op);
    }
    if _is_tuple(ta, pa) and _is_tuple(tb, pb) {
        return _seq_less(pa, True, pb, True, or_equal, op);
    }
    if _is_buffer(ta, pa) and _is_buffer(tb, pb) {
        order = __jac_rt_str_cmp(
            ptr[u8](_buffer_data(pa)),
            _buffer_len(pa),
            ptr[u8](_buffer_data(pb)),
            _buffer_len(pb)
        );
        return order < 0 or (or_equal and order == 0);
    }
    if ta == ANY_TAG_SET and tb == ANY_TAG_SET {
        na = __jac_rt_dict_len(pa);
        if na > __jac_rt_dict_len(pb)
            or (not or_equal and na == __jac_rt_dict_len(pb)) {
            return False;
        }
        kind = __mem_load_i64(pa + DICT_KEY_KIND);
        at = __jac_rt_dict_next(pa, -1);
        while at >= 0 {
            bits = __jac_rt_dict_key_at(pa, at);
            if _map_find(
                pb, __jac_rt_elem_tag(bits, kind), __jac_rt_elem_payload(bits, kind)
            )
                < 0 {
                return False;
            }
            at = __jac_rt_dict_next(pa, at);
        }
        return True;
    }
    _unordered(ta, pa, tb, pb, op);
    return False;
}

impl _seq_less(a: int, at: bool, b: int, bt: bool, or_equal: bool, op: int) -> bool {
    na = __mem_load_i64(a + LIST_LEN);
    nb = __mem_load_i64(b + LIST_LEN);
    i = 0;
    while i < na and i < nb {
        x = _seq_bits(a, i, at);
        kx = _seq_kind(a, i, at);
        y = _seq_bits(b, i, bt);
        ky = _seq_kind(b, i, bt);
        if not _elem_equal(x, kx, y, ky) {
            if (kx == KIND_UINT or ky == KIND_UINT)
                and (kx == KIND_UINT or kx == KIND_INT)
                and (ky == KIND_UINT or ky == KIND_INT) {
                return _uint_less(x, kx, y, ky);
            }
            return _any_less(
                __jac_rt_elem_tag(x, kx),
                __jac_rt_elem_payload(x, kx),
                __jac_rt_elem_tag(y, ky),
                __jac_rt_elem_payload(y, ky),
                False,
                op
            );
        }
        i += 1;
    }
    return na < nb or (or_equal and na == nb);
}

impl __jac_rt_class_tag(name: ptr[u8]) -> int {
    h = 5239054864098085;
    at = int(name);
    size = int(strlen(name));
    i = 0;
    while i < size {
        h = h ^ (int(__mem_load_i8(at + i)) & 255);
        low = (h & 67108863) * 435;
        high = ((h >> 26) * 435 + (h & 67108863) * 16384 + (low >> 26)) & 134217727;
        h = (high << 26) | (low & 67108863);
        i += 1;
    }
    return h & 9007199254740991;
}

impl __jac_rt_ref_swap(slot: int, value: int) {
    if value != 0 {
        __jac_rt_retain(value);
    }
    old = __mem_load_i64(slot);
    __mem_store_i64(slot, value);
    if old != 0 {
        __jac_rt_release(old);
    }
}

impl _box_owned(tag: int, payload: int) -> int {
    box = __jac_rt_any_box(tag, payload);
    __jac_rt_release(payload);
    return box;
}

impl _unsupported(op: int, ta: int, pa: int, tb: int, pb: int) {
    sb = __jac_rt_sb_new(64);
    _sb_cstr(sb, ptr[u8]("unsupported operand type(s) for "));
    if op == ARITH_ADD {
        _sb_cstr(sb, ptr[u8]("+"));
    } elif op == ARITH_SUB {
        _sb_cstr(sb, ptr[u8]("-"));
    } elif op == ARITH_MUL {
        _sb_cstr(sb, ptr[u8]("*"));
    } elif op == ARITH_DIV {
        _sb_cstr(sb, ptr[u8]("/"));
    } elif op == ARITH_FLOOR {
        _sb_cstr(sb, ptr[u8]("//"));
    } else {
        _sb_cstr(sb, ptr[u8]("%"));
    }
    _sb_cstr(sb, ptr[u8](": '"));
    _sb_owned(sb, __jac_rt_class_name(__jac_rt_any_type_name(ta, pa)));
    _sb_cstr(sb, ptr[u8]("' and '"));
    _sb_owned(sb, __jac_rt_class_name(__jac_rt_any_type_name(tb, pb)));
    _sb_cstr(sb, ptr[u8]("'"));
    raise TypeError(__jac_rt_sb_finish(sb));
}

impl _seq_join(a: int, at: bool, b: int, bt: bool) -> int {
    na = __mem_load_i64(a + LIST_LEN);
    nb = __mem_load_i64(b + LIST_LEN);
    if at {
        made = __jac_rt_tuple_new(na + nb);
        i = 0;
        while i < na {
            __jac_rt_tuple_set(made, i, _seq_bits(a, i, True), _seq_kind(a, i, True));
            i += 1;
        }
        j = 0;
        while j < nb {
            __jac_rt_tuple_set(
                made, na + j, _seq_bits(b, j, True), _seq_kind(b, j, True)
            );
            j += 1;
        }
        return made;
    }
    ka = __jac_rt_list_kind(a);
    kb = __jac_rt_list_kind(b);
    kind = ka if ka == kb else KIND_ANY;
    made = __jac_rt_list_new(na + nb, kind);
    _join_into(made, a, ka, kind);
    _join_into(made, b, kb, kind);
    return made;
}

impl _join_into(made: int, src: int, src_kind: int, kind: int) {
    count = __mem_load_i64(src + LIST_LEN);
    i = 0;
    while i < count {
        bits = _seq_bits(src, i, False);
        if kind == KIND_ANY and src_kind != KIND_ANY {
            boxed = __jac_rt_elem_box(bits, src_kind);
            __jac_rt_list_push(made, boxed, KIND_ANY);
            __jac_rt_release(boxed);
        } else {
            __jac_rt_list_push(made, bits, kind);
        }
        i += 1;
    }
}

impl _seq_repeat(a: int, is_tup: bool, times: int) -> int {
    n = __mem_load_i64(a + LIST_LEN);
    count = times if times > 0 else 0;
    if is_tup {
        made = __jac_rt_tuple_new(n * count);
        k = 0;
        while k < count {
            i = 0;
            while i < n {
                __jac_rt_tuple_set(
                    made, k * n + i, _seq_bits(a, i, True), _seq_kind(a, i, True)
                );
                i += 1;
            }
            k += 1;
        }
        return made;
    }
    kind = __jac_rt_list_kind(a);
    made = __jac_rt_list_new(n * count, kind);
    k = 0;
    while k < count {
        __jac_rt_list_extend(made, a, kind);
        k += 1;
    }
    return made;
}

impl __jac_rt_any_binary(op: int, ta: int, pa: int, tb: int, pb: int) -> int {
    if _is_number(ta) and _is_number(tb) {
        if op == ARITH_DIV or ta == ANY_TAG_FLOAT or tb == ANY_TAG_FLOAT {
            fa = _as_float(ta, pa);
            fb = _as_float(tb, pb);
            result = 0.0;
            if op == ARITH_ADD {
                result = fa + fb;
            } elif op == ARITH_SUB {
                result = fa - fb;
            } elif op == ARITH_MUL {
                result = fa * fb;
            } elif op == ARITH_DIV {
                result = fa / fb;
            } elif op == ARITH_FLOOR {
                result = fa // fb;
            } else {
                result = fa % fb;
            }
            return __jac_rt_any_box(ANY_TAG_FLOAT, __float_bits(result));
        }
        value = 0;
        if op == ARITH_ADD {
            value = pa + pb;
        } elif op == ARITH_SUB {
            value = pa - pb;
        } elif op == ARITH_MUL {
            value = pa * pb;
        } elif op == ARITH_FLOOR {
            value = pa // pb;
        } else {
            value = pa % pb;
        }
        return __jac_rt_any_box(ANY_TAG_INT, value);
    }
    if op == ARITH_ADD and ta == ANY_TAG_STR and tb == ANY_TAG_STR {
        return _box_owned(
            ANY_TAG_STR,
            int(
                __jac_rt_str_concat(
                    ptr[u8](pa),
                    __jac_rt_str_size(ptr[u8](pa)),
                    ptr[u8](pb),
                    __jac_rt_str_size(ptr[u8](pb))
                )
            )
        );
    }
    if op == ARITH_ADD and ta == ANY_TAG_LIST and tb == ANY_TAG_LIST {
        return _box_owned(ANY_TAG_LIST, _seq_join(pa, False, pb, False));
    }
    if op == ARITH_ADD and _is_tuple(ta, pa) and _is_tuple(tb, pb) {
        return _box_owned(ANY_TAG_OBJ, _seq_join(pa, True, pb, True));
    }
    if op == ARITH_MUL and (ta == ANY_TAG_INT or tb == ANY_TAG_INT) {
        seq_tag = ta;
        seq = pa;
        times = pb;
        if ta == ANY_TAG_INT {
            seq_tag = tb;
            seq = pb;
            times = pa;
        }
        if seq_tag == ANY_TAG_STR {
            return _box_owned(
                ANY_TAG_STR,
                int(
                    __jac_rt_str_repeat(
                        ptr[u8](seq), __jac_rt_str_size(ptr[u8](seq)), times
                    )
                )
            );
        }
        if seq_tag == ANY_TAG_LIST {
            return _box_owned(ANY_TAG_LIST, _seq_repeat(seq, False, times));
        }
        if _is_tuple(seq_tag, seq) {
            return _box_owned(ANY_TAG_OBJ, _seq_repeat(seq, True, times));
        }
    }
    if op == ARITH_ADD and (ta == ANY_TAG_STR or ta == ANY_TAG_LIST) {
        sb = __jac_rt_sb_new(64);
        _sb_cstr(
            sb,
            ptr[u8]("can only concatenate str (not \"")
                if ta == ANY_TAG_STR
                else ptr[u8]("can only concatenate list (not \"")
        );
        _sb_owned(sb, __jac_rt_class_name(__jac_rt_any_type_name(tb, pb)));
        _sb_cstr(
            sb, ptr[u8]("\") to str") if ta == ANY_TAG_STR else ptr[u8]("\") to list")
        );
        raise TypeError(__jac_rt_sb_finish(sb));
    }
    _unsupported(op, ta, pa, tb, pb);
    return 0;
}

impl __jac_rt_any_unary(op: int, tag: int, payload: int) -> int {
    if tag == ANY_TAG_FLOAT and op != UNARY_INVERT {
        if op == UNARY_POSITIVE {
            return __jac_rt_any_box(ANY_TAG_FLOAT, payload);
        }
        return __jac_rt_any_box(ANY_TAG_FLOAT, __float_bits(-__bits_float(payload)));
    }
    if tag == ANY_TAG_INT or tag == ANY_TAG_BOOL {
        if op == UNARY_POSITIVE {
            return __jac_rt_any_box(ANY_TAG_INT, payload);
        }
        if op == UNARY_INVERT {
            return __jac_rt_any_box(ANY_TAG_INT, payload ^ -1);
        }
        return __jac_rt_any_box(ANY_TAG_INT, 0 - payload);
    }
    sb = __jac_rt_sb_new(48);
    if op == UNARY_POSITIVE {
        _sb_cstr(sb, ptr[u8]("bad operand type for unary +: '"));
    } elif op == UNARY_INVERT {
        _sb_cstr(sb, ptr[u8]("bad operand type for unary ~: '"));
    } else {
        _sb_cstr(sb, ptr[u8]("bad operand type for unary -: '"));
    }
    _sb_owned(sb, __jac_rt_class_name(__jac_rt_any_type_name(tag, payload)));
    _sb_cstr(sb, ptr[u8]("'"));
    raise TypeError(__jac_rt_sb_finish(sb));
}

impl _kind_bits(bits: int, have: int, want: int) -> int {
    if have == want {
        __jac_rt_elem_retain(bits, want);
        return bits;
    }
    if want == KIND_ANY {
        return __jac_rt_elem_box(bits, have);
    }
    held = __jac_rt_elem_payload(bits, have);
    __jac_rt_elem_retain(held, want);
    return held;
}

impl __jac_rt_dict_convert(
    tag: int, payload: int, key_kind: int, val_kind: int
) -> int {
    if tag != ANY_TAG_DICT and not (tag == ANY_TAG_SET and val_kind < 0) {
        raise TypeError(_not_iterable(tag, payload));
    }
    made = __jac_rt_dict_new(key_kind, val_kind);
    have_key = __mem_load_i64(payload + DICT_KEY_KIND);
    have_val = __mem_load_i64(payload + DICT_VAL_KIND);
    at = __jac_rt_dict_next(payload, -1);
    while at >= 0 {
        key = _kind_bits(__jac_rt_dict_key_at(payload, at), have_key, key_kind);
        value = 0;
        if val_kind >= 0 {
            value = _kind_bits(__jac_rt_dict_val_at(payload, at), have_val, val_kind);
        }
        __jac_rt_dict_set(made, key, value, key_kind, val_kind);
        __jac_rt_elem_release(key, key_kind);
        if val_kind >= 0 {
            __jac_rt_elem_release(value, val_kind);
        }
        at = __jac_rt_dict_next(payload, at);
    }
    return made;
}

impl _bind_kind(have: int, want: int) -> bool {
    return have == want or want == KIND_ANY;
}

impl _bind_elem(bits: int, kind: int, family: int) -> bool {
    if kind == KIND_ANY {
        return True;
    }
    tag = __jac_rt_elem_tag(bits, KIND_ANY);
    if kind == KIND_INT or kind == KIND_UINT {
        return tag == ANY_TAG_INT or tag == ANY_TAG_BOOL;
    }
    if kind == KIND_FLOAT {
        return tag == ANY_TAG_FLOAT;
    }
    if kind == KIND_BOOL {
        return tag == ANY_TAG_BOOL;
    }
    if kind == KIND_STR {
        return tag == ANY_TAG_STR;
    }
    if kind != KIND_REF or family < 0 or tag != (family & 255) {
        return False;
    }
    if tag == ANY_TAG_OBJ {
        return True;
    }
    payload = __jac_rt_elem_payload(bits, KIND_ANY);
    inner_first = ((family >> 8) & 255) - 1;
    inner_second = ((family >> 16) & 255) - 1;
    if tag == ANY_TAG_LIST {
        return _bind_kind(__jac_rt_list_kind(payload), inner_first);
    }
    return _bind_kind(__mem_load_i64(payload + DICT_KEY_KIND), inner_first)
        and (
            tag == ANY_TAG_SET
            or _bind_kind(__mem_load_i64(payload + DICT_VAL_KIND), inner_second)
        );
}

impl _bind_refuse(label: ptr[u8]) {
    sb = __jac_rt_sb_new(48);
    _sb_cstr(sb, ptr[u8]("a container held as `any` is not a "));
    _sb_cstr(sb, label);
    raise TypeError(__jac_rt_sb_finish(sb));
}

impl _bind_list(payload: int, kind: int, family: int, label: ptr[u8]) -> int {
    n = __mem_load_i64(payload + LIST_LEN);
    data = __mem_load_i64(payload + LIST_DATA);
    i = 0;
    while i < n {
        if not _bind_elem(__mem_load_i64(data + i * SLOT), kind, family) {
            _bind_refuse(label);
        }
        i += 1;
    }
    made = __jac_rt_list_new(n, kind);
    i = 0;
    while i < n {
        held = _kind_bits(__mem_load_i64(data + i * SLOT), KIND_ANY, kind);
        __jac_rt_list_push(made, held, kind);
        __jac_rt_elem_release(held, kind);
        i += 1;
    }
    return made;
}

impl _bind_dict(
    payload: int,
    want: int,
    key_kind: int,
    key_family: int,
    val_kind: int,
    val_family: int,
    label: ptr[u8]
) -> int {
    have_key = __mem_load_i64(payload + DICT_KEY_KIND);
    have_val = __mem_load_i64(payload + DICT_VAL_KIND);
    keys_ok = _bind_kind(have_key, key_kind) or have_key == KIND_ANY;
    vals_ok = want == ANY_TAG_SET
        or _bind_kind(have_val, val_kind)
        or have_val == KIND_ANY;
    if not keys_ok or not vals_ok {
        _bind_refuse(label);
    }
    at = __jac_rt_dict_next(payload, -1);
    while at >= 0 {
        if (
            have_key == KIND_ANY
            and not _bind_elem(__jac_rt_dict_key_at(payload, at), key_kind, key_family)
        )
            or (
                want != ANY_TAG_SET
                and have_val == KIND_ANY
                and not _bind_elem(
                    __jac_rt_dict_val_at(payload, at), val_kind, val_family
                )
            ) {
            _bind_refuse(label);
        }
        at = __jac_rt_dict_next(payload, at);
    }
    return __jac_rt_dict_convert(
        want, payload, key_kind, have_val if want == ANY_TAG_SET else val_kind
    );
}

impl __jac_rt_any_bind(
    tag: int,
    payload: int,
    want: int,
    first: int,
    first_family: int,
    second: int,
    second_family: int,
    label: ptr[u8]
) -> int {
    if tag == ANY_TAG_NONE or payload == 0 {
        return 0;
    }
    if tag != want {
        _bind_refuse(label);
    }
    if want == ANY_TAG_LIST {
        have = __jac_rt_list_kind(payload);
        if _bind_kind(have, first) {
            __jac_rt_retain(payload);
            return payload;
        }
        if __mem_load_i64(payload + LIST_LEN) == 0 {
            __jac_rt_list_rekind(payload, first);
            __jac_rt_retain(payload);
            return payload;
        }
        if have != KIND_ANY {
            _bind_refuse(label);
        }
        return _bind_list(payload, first, first_family, label);
    }
    have_key = __mem_load_i64(payload + DICT_KEY_KIND);
    have_val = __mem_load_i64(payload + DICT_VAL_KIND);
    if _bind_kind(have_key, first)
        and (want == ANY_TAG_SET or _bind_kind(have_val, second)) {
        __jac_rt_retain(payload);
        return payload;
    }
    if __mem_load_i64(payload + DICT_LEN_AT) == 0 {
        __jac_rt_dict_rekind(
            payload, first, have_val if want == ANY_TAG_SET else second
        );
        __jac_rt_retain(payload);
        return payload;
    }
    return _bind_dict(payload, want, first, first_family, second, second_family, label);
}

impl __jac_rt_any_getitem(tag: int, payload: int, ktag: int, kpayload: int) -> int {
    if tag == ANY_TAG_DICT {
        kind = __mem_load_i64(payload + DICT_KEY_KIND);
        at = -1;
        if (kind == KIND_STR and ktag == ANY_TAG_STR)
            or (kind == KIND_INT and (ktag == ANY_TAG_INT or ktag == ANY_TAG_BOOL)) {
            at = __jac_rt_dict_find(payload, kpayload, kind);
        } else {
            at = _map_find(payload, ktag, kpayload);
        }
        if at < 0 {
            sb = __jac_rt_sb_new(32);
            _any_text(sb, ktag, kpayload, TEXT_REPR);
            raise KeyError(__jac_rt_sb_finish(sb));
        }
        return __jac_rt_elem_box(
            __jac_rt_dict_val_at(payload, at), __mem_load_i64(payload + DICT_VAL_KIND)
        );
    }
    if ktag != ANY_TAG_INT and ktag != ANY_TAG_BOOL {
        raise TypeError("indices must be integers");
    }
    if tag == ANY_TAG_STR {
        size = __jac_rt_str_size(ptr[u8](payload));
        total = __jac_rt_str_cp_total(ptr[u8](payload), ptr[u8](payload), size);
        index = kpayload + total if kpayload < 0 else kpayload;
        if index < 0 or index >= total {
            raise IndexError("string index out of range");
        }
        return _box_owned(
            ANY_TAG_STR,
            int(__jac_rt_str_index(ptr[u8](payload), ptr[u8](payload), size, index))
        );
    }
    is_tup = _is_tuple(tag, payload);
    if tag != ANY_TAG_LIST and not is_tup {
        raise TypeError("object is not subscriptable");
    }
    n = __mem_load_i64(payload + LIST_LEN);
    index = kpayload + n if kpayload < 0 else kpayload;
    if index < 0 or index >= n {
        raise IndexError(
            ptr[u8]("tuple index out of range")
                if is_tup
                else ptr[u8]("list index out of range")
        );
    }
    return __jac_rt_elem_box(
        _seq_bits(payload, index, is_tup), _seq_kind(payload, index, is_tup)
    );
}

impl _uint_less(x: int, kx: int, y: int, ky: int) -> bool {
    x_big = kx == KIND_UINT and x < 0;
    y_big = ky == KIND_UINT and y < 0;
    if x_big != y_big {
        return y_big;
    }
    return x < y;
}

impl _uint_equal(x: int, kx: int, y: int, ky: int) -> bool {
    if kx == KIND_UINT and ky == KIND_UINT {
        return x == y;
    }
    big = x if kx == KIND_UINT else y;
    other = y if kx == KIND_UINT else x;
    other_kind = ky if kx == KIND_UINT else kx;
    tag = __jac_rt_elem_tag(other, other_kind);
    if tag != ANY_TAG_FLOAT {
        return False;
    }
    wide = float(big & 9223372036854775807) + 9223372036854775808.0;
    return __bits_float(__jac_rt_elem_payload(other, other_kind)) == wide;
}
