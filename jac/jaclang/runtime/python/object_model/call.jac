import from c {
    def _PyEval_Vector(
        tstate: ptr[PyThreadState],
        func: ptr[PyObject],
        locals: ptr[PyObject],
        args: ptr[ptr[PyObject]],
        argcount: u64,
        kwnames: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyDict_FromItems(
        keys: ptr[ptr[PyObject]],
        keys_offset: i64,
        values: ptr[ptr[PyObject]],
        values_offset: i64,
        length: i64
    ) -> ptr[PyObject];  def _PyObject_GetMethodStackRef(
        ts: ptr[PyThreadState],
        self_ref: ptr[u64],
        name: ptr[PyObject],
        method: ptr[u64]
    ) -> i32;  def _PyObject_GetMethod(
        obj_: ptr[PyObject], name: ptr[PyObject], method: &mut ptr[PyObject]
    ) -> i32;  def _PyUnicode_FromId(id: ptr) -> ptr[PyObject];  def Py_EnterRecursiveCall(
        where: ptr[u8]
    ) -> i32;  def _Py_FatalErrorFormat(func: ptr[u8], format: ptr[u8], *args: any);  def memcpy(
        target: ptr, source: ptr, size: u64
    ) -> ptr;  obj ArgStack {
        has s0: ptr[PyObject] = ptr[PyObject](),
            s1: ptr[PyObject] = ptr[PyObject](),
            s2: ptr[PyObject] = ptr[PyObject](),
            s3: ptr[PyObject] = ptr[PyObject](),
            s4: ptr[PyObject] = ptr[PyObject]();
    }  def jacpy_stack_address(slots: &mut ArgStack) -> int;  obj VectorcallEntry {
        has call:
            Callable[
                [ptr[PyObject], ptr[ptr[PyObject]], u64, ptr[PyObject]],
                ptr[PyObject]
            ] = 0;
    }  obj CallSlot {
        has vectorcall:
            Callable[
                [ptr[PyObject], ptr[ptr[PyObject]], u64, ptr[PyObject]],
                ptr[PyObject]
            ] = 0,
            ternary:
                Callable[
                    [ptr[PyObject], ptr[PyObject], ptr[PyObject]],
                    ptr[PyObject]
                ] = 0;
    }
}

glob:priv PY_SSIZE_T_MAX: i64 = 0x7FFFFFFFFFFFFFFF,
     STACKREF_TAG: u64 = u64(1),
     STACKREF_NULL: u64 = u64(1);

def thread_state -> ptr[PyThreadState];

def exception_raised(tstate: ptr[PyThreadState]) -> bool;

def error_occurred(tstate: ptr[PyThreadState]) -> ptr[PyObject];

def vectorcall_nargs(nargsf: u64) -> i64;

def tuple_check(op: ptr[PyObject]) -> bool;

def dict_check(op: ptr[PyObject]) -> bool;

def dict_size(op: ptr[PyObject]) -> i64;

def arg_array(address: int) -> ptr[ptr[PyObject]];

def null_error(tstate: ptr[PyThreadState]) -> ptr[PyObject];

def vectorcall_function(callable: ptr[PyObject]) -> int;

def call_vectorcall(
    func: int,
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def call_ternary(
    func: int, callable: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def check_result(
    tstate: ptr[PyThreadState], callable: ptr[PyObject], result: ptr[PyObject]
) -> ptr[PyObject];

def vectorcall_tstate(
    tstate: ptr[PyThreadState],
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject];

def object_is_not_callable(callable: ptr[PyObject]);

def vectorcall_call(
    tstate: ptr[PyThreadState],
    func: int,
    callable: ptr[PyObject],
    argtuple: ptr[PyObject],
    kwargs: ptr[PyObject]
) -> ptr[PyObject];

def unpack_dict(
    args: ptr[ptr[PyObject]], nargs: i64, kwargs: ptr[PyObject]
) -> tuple[ptr[ptr[PyObject]], ptr[PyObject]];

def stackref_borrow(bits: u64) -> ptr[PyObject];

def stackref_xclose(bits: u64);

def grow_args(
    stack: ptr[ptr[PyObject]], small_stack: ptr[ptr[PyObject]], capacity: i64
) -> ptr[ptr[PyObject]];

def free_args(stack: ptr[ptr[PyObject]], small_stack: ptr[ptr[PyObject]]);

import from c {
    def _Py_CheckFunctionResult(
        tstate: ptr[PyThreadState],
        callable: ptr[PyObject],
        result: ptr[PyObject],
        where: ptr[u8]
    ) -> ptr[PyObject] {
        if not result {
            if not exception_raised(tstate) {
                if callable {
                    PyErr_Format(
                        PyExc_SystemError,
                        ptr[u8]("%R returned NULL without setting an exception"),
                        callable
                    );
                } else {
                    PyErr_Format(
                        PyExc_SystemError,
                        ptr[u8]("%s returned NULL without setting an exception"),
                        where
                    );
                }
                return NULL;
            }
        } elif exception_raised(tstate) {
            object_decref(result);
            if callable {
                _PyErr_FormatFromCause(
                    PyExc_SystemError,
                    ptr[u8]("%R returned a result with an exception set"),
                    callable
                );
            } else {
                _PyErr_FormatFromCause(
                    PyExc_SystemError,
                    ptr[u8]("%s returned a result with an exception set"),
                    where
                );
            }
            return NULL;
        }
        return result;
    }  def _Py_CheckSlotResult(
        obj_: ptr[PyObject], slot_name: ptr[u8], success: i32
    ) -> i32 {
        tstate = thread_state();
        tp_name = object_type(obj_).view(1)[0].tp_name;
        if success == i32(0) {
            if not exception_raised(tstate) {
                _Py_FatalErrorFormat(
                    ptr[u8]("_Py_CheckSlotResult"),
                    ptr[u8]("Slot %s of type %s failed without setting an exception"),
                    slot_name,
                    tp_name
                );
            }
        } elif exception_raised(tstate) {
            _Py_FatalErrorFormat(
                ptr[u8]("_Py_CheckSlotResult"),
                ptr[u8]("Slot %s of type %s succeeded with an exception set"),
                slot_name,
                tp_name
            );
        }
        return i32(1);
    }  def PyObject_CallNoArgs(func: ptr[PyObject]) -> ptr[PyObject] {
        return vectorcall_tstate(
            thread_state(), func, ptr[ptr[PyObject]](), u64(0), NULL
        );
    }  def _PyObject_VectorcallDictTstate(
        tstate: ptr[PyThreadState],
        callable: ptr[PyObject],
        args: ptr[ptr[PyObject]],
        nargsf: u64,
        kwargs: ptr[PyObject]
    ) -> ptr[PyObject] {
        nargs = vectorcall_nargs(nargsf);
        func = vectorcall_function(callable);
        if func == 0 {
            return _PyObject_MakeTpCall(tstate, callable, args, nargs, kwargs);
        }
        res = NULL;
        if not kwargs or dict_size(kwargs) == 0 {
            res = call_vectorcall(func, callable, args, nargsf, NULL);
        } else {
            (newargs, kwnames) = unpack_dict(args, nargs, kwargs);
            if not newargs {
                return NULL;
            }
            res = call_vectorcall(
                func,
                callable,
                newargs,
                u64(nargs) | PY_VECTORCALL_ARGUMENTS_OFFSET,
                kwnames
            );
            _PyStack_UnpackDict_Free(newargs, nargs, kwnames);
        }
        return check_result(tstate, callable, res);
    }  def PyObject_VectorcallDict(
        callable: ptr[PyObject],
        args: ptr[ptr[PyObject]],
        nargsf: u64,
        kwargs: ptr[PyObject]
    ) -> ptr[PyObject] {
        return _PyObject_VectorcallDictTstate(
            thread_state(), callable, args, nargsf, kwargs
        );
    }  def _PyObject_MakeTpCall(
        tstate: ptr[PyThreadState],
        callable: ptr[PyObject],
        args: ptr[ptr[PyObject]],
        nargs: i64,
        keywords: ptr[PyObject]
    ) -> ptr[PyObject] {
        call = int(object_type(callable).view(1)[0].tp_call);
        if call == 0 {
            object_is_not_callable(callable);
            return NULL;
        }
        argstuple = _PyTuple_FromArray(args, nargs);
        if not argstuple {
            return NULL;
        }
        kw = keywords;
        kwdict = keywords;
        if kw and not dict_check(kw) {
            if object_size(kw) != 0 {
                kwdict = _PyStack_AsDict(args + nargs, kw);
                if not kwdict {
                    object_decref(argstuple);
                    return NULL;
                }
            } else {
                kw = NULL;
                kwdict = NULL;
            }
        }
        result = NULL;
        if Py_EnterRecursiveCall(ptr[u8](" while calling a Python object")) == 0 {
            result = call_ternary(call, callable, argstuple, kwdict);
        }
        object_decref(argstuple);
        if kwdict != kw {
            object_decref(kwdict);
        }
        return check_result(tstate, callable, result);
    }  def PyVectorcall_Function(callable: ptr[PyObject]) -> ptr {
        tp = object_type(callable);
        if not type_has_feature(tp, Py_TPFLAGS_HAVE_VECTORCALL) {
            return ptr();
        }
        return ptr[ptr](ptr[u8](callable) + tp.view(1)[0].tp_vectorcall_offset).view(1)[
            0
        ];
    }  def PyVectorcall_Call(
        callable: ptr[PyObject], argtuple: ptr[PyObject], kwargs: ptr[PyObject]
    ) -> ptr[PyObject] {
        tstate = thread_state();

        offset = object_type(callable).view(1)[0].tp_vectorcall_offset;
        if offset <= 0 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("'%.200s' object does not support vectorcall"),
                object_type(callable).view(1)[0].tp_name
            );
            return NULL;
        }
        func = int(ptr[ptr](ptr[u8](callable) + offset).view(1)[0]);
        if func == 0 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("'%.200s' object does not support vectorcall"),
                object_type(callable).view(1)[0].tp_name
            );
            return NULL;
        }
        return vectorcall_call(tstate, func, callable, argtuple, kwargs);
    }  def PyObject_Vectorcall(
        callable: ptr[PyObject],
        args: ptr[ptr[PyObject]],
        nargsf: u64,
        kwnames: ptr[PyObject]
    ) -> ptr[PyObject] {
        return vectorcall_tstate(thread_state(), callable, args, nargsf, kwnames);
    }  def _PyObject_Call(
        tstate: ptr[PyThreadState],
        callable: ptr[PyObject],
        args: ptr[PyObject],
        kwargs: ptr[PyObject]
    ) -> ptr[PyObject] {
        vector_func = vectorcall_function(callable);
        if vector_func != 0 {
            return vectorcall_call(tstate, vector_func, callable, args, kwargs);
        }
        tp = object_type(callable);
        if int(tp.view(1)[0].tp_call) == 0 {
            object_is_not_callable(callable);
            return NULL;
        }
        if Py_EnterRecursiveCall(ptr[u8](" while calling a Python object")) != 0 {
            return NULL;
        }

        result = tp.view(1)[0].tp_call(callable, args, kwargs);
        return check_result(tstate, callable, result);
    }  def PyObject_Call(
        callable: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
    ) -> ptr[PyObject] {
        return _PyObject_Call(thread_state(), callable, args, kwargs);
    }  def PyCFunction_Call(
        callable: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
    ) -> ptr[PyObject] {
        return PyObject_Call(callable, args, kwargs);
    }  def PyObject_CallOneArg(
        func: ptr[PyObject], arg: ptr[PyObject]
    ) -> ptr[PyObject] {
        small: own ArgStack = ArgStack();
        args = arg_array(jacpy_stack_address(&mut small)) + 1;
        args.view(1)[0] = arg;
        return vectorcall_tstate(
            thread_state(), func, args, u64(1) | PY_VECTORCALL_ARGUMENTS_OFFSET, NULL
        );
    }  def _PyFunction_Vectorcall(
        func: ptr[PyObject],
        stack: ptr[ptr[PyObject]],
        nargsf: u64,
        kwnames: ptr[PyObject]
    ) -> ptr[PyObject] {
        nargs = vectorcall_nargs(nargsf);
        tstate = thread_state();
        code = ptr[ptr[u8]](ptr[u8](func) + PyFunctionObject_CODE).view(1)[0];
        if (ptr[i32](code + PyCodeObject_FLAGS).view(1)[0] & CO_OPTIMIZED) != i32(0) {
            return _PyEval_Vector(tstate, func, NULL, stack, u64(nargs), kwnames);
        }
        globals = ptr[ptr[PyObject]](ptr[u8](func) + PyFunctionObject_GLOBALS).view(1)[
            0
        ];
        return _PyEval_Vector(tstate, func, globals, stack, u64(nargs), kwnames);
    }  def PyEval_CallObjectWithKeywords(
        callable: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
    ) -> ptr[PyObject] {
        tstate = thread_state();
        if args and not tuple_check(args) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("argument list must be a tuple"));
            return NULL;
        }
        if kwargs and not dict_check(kwargs) {
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("keyword list must be a dictionary")
            );
            return NULL;
        }
        if not args {
            return _PyObject_VectorcallDictTstate(
                tstate, callable, ptr[ptr[PyObject]](), u64(0), kwargs
            );
        }
        return _PyObject_Call(tstate, callable, args, kwargs);
    }  def PyObject_CallObject(
        callable: ptr[PyObject], args: ptr[PyObject]
    ) -> ptr[PyObject] {
        tstate = thread_state();
        if not args {
            return vectorcall_tstate(
                tstate, callable, ptr[ptr[PyObject]](), u64(0), NULL
            );
        }
        if not tuple_check(args) {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("argument list must be a tuple"));
            return NULL;
        }
        return _PyObject_Call(tstate, callable, args, NULL);
    }  def _PyObject_Call_Prepend(
        tstate: ptr[PyThreadState],
        callable: ptr[PyObject],
        obj_: ptr[PyObject],
        args: ptr[PyObject],
        kwargs: ptr[PyObject]
    ) -> ptr[PyObject] {
        small: own ArgStack = ArgStack();
        small_stack = arg_array(jacpy_stack_address(&mut small));
        argcount = object_size(args);
        stack = small_stack;
        if argcount + 1 > _PY_FASTCALL_SMALL_STACK {
            stack = ptr[ptr[PyObject]](PyMem_Malloc(u64((argcount + 1) * 8)));
            if not stack {
                PyErr_NoMemory();
                return NULL;
            }
        }

        stack.view(1)[0] = obj_;
        memcpy(ptr(stack + 1), ptr(tuple_items(args)), u64(argcount * 8));
        result = _PyObject_VectorcallDictTstate(
            tstate, callable, stack, u64(argcount + 1), kwargs
        );
        if stack != small_stack {
            PyMem_Free(ptr(stack));
        }
        return result;
    }  def _PyObject_VectorcallPrepend(
        tstate: ptr[PyThreadState],
        callable: ptr[PyObject],
        arg: ptr[PyObject],
        args: ptr[ptr[PyObject]],
        nargsf: u64,
        kwnames: ptr[PyObject]
    ) -> ptr[PyObject] {
        nargs = vectorcall_nargs(nargsf);
        if (nargsf & PY_VECTORCALL_ARGUMENTS_OFFSET) != u64(0) {
            newargs = args - 1;
            tmp = newargs.view(1)[0];
            newargs.view(1)[0] = arg;
            result = vectorcall_tstate(
                tstate, callable, newargs, u64(nargs + 1), kwnames
            );
            newargs.view(1)[0] = tmp;
            return result;
        }
        nkwargs: i64 = 0;
        if kwnames {
            nkwargs = object_size(kwnames);
        }
        totalargs = nargs + nkwargs;
        small: own ArgStack = ArgStack();
        newargs_stack = arg_array(jacpy_stack_address(&mut small));
        if totalargs == 0 {
            newargs_stack.view(1)[0] = arg;
            return vectorcall_tstate(tstate, callable, newargs_stack, u64(1), NULL);
        }
        newargs = newargs_stack;
        if totalargs > _PY_FASTCALL_SMALL_STACK - 1 {
            newargs = ptr[ptr[PyObject]](PyMem_Malloc(u64((totalargs + 1) * 8)));
            if not newargs {
                PyErr_NoMemory();
                return NULL;
            }
        }

        newargs.view(1)[0] = arg;
        memcpy(ptr(newargs + 1), ptr(args), u64(totalargs * 8));
        result = vectorcall_tstate(tstate, callable, newargs, u64(nargs + 1), kwnames);
        if newargs != newargs_stack {
            PyMem_Free(ptr(newargs));
        }
        return result;
    }  def PyObject_VectorcallMethod(
        name: ptr[PyObject],
        args: ptr[ptr[PyObject]],
        nargsf: u64,
        kwnames: ptr[PyObject]
    ) -> ptr[PyObject] {
        tstate = thread_state();

        refs: own ArgStack = ArgStack();
        self_ref = ptr[u64](jacpy_stack_address(&mut refs));
        method_ref = self_ref + 1;
        method_ref.view(1)[0] = STACKREF_NULL;

        self_ref.view(1)[0] = u64.wrap(int(args.view(1)[0])) | STACKREF_TAG;
        unbound = _PyObject_GetMethodStackRef(tstate, self_ref, name, method_ref);
        if unbound < i32(0) {
            stackref_xclose(method_ref.view(1)[0]);
            stackref_xclose(self_ref.view(1)[0]);
            return NULL;
        }
        callable = stackref_borrow(method_ref.view(1)[0]);
        self_obj = stackref_borrow(self_ref.view(1)[0]);
        result = NULL;
        if not self_obj {
            result = vectorcall_tstate(
                tstate, callable, args + 1, nargsf - u64(1), kwnames
            );
        } elif self_obj == args.view(1)[0] {
            result = vectorcall_tstate(
                tstate,
                callable,
                args,
                nargsf & ~PY_VECTORCALL_ARGUMENTS_OFFSET,
                kwnames
            );
        } else {
            result = _PyObject_VectorcallPrepend(
                tstate, callable, self_obj, args + 1, nargsf - u64(1), kwnames
            );
        }
        stackref_xclose(method_ref.view(1)[0]);
        stackref_xclose(self_ref.view(1)[0]);
        return result;
    }  def PyObject_CallMethodObjArgs(
        obj_: ptr[PyObject], name: ptr[PyObject], *vargs: VaList
    ) -> ptr[PyObject] {
        tstate = thread_state();
        if not obj_ or not name {
            return null_error(tstate);
        }
        refs: own ArgStack = ArgStack();
        self_ref = ptr[u64](jacpy_stack_address(&mut refs));
        method_ref = self_ref + 1;
        method_ref.view(1)[0] = STACKREF_NULL;
        self_ref.view(1)[0] = u64.wrap(int(obj_)) | STACKREF_TAG;
        res = _PyObject_GetMethodStackRef(tstate, self_ref, name, method_ref);
        if res < i32(0) {
            stackref_xclose(method_ref.view(1)[0]);
            stackref_xclose(self_ref.view(1)[0]);
            return NULL;
        }
        callable = stackref_borrow(method_ref.view(1)[0]);
        self_obj = stackref_borrow(self_ref.view(1)[0]);
        result = NULL;
        if not callable {
            result = null_error(tstate);
        } else {
            small: own ArgStack = ArgStack();
            small_stack = arg_array(jacpy_stack_address(&mut small));
            stack = small_stack;
            capacity = _PY_FASTCALL_SMALL_STACK;
            nargs: i64 = 0;
            if self_obj {
                stack.view(1)[0] = self_obj;
                nargs = 1;
            }
            failed = False;
            while True {
                arg = vargs.arg(ptr[PyObject]);
                if not arg {
                    break;
                }
                if nargs == capacity {
                    grown = grow_args(stack, small_stack, capacity);
                    if not grown {
                        failed = True;
                        break;
                    }
                    stack = grown;
                    capacity = capacity * 2;
                }
                (stack + nargs).view(1)[0] = arg;
                nargs += 1;
            }
            if not failed {
                result = vectorcall_tstate(tstate, callable, stack, u64(nargs), NULL);
            }
            free_args(stack, small_stack);
        }
        stackref_xclose(method_ref.view(1)[0]);
        stackref_xclose(self_ref.view(1)[0]);
        return result;
    }  def _PyObject_CallMethodIdObjArgs(
        obj_: ptr[PyObject], name: ptr, *vargs: VaList
    ) -> ptr[PyObject] {
        tstate = thread_state();
        if not obj_ or not name {
            return null_error(tstate);
        }

        oname = _PyUnicode_FromId(name);
        if not oname {
            return NULL;
        }
        callable = NULL;
        is_method = _PyObject_GetMethod(obj_, oname, &mut callable);
        if not callable {
            return NULL;
        }
        small: own ArgStack = ArgStack();
        small_stack = arg_array(jacpy_stack_address(&mut small));
        stack = small_stack;
        capacity = _PY_FASTCALL_SMALL_STACK;
        nargs: i64 = 0;
        if is_method != i32(0) {
            stack.view(1)[0] = obj_;
            nargs = 1;
        }
        failed = False;
        while True {
            arg = vargs.arg(ptr[PyObject]);
            if not arg {
                break;
            }
            if nargs == capacity {
                grown = grow_args(stack, small_stack, capacity);
                if not grown {
                    failed = True;
                    break;
                }
                stack = grown;
                capacity = capacity * 2;
            }
            (stack + nargs).view(1)[0] = arg;
            nargs += 1;
        }
        result = NULL;
        if not failed {
            result = vectorcall_tstate(tstate, callable, stack, u64(nargs), NULL);
        }
        free_args(stack, small_stack);
        object_decref(callable);
        return result;
    }  def PyObject_CallFunctionObjArgs(
        callable: ptr[PyObject], *vargs: VaList
    ) -> ptr[PyObject] {
        tstate = thread_state();
        if not callable {
            return null_error(tstate);
        }
        small: own ArgStack = ArgStack();
        small_stack = arg_array(jacpy_stack_address(&mut small));
        stack = small_stack;
        capacity = _PY_FASTCALL_SMALL_STACK;
        nargs: i64 = 0;
        while True {
            arg = vargs.arg(ptr[PyObject]);
            if not arg {
                break;
            }
            if nargs == capacity {
                grown = grow_args(stack, small_stack, capacity);
                if not grown {
                    free_args(stack, small_stack);
                    return NULL;
                }
                stack = grown;
                capacity = capacity * 2;
            }
            (stack + nargs).view(1)[0] = arg;
            nargs += 1;
        }
        result = vectorcall_tstate(tstate, callable, stack, u64(nargs), NULL);
        free_args(stack, small_stack);
        return result;
    }  def _PyStack_AsDict(
        values: ptr[ptr[PyObject]], kwnames: ptr[PyObject]
    ) -> ptr[PyObject] {
        return _PyDict_FromItems(
            tuple_items(kwnames), 1, values, 1, object_size(kwnames)
        );
    }  def _PyStack_UnpackDict(
        tstate: ptr[PyThreadState],
        args: ptr[ptr[PyObject]],
        nargs: i64,
        kwargs: ptr[PyObject],
        p_kwnames: ptr[ptr[PyObject]]
    ) -> ptr[ptr[PyObject]] {
        (stack, kwnames) = unpack_dict(args, nargs, kwargs);
        if stack {
            p_kwnames.view(1)[0] = kwnames;
        }
        return stack;
    }  def _PyStack_UnpackDict_Free(
        stack: ptr[ptr[PyObject]], nargs: i64, kwnames: ptr[PyObject]
    ) {
        n = object_size(kwnames) + nargs;
        for i in range(n) {
            object_decref((stack + i).view(1)[0]);
        }
        _PyStack_UnpackDict_FreeNoDecRef(stack, kwnames);
    }  def _PyStack_UnpackDict_FreeNoDecRef(
        stack: ptr[ptr[PyObject]], kwnames: ptr[PyObject]
    ) {
        PyMem_Free(ptr(stack - 1));
        object_decref(kwnames);
    }  def PyVectorcall_NARGS(n: u64) -> i64 {
        return vectorcall_nargs(n);
    }
}

impl thread_state -> ptr[PyThreadState] {
    return current_tstate();
}

impl exception_raised(tstate: ptr[PyThreadState]) -> bool {
    if ptr[ptr](ptr[u8](tstate) + PyThreadState_CURRENT_EXCEPTION).view(1)[0] {
        return True;
    }
    return False;
}

impl error_occurred(tstate: ptr[PyThreadState]) -> ptr[PyObject] {
    exc = ptr[ptr[PyObject]](ptr[u8](tstate) + PyThreadState_CURRENT_EXCEPTION).view(1)[
        0
    ];
    if not exc {
        return NULL;
    }
    return ptr[PyObject](object_type(exc));
}

impl vectorcall_nargs(nargsf: u64) -> i64 {
    return i64.wrap(nargsf & ~PY_VECTORCALL_ARGUMENTS_OFFSET);
}

impl tuple_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_TUPLE_SUBCLASS);
}

impl dict_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_DICT_SUBCLASS);
}

impl dict_size(op: ptr[PyObject]) -> i64 {
    return ptr[PyDictObject](op).view(1)[0].ma_used;
}

impl arg_array(address: int) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](address);
}

impl null_error(tstate: ptr[PyThreadState]) -> ptr[PyObject] {
    if not exception_raised(tstate) {
        PyErr_SetString(
            PyExc_SystemError, ptr[u8]("null argument to internal routine")
        );
    }
    return NULL;
}

impl vectorcall_function(callable: ptr[PyObject]) -> int {
    tp = object_type(callable);
    if not type_has_feature(tp, Py_TPFLAGS_HAVE_VECTORCALL) {
        return 0;
    }
    return int(
        ptr[ptr](ptr[u8](callable) + tp.view(1)[0].tp_vectorcall_offset).view(1)[0]
    );
}

impl call_vectorcall(
    func: int,
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    slot = ptr[CallSlot](__thread_local_block("jac_object_model_call_call_slot", 16));
    slot.view(1)[0].vectorcall = func;
    return slot.view(1)[0].vectorcall(callable, args, nargsf, kwnames);
}

impl call_ternary(
    func: int, callable: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    slot = ptr[CallSlot](__thread_local_block("jac_object_model_call_call_slot", 16));
    slot.view(1)[0].ternary = func;
    return slot.view(1)[0].ternary(callable, args, kwargs);
}

impl check_result(
    tstate: ptr[PyThreadState], callable: ptr[PyObject], result: ptr[PyObject]
) -> ptr[PyObject] {
    if result and not exception_raised(tstate) {
        return result;
    }
    return _Py_CheckFunctionResult(tstate, callable, result, ptr[u8]());
}

impl vectorcall_tstate(
    tstate: ptr[PyThreadState],
    callable: ptr[PyObject],
    args: ptr[ptr[PyObject]],
    nargsf: u64,
    kwnames: ptr[PyObject]
) -> ptr[PyObject] {
    tp = object_type(callable);
    if type_has_feature(tp, Py_TPFLAGS_HAVE_VECTORCALL) {
        vc_slot = ptr[u8](callable) + tp.view(1)[0].tp_vectorcall_offset;
        if ptr[ptr](vc_slot).view(1)[0] {
            res = ptr[VectorcallEntry](vc_slot).view(1)[0].call(
                callable, args, nargsf, kwnames
            );
            return check_result(tstate, callable, res);
        }
    }
    return _PyObject_MakeTpCall(
        tstate, callable, args, vectorcall_nargs(nargsf), kwnames
    );
}

impl object_is_not_callable(callable: ptr[PyObject]) {
    tp_name = object_type(callable).view(1)[0].tp_name;
    if object_is_type(callable, ptr[PyTypeObject](addressof(PyModule_Type))) {
        name = PyModule_GetNameObject(callable);
        if not name {
            PyErr_Clear();
        } else {
            attr = NULL;
            res = PyObject_GetOptionalAttr(callable, name, &mut attr);
            if res < 0 {
                PyErr_Clear();
            } elif res > 0 and PyCallable_Check(attr) != 0 {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8](
                        "'%.200s' object is not callable. Did you mean: '%U.%U(...)'?"
                    ),
                    tp_name,
                    name,
                    name
                );
                object_decref(attr);
                object_decref(name);
                return;
            }
            object_xdecref(attr);
            object_decref(name);
        }
    }
    PyErr_Format(PyExc_TypeError, ptr[u8]("'%.200s' object is not callable"), tp_name);
}

impl vectorcall_call(
    tstate: ptr[PyThreadState],
    func: int,
    callable: ptr[PyObject],
    argtuple: ptr[PyObject],
    kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    nargs = object_size(argtuple);

    if not kwargs or dict_size(kwargs) == 0 {
        return call_vectorcall(func, callable, tuple_items(argtuple), u64(nargs), NULL);
    }

    (args, kwnames) = unpack_dict(tuple_items(argtuple), nargs, kwargs);
    if not args {
        return NULL;
    }
    result = call_vectorcall(
        func, callable, args, u64(nargs) | PY_VECTORCALL_ARGUMENTS_OFFSET, kwnames
    );
    _PyStack_UnpackDict_Free(args, nargs, kwnames);
    return check_result(tstate, callable, result);
}

impl unpack_dict(
    args: ptr[ptr[PyObject]], nargs: i64, kwargs: ptr[PyObject]
) -> tuple[ptr[ptr[PyObject]], ptr[PyObject]] {
    nkwargs = dict_size(kwargs);

    maxnargs = PY_SSIZE_T_MAX // 8 - 1;
    if nargs > maxnargs - nkwargs {
        PyErr_NoMemory();
        return (ptr[ptr[PyObject]](), NULL);
    }

    block = ptr[ptr[PyObject]](PyMem_Malloc(u64((1 + nargs + nkwargs) * 8)));
    if not block {
        PyErr_NoMemory();
        return (block, NULL);
    }
    kwnames = PyTuple_New(nkwargs);
    if not kwnames {
        PyMem_Free(ptr(block));
        return (ptr[ptr[PyObject]](), NULL);
    }
    stack = block + 1;

    for k in range(nargs) {
        (stack + k).view(1)[0] = object_new_ref((args + k).view(1)[0]);
    }
    kwstack = stack + nargs;

    pos: i64 = 0;
    i: i64 = 0;
    key = NULL;
    value = NULL;
    keys_are_strings = Py_TPFLAGS_UNICODE_SUBCLASS;
    while PyDict_Next(kwargs, &mut pos, &mut key, &mut value) != 0 {
        keys_are_strings = keys_are_strings & object_type(key).view(1)[0].tp_flags;
        tuple_set_item(kwnames, i, object_new_ref(key));
        (kwstack + i).view(1)[0] = object_new_ref(value);
        i += 1;
    }

    if keys_are_strings == u64(0) {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("keywords must be strings"));
        _PyStack_UnpackDict_Free(stack, nargs, kwnames);
        return (ptr[ptr[PyObject]](), NULL);
    }
    return (stack, kwnames);
}

impl stackref_borrow(bits: u64) -> ptr[PyObject] {
    return ptr[PyObject](i64.wrap(bits & ~STACKREF_TAG));
}

impl stackref_xclose(bits: u64) {
    if (bits & STACKREF_TAG) == u64(0) {
        object_decref(ptr[PyObject](i64.wrap(bits)));
    }
}

impl grow_args(
    stack: ptr[ptr[PyObject]], small_stack: ptr[ptr[PyObject]], capacity: i64
) -> ptr[ptr[PyObject]] {
    size = u64(capacity * 2 * 8);
    grown = ptr[ptr[PyObject]]();
    if stack == small_stack {
        grown = ptr[ptr[PyObject]](PyMem_Malloc(size));
        if grown {
            memcpy(ptr(grown), ptr(stack), u64(capacity * 8));
        }
    } else {
        grown = ptr[ptr[PyObject]](PyMem_Realloc(ptr(stack), size));
    }
    if not grown {
        PyErr_NoMemory();
    }
    return grown;
}

impl free_args(stack: ptr[ptr[PyObject]], small_stack: ptr[ptr[PyObject]]) {
    if stack != small_stack {
        PyMem_Free(ptr(stack));
    }
}
