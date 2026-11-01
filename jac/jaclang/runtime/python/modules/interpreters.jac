import from c {
    def _PyInterpreterState_LookUpID(requested_id: i64) -> ptr[u8];  def _PyInterpreterState_LookUpIDObject(
        requested_id: ptr[PyObject]
    ) -> ptr[u8];  def _PyInterpreterState_IDIncref(interp: ptr[u8]);  def _PyInterpreterState_IDDecref(
        interp: ptr[u8]
    );  def _PyInterpreterState_RequireIDRef(interp: ptr[u8], required: i32);  def _PyInterpreterState_IsReady(
        interp: ptr[u8]
    ) -> i32;  def _PyInterpreterState_GetWhence(interp: ptr[u8]) -> i64;  def _PyInterpreterState_GetIDObject(
        interp: ptr[u8]
    ) -> ptr[PyObject];  def _PyInterpreterState_IsRunningMain(
        interp: ptr[u8]
    ) -> i32;  def _PyInterpreterConfig_InitFromState(
        config: ptr[PyInterpreterConfig], interp: ptr[u8]
    ) -> i32;  def _PyInterpreterConfig_AsDict(
        config: ptr[PyInterpreterConfig]
    ) -> ptr[PyObject];  def _PyInterpreterConfig_InitFromDict(
        config: ptr[PyInterpreterConfig], dict_: ptr[PyObject]
    ) -> i32;  def _PyInterpreterConfig_UpdateFromDict(
        config: ptr[PyInterpreterConfig], dict_: ptr[PyObject]
    ) -> i32;  def PyInterpreterState_Head -> ptr[u8];  def PyInterpreterState_Next(
        interp: ptr[u8]
    ) -> ptr[u8];  def _PyBuffer_ReleaseInInterpreterAndRawFree(
        interp: ptr[PyInterpreterState], view: ptr[Py_buffer]
    ) -> i32;  def _PyNamespace_New(kwds: ptr[PyObject]) -> ptr[PyObject];  def PyEval_EvalCode(
        co: ptr[PyObject], globals: ptr[PyObject], locals: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyErr_ExceptionMatches(
        tstate: ptr[PyThreadState], exc: ptr[PyObject]
    ) -> i32;  def _PyErr_Clear(tstate: ptr[PyThreadState]);  def _PyErr_GetRaisedException(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyObject];  def _PyErr_SetRaisedException(
        tstate: ptr[PyThreadState], exc: ptr[PyObject]
    );  def _PyErr_Format(
        tstate: ptr[PyThreadState],
        exception: ptr[PyObject],
        format_: ptr[u8],
        *args: any
    ) -> ptr[PyObject];  def PyModule_GetState(m: ptr[PyObject]) -> ptr;  def strcmp(
        left: ptr[u8], right: ptr[u8]
    ) -> i32;  def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  def memset(
        target: ptr, value: i32, size: u64
    ) -> ptr;  def jacpy_stack_address(slots: &mut InterpStack) -> int;  def _PyXIData_Init(
        xidata: ptr[_PyXIData_t],
        interp: ptr[u8],
        shared: ptr,
        obj_: ptr[PyObject],
        new_object: ptr
    );  def _PyXIData_Clear(interp: ptr[u8], xidata: ptr[_PyXIData_t]);  def _PyXIData_GetNotShareableErrorType(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyObject];  def _PyXIData_FormatNotShareableError(
        tstate: ptr[PyThreadState], format_: ptr[u8], *args: any
    );  def _PyObject_CheckXIData(
        tstate: ptr[PyThreadState], obj_: ptr[PyObject]
    ) -> i32;  def _PyObject_GetXIData(
        tstate: ptr[PyThreadState],
        obj_: ptr[PyObject],
        fallback: i32,
        xidata: ptr[_PyXIData_t]
    ) -> i32;  def _PyPickle_GetXIData(
        tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
    ) -> i32;  def _PyCode_GetScriptXIData(
        tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
    ) -> i32;  def _PyFunction_GetXIData(
        tstate: ptr[PyThreadState], obj_: ptr[PyObject], xidata: ptr[_PyXIData_t]
    ) -> i32;  def _PyXIData_NewObject(xidata: ptr[_PyXIData_t]) -> ptr[PyObject];  def _PyXIData_Release(
        xidata: ptr[_PyXIData_t]
    ) -> i32;  def _PyXI_NewExcInfo(exc: ptr[PyObject]) -> ptr;  def _PyXI_FreeExcInfo(
        info: ptr
    );  def _PyXI_FormatExcInfo(info: ptr) -> ptr[PyObject];  def _PyXI_ExcInfoAsObject(
        info: ptr
    ) -> ptr[PyObject];  def _PyXI_NewFailure -> ptr;  def _PyXI_FreeFailure(
        failure: ptr
    );  def _PyXI_InitFailure(failure: ptr, code: i32, obj_: ptr[PyObject]) -> i32;  def _PyXI_UnwrapNotShareableError(
        tstate: ptr[PyThreadState], failure: ptr
    ) -> i32;  def _PyXI_NewSession -> ptr;  def _PyXI_FreeSession(session: ptr);  def _PyXI_ClearResult(
        result: ptr[_PyXI_session_result]
    );  def _PyXI_Enter(
        session: ptr,
        interp: ptr[u8],
        nsupdates: ptr[PyObject],
        result: ptr[_PyXI_session_result]
    ) -> i32;  def _PyXI_Exit(
        session: ptr, overrides: ptr, result: ptr[_PyXI_session_result]
    ) -> i32;  def _PyXI_GetMainNamespace(
        session: ptr, failure: ptr
    ) -> ptr[PyObject];  def _PyXI_Preserve(
        session: ptr, name: ptr[u8], value: ptr[PyObject], failure: ptr
    ) -> i32;  def _PyXI_GetPreserved(
        result: ptr[_PyXI_session_result], name: ptr[u8]
    ) -> ptr[PyObject];  def _PyXI_NewInterpreter(
        config: ptr[PyInterpreterConfig],
        maybe_whence: ptr[i64],
        p_tstate: ptr[ptr[PyThreadState]],
        p_save_tstate: ptr[ptr[PyThreadState]]
    ) -> ptr[u8];  def _PyXI_EndInterpreter(
        interp: ptr[u8],
        tstate: ptr[PyThreadState],
        p_save_tstate: ptr[ptr[PyThreadState]]
    );  glob PyExc_InterpreterError: ptr[PyObject]; glob PyExc_InterpreterNotFoundError:
             ptr[PyObject]; glob PyMemoryView_Type: PyTypeObject; obj xibufferview {
        has ob_base: _object,
            view: ptr[Py_buffer],
            interpid: i64;
    }  obj xibuffer {
        has view: Py_buffer,
            used: i32;
    }  obj module_state {
        has _notused: i32,
            XIBufferViewType: ptr[PyTypeObject];
    }  obj interp_call_data {
        has func: ptr[_PyXIData_t],
            args: ptr[_PyXIData_t],
            kwargs: ptr[_PyXIData_t],
            preallocated_func: _PyXIData_t,
            preallocated_args: _PyXIData_t,
            preallocated_kwargs: _PyXIData_t;
    }  obj run_result {
        has result: ptr[PyObject],
            excinfo: ptr[PyObject];
    }  obj InterpStack {
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
            w15: u64 = 0,
            w16: u64 = 0,
            w17: u64 = 0;
    }
}

glob:priv SIZEOF_PY_BUFFER: Final[u64] = 80,
     SIZEOF_XIBUFFER: Final[u64] = 88,
     SIZEOF_XIBUFFERVIEW: Final[u64] = 32,
     SIZEOF_INTERP_CALL: Final[u64] = 144,
     SIZEOF_INTERPRETER_CONFIG: Final[u64] = 28,
     INTERP_CALL_PREALLOCATED_FUNC: Final[i64] = 24,
     INTERP_CALL_PREALLOCATED_ARGS: Final[i64] = 64,
     INTERP_CALL_PREALLOCATED_KWARGS: Final[i64] = 104,
     MODULE_STATE_XIBUFFERVIEWTYPE: Final[i64] = 8,
     STACK_WHENCE: Final[i64] = 32,
     PY_INTERPRETER_CONFIG_SHARED_GIL: Final[i32] = 1,
     PY_INTERPRETER_CONFIG_OWN_GIL: Final[i32] = 2,
     WHENCE_UNKNOWN: Final[i64] = 0,
     WHENCE_RUNTIME: Final[i64] = 1,
     WHENCE_LEGACY_CAPI: Final[i64] = 2,
     WHENCE_CAPI: Final[i64] = 3,
     WHENCE_XI: Final[i64] = 4,
     WHENCE_STDLIB: Final[i64] = 5,
     XI_ERR_UNCAUGHT_EXCEPTION: Final[i32] = -1,
     XI_ERR_OTHER: Final[i32] = -2,
     XI_ERR_NOT_SHAREABLE: Final[i32] = -9;

import from c {
    glob:priv XIBufferViewType_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(xibufferview_dealloc)),
             PyType_Slot(slot=1, pfunc=ptr(xibufferview_getbuf)),
             PyType_Slot(slot=0, pfunc=ptr())
         ],
         XIBufferViewType_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_interpreters.CrossInterpreterBufferView"),
             basicsize=32,
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_DISALLOW_INSTANTIATION
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(XIBufferViewType_slots)
         );
}

def _get_current_interp -> ptr[u8];

def _get_current_module -> ptr[PyObject];

def is_running_main(interp: ptr[u8]) -> i32;

def is_notshareable_raised(tstate: ptr[PyThreadState]) -> i32;

def unwrap_not_shareable(tstate: ptr[PyThreadState], failure: ptr);

def xibufferview_from_buffer(
    cls: ptr[PyTypeObject], view: ptr[Py_buffer], interpid: i64
) -> ptr[PyObject];

def xibufferview_dealloc(op: ptr[PyObject]);

def xibufferview_getbuf(op: ptr[PyObject], view: ptr[Py_buffer], flags: i32) -> i32;

def _memoryview_from_xid(data: ptr[_PyXIData_t]) -> ptr[PyObject];

def _pybuffer_shared_free(data: ptr);

def _pybuffer_shared(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], data: ptr[_PyXIData_t]
) -> i32;

def register_memoryview_xid(
    mod: ptr[PyObject], p_state: ptr[ptr[PyTypeObject]]
) -> i32;

def get_module_state(mod: ptr[PyObject]) -> ptr[module_state];

def _get_current_module_state -> ptr[module_state];

def traverse_module_state(state: ptr[module_state], visitor: ptr, arg: ptr) -> i32;

def clear_module_state(state: ptr[module_state]) -> i32;

def _get_current_xibufferview_type -> ptr[PyTypeObject];

def init_named_config(config: ptr[PyInterpreterConfig], name: ptr[u8]) -> i32;

def config_from_object(
    configobj: ptr[PyObject], config: ptr[PyInterpreterConfig]
) -> i32;

def _interp_call_clear(call: ptr[interp_call_data]);

def _interp_call_pack(
    tstate: ptr[PyThreadState],
    call: ptr[interp_call_data],
    func: ptr[PyObject],
    args: ptr[PyObject],
    kwargs: ptr[PyObject]
) -> i32;

def wrap_notshareable(tstate: ptr[PyThreadState], label: ptr[u8]);

def _interp_call_unpack(
    call: ptr[interp_call_data]
) -> tuple[i32, ptr[PyObject], ptr[PyObject], ptr[PyObject]];

def _make_call(call: ptr[interp_call_data], failure: ptr) -> tuple[i32, ptr[PyObject]];

def _run_script(script: ptr[_PyXIData_t], ns: ptr[PyObject], failure: ptr) -> i32;

def _run_result_clear(runres: ptr[run_result]);

def _run_in_interpreter(
    tstate: ptr[PyThreadState],
    interp: ptr[u8],
    script: ptr[_PyXIData_t],
    call: ptr[interp_call_data],
    shareables: ptr[PyObject],
    runres: ptr[run_result]
) -> i32;

def get_whence(interp: ptr[u8]) -> i64;

def resolve_interp(
    idobj: ptr[PyObject], restricted: i32, reqready: i32, op: ptr[u8]
) -> ptr[u8];

def get_summary(interp: ptr[u8]) -> ptr[PyObject];

def interp_new_config(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def interp_create(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def interp_destroy(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def interp_list_all(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def interp_get_current(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def interp_get_main(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def interp_set___main___attrs(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def _handle_script_error(runres: ptr[run_result]) -> ptr[PyObject];

def interp_exec(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def interp_run_string(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def interp_run_func(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def interp_call(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def object_is_shareable(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def interp_is_running(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def interp_get_config(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def interp_whence(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def interp_incref(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def interp_decref(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def capture_exception(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def module_exec(mod: ptr[PyObject]) -> i32;

def module_traverse(mod: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def module_clear(mod: ptr[PyObject]) -> i32;

def module_free(mod: ptr);

import from c {
    glob:priv create_kwlist: list[ptr[u8]] = [
             ptr[u8]("config"),
             ptr[u8]("reqrefs"),
             ptr[u8]()
         ],
         destroy_kwlist: list[ptr[u8]] = [
             ptr[u8]("id"),
             ptr[u8]("restrict"),
             ptr[u8]()
         ],
         list_all_kwlist: list[ptr[u8]] = [ptr[u8]("require_ready"), ptr[u8]()],
         set___main___attrs_kwlist: list[ptr[u8]] = [
             ptr[u8]("id"),
             ptr[u8]("updates"),
             ptr[u8]("restrict"),
             ptr[u8]()
         ],
         exec_kwlist: list[ptr[u8]] = [
             ptr[u8]("id"),
             ptr[u8]("code"),
             ptr[u8]("shared"),
             ptr[u8]("restrict"),
             ptr[u8]()
         ],
         run_string_kwlist: list[ptr[u8]] = [
             ptr[u8]("id"),
             ptr[u8]("script"),
             ptr[u8]("shared"),
             ptr[u8]("restrict"),
             ptr[u8]()
         ],
         run_func_kwlist: list[ptr[u8]] = [
             ptr[u8]("id"),
             ptr[u8]("func"),
             ptr[u8]("shared"),
             ptr[u8]("restrict"),
             ptr[u8]()
         ],
         call_kwlist: list[ptr[u8]] = [
             ptr[u8]("id"),
             ptr[u8]("callable"),
             ptr[u8]("args"),
             ptr[u8]("kwargs"),
             ptr[u8]("preserve_exc"),
             ptr[u8]("restrict"),
             ptr[u8]()
         ],
         is_shareable_kwlist: list[ptr[u8]] = [ptr[u8]("obj"), ptr[u8]()],
         is_running_kwlist: list[ptr[u8]] = [
             ptr[u8]("id"),
             ptr[u8]("restrict"),
             ptr[u8]()
         ],
         get_config_kwlist: list[ptr[u8]] = [
             ptr[u8]("id"),
             ptr[u8]("restrict"),
             ptr[u8]()
         ],
         whence_kwlist: list[ptr[u8]] = [ptr[u8]("id"), ptr[u8]()],
         incref_kwlist: list[ptr[u8]] = [
             ptr[u8]("id"),
             ptr[u8]("implieslink"),
             ptr[u8]("restrict"),
             ptr[u8]()
         ],
         decref_kwlist: list[ptr[u8]] = [ptr[u8]("id"), ptr[u8]("restrict"), ptr[u8]()],
         capture_exception_kwlist: list[ptr[u8]] = [ptr[u8]("exc"), ptr[u8]()];
}

impl _get_current_interp -> ptr[u8] {
    return current_interp();
}

impl _get_current_module -> ptr[PyObject] {
    name = PyUnicode_FromString(ptr[u8]("_interpreters"));
    if not name {
        return NULL;
    }
    mod = PyImport_GetModule(name);
    object_decref(name);
    if not mod {
        return NULL;
    }
    return mod;
}

impl is_running_main(interp: ptr[u8]) -> i32 {
    if _PyInterpreterState_IsRunningMain(interp) != 0 {
        return 1;
    }
    if interp == ptr[u8](_PyInterpreterState_Main()) {
        return 1;
    }
    return 0;
}

impl is_notshareable_raised(tstate: ptr[PyThreadState]) -> i32 {
    exctype = _PyXIData_GetNotShareableErrorType(tstate);
    return _PyErr_ExceptionMatches(tstate, exctype);
}

impl unwrap_not_shareable(tstate: ptr[PyThreadState], failure: ptr) {
    if _PyXI_UnwrapNotShareableError(tstate, failure) < 0 {
        _PyErr_Clear(tstate);
    }
}

impl xibufferview_from_buffer(
    cls: ptr[PyTypeObject], view: ptr[Py_buffer], interpid: i64
) -> ptr[PyObject] {
    copied = ptr[Py_buffer](PyMem_RawMalloc(SIZEOF_PY_BUFFER));
    if not copied {
        return NULL;
    }
    memcpy(ptr(copied), ptr(view), SIZEOF_PY_BUFFER);
    self_ = ptr[xibufferview](PyObject_Malloc(SIZEOF_XIBUFFERVIEW));
    if not self_ {
        PyMem_RawFree(ptr(copied));
        return NULL;
    }
    PyObject_Init(ptr[PyObject](self_), ptr[PyObject](cls));
    self_.view(1)[0].view = copied;
    self_.view(1)[0].interpid = interpid;
    return ptr[PyObject](self_);
}

impl xibufferview_dealloc(op: ptr[PyObject]) {
    self_ = ptr[xibufferview](op);
    if self_.view(1)[0].view {
        interp = _PyInterpreterState_LookUpID(self_.view(1)[0].interpid);
        if not interp {
            PyErr_Clear();
            PyMem_RawFree(ptr(self_.view(1)[0].view));
        } else {
            if _PyBuffer_ReleaseInInterpreterAndRawFree(
                ptr[PyInterpreterState](interp), self_.view(1)[0].view
            )
                < 0 {
                PyErr_Clear();
            }
        }
    }
    tp = object_type(op);
    tp.view(1)[0].tp_free(ptr(op));
    object_decref(ptr[PyObject](tp));
}

impl xibufferview_getbuf(op: ptr[PyObject], view: ptr[Py_buffer], flags: i32) -> i32 {
    self_ = ptr[xibufferview](op);
    memcpy(ptr(view), ptr(self_.view(1)[0].view), SIZEOF_PY_BUFFER);
    view.view(1)[0].owner = op;
    view.view(1)[0].internal = ptr();
    return 0;
}

impl _memoryview_from_xid(data: ptr[_PyXIData_t]) -> ptr[PyObject] {
    view = ptr[xibuffer](data.view(1)[0].data);
    cls = _get_current_xibufferview_type();
    if not cls {
        return NULL;
    }
    obj_ = xibufferview_from_buffer(
        cls, ptr[Py_buffer](view), data.view(1)[0].interpid
    );
    if not obj_ {
        return NULL;
    }
    res = PyMemoryView_FromObject(obj_);
    if not res {
        object_decref(obj_);
        return NULL;
    }
    view.view(1)[0].used = 1;
    return res;
}

impl _pybuffer_shared_free(data: ptr) {
    view = ptr[xibuffer](data);
    if view.view(1)[0].used == 0 {
        PyBuffer_Release(ptr[Py_buffer](view));
    }
    PyMem_RawFree(data);
}

impl _pybuffer_shared(
    tstate: ptr[PyThreadState], obj_: ptr[PyObject], data: ptr[_PyXIData_t]
) -> i32 {
    view = ptr[xibuffer](PyMem_RawMalloc(SIZEOF_XIBUFFER));
    if not view {
        return -1;
    }
    view.view(1)[0].used = 0;
    if PyObject_GetBuffer(obj_, ptr[Py_buffer](view), PyBUF_FULL_RO) < 0 {
        PyMem_RawFree(ptr(view));
        return -1;
    }
    _PyXIData_Init(data, current_interp(), ptr(view), NULL, ptr(_memoryview_from_xid));
    data.view(1)[0].free = int(ptr(_pybuffer_shared_free));
    return 0;
}

impl register_memoryview_xid(
    mod: ptr[PyObject], p_state: ptr[ptr[PyTypeObject]]
) -> i32 {
    cls = ptr[PyTypeObject](
        PyType_FromModuleAndSpec(mod, addressof(XIBufferViewType_spec), NULL)
    );
    if not cls {
        return -1;
    }
    if PyModule_AddType(mod, ptr[PyObject](cls)) < 0 {
        object_decref(ptr[PyObject](cls));
        return -1;
    }
    p_state.view(1)[0] = cls;
    if ensure_xid_class(addressof(PyMemoryView_Type), ptr(_pybuffer_shared)) < 0 {
        return -1;
    }
    return 0;
}

impl get_module_state(mod: ptr[PyObject]) -> ptr[module_state] {
    return ptr[module_state](PyModule_GetState(mod));
}

impl _get_current_module_state -> ptr[module_state] {
    mod = _get_current_module();
    if not mod {
        mod = PyImport_ImportModule(ptr[u8]("_interpreters"));
        if not mod {
            return ptr[module_state]();
        }
    }
    state = get_module_state(mod);
    object_decref(mod);
    return state;
}

impl traverse_module_state(state: ptr[module_state], visitor: ptr, arg: ptr) -> i32 {
    vret = visit_reference(
        ptr[PyObject](state.view(1)[0].XIBufferViewType), visitor, arg
    );
    if vret != 0 {
        return vret;
    }
    return 0;
}

impl clear_module_state(state: ptr[module_state]) -> i32 {
    old = state.view(1)[0].XIBufferViewType;
    state.view(1)[0].XIBufferViewType = ptr[PyTypeObject]();
    object_xdecref(ptr[PyObject](old));
    return 0;
}

impl _get_current_xibufferview_type -> ptr[PyTypeObject] {
    state = _get_current_module_state();
    if not state {
        return ptr[PyTypeObject]();
    }
    return state.view(1)[0].XIBufferViewType;
}

impl init_named_config(config: ptr[PyInterpreterConfig], name: ptr[u8]) -> i32 {
    if not name
        or strcmp(name, ptr[u8]("")) == 0
        or strcmp(name, ptr[u8]("default")) == 0 {
        name = ptr[u8]("isolated");
    }
    cfg = config.view(1);
    if strcmp(name, ptr[u8]("isolated")) == 0 {
        cfg[0].use_main_obmalloc = 0;
        cfg[0].allow_fork = 0;
        cfg[0].allow_exec = 0;
        cfg[0].allow_threads = 1;
        cfg[0].allow_daemon_threads = 0;
        cfg[0].check_multi_interp_extensions = 1;
        cfg[0].gil = PY_INTERPRETER_CONFIG_OWN_GIL;
    } elif strcmp(name, ptr[u8]("legacy")) == 0 {
        cfg[0].use_main_obmalloc = 1;
        cfg[0].allow_fork = 1;
        cfg[0].allow_exec = 1;
        cfg[0].allow_threads = 1;
        cfg[0].allow_daemon_threads = 1;
        cfg[0].check_multi_interp_extensions = 0;
        cfg[0].gil = PY_INTERPRETER_CONFIG_SHARED_GIL;
    } elif strcmp(name, ptr[u8]("empty")) == 0 {
        memset(ptr(config), 0, SIZEOF_INTERPRETER_CONFIG);
    } else {
        PyErr_Format(PyExc_ValueError, ptr[u8]("unsupported config name '%s'"), name);
        return -1;
    }
    return 0;
}

impl config_from_object(
    configobj: ptr[PyObject], config: ptr[PyInterpreterConfig]
) -> i32 {
    if configobj == NULL or configobj == Py_None {
        if init_named_config(config, ptr[u8]()) < 0 {
            return -1;
        }
    } elif unicode_check(configobj) {
        utf8name = PyUnicode_AsUTF8(configobj);
        if not utf8name {
            return -1;
        }
        if init_named_config(config, utf8name) < 0 {
            return -1;
        }
    } else {
        dct = PyObject_GetAttrString(configobj, ptr[u8]("__dict__"));
        if not dct {
            PyErr_Format(PyExc_TypeError, ptr[u8]("bad config %R"), configobj);
            return -1;
        }
        res = _PyInterpreterConfig_InitFromDict(config, dct);
        object_decref(dct);
        if res < 0 {
            return -1;
        }
    }
    return 0;
}

impl _interp_call_clear(call: ptr[interp_call_data]) {
    c = call.view(1);
    if c[0].func {
        _PyXIData_Clear(ptr[u8](), c[0].func);
    }
    if c[0].args {
        _PyXIData_Clear(ptr[u8](), c[0].args);
    }
    if c[0].kwargs {
        _PyXIData_Clear(ptr[u8](), c[0].kwargs);
    }
    memset(ptr(call), 0, SIZEOF_INTERP_CALL);
}

impl _interp_call_pack(
    tstate: ptr[PyThreadState],
    call: ptr[interp_call_data],
    func: ptr[PyObject],
    args: ptr[PyObject],
    kwargs: ptr[PyObject]
) -> i32 {
    fallback = XIDATA_FULL_FALLBACK;
    c = call.view(1);
    pre_func = ptr[_PyXIData_t](ptr[u8](call) + INTERP_CALL_PREALLOCATED_FUNC);
    pre_args = ptr[_PyXIData_t](ptr[u8](call) + INTERP_CALL_PREALLOCATED_ARGS);
    pre_kwargs = ptr[_PyXIData_t](ptr[u8](call) + INTERP_CALL_PREALLOCATED_KWARGS);
    if PyCallable_Check(func) == 0 {
        _PyErr_Format(
            tstate, PyExc_TypeError, ptr[u8]("expected a callable, got %R"), func
        );
        return -1;
    }
    if _PyFunction_GetXIData(tstate, func, pre_func) < 0 {
        exc = _PyErr_GetRaisedException(tstate);
        if _PyPickle_GetXIData(tstate, func, pre_func) < 0 {
            _PyErr_SetRaisedException(tstate, exc);
            return -1;
        }
        object_decref(exc);
    }
    c[0].func = pre_func;
    if args != NULL and args != Py_None {
        if object_size(args) > 0 {
            if _PyObject_GetXIData(tstate, args, fallback, pre_args) < 0 {
                _interp_call_clear(call);
                return -1;
            }
            c[0].args = pre_args;
        }
    }
    if kwargs != NULL and kwargs != Py_None {
        if ptr[PyDictObject](kwargs).view(1)[0].ma_used > 0 {
            if _PyObject_GetXIData(tstate, kwargs, fallback, pre_kwargs) < 0 {
                _interp_call_clear(call);
                return -1;
            }
            c[0].kwargs = pre_kwargs;
        }
    }
    return 0;
}

impl wrap_notshareable(tstate: ptr[PyThreadState], label: ptr[u8]) {
    if is_notshareable_raised(tstate) == 0 {
        return;
    }
    cause = _PyErr_GetRaisedException(tstate);
    _PyXIData_FormatNotShareableError(tstate, ptr[u8]("%s not shareable"), label);
    exc = _PyErr_GetRaisedException(tstate);
    PyException_SetCause(exc, cause);
    _PyErr_SetRaisedException(tstate, exc);
}

impl _interp_call_unpack(
    call: ptr[interp_call_data]
) -> tuple[i32, ptr[PyObject], ptr[PyObject], ptr[PyObject]] {
    tstate = PyThreadState_Get();
    c = call.view(1);
    func = _PyXIData_NewObject(c[0].func);
    if not func {
        wrap_notshareable(tstate, ptr[u8]("func"));
        return (i32(-1), NULL, NULL, NULL);
    }
    args = NULL;
    if not c[0].args {
        args = PyTuple_New(0);
        if not args {
            object_decref(func);
            return (i32(-1), NULL, NULL, NULL);
        }
    } else {
        args = _PyXIData_NewObject(c[0].args);
        if not args {
            wrap_notshareable(tstate, ptr[u8]("args"));
            object_decref(func);
            return (i32(-1), NULL, NULL, NULL);
        }
    }
    kwargs = NULL;
    if c[0].kwargs {
        kwargs = _PyXIData_NewObject(c[0].kwargs);
        if not kwargs {
            wrap_notshareable(tstate, ptr[u8]("kwargs"));
            object_decref(func);
            object_decref(args);
            return (i32(-1), NULL, NULL, NULL);
        }
    }
    return (i32(0), func, args, kwargs);
}

impl _make_call(
    call: ptr[interp_call_data], failure: ptr
) -> tuple[i32, ptr[PyObject]] {
    tstate = thread_state();
    (status, func, args, kwargs) = _interp_call_unpack(call);
    if status < 0 {
        _PyXI_InitFailure(failure, XI_ERR_OTHER, NULL);
        unwrap_not_shareable(tstate, failure);
        return (i32(-1), NULL);
    }
    resobj = PyObject_Call(func, args, kwargs);
    object_decref(func);
    object_xdecref(args);
    object_xdecref(kwargs);
    if not resobj {
        return (i32(-1), NULL);
    }
    return (i32(0), resobj);
}

impl _run_script(script: ptr[_PyXIData_t], ns: ptr[PyObject], failure: ptr) -> i32 {
    code = _PyXIData_NewObject(script);
    if not code {
        _PyXI_InitFailure(failure, XI_ERR_NOT_SHAREABLE, NULL);
        return -1;
    }
    result = PyEval_EvalCode(code, ns, ns);
    object_decref(code);
    if not result {
        _PyXI_InitFailure(failure, XI_ERR_UNCAUGHT_EXCEPTION, NULL);
        return -1;
    }
    object_decref(result);
    return 0;
}

impl _run_result_clear(runres: ptr[run_result]) {
    r = runres.view(1);
    old_result = r[0].result;
    r[0].result = NULL;
    object_xdecref(old_result);
    old_excinfo = r[0].excinfo;
    r[0].excinfo = NULL;
    object_xdecref(old_excinfo);
}

impl _run_in_interpreter(
    tstate: ptr[PyThreadState],
    interp: ptr[u8],
    script: ptr[_PyXIData_t],
    call: ptr[interp_call_data],
    shareables: ptr[PyObject],
    runres: ptr[run_result]
) -> i32 {
    res: i32 = -1;
    failure = _PyXI_NewFailure();
    if not failure {
        return -1;
    }
    session = _PyXI_NewSession();
    if not session {
        _PyXI_FreeFailure(failure);
        return -1;
    }
    result_slots: own InterpStack = InterpStack();
    result = ptr[_PyXI_session_result](jacpy_stack_address(&mut result_slots));
    if _PyXI_Enter(session, interp, shareables, result) < 0 {
        _PyXI_FreeSession(session);
        _PyXI_FreeFailure(failure);
        return -1;
    }
    if script {
        mainns = _PyXI_GetMainNamespace(session, failure);
        if mainns {
            res = _run_script(script, mainns, failure);
        }
    } else {
        (status, resobj) = _make_call(call, failure);
        res = status;
        if res == 0 {
            res = _PyXI_Preserve(session, ptr[u8]("resobj"), resobj, failure);
            object_decref(resobj);
        }
    }
    exitres = _PyXI_Exit(session, failure, result);
    _PyXI_FreeSession(session);
    _PyXI_FreeFailure(failure);
    res = exitres;
    if not exception_raised(tstate) {
        if res < 0 {
            runres.view(1)[0].excinfo = object_new_ref(result.view(1)[0].excinfo);
            res = -1;
        } else {
            runres.view(1)[0].result = _PyXI_GetPreserved(result, ptr[u8]("resobj"));
            if exception_raised(tstate) {
                res = -1;
            }
        }
    }
    _PyXI_ClearResult(result);
    return res;
}

impl get_whence(interp: ptr[u8]) -> i64 {
    return _PyInterpreterState_GetWhence(interp);
}

impl resolve_interp(
    idobj: ptr[PyObject], restricted: i32, reqready: i32, op: ptr[u8]
) -> ptr[u8] {
    interp = ptr[u8]();
    if idobj == NULL {
        interp = current_interp();
    } else {
        interp = _PyInterpreterState_LookUpIDObject(idobj);
        if not interp {
            return ptr[u8]();
        }
    }
    if reqready != 0 and _PyInterpreterState_IsReady(interp) == 0 {
        if idobj == NULL {
            PyErr_Format(
                PyExc_InterpreterError,
                ptr[u8]("cannot %s current interpreter (not ready)"),
                op
            );
        } else {
            PyErr_Format(
                PyExc_InterpreterError,
                ptr[u8]("cannot %s interpreter %R (not ready)"),
                op,
                idobj
            );
        }
        return ptr[u8]();
    }
    if restricted != 0 and get_whence(interp) != WHENCE_STDLIB {
        if idobj == NULL {
            PyErr_Format(
                PyExc_InterpreterError,
                ptr[u8]("cannot %s unrecognized current interpreter"),
                op
            );
        } else {
            PyErr_Format(
                PyExc_InterpreterError,
                ptr[u8]("cannot %s unrecognized interpreter %R"),
                op,
                idobj
            );
        }
        return ptr[u8]();
    }
    return interp;
}

impl get_summary(interp: ptr[u8]) -> ptr[PyObject] {
    idobj = _PyInterpreterState_GetIDObject(interp);
    if not idobj {
        return NULL;
    }
    whenceobj = PyLong_FromLong(get_whence(interp));
    if not whenceobj {
        object_decref(idobj);
        return NULL;
    }
    res = PyTuple_Pack(2, idobj, whenceobj);
    object_decref(idobj);
    object_decref(whenceobj);
    return res;
}

impl interp_new_config(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    name = ptr[u8]();
    if PyArg_ParseTuple(args, ptr[u8]("|s:_interpreters.new_config"), &mut name) == 0 {
        return NULL;
    }
    overrides = kwds;
    config_slots: own InterpStack = InterpStack();
    config = ptr[PyInterpreterConfig](jacpy_stack_address(&mut config_slots));
    if init_named_config(config, name) < 0 {
        return NULL;
    }
    if overrides != NULL and ptr[PyDictObject](overrides).view(1)[0].ma_used > 0 {
        if _PyInterpreterConfig_UpdateFromDict(config, overrides) < 0 {
            return NULL;
        }
    }
    dct = _PyInterpreterConfig_AsDict(config);
    if not dct {
        return NULL;
    }
    configobj = _PyNamespace_New(dct);
    object_decref(dct);
    return configobj;
}

impl interp_create(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    configobj = NULL;
    reqrefs: i32 = 0;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("|O$p:create"),
        ptr(addressof(create_kwlist)),
        &mut configobj,
        &mut reqrefs
    )
        == 0 {
        return NULL;
    }
    slots: own InterpStack = InterpStack();
    base = ptr[u8](jacpy_stack_address(&mut slots));
    config = ptr[PyInterpreterConfig](base);
    if config_from_object(configobj, config) < 0 {
        return NULL;
    }
    whence = ptr[i64](base + STACK_WHENCE);
    whence.view(1)[0] = WHENCE_STDLIB;
    interp = _PyXI_NewInterpreter(
        config, whence, ptr[ptr[PyThreadState]](), ptr[ptr[PyThreadState]]()
    );
    if not interp {
        exc = PyErr_GetRaisedException();
        PyErr_SetString(PyExc_InterpreterError, ptr[u8]("interpreter creation failed"));
        _PyErr_ChainExceptions1(exc);
        return NULL;
    }
    idobj = _PyInterpreterState_GetIDObject(interp);
    if not idobj {
        _PyXI_EndInterpreter(interp, ptr[PyThreadState](), ptr[ptr[PyThreadState]]());
        return NULL;
    }
    if reqrefs != 0 {
        _PyInterpreterState_RequireIDRef(interp, 1);
    }
    return idobj;
}

impl interp_destroy(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    id = NULL;
    restricted: i32 = 0;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O|$p:destroy"),
        ptr(addressof(destroy_kwlist)),
        &mut id,
        &mut restricted
    )
        == 0 {
        return NULL;
    }
    reqready: i32 = 0;
    interp = resolve_interp(id, restricted, reqready, ptr[u8]("destroy"));
    if not interp {
        return NULL;
    }
    current = _get_current_interp();
    if not current {
        return NULL;
    }
    if interp == current {
        PyErr_SetString(
            PyExc_InterpreterError, ptr[u8]("cannot destroy the current interpreter")
        );
        return NULL;
    }
    if is_running_main(interp) != 0 {
        PyErr_Format(PyExc_InterpreterError, ptr[u8]("interpreter running"));
        return NULL;
    }
    _PyXI_EndInterpreter(interp, ptr[PyThreadState](), ptr[ptr[PyThreadState]]());
    return object_new_ref(Py_None);
}

impl interp_list_all(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    reqready: i32 = 0;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwargs,
        ptr[u8]("|$p:_interpreters.list_all"),
        ptr(addressof(list_all_kwlist)),
        &mut reqready
    )
        == 0 {
        return NULL;
    }
    ids = PyList_New(0);
    if not ids {
        return NULL;
    }
    interp = PyInterpreterState_Head();
    while interp {
        if reqready == 0 or _PyInterpreterState_IsReady(interp) != 0 {
            item = get_summary(interp);
            if not item {
                object_decref(ids);
                return NULL;
            }
            res = PyList_Insert(ids, 0, item);
            object_decref(item);
            if res < 0 {
                object_decref(ids);
                return NULL;
            }
        }
        interp = PyInterpreterState_Next(interp);
    }
    return ids;
}

impl interp_get_current(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    interp = _get_current_interp();
    if not interp {
        return NULL;
    }
    return get_summary(interp);
}

impl interp_get_main(self_: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    interp = ptr[u8](_PyInterpreterState_Main());
    return get_summary(interp);
}

impl interp_set___main___attrs(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    id = NULL;
    updates = NULL;
    restricted: i32 = 0;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwargs,
        ptr[u8]("OO!|$p:_interpreters.set___main___attrs"),
        ptr(addressof(set___main___attrs_kwlist)),
        &mut id,
        addressof(PyDict_Type),
        &mut updates,
        &mut restricted
    )
        == 0 {
        return NULL;
    }
    reqready: i32 = 1;
    interp = resolve_interp(id, restricted, reqready, ptr[u8]("update __main__ for"));
    if not interp {
        return NULL;
    }
    size = PyDict_Size(updates);
    if size < 0 {
        return NULL;
    }
    if size == 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("arg 2 must be a non-empty dict"));
        return NULL;
    }
    session = _PyXI_NewSession();
    if not session {
        return NULL;
    }
    if _PyXI_Enter(session, interp, updates, ptr[_PyXI_session_result]()) < 0 {
        _PyXI_FreeSession(session);
        return NULL;
    }
    res = _PyXI_Exit(session, ptr(), ptr[_PyXI_session_result]());
    _PyXI_FreeSession(session);
    if res < 0 {
        if not PyErr_Occurred() {
            PyErr_SetString(PyExc_RuntimeError, ptr[u8]("unresolved error"));
        }
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl _handle_script_error(runres: ptr[run_result]) -> ptr[PyObject] {
    if not runres.view(1)[0].excinfo {
        return NULL;
    }
    return runres.view(1)[0].excinfo;
}

impl interp_exec(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = thread_state();
    id = NULL;
    code = NULL;
    shared = NULL;
    restricted: i32 = 0;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("OO|O!$p:_interpreters.exec"),
        ptr(addressof(exec_kwlist)),
        &mut id,
        &mut code,
        addressof(PyDict_Type),
        &mut shared,
        &mut restricted
    )
        == 0 {
        return NULL;
    }
    reqready: i32 = 1;
    interp = resolve_interp(id, restricted, reqready, ptr[u8]("exec code for"));
    if not interp {
        return NULL;
    }
    xidata_slots: own InterpStack = InterpStack();
    xidata = ptr[_PyXIData_t](jacpy_stack_address(&mut xidata_slots));
    if _PyCode_GetScriptXIData(tstate, code, xidata) < 0 {
        unwrap_not_shareable(tstate, ptr());
        return NULL;
    }
    runres_slots: own InterpStack = InterpStack();
    runres = ptr[run_result](jacpy_stack_address(&mut runres_slots));
    res = _run_in_interpreter(
        tstate, interp, xidata, ptr[interp_call_data](), shared, runres
    );
    _PyXIData_Release(xidata);
    if res < 0 {
        return _handle_script_error(runres);
    }
    return object_new_ref(Py_None);
}

impl interp_run_string(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = thread_state();
    id = NULL;
    script = NULL;
    shared = NULL;
    restricted: i32 = 0;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("OU|O!$p:_interpreters.run_string"),
        ptr(addressof(run_string_kwlist)),
        &mut id,
        &mut script,
        addressof(PyDict_Type),
        &mut shared,
        &mut restricted
    )
        == 0 {
        return NULL;
    }
    reqready: i32 = 1;
    interp = resolve_interp(id, restricted, reqready, ptr[u8]("run a string in"));
    if not interp {
        return NULL;
    }
    script_type = object_type(script);
    if script_type == ptr[PyTypeObject](addressof(PyFunction_Type))
        or script_type == ptr[PyTypeObject](addressof(PyCode_Type)) {
        _PyArg_BadArgument(
            ptr[u8]("_interpreters.run_string"),
            ptr[u8]("argument 2"),
            ptr[u8]("a string"),
            script
        );
        return NULL;
    }
    xidata_slots: own InterpStack = InterpStack();
    xidata = ptr[_PyXIData_t](jacpy_stack_address(&mut xidata_slots));
    if _PyCode_GetScriptXIData(tstate, script, xidata) < 0 {
        unwrap_not_shareable(tstate, ptr());
        return NULL;
    }
    runres_slots: own InterpStack = InterpStack();
    runres = ptr[run_result](jacpy_stack_address(&mut runres_slots));
    res = _run_in_interpreter(
        tstate, interp, xidata, ptr[interp_call_data](), shared, runres
    );
    _PyXIData_Release(xidata);
    if res < 0 {
        return _handle_script_error(runres);
    }
    return object_new_ref(Py_None);
}

impl interp_run_func(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = thread_state();
    id = NULL;
    func = NULL;
    shared = NULL;
    restricted: i32 = 0;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("OO|O!$p:_interpreters.run_func"),
        ptr(addressof(run_func_kwlist)),
        &mut id,
        &mut func,
        addressof(PyDict_Type),
        &mut shared,
        &mut restricted
    )
        == 0 {
        return NULL;
    }
    reqready: i32 = 1;
    interp = resolve_interp(id, restricted, reqready, ptr[u8]("run a function in"));
    if not interp {
        return NULL;
    }
    code = NULL;
    func_type = object_type(func);
    if func_type == ptr[PyTypeObject](addressof(PyFunction_Type)) {
        code = ptr[ptr[PyObject]](ptr[u8](func) + PyFunctionObject_CODE).view(1)[0];
    } elif func_type == ptr[PyTypeObject](addressof(PyCode_Type)) {
        code = func;
    } else {
        _PyArg_BadArgument(
            ptr[u8]("_interpreters.run_func"),
            ptr[u8]("argument 2"),
            ptr[u8]("a function"),
            func
        );
        return NULL;
    }
    xidata_slots: own InterpStack = InterpStack();
    xidata = ptr[_PyXIData_t](jacpy_stack_address(&mut xidata_slots));
    if _PyCode_GetScriptXIData(tstate, code, xidata) < 0 {
        unwrap_not_shareable(tstate, ptr());
        return NULL;
    }
    runres_slots: own InterpStack = InterpStack();
    runres = ptr[run_result](jacpy_stack_address(&mut runres_slots));
    res = _run_in_interpreter(
        tstate, interp, xidata, ptr[interp_call_data](), shared, runres
    );
    _PyXIData_Release(xidata);
    if res < 0 {
        return _handle_script_error(runres);
    }
    return object_new_ref(Py_None);
}

impl interp_call(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    tstate = thread_state();
    id = NULL;
    callable = NULL;
    args_obj = NULL;
    kwargs_obj = NULL;
    preserve_exc: i32 = 0;
    restricted: i32 = 0;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("OO|O!O!$pp:_interpreters.call"),
        ptr(addressof(call_kwlist)),
        &mut id,
        &mut callable,
        addressof(PyTuple_Type),
        &mut args_obj,
        addressof(PyDict_Type),
        &mut kwargs_obj,
        &mut preserve_exc,
        &mut restricted
    )
        == 0 {
        return NULL;
    }
    reqready: i32 = 1;
    interp = resolve_interp(id, restricted, reqready, ptr[u8]("make a call in"));
    if not interp {
        return NULL;
    }
    call_slots: own InterpStack = InterpStack();
    call = ptr[interp_call_data](jacpy_stack_address(&mut call_slots));
    if _interp_call_pack(tstate, call, callable, args_obj, kwargs_obj) < 0 {
        return NULL;
    }
    res_and_exc = NULL;
    runres_slots: own InterpStack = InterpStack();
    runres = ptr[run_result](jacpy_stack_address(&mut runres_slots));
    failed = False;
    if _run_in_interpreter(tstate, interp, ptr[_PyXIData_t](), call, NULL, runres)
        < 0 {
        if not runres.view(1)[0].excinfo {
            failed = True;
        }
    }
    if not failed {
        result_obj = runres.view(1)[0].result;
        if not result_obj {
            result_obj = Py_None;
        }
        excinfo_obj = runres.view(1)[0].excinfo;
        if not excinfo_obj {
            excinfo_obj = Py_None;
        }
        res_and_exc = Py_BuildValue(ptr[u8]("OO"), result_obj, excinfo_obj);
    }
    _interp_call_clear(call);
    _run_result_clear(runres);
    return res_and_exc;
}

impl object_is_shareable(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    obj_ = NULL;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O:is_shareable"),
        ptr(addressof(is_shareable_kwlist)),
        &mut obj_
    )
        == 0 {
        return NULL;
    }
    tstate = thread_state();
    if _PyObject_CheckXIData(tstate, obj_) == 0 {
        return PyBool_FromLong(1);
    }
    PyErr_Clear();
    return PyBool_FromLong(0);
}

impl interp_is_running(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    id = NULL;
    restricted: i32 = 0;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O|$p:is_running"),
        ptr(addressof(is_running_kwlist)),
        &mut id,
        &mut restricted
    )
        == 0 {
        return NULL;
    }
    reqready: i32 = 1;
    interp = resolve_interp(id, restricted, reqready, ptr[u8]("check if running for"));
    if not interp {
        return NULL;
    }
    if is_running_main(interp) != 0 {
        return PyBool_FromLong(1);
    }
    return PyBool_FromLong(0);
}

impl interp_get_config(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    idobj = NULL;
    restricted: i32 = 0;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O|$p:get_config"),
        ptr(addressof(get_config_kwlist)),
        &mut idobj,
        &mut restricted
    )
        == 0 {
        return NULL;
    }
    if idobj == Py_None {
        idobj = NULL;
    }
    reqready: i32 = 0;
    interp = resolve_interp(idobj, restricted, reqready, ptr[u8]("get the config of"));
    if not interp {
        return NULL;
    }
    config_slots: own InterpStack = InterpStack();
    config = ptr[PyInterpreterConfig](jacpy_stack_address(&mut config_slots));
    if _PyInterpreterConfig_InitFromState(config, interp) < 0 {
        return NULL;
    }
    dct = _PyInterpreterConfig_AsDict(config);
    if not dct {
        return NULL;
    }
    configobj = _PyNamespace_New(dct);
    object_decref(dct);
    return configobj;
}

impl interp_whence(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    id = NULL;
    if PyArg_ParseTupleAndKeywords(
        args, kwds, ptr[u8]("O:whence"), ptr(addressof(whence_kwlist)), &mut id
    )
        == 0 {
        return NULL;
    }
    interp = _PyInterpreterState_LookUpIDObject(id);
    if not interp {
        return NULL;
    }
    whence = get_whence(interp);
    return PyLong_FromLong(whence);
}

impl interp_incref(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    id = NULL;
    implieslink: i32 = 0;
    restricted: i32 = 0;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O|$pp:incref"),
        ptr(addressof(incref_kwlist)),
        &mut id,
        &mut implieslink,
        &mut restricted
    )
        == 0 {
        return NULL;
    }
    reqready: i32 = 1;
    interp = resolve_interp(id, restricted, reqready, ptr[u8]("incref"));
    if not interp {
        return NULL;
    }
    if implieslink != 0 {
        _PyInterpreterState_RequireIDRef(interp, 1);
    }
    _PyInterpreterState_IDIncref(interp);
    return object_new_ref(Py_None);
}

impl interp_decref(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    id = NULL;
    restricted: i32 = 0;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("O|$p:decref"),
        ptr(addressof(decref_kwlist)),
        &mut id,
        &mut restricted
    )
        == 0 {
        return NULL;
    }
    reqready: i32 = 1;
    interp = resolve_interp(id, restricted, reqready, ptr[u8]("decref"));
    if not interp {
        return NULL;
    }
    _PyInterpreterState_IDDecref(interp);
    return object_new_ref(Py_None);
}

impl capture_exception(
    self_: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    exc_arg = NULL;
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("|O:capture_exception"),
        ptr(addressof(capture_exception_kwlist)),
        &mut exc_arg
    )
        == 0 {
        return NULL;
    }
    exc = exc_arg;
    if exc == NULL or exc == Py_None {
        exc = PyErr_GetRaisedException();
        if not exc {
            return object_new_ref(Py_None);
        }
    } elif not type_has_feature(object_type(exc), Py_TPFLAGS_BASE_EXC_SUBCLASS) {
        PyErr_Format(PyExc_TypeError, ptr[u8]("expected exception, got %R"), exc);
        return NULL;
    }
    captured = NULL;
    info = _PyXI_NewExcInfo(exc);
    if info {
        captured = _PyXI_ExcInfoAsObject(info);
        if captured {
            formatted = _PyXI_FormatExcInfo(info);
            if not formatted {
                old = captured;
                captured = NULL;
                object_decref(old);
            } else {
                res = PyObject_SetAttrString(captured, ptr[u8]("formatted"), formatted);
                object_decref(formatted);
                if res < 0 {
                    old = captured;
                    captured = NULL;
                    object_decref(old);
                }
            }
        }
    }
    _PyXI_FreeExcInfo(info);
    if exc != exc_arg {
        if PyErr_Occurred() {
            PyErr_SetRaisedException(exc);
        } else {
            _PyErr_ChainExceptions1(exc);
        }
    }
    return captured;
}

impl module_exec(mod: ptr[PyObject]) -> i32 {
    tstate = thread_state();
    state = get_module_state(mod);
    if PyModule_AddIntConstant(mod, ptr[u8]("WHENCE_UNKNOWN"), WHENCE_UNKNOWN) < 0 {
        return -1;
    }
    if PyModule_AddIntConstant(mod, ptr[u8]("WHENCE_RUNTIME"), WHENCE_RUNTIME) < 0 {
        return -1;
    }
    if PyModule_AddIntConstant(mod, ptr[u8]("WHENCE_LEGACY_CAPI"), WHENCE_LEGACY_CAPI)
        < 0 {
        return -1;
    }
    if PyModule_AddIntConstant(mod, ptr[u8]("WHENCE_CAPI"), WHENCE_CAPI) < 0 {
        return -1;
    }
    if PyModule_AddIntConstant(mod, ptr[u8]("WHENCE_XI"), WHENCE_XI) < 0 {
        return -1;
    }
    if PyModule_AddIntConstant(mod, ptr[u8]("WHENCE_STDLIB"), WHENCE_STDLIB) < 0 {
        return -1;
    }
    if PyModule_AddType(mod, PyExc_InterpreterError) < 0 {
        return -1;
    }
    if PyModule_AddType(mod, PyExc_InterpreterNotFoundError) < 0 {
        return -1;
    }
    exctype = _PyXIData_GetNotShareableErrorType(tstate);
    if PyModule_AddType(mod, exctype) < 0 {
        return -1;
    }
    p_state = ptr[ptr[PyTypeObject]](ptr[u8](state) + MODULE_STATE_XIBUFFERVIEWTYPE);
    if register_memoryview_xid(mod, p_state) < 0 {
        return -1;
    }
    return 0;
}

impl module_traverse(mod: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    state = get_module_state(mod);
    return traverse_module_state(state, visitor, arg);
}

impl module_clear(mod: ptr[PyObject]) -> i32 {
    state = get_module_state(mod);
    return clear_module_state(state);
}

impl module_free(mod: ptr) {
    state = get_module_state(ptr[PyObject](mod));
    clear_module_state(state);
}
