"""The _asyncio module: Future, Task, the Future iterator, the Task step
wrapper, and the running loop and task registry functions.

Derived from CPython 3.14.6 Modules/_asynciomodule.c; see ../LICENSE.cpython.
The Argument Clinic methods' _impl functions keep their C names and live
here, with the Task step machinery and the type slots the binding installs;
the object layouts, state and Future primitives are in asyncio_core.jac.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyCFunction_NewEx,
    PyContext_CopyCurrent,
    PyContext_Enter,
    PyContext_Exit,
    PyDict_New,
    PyDict_SetItem,
    PyErr_Format,
    PyErr_FormatUnraisable,
    PyErr_GetRaisedException,
    PyErr_GivenExceptionMatches,
    PyErr_ExceptionMatches,
    PyErr_NormalizeException,
    PyErr_Restore,
    PyErr_SetObject,
    PyErr_SetRaisedException,
    PyErr_SetString,
    PyErr_WarnEx,
    PyException_GetTraceback,
    PyExc_AttributeError,
    PyExc_DeprecationWarning,
    PyExc_KeyboardInterrupt,
    PyExc_RuntimeError,
    PyExc_SystemExit,
    PyExc_TypeError,
    PyExc_ValueError,
    PyFrozenSet_New,
    PyGen_Type,
    PyIter_Send,
    PyList_Append,
    PyList_Extend,
    PyList_GetItem,
    PyList_New,
    PyList_SetItem,
    PyList_SetSlice,
    PyList_Size,
    PyLong_FromLong,
    PyMethodDef,
    PyLong_FromSsize_t,
    PyLong_FromUnsignedLongLong,
    PyObject,
    PyObject_CallFinalizerFromDealloc,
    PyObject_CallMethodObjArgs,
    PyObject_CallNoArgs,
    PyObject_CallOneArg,
    PyObject_ClearManagedDict,
    PyObject_ClearWeakRefs,
    PyObject_GC_Del,
    PyObject_GC_Track,
    PyObject_GC_UnTrack,
    PyObject_GetAttr,
    PyObject_GetOptionalAttr,
    PyObject_IsInstance,
    PyObject_IsTrue,
    PyObject_RichCompareBool,
    PyObject_SetAttr,
    PyObject_Str,
    PyObject_Vectorcall,
    PyObject_VisitManagedDict,
    PySet_Add,
    PySet_Discard,
    PySet_New,
    PyTraceBack_Type,
    PyTuple_GetItem,
    PyTuple_New,
    PyTuple_Size,
    PyUnicode_FromFormat,
    PyUnicode_FromString,
    Py_NewRef,
    Py_None,
    Py_TYPE,
    _PyArg_CheckPositional,
    _PyErr_ChainExceptions1,
    _PyGen_FetchStopIterationValue,
    _PyGen_SetStopIterationValue,
    _PyObject_GC_New,
    _PyType_Name,
    jacpy_asyncio_add_tasks,
    jacpy_asyncio_thread_task,
    jacpy_dict_size,
    jacpy_is_exact_long,
    jacpy_is_exact_unicode,
    jacpy_release,
    jacpy_tuple_set_owned
}
import from jaclang.runtime.python.layouts {
    PYGEN_ERROR,
    PYGEN_NEXT,
    PYGEN_RETURN,
    Py_futureiters_MAXFREELIST,
    _Py_freelists_FUTUREITERS
}
import from jaclang.runtime.python.object_model.bool { py_false, py_true }
import from jaclang.runtime.python.object_model.header { freelist_pop, freelist_push }
import from jaclang.runtime.python.bindings.module {
    PositionalMethodRecord,
    visit_reference
}
import from jaclang.runtime.python.bindings.converters { ClassToken }
import from jaclang.runtime.python.modules.asyncio_core {
    BIT_BLOCKING,
    BIT_LOG_DESTROY_PENDING,
    BIT_LOG_TB,
    BIT_MUST_CANCEL,
    FutureIterObject,
    STATE_CANCELLED,
    STATE_CANCELLED_ERROR,
    STATE_FINISHED,
    STATE_FUTURE_ITER_TYPE,
    STATE_FUTURE_REPR_FUNC,
    STATE_INVALID_STATE_ERROR,
    STATE_NON_ASYNCIO_EAGER_TASKS,
    STATE_NON_ASYNCIO_TASKS,
    STATE_PENDING,
    STATE_TASK_GET_STACK_FUNC,
    STATE_TASK_PRINT_STACK_FUNC,
    STATE_TASK_REPR_FUNC,
    STATE_TASK_STEP_WRAPPER_TYPE,
    STATE_CONTEXT_KWNAME,
    TASK_NODE_OFFSET,
    TaskStepMethWrapper,
    call_soon,
    create_cancelled_error,
    enter_task,
    exception_class_check,
    exception_instance_check,
    fut_of,
    future_add_done_callback,
    future_awaited_by_add,
    future_awaited_by_discard,
    future_cancel,
    future_check_exact,
    future_ensure_alive,
    future_get_result,
    future_init,
    future_is_alive,
    future_set_cancelled_error,
    future_set_exception,
    future_set_result,
    get_event_loop,
    get_future_loop,
    has_bit,
    ids,
    is_coroutine,
    leave_task,
    module_of,
    module_of_type,
    native_state,
    register_task,
    release,
    running_loop,
    running_loop_slot,
    running_task_slot,
    set_bit,
    state_ref,
    swap_current_task,
    task_check,
    task_check_exact,
    task_of,
    task_or_future_check,
    unregister_task
}

glob Future_token = ClassToken(),
     Task_token = ClassToken();

def:priv none -> ptr[PyObject] {
    return Py_NewRef(Py_None);
}

def:priv truth(flag: bool) -> ptr[PyObject] {
    return Py_NewRef(py_true() if flag else py_false());
}

"""ENSURE_FUTURE_ALIVE: False with RuntimeError for an uninitialized future."""
def:priv alive(op: ptr[PyObject]) -> bool {
    return future_ensure_alive(op) == 0;
}

"""The InvalidStateError "Future object is not initialized." of a module."""
def:priv not_initialized(module: ptr[PyObject]) -> ptr[PyObject] {
    PyErr_SetString(
        state_ref(module, STATE_INVALID_STATE_ERROR),
        "Future object is not initialized."
    );
    return NULL;
}

# ---------------------------------------------------------------------------
# Future

def _asyncio_Future___init___impl(receiver: ptr[PyObject], loop: ptr[PyObject]) -> i32 {
    return i32(future_init(receiver, loop));
}

"""FutureObj_clear()."""
def future_clear(op: ptr[PyObject]) -> i32 {
    import from jaclang.runtime.python.modules.asyncio_core { clear_future_fields }
    clear_future_fields(op);
    fut_of(op).view(1)[0].fut_awaited_by_is_set = i8(0);
    PyObject_ClearManagedDict(op);
    return i32(0);
}

"""FutureObj_traverse()."""
def future_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
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

def _asyncio_Future_result_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    module = module_of(receiver);
    if not future_is_alive(receiver) {
        return not_initialized(module);
    }
    (res, result) = future_get_result(module, receiver);
    if res == -1 {
        return NULL;
    }
    if res == 0 {
        return result;
    }
    PyErr_SetObject(Py_TYPE(result), result);
    jacpy_release(result);
    return NULL;
}

def _asyncio_Future_exception_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    if not future_is_alive(receiver) {
        return not_initialized(module_of_type(cls));
    }
    record = fut_of(receiver).view(1);
    state = int(record[0].fut_state);
    if state == STATE_CANCELLED {
        future_set_cancelled_error(module_of_type(cls), receiver);
        return NULL;
    }
    if state != STATE_FINISHED {
        PyErr_SetString(
            state_ref(module_of_type(cls), STATE_INVALID_STATE_ERROR),
            "Exception is not set."
        );
        return NULL;
    }
    if record[0].fut_exception {
        set_bit(receiver, BIT_LOG_TB, False);
        return Py_NewRef(record[0].fut_exception);
    }
    return none();
}

def _asyncio_Future_set_result_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], result: ptr[PyObject]
) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    return future_set_result(module_of_type(cls), receiver, result);
}

def _asyncio_Future_set_exception_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], exception: ptr[PyObject]
) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    return future_set_exception(module_of_type(cls), receiver, exception);
}

def _asyncio_Future_add_done_callback_impl(
    receiver: ptr[PyObject],
    cls: ptr[PyObject],
    fn: ptr[PyObject],
    context: ptr[PyObject]
) -> ptr[PyObject] {
    module = module_of_type(cls);
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

def _asyncio_Future_remove_done_callback_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], fn: ptr[PyObject]
) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    record = fut_of(receiver).view(1);
    cleared_callback0 = 0;
    if record[0].fut_callback0 {
        # An evil PyObject_RichCompareBool could free fut_callback0 before a
        # recursive call is made with that same arg.
        fut_callback0 = Py_NewRef(record[0].fut_callback0);
        cmp = int(PyObject_RichCompareBool(fut_callback0, fn, i32(2)));
        jacpy_release(fut_callback0);
        if cmp == -1 {
            return NULL;
        }
        if cmp == 1 {
            # callback0 == fn
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
            # callbacks[0] == fn
            callbacks = record[0].fut_callbacks;
            record[0].fut_callbacks = NULL;
            release(callbacks);
            return PyLong_FromSsize_t(i64(1 + cleared_callback0));
        }
        # callbacks[0] != fn and len(callbacks) == 1
        return PyLong_FromSsize_t(i64(cleared_callback0));
    }
    newlist = PyList_New(0);
    if not newlist {
        return NULL;
    }
    # PyObject_RichCompareBool may change fut_callbacks (GH-97592).
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
    # fut_callbacks may have been cleared.
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

def _asyncio_Future_cancel_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    return future_cancel(module_of_type(cls), receiver, msg);
}

def _asyncio_Future_cancelled_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return truth(
        future_is_alive(receiver)
            and int(fut_of(receiver).view(1)[0].fut_state) == STATE_CANCELLED
    );
}

def _asyncio_Future_done_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return truth(
        future_is_alive(receiver)
            and int(fut_of(receiver).view(1)[0].fut_state) != STATE_PENDING
    );
}

def _asyncio_Future_get_loop_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject]
) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    return Py_NewRef(fut_of(receiver).view(1)[0].fut_loop);
}

def _asyncio_Future__asyncio_awaited_by_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    record = fut_of(receiver).view(1);
    if not record[0].fut_awaited_by {
        return none();
    }
    if record[0].fut_awaited_by_is_set {
        # Already a set: wrap it into a frozen set.
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

def _asyncio_Future__asyncio_future_blocking_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    return truth(future_is_alive(receiver) and has_bit(receiver, BIT_BLOCKING));
}

def _asyncio_Future__asyncio_future_blocking_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    if future_ensure_alive(receiver) != 0 {
        return -1;
    }
    if not value {
        PyErr_SetString(PyExc_AttributeError, "cannot delete attribute");
        return -1;
    }
    is_true = int(PyObject_IsTrue(value));
    if is_true < 0 {
        return -1;
    }
    set_bit(receiver, BIT_BLOCKING, is_true != 0);
    return 0;
}

def _asyncio_Future__log_traceback_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    return truth(has_bit(receiver, BIT_LOG_TB));
}

def _asyncio_Future__log_traceback_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    if not value {
        PyErr_SetString(PyExc_AttributeError, "cannot delete attribute");
        return -1;
    }
    is_true = int(PyObject_IsTrue(value));
    if is_true < 0 {
        return -1;
    }
    if is_true {
        PyErr_SetString(PyExc_ValueError, "_log_traceback can only be set to False");
        return -1;
    }
    set_bit(receiver, BIT_LOG_TB, False);
    return 0;
}

def _asyncio_Future__loop_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    if not future_is_alive(receiver) {
        return none();
    }
    return Py_NewRef(fut_of(receiver).view(1)[0].fut_loop);
}

def _asyncio_Future__callbacks_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
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

def _asyncio_Future__result_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    result = fut_of(receiver).view(1)[0].fut_result;
    return Py_NewRef(result) if result else none();
}

def _asyncio_Future__exception_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    if not alive(receiver) {
        return NULL;
    }
    exception = fut_of(receiver).view(1)[0].fut_exception;
    return Py_NewRef(exception) if exception else none();
}

def _asyncio_Future__source_traceback_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    source_tb = fut_of(receiver).view(1)[0].fut_source_tb;
    if not future_is_alive(receiver) or not source_tb {
        return none();
    }
    return Py_NewRef(source_tb);
}

def _asyncio_Future__cancel_message_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    msg = fut_of(receiver).view(1)[0].fut_cancel_msg;
    return Py_NewRef(msg) if msg else none();
}

def _asyncio_Future__cancel_message_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    if not value {
        PyErr_SetString(PyExc_AttributeError, "cannot delete attribute");
        return -1;
    }
    record = fut_of(receiver).view(1);
    previous = record[0].fut_cancel_msg;
    record[0].fut_cancel_msg = Py_NewRef(value);
    release(previous);
    return 0;
}

def _asyncio_Future__state_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
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

"""FutureObj_repr()."""
def future_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    if not alive(op) {
        return NULL;
    }
    return PyObject_CallOneArg(state_ref(module_of(op), STATE_FUTURE_REPR_FUNC), op);
}

def _asyncio_Future__make_cancelled_error_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    return create_cancelled_error(module_of(receiver), receiver);
}

"""Report a never-retrieved exception or a pending task's destruction
through loop.call_exception_handler(), keeping the current exception."""
def:priv call_exception_handler(
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
                    "Exception ignored while calling asyncio function %R", func
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

"""FutureObj_finalize(): report an exception that was never retrieved."""
def future_finalize(op: ptr[PyObject]) {
    if not has_bit(op, BIT_LOG_TB) {
        return;
    }
    set_bit(op, BIT_LOG_TB, False);
    # Save the current exception, if any.
    exc = PyErr_GetRaisedException();
    message = PyUnicode_FromFormat(
        "%s exception was never retrieved", _PyType_Name(Py_TYPE(op))
    );
    call_exception_handler(
        op, message, ids.exception, fut_of(op).view(1)[0].fut_exception
    );
    # Restore the saved exception.
    PyErr_SetRaisedException(exc);
}

"""FutureObj_dealloc()."""
def future_dealloc(op: ptr[PyObject]) {
    if PyObject_CallFinalizerFromDealloc(op) < 0 {
        # Resurrected.
        return;
    }
    type = Py_TYPE(op);
    PyObject_GC_UnTrack(op);
    PyObject_ClearWeakRefs(op);
    future_clear(op);
    free_object(type, op);
}

"""tp->tp_free(self); Py_DECREF(tp)."""
def:priv free_object(type: ptr[PyObject], op: ptr[PyObject]) {
    import from jaclang.runtime.python.bindings.type { jacpy_binding_free }
    jacpy_binding_free(op);
}

# ---------------------------------------------------------------------------
# The Future iterator.

def:priv iter_of(op: ptr[PyObject]) -> ptr[FutureIterObject] {
    return ptr[FutureIterObject](op);
}

"""future_new_iter(): tp_iter and am_await of Future and Task."""
def future_new_iter(fut: ptr[PyObject]) -> ptr[PyObject] {
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

"""FutureIter_dealloc(): kept on the interpreter's freelist when there is
room (with its type reference), else freed."""
def futureiter_dealloc(op: ptr[PyObject]) {
    type = Py_TYPE(op);
    PyObject_GC_UnTrack(op);
    futureiter_clear(op);
    if not freelist_push(_Py_freelists_FUTUREITERS, op, Py_futureiters_MAXFREELIST) {
        PyObject_GC_Del(op);
        jacpy_release(type);
    }
}

"""FutureIter_am_send(): the future itself while pending (once), else its
result as the return value."""
def futureiter_am_send(
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
        PyErr_SetString(PyExc_RuntimeError, "await wasn't used with future");
        return PYGEN_ERROR;
    }
    res = _asyncio_Future_result_impl(fut);
    if res {
        out[0] = res;
        return PYGEN_RETURN;
    }
    return PYGEN_ERROR;
}

"""FutureIter_iternext()."""
def futureiter_iternext(op: ptr[PyObject]) -> ptr[PyObject] {
    fut = iter_of(op).view(1)[0].future;
    if int(fut_of(fut).view(1)[0].fut_state) == STATE_PENDING {
        if not has_bit(fut, BIT_BLOCKING) {
            set_bit(fut, BIT_BLOCKING, True);
            return Py_NewRef(fut);
        }
        PyErr_SetString(PyExc_RuntimeError, "await wasn't used with future");
        return NULL;
    }
    res = _asyncio_Future_result_impl(fut);
    if res {
        _PyGen_SetStopIterationValue(res);
        jacpy_release(res);
    }
    return NULL;
}

"""FutureIter_send(): Future.__iter__ ignores values pushed to it."""
def futureiter_send(op: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    return futureiter_iternext(op);
}

"""FutureIter_throw()."""
def futureiter_throw(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    if _PyArg_CheckPositional("throw", nargs, 1, 3) == 0 {
        return NULL;
    }
    if nargs > 1 {
        if PyErr_WarnEx(
            PyExc_DeprecationWarning,
            "the (type, exc, tb) signature of throw() is deprecated, use the single-arg signature instead.",
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
        PyErr_SetString(PyExc_TypeError, "throw() third argument must be a traceback");
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
                PyExc_TypeError, "instance exception may not have a separate value"
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
            "exceptions must be classes deriving BaseException or instances of such a class"
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

"""FutureIter_clear()."""
def futureiter_clear(op: ptr[PyObject]) -> i32 {
    record = iter_of(op).view(1);
    future = record[0].future;
    if future {
        record[0].future = NULL;
        jacpy_release(future);
    }
    return i32(0);
}

"""FutureIter_close()."""
def futureiter_close(op: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    futureiter_clear(op);
    return none();
}

"""FutureIter_traverse()."""
def futureiter_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    status = visit_reference(Py_TYPE(op), visitor, context);
    if status != 0 {
        return status;
    }
    return visit_reference(iter_of(op).view(1)[0].future, visitor, context);
}

# ---------------------------------------------------------------------------
# The Task step wrapper and Task._wakeup.

def:priv wrapper_of(op: ptr[PyObject]) -> ptr[TaskStepMethWrapper] {
    return ptr[TaskStepMethWrapper](op);
}

"""TaskStepMethWrapper_clear()."""
def stepwrapper_clear(op: ptr[PyObject]) -> i32 {
    record = wrapper_of(op).view(1);
    task = record[0].sw_task;
    record[0].sw_task = NULL;
    release(task);
    arg = record[0].sw_arg;
    record[0].sw_arg = NULL;
    release(arg);
    return i32(0);
}

"""TaskStepMethWrapper_dealloc()."""
def stepwrapper_dealloc(op: ptr[PyObject]) {
    PyObject_GC_UnTrack(op);
    stepwrapper_clear(op);
    free_object(Py_TYPE(op), op);
}

"""TaskStepMethWrapper_call(): step the task with the stored argument."""
def stepwrapper_call(
    op: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    if kwds and jacpy_dict_size(kwds) != 0 {
        PyErr_SetString(PyExc_TypeError, "function takes no keyword arguments");
        return NULL;
    }
    if args and PyTuple_Size(args) != 0 {
        PyErr_SetString(PyExc_TypeError, "function takes no positional arguments");
        return NULL;
    }
    record = wrapper_of(op).view(1);
    return task_step(module_of(op), record[0].sw_task, record[0].sw_arg);
}

"""TaskStepMethWrapper_traverse()."""
def stepwrapper_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
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

"""TaskStepMethWrapper_get___self__()."""
def stepwrapper_self(op: ptr[PyObject], closure: u64) -> ptr[PyObject] {
    task = wrapper_of(op).view(1)[0].sw_task;
    return Py_NewRef(task) if task else none();
}

"""TaskStepMethWrapper_new()."""
def:priv stepwrapper_new(task: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
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

import from c {
    # TaskWakeupDef: a METH_O method bound to its task.
    glob:priv task_wakeup_def: PositionalMethodRecord = PositionalMethodRecord(
             ml_name=ptr[u8]("task_wakeup"),
             ml_meth=task_wakeup,
             ml_flags=i32(8),
             ml_doc=ptr[u8]()
         );
}

"""task_wakeup(): resume the task when the future it awaits is done."""
def task_wakeup(op: ptr[PyObject], o: ptr[PyObject]) -> ptr[PyObject] {
    module = module_of(op);
    if task_or_future_check(module, o) {
        if future_awaited_by_discard(o, op) != 0 {
            return NULL;
        }
    }
    if future_check_exact(module, o) or task_check_exact(module, o) {
        (res, fut_result) = future_get_result(module, o);
        if res == 0 {
            jacpy_release(fut_result);
            return task_step(module, op, NULL);
        }
        if res == 1 {
            result = task_step(module, op, fut_result);
            jacpy_release(fut_result);
            return result;
        }
        # An exception was raised.
    } else {
        fut_result = PyObject_CallMethodObjArgs(o, ids.result, NULL);
        if fut_result {
            jacpy_release(fut_result);
            return task_step(module, op, NULL);
        }
        # An exception was raised.
    }
    exc = PyErr_GetRaisedException();
    result = task_step(module, op, exc);
    jacpy_release(exc);
    return result;
}

# ---------------------------------------------------------------------------
# Task

"""task_call_step_soon(): loop.call_soon(step wrapper, context=task's)."""
def:priv task_call_step_soon(
    module: ptr[PyObject], task: ptr[PyObject], arg: ptr[PyObject]
) -> int {
    cb = stepwrapper_new(task, arg);
    if not cb {
        return -1;
    }
    # An evil call_soon could alter task_context (gh-126080).
    task_context = Py_NewRef(task_of(task).view(1)[0].task_context);
    ret = call_soon(module, fut_of(task).view(1)[0].fut_loop, cb, NULL, task_context);
    jacpy_release(task_context);
    jacpy_release(cb);
    return ret;
}

"""task_set_error_soon(): schedule a step that raises `et(message)`."""
def:priv task_set_error_soon(
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

def _asyncio_Task___init___impl(
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
        PyErr_Format(PyExc_TypeError, "a coroutine was expected, got %R", coro);
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
        # Defer the task name formatting: store the counter as an int.
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

"""TaskObj_clear()."""
def task_clear(op: ptr[PyObject]) -> i32 {
    future_clear(op);
    record = task_of(op).view(1);
    for index in [0, 1, 2, 3] {
        # coro, context, name, fut_waiter
        value = NULL;
        if index == 0 {
            value = record[0].task_coro;
            record[0].task_coro = NULL;
        } elif index == 1 {
            value = record[0].task_context;
            record[0].task_context = NULL;
        } elif index == 2 {
            value = record[0].task_name;
            record[0].task_name = NULL;
        } else {
            value = record[0].task_fut_waiter;
            record[0].task_fut_waiter = NULL;
        }
        release(value);
    }
    return i32(0);
}

"""TaskObj_traverse()."""
def task_traverse(op: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    record = task_of(op).view(1);
    status = visit_reference(Py_TYPE(op), visitor, context);
    for value in [
        record[0].task_context,
        record[0].task_coro,
        record[0].task_name,
        record[0].task_fut_waiter
    ] {
        if status != 0 {
            return status;
        }
        status = visit_reference(value, visitor, context);
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

def _asyncio_Task__log_destroy_pending_get_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    return truth(has_bit(receiver, BIT_LOG_DESTROY_PENDING));
}

def _asyncio_Task__log_destroy_pending_set_impl(
    receiver: ptr[PyObject], value: ptr[PyObject]
) -> int {
    if not value {
        PyErr_SetString(PyExc_AttributeError, "cannot delete attribute");
        return -1;
    }
    is_true = int(PyObject_IsTrue(value));
    if is_true < 0 {
        return -1;
    }
    set_bit(receiver, BIT_LOG_DESTROY_PENDING, is_true != 0);
    return 0;
}

def _asyncio_Task__must_cancel_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return truth(has_bit(receiver, BIT_MUST_CANCEL));
}

def _asyncio_Task__coro_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    coro = task_of(receiver).view(1)[0].task_coro;
    return Py_NewRef(coro) if coro else none();
}

def _asyncio_Task__fut_waiter_get_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    waiter = task_of(receiver).view(1)[0].task_fut_waiter;
    return Py_NewRef(waiter) if waiter else none();
}

"""TaskObj_repr()."""
def task_repr(op: ptr[PyObject]) -> ptr[PyObject] {
    return PyObject_CallOneArg(state_ref(module_of(op), STATE_TASK_REPR_FUNC), op);
}

def _asyncio_Task__make_cancelled_error_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return _asyncio_Future__make_cancelled_error_impl(receiver);
}

def _asyncio_Task_cancel_impl(
    receiver: ptr[PyObject], msg: ptr[PyObject]
) -> ptr[PyObject] {
    set_bit(receiver, BIT_LOG_TB, False);
    if int(fut_of(receiver).view(1)[0].fut_state) != STATE_PENDING {
        return truth(False);
    }
    record = task_of(receiver).view(1);
    record[0].task_num_cancels_requested = record[0].task_num_cancels_requested
        + i32(1);
    # These three lines are controversial: see the discussion starting at
    # https://github.com/python/cpython/pull/31394#issuecomment-1053545331
    # and the corresponding code in tasks.py.
    # if self.task_num_cancels_requested > 1: return False
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

def _asyncio_Task_cancelling_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromLong(
        i64(task_of(receiver).view(1)[0].task_num_cancels_requested)
    );
}

def _asyncio_Task_uncancel_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
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

"""A call of `function(receiver, *rest)` (the base_tasks helpers)."""
def:priv call_with_task(
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

def _asyncio_Task_get_stack_impl(
    receiver: ptr[PyObject], cls: ptr[PyObject], limit: ptr[PyObject]
) -> ptr[PyObject] {
    return call_with_task(
        state_ref(module_of_type(cls), STATE_TASK_GET_STACK_FUNC), receiver, [limit]
    );
}

def _asyncio_Task_print_stack_impl(
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

def _asyncio_Task_set_result_impl(
    receiver: ptr[PyObject], result: ptr[PyObject]
) -> ptr[PyObject] {
    PyErr_SetString(PyExc_RuntimeError, "Task does not support set_result operation");
    return NULL;
}

def _asyncio_Task_set_exception_impl(
    receiver: ptr[PyObject], exception: ptr[PyObject]
) -> ptr[PyObject] {
    PyErr_SetString(
        PyExc_RuntimeError, "Task does not support set_exception operation"
    );
    return NULL;
}

def _asyncio_Task_get_coro_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return _asyncio_Task__coro_get_impl(receiver);
}

def _asyncio_Task_get_context_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(task_of(receiver).view(1)[0].task_context);
}

def _asyncio_Task_get_name_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
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

def _asyncio_Task_set_name_impl(
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

"""TaskObj_finalize(): report a task destroyed while pending, then the
future's never-retrieved exception."""
def task_finalize(op: ptr[PyObject]) {
    if int(fut_of(op).view(1)[0].fut_state) == STATE_PENDING
        and has_bit(op, BIT_LOG_DESTROY_PENDING) {
        # Save the current exception, if any.
        exc = PyErr_GetRaisedException();
        message = PyUnicode_FromString("Task was destroyed but it is pending!");
        call_exception_handler(op, message, ids.task, op);
        # Restore the saved exception.
        PyErr_SetRaisedException(exc);
    }
    future_finalize(op);
}

"""TaskObj_dealloc(): unregister after finalization, so a resurrected task
stays registered."""
def task_dealloc(op: ptr[PyObject]) {
    if PyObject_CallFinalizerFromDealloc(op) < 0 {
        # Resurrected.
        return;
    }
    unregister_task(op);
    type = Py_TYPE(op);
    PyObject_GC_UnTrack(op);
    PyObject_ClearWeakRefs(op);
    task_clear(op);
    free_object(type, op);
}

"""gen_status_from_result()."""
def:priv gen_status_from_result(result: ptr[PyObject]) -> tuple[int, ptr[PyObject]] {
    if result {
        return (int(PYGEN_NEXT), result);
    }
    value = NULL;
    if _PyGen_FetchStopIterationValue(&mut value) == 0 {
        return (int(PYGEN_RETURN), value);
    }
    return (int(PYGEN_ERROR), NULL);
}

"""The awaiting part of task_step_handle_result_impl() for a future on the
task's loop: await it, waking the task when it is done."""
def:priv await_future(
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
        # result.add_done_callback(task._wakeup)
        tmp = future_add_done_callback(module, result, wrapper, record[0].task_context);
    } else {
        # result._asyncio_future_blocking = False
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
    # task._fut_waiter = result; the reference `result` held moves there.
    record[0].task_fut_waiter = result;
    if has_bit(task, BIT_MUST_CANCEL) {
        # An evil __getattribute__ could delete task_cancel_msg before the
        # task is cancelled (gh-126138).
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

"""callable(arg, context=ctx) through vectorcall with keyword names."""
def:priv call_with_context(
    callable: ptr[PyObject],
    arg: ptr[PyObject],
    ctx: ptr[PyObject],
    module: ptr[PyObject]
) -> ptr[PyObject] {
    import from jaclang.runtime.python.modules.asyncio_core { CallStack }
    stack = CallStack(slot0=arg, slot1=ctx, slot2=NULL, slot3=NULL, slot4=NULL);
    return PyObject_Vectorcall(
        callable,
        ptr[ptr[PyObject]](ptr(&mut stack)),
        u64(1),
        state_ref(module, STATE_CONTEXT_KWNAME)
    );
}

"""task_step_handle_result_impl(): act on what the coroutine yielded; owns
`result`."""
def:priv task_step_handle_result(
    module: ptr[PyObject], task: ptr[PyObject], result: ptr[PyObject]
) -> ptr[PyObject] {
    task_loop = fut_of(task).view(1)[0].fut_loop;
    if result == task {
        # A task that wants to await on itself.
        o = task_set_error_soon(
            module,
            task,
            PyExc_RuntimeError,
            PyUnicode_FromFormat("Task cannot await on itself: %R", task)
        );
        jacpy_release(result);
        return o;
    }
    # Is `result` a FutureObj or TaskObj (and not a subclass)?
    if future_check_exact(module, result) or task_check_exact(module, result) {
        # Is `result` future attached to a different loop?
        if fut_of(result).view(1)[0].fut_loop != task_loop {
            return different_loop(module, task, result);
        }
        if not has_bit(result, BIT_BLOCKING) {
            return yield_instead_of_yield_from(module, task, result);
        }
        return await_future(module, task, result, True);
    }
    # A bare yield relinquishes control for one event loop iteration.
    if result == Py_None {
        if task_call_step_soon(module, task, NULL) != 0 {
            jacpy_release(result);
            return NULL;
        }
        return result;
    }
    # Is `result` a Future-compatible object?
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
        # Is `result` future attached to a different loop?
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
    # Is `result` a generator?
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
    # The `result` is none of the above.
    o = task_set_error_soon(
        module,
        task,
        PyExc_RuntimeError,
        PyUnicode_FromFormat("Task got bad yield: %R", result)
    );
    jacpy_release(result);
    return o;
}

def:priv yield_instead_of_yield_from(
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

def:priv different_loop(
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

"""task_step_impl(): run the coroutine one step (sending None, or throwing
`exc`)."""
def:priv task_step_impl(
    module: ptr[PyObject], task: ptr[PyObject], exc: ptr[PyObject]
) -> ptr[PyObject] {
    record = task_of(task).view(1);
    if int(fut_of(task).view(1)[0].fut_state) != STATE_PENDING {
        PyErr_Format(
            state_ref(module, STATE_INVALID_STATE_ERROR),
            "__step(): already done: %R %R",
            task,
            exc if exc else Py_None
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
            # exc was not a CancelledError.
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
        PyErr_SetString(PyExc_RuntimeError, "uninitialized Task object");
        if clear_exc {
            # We created `exc` during this call.
            jacpy_release(exc);
        }
        return NULL;
    }
    gen_status = int(PYGEN_ERROR);
    result = NULL;
    if not exc {
        gen_status = int(PyIter_Send(coro, Py_None, &mut result));
    } else {
        (gen_status, result) = gen_status_from_result(
            PyObject_CallMethodObjArgs(coro, ids.throw, exc, NULL)
        );
        if clear_exc {
            # We created `exc` during this call.
            jacpy_release(exc);
        }
    }
    if gen_status == PYGEN_RETURN or gen_status == PYGEN_ERROR {
        if result {
            # StopIteration: the underlying coroutine has resolved.
            tmp = NULL;
            if has_bit(task, BIT_MUST_CANCEL) {
                # The task is cancelled right before the coroutine stops.
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
            # CancelledError: transfer its ownership to the future.
            cancelled = PyErr_GetRaisedException();
            fut_of(task).view(1)[0].fut_cancelled_exc = cancelled;
            return future_cancel(module, task, NULL);
        }
        # Some other exception: pop it and call Task.set_exception().
        raised = PyErr_GetRaisedException();
        o = future_set_exception(module, task, raised);
        if not o {
            # An exception in Task.set_exception().
            jacpy_release(raised);
            return NULL;
        }
        jacpy_release(o);
        if PyErr_GivenExceptionMatches(raised, PyExc_KeyboardInterrupt) != 0
            or PyErr_GivenExceptionMatches(raised, PyExc_SystemExit) != 0 {
            # A KeyboardInterrupt or SystemExit is re-raised.
            PyErr_SetRaisedException(raised);
            return NULL;
        }
        jacpy_release(raised);
        return none();
    }
    return task_step_handle_result(module, task, result);
}

"""task_step(): step the task as the running task of its loop."""
def task_step(
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

"""task_eager_start(): run the first step now, as the loop's current task."""
def:priv task_eager_start(module: ptr[PyObject], task: ptr[PyObject]) -> int {
    record = task_of(task).view(1);
    loop = fut_of(task).view(1)[0].fut_loop;
    prevtask = swap_current_task(loop, task);
    if not prevtask {
        return -1;
    }
    # Register the task into the list of tasks: a task that completes
    # eagerly (without suspending) unregisters itself when done in
    # future_schedule_callbacks(), otherwise it continues as a regular task.
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
        # This really helps performance on pyperformance benchmarks.
        coro = record[0].task_coro;
        record[0].task_coro = NULL;
        release(coro);
    }
    return retval;
}

# ---------------------------------------------------------------------------
# Module functions.

def _asyncio__get_running_loop_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    loop = running_loop();
    if not loop {
        # There's no currently running event loop.
        return none();
    }
    return Py_NewRef(loop);
}

def _asyncio__set_running_loop_impl(
    module: ptr[PyObject], loop: ptr[PyObject]
) -> ptr[PyObject] {
    slot = running_loop_slot().view(1);
    previous = slot[0];
    slot[0] = Py_NewRef(loop) if loop != Py_None else NULL;
    release(previous);
    return none();
}

def _asyncio_get_event_loop_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    return get_event_loop(module);
}

def _asyncio_get_running_loop_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    loop = running_loop();
    if not loop {
        # There's no currently running event loop.
        PyErr_SetString(PyExc_RuntimeError, "no running event loop");
        return NULL;
    }
    return Py_NewRef(loop);
}

def _asyncio__register_task_impl(
    module: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject] {
    if task_check(module, task) {
        # An asyncio.Task instance or subclass: the linked list.
        register_task(task);
        return none();
    }
    # A task not inheriting from asyncio.Task falls back to the weak set.
    res = PyObject_CallMethodObjArgs(
        state_ref(module, STATE_NON_ASYNCIO_TASKS), ids.add, task, NULL
    );
    if not res {
        return NULL;
    }
    jacpy_release(res);
    return none();
}

def _asyncio__register_eager_task_impl(
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

def _asyncio__unregister_task_impl(
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

def _asyncio__unregister_eager_task_impl(
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

def _asyncio__enter_task_impl(
    module: ptr[PyObject], loop: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject] {
    if enter_task(loop, task) < 0 {
        return NULL;
    }
    return none();
}

def _asyncio__leave_task_impl(
    module: ptr[PyObject], loop: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject] {
    if leave_task(loop, task) < 0 {
        return NULL;
    }
    return none();
}

def _asyncio__swap_current_task_impl(
    module: ptr[PyObject], loop: ptr[PyObject], task: ptr[PyObject]
) -> ptr[PyObject] {
    return swap_current_task(loop, task);
}

def _asyncio_current_task_impl(
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
    # Fast path for the running loop of the current thread.
    if running_loop() == loop {
        jacpy_release(loop);
        task = running_task_slot().view(1)[0];
        return Py_NewRef(task) if task else none();
    }
    # Look through the running loops and tasks of every thread.
    ret = jacpy_asyncio_thread_task(loop);
    jacpy_release(loop);
    return ret;
}

"""add_one_task(): add a pending task of `loop` to the set `tasks`."""
def:priv add_one_task(
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

def _asyncio_all_tasks_impl(
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
    # Add the eager tasks first so as not to miss a task that graduates from
    # eager to non-eager; all tasks go to a list first, and those done are
    # filtered out into the resulting set.
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
    # The current thread's list alone for its running loop; for a loop
    # running elsewhere, with the world stopped, the interpreter's list (of
    # tasks whose thread state is gone) and every thread's.
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

def _asyncio_future_add_to_awaited_by_impl(
    module: ptr[PyObject], fut: ptr[PyObject], waiter: ptr[PyObject]
) -> ptr[PyObject] {
    if task_or_future_check(module, fut) and task_or_future_check(module, waiter) {
        if future_awaited_by_add(fut, waiter) != 0 {
            return NULL;
        }
    }
    return none();
}

def _asyncio_future_discard_from_awaited_by_impl(
    module: ptr[PyObject], fut: ptr[PyObject], waiter: ptr[PyObject]
) -> ptr[PyObject] {
    if task_or_future_check(module, fut) and task_or_future_check(module, waiter) {
        if future_awaited_by_discard(fut, waiter) != 0 {
            return NULL;
        }
    }
    return none();
}
