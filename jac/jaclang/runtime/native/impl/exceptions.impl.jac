impl __jac_rt_exit(code: int) {
    fflush(ptr[u8]());
    _exit(i32(code));
}

impl __jac_rt_exc_context -> ptr[JacRtExcContext] {
    return ptr[JacRtExcContext](__thread_local_block("jac_rt_exception_context", 40));
}

impl __jac_rt_exc_jmp_buf(state: ptr[JacRtExcState]) -> ptr[u8] {
    return ptr[u8](state) + EXC_STATE_HEADER;
}

impl __jac_rt_exc_push(state: ptr[JacRtExcState]) {
    ctx = __jac_rt_exc_context();
    cell = state.view(1);
    cell[0].prev = ctx.view(1)[0].handler;
    cell[0].type_id = i32(0);
    cell[0].target = ptr[u8](0);
    cell[0].message = ptr[u8](0);
    cell[0].saved_unwind_top = ctx.view(1)[0].unwind_top;
    ctx.view(1)[0].handler = state;
}

impl __jac_rt_exc_pop(state: ptr[JacRtExcState]) {
    ctx = __jac_rt_exc_context();
    ctx.view(1)[0].handler = state.view(1)[0].prev;
}

impl __jac_rt_unwind_push(record: ptr[JacRtUnwindRecord]) {
    ctx = __jac_rt_exc_context();
    record.view(1)[0].next = ctx.view(1)[0].unwind_top;
    ctx.view(1)[0].unwind_top = record;
}

impl __jac_rt_unwind_pop(record: ptr[JacRtUnwindRecord]) {
    ctx = __jac_rt_exc_context();
    ctx.view(1)[0].unwind_top = record.view(1)[0].next;
}

impl __jac_rt_raise(target: ptr[u8], type_id: i32, message: ptr[u8]) {
    ctx = __jac_rt_exc_context();
    handler = ctx.view(1)[0].handler;
    if int(handler) == 0 {
        _report_uncaught(message);
        fflush(ptr[u8]());
        _exit(i32(1));
    }
    cell = handler.view(1);
    cell[0].target = target;
    cell[0].type_id = type_id;
    cell[0].message = message;
    stop = cell[0].saved_unwind_top;
    record = ctx.view(1)[0].unwind_top;
    while int(record) != 0 and int(record) != int(stop) {
        entry_record = record.view(1)[0];
        ctx.view(1)[0].unwind_top = entry_record.next;
        entry_record.cleanup(entry_record.target);
        record = ctx.view(1)[0].unwind_top;
    }
    ctx.view(1)[0].unwind_top = stop;
    _longjmp(__jac_rt_exc_jmp_buf(handler), i32(1));
}

impl __jac_rt_raise_builtin(type_id: i32, message: ptr[u8]) {
    __jac_rt_raise(message, type_id, message);
}

impl _write_text(text: ptr[u8]) {
    write(i32(2), text, strlen(text));
}

impl _report_uncaught(message: ptr[u8]) {
    _write_text(ptr[u8]("Uncaught exception: "));
    if int(message) != 0 {
        _write_text(message);
    }
    _write_text(ptr[u8]("\n"));
}

impl _lineage_slot(key: int) -> int {
    table = __global_block("__jac_rt_exc_lineage", 4096);
    at = (key ^ (key >> 17) ^ (key >> 31)) & (EXC_LINEAGE_SLOTS - 1);
    probes = 0;
    while probes < EXC_LINEAGE_SLOTS {
        held = __mem_load_i64(table + at * 8);
        if held == key or held == 0 {
            return table + at * 8;
        }
        at = (at + 1) & (EXC_LINEAGE_SLOTS - 1);
        probes += 1;
    }
    return 0;
}

impl __jac_rt_exc_lineage_add(type_id: int, base_id: int) {
    key = (type_id << 32) | base_id;
    place = _lineage_slot(key);
    if place != 0 {
        __mem_store_i64(place, key);
    }
}

impl __jac_rt_exc_isa(type_id: int, base_id: int) -> bool {
    if type_id == base_id {
        return True;
    }
    key = (type_id << 32) | base_id;
    place = _lineage_slot(key);
    return place != 0 and __mem_load_i64(place) == key;
}

impl __jac_rt_exc_class_add(name: ptr[u8], type_id: int) {
    table = __global_block("__jac_rt_exc_classes", 1025);
    count = __mem_load_i64(table);
    i = 0;
    while i < count {
        if __mem_load_i64(table + 16 + i * 16) == type_id {
            return;
        }
        i += 1;
    }
    if count >= 511 {
        return;
    }
    __mem_store_i64(table + 8 + count * 16, int(name));
    __mem_store_i64(table + 16 + count * 16, type_id);
    __mem_store_i64(table, count + 1);
}

impl __jac_rt_exc_class_of(held: int, fallback: int) -> int {
    if held == 0 {
        return fallback;
    }
    name = ptr[u8](__mem_load_i64(held - 24));
    table = __global_block("__jac_rt_exc_classes", 1025);
    count = __mem_load_i64(table);
    i = 0;
    while i < count {
        if int(strcmp(ptr[u8](__mem_load_i64(table + 8 + i * 16)), name)) == 0 {
            return __mem_load_i64(table + 16 + i * 16);
        }
        i += 1;
    }
    return fallback;
}
