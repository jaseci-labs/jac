impl _holds_ref(tag: int) -> bool {
    return tag >= ANY_TAG_FIRST_REF and tag <= ANY_TAG_LAST_REF;
}

impl __jac_rt_any_retain(tag: int, payload: int) {
    if payload != 0 and _holds_ref(tag) {
        __jac_rt_retain(payload);
    }
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
    return box;
}

impl _box_drop(box: ptr[u8]) {
    at = int(box);
    __jac_rt_any_release(__mem_load_i64(at + BOX_TAG), __mem_load_i64(at + BOX_PAYLOAD));
    __jac_rt_free_block(at - HDR_TOTAL);
}

impl __jac_rt_any_truthy(tag: int, payload: int) -> bool {
    if tag == ANY_TAG_NONE {
        return False;
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
    return True;
}

impl __jac_rt_any_str(tag: int, payload: int) -> ptr[u8] {
    if tag == ANY_TAG_STR {
        __jac_rt_retain(payload);
        return ptr[u8](payload);
    }
    if tag == ANY_TAG_INT {
        return __jac_rt_str_from_int(payload);
    }
    if tag == ANY_TAG_BOOL {
        if payload != 0 {
            return __jac_rt_str_new(ptr[u8]("True"), 4);
        }
        return __jac_rt_str_new(ptr[u8]("False"), 5);
    }
    if tag == ANY_TAG_NONE {
        return __jac_rt_str_new(ptr[u8]("None"), 4);
    }
    return ptr[u8](0);
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
    if tag == ANY_TAG_OBJ {
        return __jac_rt_type_name(payload);
    }
    if tag == ANY_TAG_BOOL {
        return ptr[u8]("bool");
    }
    return ptr[u8]("NoneType");
}

impl __jac_rt_any_isa(tag: int, payload: int, name: ptr[u8]) -> bool {
    return tag == ANY_TAG_OBJ
        and payload != 0
        and __jac_rt_cstr_eq(__jac_rt_type_name(payload), name);
}

impl __jac_rt_cstr_eq(a: ptr[u8], b: ptr[u8]) -> bool {
    if int(a) == int(b) {
        return True;
    }
    if int(a) == 0 or int(b) == 0 {
        return False;
    }
    return strcmp(int(a), int(b)) == 0;
}

impl __jac_rt_str_from_cstr(text: ptr[u8]) -> ptr[u8] {
    if int(text) == 0 {
        return __jac_rt_str_new(text, 0);
    }
    return __jac_rt_str_new(text, strlen(int(text)));
}
