import from c {
    glob PyExc_NameError: ptr[PyObject]; def PyObject_Length(o: ptr[PyObject]) -> i64;  def PyFunction_New(
        code: ptr[PyObject], globals: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyFunction_SetVersion(
        func: ptr[PyObject], version: u32
    );  def PyMapping_GetOptionalItem(
        obj_: ptr[PyObject], key: ptr[PyObject], result: &mut ptr[PyObject]
    ) -> i32;  def _PyList_AppendTakeRefListResize(
        op: ptr[PyObject], newitem: ptr[PyObject]
    ) -> i32;  def _Py_ReachedRecursionLimitWithMargin(
        tstate: ptr[PyThreadState], margin_count: i32
    ) -> i32;  obj CallnativeMethO {
        has ml_name: ptr[u8] = ptr[u8](),
            ml_meth: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            ml_flags: i32 = 0,
            ml_doc: ptr[u8] = ptr[u8]();
    }  obj CallnativeMethFast {
        has ml_name: ptr[u8] = ptr[u8](),
            ml_meth:
                Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]] = 0,
            ml_flags: i32 = 0,
            ml_doc: ptr[u8] = ptr[u8]();
    }  obj CallnativeMethFastKw {
        has ml_name: ptr[u8] = ptr[u8](),
            ml_meth:
                Callable[
                    [ptr[PyObject], ptr[ptr[PyObject]], i64, ptr[PyObject]],
                    ptr[PyObject]
                ] = 0,
            ml_flags: i32 = 0,
            ml_doc: ptr[u8] = ptr[u8]();
    }  obj CallnativeScratch {
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
    }  def jacpy_stack_address(slots: &mut CallnativeScratch) -> int;
}

glob:priv CALLNATIVE_MAX_STACKREF_SCRATCH: i64 = 10,
     CALLNATIVE_MAKE_FUNCTION_DEFAULTS: i32 = 1,
     CALLNATIVE_MAKE_FUNCTION_KWDEFAULTS: i32 = 2,
     CALLNATIVE_MAKE_FUNCTION_ANNOTATIONS: i32 = 4,
     CALLNATIVE_MAKE_FUNCTION_CLOSURE: i32 = 8,
     CALLNATIVE_MAKE_FUNCTION_ANNOTATE: i32 = 16;

def callnative_cached_callable(tstate: ptr, offset: i64) -> ptr[PyObject];

def callnative_recursion_reached(tstate: ptr) -> bool;

def callnative_args_from_stack(
    input_: ptr[u64], nargs: i64, scratch: ptr[ptr[PyObject]]
) -> ptr[ptr[PyObject]];

def callnative_args_free(array: ptr[ptr[PyObject]], scratch: ptr[ptr[PyObject]]);

def callnative_is_cfunction(callable: u64) -> bool;

def callnative_is_method_descr(callable: u64) -> bool;

def callnative_descr_method(callable_o: ptr[PyObject]) -> ptr[PyMethodDef];

def callnative_descr_type(callable_o: ptr[PyObject]) -> ptr[PyTypeObject];

def callnative_function_attribute_offset(oparg: i32) -> i64;

def _GUARD_NOS_NULL(null: u64) -> bool;

def _GUARD_CALLABLE_TYPE_1(callable: u64) -> bool;

def _GUARD_CALLABLE_STR_1(callable: u64) -> bool;

def _GUARD_CALLABLE_TUPLE_1(callable: u64) -> bool;

def _GUARD_CALLABLE_LEN(tstate: ptr, callable: u64) -> bool;

def _CALL_TYPE_1(arg: u64) -> u64;

def _CALL_STR_1(arg: u64) -> u64;

def _CALL_TUPLE_1(arg: u64) -> u64;

def _CALL_LEN(arg: u64) -> u64;

def _CALL_BUILTIN_CLASS(
    callable: u64, self_or_null: u64, args: ptr[u64], oparg: i32, res: ptr[u64]
) -> i32;

def _CALL_BUILTIN_O(
    tstate: ptr,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    oparg: i32,
    res: ptr[u64]
) -> i32;

def _CALL_BUILTIN_FAST(
    callable: u64, self_or_null: u64, args: ptr[u64], oparg: i32, res: ptr[u64]
) -> i32;

def _CALL_BUILTIN_FAST_WITH_KEYWORDS(
    callable: u64, self_or_null: u64, args: ptr[u64], oparg: i32, res: ptr[u64]
) -> i32;

def CALL_ISINSTANCE(
    tstate: ptr,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    oparg: i32,
    res: ptr[u64]
) -> i32;

def _CALL_LIST_APPEND(tstate: ptr, callable: u64, self_: u64, arg: u64) -> i32;

def _SKIP_POP_TOP -> i64;

def _CALL_METHOD_DESCRIPTOR_O(
    tstate: ptr,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    oparg: i32,
    res: ptr[u64]
) -> i32;

def _CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS(
    callable: u64, self_or_null: u64, args: ptr[u64], oparg: i32, res: ptr[u64]
) -> i32;

def _CALL_METHOD_DESCRIPTOR_NOARGS(
    tstate: ptr,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    oparg: i32,
    res: ptr[u64]
) -> i32;

def _CALL_METHOD_DESCRIPTOR_FAST(
    callable: u64, self_or_null: u64, args: ptr[u64], oparg: i32, res: ptr[u64]
) -> i32;

def CALL_INTRINSIC_1(tstate: ptr, value: u64, oparg: i32) -> u64;

def CALL_INTRINSIC_2(tstate: ptr, value2_st: u64, value1_st: u64, oparg: i32) -> u64;

def MAKE_FUNCTION(frame: ptr[u8], codeobj_st: u64) -> u64;

def SET_FUNCTION_ATTRIBUTE(attr_st: u64, func_in: u64, oparg: i32) -> u64;

def LOAD_BUILD_CLASS(frame: ptr[u8]) -> u64;

impl callnative_cached_callable(tstate: ptr, offset: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](tstate_interp(tstate) + offset).view(1)[0];
}

impl callnative_recursion_reached(tstate: ptr) -> bool {
    return _Py_ReachedRecursionLimitWithMargin(ptr[PyThreadState](tstate), 0) != 0;
}

impl callnative_args_from_stack(
    input_: ptr[u64], nargs: i64, scratch: ptr[ptr[PyObject]]
) -> ptr[ptr[PyObject]] {
    result = scratch;
    if nargs > CALLNATIVE_MAX_STACKREF_SCRATCH {
        block = ptr[ptr[PyObject]](PyMem_Malloc(u64(nargs + 1) * u64(8)));
        if not block {
            return ptr[ptr[PyObject]]();
        }
        result = block + 1;
    }
    for i in range(nargs) {
        (result + i).view(1)[0] = sr_borrow((input_ + i).view(1)[0]);
    }
    return result;
}

impl callnative_args_free(array: ptr[ptr[PyObject]], scratch: ptr[ptr[PyObject]]) {
    if array != scratch {
        PyMem_Free(ptr(array));
    }
}

impl callnative_is_cfunction(callable: u64) -> bool {
    return sr_type(callable) == ptr[PyTypeObject](addressof(PyCFunction_Type));
}

impl callnative_is_method_descr(callable: u64) -> bool {
    return sr_type(callable) == ptr[PyTypeObject](addressof(PyMethodDescr_Type));
}

impl callnative_descr_method(callable_o: ptr[PyObject]) -> ptr[PyMethodDef] {
    return ptr[ptr[PyMethodDef]](ptr[u8](callable_o) + PyMethodDescrObject_METHOD).view(
        1
    )[0];
}

impl callnative_descr_type(callable_o: ptr[PyObject]) -> ptr[PyTypeObject] {
    return ptr[PyDescrObject](callable_o).view(1)[0].d_type;
}

impl callnative_function_attribute_offset(oparg: i32) -> i64 {
    if oparg == CALLNATIVE_MAKE_FUNCTION_CLOSURE {
        return PyFunctionObject_CLOSURE;
    }
    if oparg == CALLNATIVE_MAKE_FUNCTION_ANNOTATIONS {
        return PyFunctionObject_ANNOTATIONS;
    }
    if oparg == CALLNATIVE_MAKE_FUNCTION_KWDEFAULTS {
        return PyFunctionObject_KWDEFAULTS;
    }
    if oparg == CALLNATIVE_MAKE_FUNCTION_DEFAULTS {
        return PyFunctionObject_DEFAULTS;
    }
    return PyFunctionObject_ANNOTATE;
}

impl _GUARD_NOS_NULL(null: u64) -> bool {
    return sr_is_null(null);
}

impl _GUARD_CALLABLE_TYPE_1(callable: u64) -> bool {
    return sr_borrow(callable) == ptr[PyObject](addressof(PyType_Type));
}

impl _GUARD_CALLABLE_STR_1(callable: u64) -> bool {
    return sr_borrow(callable) == ptr[PyObject](addressof(PyUnicode_Type));
}

impl _GUARD_CALLABLE_TUPLE_1(callable: u64) -> bool {
    return sr_borrow(callable) == ptr[PyObject](addressof(PyTuple_Type));
}

impl _GUARD_CALLABLE_LEN(tstate: ptr, callable: u64) -> bool {
    return sr_borrow(callable)
        == callnative_cached_callable(tstate, PyInterpreterState_CALLABLE_CACHE_LEN);
}

impl _CALL_TYPE_1(arg: u64) -> u64 {
    res = sr_new(ptr[PyObject](sr_type(arg)));
    sr_close(arg);
    return res;
}

impl _CALL_STR_1(arg: u64) -> u64 {
    res_o = PyObject_Str(sr_borrow(arg));
    sr_close(arg);
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl _CALL_TUPLE_1(arg: u64) -> u64 {
    res_o = PySequence_Tuple(sr_borrow(arg));
    sr_close(arg);
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl _CALL_LEN(arg: u64) -> u64 {
    len_i = PyObject_Length(sr_borrow(arg));
    if len_i < 0 {
        return u64(0);
    }
    res_o = PyLong_FromSsize_t(len_i);
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl _CALL_BUILTIN_CLASS(
    callable: u64, self_or_null: u64, args: ptr[u64], oparg: i32, res: ptr[u64]
) -> i32 {
    if (sr_type(callable).view(1)[0].tp_flags & Py_TPFLAGS_TYPE_SUBCLASS) == u64(0) {
        return ST_DEOPT;
    }
    tp = ptr[PyTypeObject](sr_borrow(callable));
    total_args = i64(oparg);
    arguments = args;
    if not sr_is_null(self_or_null) {
        arguments = args - 1;
        total_args = total_args + 1;
    }
    if int(tp.view(1)[0].tp_vectorcall) == 0 {
        return ST_DEOPT;
    }
    slots: own CallnativeScratch = CallnativeScratch();
    scratch = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    args_o = callnative_args_from_stack(arguments, total_args, scratch + 1);
    if not args_o {
        return ST_ERROR;
    }
    res_o = tp.view(1)[0].tp_vectorcall(
        ptr[PyObject](tp), args_o, u64(total_args), NULL
    );
    callnative_args_free(args_o - 1, scratch);
    if not res_o {
        return ST_ERROR;
    }
    res.view(1)[0] = sr_steal(res_o);
    return ST_OK;
}

impl _CALL_BUILTIN_O(
    tstate: ptr,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    oparg: i32,
    res: ptr[u64]
) -> i32 {
    total_args = i64(oparg);
    arguments = args;
    if not sr_is_null(self_or_null) {
        arguments = args - 1;
        total_args = total_args + 1;
    }
    if total_args != 1 {
        return ST_DEOPT;
    }
    if not callnative_is_cfunction(callable) {
        return ST_DEOPT;
    }
    func = ptr[PyCFunctionObject](sr_borrow(callable));
    ml = func.view(1)[0].m_ml;
    if ml.view(1)[0].ml_flags != METH_O {
        return ST_DEOPT;
    }
    if callnative_recursion_reached(tstate) {
        return ST_DEOPT;
    }
    res_o = ptr[CallnativeMethO](ml).view(1)[0].ml_meth(
        func.view(1)[0].m_self, sr_borrow(arguments.view(1)[0])
    );
    if not res_o {
        return ST_ERROR;
    }
    res.view(1)[0] = sr_steal(res_o);
    return ST_OK;
}

impl _CALL_BUILTIN_FAST(
    callable: u64, self_or_null: u64, args: ptr[u64], oparg: i32, res: ptr[u64]
) -> i32 {
    total_args = i64(oparg);
    arguments = args;
    if not sr_is_null(self_or_null) {
        arguments = args - 1;
        total_args = total_args + 1;
    }
    if not callnative_is_cfunction(callable) {
        return ST_DEOPT;
    }
    func = ptr[PyCFunctionObject](sr_borrow(callable));
    ml = func.view(1)[0].m_ml;
    if ml.view(1)[0].ml_flags != METH_FASTCALL {
        return ST_DEOPT;
    }
    slots: own CallnativeScratch = CallnativeScratch();
    scratch = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    args_o = callnative_args_from_stack(arguments, total_args, scratch + 1);
    if not args_o {
        return ST_ERROR;
    }
    res_o = ptr[CallnativeMethFast](ml).view(1)[0].ml_meth(
        func.view(1)[0].m_self, args_o, total_args
    );
    callnative_args_free(args_o - 1, scratch);
    if not res_o {
        return ST_ERROR;
    }
    res.view(1)[0] = sr_steal(res_o);
    return ST_OK;
}

impl _CALL_BUILTIN_FAST_WITH_KEYWORDS(
    callable: u64, self_or_null: u64, args: ptr[u64], oparg: i32, res: ptr[u64]
) -> i32 {
    total_args = i64(oparg);
    arguments = args;
    if not sr_is_null(self_or_null) {
        arguments = args - 1;
        total_args = total_args + 1;
    }
    if not callnative_is_cfunction(callable) {
        return ST_DEOPT;
    }
    func = ptr[PyCFunctionObject](sr_borrow(callable));
    ml = func.view(1)[0].m_ml;
    if ml.view(1)[0].ml_flags != (METH_FASTCALL | METH_KEYWORDS) {
        return ST_DEOPT;
    }
    slots: own CallnativeScratch = CallnativeScratch();
    scratch = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    args_o = callnative_args_from_stack(arguments, total_args, scratch + 1);
    if not args_o {
        return ST_ERROR;
    }
    res_o = ptr[CallnativeMethFastKw](ml).view(1)[0].ml_meth(
        func.view(1)[0].m_self, args_o, total_args, NULL
    );
    callnative_args_free(args_o - 1, scratch);
    if not res_o {
        return ST_ERROR;
    }
    res.view(1)[0] = sr_steal(res_o);
    return ST_OK;
}

impl CALL_ISINSTANCE(
    tstate: ptr,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    oparg: i32,
    res: ptr[u64]
) -> i32 {
    total_args = i64(oparg);
    arguments = args;
    if not sr_is_null(self_or_null) {
        arguments = args - 1;
        total_args = total_args + 1;
    }
    if total_args != 2 {
        return ST_DEOPT;
    }
    if sr_borrow(callable)
        != callnative_cached_callable(
            tstate, PyInterpreterState_CALLABLE_CACHE_ISINSTANCE
        ) {
        return ST_DEOPT;
    }
    retval = PyObject_IsInstance(
        sr_borrow(arguments.view(1)[0]), sr_borrow((arguments + 1).view(1)[0])
    );
    if retval < 0 {
        return ST_ERROR;
    }
    if retval != 0 {
        res.view(1)[0] = sr_true();
    } else {
        res.view(1)[0] = sr_false();
    }
    return ST_OK;
}

impl _CALL_LIST_APPEND(tstate: ptr, callable: u64, self_: u64, arg: u64) -> i32 {
    self_o = sr_borrow(self_);
    if sr_borrow(callable)
        != callnative_cached_callable(
            tstate, PyInterpreterState_CALLABLE_CACHE_LIST_APPEND
        ) {
        return ST_DEOPT;
    }
    if not self_o {
        return ST_DEOPT;
    }
    if (sr_type(self_).view(1)[0].tp_flags & Py_TPFLAGS_LIST_SUBCLASS) == u64(0) {
        return ST_DEOPT;
    }
    item = sr_as_steal(arg);
    lst = ptr[PyListObject](self_o);
    length = ptr[PyVarObject](self_o).view(1)[0].ob_size;
    err: i32 = 0;
    if lst.view(1)[0].allocated > length {
        (lst.view(1)[0].ob_item + length).view(1)[0] = item;
        ptr[PyVarObject](self_o).view(1)[0].ob_size = length + 1;
    } else {
        err = _PyList_AppendTakeRefListResize(self_o, item);
    }
    sr_close(self_);
    sr_close(callable);
    if err != 0 {
        return ST_ERROR;
    }
    return ST_OK;
}

impl _SKIP_POP_TOP -> i64 {
    return 1;
}

impl _CALL_METHOD_DESCRIPTOR_O(
    tstate: ptr,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    oparg: i32,
    res: ptr[u64]
) -> i32 {
    total_args = i64(oparg);
    arguments = args;
    if not sr_is_null(self_or_null) {
        arguments = args - 1;
        total_args = total_args + 1;
    }
    if total_args != 2 {
        return ST_DEOPT;
    }
    if not callnative_is_method_descr(callable) {
        return ST_DEOPT;
    }
    callable_o = sr_borrow(callable);
    meth = callnative_descr_method(callable_o);
    if meth.view(1)[0].ml_flags != METH_O {
        return ST_DEOPT;
    }
    if callnative_recursion_reached(tstate) {
        return ST_DEOPT;
    }
    self_o = sr_borrow(arguments.view(1)[0]);
    if ptr[_object](self_o).view(1)[0].ob_type != callnative_descr_type(callable_o) {
        return ST_DEOPT;
    }
    res_o = ptr[CallnativeMethO](meth).view(1)[0].ml_meth(
        self_o, sr_borrow((arguments + 1).view(1)[0])
    );
    if not res_o {
        return ST_ERROR;
    }
    res.view(1)[0] = sr_steal(res_o);
    return ST_OK;
}

impl _CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS(
    callable: u64, self_or_null: u64, args: ptr[u64], oparg: i32, res: ptr[u64]
) -> i32 {
    total_args = i64(oparg);
    arguments = args;
    if not sr_is_null(self_or_null) {
        arguments = args - 1;
        total_args = total_args + 1;
    }
    if total_args == 0 {
        return ST_DEOPT;
    }
    if not callnative_is_method_descr(callable) {
        return ST_DEOPT;
    }
    callable_o = sr_borrow(callable);
    meth = callnative_descr_method(callable_o);
    if meth.view(1)[0].ml_flags != (METH_FASTCALL | METH_KEYWORDS) {
        return ST_DEOPT;
    }
    self_o = sr_borrow(arguments.view(1)[0]);
    if ptr[_object](self_o).view(1)[0].ob_type != callnative_descr_type(callable_o) {
        return ST_DEOPT;
    }
    slots: own CallnativeScratch = CallnativeScratch();
    scratch = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    args_o = callnative_args_from_stack(arguments, total_args, scratch + 1);
    if not args_o {
        return ST_ERROR;
    }
    res_o = ptr[CallnativeMethFastKw](meth).view(1)[0].ml_meth(
        self_o, args_o + 1, total_args - 1, NULL
    );
    callnative_args_free(args_o - 1, scratch);
    if not res_o {
        return ST_ERROR;
    }
    res.view(1)[0] = sr_steal(res_o);
    return ST_OK;
}

impl _CALL_METHOD_DESCRIPTOR_NOARGS(
    tstate: ptr,
    callable: u64,
    self_or_null: u64,
    args: ptr[u64],
    oparg: i32,
    res: ptr[u64]
) -> i32 {
    total_args = i64(oparg);
    arguments = args;
    if not sr_is_null(self_or_null) {
        arguments = args - 1;
        total_args = total_args + 1;
    }
    if total_args != 1 {
        return ST_DEOPT;
    }
    if not callnative_is_method_descr(callable) {
        return ST_DEOPT;
    }
    callable_o = sr_borrow(callable);
    meth = callnative_descr_method(callable_o);
    self_o = sr_borrow(arguments.view(1)[0]);
    if ptr[_object](self_o).view(1)[0].ob_type != callnative_descr_type(callable_o) {
        return ST_DEOPT;
    }
    if meth.view(1)[0].ml_flags != METH_NOARGS {
        return ST_DEOPT;
    }
    if callnative_recursion_reached(tstate) {
        return ST_DEOPT;
    }
    res_o = ptr[CallnativeMethO](meth).view(1)[0].ml_meth(self_o, NULL);
    if not res_o {
        return ST_ERROR;
    }
    res.view(1)[0] = sr_steal(res_o);
    return ST_OK;
}

impl _CALL_METHOD_DESCRIPTOR_FAST(
    callable: u64, self_or_null: u64, args: ptr[u64], oparg: i32, res: ptr[u64]
) -> i32 {
    total_args = i64(oparg);
    arguments = args;
    if not sr_is_null(self_or_null) {
        arguments = args - 1;
        total_args = total_args + 1;
    }
    if total_args == 0 {
        return ST_DEOPT;
    }
    if not callnative_is_method_descr(callable) {
        return ST_DEOPT;
    }
    callable_o = sr_borrow(callable);
    meth = callnative_descr_method(callable_o);
    if meth.view(1)[0].ml_flags != METH_FASTCALL {
        return ST_DEOPT;
    }
    self_o = sr_borrow(arguments.view(1)[0]);
    if ptr[_object](self_o).view(1)[0].ob_type != callnative_descr_type(callable_o) {
        return ST_DEOPT;
    }
    slots: own CallnativeScratch = CallnativeScratch();
    scratch = ptr[ptr[PyObject]](jacpy_stack_address(&mut slots));
    args_o = callnative_args_from_stack(arguments, total_args, scratch + 1);
    if not args_o {
        return ST_ERROR;
    }
    res_o = ptr[CallnativeMethFast](meth).view(1)[0].ml_meth(
        self_o, args_o + 1, total_args - 1
    );
    callnative_args_free(args_o - 1, scratch);
    if not res_o {
        return ST_ERROR;
    }
    res.view(1)[0] = sr_steal(res_o);
    return ST_OK;
}

impl CALL_INTRINSIC_1(tstate: ptr, value: u64, oparg: i32) -> u64 {
    info = ptr[intrinsic_func1_info](addressof(_PyIntrinsics_UnaryFunctions))
        + i64(oparg);
    res_o = info.view(1)[0].func(tstate, sr_borrow(value));
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl CALL_INTRINSIC_2(tstate: ptr, value2_st: u64, value1_st: u64, oparg: i32) -> u64 {
    info = ptr[intrinsic_func2_info](addressof(_PyIntrinsics_BinaryFunctions))
        + i64(oparg);
    res_o = info.view(1)[0].func(tstate, sr_borrow(value2_st), sr_borrow(value1_st));
    if not res_o {
        return u64(0);
    }
    return sr_steal(res_o);
}

impl MAKE_FUNCTION(frame: ptr[u8], codeobj_st: u64) -> u64 {
    codeobj = sr_borrow(codeobj_st);
    globals = ptr[ptr[PyObject]](frame + _PyInterpreterFrame_F_GLOBALS).view(1)[0];
    func_obj = PyFunction_New(codeobj, globals);
    if not func_obj {
        return u64(0);
    }
    _PyFunction_SetVersion(
        func_obj, ptr[u32](ptr[u8](codeobj) + PyCodeObject_VERSION).view(1)[0]
    );
    return sr_steal(func_obj);
}

impl SET_FUNCTION_ATTRIBUTE(attr_st: u64, func_in: u64, oparg: i32) -> u64 {
    func = sr_borrow(func_in);
    attr = sr_as_steal(attr_st);
    slot = ptr[ptr[PyObject]](
        ptr[u8](func) + callnative_function_attribute_offset(oparg)
    );
    slot.view(1)[0] = attr;
    is_function = ptr[_object](attr).view(1)[0].ob_type
        == ptr[PyTypeObject](addressof(PyFunction_Type));
    if oparg == CALLNATIVE_MAKE_FUNCTION_ANNOTATE and is_function {
        qualname = ptr[ptr[PyObject]](ptr[u8](func) + PyFunctionObject_QUALNAME).view(1)[
            0
        ];
        fixed_qualname = PyUnicode_FromFormat("%U.__annotate__", qualname);
        if not fixed_qualname {
            sr_close(func_in);
            return u64(0);
        }
        attr_qualname = ptr[ptr[PyObject]](ptr[u8](attr) + PyFunctionObject_QUALNAME);
        old = attr_qualname.view(1)[0];
        attr_qualname.view(1)[0] = fixed_qualname;
        object_decref(old);
    }
    return func_in;
}

impl LOAD_BUILD_CLASS(frame: ptr[u8]) -> u64 {
    builtins = ptr[ptr[PyObject]](frame + _PyInterpreterFrame_F_BUILTINS).view(1)[0];
    name = ptr[PyObject](
        ptr[u8](addressof(_PyRuntime))
            + _PyRuntimeState_GLOBAL_STRINGS
            + _Py_ID___build_class__
    );
    bc_o = NULL;
    err = PyMapping_GetOptionalItem(builtins, name, &mut bc_o);
    if err < 0 {
        return u64(0);
    }
    if not bc_o {
        PyErr_SetString(PyExc_NameError, "__build_class__ not found");
        return u64(0);
    }
    return sr_steal(bc_o);
}
