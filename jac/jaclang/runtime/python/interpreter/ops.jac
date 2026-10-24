import from c {
    @__preserve_none
    obj HandlerSlot {
        has handler:
            Callable[[ptr[u8], ptr[u64], ptr, ptr[u16], i32], ptr[PyObject]] = 0;
    }  glob INSTRUCTION_TABLE: HandlerSlot; def _PyLong_Add(
        a: ptr[PyLongObject], b: ptr[PyLongObject]
    ) -> ptr[PyObject];  def _PyLong_Subtract(
        a: ptr[PyLongObject], b: ptr[PyLongObject]
    ) -> ptr[PyObject];  def _PyLong_Multiply(
        a: ptr[PyLongObject], b: ptr[PyLongObject]
    ) -> ptr[PyObject];
}

glob OP_LOAD_CONST: Final[u16] = u16(82),
     OP_LOAD_CONST_IMMORTAL: Final[u16] = u16(190),
     OP_LOAD_CONST_MORTAL: Final[u16] = u16(191),
     OP_NOT_TAKEN: Final[u16] = u16(28);

glob ST_OK: Final[i32] = 0,
     ST_ERROR: Final[i32] = 1,
     ST_DEOPT: Final[i32] = 2,
     ST_REDISPATCH: Final[i32] = 3,
     ST_UNWIND: Final[i32] = 4,
     ST_INLINED: Final[i32] = 5,
     ST_ERROR_TAKEN: Final[i32] = 6,
     ST_EXHAUSTED: Final[i32] = 7,
     ST_RESUME_AT: Final[i32] = 8;

def frame_stackpointer(frame: ptr[u8]) -> ptr[u64];

def frame_instr_ptr(frame: ptr[u8]) -> ptr[u16];

def frame_return_offset(frame: ptr[u8]) -> i64;

def tstate_current_frame(tstate: ptr) -> ptr[u8];

def frame_local(frame: ptr[u8], index: i32) -> ptr[u64];

def frame_set_instr_ptr(frame: ptr[u8], instr: ptr[u16]);

def frame_set_stackpointer(frame: ptr[u8], sp: ptr[u64]);

def frame_code(frame: ptr[u8]) -> ptr[u8];

def frame_const(frame: ptr[u8], index: i32) -> ptr[PyObject];

def next_handler(next_instr: ptr[u16]) -> ptr[HandlerSlot];

def next_oparg(next_instr: ptr[u16]) -> i32;

def NOP;

def NOT_TAKEN;

def LOAD_FAST(frame: ptr[u8], oparg: i32) -> u64;

def LOAD_FAST_BORROW(frame: ptr[u8], oparg: i32) -> u64;

def LOAD_FAST_AND_CLEAR(frame: ptr[u8], oparg: i32) -> u64;

def LOAD_FAST_LOAD_FAST(
    frame: ptr[u8], oparg: i32, value1: ptr[u64], value2: ptr[u64]
);

def LOAD_FAST_BORROW_LOAD_FAST_BORROW(
    frame: ptr[u8], oparg: i32, value1: ptr[u64], value2: ptr[u64]
);

def LOAD_CONST(frame: ptr[u8], oparg: i32, this_instr: ptr[u16]) -> u64;

def LOAD_CONST_MORTAL(frame: ptr[u8], oparg: i32) -> u64;

def LOAD_CONST_IMMORTAL(frame: ptr[u8], oparg: i32) -> u64;

def LOAD_SMALL_INT(oparg: i32) -> u64;

def STORE_FAST(frame: ptr[u8], oparg: i32, value: u64);

def STORE_FAST_LOAD_FAST(frame: ptr[u8], oparg: i32, value1: u64) -> u64;

def STORE_FAST_STORE_FAST(frame: ptr[u8], oparg: i32, value2: u64, value1: u64);

def COPY(values: ptr[u64]) -> u64;

def SWAP(values: ptr[u64], oparg: i32);

def PUSH_NULL -> u64;

def UNARY_NOT(value: u64) -> u64;

def _GUARD_TOS_INT(value: u64) -> bool;

def _GUARD_NOS_INT(left: u64) -> bool;

def _BINARY_OP_ADD_INT(left: u64, right: u64) -> u64;

def _BINARY_OP_SUBTRACT_INT(left: u64, right: u64) -> u64;

def _BINARY_OP_MULTIPLY_INT(left: u64, right: u64) -> u64;

def _IS_NONE(value: u64) -> u64;

def _POP_JUMP_IF_FALSE(
    cond: u64, oparg: i32, this_instr: ptr[u16], next_instr: ptr[u16]
) -> i64;

def _POP_JUMP_IF_TRUE(
    cond: u64, oparg: i32, this_instr: ptr[u16], next_instr: ptr[u16]
) -> i64;

def JUMP_FORWARD(oparg: i32) -> i64;

impl frame_stackpointer(frame: ptr[u8]) -> ptr[u64] {
    return ptr[ptr[u64]](frame + _PyInterpreterFrame_STACKPOINTER).view(1)[0];
}

impl frame_instr_ptr(frame: ptr[u8]) -> ptr[u16] {
    return ptr[ptr[u16]](frame + _PyInterpreterFrame_INSTR_PTR).view(1)[0];
}

impl frame_return_offset(frame: ptr[u8]) -> i64 {
    return i64(ptr[u16](frame + _PyInterpreterFrame_RETURN_OFFSET).view(1)[0]);
}

impl tstate_current_frame(tstate: ptr) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_CURRENT_FRAME).view(1)[0];
}

impl frame_local(frame: ptr[u8], index: i32) -> ptr[u64] {
    return ptr[u64](frame + _PyInterpreterFrame_LOCALSPLUS) + i64(index);
}

impl frame_set_instr_ptr(frame: ptr[u8], instr: ptr[u16]) {
    ptr[ptr[u16]](frame + _PyInterpreterFrame_INSTR_PTR).view(1)[0] = instr;
}

impl frame_set_stackpointer(frame: ptr[u8], sp: ptr[u64]) {
    ptr[ptr[u64]](frame + _PyInterpreterFrame_STACKPOINTER).view(1)[0] = sp;
}

impl frame_code(frame: ptr[u8]) -> ptr[u8] {
    bits = ptr[u64](frame + _PyInterpreterFrame_F_EXECUTABLE).view(1)[0];
    return ptr[u8](i64.wrap(bits & SR_PTR_MASK));
}

impl frame_const(frame: ptr[u8], index: i32) -> ptr[PyObject] {
    consts = ptr[ptr[PyObject]](frame_code(frame) + PyCodeObject_CONSTS).view(1)[0];
    return tuple_get_item(consts, i64(index));
}

impl next_handler(next_instr: ptr[u16]) -> ptr[HandlerSlot] {
    word = next_instr.view(1)[0];
    return ptr[HandlerSlot](addressof(INSTRUCTION_TABLE)) + i64(word & u16(255));
}

impl next_oparg(next_instr: ptr[u16]) -> i32 {
    return i32(next_instr.view(1)[0] >> u16(8));
}

impl NOP {
    return;
}

impl NOT_TAKEN {
    return;
}

impl LOAD_FAST(frame: ptr[u8], oparg: i32) -> u64 {
    return sr_dup(frame_local(frame, oparg).view(1)[0]);
}

impl LOAD_FAST_BORROW(frame: ptr[u8], oparg: i32) -> u64 {
    return sr_borrow_ref(frame_local(frame, oparg).view(1)[0]);
}

impl LOAD_FAST_AND_CLEAR(frame: ptr[u8], oparg: i32) -> u64 {
    slot = frame_local(frame, oparg);
    value = slot.view(1)[0];
    slot.view(1)[0] = SR_NULL;
    return value;
}

impl LOAD_FAST_LOAD_FAST(
    frame: ptr[u8], oparg: i32, value1: ptr[u64], value2: ptr[u64]
) {
    value1.view(1)[0] = sr_dup(frame_local(frame, oparg >> 4).view(1)[0]);
    value2.view(1)[0] = sr_dup(frame_local(frame, oparg & 15).view(1)[0]);
}

impl LOAD_FAST_BORROW_LOAD_FAST_BORROW(
    frame: ptr[u8], oparg: i32, value1: ptr[u64], value2: ptr[u64]
) {
    value1.view(1)[0] = sr_borrow_ref(frame_local(frame, oparg >> 4).view(1)[0]);
    value2.view(1)[0] = sr_borrow_ref(frame_local(frame, oparg & 15).view(1)[0]);
}

impl LOAD_CONST(frame: ptr[u8], oparg: i32, this_instr: ptr[u16]) -> u64 {
    value = sr_new(frame_const(frame, oparg));
    word = this_instr.view(1)[0];
    if (word & u16(255)) == OP_LOAD_CONST {
        code = OP_LOAD_CONST_MORTAL;
        if (value & SR_TAG_REFCNT) != u64(0) {
            code = OP_LOAD_CONST_IMMORTAL;
        }
        this_instr.view(1)[0] = (word & u16(0xFF00)) | code;
    }
    return value;
}

impl LOAD_CONST_MORTAL(frame: ptr[u8], oparg: i32) -> u64 {
    return sr_new_mortal(frame_const(frame, oparg));
}

impl LOAD_CONST_IMMORTAL(frame: ptr[u8], oparg: i32) -> u64 {
    return sr_immortal(frame_const(frame, oparg));
}

impl LOAD_SMALL_INT(oparg: i32) -> u64 {
    return sr_immortal(get_small_int(i64(oparg)));
}

impl STORE_FAST(frame: ptr[u8], oparg: i32, value: u64) {
    slot = frame_local(frame, oparg);
    tmp = slot.view(1)[0];
    slot.view(1)[0] = value;
    sr_xclose(tmp);
}

impl STORE_FAST_LOAD_FAST(frame: ptr[u8], oparg: i32, value1: u64) -> u64 {
    slot = frame_local(frame, oparg >> 4);
    tmp = slot.view(1)[0];
    slot.view(1)[0] = value1;
    sr_xclose(tmp);
    return sr_dup(frame_local(frame, oparg & 15).view(1)[0]);
}

impl STORE_FAST_STORE_FAST(frame: ptr[u8], oparg: i32, value2: u64, value1: u64) {
    slot = frame_local(frame, oparg >> 4);
    tmp = slot.view(1)[0];
    slot.view(1)[0] = value1;
    sr_xclose(tmp);
    slot = frame_local(frame, oparg & 15);
    tmp = slot.view(1)[0];
    slot.view(1)[0] = value2;
    sr_xclose(tmp);
}

impl COPY(values: ptr[u64]) -> u64 {
    return sr_dup(values.view(1)[0]);
}

impl SWAP(values: ptr[u64], oparg: i32) {
    top = values + (i64(oparg) - 1);
    temp = values.view(1)[0];
    values.view(1)[0] = top.view(1)[0];
    top.view(1)[0] = temp;
}

impl PUSH_NULL -> u64 {
    return SR_NULL;
}

impl UNARY_NOT(value: u64) -> u64 {
    if sr_is_false(value) {
        return sr_true();
    }
    return sr_false();
}

impl _GUARD_TOS_INT(value: u64) -> bool {
    return sr_type(value) == ptr[PyTypeObject](addressof(PyLong_Type));
}

impl _GUARD_NOS_INT(left: u64) -> bool {
    return sr_type(left) == ptr[PyTypeObject](addressof(PyLong_Type));
}

impl _BINARY_OP_ADD_INT(left: u64, right: u64) -> u64 {
    res = _PyLong_Add(
        ptr[PyLongObject](sr_borrow(left)), ptr[PyLongObject](sr_borrow(right))
    );
    sr_close_long(right);
    sr_close_long(left);
    if not res {
        return u64(0);
    }
    return sr_steal(res);
}

impl _BINARY_OP_SUBTRACT_INT(left: u64, right: u64) -> u64 {
    res = _PyLong_Subtract(
        ptr[PyLongObject](sr_borrow(left)), ptr[PyLongObject](sr_borrow(right))
    );
    sr_close_long(right);
    sr_close_long(left);
    if not res {
        return u64(0);
    }
    return sr_steal(res);
}

impl _BINARY_OP_MULTIPLY_INT(left: u64, right: u64) -> u64 {
    res = _PyLong_Multiply(
        ptr[PyLongObject](sr_borrow(left)), ptr[PyLongObject](sr_borrow(right))
    );
    sr_close_long(right);
    sr_close_long(left);
    if not res {
        return u64(0);
    }
    return sr_steal(res);
}

impl _IS_NONE(value: u64) -> u64 {
    if sr_is_none(value) {
        return sr_true();
    }
    return sr_false();
}

impl _POP_JUMP_IF_FALSE(
    cond: u64, oparg: i32, this_instr: ptr[u16], next_instr: ptr[u16]
) -> i64 {
    flag = sr_is_false(cond);
    cache = this_instr + 1;
    taken = u16(1) if flag else u16(0);
    cache.view(1)[0] = u16.wrap((i64(cache.view(1)[0]) << 1) | i64(taken));
    if flag {
        return i64(oparg);
    }
    return 1 if (next_instr.view(1)[0] & u16(255)) == OP_NOT_TAKEN else 0;
}

impl _POP_JUMP_IF_TRUE(
    cond: u64, oparg: i32, this_instr: ptr[u16], next_instr: ptr[u16]
) -> i64 {
    flag = sr_is_true(cond);
    cache = this_instr + 1;
    taken = u16(1) if flag else u16(0);
    cache.view(1)[0] = u16.wrap((i64(cache.view(1)[0]) << 1) | i64(taken));
    if flag {
        return i64(oparg);
    }
    return 1 if (next_instr.view(1)[0] & u16(255)) == OP_NOT_TAKEN else 0;
}

impl JUMP_FORWARD(oparg: i32) -> i64 {
    return i64(oparg);
}
