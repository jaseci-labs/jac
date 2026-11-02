import from c {
    obj OpsCallScratch {
        has s0: ptr[PyObject] = ptr[PyObject](),
            s1: ptr[PyObject] = ptr[PyObject](),
            s2: ptr[PyObject] = ptr[PyObject](),
            s3: ptr[PyObject] = ptr[PyObject](),
            s4: ptr[PyObject] = ptr[PyObject](),
            s5: ptr[PyObject] = ptr[PyObject](),
            s6: ptr[PyObject] = ptr[PyObject](),
            s7: ptr[PyObject] = ptr[PyObject](),
            s8: ptr[PyObject] = ptr[PyObject](),
            s9: ptr[PyObject] = ptr[PyObject](),
            s10: ptr[PyObject] = ptr[PyObject]();
    }  def jacpy_stack_address(slots: &mut OpsCallScratch) -> int;  glob _Py_InitCleanup:
             PyObject,
         _PyInstrumentation_MISSING: PyObject; def _PyEvalFramePushAndInit(
        tstate: ptr[PyThreadState],
        func: u64,
        locals: ptr[PyObject],
        args: ptr[u64],
        argcount: u64,
        kwnames: ptr[PyObject],
        previous: ptr[u8]
    ) -> ptr[u8];  def _PyEval_FrameClearAndPop(
        tstate: ptr[PyThreadState], frame: ptr[u8]
    );  def _PyThreadState_PopFrame(tstate: ptr[PyThreadState], frame: ptr[u8]);  def _Py_MakeCoro(
        func: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyFunction_Vectorcall(
        func: ptr[PyObject],
        stack: ptr[ptr[PyObject]],
        nargsf: u64,
        kwnames: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyStack_UnpackDict(
        tstate: ptr[PyThreadState],
        args: ptr[ptr[PyObject]],
        nargs: i64,
        kwargs: ptr[PyObject],
        p_kwnames: ptr[ptr[PyObject]]
    ) -> ptr[ptr[PyObject]];  def _PyStack_UnpackDict_FreeNoDecRef(
        stack: ptr[ptr[PyObject]], kwnames: ptr[PyObject]
    );  def _Py_Check_ArgsIterable(
        tstate: ptr[PyThreadState], func: ptr[PyObject], args: ptr[PyObject]
    ) -> i32;  def _Py_Specialize_Call(callable: u64, instr: ptr[u16], nargs: i32);  def _Py_Specialize_CallKw(
        callable: u64, instr: ptr[u16], nargs: i32
    );  def _Py_call_instrumentation_2args(
        tstate: ptr[PyThreadState],
        event: i32,
        frame: ptr[u8],
        instr: ptr[u16],
        arg0: ptr[PyObject],
        arg1: ptr[PyObject]
    ) -> i32;  def _Py_call_instrumentation_exc2(
        tstate: ptr[PyThreadState],
        event: i32,
        frame: ptr[u8],
        instr: ptr[u16],
        arg0: ptr[PyObject],
        arg1: ptr[PyObject]
    );
}

glob MAX_STACKREF_SCRATCH: Final[i64] = 10,
     STACK_ARRAY_SIZE: Final[i64] = 8,
     UNREACHABLE_BACKOFF: Final[u16] = u16(15),
     BACKOFF_STEP: Final[i64] = 16,
     PY_MONITORING_EVENT_CALL: Final[i32] = 4,
     PY_MONITORING_EVENT_C_RETURN: Final[i32] = 16,
     PY_MONITORING_EVENT_C_RAISE: Final[i32] = 17;

def call_ptr_at(base: ptr[u8], offset: i64) -> ptr[u8];

def call_set_ptr_at(base: ptr[u8], offset: i64, value: ptr[u8]);

def call_ref_at(base: ptr[u8], offset: i64) -> u64;

def call_set_ref_at(base: ptr[u8], offset: i64, value: u64);

def call_i32_at(base: ptr[u8], offset: i64) -> i32;

def call_func_code(func_o: ptr[PyObject]) -> ptr[u8];

def call_is_function(op: ptr[PyObject]) -> bool;

def call_is_method(op: ptr[PyObject]) -> bool;

def call_method_func(method: ptr[PyObject]) -> ptr[PyObject];

def call_function_version(func_o: ptr[PyObject]) -> u32;

def call_link_frame(tstate: ptr, new_frame: ptr[u8]);

def call_leave_recursive_py(tstate: ptr);

def call_set_return_offset(frame: ptr[u8], this_instr: ptr[u16], next_instr: ptr[u16]);

def call_push_result(frame: ptr[u8], value: u64);

def call_has_stack_space(tstate: ptr, size: i64) -> bool;

def call_can_inline(tstate: ptr, callable_o: ptr[PyObject]) -> bool;

def call_function_locals(func_o: ptr[PyObject]) -> ptr[PyObject];

def call_frame_initialize(
    frame: ptr[u8],
    func: u64,
    locals: ptr[PyObject],
    code: ptr[u8],
    null_locals_from: i64,
    previous: ptr[u8]
);

def call_push_frame_unchecked(
    tstate: ptr, func: u64, null_locals_from: i64, previous: ptr[u8]
) -> ptr[u8];

def call_push_trampoline_unchecked(
    tstate: ptr, code: ptr[u8], stackdepth: i64, previous: ptr[u8]
) -> ptr[u8];

def call_frame_push_and_init_ex(
    tstate: ptr,
    func: u64,
    locals: ptr[PyObject],
    nargs: i64,
    callargs: ptr[PyObject],
    kwargs: ptr[PyObject],
    previous: ptr[u8]
) -> ptr[u8];

def call_vectorcall_refs(
    callable_o: ptr[PyObject],
    arguments: ptr[u64],
    total_args: i64,
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def call_c_events(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    callable_o: ptr[PyObject],
    arg: ptr[PyObject],
    res_o: ptr[PyObject]
) -> ptr[PyObject];

def call_first_arg(arguments: ptr[u64], total_args: i64) -> ptr[PyObject];

def call_expand_method(callable_self: ptr[u64]);

def call_maybe_expand_method(callable_self: ptr[u64]);

def call_specialize_nargs(oparg: i32, self_or_null: u64) -> i32;

def call_advance_counter(this_instr: ptr[u16], counter: u16);

def _SPECIALIZE_CALL(
    this_instr: ptr[u16], oparg: i32, counter: u16, callable: u64, self_or_null: u64
) -> i32;

def _MAYBE_EXPAND_METHOD(callable_self: ptr[u64]);

def _DO_CALL(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    next_instr: ptr[u16],
    oparg: i32,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    res: ptr[u64]
) -> i32;

def _DO_CALL_INSTRUMENTED(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    next_instr: ptr[u16],
    oparg: i32,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    res: ptr[u64]
) -> i32;

def _CHECK_FUNCTION_VERSION(func_version: u32, callable: u64) -> bool;

def _CHECK_FUNCTION_EXACT_ARGS(oparg: i32, callable: u64, self_or_null: u64) -> bool;

def _CHECK_STACK_SPACE(tstate: ptr, callable: u64) -> bool;

def _CHECK_RECURSION_REMAINING(tstate: ptr) -> bool;

def _INIT_CALL_PY_EXACT_ARGS(
    tstate: ptr,
    frame: ptr[u8],
    oparg: i32,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64]
) -> u64;

def _CHECK_METHOD_VERSION(func_version: u32, callable: u64, null: u64) -> bool;

def _CHECK_METHOD_EXACT_ARGS(oparg: i32, callable: u64) -> bool;

def _CHECK_METHOD_STACK_SPACE(tstate: ptr, callable: u64) -> bool;

def _INIT_CALL_BOUND_METHOD_EXACT_ARGS(callable_self: ptr[u64]);

def _EXPAND_METHOD(callable_self: ptr[u64]);

def _PY_FRAME_GENERAL(
    tstate: ptr,
    frame: ptr[u8],
    oparg: i32,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64]
) -> u64;

def _CHECK_IS_NOT_PY_CALLABLE(callable: u64) -> bool;

def _CALL_NON_PY_GENERAL(
    oparg: i32, callable: u64, self_or_null: u64, args: ptr[u64]
) -> u64;

def _CHECK_AND_ALLOCATE_OBJECT(
    tstate: ptr, type_version: u32, callable_self: ptr[u64]
) -> i32;

def _CREATE_INIT_FRAME(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    next_instr: ptr[u16],
    oparg: i32,
    init_fn: u64,
    self_: u64,
    args: ptr[u64]
) -> u64;

def EXIT_INIT_CHECK(should_be_none: u64) -> i32;

def _SPECIALIZE_CALL_KW(
    this_instr: ptr[u16], oparg: i32, counter: u16, callable: u64, self_or_null: u64
) -> i32;

def _MAYBE_EXPAND_METHOD_KW(callable_self: ptr[u64]);

def _DO_CALL_KW(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    next_instr: ptr[u16],
    oparg: i32,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    kwnames: u64,
    res: ptr[u64]
) -> i32;

def _DO_CALL_KW_INSTRUMENTED(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    next_instr: ptr[u16],
    oparg: i32,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    kwnames: u64,
    res: ptr[u64]
) -> i32;

def _CHECK_FUNCTION_VERSION_KW(func_version: u32, callable: u64) -> bool;

def _PY_FRAME_KW(
    tstate: ptr,
    frame: ptr[u8],
    oparg: i32,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    kwnames: u64
) -> u64;

def _CHECK_METHOD_VERSION_KW(func_version: u32, callable: u64, null: u64) -> bool;

def _EXPAND_METHOD_KW(callable_self: ptr[u64]);

def _CHECK_IS_NOT_PY_CALLABLE_KW(callable: u64) -> bool;

def _CALL_KW_NON_PY(
    oparg: i32, callable: u64, self_or_null: u64, args: ptr[u64], kwnames: u64
) -> u64;

def _MAKE_CALLARGS_A_TUPLE(tstate: ptr, func: u64, callargs: ptr[u64]) -> i32;

def _DO_CALL_FUNCTION_EX(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    next_instr: ptr[u16],
    func_st: u64,
    callargs_st: u64,
    kwargs_st: u64,
    result: ptr[u64]
) -> i32;

def _DO_CALL_FUNCTION_EX_INSTRUMENTED(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    func_st: u64,
    callargs_st: u64,
    kwargs_st: u64,
    result: ptr[u64]
) -> i32;

def RETURN_VALUE(tstate: ptr, frame: ptr[u8], retval: u64) -> ptr[u8];

def YIELD_VALUE(tstate: ptr, frame: ptr[u8], oparg: i32, retval: u64) -> ptr[u8];

def _MAKE_GENERATOR(frame: ptr[u8]) -> u64;

def _RETURN_GENERATOR(tstate: ptr, frame: ptr[u8], gen: u64) -> ptr[u8];

impl call_ptr_at(base: ptr[u8], offset: i64) -> ptr[u8] {
    return ptr[ptr[u8]](base + offset).view(1)[0];
}

impl call_set_ptr_at(base: ptr[u8], offset: i64, value: ptr[u8]) {
    ptr[ptr[u8]](base + offset).view(1)[0] = value;
}

impl call_ref_at(base: ptr[u8], offset: i64) -> u64 {
    return ptr[u64](base + offset).view(1)[0];
}

impl call_set_ref_at(base: ptr[u8], offset: i64, value: u64) {
    ptr[u64](base + offset).view(1)[0] = value;
}

impl call_i32_at(base: ptr[u8], offset: i64) -> i32 {
    return ptr[i32](base + offset).view(1)[0];
}

impl call_func_code(func_o: ptr[PyObject]) -> ptr[u8] {
    return call_ptr_at(ptr[u8](func_o), PyFunctionObject_CODE);
}

impl call_is_function(op: ptr[PyObject]) -> bool {
    return object_type(op) == ptr[PyTypeObject](addressof(PyFunction_Type));
}

impl call_is_method(op: ptr[PyObject]) -> bool {
    return object_type(op) == ptr[PyTypeObject](addressof(PyMethod_Type));
}

impl call_method_func(method: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[PyMethodObject](method).view(1)[0].im_func;
}

impl call_function_version(func_o: ptr[PyObject]) -> u32 {
    return ptr[u32](ptr[u8](func_o) + PyFunctionObject_VERSION).view(1)[0];
}

impl call_link_frame(tstate: ptr, new_frame: ptr[u8]) {
    call_set_ptr_at(ptr[u8](tstate), PyThreadState_CURRENT_FRAME, new_frame);
}

impl call_leave_recursive_py(tstate: ptr) {
    remaining = ptr[i32](ptr[u8](tstate) + PyThreadState_PY_RECURSION_REMAINING);
    remaining.view(1)[0] = remaining.view(1)[0] + 1;
}

impl call_set_return_offset(
    frame: ptr[u8], this_instr: ptr[u16], next_instr: ptr[u16]
) {
    ptr[u16](frame + _PyInterpreterFrame_RETURN_OFFSET).view(1)[0] = u16.wrap(
        (int(next_instr) - int(this_instr)) // 2
    );
}

impl call_push_result(frame: ptr[u8], value: u64) {
    sp = frame_stackpointer(frame);
    sp.view(1)[0] = value;
    frame_set_stackpointer(frame, sp + 1);
}

impl call_has_stack_space(tstate: ptr, size: i64) -> bool {
    top = int(call_ptr_at(ptr[u8](tstate), PyThreadState_DATASTACK_TOP));
    limit = int(call_ptr_at(ptr[u8](tstate), PyThreadState_DATASTACK_LIMIT));
    return top != 0 and size < (limit - top) // 8;
}

impl call_can_inline(tstate: ptr, callable_o: ptr[PyObject]) -> bool {
    return call_is_function(callable_o)
        and _CHECK_PEP_523(tstate)
        and int(call_ptr_at(ptr[u8](callable_o), PyFunctionObject_VECTORCALL))
            == int(ptr(_PyFunction_Vectorcall));
}

impl call_function_locals(func_o: ptr[PyObject]) -> ptr[PyObject] {
    code = call_func_code(func_o);
    if (call_i32_at(code, PyCodeObject_FLAGS) & CO_OPTIMIZED) != 0 {
        return NULL;
    }
    return object_new_ref(
        ptr[PyObject](call_ptr_at(ptr[u8](func_o), PyFunctionObject_GLOBALS))
    );
}

impl call_frame_initialize(
    frame: ptr[u8],
    func: u64,
    locals: ptr[PyObject],
    code: ptr[u8],
    null_locals_from: i64,
    previous: ptr[u8]
) {
    func_o = ptr[u8](sr_borrow(func));
    call_set_ptr_at(frame, _PyInterpreterFrame_PREVIOUS, previous);
    call_set_ref_at(frame, _PyInterpreterFrame_F_FUNCOBJ, func);
    call_set_ref_at(
        frame, _PyInterpreterFrame_F_EXECUTABLE, sr_new(ptr[PyObject](code))
    );
    call_set_ptr_at(
        frame,
        _PyInterpreterFrame_F_BUILTINS,
        call_ptr_at(func_o, PyFunctionObject_BUILTINS)
    );
    call_set_ptr_at(
        frame,
        _PyInterpreterFrame_F_GLOBALS,
        call_ptr_at(func_o, PyFunctionObject_GLOBALS)
    );
    call_set_ptr_at(frame, _PyInterpreterFrame_F_LOCALS, ptr[u8](locals));
    nlocalsplus = i64(call_i32_at(code, PyCodeObject_NLOCALSPLUS));
    localsplus = ptr[u64](frame + _PyInterpreterFrame_LOCALSPLUS);
    call_set_ptr_at(
        frame, _PyInterpreterFrame_STACKPOINTER, ptr[u8](localsplus + nlocalsplus)
    );
    call_set_ptr_at(frame, _PyInterpreterFrame_FRAME_OBJ, ptr[u8]());
    call_set_ptr_at(
        frame, _PyInterpreterFrame_INSTR_PTR, code + PyCodeObject_CODE_ADAPTIVE
    );
    ptr[u16](frame + _PyInterpreterFrame_RETURN_OFFSET).view(1)[0] = u16(0);
    (frame + _PyInterpreterFrame_OWNER).view(1)[0] = u8(FRAME_OWNED_BY_THREAD);
    (frame + _PyInterpreterFrame_VISITED).view(1)[0] = u8(0);
    i = null_locals_from;
    while i < nlocalsplus {
        (localsplus + i).view(1)[0] = SR_NULL;
        i += 1;
    }
}

impl call_push_frame_unchecked(
    tstate: ptr, func: u64, null_locals_from: i64, previous: ptr[u8]
) -> ptr[u8] {
    code = call_func_code(sr_borrow(func));
    top_slot = ptr[ptr[u64]](ptr[u8](tstate) + PyThreadState_DATASTACK_TOP);
    top = top_slot.view(1)[0];
    top_slot.view(1)[0] = top + i64(call_i32_at(code, PyCodeObject_FRAMESIZE));
    new_frame = ptr[u8](top);
    call_frame_initialize(new_frame, func, NULL, code, null_locals_from, previous);
    return new_frame;
}

impl call_push_trampoline_unchecked(
    tstate: ptr, code: ptr[u8], stackdepth: i64, previous: ptr[u8]
) -> ptr[u8] {
    top_slot = ptr[ptr[u64]](ptr[u8](tstate) + PyThreadState_DATASTACK_TOP);
    top = top_slot.view(1)[0];
    top_slot.view(1)[0] = top + i64(call_i32_at(code, PyCodeObject_FRAMESIZE));
    frame = ptr[u8](top);
    call_set_ptr_at(frame, _PyInterpreterFrame_PREVIOUS, previous);
    call_set_ref_at(frame, _PyInterpreterFrame_F_FUNCOBJ, sr_none());
    call_set_ref_at(
        frame, _PyInterpreterFrame_F_EXECUTABLE, sr_new(ptr[PyObject](code))
    );
    call_set_ptr_at(frame, _PyInterpreterFrame_F_LOCALS, ptr[u8]());
    nlocalsplus = i64(call_i32_at(code, PyCodeObject_NLOCALSPLUS));
    localsplus = ptr[u64](frame + _PyInterpreterFrame_LOCALSPLUS);
    call_set_ptr_at(
        frame,
        _PyInterpreterFrame_STACKPOINTER,
        ptr[u8](localsplus + (nlocalsplus + stackdepth))
    );
    call_set_ptr_at(frame, _PyInterpreterFrame_FRAME_OBJ, ptr[u8]());
    call_set_ptr_at(
        frame, _PyInterpreterFrame_INSTR_PTR, code + PyCodeObject_CODE_ADAPTIVE
    );
    (frame + _PyInterpreterFrame_OWNER).view(1)[0] = u8(FRAME_OWNED_BY_THREAD);
    (frame + _PyInterpreterFrame_VISITED).view(1)[0] = u8(0);
    ptr[u16](frame + _PyInterpreterFrame_RETURN_OFFSET).view(1)[0] = u16(0);
    return frame;
}

impl call_frame_push_and_init_ex(
    tstate: ptr,
    func: u64,
    locals: ptr[PyObject],
    nargs: i64,
    callargs: ptr[PyObject],
    kwargs: ptr[PyObject],
    previous: ptr[u8]
) -> ptr[u8] {
    has_dict = False;
    if kwargs and ptr[PyDictObject](kwargs).view(1)[0].ma_used > 0 {
        has_dict = True;
    }
    scratch: own OpsCallScratch = OpsCallScratch();
    stack_array = ptr[u64](jacpy_stack_address(&mut scratch));
    kwnames = NULL;
    newargs = stack_array;
    object_array = ptr[ptr[PyObject]]();
    if has_dict {
        kwnames_slot = ptr[ptr[PyObject]](stack_array);
        kwnames_slot.view(1)[0] = NULL;
        object_array = _PyStack_UnpackDict(
            ptr[PyThreadState](tstate),
            tuple_items(callargs),
            nargs,
            kwargs,
            kwnames_slot
        );
        if not object_array {
            sr_close(func);
            object_decref(callargs);
            object_xdecref(kwargs);
            return ptr[u8]();
        }
        kwnames = kwnames_slot.view(1)[0];
        total_args = nargs + ptr[PyDictObject](kwargs).view(1)[0].ma_used;
        newargs = ptr[u64](object_array);
        for i in range(total_args) {
            (newargs + i).view(1)[0] = sr_steal((object_array + i).view(1)[0]);
        }
    } else {
        if nargs > STACK_ARRAY_SIZE {
            newargs = ptr[u64](PyMem_Malloc(u64(8 * nargs)));
            if not newargs {
                PyErr_NoMemory();
                sr_close(func);
                object_decref(callargs);
                object_xdecref(kwargs);
                return ptr[u8]();
            }
        }
        for i in range(nargs) {
            (newargs + i).view(1)[0] = sr_new(tuple_get_item(callargs, i));
        }
    }
    new_frame = _PyEvalFramePushAndInit(
        ptr[PyThreadState](tstate), func, locals, newargs, u64(nargs), kwnames, previous
    );
    if has_dict {
        _PyStack_UnpackDict_FreeNoDecRef(object_array, kwnames);
    } elif nargs > STACK_ARRAY_SIZE {
        PyMem_Free(ptr(newargs));
    }
    object_decref(callargs);
    object_xdecref(kwargs);
    return new_frame;
}

impl call_vectorcall_refs(
    callable_o: ptr[PyObject],
    arguments: ptr[u64],
    total_args: i64,
    nargs: i64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    scratch: own OpsCallScratch = OpsCallScratch();
    temp = ptr[ptr[PyObject]](jacpy_stack_address(&mut scratch));
    args_o = temp + 1;
    if total_args > MAX_STACKREF_SCRATCH {
        block = ptr[ptr[PyObject]](PyMem_Malloc(u64((total_args + 1) * 8)));
        if not block {
            return NULL;
        }
        args_o = block + 1;
    }
    for i in range(total_args) {
        (args_o + i).view(1)[0] = sr_borrow((arguments + i).view(1)[0]);
    }
    res_o = PyObject_Vectorcall(
        callable_o, args_o, u64(nargs) | PY_VECTORCALL_ARGUMENTS_OFFSET, kwnames
    );
    if int(args_o - 1) != int(temp) {
        PyMem_Free(ptr(args_o - 1));
    }
    return res_o;
}

impl call_c_events(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    callable_o: ptr[PyObject],
    arg: ptr[PyObject],
    res_o: ptr[PyObject]
) -> ptr[PyObject] {
    if not res_o {
        _Py_call_instrumentation_exc2(
            ptr[PyThreadState](tstate),
            PY_MONITORING_EVENT_C_RAISE,
            frame,
            this_instr,
            callable_o,
            arg
        );
        return res_o;
    }
    err = _Py_call_instrumentation_2args(
        ptr[PyThreadState](tstate),
        PY_MONITORING_EVENT_C_RETURN,
        frame,
        this_instr,
        callable_o,
        arg
    );
    if err < 0 {
        object_decref(res_o);
        return NULL;
    }
    return res_o;
}

impl call_first_arg(arguments: ptr[u64], total_args: i64) -> ptr[PyObject] {
    if total_args == 0 {
        return addressof(_PyInstrumentation_MISSING);
    }
    return sr_borrow(arguments.view(1)[0]);
}

impl call_expand_method(callable_self: ptr[u64]) {
    callable = callable_self.view(1)[0];
    method = ptr[PyMethodObject](sr_borrow(callable));
    (callable_self + 1).view(1)[0] = sr_new(method.view(1)[0].im_self);
    callable_self.view(1)[0] = sr_new(method.view(1)[0].im_func);
    sr_close(callable);
}

impl call_maybe_expand_method(callable_self: ptr[u64]) {
    if call_is_method(sr_borrow(callable_self.view(1)[0]))
        and sr_is_null((callable_self + 1).view(1)[0]) {
        call_expand_method(callable_self);
    }
}

impl call_specialize_nargs(oparg: i32, self_or_null: u64) -> i32 {
    if sr_is_null(self_or_null) {
        return oparg;
    }
    return oparg + 1;
}

impl call_advance_counter(this_instr: ptr[u16], counter: u16) {
    (this_instr + 1).view(1)[0] = u16.wrap(i64(counter) - BACKOFF_STEP);
}

impl _SPECIALIZE_CALL(
    this_instr: ptr[u16], oparg: i32, counter: u16, callable: u64, self_or_null: u64
) -> i32 {
    if counter < UNREACHABLE_BACKOFF {
        _Py_Specialize_Call(
            callable, this_instr, call_specialize_nargs(oparg, self_or_null)
        );
        return ST_REDISPATCH;
    }
    call_advance_counter(this_instr, counter);
    return ST_OK;
}

impl _MAYBE_EXPAND_METHOD(callable_self: ptr[u64]) {
    call_maybe_expand_method(callable_self);
}

impl _DO_CALL(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    next_instr: ptr[u16],
    oparg: i32,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    res: ptr[u64]
) -> i32 {
    callable_o = sr_borrow(callable);
    total_args = i64(oparg);
    arguments = args;
    if not sr_is_null(self_or_null) {
        arguments = args - 1;
        total_args += 1;
    }
    if call_can_inline(tstate, callable_o) {
        new_frame = _PyEvalFramePushAndInit(
            ptr[PyThreadState](tstate),
            callable,
            call_function_locals(callable_o),
            arguments,
            u64(total_args),
            NULL,
            frame
        );
        if not new_frame {
            return ST_ERROR_TAKEN;
        }
        call_set_return_offset(frame, this_instr, next_instr);
        call_link_frame(tstate, new_frame);
        return ST_INLINED;
    }
    res_o = call_vectorcall_refs(callable_o, arguments, total_args, total_args, NULL);
    if not res_o {
        return ST_ERROR;
    }
    res.view(1)[0] = sr_steal(res_o);
    return ST_OK;
}

impl _DO_CALL_INSTRUMENTED(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    next_instr: ptr[u16],
    oparg: i32,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    res: ptr[u64]
) -> i32 {
    callable_o = sr_borrow(callable);
    total_args = i64(oparg);
    arguments = args;
    if not sr_is_null(self_or_null) {
        arguments = args - 1;
        total_args += 1;
    }
    if call_can_inline(tstate, callable_o) {
        new_frame = _PyEvalFramePushAndInit(
            ptr[PyThreadState](tstate),
            callable,
            call_function_locals(callable_o),
            arguments,
            u64(total_args),
            NULL,
            frame
        );
        if not new_frame {
            return ST_ERROR_TAKEN;
        }
        call_set_return_offset(frame, this_instr, next_instr);
        call_link_frame(tstate, new_frame);
        return ST_INLINED;
    }
    res_o = call_vectorcall_refs(callable_o, arguments, total_args, total_args, NULL);
    if res_o or PyErr_Occurred() {
        res_o = call_c_events(
            tstate,
            frame,
            this_instr,
            callable_o,
            call_first_arg(arguments, total_args),
            res_o
        );
    }
    if not res_o {
        return ST_ERROR;
    }
    res.view(1)[0] = sr_steal(res_o);
    return ST_OK;
}

impl _CHECK_FUNCTION_VERSION(func_version: u32, callable: u64) -> bool {
    callable_o = sr_borrow(callable);
    return call_is_function(callable_o)
        and call_function_version(callable_o) == func_version;
}

impl _CHECK_FUNCTION_EXACT_ARGS(oparg: i32, callable: u64, self_or_null: u64) -> bool {
    code = call_func_code(sr_borrow(callable));
    return call_i32_at(code, PyCodeObject_ARGCOUNT)
        == call_specialize_nargs(oparg, self_or_null);
}

impl _CHECK_STACK_SPACE(tstate: ptr, callable: u64) -> bool {
    code = call_func_code(sr_borrow(callable));
    return call_has_stack_space(tstate, i64(call_i32_at(code, PyCodeObject_FRAMESIZE)));
}

impl _CHECK_RECURSION_REMAINING(tstate: ptr) -> bool {
    return ptr[i32](ptr[u8](tstate) + PyThreadState_PY_RECURSION_REMAINING).view(1)[0]
        > 1;
}

impl _INIT_CALL_PY_EXACT_ARGS(
    tstate: ptr,
    frame: ptr[u8],
    oparg: i32,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64]
) -> u64 {
    has_self: i64 = 0;
    if not sr_is_null(self_or_null) {
        has_self = 1;
    }
    new_frame = call_push_frame_unchecked(
        tstate, callable, i64(oparg) + has_self, frame
    );
    localsplus = ptr[u64](new_frame + _PyInterpreterFrame_LOCALSPLUS);
    localsplus.view(1)[0] = self_or_null;
    first_non_self_local = localsplus + has_self;
    for i in range(i64(oparg)) {
        (first_non_self_local + i).view(1)[0] = (args + i).view(1)[0];
    }
    return u64(int(new_frame));
}

impl _CHECK_METHOD_VERSION(func_version: u32, callable: u64, null: u64) -> bool {
    callable_o = sr_borrow(callable);
    if not call_is_method(callable_o) {
        return False;
    }
    func = call_method_func(callable_o);
    return call_is_function(func)
        and call_function_version(func) == func_version
        and sr_is_null(null);
}

impl _CHECK_METHOD_EXACT_ARGS(oparg: i32, callable: u64) -> bool {
    code = call_func_code(call_method_func(sr_borrow(callable)));
    return call_i32_at(code, PyCodeObject_ARGCOUNT) == oparg + 1;
}

impl _CHECK_METHOD_STACK_SPACE(tstate: ptr, callable: u64) -> bool {
    code = call_func_code(call_method_func(sr_borrow(callable)));
    return call_has_stack_space(tstate, i64(call_i32_at(code, PyCodeObject_FRAMESIZE)));
}

impl _INIT_CALL_BOUND_METHOD_EXACT_ARGS(callable_self: ptr[u64]) {
    call_expand_method(callable_self);
}

impl _EXPAND_METHOD(callable_self: ptr[u64]) {
    call_expand_method(callable_self);
}

impl _PY_FRAME_GENERAL(
    tstate: ptr,
    frame: ptr[u8],
    oparg: i32,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64]
) -> u64 {
    total_args = i64(oparg);
    arguments = args;
    if not sr_is_null(self_or_null) {
        arguments = args - 1;
        total_args += 1;
    }
    temp = _PyEvalFramePushAndInit(
        ptr[PyThreadState](tstate),
        callable,
        call_function_locals(sr_borrow(callable)),
        arguments,
        u64(total_args),
        NULL,
        frame
    );
    if not temp {
        return u64(0);
    }
    return u64(int(temp));
}

impl _CHECK_IS_NOT_PY_CALLABLE(callable: u64) -> bool {
    callable_o = sr_borrow(callable);
    return not call_is_function(callable_o) and not call_is_method(callable_o);
}

impl _CALL_NON_PY_GENERAL(
    oparg: i32, callable: u64, self_or_null: u64, args: ptr[u64]
) -> u64 {
    total_args = i64(oparg);
    arguments = args;
    if not sr_is_null(self_or_null) {
        arguments = args - 1;
        total_args += 1;
    }
    res_o = call_vectorcall_refs(
        sr_borrow(callable), arguments, total_args, total_args, NULL
    );
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl _CHECK_AND_ALLOCATE_OBJECT(
    tstate: ptr, type_version: u32, callable_self: ptr[u64]
) -> i32 {
    callable = callable_self.view(1)[0];
    callable_o = sr_borrow(callable);
    if not sr_is_null((callable_self + 1).view(1)[0]) {
        return ST_DEOPT;
    }
    if not type_has_feature(object_type(callable_o), Py_TPFLAGS_TYPE_SUBCLASS) {
        return ST_DEOPT;
    }
    tp = ptr[PyTypeObject](callable_o);
    if tp.view(1)[0].tp_version_tag != type_version {
        return ST_DEOPT;
    }
    init_func = ptr[PyObject](
        call_ptr_at(ptr[u8](callable_o), PyHeapTypeObject_SPEC_CACHE_INIT)
    );
    code = call_func_code(init_func);
    cleanup = ptr[u8](addressof(_Py_InitCleanup));
    if not call_has_stack_space(
        tstate,
        i64(call_i32_at(code, PyCodeObject_FRAMESIZE))
            + i64(call_i32_at(cleanup, PyCodeObject_FRAMESIZE))
    ) {
        return ST_DEOPT;
    }
    self_o = PyType_GenericAlloc(callable_o, 0);
    if not self_o {
        return ST_ERROR;
    }
    (callable_self + 1).view(1)[0] = sr_steal(self_o);
    callable_self.view(1)[0] = sr_new(init_func);
    sr_close(callable);
    return ST_OK;
}

impl _CREATE_INIT_FRAME(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    next_instr: ptr[u16],
    oparg: i32,
    init_fn: u64,
    self_: u64,
    args: ptr[u64]
) -> u64 {
    shim = call_push_trampoline_unchecked(
        tstate, ptr[u8](addressof(_Py_InitCleanup)), 1, frame
    );
    ptr[u64](shim + _PyInterpreterFrame_LOCALSPLUS).view(1)[0] = sr_dup(self_);
    temp = _PyEvalFramePushAndInit(
        ptr[PyThreadState](tstate),
        init_fn,
        NULL,
        args - 1,
        u64(i64(oparg) + 1),
        NULL,
        shim
    );
    if not temp {
        _PyEval_FrameClearAndPop(ptr[PyThreadState](tstate), shim);
        return u64(0);
    }
    call_set_return_offset(frame, this_instr, next_instr);
    remaining = ptr[i32](ptr[u8](tstate) + PyThreadState_PY_RECURSION_REMAINING);
    remaining.view(1)[0] = remaining.view(1)[0] - 1;
    return u64(int(temp));
}

impl EXIT_INIT_CHECK(should_be_none: u64) -> i32 {
    if not sr_is_none(should_be_none) {
        PyErr_Format(
            PyExc_TypeError,
            ptr[u8]("__init__() should return None, not '%.200s'"),
            sr_type(should_be_none).view(1)[0].tp_name
        );
        sr_close(should_be_none);
        return ST_ERROR;
    }
    return ST_OK;
}

impl _SPECIALIZE_CALL_KW(
    this_instr: ptr[u16], oparg: i32, counter: u16, callable: u64, self_or_null: u64
) -> i32 {
    if counter < UNREACHABLE_BACKOFF {
        _Py_Specialize_CallKw(
            callable, this_instr, call_specialize_nargs(oparg, self_or_null)
        );
        return ST_REDISPATCH;
    }
    call_advance_counter(this_instr, counter);
    return ST_OK;
}

impl _MAYBE_EXPAND_METHOD_KW(callable_self: ptr[u64]) {
    call_maybe_expand_method(callable_self);
}

impl _DO_CALL_KW(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    next_instr: ptr[u16],
    oparg: i32,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    kwnames: u64,
    res: ptr[u64]
) -> i32 {
    callable_o = sr_borrow(callable);
    kwnames_o = sr_borrow(kwnames);
    total_args = i64(oparg);
    arguments = args;
    if not sr_is_null(self_or_null) {
        arguments = args - 1;
        total_args += 1;
    }
    positional_args = total_args - object_size(kwnames_o);
    if call_can_inline(tstate, callable_o) {
        new_frame = _PyEvalFramePushAndInit(
            ptr[PyThreadState](tstate),
            callable,
            call_function_locals(callable_o),
            arguments,
            u64(positional_args),
            kwnames_o,
            frame
        );
        sr_close(kwnames);
        if not new_frame {
            return ST_ERROR_TAKEN;
        }
        call_set_return_offset(frame, this_instr, next_instr);
        call_link_frame(tstate, new_frame);
        return ST_INLINED;
    }
    res_o = call_vectorcall_refs(
        callable_o, arguments, total_args, positional_args, kwnames_o
    );
    if not res_o {
        return ST_ERROR;
    }
    res.view(1)[0] = sr_steal(res_o);
    return ST_OK;
}

impl _DO_CALL_KW_INSTRUMENTED(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    next_instr: ptr[u16],
    oparg: i32,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    kwnames: u64,
    res: ptr[u64]
) -> i32 {
    callable_o = sr_borrow(callable);
    kwnames_o = sr_borrow(kwnames);
    total_args = i64(oparg);
    arguments = args;
    if not sr_is_null(self_or_null) {
        arguments = args - 1;
        total_args += 1;
    }
    positional_args = total_args - object_size(kwnames_o);
    if call_can_inline(tstate, callable_o) {
        new_frame = _PyEvalFramePushAndInit(
            ptr[PyThreadState](tstate),
            callable,
            call_function_locals(callable_o),
            arguments,
            u64(positional_args),
            kwnames_o,
            frame
        );
        sr_close(kwnames);
        if not new_frame {
            return ST_ERROR_TAKEN;
        }
        call_set_return_offset(frame, this_instr, next_instr);
        call_link_frame(tstate, new_frame);
        return ST_INLINED;
    }
    res_o = call_vectorcall_refs(
        callable_o, arguments, total_args, positional_args, kwnames_o
    );
    if res_o or PyErr_Occurred() {
        res_o = call_c_events(
            tstate,
            frame,
            this_instr,
            callable_o,
            call_first_arg(arguments, total_args),
            res_o
        );
    }
    if not res_o {
        return ST_ERROR;
    }
    res.view(1)[0] = sr_steal(res_o);
    return ST_OK;
}

impl _CHECK_FUNCTION_VERSION_KW(func_version: u32, callable: u64) -> bool {
    callable_o = sr_borrow(callable);
    return call_is_function(callable_o)
        and call_function_version(callable_o) == func_version;
}

impl _PY_FRAME_KW(
    tstate: ptr,
    frame: ptr[u8],
    oparg: i32,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    kwnames: u64
) -> u64 {
    total_args = i64(oparg);
    arguments = args;
    if not sr_is_null(self_or_null) {
        arguments = args - 1;
        total_args += 1;
    }
    kwnames_o = sr_borrow(kwnames);
    positional_args = total_args - object_size(kwnames_o);
    temp = _PyEvalFramePushAndInit(
        ptr[PyThreadState](tstate),
        callable,
        call_function_locals(sr_borrow(callable)),
        arguments,
        u64(positional_args),
        kwnames_o,
        frame
    );
    sr_close(kwnames);
    if not temp {
        return u64(0);
    }
    return u64(int(temp));
}

impl _CHECK_METHOD_VERSION_KW(func_version: u32, callable: u64, null: u64) -> bool {
    callable_o = sr_borrow(callable);
    if not call_is_method(callable_o) {
        return False;
    }
    func = call_method_func(callable_o);
    return call_is_function(func)
        and call_function_version(func) == func_version
        and sr_is_null(null);
}

impl _EXPAND_METHOD_KW(callable_self: ptr[u64]) {
    call_expand_method(callable_self);
}

impl _CHECK_IS_NOT_PY_CALLABLE_KW(callable: u64) -> bool {
    callable_o = sr_borrow(callable);
    return not call_is_function(callable_o) and not call_is_method(callable_o);
}

impl _CALL_KW_NON_PY(
    oparg: i32, callable: u64, self_or_null: u64, args: ptr[u64], kwnames: u64
) -> u64 {
    total_args = i64(oparg);
    arguments = args;
    if not sr_is_null(self_or_null) {
        arguments = args - 1;
        total_args += 1;
    }
    kwnames_o = sr_borrow(kwnames);
    res_o = call_vectorcall_refs(
        sr_borrow(callable),
        arguments,
        total_args,
        total_args - object_size(kwnames_o),
        kwnames_o
    );
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl _MAKE_CALLARGS_A_TUPLE(tstate: ptr, func: u64, callargs: ptr[u64]) -> i32 {
    callargs_o = sr_borrow(callargs.view(1)[0]);
    if object_type(callargs_o) != ptr[PyTypeObject](addressof(PyTuple_Type)) {
        err = _Py_Check_ArgsIterable(
            ptr[PyThreadState](tstate), sr_borrow(func), callargs_o
        );
        if err < 0 {
            return ST_ERROR;
        }
        tuple_o = PySequence_Tuple(callargs_o);
        if not tuple_o {
            return ST_ERROR;
        }
        temp = callargs.view(1)[0];
        callargs.view(1)[0] = sr_steal(tuple_o);
        sr_close(temp);
    }
    return ST_OK;
}

impl _DO_CALL_FUNCTION_EX(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    next_instr: ptr[u16],
    func_st: u64,
    callargs_st: u64,
    kwargs_st: u64,
    result: ptr[u64]
) -> i32 {
    func = sr_borrow(func_st);
    if call_can_inline(tstate, func) {
        callargs = sr_as_steal(callargs_st);
        kwargs = NULL;
        if not sr_is_null(kwargs_st) {
            kwargs = sr_as_steal(kwargs_st);
        }
        new_frame = call_frame_push_and_init_ex(
            tstate,
            func_st,
            call_function_locals(func),
            object_size(callargs),
            callargs,
            kwargs,
            frame
        );
        if not new_frame {
            return ST_ERROR_TAKEN;
        }
        call_set_return_offset(frame, this_instr, next_instr);
        call_link_frame(tstate, new_frame);
        return ST_INLINED;
    }
    result_o = PyObject_Call(func, sr_borrow(callargs_st), sr_borrow(kwargs_st));
    if not result_o {
        return ST_ERROR;
    }
    result.view(1)[0] = sr_steal(result_o);
    return ST_OK;
}

impl _DO_CALL_FUNCTION_EX_INSTRUMENTED(
    tstate: ptr,
    frame: ptr[u8],
    this_instr: ptr[u16],
    func_st: u64,
    callargs_st: u64,
    kwargs_st: u64,
    result: ptr[u64]
) -> i32 {
    func = sr_borrow(func_st);
    callargs = sr_borrow(callargs_st);
    kwargs = sr_borrow(kwargs_st);
    arg = addressof(_PyInstrumentation_MISSING);
    if object_size(callargs) > 0 {
        arg = tuple_get_item(callargs, 0);
    }
    err = _Py_call_instrumentation_2args(
        ptr[PyThreadState](tstate),
        PY_MONITORING_EVENT_CALL,
        frame,
        this_instr,
        func,
        arg
    );
    if err != 0 {
        return ST_ERROR;
    }
    result_o = PyObject_Call(func, callargs, kwargs);
    if not call_is_function(func) and not call_is_method(func) {
        result_o = call_c_events(tstate, frame, this_instr, func, arg, result_o);
    }
    if not result_o {
        return ST_ERROR;
    }
    result.view(1)[0] = sr_steal(result_o);
    return ST_OK;
}

impl RETURN_VALUE(tstate: ptr, frame: ptr[u8], retval: u64) -> ptr[u8] {
    temp = sr_make_heap_safe(retval);
    call_leave_recursive_py(tstate);
    caller = call_ptr_at(frame, _PyInterpreterFrame_PREVIOUS);
    call_link_frame(tstate, caller);
    _PyEval_FrameClearAndPop(ptr[PyThreadState](tstate), frame);
    call_push_result(caller, temp);
    return caller;
}

impl YIELD_VALUE(tstate: ptr, frame: ptr[u8], oparg: i32, retval: u64) -> ptr[u8] {
    frame_set_instr_ptr(frame, frame_instr_ptr(frame) + 1);
    gen = frame - PyGenObject_IFRAME;
    ptr[i8](gen + PyGenObject_FRAME_STATE).view(1)[0] = i8(FRAME_SUSPENDED + oparg);
    call_set_ptr_at(
        ptr[u8](tstate),
        PyThreadState_EXC_INFO,
        call_ptr_at(gen, PyGenObject_EXC_PREVIOUS_ITEM)
    );
    call_set_ptr_at(gen, PyGenObject_EXC_PREVIOUS_ITEM, ptr[u8]());
    call_leave_recursive_py(tstate);
    caller = call_ptr_at(frame, _PyInterpreterFrame_PREVIOUS);
    call_link_frame(tstate, caller);
    call_set_ptr_at(frame, _PyInterpreterFrame_PREVIOUS, ptr[u8]());
    call_push_result(caller, sr_make_heap_safe(retval));
    return caller;
}

impl _MAKE_GENERATOR(frame: ptr[u8]) -> u64 {
    func = sr_borrow(call_ref_at(frame, _PyInterpreterFrame_F_FUNCOBJ));
    gen = _Py_MakeCoro(func);
    if not gen {
        return u64(0);
    }
    return sr_steal_mortal(gen);
}

impl _RETURN_GENERATOR(tstate: ptr, frame: ptr[u8], gen: u64) -> ptr[u8] {
    gen_o = ptr[u8](sr_borrow(gen));
    gen_frame = gen_o + PyGenObject_IFRAME;
    frame_set_instr_ptr(frame, frame_instr_ptr(frame) + 1);
    iframe_copy(frame, gen_frame);
    ptr[i8](gen_o + PyGenObject_FRAME_STATE).view(1)[0] = i8(FRAME_CREATED);
    (gen_frame + _PyInterpreterFrame_OWNER).view(1)[0] = u8(FRAME_OWNED_BY_GENERATOR);
    call_leave_recursive_py(tstate);
    prev = call_ptr_at(frame, _PyInterpreterFrame_PREVIOUS);
    _PyThreadState_PopFrame(ptr[PyThreadState](tstate), frame);
    call_link_frame(tstate, prev);
    call_push_result(prev, gen);
    return prev;
}
