import from c {
    obj FutureObj {
        has ob_base: _object,
            fut_loop: ptr[PyObject],
            fut_callback0: ptr[PyObject],
            fut_context0: ptr[PyObject],
            fut_callbacks: ptr[PyObject],
            fut_exception: ptr[PyObject],
            fut_exception_tb: ptr[PyObject],
            fut_result: ptr[PyObject],
            fut_source_tb: ptr[PyObject],
            fut_cancel_msg: ptr[PyObject],
            fut_cancelled_exc: ptr[PyObject],
            fut_awaited_by: ptr[PyObject],
            fut_state: i32,
            fut_is_task: i8,
            fut_awaited_by_is_set: i8,
            fut_bits: u8,
            fut_bits_pad: u8;
    }  obj TaskObj {
        has base: FutureObj,
            task_num_cancels_requested: i32,
            task_fut_waiter: ptr[PyObject],
            task_coro: ptr[PyObject],
            task_name: ptr[PyObject],
            task_context: ptr[PyObject],
            task_node_next: ptr,
            task_node_prev: ptr;
    }  obj TaskStepMethWrapper {
        has ob_base: _object,
            sw_task: ptr[PyObject],
            sw_arg: ptr[PyObject];
    }  obj FutureIterObject {
        has ob_base: _object,
            future: ptr[PyObject];
    }  obj LlistNode {
        has next: ptr,
            prev: ptr;
    }  obj CallStack {
        has slot0: ptr[PyObject],
            slot1: ptr[PyObject],
            slot2: ptr[PyObject],
            slot3: ptr[PyObject],
            slot4: ptr[PyObject];
    }
}

glob FUTURE_OBJECT_SIZE: Final[int] = 112,
     TASK_OBJECT_SIZE: Final[int] = 168,
     TASK_STEP_WRAPPER_SIZE: Final[int] = 32,
     FUTURE_ITER_SIZE: Final[int] = 24,
     TASK_NODE_OFFSET: Final[int] = 152;

glob STATE_PENDING: Final[int] = 0,
     STATE_CANCELLED: Final[int] = 1,
     STATE_FINISHED: Final[int] = 2;

glob BIT_LOG_TB: Final[int] = 1,
     BIT_BLOCKING: Final[int] = 2,
     BIT_MUST_CANCEL: Final[int] = 4,
     BIT_LOG_DESTROY_PENDING: Final[int] = 8;

glob ARGUMENTS_OFFSET: Final[u64] = 0x8000000000000000;

glob STATE_FUTURE_ITER_TYPE: Final[int] = 0,
     STATE_TASK_STEP_WRAPPER_TYPE: Final[int] = 1,
     STATE_FUTURE_TYPE: Final[int] = 2,
     STATE_TASK_TYPE: Final[int] = 3,
     STATE_ASYNCIO_MOD: Final[int] = 4,
     STATE_CONTEXT_KWNAME: Final[int] = 5,
     STATE_NON_ASYNCIO_TASKS: Final[int] = 6,
     STATE_NON_ASYNCIO_EAGER_TASKS: Final[int] = 7,
     STATE_ISCOROUTINE_TYPECACHE: Final[int] = 8,
     STATE_GET_EVENT_LOOP_POLICY: Final[int] = 9,
     STATE_FUTURE_REPR_FUNC: Final[int] = 10,
     STATE_CANCELLED_ERROR: Final[int] = 11,
     STATE_INVALID_STATE_ERROR: Final[int] = 12,
     STATE_TASK_GET_STACK_FUNC: Final[int] = 13,
     STATE_TASK_PRINT_STACK_FUNC: Final[int] = 14,
     STATE_TASK_REPR_FUNC: Final[int] = 15,
     STATE_ISCOROUTINE_FUNC: Final[int] = 16,
     STATE_TRACEBACK_EXTRACT_STACK: Final[int] = 17,
     STATE_COUNT: Final[int] = 18;

obj ModuleToken {
    has handle: ptr = ptr();
}

glob asyncio_module_token: ModuleToken = ModuleToken();

obj AsyncioState(NativeState) {
    has task_name_counter: int = 0;

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
}

obj Identifiers {
    has ready: bool = False,
        call_soon: ptr[PyObject] = NULL,
        get_debug: ptr[PyObject] = NULL,
        get_event_loop: ptr[PyObject] = NULL,
        get_loop: ptr[PyObject] = NULL,
        loop_attr: ptr[PyObject] = NULL,
        cancel: ptr[PyObject] = NULL,
        throw: ptr[PyObject] = NULL,
        asyncio_future_blocking: ptr[PyObject] = NULL,
        add_done_callback: ptr[PyObject] = NULL,
        is_running: ptr[PyObject] = NULL,
        add: ptr[PyObject] = NULL,
        discard: ptr[PyObject] = NULL,
        done: ptr[PyObject] = NULL,
        call_exception_handler: ptr[PyObject] = NULL,
        message: ptr[PyObject] = NULL,
        exception: ptr[PyObject] = NULL,
        future: ptr[PyObject] = NULL,
        source_traceback: ptr[PyObject] = NULL,
        task: ptr[PyObject] = NULL,
        pending: ptr[PyObject] = NULL,
        cancelled: ptr[PyObject] = NULL,
        finished: ptr[PyObject] = NULL,
        result: ptr[PyObject] = NULL,
        kw_loop: ptr[PyObject] = NULL,
        kw_name: ptr[PyObject] = NULL,
        kw_context: ptr[PyObject] = NULL,
        kw_eager_start: ptr[PyObject] = NULL;
}

glob ids = Identifiers();

def intern_identifiers -> bool;

def fut_of(op: ptr[PyObject]) -> ptr[FutureObj];

def task_of(op: ptr[PyObject]) -> ptr[TaskObj];

def has_bit(op: ptr[PyObject], bit: int) -> bool;

def set_bit(op: ptr[PyObject], bit: int, value: bool);

def state_ref(module: ptr[PyObject], index: int) -> ptr[PyObject];

def module_of_type(type: ptr[PyObject]) -> ptr[PyObject];

def module_of(op: ptr[PyObject]) -> ptr[PyObject];

def native_state(module: ptr[PyObject]) -> AsyncioState | None;

def type_check(op: ptr[PyObject], type: ptr[PyObject]) -> bool;

def future_check_exact(module: ptr[PyObject], op: ptr[PyObject]) -> bool;

def task_check_exact(module: ptr[PyObject], op: ptr[PyObject]) -> bool;

def task_check(module: ptr[PyObject], op: ptr[PyObject]) -> bool;

def task_or_future_check(module: ptr[PyObject], op: ptr[PyObject]) -> bool;

def exception_class_check(op: ptr[PyObject]) -> bool;

def exception_instance_check(op: ptr[PyObject]) -> bool;

def release(value: ptr[PyObject]);

def running_loop_slot -> ptr[ptr[PyObject]];

def running_task_slot -> ptr[ptr[PyObject]];

def running_loop -> ptr[PyObject];

def:priv is_coroutine_slow(module: ptr[PyObject], coro: ptr[PyObject]) -> int;

def is_coroutine(module: ptr[PyObject], coro: ptr[PyObject]) -> int;

def get_future_loop(module: ptr[PyObject], fut: ptr[PyObject]) -> ptr[PyObject];

def get_event_loop(module: ptr[PyObject]) -> ptr[PyObject];

def call_soon(
    module: ptr[PyObject],
    loop: ptr[PyObject],
    func: ptr[PyObject],
    arg: ptr[PyObject],
    ctx: ptr[PyObject]
) -> int;

def future_is_alive(op: ptr[PyObject]) -> bool;

def future_ensure_alive(op: ptr[PyObject]) -> int;

def register_task(op: ptr[PyObject]);

def unregister_task(op: ptr[PyObject]);

def enter_task(loop: ptr[PyObject], task: ptr[PyObject]) -> int;

def leave_task(loop: ptr[PyObject], task: ptr[PyObject]) -> int;

def swap_current_task(loop: ptr[PyObject], task: ptr[PyObject]) -> ptr[PyObject];

def future_schedule_callbacks(module: ptr[PyObject], op: ptr[PyObject]) -> int;

def clear_future_fields(op: ptr[PyObject]);

def future_init(op: ptr[PyObject], loop: ptr[PyObject]) -> int;

def future_awaited_by_add(op: ptr[PyObject], thing: ptr[PyObject]) -> int;

def future_awaited_by_discard(op: ptr[PyObject], thing: ptr[PyObject]) -> int;

def future_set_result(
    module: ptr[PyObject], op: ptr[PyObject], res: ptr[PyObject]
) -> ptr[PyObject];

def future_set_exception(
    module: ptr[PyObject], op: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject];

def create_cancelled_error(module: ptr[PyObject], op: ptr[PyObject]) -> ptr[PyObject];

def future_set_cancelled_error(module: ptr[PyObject], op: ptr[PyObject]);

def future_get_result(module: ptr[PyObject], op: ptr[PyObject]) -> ptr[PyObject];

def future_add_done_callback(
    module: ptr[PyObject], op: ptr[PyObject], arg: ptr[PyObject], ctx: ptr[PyObject]
) -> ptr[PyObject];

def future_cancel(
    module: ptr[PyObject], op: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

impl AsyncioState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return i32(0);
}

impl AsyncioState.clear {}

impl intern_identifiers -> bool {
    if ids.ready {
        return True;
    }
    names = [
        "call_soon",
        "get_debug",
        "get_event_loop",
        "get_loop",
        "_loop",
        "cancel",
        "throw",
        "_asyncio_future_blocking",
        "add_done_callback",
        "is_running",
        "add",
        "discard",
        "done",
        "call_exception_handler",
        "message",
        "exception",
        "future",
        "source_traceback",
        "task",
        "PENDING",
        "CANCELLED",
        "FINISHED",
        "result",
        "loop",
        "name",
        "context",
        "eager_start"
    ];
    values: list[ptr[PyObject]] = [];
    for name in names {
        value = jacpy_unicode_intern_text(name);
        if not value {
            for made in values {
                jacpy_release(made);
            }
            return False;
        }
        values.append(value);
    }
    ids.call_soon = values[0];
    ids.get_debug = values[1];
    ids.get_event_loop = values[2];
    ids.get_loop = values[3];
    ids.loop_attr = values[4];
    ids.cancel = values[5];
    ids.throw = values[6];
    ids.asyncio_future_blocking = values[7];
    ids.add_done_callback = values[8];
    ids.is_running = values[9];
    ids.add = values[10];
    ids.discard = values[11];
    ids.done = values[12];
    ids.call_exception_handler = values[13];
    ids.message = values[14];
    ids.exception = values[15];
    ids.future = values[16];
    ids.source_traceback = values[17];
    ids.task = values[18];
    ids.pending = values[19];
    ids.cancelled = values[20];
    ids.finished = values[21];
    ids.result = values[22];
    ids.kw_loop = values[23];
    ids.kw_name = values[24];
    ids.kw_context = values[25];
    ids.kw_eager_start = values[26];
    ids.ready = True;
    return True;
}

impl fut_of(op: ptr[PyObject]) -> ptr[FutureObj] {
    return ptr[FutureObj](op);
}

impl task_of(op: ptr[PyObject]) -> ptr[TaskObj] {
    return ptr[TaskObj](op);
}

impl has_bit(op: ptr[PyObject], bit: int) -> bool {
    return (int(ptr[FutureObj](op).view(1)[0].fut_bits) & bit) != 0;
}

impl set_bit(op: ptr[PyObject], bit: int, value: bool) {
    record = ptr[FutureObj](op).view(1);
    bits = int(record[0].fut_bits);
    record[0].fut_bits = u8((bits | bit) if value else (bits & ~bit & 0xFF));
}

impl state_ref(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    return jacpy_binding_state_get(module, i64(index));
}

impl module_of_type(type: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(type, asyncio_module_token.handle);
}

impl module_of(op: ptr[PyObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(Py_TYPE(op), asyncio_module_token.handle);
}

impl native_state(module: ptr[PyObject]) -> AsyncioState | None {
    if jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        if isinstance(state, AsyncioState) {
            return state;
        }
    }
    return None;
}

impl type_check(op: ptr[PyObject], type: ptr[PyObject]) -> bool {
    return Py_TYPE(op) == type or PyType_IsSubtype(Py_TYPE(op), type) != 0;
}

impl future_check_exact(module: ptr[PyObject], op: ptr[PyObject]) -> bool {
    return Py_TYPE(op) == state_ref(module, STATE_FUTURE_TYPE);
}

impl task_check_exact(module: ptr[PyObject], op: ptr[PyObject]) -> bool {
    return Py_TYPE(op) == state_ref(module, STATE_TASK_TYPE);
}

impl task_check(module: ptr[PyObject], op: ptr[PyObject]) -> bool {
    return type_check(op, state_ref(module, STATE_TASK_TYPE));
}

impl task_or_future_check(module: ptr[PyObject], op: ptr[PyObject]) -> bool {
    type = Py_TYPE(op);
    future_type = state_ref(module, STATE_FUTURE_TYPE);
    task_type = state_ref(module, STATE_TASK_TYPE);
    return type == task_type
        or type == future_type
        or PyType_IsSubtype(type, future_type) != 0
        or PyType_IsSubtype(type, task_type) != 0;
}

impl exception_class_check(op: ptr[PyObject]) -> bool {
    return jacpy_is_type(op) != 0 and PyType_IsSubtype(op, PyExc_BaseException) != 0;
}

impl exception_instance_check(op: ptr[PyObject]) -> bool {
    return PyType_IsSubtype(Py_TYPE(op), PyExc_BaseException) != 0;
}

impl release(value: ptr[PyObject]) {
    if value {
        jacpy_release(value);
    }
}

impl running_loop_slot -> ptr[ptr[PyObject]] {
    return jacpy_asyncio_running_loop();
}

impl running_task_slot -> ptr[ptr[PyObject]] {
    return jacpy_asyncio_running_task();
}

impl running_loop -> ptr[PyObject] {
    return jacpy_asyncio_running_loop().view(1)[0];
}

impl is_coroutine_slow(module: ptr[PyObject], coro: ptr[PyObject]) -> int {
    res = PyObject_CallOneArg(state_ref(module, STATE_ISCOROUTINE_FUNC), coro);
    if not res {
        return -1;
    }
    is_res_true = int(PyObject_IsTrue(res));
    jacpy_release(res);
    if is_res_true <= 0 {
        return is_res_true;
    }
    typecache = state_ref(module, STATE_ISCOROUTINE_TYPECACHE);
    if PySet_Size(typecache) < 100 {
        if PySet_Add(typecache, Py_TYPE(coro)) != 0 {
            return -1;
        }
    }
    return 1;
}

impl is_coroutine(module: ptr[PyObject], coro: ptr[PyObject]) -> int {
    if Py_TYPE(coro) == addressof(PyCoro_Type) {
        return 1;
    }

    has_it = int(
        PySet_Contains(state_ref(module, STATE_ISCOROUTINE_TYPECACHE), Py_TYPE(coro))
    );
    if has_it == 0 {
        return is_coroutine_slow(module, coro);
    }
    return has_it;
}

impl get_future_loop(module: ptr[PyObject], fut: ptr[PyObject]) -> ptr[PyObject] {
    if future_check_exact(module, fut) or task_check_exact(module, fut) {
        return Py_NewRef(fut_of(fut).view(1)[0].fut_loop);
    }
    getloop = NULL;
    if PyObject_GetOptionalAttr(fut, ids.get_loop, &mut getloop) < 0 {
        return NULL;
    }
    if getloop {
        res = PyObject_CallNoArgs(getloop);
        jacpy_release(getloop);
        return res;
    }
    return PyObject_GetAttr(fut, ids.loop_attr);
}

impl get_event_loop(module: ptr[PyObject]) -> ptr[PyObject] {
    loop = running_loop();
    if loop {
        return Py_NewRef(loop);
    }
    policy = PyObject_CallNoArgs(state_ref(module, STATE_GET_EVENT_LOOP_POLICY));
    if not policy {
        return NULL;
    }
    loop = PyObject_CallMethodObjArgs(policy, ids.get_event_loop, NULL);
    jacpy_release(policy);
    return loop;
}

impl call_soon(
    module: ptr[PyObject],
    loop: ptr[PyObject],
    func: ptr[PyObject],
    arg: ptr[PyObject],
    ctx: ptr[PyObject]
) -> int {
    stack = CallStack(slot0=NULL, slot1=loop, slot2=func, slot3=arg, slot4=ctx);
    args = ptr[ptr[PyObject]](ptr(&mut stack)) + 1;
    handle = NULL;
    if not ctx {
        handle = PyObject_VectorcallMethod(
            ids.call_soon, args, u64(3) | ARGUMENTS_OFFSET, NULL
        );
    } else {
        nargs = 2;
        if arg {
            nargs = 3;
        } else {
            stack.slot3 = ctx;
        }
        handle = PyObject_VectorcallMethod(
            ids.call_soon,
            args,
            u64(nargs) | ARGUMENTS_OFFSET,
            state_ref(module, STATE_CONTEXT_KWNAME)
        );
    }
    if not handle {
        return -1;
    }
    jacpy_release(handle);
    return 0;
}

impl future_is_alive(op: ptr[PyObject]) -> bool {
    return bool(fut_of(op).view(1)[0].fut_loop);
}

impl future_ensure_alive(op: ptr[PyObject]) -> int {
    if not future_is_alive(op) {
        PyErr_SetString(
            PyExc_RuntimeError, ptr[u8]("Future object is not initialized.")
        );
        return -1;
    }
    return 0;
}

impl register_task(op: ptr[PyObject]) {
    record = task_of(op).view(1);
    if record[0].task_node_next {
        return;
    }
    head = ptr[LlistNode](jacpy_asyncio_tasks_head());
    link = ptr(op) + TASK_NODE_OFFSET;
    last = head.view(1)[0].prev;
    record[0].task_node_prev = last;
    record[0].task_node_next = ptr(head);
    ptr[LlistNode](last).view(1)[0].next = link;
    head.view(1)[0].prev = link;
}

impl unregister_task(op: ptr[PyObject]) {
    record = task_of(op).view(1);
    next = record[0].task_node_next;
    if not next {
        return;
    }
    prev = record[0].task_node_prev;
    ptr[LlistNode](prev).view(1)[0].next = next;
    ptr[LlistNode](next).view(1)[0].prev = prev;
    record[0].task_node_prev = ptr();
    record[0].task_node_next = ptr();
}

impl enter_task(loop: ptr[PyObject], task: ptr[PyObject]) -> int {
    if running_loop() != loop {
        PyErr_Format(
            PyExc_RuntimeError, ptr[u8]("loop %R is not the running loop"), loop
        );
        return -1;
    }
    slot = running_task_slot().view(1);
    if slot[0] {
        PyErr_Format(
            PyExc_RuntimeError,
            ptr[u8](
                "Cannot enter into task %R while another task %R is being executed."
            ),
            task,
            slot[0]
        );
        return -1;
    }
    slot[0] = Py_NewRef(task);
    return 0;
}

impl leave_task(loop: ptr[PyObject], task: ptr[PyObject]) -> int {
    if running_loop() != loop {
        PyErr_Format(
            PyExc_RuntimeError, ptr[u8]("loop %R is not the running loop"), loop
        );
        return -1;
    }
    slot = running_task_slot().view(1);
    if slot[0] != task {
        PyErr_Format(
            PyExc_RuntimeError,
            ptr[u8]("Invalid attempt to leave task %R while task %R is entered."),
            task,
            slot[0] if slot[0] else Py_None
        );
        return -1;
    }
    current = slot[0];
    slot[0] = NULL;
    jacpy_release(current);
    return 0;
}

impl swap_current_task(loop: ptr[PyObject], task: ptr[PyObject]) -> ptr[PyObject] {
    if running_loop() != loop {
        PyErr_Format(
            PyExc_RuntimeError, ptr[u8]("loop %R is not the running loop"), loop
        );
        return NULL;
    }
    slot = running_task_slot().view(1);

    prev_task = slot[0];
    slot[0] = Py_NewRef(task) if task != Py_None else NULL;
    if not prev_task {
        return Py_NewRef(Py_None);
    }
    return prev_task;
}

impl future_schedule_callbacks(module: ptr[PyObject], op: ptr[PyObject]) -> int {
    if task_check(module, op) {
        unregister_task(op);
    }
    record = fut_of(op).view(1);
    if record[0].fut_callback0 {
        fut_callback0 = record[0].fut_callback0;
        record[0].fut_callback0 = NULL;
        fut_context0 = record[0].fut_context0;
        record[0].fut_context0 = NULL;
        ret = call_soon(module, record[0].fut_loop, fut_callback0, op, fut_context0);
        release(fut_callback0);
        release(fut_context0);
        if ret != 0 {
            callbacks = record[0].fut_callbacks;
            record[0].fut_callbacks = NULL;
            release(callbacks);
            return ret;
        }
    }
    if not record[0].fut_callbacks {
        return 0;
    }

    callbacks = record[0].fut_callbacks;
    record[0].fut_callbacks = NULL;
    n = PyList_Size(callbacks);
    for i in range(int(n)) {
        cb_tup = PyList_GetItem(callbacks, i64(i));
        cb = PyTuple_GetItem(cb_tup, 0);
        ctx = PyTuple_GetItem(cb_tup, 1);
        if call_soon(module, record[0].fut_loop, cb, op, ctx) != 0 {
            jacpy_release(callbacks);
            return -1;
        }
    }
    jacpy_release(callbacks);
    return 0;
}

impl clear_future_fields(op: ptr[PyObject]) {
    record = fut_of(op).view(1);
    for index in range(11) {
        slot = ptr[ptr[PyObject]](ptr(op) + 16 + 8 * index).view(1);
        value = slot[0];
        if value {
            slot[0] = NULL;
            jacpy_release(value);
        }
    }
}

impl future_init(op: ptr[PyObject], loop: ptr[PyObject]) -> int {
    clear_future_fields(op);
    record = fut_of(op).view(1);
    record[0].fut_state = i32(STATE_PENDING);
    set_bit(op, BIT_LOG_TB, False);
    set_bit(op, BIT_BLOCKING, False);
    record[0].fut_awaited_by_is_set = i8(0);
    record[0].fut_is_task = i8(0);
    if loop == Py_None {
        loop = get_event_loop(module_of(op));
        if not loop {
            return -1;
        }
    } else {
        loop = Py_NewRef(loop);
    }
    record[0].fut_loop = loop;
    res = PyObject_CallMethodObjArgs(loop, ids.get_debug, NULL);
    if not res {
        return -1;
    }
    is_true = int(PyObject_IsTrue(res));
    jacpy_release(res);
    if is_true < 0 {
        return -1;
    }
    if is_true and _Py_IsInterpreterFinalizing(PyInterpreterState_Get()) == 0 {
        source_tb = PyObject_CallNoArgs(
            state_ref(module_of(op), STATE_TRACEBACK_EXTRACT_STACK)
        );
        record[0].fut_source_tb = source_tb;
        if not source_tb {
            return -1;
        }
    }
    return 0;
}

impl future_awaited_by_add(op: ptr[PyObject], thing: ptr[PyObject]) -> int {
    record = fut_of(op).view(1);
    if not record[0].fut_awaited_by {
        record[0].fut_awaited_by = Py_NewRef(thing);
        return 0;
    }
    if record[0].fut_awaited_by_is_set {
        return int(PySet_Add(record[0].fut_awaited_by, thing));
    }
    collected = PySet_New(NULL);
    if not collected {
        return -1;
    }
    if PySet_Add(collected, thing) != 0
        or PySet_Add(collected, record[0].fut_awaited_by) != 0 {
        jacpy_release(collected);
        return -1;
    }
    previous = record[0].fut_awaited_by;
    record[0].fut_awaited_by = collected;
    jacpy_release(previous);
    record[0].fut_awaited_by_is_set = i8(1);
    return 0;
}

impl future_awaited_by_discard(op: ptr[PyObject], thing: ptr[PyObject]) -> int {
    record = fut_of(op).view(1);
    awaited_by = record[0].fut_awaited_by;
    if not awaited_by {
        return 0;
    }
    if awaited_by == thing {
        record[0].fut_awaited_by = NULL;
        jacpy_release(awaited_by);
        return 0;
    }
    if record[0].fut_awaited_by_is_set {
        if PySet_Discard(awaited_by, thing) < 0 {
            return -1;
        }
    }
    return 0;
}

impl future_set_result(
    module: ptr[PyObject], op: ptr[PyObject], res: ptr[PyObject]
) -> ptr[PyObject] {
    if future_ensure_alive(op) != 0 {
        return NULL;
    }
    record = fut_of(op).view(1);
    if int(record[0].fut_state) != STATE_PENDING {
        PyErr_SetString(
            state_ref(module, STATE_INVALID_STATE_ERROR), ptr[u8]("invalid state")
        );
        return NULL;
    }
    record[0].fut_result = Py_NewRef(res);
    record[0].fut_state = i32(STATE_FINISHED);
    if future_schedule_callbacks(module, op) == -1 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

impl future_set_exception(
    module: ptr[PyObject], op: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject] {
    record = fut_of(op).view(1);
    invalid_state = state_ref(module, STATE_INVALID_STATE_ERROR);
    if int(record[0].fut_state) != STATE_PENDING {
        PyErr_SetString(invalid_state, ptr[u8]("invalid state"));
        return NULL;
    }
    exc_val = NULL;
    if exception_class_check(exc) {
        exc_val = PyObject_CallNoArgs(exc);
        if not exc_val {
            return NULL;
        }
        if int(record[0].fut_state) != STATE_PENDING {
            jacpy_release(exc_val);
            PyErr_SetString(invalid_state, ptr[u8]("invalid state"));
            return NULL;
        }
    } else {
        exc_val = Py_NewRef(exc);
    }
    if not exception_instance_check(exc_val) {
        jacpy_release(exc_val);
        PyErr_SetString(PyExc_TypeError, ptr[u8]("invalid exception object"));
        return NULL;
    }
    if PyErr_GivenExceptionMatches(exc_val, PyExc_StopIteration) != 0 {
        message = PyUnicode_FromString(
            ptr[u8](
                "StopIteration interacts badly with generators and cannot be raised into a Future"
            )
        );
        if not message {
            jacpy_release(exc_val);
            return NULL;
        }
        err = PyObject_CallOneArg(PyExc_RuntimeError, message);
        jacpy_release(message);
        if not err {
            jacpy_release(exc_val);
            return NULL;
        }
        PyException_SetCause(err, Py_NewRef(exc_val));
        PyException_SetContext(err, Py_NewRef(exc_val));
        jacpy_release(exc_val);
        exc_val = err;
    }
    record[0].fut_exception = exc_val;
    record[0].fut_exception_tb = PyException_GetTraceback(exc_val);
    record[0].fut_state = i32(STATE_FINISHED);
    if future_schedule_callbacks(module, op) == -1 {
        return NULL;
    }
    set_bit(op, BIT_LOG_TB, True);
    return Py_NewRef(Py_None);
}

impl create_cancelled_error(module: ptr[PyObject], op: ptr[PyObject]) -> ptr[PyObject] {
    record = fut_of(op).view(1);
    if record[0].fut_cancelled_exc {
        exc = record[0].fut_cancelled_exc;
        record[0].fut_cancelled_exc = NULL;
        return exc;
    }
    msg = record[0].fut_cancel_msg;
    cancelled_error = state_ref(module, STATE_CANCELLED_ERROR);
    if not msg or msg == Py_None {
        return PyObject_CallNoArgs(cancelled_error);
    }
    return PyObject_CallOneArg(cancelled_error, msg);
}

impl future_set_cancelled_error(module: ptr[PyObject], op: ptr[PyObject]) {
    exc = create_cancelled_error(module, op);
    if not exc {
        return;
    }
    PyErr_SetObject(state_ref(module, STATE_CANCELLED_ERROR), exc);
    jacpy_release(exc);
}

impl future_get_result(module: ptr[PyObject], op: ptr[PyObject]) -> ptr[PyObject] {
    record = fut_of(op).view(1);
    state = int(record[0].fut_state);
    if state == STATE_CANCELLED {
        future_set_cancelled_error(module, op);
        return NULL;
    }
    if state != STATE_FINISHED {
        PyErr_SetString(
            state_ref(module, STATE_INVALID_STATE_ERROR), ptr[u8]("Result is not set.")
        );
        return NULL;
    }
    set_bit(op, BIT_LOG_TB, False);
    if record[0].fut_exception {
        tb = record[0].fut_exception_tb;
        if not tb {
            tb = Py_None;
        }
        if PyException_SetTraceback(record[0].fut_exception, tb) < 0 {
            return NULL;
        }
        result = Py_NewRef(record[0].fut_exception);
        exception_tb = record[0].fut_exception_tb;
        record[0].fut_exception_tb = NULL;
        release(exception_tb);
        return result;
    }
    return Py_NewRef(record[0].fut_result);
}

impl future_add_done_callback(
    module: ptr[PyObject], op: ptr[PyObject], arg: ptr[PyObject], ctx: ptr[PyObject]
) -> ptr[PyObject] {
    if not future_is_alive(op) {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("uninitialized Future object"));
        return NULL;
    }
    record = fut_of(op).view(1);
    if int(record[0].fut_state) != STATE_PENDING {
        if call_soon(module, record[0].fut_loop, arg, op, ctx) != 0 {
            return NULL;
        }
    } elif not record[0].fut_callbacks and not record[0].fut_callback0 {
        record[0].fut_callback0 = Py_NewRef(arg);
        record[0].fut_context0 = Py_NewRef(ctx);
    } else {
        tup = PyTuple_New(2);
        if not tup {
            return NULL;
        }
        jacpy_tuple_set_owned(tup, 0, Py_NewRef(arg));
        jacpy_tuple_set_owned(tup, 1, Py_NewRef(ctx));
        if record[0].fut_callbacks {
            err = PyList_Append(record[0].fut_callbacks, tup);
            jacpy_release(tup);
            if err != 0 {
                return NULL;
            }
        } else {
            callbacks = PyList_New(1);
            if not callbacks {
                jacpy_release(tup);
                return NULL;
            }
            PyList_SetItem(callbacks, 0, tup);
            record[0].fut_callbacks = callbacks;
        }
    }
    return Py_NewRef(Py_None);
}

impl future_cancel(
    module: ptr[PyObject], op: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    set_bit(op, BIT_LOG_TB, False);
    record = fut_of(op).view(1);
    if int(record[0].fut_state) != STATE_PENDING {
        return Py_NewRef(py_false());
    }
    record[0].fut_state = i32(STATE_CANCELLED);
    previous = record[0].fut_cancel_msg;
    record[0].fut_cancel_msg = Py_NewRef(msg) if msg else NULL;
    release(previous);
    if future_schedule_callbacks(module, op) == -1 {
        return NULL;
    }
    return Py_NewRef(py_true());
}
