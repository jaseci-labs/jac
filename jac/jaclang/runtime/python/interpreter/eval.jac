import from c {
    @__preserve_none
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
    def _TAIL_CALL_start_frame(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_NOP(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        NOP();
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_NOT_TAKEN(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        NOT_TAKEN();
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_POP_TOP(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_PUSH_NULL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = PUSH_NULL();
        stack_pointer.view(1)[0] = v1;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_FAST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = LOAD_FAST(frame, oparg);
        stack_pointer.view(1)[0] = v1;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_FAST_BORROW(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = LOAD_FAST_BORROW(frame, oparg);
        stack_pointer.view(1)[0] = v1;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_FAST_AND_CLEAR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = LOAD_FAST_AND_CLEAR(frame, oparg);
        stack_pointer.view(1)[0] = v1;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_FAST_LOAD_FAST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        LOAD_FAST_LOAD_FAST(frame, oparg, stack_pointer, (stack_pointer + 1));
        stack_pointer = stack_pointer + 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_FAST_BORROW_LOAD_FAST_BORROW(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        LOAD_FAST_BORROW_LOAD_FAST_BORROW(
            frame, oparg, stack_pointer, (stack_pointer + 1)
        );
        stack_pointer = stack_pointer + 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_CONST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = LOAD_CONST(frame, oparg, this_instr);
        stack_pointer.view(1)[0] = v1;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_CONST_MORTAL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = LOAD_CONST_MORTAL(frame, oparg);
        stack_pointer.view(1)[0] = v1;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_CONST_IMMORTAL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = LOAD_CONST_IMMORTAL(frame, oparg);
        stack_pointer.view(1)[0] = v1;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_SMALL_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = LOAD_SMALL_INT(oparg);
        stack_pointer.view(1)[0] = v1;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_STORE_FAST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        STORE_FAST(frame, oparg, v1);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_STORE_FAST_LOAD_FAST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        v2 = STORE_FAST_LOAD_FAST(frame, oparg, v1);
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_STORE_FAST_STORE_FAST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 2));
        STORE_FAST_STORE_FAST(frame, oparg, v1, v2);
        stack_pointer = stack_pointer - 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_COPY(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = stack_pointer + (-i64(oparg));
        v2 = COPY(v1);
        stack_pointer.view(1)[0] = v2;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_SWAP(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = stack_pointer + (-i64(oparg));
        SWAP(v1, oparg);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_UNARY_NOT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        v2 = UNARY_NOT(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_JUMP_FORWARD(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        next_instr = next_instr + JUMP_FORWARD(oparg);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_FAST_CHECK(
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
        v1 = LOAD_FAST_CHECK(frame, tstate, oparg);
        if v1 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        stack_pointer.view(1)[0] = v1;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_DELETE_FAST(
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
        v1 = DELETE_FAST(frame, tstate, oparg);
        if v1 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_COMMON_CONSTANT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = LOAD_COMMON_CONSTANT(tstate, oparg);
        stack_pointer.view(1)[0] = v1;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_STORE_NAME(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = STORE_NAME(frame, oparg, v1);
        if v2 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_DELETE_NAME(
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
        v1 = DELETE_NAME(frame, tstate, oparg);
        if v1 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_STORE_GLOBAL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = STORE_GLOBAL(frame, oparg, v1);
        if v2 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_DELETE_GLOBAL(
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
        v1 = DELETE_GLOBAL(frame, tstate, oparg);
        if v1 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_LOCALS(
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
        v1 = LOAD_LOCALS(frame);
        if v1 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        stack_pointer.view(1)[0] = v1;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_FROM_DICT_OR_GLOBALS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        v2 = LOAD_FROM_DICT_OR_GLOBALS(frame, tstate, oparg, v1);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 1), tstate, next_instr, oparg
            );
        }
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_NAME(
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
        v1 = LOAD_NAME(frame, tstate, oparg);
        if v1 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        stack_pointer.view(1)[0] = v1;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_MAKE_CELL(
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
        v1 = MAKE_CELL(frame, oparg);
        if v1 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_DELETE_DEREF(
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
        v1 = DELETE_DEREF(frame, tstate, oparg);
        if v1 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_FROM_DICT_OR_DEREF(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = LOAD_FROM_DICT_OR_DEREF(frame, tstate, oparg, v1);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_DEREF(
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
        v1 = LOAD_DEREF(frame, tstate, oparg);
        if v1 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        stack_pointer.view(1)[0] = v1;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_STORE_DEREF(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        STORE_DEREF(frame, oparg, v1);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_COPY_FREE_VARS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        COPY_FREE_VARS(frame, oparg);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_SETUP_ANNOTATIONS(
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
        v1 = SETUP_ANNOTATIONS(frame);
        if v1 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_IMPORT_NAME(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = IMPORT_NAME(frame, tstate, oparg, v1, v2);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v2);
        sr_close(v1);
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_IMPORT_FROM(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = IMPORT_FROM(frame, tstate, oparg, v1);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        stack_pointer.view(1)[0] = v2;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BUILD_TUPLE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = stack_pointer + (-i64(oparg));
        v2 = BUILD_TUPLE(v1, oparg);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer + (-i64(oparg))), tstate, next_instr, oparg
            );
        }
        (stack_pointer + (-i64(oparg))).view(1)[0] = v2;
        stack_pointer = stack_pointer + (1 - i64(oparg));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BUILD_LIST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, (stack_pointer + (-i64(oparg))));
        v2 = BUILD_LIST(v1, oparg);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer + (-i64(oparg))), tstate, next_instr, oparg
            );
        }
        (stack_pointer + (-i64(oparg))).view(1)[0] = v2;
        stack_pointer = stack_pointer + (1 - i64(oparg));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BUILD_SET(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, (stack_pointer + (-i64(oparg))));
        v2 = BUILD_SET(v1, oparg);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer + (-i64(oparg))), tstate, next_instr, oparg
            );
        }
        (stack_pointer + (-i64(oparg))).view(1)[0] = v2;
        stack_pointer = stack_pointer + (1 - i64(oparg));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BUILD_MAP(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = stack_pointer + (-i64(oparg * 2));
        frame_set_stackpointer(frame, stack_pointer);
        v2 = BUILD_MAP(v1, oparg);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-i64(oparg * 2))));
        for v3 in range(i64(oparg * 2)) {
            sr_close((v1 + v3).view(1)[0]);
        }
        (stack_pointer + (-i64(oparg * 2))).view(1)[0] = v2;
        stack_pointer = stack_pointer + (1 - i64(oparg * 2));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BUILD_STRING(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = stack_pointer + (-i64(oparg));
        v2 = BUILD_STRING(v1, oparg);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-i64(oparg))));
        for v3 in range(i64(oparg)) {
            sr_close((v1 + v3).view(1)[0]);
        }
        (stack_pointer + (-i64(oparg))).view(1)[0] = v2;
        stack_pointer = stack_pointer + (1 - i64(oparg));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BUILD_SLICE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = stack_pointer + (-i64(oparg));
        v2 = BUILD_SLICE(v1, oparg);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-i64(oparg))));
        for v3 in range(i64(oparg)) {
            sr_close((v1 + v3).view(1)[0]);
        }
        (stack_pointer + (-i64(oparg))).view(1)[0] = v2;
        stack_pointer = stack_pointer + (1 - i64(oparg));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BUILD_INTERPOLATION(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer + (-2 - i64(oparg & 1))).view(1)[0];
        v2 = (stack_pointer + (-1 - i64(oparg & 1))).view(1)[0];
        v3 = stack_pointer + (-i64(oparg & 1));
        frame_set_stackpointer(frame, stack_pointer);
        v4 = BUILD_INTERPOLATION(v1, v2, v3, oparg);
        if v4 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg & 1))));
        for v5 in range(i64(oparg & 1)) {
            sr_close((v3 + v5).view(1)[0]);
        }
        sr_close(v2);
        sr_close(v1);
        (stack_pointer + (-2 - i64(oparg & 1))).view(1)[0] = v4;
        stack_pointer = stack_pointer + (-1 - i64(oparg & 1));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BUILD_TEMPLATE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = BUILD_TEMPLATE(v1, v2);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v2);
        sr_close(v1);
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CONVERT_VALUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = CONVERT_VALUE(v1, oparg);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_FORMAT_SIMPLE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        v2 = FORMAT_SIMPLE(v1);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 1), tstate, next_instr, oparg
            );
        }
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_FORMAT_WITH_SPEC(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = FORMAT_WITH_SPEC(v1, v2);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v2);
        sr_close(v1);
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_GET_LEN(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = GET_LEN(v1);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        stack_pointer.view(1)[0] = v2;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LIST_APPEND(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer + (-2 - i64(oparg - 1))).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        v3 = LIST_APPEND(v1, v2);
        if v3 != 0 {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 1), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LIST_EXTEND(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer + (-2 - i64(oparg - 1))).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = LIST_EXTEND(v1, v2);
        if v3 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v2);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_SET_ADD(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer + (-2 - i64(oparg - 1))).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        v3 = SET_ADD(v1, v2);
        if v3 != 0 {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 1), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_SET_UPDATE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer + (-2 - i64(oparg - 1))).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = SET_UPDATE(v1, v2);
        if v3 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v2);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_DICT_UPDATE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer + (-2 - i64(oparg - 1))).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = DICT_UPDATE(v1, v2);
        if v3 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v2);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_DICT_MERGE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer + (-5 - i64(oparg - 1))).view(1)[0];
        v2 = (stack_pointer + (-2 - i64(oparg - 1))).view(1)[0];
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v4 = DICT_MERGE(tstate, v1, v2, v3);
        if v4 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v3);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_MAP_ADD(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer + (-3 - i64(oparg - 1))).view(1)[0];
        v2 = (stack_pointer - 2).view(1)[0];
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 2));
        v4 = MAP_ADD(v1, v2, v3);
        if v4 != 0 {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer - 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_MATCH_CLASS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 3).view(1)[0];
        v2 = (stack_pointer - 2).view(1)[0];
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v4 = MATCH_CLASS(tstate, v1, v2, v3, oparg);
        if v4 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 3));
        sr_close(v3);
        sr_close(v2);
        sr_close(v1);
        (stack_pointer - 3).view(1)[0] = v4;
        stack_pointer = stack_pointer - 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_MATCH_KEYS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = MATCH_KEYS(tstate, v1, v2);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        stack_pointer.view(1)[0] = v3;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_MATCH_MAPPING(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        v2 = MATCH_MAPPING(v1);
        stack_pointer.view(1)[0] = v2;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_MATCH_SEQUENCE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        v2 = MATCH_SEQUENCE(v1);
        stack_pointer.view(1)[0] = v2;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_UNPACK_EX(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        v2 = UNPACK_EX(tstate, v1, oparg, (stack_pointer - 1));
        if v2 != 0 {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 1), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer + (-1 + i64((oparg & 0xFF) + (oparg >> 8) + 1));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_ISINSTANCE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v2 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v3 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v4 = CALL_ISINSTANCE(
            tstate, v1, v2, v3, oparg, (stack_pointer + (-2 - i64(oparg)))
        );
        if v4 != 0 {
            if v4 == 2 {
                return tail _TAIL_CALL_CALL(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg))));
        for v5 in range(i64(oparg)) {
            sr_close((v3 + v5).view(1)[0]);
        }
        sr_close(v2);
        sr_close(v1);
        stack_pointer = stack_pointer + (-1 - i64(oparg));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_INTRINSIC_1(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = CALL_INTRINSIC_1(tstate, v1, oparg);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_INTRINSIC_2(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = CALL_INTRINSIC_2(tstate, v1, v2, oparg);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v2);
        sr_close(v1);
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_MAKE_FUNCTION(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = MAKE_FUNCTION(frame, v1);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_SET_FUNCTION_ATTRIBUTE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 2));
        v3 = SET_FUNCTION_ATTRIBUTE(v1, v2, oparg);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_BUILD_CLASS(
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
        v1 = LOAD_BUILD_CLASS(frame);
        if v1 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        stack_pointer.view(1)[0] = v1;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_EXIT_INIT_CHECK(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        v2 = EXIT_INIT_CHECK(v1);
        if v2 != 0 {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 1), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_RETURN_VALUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        frame = ptr[u8](RETURN_VALUE(tstate, frame, v1));
        stack_pointer = frame_stackpointer(frame);
        next_instr = frame_instr_ptr(frame) + frame_return_offset(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_YIELD_VALUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        frame = ptr[u8](YIELD_VALUE(tstate, frame, oparg, v1));
        stack_pointer = frame_stackpointer(frame);
        next_instr = frame_instr_ptr(frame) + 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CHECK_EG_MATCH(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = CHECK_EG_MATCH(
            tstate, frame, v1, v2, (stack_pointer - 2), (stack_pointer - 1)
        );
        if v3 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v2);
        sr_close(v1);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CHECK_EXC_MATCH(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = CHECK_EXC_MATCH(tstate, v1, v2);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v2);
        (stack_pointer - 1).view(1)[0] = v3;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_POP_EXCEPT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        POP_EXCEPT(tstate, v1);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_PUSH_EXC_INFO(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        PUSH_EXC_INFO(tstate, v1, (stack_pointer - 1), stack_pointer);
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_RAISE_VARARGS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, (stack_pointer + (-i64(oparg))));
        v2 = RAISE_VARARGS(tstate, frame, this_instr, oparg, v1);
        if v2 != 0 {
            if v2 == 4 {
                return tail _TAIL_CALL_exception_unwind(
                    frame, (stack_pointer + (-i64(oparg))), tstate, next_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, (stack_pointer + (-i64(oparg))), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer + (-i64(oparg));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_RERAISE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = stack_pointer + (-1 - i64(oparg));
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        v3 = RERAISE(tstate, frame, this_instr, oparg, v1, v2);
        if v3 != 0 {
            if v3 == 4 {
                return tail _TAIL_CALL_exception_unwind(
                    frame, (stack_pointer - 1), tstate, next_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 1), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_WITH_EXCEPT_START(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 5).view(1)[0];
        v2 = (stack_pointer - 4).view(1)[0];
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v4 = WITH_EXCEPT_START(v1, v2, v3);
        if v4 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        stack_pointer.view(1)[0] = v4;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_JUMP_BACKWARD_NO_INTERRUPT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        next_instr = next_instr + JUMP_BACKWARD_NO_INTERRUPT(oparg);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_RESUME_CHECK(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        if not RESUME_CHECK(tstate, frame) {
            return tail _TAIL_CALL_RESUME(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_UNARY_NEGATIVE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = UNARY_NEGATIVE(v1);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_UNARY_INVERT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = UNARY_INVERT(v1);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_TO_BOOL_BOOL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer - 1).view(1)[0];
        if not TO_BOOL_BOOL(v1) {
            return tail _TAIL_CALL_TO_BOOL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_TO_BOOL_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer - 1).view(1)[0];
        v2 = TO_BOOL_INT(v1, (stack_pointer - 1));
        if v2 != 0 {
            if v2 == 2 {
                return tail _TAIL_CALL_TO_BOOL(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_TO_BOOL_NONE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer - 1).view(1)[0];
        v2 = TO_BOOL_NONE(v1, (stack_pointer - 1));
        if v2 != 0 {
            if v2 == 2 {
                return tail _TAIL_CALL_TO_BOOL(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 1), tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_DELETE_SUBSCR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = DELETE_SUBSCR(v1, v2);
        if v3 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v2);
        sr_close(v1);
        stack_pointer = stack_pointer - 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_IS_OP(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        v3 = IS_OP(oparg, v1, v2);
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v2);
        sr_close(v1);
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_END_SEND(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        v3 = INSTRUMENTED_END_SEND(tstate, frame, this_instr, v1, v2);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 1), tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v1);
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_END_SEND(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        v3 = END_SEND(v2);
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v1);
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_GET_ITER(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = GET_ITER(v1);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_GET_YIELD_FROM_ITER(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = GET_YIELD_FROM_ITER(frame, v1);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_GET_AITER(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = GET_AITER(v1);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_GET_ANEXT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = GET_ANEXT(v1);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        stack_pointer.view(1)[0] = v2;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_GET_AWAITABLE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = GET_AWAITABLE(oparg, v1);
        if v2 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CLEANUP_THROW(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 3).view(1)[0];
        v2 = (stack_pointer - 2).view(1)[0];
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v4 = CLEANUP_THROW(
            tstate, frame, this_instr, v3, (stack_pointer - 3), (stack_pointer - 2)
        );
        if v4 != 0 {
            if v4 == 4 {
                return tail _TAIL_CALL_exception_unwind(
                    frame, stack_pointer, tstate, next_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 3));
        sr_close(v3);
        sr_close(v2);
        sr_close(v1);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 10;
        v1 = (stack_pointer - 1).view(1)[0];
        v2 = LOAD_ATTR_GETATTRIBUTE_OVERRIDDEN(
            ptr[u32]((this_instr + 2)).view(1)[0],
            ptr[u32]((this_instr + 4)).view(1)[0],
            ptr[u64]((this_instr + 6)).view(1)[0],
            v1,
            tstate,
            frame,
            oparg,
            this_instr,
            next_instr
        );
        if v2 != 0 {
            if v2 == 2 {
                return tail _TAIL_CALL_LOAD_ATTR(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            if v2 == 5 {
                frame_set_stackpointer(frame, (stack_pointer - 1));
                return tail _TAIL_CALL_start_frame(
                    tstate_current_frame(tstate),
                    stack_pointer,
                    tstate,
                    next_instr,
                    oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 1), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_SUPER_ATTR_ATTR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 3).view(1)[0];
        v2 = (stack_pointer - 2).view(1)[0];
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v4 = LOAD_SUPER_ATTR_ATTR(v1, v2, v3, frame, oparg, (stack_pointer - 3));
        if v4 != 0 {
            if v4 == 2 {
                return tail _TAIL_CALL_LOAD_SUPER_ATTR(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 3));
        sr_close(v3);
        sr_close(v2);
        sr_close(v1);
        stack_pointer = stack_pointer - 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_SUPER_ATTR_METHOD(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 3).view(1)[0];
        v2 = (stack_pointer - 2).view(1)[0];
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        v4 = LOAD_SUPER_ATTR_METHOD(
            v1, v2, v3, frame, oparg, (stack_pointer - 3), (stack_pointer - 2)
        );
        if v4 != 0 {
            if v4 == 2 {
                return tail _TAIL_CALL_LOAD_SUPER_ATTR(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 1), tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 3));
        sr_close(v2);
        sr_close(v1);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_DELETE_ATTR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = DELETE_ATTR(v1, frame, oparg);
        if v2 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BINARY_OP_MULTIPLY_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 6;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_INT(v1) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_INT(v2) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        v3 = _BINARY_OP_MULTIPLY_INT(v2, v1);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BINARY_OP_ADD_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 6;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_INT(v1) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_INT(v2) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        v3 = _BINARY_OP_ADD_INT(v2, v1);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BINARY_OP_SUBTRACT_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 6;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_INT(v1) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_INT(v2) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        v3 = _BINARY_OP_SUBTRACT_INT(v2, v1);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_POP_JUMP_IF_TRUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        next_instr = next_instr + _POP_JUMP_IF_TRUE(v1, oparg, this_instr, next_instr);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_POP_JUMP_IF_FALSE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        next_instr = next_instr + _POP_JUMP_IF_FALSE(v1, oparg, this_instr, next_instr);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_POP_JUMP_IF_NONE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        v2 = _IS_NONE(v1);
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        next_instr = next_instr + _POP_JUMP_IF_TRUE(v2, oparg, this_instr, next_instr);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_POP_JUMP_IF_NOT_NONE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        v2 = _IS_NONE(v1);
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        next_instr = next_instr + _POP_JUMP_IF_FALSE(v2, oparg, this_instr, next_instr);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_GLOBAL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 5;
        frame_set_stackpointer(frame, stack_pointer);
        v1 = _SPECIALIZE_LOAD_GLOBAL(
            frame, oparg, this_instr, (this_instr + 1).view(1)[0]
        );
        if v1 != 0 {
            if v1 == 3 {
                slot = next_handler(this_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, stack_pointer);
        v2 = _LOAD_GLOBAL(frame, oparg, stack_pointer);
        if v2 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer + 1;
        _PUSH_NULL_CONDITIONAL(oparg, stack_pointer);
        stack_pointer = stack_pointer + (i64(oparg & 1));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_GLOBAL_MODULE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 5;
        v1 = _LOAD_GLOBAL_MODULE(
            frame,
            (this_instr + 2).view(1)[0],
            (this_instr + 4).view(1)[0],
            stack_pointer
        );
        if v1 != 0 {
            if v1 == 2 {
                return tail _TAIL_CALL_LOAD_GLOBAL(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer + 1;
        _PUSH_NULL_CONDITIONAL(oparg, stack_pointer);
        stack_pointer = stack_pointer + (i64(oparg & 1));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_GLOBAL_BUILTIN(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 5;
        if not _GUARD_GLOBALS_VERSION(frame, (this_instr + 2).view(1)[0]) {
            return tail _TAIL_CALL_LOAD_GLOBAL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v1 = _LOAD_GLOBAL_BUILTINS(
            frame,
            (this_instr + 3).view(1)[0],
            (this_instr + 4).view(1)[0],
            stack_pointer
        );
        if v1 != 0 {
            if v1 == 2 {
                return tail _TAIL_CALL_LOAD_GLOBAL(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer + 1;
        _PUSH_NULL_CONDITIONAL(oparg, stack_pointer);
        stack_pointer = stack_pointer + (i64(oparg & 1));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_UNPACK_SEQUENCE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = _SPECIALIZE_UNPACK_SEQUENCE(
            (this_instr + 1).view(1)[0], v1, this_instr, oparg
        );
        if v2 != 0 {
            if v2 == 3 {
                slot = next_handler(this_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        v4 = _UNPACK_SEQUENCE(tstate, v3, oparg, (stack_pointer - 1));
        if v4 != 0 {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 1), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer + (-1 + i64(oparg));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_UNPACK_SEQUENCE_TWO_TUPLE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_TUPLE(v1) {
            return tail _TAIL_CALL_UNPACK_SEQUENCE(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = _UNPACK_SEQUENCE_TWO_TUPLE(v1, (stack_pointer - 1), stack_pointer);
        if v2 != 0 {
            if v2 == 2 {
                return tail _TAIL_CALL_UNPACK_SEQUENCE(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_UNPACK_SEQUENCE_TUPLE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_TUPLE(v1) {
            return tail _TAIL_CALL_UNPACK_SEQUENCE(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 1).view(1)[0];
        v3 = _UNPACK_SEQUENCE_TUPLE(v2, oparg, (stack_pointer - 1));
        if v3 != 0 {
            if v3 == 2 {
                return tail _TAIL_CALL_UNPACK_SEQUENCE(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v2);
        stack_pointer = stack_pointer + (-1 + i64(oparg));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_UNPACK_SEQUENCE_LIST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_LIST(v1) {
            return tail _TAIL_CALL_UNPACK_SEQUENCE(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 1).view(1)[0];
        v3 = _UNPACK_SEQUENCE_LIST(v2, oparg, (stack_pointer - 1));
        if v3 != 0 {
            if v3 == 2 {
                return tail _TAIL_CALL_UNPACK_SEQUENCE(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v2);
        stack_pointer = stack_pointer + (-1 + i64(oparg));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_TYPE_1(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_NULL(v1) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 3).view(1)[0];
        if not _GUARD_CALLABLE_TYPE_1(v2) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 3));
        v4 = _CALL_TYPE_1(v3);
        (stack_pointer - 3).view(1)[0] = v4;
        stack_pointer = stack_pointer - 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_STR_1(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_NULL(v1) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 3).view(1)[0];
        if not _GUARD_CALLABLE_STR_1(v2) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 3));
        v4 = _CALL_STR_1(v3);
        if v4 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 3), tstate, next_instr, oparg
            );
        }
        (stack_pointer - 3).view(1)[0] = v4;
        frame_set_stackpointer(frame, (stack_pointer - 2));
        v5 = _CHECK_PERIODIC(tstate);
        if v5 != 0 {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer - 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_TUPLE_1(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_NULL(v1) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 3).view(1)[0];
        if not _GUARD_CALLABLE_TUPLE_1(v2) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 3));
        v4 = _CALL_TUPLE_1(v3);
        if v4 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 3), tstate, next_instr, oparg
            );
        }
        (stack_pointer - 3).view(1)[0] = v4;
        frame_set_stackpointer(frame, (stack_pointer - 2));
        v5 = _CHECK_PERIODIC(tstate);
        if v5 != 0 {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer - 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_BUILTIN_CLASS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v2 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v3 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v4 = _CALL_BUILTIN_CLASS(
            v1, v2, v3, oparg, (stack_pointer + (-2 - i64(oparg)))
        );
        if v4 != 0 {
            if v4 == 2 {
                return tail _TAIL_CALL_CALL(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg))));
        for v5 in range(i64(oparg)) {
            sr_close((v3 + v5).view(1)[0]);
        }
        sr_close(v2);
        sr_close(v1);
        stack_pointer = stack_pointer + (-1 - i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v6 = _CHECK_PERIODIC(tstate);
        if v6 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_BUILTIN_O(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v2 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v3 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v4 = _CALL_BUILTIN_O(
            tstate, v1, v2, v3, oparg, (stack_pointer + (-2 - i64(oparg)))
        );
        if v4 != 0 {
            if v4 == 2 {
                return tail _TAIL_CALL_CALL(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg))));
        for v5 in range(i64(oparg)) {
            sr_close((v3 + v5).view(1)[0]);
        }
        sr_close(v2);
        sr_close(v1);
        stack_pointer = stack_pointer + (-1 - i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v6 = _CHECK_PERIODIC(tstate);
        if v6 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_BUILTIN_FAST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v2 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v3 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v4 = _CALL_BUILTIN_FAST(v1, v2, v3, oparg, (stack_pointer + (-2 - i64(oparg))));
        if v4 != 0 {
            if v4 == 2 {
                return tail _TAIL_CALL_CALL(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg))));
        for v5 in range(i64(oparg)) {
            sr_close((v3 + v5).view(1)[0]);
        }
        sr_close(v2);
        sr_close(v1);
        stack_pointer = stack_pointer + (-1 - i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v6 = _CHECK_PERIODIC(tstate);
        if v6 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_BUILTIN_FAST_WITH_KEYWORDS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v2 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v3 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v4 = _CALL_BUILTIN_FAST_WITH_KEYWORDS(
            v1, v2, v3, oparg, (stack_pointer + (-2 - i64(oparg)))
        );
        if v4 != 0 {
            if v4 == 2 {
                return tail _TAIL_CALL_CALL(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg))));
        for v5 in range(i64(oparg)) {
            sr_close((v3 + v5).view(1)[0]);
        }
        sr_close(v2);
        sr_close(v1);
        stack_pointer = stack_pointer + (-1 - i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v6 = _CHECK_PERIODIC(tstate);
        if v6 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_LEN(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_NULL(v1) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 3).view(1)[0];
        if not _GUARD_CALLABLE_LEN(tstate, v2) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v4 = _CALL_LEN(v3);
        if v4 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 3));
        sr_close(v3);
        sr_close(v1);
        sr_close(v2);
        (stack_pointer - 3).view(1)[0] = v4;
        stack_pointer = stack_pointer - 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_LIST_APPEND(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer - 3).view(1)[0];
        v2 = (stack_pointer - 2).view(1)[0];
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 3));
        v4 = _CALL_LIST_APPEND(tstate, v1, v2, v3);
        if v4 != 0 {
            if v4 == 2 {
                return tail _TAIL_CALL_CALL(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 3), tstate, next_instr, oparg
            );
        }
        next_instr = next_instr + _SKIP_POP_TOP();
        stack_pointer = stack_pointer - 3;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_METHOD_DESCRIPTOR_O(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v2 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v3 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v4 = _CALL_METHOD_DESCRIPTOR_O(
            tstate, v1, v2, v3, oparg, (stack_pointer + (-2 - i64(oparg)))
        );
        if v4 != 0 {
            if v4 == 2 {
                return tail _TAIL_CALL_CALL(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg))));
        for v5 in range(i64(oparg)) {
            sr_close((v3 + v5).view(1)[0]);
        }
        sr_close(v2);
        sr_close(v1);
        stack_pointer = stack_pointer + (-1 - i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v6 = _CHECK_PERIODIC(tstate);
        if v6 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v2 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v3 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v4 = _CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS(
            v1, v2, v3, oparg, (stack_pointer + (-2 - i64(oparg)))
        );
        if v4 != 0 {
            if v4 == 2 {
                return tail _TAIL_CALL_CALL(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg))));
        for v5 in range(i64(oparg)) {
            sr_close((v3 + v5).view(1)[0]);
        }
        sr_close(v2);
        sr_close(v1);
        stack_pointer = stack_pointer + (-1 - i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v6 = _CHECK_PERIODIC(tstate);
        if v6 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_METHOD_DESCRIPTOR_NOARGS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v2 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v3 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v4 = _CALL_METHOD_DESCRIPTOR_NOARGS(
            tstate, v1, v2, v3, oparg, (stack_pointer + (-2 - i64(oparg)))
        );
        if v4 != 0 {
            if v4 == 2 {
                return tail _TAIL_CALL_CALL(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg))));
        for v5 in range(i64(oparg)) {
            sr_close((v3 + v5).view(1)[0]);
        }
        sr_close(v2);
        sr_close(v1);
        stack_pointer = stack_pointer + (-1 - i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v6 = _CHECK_PERIODIC(tstate);
        if v6 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_METHOD_DESCRIPTOR_FAST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v2 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v3 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v4 = _CALL_METHOD_DESCRIPTOR_FAST(
            v1, v2, v3, oparg, (stack_pointer + (-2 - i64(oparg)))
        );
        if v4 != 0 {
            if v4 == 2 {
                return tail _TAIL_CALL_CALL(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg))));
        for v5 in range(i64(oparg)) {
            sr_close((v3 + v5).view(1)[0]);
        }
        sr_close(v2);
        sr_close(v1);
        stack_pointer = stack_pointer + (-1 - i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v6 = _CHECK_PERIODIC(tstate);
        if v6 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v2 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _SPECIALIZE_CALL(this_instr, oparg, (this_instr + 1).view(1)[0], v1, v2);
        if v3 != 0 {
            if v3 == 3 {
                slot = next_handler(this_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        v4 = stack_pointer + (-i64(oparg) - i64(2));
        frame_set_stackpointer(frame, stack_pointer);
        _MAYBE_EXPAND_METHOD(v4);
        v5 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v6 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v7 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v8 = _DO_CALL(
            tstate,
            frame,
            this_instr,
            next_instr,
            oparg,
            v5,
            v6,
            v7,
            (stack_pointer + (-2 - i64(oparg)))
        );
        if v8 != 0 {
            if v8 == 5 {
                frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg))));
                return tail _TAIL_CALL_start_frame(
                    tstate_current_frame(tstate),
                    stack_pointer,
                    tstate,
                    next_instr,
                    oparg
                );
            }
            if v8 == 6 {
                return tail _TAIL_CALL_error(
                    frame,
                    (stack_pointer + (-2 - i64(oparg))),
                    tstate,
                    next_instr,
                    oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg))));
        for v9 in range(i64(oparg)) {
            sr_close((v7 + v9).view(1)[0]);
        }
        sr_close(v6);
        sr_close(v5);
        stack_pointer = stack_pointer + (-1 - i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v10 = _CHECK_PERIODIC(tstate);
        if v10 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_PY_EXACT_ARGS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        if not _CHECK_PEP_523(tstate) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v1 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        if not _CHECK_FUNCTION_VERSION(ptr[u32]((this_instr + 2)).view(1)[0], v1) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v3 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        if not _CHECK_FUNCTION_EXACT_ARGS(oparg, v2, v3) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v4 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        if not _CHECK_STACK_SPACE(tstate, v4) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        if not _CHECK_RECURSION_REMAINING(tstate) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v5 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v6 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v7 = stack_pointer + (-i64(oparg));
        v8 = _INIT_CALL_PY_EXACT_ARGS(tstate, frame, oparg, v5, v6, v7);
        (stack_pointer + (-2 - i64(oparg))).view(1)[0] = v8;
        stack_pointer = stack_pointer + (-1 - i64(oparg));
        _SAVE_RETURN_OFFSET(frame, this_instr, next_instr);
        v9 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        frame = ptr[u8](_PUSH_FRAME(tstate, v9));
        stack_pointer = frame_stackpointer(frame);
        next_instr = frame_instr_ptr(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_BOUND_METHOD_EXACT_ARGS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        if not _CHECK_PEP_523(tstate) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v1 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v2 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        if not _CHECK_METHOD_VERSION(ptr[u32]((this_instr + 2)).view(1)[0], v1, v2) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v3 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        if not _CHECK_METHOD_EXACT_ARGS(oparg, v3) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v4 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        if not _CHECK_METHOD_STACK_SPACE(tstate, v4) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        if not _CHECK_RECURSION_REMAINING(tstate) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v5 = stack_pointer + (-i64(oparg) - i64(2));
        frame_set_stackpointer(frame, stack_pointer);
        _INIT_CALL_BOUND_METHOD_EXACT_ARGS(v5);
        v6 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v7 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v8 = stack_pointer + (-i64(oparg));
        v9 = _INIT_CALL_PY_EXACT_ARGS(tstate, frame, oparg, v6, v7, v8);
        (stack_pointer + (-2 - i64(oparg))).view(1)[0] = v9;
        stack_pointer = stack_pointer + (-1 - i64(oparg));
        _SAVE_RETURN_OFFSET(frame, this_instr, next_instr);
        v10 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        frame = ptr[u8](_PUSH_FRAME(tstate, v10));
        stack_pointer = frame_stackpointer(frame);
        next_instr = frame_instr_ptr(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_PY_GENERAL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        if not _CHECK_PEP_523(tstate) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v1 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        if not _CHECK_FUNCTION_VERSION(ptr[u32]((this_instr + 2)).view(1)[0], v1) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        if not _CHECK_RECURSION_REMAINING(tstate) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v3 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v4 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg))));
        v5 = _PY_FRAME_GENERAL(tstate, frame, oparg, v2, v3, v4);
        if v5 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer + (-2 - i64(oparg))), tstate, next_instr, oparg
            );
        }
        (stack_pointer + (-2 - i64(oparg))).view(1)[0] = v5;
        stack_pointer = stack_pointer + (-1 - i64(oparg));
        _SAVE_RETURN_OFFSET(frame, this_instr, next_instr);
        v6 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        frame = ptr[u8](_PUSH_FRAME(tstate, v6));
        stack_pointer = frame_stackpointer(frame);
        next_instr = frame_instr_ptr(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_BOUND_METHOD_GENERAL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        if not _CHECK_PEP_523(tstate) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v1 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v2 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        if not _CHECK_METHOD_VERSION(ptr[u32]((this_instr + 2)).view(1)[0], v1, v2) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        if not _CHECK_RECURSION_REMAINING(tstate) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v3 = stack_pointer + (-i64(oparg) - i64(2));
        frame_set_stackpointer(frame, stack_pointer);
        _EXPAND_METHOD(v3);
        v4 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v5 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v6 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg))));
        v7 = _PY_FRAME_GENERAL(tstate, frame, oparg, v4, v5, v6);
        if v7 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer + (-2 - i64(oparg))), tstate, next_instr, oparg
            );
        }
        (stack_pointer + (-2 - i64(oparg))).view(1)[0] = v7;
        stack_pointer = stack_pointer + (-1 - i64(oparg));
        _SAVE_RETURN_OFFSET(frame, this_instr, next_instr);
        v8 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        frame = ptr[u8](_PUSH_FRAME(tstate, v8));
        stack_pointer = frame_stackpointer(frame);
        next_instr = frame_instr_ptr(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_NON_PY_GENERAL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        if not _CHECK_IS_NOT_PY_CALLABLE(v1) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v3 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v4 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v5 = _CALL_NON_PY_GENERAL(oparg, v2, v3, v4);
        if v5 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg))));
        for v6 in range(i64(oparg)) {
            sr_close((v4 + v6).view(1)[0]);
        }
        sr_close(v3);
        sr_close(v2);
        (stack_pointer + (-2 - i64(oparg))).view(1)[0] = v5;
        stack_pointer = stack_pointer + (-1 - i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v7 = _CHECK_PERIODIC(tstate);
        if v7 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_ALLOC_AND_ENTER_INIT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        if not _CHECK_PEP_523(tstate) {
            return tail _TAIL_CALL_CALL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v1 = stack_pointer + (-i64(oparg) - i64(2));
        frame_set_stackpointer(frame, stack_pointer);
        v2 = _CHECK_AND_ALLOCATE_OBJECT(
            tstate, ptr[u32]((this_instr + 2)).view(1)[0], v1
        );
        if v2 != 0 {
            if v2 == 2 {
                return tail _TAIL_CALL_CALL(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        v3 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v4 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v5 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg))));
        v6 = _CREATE_INIT_FRAME(
            tstate, frame, this_instr, next_instr, oparg, v3, v4, v5
        );
        if v6 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer + (-2 - i64(oparg))), tstate, next_instr, oparg
            );
        }
        (stack_pointer + (-2 - i64(oparg))).view(1)[0] = v6;
        stack_pointer = stack_pointer + (-1 - i64(oparg));
        v7 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        frame = ptr[u8](_PUSH_FRAME(tstate, v7));
        stack_pointer = frame_stackpointer(frame);
        next_instr = frame_instr_ptr(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_KW(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer + (-3 - i64(oparg))).view(1)[0];
        v2 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _SPECIALIZE_CALL_KW(
            this_instr, oparg, (this_instr + 1).view(1)[0], v1, v2
        );
        if v3 != 0 {
            if v3 == 3 {
                slot = next_handler(this_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        v4 = stack_pointer + (-1 - i64(oparg) - i64(2));
        frame_set_stackpointer(frame, stack_pointer);
        _MAYBE_EXPAND_METHOD_KW(v4);
        v5 = (stack_pointer + (-3 - i64(oparg))).view(1)[0];
        v6 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v7 = stack_pointer + (-1 - i64(oparg));
        v8 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v9 = _DO_CALL_KW(
            tstate,
            frame,
            this_instr,
            next_instr,
            oparg,
            v5,
            v6,
            v7,
            v8,
            (stack_pointer + (-3 - i64(oparg)))
        );
        if v9 != 0 {
            if v9 == 5 {
                frame_set_stackpointer(frame, (stack_pointer + (-3 - i64(oparg))));
                return tail _TAIL_CALL_start_frame(
                    tstate_current_frame(tstate),
                    stack_pointer,
                    tstate,
                    next_instr,
                    oparg
                );
            }
            if v9 == 6 {
                return tail _TAIL_CALL_error(
                    frame,
                    (stack_pointer + (-3 - i64(oparg))),
                    tstate,
                    next_instr,
                    oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-3 - i64(oparg))));
        sr_close(v8);
        for v10 in range(i64(oparg)) {
            sr_close((v7 + v10).view(1)[0]);
        }
        sr_close(v6);
        sr_close(v5);
        stack_pointer = stack_pointer + (-2 - i64(oparg));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_KW_PY(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        if not _CHECK_PEP_523(tstate) {
            return tail _TAIL_CALL_CALL_KW(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v1 = (stack_pointer + (-3 - i64(oparg))).view(1)[0];
        if not _CHECK_FUNCTION_VERSION_KW(ptr[u32]((this_instr + 2)).view(1)[0], v1) {
            return tail _TAIL_CALL_CALL_KW(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        if not _CHECK_RECURSION_REMAINING(tstate) {
            return tail _TAIL_CALL_CALL_KW(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer + (-3 - i64(oparg))).view(1)[0];
        v3 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v4 = stack_pointer + (-1 - i64(oparg));
        v5 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer + (-3 - i64(oparg))));
        v6 = _PY_FRAME_KW(tstate, frame, oparg, v2, v3, v4, v5);
        if v6 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer + (-3 - i64(oparg))), tstate, next_instr, oparg
            );
        }
        (stack_pointer + (-3 - i64(oparg))).view(1)[0] = v6;
        stack_pointer = stack_pointer + (-2 - i64(oparg));
        _SAVE_RETURN_OFFSET(frame, this_instr, next_instr);
        v7 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        frame = ptr[u8](_PUSH_FRAME(tstate, v7));
        stack_pointer = frame_stackpointer(frame);
        next_instr = frame_instr_ptr(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_KW_BOUND_METHOD(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        if not _CHECK_PEP_523(tstate) {
            return tail _TAIL_CALL_CALL_KW(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v1 = (stack_pointer + (-3 - i64(oparg))).view(1)[0];
        v2 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        if not _CHECK_METHOD_VERSION_KW(
            ptr[u32]((this_instr + 2)).view(1)[0], v1, v2
        ) {
            return tail _TAIL_CALL_CALL_KW(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v3 = stack_pointer + (-1 - i64(oparg) - i64(2));
        frame_set_stackpointer(frame, stack_pointer);
        _EXPAND_METHOD_KW(v3);
        v4 = (stack_pointer + (-3 - i64(oparg))).view(1)[0];
        v5 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v6 = stack_pointer + (-1 - i64(oparg));
        v7 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer + (-3 - i64(oparg))));
        v8 = _PY_FRAME_KW(tstate, frame, oparg, v4, v5, v6, v7);
        if v8 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer + (-3 - i64(oparg))), tstate, next_instr, oparg
            );
        }
        (stack_pointer + (-3 - i64(oparg))).view(1)[0] = v8;
        stack_pointer = stack_pointer + (-2 - i64(oparg));
        _SAVE_RETURN_OFFSET(frame, this_instr, next_instr);
        v9 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        frame = ptr[u8](_PUSH_FRAME(tstate, v9));
        stack_pointer = frame_stackpointer(frame);
        next_instr = frame_instr_ptr(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_KW_NON_PY(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer + (-3 - i64(oparg))).view(1)[0];
        if not _CHECK_IS_NOT_PY_CALLABLE_KW(v1) {
            return tail _TAIL_CALL_CALL_KW(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer + (-3 - i64(oparg))).view(1)[0];
        v3 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v4 = stack_pointer + (-1 - i64(oparg));
        v5 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v6 = _CALL_KW_NON_PY(oparg, v2, v3, v4, v5);
        if v6 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-3 - i64(oparg))));
        sr_close(v5);
        for v7 in range(i64(oparg)) {
            sr_close((v4 + v7).view(1)[0]);
        }
        sr_close(v3);
        sr_close(v2);
        (stack_pointer + (-3 - i64(oparg))).view(1)[0] = v6;
        stack_pointer = stack_pointer + (-2 - i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v8 = _CHECK_PERIODIC(tstate);
        if v8 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CALL_FUNCTION_EX(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer + (-3 - i64(1))).view(1)[0];
        v2 = stack_pointer + (-1 - i64(1));
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _MAKE_CALLARGS_A_TUPLE(tstate, v1, v2);
        if v3 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        v4 = (stack_pointer - 4).view(1)[0];
        v5 = (stack_pointer - 3).view(1)[0];
        v6 = (stack_pointer - 2).view(1)[0];
        v7 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v8 = _DO_CALL_FUNCTION_EX(
            tstate, frame, this_instr, next_instr, v4, v6, v7, (stack_pointer - 4)
        );
        if v8 != 0 {
            if v8 == 5 {
                frame_set_stackpointer(frame, (stack_pointer - 4));
                return tail _TAIL_CALL_start_frame(
                    tstate_current_frame(tstate),
                    stack_pointer,
                    tstate,
                    next_instr,
                    oparg
                );
            }
            if v8 == 6 {
                return tail _TAIL_CALL_error(
                    frame, (stack_pointer - 4), tstate, next_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 4));
        sr_close(v7);
        sr_close(v6);
        sr_close(v5);
        sr_close(v4);
        frame_set_stackpointer(frame, (stack_pointer - 3));
        v9 = _CHECK_PERIODIC(tstate);
        if v9 != 0 {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 3), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer - 3;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_RETURN_GENERATOR(
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
        v1 = _MAKE_GENERATOR(frame);
        if v1 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, stack_pointer);
        frame = ptr[u8](_RETURN_GENERATOR(tstate, frame, v1));
        stack_pointer = frame_stackpointer(frame);
        next_instr = frame_instr_ptr(frame) + frame_return_offset(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_RESUME(
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
        v1 = _MAYBE_INSTRUMENT(tstate, frame);
        if v1 != 0 {
            if v1 == 3 {
                slot = next_handler(this_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        _QUICKEN_RESUME(tstate, this_instr);
        frame_set_stackpointer(frame, stack_pointer);
        v2 = _CHECK_PERIODIC_IF_NOT_YIELD_FROM(tstate, oparg);
        if v2 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_JUMP_BACKWARD(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = _SPECIALIZE_JUMP_BACKWARD(tstate, this_instr);
        if v1 != 0 {
            if v1 == 3 {
                slot = next_handler(this_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, stack_pointer);
        v2 = _CHECK_PERIODIC(tstate);
        if v2 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        next_instr = next_instr + JUMP_BACKWARD_NO_INTERRUPT(oparg);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_JUMP_BACKWARD_NO_JIT(
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
        v1 = _CHECK_PERIODIC(tstate);
        if v1 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        next_instr = next_instr + JUMP_BACKWARD_NO_INTERRUPT(oparg);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_JUMP_BACKWARD_JIT(
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
        v1 = _CHECK_PERIODIC(tstate);
        if v1 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        next_instr = next_instr + JUMP_BACKWARD_NO_INTERRUPT(oparg);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BINARY_OP(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 6;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _SPECIALIZE_BINARY_OP(
            (this_instr + 1).view(1)[0], v1, v2, frame, this_instr, oparg
        );
        if v3 != 0 {
            if v3 == 3 {
                slot = next_handler(this_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, stack_pointer);
        v4 = _BINARY_OP(oparg, v1, v2);
        if v4 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v2);
        sr_close(v1);
        (stack_pointer - 2).view(1)[0] = v4;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BINARY_OP_MULTIPLY_FLOAT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 6;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_FLOAT(v1) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_FLOAT(v2) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        v3 = _BINARY_OP_MULTIPLY_FLOAT(v2, v1);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BINARY_OP_ADD_FLOAT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 6;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_FLOAT(v1) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_FLOAT(v2) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        v3 = _BINARY_OP_ADD_FLOAT(v2, v1);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BINARY_OP_SUBTRACT_FLOAT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 6;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_FLOAT(v1) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_FLOAT(v2) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        v3 = _BINARY_OP_SUBTRACT_FLOAT(v2, v1);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BINARY_OP_ADD_UNICODE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 6;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_UNICODE(v1) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_UNICODE(v2) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        v3 = _BINARY_OP_ADD_UNICODE(v2, v1);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BINARY_OP_INPLACE_ADD_UNICODE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 6;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_UNICODE(v1) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_UNICODE(v2) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        v3 = _BINARY_OP_INPLACE_ADD_UNICODE(frame, next_instr, v2, v1);
        if v3 != 0 {
            if v3 == 2 {
                return tail _TAIL_CALL_BINARY_OP(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        next_instr = next_instr + _SKIP_STORE_FAST();
        stack_pointer = stack_pointer - 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BINARY_OP_EXTEND(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 6;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_BINARY_OP_EXTEND(ptr[u64]((this_instr + 2)).view(1)[0], v1, v2) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _BINARY_OP_EXTEND(this_instr, v1, v2);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v2);
        sr_close(v1);
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BINARY_OP_SUBSCR_LIST_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 6;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_INT(v1) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_LIST(v2) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v3 = _BINARY_OP_SUBSCR_LIST_INT(v2, v1, (stack_pointer - 2));
        if v3 != 0 {
            if v3 == 2 {
                return tail _TAIL_CALL_BINARY_OP(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v1);
        sr_close(v2);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BINARY_OP_SUBSCR_LIST_SLICE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 6;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_SLICE(v1) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_LIST(v2) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _BINARY_OP_SUBSCR_LIST_SLICE(v2, v1);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v1);
        sr_close(v2);
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BINARY_OP_SUBSCR_STR_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 6;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_INT(v1) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_UNICODE(v2) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        v3 = _BINARY_OP_SUBSCR_STR_INT(v2, v1, (stack_pointer - 2));
        if v3 != 0 {
            if v3 == 2 {
                return tail _TAIL_CALL_BINARY_OP(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BINARY_OP_SUBSCR_TUPLE_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 6;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_INT(v1) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_TUPLE(v2) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v3 = _BINARY_OP_SUBSCR_TUPLE_INT(v2, v1, (stack_pointer - 2));
        if v3 != 0 {
            if v3 == 2 {
                return tail _TAIL_CALL_BINARY_OP(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 1), tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v2);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BINARY_OP_SUBSCR_DICT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 6;
        v1 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_DICT(v1) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _BINARY_OP_SUBSCR_DICT(v1, v2);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v2);
        sr_close(v1);
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BINARY_OP_SUBSCR_GETITEM(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 6;
        if not _CHECK_PEP_523(tstate) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v1 = (stack_pointer - 2).view(1)[0];
        if not _BINARY_OP_SUBSCR_CHECK_FUNC(tstate, v1) {
            return tail _TAIL_CALL_BINARY_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 1).view(1)[0];
        v3 = _BINARY_OP_SUBSCR_INIT_CALL(tstate, frame, v1, v2);
        frame_set_stackpointer(frame, (stack_pointer - 2));
        frame = ptr[u8](_PUSH_FRAME(tstate, v3));
        stack_pointer = frame_stackpointer(frame);
        next_instr = frame_instr_ptr(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_BINARY_SLICE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 3).view(1)[0];
        v2 = (stack_pointer - 2).view(1)[0];
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 2));
        v4 = _BINARY_SLICE(v1, v2, v3);
        if v4 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 3));
        sr_close(v1);
        (stack_pointer - 3).view(1)[0] = v4;
        stack_pointer = stack_pointer - 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_STORE_SLICE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 4).view(1)[0];
        v2 = (stack_pointer - 3).view(1)[0];
        v3 = (stack_pointer - 2).view(1)[0];
        v4 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 2));
        v5 = _STORE_SLICE(v1, v2, v3, v4);
        if v5 != 0 {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 4));
        sr_close(v2);
        sr_close(v1);
        stack_pointer = stack_pointer - 4;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_STORE_SUBSCR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _SPECIALIZE_STORE_SUBSCR((this_instr + 1).view(1)[0], v1, v2, this_instr);
        if v3 != 0 {
            if v3 == 3 {
                slot = next_handler(this_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        v4 = (stack_pointer - 3).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v5 = _STORE_SUBSCR(v4, v1, v2);
        if v5 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 3));
        sr_close(v2);
        sr_close(v1);
        sr_close(v4);
        stack_pointer = stack_pointer - 3;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_STORE_SUBSCR_LIST_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_INT(v1) {
            return tail _TAIL_CALL_STORE_SUBSCR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_LIST(v2) {
            return tail _TAIL_CALL_STORE_SUBSCR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v3 = (stack_pointer - 3).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 3));
        v4 = _STORE_SUBSCR_LIST_INT(v3, v2, v1);
        if v4 != 0 {
            if v4 == 2 {
                return tail _TAIL_CALL_STORE_SUBSCR(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 3), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer - 3;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_STORE_SUBSCR_DICT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_DICT(v1) {
            return tail _TAIL_CALL_STORE_SUBSCR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 3).view(1)[0];
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 3));
        v4 = _STORE_SUBSCR_DICT(v2, v1, v3);
        if v4 != 0 {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 3), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer - 3;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_COMPARE_OP(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _SPECIALIZE_COMPARE_OP(
            (this_instr + 1).view(1)[0], v1, v2, this_instr, oparg
        );
        if v3 != 0 {
            if v3 == 3 {
                slot = next_handler(this_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        v4 = _COMPARE_OP(oparg, v1, v2);
        if v4 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        (stack_pointer - 2).view(1)[0] = v4;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_COMPARE_OP_FLOAT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_FLOAT(v1) {
            return tail _TAIL_CALL_COMPARE_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_FLOAT(v2) {
            return tail _TAIL_CALL_COMPARE_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v3 = _COMPARE_OP_FLOAT(oparg, v2, v1);
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_COMPARE_OP_INT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_INT(v1) {
            return tail _TAIL_CALL_COMPARE_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_INT(v2) {
            return tail _TAIL_CALL_COMPARE_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v3 = _COMPARE_OP_INT(oparg, v2, v1, (stack_pointer - 2));
        if v3 != 0 {
            if v3 == 2 {
                return tail _TAIL_CALL_COMPARE_OP(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_COMPARE_OP_STR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_UNICODE(v1) {
            return tail _TAIL_CALL_COMPARE_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        if not _GUARD_NOS_UNICODE(v2) {
            return tail _TAIL_CALL_COMPARE_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v3 = _COMPARE_OP_STR(oparg, v2, v1);
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CONTAINS_OP(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _SPECIALIZE_CONTAINS_OP((this_instr + 1).view(1)[0], v2, this_instr);
        if v3 != 0 {
            if v3 == 3 {
                slot = next_handler(this_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, stack_pointer);
        v4 = _CONTAINS_OP(oparg, v1, v2);
        if v4 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v2);
        sr_close(v1);
        (stack_pointer - 2).view(1)[0] = v4;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CONTAINS_OP_SET(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_ANY_SET(v1) {
            return tail _TAIL_CALL_CONTAINS_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _CONTAINS_OP_SET(oparg, v2, v1);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v1);
        sr_close(v2);
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_CONTAINS_OP_DICT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_DICT(v1) {
            return tail _TAIL_CALL_CONTAINS_OP(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _CONTAINS_OP_DICT(oparg, v2, v1);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v1);
        sr_close(v2);
        (stack_pointer - 2).view(1)[0] = v3;
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_TO_BOOL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = _SPECIALIZE_TO_BOOL((this_instr + 1).view(1)[0], v1, this_instr);
        if v2 != 0 {
            if v2 == 3 {
                slot = next_handler(this_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _TO_BOOL(v1);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v3;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_TO_BOOL_LIST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_LIST(v1) {
            return tail _TAIL_CALL_TO_BOOL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = _TO_BOOL_LIST(v1);
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_TO_BOOL_STR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TOS_UNICODE(v1) {
            return tail _TAIL_CALL_TO_BOOL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = _TO_BOOL_STR(v1);
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_TO_BOOL_ALWAYS_TRUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TYPE_VERSION(ptr[u32]((this_instr + 2)).view(1)[0], v1) {
            return tail _TAIL_CALL_TO_BOOL(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = _REPLACE_WITH_TRUE();
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_POP_ITER(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        stack_pointer = stack_pointer - 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_END_ASYNC_FOR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _END_ASYNC_FOR(tstate, frame, this_instr, v2);
        if v3 != 0 {
            if v3 == 4 {
                return tail _TAIL_CALL_exception_unwind(
                    frame, stack_pointer, tstate, next_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v2);
        sr_close(v1);
        stack_pointer = stack_pointer - 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_FOR_ITER(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = _SPECIALIZE_FOR_ITER((this_instr + 1).view(1)[0], v1, this_instr, oparg);
        if v2 != 0 {
            if v2 == 3 {
                slot = next_handler(this_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _FOR_ITER(tstate, frame, this_instr, v1, stack_pointer);
        if v3 != 0 {
            if v3 == 7 {
                next_instr = next_instr + (i64(oparg) + 1);
                stack_pointer = stack_pointer;
                slot = next_handler(next_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_FOR_ITER_LIST(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _ITER_CHECK_LIST(v1) {
            return tail _TAIL_CALL_FOR_ITER(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        frame_set_stackpointer(frame, stack_pointer);
        v2 = _ITER_JUMP_LIST(v1);
        if v2 != 0 {
            if v2 == 7 {
                next_instr = next_instr + (i64(oparg) + 1);
                stack_pointer = stack_pointer;
                slot = next_handler(next_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        v3 = _ITER_NEXT_LIST(v1);
        stack_pointer.view(1)[0] = v3;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_FOR_ITER_TUPLE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _ITER_CHECK_TUPLE(v1) {
            return tail _TAIL_CALL_FOR_ITER(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        frame_set_stackpointer(frame, stack_pointer);
        v2 = _ITER_JUMP_TUPLE(v1);
        if v2 != 0 {
            if v2 == 7 {
                next_instr = next_instr + (i64(oparg) + 1);
                stack_pointer = stack_pointer;
                slot = next_handler(next_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        v3 = _ITER_NEXT_TUPLE(v1);
        stack_pointer.view(1)[0] = v3;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_FOR_ITER_RANGE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _ITER_CHECK_RANGE(v1) {
            return tail _TAIL_CALL_FOR_ITER(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = _ITER_JUMP_RANGE(v1);
        if v2 != 0 {
            if v2 == 7 {
                next_instr = next_instr + (i64(oparg) + 1);
                stack_pointer = stack_pointer;
                slot = next_handler(next_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _ITER_NEXT_RANGE(v1);
        if v3 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        stack_pointer.view(1)[0] = v3;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_FOR_ITER_GEN(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        if not _CHECK_PEP_523(tstate) {
            return tail _TAIL_CALL_FOR_ITER(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v1 = (stack_pointer - 1).view(1)[0];
        v2 = _FOR_ITER_GEN_FRAME(tstate, frame, oparg, v1, stack_pointer);
        if v2 != 0 {
            if v2 == 2 {
                return tail _TAIL_CALL_FOR_ITER(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        v3 = stack_pointer.view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        frame = ptr[u8](_PUSH_FRAME(tstate, v3));
        stack_pointer = frame_stackpointer(frame);
        next_instr = frame_instr_ptr(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_SEND(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 2).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = _SPECIALIZE_SEND((this_instr + 1).view(1)[0], v1, this_instr);
        if v2 != 0 {
            if v2 == 3 {
                slot = next_handler(this_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        v4 = _SEND(
            tstate, frame, oparg, this_instr, next_instr, v3, (stack_pointer - 1)
        );
        if v4 != 0 {
            if v4 == 5 {
                frame_set_stackpointer(frame, (stack_pointer - 1));
                return tail _TAIL_CALL_start_frame(
                    tstate_current_frame(tstate),
                    stack_pointer,
                    tstate,
                    next_instr,
                    oparg
                );
            }
            if v4 == 8 {
                next_instr = frame_instr_ptr(frame);
                stack_pointer = stack_pointer;
                slot = next_handler(next_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
                );
            }
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 1), tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_SEND_GEN(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        if not _CHECK_PEP_523(tstate) {
            return tail _TAIL_CALL_SEND(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v1 = (stack_pointer - 2).view(1)[0];
        v2 = (stack_pointer - 1).view(1)[0];
        v3 = _SEND_GEN_FRAME(tstate, frame, oparg, v1, v2, (stack_pointer - 1));
        if v3 != 0 {
            if v3 == 2 {
                return tail _TAIL_CALL_SEND(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 1), tstate, next_instr, oparg
            );
        }
        v4 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        frame = ptr[u8](_PUSH_FRAME(tstate, v4));
        stack_pointer = frame_stackpointer(frame);
        next_instr = frame_instr_ptr(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_RESUME(
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
        v1 = _MAYBE_INSTRUMENT(tstate, frame);
        if v1 != 0 {
            if v1 == 3 {
                slot = next_handler(this_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, stack_pointer);
        v2 = _CHECK_PERIODIC_IF_NOT_YIELD_FROM(tstate, oparg);
        if v2 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _MONITOR_RESUME(tstate, frame, oparg, this_instr);
        if v3 != 0 {
            if v3 == 8 {
                next_instr = frame_instr_ptr(frame);
                stack_pointer = stack_pointer;
                slot = next_handler(next_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_RETURN_VALUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = _RETURN_VALUE_EVENT(tstate, frame, this_instr, v1);
        if v2 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        frame = ptr[u8](RETURN_VALUE(tstate, frame, v1));
        stack_pointer = frame_stackpointer(frame);
        next_instr = frame_instr_ptr(frame) + frame_return_offset(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_YIELD_VALUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = _YIELD_VALUE_EVENT(tstate, frame, this_instr, v1);
        if v2 != 0 {
            if v2 == 8 {
                next_instr = frame_instr_ptr(frame);
                stack_pointer = stack_pointer;
                slot = next_handler(next_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        frame = ptr[u8](YIELD_VALUE(tstate, frame, oparg, v1));
        stack_pointer = frame_stackpointer(frame);
        next_instr = frame_instr_ptr(frame) + 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_CALL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = stack_pointer + (-i64(oparg) - i64(2));
        frame_set_stackpointer(frame, stack_pointer);
        _MAYBE_EXPAND_METHOD(v1);
        v2 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v3 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v4 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v5 = _MONITOR_CALL(tstate, frame, this_instr, oparg, v2, v3, v4);
        if v5 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        v6 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v7 = (stack_pointer + (-1 - i64(oparg))).view(1)[0];
        v8 = stack_pointer + (-i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v9 = _DO_CALL_INSTRUMENTED(
            tstate,
            frame,
            this_instr,
            next_instr,
            oparg,
            v6,
            v7,
            v8,
            (stack_pointer + (-2 - i64(oparg)))
        );
        if v9 != 0 {
            if v9 == 5 {
                frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg))));
                return tail _TAIL_CALL_start_frame(
                    tstate_current_frame(tstate),
                    stack_pointer,
                    tstate,
                    next_instr,
                    oparg
                );
            }
            if v9 == 6 {
                return tail _TAIL_CALL_error(
                    frame,
                    (stack_pointer + (-2 - i64(oparg))),
                    tstate,
                    next_instr,
                    oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-2 - i64(oparg))));
        for v10 in range(i64(oparg)) {
            sr_close((v8 + v10).view(1)[0]);
        }
        sr_close(v7);
        sr_close(v6);
        stack_pointer = stack_pointer + (-1 - i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v11 = _CHECK_PERIODIC(tstate);
        if v11 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_CALL_KW(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 4;
        v1 = stack_pointer + (-1 - i64(oparg) - i64(2));
        frame_set_stackpointer(frame, stack_pointer);
        _MAYBE_EXPAND_METHOD_KW(v1);
        v2 = (stack_pointer + (-3 - i64(oparg))).view(1)[0];
        v3 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v4 = stack_pointer + (-1 - i64(oparg));
        frame_set_stackpointer(frame, stack_pointer);
        v5 = _MONITOR_CALL_KW(tstate, frame, this_instr, v2, v3, v4);
        if v5 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        v6 = (stack_pointer + (-3 - i64(oparg))).view(1)[0];
        v7 = (stack_pointer + (-2 - i64(oparg))).view(1)[0];
        v8 = stack_pointer + (-1 - i64(oparg));
        v9 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v10 = _DO_CALL_KW_INSTRUMENTED(
            tstate,
            frame,
            this_instr,
            next_instr,
            oparg,
            v6,
            v7,
            v8,
            v9,
            (stack_pointer + (-3 - i64(oparg)))
        );
        if v10 != 0 {
            if v10 == 5 {
                frame_set_stackpointer(frame, (stack_pointer + (-3 - i64(oparg))));
                return tail _TAIL_CALL_start_frame(
                    tstate_current_frame(tstate),
                    stack_pointer,
                    tstate,
                    next_instr,
                    oparg
                );
            }
            if v10 == 6 {
                return tail _TAIL_CALL_error(
                    frame,
                    (stack_pointer + (-3 - i64(oparg))),
                    tstate,
                    next_instr,
                    oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer + (-3 - i64(oparg))));
        sr_close(v9);
        for v11 in range(i64(oparg)) {
            sr_close((v8 + v11).view(1)[0]);
        }
        sr_close(v7);
        sr_close(v6);
        stack_pointer = stack_pointer + (-2 - i64(oparg));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_CALL_FUNCTION_EX(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer + (-3 - i64(1))).view(1)[0];
        v2 = stack_pointer + (-1 - i64(1));
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _MAKE_CALLARGS_A_TUPLE(tstate, v1, v2);
        if v3 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        v4 = (stack_pointer - 4).view(1)[0];
        v5 = (stack_pointer - 3).view(1)[0];
        v6 = (stack_pointer - 2).view(1)[0];
        v7 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v8 = _DO_CALL_FUNCTION_EX_INSTRUMENTED(
            tstate, frame, this_instr, v4, v6, v7, (stack_pointer - 4)
        );
        if v8 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 4));
        sr_close(v7);
        sr_close(v6);
        sr_close(v5);
        sr_close(v4);
        frame_set_stackpointer(frame, (stack_pointer - 3));
        v9 = _CHECK_PERIODIC(tstate);
        if v9 != 0 {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 3), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer - 3;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 10;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = _SPECIALIZE_LOAD_ATTR(
            (this_instr + 1).view(1)[0], v1, frame, oparg, this_instr
        );
        if v2 != 0 {
            if v2 == 3 {
                slot = next_handler(this_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        v4 = _LOAD_ATTR(v3, stack_pointer, tstate, frame, oparg);
        if v4 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 1), tstate, next_instr, oparg
            );
        }
        (stack_pointer - 1).view(1)[0] = v4;
        stack_pointer = stack_pointer + (i64(oparg & 1));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_INSTANCE_VALUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 10;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TYPE_VERSION(ptr[u32]((this_instr + 2)).view(1)[0], v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        if not _CHECK_MANAGED_OBJECT_HAS_VALUES(v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = _LOAD_ATTR_INSTANCE_VALUE(
            (this_instr + 4).view(1)[0], v1, (stack_pointer - 1)
        );
        if v2 != 0 {
            if v2 == 2 {
                return tail _TAIL_CALL_LOAD_ATTR(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        _PUSH_NULL_CONDITIONAL(oparg, stack_pointer);
        stack_pointer = stack_pointer + (i64(oparg & 1));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_MODULE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 10;
        v1 = (stack_pointer - 1).view(1)[0];
        v2 = _LOAD_ATTR_MODULE(
            ptr[u32]((this_instr + 2)).view(1)[0],
            (this_instr + 4).view(1)[0],
            v1,
            (stack_pointer - 1)
        );
        if v2 != 0 {
            if v2 == 2 {
                return tail _TAIL_CALL_LOAD_ATTR(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        _PUSH_NULL_CONDITIONAL(oparg, stack_pointer);
        stack_pointer = stack_pointer + (i64(oparg & 1));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_WITH_HINT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 10;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TYPE_VERSION(ptr[u32]((this_instr + 2)).view(1)[0], v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = _LOAD_ATTR_WITH_HINT(
            (this_instr + 4).view(1)[0], v1, frame, oparg, (stack_pointer - 1)
        );
        if v2 != 0 {
            if v2 == 2 {
                return tail _TAIL_CALL_LOAD_ATTR(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        _PUSH_NULL_CONDITIONAL(oparg, stack_pointer);
        stack_pointer = stack_pointer + (i64(oparg & 1));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_SLOT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 10;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TYPE_VERSION(ptr[u32]((this_instr + 2)).view(1)[0], v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = _LOAD_ATTR_SLOT((this_instr + 4).view(1)[0], v1, (stack_pointer - 1));
        if v2 != 0 {
            if v2 == 2 {
                return tail _TAIL_CALL_LOAD_ATTR(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        _PUSH_NULL_CONDITIONAL(oparg, stack_pointer);
        stack_pointer = stack_pointer + (i64(oparg & 1));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_CLASS(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 10;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _CHECK_ATTR_CLASS(ptr[u32]((this_instr + 2)).view(1)[0], v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = _LOAD_ATTR_CLASS(ptr[u64]((this_instr + 6)).view(1)[0]);
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        _PUSH_NULL_CONDITIONAL(oparg, stack_pointer);
        stack_pointer = stack_pointer + (i64(oparg & 1));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_CLASS_WITH_METACLASS_CHECK(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 10;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _CHECK_ATTR_CLASS(ptr[u32]((this_instr + 2)).view(1)[0], v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        if not _GUARD_TYPE_VERSION(ptr[u32]((this_instr + 4)).view(1)[0], v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = _LOAD_ATTR_CLASS(ptr[u64]((this_instr + 6)).view(1)[0]);
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        _PUSH_NULL_CONDITIONAL(oparg, stack_pointer);
        stack_pointer = stack_pointer + (i64(oparg & 1));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_PROPERTY(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 10;
        if not _CHECK_PEP_523(tstate) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TYPE_VERSION(ptr[u32]((this_instr + 2)).view(1)[0], v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = _LOAD_ATTR_PROPERTY_FRAME(
            ptr[u64]((this_instr + 6)).view(1)[0],
            v1,
            tstate,
            frame,
            (stack_pointer - 1)
        );
        if v2 != 0 {
            if v2 == 2 {
                return tail _TAIL_CALL_LOAD_ATTR(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 1), tstate, next_instr, oparg
            );
        }
        _SAVE_RETURN_OFFSET(frame, this_instr, next_instr);
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 1));
        frame = ptr[u8](_PUSH_FRAME(tstate, v3));
        stack_pointer = frame_stackpointer(frame);
        next_instr = frame_instr_ptr(frame);
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_METHOD_WITH_VALUES(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 10;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TYPE_VERSION(ptr[u32]((this_instr + 2)).view(1)[0], v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        if not _GUARD_DORV_VALUES_INST_ATTR_FROM_DICT(v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        if not _GUARD_KEYS_VERSION(ptr[u32]((this_instr + 4)).view(1)[0], v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = _LOAD_ATTR_METHOD_WITH_VALUES(
            ptr[u64]((this_instr + 6)).view(1)[0], v1, stack_pointer
        );
        (stack_pointer - 1).view(1)[0] = v2;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_METHOD_NO_DICT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 10;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TYPE_VERSION(ptr[u32]((this_instr + 2)).view(1)[0], v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = _LOAD_ATTR_METHOD_NO_DICT(
            ptr[u64]((this_instr + 6)).view(1)[0], v1, stack_pointer
        );
        (stack_pointer - 1).view(1)[0] = v2;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_METHOD_LAZY_DICT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 10;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TYPE_VERSION(ptr[u32]((this_instr + 2)).view(1)[0], v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        if not _CHECK_ATTR_METHOD_LAZY_DICT((this_instr + 4).view(1)[0], v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = _LOAD_ATTR_METHOD_LAZY_DICT(
            ptr[u64]((this_instr + 6)).view(1)[0], v1, stack_pointer
        );
        (stack_pointer - 1).view(1)[0] = v2;
        stack_pointer = stack_pointer + 1;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 10;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TYPE_VERSION(ptr[u32]((this_instr + 2)).view(1)[0], v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        if not _GUARD_DORV_VALUES_INST_ATTR_FROM_DICT(v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        if not _GUARD_KEYS_VERSION(ptr[u32]((this_instr + 4)).view(1)[0], v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = _LOAD_ATTR_NONDESCRIPTOR_WITH_VALUES(
            ptr[u64]((this_instr + 6)).view(1)[0]
        );
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_ATTR_NONDESCRIPTOR_NO_DICT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 10;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TYPE_VERSION(ptr[u32]((this_instr + 2)).view(1)[0], v1) {
            return tail _TAIL_CALL_LOAD_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = _LOAD_ATTR_NONDESCRIPTOR_NO_DICT(ptr[u64]((this_instr + 6)).view(1)[0]);
        frame_set_stackpointer(frame, (stack_pointer - 1));
        sr_close(v1);
        (stack_pointer - 1).view(1)[0] = v2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_SUPER_ATTR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 3).view(1)[0];
        v2 = (stack_pointer - 2).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _SPECIALIZE_LOAD_SUPER_ATTR(
            (this_instr + 1).view(1)[0], v1, v2, oparg, this_instr
        );
        if v3 != 0 {
            if v3 == 3 {
                slot = next_handler(this_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        v4 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v5 = _LOAD_SUPER_ATTR(v1, v2, v4, tstate, frame, oparg, this_instr);
        if v5 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 3));
        sr_close(v4);
        sr_close(v2);
        sr_close(v1);
        (stack_pointer - 3).view(1)[0] = v5;
        stack_pointer = stack_pointer - 2;
        _PUSH_NULL_CONDITIONAL(oparg, stack_pointer);
        stack_pointer = stack_pointer + (i64(oparg & 1));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_LOAD_SPECIAL(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 1;
        v1 = (stack_pointer - 1).view(1)[0];
        _INSERT_NULL(v1, (stack_pointer - 1));
        stack_pointer = stack_pointer + (-1 + i64(2));
        v2 = stack_pointer + (-i64(2));
        frame_set_stackpointer(frame, stack_pointer);
        v3 = _LOAD_SPECIAL(v2, tstate, oparg);
        if v3 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_STORE_ATTR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 5;
        v1 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v2 = _SPECIALIZE_STORE_ATTR(
            (this_instr + 1).view(1)[0], v1, frame, oparg, this_instr
        );
        if v2 != 0 {
            if v2 == 3 {
                slot = next_handler(this_instr);
                return tail slot.view(1)[0].handler(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        v3 = (stack_pointer - 2).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v4 = _STORE_ATTR(v3, v1, frame, oparg);
        if v4 != 0 {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 2));
        sr_close(v1);
        sr_close(v3);
        stack_pointer = stack_pointer - 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_STORE_ATTR_INSTANCE_VALUE(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 5;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TYPE_VERSION_AND_LOCK(
            ptr[u32]((this_instr + 2)).view(1)[0], v1
        ) {
            return tail _TAIL_CALL_STORE_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        if not _GUARD_DORV_NO_DICT(v1) {
            return tail _TAIL_CALL_STORE_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 2));
        _STORE_ATTR_INSTANCE_VALUE((this_instr + 4).view(1)[0], v2, v1);
        stack_pointer = stack_pointer - 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_STORE_ATTR_WITH_HINT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 5;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TYPE_VERSION(ptr[u32]((this_instr + 2)).view(1)[0], v1) {
            return tail _TAIL_CALL_STORE_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 2));
        v3 = _STORE_ATTR_WITH_HINT((this_instr + 4).view(1)[0], v2, v1, frame, oparg);
        if v3 != 0 {
            if v3 == 2 {
                return tail _TAIL_CALL_STORE_ATTR(
                    frame, stack_pointer, tstate, this_instr, oparg
                );
            }
            return tail _TAIL_CALL_error(
                frame, (stack_pointer - 2), tstate, next_instr, oparg
            );
        }
        stack_pointer = stack_pointer - 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_STORE_ATTR_SLOT(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 5;
        v1 = (stack_pointer - 1).view(1)[0];
        if not _GUARD_TYPE_VERSION(ptr[u32]((this_instr + 2)).view(1)[0], v1) {
            return tail _TAIL_CALL_STORE_ATTR(
                frame, stack_pointer, tstate, this_instr, oparg
            );
        }
        v2 = (stack_pointer - 2).view(1)[0];
        frame_set_stackpointer(frame, (stack_pointer - 2));
        _STORE_ATTR_SLOT((this_instr + 4).view(1)[0], v2, v1);
        stack_pointer = stack_pointer - 2;
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }  @__preserve_none
    def _TAIL_CALL_INSTRUMENTED_LOAD_SUPER_ATTR(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject] {
        this_instr = next_instr;
        frame_set_instr_ptr(frame, next_instr);
        next_instr = next_instr + 2;
        v1 = (stack_pointer - 3).view(1)[0];
        v2 = (stack_pointer - 2).view(1)[0];
        v3 = (stack_pointer - 1).view(1)[0];
        frame_set_stackpointer(frame, stack_pointer);
        v4 = _LOAD_SUPER_ATTR_INSTRUMENTED(
            v1, v2, v3, tstate, frame, oparg, this_instr
        );
        if v4 == u64(0) {
            return tail _TAIL_CALL_error(
                frame, stack_pointer, tstate, next_instr, oparg
            );
        }
        frame_set_stackpointer(frame, (stack_pointer - 3));
        sr_close(v3);
        sr_close(v2);
        sr_close(v1);
        (stack_pointer - 3).view(1)[0] = v4;
        stack_pointer = stack_pointer - 2;
        _PUSH_NULL_CONDITIONAL(oparg, stack_pointer);
        stack_pointer = stack_pointer + (i64(oparg & 1));
        slot = next_handler(next_instr);
        return tail slot.view(1)[0].handler(
            frame, stack_pointer, tstate, next_instr, next_oparg(next_instr)
        );
    }
}
