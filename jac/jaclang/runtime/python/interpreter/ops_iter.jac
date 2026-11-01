import from c {
    glob PyListIter_Type: PyTypeObject,
         PyTupleIter_Type: PyTypeObject; obj IterArgs {
        has s0: ptr[PyObject] = ptr[PyObject](),
            s1: ptr[PyObject] = ptr[PyObject]();
    }  def jacpy_stack_address(slots: &mut IterArgs) -> int;  def _PyEval_GetANext(
        aiter: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyEval_GetAwaitable(
        iterable: ptr[PyObject], oparg: i32
    ) -> ptr[PyObject];  def _PyEval_MonitorRaise(
        tstate: ptr, frame: ptr[u8], instr: ptr[u16]
    );  def _PyErr_SetRaisedException(tstate: ptr, exc: ptr[PyObject]);  def _Py_call_instrumentation_arg(
        tstate: ptr, event: i32, frame: ptr[u8], instr: ptr[u16], arg: ptr[PyObject]
    ) -> i32;  def _Py_Specialize_ForIter(iter_: u64, instr: ptr[u16], oparg: i32);  def _Py_Specialize_Send(
        receiver: u64, instr: ptr[u16]
    );  @__preserve_none
    def _TAIL_CALL_END_FOR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        next_instr = next_instr + 1;
        value = (stack_pointer - 1).view(1)[0];
        stack_pointer = stack_pointer - 1;
        frame_set_stackpointer(frame, stack_pointer);
        sr_close(value);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }
}

def iter_error_occurred(tstate: ptr) -> bool;

def iter_do_monitor_exc(
    tstate: ptr, frame: ptr[u8], instr: ptr[u16], event: i32
) -> i32;

def iter_monitor_reraise(tstate: ptr, frame: ptr[u8], instr: ptr[u16]);

def iter_counter_triggers(counter: u16) -> bool;

def iter_counter_advance(this_instr: ptr[u16]);

def iter_gen_ready(gen: ptr[PyObject]) -> bool;

def iter_gen_push_frame(
    tstate: ptr, frame: ptr[u8], oparg: i32, gen: ptr[PyObject], value: u64
) -> ptr[u8];

def END_SEND(value: u64) -> u64;

def GET_ITER(iterable: u64) -> u64;

def GET_YIELD_FROM_ITER(frame: ptr[u8], iterable: u64) -> u64;

def GET_AITER(obj_: u64) -> u64;

def GET_ANEXT(aiter: u64) -> u64;

def GET_AWAITABLE(oparg: i32, iterable: u64) -> u64;

def _END_ASYNC_FOR(
    tstate: ptr, frame: ptr[u8], this_instr: ptr[u16], exc_st: u64
) -> i32;

def CLEANUP_THROW(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    exc_value_st: u64,
    none: ptr[u64],
    value: ptr[u64]
) -> i32;

def _SPECIALIZE_FOR_ITER(
    counter: u16, iter_: u64, this_instr: ptr[u16], oparg: i32
) -> i32;

def _FOR_ITER(
    tstate: ptr, frame: ptr[u8], this_instr: ptr[u16], iter_: u64, next_: ptr[u64]
) -> i32;

def _ITER_CHECK_LIST(iter_: u64) -> bool;

def _ITER_JUMP_LIST(iter_: u64) -> i32;

def _ITER_NEXT_LIST(iter_: u64) -> u64;

def _ITER_CHECK_TUPLE(iter_: u64) -> bool;

def _ITER_JUMP_TUPLE(iter_: u64) -> i32;

def _ITER_NEXT_TUPLE(iter_: u64) -> u64;

def _ITER_CHECK_RANGE(iter_: u64) -> bool;

def _ITER_JUMP_RANGE(iter_: u64) -> i32;

def _ITER_NEXT_RANGE(iter_: u64) -> u64;

def _FOR_ITER_GEN_FRAME(
    tstate: ptr, frame: ptr[u8], oparg: i32, iter_: u64, gen_frame: ptr[u64]
) -> i32;

def _SPECIALIZE_SEND(counter: u16, receiver: u64, this_instr: ptr[u16]) -> i32;

def _SEND(
    tstate: ptr,
    frame: ptr[u8],
    oparg: i32,
    this_instr: ptr[u16],
    next_instr: ptr[u16],
    v: u64,
    retval: ptr[u64]
) -> i32;

def _SEND_GEN_FRAME(
    tstate: ptr, frame: ptr[u8], oparg: i32, receiver: u64, v: u64, gen_frame: ptr[u64]
) -> i32;

impl iter_error_occurred(tstate: ptr) -> bool {
    current = ptr[ptr[PyObject]](
        ptr[u8](tstate) + PyThreadState_CURRENT_EXCEPTION
    ).view(
        1
    )[0];
    if current {
        return True;
    }
    return False;
}

impl iter_do_monitor_exc(
    tstate: ptr, frame: ptr[u8], instr: ptr[u16], event: i32
) -> i32 {
    flags = ptr[i32](frame_code(frame) + PyCodeObject_FLAGS).view(1)[0];
    if (flags & CO_NO_MONITORING_EVENTS) != 0 {
        return 0;
    }
    exc = PyErr_GetRaisedException();
    err = _Py_call_instrumentation_arg(tstate, event, frame, instr, exc);
    if err == 0 {
        PyErr_SetRaisedException(exc);
    } else {
        object_decref(exc);
    }
    return err;
}

impl iter_monitor_reraise(tstate: ptr, frame: ptr[u8], instr: ptr[u16]) {
    tools = tstate_interp(tstate)
        + (PyInterpreterState_MONITORS + i64(PY_MONITORING_EVENT_RERAISE));
    if tools.view(1)[0] == u8(0) {
        return;
    }
    iter_do_monitor_exc(tstate, frame, instr, PY_MONITORING_EVENT_RERAISE);
}

impl iter_counter_triggers(counter: u16) -> bool {
    return counter < u16(15);
}

impl iter_counter_advance(this_instr: ptr[u16]) {
    cache = this_instr + 1;
    cache.view(1)[0] = u16.wrap(i64(cache.view(1)[0]) - 16);
}

impl iter_gen_ready(gen: ptr[PyObject]) -> bool {
    state = ptr[i8](ptr[u8](gen) + PyGenObject_FRAME_STATE).view(1)[0];
    return i32(state) < FRAME_EXECUTING;
}

impl iter_gen_push_frame(
    tstate: ptr, frame: ptr[u8], oparg: i32, gen: ptr[PyObject], value: u64
) -> ptr[u8] {
    gen_frame = ptr[u8](gen) + PyGenObject_IFRAME;
    sp = frame_stackpointer(gen_frame);
    sp.view(1)[0] = value;
    frame_set_stackpointer(gen_frame, sp + 1);
    ptr[i8](ptr[u8](gen) + PyGenObject_FRAME_STATE).view(1)[0] = i8(FRAME_EXECUTING);
    exc_info = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_EXC_INFO);
    ptr[ptr[u8]](ptr[u8](gen) + PyGenObject_EXC_PREVIOUS_ITEM).view(1)[0] = exc_info.view(
        1
    )[0];
    exc_info.view(1)[0] = ptr[u8](gen) + PyGenObject_EXC_STATE;
    ptr[u16](frame + _PyInterpreterFrame_RETURN_OFFSET).view(1)[0] = u16.wrap(
        i64(oparg) + 2
    );
    ptr[ptr[u8]](gen_frame + _PyInterpreterFrame_PREVIOUS).view(1)[0] = frame;
    return gen_frame;
}

impl END_SEND(value: u64) -> u64 {
    return value;
}

impl GET_ITER(iterable: u64) -> u64 {
    iter_o = PyObject_GetIter(sr_borrow(iterable));
    if not iter_o {
        return u64(0);
    }
    return sr_steal(iter_o);
}

impl GET_YIELD_FROM_ITER(frame: ptr[u8], iterable: u64) -> u64 {
    type = sr_type(iterable);
    if type == ptr[PyTypeObject](addressof(PyCoro_Type)) {
        flags = ptr[i32](frame_code(frame) + PyCodeObject_FLAGS).view(1)[0];
        if (flags & (CO_COROUTINE | CO_ITERABLE_COROUTINE)) == 0 {
            PyErr_SetString(
                PyExc_TypeError,
                ptr[u8](
                    "cannot 'yield from' a coroutine object in a non-coroutine generator"
                )
            );
            return u64(0);
        }
        return sr_dup(iterable);
    }
    if type == ptr[PyTypeObject](addressof(PyGen_Type)) {
        return sr_dup(iterable);
    }
    iter_o = PyObject_GetIter(sr_borrow(iterable));
    if not iter_o {
        return u64(0);
    }
    return sr_steal(iter_o);
}

impl GET_AITER(obj_: u64) -> u64 {
    obj_o = sr_borrow(obj_);
    type = sr_type(obj_);
    methods = type.view(1)[0].tp_as_async;
    getter_missing = True;
    if methods {
        if int(methods.view(1)[0].am_aiter) != 0 {
            getter_missing = False;
        }
    }
    if getter_missing {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("'async for' requires an object with __aiter__ method, got %.100s"),
            type.view(1)[0].tp_name
        );
        return u64(0);
    }
    iter_o = methods.view(1)[0].am_aiter(obj_o);
    if not iter_o {
        return u64(0);
    }
    iter_type = ptr[_object](iter_o).view(1)[0].ob_type;
    iter_methods = iter_type.view(1)[0].tp_as_async;
    anext_missing = True;
    if iter_methods {
        if int(iter_methods.view(1)[0].am_anext) != 0 {
            anext_missing = False;
        }
    }
    if anext_missing {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8](
                "'async for' received an object from __aiter__ that does not implement __anext__: %.100s"
            ),
            iter_type.view(1)[0].tp_name
        );
        object_decref(iter_o);
        return u64(0);
    }
    return sr_steal(iter_o);
}

impl GET_ANEXT(aiter: u64) -> u64 {
    awaitable_o = _PyEval_GetANext(sr_borrow(aiter));
    if not awaitable_o {
        return u64(0);
    }
    return sr_steal(awaitable_o);
}

impl GET_AWAITABLE(oparg: i32, iterable: u64) -> u64 {
    iter_o = _PyEval_GetAwaitable(sr_borrow(iterable), oparg);
    if not iter_o {
        return u64(0);
    }
    return sr_steal(iter_o);
}

impl _END_ASYNC_FOR(
    tstate: ptr, frame: ptr[u8], this_instr: ptr[u16], exc_st: u64
) -> i32 {
    exc = sr_borrow(exc_st);
    if PyErr_GivenExceptionMatches(exc, PyExc_StopAsyncIteration) != 0 {
        return ST_OK;
    }
    object_incref(exc);
    _PyErr_SetRaisedException(tstate, exc);
    iter_monitor_reraise(tstate, frame, this_instr);
    return ST_UNWIND;
}

impl CLEANUP_THROW(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    exc_value_st: u64,
    none: ptr[u64],
    value: ptr[u64]
) -> i32 {
    exc_value = sr_borrow(exc_value_st);
    if PyErr_GivenExceptionMatches(exc_value, PyExc_StopIteration) != 0 {
        stop_value = ptr[ptr[PyObject]](
            ptr[u8](exc_value) + PyStopIterationObject_VALUE
        ).view(
            1
        )[0];
        value.view(1)[0] = sr_new(stop_value);
        none.view(1)[0] = sr_none();
        return ST_OK;
    }
    _PyErr_SetRaisedException(tstate, object_new_ref(exc_value));
    iter_monitor_reraise(tstate, frame, this_instr);
    return ST_UNWIND;
}

impl _SPECIALIZE_FOR_ITER(
    counter: u16, iter_: u64, this_instr: ptr[u16], oparg: i32
) -> i32 {
    if iter_counter_triggers(counter) {
        _Py_Specialize_ForIter(iter_, this_instr, oparg);
        return ST_REDISPATCH;
    }
    iter_counter_advance(this_instr);
    return ST_OK;
}

impl _FOR_ITER(
    tstate: ptr, frame: ptr[u8], this_instr: ptr[u16], iter_: u64, next_: ptr[u64]
) -> i32 {
    iter_o = sr_borrow(iter_);
    type = sr_type(iter_);
    if int(type.view(1)[0].tp_iternext) == 0 {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("'%.100s' object is not an iterator"),
            type.view(1)[0].tp_name
        );
        return ST_ERROR;
    }
    next_o = type.view(1)[0].tp_iternext(iter_o);
    if not next_o {
        if iter_error_occurred(tstate) {
            if PyErr_ExceptionMatches(PyExc_StopIteration) == 0 {
                return ST_ERROR;
            }
            _PyEval_MonitorRaise(tstate, frame, this_instr);
            PyErr_Clear();
        }
        return ST_EXHAUSTED;
    }
    next_.view(1)[0] = sr_steal(next_o);
    return ST_OK;
}

impl _ITER_CHECK_LIST(iter_: u64) -> bool {
    return sr_type(iter_) == addressof(PyListIter_Type);
}

impl _ITER_JUMP_LIST(iter_: u64) -> i32 {
    it = ptr[_PyListIterObject](sr_borrow(iter_));
    seq = it.view(1)[0].it_seq;
    if not seq {
        it.view(1)[0].it_index = -1;
        return ST_EXHAUSTED;
    }
    index = it.view(1)[0].it_index;
    if index < 0 or index >= ptr[PyVarObject](seq).view(1)[0].ob_size {
        it.view(1)[0].it_index = -1;
        it.view(1)[0].it_seq = ptr[PyListObject]();
        object_decref(ptr[PyObject](seq));
        return ST_EXHAUSTED;
    }
    return ST_OK;
}

impl _ITER_NEXT_LIST(iter_: u64) -> u64 {
    it = ptr[_PyListIterObject](sr_borrow(iter_));
    seq = it.view(1)[0].it_seq;
    index = it.view(1)[0].it_index;
    it.view(1)[0].it_index = index + 1;
    return sr_new((seq.view(1)[0].ob_item + index).view(1)[0]);
}

impl _ITER_CHECK_TUPLE(iter_: u64) -> bool {
    return sr_type(iter_) == addressof(PyTupleIter_Type);
}

impl _ITER_JUMP_TUPLE(iter_: u64) -> i32 {
    it = ptr[_PyTupleIterObject](sr_borrow(iter_));
    seq = it.view(1)[0].it_seq;
    if not seq {
        return ST_EXHAUSTED;
    }
    index = it.view(1)[0].it_index;
    if index < 0 or index >= ptr[PyVarObject](seq).view(1)[0].ob_size {
        it.view(1)[0].it_seq = ptr[PyTupleObject]();
        object_decref(ptr[PyObject](seq));
        return ST_EXHAUSTED;
    }
    return ST_OK;
}

impl _ITER_NEXT_TUPLE(iter_: u64) -> u64 {
    it = ptr[_PyTupleIterObject](sr_borrow(iter_));
    seq = it.view(1)[0].it_seq;
    index = it.view(1)[0].it_index;
    it.view(1)[0].it_index = index + 1;
    return sr_new(tuple_get_item(ptr[PyObject](seq), index));
}

impl _ITER_CHECK_RANGE(iter_: u64) -> bool {
    return sr_type(iter_) == ptr[PyTypeObject](addressof(PyRangeIter_Type));
}

impl _ITER_JUMP_RANGE(iter_: u64) -> i32 {
    r = ptr[_PyRangeIterObject](sr_borrow(iter_));
    if r.view(1)[0].len <= 0 {
        return ST_EXHAUSTED;
    }
    return ST_OK;
}

impl _ITER_NEXT_RANGE(iter_: u64) -> u64 {
    r = ptr[_PyRangeIterObject](sr_borrow(iter_));
    value = r.view(1)[0].start;
    r.view(1)[0].start = wrapping_add(value, r.view(1)[0].step);
    r.view(1)[0].len = r.view(1)[0].len - 1;
    res = PyLong_FromLong(value);
    if not res {
        return u64(0);
    }
    return sr_steal(res);
}

impl _FOR_ITER_GEN_FRAME(
    tstate: ptr, frame: ptr[u8], oparg: i32, iter_: u64, gen_frame: ptr[u64]
) -> i32 {
    if sr_type(iter_) != ptr[PyTypeObject](addressof(PyGen_Type)) {
        return ST_DEOPT;
    }
    gen = sr_borrow(iter_);
    if not iter_gen_ready(gen) {
        return ST_DEOPT;
    }
    pushed = iter_gen_push_frame(tstate, frame, oparg, gen, sr_none());
    gen_frame.view(1)[0] = u64(int(pushed));
    return ST_OK;
}

impl _SPECIALIZE_SEND(counter: u16, receiver: u64, this_instr: ptr[u16]) -> i32 {
    if iter_counter_triggers(counter) {
        _Py_Specialize_Send(receiver, this_instr);
        return ST_REDISPATCH;
    }
    iter_counter_advance(this_instr);
    return ST_OK;
}

impl _SEND(
    tstate: ptr,
    frame: ptr[u8],
    oparg: i32,
    this_instr: ptr[u16],
    next_instr: ptr[u16],
    v: u64,
    retval: ptr[u64]
) -> i32 {
    receiver = (frame_stackpointer(frame) - 1).view(1)[0];
    receiver_o = sr_borrow(receiver);
    type = sr_type(receiver);
    if _CHECK_PEP_523(tstate)
        and (
            type == ptr[PyTypeObject](addressof(PyGen_Type))
            or type == ptr[PyTypeObject](addressof(PyCoro_Type))
        )
        and iter_gen_ready(receiver_o) {
        gen_frame = iter_gen_push_frame(
            tstate, frame, oparg, receiver_o, sr_make_heap_safe(v)
        );
        ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_CURRENT_FRAME).view(1)[0] = gen_frame;
        return ST_INLINED;
    }
    retval_o = NULL;
    if sr_is_none(v) and PyIter_Check(receiver_o) != 0 {
        retval_o = type.view(1)[0].tp_iternext(receiver_o);
    } else {
        slots: own IterArgs = IterArgs();
        stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
        stack.view(1)[0] = receiver_o;
        (stack + 1).view(1)[0] = sr_borrow(v);
        retval_o = PyObject_VectorcallMethod(
            py_id(_Py_ID_send), stack, u64(2) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
        );
    }
    jumped = False;
    if not retval_o {
        if PyErr_ExceptionMatches(PyExc_StopIteration) != 0 {
            _PyEval_MonitorRaise(tstate, frame, this_instr);
        }
        if _PyGen_FetchStopIterationValue(&mut retval_o) != 0 {
            sr_close(v);
            return ST_ERROR;
        }
        jumped = True;
    }
    sr_close(v);
    retval.view(1)[0] = sr_steal(retval_o);
    if jumped {
        frame_set_instr_ptr(frame, next_instr + i64(oparg));
        return ST_RESUME_AT;
    }
    return ST_OK;
}

impl _SEND_GEN_FRAME(
    tstate: ptr, frame: ptr[u8], oparg: i32, receiver: u64, v: u64, gen_frame: ptr[u64]
) -> i32 {
    type = sr_type(receiver);
    if type != ptr[PyTypeObject](addressof(PyGen_Type))
        and type != ptr[PyTypeObject](addressof(PyCoro_Type)) {
        return ST_DEOPT;
    }
    gen = sr_borrow(receiver);
    if not iter_gen_ready(gen) {
        return ST_DEOPT;
    }
    pushed = iter_gen_push_frame(tstate, frame, oparg, gen, sr_make_heap_safe(v));
    gen_frame.view(1)[0] = u64(int(pushed));
    return ST_OK;
}
