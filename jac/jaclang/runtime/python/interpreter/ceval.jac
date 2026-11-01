import from c {
    glob PyFrameLocalsProxy_Type: PyTypeObject,
         PyExc_NameError: ptr[PyObject],
         PyExc_UnboundLocalError: ptr[PyObject],
         PyExc_BaseExceptionGroup: ptr[PyObject]; obj CevalBinaryOp {
        has func: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0;
    }  obj CevalConversion {
        has func: Callable[[ptr[PyObject]], ptr[PyObject]] = 0;
    }  obj CevalSpecialMethod {
        has name: ptr[PyObject] = ptr[PyObject](),
            error: ptr[u8] = ptr[u8](),
            error_suggestion: ptr[u8] = ptr[u8]();
    }  obj CevalOffset {
        has offset: i64 = 0;
    }  obj CevalCodeUnits {
        has u0: u16 = 0,
            u1: u16 = 0,
            u2: u16 = 0,
            u3: u16 = 0,
            u4: u16 = 0;
    }  obj CevalEvalFrameHook {
        has call: Callable[[ptr[PyThreadState], ptr[u8], i32], ptr[PyObject]] = 0;
    }  def _Py_FatalErrorFunc(func: ptr[u8], message: ptr[u8]);  def snprintf(
        buf: ptr[u8], size: u64, format_: ptr[u8], *args: any
    ) -> i32;  def _PyErr_Format(
        tstate: ptr[PyThreadState],
        exception: ptr[PyObject],
        format_: ptr[u8],
        *args: any
    ) -> ptr[PyObject];  def _PyErr_SetString(
        tstate: ptr[PyThreadState], exception: ptr[PyObject], message: ptr[u8]
    );  def _PyErr_Clear(tstate: ptr[PyThreadState]);  def _PyErr_ExceptionMatches(
        tstate: ptr[PyThreadState], exc: ptr[PyObject]
    ) -> i32;  def _PyErr_GetRaisedException(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyObject];  def _PyErr_SetRaisedException(
        tstate: ptr[PyThreadState], exc: ptr[PyObject]
    );  def _PyEval_StopTheWorld(interp: ptr[u8]);  def _PyEval_StartTheWorld(
        interp: ptr[u8]
    );  def pthread_self -> u64;  def pthread_getattr_np(
        thread: u64, attr: ptr[u8]
    ) -> i32;  def pthread_attr_getguardsize(
        attr: ptr[u8], guardsize: ptr[u64]
    ) -> i32;  def pthread_attr_getstack(
        attr: ptr[u8], stackaddr: ptr[u64], stacksize: ptr[u64]
    ) -> i32;  def pthread_attr_destroy(attr: ptr[u8]) -> i32;  def pthread_get_stackaddr_np(
        thread: u64
    ) -> ptr[u8];  def pthread_get_stacksize_np(thread: u64) -> u64;  def _PyObject_GetMethodStackRef(
        ts: ptr[PyThreadState],
        self_ref: ptr[u64],
        name: ptr[PyObject],
        method: ptr[u64]
    ) -> i32;  def PyMapping_GetOptionalItem(
        obj_: ptr[PyObject], key: ptr[PyObject], result: &mut ptr[PyObject]
    ) -> i32;  def _PyDict_LoadBuiltinsFromGlobals(
        globals: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyFunction_FromConstructor(
        constr: ptr[u8]
    ) -> ptr[PyObject];  def _PyThreadState_PushFrame(
        tstate: ptr[PyThreadState], size: u64
    ) -> ptr[u8];  def _PyThreadState_PopFrame(
        tstate: ptr[PyThreadState], frame: ptr[u8]
    );  def _PyFrame_ClearExceptCode(frame: ptr[u8]);  def _PyFrame_GetLocals(
        frame: ptr[u8]
    ) -> ptr[PyObject];  def _PyTuple_FromStackRefStealOnSuccess(
        src: ptr[u64], n: i64
    ) -> ptr[PyObject];  def _PyExc_CreateExceptionGroup(
        msg_str: ptr[u8], excs: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyTraceBack_FromFrame(
        tb_next: ptr[PyObject], frame: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_Instrument(code: ptr[u8], interp: ptr[u8]) -> i32;  def _PyEval_SetProfileAllThreads(
        interp: ptr[u8], func: ptr, arg: ptr[PyObject]
    ) -> i32;  def _PyEval_SetTrace(
        tstate: ptr[PyThreadState], func: ptr, arg: ptr[PyObject]
    ) -> i32;  def _PyEval_SetTraceAllThreads(
        interp: ptr[u8], func: ptr, arg: ptr[PyObject]
    ) -> i32;  def _PySys_Audit(
        tstate: ptr[PyThreadState], event: ptr[u8], format_: ptr[u8], *args: any
    ) -> i32;  def _PyUnicode_FromId(id: ptr) -> ptr[PyObject];  def _PyInterpreterState_IsRunningMain(
        interp: ptr[u8]
    ) -> i32;  def _Py_GetMainModule(tstate: ptr[PyThreadState]) -> ptr[PyObject];  def _Py_CheckMainModule(
        module: ptr[PyObject]
    ) -> i32;  def PyImport_ImportModuleLevel(
        name: ptr[u8],
        globals: ptr[PyObject],
        locals: ptr[PyObject],
        fromlist: ptr[PyObject],
        level: i32
    ) -> ptr[PyObject];  def PyImport_ImportModuleLevelObject(
        name: ptr[PyObject],
        globals: ptr[PyObject],
        locals: ptr[PyObject],
        fromlist: ptr[PyObject],
        level: i32
    ) -> ptr[PyObject];  def _PyImport_IsDefaultImportFunc(
        interp: ptr[u8], func: ptr[PyObject]
    ) -> i32;  def _PyModuleSpec_GetFileOrigin(
        spec: ptr[PyObject], p_origin: &mut ptr[PyObject]
    ) -> i32;  def _PyModule_IsPossiblyShadowing(origin: ptr[PyObject]) -> i32;  def PyModule_GetFilenameObject(
        module: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyModuleSpec_IsInitializing(spec: ptr[PyObject]) -> i32;  def _PyErr_SetImportErrorWithNameFrom(
        msg: ptr[PyObject],
        name: ptr[PyObject],
        path: ptr[PyObject],
        from_name: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyObject_FunctionStr(x: ptr[PyObject]) -> ptr[PyObject];  def PyException_GetArgs(
        exc: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyDict_LoadGlobalStackRef(
        globals: ptr[PyObject],
        builtins: ptr[PyObject],
        key: ptr[PyObject],
        res: ptr[u64]
    );  def _PyGen_yf(gen: ptr[PyObject]) -> ptr[PyObject];  def _PyType_Lookup(
        type: ptr[PyTypeObject], name: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyNumber_PowerNoMod(
        lhs: ptr[PyObject], rhs: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyNumber_InPlacePowerNoMod(
        lhs: ptr[PyObject], rhs: ptr[PyObject]
    ) -> ptr[PyObject];  def PyObject_ASCII(v: ptr[PyObject]) -> ptr[PyObject];  @__preserve_none
    def _TAIL_CALL_start_frame(
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
    ) -> ptr[PyObject];
}

glob CEVAL_STACK_MARGIN_BYTES: Final[u64] = u64(16384),
     CEVAL_MIN_STACK_SIZE: Final[u64] = u64(49152),
     CEVAL_C_STACK_SIZE: Final[u64] = u64(4000000),
     CEVAL_SYSTEM_PAGE_SIZE: Final[u64] = u64(4096),
     CEVAL_MAX_STACKREF_SCRATCH: Final[i64] = 10,
     CEVAL_STACK_ARRAY_SIZE: Final[u64] = u64(8),
     CEVAL_MAX_CO_EXTRA_USERS: Final[i64] = 255,
     CEVAL_PYCF_MASK: Final[i32] = 0x1FE0000;

import from c {
    glob _PyEval_BinaryOps: list[CevalBinaryOp] = [
             CevalBinaryOp(func=PyNumber_Add),
             CevalBinaryOp(func=PyNumber_And),
             CevalBinaryOp(func=PyNumber_FloorDivide),
             CevalBinaryOp(func=PyNumber_Lshift),
             CevalBinaryOp(func=PyNumber_MatrixMultiply),
             CevalBinaryOp(func=PyNumber_Multiply),
             CevalBinaryOp(func=PyNumber_Remainder),
             CevalBinaryOp(func=PyNumber_Or),
             CevalBinaryOp(func=_PyNumber_PowerNoMod),
             CevalBinaryOp(func=PyNumber_Rshift),
             CevalBinaryOp(func=PyNumber_Subtract),
             CevalBinaryOp(func=PyNumber_TrueDivide),
             CevalBinaryOp(func=PyNumber_Xor),
             CevalBinaryOp(func=PyNumber_InPlaceAdd),
             CevalBinaryOp(func=PyNumber_InPlaceAnd),
             CevalBinaryOp(func=PyNumber_InPlaceFloorDivide),
             CevalBinaryOp(func=PyNumber_InPlaceLshift),
             CevalBinaryOp(func=PyNumber_InPlaceMatrixMultiply),
             CevalBinaryOp(func=PyNumber_InPlaceMultiply),
             CevalBinaryOp(func=PyNumber_InPlaceRemainder),
             CevalBinaryOp(func=PyNumber_InPlaceOr),
             CevalBinaryOp(func=_PyNumber_InPlacePowerNoMod),
             CevalBinaryOp(func=PyNumber_InPlaceRshift),
             CevalBinaryOp(func=PyNumber_InPlaceSubtract),
             CevalBinaryOp(func=PyNumber_InPlaceTrueDivide),
             CevalBinaryOp(func=PyNumber_InPlaceXor),
             CevalBinaryOp(func=PyObject_GetItem)
         ]; glob _PyEval_ConversionFuncs: list[CevalConversion] = [
             CevalConversion(),
             CevalConversion(func=PyObject_Str),
             CevalConversion(func=PyObject_Repr),
             CevalConversion(func=PyObject_ASCII)
         ]; glob _Py_SpecialMethods: list[CevalSpecialMethod] = [
             CevalSpecialMethod(
                 error=ptr[u8](
                     "'%T' object does not support the context manager protocol (missed __enter__ method)"
                 ),
                 error_suggestion=ptr[u8](
                     "'%T' object does not support the context manager protocol (missed __enter__ method) but it supports the asynchronous context manager protocol. Did you mean to use 'async with'?"
                 )
             ),
             CevalSpecialMethod(
                 error=ptr[u8](
                     "'%T' object does not support the context manager protocol (missed __exit__ method)"
                 ),
                 error_suggestion=ptr[u8](
                     "'%T' object does not support the context manager protocol (missed __exit__ method) but it supports the asynchronous context manager protocol. Did you mean to use 'async with'?"
                 )
             ),
             CevalSpecialMethod(
                 error=ptr[u8](
                     "'%T' object does not support the asynchronous context manager protocol (missed __aenter__ method)"
                 ),
                 error_suggestion=ptr[u8](
                     "'%T' object does not support the asynchronous context manager protocol (missed __aenter__ method) but it supports the context manager protocol. Did you mean to use 'with'?"
                 )
             ),
             CevalSpecialMethod(
                 error=ptr[u8](
                     "'%T' object does not support the asynchronous context manager protocol (missed __aexit__ method)"
                 ),
                 error_suggestion=ptr[u8](
                     "'%T' object does not support the asynchronous context manager protocol (missed __aexit__ method) but it supports the context manager protocol. Did you mean to use 'with'?"
                 )
             )
         ]; glob _Py_FunctionAttributeOffsets: list[CevalOffset] = [
             CevalOffset(),
             CevalOffset(offset=PyFunctionObject_DEFAULTS),
             CevalOffset(offset=PyFunctionObject_KWDEFAULTS),
             CevalOffset(),
             CevalOffset(offset=PyFunctionObject_ANNOTATIONS),
             CevalOffset(),
             CevalOffset(),
             CevalOffset(),
             CevalOffset(offset=PyFunctionObject_CLOSURE),
             CevalOffset(),
             CevalOffset(),
             CevalOffset(),
             CevalOffset(),
             CevalOffset(),
             CevalOffset(),
             CevalOffset(),
             CevalOffset(offset=PyFunctionObject_ANNOTATE)
         ]; glob:priv _Py_INTERPRETER_TRAMPOLINE_INSTRUCTIONS: CevalCodeUnits = CevalCodeUnits(
             u0=27, u1=20, u2=27, u3=20, u4=1152
         );
}

def ceval_u64_at(base: ptr[u8], offset: i64) -> u64;

def ceval_set_u64_at(base: ptr[u8], offset: i64, value: u64);

def ceval_set_i32_at(base: ptr[u8], offset: i64, value: i32);

def ceval_obj_at(base: ptr[u8], offset: i64) -> ptr[PyObject];

def ceval_set_obj_at(base: ptr[u8], offset: i64, value: ptr[PyObject]);

def ceval_interp(tstate: ptr[PyThreadState]) -> ptr[u8];

def ceval_current_frame(tstate: ptr[PyThreadState]) -> ptr[u8];

def ceval_set_current_frame(tstate: ptr[PyThreadState], frame: ptr[u8]);

def ceval_thread_frame(tstate: ptr[PyThreadState]) -> ptr[u8];

def ceval_frame_code(frame: ptr[u8]) -> ptr[u8];

def ceval_err_occurred(tstate: ptr[PyThreadState]) -> bool;

def ceval_tp_name(op: ptr[PyObject]) -> ptr[u8];

def ceval_tuple_empty -> ptr[PyObject];

def ceval_list_items(lst: ptr[PyObject]) -> ptr[ptr[PyObject]];

def ceval_is_type(op: ptr[PyObject], type: ptr[PyObject]) -> bool;

def ceval_stack_pointer -> u64;

def ceval_make_rec_check(tstate: ptr[PyThreadState]) -> bool;

def ceval_enter_recursive_call(tstate: ptr[PyThreadState], where: ptr[u8]) -> bool;

def ceval_enter_recursive_py(tstate: ptr[PyThreadState]) -> bool;

def ceval_kbytes_used(top: u64, here: u64) -> i32;

def ceval_init_special_methods;

def hardware_stack_limits(sp: u64) -> tuple[u64, u64];

def tstate_set_stack(tstate: ptr[PyThreadState], base: u64, top: u64);

def match_class_attr(
    tstate: ptr[PyThreadState],
    subject: ptr[PyObject],
    type: ptr[PyObject],
    name: ptr[PyObject],
    seen: ptr[PyObject]
) -> ptr[PyObject];

def match_class_fail(
    match_args: ptr[PyObject], seen: ptr[PyObject], attrs: ptr[PyObject]
) -> ptr[PyObject];

def match_keys_done(
    tstate: ptr[PyThreadState],
    refs: ptr[u64],
    seen: ptr[PyObject],
    dummy: ptr[PyObject],
    values: ptr[PyObject]
) -> ptr[PyObject];

def match_keys_fail(
    refs: ptr[u64], seen: ptr[PyObject], dummy: ptr[PyObject], values: ptr[PyObject]
) -> ptr[PyObject];

def ceval_eval_frame(
    tstate: ptr[PyThreadState], frame: ptr[u8], throwflag: i32
) -> ptr[PyObject];

def monitor_throw(tstate: ptr[PyThreadState], frame: ptr[u8], instr: ptr[u16]);

def eval_frame_early_exit(tstate: ptr[PyThreadState], dying: ptr[u8]) -> ptr[PyObject];

def format_missing(
    tstate: ptr[PyThreadState],
    kind: ptr[u8],
    co: ptr[u8],
    names: ptr[PyObject],
    qualname: ptr[PyObject]
);

def missing_arguments(
    tstate: ptr[PyThreadState],
    co: ptr[u8],
    missing: i64,
    defcount: i64,
    localsplus: ptr[u64],
    qualname: ptr[PyObject]
);

def too_many_positional(
    tstate: ptr[PyThreadState],
    co: ptr[u8],
    given: i64,
    defaults: ptr[PyObject],
    localsplus: ptr[u64],
    qualname: ptr[PyObject]
);

def positional_only_passed_as_keyword(
    tstate: ptr[PyThreadState],
    co: ptr[u8],
    kwcount: i64,
    kwnames: ptr[PyObject],
    qualname: ptr[PyObject]
) -> i32;

def unexpected_keyword(
    tstate: ptr[PyThreadState],
    co: ptr[u8],
    kwcount: i64,
    kwnames: ptr[PyObject],
    qualname: ptr[PyObject],
    keyword: ptr[PyObject],
    total_args: i64
);

def close_refs(refs: ptr[u64], start: i64, end: i64);

def close_kwarg_refs(args: ptr[u64], argcount: i64, kwnames: ptr[PyObject]);

def initialize_locals(
    tstate: ptr[PyThreadState],
    func: ptr[PyObject],
    localsplus: ptr[u64],
    args: ptr[u64],
    argcount: i64,
    kwnames: ptr[PyObject]
) -> i32;

def clear_thread_frame(tstate: ptr[PyThreadState], frame: ptr[u8]);

def clear_gen_frame(tstate: ptr[PyThreadState], frame: ptr[u8]);

def get_globals_builtins(globals: ptr[PyObject]) -> ptr[PyObject];

def set_globals_builtins(globals: ptr[PyObject], builtins: ptr[PyObject]) -> i32;

def _PyEval_GetGlobals(tstate: ptr[PyThreadState]) -> ptr[PyObject];

def import_from_done(
    origin: ptr[PyObject], spec: ptr[PyObject], mod_name_or_unknown: ptr[PyObject]
) -> ptr[PyObject];

def import_from_raise(
    errmsg: ptr[PyObject],
    mod_name: ptr[PyObject],
    origin: ptr[PyObject],
    name: ptr[PyObject],
    spec: ptr[PyObject],
    mod_name_or_unknown: ptr[PyObject]
) -> ptr[PyObject];

def import_from_error(
    tstate: ptr[PyThreadState],
    v: ptr[PyObject],
    name: ptr[PyObject],
    mod_name: ptr[PyObject]
) -> ptr[PyObject];

def type_has_special_method(cls: ptr[PyTypeObject], name: ptr[PyObject]) -> bool;

def index_check(v: ptr[PyObject]) -> bool;

import from c {
    def Py_GetRecursionLimit -> i32 {
        return call_i32_at(current_interp(), PyInterpreterState_CEVAL_RECURSION_LIMIT);
    }  def Py_SetRecursionLimit(new_limit: i32) {
        interp = current_interp();
        _PyEval_StopTheWorld(interp);
        ceval_set_i32_at(interp, PyInterpreterState_CEVAL_RECURSION_LIMIT, new_limit);
        runtime = call_ptr_at(interp, PyInterpreterState_RUNTIME);
        head_lock(runtime);
        p = call_ptr_at(interp, PyInterpreterState_THREADS_HEAD);
        while p {
            depth = i64(call_i32_at(p, PyThreadState_PY_RECURSION_LIMIT))
                - i64(call_i32_at(p, PyThreadState_PY_RECURSION_REMAINING));
            ceval_set_i32_at(p, PyThreadState_PY_RECURSION_LIMIT, new_limit);
            ceval_set_i32_at(
                p,
                PyThreadState_PY_RECURSION_REMAINING,
                i32.wrap(i64(new_limit) - depth)
            );
            p = call_ptr_at(p, PyThreadState_NEXT);
        }
        head_unlock(runtime);
        _PyEval_StartTheWorld(interp);
    }  def _Py_ReachedRecursionLimitWithMargin(
        tstate: ptr[PyThreadState], margin_count: i32
    ) -> i32 {
        here_addr = ceval_stack_pointer();
        ts = ptr[u8](tstate);
        margin = u64.wrap(i64(margin_count) * i64(CEVAL_STACK_MARGIN_BYTES));
        soft = ceval_u64_at(ts, _PyThreadStateImpl_C_STACK_SOFT_LIMIT);
        if here_addr > wrapping_add(soft, margin) {
            return 0;
        }
        if ceval_u64_at(ts, _PyThreadStateImpl_C_STACK_HARD_LIMIT) == u64(0) {
            _Py_InitializeRecursionLimits(tstate);
        }
        soft = ceval_u64_at(ts, _PyThreadStateImpl_C_STACK_SOFT_LIMIT);
        if here_addr <= wrapping_add(soft, margin)
            and here_addr >= wrapping_sub(soft, u64(2) * CEVAL_STACK_MARGIN_BYTES) {
            return 1;
        }
        return 0;
    }  def _Py_EnterRecursiveCallUnchecked(tstate: ptr[PyThreadState]) {
        here_addr = ceval_stack_pointer();
        if here_addr
            < ceval_u64_at(ptr[u8](tstate), _PyThreadStateImpl_C_STACK_HARD_LIMIT) {
            _Py_FatalErrorFunc(
                ptr[u8]("_Py_EnterRecursiveCallUnchecked"),
                ptr[u8]("Unchecked stack overflow.")
            );
        }
    }  def _Py_InitializeRecursionLimits(tstate: ptr[PyThreadState]) {
        here_addr = ceval_stack_pointer();
        (base, top) = hardware_stack_limits(here_addr);
        tstate_set_stack(tstate, base, top);
        ts = ptr[u8](tstate);
        ceval_set_u64_at(ts, _PyThreadStateImpl_C_STACK_INIT_BASE, base);
        ceval_set_u64_at(ts, _PyThreadStateImpl_C_STACK_INIT_TOP, top);
        ceval_init_special_methods();
    }  def PyUnstable_ThreadState_SetStackProtection(
        tstate: ptr[PyThreadState], stack_start_addr: ptr, stack_size: u64
    ) -> i32 {
        if stack_size < CEVAL_MIN_STACK_SIZE {
            min_size = i64(CEVAL_MIN_STACK_SIZE);
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8]("stack_size must be at least %zu bytes"),
                min_size
            );
            return -1;
        }
        base = u64(int(stack_start_addr));
        tstate_set_stack(tstate, base, wrapping_add(base, stack_size));
        return 0;
    }  def PyUnstable_ThreadState_ResetStackProtection(tstate: ptr[PyThreadState]) {
        ts = ptr[u8](tstate);
        init_top = ceval_u64_at(ts, _PyThreadStateImpl_C_STACK_INIT_TOP);
        if init_top != u64(0) {
            tstate_set_stack(
                tstate, ceval_u64_at(ts, _PyThreadStateImpl_C_STACK_INIT_BASE), init_top
            );
            return;
        }
        _Py_InitializeRecursionLimits(tstate);
    }  def _Py_CheckRecursiveCall(tstate: ptr[PyThreadState], where: ptr[u8]) -> i32 {
        ts = ptr[u8](tstate);
        here_addr = ceval_stack_pointer();
        top = ceval_u64_at(ts, _PyThreadStateImpl_C_STACK_TOP);
        if here_addr < ceval_u64_at(ts, _PyThreadStateImpl_C_STACK_HARD_LIMIT) {
            overflow_kbytes = ceval_kbytes_used(top, here_addr);
            buffer = ptr[u8](__alloca(80));
            snprintf(
                buffer,
                u64(80),
                ptr[u8]("Unrecoverable stack overflow (used %d kB)%s"),
                overflow_kbytes,
                where
            );
            _Py_FatalErrorFunc(ptr[u8]("_Py_CheckRecursiveCall"), buffer);
        }
        headroom = call_i32_at(ts, PyThreadState_RECURSION_HEADROOM);
        if headroom != 0 {
            return 0;
        }
        kbytes_used = ceval_kbytes_used(top, here_addr);
        ceval_set_i32_at(ts, PyThreadState_RECURSION_HEADROOM, headroom + 1);
        _PyErr_Format(
            tstate,
            PyExc_RecursionError,
            ptr[u8]("Stack overflow (used %d kB)%s"),
            kbytes_used,
            where
        );
        ceval_set_i32_at(
            ts,
            PyThreadState_RECURSION_HEADROOM,
            call_i32_at(ts, PyThreadState_RECURSION_HEADROOM) - 1
        );
        return -1;
    }  def _PyEval_MatchKeys(
        tstate: ptr[PyThreadState], map_: ptr[PyObject], keys: ptr[PyObject]
    ) -> ptr[PyObject] {
        nkeys = object_size(keys);
        if nkeys == 0 {
            return PyTuple_New(0);
        }
        seen: ptr[PyObject] = NULL;
        dummy: ptr[PyObject] = NULL;
        values: ptr[PyObject] = NULL;
        refs = ptr[u64](__alloca(16));
        refs.view(2)[0] = SR_NULL;
        refs.view(2)[1] = SR_NULL;
        refs.view(2)[0] = sr_from_borrow(map_);
        res = _PyObject_GetMethodStackRef(tstate, refs, py_id(_Py_ID_get), refs + 1);
        if res < 0 {
            return match_keys_fail(refs, seen, dummy, values);
        }
        get = sr_borrow(refs.view(2)[1]);
        seen = PySet_New(NULL);
        if not seen {
            return match_keys_fail(refs, seen, dummy, values);
        }
        dummy = PyObject_CallNoArgs(addressof(PyBaseObject_Type));
        if not dummy {
            return match_keys_fail(refs, seen, dummy, values);
        }
        values = PyTuple_New(nkeys);
        if not values {
            return match_keys_fail(refs, seen, dummy, values);
        }
        args = ptr[ptr[PyObject]](__alloca(24));
        for i in range(nkeys) {
            key = tuple_get_item(keys, i);
            if PySet_Contains(seen, key) != 0 or PySet_Add(seen, key) != 0 {
                if not ceval_err_occurred(tstate) {
                    _PyErr_Format(
                        tstate,
                        PyExc_ValueError,
                        ptr[u8]("mapping pattern checks duplicate key (%R)"),
                        key
                    );
                }
                return match_keys_fail(refs, seen, dummy, values);
            }
            args.view(3)[0] = sr_borrow(refs.view(2)[0]);
            args.view(3)[1] = key;
            args.view(3)[2] = dummy;
            value: ptr[PyObject] = NULL;
            if not sr_is_null(refs.view(2)[0]) {
                value = PyObject_Vectorcall(get, args, u64(3), NULL);
            } else {
                value = PyObject_Vectorcall(get, args + 1, u64(2), NULL);
            }
            if not value {
                return match_keys_fail(refs, seen, dummy, values);
            }
            if value == dummy {
                object_decref(value);
                object_decref(values);
                return match_keys_done(
                    tstate, refs, seen, dummy, object_new_ref(Py_None)
                );
            }
            tuple_set_item(values, i, value);
        }
        return match_keys_done(tstate, refs, seen, dummy, values);
    }  def _PyEval_MatchClass(
        tstate: ptr[PyThreadState],
        subject: ptr[PyObject],
        type: ptr[PyObject],
        nargs: i64,
        kwargs: ptr[PyObject]
    ) -> ptr[PyObject] {
        if not ceval_type_check(type) {
            _PyErr_Format(
                tstate, PyExc_TypeError, ptr[u8]("called match pattern must be a class")
            );
            return NULL;
        }
        if PyObject_IsInstance(subject, type) <= 0 {
            return NULL;
        }
        seen = PySet_New(NULL);
        if not seen {
            return NULL;
        }
        attrs = PyList_New(0);
        if not attrs {
            object_decref(seen);
            return NULL;
        }
        type_name = ptr[PyTypeObject](type).view(1)[0].tp_name;
        match_args: ptr[PyObject] = NULL;
        if nargs != 0 {
            match_self = False;
            if PyObject_GetOptionalAttr(
                type, py_id(_Py_ID___match_args__), &mut match_args
            )
                < 0 {
                return match_class_fail(match_args, seen, attrs);
            }
            if match_args {
                if not tuple_check_exact(match_args) {
                    _PyErr_Format(
                        tstate,
                        PyExc_TypeError,
                        ptr[u8]("%s.__match_args__ must be a tuple (got %s)"),
                        type_name,
                        ceval_tp_name(match_args)
                    );
                    return match_class_fail(match_args, seen, attrs);
                }
            } else {
                match_args = PyTuple_New(0);
                match_self = type_has_feature(
                    ptr[PyTypeObject](type), _Py_TPFLAGS_MATCH_SELF
                );
            }
            allowed: i64 = 1;
            if not match_self {
                allowed = object_size(match_args);
            }
            if allowed < nargs {
                plural = ptr[u8]("s");
                if allowed == 1 {
                    plural = ptr[u8]("");
                }
                _PyErr_Format(
                    tstate,
                    PyExc_TypeError,
                    ptr[u8]("%s() accepts %zd positional sub-pattern%s (%zd given)"),
                    type_name,
                    allowed,
                    plural,
                    nargs
                );
                return match_class_fail(match_args, seen, attrs);
            }
            if match_self {
                if PyList_Append(attrs, subject) < 0 {
                    return match_class_fail(match_args, seen, attrs);
                }
            } else {
                for i in range(nargs) {
                    name = tuple_get_item(match_args, i);
                    if not ceval_unicode_check_exact(name) {
                        _PyErr_Format(
                            tstate,
                            PyExc_TypeError,
                            ptr[u8]("__match_args__ elements must be strings (got %s)"),
                            ceval_tp_name(name)
                        );
                        return match_class_fail(match_args, seen, attrs);
                    }
                    attr = match_class_attr(tstate, subject, type, name, seen);
                    if not attr {
                        return match_class_fail(match_args, seen, attrs);
                    }
                    if PyList_Append(attrs, attr) < 0 {
                        object_decref(attr);
                        return match_class_fail(match_args, seen, attrs);
                    }
                    object_decref(attr);
                }
            }
            object_decref(match_args);
            match_args = NULL;
        }
        nkwargs = object_size(kwargs);
        for i in range(nkwargs) {
            name = tuple_get_item(kwargs, i);
            attr = match_class_attr(tstate, subject, type, name, seen);
            if not attr {
                return match_class_fail(match_args, seen, attrs);
            }
            if PyList_Append(attrs, attr) < 0 {
                object_decref(attr);
                return match_class_fail(match_args, seen, attrs);
            }
            object_decref(attr);
        }
        result = PyList_AsTuple(attrs);
        object_decref(attrs);
        object_decref(seen);
        return result;
    }  def PyEval_EvalCode(
        co: ptr[PyObject], globals: ptr[PyObject], locals: ptr[PyObject]
    ) -> ptr[PyObject] {
        tstate = current_tstate();
        if not locals {
            locals = globals;
        }
        builtins = _PyDict_LoadBuiltinsFromGlobals(globals);
        if not builtins {
            return NULL;
        }
        co_name = ceval_obj_at(ptr[u8](co), PyCodeObject_NAME);
        desc = ptr[ptr[PyObject]](__alloca(64));
        desc.view(8)[0] = globals;
        desc.view(8)[1] = builtins;
        desc.view(8)[2] = co_name;
        desc.view(8)[3] = co_name;
        desc.view(8)[4] = co;
        desc.view(8)[5] = NULL;
        desc.view(8)[6] = NULL;
        desc.view(8)[7] = NULL;
        func = _PyFunction_FromConstructor(ptr[u8](desc));
        object_decref(builtins);
        if not func {
            return NULL;
        }
        res = _PyEval_Vector(tstate, func, locals, ptr[ptr[PyObject]](), u64(0), NULL);
        object_decref(func);
        return res;
    }  def PyEval_EvalFrame(f: ptr[PyObject]) -> ptr[PyObject] {
        return ceval_eval_frame(
            current_tstate(), call_ptr_at(ptr[u8](f), PyFrameObject_F_FRAME), 0
        );
    }  def PyEval_EvalFrameEx(f: ptr[PyObject], throwflag: i32) -> ptr[PyObject] {
        return ceval_eval_frame(
            current_tstate(), call_ptr_at(ptr[u8](f), PyFrameObject_F_FRAME), throwflag
        );
    }  def _Py_LoadAttr_StackRefSteal(
        tstate: ptr[PyThreadState],
        owner: u64,
        name: ptr[PyObject],
        self_or_null: ptr[u64]
    ) -> u64 {
        refs = ptr[u64](__alloca(16));
        refs.view(2)[0] = SR_NULL;
        refs.view(2)[1] = SR_NULL;
        refs.view(2)[1] = owner;
        _PyObject_GetMethodStackRef(tstate, refs + 1, name, refs);
        self_or_null.view(1)[0] = refs.view(2)[1];
        return refs.view(2)[0];
    }  def _Py_CheckRecursiveCallPy(tstate: ptr[PyThreadState]) -> i32 {
        ts = ptr[u8](tstate);
        remaining = call_i32_at(ts, PyThreadState_PY_RECURSION_REMAINING);
        headroom = call_i32_at(ts, PyThreadState_RECURSION_HEADROOM);
        if headroom != 0 {
            if remaining < -50 {
                _Py_FatalErrorFunc(
                    ptr[u8]("_Py_CheckRecursiveCallPy"),
                    ptr[u8]("Cannot recover from Python stack overflow.")
                );
            }
        } else {
            if remaining <= 0 {
                ceval_set_i32_at(ts, PyThreadState_RECURSION_HEADROOM, headroom + 1);
                _PyErr_Format(
                    tstate,
                    PyExc_RecursionError,
                    ptr[u8]("maximum recursion depth exceeded")
                );
                ceval_set_i32_at(
                    ts,
                    PyThreadState_RECURSION_HEADROOM,
                    call_i32_at(ts, PyThreadState_RECURSION_HEADROOM) - 1
                );
                return -1;
            }
        }
        return 0;
    }  def _PyObjectArray_FromStackRefArray(
        refs: ptr[u64], nargs: i64, scratch: ptr[ptr[PyObject]]
    ) -> ptr[ptr[PyObject]] {
        result = scratch;
        if nargs > CEVAL_MAX_STACKREF_SCRATCH {
            result = ptr[ptr[PyObject]](PyMem_Malloc(u64(nargs + 1) * u64(8)));
            if not result {
                return ptr[ptr[PyObject]]();
            }
            result = result + 1;
        }
        for i in range(nargs) {
            (result + i).view(1)[0] = sr_borrow((refs + i).view(1)[0]);
        }
        return result;
    }  def _PyObjectArray_Free(array: ptr[ptr[PyObject]], scratch: ptr[ptr[PyObject]]) {
        if array != scratch {
            PyMem_Free(ptr(array));
        }
    }  def _PyEval_EvalFrameDefault(
        tstate: ptr[PyThreadState], frame: ptr[u8], throwflag: i32
    ) -> ptr[PyObject] {
        entry_frame = ptr[u8](__alloca(128));
        if ceval_enter_recursive_call(tstate, ptr[u8]("")) {
            _PyEval_FrameClearAndPop(tstate, frame);
            return NULL;
        }
        stack = ptr[u64](entry_frame + (_PyInterpreterFrame_LOCALSPLUS + 8));
        stack.view(1)[0] = SR_NULL;
        call_set_ref_at(entry_frame, _PyInterpreterFrame_F_EXECUTABLE, sr_none());
        call_set_ref_at(entry_frame, _PyInterpreterFrame_F_FUNCOBJ, SR_NULL);
        call_set_ptr_at(entry_frame, _PyInterpreterFrame_F_GLOBALS, ptr[u8]());
        call_set_ptr_at(entry_frame, _PyInterpreterFrame_F_BUILTINS, ptr[u8]());
        call_set_ptr_at(entry_frame, _PyInterpreterFrame_F_LOCALS, ptr[u8]());
        call_set_ptr_at(entry_frame, _PyInterpreterFrame_FRAME_OBJ, ptr[u8]());
        call_set_ptr_at(
            entry_frame,
            _PyInterpreterFrame_INSTR_PTR,
            ptr[u8](ptr[u16](addressof(_Py_INTERPRETER_TRAMPOLINE_INSTRUCTIONS)) + 1)
        );
        call_set_ptr_at(entry_frame, _PyInterpreterFrame_STACKPOINTER, ptr[u8](stack));
        (entry_frame + _PyInterpreterFrame_OWNER).view(1)[0] = u8(
            FRAME_OWNED_BY_INTERPRETER
        );
        (entry_frame + _PyInterpreterFrame_VISITED).view(1)[0] = u8(0);
        ptr[u16](entry_frame + _PyInterpreterFrame_RETURN_OFFSET).view(1)[0] = u16(0);
        call_set_ptr_at(
            entry_frame, _PyInterpreterFrame_PREVIOUS, ceval_current_frame(tstate)
        );
        call_set_ptr_at(frame, _PyInterpreterFrame_PREVIOUS, entry_frame);
        ceval_set_current_frame(tstate, frame);
        call_set_ref_at(entry_frame, _PyInterpreterFrame_LOCALSPLUS, SR_NULL);
        if throwflag != 0 {
            if ceval_enter_recursive_py(tstate) {
                return eval_frame_early_exit(tstate, frame);
            }
            _Py_Instrument(ceval_frame_code(frame), ceval_interp(tstate));
            next_instr = ptr[u16](call_ptr_at(frame, _PyInterpreterFrame_INSTR_PTR));
            monitor_throw(tstate, frame, next_instr);
            stack_pointer = ptr[u64](
                call_ptr_at(frame, _PyInterpreterFrame_STACKPOINTER)
            );
            return _TAIL_CALL_error(frame, stack_pointer, ptr(tstate), next_instr, 0);
        }
        return _TAIL_CALL_start_frame(frame, ptr[u64](), ptr(tstate), ptr[u16](), 0);
    }  def _PyEval_FrameClearAndPop(tstate: ptr[PyThreadState], frame: ptr[u8]) {
        if i32((frame + _PyInterpreterFrame_OWNER).view(1)[0])
            == FRAME_OWNED_BY_THREAD {
            clear_thread_frame(tstate, frame);
        } else {
            clear_gen_frame(tstate, frame);
        }
    }  def _PyEvalFramePushAndInit(
        tstate: ptr[PyThreadState],
        func: u64,
        locals: ptr[PyObject],
        args: ptr[u64],
        argcount: u64,
        kwnames: ptr[PyObject],
        previous: ptr[u8]
    ) -> ptr[u8] {
        func_obj = sr_borrow(func);
        code = call_func_code(func_obj);
        frame = _PyThreadState_PushFrame(
            tstate, u64(call_i32_at(code, PyCodeObject_FRAMESIZE))
        );
        if not frame {
            sr_close(func);
            object_xdecref(locals);
            close_refs(args, 0, i64(argcount));
            close_kwarg_refs(args, i64(argcount), kwnames);
            PyErr_NoMemory();
            return ptr[u8]();
        }
        call_frame_initialize(frame, func, locals, code, 0, previous);
        if initialize_locals(
            tstate,
            func_obj,
            ptr[u64](frame + _PyInterpreterFrame_LOCALSPLUS),
            args,
            i64(argcount),
            kwnames
        )
            != 0 {
            clear_thread_frame(tstate, frame);
            return ptr[u8]();
        }
        return frame;
    }  def _PyEval_Vector(
        tstate: ptr[PyThreadState],
        func: ptr[PyObject],
        locals: ptr[PyObject],
        args: ptr[ptr[PyObject]],
        argcount: u64,
        kwnames: ptr[PyObject]
    ) -> ptr[PyObject] {
        total_args = argcount;
        if kwnames {
            total_args = total_args + u64(object_size(kwnames));
        }
        arguments = ptr[u64](__alloca(64));
        if total_args > CEVAL_STACK_ARRAY_SIZE {
            arguments = ptr[u64](PyMem_Malloc(u64(8) * total_args));
            if not arguments {
                return PyErr_NoMemory();
            }
        }
        if locals {
            object_incref(locals);
        }
        nargs = i64(argcount);
        for i in range(nargs) {
            (arguments + i).view(1)[0] = sr_new((args + i).view(1)[0]);
        }
        if kwnames {
            kwcount = object_size(kwnames);
            for i in range(kwcount) {
                (arguments + (i + nargs)).view(1)[0] = sr_new(
                    (args + (i + nargs)).view(1)[0]
                );
            }
        }
        frame = _PyEvalFramePushAndInit(
            tstate, sr_new(func), locals, arguments, argcount, kwnames, ptr[u8]()
        );
        if total_args > CEVAL_STACK_ARRAY_SIZE {
            PyMem_Free(ptr(arguments));
        }
        if not frame {
            return NULL;
        }
        return ceval_eval_frame(tstate, frame, 0);
    }  def PyEval_EvalCodeEx(
        _co: ptr[PyObject],
        globals: ptr[PyObject],
        locals: ptr[PyObject],
        args: ptr[ptr[PyObject]],
        argcount: i32,
        kws: ptr[ptr[PyObject]],
        kwcount: i32,
        defs: ptr[ptr[PyObject]],
        defcount: i32,
        kwdefs: ptr[PyObject],
        closure: ptr[PyObject]
    ) -> ptr[PyObject] {
        tstate = current_tstate();
        res: ptr[PyObject] = NULL;
        defaults = _PyTuple_FromArray(defs, i64(defcount));
        if not defaults {
            return NULL;
        }
        builtins = _PyDict_LoadBuiltinsFromGlobals(globals);
        if not builtins {
            object_decref(defaults);
            return NULL;
        }
        if not locals {
            locals = globals;
        }
        kwnames: ptr[PyObject] = NULL;
        allargs = args;
        newargs = ptr[ptr[PyObject]]();
        func: ptr[PyObject] = NULL;
        ok = True;
        if kwcount != 0 {
            kwnames = PyTuple_New(i64(kwcount));
            if not kwnames {
                ok = False;
            } else {
                newargs = ptr[ptr[PyObject]](
                    PyMem_Malloc(u64(8) * u64(i64(kwcount) + i64(argcount)))
                );
                if not newargs {
                    ok = False;
                } else {
                    for i in range(i64(argcount)) {
                        (newargs + i).view(1)[0] = (args + i).view(1)[0];
                    }
                    for i in range(i64(kwcount)) {
                        tuple_set_item(
                            kwnames, i, object_new_ref((kws + (2 * i)).view(1)[0])
                        );
                        (newargs + (i64(argcount) + i)).view(1)[0] = (
                            kws + (2 * i + 1)
                        ).view(
                            1
                        )[0];
                    }
                    allargs = newargs;
                }
            }
        }
        if ok {
            co_name = ceval_obj_at(ptr[u8](_co), PyCodeObject_NAME);
            constr = ptr[ptr[PyObject]](__alloca(64));
            constr.view(8)[0] = globals;
            constr.view(8)[1] = builtins;
            constr.view(8)[2] = co_name;
            constr.view(8)[3] = co_name;
            constr.view(8)[4] = _co;
            constr.view(8)[5] = defaults;
            constr.view(8)[6] = kwdefs;
            constr.view(8)[7] = closure;
            func = _PyFunction_FromConstructor(ptr[u8](constr));
            if func {
                res = _PyEval_Vector(
                    tstate, func, locals, allargs, u64(i64(argcount)), kwnames
                );
            }
        }
        object_xdecref(func);
        object_xdecref(kwnames);
        PyMem_Free(ptr(newargs));
        object_decref(builtins);
        object_decref(defaults);
        return res;
    }  def _PyEval_ExceptionGroupMatch(
        frame: ptr[u8],
        exc_value: ptr[PyObject],
        match_type: ptr[PyObject],
        match_: ptr[ptr[PyObject]],
        rest: ptr[ptr[PyObject]]
    ) -> i32 {
        if exc_value == Py_None {
            match_.view(1)[0] = object_new_ref(Py_None);
            rest.view(1)[0] = object_new_ref(Py_None);
            return 0;
        }
        eg_type = ptr[PyTypeObject](PyExc_BaseExceptionGroup);
        if PyErr_GivenExceptionMatches(exc_value, match_type) != 0 {
            if object_type_check(exc_value, eg_type) {
                match_.view(1)[0] = object_new_ref(exc_value);
            } else {
                excs = PyTuple_Pack(i64(1), exc_value);
                if not excs {
                    return -1;
                }
                wrapped = _PyExc_CreateExceptionGroup(ptr[u8](""), excs);
                object_decref(excs);
                if not wrapped {
                    return -1;
                }
                f = control_frame_object(frame);
                if not f {
                    object_decref(wrapped);
                    return -1;
                }
                tb = _PyTraceBack_FromFrame(NULL, f);
                if not tb {
                    return -1;
                }
                PyException_SetTraceback(wrapped, tb);
                object_decref(tb);
                match_.view(1)[0] = wrapped;
            }
            rest.view(1)[0] = object_new_ref(Py_None);
            return 0;
        }
        if object_type_check(exc_value, eg_type) {
            pair = PyObject_CallMethod(exc_value, "split", "(O)", match_type);
            if not pair {
                return -1;
            }
            if not tuple_check_exact(pair) {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8]("%.200s.split must return a tuple, not %.200s"),
                    ceval_tp_name(exc_value),
                    ceval_tp_name(pair)
                );
                object_decref(pair);
                return -1;
            }
            pair_size = object_size(pair);
            if pair_size < 2 {
                PyErr_Format(
                    PyExc_TypeError,
                    ptr[u8](
                        "%.200s.split must return a 2-tuple, got tuple of size %zd"
                    ),
                    ceval_tp_name(exc_value),
                    pair_size
                );
                object_decref(pair);
                return -1;
            }
            match_.view(1)[0] = object_new_ref(tuple_get_item(pair, 0));
            rest.view(1)[0] = object_new_ref(tuple_get_item(pair, 1));
            object_decref(pair);
            return 0;
        }
        match_.view(1)[0] = object_new_ref(Py_None);
        rest.view(1)[0] = object_new_ref(exc_value);
        return 0;
    }  def _PyEval_UnpackIterableStackRef(
        tstate: ptr[PyThreadState],
        v: ptr[PyObject],
        argcnt: i32,
        argcntafter: i32,
        sp: ptr[u64]
    ) -> i32 {
        i: i32 = 0;
        it = PyObject_GetIter(v);
        if not it {
            if _PyErr_ExceptionMatches(tstate, PyExc_TypeError) != 0
                and int(object_type(v).view(1)[0].tp_iter) == 0
                and PySequence_Check(v) == 0 {
                _PyErr_Format(
                    tstate,
                    PyExc_TypeError,
                    ptr[u8]("cannot unpack non-iterable %.200s object"),
                    ceval_tp_name(v)
                );
            }
            return 0;
        }
        failed = False;
        while i < argcnt {
            w = PyIter_Next(it);
            if not w {
                if not ceval_err_occurred(tstate) {
                    if argcntafter == -1 {
                        _PyErr_Format(
                            tstate,
                            PyExc_ValueError,
                            ptr[u8](
                                "not enough values to unpack (expected %d, got %d)"
                            ),
                            argcnt,
                            i
                        );
                    } else {
                        expected = argcnt + argcntafter;
                        _PyErr_Format(
                            tstate,
                            PyExc_ValueError,
                            ptr[u8](
                                "not enough values to unpack (expected at least %d, got %d)"
                            ),
                            expected,
                            i
                        );
                    }
                }
                failed = True;
                break;
            }
            sp = sp - 1;
            sp.view(1)[0] = sr_steal(w);
            i += 1;
        }
        if not failed and argcntafter == -1 {
            w = PyIter_Next(it);
            if not w {
                if ceval_err_occurred(tstate) {
                    failed = True;
                } else {
                    object_decref(it);
                    return 1;
                }
            } else {
                object_decref(w);
                if object_type(v) == ptr[PyTypeObject](addressof(PyList_Type))
                    or tuple_check_exact(v)
                    or dict_check_exact(v) {
                    seq_len: i64 = 0;
                    if dict_check_exact(v) {
                        seq_len = PyDict_Size(v);
                    } else {
                        seq_len = object_size(v);
                    }
                    if seq_len > i64(argcnt) {
                        _PyErr_Format(
                            tstate,
                            PyExc_ValueError,
                            ptr[u8]("too many values to unpack (expected %d, got %zd)"),
                            argcnt,
                            seq_len
                        );
                        failed = True;
                    }
                }
                if not failed {
                    _PyErr_Format(
                        tstate,
                        PyExc_ValueError,
                        ptr[u8]("too many values to unpack (expected %d)"),
                        argcnt
                    );
                    failed = True;
                }
            }
        }
        if not failed {
            l = PySequence_List(it);
            if not l {
                failed = True;
            } else {
                sp = sp - 1;
                sp.view(1)[0] = sr_steal(l);
                i += 1;
                ll = object_size(l);
                if ll < i64(argcntafter) {
                    expected = argcnt + argcntafter;
                    got = i64(argcnt) + ll;
                    _PyErr_Format(
                        tstate,
                        PyExc_ValueError,
                        ptr[u8](
                            "not enough values to unpack (expected at least %d, got %zd)"
                        ),
                        expected,
                        got
                    );
                    failed = True;
                } else {
                    items = ceval_list_items(l);
                    j = argcntafter;
                    while j > 0 {
                        sp = sp - 1;
                        sp.view(1)[0] = sr_steal((items + (ll - i64(j))).view(1)[0]);
                        j -= 1;
                        i += 1;
                    }
                    ptr[PyVarObject](l).view(1)[0].ob_size = ll - i64(argcntafter);
                    object_decref(it);
                    return 1;
                }
            }
        }
        while i > 0 {
            sr_close(sp.view(1)[0]);
            i -= 1;
            sp = sp + 1;
        }
        object_xdecref(it);
        return 0;
    }  def _PyEval_MonitorRaise(
        tstate: ptr[PyThreadState], frame: ptr[u8], instr: ptr[u16]
    ) {
        if no_tools_for_global_event(ptr(tstate), PY_MONITORING_EVENT_RAISE) {
            return;
        }
        do_monitor_exc(ptr(tstate), frame, instr, PY_MONITORING_EVENT_RAISE);
    }  def _PyEval_NoToolsForUnwind(tstate: ptr[PyThreadState]) -> bool {
        return no_tools_for_global_event(ptr(tstate), PY_MONITORING_EVENT_PY_UNWIND);
    }  def PyThreadState_EnterTracing(tstate: ptr[PyThreadState]) {
        ts = ptr[u8](tstate);
        ceval_set_i32_at(
            ts, PyThreadState_TRACING, call_i32_at(ts, PyThreadState_TRACING) + 1
        );
    }  def PyThreadState_LeaveTracing(tstate: ptr[PyThreadState]) {
        ts = ptr[u8](tstate);
        ceval_set_i32_at(
            ts, PyThreadState_TRACING, call_i32_at(ts, PyThreadState_TRACING) - 1
        );
    }  def _PyEval_CallTracing(
        func: ptr[PyObject], args: ptr[PyObject]
    ) -> ptr[PyObject] {
        ts = ptr[u8](current_tstate());
        save_tracing = call_i32_at(ts, PyThreadState_TRACING);
        ceval_set_i32_at(ts, PyThreadState_TRACING, 0);
        result = PyObject_Call(func, args, NULL);
        ceval_set_i32_at(ts, PyThreadState_TRACING, save_tracing);
        return result;
    }  def PyEval_SetProfile(func: ptr, arg: ptr[PyObject]) {
        if _PyEval_SetProfile(current_tstate(), func, arg) < 0 {
            PyErr_FormatUnraisable(ptr[u8]("Exception ignored in PyEval_SetProfile"));
        }
    }  def PyEval_SetProfileAllThreads(func: ptr, arg: ptr[PyObject]) {
        if _PyEval_SetProfileAllThreads(current_interp(), func, arg) < 0 {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored in PyEval_SetProfileAllThreads")
            );
        }
    }  def PyEval_SetTrace(func: ptr, arg: ptr[PyObject]) {
        if _PyEval_SetTrace(current_tstate(), func, arg) < 0 {
            PyErr_FormatUnraisable(ptr[u8]("Exception ignored in PyEval_SetTrace"));
        }
    }  def PyEval_SetTraceAllThreads(func: ptr, arg: ptr[PyObject]) {
        if _PyEval_SetTraceAllThreads(current_interp(), func, arg) < 0 {
            PyErr_FormatUnraisable(
                ptr[u8]("Exception ignored in PyEval_SetTraceAllThreads")
            );
        }
    }  def _PyEval_SetCoroutineOriginTrackingDepth(depth: i32) -> i32 {
        tstate = current_tstate();
        if depth < 0 {
            _PyErr_SetString(tstate, PyExc_ValueError, ptr[u8]("depth must be >= 0"));
            return -1;
        }
        ceval_set_i32_at(
            ptr[u8](tstate), PyThreadState_COROUTINE_ORIGIN_TRACKING_DEPTH, depth
        );
        return 0;
    }  def _PyEval_GetCoroutineOriginTrackingDepth -> i32 {
        return call_i32_at(
            ptr[u8](current_tstate()), PyThreadState_COROUTINE_ORIGIN_TRACKING_DEPTH
        );
    }  def _PyEval_SetAsyncGenFirstiter(firstiter: ptr[PyObject]) -> i32 {
        tstate = current_tstate();
        if _PySys_Audit(tstate, ptr[u8]("sys.set_asyncgen_hook_firstiter"), ptr[u8]())
            < 0 {
            return -1;
        }
        if firstiter {
            object_incref(firstiter);
        }
        ts = ptr[u8](tstate);
        old = ceval_obj_at(ts, PyThreadState_ASYNC_GEN_FIRSTITER);
        ceval_set_obj_at(ts, PyThreadState_ASYNC_GEN_FIRSTITER, firstiter);
        object_xdecref(old);
        return 0;
    }  def _PyEval_GetAsyncGenFirstiter -> ptr[PyObject] {
        return ceval_obj_at(
            ptr[u8](current_tstate()), PyThreadState_ASYNC_GEN_FIRSTITER
        );
    }  def _PyEval_SetAsyncGenFinalizer(finalizer: ptr[PyObject]) -> i32 {
        tstate = current_tstate();
        if _PySys_Audit(tstate, ptr[u8]("sys.set_asyncgen_hook_finalizer"), ptr[u8]())
            < 0 {
            return -1;
        }
        if finalizer {
            object_incref(finalizer);
        }
        ts = ptr[u8](tstate);
        old = ceval_obj_at(ts, PyThreadState_ASYNC_GEN_FINALIZER);
        ceval_set_obj_at(ts, PyThreadState_ASYNC_GEN_FINALIZER, finalizer);
        object_xdecref(old);
        return 0;
    }  def _PyEval_GetAsyncGenFinalizer -> ptr[PyObject] {
        return ceval_obj_at(
            ptr[u8](current_tstate()), PyThreadState_ASYNC_GEN_FINALIZER
        );
    }  def _PyEval_GetFrame -> ptr[u8] {
        return ceval_thread_frame(current_tstate());
    }  def PyEval_GetFrame -> ptr[PyObject] {
        frame = ceval_thread_frame(current_tstate());
        if not frame {
            return NULL;
        }
        f = control_frame_object(frame);
        if not f {
            PyErr_Clear();
        }
        return f;
    }  def _PyEval_GetBuiltins(tstate: ptr[PyThreadState]) -> ptr[PyObject] {
        frame = ceval_thread_frame(tstate);
        if frame {
            return ceval_obj_at(frame, _PyInterpreterFrame_F_BUILTINS);
        }
        return ceval_obj_at(ceval_interp(tstate), PyInterpreterState_BUILTINS);
    }  def PyEval_GetBuiltins -> ptr[PyObject] {
        return _PyEval_GetBuiltins(current_tstate());
    }  def _PyEval_GetBuiltin(name: ptr[PyObject]) -> ptr[PyObject] {
        attr: ptr[PyObject] = NULL;
        if PyMapping_GetOptionalItem(
            _PyEval_GetBuiltins(current_tstate()), name, &mut attr
        )
            == 0 {
            PyErr_SetObject(PyExc_AttributeError, name);
        }
        return attr;
    }  def _PyEval_GetBuiltinId(name: ptr) -> ptr[PyObject] {
        return _PyEval_GetBuiltin(_PyUnicode_FromId(name));
    }  def PyEval_GetLocals -> ptr[PyObject] {
        tstate = current_tstate();
        current_frame = ceval_thread_frame(tstate);
        if not current_frame {
            _PyErr_SetString(
                tstate, PyExc_SystemError, ptr[u8]("frame does not exist")
            );
            return NULL;
        }
        locals = _PyFrame_GetLocals(current_frame);
        if not locals {
            return NULL;
        }
        if ceval_is_type(locals, ptr[PyObject](addressof(PyFrameLocalsProxy_Type))) {
            f = ptr[u8](control_frame_object(current_frame));
            if not f {
                object_decref(locals);
                return NULL;
            }
            ret = ceval_obj_at(f, PyFrameObject_LOCALS_CACHE);
            if not ret {
                ret = PyDict_New();
                if not ret {
                    object_decref(locals);
                    return NULL;
                }
                ceval_set_obj_at(f, PyFrameObject_LOCALS_CACHE, ret);
            }
            if PyDict_Update(ret, locals) < 0 {
                ret = NULL;
            }
            object_decref(locals);
            return ret;
        }
        object_decref(locals);
        return locals;
    }  def _PyEval_GetFrameLocals -> ptr[PyObject] {
        tstate = current_tstate();
        current_frame = ceval_thread_frame(tstate);
        if not current_frame {
            _PyErr_SetString(
                tstate, PyExc_SystemError, ptr[u8]("frame does not exist")
            );
            return NULL;
        }
        locals = _PyFrame_GetLocals(current_frame);
        if not locals {
            return NULL;
        }
        if ceval_is_type(locals, ptr[PyObject](addressof(PyFrameLocalsProxy_Type))) {
            ret = PyDict_New();
            if not ret {
                object_decref(locals);
                return NULL;
            }
            if PyDict_Update(ret, locals) < 0 {
                object_decref(ret);
                object_decref(locals);
                return NULL;
            }
            object_decref(locals);
            return ret;
        }
        return locals;
    }  def PyEval_GetGlobals -> ptr[PyObject] {
        return _PyEval_GetGlobals(current_tstate());
    }  def _PyEval_GetGlobalsFromRunningMain(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyObject] {
        if _PyInterpreterState_IsRunningMain(ceval_interp(tstate)) == 0 {
            return NULL;
        }
        mod = _Py_GetMainModule(tstate);
        if _Py_CheckMainModule(mod) < 0 {
            object_xdecref(mod);
            return NULL;
        }
        globals = PyModule_GetDict(mod);
        object_decref(mod);
        return globals;
    }  def _PyEval_EnsureBuiltins(
        tstate: ptr[PyThreadState],
        globals: ptr[PyObject],
        p_builtins: ptr[ptr[PyObject]]
    ) -> i32 {
        builtins = get_globals_builtins(globals);
        if not builtins {
            if ceval_err_occurred(tstate) {
                return -1;
            }
            builtins = _PyEval_GetBuiltins(current_tstate());
            if not builtins {
                return -1;
            }
            object_incref(builtins);
            if set_globals_builtins(globals, builtins) < 0 {
                object_decref(builtins);
                return -1;
            }
        }
        if p_builtins {
            p_builtins.view(1)[0] = builtins;
        } else {
            object_decref(builtins);
        }
        return 0;
    }  def _PyEval_EnsureBuiltinsWithModule(
        tstate: ptr[PyThreadState],
        globals: ptr[PyObject],
        p_builtins: ptr[ptr[PyObject]]
    ) -> i32 {
        builtins = get_globals_builtins(globals);
        if not builtins {
            if ceval_err_occurred(tstate) {
                return -1;
            }
            builtins = PyImport_ImportModuleLevel(
                ptr[u8]("builtins"), NULL, NULL, NULL, 0
            );
            if not builtins {
                return -1;
            }
            if set_globals_builtins(globals, builtins) < 0 {
                object_decref(builtins);
                return -1;
            }
        }
        if p_builtins {
            p_builtins.view(1)[0] = builtins;
        } else {
            object_decref(builtins);
        }
        return 0;
    }  def PyEval_GetFrameLocals -> ptr[PyObject] {
        return _PyEval_GetFrameLocals();
    }  def PyEval_GetFrameGlobals -> ptr[PyObject] {
        current_frame = ceval_thread_frame(current_tstate());
        if not current_frame {
            return NULL;
        }
        globals = ceval_obj_at(current_frame, _PyInterpreterFrame_F_GLOBALS);
        if globals {
            object_incref(globals);
        }
        return globals;
    }  def PyEval_GetFrameBuiltins -> ptr[PyObject] {
        builtins = _PyEval_GetBuiltins(current_tstate());
        if builtins {
            object_incref(builtins);
        }
        return builtins;
    }  def PyEval_MergeCompilerFlags(cf: ptr[PyCompilerFlags]) -> i32 {
        current_frame = ceval_current_frame(current_tstate());
        flags = ptr[i32](cf);
        result: i32 = 0;
        if flags.view(1)[0] != 0 {
            result = 1;
        }
        if current_frame {
            codeflags = call_i32_at(
                ceval_frame_code(current_frame), PyCodeObject_FLAGS
            );
            compilerflags = codeflags & CEVAL_PYCF_MASK;
            if compilerflags != 0 {
                result = 1;
                flags.view(1)[0] = flags.view(1)[0] | compilerflags;
            }
        }
        return result;
    }  def PyEval_GetFuncName(func: ptr[PyObject]) -> ptr[u8] {
        if ceval_is_type(func, addressof(PyMethod_Type)) {
            return PyEval_GetFuncName(ptr[PyMethodObject](func).view(1)[0].im_func);
        } elif ceval_is_type(func, addressof(PyFunction_Type)) {
            return PyUnicode_AsUTF8(ceval_obj_at(ptr[u8](func), PyFunctionObject_NAME));
        } elif object_type_check(
            func, ptr[PyTypeObject](addressof(PyCFunction_Type))
        ) {
            return ptr[PyCFunctionObject](func).view(1)[0].m_ml.view(1)[0].ml_name;
        }
        return ceval_tp_name(func);
    }  def PyEval_GetFuncDesc(func: ptr[PyObject]) -> ptr[u8] {
        if ceval_is_type(func, addressof(PyMethod_Type)) {
            return ptr[u8]("()");
        } elif ceval_is_type(func, addressof(PyFunction_Type)) {
            return ptr[u8]("()");
        } elif object_type_check(
            func, ptr[PyTypeObject](addressof(PyCFunction_Type))
        ) {
            return ptr[u8]("()");
        }
        return ptr[u8](" object");
    }  def _PyEval_SliceIndex(v: ptr[PyObject], pi: ptr[i64]) -> i32 {
        tstate = current_tstate();
        if v != Py_None {
            x: i64 = 0;
            if index_check(v) {
                x = PyNumber_AsSsize_t(v, NULL);
                if x == -1 and ceval_err_occurred(tstate) {
                    return 0;
                }
            } else {
                _PyErr_SetString(
                    tstate,
                    PyExc_TypeError,
                    ptr[u8](
                        "slice indices must be integers or None or have an __index__ method"
                    )
                );
                return 0;
            }
            if pi {
                pi.view(1)[0] = x;
            }
        }
        return 1;
    }  def _PyEval_SliceIndexNotNone(v: ptr[PyObject], pi: ptr[i64]) -> i32 {
        tstate = current_tstate();
        x: i64 = 0;
        if index_check(v) {
            x = PyNumber_AsSsize_t(v, NULL);
            if x == -1 and ceval_err_occurred(tstate) {
                return 0;
            }
        } else {
            _PyErr_SetString(
                tstate,
                PyExc_TypeError,
                ptr[u8]("slice indices must be integers or have an __index__ method")
            );
            return 0;
        }
        if pi {
            pi.view(1)[0] = x;
        }
        return 1;
    }  def _PyEval_ImportName(
        tstate: ptr[PyThreadState],
        frame: ptr[u8],
        name: ptr[PyObject],
        fromlist: ptr[PyObject],
        level: ptr[PyObject]
    ) -> ptr[PyObject] {
        import_func: ptr[PyObject] = NULL;
        if PyMapping_GetOptionalItem(
            ceval_obj_at(frame, _PyInterpreterFrame_F_BUILTINS),
            py_id(_Py_ID___import__),
            &mut import_func
        )
            < 0 {
            return NULL;
        }
        if not import_func {
            _PyErr_SetString(
                tstate, PyExc_ImportError, ptr[u8]("__import__ not found")
            );
            return NULL;
        }
        locals = ceval_obj_at(frame, _PyInterpreterFrame_F_LOCALS);
        if not locals {
            locals = Py_None;
        }
        globals = ceval_obj_at(frame, _PyInterpreterFrame_F_GLOBALS);
        if _PyImport_IsDefaultImportFunc(ceval_interp(tstate), import_func) != 0 {
            object_decref(import_func);
            ilevel = PyLong_AsInt(level);
            if ilevel == -1 and ceval_err_occurred(tstate) {
                return NULL;
            }
            return PyImport_ImportModuleLevelObject(
                name, globals, locals, fromlist, ilevel
            );
        }
        args = ptr[ptr[PyObject]](__alloca(40));
        args.view(5)[0] = name;
        args.view(5)[1] = globals;
        args.view(5)[2] = locals;
        args.view(5)[3] = fromlist;
        args.view(5)[4] = level;
        res = PyObject_Vectorcall(import_func, args, u64(5), NULL);
        object_decref(import_func);
        return res;
    }  def _PyEval_ImportFrom(
        tstate: ptr[PyThreadState], v: ptr[PyObject], name: ptr[PyObject]
    ) -> ptr[PyObject] {
        x: ptr[PyObject] = NULL;
        if PyObject_GetOptionalAttr(v, name, &mut x) != 0 {
            return x;
        }

        mod_name: ptr[PyObject] = NULL;
        if PyObject_GetOptionalAttr(v, py_id(_Py_ID___name__), &mut mod_name) < 0 {
            return NULL;
        }
        if not mod_name or not ceval_unicode_check(mod_name) {
            object_xdecref(mod_name);
            return import_from_error(tstate, v, name, NULL);
        }
        fullmodname = PyUnicode_FromFormat("%U.%U", mod_name, name);
        if not fullmodname {
            object_decref(mod_name);
            return NULL;
        }
        x = PyImport_GetModule(fullmodname);
        object_decref(fullmodname);
        if not x and not ceval_err_occurred(tstate) {
            return import_from_error(tstate, v, name, mod_name);
        }
        object_decref(mod_name);
        return x;
    }  def _PyEval_CheckExceptTypeValid(
        tstate: ptr[PyThreadState], right: ptr[PyObject]
    ) -> i32 {
        if tuple_check(right) {
            length = object_size(right);
            for i in range(length) {
                exc = tuple_get_item(right, i);
                if not control_exception_class_check(exc) {
                    _PyErr_SetString(
                        tstate,
                        PyExc_TypeError,
                        ptr[u8](
                            "catching classes that do not inherit from BaseException is not allowed"
                        )
                    );
                    return -1;
                }
            }
        } else {
            if not control_exception_class_check(right) {
                _PyErr_SetString(
                    tstate,
                    PyExc_TypeError,
                    ptr[u8](
                        "catching classes that do not inherit from BaseException is not allowed"
                    )
                );
                return -1;
            }
        }
        return 0;
    }  def _PyEval_CheckExceptStarTypeValid(
        tstate: ptr[PyThreadState], right: ptr[PyObject]
    ) -> i32 {
        if _PyEval_CheckExceptTypeValid(tstate, right) < 0 {
            return -1;
        }
        is_subclass: i32 = 0;
        if tuple_check(right) {
            length = object_size(right);
            for i in range(length) {
                exc = tuple_get_item(right, i);
                is_subclass = PyObject_IsSubclass(exc, PyExc_BaseExceptionGroup);
                if is_subclass < 0 {
                    return -1;
                }
                if is_subclass != 0 {
                    break;
                }
            }
        } else {
            is_subclass = PyObject_IsSubclass(right, PyExc_BaseExceptionGroup);
            if is_subclass < 0 {
                return -1;
            }
        }
        if is_subclass != 0 {
            _PyErr_SetString(
                tstate,
                PyExc_TypeError,
                ptr[u8](
                    "catching ExceptionGroup with except* is not allowed. Use except instead."
                )
            );
            return -1;
        }
        return 0;
    }  def _Py_Check_ArgsIterable(
        tstate: ptr[PyThreadState], func: ptr[PyObject], args: ptr[PyObject]
    ) -> i32 {
        if int(object_type(args).view(1)[0].tp_iter) == 0
            and PySequence_Check(args) == 0 {
            _PyErr_Clear(tstate);
            funcstr = _PyObject_FunctionStr(func);
            if funcstr {
                _PyErr_Format(
                    tstate,
                    PyExc_TypeError,
                    ptr[u8]("%U argument after * must be an iterable, not %.200s"),
                    funcstr,
                    ceval_tp_name(args)
                );
                object_decref(funcstr);
            }
            return -1;
        }
        return 0;
    }  def _PyEval_FormatKwargsError(
        tstate: ptr[PyThreadState], func: ptr[PyObject], kwargs: ptr[PyObject]
    ) {
        if _PyErr_ExceptionMatches(tstate, PyExc_AttributeError) != 0 {
            _PyErr_Clear(tstate);
            funcstr = _PyObject_FunctionStr(func);
            if funcstr {
                _PyErr_Format(
                    tstate,
                    PyExc_TypeError,
                    ptr[u8]("%U argument after ** must be a mapping, not %.200s"),
                    funcstr,
                    ceval_tp_name(kwargs)
                );
                object_decref(funcstr);
            }
        } elif _PyErr_ExceptionMatches(tstate, PyExc_KeyError) != 0 {
            exc = _PyErr_GetRaisedException(tstate);
            args = PyException_GetArgs(exc);
            if exc and tuple_check(args) and object_size(args) == 1 {
                _PyErr_Clear(tstate);
                funcstr = _PyObject_FunctionStr(func);
                if funcstr {
                    key = tuple_get_item(args, 0);
                    _PyErr_Format(
                        tstate,
                        PyExc_TypeError,
                        ptr[u8]("%U got multiple values for keyword argument '%S'"),
                        funcstr,
                        key
                    );
                    object_decref(funcstr);
                }
                object_xdecref(exc);
            } else {
                _PyErr_SetRaisedException(tstate, exc);
            }
            object_decref(args);
        }
    }  def _PyEval_FormatExcCheckArg(
        tstate: ptr[PyThreadState],
        exc: ptr[PyObject],
        format_str: ptr[u8],
        obj_: ptr[PyObject]
    ) {
        if not obj_ {
            return;
        }
        obj_str = PyUnicode_AsUTF8(obj_);
        if not obj_str {
            return;
        }
        _PyErr_Format(tstate, exc, format_str, obj_str);
        if exc == PyExc_NameError {
            raised = PyErr_GetRaisedException();
            if PyErr_GivenExceptionMatches(raised, PyExc_NameError) != 0 {
                if not ceval_obj_at(ptr[u8](raised), PyNameErrorObject_NAME) {
                    PyObject_SetAttr(raised, py_id(_Py_ID_name), obj_);
                }
            }
            PyErr_SetRaisedException(raised);
        }
    }  def _PyEval_FormatExcUnbound(
        tstate: ptr[PyThreadState], co: ptr[PyCodeObject], oparg: i32
    ) {
        if ceval_err_occurred(tstate) {
            return;
        }
        code = ptr[u8](co);
        name = tuple_get_item(
            ceval_obj_at(code, PyCodeObject_LOCALSPLUSNAMES), i64(oparg)
        );
        first_free = call_i32_at(code, PyCodeObject_NLOCALSPLUS)
            - call_i32_at(code, PyCodeObject_NFREEVARS);
        if oparg < first_free {
            _PyEval_FormatExcCheckArg(
                tstate,
                PyExc_UnboundLocalError,
                ptr[u8](
                    "cannot access local variable '%s' where it is not associated with a value"
                ),
                name
            );
        } else {
            _PyEval_FormatExcCheckArg(
                tstate,
                PyExc_NameError,
                ptr[u8](
                    "cannot access free variable '%s' where it is not associated with a value in enclosing scope"
                ),
                name
            );
        }
    }  def _PyEval_FormatAwaitableError(
        tstate: ptr[PyThreadState], type: ptr[PyTypeObject], oparg: i32
    ) {
        am = type.view(1)[0].tp_as_async;
        if not am or int(am.view(1)[0].am_await) == 0 {
            if oparg == 1 {
                _PyErr_Format(
                    tstate,
                    PyExc_TypeError,
                    ptr[u8](
                        "'async with' received an object from __aenter__ that does not implement __await__: %.100s"
                    ),
                    type.view(1)[0].tp_name
                );
            } elif oparg == 2 {
                _PyErr_Format(
                    tstate,
                    PyExc_TypeError,
                    ptr[u8](
                        "'async with' received an object from __aexit__ that does not implement __await__: %.100s"
                    ),
                    type.view(1)[0].tp_name
                );
            }
        }
    }  def PyUnstable_Eval_RequestCodeExtraIndex(free: ptr) -> i64 {
        interp = current_interp();
        count_slot = ptr[i64](interp + PyInterpreterState_CO_EXTRA_USER_COUNT);
        if count_slot.view(1)[0] >= CEVAL_MAX_CO_EXTRA_USERS - 1 {
            return -1;
        }
        new_index = count_slot.view(1)[0];
        (ptr[u64](interp + PyInterpreterState_CO_EXTRA_FREEFUNCS) + new_index).view(1)[
            0
        ] = u64(int(free));
        count_slot.view(1)[0] = new_index + 1;
        return new_index;
    }  def Py_EnterRecursiveCall(where: ptr[u8]) -> i32 {
        if ceval_enter_recursive_call(current_tstate(), where) {
            return 1;
        }
        return 0;
    }  def Py_LeaveRecursiveCall {
        return;
    }  def _PyEval_GetANext(aiter: ptr[PyObject]) -> ptr[PyObject] {
        type = object_type(aiter);
        am = type.view(1)[0].tp_as_async;
        if type == ptr[PyTypeObject](addressof(PyAsyncGen_Type)) {
            return am.view(1)[0].am_anext(aiter);
        }
        if not am or int(am.view(1)[0].am_anext) == 0 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8](
                    "'async for' requires an iterator with __anext__ method, got %.100s"
                ),
                type.view(1)[0].tp_name
            );
            return NULL;
        }
        next_iter = am.view(1)[0].am_anext(aiter);
        if not next_iter {
            return NULL;
        }
        awaitable = _PyCoro_GetAwaitableIter(next_iter);
        if not awaitable {
            _PyErr_FormatFromCause(
                PyExc_TypeError,
                ptr[u8](
                    "'async for' received an invalid object from __anext__: %.100s"
                ),
                ceval_tp_name(next_iter)
            );
        }
        object_decref(next_iter);
        return awaitable;
    }  def _PyEval_LoadGlobalStackRef(
        globals: ptr[PyObject],
        builtins: ptr[PyObject],
        name: ptr[PyObject],
        writeto: ptr[u64]
    ) {
        if dict_check_exact(globals) and dict_check_exact(builtins) {
            _PyDict_LoadGlobalStackRef(globals, builtins, name, writeto);
            if sr_is_null(writeto.view(1)[0]) and not PyErr_Occurred() {
                _PyEval_FormatExcCheckArg(
                    current_tstate(),
                    PyExc_NameError,
                    ptr[u8]("name '%.200s' is not defined"),
                    name
                );
            }
            return;
        }
        res: ptr[PyObject] = NULL;
        if PyMapping_GetOptionalItem(globals, name, &mut res) < 0 {
            writeto.view(1)[0] = SR_NULL;
            return;
        }
        if not res {
            if PyMapping_GetOptionalItem(builtins, name, &mut res) < 0 {
                writeto.view(1)[0] = SR_NULL;
                return;
            }
            if not res {
                _PyEval_FormatExcCheckArg(
                    current_tstate(),
                    PyExc_NameError,
                    ptr[u8]("name '%.200s' is not defined"),
                    name
                );
                writeto.view(1)[0] = SR_NULL;
                return;
            }
        }
        writeto.view(1)[0] = sr_steal(res);
    }  def _PyEval_GetAwaitable(iterable: ptr[PyObject], oparg: i32) -> ptr[PyObject] {
        awaitable = _PyCoro_GetAwaitableIter(iterable);
        if not awaitable {
            _PyEval_FormatAwaitableError(
                current_tstate(), object_type(iterable), oparg
            );
        } elif ceval_is_type(awaitable, addressof(PyCoro_Type)) {
            yf = _PyGen_yf(awaitable);
            if yf {
                object_decref(yf);
                object_decref(awaitable);
                awaitable = NULL;
                _PyErr_SetString(
                    current_tstate(),
                    PyExc_RuntimeError,
                    ptr[u8]("coroutine is being awaited already")
                );
            }
        }
        return awaitable;
    }  def _PyEval_LoadName(
        tstate: ptr[PyThreadState], frame: ptr[u8], name: ptr[PyObject]
    ) -> ptr[PyObject] {
        value: ptr[PyObject] = NULL;
        locals = ceval_obj_at(frame, _PyInterpreterFrame_F_LOCALS);
        if not locals {
            _PyErr_SetString(tstate, PyExc_SystemError, ptr[u8]("no locals found"));
            return NULL;
        }
        if PyMapping_GetOptionalItem(locals, name, &mut value) < 0 {
            return NULL;
        }
        if value {
            return value;
        }
        if PyDict_GetItemRef(
            ceval_obj_at(frame, _PyInterpreterFrame_F_GLOBALS), name, &mut value
        )
            < 0 {
            return NULL;
        }
        if value {
            return value;
        }
        if PyMapping_GetOptionalItem(
            ceval_obj_at(frame, _PyInterpreterFrame_F_BUILTINS), name, &mut value
        )
            < 0 {
            return NULL;
        }
        if not value {
            _PyEval_FormatExcCheckArg(
                tstate, PyExc_NameError, ptr[u8]("name '%.200s' is not defined"), name
            );
        }
        return value;
    }  def _PyEval_SpecialMethodCanSuggest(self_: ptr[PyObject], oparg: i32) -> i32 {
        type = object_type(self_);
        if oparg == 0 or oparg == 1 {
            if type_has_special_method(type, py_id(_Py_ID___aenter__))
                and type_has_special_method(type, py_id(_Py_ID___aexit__)) {
                return 1;
            }
            return 0;
        } elif oparg == 2 or oparg == 3 {
            if type_has_special_method(type, py_id(_Py_ID___enter__))
                and type_has_special_method(type, py_id(_Py_ID___exit__)) {
                return 1;
            }
            return 0;
        }
        _Py_FatalErrorFunc(
            ptr[u8]("_PyEval_SpecialMethodCanSuggest"),
            ptr[u8]("unsupported special method")
        );
        return 0;
    }
}

impl ceval_u64_at(base: ptr[u8], offset: i64) -> u64 {
    return ptr[u64](base + offset).view(1)[0];
}

impl ceval_set_u64_at(base: ptr[u8], offset: i64, value: u64) {
    ptr[u64](base + offset).view(1)[0] = value;
}

impl ceval_set_i32_at(base: ptr[u8], offset: i64, value: i32) {
    ptr[i32](base + offset).view(1)[0] = value;
}

impl ceval_obj_at(base: ptr[u8], offset: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](base + offset).view(1)[0];
}

impl ceval_set_obj_at(base: ptr[u8], offset: i64, value: ptr[PyObject]) {
    ptr[ptr[PyObject]](base + offset).view(1)[0] = value;
}

impl ceval_interp(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return call_ptr_at(ptr[u8](tstate), PyThreadState_INTERP);
}

impl ceval_current_frame(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return call_ptr_at(ptr[u8](tstate), PyThreadState_CURRENT_FRAME);
}

impl ceval_set_current_frame(tstate: ptr[PyThreadState], frame: ptr[u8]) {
    call_set_ptr_at(ptr[u8](tstate), PyThreadState_CURRENT_FRAME, frame);
}

impl ceval_thread_frame(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return iframe_first_complete(ceval_current_frame(tstate));
}

impl ceval_frame_code(frame: ptr[u8]) -> ptr[u8] {
    return ptr[u8](sr_borrow(call_ref_at(frame, _PyInterpreterFrame_F_EXECUTABLE)));
}

impl ceval_err_occurred(tstate: ptr[PyThreadState]) -> bool {
    if ceval_obj_at(ptr[u8](tstate), PyThreadState_CURRENT_EXCEPTION) {
        return True;
    }
    return False;
}

impl ceval_tp_name(op: ptr[PyObject]) -> ptr[u8] {
    return object_type(op).view(1)[0].tp_name;
}

impl ceval_tuple_empty -> ptr[PyObject] {
    return ptr[PyObject](ptr[u8](addressof(_PyRuntime)) + _PyRuntimeState_TUPLE_EMPTY);
}

impl ceval_list_items(lst: ptr[PyObject]) -> ptr[ptr[PyObject]] {
    return ptr[PyListObject](lst).view(1)[0].ob_item;
}

impl ceval_is_type(op: ptr[PyObject], type: ptr[PyObject]) -> bool {
    return object_type(op) == ptr[PyTypeObject](type);
}

impl ceval_stack_pointer -> u64 {
    return u64(__alloca(8));
}

impl ceval_make_rec_check(tstate: ptr[PyThreadState]) -> bool {
    here = ceval_stack_pointer();
    soft = ceval_u64_at(ptr[u8](tstate), _PyThreadStateImpl_C_STACK_SOFT_LIMIT);
    return here < soft
        and here >= wrapping_sub(soft, u64(2) * CEVAL_STACK_MARGIN_BYTES);
}

impl ceval_enter_recursive_call(tstate: ptr[PyThreadState], where: ptr[u8]) -> bool {
    return ceval_make_rec_check(tstate) and _Py_CheckRecursiveCall(tstate, where) != 0;
}

impl ceval_enter_recursive_py(tstate: ptr[PyThreadState]) -> bool {
    remaining = call_i32_at(ptr[u8](tstate), PyThreadState_PY_RECURSION_REMAINING);
    ceval_set_i32_at(
        ptr[u8](tstate),
        PyThreadState_PY_RECURSION_REMAINING,
        i32.wrap(i64(remaining) - 1)
    );
    return remaining <= 0 and _Py_CheckRecursiveCallPy(tstate) != 0;
}

impl ceval_kbytes_used(top: u64, here: u64) -> i32 {
    used = i64(i32.wrap(wrapping_sub(top, here)));
    if used < 0 {
        return i32(-((-used) // 1024));
    }
    return i32(used // 1024);
}

impl ceval_init_special_methods {
    table = ptr[CevalSpecialMethod](addressof(_Py_SpecialMethods));
    if table.view(4)[3].name {
        return;
    }
    table.view(4)[0].name = py_id(_Py_ID___enter__);
    table.view(4)[1].name = py_id(_Py_ID___exit__);
    table.view(4)[2].name = py_id(_Py_ID___aenter__);
    table.view(4)[3].name = py_id(_Py_ID___aexit__);
}

impl hardware_stack_limits(sp: u64) -> tuple[u64, u64] {
    if MI_PLATFORM_LINUX == 0 {
        this_thread = pthread_self();
        stack_addr = u64(int(pthread_get_stackaddr_np(this_thread)));
        stack_size = pthread_get_stacksize_np(this_thread);
        return (wrapping_sub(stack_addr, stack_size), stack_addr);
    }
    words = ptr[u64](__alloca(128));
    attr = ptr[u8](words);
    err = pthread_getattr_np(pthread_self(), attr);
    if err == 0 {
        err = pthread_attr_getguardsize(attr, words + 12);
        err = err | pthread_attr_getstack(attr, words + 13, words + 14);
        err = err | pthread_attr_destroy(attr);
    }
    if err == 0 {
        guard_size = words.view(16)[12];
        stack_addr = words.view(16)[13];
        stack_size = words.view(16)[14];
        return (
            wrapping_add(stack_addr, guard_size),
            wrapping_add(stack_addr, stack_size)
        );
    }
    top_addr = wrapping_add(sp, u64(64) + (CEVAL_SYSTEM_PAGE_SIZE - u64(1)))
        & ~(CEVAL_SYSTEM_PAGE_SIZE - u64(1));
    return (wrapping_sub(top_addr, CEVAL_C_STACK_SIZE), top_addr);
}

impl tstate_set_stack(tstate: ptr[PyThreadState], base: u64, top: u64) {
    ts = ptr[u8](tstate);
    ceval_set_u64_at(ts, _PyThreadStateImpl_C_STACK_TOP, top);
    ceval_set_u64_at(
        ts,
        _PyThreadStateImpl_C_STACK_HARD_LIMIT,
        wrapping_add(base, CEVAL_STACK_MARGIN_BYTES)
    );
    ceval_set_u64_at(
        ts,
        _PyThreadStateImpl_C_STACK_SOFT_LIMIT,
        wrapping_add(base, CEVAL_STACK_MARGIN_BYTES * u64(2))
    );
}

impl match_class_attr(
    tstate: ptr[PyThreadState],
    subject: ptr[PyObject],
    type: ptr[PyObject],
    name: ptr[PyObject],
    seen: ptr[PyObject]
) -> ptr[PyObject] {
    if PySet_Contains(seen, name) != 0 or PySet_Add(seen, name) != 0 {
        if not ceval_err_occurred(tstate) {
            _PyErr_Format(
                tstate,
                PyExc_TypeError,
                ptr[u8]("%s() got multiple sub-patterns for attribute %R"),
                ptr[PyTypeObject](type).view(1)[0].tp_name,
                name
            );
        }
        return NULL;
    }
    attr: ptr[PyObject] = NULL;
    PyObject_GetOptionalAttr(subject, name, &mut attr);
    return attr;
}

impl match_class_fail(
    match_args: ptr[PyObject], seen: ptr[PyObject], attrs: ptr[PyObject]
) -> ptr[PyObject] {
    object_xdecref(match_args);
    object_decref(seen);
    object_decref(attrs);
    return NULL;
}

impl match_keys_done(
    tstate: ptr[PyThreadState],
    refs: ptr[u64],
    seen: ptr[PyObject],
    dummy: ptr[PyObject],
    values: ptr[PyObject]
) -> ptr[PyObject] {
    sr_xclose(refs.view(2)[1]);
    sr_xclose(refs.view(2)[0]);
    object_decref(seen);
    object_decref(dummy);
    return values;
}

impl match_keys_fail(
    refs: ptr[u64], seen: ptr[PyObject], dummy: ptr[PyObject], values: ptr[PyObject]
) -> ptr[PyObject] {
    sr_xclose(refs.view(2)[1]);
    sr_xclose(refs.view(2)[0]);
    object_xdecref(seen);
    object_xdecref(dummy);
    object_xdecref(values);
    return NULL;
}

impl ceval_eval_frame(
    tstate: ptr[PyThreadState], frame: ptr[u8], throwflag: i32
) -> ptr[PyObject] {
    hook = ptr[CevalEvalFrameHook](
        ceval_interp(tstate) + PyInterpreterState_EVAL_FRAME
    );
    if int(hook.view(1)[0].call) == 0 {
        return _PyEval_EvalFrameDefault(tstate, frame, throwflag);
    }
    return hook.view(1)[0].call(tstate, frame, throwflag);
}

impl monitor_throw(tstate: ptr[PyThreadState], frame: ptr[u8], instr: ptr[u16]) {
    if no_tools_for_global_event(ptr(tstate), PY_MONITORING_EVENT_PY_THROW) {
        return;
    }
    do_monitor_exc(ptr(tstate), frame, instr, PY_MONITORING_EVENT_PY_THROW);
}

impl eval_frame_early_exit(
    tstate: ptr[PyThreadState], dying: ptr[u8]
) -> ptr[PyObject] {
    call_leave_recursive_py(ptr(tstate));
    frame = call_ptr_at(dying, _PyInterpreterFrame_PREVIOUS);
    ceval_set_current_frame(tstate, frame);
    _PyEval_FrameClearAndPop(tstate, dying);
    ptr[u16](frame + _PyInterpreterFrame_RETURN_OFFSET).view(1)[0] = u16(0);
    ceval_set_current_frame(tstate, call_ptr_at(frame, _PyInterpreterFrame_PREVIOUS));
    return NULL;
}

impl format_missing(
    tstate: ptr[PyThreadState],
    kind: ptr[u8],
    co: ptr[u8],
    names: ptr[PyObject],
    qualname: ptr[PyObject]
) {
    count = object_size(names);
    items = ceval_list_items(names);
    name_str: ptr[PyObject] = NULL;
    if count == 1 {
        name_str = items.view(1)[0];
        object_incref(name_str);
    } elif count == 2 {
        name_str = PyUnicode_FromFormat(
            "%U and %U",
            (items + (count - 2)).view(1)[0],
            (items + (count - 1)).view(1)[0]
        );
    } else {
        tail = PyUnicode_FromFormat(
            ", %U, and %U",
            (items + (count - 2)).view(1)[0],
            (items + (count - 1)).view(1)[0]
        );
        if not tail {
            return;
        }
        err = PyList_SetSlice(names, count - 2, count, NULL);
        if err == -1 {
            object_decref(tail);
            return;
        }
        comma = PyUnicode_FromString(ptr[u8](", "));
        if not comma {
            object_decref(tail);
            return;
        }
        tmp = PyUnicode_Join(comma, names);
        object_decref(comma);
        if not tmp {
            object_decref(tail);
            return;
        }
        name_str = PyUnicode_Concat(tmp, tail);
        object_decref(tmp);
        object_decref(tail);
    }
    if not name_str {
        return;
    }
    plural = ptr[u8]("s");
    if count == 1 {
        plural = ptr[u8]("");
    }
    _PyErr_Format(
        tstate,
        PyExc_TypeError,
        ptr[u8]("%U() missing %zd required %s argument%s: %U"),
        qualname,
        count,
        kind,
        plural,
        name_str
    );
    object_decref(name_str);
}

impl missing_arguments(
    tstate: ptr[PyThreadState],
    co: ptr[u8],
    missing: i64,
    defcount: i64,
    localsplus: ptr[u64],
    qualname: ptr[PyObject]
) {
    positional = defcount != -1;
    kind = ptr[u8]("keyword-only");
    if positional {
        kind = ptr[u8]("positional");
    }
    missing_names = PyList_New(missing);
    if not missing_names {
        return;
    }
    co_argcount = i64(call_i32_at(co, PyCodeObject_ARGCOUNT));
    start: i64 = co_argcount;
    end: i64 = co_argcount + i64(call_i32_at(co, PyCodeObject_KWONLYARGCOUNT));
    if positional {
        start = 0;
        end = co_argcount - defcount;
    }
    names = ceval_obj_at(co, PyCodeObject_LOCALSPLUSNAMES);
    j: i64 = 0;
    i = start;
    while i < end {
        if sr_is_null((localsplus + i).view(1)[0]) {
            raw = tuple_get_item(names, i);
            name = PyObject_Repr(raw);
            if not name {
                object_decref(missing_names);
                return;
            }
            (ceval_list_items(missing_names) + j).view(1)[0] = name;
            j += 1;
        }
        i += 1;
    }
    format_missing(tstate, kind, co, missing_names, qualname);
    object_decref(missing_names);
}

impl too_many_positional(
    tstate: ptr[PyThreadState],
    co: ptr[u8],
    given: i64,
    defaults: ptr[PyObject],
    localsplus: ptr[u64],
    qualname: ptr[PyObject]
) {
    kwonly_given: i64 = 0;
    co_argcount = i64(call_i32_at(co, PyCodeObject_ARGCOUNT));
    kwonly_end = co_argcount + i64(call_i32_at(co, PyCodeObject_KWONLYARGCOUNT));
    i = co_argcount;
    while i < kwonly_end {
        if sr_borrow((localsplus + i).view(1)[0]) {
            kwonly_given += 1;
        }
        i += 1;
    }
    defcount: i64 = 0;
    if defaults {
        defcount = object_size(defaults);
    }
    plural = False;
    sig: ptr[PyObject] = NULL;
    if defcount != 0 {
        atleast = co_argcount - defcount;
        plural = True;
        sig = PyUnicode_FromFormat("from %zd to %zd", atleast, co_argcount);
    } else {
        plural = co_argcount != 1;
        sig = PyUnicode_FromFormat("%zd", co_argcount);
    }
    if not sig {
        return;
    }
    kwonly_sig: ptr[PyObject] = NULL;
    if kwonly_given != 0 {
        given_plural = ptr[u8]("");
        if given != 1 {
            given_plural = ptr[u8]("s");
        }
        kwonly_plural = ptr[u8]("");
        if kwonly_given != 1 {
            kwonly_plural = ptr[u8]("s");
        }
        kwonly_sig = PyUnicode_FromFormat(
            " positional argument%s (and %zd keyword-only argument%s)",
            given_plural,
            kwonly_given,
            kwonly_plural
        );
        if not kwonly_sig {
            object_decref(sig);
            return;
        }
    } else {
        kwonly_sig = Py_GetConstant(Py_CONSTANT_EMPTY_STR);
    }
    plural_s = ptr[u8]("");
    if plural {
        plural_s = ptr[u8]("s");
    }
    verb = ptr[u8]("were");
    if given == 1 and kwonly_given == 0 {
        verb = ptr[u8]("was");
    }
    _PyErr_Format(
        tstate,
        PyExc_TypeError,
        ptr[u8]("%U() takes %U positional argument%s but %zd%U %s given"),
        qualname,
        sig,
        plural_s,
        given,
        kwonly_sig,
        verb
    );
    object_decref(sig);
    object_decref(kwonly_sig);
}

impl positional_only_passed_as_keyword(
    tstate: ptr[PyThreadState],
    co: ptr[u8],
    kwcount: i64,
    kwnames: ptr[PyObject],
    qualname: ptr[PyObject]
) -> i32 {
    posonly_conflicts: i64 = 0;
    posonly_names = PyList_New(0);
    if not posonly_names {
        return 1;
    }
    names = ceval_obj_at(co, PyCodeObject_LOCALSPLUSNAMES);
    posonly = i64(call_i32_at(co, PyCodeObject_POSONLYARGCOUNT));
    for k in range(posonly) {
        posonly_name = tuple_get_item(names, k);
        for k2 in range(kwcount) {
            kwname = tuple_get_item(kwnames, k2);
            if kwname == posonly_name {
                if PyList_Append(posonly_names, kwname) != 0 {
                    object_decref(posonly_names);
                    return 1;
                }
                posonly_conflicts += 1;
                continue;
            }
            cmp = PyObject_RichCompareBool(posonly_name, kwname, Py_EQ);
            if cmp > 0 {
                if PyList_Append(posonly_names, kwname) != 0 {
                    object_decref(posonly_names);
                    return 1;
                }
                posonly_conflicts += 1;
            } elif cmp < 0 {
                object_decref(posonly_names);
                return 1;
            }
        }
    }
    if posonly_conflicts != 0 {
        comma = PyUnicode_FromString(ptr[u8](", "));
        if not comma {
            object_decref(posonly_names);
            return 1;
        }
        error_names = PyUnicode_Join(comma, posonly_names);
        object_decref(comma);
        if not error_names {
            object_decref(posonly_names);
            return 1;
        }
        _PyErr_Format(
            tstate,
            PyExc_TypeError,
            ptr[u8](
                "%U() got some positional-only arguments passed as keyword arguments: '%U'"
            ),
            qualname,
            error_names
        );
        object_decref(error_names);
        object_decref(posonly_names);
        return 1;
    }
    object_decref(posonly_names);
    return 0;
}

impl unexpected_keyword(
    tstate: ptr[PyThreadState],
    co: ptr[u8],
    kwcount: i64,
    kwnames: ptr[PyObject],
    qualname: ptr[PyObject],
    keyword: ptr[PyObject],
    total_args: i64
) {
    posonly = i64(call_i32_at(co, PyCodeObject_POSONLYARGCOUNT));
    if posonly != 0
        and positional_only_passed_as_keyword(tstate, co, kwcount, kwnames, qualname)
            != 0 {
        return;
    }
    co_varnames = tuple_items(ceval_obj_at(co, PyCodeObject_LOCALSPLUSNAMES));
    suggestion_keyword: ptr[PyObject] = NULL;
    if total_args > posonly {
        possible_keywords = PyList_New(total_args - posonly);
        if not possible_keywords {
            PyErr_Clear();
        } else {
            k = posonly;
            while k < total_args {
                (ceval_list_items(possible_keywords) + (k - posonly)).view(1)[0] = (
                    co_varnames + k
                ).view(
                    1
                )[0];
                k += 1;
            }
            suggestion_keyword = _Py_CalculateSuggestions(possible_keywords, keyword);
            object_decref(possible_keywords);
        }
    }
    if suggestion_keyword {
        _PyErr_Format(
            tstate,
            PyExc_TypeError,
            ptr[u8]("%U() got an unexpected keyword argument '%S'. Did you mean '%S'?"),
            qualname,
            keyword,
            suggestion_keyword
        );
        object_decref(suggestion_keyword);
    } else {
        _PyErr_Format(
            tstate,
            PyExc_TypeError,
            ptr[u8]("%U() got an unexpected keyword argument '%S'"),
            qualname,
            keyword
        );
    }
}

impl close_refs(refs: ptr[u64], start: i64, end: i64) {
    j = start;
    while j < end {
        sr_close((refs + j).view(1)[0]);
        j += 1;
    }
}

impl close_kwarg_refs(args: ptr[u64], argcount: i64, kwnames: ptr[PyObject]) {
    if kwnames {
        close_refs(args, argcount, argcount + object_size(kwnames));
    }
}

impl initialize_locals(
    tstate: ptr[PyThreadState],
    func: ptr[PyObject],
    localsplus: ptr[u64],
    args: ptr[u64],
    argcount: i64,
    kwnames: ptr[PyObject]
) -> i32 {
    fn = ptr[u8](func);
    co = call_func_code(func);
    co_argcount = i64(call_i32_at(co, PyCodeObject_ARGCOUNT));
    posonly = i64(call_i32_at(co, PyCodeObject_POSONLYARGCOUNT));
    flags = call_i32_at(co, PyCodeObject_FLAGS);
    qualname = ceval_obj_at(fn, PyFunctionObject_QUALNAME);
    total_args = co_argcount + i64(call_i32_at(co, PyCodeObject_KWONLYARGCOUNT));
    kwdict: ptr[PyObject] = NULL;
    if (flags & CO_VARKEYWORDS) != 0 {
        kwdict = PyDict_New();
        if not kwdict {
            close_refs(args, 0, argcount);
            close_kwarg_refs(args, argcount, kwnames);
            return -1;
        }
        slot = total_args;
        if (flags & CO_VARARGS) != 0 {
            slot += 1;
        }
        (localsplus + slot).view(1)[0] = sr_steal(kwdict);
    }
    n = argcount;
    if argcount > co_argcount {
        n = co_argcount;
    }
    for j in range(n) {
        (localsplus + j).view(1)[0] = (args + j).view(1)[0];
    }
    if (flags & CO_VARARGS) != 0 {
        u: ptr[PyObject] = NULL;
        if argcount == n {
            u = ceval_tuple_empty();
        } else {
            u = _PyTuple_FromStackRefStealOnSuccess(args + n, argcount - n);
            if not u {
                close_refs(args, n, argcount);
            }
        }
        if not u {
            close_kwarg_refs(args, argcount, kwnames);
            return -1;
        }
        (localsplus + total_args).view(1)[0] = sr_steal(u);
    } elif argcount > n {
        close_refs(args, n, argcount);
    }
    if kwnames {
        kwcount = object_size(kwnames);
        co_varnames = tuple_items(ceval_obj_at(co, PyCodeObject_LOCALSPLUSNAMES));
        i: i64 = 0;
        while i < kwcount {
            keyword = tuple_get_item(kwnames, i);
            value_stackref = (args + (i + argcount)).view(1)[0];
            if not keyword or not ceval_unicode_check(keyword) {
                _PyErr_Format(
                    tstate,
                    PyExc_TypeError,
                    ptr[u8]("%U() keywords must be strings"),
                    qualname
                );
                close_refs(args, i + argcount, kwcount + argcount);
                return -1;
            }
            found = False;
            j = posonly;
            while j < total_args {
                if (co_varnames + j).view(1)[0] == keyword {
                    found = True;
                    break;
                }
                j += 1;
            }
            if not found {
                j = posonly;
                while j < total_args {
                    cmp = PyObject_RichCompareBool(
                        keyword, (co_varnames + j).view(1)[0], Py_EQ
                    );
                    if cmp > 0 {
                        found = True;
                        break;
                    } elif cmp < 0 {
                        close_refs(args, i + argcount, kwcount + argcount);
                        return -1;
                    }
                    j += 1;
                }
            }
            if not found {
                if not kwdict {
                    unexpected_keyword(
                        tstate, co, kwcount, kwnames, qualname, keyword, total_args
                    );
                    close_refs(args, i + argcount, kwcount + argcount);
                    return -1;
                }
                if PyDict_SetItem(kwdict, keyword, sr_borrow(value_stackref)) == -1 {
                    close_refs(args, i + argcount, kwcount + argcount);
                    return -1;
                }
                sr_close(value_stackref);
                i += 1;
                continue;
            }
            if sr_borrow((localsplus + j).view(1)[0]) {
                _PyErr_Format(
                    tstate,
                    PyExc_TypeError,
                    ptr[u8]("%U() got multiple values for argument '%S'"),
                    qualname,
                    keyword
                );
                close_refs(args, i + argcount, kwcount + argcount);
                return -1;
            }
            (localsplus + j).view(1)[0] = value_stackref;
            i += 1;
        }
    }
    defaults = ceval_obj_at(fn, PyFunctionObject_DEFAULTS);
    if argcount > co_argcount and (flags & CO_VARARGS) == 0 {
        too_many_positional(tstate, co, argcount, defaults, localsplus, qualname);
        return -1;
    }
    if argcount < co_argcount {
        defcount: i64 = 0;
        if defaults {
            defcount = object_size(defaults);
        }
        m = co_argcount - defcount;
        missing: i64 = 0;
        i = argcount;
        while i < m {
            if sr_is_null((localsplus + i).view(1)[0]) {
                missing += 1;
            }
            i += 1;
        }
        if missing != 0 {
            missing_arguments(tstate, co, missing, defcount, localsplus, qualname);
            return -1;
        }
        i = 0;
        if n > m {
            i = n - m;
        }
        if defcount != 0 {
            defs = tuple_items(defaults);
            while i < defcount {
                if not sr_borrow((localsplus + (m + i)).view(1)[0]) {
                    (localsplus + (m + i)).view(1)[0] = sr_new((defs + i).view(1)[0]);
                }
                i += 1;
            }
        }
    }
    if total_args > co_argcount {
        kw_missing: i64 = 0;
        kwdefaults = ceval_obj_at(fn, PyFunctionObject_KWDEFAULTS);
        names = ceval_obj_at(co, PyCodeObject_LOCALSPLUSNAMES);
        i = co_argcount;
        while i < total_args {
            if sr_borrow((localsplus + i).view(1)[0]) {
                i += 1;
                continue;
            }
            varname = tuple_get_item(names, i);
            if kwdefaults {
                dflt: ptr[PyObject] = NULL;
                if PyDict_GetItemRef(kwdefaults, varname, &mut dflt) < 0 {
                    return -1;
                }
                if dflt {
                    (localsplus + i).view(1)[0] = sr_steal(dflt);
                    i += 1;
                    continue;
                }
            }
            kw_missing += 1;
            i += 1;
        }
        if kw_missing != 0 {
            missing_arguments(tstate, co, kw_missing, -1, localsplus, qualname);
            return -1;
        }
    }
    return 0;
}

impl clear_thread_frame(tstate: ptr[PyThreadState], frame: ptr[u8]) {
    _PyFrame_ClearExceptCode(frame);
    old = call_ref_at(frame, _PyInterpreterFrame_F_EXECUTABLE);
    call_set_ref_at(frame, _PyInterpreterFrame_F_EXECUTABLE, SR_NULL);
    sr_xclose(old);
    _PyThreadState_PopFrame(tstate, frame);
}

impl clear_gen_frame(tstate: ptr[PyThreadState], frame: ptr[u8]) {
    gen = frame - PyGenObject_IFRAME;
    (gen + PyGenObject_FRAME_STATE).view(1)[0] = u8(FRAME_CLEARED);
    call_set_ptr_at(
        ptr[u8](tstate),
        PyThreadState_EXC_INFO,
        call_ptr_at(gen, PyGenObject_EXC_PREVIOUS_ITEM)
    );
    call_set_ptr_at(gen, PyGenObject_EXC_PREVIOUS_ITEM, ptr[u8]());
    call_set_ptr_at(frame, _PyInterpreterFrame_PREVIOUS, ptr[u8]());
    _PyFrame_ClearExceptCode(frame);
    old = ceval_obj_at(gen, PyGenObject_EXC_VALUE);
    ceval_set_obj_at(gen, PyGenObject_EXC_VALUE, NULL);
    object_xdecref(old);
}

impl get_globals_builtins(globals: ptr[PyObject]) -> ptr[PyObject] {
    builtins: ptr[PyObject] = NULL;
    if ceval_dict_check(globals) {
        if PyDict_GetItemRef(globals, py_id(_Py_ID___builtins__), &mut builtins) < 0 {
            return NULL;
        }
    } else {
        if PyMapping_GetOptionalItem(globals, py_id(_Py_ID___builtins__), &mut builtins)
            < 0 {
            return NULL;
        }
    }
    return builtins;
}

impl set_globals_builtins(globals: ptr[PyObject], builtins: ptr[PyObject]) -> i32 {
    if ceval_dict_check(globals) {
        if PyDict_SetItem(globals, py_id(_Py_ID___builtins__), builtins) < 0 {
            return -1;
        }
    } else {
        if PyObject_SetItem(globals, py_id(_Py_ID___builtins__), builtins) < 0 {
            return -1;
        }
    }
    return 0;
}

impl _PyEval_GetGlobals(tstate: ptr[PyThreadState]) -> ptr[PyObject] {
    current_frame = ceval_thread_frame(tstate);
    if not current_frame {
        return NULL;
    }
    return ceval_obj_at(current_frame, _PyInterpreterFrame_F_GLOBALS);
}

impl import_from_done(
    origin: ptr[PyObject], spec: ptr[PyObject], mod_name_or_unknown: ptr[PyObject]
) -> ptr[PyObject] {
    object_xdecref(origin);
    object_xdecref(spec);
    object_decref(mod_name_or_unknown);
    return NULL;
}

impl import_from_raise(
    errmsg: ptr[PyObject],
    mod_name: ptr[PyObject],
    origin: ptr[PyObject],
    name: ptr[PyObject],
    spec: ptr[PyObject],
    mod_name_or_unknown: ptr[PyObject]
) -> ptr[PyObject] {
    if errmsg {
        _PyErr_SetImportErrorWithNameFrom(errmsg, mod_name, origin, name);
        object_decref(errmsg);
    }
    return import_from_done(origin, spec, mod_name_or_unknown);
}

impl import_from_error(
    tstate: ptr[PyThreadState],
    v: ptr[PyObject],
    name: ptr[PyObject],
    mod_name: ptr[PyObject]
) -> ptr[PyObject] {
    mod_name_or_unknown = mod_name;
    if not mod_name {
        mod_name_or_unknown = PyUnicode_FromString(ptr[u8]("<unknown module name>"));
        if not mod_name_or_unknown {
            return NULL;
        }
    }
    origin: ptr[PyObject] = NULL;
    spec: ptr[PyObject] = NULL;
    if PyObject_GetOptionalAttr(v, py_id(_Py_ID___spec__), &mut spec) < 0 {
        object_decref(mod_name_or_unknown);
        return NULL;
    }
    errmsg: ptr[PyObject] = NULL;
    if not spec {
        errmsg = PyUnicode_FromFormat(
            "cannot import name %R from %R (unknown location)",
            name,
            mod_name_or_unknown
        );
        return import_from_raise(
            errmsg, mod_name, origin, name, spec, mod_name_or_unknown
        );
    }
    if _PyModuleSpec_GetFileOrigin(spec, &mut origin) < 0 {
        return import_from_done(origin, spec, mod_name_or_unknown);
    }
    is_possibly_shadowing = _PyModule_IsPossiblyShadowing(origin);
    if is_possibly_shadowing < 0 {
        return import_from_done(origin, spec, mod_name_or_unknown);
    }
    is_possibly_shadowing_stdlib: i32 = 0;
    if is_possibly_shadowing != 0 {
        stdlib_modules: ptr[PyObject] = NULL;
        if _PySys_GetOptionalAttrString(
            ptr[u8]("stdlib_module_names"), &mut stdlib_modules
        )
            < 0 {
            return import_from_done(origin, spec, mod_name_or_unknown);
        }
        if stdlib_modules
            and (
                object_type_check(
                    stdlib_modules, ptr[PyTypeObject](addressof(PySet_Type))
                )
                or object_type_check(
                    stdlib_modules, ptr[PyTypeObject](addressof(PyFrozenSet_Type))
                )
            ) {
            is_possibly_shadowing_stdlib = PySet_Contains(
                stdlib_modules, mod_name_or_unknown
            );
            if is_possibly_shadowing_stdlib < 0 {
                object_decref(stdlib_modules);
                return import_from_done(origin, spec, mod_name_or_unknown);
            }
        }
        object_xdecref(stdlib_modules);
    }
    if not origin
        and object_type_check(v, ptr[PyTypeObject](addressof(PyModule_Type))) {
        origin = PyModule_GetFilenameObject(v);
        if not origin {
            if PyErr_ExceptionMatches(PyExc_SystemError) == 0 {
                return import_from_done(origin, spec, mod_name_or_unknown);
            }
            _PyErr_Clear(tstate);
        }
    }
    if is_possibly_shadowing_stdlib != 0 {
        errmsg = PyUnicode_FromFormat(
            "cannot import name %R from %R (consider renaming %R since it has the same name as the standard library module named %R and prevents importing that standard library module)",
            name,
            mod_name_or_unknown,
            origin,
            mod_name_or_unknown
        );
    } else {
        rc = _PyModuleSpec_IsInitializing(spec);
        if rc < 0 {
            return import_from_done(origin, spec, mod_name_or_unknown);
        } elif rc > 0 {
            if is_possibly_shadowing != 0 {
                errmsg = PyUnicode_FromFormat(
                    "cannot import name %R from %R (consider renaming %R if it has the same name as a library you intended to import)",
                    name,
                    mod_name_or_unknown,
                    origin
                );
            } elif origin {
                errmsg = PyUnicode_FromFormat(
                    "cannot import name %R from partially initialized module %R (most likely due to a circular import) (%S)",
                    name,
                    mod_name_or_unknown,
                    origin
                );
            } else {
                errmsg = PyUnicode_FromFormat(
                    "cannot import name %R from partially initialized module %R (most likely due to a circular import)",
                    name,
                    mod_name_or_unknown
                );
            }
        } else {
            if origin {
                errmsg = PyUnicode_FromFormat(
                    "cannot import name %R from %R (%S)",
                    name,
                    mod_name_or_unknown,
                    origin
                );
            } else {
                errmsg = PyUnicode_FromFormat(
                    "cannot import name %R from %R (unknown location)",
                    name,
                    mod_name_or_unknown
                );
            }
        }
    }
    return import_from_raise(errmsg, mod_name, origin, name, spec, mod_name_or_unknown);
}

impl type_has_special_method(cls: ptr[PyTypeObject], name: ptr[PyObject]) -> bool {
    r = _PyType_Lookup(cls, name);
    if not r {
        return False;
    }
    return int(object_type(r).view(1)[0].tp_descr_get) != 0;
}

impl index_check(v: ptr[PyObject]) -> bool {
    number = object_type(v).view(1)[0].tp_as_number;
    if not number {
        return False;
    }
    return int(number.view(1)[0].nb_index) != 0;
}

def ceval_unicode_check(op: ptr[PyObject]) -> bool;

def ceval_unicode_check_exact(op: ptr[PyObject]) -> bool;

def ceval_type_check(op: ptr[PyObject]) -> bool;

def ceval_dict_check(op: ptr[PyObject]) -> bool;

impl ceval_unicode_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_UNICODE_SUBCLASS);
}

impl ceval_unicode_check_exact(op: ptr[PyObject]) -> bool {
    return object_type(op) == ptr[PyTypeObject](addressof(PyUnicode_Type));
}

impl ceval_type_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_TYPE_SUBCLASS);
}

impl ceval_dict_check(op: ptr[PyObject]) -> bool {
    return type_has_feature(object_type(op), Py_TPFLAGS_DICT_SUBCLASS);
}
