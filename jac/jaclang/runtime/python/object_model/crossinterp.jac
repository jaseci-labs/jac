import from c {
    def _Py_GetMainModule(tstate: ptr[PyThreadState]) -> ptr[PyObject];  def _Py_CheckMainModule(
        module: ptr[PyObject]
    ) -> i32;  def _PyModule_GetFilenameUTF8(
        mod: ptr[PyObject], buffer: ptr[u8], maxlen: i64
    ) -> i64;  def _PyErr_GetRaisedException(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyObject];  def _PyErr_SetRaisedException(
        tstate: ptr[PyThreadState], exc: ptr[PyObject]
    );  def _PyErr_SetString(
        tstate: ptr[PyThreadState], exception: ptr[PyObject], string: ptr[u8]
    );  def _PyErr_Format(
        tstate: ptr[PyThreadState],
        exception: ptr[PyObject],
        format: ptr[u8],
        *args: any
    ) -> ptr[PyObject];  def _PyErr_SetObject(
        tstate: ptr[PyThreadState], exception: ptr[PyObject], value_in: ptr[PyObject]
    );  def _PyErr_ChainExceptions1Tstate(
        tstate: ptr[PyThreadState], exc: ptr[PyObject]
    );  def _PyErr_ExceptionMatches(
        tstate: ptr[PyThreadState], exc: ptr[PyObject]
    ) -> i32;  def _PyErr_Clear(tstate: ptr[PyThreadState]);  def PyModule_NewObject(
        name: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyEval_AddPendingCall(
        interp: ptr[u8], func: ptr, arg: ptr, flags: i32
    ) -> i32;  def PyException_GetArgs(self: ptr[PyObject]) -> ptr[PyObject];  def PyException_GetCause(
        self: ptr[PyObject]
    ) -> ptr[PyObject];  def PyObject_Size(o: ptr[PyObject]) -> i64;  def strncmp(
        left: ptr[u8], right: ptr[u8], size: u64
    ) -> i32;  def strcmp(left: ptr[u8], right: ptr[u8]) -> i32;  def strlen(
        text: ptr[u8]
    ) -> u64;  def strcpy(target: ptr[u8], source: ptr[u8]) -> ptr[u8];  def PyMemoryView_FromMemory(
        mem: ptr[u8], size: i64, flags: i32
    ) -> ptr[PyObject];  def PyMarshal_ReadObjectFromString(
        data: ptr[u8], len: i64
    ) -> ptr[PyObject];  def PyMarshal_WriteObjectToString(
        x: ptr[PyObject], version: i32
    ) -> ptr[PyObject];  def _PyEval_GetBuiltins(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyObject];  def _PyEval_GetGlobalsFromRunningMain(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyObject];  def _PyEval_EnsureBuiltins(
        tstate: ptr[PyThreadState],
        globals: ptr[PyObject],
        p_builtins: ptr[ptr[PyObject]]
    ) -> i32;  def _PyCode_VerifyStateless(
        tstate: ptr,
        co: ptr[PyObject],
        globalnames: ptr[PyObject],
        globalsns: ptr[PyObject],
        builtinsns: ptr[PyObject]
    ) -> i32;  def _PyCode_ReturnsOnlyNone(co: ptr[PyObject]) -> i32;  def _PyFunction_VerifyStateless(
        tstate: ptr, func: ptr[PyObject]
    ) -> i32;  def PyFunction_New(
        code: ptr[PyObject], globals: ptr[PyObject]
    ) -> ptr[PyObject];  def _Py_SourceAsString(
        cmd: ptr[PyObject],
        funcname: ptr[u8],
        what: ptr[u8],
        cf: ptr[PyCompilerFlags],
        cmd_copy: &mut ptr[PyObject]
    ) -> ptr[u8];  def _PyObject_SupportedAsScript(cmd: ptr[PyObject]) -> i32;  def Py_CompileStringExFlags(
        source: ptr[u8],
        filename: ptr[u8],
        start: i32,
        flags: ptr[PyCompilerFlags],
        optimize: i32
    ) -> ptr[PyObject];  def PyType_GetName(type: ptr[PyTypeObject]) -> ptr[PyObject];  def PyType_GetQualName(
        type: ptr[PyTypeObject]
    ) -> ptr[PyObject];  def PyType_GetModuleName(
        type: ptr[PyTypeObject]
    ) -> ptr[PyObject];  def _PyNamespace_New(kwds: ptr[PyObject]) -> ptr[PyObject];  def PyThreadState_Clear(
        tstate: ptr[PyThreadState]
    );  def PyThreadState_Delete(tstate: ptr[PyThreadState]);  def PyDict_GetItemString(
        v: ptr[PyObject], key: ptr[u8]
    ) -> ptr[PyObject];  def _Py_FatalErrorFunc(func: ptr[u8], message: ptr[u8]);  def PyUnicode_FromFormatV(
        format: ptr[u8], vargs: VaList
    ) -> ptr[PyObject];  def _PyStaticType_InitBuiltin(
        interp: ptr[u8], self_: ptr[PyTypeObject]
    ) -> i32;  def _PyStaticType_FiniBuiltin(
        interp: ptr[u8], type: ptr[PyTypeObject]
    );  def Py_EnterRecursiveCall(where: ptr[u8]) -> i32;  def PyErr_PrintEx(
        set_sys_last_vars: i32
    );  def PyInterpreterState_GetID(interp: ptr[u8]) -> i64;  def _PyInterpreterState_LookUpID(
        requested_id: i64
    ) -> ptr[u8];  def _PyThreadState_NewBound(
        interp: ptr[u8], whence: i32
    ) -> ptr[PyThreadState];  def _PyInterpreterState_SetRunningMain(
        interp: ptr[u8]
    ) -> i32;  def _PyInterpreterState_SetNotRunningMain(interp: ptr[u8]);  def _PyErr_SetInterpreterAlreadyRunning;  def _PyInterpreterState_SetWhence(
        interp: ptr[u8], whence: i64
    );  def _PyInterpreterState_IsReady(interp: ptr[u8]) -> i32;  def PyInterpreterState_Delete(
        interp: ptr[u8]
    );  def Py_EndInterpreter(tstate: ptr[PyThreadState]);  def Py_NewInterpreterFromConfig(
        tstate_p: ptr[ptr[PyThreadState]], config: ptr[PyInterpreterConfig]
    ) -> PyStatus;  def _PyErr_SetFromPyStatus(status: PyStatus);  def jacpy_stack_address(
        slots: &mut XIStack
    ) -> int;  obj XIStack {
        has w0: u64 = 0,
            w1: u64 = 0,
            w2: u64 = 0,
            w3: u64 = 0,
            w4: u64 = 0,
            w5: u64 = 0,
            w6: u64 = 0,
            w7: u64 = 0,
            w8: u64 = 0,
            w9: u64 = 0,
            w10: u64 = 0,
            w11: u64 = 0,
            w12: u64 = 0,
            w13: u64 = 0,
            w14: u64 = 0,
            w15: u64 = 0;
    }  obj XICall {
        has simple: Callable[[ptr], i32];
    }  obj CompilerFlags {
        has cf_flags: i32,
            cf_feature_version: i32;
    }  obj sync_module {
        has filename: ptr[u8],
            module: ptr[PyObject],
            loaded: ptr[PyObject],
            failed: ptr[PyObject];
    }  obj unpickle_context {
        has tstate: ptr[PyThreadState],
            filename: ptr[u8],
            module: ptr[PyObject],
            loaded: ptr[PyObject],
            failed: ptr[PyObject];
    }  obj shared_str_data {
        has kind: i32,
            buffer: ptr,
            len: i64;
    }  obj shared_tuple_data {
        has len: i64,
            items: ptr[ptr[_PyXIData_t]];
    }  obj _PyXI_excinfo {
        has type_builtin: ptr[PyTypeObject],
            type_name: ptr[u8],
            type_qualname: ptr[u8],
            type_module: ptr[u8],
            msg: ptr[u8],
            errdisplay: ptr[u8];
    }  obj _PyXI_failure {
        has code: i32,
            msg: ptr[u8],
            msg_owned: i32;
    }  obj _PyXI_error {
        has interp: ptr[u8],
            override_: ptr[_PyXI_failure],
            override_code: i32,
            override_msg: ptr[u8],
            override_msg_owned: i32,
            uncaught_type_builtin: ptr[PyTypeObject],
            uncaught_type_name: ptr[u8],
            uncaught_type_qualname: ptr[u8],
            uncaught_type_module: ptr[u8],
            uncaught_msg: ptr[u8],
            uncaught_errdisplay: ptr[u8];
    }  obj _PyXI_namespace_item {
        has name: ptr[u8],
            xidata: ptr[_PyXIData_t];
    }  obj _PyXI_namespace {
        has maxitems: i64,
            numnames: i64,
            numvalues: i64;
    }  obj _PyXI_session {
        has status: i32,
            switched: i32,
            prev_tstate: ptr[PyThreadState],
            init_tstate: ptr[PyThreadState],
            own_init_tstate: i32,
            running: i32,
            main_ns: ptr[PyObject],
            _preserved: ptr[PyObject];
    }  obj _PyXIData_regitem_t {
        has prev: ptr[_PyXIData_regitem_t],
            next: ptr[_PyXIData_regitem_t],
            cls: ptr[PyTypeObject],
            weakref: ptr[PyObject],
            refcount: u64,
            getdata_basic:
                Callable[[ptr[PyThreadState], ptr[PyObject], ptr[_PyXIData_t]], i32],
            getdata_fallback:
                Callable[
                    [ptr[PyThreadState], ptr[PyObject], i32, ptr[_PyXIData_t]],
                    i32
                ];
    }  obj _PyXIData_registry_t {
        has global: i32,
            initialized: i32,
            mutex: u8,
            head: ptr[_PyXIData_regitem_t];
    }  glob:priv _PyExc_InterpreterError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("concurrent.interpreters.InterpreterError"),
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("A cross-interpreter operation failed")
         ),
         _PyExc_InterpreterNotFoundError: PyTypeObject = PyTypeObject(
             ob_base=PyVarObject(
                 ob_base=_object(
                     ob_refcnt_full=_Py_STATIC_IMMORTAL_INITIAL_REFCNT,
                     ob_type=ptr[PyTypeObject]()
                 ),
                 ob_size=0
             ),
             tp_name=ptr[u8]("concurrent.interpreters.InterpreterNotFoundError"),
             tp_flags=Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE | Py_TPFLAGS_HAVE_GC,
             tp_doc=ptr[u8]("An interpreter was not found"),
             tp_base=addressof(_PyExc_InterpreterError)
         ); glob PyExc_InterpreterError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_InterpreterError)
         ),
         PyExc_InterpreterNotFoundError: ptr[PyObject] = ptr[PyObject](
             addressof(_PyExc_InterpreterNotFoundError)
         );
}

glob:priv XI_ERR_NO_ERROR: Final[i32] = 0,
     XI_ERR_UNCAUGHT_EXCEPTION: Final[i32] = -1,
     XI_ERR_OTHER: Final[i32] = -2,
     XI_ERR_NO_MEMORY: Final[i32] = -3,
     XI_ERR_ALREADY_RUNNING: Final[i32] = -4,
     XI_ERR_MAIN_NS_FAILURE: Final[i32] = -5,
     XI_ERR_APPLY_NS_FAILURE: Final[i32] = -6,
     XI_ERR_PRESERVE_FAILURE: Final[i32] = -7,
     XI_ERR_EXC_PROPAGATION_FAILURE: Final[i32] = -8,
     XI_ERR_NOT_SHAREABLE: Final[i32] = -9,
     XIDATA_XIDATA_ONLY: Final[i32] = 0,
     XIDATA_FULL_FALLBACK: Final[i32] = 1,
     SESSION_UNUSED: Final[i32] = 0,
     SESSION_ACTIVE: Final[i32] = 1,
     XIDATA_SIZE: Final[u64] = 40,
     BYTES_DATA_SIZE: Final[u64] = 16,
     SHARED_STR_DATA_SIZE: Final[u64] = 24,
     SHARED_TUPLE_DATA_SIZE: Final[u64] = 16,
     XI_FAILURE_SIZE: Final[u64] = 24,
     XI_SESSION_SIZE: Final[u64] = 48,
     XI_ERROR_OVERRIDE: Final[i64] = 16,
     XI_ERROR_UNCAUGHT: Final[i64] = 40,
     UNPICKLE_CONTEXT_MAIN: Final[i64] = 8,
     SHARED_PICKLE_CTX: Final[i64] = 16,
     PICKLE_CTX_UTF8: Final[i64] = 0,
     PICKLE_CTX_LEN: Final[i64] = 8,
     PICKLE_CTX_BUFFER: Final[i64] = 16,
     NAMESPACE_ITEMS: Final[i64] = 24,
     NAMESPACE_ITEM_SIZE: Final[i64] = 16,
     PY_MARSHAL_VERSION: Final[i32] = 5,
     PY_SSIZE_T_MAX_VALUE: Final[i64] = 9223372036854775807,
     WHENCE_XI: Final[i64] = 4,
     TSTATE_WHENCE_FINI: Final[i32] = 2,
     TSTATE_WHENCE_EXEC: Final[i32] = 5;

def tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8];

def xi_state(interp: ptr[u8]) -> ptr[u8];

def xi_global_state(interp: ptr[u8]) -> ptr[u8];

def xi_exc_slot(state: ptr[u8], offset: i64) -> ptr[ptr[PyObject]];

def scratch_of(slots: ptr) -> ptr[u8];

def excinfo_type(info: ptr[_PyXI_excinfo]) -> ptr[_PyXI_excinfo_type];

def error_override_storage(err: ptr[_PyXI_error]) -> ptr[_PyXI_failure];

def error_uncaught(err: ptr[_PyXI_error]) -> ptr[_PyXI_excinfo];

def unpickle_main(ctx: ptr[unpickle_context]) -> ptr[sync_module];

def ns_item(ns: ptr[_PyXI_namespace], i: i64) -> ptr[_PyXI_namespace_item];

def registry_mutex(registry: ptr[_PyXIData_registry_t]) -> ptr[PyMutex];

def function_code(func: ptr[PyObject]) -> ptr[PyObject];

def code_int(co: ptr[PyObject], offset: i64) -> i32;

def shared_pickle_data_size -> u64;

def call_simple_func(func: ptr, arg: ptr) -> i32;

def _Py_GetMainfile(buffer: ptr[u8], maxlen: u64) -> i64;

def runpy_run_path(filename: ptr[u8], modname: ptr[u8]) -> ptr[PyObject];

def set_exc_with_cause(exctype: ptr[PyObject], msg: ptr[u8]);

def sync_module_clear(data: ptr[sync_module]);

def sync_module_capture_exc(tstate: ptr[PyThreadState], data: ptr[sync_module]);

def ensure_isolated_main_error(
    tstate: ptr[PyThreadState],
    main: ptr[sync_module],
    loaded: ptr[PyObject],
    mod: ptr[PyObject],
    key: ptr[PyObject]
) -> i32;

def ensure_isolated_main(tstate: ptr[PyThreadState], main: ptr[sync_module]) -> i32;

def apply_isolated_main(tstate: ptr[PyThreadState], main: ptr[sync_module]) -> i32;

def restore_main(tstate: ptr[PyThreadState], main: ptr[sync_module]);

def _ensure_current_cause(tstate: ptr[PyThreadState], cause: ptr[PyObject]);

def _init_notshareableerror(state: ptr[u8]) -> i32;

def _fini_notshareableerror(state: ptr[u8]);

def get_notshareableerror_type(tstate: ptr[PyThreadState]) -> ptr[PyObject];

def _ensure_notshareableerror(
    tstate: ptr[PyThreadState], cause: ptr[PyObject], force: i32, msgobj: ptr[PyObject]
);

def set_notshareableerror(
    tstate: ptr[PyThreadState], cause: ptr[PyObject], force: i32, msg: ptr[u8]
);

def notshareableerror_from_message(
    tstate: ptr[PyThreadState], cause: ptr[PyObject], force: i32, msgobj: ptr[PyObject]
);

def fini_static_exctypes(state: ptr[u8], interp: ptr[u8]);

def init_static_exctypes(state: ptr[u8], interp: ptr[u8]) -> i32;

def fini_heap_exctypes(state: ptr[u8]);

def init_heap_exctypes(state: ptr[u8]) -> i32;

import from c {
    def _Py_CallInInterpreter(interp: ptr[u8], func: ptr, arg: ptr) -> i32 {
        if interp == ptr[u8](PyInterpreterState_Get()) {
            return call_simple_func(func, arg);
        }
        _PyEval_AddPendingCall(interp, func, arg, 0);
        return 0;
    }  def _Py_CallInInterpreterAndRawFree(
        interp: ptr[u8], func: ptr, arg: ptr
    ) -> i32 {
        if interp == ptr[u8](PyInterpreterState_Get()) {
            res = call_simple_func(func, arg);
            PyMem_RawFree(arg);
            return res;
        }
        _PyEval_AddPendingCall(interp, func, arg, _Py_PENDING_RAWFREE);
        return 0;
    }  def _PyXIData_New -> ptr[_PyXIData_t] {
        xid = ptr[_PyXIData_t](PyMem_RawCalloc(1, XIDATA_SIZE));
        if not xid {
            PyErr_NoMemory();
        }
        return xid;
    }  def _PyXIData_Free(xid: ptr[_PyXIData_t]) {
        interp = ptr[u8](PyInterpreterState_Get());
        _PyXIData_Clear(interp, xid);
        PyMem_RawFree(xid);
    }  def _PyXIData_Init(
        xidata: ptr[_PyXIData_t],
        interp: ptr[u8],
        shared: ptr,
        obj_: ptr[PyObject],
        new_object: ptr
    ) {
        _xidata_init(xidata);
        xidata.view(1)[0].data = shared;
        if obj_ {
            xidata.view(1)[0].obj_ = object_new_ref(obj_);
        }
        if interp {
            xidata.view(1)[0].interpid = PyInterpreterState_GetID(interp);
        } else {
            xidata.view(1)[0].interpid = -1;
        }
        xidata.view(1)[0].new_object = int(new_object);
    }  def _PyXIData_InitWithSize(
        xidata: ptr[_PyXIData_t],
        interp: ptr[u8],
        size: u64,
        obj_: ptr[PyObject],
        new_object: ptr
    ) -> i32 {
        _PyXIData_Init(xidata, interp, ptr(), obj_, new_object);
        xidata.view(1)[0].data = PyMem_RawCalloc(1, size);
        if not xidata.view(1)[0].data {
            return -1;
        }
        xidata.view(1)[0].free = int(ptr(PyMem_RawFree));
        return 0;
    }  def _PyXIData_Clear(interp: ptr[u8], xidata: ptr[_PyXIData_t]) {
        _xidata_clear(xidata);
    }  def _PyObject_CheckXIData(
        tstate: ptr[PyThreadState], obj_: ptr[PyObject]
    ) -> i32 {
        (status, global_lookup, local_lookup) = get_lookup_context(tstate);
        if status < 0 {
            return -1;
        }
        (basic, fallback) = lookup_getdata(global_lookup, local_lookup, obj_);
        if basic == 0 and fallback == 0 {
            if not PyErr_Occurred() {
                _set_xid_lookup_failure(tstate, obj_, ptr[u8](), NULL);
            }
            return -1;
        }
        return 0;
    }  def _PyObject_GetXIDataNoFallback(
        tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
    ) -> i32 {
        return _get_xidata(tstate, obj_, XIDATA_XIDATA_ONLY, xidata);
    }  def _PyObject_GetXIData(
        tstate: ptr[PyThreadState],
        obj_: ptr[PyObject],
        fallback: i32,
        xidata: ptr[_PyXIData_t]
    ) -> i32 {
        if fallback == XIDATA_XIDATA_ONLY {
            return _get_xidata(tstate, obj_, fallback, xidata);
        } elif fallback == XIDATA_FULL_FALLBACK {
            if _get_xidata(tstate, obj_, fallback, xidata) == 0 {
                return 0;
            }
            exc = _PyErr_GetRaisedException(tstate);
            if function_check(obj_) {
                if _PyFunction_GetXIData(tstate, obj_, xidata) == 0 {
                    object_decref(exc);
                    return 0;
                }
                _PyErr_Clear(tstate);
            }
            if _PyPickle_GetXIData(tstate, obj_, xidata) == 0 {
                object_decref(exc);
                return 0;
            }
            _PyErr_SetRaisedException(tstate, exc);
            return -1;
        }
        _PyErr_SetString(
            tstate, PyExc_SystemError, ptr[u8]("unsupported xidata fallback option")
        );
        return -1;
    }  def _PyPickle_LoadFromXIData(xidata: ptr[_PyXIData_t]) -> ptr[PyObject] {
        tstate = thread_state();
        shared = ptr[u8](xidata.view(1)[0].data);
        pickled_data = ptr[_PyBytes_data_t](shared);
        pickled = PyMemoryView_FromMemory(
            pickled_data.view(1)[0].bytes, pickled_data.view(1)[0].len, PyBUF_READ
        );
        if not pickled {
            return NULL;
        }
        slots: own XIStack = XIStack();
        ctx = ptr[unpickle_context](jacpy_stack_address(&mut slots));
        ctx.view(1)[0].tstate = tstate;
        ctx.view(1)[0].filename = ptr[ptr[u8]](
            shared + SHARED_PICKLE_CTX + PICKLE_CTX_UTF8
        ).view(
            1
        )[0];
        obj_ = _PyPickle_Loads(ctx, pickled);
        object_decref(pickled);
        _unpickle_context_clear(ctx);
        if not obj_ {
            cause = _PyErr_GetRaisedException(tstate);
            _set_xid_lookup_failure(
                tstate, NULL, ptr[u8]("object could not be unpickled"), cause
            );
            object_decref(cause);
        }
        return obj_;
    }  def _PyPickle_GetXIData(
        tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
    ) -> i32 {
        bytes_obj = _PyPickle_Dumps(tstate, obj_);
        if not bytes_obj {
            cause = _PyErr_GetRaisedException(tstate);
            _set_xid_lookup_failure(
                tstate, NULL, ptr[u8]("object could not be pickled"), cause
            );
            object_decref(cause);
            return -1;
        }
        size = shared_pickle_data_size();
        shared = _PyBytes_GetXIDataWrapped(
            tstate, bytes_obj, size, ptr(_PyPickle_LoadFromXIData), xidata
        );
        object_decref(bytes_obj);
        if not shared {
            return -1;
        }
        if _set_pickle_xid_context(tstate, ptr[u8](shared) + SHARED_PICKLE_CTX) < 0 {
            _xidata_clear(xidata);
            return -1;
        }
        return 0;
    }  def _PyMarshal_ReadObjectFromXIData(xidata: ptr[_PyXIData_t]) -> ptr[PyObject] {
        tstate = thread_state();
        shared = ptr[_PyBytes_data_t](xidata.view(1)[0].data);
        obj_ = PyMarshal_ReadObjectFromString(
            shared.view(1)[0].bytes, shared.view(1)[0].len
        );
        if not obj_ {
            cause = _PyErr_GetRaisedException(tstate);
            _set_xid_lookup_failure(
                tstate, NULL, ptr[u8]("object could not be unmarshalled"), cause
            );
            object_decref(cause);
            return NULL;
        }
        return obj_;
    }  def _PyMarshal_GetXIData(
        tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
    ) -> i32 {
        bytes_obj = PyMarshal_WriteObjectToString(obj_, PY_MARSHAL_VERSION);
        if not bytes_obj {
            cause = _PyErr_GetRaisedException(tstate);
            _set_xid_lookup_failure(
                tstate, NULL, ptr[u8]("object could not be marshalled"), cause
            );
            object_decref(cause);
            return -1;
        }
        shared = _PyBytes_GetXIDataWrapped(
            tstate,
            bytes_obj,
            BYTES_DATA_SIZE,
            ptr(_PyMarshal_ReadObjectFromXIData),
            xidata
        );
        object_decref(bytes_obj);
        if not shared {
            return -1;
        }
        return 0;
    }  def _PyCode_GetScriptXIData(
        tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
    ) -> i32 {
        return get_script_xidata(tstate, obj_, 0, xidata);
    }  def _PyCode_GetPureScriptXIData(
        tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
    ) -> i32 {
        return get_script_xidata(tstate, obj_, 1, xidata);
    }  def _PyXIData_NewObject(xidata: ptr[_PyXIData_t]) -> ptr[PyObject] {
        return xidata.view(1)[0].new_object(xidata);
    }  def _PyXIData_Release(xidata: ptr[_PyXIData_t]) -> i32 {
        return _xidata_release(xidata, 0);
    }  def _PyXIData_ReleaseAndRawFree(xidata: ptr[_PyXIData_t]) -> i32 {
        return _xidata_release(xidata, 1);
    }
}

def _xidata_init(xidata: ptr[_PyXIData_t]);

def _xidata_clear(xidata: ptr[_PyXIData_t]);

def _set_xid_lookup_failure(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], msg: ptr[u8], cause: ptr[PyObject]
);

def _check_xidata(tstate: ptr[PyThreadState], xidata: ptr[_PyXIData_t]) -> i32;

def call_getdata(
    basic: int,
    fallback_fn: int,
    tstate: ptr[PyThreadState],
    obj_: ptr[PyObject],
    fallback: i32,
    xidata: ptr[_PyXIData_t]
) -> i32;

def _get_xidata(
    tstate: ptr[PyThreadState],
    obj_: ptr[PyObject],
    fallback: i32,
    xidata: ptr[_PyXIData_t]
) -> i32;

def _PyPickle_Dumps(tstate: ptr[PyThreadState], obj_: ptr[PyObject]) -> ptr[PyObject];

def _unpickle_context_clear(ctx: ptr[unpickle_context]);

def check_missing___main___attr(exc: ptr[PyObject]) -> i32;

def _PyPickle_Loads(
    ctx: ptr[unpickle_context], pickled: ptr[PyObject]
) -> ptr[PyObject];

def _set_pickle_xid_context(tstate: ptr[PyThreadState], ctx: ptr[u8]) -> i32;

def verify_script(
    tstate: ptr[PyThreadState], co: ptr[PyObject], checked: i32, pure: i32
) -> i32;

def get_script_xidata_error(tstate: ptr[PyThreadState], code: ptr[PyObject]) -> i32;

def get_script_xidata(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], pure: i32, xidata: ptr[_PyXIData_t]
) -> i32;

def _call_clear_xidata(data: ptr) -> i32;

def _xidata_release(xidata: ptr[_PyXIData_t], rawfree: i32) -> i32;

def _copy_string_obj_raw(strobj: ptr[PyObject]) -> tuple[ptr[u8], i64];

def _convert_exc_to_TracebackException_error(
    args: ptr[PyObject], kwargs: ptr[PyObject], create: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def _convert_exc_to_TracebackException(
    exc: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

def _format_TracebackException(tbexc: ptr[PyObject]) -> ptr[u8];

def _release_xid_data(xidata: ptr[_PyXIData_t], rawfree: i32) -> i32;

def _excinfo_init_type_from_exception(
    info: ptr[_PyXI_excinfo_type], exc: ptr[PyObject]
) -> i32;

def _excinfo_init_type_from_object(
    info: ptr[_PyXI_excinfo_type], exctype: ptr[PyObject]
) -> i32;

def _excinfo_clear_type(info: ptr[_PyXI_excinfo_type]);

def _excinfo_normalize_type(info: ptr[_PyXI_excinfo_type]) -> tuple[ptr[u8], ptr[u8]];

def excinfo_is_set(info: ptr[_PyXI_excinfo]) -> i32;

def _PyXI_excinfo_clear(info: ptr[_PyXI_excinfo]);

def _PyXI_excinfo_InitFromException(
    info: ptr[_PyXI_excinfo], exc: ptr[PyObject]
) -> ptr[u8];

def _PyXI_excinfo_InitFromObject(
    info: ptr[_PyXI_excinfo], obj_: ptr[PyObject]
) -> ptr[u8];

def _PyXI_excinfo_Apply(info: ptr[_PyXI_excinfo], exctype: ptr[PyObject]);

def set_namespace_text(ns: ptr[PyObject], attr: ptr[u8], text: ptr[u8]) -> i32;

def _PyXI_excinfo_TypeAsObject(info: ptr[_PyXI_excinfo]) -> ptr[PyObject];

def _PyXI_excinfo_AsObject(info: ptr[_PyXI_excinfo]) -> ptr[PyObject];

import from c {
    def _PyXI_excinfo_format(info: ptr[_PyXI_excinfo]) -> ptr[PyObject] {
        (module, qualname) = _excinfo_normalize_type(excinfo_type(info));
        msg = info.view(1)[0].msg;
        if qualname {
            if module {
                if msg {
                    return PyUnicode_FromFormat("%s.%s: %s", module, qualname, msg);
                }
                return PyUnicode_FromFormat("%s.%s", module, qualname);
            }
            if msg {
                return PyUnicode_FromFormat("%s: %s", qualname, msg);
            }
            return PyUnicode_FromString(qualname);
        } elif msg {
            return PyUnicode_FromString(msg);
        }
        return object_new_ref(Py_None);
    }  def _PyXI_NewExcInfo(exc: ptr[PyObject]) -> ptr[_PyXI_excinfo] {
        if not exc or exc == Py_None {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("missing exc"));
            return ptr[_PyXI_excinfo]();
        }
        info = ptr[_PyXI_excinfo](PyMem_RawCalloc(1, u64(_PyXI_excinfo_SIZE)));
        if not info {
            return info;
        }
        failure = ptr[u8]();
        if exception_instance_check(exc) or exception_class_check(exc) {
            failure = _PyXI_excinfo_InitFromException(info, exc);
        } else {
            failure = _PyXI_excinfo_InitFromObject(info, exc);
        }
        if failure {
            PyMem_RawFree(info);
            set_exc_with_cause(PyExc_Exception, failure);
            return ptr[_PyXI_excinfo]();
        }
        return info;
    }  def _PyXI_FreeExcInfo(info: ptr[_PyXI_excinfo]) {
        _PyXI_excinfo_clear(info);
        PyMem_RawFree(info);
    }  def _PyXI_FormatExcInfo(info: ptr[_PyXI_excinfo]) -> ptr[PyObject] {
        return _PyXI_excinfo_format(info);
    }  def _PyXI_ExcInfoAsObject(info: ptr[_PyXI_excinfo]) -> ptr[PyObject] {
        return _PyXI_excinfo_AsObject(info);
    }  def _PyXI_NewFailure -> ptr[_PyXI_failure] {
        failure = ptr[_PyXI_failure](PyMem_RawMalloc(XI_FAILURE_SIZE));
        if not failure {
            PyErr_NoMemory();
            return failure;
        }
        failure_reset(failure);
        return failure;
    }  def _PyXI_FreeFailure(failure: ptr[_PyXI_failure]) {
        clear_xi_failure(failure);
        PyMem_RawFree(failure);
    }  def _PyXI_GetFailureCode(failure: ptr[_PyXI_failure]) -> i32 {
        if not failure {
            return XI_ERR_NO_ERROR;
        }
        return failure.view(1)[0].code;
    }  def _PyXI_InitFailureUTF8(failure: ptr[_PyXI_failure], code: i32, msg: ptr[u8]) {
        failure.view(1)[0].code = code;
        failure.view(1)[0].msg = msg;
        failure.view(1)[0].msg_owned = 0;
    }  def _PyXI_InitFailure(
        failure: ptr[_PyXI_failure], code: i32, obj_: ptr[PyObject]
    ) -> i32 {
        failure.view(1)[0].code = code;
        failure.view(1)[0].msg = ptr[u8]();
        failure.view(1)[0].msg_owned = 0;
        if not obj_ {
            return 0;
        }
        msgobj = PyObject_Str(obj_);
        if not msgobj {
            return -1;
        }
        (msg, msg_size) = _copy_string_obj_raw(msgobj);
        object_decref(msgobj);
        if not msg {
            return -1;
        }
        failure.view(1)[0].code = code;
        failure.view(1)[0].msg = msg;
        failure.view(1)[0].msg_owned = 1;
        return 0;
    }
}

def _PyXI_ApplyErrorCode(code: i32, interp: ptr[u8]) -> i32;

def failure_reset(failure: ptr[_PyXI_failure]);

def clear_xi_failure(failure: ptr[_PyXI_failure]);

def copy_xi_failure(dest: ptr[_PyXI_failure], src: ptr[_PyXI_failure]);

def xi_error_clear(err: ptr[_PyXI_error]);

def xi_error_is_set(error: ptr[_PyXI_error]) -> i32;

def xi_error_has_override(err: ptr[_PyXI_error]) -> i32;

def xi_error_resolve_current_exc(
    tstate: ptr[PyThreadState], override_: ptr[_PyXI_failure]
) -> ptr[PyObject];

def xi_error_set_override(
    tstate: ptr[PyThreadState], err: ptr[_PyXI_error], override_: ptr[_PyXI_failure]
);

def xi_error_set_override_code(
    tstate: ptr[PyThreadState], err: ptr[_PyXI_error], code: i32
);

def xi_error_set_exc(
    tstate: ptr[PyThreadState], err: ptr[_PyXI_error], exc: ptr[PyObject]
) -> ptr[u8];

def _PyXI_ApplyError(error: ptr[_PyXI_error], failure: ptr[u8]) -> ptr[PyObject];

def _sharednsitem_init(item: ptr[_PyXI_namespace_item], key: ptr[PyObject]) -> i32;

def _sharednsitem_has_value(item: ptr[_PyXI_namespace_item]) -> tuple[i32, i64];

def _sharednsitem_set_value(
    item: ptr[_PyXI_namespace_item], value: ptr[PyObject], fallback: i32
) -> i32;

def _sharednsitem_clear_value(item: ptr[_PyXI_namespace_item]);

def _sharednsitem_clear(item: ptr[_PyXI_namespace_item]);

def _sharednsitem_copy_from_ns(
    item: ptr[_PyXI_namespace_item], ns: ptr[PyObject], fallback: i32
) -> i32;

def _sharednsitem_apply(
    item: ptr[_PyXI_namespace_item], ns: ptr[PyObject], dflt: ptr[PyObject]
) -> i32;

def _sharedns_alloc(maxitems: i64) -> ptr[_PyXI_namespace];

def _sharedns_free(ns: ptr[_PyXI_namespace]);

def _create_sharedns(names: ptr[PyObject]) -> ptr[_PyXI_namespace];

def _fill_sharedns(
    ns: ptr[_PyXI_namespace],
    nsobj: ptr[PyObject],
    fallback: i32,
    p_err: ptr[_PyXI_failure]
) -> i32;

def _sharedns_free_pending(data: ptr) -> i32;

def _destroy_sharedns(ns: ptr[_PyXI_namespace]);

def _apply_sharedns(
    ns: ptr[_PyXI_namespace], nsobj: ptr[PyObject], dflt: ptr[PyObject]
) -> i32;

def _session_is_active(session: ptr[_PyXI_session]) -> bool;

def session_reset(session: ptr[_PyXI_session]);

def _enter_session(session: ptr[_PyXI_session], interp: ptr[u8]);

def _exit_session(session: ptr[_PyXI_session]);

def _propagate_not_shareable_error(
    tstate: ptr[PyThreadState], override_: ptr[_PyXI_failure]
);

def _enter_session_failed(
    session: ptr[_PyXI_session],
    sharedns: ptr[_PyXI_namespace],
    override_: ptr[_PyXI_failure],
    result: ptr[_PyXI_session_result]
) -> i32;

def capture_session_error(
    session: ptr[_PyXI_session], err: ptr[_PyXI_error], override_: ptr[_PyXI_failure]
) -> ptr[u8];

def _ensure_main_ns(session: ptr[_PyXI_session], failure: ptr[_PyXI_failure]) -> i32;

def _pop_preserved(
    session: ptr[_PyXI_session], p_failure: ptr[_PyXI_failure]
) -> tuple[i32, ptr[_PyXI_namespace], ptr[PyObject]];

def _finish_preserved(
    xidata: ptr[_PyXI_namespace], current: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]];

import from c {
    def _PyXI_NewSession -> ptr[_PyXI_session] {
        session = ptr[_PyXI_session](PyMem_RawCalloc(1, XI_SESSION_SIZE));
        if not session {
            PyErr_NoMemory();
        }
        return session;
    }  def _PyXI_FreeSession(session: ptr[_PyXI_session]) {
        PyMem_RawFree(session);
    }  def _PyXI_Enter(
        session: ptr[_PyXI_session],
        interp: ptr[u8],
        nsupdates: ptr[PyObject],
        result: ptr[_PyXI_session_result]
    ) -> i32 {
        sharedns = ptr[_PyXI_namespace]();
        if nsupdates {
            len = PyDict_Size(nsupdates);
            if len < 0 {
                if result {
                    result.view(1)[0].errcode = XI_ERR_APPLY_NS_FAILURE;
                }
                return -1;
            }
            if len > 0 {
                sharedns = _create_sharedns(nsupdates);
                if not sharedns {
                    if result {
                        result.view(1)[0].errcode = XI_ERR_APPLY_NS_FAILURE;
                    }
                    return -1;
                }
                fill_slots: own XIStack = XIStack();
                fill_err = ptr[_PyXI_failure](jacpy_stack_address(&mut fill_slots));
                failure_reset(fill_err);
                if _fill_sharedns(sharedns, nsupdates, XIDATA_XIDATA_ONLY, fill_err)
                    < 0 {
                    if fill_err.view(1)[0].code == XI_ERR_NO_ERROR {
                        fill_err.view(1)[0].code = XI_ERR_UNCAUGHT_EXCEPTION;
                    }
                    _destroy_sharedns(sharedns);
                    if result {
                        result.view(1)[0].errcode = fill_err.view(1)[0].code;
                    }
                    return -1;
                }
            }
        }
        _enter_session(session, interp);
        slots: own XIStack = XIStack();
        override_ = ptr[_PyXI_failure](jacpy_stack_address(&mut slots));
        failure_reset(override_);
        override_.view(1)[0].code = XI_ERR_UNCAUGHT_EXCEPTION;
        if _PyInterpreterState_SetRunningMain(interp) < 0 {
            override_.view(1)[0].code = XI_ERR_ALREADY_RUNNING;
            return _enter_session_failed(session, sharedns, override_, result);
        }
        session.view(1)[0].running = 1;
        if sharedns {
            if _ensure_main_ns(session, override_) < 0 {
                return _enter_session_failed(session, sharedns, override_, result);
            }
            if _apply_sharedns(sharedns, session.view(1)[0].main_ns, NULL) < 0 {
                override_.view(1)[0].code = XI_ERR_APPLY_NS_FAILURE;
                return _enter_session_failed(session, sharedns, override_, result);
            }
            _destroy_sharedns(sharedns);
        }
        override_.view(1)[0].code = XI_ERR_NO_ERROR;
        return 0;
    }  def _PyXI_Exit(
        session: ptr[_PyXI_session],
        override_: ptr[_PyXI_failure],
        result: ptr[_PyXI_session_result]
    ) -> i32 {
        tstate = thread_state();
        res: i32 = 0;
        slots: own XIStack = XIStack();
        err = ptr[_PyXI_error](jacpy_stack_address(&mut slots));
        failure = ptr[u8]();
        given = override_;
        if given and given.view(1)[0].code == XI_ERR_NO_ERROR {
            given = ptr[_PyXI_failure]();
        }
        if PyErr_Occurred() {
            failure = capture_session_error(session, err, given);
        }
        preserved = ptr[_PyXI_namespace]();
        preservedobj = NULL;
        if result {
            pop_slots: own XIStack = XIStack();
            pop_failure = ptr[_PyXI_failure](jacpy_stack_address(&mut pop_slots));
            failure_reset(pop_failure);
            (pop_status, popped, popped_obj) = _pop_preserved(session, pop_failure);
            preserved = popped;
            preservedobj = popped_obj;
            if pop_status < 0 {
                if xi_error_is_set(err) != 0 {
                    PyErr_FormatUnraisable(
                        ptr[u8]("Exception ignored while capturing preserved objects")
                    );
                    clear_xi_failure(pop_failure);
                } else {
                    if pop_failure.view(1)[0].code == XI_ERR_NO_ERROR {
                        pop_failure.view(1)[0].code = XI_ERR_UNCAUGHT_EXCEPTION;
                    }
                    failure = capture_session_error(session, err, pop_failure);
                }
            }
        }
        _exit_session(session);
        tstate = thread_state();
        (finish_status, finished) = _finish_preserved(preserved, preservedobj);
        preservedobj = finished;
        if finish_status < 0 {
            if xi_error_is_set(err) != 0 {
                PyErr_FormatUnraisable(
                    ptr[u8]("Exception ignored while capturing preserved objects")
                );
            } else {
                xi_error_set_override_code(tstate, err, XI_ERR_PRESERVE_FAILURE);
                _propagate_not_shareable_error(tstate, err.view(1)[0].override_);
            }
        }
        if result {
            result.view(1)[0].preserved = preservedobj;
            if err.view(1)[0].override_ {
                result.view(1)[0].errcode = err.view(1)[0].override_.view(1)[0].code;
            } else {
                result.view(1)[0].errcode = XI_ERR_NO_ERROR;
            }
        }
        if xi_error_is_set(err) != 0 {
            res = -1;
            excinfo = _PyXI_ApplyError(err, failure);
            if not excinfo {
                if result and xi_error_has_override(err) == 0 {
                    _PyXI_ClearResult(result);
                    result.view(1)[0].preserved = NULL;
                    result.view(1)[0].excinfo = NULL;
                    result.view(1)[0].errcode = XI_ERR_EXC_PROPAGATION_FAILURE;
                }
            } elif result {
                result.view(1)[0].excinfo = excinfo;
            } else {
                object_decref(excinfo);
            }
            xi_error_clear(err);
        }
        return res;
    }  def _PyXI_GetMainNamespace(
        session: ptr[_PyXI_session], failure: ptr[_PyXI_failure]
    ) -> ptr[PyObject] {
        if not _session_is_active(session) {
            PyErr_SetString(PyExc_RuntimeError, ptr[u8]("session not active"));
            return NULL;
        }
        if _ensure_main_ns(session, failure) < 0 {
            return NULL;
        }
        return session.view(1)[0].main_ns;
    }  def _PyXI_Preserve(
        session: ptr[_PyXI_session],
        name: ptr[u8],
        value: ptr[PyObject],
        p_failure: ptr[_PyXI_failure]
    ) -> i32 {
        if not _session_is_active(session) {
            PyErr_SetString(PyExc_RuntimeError, ptr[u8]("session not active"));
            return -1;
        }
        if not session.view(1)[0]._preserved {
            session.view(1)[0]._preserved = PyDict_New();
            if not session.view(1)[0]._preserved {
                set_exc_with_cause(
                    PyExc_RuntimeError,
                    ptr[u8]("failed to initialize preserved objects")
                );
                if p_failure {
                    failure_reset(p_failure);
                    p_failure.view(1)[0].code = XI_ERR_PRESERVE_FAILURE;
                }
                return -1;
            }
        }
        if PyDict_SetItemString(session.view(1)[0]._preserved, name, value) < 0 {
            set_exc_with_cause(
                PyExc_RuntimeError, ptr[u8]("failed to preserve object")
            );
            if p_failure {
                failure_reset(p_failure);
                p_failure.view(1)[0].code = XI_ERR_PRESERVE_FAILURE;
            }
            return -1;
        }
        return 0;
    }  def _PyXI_GetPreserved(
        result: ptr[_PyXI_session_result], name: ptr[u8]
    ) -> ptr[PyObject] {
        value = NULL;
        if result.view(1)[0].preserved {
            PyDict_GetItemStringRef(result.view(1)[0].preserved, name, &mut value);
        }
        return value;
    }  def _PyXI_ClearResult(result: ptr[_PyXI_session_result]) {
        old = result.view(1)[0].preserved;
        result.view(1)[0].preserved = NULL;
        object_xdecref(old);
        old = result.view(1)[0].excinfo;
        result.view(1)[0].excinfo = NULL;
        object_xdecref(old);
    }  def _Py_xi_global_state_init(state: ptr[u8]) -> i32 {
        xid_lookup_init(state);
        return 0;
    }  def _Py_xi_global_state_fini(state: ptr[u8]) {
        xid_lookup_fini(state);
    }  def _Py_xi_state_init(state: ptr[u8], interp: ptr[u8]) -> i32 {
        xid_lookup_init(state);
        if interp {
            if init_static_exctypes(state, interp) < 0 {
                fini_heap_exctypes(state);
                return -1;
            }
        }
        if init_heap_exctypes(state) < 0 {
            return -1;
        }
        return 0;
    }  def _Py_xi_state_fini(state: ptr[u8], interp: ptr[u8]) {
        fini_heap_exctypes(state);
        if interp {
            fini_static_exctypes(state, interp);
        }
        xid_lookup_fini(state);
    }  def _PyXI_Init(interp: ptr[u8]) -> PyStatus {
        if interp == ptr[u8](_PyInterpreterState_Main()) {
            global_state = xi_global_state(interp);
            if not global_state {
                PyErr_PrintEx(0);
                return status_error(
                    ptr[u8]("_PyXI_Init"),
                    ptr[u8]("failed to get global cross-interpreter state")
                );
            }
            if _Py_xi_global_state_init(global_state) < 0 {
                PyErr_PrintEx(0);
                return status_error(
                    ptr[u8]("_PyXI_Init"),
                    ptr[u8]("failed to initialize  global cross-interpreter state")
                );
            }
        }
        state = xi_state(interp);
        if not state {
            PyErr_PrintEx(0);
            return status_error(
                ptr[u8]("_PyXI_Init"),
                ptr[u8]("failed to get interpreter's cross-interpreter state")
            );
        }
        if _Py_xi_state_init(state, ptr[u8]()) < 0 {
            PyErr_PrintEx(0);
            return status_error(
                ptr[u8]("_PyXI_Init"),
                ptr[u8]("failed to initialize interpreter's cross-interpreter state")
            );
        }
        return status_ok();
    }  def _PyXI_Fini(interp: ptr[u8]) {
        state = xi_state(interp);
        _Py_xi_state_fini(state, ptr[u8]());
        if interp == ptr[u8](_PyInterpreterState_Main()) {
            global_state = xi_global_state(interp);
            _Py_xi_global_state_fini(global_state);
        }
    }  def _PyXI_InitTypes(interp: ptr[u8]) -> PyStatus {
        if init_static_exctypes(xi_state(interp), interp) < 0 {
            PyErr_PrintEx(0);
            return status_error(
                ptr[u8]("_PyXI_InitTypes"),
                ptr[u8]("failed to initialize the cross-interpreter exception types")
            );
        }
        return status_ok();
    }  def _PyXI_FiniTypes(interp: ptr[u8]) {
        fini_static_exctypes(xi_state(interp), interp);
    }  def _PyXI_NewInterpreter(
        config: ptr[PyInterpreterConfig],
        maybe_whence: ptr[i64],
        p_tstate: ptr[ptr[PyThreadState]],
        p_save_tstate: ptr[ptr[PyThreadState]]
    ) -> ptr[u8] {
        save_tstate = PyThreadState_Swap(ptr[PyThreadState]());
        slots: own XIStack = XIStack();
        tstate_slot = ptr[ptr[PyThreadState]](jacpy_stack_address(&mut slots));
        status = Py_NewInterpreterFromConfig(tstate_slot, config);
        if status._type != _PyStatus_TYPE_OK {
            PyThreadState_Swap(save_tstate);
            _PyErr_SetFromPyStatus(status);
            exc = PyErr_GetRaisedException();
            PyErr_SetString(
                PyExc_InterpreterError, ptr[u8]("sub-interpreter creation failed")
            );
            _PyErr_ChainExceptions1(exc);
            return ptr[u8]();
        }
        tstate = tstate_slot.view(1)[0];
        interp = ptr[u8](PyThreadState_GetInterpreter(tstate));
        whence: i64 = WHENCE_XI;
        if maybe_whence {
            whence = maybe_whence.view(1)[0];
        }
        _PyInterpreterState_SetWhence(interp, whence);
        if p_tstate {
            p_tstate.view(1)[0] = tstate;
        } else {
            PyThreadState_Clear(tstate);
            PyThreadState_Swap(save_tstate);
            PyThreadState_Delete(tstate);
            save_tstate = ptr[PyThreadState]();
        }
        if p_save_tstate {
            p_save_tstate.view(1)[0] = save_tstate;
        }
        return interp;
    }  def _PyXI_EndInterpreter(
        interp: ptr[u8],
        tstate: ptr[PyThreadState],
        p_save_tstate: ptr[ptr[PyThreadState]]
    ) {
        if _PyInterpreterState_IsReady(interp) == 0 {
            PyInterpreterState_Delete(interp);
            return;
        }
        save_tstate = ptr[PyThreadState]();
        cur_tstate = thread_state();
        target = tstate;
        if not target {
            if ptr[u8](PyThreadState_GetInterpreter(cur_tstate)) == interp {
                target = cur_tstate;
            } else {
                target = _PyThreadState_NewBound(interp, TSTATE_WHENCE_FINI);
                save_tstate = PyThreadState_Swap(target);
            }
        } elif target != cur_tstate {
            save_tstate = PyThreadState_Swap(target);
        }
        Py_EndInterpreter(target);
        if p_save_tstate {
            save_tstate = p_save_tstate.view(1)[0];
        }
        PyThreadState_Swap(save_tstate);
    }
}

def status_ok -> PyStatus;

def status_error(func: ptr[u8], msg: ptr[u8]) -> PyStatus;

def xid_lookup_init(state: ptr[u8]);

def xid_lookup_fini(state: ptr[u8]);

def get_lookup_context(tstate: ptr[PyThreadState]) -> tuple[i32, ptr[u8], ptr[u8]];

def lookup_getdata(
    global_lookup: ptr[u8], local_lookup: ptr[u8], obj_: ptr[PyObject]
) -> tuple[int, int];

import from c {
    def _PyXIData_GetNotShareableErrorType(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyObject] {
        return get_notshareableerror_type(tstate);
    }  def _PyXIData_SetNotShareableError(tstate: ptr[PyThreadState], msg: ptr[u8]) {
        set_notshareableerror(tstate, NULL, 1, msg);
    }  def _PyXIData_FormatNotShareableError(
        tstate: ptr[PyThreadState], format: ptr[u8], *vargs: VaList
    ) {
        msgobj = PyUnicode_FromFormatV(format, vargs);
        notshareableerror_from_message(tstate, NULL, 1, msgobj);
    }  def _PyXI_UnwrapNotShareableError(
        tstate: ptr[PyThreadState], failure: ptr[_PyXI_failure]
    ) -> i32 {
        exctype = get_notshareableerror_type(tstate);
        if _PyErr_ExceptionMatches(tstate, exctype) == 0 {
            return -1;
        }
        exc = _PyErr_GetRaisedException(tstate);
        if failure {
            if _PyXI_InitFailure(failure, XI_ERR_NOT_SHAREABLE, exc) < 0 {
                return -1;
            }
        }
        cause = PyException_GetCause(exc);
        if cause {
            object_decref(exc);
            exc = cause;
        }
        _PyErr_SetRaisedException(tstate, exc);
        return 0;
    }  def _PyXIData_Lookup(
        tstate: ptr[PyThreadState], obj_: ptr[PyObject]
    ) -> _PyXIData_getdata_t {
        getdata = _PyXIData_getdata_t();
        (status, global_lookup, local_lookup) = get_lookup_context(tstate);
        if status < 0 {
            return getdata;
        }
        (basic, fallback) = lookup_getdata(global_lookup, local_lookup, obj_);
        getdata.basic = basic;
        getdata.fallback = fallback;
        return getdata;
    }  def _PyXIData_RegisterClass(
        tstate: ptr[PyThreadState], cls: ptr[PyTypeObject], getdata: _PyXIData_getdata_t
    ) -> i32 {
        if not type_check(ptr[PyObject](cls)) {
            PyErr_Format(PyExc_ValueError, ptr[u8]("only classes may be registered"));
            return -1;
        }
        basic = int(getdata.basic);
        fallback = int(getdata.fallback);
        if basic == 0 and fallback == 0 {
            PyErr_Format(PyExc_ValueError, ptr[u8]("missing 'getdata' func"));
            return -1;
        }
        res: i32 = 0;
        (status, global_lookup, local_lookup) = get_lookup_context(tstate);
        if status < 0 {
            return -1;
        }
        xidregistry = _get_xidregistry_for_type(global_lookup, local_lookup, cls);
        _xidregistry_lock(xidregistry);
        matched = _xidregistry_find_type(xidregistry, cls);
        if matched {
            matched.view(1)[0].refcount += 1;
        } else {
            res = _xidregistry_add_type(xidregistry, cls, basic, fallback);
        }
        _xidregistry_unlock(xidregistry);
        return res;
    }  def _PyXIData_UnregisterClass(
        tstate: ptr[PyThreadState], cls: ptr[PyTypeObject]
    ) -> i32 {
        res: i32 = 0;
        (status, global_lookup, local_lookup) = get_lookup_context(tstate);
        if status < 0 {
            return -1;
        }
        xidregistry = _get_xidregistry_for_type(global_lookup, local_lookup, cls);
        _xidregistry_lock(xidregistry);
        matched = _xidregistry_find_type(xidregistry, cls);
        if matched {
            matched.view(1)[0].refcount -= 1;
            if matched.view(1)[0].refcount == 0 {
                _xidregistry_remove_entry(xidregistry, matched);
            }
            res = 1;
        }
        _xidregistry_unlock(xidregistry);
        return res;
    }  def _PyBytes_GetData(obj_: ptr[PyObject], data: ptr[_PyBytes_data_t]) -> i32 {
        if not bytes_check(obj_) {
            PyErr_Format(PyExc_TypeError, ptr[u8]("expected bytes, got %R"), obj_);
            return -1;
        }
        bytes_ptr = ptr[u8]();
        len: i64 = 0;
        if PyBytes_AsStringAndSize(obj_, &mut bytes_ptr, &mut len) < 0 {
            return -1;
        }
        data.view(1)[0].bytes = bytes_ptr;
        data.view(1)[0].len = len;
        return 0;
    }  def _PyBytes_FromData(data: ptr[_PyBytes_data_t]) -> ptr[PyObject] {
        return PyBytes_FromStringAndSize(data.view(1)[0].bytes, data.view(1)[0].len);
    }  def _PyBytes_FromXIData(xidata: ptr[_PyXIData_t]) -> ptr[PyObject] {
        return _PyBytes_FromData(ptr[_PyBytes_data_t](xidata.view(1)[0].data));
    }  def _PyBytes_GetXIData(
        tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
    ) -> i32 {
        if not bytes_check(obj_) {
            PyErr_Format(PyExc_TypeError, ptr[u8]("expected bytes, got %R"), obj_);
            return -1;
        }
        return _bytes_shared(
            tstate, obj_, BYTES_DATA_SIZE, ptr(_PyBytes_FromXIData), xidata
        );
    }  def _PyBytes_GetXIDataWrapped(
        tstate: ptr[PyThreadState],
        obj_: ptr[PyObject],
        size: u64,
        newfunc: ptr,
        xidata: ptr[_PyXIData_t]
    ) -> ptr[_PyBytes_data_t] {
        if not bytes_check(obj_) {
            PyErr_Format(PyExc_TypeError, ptr[u8]("expected bytes, got %R"), obj_);
            return ptr[_PyBytes_data_t]();
        }
        if size < BYTES_DATA_SIZE {
            expected = i64(BYTES_DATA_SIZE);
            got = i64(size);
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8]("expected size >= %zu, got %zu"),
                expected,
                got
            );
            return ptr[_PyBytes_data_t]();
        }
        func = newfunc;
        if not func {
            if size == BYTES_DATA_SIZE {
                PyErr_SetString(PyExc_ValueError, ptr[u8]("missing new_object func"));
                return ptr[_PyBytes_data_t]();
            }
            func = ptr(_PyBytes_FromXIData);
        }
        if _bytes_shared(tstate, obj_, size, func, xidata) < 0 {
            return ptr[_PyBytes_data_t]();
        }
        return ptr[_PyBytes_data_t](xidata.view(1)[0].data);
    }  def _PyCode_FromXIData(xidata: ptr[_PyXIData_t]) -> ptr[PyObject] {
        return _PyMarshal_ReadObjectFromXIData(xidata);
    }  def _PyCode_GetXIData(
        tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
    ) -> i32 {
        if not code_check(obj_) {
            msgobj = PyUnicode_FromFormat("expected code, got %R", obj_);
            notshareableerror_from_message(tstate, NULL, 1, msgobj);
            return -1;
        }
        if _PyMarshal_GetXIData(tstate, obj_, xidata) < 0 {
            return -1;
        }
        xidata.view(1)[0].new_object = int(ptr(_PyCode_FromXIData));
        return 0;
    }  def _PyFunction_FromXIData(xidata: ptr[_PyXIData_t]) -> ptr[PyObject] {
        code = _PyMarshal_ReadObjectFromXIData(xidata);
        if not code {
            return NULL;
        }
        tstate = thread_state();
        globals = _PyEval_GetGlobalsFromRunningMain(tstate);
        if not globals {
            if PyErr_Occurred() {
                object_decref(code);
                return NULL;
            }
            globals = PyDict_New();
            if not globals {
                object_decref(code);
                return NULL;
            }
        } else {
            object_incref(globals);
        }
        if _PyEval_EnsureBuiltins(tstate, globals, ptr[ptr[PyObject]]()) < 0 {
            object_decref(code);
            object_decref(globals);
            return NULL;
        }
        func = PyFunction_New(code, globals);
        object_decref(code);
        object_decref(globals);
        return func;
    }  def _PyFunction_GetXIData(
        tstate: ptr[PyThreadState], func: ptr[PyObject], xidata: ptr[_PyXIData_t]
    ) -> i32 {
        if not function_check(func) {
            msgobj = PyUnicode_FromFormat("expected a function, got %R", func);
            notshareableerror_from_message(tstate, NULL, 0, msgobj);
            return -1;
        }
        if _PyFunction_VerifyStateless(ptr(tstate), func) < 0 {
            cause = _PyErr_GetRaisedException(tstate);
            set_notshareableerror(
                tstate, cause, 0, ptr[u8]("only stateless functions are shareable")
            );
            object_decref(cause);
            return -1;
        }
        code = function_code(func);
        if _PyMarshal_GetXIData(tstate, code, xidata) < 0 {
            return -1;
        }
        xidata.view(1)[0].new_object = int(ptr(_PyFunction_FromXIData));
        return 0;
    }
}

def _xidregistry_init(registry: ptr[_PyXIData_registry_t]);

def _xidregistry_fini(registry: ptr[_PyXIData_registry_t]);

def _xidregistry_lock(registry: ptr[_PyXIData_registry_t]);

def _xidregistry_unlock(registry: ptr[_PyXIData_registry_t]);

def _get_xidregistry_for_type(
    global_lookup: ptr[u8], local_lookup: ptr[u8], cls: ptr[PyTypeObject]
) -> ptr[_PyXIData_registry_t];

def _xidregistry_find_type(
    xidregistry: ptr[_PyXIData_registry_t], cls: ptr[PyTypeObject]
) -> ptr[_PyXIData_regitem_t];

def _lookup_getdata_from_registry(
    global_lookup: ptr[u8], local_lookup: ptr[u8], obj_: ptr[PyObject]
) -> tuple[int, int];

def _xidregistry_add_type(
    xidregistry: ptr[_PyXIData_registry_t],
    cls: ptr[PyTypeObject],
    basic: int,
    fallback: int
) -> i32;

def _xidregistry_remove_entry(
    xidregistry: ptr[_PyXIData_registry_t], regitem: ptr[_PyXIData_regitem_t]
) -> ptr[_PyXIData_regitem_t];

def _xidregistry_clear(xidregistry: ptr[_PyXIData_registry_t]);

def _bytes_shared(
    tstate: ptr[PyThreadState],
    obj_: ptr[PyObject],
    size: u64,
    newfunc: ptr,
    xidata: ptr[_PyXIData_t]
) -> i32;

def _new_str_object(xidata: ptr[_PyXIData_t]) -> ptr[PyObject];

def _str_shared(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
) -> i32;

def _new_long_object(xidata: ptr[_PyXIData_t]) -> ptr[PyObject];

def _long_shared(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
) -> i32;

def _new_float_object(xidata: ptr[_PyXIData_t]) -> ptr[PyObject];

def _float_shared(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
) -> i32;

def _new_none_object(xidata: ptr[_PyXIData_t]) -> ptr[PyObject];

def _none_shared(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
) -> i32;

def _new_bool_object(xidata: ptr[_PyXIData_t]) -> ptr[PyObject];

def _bool_shared(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
) -> i32;

def _new_tuple_object(xidata: ptr[_PyXIData_t]) -> ptr[PyObject];

def _tuple_shared_free(data: ptr);

def _tuple_shared(
    tstate: ptr[PyThreadState],
    obj_: ptr[PyObject],
    fallback: i32,
    xidata: ptr[_PyXIData_t]
) -> i32;

def register_builtin(
    xidregistry: ptr[_PyXIData_registry_t],
    type: ptr[PyTypeObject],
    basic: int,
    fallback: int
) -> i32;

def _register_builtins_for_crossinterpreter_data(
    xidregistry: ptr[_PyXIData_registry_t]
);

impl tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[0];
}

impl xi_state(interp: ptr[u8]) -> ptr[u8] {
    return interp + PyInterpreterState_XI;
}

impl xi_global_state(interp: ptr[u8]) -> ptr[u8] {
    runtime = ptr[ptr[u8]](interp + PyInterpreterState_RUNTIME).view(1)[0];
    return runtime + _PyRuntimeState_XI;
}

impl xi_exc_slot(state: ptr[u8], offset: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](state + offset);
}

impl scratch_of(slots: ptr) -> ptr[u8] {
    return ptr[u8](slots);
}

impl excinfo_type(info: ptr[_PyXI_excinfo]) -> ptr[_PyXI_excinfo_type] {
    return ptr[_PyXI_excinfo_type](info);
}

impl error_override_storage(err: ptr[_PyXI_error]) -> ptr[_PyXI_failure] {
    return ptr[_PyXI_failure](ptr[u8](err) + XI_ERROR_OVERRIDE);
}

impl error_uncaught(err: ptr[_PyXI_error]) -> ptr[_PyXI_excinfo] {
    return ptr[_PyXI_excinfo](ptr[u8](err) + XI_ERROR_UNCAUGHT);
}

impl unpickle_main(ctx: ptr[unpickle_context]) -> ptr[sync_module] {
    return ptr[sync_module](ptr[u8](ctx) + UNPICKLE_CONTEXT_MAIN);
}

impl ns_item(ns: ptr[_PyXI_namespace], i: i64) -> ptr[_PyXI_namespace_item] {
    return ptr[_PyXI_namespace_item](
        ptr[u8](ns) + NAMESPACE_ITEMS + i * NAMESPACE_ITEM_SIZE
    );
}

impl registry_mutex(registry: ptr[_PyXIData_registry_t]) -> ptr[PyMutex] {
    return ptr[PyMutex](ptr[u8](registry) + _PyXIData_registry_t_MUTEX);
}

impl function_code(func: ptr[PyObject]) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](ptr[u8](func) + PyFunctionObject_CODE).view(1)[0];
}

impl code_int(co: ptr[PyObject], offset: i64) -> i32 {
    return ptr[i32](ptr[u8](co) + offset).view(1)[0];
}

impl shared_pickle_data_size -> u64 {
    return u64((SHARED_PICKLE_CTX + PICKLE_CTX_BUFFER + MAXPATHLEN + 1 + 7) // 8 * 8);
}

impl call_simple_func(func: ptr, arg: ptr) -> i32 {
    slots: own XIStack = XIStack();
    calls = ptr[XICall](jacpy_stack_address(&mut slots));
    calls.view(1)[0].simple = int(func);
    return calls.view(1)[0].simple(arg);
}

impl _Py_GetMainfile(buffer: ptr[u8], maxlen: u64) -> i64 {
    tstate = thread_state();
    module = _Py_GetMainModule(tstate);
    if _Py_CheckMainModule(module) < 0 {
        object_xdecref(module);
        return -1;
    }
    size = _PyModule_GetFilenameUTF8(module, buffer, i64(maxlen));
    object_decref(module);
    return size;
}

impl runpy_run_path(filename: ptr[u8], modname: ptr[u8]) -> ptr[PyObject] {
    run_path = PyImport_ImportModuleAttrString("runpy", "run_path");
    if not run_path {
        return NULL;
    }
    args = Py_BuildValue(ptr[u8]("(sOs)"), filename, Py_None, modname);
    if not args {
        object_decref(run_path);
        return NULL;
    }
    ns = PyObject_Call(run_path, args, NULL);
    object_decref(run_path);
    object_decref(args);
    return ns;
}

impl set_exc_with_cause(exctype: ptr[PyObject], msg: ptr[u8]) {
    cause = PyErr_GetRaisedException();
    PyErr_SetString(exctype, msg);
    exc = PyErr_GetRaisedException();
    PyException_SetCause(exc, cause);
    PyErr_SetRaisedException(exc);
}

impl sync_module_clear(data: ptr[sync_module]) {
    data.view(1)[0].filename = ptr[u8]();
    old = data.view(1)[0].module;
    data.view(1)[0].module = NULL;
    object_xdecref(old);
    old = data.view(1)[0].loaded;
    data.view(1)[0].loaded = NULL;
    object_xdecref(old);
    old = data.view(1)[0].failed;
    data.view(1)[0].failed = NULL;
    object_xdecref(old);
}

impl sync_module_capture_exc(tstate: ptr[PyThreadState], data: ptr[sync_module]) {
    context = data.view(1)[0].failed;
    exc = _PyErr_GetRaisedException(tstate);
    _PyErr_SetRaisedException(tstate, object_new_ref(exc));
    if context {
        PyException_SetContext(exc, context);
    }
    data.view(1)[0].failed = exc;
}

impl ensure_isolated_main_error(
    tstate: ptr[PyThreadState],
    main: ptr[sync_module],
    loaded: ptr[PyObject],
    mod: ptr[PyObject],
    key: ptr[PyObject]
) -> i32 {
    sync_module_capture_exc(tstate, main);
    object_xdecref(loaded);
    object_decref(mod);
    object_xdecref(key);
    return -1;
}

impl ensure_isolated_main(tstate: ptr[PyThreadState], main: ptr[sync_module]) -> i32 {
    if main.view(1)[0].failed {
        return 0;
    } elif main.view(1)[0].loaded {
        return 0;
    }
    if not main.view(1)[0].filename {
        _PyErr_SetString(tstate, PyExc_NotImplementedError, ptr[u8](""));
        return -1;
    }
    mod = _Py_GetMainModule(tstate);
    if _Py_CheckMainModule(mod) < 0 {
        object_xdecref(mod);
        return -1;
    }
    loaded = NULL;
    interpns = PyInterpreterState_GetDict(
        ptr[PyInterpreterState](tstate_interp(tstate))
    );
    key = PyUnicode_FromString(ptr[u8]("CACHED_MODULE_NS___main__"));
    if not key {
        object_decref(mod);
        return -1;
    } elif PyDict_GetItemRef(interpns, key, &mut loaded) < 0 {
        object_decref(mod);
        object_decref(key);
        return -1;
    } elif not loaded {
        loaded = PyModule_NewObject(py_id(_Py_ID___main__));
        if not loaded {
            return ensure_isolated_main_error(tstate, main, loaded, mod, key);
        }
        ns = PyModule_GetDict(loaded);
        loaded_ns = runpy_run_path(
            main.view(1)[0].filename, ptr[u8]("<fake __main__>")
        );
        if not loaded_ns {
            return ensure_isolated_main_error(tstate, main, loaded, mod, key);
        }
        res = PyDict_Update(ns, loaded_ns);
        object_decref(loaded_ns);
        if res < 0 {
            return ensure_isolated_main_error(tstate, main, loaded, mod, key);
        }
        if PyDict_SetItem(interpns, key, loaded) < 0 {
            return ensure_isolated_main_error(tstate, main, loaded, mod, key);
        }
    }
    object_decref(key);
    main.view(1)[0].module = mod;
    main.view(1)[0].loaded = loaded;
    main.view(1)[0].failed = NULL;
    return 0;
}

impl apply_isolated_main(tstate: ptr[PyThreadState], main: ptr[sync_module]) -> i32 {
    if main.view(1)[0].failed {
        _PyErr_SetRaisedException(tstate, main.view(1)[0].failed);
        return -1;
    }
    if _PyImport_SetModule(py_id(_Py_ID___main__), main.view(1)[0].loaded) < 0 {
        sync_module_capture_exc(tstate, main);
        return -1;
    }
    return 0;
}

impl restore_main(tstate: ptr[PyThreadState], main: ptr[sync_module]) {
    exc = _PyErr_GetRaisedException(tstate);
    res = _PyImport_SetModule(py_id(_Py_ID___main__), main.view(1)[0].module);
    if res < 0 {
        PyErr_FormatUnraisable(ptr[u8]("Exception ignored while restoring __main__"));
    }
    _PyErr_SetRaisedException(tstate, exc);
}

impl _ensure_current_cause(tstate: ptr[PyThreadState], cause: ptr[PyObject]) {
    if not cause {
        return;
    }
    exc = _PyErr_GetRaisedException(tstate);
    PyException_SetCause(exc, object_new_ref(cause));
    _PyErr_SetRaisedException(tstate, exc);
}

impl _init_notshareableerror(state: ptr[u8]) -> i32 {
    exctype = PyErr_NewException(
        ptr[u8]("concurrent.interpreters.NotShareableError"), PyExc_TypeError, NULL
    );
    if not exctype {
        return -1;
    }
    xi_exc_slot(state, _PyXI_state_t_EXC_NOT_SHAREABLE_ERROR).view(1)[0] = exctype;
    return 0;
}

impl _fini_notshareableerror(state: ptr[u8]) {
    slot = xi_exc_slot(state, _PyXI_state_t_EXC_NOT_SHAREABLE_ERROR);
    old = slot.view(1)[0];
    slot.view(1)[0] = NULL;
    object_xdecref(old);
}

impl get_notshareableerror_type(tstate: ptr[PyThreadState]) -> ptr[PyObject] {
    local = xi_state(tstate_interp(tstate));
    if not local {
        PyErr_Clear();
        return NULL;
    }
    return xi_exc_slot(local, _PyXI_state_t_EXC_NOT_SHAREABLE_ERROR).view(1)[0];
}

impl _ensure_notshareableerror(
    tstate: ptr[PyThreadState], cause: ptr[PyObject], force: i32, msgobj: ptr[PyObject]
) {
    ctx = _PyErr_GetRaisedException(tstate);
    exctype = get_notshareableerror_type(tstate);
    if exctype {
        if force == 0 and ctx and ptr[PyObject](object_type(ctx)) == exctype {
            _PyErr_SetRaisedException(tstate, ctx);
        }
    } else {
        exctype = PyExc_TypeError;
    }
    _PyErr_SetObject(tstate, exctype, msgobj);
    _PyErr_ChainExceptions1Tstate(tstate, ctx);
    _ensure_current_cause(tstate, cause);
}

impl set_notshareableerror(
    tstate: ptr[PyThreadState], cause: ptr[PyObject], force: i32, msg: ptr[u8]
) {
    msgobj = PyUnicode_FromString(msg);
    if msgobj {
        _ensure_notshareableerror(tstate, cause, force, msgobj);
        object_decref(msgobj);
    }
}

impl notshareableerror_from_message(
    tstate: ptr[PyThreadState], cause: ptr[PyObject], force: i32, msgobj: ptr[PyObject]
) {
    if msgobj {
        _ensure_notshareableerror(tstate, cause, force, msgobj);
        object_decref(msgobj);
    }
}

impl fini_static_exctypes(state: ptr[u8], interp: ptr[u8]) {
    not_found = xi_exc_slot(state, _PyXI_state_t_EXC_INTERPRETER_NOT_FOUND_ERROR);
    if not_found.view(1)[0] {
        not_found.view(1)[0] = NULL;
        _PyStaticType_FiniBuiltin(interp, addressof(_PyExc_InterpreterNotFoundError));
    }
    interp_error = xi_exc_slot(state, _PyXI_state_t_EXC_INTERPRETER_ERROR);
    if interp_error.view(1)[0] {
        interp_error.view(1)[0] = NULL;
        _PyStaticType_FiniBuiltin(interp, addressof(_PyExc_InterpreterError));
    }
}

impl init_static_exctypes(state: ptr[u8], interp: ptr[u8]) -> i32 {
    base = ptr[PyTypeObject](PyExc_Exception);
    interp_error = addressof(_PyExc_InterpreterError);
    interp_error.view(1)[0].tp_base = base;
    interp_error.view(1)[0].tp_traverse = base.view(1)[0].tp_traverse;
    interp_error.view(1)[0].tp_clear = base.view(1)[0].tp_clear;
    if _PyStaticType_InitBuiltin(interp, interp_error) < 0 {
        fini_static_exctypes(state, interp);
        return -1;
    }
    xi_exc_slot(state, _PyXI_state_t_EXC_INTERPRETER_ERROR).view(1)[0] = ptr[PyObject](
        interp_error
    );
    not_found = addressof(_PyExc_InterpreterNotFoundError);
    not_found.view(1)[0].tp_traverse = base.view(1)[0].tp_traverse;
    not_found.view(1)[0].tp_clear = base.view(1)[0].tp_clear;
    if _PyStaticType_InitBuiltin(interp, not_found) < 0 {
        fini_static_exctypes(state, interp);
        return -1;
    }
    xi_exc_slot(state, _PyXI_state_t_EXC_INTERPRETER_NOT_FOUND_ERROR).view(1)[0] = ptr[
        PyObject
    ](
        not_found
    );
    return 0;
}

impl fini_heap_exctypes(state: ptr[u8]) {
    _fini_notshareableerror(state);
}

impl init_heap_exctypes(state: ptr[u8]) -> i32 {
    if _init_notshareableerror(state) < 0 {
        fini_heap_exctypes(state);
        return -1;
    }
    return 0;
}

impl _xidata_init(xidata: ptr[_PyXIData_t]) {
    xidata.view(1)[0].data = ptr();
    xidata.view(1)[0].obj_ = NULL;
    xidata.view(1)[0].new_object = 0;
    xidata.view(1)[0].free = 0;
    xidata.view(1)[0].interpid = -1;
}

impl _xidata_clear(xidata: ptr[_PyXIData_t]) {
    if xidata.view(1)[0].data {
        if int(xidata.view(1)[0].free) != 0 {
            xidata.view(1)[0].free(xidata.view(1)[0].data);
        }
        xidata.view(1)[0].data = ptr();
    }
    old = xidata.view(1)[0].obj_;
    xidata.view(1)[0].obj_ = NULL;
    object_xdecref(old);
}

impl _set_xid_lookup_failure(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], msg: ptr[u8], cause: ptr[PyObject]
) {
    if msg {
        set_notshareableerror(tstate, cause, 0, msg);
    } elif not obj_ {
        set_notshareableerror(
            tstate, cause, 0, ptr[u8]("object does not support cross-interpreter data")
        );
    } else {
        msgobj = PyUnicode_FromFormat(
            "%R does not support cross-interpreter data", obj_
        );
        notshareableerror_from_message(tstate, cause, 0, msgobj);
    }
}

impl _check_xidata(tstate: ptr[PyThreadState], xidata: ptr[_PyXIData_t]) -> i32 {
    if xidata.view(1)[0].interpid < 0 {
        PyErr_SetString(PyExc_SystemError, ptr[u8]("missing interp"));
        return -1;
    }
    if int(xidata.view(1)[0].new_object) == 0 {
        PyErr_SetString(PyExc_SystemError, ptr[u8]("missing new_object func"));
        return -1;
    }
    return 0;
}

impl call_getdata(
    basic: int,
    fallback_fn: int,
    tstate: ptr[PyThreadState],
    obj_: ptr[PyObject],
    fallback: i32,
    xidata: ptr[_PyXIData_t]
) -> i32 {
    slots: own XIStack = XIStack();
    getdata = ptr[_PyXIData_getdata_t](jacpy_stack_address(&mut slots));
    if basic != 0 {
        getdata.view(1)[0].basic = basic;
        return getdata.view(1)[0].basic(tstate, obj_, xidata);
    }
    getdata.view(1)[0].fallback = fallback_fn;
    return getdata.view(1)[0].fallback(tstate, obj_, fallback, xidata);
}

impl _get_xidata(
    tstate: ptr[PyThreadState],
    obj_: ptr[PyObject],
    fallback: i32,
    xidata: ptr[_PyXIData_t]
) -> i32 {
    interp = tstate_interp(tstate);
    if xidata.view(1)[0].data or xidata.view(1)[0].obj_ {
        _PyErr_SetString(tstate, PyExc_ValueError, ptr[u8]("xidata not cleared"));
        return -1;
    }
    (status, global_lookup, local_lookup) = get_lookup_context(tstate);
    if status < 0 {
        return -1;
    }
    object_incref(obj_);
    (basic, fallback_fn) = lookup_getdata(global_lookup, local_lookup, obj_);
    if basic == 0 and fallback_fn == 0 {
        if PyErr_Occurred() {
            object_decref(obj_);
            return -1;
        }
        object_decref(obj_);
        if not PyErr_Occurred() {
            _set_xid_lookup_failure(tstate, obj_, ptr[u8](), NULL);
        }
        return -1;
    }
    res = call_getdata(basic, fallback_fn, tstate, obj_, fallback, xidata);
    object_decref(obj_);
    if res != 0 {
        cause = _PyErr_GetRaisedException(tstate);
        _set_xid_lookup_failure(tstate, obj_, ptr[u8](), cause);
        object_xdecref(cause);
        return -1;
    }
    xidata.view(1)[0].interpid = PyInterpreterState_GetID(interp);
    if _check_xidata(tstate, xidata) != 0 {
        _PyXIData_Release(xidata);
        return -1;
    }
    return 0;
}

impl _PyPickle_Dumps(tstate: ptr[PyThreadState], obj_: ptr[PyObject]) -> ptr[PyObject] {
    dumps = PyImport_ImportModuleAttrString("pickle", "dumps");
    if not dumps {
        return NULL;
    }
    bytes_obj = PyObject_CallOneArg(dumps, obj_);
    object_decref(dumps);
    return bytes_obj;
}

impl _unpickle_context_clear(ctx: ptr[unpickle_context]) {
    sync_module_clear(unpickle_main(ctx));
}

impl check_missing___main___attr(exc: ptr[PyObject]) -> i32 {
    if PyErr_GivenExceptionMatches(exc, PyExc_AttributeError) == 0 {
        return 0;
    }
    args = PyException_GetArgs(exc);
    if not args or args == Py_None or PyObject_Size(args) < 1 {
        object_xdecref(args);
        return 0;
    }
    msgobj = args;
    if not unicode_check(msgobj) {
        msgobj = PySequence_GetItem(args, 0);
        object_decref(args);
        if not msgobj {
            PyErr_Clear();
            return 0;
        }
    }
    err = PyUnicode_AsUTF8(msgobj);
    cmp = strncmp(err, ptr[u8]("module '__main__' has no attribute '"), 36);
    object_decref(msgobj);
    if cmp == 0 {
        return 1;
    }
    return 0;
}

impl _PyPickle_Loads(
    ctx: ptr[unpickle_context], pickled: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = ctx.view(1)[0].tstate;
    exc = NULL;
    loads = PyImport_ImportModuleAttrString("pickle", "loads");
    if not loads {
        return NULL;
    }
    obj_ = PyObject_CallOneArg(loads, pickled);
    if not obj_ and ctx {
        exc = _PyErr_GetRaisedException(tstate);
        if check_missing___main___attr(exc) != 0 {
            main = unpickle_main(ctx);
            if ensure_isolated_main(tstate, main) >= 0
                and apply_isolated_main(tstate, main) >= 0 {
                obj_ = PyObject_CallOneArg(loads, pickled);
                restore_main(tstate, main);
                if obj_ {
                    old = exc;
                    exc = NULL;
                    object_decref(old);
                }
            }
        }
    }
    if exc {
        if PyErr_Occurred() {
            sync_module_capture_exc(tstate, unpickle_main(ctx));
        }
        _PyErr_SetRaisedException(tstate, exc);
    }
    object_decref(loads);
    return obj_;
}

impl _set_pickle_xid_context(tstate: ptr[PyThreadState], ctx: ptr[u8]) -> i32 {
    buffer = ctx + PICKLE_CTX_BUFFER;
    len = _Py_GetMainfile(buffer, u64(MAXPATHLEN));
    if len < 0 {
        PyErr_Clear();
    } elif len > 0 {
        ptr[ptr[u8]](ctx + PICKLE_CTX_UTF8).view(1)[0] = buffer;
        ptr[u64](ctx + PICKLE_CTX_LEN).view(1)[0] = u64(len);
    }
    return 0;
}

impl verify_script(
    tstate: ptr[PyThreadState], co: ptr[PyObject], checked: i32, pure: i32
) -> i32 {
    builtins = NULL;
    if pure != 0 {
        builtins = _PyEval_GetBuiltins(tstate);
    }
    if checked == 0 {
        if _PyCode_VerifyStateless(ptr(tstate), co, NULL, NULL, builtins) < 0 {
            return -1;
        }
    }
    if code_int(co, PyCodeObject_ARGCOUNT) > 0
        or code_int(co, PyCodeObject_POSONLYARGCOUNT) > 0
        or code_int(co, PyCodeObject_KWONLYARGCOUNT) > 0
        or (code_int(co, PyCodeObject_FLAGS) & (CO_VARARGS | CO_VARKEYWORDS)) != 0 {
        _PyErr_SetString(
            tstate, PyExc_ValueError, ptr[u8]("code with args not supported")
        );
        return -1;
    }
    if _PyCode_ReturnsOnlyNone(co) == 0 {
        _PyErr_SetString(
            tstate,
            PyExc_ValueError,
            ptr[u8]("code that returns a value is not a script")
        );
        return -1;
    }
    return 0;
}

impl get_script_xidata_error(tstate: ptr[PyThreadState], code: ptr[PyObject]) -> i32 {
    object_xdecref(code);
    cause = _PyErr_GetRaisedException(tstate);
    _set_xid_lookup_failure(tstate, NULL, ptr[u8]("object not a valid script"), cause);
    object_decref(cause);
    return -1;
}

impl get_script_xidata(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], pure: i32, xidata: ptr[_PyXIData_t]
) -> i32 {
    code = NULL;
    checked: i32 = 0;
    if code_check(obj_) {
        code = obj_;
        object_incref(code);
    } elif function_check(obj_) {
        code = function_code(obj_);
        object_incref(code);
        if pure != 0 {
            if _PyFunction_VerifyStateless(ptr(tstate), obj_) < 0 {
                return get_script_xidata_error(tstate, code);
            }
            checked = 1;
        }
    } else {
        filename = ptr[u8]("<script>");
        optimize: i32 = 0;
        slots: own XIStack = XIStack();
        cf = ptr[CompilerFlags](jacpy_stack_address(&mut slots));
        cf.view(1)[0].cf_flags = PyCF_SOURCE_IS_UTF8;
        cf.view(1)[0].cf_feature_version = PY_MINOR_VERSION;
        ref_ = NULL;
        script = _Py_SourceAsString(
            obj_, ptr[u8]("???"), ptr[u8]("???"), ptr[PyCompilerFlags](cf), &mut ref_
        );
        if not script {
            if _PyObject_SupportedAsScript(obj_) == 0 {
                _PyErr_Format(
                    tstate, PyExc_TypeError, ptr[u8]("unsupported script %R"), obj_
                );
            }
            return get_script_xidata_error(tstate, code);
        }
        code = Py_CompileStringExFlags(
            script, filename, Py_file_input, ptr[PyCompilerFlags](cf), optimize
        );
        object_xdecref(ref_);
        if not code {
            return get_script_xidata_error(tstate, code);
        }
        if pure == 0 {
            checked = 1;
        }
    }
    if verify_script(tstate, code, checked, pure) < 0 {
        return get_script_xidata_error(tstate, code);
    }
    res = _PyCode_GetXIData(tstate, code, xidata);
    object_decref(code);
    if res < 0 {
        return -1;
    }
    return 0;
}

impl _call_clear_xidata(data: ptr) -> i32 {
    _xidata_clear(ptr[_PyXIData_t](data));
    return 0;
}

impl _xidata_release(xidata: ptr[_PyXIData_t], rawfree: i32) -> i32 {
    if (not xidata.view(1)[0].data or int(xidata.view(1)[0].free) == 0)
        and not xidata.view(1)[0].obj_ {
        if rawfree != 0 {
            PyMem_RawFree(xidata);
        } else {
            xidata.view(1)[0].data = ptr();
        }
        return 0;
    }
    interp = _PyInterpreterState_LookUpID(xidata.view(1)[0].interpid);
    if not interp {
        if rawfree != 0 {
            PyMem_RawFree(xidata);
        }
        return -1;
    }
    if rawfree != 0 {
        return _Py_CallInInterpreterAndRawFree(
            interp, ptr(_call_clear_xidata), ptr(xidata)
        );
    }
    return _Py_CallInInterpreter(interp, ptr(_call_clear_xidata), ptr(xidata));
}

impl _copy_string_obj_raw(strobj: ptr[PyObject]) -> tuple[ptr[u8], i64] {
    size: i64 = -1;
    text = PyUnicode_AsUTF8AndSize(strobj, &mut size);
    if not text {
        return (ptr[u8](), size);
    }
    if size != i64(strlen(text)) {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("found embedded NULL character"));
        return (ptr[u8](), size);
    }
    copied = ptr[u8](PyMem_RawMalloc(u64(size + 1)));
    if not copied {
        PyErr_NoMemory();
        return (ptr[u8](), size);
    }
    strcpy(copied, text);
    return (copied, size);
}

impl _convert_exc_to_TracebackException_error(
    args: ptr[PyObject], kwargs: ptr[PyObject], create: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    object_xdecref(args);
    object_xdecref(kwargs);
    object_xdecref(create);
    return (i32(-1), NULL);
}

impl _convert_exc_to_TracebackException(
    exc: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    args = NULL;
    kwargs = NULL;
    create = NULL;
    tbexc_type = PyImport_ImportModuleAttrString("traceback", "TracebackException");
    if not tbexc_type {
        return (i32(-1), NULL);
    }
    create = PyObject_GetAttrString(tbexc_type, ptr[u8]("from_exception"));
    object_decref(tbexc_type);
    if not create {
        return (i32(-1), NULL);
    }
    args = PyTuple_Pack(1, exc);
    if not args {
        return _convert_exc_to_TracebackException_error(args, kwargs, create);
    }
    kwargs = PyDict_New();
    if not kwargs {
        return _convert_exc_to_TracebackException_error(args, kwargs, create);
    }
    false_obj = ptr[PyObject](addressof(_Py_FalseStruct));
    if PyDict_SetItemString(kwargs, ptr[u8]("save_exc_type"), false_obj) < 0 {
        return _convert_exc_to_TracebackException_error(args, kwargs, create);
    }
    if PyDict_SetItemString(kwargs, ptr[u8]("lookup_lines"), false_obj) < 0 {
        return _convert_exc_to_TracebackException_error(args, kwargs, create);
    }
    tbexc = PyObject_Call(create, args, kwargs);
    object_decref(args);
    object_decref(kwargs);
    object_decref(create);
    if not tbexc {
        return _convert_exc_to_TracebackException_error(args, kwargs, create);
    }
    return (i32(0), tbexc);
}

impl _format_TracebackException(tbexc: ptr[PyObject]) -> ptr[u8] {
    format_method = PyObject_GetAttrString(tbexc, ptr[u8]("format"));
    if not format_method {
        return ptr[u8]();
    }
    lines = PyObject_CallNoArgs(format_method);
    object_decref(format_method);
    if not lines {
        return ptr[u8]();
    }
    formatted_obj = PyUnicode_Join(unicode_get_empty(), lines);
    object_decref(lines);
    if not formatted_obj {
        return ptr[u8]();
    }
    (formatted, size) = _copy_string_obj_raw(formatted_obj);
    object_decref(formatted_obj);
    if not formatted or size == 0 {
        return formatted;
    }
    last = formatted + (size - 1);
    if last.view(1)[0] == u8(10) {
        last.view(1)[0] = u8(0);
    }
    return formatted;
}

impl _release_xid_data(xidata: ptr[_PyXIData_t], rawfree: i32) -> i32 {
    exc = PyErr_GetRaisedException();
    res: i32 = 0;
    if rawfree != 0 {
        res = _PyXIData_ReleaseAndRawFree(xidata);
    } else {
        res = _PyXIData_Release(xidata);
    }
    if res < 0 {
        _PyXIData_Clear(ptr[u8](), xidata);
        PyErr_Clear();
    }
    PyErr_SetRaisedException(exc);
    return res;
}

impl _excinfo_init_type_from_exception(
    info: ptr[_PyXI_excinfo_type], exc: ptr[PyObject]
) -> i32 {
    type = object_type(exc);
    if (type.view(1)[0].tp_flags & _Py_TPFLAGS_STATIC_BUILTIN) != 0 {
        info.view(1)[0].builtin = type;
    } else {
        info.view(1)[0].builtin = ptr[PyTypeObject]();
    }
    strobj = PyType_GetName(type);
    if not strobj {
        return -1;
    }
    (name, name_size) = _copy_string_obj_raw(strobj);
    info.view(1)[0].name = name;
    object_decref(strobj);
    if not info.view(1)[0].name {
        return -1;
    }
    strobj = PyType_GetQualName(type);
    if not strobj {
        return -1;
    }
    (qualname, qualname_size) = _copy_string_obj_raw(strobj);
    info.view(1)[0].qualname = qualname;
    object_decref(strobj);
    if not info.view(1)[0].qualname {
        return -1;
    }
    strobj = PyType_GetModuleName(type);
    if not strobj {
        return -1;
    }
    (module, module_size) = _copy_string_obj_raw(strobj);
    info.view(1)[0].module = module;
    object_decref(strobj);
    if not info.view(1)[0].module {
        return -1;
    }
    return 0;
}

impl _excinfo_init_type_from_object(
    info: ptr[_PyXI_excinfo_type], exctype: ptr[PyObject]
) -> i32 {
    strobj = PyObject_GetAttrString(exctype, ptr[u8]("__name__"));
    if not strobj {
        return -1;
    }
    (name, name_size) = _copy_string_obj_raw(strobj);
    info.view(1)[0].name = name;
    object_decref(strobj);
    if not info.view(1)[0].name {
        return -1;
    }
    strobj = PyObject_GetAttrString(exctype, ptr[u8]("__qualname__"));
    if not strobj {
        return -1;
    }
    (qualname, qualname_size) = _copy_string_obj_raw(strobj);
    info.view(1)[0].qualname = qualname;
    object_decref(strobj);
    if not info.view(1)[0].qualname {
        return -1;
    }
    strobj = PyObject_GetAttrString(exctype, ptr[u8]("__module__"));
    if not strobj {
        return -1;
    }
    (module, module_size) = _copy_string_obj_raw(strobj);
    info.view(1)[0].module = module;
    object_decref(strobj);
    if not info.view(1)[0].module {
        return -1;
    }
    return 0;
}

impl _excinfo_clear_type(info: ptr[_PyXI_excinfo_type]) {
    if info.view(1)[0].name {
        PyMem_RawFree(info.view(1)[0].name);
    }
    if info.view(1)[0].qualname {
        PyMem_RawFree(info.view(1)[0].qualname);
    }
    if info.view(1)[0].module {
        PyMem_RawFree(info.view(1)[0].module);
    }
    info.view(1)[0].builtin = ptr[PyTypeObject]();
    info.view(1)[0].name = ptr[u8]();
    info.view(1)[0].qualname = ptr[u8]();
    info.view(1)[0].module = ptr[u8]();
}

impl _excinfo_normalize_type(info: ptr[_PyXI_excinfo_type]) -> tuple[ptr[u8], ptr[u8]] {
    if not info.view(1)[0].name {
        return (ptr[u8](), ptr[u8]());
    }
    module = info.view(1)[0].module;
    qualname = info.view(1)[0].qualname;
    if not qualname {
        qualname = info.view(1)[0].name;
    }
    if strcmp(module, ptr[u8]("builtins")) == 0 {
        module = ptr[u8]();
    } elif strcmp(module, ptr[u8]("__main__")) == 0 {
        module = ptr[u8]();
    }
    return (module, qualname);
}

impl excinfo_is_set(info: ptr[_PyXI_excinfo]) -> i32 {
    if info.view(1)[0].type_name or info.view(1)[0].msg {
        return 1;
    }
    return 0;
}

impl _PyXI_excinfo_clear(info: ptr[_PyXI_excinfo]) {
    _excinfo_clear_type(excinfo_type(info));
    if info.view(1)[0].msg {
        PyMem_RawFree(info.view(1)[0].msg);
    }
    if info.view(1)[0].errdisplay {
        PyMem_RawFree(info.view(1)[0].errdisplay);
    }
    info.view(1)[0].type_builtin = ptr[PyTypeObject]();
    info.view(1)[0].type_name = ptr[u8]();
    info.view(1)[0].type_qualname = ptr[u8]();
    info.view(1)[0].type_module = ptr[u8]();
    info.view(1)[0].msg = ptr[u8]();
    info.view(1)[0].errdisplay = ptr[u8]();
}

impl _PyXI_excinfo_InitFromException(
    info: ptr[_PyXI_excinfo], exc: ptr[PyObject]
) -> ptr[u8] {
    if PyErr_GivenExceptionMatches(exc, PyExc_MemoryError) != 0 {
        _PyXI_excinfo_clear(info);
        return ptr[u8]();
    }
    if _excinfo_init_type_from_exception(excinfo_type(info), exc) < 0 {
        _PyXI_excinfo_clear(info);
        return ptr[u8]("error while initializing exception type snapshot");
    }
    msgobj = PyObject_Str(exc);
    if not msgobj {
        _PyXI_excinfo_clear(info);
        return ptr[u8]("error while formatting exception");
    }
    (msg, msg_size) = _copy_string_obj_raw(msgobj);
    info.view(1)[0].msg = msg;
    object_decref(msgobj);
    if not info.view(1)[0].msg {
        _PyXI_excinfo_clear(info);
        return ptr[u8]("error while copying exception message");
    }
    (status, tbexc) = _convert_exc_to_TracebackException(exc);
    if status < 0 {
        PyErr_Clear();
    } else {
        info.view(1)[0].errdisplay = _format_TracebackException(tbexc);
        object_decref(tbexc);
        if not info.view(1)[0].errdisplay {
            PyErr_Clear();
        }
    }
    return ptr[u8]();
}

impl _PyXI_excinfo_InitFromObject(
    info: ptr[_PyXI_excinfo], obj_: ptr[PyObject]
) -> ptr[u8] {
    exctype = PyObject_GetAttrString(obj_, ptr[u8]("type"));
    if not exctype {
        _PyXI_excinfo_clear(info);
        return ptr[u8]("exception snapshot missing 'type' attribute");
    }
    res = _excinfo_init_type_from_object(excinfo_type(info), exctype);
    object_decref(exctype);
    if res < 0 {
        _PyXI_excinfo_clear(info);
        return ptr[u8]("error while initializing exception type snapshot");
    }
    msgobj = PyObject_GetAttrString(obj_, ptr[u8]("msg"));
    if not msgobj {
        _PyXI_excinfo_clear(info);
        return ptr[u8]("exception snapshot missing 'msg' attribute");
    }
    (msg, msg_size) = _copy_string_obj_raw(msgobj);
    info.view(1)[0].msg = msg;
    object_decref(msgobj);
    if not info.view(1)[0].msg {
        _PyXI_excinfo_clear(info);
        return ptr[u8]("error while copying exception message");
    }
    errdisplay = PyObject_GetAttrString(obj_, ptr[u8]("errdisplay"));
    if not errdisplay {
        _PyXI_excinfo_clear(info);
        return ptr[u8]("exception snapshot missing 'errdisplay' attribute");
    }
    (display, display_size) = _copy_string_obj_raw(errdisplay);
    info.view(1)[0].errdisplay = display;
    object_decref(errdisplay);
    if not info.view(1)[0].errdisplay {
        _PyXI_excinfo_clear(info);
        return ptr[u8]("error while copying exception error display");
    }
    return ptr[u8]();
}

impl _PyXI_excinfo_Apply(info: ptr[_PyXI_excinfo], exctype: ptr[PyObject]) {
    tbexc = NULL;
    if info.view(1)[0].errdisplay {
        tbexc = PyUnicode_FromString(info.view(1)[0].errdisplay);
        if not tbexc {
            PyErr_Clear();
        } else {
            PyErr_SetObject(exctype, tbexc);
            object_decref(tbexc);
            return;
        }
    }
    formatted = _PyXI_excinfo_format(info);
    PyErr_SetObject(exctype, formatted);
    object_decref(formatted);
    if tbexc {
        exc = PyErr_GetRaisedException();
        if PyObject_SetAttrString(exc, ptr[u8]("_errdisplay"), tbexc) < 0 {
            PyErr_Clear();
        }
        object_decref(tbexc);
        PyErr_SetRaisedException(exc);
    }
}

impl set_namespace_text(ns: ptr[PyObject], attr: ptr[u8], text: ptr[u8]) -> i32 {
    value = PyUnicode_FromString(text);
    if not value {
        return -1;
    }
    res = PyObject_SetAttrString(ns, attr, value);
    object_decref(value);
    return res;
}

impl _PyXI_excinfo_TypeAsObject(info: ptr[_PyXI_excinfo]) -> ptr[PyObject] {
    ns = _PyNamespace_New(NULL);
    if not ns {
        return NULL;
    }
    empty = True;
    if info.view(1)[0].type_name {
        if set_namespace_text(ns, ptr[u8]("__name__"), info.view(1)[0].type_name) < 0 {
            object_decref(ns);
            return NULL;
        }
        empty = False;
    }
    if info.view(1)[0].type_qualname {
        if set_namespace_text(
            ns, ptr[u8]("__qualname__"), info.view(1)[0].type_qualname
        )
            < 0 {
            object_decref(ns);
            return NULL;
        }
        empty = False;
    }
    if info.view(1)[0].type_module {
        if set_namespace_text(ns, ptr[u8]("__module__"), info.view(1)[0].type_module)
            < 0 {
            object_decref(ns);
            return NULL;
        }
        empty = False;
    }
    if empty {
        object_decref(ns);
        return NULL;
    }
    return ns;
}

impl _PyXI_excinfo_AsObject(info: ptr[_PyXI_excinfo]) -> ptr[PyObject] {
    ns = _PyNamespace_New(NULL);
    if not ns {
        return NULL;
    }
    type = _PyXI_excinfo_TypeAsObject(info);
    if not type {
        if PyErr_Occurred() {
            object_decref(ns);
            return NULL;
        }
        type = object_new_ref(Py_None);
    }
    res = PyObject_SetAttrString(ns, ptr[u8]("type"), type);
    object_decref(type);
    if res < 0 {
        object_decref(ns);
        return NULL;
    }
    msg = NULL;
    if info.view(1)[0].msg {
        msg = PyUnicode_FromString(info.view(1)[0].msg);
    } else {
        msg = object_new_ref(Py_None);
    }
    if not msg {
        object_decref(ns);
        return NULL;
    }
    res = PyObject_SetAttrString(ns, ptr[u8]("msg"), msg);
    object_decref(msg);
    if res < 0 {
        object_decref(ns);
        return NULL;
    }
    formatted = _PyXI_excinfo_format(info);
    if not formatted {
        object_decref(ns);
        return NULL;
    }
    res = PyObject_SetAttrString(ns, ptr[u8]("formatted"), formatted);
    object_decref(formatted);
    if res < 0 {
        object_decref(ns);
        return NULL;
    }
    if info.view(1)[0].errdisplay {
        tbexc = PyUnicode_FromString(info.view(1)[0].errdisplay);
        if not tbexc {
            PyErr_Clear();
        } else {
            res = PyObject_SetAttrString(ns, ptr[u8]("errdisplay"), tbexc);
            object_decref(tbexc);
            if res < 0 {
                object_decref(ns);
                return NULL;
            }
        }
    }
    return ns;
}

impl _PyXI_ApplyErrorCode(code: i32, interp: ptr[u8]) -> i32 {
    tstate = thread_state();
    if code == XI_ERR_OTHER {
        PyErr_SetNone(PyExc_InterpreterError);
    } elif code == XI_ERR_NO_MEMORY {
        PyErr_NoMemory();
    } elif code == XI_ERR_ALREADY_RUNNING {
        _PyErr_SetInterpreterAlreadyRunning();
    } elif code == XI_ERR_MAIN_NS_FAILURE {
        PyErr_SetString(
            PyExc_InterpreterError, ptr[u8]("failed to get __main__ namespace")
        );
    } elif code == XI_ERR_APPLY_NS_FAILURE {
        PyErr_SetString(
            PyExc_InterpreterError, ptr[u8]("failed to apply namespace to __main__")
        );
    } elif code == XI_ERR_PRESERVE_FAILURE {
        PyErr_SetString(
            PyExc_InterpreterError, ptr[u8]("failed to preserve objects across session")
        );
    } elif code == XI_ERR_EXC_PROPAGATION_FAILURE {
        PyErr_SetString(
            PyExc_InterpreterError,
            ptr[u8]("failed to transfer exception between interpreters")
        );
    } elif code == XI_ERR_NOT_SHAREABLE {
        _set_xid_lookup_failure(tstate, NULL, ptr[u8](), NULL);
    } else {
        PyErr_Format(PyExc_RuntimeError, ptr[u8]("unsupported error code %d"), code);
    }
    return -1;
}

impl failure_reset(failure: ptr[_PyXI_failure]) {
    failure.view(1)[0].code = XI_ERR_NO_ERROR;
    failure.view(1)[0].msg = ptr[u8]();
    failure.view(1)[0].msg_owned = 0;
}

impl clear_xi_failure(failure: ptr[_PyXI_failure]) {
    if failure.view(1)[0].msg and failure.view(1)[0].msg_owned != 0 {
        PyMem_RawFree(failure.view(1)[0].msg);
    }
    failure_reset(failure);
}

impl copy_xi_failure(dest: ptr[_PyXI_failure], src: ptr[_PyXI_failure]) {
    dest.view(1)[0].code = src.view(1)[0].code;
    dest.view(1)[0].msg = src.view(1)[0].msg;
    dest.view(1)[0].msg_owned = 0;
}

impl xi_error_clear(err: ptr[_PyXI_error]) {
    err.view(1)[0].interp = ptr[u8]();
    if err.view(1)[0].override_ {
        clear_xi_failure(err.view(1)[0].override_);
    }
    _PyXI_excinfo_clear(error_uncaught(err));
}

impl xi_error_is_set(error: ptr[_PyXI_error]) -> i32 {
    if error.view(1)[0].override_ {
        return 1;
    }
    return excinfo_is_set(error_uncaught(error));
}

impl xi_error_has_override(err: ptr[_PyXI_error]) -> i32 {
    override_ = err.view(1)[0].override_;
    if not override_ {
        return 0;
    }
    if override_.view(1)[0].code != XI_ERR_NO_ERROR
        and override_.view(1)[0].code != XI_ERR_UNCAUGHT_EXCEPTION {
        return 1;
    }
    return 0;
}

impl xi_error_resolve_current_exc(
    tstate: ptr[PyThreadState], override_: ptr[_PyXI_failure]
) -> ptr[PyObject] {
    exc = _PyErr_GetRaisedException(tstate);
    if exc and override_ and override_.view(1)[0].code != XI_ERR_UNCAUGHT_EXCEPTION {
        if override_.view(1)[0].code == XI_ERR_ALREADY_RUNNING {
            old = exc;
            exc = NULL;
            object_decref(old);
        }
    }
    return exc;
}

impl xi_error_set_override(
    tstate: ptr[PyThreadState], err: ptr[_PyXI_error], override_: ptr[_PyXI_failure]
) {
    storage = error_override_storage(err);
    err.view(1)[0].override_ = storage;
    copy_xi_failure(storage, override_);
    err.view(1)[0].interp = tstate_interp(tstate);
}

impl xi_error_set_override_code(
    tstate: ptr[PyThreadState], err: ptr[_PyXI_error], code: i32
) {
    slots: own XIStack = XIStack();
    override_ = ptr[_PyXI_failure](jacpy_stack_address(&mut slots));
    failure_reset(override_);
    override_.view(1)[0].code = code;
    xi_error_set_override(tstate, err, override_);
}

impl xi_error_set_exc(
    tstate: ptr[PyThreadState], err: ptr[_PyXI_error], exc: ptr[PyObject]
) -> ptr[u8] {
    failure = _PyXI_excinfo_InitFromException(error_uncaught(err), exc);
    if failure {
        if _PyErr_ExceptionMatches(tstate, PyExc_MemoryError) != 0 {
            xi_error_set_override_code(tstate, err, XI_ERR_NO_MEMORY);
        } else {
            xi_error_set_override_code(tstate, err, XI_ERR_OTHER);
        }
        PyErr_Clear();
    }
    return failure;
}

impl _PyXI_ApplyError(error: ptr[_PyXI_error], failure: ptr[u8]) -> ptr[PyObject] {
    tstate = PyThreadState_Get();
    if failure {
        xi_error_clear(error);
        return NULL;
    }
    code: i32 = XI_ERR_UNCAUGHT_EXCEPTION;
    if error.view(1)[0].override_ {
        code = error.view(1)[0].override_.view(1)[0].code;
    }
    uncaught = error_uncaught(error);
    if code == XI_ERR_UNCAUGHT_EXCEPTION {
        return _PyXI_excinfo_AsObject(uncaught);
    } elif code == XI_ERR_NOT_SHAREABLE {
        cause = NULL;
        if excinfo_is_set(uncaught) != 0 {
            _PyXI_excinfo_Apply(uncaught, PyExc_Exception);
            cause = _PyErr_GetRaisedException(tstate);
        }
        msg = uncaught.view(1)[0].msg;
        if error.view(1)[0].override_ {
            msg = error.view(1)[0].override_.view(1)[0].msg;
        }
        _set_xid_lookup_failure(tstate, NULL, msg, cause);
        object_xdecref(cause);
    } else {
        _PyXI_ApplyErrorCode(code, error.view(1)[0].interp);
        if excinfo_is_set(uncaught) != 0 {
            exc = _PyErr_GetRaisedException(tstate);
            _PyXI_excinfo_Apply(uncaught, PyExc_InterpreterError);
            exc2 = _PyErr_GetRaisedException(tstate);
            PyException_SetContext(exc, exc2);
            _PyErr_SetRaisedException(tstate, exc);
        }
    }
    return NULL;
}

impl _sharednsitem_init(item: ptr[_PyXI_namespace_item], key: ptr[PyObject]) -> i32 {
    (name, name_size) = _copy_string_obj_raw(key);
    item.view(1)[0].name = name;
    if not item.view(1)[0].name {
        return -1;
    }
    item.view(1)[0].xidata = ptr[_PyXIData_t]();
    return 0;
}

impl _sharednsitem_has_value(item: ptr[_PyXI_namespace_item]) -> tuple[i32, i64] {
    if not item.view(1)[0].xidata {
        return (i32(0), i64(-1));
    }
    return (i32(1), item.view(1)[0].xidata.view(1)[0].interpid);
}

impl _sharednsitem_set_value(
    item: ptr[_PyXI_namespace_item], value: ptr[PyObject], fallback: i32
) -> i32 {
    item.view(1)[0].xidata = _PyXIData_New();
    if not item.view(1)[0].xidata {
        return -1;
    }
    tstate = PyThreadState_Get();
    if _PyObject_GetXIData(tstate, value, fallback, item.view(1)[0].xidata) < 0 {
        PyMem_RawFree(item.view(1)[0].xidata);
        item.view(1)[0].xidata = ptr[_PyXIData_t]();
        return -1;
    }
    return 0;
}

impl _sharednsitem_clear_value(item: ptr[_PyXI_namespace_item]) {
    xidata = item.view(1)[0].xidata;
    if xidata {
        item.view(1)[0].xidata = ptr[_PyXIData_t]();
        _release_xid_data(xidata, 1);
    }
}

impl _sharednsitem_clear(item: ptr[_PyXI_namespace_item]) {
    if item.view(1)[0].name {
        PyMem_RawFree(item.view(1)[0].name);
        item.view(1)[0].name = ptr[u8]();
    }
    _sharednsitem_clear_value(item);
}

impl _sharednsitem_copy_from_ns(
    item: ptr[_PyXI_namespace_item], ns: ptr[PyObject], fallback: i32
) -> i32 {
    value = PyDict_GetItemString(ns, item.view(1)[0].name);
    if not value {
        if PyErr_Occurred() {
            return -1;
        }
        return 0;
    }
    if _sharednsitem_set_value(item, value, fallback) < 0 {
        return -1;
    }
    return 0;
}

impl _sharednsitem_apply(
    item: ptr[_PyXI_namespace_item], ns: ptr[PyObject], dflt: ptr[PyObject]
) -> i32 {
    name = PyUnicode_FromString(item.view(1)[0].name);
    if not name {
        return -1;
    }
    value = NULL;
    if item.view(1)[0].xidata {
        value = _PyXIData_NewObject(item.view(1)[0].xidata);
        if not value {
            object_decref(name);
            return -1;
        }
    } else {
        value = object_new_ref(dflt);
    }
    res = PyDict_SetItem(ns, name, value);
    object_decref(name);
    object_decref(value);
    return res;
}

impl _sharedns_alloc(maxitems: i64) -> ptr[_PyXI_namespace] {
    if maxitems < 0 {
        if not PyErr_Occurred() {
            PyErr_BadInternalCall();
        }
        return ptr[_PyXI_namespace]();
    } elif maxitems == 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("empty namespaces not allowed"));
        return ptr[_PyXI_namespace]();
    }
    fixedsize = u64(NAMESPACE_ITEMS);
    itemsize = u64(NAMESPACE_ITEM_SIZE);
    if u64(maxitems) > (u64(PY_SSIZE_T_MAX_VALUE) - fixedsize) // itemsize {
        PyErr_NoMemory();
        return ptr[_PyXI_namespace]();
    }
    size = fixedsize + itemsize * u64(maxitems);
    ns = ptr[_PyXI_namespace](PyMem_RawCalloc(size, 1));
    if not ns {
        PyErr_NoMemory();
        return ns;
    }
    ns.view(1)[0].maxitems = maxitems;
    return ns;
}

impl _sharedns_free(ns: ptr[_PyXI_namespace]) {
    i: i64 = 0;
    if ns.view(1)[0].numvalues > 0 {
        while i < ns.view(1)[0].numvalues {
            _sharednsitem_clear(ns_item(ns, i));
            i += 1;
        }
    }
    while i < ns.view(1)[0].numnames {
        _sharednsitem_clear(ns_item(ns, i));
        i += 1;
    }
    PyMem_RawFree(ns);
}

impl _create_sharedns(names: ptr[PyObject]) -> ptr[_PyXI_namespace] {
    numnames: i64 = 0;
    if dict_check_exact(names) {
        numnames = PyDict_Size(names);
    } else {
        numnames = PySequence_Size(names);
    }
    ns = _sharedns_alloc(numnames);
    if not ns {
        return ns;
    }
    if dict_check_exact(names) {
        i: i64 = 0;
        pos: i64 = 0;
        name = NULL;
        value = NULL;
        while PyDict_Next(names, &mut pos, &mut name, &mut value) != 0 {
            if _sharednsitem_init(ns_item(ns, i), name) < 0 {
                _sharedns_free(ns);
                return ptr[_PyXI_namespace]();
            }
            ns.view(1)[0].numnames += 1;
            i += 1;
        }
    } elif PySequence_Check(names) != 0 {
        j: i64 = 0;
        while j < numnames {
            item_name = PySequence_GetItem(names, j);
            if not item_name {
                _sharedns_free(ns);
                return ptr[_PyXI_namespace]();
            }
            res = _sharednsitem_init(ns_item(ns, j), item_name);
            object_decref(item_name);
            if res < 0 {
                _sharedns_free(ns);
                return ptr[_PyXI_namespace]();
            }
            ns.view(1)[0].numnames += 1;
            j += 1;
        }
    } else {
        PyErr_SetString(
            PyExc_NotImplementedError, ptr[u8]("non-sequence namespace not supported")
        );
        _sharedns_free(ns);
        return ptr[_PyXI_namespace]();
    }
    return ns;
}

impl _fill_sharedns(
    ns: ptr[_PyXI_namespace],
    nsobj: ptr[PyObject],
    fallback: i32,
    p_err: ptr[_PyXI_failure]
) -> i32 {
    tstate = PyThreadState_Get();
    i: i64 = 0;
    while i < ns.view(1)[0].maxitems {
        if _sharednsitem_copy_from_ns(ns_item(ns, i), nsobj, fallback) < 0 {
            if p_err {
                _propagate_not_shareable_error(tstate, p_err);
            }
            j: i64 = 0;
            while j < i {
                _sharednsitem_clear_value(ns_item(ns, j));
                ns.view(1)[0].numvalues -= 1;
                j += 1;
            }
            return -1;
        }
        ns.view(1)[0].numvalues += 1;
        i += 1;
    }
    return 0;
}

impl _sharedns_free_pending(data: ptr) -> i32 {
    _sharedns_free(ptr[_PyXI_namespace](data));
    return 0;
}

impl _destroy_sharedns(ns: ptr[_PyXI_namespace]) {
    if ns.view(1)[0].numvalues == 0 {
        _sharedns_free(ns);
        return;
    }
    (has_value, interpid0) = _sharednsitem_has_value(ns_item(ns, 0));
    if has_value == 0 {
        _sharedns_free(ns);
        return;
    }
    interp = _PyInterpreterState_LookUpID(interpid0);
    if interp == ptr[u8](PyInterpreterState_Get()) {
        _sharedns_free(ns);
        return;
    }
    _Py_CallInInterpreter(interp, ptr(_sharedns_free_pending), ptr(ns));
}

impl _apply_sharedns(
    ns: ptr[_PyXI_namespace], nsobj: ptr[PyObject], dflt: ptr[PyObject]
) -> i32 {
    i: i64 = 0;
    while i < ns.view(1)[0].maxitems {
        if _sharednsitem_apply(ns_item(ns, i), nsobj, dflt) != 0 {
            return -1;
        }
        i += 1;
    }
    return 0;
}

impl _session_is_active(session: ptr[_PyXI_session]) -> bool {
    return session.view(1)[0].status == SESSION_ACTIVE;
}

impl session_reset(session: ptr[_PyXI_session]) {
    session.view(1)[0].status = SESSION_UNUSED;
    session.view(1)[0].switched = 0;
    session.view(1)[0].prev_tstate = ptr[PyThreadState]();
    session.view(1)[0].init_tstate = ptr[PyThreadState]();
    session.view(1)[0].own_init_tstate = 0;
    session.view(1)[0].running = 0;
    session.view(1)[0].main_ns = NULL;
    session.view(1)[0]._preserved = NULL;
}

impl _enter_session(session: ptr[_PyXI_session], interp: ptr[u8]) {
    tstate = PyThreadState_Get();
    prev = tstate;
    same_interp = interp == tstate_interp(tstate);
    if not same_interp {
        tstate = _PyThreadState_NewBound(interp, TSTATE_WHENCE_EXEC);
        PyThreadState_Swap(tstate);
    }
    session_reset(session);
    session.view(1)[0].status = SESSION_ACTIVE;
    session.view(1)[0].init_tstate = tstate;
    session.view(1)[0].prev_tstate = prev;
    if same_interp {
        session.view(1)[0].switched = 0;
        session.view(1)[0].own_init_tstate = 0;
    } else {
        session.view(1)[0].switched = 1;
        session.view(1)[0].own_init_tstate = 1;
    }
}

impl _exit_session(session: ptr[_PyXI_session]) {
    tstate = session.view(1)[0].init_tstate;
    old = session.view(1)[0].main_ns;
    session.view(1)[0].main_ns = NULL;
    object_xdecref(old);
    old = session.view(1)[0]._preserved;
    session.view(1)[0]._preserved = NULL;
    object_xdecref(old);
    if session.view(1)[0].running != 0 {
        _PyInterpreterState_SetNotRunningMain(tstate_interp(tstate));
        session.view(1)[0].running = 0;
    }
    if session.view(1)[0].prev_tstate != session.view(1)[0].init_tstate {
        session.view(1)[0].own_init_tstate = 0;
        PyThreadState_Clear(tstate);
        PyThreadState_Swap(session.view(1)[0].prev_tstate);
        PyThreadState_Delete(tstate);
    }
    session_reset(session);
}

impl _propagate_not_shareable_error(
    tstate: ptr[PyThreadState], override_: ptr[_PyXI_failure]
) {
    exctype = get_notshareableerror_type(tstate);
    if not exctype {
        PyErr_FormatUnraisable(
            ptr[u8]("Exception ignored while propagating not shareable error")
        );
        return;
    }
    if PyErr_ExceptionMatches(exctype) != 0 {
        failure_reset(override_);
        override_.view(1)[0].code = XI_ERR_NOT_SHAREABLE;
    }
}

impl _enter_session_failed(
    session: ptr[_PyXI_session],
    sharedns: ptr[_PyXI_namespace],
    override_: ptr[_PyXI_failure],
    result: ptr[_PyXI_session_result]
) -> i32 {
    slots: own XIStack = XIStack();
    err = ptr[_PyXI_error](jacpy_stack_address(&mut slots));
    failure = capture_session_error(session, err, override_);
    _exit_session(session);
    if sharedns {
        _destroy_sharedns(sharedns);
    }
    excinfo = _PyXI_ApplyError(err, failure);
    xi_error_clear(err);
    if excinfo {
        if result {
            result.view(1)[0].excinfo = excinfo;
        } else {
            object_decref(excinfo);
        }
    }
    return -1;
}

impl capture_session_error(
    session: ptr[_PyXI_session], err: ptr[_PyXI_error], override_: ptr[_PyXI_failure]
) -> ptr[u8] {
    tstate = session.view(1)[0].init_tstate;
    normalized = override_;
    if normalized and normalized.view(1)[0].code == XI_ERR_UNCAUGHT_EXCEPTION {
        normalized = ptr[_PyXI_failure]();
    }
    failure = ptr[u8]();
    exc = xi_error_resolve_current_exc(tstate, normalized);
    if exc {
        failure = xi_error_set_exc(tstate, err, exc);
        object_decref(exc);
        if PyErr_Occurred() {
            PyErr_FormatUnraisable(failure);
        }
    }
    if normalized and not failure {
        xi_error_set_override(tstate, err, normalized);
    }
    return failure;
}

impl _ensure_main_ns(session: ptr[_PyXI_session], failure: ptr[_PyXI_failure]) -> i32 {
    tstate = session.view(1)[0].init_tstate;
    if session.view(1)[0].main_ns {
        return 0;
    }
    main_mod = _Py_GetMainModule(tstate);
    if _Py_CheckMainModule(main_mod) < 0 {
        object_xdecref(main_mod);
        if failure {
            failure_reset(failure);
            failure.view(1)[0].code = XI_ERR_MAIN_NS_FAILURE;
        }
        return -1;
    }
    ns = PyModule_GetDict(main_mod);
    object_decref(main_mod);
    if not ns {
        if failure {
            failure_reset(failure);
            failure.view(1)[0].code = XI_ERR_MAIN_NS_FAILURE;
        }
        return -1;
    }
    session.view(1)[0].main_ns = object_new_ref(ns);
    return 0;
}

impl _pop_preserved(
    session: ptr[_PyXI_session], p_failure: ptr[_PyXI_failure]
) -> tuple[i32, ptr[_PyXI_namespace], ptr[PyObject]] {
    slots: own XIStack = XIStack();
    failure = ptr[_PyXI_failure](jacpy_stack_address(&mut slots));
    failure_reset(failure);
    xidata = ptr[_PyXI_namespace]();
    if not session.view(1)[0]._preserved {
        return (i32(0), xidata, NULL);
    }
    if session.view(1)[0].init_tstate == session.view(1)[0].prev_tstate {
        preserved = session.view(1)[0]._preserved;
        session.view(1)[0]._preserved = NULL;
        return (i32(0), xidata, preserved);
    }
    failed = False;
    len = PyDict_Size(session.view(1)[0]._preserved);
    if len < 0 {
        failure.view(1)[0].code = XI_ERR_PRESERVE_FAILURE;
        failed = True;
    } elif len > 0 {
        xidata = _create_sharedns(session.view(1)[0]._preserved);
        if not xidata {
            failure.view(1)[0].code = XI_ERR_PRESERVE_FAILURE;
            failed = True;
        } elif _fill_sharedns(
            xidata, session.view(1)[0]._preserved, XIDATA_FULL_FALLBACK, failure
        )
            < 0 {
            if failure.view(1)[0].code != XI_ERR_NOT_SHAREABLE {
                failure.view(1)[0].code = XI_ERR_PRESERVE_FAILURE;
            }
            failed = True;
        }
    }
    if failed {
        if p_failure {
            p_failure.view(1)[0].code = failure.view(1)[0].code;
            p_failure.view(1)[0].msg = failure.view(1)[0].msg;
            p_failure.view(1)[0].msg_owned = failure.view(1)[0].msg_owned;
        }
        if xidata {
            _destroy_sharedns(xidata);
        }
        return (i32(-1), ptr[_PyXI_namespace](), NULL);
    }
    old = session.view(1)[0]._preserved;
    session.view(1)[0]._preserved = NULL;
    object_xdecref(old);
    return (i32(0), xidata, NULL);
}

impl _finish_preserved(
    xidata: ptr[_PyXI_namespace], current: ptr[PyObject]
) -> tuple[i32, ptr[PyObject]] {
    if not xidata {
        return (i32(0), current);
    }
    res: i32 = -1;
    preserved = current;
    ns = PyDict_New();
    if ns {
        if _apply_sharedns(xidata, ns, NULL) < 0 {
            object_decref(ns);
        } else {
            preserved = ns;
            res = 0;
        }
    }
    _destroy_sharedns(xidata);
    return (res, preserved);
}

impl status_ok -> PyStatus {
    return PyStatus(
        _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
    );
}

impl status_error(func: ptr[u8], msg: ptr[u8]) -> PyStatus {
    return PyStatus(_type=_PyStatus_TYPE_ERROR, func=func, err_msg=msg, exitcode=0);
}

impl xid_lookup_init(state: ptr[u8]) {
    _xidregistry_init(ptr[_PyXIData_registry_t](state));
}

impl xid_lookup_fini(state: ptr[u8]) {
    _xidregistry_fini(ptr[_PyXIData_registry_t](state));
}

impl get_lookup_context(tstate: ptr[PyThreadState]) -> tuple[i32, ptr[u8], ptr[u8]] {
    interp = tstate_interp(tstate);
    global_state = xi_global_state(interp);
    if not global_state {
        return (i32(-1), ptr[u8](), ptr[u8]());
    }
    local = xi_state(interp);
    if not local {
        return (i32(-1), ptr[u8](), ptr[u8]());
    }
    return (i32(0), global_state, local);
}

impl lookup_getdata(
    global_lookup: ptr[u8], local_lookup: ptr[u8], obj_: ptr[PyObject]
) -> tuple[int, int] {
    return _lookup_getdata_from_registry(global_lookup, local_lookup, obj_);
}

impl _xidregistry_init(registry: ptr[_PyXIData_registry_t]) {
    if registry.view(1)[0].initialized != 0 {
        return;
    }
    registry.view(1)[0].initialized = 1;
    if registry.view(1)[0].global != 0 {
        _register_builtins_for_crossinterpreter_data(registry);
    }
}

impl _xidregistry_fini(registry: ptr[_PyXIData_registry_t]) {
    if registry.view(1)[0].initialized == 0 {
        return;
    }
    registry.view(1)[0].initialized = 0;
    _xidregistry_clear(registry);
}

impl _xidregistry_lock(registry: ptr[_PyXIData_registry_t]) {
    if registry.view(1)[0].global != 0 {
        PyMutex_Lock(registry_mutex(registry));
    }
}

impl _xidregistry_unlock(registry: ptr[_PyXIData_registry_t]) {
    if registry.view(1)[0].global != 0 {
        PyMutex_Unlock(registry_mutex(registry));
    }
}

impl _get_xidregistry_for_type(
    global_lookup: ptr[u8], local_lookup: ptr[u8], cls: ptr[PyTypeObject]
) -> ptr[_PyXIData_registry_t] {
    if (cls.view(1)[0].tp_flags & Py_TPFLAGS_HEAPTYPE) != 0 {
        return ptr[_PyXIData_registry_t](local_lookup);
    }
    return ptr[_PyXIData_registry_t](global_lookup);
}

impl _xidregistry_find_type(
    xidregistry: ptr[_PyXIData_registry_t], cls: ptr[PyTypeObject]
) -> ptr[_PyXIData_regitem_t] {
    cur = xidregistry.view(1)[0].head;
    while cur {
        if cur.view(1)[0].weakref {
            registered = weakref_get_ref(cur.view(1)[0].weakref);
            if not registered {
                cur = _xidregistry_remove_entry(xidregistry, cur);
                continue;
            }
            object_decref(registered);
        }
        if cur.view(1)[0].cls == cls {
            return cur;
        }
        cur = cur.view(1)[0].next;
    }
    return ptr[_PyXIData_regitem_t]();
}

impl _lookup_getdata_from_registry(
    global_lookup: ptr[u8], local_lookup: ptr[u8], obj_: ptr[PyObject]
) -> tuple[int, int] {
    cls = object_type(obj_);
    xidregistry = _get_xidregistry_for_type(global_lookup, local_lookup, cls);
    _xidregistry_lock(xidregistry);
    matched = _xidregistry_find_type(xidregistry, cls);
    basic = 0;
    fallback = 0;
    if matched {
        basic = int(matched.view(1)[0].getdata_basic);
        fallback = int(matched.view(1)[0].getdata_fallback);
    }
    _xidregistry_unlock(xidregistry);
    return (basic, fallback);
}

impl _xidregistry_add_type(
    xidregistry: ptr[_PyXIData_registry_t],
    cls: ptr[PyTypeObject],
    basic: int,
    fallback: int
) -> i32 {
    newhead = ptr[_PyXIData_regitem_t](PyMem_RawMalloc(u64(_PyXIData_regitem_t_SIZE)));
    if not newhead {
        return -1;
    }
    newhead.view(1)[0].prev = ptr[_PyXIData_regitem_t]();
    newhead.view(1)[0].next = ptr[_PyXIData_regitem_t]();
    newhead.view(1)[0].cls = cls;
    newhead.view(1)[0].weakref = NULL;
    newhead.view(1)[0].refcount = 1;
    newhead.view(1)[0].getdata_basic = basic;
    newhead.view(1)[0].getdata_fallback = fallback;
    if (cls.view(1)[0].tp_flags & Py_TPFLAGS_HEAPTYPE) != 0 {
        newhead.view(1)[0].weakref = PyWeakref_NewRef(ptr[PyObject](cls), NULL);
        if not newhead.view(1)[0].weakref {
            PyMem_RawFree(newhead);
            return -1;
        }
    }
    newhead.view(1)[0].next = xidregistry.view(1)[0].head;
    if newhead.view(1)[0].next {
        newhead.view(1)[0].next.view(1)[0].prev = newhead;
    }
    xidregistry.view(1)[0].head = newhead;
    return 0;
}

impl _xidregistry_remove_entry(
    xidregistry: ptr[_PyXIData_registry_t], regitem: ptr[_PyXIData_regitem_t]
) -> ptr[_PyXIData_regitem_t] {
    next = regitem.view(1)[0].next;
    if regitem.view(1)[0].prev {
        regitem.view(1)[0].prev.view(1)[0].next = next;
    } else {
        xidregistry.view(1)[0].head = next;
    }
    if next {
        next.view(1)[0].prev = regitem.view(1)[0].prev;
    }
    object_xdecref(regitem.view(1)[0].weakref);
    PyMem_RawFree(regitem);
    return next;
}

impl _xidregistry_clear(xidregistry: ptr[_PyXIData_registry_t]) {
    cur = xidregistry.view(1)[0].head;
    xidregistry.view(1)[0].head = ptr[_PyXIData_regitem_t]();
    while cur {
        next = cur.view(1)[0].next;
        object_xdecref(cur.view(1)[0].weakref);
        PyMem_RawFree(cur);
        cur = next;
    }
}

impl _bytes_shared(
    tstate: ptr[PyThreadState],
    obj_: ptr[PyObject],
    size: u64,
    newfunc: ptr,
    xidata: ptr[_PyXIData_t]
) -> i32 {
    if _PyXIData_InitWithSize(xidata, tstate_interp(tstate), size, obj_, newfunc) < 0 {
        return -1;
    }
    data = ptr[_PyBytes_data_t](xidata.view(1)[0].data);
    if _PyBytes_GetData(obj_, data) < 0 {
        _PyXIData_Clear(tstate_interp(tstate), xidata);
        return -1;
    }
    return 0;
}

impl _new_str_object(xidata: ptr[_PyXIData_t]) -> ptr[PyObject] {
    shared = ptr[shared_str_data](xidata.view(1)[0].data);
    return PyUnicode_FromKindAndData(
        shared.view(1)[0].kind, shared.view(1)[0].buffer, shared.view(1)[0].len
    );
}

impl _str_shared(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
) -> i32 {
    if _PyXIData_InitWithSize(
        xidata, tstate_interp(tstate), SHARED_STR_DATA_SIZE, obj_, ptr(_new_str_object)
    )
        < 0 {
        return -1;
    }
    shared = ptr[shared_str_data](xidata.view(1)[0].data);
    shared.view(1)[0].kind = i32(uo_kind(obj_));
    shared.view(1)[0].buffer = ptr(uo_data(obj_));
    shared.view(1)[0].len = uo_length(obj_);
    return 0;
}

impl _new_long_object(xidata: ptr[_PyXIData_t]) -> ptr[PyObject] {
    return PyLong_FromSsize_t(ptr[i64](xidata).view(1)[0]);
}

impl _long_shared(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
) -> i32 {
    value = PyLong_AsSsize_t(obj_);
    if value == -1 and PyErr_Occurred() {
        if PyErr_ExceptionMatches(PyExc_OverflowError) != 0 {
            PyErr_SetString(PyExc_OverflowError, ptr[u8]("try sending as bytes"));
        }
        return -1;
    }
    _PyXIData_Init(xidata, tstate_interp(tstate), ptr(), NULL, ptr(_new_long_object));
    ptr[i64](xidata).view(1)[0] = value;
    return 0;
}

impl _new_float_object(xidata: ptr[_PyXIData_t]) -> ptr[PyObject] {
    return PyFloat_FromDouble(ptr[f64](xidata.view(1)[0].data).view(1)[0]);
}

impl _float_shared(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
) -> i32 {
    if _PyXIData_InitWithSize(
        xidata, tstate_interp(tstate), 8, NULL, ptr(_new_float_object)
    )
        < 0 {
        return -1;
    }
    ptr[f64](xidata.view(1)[0].data).view(1)[0] = PyFloat_AsDouble(obj_);
    return 0;
}

impl _new_none_object(xidata: ptr[_PyXIData_t]) -> ptr[PyObject] {
    return object_new_ref(Py_None);
}

impl _none_shared(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
) -> i32 {
    _PyXIData_Init(xidata, tstate_interp(tstate), ptr(), NULL, ptr(_new_none_object));
    return 0;
}

impl _new_bool_object(xidata: ptr[_PyXIData_t]) -> ptr[PyObject] {
    if xidata.view(1)[0].data {
        return object_new_ref(ptr[PyObject](addressof(_Py_TrueStruct)));
    }
    return object_new_ref(ptr[PyObject](addressof(_Py_FalseStruct)));
}

impl _bool_shared(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
) -> i32 {
    _PyXIData_Init(xidata, tstate_interp(tstate), ptr(), NULL, ptr(_new_bool_object));
    if obj_ == ptr[PyObject](addressof(_Py_TrueStruct)) {
        ptr[i64](xidata).view(1)[0] = 1;
    }
    return 0;
}

impl _new_tuple_object(xidata: ptr[_PyXIData_t]) -> ptr[PyObject] {
    shared = ptr[shared_tuple_data](xidata.view(1)[0].data);
    len = shared.view(1)[0].len;
    tuple = PyTuple_New(len);
    if not tuple {
        return NULL;
    }
    i: i64 = 0;
    while i < len {
        item = _PyXIData_NewObject((shared.view(1)[0].items + i).view(1)[0]);
        if not item {
            object_decref(tuple);
            return NULL;
        }
        tuple_set_item(tuple, i, item);
        i += 1;
    }
    return tuple;
}

impl _tuple_shared_free(data: ptr) {
    shared = ptr[shared_tuple_data](data);
    i: i64 = 0;
    while i < shared.view(1)[0].len {
        slot = shared.view(1)[0].items + i;
        if slot.view(1)[0] {
            _PyXIData_Release(slot.view(1)[0]);
            PyMem_RawFree(slot.view(1)[0]);
            slot.view(1)[0] = ptr[_PyXIData_t]();
        }
        i += 1;
    }
    PyMem_Free(shared.view(1)[0].items);
    PyMem_RawFree(shared);
}

impl _tuple_shared(
    tstate: ptr[PyThreadState],
    obj_: ptr[PyObject],
    fallback: i32,
    xidata: ptr[_PyXIData_t]
) -> i32 {
    len = object_size(obj_);
    if len < 0 {
        return -1;
    }
    shared = ptr[shared_tuple_data](PyMem_RawMalloc(SHARED_TUPLE_DATA_SIZE));
    if not shared {
        PyErr_NoMemory();
        return -1;
    }
    shared.view(1)[0].len = len;
    shared.view(1)[0].items = ptr[ptr[_PyXIData_t]](PyMem_Calloc(u64(len), 8));
    if not shared.view(1)[0].items {
        PyErr_NoMemory();
        return -1;
    }
    i: i64 = 0;
    while i < len {
        xidata_i = _PyXIData_New();
        if not xidata_i {
            _tuple_shared_free(shared);
            return -1;
        }
        item = tuple_get_item(obj_, i);
        res: i32 = -1;
        if Py_EnterRecursiveCall(ptr[u8](" while sharing a tuple")) == 0 {
            res = _PyObject_GetXIData(tstate, item, fallback, xidata_i);
            Py_LeaveRecursiveCall();
        }
        if res < 0 {
            PyMem_RawFree(xidata_i);
            _tuple_shared_free(shared);
            return -1;
        }
        (shared.view(1)[0].items + i).view(1)[0] = xidata_i;
        i += 1;
    }
    _PyXIData_Init(
        xidata, tstate_interp(tstate), ptr(shared), obj_, ptr(_new_tuple_object)
    );
    xidata.view(1)[0].free = int(ptr(_tuple_shared_free));
    return 0;
}

impl register_builtin(
    xidregistry: ptr[_PyXIData_registry_t],
    type: ptr[PyTypeObject],
    basic: int,
    fallback: int
) -> i32 {
    return _xidregistry_add_type(xidregistry, type, basic, fallback);
}

impl _register_builtins_for_crossinterpreter_data(
    xidregistry: ptr[_PyXIData_registry_t]
) {
    where = ptr[u8]("_register_builtins_for_crossinterpreter_data");
    if register_builtin(xidregistry, object_type(Py_None), int(ptr(_none_shared)), 0)
        != 0 {
        _Py_FatalErrorFunc(
            where, ptr[u8]("could not register None for cross-interpreter sharing")
        );
    }
    if register_builtin(
        xidregistry,
        ptr[PyTypeObject](addressof(PyLong_Type)),
        int(ptr(_long_shared)),
        0
    )
        != 0 {
        _Py_FatalErrorFunc(
            where, ptr[u8]("could not register int for cross-interpreter sharing")
        );
    }
    if register_builtin(
        xidregistry,
        ptr[PyTypeObject](addressof(PyBytes_Type)),
        int(ptr(_PyBytes_GetXIData)),
        0
    )
        != 0 {
        _Py_FatalErrorFunc(
            where, ptr[u8]("could not register bytes for cross-interpreter sharing")
        );
    }
    if register_builtin(
        xidregistry,
        ptr[PyTypeObject](addressof(PyUnicode_Type)),
        int(ptr(_str_shared)),
        0
    )
        != 0 {
        _Py_FatalErrorFunc(
            where, ptr[u8]("could not register str for cross-interpreter sharing")
        );
    }
    if register_builtin(
        xidregistry,
        ptr[PyTypeObject](addressof(PyBool_Type)),
        int(ptr(_bool_shared)),
        0
    )
        != 0 {
        _Py_FatalErrorFunc(
            where, ptr[u8]("could not register bool for cross-interpreter sharing")
        );
    }
    if register_builtin(
        xidregistry,
        ptr[PyTypeObject](addressof(PyFloat_Type)),
        int(ptr(_float_shared)),
        0
    )
        != 0 {
        _Py_FatalErrorFunc(
            where, ptr[u8]("could not register float for cross-interpreter sharing")
        );
    }
    if register_builtin(
        xidregistry,
        ptr[PyTypeObject](addressof(PyTuple_Type)),
        0,
        int(ptr(_tuple_shared))
    )
        != 0 {
        _Py_FatalErrorFunc(
            where, ptr[u8]("could not register tuple for cross-interpreter sharing")
        );
    }
}
