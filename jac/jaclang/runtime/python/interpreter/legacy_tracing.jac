import from c {
    glob _PyInstrumentation_DISABLE: PyObject,
         _PyInstrumentation_MISSING: PyObject; obj LegacyEventHandler {
        has ob_base: _object,
            vectorcall:
                Callable[
                    [ptr[PyObject], ptr[ptr[PyObject]], u64, ptr[PyObject]],
                    ptr[PyObject]
                ],
            event: i32;
    }  obj LegacyTraceCall {
        has call: Callable[[ptr[PyObject], ptr[PyObject], i32, ptr[PyObject]], i32] = 0;
    }  obj LegacyEventSet {
        has value: u64 = u64(0);
    }  def jacpy_stack_address(slots: &mut LegacyEventSet) -> int;  def PyEval_GetFrame -> ptr[
        PyObject
    ];  def _PyEval_StopTheWorld(interp: ptr[u8]);  def _PyEval_StartTheWorld(
        interp: ptr[u8]
    );  def _PySys_Audit(
        tstate: ptr[PyThreadState], event: ptr[u8], argFormat: ptr[u8], *args: any
    ) -> i32;  def _PyOnceFlag_CallOnceSlow(
        flag: ptr[u8], once_fn: ptr, arg: ptr
    ) -> i32;  def _PyMonitoring_RegisterCallback(
        tool_id: i32, event_id: i32, obj_: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyMonitoring_SetEvents(
        tool_id: i32, events: u32
    ) -> i32;  def _PyMonitoring_SetLocalEvents(
        code: ptr[PyObject], tool_id: i32, events: u32
    ) -> i32;  def _PyMonitoring_GetLocalEvents(
        code: ptr[PyObject], tool_id: i32, events: ptr[u32]
    ) -> i32;  def _Py_Instrumentation_GetLine(
        code: ptr[PyObject], line_data: ptr[u8], index: i32
    ) -> i32;
}

def handler_event(op: ptr[PyObject]) -> i32;

def tstate_slot(tstate: ptr[PyThreadState], offset: i64) -> ptr[ptr[u8]];

def tstate_object(tstate: ptr[PyThreadState], offset: i64) -> ptr[PyObject];

def call_tracefunc(
    tstate: ptr[PyThreadState],
    func_offset: i64,
    obj_offset: i64,
    frame: ptr[PyObject],
    what: i32,
    arg: ptr[PyObject]
) -> i32;

def frame_flag(frame: ptr[PyObject], offset: i64) -> bool;

def set_frame_lineno(frame: ptr[PyObject], lineno: i32);

def none_result -> ptr[PyObject];

def disable_result -> ptr[PyObject];

def missing_frame_error(message_kind: i32) -> ptr[PyObject];

def call_profile_func(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def sys_profile_start(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def sys_profile_throw(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def sys_profile_return(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def sys_profile_unwind(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def sys_profile_call_or_return(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject];

def set_opcode_trace_world_stopped(code: ptr[PyObject], enable: bool) -> i32;

def call_trace_func(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def sys_trace_exception_func(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def sys_trace_start(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def sys_trace_throw(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def sys_trace_unwind(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def sys_trace_return(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def sys_trace_yield(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def sys_trace_instruction_func(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def trace_line(
    tstate: ptr[PyThreadState], self_: ptr[PyObject], frame: ptr[PyObject], line: i32
) -> ptr[PyObject];

def sys_trace_line_func(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def code_unit_index(offset: ptr[PyObject]) -> i32;

def sys_trace_jump_func(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def set_callbacks(
    tool: i32, vectorcall: int, legacy_event: i32, event1: i32, event2: i32
) -> i32;

def setup_profile_callbacks(arg: ptr) -> i32;

def tstate_interp_of(tstate: ptr[PyThreadState]) -> ptr[u8];

def swap_func_arg(
    tstate: ptr[PyThreadState],
    func_offset: i64,
    obj_offset: i64,
    count_offset: i64,
    func: ptr,
    arg: ptr[PyObject]
) -> ptr[PyObject];

def swap_profile_func_arg(
    tstate: ptr[PyThreadState], func: ptr, arg: ptr[PyObject]
) -> ptr[PyObject];

def set_monitoring_profile_events(interp: ptr[u8]) -> i32;

def call_once(flag: ptr[u8], once_fn: ptr) -> i32;

def runtime_state -> ptr[u8];

def threads_head(interp: ptr[u8]) -> ptr[PyThreadState];

def thread_next(tstate: ptr[PyThreadState]) -> ptr[PyThreadState];

def count_threads(interp: ptr[u8]) -> i64;

def setup_trace_callbacks(arg: ptr) -> i32;

def swap_trace_func_arg(
    tstate: ptr[PyThreadState], func: ptr, arg: ptr[PyObject]
) -> ptr[PyObject];

def set_monitoring_trace_events(interp: ptr[u8]) -> i32;

def maybe_set_opcode_trace(tstate: ptr[PyThreadState]) -> i32;

import from c {
    glob _PyLegacyEventHandler_Type: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=addressof(PyType_Type)
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("sys.legacy_event_handler"),
             tp_basicsize=32,
             tp_vectorcall_offset=16,
             tp_call=PyVectorcall_Call,
             tp_flags=Py_TPFLAGS_DEFAULT
                 | Py_TPFLAGS_BASETYPE
                 | Py_TPFLAGS_HAVE_VECTORCALL
                 | Py_TPFLAGS_DISALLOW_INSTANTIATION
         );
}

import from c {
    def _PyEval_SetOpcodeTrace(frame: ptr[PyObject], enable: bool) -> i32 {
        code = iframe_code(
            ptr[ptr[u8]](ptr[u8](frame) + PyFrameObject_F_FRAME).view(1)[0]
        );
        interp = current_interp();
        _PyEval_StopTheWorld(interp);
        res = set_opcode_trace_world_stopped(code, enable);
        _PyEval_StartTheWorld(interp);
        return res;
    }  def _PyEval_SetProfile(
        tstate: ptr[PyThreadState], func: ptr, arg: ptr[PyObject]
    ) -> i32 {
        current = current_tstate();
        if _PySys_Audit(current, ptr[u8]("sys.setprofile"), ptr[u8]()) < 0 {
            return -1;
        }
        interp = tstate_interp_of(tstate);
        if call_once(
            interp + PyInterpreterState_SYS_PROFILE_ONCE_FLAG,
            ptr(setup_profile_callbacks)
        )
            < 0 {
            return -1;
        }
        _PyEval_StopTheWorld(interp);
        old_profileobj = swap_profile_func_arg(tstate, func, arg);
        ret = set_monitoring_profile_events(interp);
        _PyEval_StartTheWorld(interp);
        object_xdecref(old_profileobj);
        return ret;
    }  def _PyEval_SetProfileAllThreads(
        interp: ptr[u8], func: ptr, arg: ptr[PyObject]
    ) -> i32 {
        current = current_tstate();
        if _PySys_Audit(current, ptr[u8]("sys.setprofile"), ptr[u8]()) < 0 {
            return -1;
        }
        if call_once(
            interp + PyInterpreterState_SYS_PROFILE_ONCE_FLAG,
            ptr(setup_profile_callbacks)
        )
            < 0 {
            return -1;
        }
        _PyEval_StopTheWorld(interp);
        head_lock(runtime_state());
        num_thread_states = count_threads(interp);
        old_profileobjs = PyTuple_New(num_thread_states);
        if not old_profileobjs {
            head_unlock(runtime_state());
            _PyEval_StartTheWorld(interp);
            return -1;
        }
        ts = threads_head(interp);
        while ts {
            old = swap_profile_func_arg(ts, func, arg);
            num_thread_states -= 1;
            tuple_set_item(old_profileobjs, num_thread_states, old);
            ts = thread_next(ts);
        }
        head_unlock(runtime_state());
        ret = set_monitoring_profile_events(interp);
        _PyEval_StartTheWorld(interp);
        object_xdecref(old_profileobjs);
        return ret;
    }  def _PyEval_SetTrace(
        tstate: ptr[PyThreadState], func: ptr, arg: ptr[PyObject]
    ) -> i32 {
        current = current_tstate();
        if _PySys_Audit(current, ptr[u8]("sys.settrace"), ptr[u8]()) < 0 {
            return -1;
        }
        interp = tstate_interp_of(tstate);
        if call_once(
            interp + PyInterpreterState_SYS_TRACE_ONCE_FLAG, ptr(setup_trace_callbacks)
        )
            < 0 {
            return -1;
        }
        _PyEval_StopTheWorld(interp);
        old_traceobj = swap_trace_func_arg(tstate, func, arg);
        err = set_monitoring_trace_events(interp);
        if err == 0 {
            if ptr[i64](interp + PyInterpreterState_SYS_TRACING_THREADS).view(1)[0]
                != 0 {
                err = maybe_set_opcode_trace(tstate);
            }
        }
        _PyEval_StartTheWorld(interp);
        object_xdecref(old_traceobj);
        return err;
    }  def _PyEval_SetTraceAllThreads(
        interp: ptr[u8], func: ptr, arg: ptr[PyObject]
    ) -> i32 {
        current = current_tstate();
        if _PySys_Audit(current, ptr[u8]("sys.settrace"), ptr[u8]()) < 0 {
            return -1;
        }
        if call_once(
            interp + PyInterpreterState_SYS_TRACE_ONCE_FLAG, ptr(setup_trace_callbacks)
        )
            < 0 {
            return -1;
        }
        _PyEval_StopTheWorld(interp);
        head_lock(runtime_state());
        num_thread_states = count_threads(interp);
        old_trace_objs = PyTuple_New(num_thread_states);
        if not old_trace_objs {
            head_unlock(runtime_state());
            _PyEval_StartTheWorld(interp);
            return -1;
        }
        ts = threads_head(interp);
        while ts {
            old = swap_trace_func_arg(ts, func, arg);
            num_thread_states -= 1;
            tuple_set_item(old_trace_objs, num_thread_states, old);
            ts = thread_next(ts);
        }
        if ptr[i64](interp + PyInterpreterState_SYS_TRACING_THREADS).view(1)[0] != 0 {
            tracing_ts = threads_head(interp);
            while tracing_ts {
                if maybe_set_opcode_trace(tracing_ts) != 0 {
                    head_unlock(runtime_state());
                    _PyEval_StartTheWorld(interp);
                    object_xdecref(old_trace_objs);
                    return -1;
                }
                tracing_ts = thread_next(tracing_ts);
            }
        }
        head_unlock(runtime_state());
        err = set_monitoring_trace_events(interp);
        _PyEval_StartTheWorld(interp);
        object_xdecref(old_trace_objs);
        return err;
    }
}

impl handler_event(op: ptr[PyObject]) -> i32 {
    return ptr[LegacyEventHandler](op).view(1)[0].event;
}

impl tstate_slot(tstate: ptr[PyThreadState], offset: i64) -> ptr[ptr[u8]] {
    return ptr[ptr[u8]](ptr[u8](tstate) + offset);
}

impl tstate_object(tstate: ptr[PyThreadState], offset: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](ptr[u8](tstate) + offset).view(1)[0];
}

impl call_tracefunc(
    tstate: ptr[PyThreadState],
    func_offset: i64,
    obj_offset: i64,
    frame: ptr[PyObject],
    what: i32,
    arg: ptr[PyObject]
) -> i32 {
    return ptr[LegacyTraceCall](ptr[u8](tstate) + func_offset).view(1)[0].call(
        tstate_object(tstate, obj_offset), frame, what, arg
    );
}

impl frame_flag(frame: ptr[PyObject], offset: i64) -> bool {
    return (ptr[u8](frame) + offset).view(1)[0] != u8(0);
}

impl set_frame_lineno(frame: ptr[PyObject], lineno: i32) {
    ptr[i32](ptr[u8](frame) + PyFrameObject_LINENO).view(1)[0] = lineno;
}

impl none_result -> ptr[PyObject] {
    return object_new_ref(Py_None);
}

impl disable_result -> ptr[PyObject] {
    return addressof(_PyInstrumentation_DISABLE);
}

impl missing_frame_error(message_kind: i32) -> ptr[PyObject] {
    if message_kind == 0 {
        PyErr_SetString(
            PyExc_SystemError, "Missing frame when calling profile function."
        );
    } else {
        PyErr_SetString(
            PyExc_SystemError, "Missing frame when calling trace function."
        );
    }
    return NULL;
}

impl call_profile_func(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    tstate = current_tstate();
    if not tstate_slot(tstate, PyThreadState_C_PROFILEFUNC).view(1)[0] {
        return none_result();
    }
    frame = PyEval_GetFrame();
    if not frame {
        return missing_frame_error(0);
    }
    object_incref(frame);
    err = call_tracefunc(
        tstate,
        PyThreadState_C_PROFILEFUNC,
        PyThreadState_C_PROFILEOBJ,
        frame,
        handler_event(self_),
        arg
    );
    object_decref(frame);
    if err != 0 {
        return NULL;
    }
    return none_result();
}

impl sys_profile_start(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return call_profile_func(callable, Py_None);
}

impl sys_profile_throw(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return call_profile_func(callable, Py_None);
}

impl sys_profile_return(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return call_profile_func(callable, args.view(3)[2]);
}

impl sys_profile_unwind(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return call_profile_func(callable, NULL);
}

impl sys_profile_call_or_return(
    op: ptr[PyObject], args: ptr[ptr[PyObject]], nargsf: u64, kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    callable = args.view(4)[2];
    if object_type_check(callable, ptr[PyTypeObject](addressof(PyCFunction_Type))) {
        return call_profile_func(op, callable);
    }
    if ptr[PyObject](object_type(callable)) == addressof(PyMethodDescr_Type) {
        self_arg = args.view(4)[3];
        if self_arg == addressof(_PyInstrumentation_MISSING) {
            return none_result();
        }
        meth = object_type(callable).view(1)[0].tp_descr_get(
            callable, self_arg, ptr[PyObject](object_type(self_arg))
        );
        if not meth {
            return NULL;
        }
        res = call_profile_func(op, meth);
        object_decref(meth);
        return res;
    }
    return none_result();
}

impl set_opcode_trace_world_stopped(code: ptr[PyObject], enable: bool) -> i32 {
    slots: own LegacyEventSet = LegacyEventSet();
    events_ptr = ptr[u32](jacpy_stack_address(&mut slots));
    if _PyMonitoring_GetLocalEvents(code, PY_MONITORING_SYS_TRACE_ID, events_ptr) < 0 {
        return -1;
    }
    events = events_ptr.view(1)[0];
    instruction_bit = u32(1) << u32(PY_MONITORING_EVENT_INSTRUCTION);
    if enable {
        if (events & instruction_bit) != u32(0) {
            return 0;
        }
        events = events | instruction_bit;
    } else {
        if (events & instruction_bit) == u32(0) {
            return 0;
        }
        events = events & ~instruction_bit;
    }
    return _PyMonitoring_SetLocalEvents(code, PY_MONITORING_SYS_TRACE_ID, events);
}

impl call_trace_func(self_: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    tstate = current_tstate();
    if not tstate_slot(tstate, PyThreadState_C_TRACEFUNC).view(1)[0] {
        return none_result();
    }
    frame = PyEval_GetFrame();
    if not frame {
        return missing_frame_error(1);
    }
    if frame_flag(frame, PyFrameObject_TRACE_OPCODES) {
        if _PyEval_SetOpcodeTrace(frame, True) != 0 {
            return NULL;
        }
    }
    object_incref(frame);
    err = call_tracefunc(
        tstate,
        PyThreadState_C_TRACEFUNC,
        PyThreadState_C_TRACEOBJ,
        frame,
        handler_event(self_),
        arg
    );
    set_frame_lineno(frame, 0);
    object_decref(frame);
    if err != 0 {
        return NULL;
    }
    return none_result();
}

impl sys_trace_exception_func(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    exc = args.view(3)[2];
    type_obj = ptr[PyObject](object_type(exc));
    tb = PyException_GetTraceback(exc);
    if not tb {
        tb = object_new_ref(Py_None);
    }
    tup = PyTuple_Pack(i64(3), type_obj, exc, tb);
    object_decref(tb);
    if not tup {
        return NULL;
    }
    res = call_trace_func(callable, tup);
    object_decref(tup);
    return res;
}

impl sys_trace_start(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return call_trace_func(callable, Py_None);
}

impl sys_trace_throw(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return call_trace_func(callable, Py_None);
}

impl sys_trace_unwind(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return call_trace_func(callable, NULL);
}

impl sys_trace_return(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return call_trace_func(callable, args.view(3)[2]);
}

impl sys_trace_yield(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    return call_trace_func(callable, args.view(3)[2]);
}

impl sys_trace_instruction_func(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    frame = PyEval_GetFrame();
    if not frame {
        return missing_frame_error(1);
    }
    tstate = current_tstate();
    if not tstate_slot(tstate, PyThreadState_C_TRACEFUNC).view(1)[0]
        or not frame_flag(frame, PyFrameObject_TRACE_OPCODES) {
        if _PyEval_SetOpcodeTrace(frame, False) != 0 {
            return NULL;
        }
        return none_result();
    }
    object_incref(frame);
    err = call_tracefunc(
        tstate,
        PyThreadState_C_TRACEFUNC,
        PyThreadState_C_TRACEOBJ,
        frame,
        handler_event(callable),
        Py_None
    );
    set_frame_lineno(frame, 0);
    object_decref(frame);
    if err != 0 {
        return NULL;
    }
    return none_result();
}

impl trace_line(
    tstate: ptr[PyThreadState], self_: ptr[PyObject], frame: ptr[PyObject], line: i32
) -> ptr[PyObject] {
    if not frame_flag(frame, PyFrameObject_TRACE_LINES) {
        return none_result();
    }
    if line < 0 {
        return none_result();
    }
    object_incref(frame);
    set_frame_lineno(frame, line);
    err = call_tracefunc(
        tstate,
        PyThreadState_C_TRACEFUNC,
        PyThreadState_C_TRACEOBJ,
        frame,
        handler_event(self_),
        Py_None
    );
    set_frame_lineno(frame, 0);
    object_decref(frame);
    if err != 0 {
        return NULL;
    }
    return none_result();
}

impl sys_trace_line_func(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = current_tstate();
    if not tstate_slot(tstate, PyThreadState_C_TRACEFUNC).view(1)[0] {
        return none_result();
    }
    line = PyLong_AsInt(args.view(2)[1]);
    frame = PyEval_GetFrame();
    if not frame {
        return missing_frame_error(1);
    }
    return trace_line(tstate, callable, frame, line);
}

impl code_unit_index(offset: ptr[PyObject]) -> i32 {
    return i32.wrap(u64.wrap(i64(PyLong_AsInt(offset))) // u64(2));
}

impl sys_trace_jump_func(
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = current_tstate();
    if not tstate_slot(tstate, PyThreadState_C_TRACEFUNC).view(1)[0] {
        return none_result();
    }
    from_ = code_unit_index(args.view(3)[1]);
    to = code_unit_index(args.view(3)[2]);
    if to > from_ {
        return disable_result();
    }
    code = args.view(3)[0];
    monitoring = ptr[ptr[u8]](ptr[u8](code) + PyCodeObject_MONITORING).view(1)[0];
    lines = ptr[ptr[u8]](monitoring + _PyCoMonitoringData_LINES).view(1)[0];
    to_line = _Py_Instrumentation_GetLine(code, lines, to);
    from_line = _Py_Instrumentation_GetLine(code, lines, from_);
    if to_line != from_line {
        return disable_result();
    }
    frame = PyEval_GetFrame();
    if not frame {
        return missing_frame_error(1);
    }
    if not frame_flag(frame, PyFrameObject_TRACE_LINES) {
        return none_result();
    }
    return trace_line(tstate, callable, frame, to_line);
}

impl set_callbacks(
    tool: i32, vectorcall: int, legacy_event: i32, event1: i32, event2: i32
) -> i32 {
    callback = _PyObject_New(ptr[PyObject](addressof(_PyLegacyEventHandler_Type)));
    if not callback {
        return -1;
    }
    handler = ptr[LegacyEventHandler](callback);
    handler.view(1)[0].vectorcall = vectorcall;
    handler.view(1)[0].event = legacy_event;
    object_xdecref(_PyMonitoring_RegisterCallback(tool, event1, callback));
    if event2 >= 0 {
        object_xdecref(_PyMonitoring_RegisterCallback(tool, event2, callback));
    }
    object_decref(callback);
    return 0;
}

impl setup_profile_callbacks(arg: ptr) -> i32 {
    if set_callbacks(
        PY_MONITORING_SYS_PROFILE_ID,
        int(ptr(sys_profile_start)),
        PyTrace_CALL,
        PY_MONITORING_EVENT_PY_START,
        PY_MONITORING_EVENT_PY_RESUME
    )
        != 0 {
        return -1;
    }
    if set_callbacks(
        PY_MONITORING_SYS_PROFILE_ID,
        int(ptr(sys_profile_throw)),
        PyTrace_CALL,
        PY_MONITORING_EVENT_PY_THROW,
        -1
    )
        != 0 {
        return -1;
    }
    if set_callbacks(
        PY_MONITORING_SYS_PROFILE_ID,
        int(ptr(sys_profile_return)),
        PyTrace_RETURN,
        PY_MONITORING_EVENT_PY_RETURN,
        PY_MONITORING_EVENT_PY_YIELD
    )
        != 0 {
        return -1;
    }
    if set_callbacks(
        PY_MONITORING_SYS_PROFILE_ID,
        int(ptr(sys_profile_unwind)),
        PyTrace_RETURN,
        PY_MONITORING_EVENT_PY_UNWIND,
        -1
    )
        != 0 {
        return -1;
    }
    if set_callbacks(
        PY_MONITORING_SYS_PROFILE_ID,
        int(ptr(sys_profile_call_or_return)),
        PyTrace_C_CALL,
        PY_MONITORING_EVENT_CALL,
        -1
    )
        != 0 {
        return -1;
    }
    if set_callbacks(
        PY_MONITORING_SYS_PROFILE_ID,
        int(ptr(sys_profile_call_or_return)),
        PyTrace_C_RETURN,
        PY_MONITORING_EVENT_C_RETURN,
        -1
    )
        != 0 {
        return -1;
    }
    if set_callbacks(
        PY_MONITORING_SYS_PROFILE_ID,
        int(ptr(sys_profile_call_or_return)),
        PyTrace_C_EXCEPTION,
        PY_MONITORING_EVENT_C_RAISE,
        -1
    )
        != 0 {
        return -1;
    }
    return 0;
}

impl tstate_interp_of(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return tstate_interp(ptr(tstate));
}

impl swap_func_arg(
    tstate: ptr[PyThreadState],
    func_offset: i64,
    obj_offset: i64,
    count_offset: i64,
    func: ptr,
    arg: ptr[PyObject]
) -> ptr[PyObject] {
    func_slot = tstate_slot(tstate, func_offset);
    new_set = i64(1) if ptr[u8](func) else i64(0);
    old_set = i64(1) if func_slot.view(1)[0] else i64(0);
    func_slot.view(1)[0] = ptr[u8](func);
    obj_slot = ptr[ptr[PyObject]](ptr[u8](tstate) + obj_offset);
    old_obj = obj_slot.view(1)[0];
    if arg {
        object_incref(arg);
    }
    obj_slot.view(1)[0] = arg;
    count = ptr[i64](tstate_interp_of(tstate) + count_offset);
    count.view(1)[0] = count.view(1)[0] + (new_set - old_set);
    return old_obj;
}

impl swap_profile_func_arg(
    tstate: ptr[PyThreadState], func: ptr, arg: ptr[PyObject]
) -> ptr[PyObject] {
    return swap_func_arg(
        tstate,
        PyThreadState_C_PROFILEFUNC,
        PyThreadState_C_PROFILEOBJ,
        PyInterpreterState_SYS_PROFILING_THREADS,
        func,
        arg
    );
}

impl set_monitoring_profile_events(interp: ptr[u8]) -> i32 {
    events: u32 = 0;
    if ptr[i64](interp + PyInterpreterState_SYS_PROFILING_THREADS).view(1)[0] != 0 {
        events = u32(
            (1 << PY_MONITORING_EVENT_PY_START)
                | (1 << PY_MONITORING_EVENT_PY_RESUME)
                | (1 << PY_MONITORING_EVENT_PY_RETURN)
                | (1 << PY_MONITORING_EVENT_PY_YIELD)
                | (1 << PY_MONITORING_EVENT_CALL)
                | (1 << PY_MONITORING_EVENT_PY_UNWIND)
                | (1 << PY_MONITORING_EVENT_PY_THROW)
        );
    }
    return _PyMonitoring_SetEvents(PY_MONITORING_SYS_PROFILE_ID, events);
}

impl call_once(flag: ptr[u8], once_fn: ptr) -> i32 {
    if u8.wrap(__atomic_load_i8(int(flag), 5)) == _Py_ONCE_INITIALIZED {
        return 0;
    }
    return _PyOnceFlag_CallOnceSlow(flag, once_fn, ptr());
}

impl runtime_state -> ptr[u8] {
    return ptr[u8](addressof(_PyRuntime));
}

impl threads_head(interp: ptr[u8]) -> ptr[PyThreadState] {
    return ptr[ptr[PyThreadState]](interp + PyInterpreterState_THREADS_HEAD).view(1)[0];
}

impl thread_next(tstate: ptr[PyThreadState]) -> ptr[PyThreadState] {
    return ptr[ptr[PyThreadState]](ptr[u8](tstate) + PyThreadState_NEXT).view(1)[0];
}

impl count_threads(interp: ptr[u8]) -> i64 {
    n: i64 = 0;
    p = threads_head(interp);
    while p {
        n += 1;
        p = thread_next(p);
    }
    return n;
}

impl setup_trace_callbacks(arg: ptr) -> i32 {
    if set_callbacks(
        PY_MONITORING_SYS_TRACE_ID,
        int(ptr(sys_trace_start)),
        PyTrace_CALL,
        PY_MONITORING_EVENT_PY_START,
        PY_MONITORING_EVENT_PY_RESUME
    )
        != 0 {
        return -1;
    }
    if set_callbacks(
        PY_MONITORING_SYS_TRACE_ID,
        int(ptr(sys_trace_throw)),
        PyTrace_CALL,
        PY_MONITORING_EVENT_PY_THROW,
        -1
    )
        != 0 {
        return -1;
    }
    if set_callbacks(
        PY_MONITORING_SYS_TRACE_ID,
        int(ptr(sys_trace_return)),
        PyTrace_RETURN,
        PY_MONITORING_EVENT_PY_RETURN,
        -1
    )
        != 0 {
        return -1;
    }
    if set_callbacks(
        PY_MONITORING_SYS_TRACE_ID,
        int(ptr(sys_trace_yield)),
        PyTrace_RETURN,
        PY_MONITORING_EVENT_PY_YIELD,
        -1
    )
        != 0 {
        return -1;
    }
    if set_callbacks(
        PY_MONITORING_SYS_TRACE_ID,
        int(ptr(sys_trace_exception_func)),
        PyTrace_EXCEPTION,
        PY_MONITORING_EVENT_RAISE,
        PY_MONITORING_EVENT_STOP_ITERATION
    )
        != 0 {
        return -1;
    }
    if set_callbacks(
        PY_MONITORING_SYS_TRACE_ID,
        int(ptr(sys_trace_line_func)),
        PyTrace_LINE,
        PY_MONITORING_EVENT_LINE,
        -1
    )
        != 0 {
        return -1;
    }
    if set_callbacks(
        PY_MONITORING_SYS_TRACE_ID,
        int(ptr(sys_trace_unwind)),
        PyTrace_RETURN,
        PY_MONITORING_EVENT_PY_UNWIND,
        -1
    )
        != 0 {
        return -1;
    }
    if set_callbacks(
        PY_MONITORING_SYS_TRACE_ID,
        int(ptr(sys_trace_jump_func)),
        PyTrace_LINE,
        PY_MONITORING_EVENT_JUMP,
        -1
    )
        != 0 {
        return -1;
    }
    if set_callbacks(
        PY_MONITORING_SYS_TRACE_ID,
        int(ptr(sys_trace_instruction_func)),
        PyTrace_OPCODE,
        PY_MONITORING_EVENT_INSTRUCTION,
        -1
    )
        != 0 {
        return -1;
    }
    return 0;
}

impl swap_trace_func_arg(
    tstate: ptr[PyThreadState], func: ptr, arg: ptr[PyObject]
) -> ptr[PyObject] {
    return swap_func_arg(
        tstate,
        PyThreadState_C_TRACEFUNC,
        PyThreadState_C_TRACEOBJ,
        PyInterpreterState_SYS_TRACING_THREADS,
        func,
        arg
    );
}

impl set_monitoring_trace_events(interp: ptr[u8]) -> i32 {
    events: u32 = 0;
    if ptr[i64](interp + PyInterpreterState_SYS_TRACING_THREADS).view(1)[0] != 0 {
        events = u32(
            (1 << PY_MONITORING_EVENT_PY_START)
                | (1 << PY_MONITORING_EVENT_PY_RESUME)
                | (1 << PY_MONITORING_EVENT_PY_RETURN)
                | (1 << PY_MONITORING_EVENT_PY_YIELD)
                | (1 << PY_MONITORING_EVENT_RAISE)
                | (1 << PY_MONITORING_EVENT_LINE)
                | (1 << PY_MONITORING_EVENT_JUMP)
                | (1 << PY_MONITORING_EVENT_PY_UNWIND)
                | (1 << PY_MONITORING_EVENT_PY_THROW)
                | (1 << PY_MONITORING_EVENT_STOP_ITERATION)
        );
    }
    return _PyMonitoring_SetEvents(PY_MONITORING_SYS_TRACE_ID, events);
}

impl maybe_set_opcode_trace(tstate: ptr[PyThreadState]) -> i32 {
    iframe = tstate_current_frame(ptr(tstate));
    if not iframe {
        return 0;
    }
    frame = iframe_ptr(iframe, _PyInterpreterFrame_FRAME_OBJ);
    if not frame or not frame_flag(ptr[PyObject](frame), PyFrameObject_TRACE_OPCODES) {
        return 0;
    }
    return set_opcode_trace_world_stopped(iframe_code(iframe), True);
}
