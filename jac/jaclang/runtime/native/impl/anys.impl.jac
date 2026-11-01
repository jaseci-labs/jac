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
