impl __jac_rt_cell_new(kind: int) -> int {
    cell = __jac_rt_alloc(CELL_SIZE);
    __jac_rt_set_type(cell, int(ptr[u8]("cell")));
    __mem_store_i64(cell + CELL_BITS, 0);
    __mem_store_i64(cell + CELL_KIND, kind);
    __mem_store_i64(cell - HDR_DTOR_BACK, int(_cell_drop));
    return cell;
}

impl __jac_rt_cell_get_ref(cell: int) -> int {
    bits = __mem_load_i64(cell + CELL_BITS);
    __jac_rt_elem_retain(bits, __mem_load_i64(cell + CELL_KIND));
    return bits;
}

impl __jac_rt_cell_set(cell: int, bits: int, kind: int) {
    __jac_rt_elem_retain(bits, kind);
    previous = __mem_load_i64(cell + CELL_BITS);
    __mem_store_i64(cell + CELL_BITS, bits);
    __jac_rt_elem_release(previous, kind);
}

impl __jac_rt_closure_new(code: int, count: int) -> int {
    closure = __jac_rt_alloc(CLOSURE_CELLS + count * SLOT);
    __jac_rt_set_type(closure, int(ptr[u8]("closure")));
    __mem_store_i64(closure + CLOSURE_CODE, code);
    __mem_store_i64(closure + CLOSURE_COUNT, count);
    i = 0;
    while i < count {
        __mem_store_i64(closure + CLOSURE_CELLS + i * SLOT, 0);
        i += 1;
    }
    __mem_store_i64(closure - HDR_DTOR_BACK, int(_closure_drop));
    return closure;
}

impl __jac_rt_closure_set(closure: int, index: int, cell: int) {
    __jac_rt_retain(cell);
    __mem_store_i64(closure + CLOSURE_CELLS + index * SLOT, cell);
}

impl _cell_drop(cell: ptr[u8]) {
    at = int(cell);
    __jac_rt_elem_release(
        __mem_load_i64(at + CELL_BITS), __mem_load_i64(at + CELL_KIND)
    );
    __jac_rt_free_block(at - HDR_TOTAL);
}

impl _closure_drop(closure: ptr[u8]) {
    at = int(closure);
    count = __mem_load_i64(at + CLOSURE_COUNT);
    i = 0;
    while i < count {
        held = __mem_load_i64(at + CLOSURE_CELLS + i * SLOT);
        if held != 0 {
            __jac_rt_release(held);
        }
        i += 1;
    }
    __jac_rt_free_block(at - HDR_TOTAL);
}

impl __jac_rt_task_new(count: int) -> int {
    task = __jac_rt_alloc(TASK_ARGS + count * SLOT);
    __jac_rt_set_type(task, int(ptr[u8]("task")));
    at = 0;
    while at < TASK_ARGS + count * SLOT {
        __mem_store_i64(task + at, 0);
        at += SLOT;
    }
    __mem_store_i64(task + TASK_KIND, -1);
    __mem_store_i64(task + TASK_COUNT, count);
    __mem_store_i64(task - HDR_DTOR_BACK, int(_task_drop));
    return task;
}

impl __jac_rt_task_result(task: int) -> int {
    error = __mem_load_i64(task + TASK_ERROR);
    if error != 0 {
        __jac_rt_raise(
            ptr[u8](__mem_load_i64(task + TASK_ORIGIN)),
            i32(error),
            ptr[u8](__mem_load_i64(task + TASK_MESSAGE))
        );
    }
    bits = __mem_load_i64(task + TASK_BITS);
    kind = __mem_load_i64(task + TASK_KIND);
    if kind >= 0 {
        __jac_rt_elem_retain(bits, kind);
    }
    return bits;
}

impl _task_drop(task: ptr[u8]) {
    at = int(task);
    kind = __mem_load_i64(at + TASK_KIND);
    if kind >= 0 {
        __jac_rt_elem_release(__mem_load_i64(at + TASK_BITS), kind);
    }
    __jac_rt_free_block(at - HDR_TOTAL);
}
