import from c {
    obj ControlStack {
        has s0: ptr[PyObject] = ptr[PyObject](),
            s1: ptr[PyObject] = ptr[PyObject](),
            s2: ptr[PyObject] = ptr[PyObject](),
            s3: ptr[PyObject] = ptr[PyObject](),
            s4: ptr[PyObject] = ptr[PyObject]();
    }  def jacpy_stack_address(slots: &mut ControlStack) -> int;  def _Py_FatalErrorFunc(
        func: ptr[u8], message: ptr[u8]
    );  def _PyErr_SetString(
        tstate: ptr[PyThreadState], exception: ptr[PyObject], message: ptr[u8]
    );  def _PyErr_Format(
        tstate: ptr[PyThreadState],
        exception: ptr[PyObject],
        format_: ptr[u8],
        *args: any
    ) -> ptr[PyObject];  def _PyErr_SetObject(
        tstate: ptr[PyThreadState], exception: ptr[PyObject], value: ptr[PyObject]
    );  def _PyErr_SetRaisedException(tstate: ptr[PyThreadState], exc: ptr[PyObject]);  def _PyErr_GetRaisedException(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyObject];  def _PyErr_GetTopmostException(
        tstate: ptr[PyThreadState]
    ) -> ptr[u8];  def PyErr_SetHandledException(exc: ptr[PyObject]);  def PyTraceBack_Here(
        frame: ptr[PyObject]
    ) -> i32;  def PyUnstable_InterpreterFrame_GetLine(frame: ptr[u8]) -> i32;  def _PyFrame_MakeAndSetFrameObject(
        frame: ptr[u8]
    ) -> ptr[PyObject];  def _PyEval_MonitorRaise(
        tstate: ptr[PyThreadState], frame: ptr[u8], instr: ptr[u16]
    );  def _PyEval_FrameClearAndPop(tstate: ptr[PyThreadState], frame: ptr[u8]);  def _PyEval_CheckExceptTypeValid(
        tstate: ptr[PyThreadState], right: ptr[PyObject]
    ) -> i32;  def _PyEval_CheckExceptStarTypeValid(
        tstate: ptr[PyThreadState], right: ptr[PyObject]
    ) -> i32;  def _PyEval_ExceptionGroupMatch(
        frame: ptr[u8],
        exc_value: ptr[PyObject],
        match_type: ptr[PyObject],
        match_: &mut ptr[PyObject],
        rest: &mut ptr[PyObject]
    ) -> i32;  def _Py_CheckRecursiveCallPy(tstate: ptr[PyThreadState]) -> i32;  def _Py_Instrument(
        code: ptr[u8], interp: ptr[u8]
    ) -> i32;  def _Py_call_instrumentation_arg(
        tstate: ptr[PyThreadState],
        event: i32,
        frame: ptr[u8],
        instr: ptr[u16],
        arg: ptr[PyObject]
    ) -> i32;
}

glob MAX_LINEAR_SEARCH: Final[i64] = 40;

def control_bytecode(frame: ptr[u8]) -> ptr[u16];

def control_stackbase(frame: ptr[u8]) -> ptr[u64];

def control_stack_pop(frame: ptr[u8]) -> u64;

def control_stack_push(frame: ptr[u8], value: u64);

def control_lasti(frame: ptr[u8]) -> i32;

def control_frame_owner(frame: ptr[u8]) -> i32;

def control_frame_previous(frame: ptr[u8]) -> ptr[u8];

def control_set_current_frame(tstate: ptr, frame: ptr[u8]);

def control_frame_is_incomplete(frame: ptr[u8]) -> bool;

def control_frame_object(frame: ptr[u8]) -> ptr[PyObject];

def control_err_occurred(tstate: ptr) -> bool;

def control_exc_value_slot(tstate: ptr) -> ptr[ptr[PyObject]];

def control_exception_instance_check(op: ptr[PyObject]) -> bool;

def control_exception_class_check(op: ptr[PyObject]) -> bool;

def control_opcode(instr: ptr[u16]) -> i32;

def control_set_opcode(instr: ptr[u16], opcode: i32);

def parse_varint(base: ptr[u8], at: i64) -> tuple[i64, i32];

def scan_back_to_entry_start(base: ptr[u8], at: i64) -> i64;

def skip_to_next_entry(base: ptr[u8], at: i64, end: i64) -> i64;

def get_exception_handler(code: ptr[u8], index: i32) -> tuple[i32, i32, i32, i32];

def no_tools_for_global_event(tstate: ptr, event: i32) -> bool;

def do_monitor_exc(tstate: ptr, frame: ptr[u8], instr: ptr[u16], event: i32) -> i32;

def monitor_reraise(tstate: ptr, frame: ptr[u8], instr: ptr[u16]);

def monitor_unwind(tstate: ptr, frame: ptr[u8], instr: ptr[u16]);

def monitor_handled(
    tstate: ptr, frame: ptr[u8], instr: ptr[u16], exc: ptr[PyObject]
) -> i32;

def raise_error(
    value: ptr[PyObject], type: ptr[PyObject], cause: ptr[PyObject]
) -> i32;

def do_raise(tstate: ptr, exc_in: ptr[PyObject], cause: ptr[PyObject]) -> i32;

def CHECK_EG_MATCH(
    tstate: ptr,
    frame: ptr[u8],
    exc_value_st: u64,
    match_type_st: u64,
    rest: ptr[u64],
    matched: ptr[u64]
) -> i32;

def CHECK_EXC_MATCH(tstate: ptr, left: u64, right: u64) -> u64;

def POP_EXCEPT(tstate: ptr, exc_value: u64);

def PUSH_EXC_INFO(tstate: ptr, exc: u64, prev_exc: ptr[u64], new_exc: ptr[u64]);

def RAISE_VARARGS(
    tstate: ptr, frame: ptr[u8], this_instr: ptr[u16], oparg: i32, args: ptr[u64]
) -> i32;

def RERAISE(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    oparg: i32,
    values: ptr[u64],
    exc_st: u64
) -> i32;

def WITH_EXCEPT_START(exit_func: u64, exit_self: u64, val: u64) -> u64;

def JUMP_BACKWARD_NO_INTERRUPT(oparg: i32) -> i64;

def _SPECIALIZE_JUMP_BACKWARD(tstate: ptr, this_instr: ptr[u16]) -> i32;

def _MAYBE_INSTRUMENT(tstate: ptr, frame: ptr[u8]) -> i32;

def _QUICKEN_RESUME(tstate: ptr, this_instr: ptr[u16]);

glob CONTROL_OPCODE_RESUME_CHECK: Final[i32] = 196;

def RESUME_CHECK(tstate: ptr, frame: ptr[u8]) -> bool;

import from c {
    @__preserve_none
    def _TAIL_CALL_pop_2_error(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        return tail _TAIL_CALL_error(
            frame, stack_pointer - 2, tstate, next_instr, oparg
        );
    }  @__preserve_none
    def _TAIL_CALL_pop_1_error(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        return tail _TAIL_CALL_error(
            frame, stack_pointer - 1, tstate, next_instr, oparg
        );
    }  @__preserve_none
    def _TAIL_CALL_error(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        if not control_err_occurred(tstate) {
            frame_set_stackpointer(frame, stack_pointer);
            _PyErr_SetString(
                ptr[PyThreadState](tstate),
                PyExc_SystemError,
                ptr[u8]("error return without exception set")
            );
            stack_pointer = frame_stackpointer(frame);
        }
        if not control_frame_is_incomplete(frame) {
            frame_set_stackpointer(frame, stack_pointer);
            f = control_frame_object(frame);
            stack_pointer = frame_stackpointer(frame);
            if f {
                frame_set_stackpointer(frame, stack_pointer);
                PyTraceBack_Here(f);
                stack_pointer = frame_stackpointer(frame);
            }
        }
        frame_set_stackpointer(frame, stack_pointer);
        _PyEval_MonitorRaise(ptr[PyThreadState](tstate), frame, next_instr - 1);
        return tail _TAIL_CALL_exception_unwind(
            frame, stack_pointer, tstate, next_instr, oparg
        );
    }  @__preserve_none
    def _TAIL_CALL_exception_unwind(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        offset = i32.wrap((int(next_instr) - int(control_bytecode(frame))) // 2 - 1);
        (handled, level, handler, lasti) = get_exception_handler(
            frame_code(frame), offset
        );
        if handled == 0 {
            stackbase = control_stackbase(frame);
            while int(frame_stackpointer(frame)) > int(stackbase) {
                sr_xclose(control_stack_pop(frame));
            }
            monitor_unwind(tstate, frame, next_instr - 1);
            return tail _TAIL_CALL_exit_unwind(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        new_top = control_stackbase(frame) + i64(level);
        while int(frame_stackpointer(frame)) > int(new_top) {
            sr_xclose(control_stack_pop(frame));
        }
        if lasti != 0 {
            control_stack_push(frame, sr_tag_int(i64(control_lasti(frame))));
        }
        exc = _PyErr_GetRaisedException(ptr[PyThreadState](tstate));
        control_stack_push(frame, sr_steal(exc));
        next_instr = control_bytecode(frame) + i64(handler);
        if monitor_handled(tstate, frame, next_instr, exc) < 0 {
            return tail _TAIL_CALL_exception_unwind(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        stack_pointer = frame_stackpointer(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_exit_unwind(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        remaining = ptr[i32](ptr[u8](tstate) + PyThreadState_PY_RECURSION_REMAINING);
        remaining.view(1)[0] = i32.wrap(i64(remaining.view(1)[0]) + 1);
        dying = frame;
        frame = control_frame_previous(dying);
        control_set_current_frame(tstate, frame);
        _PyEval_FrameClearAndPop(ptr[PyThreadState](tstate), dying);
        ptr[u16](frame + _PyInterpreterFrame_RETURN_OFFSET).view(1)[0] = u16(0);
        if control_frame_owner(frame) == FRAME_OWNED_BY_INTERPRETER {
            control_set_current_frame(tstate, control_frame_previous(frame));
            return NULL;
        }
        next_instr = frame_instr_ptr(frame);
        stack_pointer = frame_stackpointer(frame);
        return tail _TAIL_CALL_error(frame, stack_pointer, tstate, next_instr, oparg);
    }  @__preserve_none
    def _TAIL_CALL_start_frame(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        remaining = ptr[i32](ptr[u8](tstate) + PyThreadState_PY_RECURSION_REMAINING);
        depth = remaining.view(1)[0];
        remaining.view(1)[0] = i32.wrap(i64(depth) - 1);
        if depth <= 0 and _Py_CheckRecursiveCallPy(ptr[PyThreadState](tstate)) != 0 {
            return tail _TAIL_CALL_exit_unwind(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        next_instr = frame_instr_ptr(frame);
        stack_pointer = frame_stackpointer(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_UNKNOWN_OPCODE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        opcode = control_opcode(next_instr);
        filename = ptr[ptr[PyObject]](frame_code(frame) + PyCodeObject_FILENAME).view(1)[
            0
        ];
        line = PyUnstable_InterpreterFrame_GetLine(frame);
        _PyErr_Format(
            ptr[PyThreadState](tstate),
            PyExc_SystemError,
            ptr[u8]("%U:%d: unknown opcode %d"),
            filename,
            line,
            opcode
        );
        return tail _TAIL_CALL_error(frame, stack_pointer, tstate, next_instr, oparg);
    }  @__preserve_none
    def _TAIL_CALL_CACHE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        _Py_FatalErrorFunc(ptr[u8]("_TAIL_CALL_CACHE"), ptr[u8]("Executing a cache."));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_RESERVED(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        _Py_FatalErrorFunc(
            ptr[u8]("_TAIL_CALL_RESERVED"), ptr[u8]("Executing RESERVED instruction.")
        );
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_ENTER_EXECUTOR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        _Py_FatalErrorFunc(
            ptr[u8]("_TAIL_CALL_ENTER_EXECUTOR"),
            ptr[u8]("ENTER_EXECUTOR is not supported in this build")
        );
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_EXTENDED_ARG(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        oparg = i32.wrap((i64(oparg) << 8) | i64(next_oparg(next_instr)));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, oparg
        );
    }  @__preserve_none
    def _TAIL_CALL_INTERPRETER_EXIT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        frame_set_instr_ptr(frame, next_instr);
        retval = (stack_pointer - 1).view(1)[0];
        control_set_current_frame(tstate, control_frame_previous(frame));
        return sr_as_steal(retval);
    }
}

impl control_bytecode(frame: ptr[u8]) -> ptr[u16] {
    return ptr[u16](frame_code(frame) + PyCodeObject_CODE_ADAPTIVE);
}

impl control_stackbase(frame: ptr[u8]) -> ptr[u64] {
    nlocalsplus = ptr[i32](frame_code(frame) + PyCodeObject_NLOCALSPLUS).view(1)[0];
    return frame_local(frame, nlocalsplus);
}

impl control_stack_pop(frame: ptr[u8]) -> u64 {
    sp = frame_stackpointer(frame) - 1;
    frame_set_stackpointer(frame, sp);
    return sp.view(1)[0];
}

impl control_stack_push(frame: ptr[u8], value: u64) {
    sp = frame_stackpointer(frame);
    sp.view(1)[0] = value;
    frame_set_stackpointer(frame, sp + 1);
}

impl control_lasti(frame: ptr[u8]) -> i32 {
    return i32.wrap((int(frame_instr_ptr(frame)) - int(control_bytecode(frame))) // 2);
}

impl control_frame_owner(frame: ptr[u8]) -> i32 {
    return i32(ptr[u8](frame + _PyInterpreterFrame_OWNER).view(1)[0]);
}

impl control_frame_previous(frame: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](frame + _PyInterpreterFrame_PREVIOUS).view(1)[0];
}

impl control_set_current_frame(tstate: ptr, frame: ptr[u8]) {
    ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_CURRENT_FRAME).view(1)[0] = frame;
}

impl control_frame_is_incomplete(frame: ptr[u8]) -> bool {
    owner = control_frame_owner(frame);
    if owner >= FRAME_OWNED_BY_INTERPRETER {
        return True;
    }
    first = ptr[i32](frame_code(frame) + PyCodeObject_FIRSTTRACEABLE).view(1)[0];
    return owner != FRAME_OWNED_BY_GENERATOR
        and int(frame_instr_ptr(frame)) < int(control_bytecode(frame) + i64(first));
}

impl control_frame_object(frame: ptr[u8]) -> ptr[PyObject] {
    res = ptr[ptr[PyObject]](frame + _PyInterpreterFrame_FRAME_OBJ).view(1)[0];
    if res {
        return res;
    }
    return _PyFrame_MakeAndSetFrameObject(frame);
}

impl control_err_occurred(tstate: ptr) -> bool {
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

impl control_exc_value_slot(tstate: ptr) -> ptr[ptr[PyObject]] {
    exc_info = ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_EXC_INFO).view(1)[0];
    return ptr[ptr[PyObject]](exc_info + _PyErr_StackItem_EXC_VALUE);
}

impl control_exception_instance_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_BASE_EXC_SUBCLASS);
}

impl control_exception_class_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_TYPE_SUBCLASS)
        and type_has_feature(ptr[PyTypeObject](op), Py_TPFLAGS_BASE_EXC_SUBCLASS);
}

impl control_opcode(instr: ptr[u16]) -> i32 {
    return i32(instr.view(1)[0] & u16(255));
}

impl control_set_opcode(instr: ptr[u16], opcode: i32) {
    ptr[u8](instr).view(1)[0] = u8(opcode);
}

impl parse_varint(base: ptr[u8], at: i64) -> tuple[i64, i32] {
    i = at;
    val = i64((base + i).view(1)[0] & u8(63));
    while ((base + i).view(1)[0] & u8(64)) != u8(0) {
        i = i + 1;
        val = ((val & 0x3FFFFFF) << 6) | i64((base + i).view(1)[0] & u8(63));
    }
    return (i + 1, i32.wrap(val));
}

impl scan_back_to_entry_start(base: ptr[u8], at: i64) -> i64 {
    i = at;
    while ((base + i).view(1)[0] & u8(128)) == u8(0) {
        i = i - 1;
    }
    return i;
}

impl skip_to_next_entry(base: ptr[u8], at: i64, end: i64) -> i64 {
    i = at;
    while i < end and ((base + i).view(1)[0] & u8(128)) == u8(0) {
        i = i + 1;
    }
    return i;
}

impl get_exception_handler(code: ptr[u8], index: i32) -> tuple[i32, i32, i32, i32] {
    table = ptr[ptr[PyObject]](code + PyCodeObject_EXCEPTIONTABLE).view(1)[0];
    base = ptr[u8](table) + PyBytesObject_OB_SVAL;
    start: i64 = 0;
    end: i64 = object_size(table);
    if end - start > MAX_LINEAR_SEARCH {
        (first_end, first_offset) = parse_varint(base, start);
        if first_offset > index {
            return (i32(0), i32(0), i32(0), i32(0));
        }
        while end - start > MAX_LINEAR_SEARCH {
            mid = scan_back_to_entry_start(base, start + ((end - start) >> 1));
            (mid_end, offset) = parse_varint(base, mid);
            if offset > index {
                end = mid;
            } else {
                start = mid;
            }
        }
    }
    scan = start;
    while scan < end {
        (after_start, start_offset) = parse_varint(base, scan);
        if start_offset > index {
            break;
        }
        (after_size, size) = parse_varint(base, after_start);
        if i64(start_offset) + i64(size) > i64(index) {
            (after_handler, handler) = parse_varint(base, after_size);
            (after_depth, depth_and_lasti) = parse_varint(base, after_handler);
            return (i32(1), depth_and_lasti >> 1, handler, depth_and_lasti & 1);
        }
        scan = skip_to_next_entry(base, after_size, end);
    }
    return (i32(0), i32(0), i32(0), i32(0));
}

impl no_tools_for_global_event(tstate: ptr, event: i32) -> bool {
    tools = tstate_interp(tstate) + PyInterpreterState_MONITORS_TOOLS;
    return (tools + i64(event)).view(1)[0] == u8(0);
}

impl do_monitor_exc(tstate: ptr, frame: ptr[u8], instr: ptr[u16], event: i32) -> i32 {
    flags = ptr[i32](frame_code(frame) + PyCodeObject_FLAGS).view(1)[0];
    if (flags & CO_NO_MONITORING_EVENTS) != 0 {
        return 0;
    }
    exc = PyErr_GetRaisedException();
    err = _Py_call_instrumentation_arg(
        ptr[PyThreadState](tstate), event, frame, instr, exc
    );
    if err == 0 {
        PyErr_SetRaisedException(exc);
    } else {
        object_decref(exc);
    }
    return err;
}

impl monitor_reraise(tstate: ptr, frame: ptr[u8], instr: ptr[u16]) {
    if no_tools_for_global_event(tstate, PY_MONITORING_EVENT_RERAISE) {
        return;
    }
    do_monitor_exc(tstate, frame, instr, PY_MONITORING_EVENT_RERAISE);
}

impl monitor_unwind(tstate: ptr, frame: ptr[u8], instr: ptr[u16]) {
    if no_tools_for_global_event(tstate, PY_MONITORING_EVENT_PY_UNWIND) {
        return;
    }
    do_monitor_exc(tstate, frame, instr, PY_MONITORING_EVENT_PY_UNWIND);
}

impl monitor_handled(
    tstate: ptr, frame: ptr[u8], instr: ptr[u16], exc: ptr[PyObject]
) -> i32 {
    if no_tools_for_global_event(tstate, PY_MONITORING_EVENT_EXCEPTION_HANDLED) {
        return 0;
    }
    return _Py_call_instrumentation_arg(
        ptr[PyThreadState](tstate),
        PY_MONITORING_EVENT_EXCEPTION_HANDLED,
        frame,
        instr,
        exc
    );
}

impl raise_error(
    value: ptr[PyObject], type: ptr[PyObject], cause: ptr[PyObject]
) -> i32 {
    object_xdecref(value);
    object_xdecref(type);
    object_xdecref(cause);
    return 0;
}

impl do_raise(tstate: ptr, exc_in: ptr[PyObject], cause: ptr[PyObject]) -> i32 {
    ts = ptr[PyThreadState](tstate);
    exc = exc_in;
    type = NULL;
    value = NULL;
    if not exc {
        exc_info = _PyErr_GetTopmostException(ts);
        exc = ptr[ptr[PyObject]](exc_info + _PyErr_StackItem_EXC_VALUE).view(1)[0];
        if exc == Py_None or not exc {
            _PyErr_SetString(
                ts, PyExc_RuntimeError, ptr[u8]("No active exception to reraise")
            );
            return 0;
        }
        object_incref(exc);
        _PyErr_SetRaisedException(ts, exc);
        return 1;
    }
    if control_exception_class_check(exc) {
        type = exc;
        value = PyObject_CallNoArgs(exc);
        if not value {
            return raise_error(value, type, cause);
        }
        if not control_exception_instance_check(value) {
            _PyErr_Format(
                ts,
                PyExc_TypeError,
                ptr[u8](
                    "calling %R should have returned an instance of BaseException, not %R"
                ),
                type,
                ptr[PyObject](object_type(value))
            );
            return raise_error(value, type, cause);
        }
    } elif control_exception_instance_check(exc) {
        value = exc;
        type = ptr[PyObject](object_type(exc));
        object_incref(type);
    } else {
        object_decref(exc);
        _PyErr_SetString(
            ts, PyExc_TypeError, ptr[u8]("exceptions must derive from BaseException")
        );
        return raise_error(value, type, cause);
    }
    if cause {
        fixed_cause = NULL;
        if control_exception_class_check(cause) {
            fixed_cause = PyObject_CallNoArgs(cause);
            if not fixed_cause {
                return raise_error(value, type, cause);
            }
            if not control_exception_instance_check(fixed_cause) {
                _PyErr_Format(
                    ts,
                    PyExc_TypeError,
                    ptr[u8](
                        "calling %R should have returned an instance of BaseException, not %R"
                    ),
                    cause,
                    ptr[PyObject](object_type(fixed_cause))
                );
                object_decref(fixed_cause);
                return raise_error(value, type, cause);
            }
            object_decref(cause);
        } elif control_exception_instance_check(cause) {
            fixed_cause = cause;
        } elif cause == Py_None {
            object_decref(cause);
            fixed_cause = NULL;
        } else {
            _PyErr_SetString(
                ts,
                PyExc_TypeError,
                ptr[u8]("exception causes must derive from BaseException")
            );
            return raise_error(value, type, cause);
        }
        PyException_SetCause(value, fixed_cause);
    }
    _PyErr_SetObject(ts, type, value);
    object_decref(value);
    object_decref(type);
    return 0;
}

impl CHECK_EG_MATCH(
    tstate: ptr,
    frame: ptr[u8],
    exc_value_st: u64,
    match_type_st: u64,
    rest: ptr[u64],
    matched: ptr[u64]
) -> i32 {
    exc_value = sr_borrow(exc_value_st);
    match_type = sr_borrow(match_type_st);
    if _PyEval_CheckExceptStarTypeValid(ptr[PyThreadState](tstate), match_type) < 0 {
        return ST_ERROR;
    }
    match_o = NULL;
    rest_o = NULL;
    res = _PyEval_ExceptionGroupMatch(
        frame, exc_value, match_type, &mut match_o, &mut rest_o
    );
    if res < 0 {
        return ST_ERROR;
    }
    if not match_o {
        return ST_ERROR;
    }
    if match_o != Py_None {
        PyErr_SetHandledException(match_o);
    }
    rest.view(1)[0] = sr_steal(rest_o);
    matched.view(1)[0] = sr_steal(match_o);
    return ST_OK;
}

impl CHECK_EXC_MATCH(tstate: ptr, left: u64, right: u64) -> u64 {
    left_o = sr_borrow(left);
    right_o = sr_borrow(right);
    if _PyEval_CheckExceptTypeValid(ptr[PyThreadState](tstate), right_o) < 0 {
        return u64(0);
    }
    if PyErr_GivenExceptionMatches(left_o, right_o) != 0 {
        return sr_true();
    }
    return sr_false();
}

impl POP_EXCEPT(tstate: ptr, exc_value: u64) {
    slot = control_exc_value_slot(tstate);
    value = NULL;
    if not sr_is_none(exc_value) {
        value = sr_as_steal(exc_value);
    }
    old = slot.view(1)[0];
    slot.view(1)[0] = value;
    object_xdecref(old);
}

impl PUSH_EXC_INFO(tstate: ptr, exc: u64, prev_exc: ptr[u64], new_exc: ptr[u64]) {
    slot = control_exc_value_slot(tstate);
    value = slot.view(1)[0];
    if value {
        prev_exc.view(1)[0] = sr_steal(value);
    } else {
        prev_exc.view(1)[0] = sr_none();
    }
    slot.view(1)[0] = object_new_ref(sr_borrow(exc));
    new_exc.view(1)[0] = exc;
}

impl RAISE_VARARGS(
    tstate: ptr, frame: ptr[u8], this_instr: ptr[u16], oparg: i32, args: ptr[u64]
) -> i32 {
    cause = NULL;
    exc = NULL;
    if oparg == 2 {
        cause = sr_as_steal((args + 1).view(1)[0]);
    }
    if oparg > 0 {
        exc = sr_as_steal(args.view(1)[0]);
    }
    if do_raise(tstate, exc, cause) != 0 {
        monitor_reraise(tstate, frame, this_instr);
        return ST_UNWIND;
    }
    return ST_ERROR;
}

impl RERAISE(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    oparg: i32,
    values: ptr[u64],
    exc_st: u64
) -> i32 {
    exc = sr_as_steal(exc_st);
    if oparg != 0 {
        frame_set_instr_ptr(
            frame, control_bytecode(frame) + sr_untag_int(values.view(1)[0])
        );
    }
    _PyErr_SetRaisedException(ptr[PyThreadState](tstate), exc);
    monitor_reraise(tstate, frame, this_instr);
    return ST_UNWIND;
}

impl WITH_EXCEPT_START(exit_func: u64, exit_self: u64, val: u64) -> u64 {
    val_o = sr_borrow(val);
    exit_func_o = sr_borrow(exit_func);
    exc = ptr[PyObject](object_type(val_o));
    original_tb = PyException_GetTraceback(val_o);
    tb = original_tb;
    if not tb {
        tb = Py_None;
    }
    slots: own ControlStack = ControlStack();
    stack = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    stack.view(5)[0] = NULL;
    stack.view(5)[1] = sr_borrow(exit_self);
    stack.view(5)[2] = exc;
    stack.view(5)[3] = val_o;
    stack.view(5)[4] = tb;
    has_self: i64 = 0;
    if not sr_is_null(exit_self) {
        has_self = 1;
    }
    res_o = PyObject_Vectorcall(
        exit_func_o,
        stack + (2 - has_self),
        u64(3 + has_self) | PY_VECTORCALL_ARGUMENTS_OFFSET,
        NULL
    );
    object_xdecref(original_tb);
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl JUMP_BACKWARD_NO_INTERRUPT(oparg: i32) -> i64 {
    return -i64(oparg);
}

impl _SPECIALIZE_JUMP_BACKWARD(tstate: ptr, this_instr: ptr[u16]) -> i32 {
    if control_opcode(this_instr) == JUMP_BACKWARD {
        jit = (tstate_interp(tstate) + PyInterpreterState_JIT).view(1)[0];
        if jit != u8(0) {
            control_set_opcode(this_instr, JUMP_BACKWARD_JIT);
        } else {
            control_set_opcode(this_instr, JUMP_BACKWARD_NO_JIT);
        }
        return ST_REDISPATCH;
    }
    return ST_OK;
}

impl _MAYBE_INSTRUMENT(tstate: ptr, frame: ptr[u8]) -> i32 {
    tracing = ptr[i32](ptr[u8](tstate) + PyThreadState_TRACING).view(1)[0];
    if tracing == 0 {
        breaker = __atomic_load_i64(
            int(ptr[u8](tstate) + PyThreadState_EVAL_BREAKER), 0
        );
        global_version = u64.wrap(breaker) & ~_PY_EVAL_EVENTS_MASK;
        code = frame_code(frame);
        code_version = ptr[u64](code + PyCodeObject_INSTRUMENTATION_VERSION).view(1)[0];
        if code_version != global_version {
            if _Py_Instrument(code, tstate_interp(tstate)) != 0 {
                return ST_ERROR;
            }
            return ST_REDISPATCH;
        }
    }
    return ST_OK;
}

impl _QUICKEN_RESUME(tstate: ptr, this_instr: ptr[u16]) {
    tracing = ptr[i32](ptr[u8](tstate) + PyThreadState_TRACING).view(1)[0];
    if tracing == 0 and control_opcode(this_instr) == RESUME {
        control_set_opcode(this_instr, CONTROL_OPCODE_RESUME_CHECK);
    }
}

impl RESUME_CHECK(tstate: ptr, frame: ptr[u8]) -> bool {
    breaker = __atomic_load_i64(int(ptr[u8](tstate) + PyThreadState_EVAL_BREAKER), 0);
    version = ptr[u64](frame_code(frame) + PyCodeObject_INSTRUMENTATION_VERSION).view(1)[
        0
    ];
    return u64.wrap(breaker) == version;
}
