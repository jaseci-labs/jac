import from c {
    glob _PyOpcode_Caches: u8,
         _PyInstrumentation_MISSING: PyObject; def _Py_call_instrumentation(
        tstate: ptr[PyThreadState], event: i32, frame: ptr[u8], instr: ptr[u16]
    ) -> i32;  def _Py_call_instrumentation_arg(
        tstate: ptr[PyThreadState],
        event: i32,
        frame: ptr[u8],
        instr: ptr[u16],
        arg: ptr[PyObject]
    ) -> i32;  def _Py_call_instrumentation_2args(
        tstate: ptr[PyThreadState],
        event: i32,
        frame: ptr[u8],
        instr: ptr[u16],
        arg0: ptr[PyObject],
        arg1: ptr[PyObject]
    ) -> i32;  def _Py_call_instrumentation_jump(
        instr: ptr[u16],
        tstate: ptr[PyThreadState],
        event: i32,
        frame: ptr[u8],
        src: ptr[u16],
        dest: ptr[u16]
    ) -> ptr[u16];  def _Py_call_instrumentation_line(
        tstate: ptr[PyThreadState], frame: ptr[u8], instr: ptr[u16], prev: ptr[u16]
    ) -> i32;  def _Py_call_instrumentation_instruction(
        tstate: ptr[PyThreadState], frame: ptr[u8], instr: ptr[u16]
    ) -> i32;  def _PyEval_MonitorRaise(
        tstate: ptr[PyThreadState], frame: ptr[u8], instr: ptr[u16]
    );  @__preserve_none
    def _TAIL_CALL_error(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_exception_unwind(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_END_FOR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        next_instr = next_instr + 1;
        value = (stack_pointer - 1).view(1)[0];
        receiver = (stack_pointer - 2).view(1)[0];
        if instrumented_gen_check(sr_borrow(receiver)) {
            frame_set_stackpointer(frame, stack_pointer);
            err = instrumented_monitor_stop_iteration(
                tstate, frame, this_instr, sr_borrow(value)
            );
            stack_pointer = frame_stackpointer(frame);
            if err != 0 {
                return tail _TAIL_CALL_error(
                    frame, stack_pointer, tstate, next_instr, oparg
                );
            }
        }
        stack_pointer = stack_pointer - 1;
        frame_set_stackpointer(frame, stack_pointer);
        sr_close(value);
        stack_pointer = frame_stackpointer(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_POP_ITER(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        prev_instr = frame_instr_ptr(frame);
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        iter = (stack_pointer - 1).view(1)[0];
        dest = this_instr + 1;
        target = instrumented_jump(
            tstate,
            frame,
            stack_pointer,
            this_instr,
            prev_instr,
            dest,
            PY_MONITORING_EVENT_BRANCH_RIGHT
        );
        stack_pointer = frame_stackpointer(frame);
        if not target {
            return tail _TAIL_CALL_error(frame, stack_pointer, tstate, dest + 1, oparg);
        }
        next_instr = target;
        stack_pointer = stack_pointer - 1;
        frame_set_stackpointer(frame, stack_pointer);
        sr_close(iter);
        stack_pointer = frame_stackpointer(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_FOR_ITER(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        iter = (stack_pointer - 1).view(1)[0];
        iter_o = sr_borrow(iter);
        if int(object_type(iter_o).view(1)[0].tp_iternext) == 0 {
            frame_set_stackpointer(frame, stack_pointer);
            instrumented_not_an_iterator(iter_o);
            stack_pointer = frame_stackpointer(frame);
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, stack_pointer);
        next_o = object_type(iter_o).view(1)[0].tp_iternext(iter_o);
        stack_pointer = frame_stackpointer(frame);
        if next_o {
            next = sr_steal(next_o);
            dest = next_instr;
            target = instrumented_jump(
                tstate,
                frame,
                stack_pointer,
                this_instr,
                this_instr,
                dest,
                PY_MONITORING_EVENT_BRANCH_LEFT
            );
            stack_pointer = frame_stackpointer(frame);
            if not target {
                return tail _TAIL_CALL_error(
                    frame, stack_pointer, tstate, dest + 1, oparg
                );
            }
            next_instr = target;
            stack_pointer.view(1)[0] = next;
            stack_pointer = stack_pointer + 1;
            slot = next_handler(next_instr);
            return tail slot.view(1)[0].handler(
                frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
            );
        }
        if instrumented_exception_raised(tstate) {
            frame_set_stackpointer(frame, stack_pointer);
            matches = PyErr_ExceptionMatches(PyExc_StopIteration);
            stack_pointer = frame_stackpointer(frame);
            if matches == 0 {
                return tail _TAIL_CALL_error(
                    frame, stack_pointer, tstate, next_instr, oparg
                );
            }
            frame_set_stackpointer(frame, stack_pointer);
            _PyEval_MonitorRaise(ptr[PyThreadState](tstate), frame, this_instr);
            PyErr_Clear();
            stack_pointer = frame_stackpointer(frame);
        }
        next_instr = next_instr + (i64(oparg) + 1);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_END_ASYNC_FOR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        dest = this_instr + 1;
        target = instrumented_jump(
            tstate,
            frame,
            stack_pointer,
            this_instr,
            next_instr + (-i64(oparg)),
            dest,
            PY_MONITORING_EVENT_BRANCH_RIGHT
        );
        stack_pointer = frame_stackpointer(frame);
        if not target {
            return tail _TAIL_CALL_error(frame, stack_pointer, tstate, dest + 1, oparg);
        }
        next_instr = target;
        exc_st = (stack_pointer - 1).view(1)[0];
        awaitable_st = (stack_pointer - 2).view(1)[0];
        exc = sr_borrow(exc_st);
        frame_set_stackpointer(frame, stack_pointer);
        matches = PyErr_GivenExceptionMatches(exc, PyExc_StopAsyncIteration);
        stack_pointer = frame_stackpointer(frame);
        if matches != 0 {
            frame_set_stackpointer(frame, stack_pointer);
            (stack_pointer - 1).view(1)[0] = SR_NULL;
            sr_close(exc_st);
            (stack_pointer - 2).view(1)[0] = SR_NULL;
            sr_close(awaitable_st);
            stack_pointer = frame_stackpointer(frame);
            stack_pointer = stack_pointer - 2;
            slot = next_handler(next_instr);
            return tail slot.view(1)[0].handler(
                frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
            );
        }
        object_incref(exc);
        frame_set_stackpointer(frame, stack_pointer);
        PyErr_SetRaisedException(exc);
        instrumented_monitor_reraise(tstate, frame, this_instr);
        return tail _TAIL_CALL_exception_unwind(
            frame, stack_pointer, tstate, next_instr, oparg
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_LINE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        prev_instr = frame_instr_ptr(frame);
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        original_opcode: i32 = 0;
        if instrumented_tracing(tstate) {
            original_opcode = instrumented_line_original_opcode(frame, this_instr);
            next_instr = this_instr;
        } else {
            frame_set_stackpointer(frame, stack_pointer);
            original_opcode = _Py_call_instrumentation_line(
                ptr[PyThreadState](tstate), frame, this_instr, prev_instr
            );
            stack_pointer = frame_stackpointer(frame);
            if original_opcode < 0 {
                return tail _TAIL_CALL_error(
                    frame, stack_pointer, tstate, this_instr + 1, oparg
                );
            }
            next_instr = frame_instr_ptr(frame);
            if next_instr != this_instr {
                slot = next_handler(next_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
                );
            }
        }
        instrumented_pause_counter(next_instr, original_opcode);
        handler = ptr[HandlerSlot](addressof(INSTRUCTION_TABLE)) + i64(original_opcode);
        return tail handler.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, oparg
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_INSTRUCTION(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        frame_set_stackpointer(frame, stack_pointer);
        next_opcode = _Py_call_instrumentation_instruction(
            ptr[PyThreadState](tstate), frame, this_instr
        );
        stack_pointer = frame_stackpointer(frame);
        if next_opcode < 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        next_instr = this_instr;
        instrumented_pause_counter(next_instr, next_opcode);
        handler = ptr[HandlerSlot](addressof(INSTRUCTION_TABLE)) + i64(next_opcode);
        return tail handler.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, oparg
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_JUMP_FORWARD(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        dest = next_instr + i64(oparg);
        target = instrumented_jump(
            tstate,
            frame,
            stack_pointer,
            this_instr,
            this_instr,
            dest,
            PY_MONITORING_EVENT_JUMP
        );
        stack_pointer = frame_stackpointer(frame);
        if not target {
            return tail _TAIL_CALL_error(frame, stack_pointer, tstate, dest + 1, oparg);
        }
        next_instr = target;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_JUMP_BACKWARD(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        frame_set_stackpointer(frame, stack_pointer);
        if eval_breaker_check(tstate) != ST_OK {
            stack_pointer = frame_stackpointer(frame);
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        stack_pointer = frame_stackpointer(frame);
        dest = next_instr + (-i64(oparg));
        target = instrumented_jump(
            tstate,
            frame,
            stack_pointer,
            this_instr,
            this_instr,
            dest,
            PY_MONITORING_EVENT_JUMP
        );
        stack_pointer = frame_stackpointer(frame);
        if not target {
            return tail _TAIL_CALL_error(frame, stack_pointer, tstate, dest + 1, oparg);
        }
        next_instr = target;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_NOT_TAKEN(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        prev_instr = frame_instr_ptr(frame);
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        dest = next_instr;
        target = instrumented_jump(
            tstate,
            frame,
            stack_pointer,
            this_instr,
            prev_instr,
            dest,
            PY_MONITORING_EVENT_BRANCH_LEFT
        );
        stack_pointer = frame_stackpointer(frame);
        if not target {
            return tail _TAIL_CALL_error(frame, stack_pointer, tstate, dest + 1, oparg);
        }
        next_instr = target;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_POP_JUMP_IF_TRUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        jump = sr_is_true((stack_pointer - 1).view(1)[0]);
        instrumented_record_branch(this_instr, jump);
        if jump {
            dest = next_instr + i64(oparg);
            target = instrumented_jump(
                tstate,
                frame,
                stack_pointer,
                this_instr,
                this_instr,
                dest,
                PY_MONITORING_EVENT_BRANCH_RIGHT
            );
            stack_pointer = frame_stackpointer(frame);
            if not target {
                return tail _TAIL_CALL_error(
                    frame, stack_pointer, tstate, dest + 1, oparg
                );
            }
            next_instr = target;
        }
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_POP_JUMP_IF_FALSE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        jump = sr_is_false((stack_pointer - 1).view(1)[0]);
        instrumented_record_branch(this_instr, jump);
        if jump {
            dest = next_instr + i64(oparg);
            target = instrumented_jump(
                tstate,
                frame,
                stack_pointer,
                this_instr,
                this_instr,
                dest,
                PY_MONITORING_EVENT_BRANCH_RIGHT
            );
            stack_pointer = frame_stackpointer(frame);
            if not target {
                return tail _TAIL_CALL_error(
                    frame, stack_pointer, tstate, dest + 1, oparg
                );
            }
            next_instr = target;
        }
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_POP_JUMP_IF_NONE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        value = (stack_pointer - 1).view(1)[0];
        jump = sr_is_none(value);
        instrumented_record_branch(this_instr, jump);
        if jump {
            dest = next_instr + i64(oparg);
            target = instrumented_jump(
                tstate,
                frame,
                stack_pointer,
                this_instr,
                this_instr,
                dest,
                PY_MONITORING_EVENT_BRANCH_RIGHT
            );
            stack_pointer = frame_stackpointer(frame);
            if not target {
                return tail _TAIL_CALL_error(
                    frame, stack_pointer, tstate, dest + 1, oparg
                );
            }
            next_instr = target;
        } else {
            stack_pointer = stack_pointer - 1;
            frame_set_stackpointer(frame, stack_pointer);
            sr_close(value);
            stack_pointer = frame_stackpointer(frame);
            stack_pointer = stack_pointer + 1;
        }
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_POP_JUMP_IF_NOT_NONE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        value = (stack_pointer - 1).view(1)[0];
        jump = not sr_is_none(value);
        instrumented_record_branch(this_instr, jump);
        if jump {
            stack_pointer = stack_pointer - 1;
            frame_set_stackpointer(frame, stack_pointer);
            sr_close(value);
            stack_pointer = frame_stackpointer(frame);
            dest = next_instr + i64(oparg);
            target = instrumented_jump(
                tstate,
                frame,
                stack_pointer,
                this_instr,
                this_instr,
                dest,
                PY_MONITORING_EVENT_BRANCH_RIGHT
            );
            stack_pointer = frame_stackpointer(frame);
            if not target {
                return tail _TAIL_CALL_error(
                    frame, stack_pointer, tstate, dest + 1, oparg
                );
            }
            next_instr = target;
        } else {
            stack_pointer = stack_pointer - 1;
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }
}

def instrumented_tracing(tstate: ptr) -> bool;

def instrumented_exception_raised(tstate: ptr) -> bool;

def instrumented_code_flags(frame: ptr[u8]) -> i32;

def instrumented_monitoring_data(frame: ptr[u8]) -> ptr[u8];

def instrumented_jump(
    tstate: ptr,
    frame: ptr[u8],
    stack_pointer: ptr[u64],
    this_instr: ptr[u16],
    src: ptr[u16],
    dest: ptr[u16],
    event: i32
) -> ptr[u16];

def instrumented_record_branch(this_instr: ptr[u16], taken: bool);

def instrumented_pause_counter(instr: ptr[u16], opcode: i32);

def instrumented_line_original_opcode(frame: ptr[u8], this_instr: ptr[u16]) -> i32;

def instrumented_not_an_iterator(iter_o: ptr[PyObject]);

def instrumented_gen_check(op: ptr[PyObject]) -> bool;

def instrumented_no_tools_for_global_event(tstate: ptr, event: i32) -> bool;

def instrumented_no_tools_for_local_event(
    tstate: ptr, frame: ptr[u8], event: i32
) -> bool;

def instrumented_do_monitor_exc(
    tstate: ptr, frame: ptr[u8], instr: ptr[u16], event: i32
) -> i32;

def instrumented_monitor_reraise(tstate: ptr, frame: ptr[u8], instr: ptr[u16]);

def instrumented_monitor_stop_iteration(
    tstate: ptr, frame: ptr[u8], instr: ptr[u16], value: ptr[PyObject]
) -> i32;

def _MONITOR_RESUME(
    tstate: ptr, frame: ptr[u8], oparg: i32, this_instr: ptr[u16]
) -> i32;

def _RETURN_VALUE_EVENT(
    tstate: ptr, frame: ptr[u8], this_instr: ptr[u16], val: u64
) -> i32;

def _YIELD_VALUE_EVENT(
    tstate: ptr, frame: ptr[u8], this_instr: ptr[u16], val: u64
) -> i32;

def _MONITOR_CALL(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    oparg: i32,
    func: u64,
    maybe_self: u64,
    args: ptr[u64]
) -> i32;

def _MONITOR_CALL_KW(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    callable: u64,
    self_or_null: u64,
    args: ptr[u64]
) -> i32;

def INSTRUMENTED_END_SEND(
    tstate: ptr, frame: ptr[u8], this_instr: ptr[u16], receiver: u64, value: u64
) -> u64;

impl instrumented_tracing(tstate: ptr) -> bool {
    return ptr[i32](ptr[u8](tstate) + PyThreadState_TRACING).view(1)[0] != 0;
}

impl instrumented_exception_raised(tstate: ptr) -> bool {
    return bool(
        ptr[ptr[PyObject]](ptr[u8](tstate) + PyThreadState_CURRENT_EXCEPTION).view(1)[0]
    );
}

impl instrumented_code_flags(frame: ptr[u8]) -> i32 {
    return ptr[i32](frame_code(frame) + PyCodeObject_FLAGS).view(1)[0];
}

impl instrumented_monitoring_data(frame: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](frame_code(frame) + PyCodeObject_MONITORING).view(1)[0];
}

impl instrumented_jump(
    tstate: ptr,
    frame: ptr[u8],
    stack_pointer: ptr[u64],
    this_instr: ptr[u16],
    src: ptr[u16],
    dest: ptr[u16],
    event: i32
) -> ptr[u16] {
    frame_set_stackpointer(frame, stack_pointer);
    if instrumented_tracing(tstate) {
        return dest;
    }
    return _Py_call_instrumentation_jump(
        this_instr, ptr[PyThreadState](tstate), event, frame, src, dest
    );
}

impl instrumented_record_branch(this_instr: ptr[u16], taken: bool) {
    cache = this_instr + 1;
    bit: i64 = 0;
    if taken {
        bit = 1;
    }
    cache.view(1)[0] = u16.wrap((i64(cache.view(1)[0]) << 1) | bit);
}

impl instrumented_pause_counter(instr: ptr[u16], opcode: i32) {
    if (addressof(_PyOpcode_Caches) + i64(opcode)).view(1)[0] != u8(0) {
        counter = instr + 1;
        counter.view(1)[0] = counter.view(1)[0] | u16(16);
    }
}

impl instrumented_line_original_opcode(frame: ptr[u8], this_instr: ptr[u16]) -> i32 {
    bytecode = frame_code(frame) + PyCodeObject_CODE_ADAPTIVE;
    index = i64((int(this_instr) - int(bytecode)) // 2);
    lines = ptr[ptr[u8]](
        instrumented_monitoring_data(frame) + _PyCoMonitoringData_LINES
    ).view(
        1
    )[0];
    per_entry = i64((lines + _PyCoLineInstrumentationData_BYTES_PER_ENTRY).view(1)[0]);
    return i32(
        (lines + _PyCoLineInstrumentationData_DATA + index * per_entry).view(1)[0]
    );
}

impl instrumented_not_an_iterator(iter_o: ptr[PyObject]) {
    PyErr_Format(
        PyExc_TypeError,
        ptr[u8]("'%.100s' object is not an iterator"),
        object_type(iter_o).view(1)[0].tp_name
    );
}

impl instrumented_gen_check(op: ptr[PyObject]) -> bool {
    return object_type_check(op, ptr[PyTypeObject](addressof(PyGen_Type)));
}

impl instrumented_no_tools_for_global_event(tstate: ptr, event: i32) -> bool {
    return (tstate_interp(tstate) + PyInterpreterState_MONITORS + i64(event)).view(1)[0]
        == u8(0);
}

impl instrumented_no_tools_for_local_event(
    tstate: ptr, frame: ptr[u8], event: i32
) -> bool {
    data = instrumented_monitoring_data(frame);
    if data {
        return (data + _PyCoMonitoringData_ACTIVE_MONITORS + i64(event)).view(1)[0]
            == u8(0);
    }
    return instrumented_no_tools_for_global_event(tstate, event);
}

impl instrumented_do_monitor_exc(
    tstate: ptr, frame: ptr[u8], instr: ptr[u16], event: i32
) -> i32 {
    if (instrumented_code_flags(frame) & CO_NO_MONITORING_EVENTS) != 0 {
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

impl instrumented_monitor_reraise(tstate: ptr, frame: ptr[u8], instr: ptr[u16]) {
    if instrumented_no_tools_for_global_event(tstate, PY_MONITORING_EVENT_RERAISE) {
        return;
    }
    instrumented_do_monitor_exc(tstate, frame, instr, PY_MONITORING_EVENT_RERAISE);
}

impl instrumented_monitor_stop_iteration(
    tstate: ptr, frame: ptr[u8], instr: ptr[u16], value: ptr[PyObject]
) -> i32 {
    if instrumented_no_tools_for_local_event(
        tstate, frame, PY_MONITORING_EVENT_STOP_ITERATION
    ) {
        return 0;
    }
    PyErr_SetObject(PyExc_StopIteration, value);
    res = instrumented_do_monitor_exc(
        tstate, frame, instr, PY_MONITORING_EVENT_STOP_ITERATION
    );
    if res < 0 {
        return res;
    }
    PyErr_SetRaisedException(NULL);
    return 0;
}

impl _MONITOR_RESUME(
    tstate: ptr, frame: ptr[u8], oparg: i32, this_instr: ptr[u16]
) -> i32 {
    event: i32 = 0;
    if oparg > 0 {
        event = 1;
    }
    err = _Py_call_instrumentation(
        ptr[PyThreadState](tstate), event, frame, this_instr
    );
    if err != 0 {
        return ST_ERROR;
    }
    if frame_instr_ptr(frame) != this_instr {
        return ST_RESUME_AT;
    }
    return ST_OK;
}

impl _RETURN_VALUE_EVENT(
    tstate: ptr, frame: ptr[u8], this_instr: ptr[u16], val: u64
) -> i32 {
    err = _Py_call_instrumentation_arg(
        ptr[PyThreadState](tstate),
        PY_MONITORING_EVENT_PY_RETURN,
        frame,
        this_instr,
        sr_borrow(val)
    );
    if err != 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl _YIELD_VALUE_EVENT(
    tstate: ptr, frame: ptr[u8], this_instr: ptr[u16], val: u64
) -> i32 {
    err = _Py_call_instrumentation_arg(
        ptr[PyThreadState](tstate),
        PY_MONITORING_EVENT_PY_YIELD,
        frame,
        this_instr,
        sr_borrow(val)
    );
    if err != 0 {
        return ST_ERROR;
    }
    if frame_instr_ptr(frame) != this_instr {
        return ST_RESUME_AT;
    }
    return ST_OK;
}

impl _MONITOR_CALL(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    oparg: i32,
    func: u64,
    maybe_self: u64,
    args: ptr[u64]
) -> i32 {
    function = sr_borrow(func);
    arg0 = ptr[PyObject](addressof(_PyInstrumentation_MISSING));
    if not sr_is_null(maybe_self) {
        arg0 = sr_borrow(maybe_self);
    } elif oparg != 0 {
        arg0 = sr_borrow(args.view(1)[0]);
    }
    err = _Py_call_instrumentation_2args(
        ptr[PyThreadState](tstate),
        PY_MONITORING_EVENT_CALL,
        frame,
        this_instr,
        function,
        arg0
    );
    if err != 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl _MONITOR_CALL_KW(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    callable: u64,
    self_or_null: u64,
    args: ptr[u64]
) -> i32 {
    arg = sr_borrow(args.view(1)[0]);
    if not sr_is_null(self_or_null) {
        arg = sr_borrow(self_or_null);
    }
    function = sr_borrow(callable);
    err = _Py_call_instrumentation_2args(
        ptr[PyThreadState](tstate),
        PY_MONITORING_EVENT_CALL,
        frame,
        this_instr,
        function,
        arg
    );
    if err != 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl INSTRUMENTED_END_SEND(
    tstate: ptr, frame: ptr[u8], this_instr: ptr[u16], receiver: u64, value: u64
) -> u64 {
    receiver_o = sr_borrow(receiver);
    if instrumented_gen_check(receiver_o)
        or object_type(receiver_o) == ptr[PyTypeObject](addressof(PyCoro_Type)) {
        err = instrumented_monitor_stop_iteration(
            tstate, frame, this_instr, sr_borrow(value)
        );
        if err != 0 {
            sr_close(value);
            return u64(0);
        }
    }
    return value;
}
