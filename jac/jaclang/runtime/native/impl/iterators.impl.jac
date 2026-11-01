impl __jac_rt_elem_share(bits: int, kind: int) -> int {
    __jac_rt_elem_retain(bits, kind);
    return bits;
}

impl __jac_rt_iter_new(code: int, state: int) -> int {
    it = __jac_rt_alloc(ITER_SIZE);
    __jac_rt_set_type(it, int(ptr[u8]("iterator")));
    __mem_store_i64(it + ITER_NEXT, code);
    __jac_rt_retain(state);
    __mem_store_i64(it + ITER_STATE, state);
    __mem_store_i64(it - HDR_DTOR_BACK, int(_iter_drop));
    return it;
}

impl _iter_drop(it: ptr[u8]) {
    at = int(it);
    __jac_rt_release(__mem_load_i64(at + ITER_STATE));
    __jac_rt_free_block(at - HDR_TOTAL);
}

impl _seq_state(coll: int, index: int, kind: int) -> int {
    state = __jac_rt_alloc(SEQ_SIZE);
    __jac_rt_set_type(state, int(ptr[u8]("iterator_state")));
    __jac_rt_retain(coll);
    __mem_store_i64(state + SEQ_COLL, coll);
    __mem_store_i64(state + SEQ_INDEX, index);
    __mem_store_i64(state + SEQ_KIND, kind);
    __mem_store_i64(state - HDR_DTOR_BACK, int(_seq_drop));
    return state;
}

impl _seq_drop(state: ptr[u8]) {
    at = int(state);
    __jac_rt_release(__mem_load_i64(at + SEQ_COLL));
    __jac_rt_free_block(at - HDR_TOTAL);
}

impl __jac_rt_iter_list(lst: int, kind: int) -> int {
    state = _seq_state(lst, 0, kind);
    it = __jac_rt_iter_new(int(_list_next), state);
    __jac_rt_release(state);
    return it;
}

impl _list_next(state: ptr[u8], out: ptr[u8]) -> bool {
    at = int(state);
    lst = __mem_load_i64(at + SEQ_COLL);
    index = __mem_load_i64(at + SEQ_INDEX);
    if index >= __mem_load_i64(lst + LIST_LEN) {
        return False;
    }
    bits = __mem_load_i64(__mem_load_i64(lst + LIST_DATA) + index * SLOT);
    __jac_rt_elem_retain(bits, __mem_load_i64(at + SEQ_KIND));
    __mem_store_i64(int(out), bits);
    __mem_store_i64(at + SEQ_INDEX, index + 1);
    return True;
}

impl __jac_rt_iter_keys(d: int, kind: int) -> int {
    state = _seq_state(d, -1, kind);
    it = __jac_rt_iter_new(int(_keys_next), state);
    __jac_rt_release(state);
    return it;
}

impl _keys_next(state: ptr[u8], out: ptr[u8]) -> bool {
    at = int(state);
    d = __mem_load_i64(at + SEQ_COLL);
    cursor = __jac_rt_dict_next(d, __mem_load_i64(at + SEQ_INDEX));
    if cursor < 0 {
        return False;
    }
    bits = __jac_rt_dict_key_at(d, cursor);
    __jac_rt_elem_retain(bits, __mem_load_i64(at + SEQ_KIND));
    __mem_store_i64(int(out), bits);
    __mem_store_i64(at + SEQ_INDEX, cursor);
    return True;
}

impl __jac_rt_iter_range(start: int, stop: int, step: int) -> int {
    state = __jac_rt_range_new(start, stop, step);
    it = __jac_rt_iter_new(int(_range_next), state);
    __jac_rt_release(state);
    return it;
}

impl _range_next(state: ptr[u8], out: ptr[u8]) -> bool {
    at = int(state);
    current = __mem_load_i64(at + RANGE_START);
    stop = __mem_load_i64(at + RANGE_STOP);
    step = __mem_load_i64(at + RANGE_STEP);
    if (step > 0 and current >= stop) or (step < 0 and current <= stop) {
        return False;
    }
    __mem_store_i64(int(out), current);
    following = current + step;
    if (step > 0 and following < current) or (step < 0 and following > current) {
        following = stop;
    }
    __mem_store_i64(at + RANGE_START, following);
    return True;
}

impl __jac_rt_iter_str(text: ptr[u8]) -> int {
    state = _seq_state(int(text), 0, KIND_STR);
    it = __jac_rt_iter_new(int(_str_next), state);
    __jac_rt_release(state);
    return it;
}

impl _str_next(state: ptr[u8], out: ptr[u8]) -> bool {
    at = int(state);
    text = __mem_load_i64(at + SEQ_COLL);
    offset = __mem_load_i64(at + SEQ_INDEX);
    size = __jac_rt_str_size(ptr[u8](text));
    if offset >= size {
        return False;
    }
    width = _utf8_width(int(__mem_load_i8(text + offset)));
    if offset + width > size {
        width = size - offset;
    }
    piece = __jac_rt_str_new(ptr[u8](text + offset), width);
    __mem_store_i64(int(out), int(piece));
    __mem_store_i64(at + SEQ_INDEX, offset + width);
    return True;
}

impl _utf8_width(lead: int) -> int {
    byte = lead & 255;
    if byte < 128 {
        return 1;
    }
    if byte >= 240 {
        return 4;
    }
    if byte >= 224 {
        return 3;
    }
    if byte >= 192 {
        return 2;
    }
    return 1;
}

impl __jac_rt_gen_frame(size: int, drop: int) -> int {
    frame = __jac_rt_alloc(size);
    __jac_rt_set_type(frame, int(ptr[u8]("generator")));
    at = 0;
    while at < size {
        __mem_store_i64(frame + at, 0);
        at += SLOT;
    }
    __mem_store_i64(frame - HDR_DTOR_BACK, drop);
    return frame;
}

impl __jac_rt_range_new(start: int, stop: int, step: int) -> int {
    made = __jac_rt_alloc(RANGE_SIZE);
    __jac_rt_set_type(made, int(ptr[u8]("range")));
    __mem_store_i64(made + RANGE_START, start);
    __mem_store_i64(made + RANGE_STOP, stop);
    __mem_store_i64(made + RANGE_STEP, step);
    return made;
}
