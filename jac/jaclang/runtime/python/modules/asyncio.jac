glob Future_token = ClassToken(),
     Task_token = ClassToken();

def:priv none -> ptr[PyObject];

def:priv truth(flag: bool) -> ptr[PyObject];

def:priv defining_module(receiver: ptr[PyObject], cls: ptr[PyObject]) -> ptr[PyObject];

def:priv alive(op: ptr[PyObject]) -> bool;

def:priv not_initialized(module: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Future___init___impl(receiver: ptr[PyObject], loop: ptr[PyObject]) -> i32;

def future_clear(op: ptr[PyObject]) -> i32;

def future_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

def _asyncio_Future_result_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Future_exception_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_Future_set_result_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], result: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_Future_set_exception_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], exception: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_Future_add_done_callback_impl(
    receiver: ptr[PyObject],
    cls: ptr[PyObject],
    fn: ptr[PyObject],
    context: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_Future_remove_done_callback_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], fn: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_Future_cancel_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_Future_cancelled_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Future_done_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Future_get_loop_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_Future__asyncio_awaited_by_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_Future__asyncio_future_blocking_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_Future__asyncio_future_blocking_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int;

def _asyncio_Future__log_traceback_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Future__log_traceback_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int;

def _asyncio_Future__loop_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Future__callbacks_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Future__result_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Future__exception_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Future__source_traceback_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_Future__cancel_message_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Future__cancel_message_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int;

def _asyncio_Future__state_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def future_repr(op: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Future__make_cancelled_error_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject];

def:priv call_exception_handler(
    op: ptr[PyObject], message: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
);

def future_finalize(op: ptr[PyObject]);

def future_dealloc(op: ptr[PyObject]);

def:priv free_object(type: ptr[PyObject], op: ptr[PyObject]);

def:priv iter_of(op: ptr[PyObject]) -> ptr[FutureIterObject];

def future_new_iter(fut: ptr[PyObject]) -> ptr[PyObject];

def futureiter_dealloc(op: ptr[PyObject]);

def:priv done_result(fut: ptr[PyObject]) -> ptr[PyObject];

def futureiter_am_send(
    op: ptr[PyObject], arg: ptr[PyObject], result: ptr[ptr[PyObject]]
) -> i32;

def futureiter_iternext(op: ptr[PyObject]) -> ptr[PyObject];

def futureiter_send(op: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject];

def futureiter_throw(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject];

def futureiter_clear(op: ptr[PyObject]) -> i32;

def futureiter_close(op: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject];

def futureiter_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

def:priv wrapper_of(op: ptr[PyObject]) -> ptr[TaskStepMethWrapper];

def stepwrapper_clear(op: ptr[PyObject]) -> i32;

def stepwrapper_dealloc(op: ptr[PyObject]);

def stepwrapper_call(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def stepwrapper_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

def stepwrapper_self(op: ptr[PyObject], closure: u64) -> ptr[PyObject];

def:priv stepwrapper_new(task: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

import from c {
    glob:priv task_wakeup_def: PositionalMethodRecord = PositionalMethodRecord(
             ml_name=ptr[u8]("task_wakeup"),
             ml_meth=task_wakeup,
             ml_flags=i32(8),
             ml_doc=ptr[u8]()
         );
}

def task_wakeup(op: ptr[PyObject], o: ptr[PyObject]) -> ptr[PyObject];

def:priv task_call_step_soon(
    module: ptr[PyObject], task: ptr[PyObject], arg: ptr[PyObject]
) -> int;

def:priv task_set_error_soon(
    module: ptr[PyObject], task: ptr[PyObject], et: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_Task___init___impl(
    receiver: ptr[PyObject],
    coro: ptr[PyObject],
    loop: ptr[PyObject],
    name: ptr[PyObject],
    context: ptr[PyObject],
    eager_start: bool
) -> i32;

def task_clear(op: ptr[PyObject]) -> i32;

def task_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

def _asyncio_Task__log_destroy_pending_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_Task__log_destroy_pending_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int;

def _asyncio_Task__must_cancel_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Task__coro_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Task__fut_waiter_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def task_repr(op: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Task__make_cancelled_error_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Task_cancel_impl(
    receiver: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_Task_cancelling_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Task_uncancel_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def:priv call_with_task(
    function: ptr[PyObject], receiver: ptr[PyObject], rest: list[ptr[PyObject]]
) -> ptr[PyObject];

def _asyncio_Task_get_stack_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], limit: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_Task_print_stack_impl(
    receiver: ptr[PyObject],
    cls: ptr[PyObject],
    limit: ptr[PyObject],
    file: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_Task_set_result_impl(
    receiver: ptr[PyObject], result: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_Task_set_exception_impl(
    receiver: ptr[PyObject], exception: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_Task_get_coro_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Task_get_context_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Task_get_name_impl(receiver: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_Task_set_name_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject];

def task_finalize(op: ptr[PyObject]);

def task_dealloc(op: ptr[PyObject]);

def:priv await_future(
    module: ptr[PyObject], task: ptr[PyObject], result: ptr[PyObject], native: bool
) -> ptr[PyObject];

def:priv call_with_context(
    callable: ptr[PyObject],
    arg: ptr[PyObject],
    ctx: ptr[PyObject],
    module: ptr[PyObject]
) -> ptr[PyObject];

def:priv task_step_handle_result(
    module: ptr[PyObject], task: ptr[PyObject], result: ptr[PyObject]
) -> ptr[PyObject];

def:priv yield_instead_of_yield_from(
    module: ptr[PyObject], task: ptr[PyObject], result: ptr[PyObject]
) -> ptr[PyObject];

def:priv different_loop(
    module: ptr[PyObject], task: ptr[PyObject], result: ptr[PyObject]
) -> ptr[PyObject];

def:priv task_step_impl(
    module: ptr[PyObject], task: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject];

def task_step(
    module: ptr[PyObject], task: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject];

def:priv task_eager_start(module: ptr[PyObject], task: ptr[PyObject]) -> int;

def _asyncio__get_running_loop_impl(module: ptr[PyObject]) -> ptr[PyObject];

def _asyncio__set_running_loop_impl(
    module: ptr[PyObject], loop: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_get_event_loop_impl(module: ptr[PyObject]) -> ptr[PyObject];

def _asyncio_get_running_loop_impl(module: ptr[PyObject]) -> ptr[PyObject];

def _asyncio__register_task_impl(
    module: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio__register_eager_task_impl(
    module: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio__unregister_task_impl(
    module: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio__unregister_eager_task_impl(
    module: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio__enter_task_impl(
    module: ptr[PyObject], loop: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio__leave_task_impl(
    module: ptr[PyObject], loop: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio__swap_current_task_impl(
    module: ptr[PyObject], loop: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_current_task_impl(
    module: ptr[PyObject], loop: ptr[PyObject]
) -> ptr[PyObject];

def:priv add_one_task(
    module: ptr[PyObject],
    tasks: ptr[PyObject],
    task: ptr[PyObject],
    loop: ptr[PyObject]
) -> int;

def _asyncio_all_tasks_impl(
    module: ptr[PyObject], loop: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_future_add_to_awaited_by_impl(
    module: ptr[PyObject], fut: ptr[PyObject], waiter: ptr[PyObject]
) -> ptr[PyObject];

def _asyncio_future_discard_from_awaited_by_impl(
    module: ptr[PyObject], fut: ptr[PyObject], waiter: ptr[PyObject]
) -> ptr[PyObject];

impl none -> ptr[PyObject] {
    return Py_NewRef(Py_None);
}

impl truth(flag: bool) -> ptr[PyObject] {
    return Py_NewRef(py_true() if flag else py_false());
}

impl defining_module(receiver: ptr[PyObject], cls: ptr[PyObject]) -> ptr[PyObject] {
    return module_of_type(cls) if cls else module_of(receiver);
}

impl alive(op: ptr[PyObject]) -> bool {
    return future_ensure_alive(op) == 0;
}

impl not_initialized(module: ptr[PyObject]) -> ptr[PyObject] {
    PyErr_SetString(
        state_ref(module, STATE_INVALID_STATE_ERROR),
        ptr[u8]("Future object is not initialized.")
    );
    return NULL;
}

impl _asyncio_Future___init___impl(
    receiver: ptr[PyObject], loop: ptr[PyObject]
) -> i32 {
    return i32(future_init(receiver, loop));
}

impl future_clear(op: ptr[PyObject]) -> i32 {
    clear_future_fields(op);
    fut_of(op).view(1)[0].fut_awaited_by_is_set = i8(0);
    PyObject_ClearManagedDict(op);
    return i32(0);
}

impl future_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    status = visit_reference(Py_TYPE(op), visitor, context);
    for index in range(11) {
        if status != 0 {
            return status;
        }
        status = visit_reference(
            ptr[ptr[PyObject]](ptr(op) + 16 + 8 * index).view(1)[0], visitor, context
        );
    }
    if status != 0 {
        return status;
    }
    return PyObject_VisitManagedDict(op, visitor, context);
}

impl _asyncio_Future_result_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    module = module_of(receiver);
    if not future_is_alive(receiver) {
        return not_initialized(module);
    }
    result = future_get_result(module, receiver);
    if not result or not fut_of(receiver).view(1)[0].fut_exception {
        return result;
    }
    PyErr_SetObject(Py_TYPE(result), result);
    jacpy_release(result);
    return NULL;
}

impl _asyncio_Future_exception_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    if not future_is_alive(receiver) {
        return not_initialized(defining_module(receiver, cls));
    }
    record = fut_of(receiver).view(1);
    state = int(record[0].fut_state);
    if state == STATE_CANCELLED {
        future_set_cancelled_error(defining_module(receiver, cls), receiver);
        return NULL;
    }
    if state != STATE_FINISHED {
        PyErr_SetString(
            state_ref(defining_module(receiver, cls), STATE_INVALID_STATE_ERROR),
            ptr[u8]("Exception is not set.")
        );
        return NULL;
    }
    if record[0].fut_exception {
        set_bit(receiver, BIT_LOG_TB, False);
        return Py_NewRef(record[0].fut_exception);
    }
    return none();
}

impl _asyncio_Future_set_result_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], result: ptr[PyObject]
) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    return future_set_result(defining_module(receiver, cls), receiver, result);
}

impl _asyncio_Future_set_exception_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], exception: ptr[PyObject]
) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    return future_set_exception(defining_module(receiver, cls), receiver, exception);
}

impl _asyncio_Future_add_done_callback_impl(
    receiver: ptr[PyObject],
    cls: ptr[PyObject],
    fn: ptr[PyObject],
    context: ptr[PyObject]
) -> ptr[PyObject] {
    module = defining_module(receiver, cls);
    if not context {
        context = PyContext_CopyCurrent();
        if not context {
            return NULL;
        }
        res = future_add_done_callback(module, receiver, fn, context);
        jacpy_release(context);
        return res;
    }
    return future_add_done_callback(module, receiver, fn, context);
}

impl _asyncio_Future_remove_done_callback_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], fn: ptr[PyObject]
) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    record = fut_of(receiver).view(1);
    cleared_callback0 = 0;
    if record[0].fut_callback0 {
        fut_callback0 = Py_NewRef(record[0].fut_callback0);
        cmp = int(PyObject_RichCompareBool(fut_callback0, fn, i32(2)));
        jacpy_release(fut_callback0);
        if cmp == -1 {
            return NULL;
        }
        if cmp == 1 {
            callback0 = record[0].fut_callback0;
            record[0].fut_callback0 = NULL;
            release(callback0);
            context0 = record[0].fut_context0;
            record[0].fut_context0 = NULL;
            release(context0);
            cleared_callback0 = 1;
        }
    }
    if not record[0].fut_callbacks {
        return PyLong_FromSsize_t(i64(cleared_callback0));
    }
    length = int(PyList_Size(record[0].fut_callbacks));
    if length == 0 {
        callbacks = record[0].fut_callbacks;
        record[0].fut_callbacks = NULL;
        release(callbacks);
        return PyLong_FromSsize_t(i64(cleared_callback0));
    }
    if length == 1 {
        cb_tup = Py_NewRef(PyList_GetItem(record[0].fut_callbacks, 0));
        cmp = int(PyObject_RichCompareBool(PyTuple_GetItem(cb_tup, 0), fn, i32(2)));
        jacpy_release(cb_tup);
        if cmp == -1 {
            return NULL;
        }
        if cmp == 1 {
            callbacks = record[0].fut_callbacks;
            record[0].fut_callbacks = NULL;
            release(callbacks);
            return PyLong_FromSsize_t(i64(1 + cleared_callback0));
        }

        return PyLong_FromSsize_t(i64(cleared_callback0));
    }
    newlist = PyList_New(0);
    if not newlist {
        return NULL;
    }

    i = 0;
    j = 0;
    while record[0].fut_callbacks and i < int(PyList_Size(record[0].fut_callbacks)) {
        item = Py_NewRef(PyList_GetItem(record[0].fut_callbacks, i64(i)));
        ret = int(PyObject_RichCompareBool(PyTuple_GetItem(item, 0), fn, i32(2)));
        if ret == 0 {
            ret = int(PyList_Append(newlist, item));
            j += 1;
        }
        jacpy_release(item);
        if ret < 0 {
            jacpy_release(newlist);
            return NULL;
        }
        i += 1;
    }

    if j == 0 or not record[0].fut_callbacks {
        callbacks = record[0].fut_callbacks;
        record[0].fut_callbacks = NULL;
        release(callbacks);
        jacpy_release(newlist);
        return PyLong_FromSsize_t(i64(length + cleared_callback0));
    }
    j = int(PyList_Size(newlist));
    length = int(PyList_Size(record[0].fut_callbacks));
    if j != length {
        if PyList_SetSlice(record[0].fut_callbacks, 0, i64(length), newlist) < 0 {
            jacpy_release(newlist);
            return NULL;
        }
    }
    jacpy_release(newlist);
    return PyLong_FromSsize_t(i64(length - j + cleared_callback0));
}

impl _asyncio_Future_cancel_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    return future_cancel(defining_module(receiver, cls), receiver, msg);
}

impl _asyncio_Future_cancelled_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return truth(
        future_is_alive(receiver)
            and int(fut_of(receiver).view(1)[0].fut_state) == STATE_CANCELLED
    );
}

impl _asyncio_Future_done_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return truth(
        future_is_alive(receiver)
            and int(fut_of(receiver).view(1)[0].fut_state) != STATE_PENDING
    );
}

impl _asyncio_Future_get_loop_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    return Py_NewRef(fut_of(receiver).view(1)[0].fut_loop);
}

impl _asyncio_Future__asyncio_awaited_by_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    record = fut_of(receiver).view(1);
    if not record[0].fut_awaited_by {
        return none();
    }
    if record[0].fut_awaited_by_is_set {
        return PyFrozenSet_New(record[0].fut_awaited_by);
    }
    frozen = PyFrozenSet_New(NULL);
    if not frozen {
        return NULL;
    }
    if PySet_Add(frozen, record[0].fut_awaited_by) != 0 {
        jacpy_release(frozen);
        return NULL;
    }
    return frozen;
}

impl _asyncio_Future__asyncio_future_blocking_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    return truth(future_is_alive(receiver) and has_bit(receiver, BIT_BLOCKING));
}

impl _asyncio_Future__asyncio_future_blocking_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    if future_ensure_alive(receiver) != 0 {
        return -1;
    }
    if not value {
        PyErr_SetString(PyExc_AttributeError, ptr[u8]("cannot delete attribute"));
        return -1;
    }
    is_true = int(PyObject_IsTrue(value));
    if is_true < 0 {
        return -1;
    }
    set_bit(receiver, BIT_BLOCKING, is_true != 0);
    return 0;
}

impl _asyncio_Future__log_traceback_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    return truth(has_bit(receiver, BIT_LOG_TB));
}

impl _asyncio_Future__log_traceback_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    if not value {
        PyErr_SetString(PyExc_AttributeError, ptr[u8]("cannot delete attribute"));
        return -1;
    }
    is_true = int(PyObject_IsTrue(value));
    if is_true < 0 {
        return -1;
    }
    if is_true {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("_log_traceback can only be set to False")
        );
        return -1;
    }
    set_bit(receiver, BIT_LOG_TB, False);
    return 0;
}

impl _asyncio_Future__loop_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    if not future_is_alive(receiver) {
        return none();
    }
    return Py_NewRef(fut_of(receiver).view(1)[0].fut_loop);
}

impl _asyncio_Future__callbacks_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    record = fut_of(receiver).view(1);
    length = 0;
    if record[0].fut_callback0 {
        length += 1;
    }
    if record[0].fut_callbacks {
        length += int(PyList_Size(record[0].fut_callbacks));
    }
    if length == 0 {
        return none();
    }
    callbacks = PyList_New(i64(length));
    if not callbacks {
        return NULL;
    }
    i = 0;
    if record[0].fut_callback0 {
        tup0 = PyTuple_New(2);
        if not tup0 {
            jacpy_release(callbacks);
            return NULL;
        }
        jacpy_tuple_set_owned(tup0, 0, Py_NewRef(record[0].fut_callback0));
        jacpy_tuple_set_owned(tup0, 1, Py_NewRef(record[0].fut_context0));
        PyList_SetItem(callbacks, i64(i), tup0);
        i += 1;
    }
    if record[0].fut_callbacks {
        for j in range(int(PyList_Size(record[0].fut_callbacks))) {
            PyList_SetItem(
                callbacks,
                i64(i),
                Py_NewRef(PyList_GetItem(record[0].fut_callbacks, i64(j)))
            );
            i += 1;
        }
    }
    return callbacks;
}

impl _asyncio_Future__result_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    result = fut_of(receiver).view(1)[0].fut_result;
    return Py_NewRef(result) if result else none();
}

impl _asyncio_Future__exception_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    exception = fut_of(receiver).view(1)[0].fut_exception;
    return Py_NewRef(exception) if exception else none();
}

impl _asyncio_Future__source_traceback_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    source_tb = fut_of(receiver).view(1)[0].fut_source_tb;
    if not future_is_alive(receiver) or not source_tb {
        return none();
    }
    return Py_NewRef(source_tb);
}

impl _asyncio_Future__cancel_message_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    msg = fut_of(receiver).view(1)[0].fut_cancel_msg;
    return Py_NewRef(msg) if msg else none();
}

impl _asyncio_Future__cancel_message_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    if not value {
        PyErr_SetString(PyExc_AttributeError, ptr[u8]("cannot delete attribute"));
        return -1;
    }
    record = fut_of(receiver).view(1);
    previous = record[0].fut_cancel_msg;
    record[0].fut_cancel_msg = Py_NewRef(value);
    release(previous);
    return 0;
}

impl _asyncio_Future__state_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    state = int(fut_of(receiver).view(1)[0].fut_state);
    if state == STATE_PENDING {
        return Py_NewRef(ids.pending);
    }
    if state == STATE_CANCELLED {
        return Py_NewRef(ids.cancelled);
    }
    return Py_NewRef(ids.finished);
}

impl future_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    if not alive(op) {
        return NULL;
    }
    return PyObject_CallOneArg(state_ref(module_of(op), STATE_FUTURE_REPR_FUNC), op);
}

impl _asyncio_Future__make_cancelled_error_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    return create_cancelled_error(module_of(receiver), receiver);
}

impl call_exception_handler(
    op: ptr[PyObject], message: ptr[PyObject], key: ptr[PyObject], value: ptr[PyObject]
) {
    record = fut_of(op).view(1);
    context = PyDict_New();
    if context
        and message
        and PyDict_SetItem(context, ids.message, message) >= 0
        and PyDict_SetItem(context, key, value) >= 0
        and (key == ids.task or PyDict_SetItem(context, ids.future, op) >= 0)
        and (
            not record[0].fut_source_tb
            or PyDict_SetItem(context, ids.source_traceback, record[0].fut_source_tb)
                >= 0
        ) {
        func = PyObject_GetAttr(record[0].fut_loop, ids.call_exception_handler);
        if func {
            res = PyObject_CallOneArg(func, context);
            if not res {
                PyErr_FormatUnraisable(
                    ptr[u8]("Exception ignored while calling asyncio function %R"), func
                );
            } else {
                jacpy_release(res);
            }
            jacpy_release(func);
        }
    }
    release(context);
    release(message);
}

impl future_finalize(op: ptr[PyObject]) {
    if not has_bit(op, BIT_LOG_TB) {
        return;
    }
    set_bit(op, BIT_LOG_TB, False);

    exc = PyErr_GetRaisedException();
    message = PyUnicode_FromFormat(
        "%s exception was never retrieved", _PyType_Name(Py_TYPE(op))
    );
    call_exception_handler(
        op, message, ids.exception, fut_of(op).view(1)[0].fut_exception
    );

    PyErr_SetRaisedException(exc);
}

impl future_dealloc(op: ptr[PyObject]) {
    if PyObject_CallFinalizerFromDealloc(op) < 0 {
        return;
    }
    type = Py_TYPE(op);
    PyObject_GC_UnTrack(op);
    PyObject_ClearWeakRefs(op);
    future_clear(op);
    free_object(type, op);
}

impl free_object(type: ptr[PyObject], op: ptr[PyObject]) {
    jacpy_binding_free(op);
}

impl iter_of(op: ptr[PyObject]) -> ptr[FutureIterObject] {
    return ptr[FutureIterObject](op);
}

impl future_new_iter(fut: ptr[PyObject]) -> ptr[PyObject] {
    if not alive(fut) {
        return NULL;
    }
    it = freelist_pop(_Py_freelists_FUTUREITERS);
    if not it {
        it = _PyObject_GC_New(state_ref(module_of(fut), STATE_FUTURE_ITER_TYPE));
        if not it {
            return NULL;
        }
    }
    iter_of(it).view(1)[0].future = Py_NewRef(fut);
    PyObject_GC_Track(it);
    return it;
}

impl futureiter_dealloc(op: ptr[PyObject]) {
    type = Py_TYPE(op);
    PyObject_GC_UnTrack(op);
    futureiter_clear(op);
    if not freelist_push(_Py_freelists_FUTUREITERS, op, Py_futureiters_MAXFREELIST) {
        PyObject_GC_Del(op);
        jacpy_release(type);
    }
}

impl done_result(fut: ptr[PyObject]) -> ptr[PyObject] {
    record = fut_of(fut).view(1);
    if record[0].fut_loop
        and int(record[0].fut_state) == STATE_FINISHED
        and not record[0].fut_exception {
        set_bit(fut, BIT_LOG_TB, False);
        return Py_NewRef(record[0].fut_result);
    }
    return _asyncio_Future_result_impl(fut);
}

impl futureiter_am_send(
    op: ptr[PyObject], arg: ptr[PyObject], result: ptr[ptr[PyObject]]
) -> i32 {
    out = result.view(1);
    out[0] = NULL;
    fut = iter_of(op).view(1)[0].future;
    if int(fut_of(fut).view(1)[0].fut_state) == STATE_PENDING {
        if not has_bit(fut, BIT_BLOCKING) {
            set_bit(fut, BIT_BLOCKING, True);
            out[0] = Py_NewRef(fut);
            return PYGEN_NEXT;
        }
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("await wasn't used with future"));
        return PYGEN_ERROR;
    }
    res = done_result(fut);
    if res {
        out[0] = res;
        return PYGEN_RETURN;
    }
    return PYGEN_ERROR;
}

impl futureiter_iternext(op: ptr[PyObject]) -> ptr[PyObject] {
    fut = iter_of(op).view(1)[0].future;
    if int(fut_of(fut).view(1)[0].fut_state) == STATE_PENDING {
        if not has_bit(fut, BIT_BLOCKING) {
            set_bit(fut, BIT_BLOCKING, True);
            return Py_NewRef(fut);
        }
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("await wasn't used with future"));
        return NULL;
    }
    res = done_result(fut);
    if res {
        _PyGen_SetStopIterationValue(res);
        jacpy_release(res);
    }
    return NULL;
}

impl futureiter_send(op: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    return futureiter_iternext(op);
}

impl futureiter_throw(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional(ptr[u8]("throw"), nargs, 1, 3) == 0 {
        return NULL;
    }
    if nargs > 1 {
        if PyErr_WarnEx(
            PyExc_DeprecationWarning,
            ptr[u8](
                "the (type, exc, tb) signature of throw() is deprecated, use the single-arg signature instead."
            ),
            1
        )
            < 0 {
            return NULL;
        }
    }
    values = args.view(int(nargs));
    type = values[0];
    val = NULL;
    tb = NULL;
    if nargs == 3 {
        val = values[1];
        tb = values[2];
    } elif nargs == 2 {
        val = values[1];
    }
    if val == Py_None {
        val = NULL;
    }
    if tb == Py_None {
        tb = NULL;
    } elif tb and Py_TYPE(tb) != addressof(PyTraceBack_Type) {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("throw() third argument must be a traceback")
        );
        return NULL;
    }
    type = Py_NewRef(type);
    if val {
        val = Py_NewRef(val);
    }
    if tb {
        tb = Py_NewRef(tb);
    }
    if exception_class_check(type) {
        PyErr_NormalizeException(&mut type, &mut val, &mut tb);
    } elif exception_instance_check(type) {
        if val {
            PyErr_SetString(
                PyExc_TypeError,
                ptr[u8]("instance exception may not have a separate value")
            );
            jacpy_release(type);
            release(val);
            release(tb);
            return NULL;
        }
        val = type;
        type = Py_NewRef(Py_TYPE(type));
        if not tb {
            tb = PyException_GetTraceback(val);
        }
    } else {
        PyErr_SetString(
            PyExc_TypeError,
            ptr[u8](
                "exceptions must be classes deriving BaseException or instances of such a class"
            )
        );
        jacpy_release(type);
        release(val);
        release(tb);
        return NULL;
    }
    futureiter_clear(op);
    PyErr_Restore(type, val, tb);
    return NULL;
}

impl futureiter_clear(op: ptr[PyObject]) -> i32 {
    record = iter_of(op).view(1);
    future = record[0].future;
    if future {
        record[0].future = NULL;
        jacpy_release(future);
    }
    return i32(0);
}

impl futureiter_close(op: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    futureiter_clear(op);
    return none();
}

impl futureiter_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    status = visit_reference(Py_TYPE(op), visitor, context);
    if status != 0 {
        return status;
    }
    return visit_reference(iter_of(op).view(1)[0].future, visitor, context);
}

impl wrapper_of(op: ptr[PyObject]) -> ptr[TaskStepMethWrapper] {
    return ptr[TaskStepMethWrapper](op);
}

impl stepwrapper_clear(op: ptr[PyObject]) -> i32 {
    record = wrapper_of(op).view(1);
    task = record[0].sw_task;
    record[0].sw_task = NULL;
    release(task);
    arg = record[0].sw_arg;
    record[0].sw_arg = NULL;
    release(arg);
    return i32(0);
}

impl stepwrapper_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(op);
    stepwrapper_clear(op);
    free_object(Py_TYPE(op), op);
}

impl stepwrapper_call(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    if kwds and jacpy_dict_size(kwds) != 0 {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("function takes no keyword arguments")
        );
        return NULL;
    }
    if args and PyTuple_Size(args) != 0 {
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("function takes no positional arguments")
        );
        return NULL;
    }
    record = wrapper_of(op).view(1);
    return task_step(module_of(op), record[0].sw_task, record[0].sw_arg);
}

impl stepwrapper_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    record = wrapper_of(op).view(1);
    status = visit_reference(Py_TYPE(op), visitor, context);
    if status == 0 {
        status = visit_reference(record[0].sw_task, visitor, context);
    }
    if status == 0 {
        status = visit_reference(record[0].sw_arg, visitor, context);
    }
    return status;
}

impl stepwrapper_self(op: ptr[PyObject], closure: u64) -> ptr[PyObject] {
    task = wrapper_of(op).view(1)[0].sw_task;
    return Py_NewRef(task) if task else none();
}

impl stepwrapper_new(task: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    wrapper = _PyObject_GC_New(
        state_ref(module_of(task), STATE_TASK_STEP_WRAPPER_TYPE)
    );
    if not wrapper {
        return NULL;
    }
    record = wrapper_of(wrapper).view(1);
    record[0].sw_task = Py_NewRef(task);
    record[0].sw_arg = Py_NewRef(arg) if arg else NULL;
    PyObject_GC_Track(wrapper);
    return wrapper;
}

impl task_wakeup(op: ptr[PyObject], o: ptr[PyObject]) -> ptr[PyObject] {
    module = module_of(op);
    if task_or_future_check(module, o) {
        if future_awaited_by_discard(o, op) != 0 {
            return NULL;
        }
    }
    if future_check_exact(module, o) or task_check_exact(module, o) {
        fut_result = future_get_result(module, o);
        if fut_result {
            if not fut_of(o).view(1)[0].fut_exception {
                jacpy_release(fut_result);
                return task_step(module, op, NULL);
            }
            result = task_step(module, op, fut_result);
            jacpy_release(fut_result);
            return result;
        }
    } else {
        fut_result = PyObject_CallMethodObjArgs(o, ids.result, NULL);
        if fut_result {
            jacpy_release(fut_result);
            return task_step(module, op, NULL);
        }
    }
    exc = PyErr_GetRaisedException();
    result = task_step(module, op, exc);
    jacpy_release(exc);
    return result;
}

impl task_call_step_soon(
    module: ptr[PyObject], task: ptr[PyObject], arg: ptr[PyObject]
) -> int {
    cb = stepwrapper_new(task, arg);
    if not cb {
        return -1;
    }

    task_context = Py_NewRef(task_of(task).view(1)[0].task_context);
    ret = call_soon(module, fut_of(task).view(1)[0].fut_loop, cb, NULL, task_context);
    jacpy_release(task_context);
    jacpy_release(cb);
    return ret;
}

impl task_set_error_soon(
    module: ptr[PyObject], task: ptr[PyObject], et: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    if not msg {
        return NULL;
    }
    e = PyObject_CallOneArg(et, msg);
    jacpy_release(msg);
    if not e {
        return NULL;
    }
    if task_call_step_soon(module, task, e) == -1 {
        jacpy_release(e);
        return NULL;
    }
    jacpy_release(e);
    return none();
}

impl _asyncio_Task___init___impl(
    receiver: ptr[PyObject],
    coro: ptr[PyObject],
    loop: ptr[PyObject],
    name: ptr[PyObject],
    context: ptr[PyObject],
    eager_start: bool
) -> i32 {
    if future_init(receiver, loop) != 0 {
        return i32(-1);
    }
    record = task_of(receiver).view(1);
    fut_of(receiver).view(1)[0].fut_is_task = i8(1);
    module = module_of(receiver);
    is_coro = is_coroutine(module, coro);
    if is_coro == -1 {
        return i32(-1);
    }
    if is_coro == 0 {
        set_bit(receiver, BIT_LOG_DESTROY_PENDING, False);
        PyErr_Format(
            PyExc_TypeError, ptr[u8]("a coroutine was expected, got %R"), coro
        );
        return i32(-1);
    }
    previous = record[0].task_context;
    if context == Py_None {
        record[0].task_context = PyContext_CopyCurrent();
        release(previous);
        if not record[0].task_context {
            return i32(-1);
        }
    } else {
        record[0].task_context = Py_NewRef(context);
        release(previous);
    }
    waiter = record[0].task_fut_waiter;
    record[0].task_fut_waiter = NULL;
    release(waiter);
    set_bit(receiver, BIT_MUST_CANCEL, False);
    set_bit(receiver, BIT_LOG_DESTROY_PENDING, True);
    record[0].task_num_cancels_requested = i32(0);
    previous = record[0].task_coro;
    record[0].task_coro = Py_NewRef(coro);
    release(previous);
    task_name = NULL;
    if name == Py_None {
        state = native_state(module);
        counter = 0;
        if state is not None {
            state.task_name_counter += 1;
            counter = state.task_name_counter;
        }
        task_name = PyLong_FromUnsignedLongLong(u64(counter));
    } elif jacpy_is_exact_unicode(name) == 0 {
        task_name = PyObject_Str(name);
    } else {
        task_name = Py_NewRef(name);
    }
    previous = record[0].task_name;
    record[0].task_name = task_name;
    release(previous);
    if not task_name {
        return i32(-1);
    }
    if eager_start {
        res = PyObject_CallMethodObjArgs(loop, ids.is_running, NULL);
        if not res {
            return i32(-1);
        }
        is_loop_running = res == py_true();
        jacpy_release(res);
        if is_loop_running {
            if task_eager_start(module, receiver) != 0 {
                return i32(-1);
            }
            return i32(0);
        }
    }
    if task_call_step_soon(module, receiver, NULL) != 0 {
        return i32(-1);
    }
    register_task(receiver);
    return i32(0);
}

impl task_clear(op: ptr[PyObject]) -> i32 {
    future_clear(op);
    record = task_of(op).view(1);
    coro = record[0].task_coro;
    record[0].task_coro = NULL;
    release(coro);
    context = record[0].task_context;
    record[0].task_context = NULL;
    release(context);
    name = record[0].task_name;
    record[0].task_name = NULL;
    release(name);
    waiter = record[0].task_fut_waiter;
    record[0].task_fut_waiter = NULL;
    release(waiter);
    return i32(0);
}

impl task_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    record = task_of(op).view(1);
    status = visit_reference(Py_TYPE(op), visitor, context);
    if status == 0 {
        status = visit_reference(record[0].task_context, visitor, context);
    }
    if status == 0 {
        status = visit_reference(record[0].task_coro, visitor, context);
    }
    if status == 0 {
        status = visit_reference(record[0].task_name, visitor, context);
    }
    if status == 0 {
        status = visit_reference(record[0].task_fut_waiter, visitor, context);
    }
    for index in range(11) {
        if status != 0 {
            return status;
        }
        status = visit_reference(
            ptr[ptr[PyObject]](ptr(op) + 16 + 8 * index).view(1)[0], visitor, context
        );
    }
    if status != 0 {
        return status;
    }
    return PyObject_VisitManagedDict(op, visitor, context);
}

impl _asyncio_Task__log_destroy_pending_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    return truth(has_bit(receiver, BIT_LOG_DESTROY_PENDING));
}

impl _asyncio_Task__log_destroy_pending_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    if not value {
        PyErr_SetString(PyExc_AttributeError, ptr[u8]("cannot delete attribute"));
        return -1;
    }
    is_true = int(PyObject_IsTrue(value));
    if is_true < 0 {
        return -1;
    }
    set_bit(receiver, BIT_LOG_DESTROY_PENDING, is_true != 0);
    return 0;
}

impl _asyncio_Task__must_cancel_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return truth(has_bit(receiver, BIT_MUST_CANCEL));
}

impl _asyncio_Task__coro_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    coro = task_of(receiver).view(1)[0].task_coro;
    return Py_NewRef(coro) if coro else none();
}

impl _asyncio_Task__fut_waiter_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    waiter = task_of(receiver).view(1)[0].task_fut_waiter;
    return Py_NewRef(waiter) if waiter else none();
}

impl task_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    return PyObject_CallOneArg(state_ref(module_of(op), STATE_TASK_REPR_FUNC), op);
}

impl _asyncio_Task__make_cancelled_error_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    return _asyncio_Future__make_cancelled_error_impl(receiver);
}

impl _asyncio_Task_cancel_impl(
    receiver: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    set_bit(receiver, BIT_LOG_TB, False);
    if int(fut_of(receiver).view(1)[0].fut_state) != STATE_PENDING {
        return truth(False);
    }
    record = task_of(receiver).view(1);
    record[0].task_num_cancels_requested = record[0].task_num_cancels_requested
        + i32(1);

    if record[0].task_fut_waiter {
        res = PyObject_CallMethodObjArgs(
            record[0].task_fut_waiter, ids.cancel, msg, NULL
        );
        if not res {
            return NULL;
        }
        is_true = int(PyObject_IsTrue(res));
        jacpy_release(res);
        if is_true < 0 {
            return NULL;
        }
        if is_true {
            return truth(True);
        }
    }
    set_bit(receiver, BIT_MUST_CANCEL, True);
    future = fut_of(receiver).view(1);
    previous = future[0].fut_cancel_msg;
    future[0].fut_cancel_msg = Py_NewRef(msg) if msg else NULL;
    release(previous);
    return truth(True);
}

impl _asyncio_Task_cancelling_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromLong(
        i64(task_of(receiver).view(1)[0].task_num_cancels_requested)
    );
}

impl _asyncio_Task_uncancel_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    record = task_of(receiver).view(1);
    if record[0].task_num_cancels_requested > i32(0) {
        record[0].task_num_cancels_requested = record[0].task_num_cancels_requested
            - i32(1);
        if record[0].task_num_cancels_requested == i32(0) {
            set_bit(receiver, BIT_MUST_CANCEL, False);
        }
    }
    return PyLong_FromLong(i64(record[0].task_num_cancels_requested));
}

impl call_with_task(
    function: ptr[PyObject], receiver: ptr[PyObject], rest: list[ptr[PyObject]]
) -> ptr[PyObject] {
    arguments = PyTuple_New(i64(1 + len(rest)));
    if not arguments {
        return NULL;
    }
    jacpy_tuple_set_owned(arguments, 0, Py_NewRef(receiver));
    for index in range(len(rest)) {
        jacpy_tuple_set_owned(arguments, i64(index + 1), Py_NewRef(rest[index]));
    }
    import from jaclang.runtime.python.cpython_api { PyObject_Call }
    result = PyObject_Call(function, arguments, NULL);
    jacpy_release(arguments);
    return result;
}

impl _asyncio_Task_get_stack_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], limit: ptr[PyObject]
) -> ptr[PyObject] {
    return call_with_task(
        state_ref(module_of_type(cls), STATE_TASK_GET_STACK_FUNC), receiver, [limit]
    );
}

impl _asyncio_Task_print_stack_impl(
    receiver: ptr[PyObject],
    cls: ptr[PyObject],
    limit: ptr[PyObject],
    file: ptr[PyObject]
) -> ptr[PyObject] {
    return call_with_task(
        state_ref(module_of_type(cls), STATE_TASK_PRINT_STACK_FUNC),
        receiver,
        [limit, file]
    );
}

impl _asyncio_Task_set_result_impl(
    receiver: ptr[PyObject], result: ptr[PyObject]
) -> ptr[PyObject] {
    PyErr_SetString(
        PyExc_RuntimeError, ptr[u8]("Task does not support set_result operation")
    );
    return NULL;
}

impl _asyncio_Task_set_exception_impl(
    receiver: ptr[PyObject], exception: ptr[PyObject]
) -> ptr[PyObject] {
    PyErr_SetString(
        PyExc_RuntimeError, ptr[u8]("Task does not support set_exception operation")
    );
    return NULL;
}

impl _asyncio_Task_get_coro_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return _asyncio_Task__coro_get_impl(receiver);
}

impl _asyncio_Task_get_context_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(task_of(receiver).view(1)[0].task_context);
}

impl _asyncio_Task_get_name_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    record = task_of(receiver).view(1);
    if not record[0].task_name {
        return none();
    }
    if jacpy_is_exact_long(record[0].task_name) != 0 {
        name = PyUnicode_FromFormat("Task-%S", record[0].task_name);
        if not name {
            return NULL;
        }
        previous = record[0].task_name;
        record[0].task_name = name;
        jacpy_release(previous);
    }
    return Py_NewRef(record[0].task_name);
}

impl _asyncio_Task_set_name_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    if jacpy_is_exact_unicode(value) == 0 {
        value = PyObject_Str(value);
        if not value {
            return NULL;
        }
    } else {
        value = Py_NewRef(value);
    }
    record = task_of(receiver).view(1);
    previous = record[0].task_name;
    record[0].task_name = value;
    release(previous);
    return none();
}

impl task_finalize(op: ptr[PyObject]) {
    if int(fut_of(op).view(1)[0].fut_state) == STATE_PENDING
        and has_bit(op, BIT_LOG_DESTROY_PENDING) {
        exc = PyErr_GetRaisedException();
        message = PyUnicode_FromString(
            ptr[u8]("Task was destroyed but it is pending!")
        );
        call_exception_handler(op, message, ids.task, op);

        PyErr_SetRaisedException(exc);
    }
    future_finalize(op);
}

impl task_dealloc(op: ptr[PyObject]) {
    if PyObject_CallFinalizerFromDealloc(op) < 0 {
        return;
    }
    unregister_task(op);
    type = Py_TYPE(op);
    PyObject_GC_UnTrack(op);
    PyObject_ClearWeakRefs(op);
    task_clear(op);
    free_object(type, op);
}

impl await_future(
    module: ptr[PyObject], task: ptr[PyObject], result: ptr[PyObject], native: bool
) -> ptr[PyObject] {
    record = task_of(task).view(1);
    if native or task_or_future_check(module, result) {
        if future_awaited_by_add(result, task) != 0 {
            jacpy_release(result);
            return NULL;
        }
    }
    wrapper = PyCFunction_NewEx(
        ptr[PyMethodDef](addressof(task_wakeup_def)), task, NULL
    );
    if not wrapper {
        jacpy_release(result);
        return NULL;
    }
    tmp = NULL;
    if native {
        set_bit(result, BIT_BLOCKING, False);

        tmp = future_add_done_callback(module, result, wrapper, record[0].task_context);
    } else {
        if PyObject_SetAttr(result, ids.asyncio_future_blocking, py_false()) == -1 {
            jacpy_release(wrapper);
            jacpy_release(result);
            return NULL;
        }
        add_cb = PyObject_GetAttr(result, ids.add_done_callback);
        if not add_cb {
            jacpy_release(wrapper);
            jacpy_release(result);
            return NULL;
        }
        tmp = call_with_context(add_cb, wrapper, record[0].task_context, module);
        jacpy_release(add_cb);
    }
    jacpy_release(wrapper);
    if not tmp {
        jacpy_release(result);
        return NULL;
    }
    jacpy_release(tmp);

    record[0].task_fut_waiter = result;
    if has_bit(task, BIT_MUST_CANCEL) {
        task_cancel_msg = Py_NewRef(fut_of(task).view(1)[0].fut_cancel_msg);
        r = PyObject_CallMethodObjArgs(result, ids.cancel, task_cancel_msg, NULL);
        jacpy_release(task_cancel_msg);
        if not r {
            return NULL;
        }
        is_true = int(PyObject_IsTrue(r));
        jacpy_release(r);
        if is_true < 0 {
            return NULL;
        }
        if is_true {
            set_bit(task, BIT_MUST_CANCEL, False);
        }
    }
    return none();
}

impl call_with_context(
    callable: ptr[PyObject],
    arg: ptr[PyObject],
    ctx: ptr[PyObject],
    module: ptr[PyObject]
) -> ptr[PyObject] {
    stack = CallStack(slot0=arg, slot1=ctx, slot2=NULL, slot3=NULL, slot4=NULL);
    return PyObject_Vectorcall(
        callable,
        ptr[ptr[PyObject]](ptr(&mut stack)),
        u64(1),
        state_ref(module, STATE_CONTEXT_KWNAME)
    );
}

impl task_step_handle_result(
    module: ptr[PyObject], task: ptr[PyObject], result: ptr[PyObject]
) -> ptr[PyObject] {
    task_loop = fut_of(task).view(1)[0].fut_loop;
    if result == task {
        o = task_set_error_soon(
            module,
            task,
            PyExc_RuntimeError,
            PyUnicode_FromFormat("Task cannot await on itself: %R", task)
        );
        jacpy_release(result);
        return o;
    }

    if future_check_exact(module, result) or task_check_exact(module, result) {
        if fut_of(result).view(1)[0].fut_loop != task_loop {
            return different_loop(module, task, result);
        }
        if not has_bit(result, BIT_BLOCKING) {
            return yield_instead_of_yield_from(module, task, result);
        }
        return await_future(module, task, result, True);
    }

    if result == Py_None {
        if task_call_step_soon(module, task, NULL) != 0 {
            jacpy_release(result);
            return NULL;
        }
        return result;
    }

    o = NULL;
    if PyObject_GetOptionalAttr(result, ids.asyncio_future_blocking, &mut o) < 0 {
        jacpy_release(result);
        return NULL;
    }
    if o and o != Py_None {
        blocking = int(PyObject_IsTrue(o));
        jacpy_release(o);
        if blocking < 0 {
            jacpy_release(result);
            return NULL;
        }

        oloop = get_future_loop(module, result);
        if not oloop {
            jacpy_release(result);
            return NULL;
        }
        jacpy_release(oloop);
        if oloop != task_loop {
            return different_loop(module, task, result);
        }
        if not blocking {
            return yield_instead_of_yield_from(module, task, result);
        }
        return await_future(module, task, result, False);
    }
    release(o);

    res = int(PyObject_IsInstance(result, ptr[PyObject](addressof(PyGen_Type))));
    if res < 0 {
        jacpy_release(result);
        return NULL;
    }
    if res {
        o = task_set_error_soon(
            module,
            task,
            PyExc_RuntimeError,
            PyUnicode_FromFormat(
                "yield was used instead of yield from for generator in task %R with %R",
                task,
                result
            )
        );
        jacpy_release(result);
        return o;
    }

    o = task_set_error_soon(
        module,
        task,
        PyExc_RuntimeError,
        PyUnicode_FromFormat("Task got bad yield: %R", result)
    );
    jacpy_release(result);
    return o;
}

impl yield_instead_of_yield_from(
    module: ptr[PyObject], task: ptr[PyObject], result: ptr[PyObject]
) -> ptr[PyObject] {
    o = task_set_error_soon(
        module,
        task,
        PyExc_RuntimeError,
        PyUnicode_FromFormat(
            "yield was used instead of yield from in task %R with %R", task, result
        )
    );
    jacpy_release(result);
    return o;
}

impl different_loop(
    module: ptr[PyObject], task: ptr[PyObject], result: ptr[PyObject]
) -> ptr[PyObject] {
    o = task_set_error_soon(
        module,
        task,
        PyExc_RuntimeError,
        PyUnicode_FromFormat(
            "Task %R got Future %R attached to a different loop", task, result
        )
    );
    jacpy_release(result);
    return o;
}

impl task_step_impl(
    module: ptr[PyObject], task: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject] {
    record = task_of(task).view(1);
    if int(fut_of(task).view(1)[0].fut_state) != STATE_PENDING {
        PyErr_Format(
            state_ref(module, STATE_INVALID_STATE_ERROR),
            ptr[u8]("__step(): already done: %R %R"),
            task,
            exc or Py_None
        );
        return NULL;
    }
    clear_exc = False;
    if has_bit(task, BIT_MUST_CANCEL) {
        if not exc
            or PyErr_GivenExceptionMatches(
                exc, state_ref(module, STATE_CANCELLED_ERROR)
            )
                == 0 {
            exc = create_cancelled_error(module, task);
            if not exc {
                return NULL;
            }
            clear_exc = True;
        }
        set_bit(task, BIT_MUST_CANCEL, False);
    }
    waiter = record[0].task_fut_waiter;
    record[0].task_fut_waiter = NULL;
    release(waiter);
    coro = record[0].task_coro;
    if not coro {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("uninitialized Task object"));
        if clear_exc {
            jacpy_release(exc);
        }
        return NULL;
    }
    gen_status = int(PYGEN_ERROR);
    result = NULL;
    if not exc {
        gen_status = int(PyIter_Send(coro, Py_None, &mut result));
    } else {
        result = PyObject_CallMethodObjArgs(coro, ids.throw, exc, NULL);
        if result {
            gen_status = int(PYGEN_NEXT);
        } elif _PyGen_FetchStopIterationValue(&mut result) == 0 {
            gen_status = int(PYGEN_RETURN);
        }
        if clear_exc {
            jacpy_release(exc);
        }
    }
    if gen_status == PYGEN_RETURN or gen_status == PYGEN_ERROR {
        if result {
            tmp = NULL;
            if has_bit(task, BIT_MUST_CANCEL) {
                set_bit(task, BIT_MUST_CANCEL, False);
                tmp = future_cancel(
                    module, task, fut_of(task).view(1)[0].fut_cancel_msg
                );
            } else {
                tmp = future_set_result(module, task, result);
            }
            jacpy_release(result);
            if not tmp {
                return NULL;
            }
            jacpy_release(tmp);
            return none();
        }
        if PyErr_ExceptionMatches(state_ref(module, STATE_CANCELLED_ERROR)) != 0 {
            cancelled = PyErr_GetRaisedException();
            fut_of(task).view(1)[0].fut_cancelled_exc = cancelled;
            return future_cancel(module, task, NULL);
        }

        raised = PyErr_GetRaisedException();
        o = future_set_exception(module, task, raised);
        if not o {
            jacpy_release(raised);
            return NULL;
        }
        jacpy_release(o);
        if PyErr_GivenExceptionMatches(raised, PyExc_KeyboardInterrupt) != 0
            or PyErr_GivenExceptionMatches(raised, PyExc_SystemExit) != 0 {
            PyErr_SetRaisedException(raised);
            return NULL;
        }
        jacpy_release(raised);
        return none();
    }
    return task_step_handle_result(module, task, result);
}

impl task_step(
    module: ptr[PyObject], task: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject] {
    loop = fut_of(task).view(1)[0].fut_loop;
    if enter_task(loop, task) < 0 {
        return NULL;
    }
    res = task_step_impl(module, task, exc);
    if not res {
        raised = PyErr_GetRaisedException();
        leave_task(fut_of(task).view(1)[0].fut_loop, task);
        _PyErr_ChainExceptions1(raised);
        return NULL;
    }
    if leave_task(fut_of(task).view(1)[0].fut_loop, task) < 0 {
        jacpy_release(res);
        return NULL;
    }
    return res;
}

impl task_eager_start(module: ptr[PyObject], task: ptr[PyObject]) -> int {
    record = task_of(task).view(1);
    loop = fut_of(task).view(1)[0].fut_loop;
    prevtask = swap_current_task(loop, task);
    if not prevtask {
        return -1;
    }

    register_task(task);
    if PyContext_Enter(record[0].task_context) == -1 {
        jacpy_release(prevtask);
        return -1;
    }
    retval = 0;
    stepres = task_step_impl(module, task, NULL);
    if not stepres {
        raised = PyErr_GetRaisedException();
        _PyErr_ChainExceptions1(raised);
        retval = -1;
    } else {
        jacpy_release(stepres);
    }
    curtask = swap_current_task(fut_of(task).view(1)[0].fut_loop, prevtask);
    jacpy_release(prevtask);
    if not curtask {
        retval = -1;
    } else {
        jacpy_release(curtask);
    }
    if PyContext_Exit(record[0].task_context) == -1 {
        retval = -1;
    }
    if int(fut_of(task).view(1)[0].fut_state) != STATE_PENDING {
        coro = record[0].task_coro;
        record[0].task_coro = NULL;
        release(coro);
    }
    return retval;
}

impl _asyncio__get_running_loop_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    loop = running_loop();
    if not loop {
        return none();
    }
    return Py_NewRef(loop);
}

impl _asyncio__set_running_loop_impl(
    module: ptr[PyObject], loop: ptr[PyObject]
) -> ptr[PyObject] {
    slot = running_loop_slot().view(1);
    previous = slot[0];
    slot[0] = Py_NewRef(loop) if loop != Py_None else NULL;
    release(previous);
    return none();
}

impl _asyncio_get_event_loop_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return get_event_loop(module);
}

impl _asyncio_get_running_loop_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    loop = running_loop();
    if not loop {
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("no running event loop"));
        return NULL;
    }
    return Py_NewRef(loop);
}

impl _asyncio__register_task_impl(
    module: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject] {
    if task_check(module, task) {
        register_task(task);
        return none();
    }

    res = PyObject_CallMethodObjArgs(
        state_ref(module, STATE_NON_ASYNCIO_TASKS), ids.add, task, NULL
    );
    if not res {
        return NULL;
    }
    jacpy_release(res);
    return none();
}

impl _asyncio__register_eager_task_impl(
    module: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject] {
    if task_check(module, task) {
        register_task(task);
        return none();
    }
    if PySet_Add(state_ref(module, STATE_NON_ASYNCIO_EAGER_TASKS), task) < 0 {
        return NULL;
    }
    return none();
}

impl _asyncio__unregister_task_impl(
    module: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject] {
    if task_check(module, task) {
        unregister_task(task);
        return none();
    }
    res = PyObject_CallMethodObjArgs(
        state_ref(module, STATE_NON_ASYNCIO_TASKS), ids.discard, task, NULL
    );
    if not res {
        return NULL;
    }
    jacpy_release(res);
    return none();
}

impl _asyncio__unregister_eager_task_impl(
    module: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject] {
    if task_check(module, task) {
        unregister_task(task);
        return none();
    }
    if PySet_Discard(state_ref(module, STATE_NON_ASYNCIO_EAGER_TASKS), task) < 0 {
        return NULL;
    }
    return none();
}

impl _asyncio__enter_task_impl(
    module: ptr[PyObject], loop: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject] {
    if enter_task(loop, task) < 0 {
        return NULL;
    }
    return none();
}

impl _asyncio__leave_task_impl(
    module: ptr[PyObject], loop: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject] {
    if leave_task(loop, task) < 0 {
        return NULL;
    }
    return none();
}

impl _asyncio__swap_current_task_impl(
    module: ptr[PyObject], loop: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject] {
    return swap_current_task(loop, task);
}

impl _asyncio_current_task_impl(
    module: ptr[PyObject], loop: ptr[PyObject]
) -> ptr[PyObject] {
    if loop == Py_None {
        loop = _asyncio_get_running_loop_impl(module);
        if not loop {
            return NULL;
        }
    } else {
        loop = Py_NewRef(loop);
    }

    if running_loop() == loop {
        jacpy_release(loop);
        task = running_task_slot().view(1)[0];
        return Py_NewRef(task) if task else none();
    }

    ret = jacpy_asyncio_thread_task(loop);
    jacpy_release(loop);
    return ret;
}

impl add_one_task(
    module: ptr[PyObject],
    tasks: ptr[PyObject],
    task: ptr[PyObject],
    loop: ptr[PyObject]
) -> int {
    if task_check_exact(module, task) {
        record = fut_of(task).view(1);
        if int(record[0].fut_state) == STATE_PENDING and record[0].fut_loop == loop {
            if PySet_Add(tasks, task) < 0 {
                return -1;
            }
        }
        return 0;
    }
    done = PyObject_CallMethodObjArgs(task, ids.done, NULL);
    if not done {
        return -1;
    }
    if done == py_true() {
        return 0;
    }
    jacpy_release(done);
    task_loop = get_future_loop(module, task);
    if not task_loop {
        return -1;
    }
    if task_loop == loop {
        if PySet_Add(tasks, task) < 0 {
            jacpy_release(task_loop);
            return -1;
        }
    }
    jacpy_release(task_loop);
    return 0;
}

impl _asyncio_all_tasks_impl(
    module: ptr[PyObject], loop: ptr[PyObject]
) -> ptr[PyObject] {
    if loop == Py_None {
        loop = _asyncio_get_running_loop_impl(module);
        if not loop {
            return NULL;
        }
    } else {
        loop = Py_NewRef(loop);
    }

    tasks = PyList_New(0);
    if not tasks {
        jacpy_release(loop);
        return NULL;
    }
    if PyList_Extend(tasks, state_ref(module, STATE_NON_ASYNCIO_EAGER_TASKS)) < 0
        or PyList_Extend(tasks, state_ref(module, STATE_NON_ASYNCIO_TASKS)) < 0 {
        jacpy_release(tasks);
        jacpy_release(loop);
        return NULL;
    }

    all_threads = running_loop() != loop;
    if jacpy_asyncio_add_tasks(tasks, i64(TASK_NODE_OFFSET), i64(all_threads)) < 0 {
        jacpy_release(tasks);
        jacpy_release(loop);
        return NULL;
    }
    res = PySet_New(NULL);
    if not res {
        jacpy_release(tasks);
        jacpy_release(loop);
        return NULL;
    }
    for i in range(int(PyList_Size(tasks))) {
        if add_one_task(module, res, PyList_GetItem(tasks, i64(i)), loop) < 0 {
            jacpy_release(res);
            jacpy_release(tasks);
            jacpy_release(loop);
            return NULL;
        }
    }
    jacpy_release(tasks);
    jacpy_release(loop);
    return res;
}

impl _asyncio_future_add_to_awaited_by_impl(
    module: ptr[PyObject], fut: ptr[PyObject], waiter: ptr[PyObject]
) -> ptr[PyObject] {
    if task_or_future_check(module, fut) and task_or_future_check(module, waiter) {
        if future_awaited_by_add(fut, waiter) != 0 {
            return NULL;
        }
    }
    return none();
}

impl _asyncio_future_discard_from_awaited_by_impl(
    module: ptr[PyObject], fut: ptr[PyObject], waiter: ptr[PyObject]
) -> ptr[PyObject] {
    if task_or_future_check(module, fut) and task_or_future_check(module, waiter) {
        if future_awaited_by_discard(fut, waiter) != 0 {
            return NULL;
        }
    }
    return none();
}
