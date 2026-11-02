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
