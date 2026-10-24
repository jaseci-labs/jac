import from c {
    @__preserve_none
    def _TAIL_CALL_BINARY_OP(
        frame: ptr[u8],
        stack_pointer: ptr[u64],
        tstate: ptr,
        next_instr: ptr[u16],
        oparg: i32
    ) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_error(
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
    }
}
