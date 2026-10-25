import from c {
    def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  def memset(
        target: ptr, value: i32, size: u64
    ) -> ptr;  def malloc(size: u64) -> ptr;  def fputs(
        text: ptr[u8], stream: ptr
    ) -> i32;  def jacpy_stdio_stream(stream: i32) -> ptr;  def PyThread_tss_is_created(
        key: ptr[u8]
    ) -> i32;  def PyThread_tss_create(key: ptr[u8]) -> i32;  def PyThread_tss_delete(
        key: ptr[u8]
    );  def PyThread_tss_get(key: ptr[u8]) -> ptr;  def PyThread_tss_set(
        key: ptr[u8], value: ptr
    ) -> i32;  def PyThread_get_thread_native_id -> u64;  def PyThread_hang_thread;  def PyPreConfig_InitPythonConfig(
        config: ptr[u8]
    );  def PyConfig_InitPythonConfig(config: ptr[u8]);  def PyConfig_Clear(
        config: ptr[u8]
    );  def _PyTime_Init(state: ptr[u8]) -> PyStatus;  def _PyParkingLot_AfterFork;  def _PyTypes_AfterFork;  def _PyThread_AfterFork(
        state: ptr[u8]
    );  def _PyMem_obmalloc_state_on_heap(interp: ptr[u8]) -> bool;  def _PyEval_InitState(
        interp: ptr[u8]
    );  def _PyGC_InitState(gcstate: ptr[u8]);  def _PyType_InitCache(
        interp: ptr[u8]
    );  def _PySys_Audit(
        tstate: ptr[PyThreadState], event: ptr[u8], format_: ptr[u8], *args: any
    ) -> i32;  def _PyErr_Clear(tstate: ptr[PyThreadState]);  def _PyErr_Print(
        tstate: ptr[PyThreadState]
    );  def _PyCodec_Fini(interp: ptr[u8]);  def _PyAST_Fini(interp: ptr[u8]);  def _PyAtExit_Fini(
        interp: ptr[u8]
    );  def _PyGC_CollectNoFail(tstate: ptr[PyThreadState]);  def _PyGC_Fini(
        interp: ptr[u8]
    );  def _PyWarnings_Fini(interp: ptr[u8]);  def _PyImport_ClearCore(
        interp: ptr[u8]
    );  def _PyImport_GetModulesRef(interp: ptr[u8]) -> ptr[PyObject];  def _PyInterpreterState_FinalizeAllocatedBlocks(
        interp: ptr[u8]
    );  def _Py_qsbr_fini(interp: ptr[u8]);  def _PyObject_FiniState(interp: ptr[u8]);  def Py_ExitStatusException(
        status: PyStatus
    );  def Py_EndInterpreter(tstate: ptr[PyThreadState]);  def PyMapping_GetOptionalItem(
        obj_: ptr[PyObject], key: ptr[PyObject], result: &mut ptr[PyObject]
    ) -> i32;  def _PyErr_SetModuleNotFoundError(name: ptr[PyObject]) -> i32;  def PyErr_SetImportError(
        msg: ptr[PyObject], name: ptr[PyObject], path: ptr[PyObject]
    ) -> ptr[PyObject];  def _PyObject_VirtualAlloc(size: u64) -> ptr;  def _PyObject_VirtualFree(
        obj_: ptr, size: u64
    );  def _Py_InitializeRecursionLimits(tstate: ptr[PyThreadState]);  def _PyEval_AcquireLock(
        tstate: ptr[PyThreadState]
    );  def _PyEval_ReleaseLock(
        interp: ptr[u8], tstate: ptr[PyThreadState], final_release: i32
    );  def _PyCriticalSection_Resume(tstate: ptr[PyThreadState]);  def _PyCriticalSection_SuspendAll(
        tstate: ptr[PyThreadState]
    );  def _PyMem_AbandonDelayed(tstate: ptr[PyThreadState]);  def _PyEvent_Notify(
        evt: ptr[u8]
    );  def _PyFrame_MakeAndSetFrameObject(frame: ptr[u8]) -> ptr[PyObject];  def _PyEval_EvalFrameDefault(
        tstate: ptr[PyThreadState], frame: ptr[u8], throwflag: i32
    ) -> ptr[PyObject];  def _PyErr_GetTopmostException(
        tstate: ptr[PyThreadState]
    ) -> ptr[u8];  def _Py_FatalErrorFunc(func: ptr[u8], message: ptr[u8]);  def _Py_FatalErrorFormat(
        func: ptr[u8], format: ptr[u8], *args: any
    );  glob PyExc_InterpreterError: ptr[PyObject],
         PyExc_InterpreterNotFoundError: ptr[PyObject]; glob:priv runtime_initial_image:
             i64 = 0;
}

glob:priv STATUS_INITIALIZED: Final[u32] = 1,
     STATUS_BOUND: Final[u32] = 2,
     STATUS_UNBOUND: Final[u32] = 4,
     STATUS_BOUND_GILSTATE: Final[u32] = 8,
     STATUS_ACTIVE: Final[u32] = 16,
     STATUS_FINALIZING: Final[u32] = 32,
     STATUS_CLEARED: Final[u32] = 64,
     STATUS_FINALIZED: Final[u32] = 128,
     MINIMUM_OVERHEAD: Final[i64] = 1000,
     WORD: Final[i64] = 8;

def ld_p(addr: ptr[u8]) -> ptr[u8];

def st_p(addr: ptr[u8], value: ptr[u8]);

def ld_t(addr: ptr[u8]) -> ptr[PyThreadState];

def st_t(addr: ptr[u8], value: ptr[PyThreadState]);

def ld_o(addr: ptr[u8]) -> ptr[PyObject];

def st_o(addr: ptr[u8], value: ptr[PyObject]);

def ld_i32(addr: ptr[u8]) -> i32;

def st_i32(addr: ptr[u8], value: i32);

def ld_i64(addr: ptr[u8]) -> i64;

def st_i64(addr: ptr[u8], value: i64);

def ld_u64(addr: ptr[u8]) -> u64;

def st_u64(addr: ptr[u8], value: u64);

def ld_u8(addr: ptr[u8]) -> u8;

def st_u8(addr: ptr[u8], value: u8);

def clear_slot(addr: ptr[u8]);

def runtime_addr -> ptr[u8];

def main_interpreter_addr -> ptr[u8];

def ts_interp(tstate: ptr[PyThreadState]) -> ptr[u8];

def interp_runtime(interp: ptr[u8]) -> ptr[u8];

def ts_runtime(tstate: ptr[PyThreadState]) -> ptr[u8];

def status_has(tstate: ptr[PyThreadState], bit: u32) -> bool;

def status_set(tstate: ptr[PyThreadState], bit: u32);

def status_unset(tstate: ptr[PyThreadState], bit: u32);

def pystatus_ok -> PyStatus;

def pystatus_error(func: ptr[u8], msg: ptr[u8]) -> PyStatus;

def pystatus_failed(status: PyStatus) -> bool;

def llist_init(head: ptr[u8]);

def llist_concat(head1: ptr[u8], head2: ptr[u8]);

def tss_slot -> ptr[ptr[PyThreadState]];

def current_fast_get -> ptr[PyThreadState];

def current_fast_set(tstate: ptr[PyThreadState]);

def current_fast_clear;

def tstate_verify_not_active(tstate: ptr[PyThreadState], func: ptr[u8]);

import from c {
    def _PyThreadState_GetCurrent -> ptr[PyThreadState] {
        return current_fast_get();
    }
}

def gilstate_key(runtime: ptr[u8]) -> ptr[u8];

def tstate_tss_reinit(key: ptr[u8]) -> PyStatus;

def gilstate_tss_get(runtime: ptr[u8]) -> ptr[PyThreadState];

def gilstate_tss_set(runtime: ptr[u8], tstate: ptr[PyThreadState]);

def gilstate_tss_clear(runtime: ptr[u8]);

def bind_tstate(tstate: ptr[PyThreadState]);

def unbind_tstate(tstate: ptr[PyThreadState]);

def bind_gilstate_tstate(tstate: ptr[PyThreadState]);

def unbind_gilstate_tstate(tstate: ptr[PyThreadState]);

def holds_gil(tstate: ptr[PyThreadState]) -> bool;

def init_runtime(
    runtime: ptr[u8],
    open_code_hook: ptr[u8],
    open_code_userdata: ptr[u8],
    audit_hook_head: ptr[u8],
    unicode_next_index: i64
);

def initial_image -> int;

def initial_main_interpreter -> int;

def runtime_fini(runtime: ptr[u8]);

import from c {
    def _PyRuntimeState_Init(runtime_: ptr[_PyRuntimeState]) -> PyStatus {
        runtime = ptr[u8](runtime_);
        if initial_image() == 0 {
            image = malloc(u64(_PyRuntimeState_SIZE));
            if not image {
                return pystatus_error(
                    ptr[u8]("_PyRuntimeState_Init"), ptr[u8]("memory allocation failed")
                );
            }
            memcpy(image, ptr(runtime_), u64(_PyRuntimeState_SIZE));
            __atomic_store_i64(int(addressof(runtime_initial_image)), int(image), 5);
        }

        open_code_hook = ld_p(runtime + _PyRuntimeState_OPEN_CODE_HOOK);
        open_code_userdata = ld_p(runtime + _PyRuntimeState_OPEN_CODE_USERDATA);
        audit_hook_head = ld_p(runtime + _PyRuntimeState_AUDIT_HOOKS_HEAD);
        unicode_next_index = ld_i64(runtime + _PyRuntimeState_UNICODE_IDS_NEXT_INDEX);

        if ld_i32(runtime + _PyRuntimeState__INITIALIZED) != 0 {
            memcpy(ptr(runtime_), ptr[u8](initial_image()), u64(_PyRuntimeState_SIZE));
            memcpy(
                ptr[u8](runtime + _PyRuntimeState_DEBUG_OFFSETS_COOKIE),
                ptr[u8]("xdebugpy"),
                u64(8)
            );
        }

        status = _PyTime_Init(ptr[u8](runtime + _PyRuntimeState_TIME));
        if pystatus_failed(status) {
            return status;
        }

        if PyThread_tss_create(gilstate_key(runtime)) != 0 {
            runtime_fini(runtime);
            return pystatus_error(
                ptr[u8]("_PyRuntimeState_Init"), ptr[u8]("memory allocation failed")
            );
        }

        if PyThread_tss_create(ptr[u8](runtime + _PyRuntimeState_TRASHTSSKEY)) != 0 {
            runtime_fini(runtime);
            return pystatus_error(
                ptr[u8]("_PyRuntimeState_Init"), ptr[u8]("memory allocation failed")
            );
        }

        init_runtime(
            runtime,
            open_code_hook,
            open_code_userdata,
            audit_hook_head,
            unicode_next_index
        );

        return pystatus_ok();
    }  def _PyRuntimeState_Fini(runtime_: ptr[_PyRuntimeState]) {
        runtime_fini(ptr[u8](runtime_));
    }  def _PyRuntimeState_ReInitThreads(runtime_: ptr[_PyRuntimeState]) -> PyStatus {
        runtime = ptr[u8](runtime_);
        st_u64(runtime + _PyRuntimeState_MAIN_THREAD, PyThread_get_thread_ident());

        _PyParkingLot_AfterFork();

        main_interp = runtime + _PyRuntimeState_MAIN_INTERPRETER;
        st_u8(runtime + _PyRuntimeState_INTERPRETERS_MUTEX, u8(0));
        st_u8(runtime + _PyRuntimeState_XI_DATA_LOOKUP_REGISTRY_MUTEX, u8(0));
        st_u8(runtime + _PyRuntimeState_UNICODE_IDS_MUTEX, u8(0));
        st_u8(runtime + _PyRuntimeState_IMPORTS_EXTENSIONS_MUTEX, u8(0));
        st_u8(runtime + _PyRuntimeState_CEVAL_PENDING_MAINTHREAD_MUTEX, u8(0));
        st_u8(runtime + _PyRuntimeState_ATEXIT_MUTEX, u8(0));
        st_u8(runtime + _PyRuntimeState_AUDIT_HOOKS_MUTEX, u8(0));
        st_u8(runtime + _PyRuntimeState_ALLOCATORS_MUTEX, u8(0));
        st_u8(main_interp + PyInterpreterState_TYPES_MUTEX, u8(0));
        st_u8(main_interp + PyInterpreterState_CODE_STATE_MUTEX, u8(0));
        st_u8(main_interp + PyInterpreterState_DICT_STATE_WATCHER_MUTEX, u8(0));

        _PyTypes_AfterFork();

        status = tstate_tss_reinit(gilstate_key(runtime));
        if pystatus_failed(status) {
            return status;
        }

        trash = ptr[u8](runtime + _PyRuntimeState_TRASHTSSKEY);
        if PyThread_tss_is_created(trash) != 0 {
            PyThread_tss_delete(trash);
        }
        if PyThread_tss_create(trash) != 0 {
            return pystatus_error(
                ptr[u8]("_PyRuntimeState_ReInitThreads"),
                ptr[u8]("memory allocation failed")
            );
        }

        _PyThread_AfterFork(ptr[u8](runtime + _PyRuntimeState_THREADS));

        return pystatus_ok();
    }  def _PyInterpreterState_Enable(runtime_: ptr[_PyRuntimeState]) -> PyStatus {
        st_i64(ptr[u8](runtime_) + _PyRuntimeState_INTERPRETERS_NEXT_ID, 0);
        return pystatus_ok();
    }
}

def alloc_interpreter -> ptr[u8];

def free_interpreter(interp: ptr[u8]);

def init_interpreter(
    interp: ptr[u8], runtime: ptr[u8], id: i64, next: ptr[u8], whence: i64
) -> PyStatus;

import from c {
    def _PyInterpreterState_New(
        tstate: ptr[PyThreadState], pinterp: ptr[ptr[u8]]
    ) -> PyStatus {
        pinterp.view(1)[0] = ptr[u8]();

        runtime = runtime_addr();

        if tstate {
            if _PySys_Audit(
                tstate, ptr[u8]("cpython.PyInterpreterState_New"), ptr[u8]()
            )
                < 0 {
                return pystatus_error(
                    ptr[u8]("_PyInterpreterState_New"), ptr[u8]("sys.audit failed")
                );
            }
        }

        head_lock(ptr[u8](runtime));

        id = ld_i64(runtime + _PyRuntimeState_INTERPRETERS_NEXT_ID);
        st_i64(runtime + _PyRuntimeState_INTERPRETERS_NEXT_ID, id + 1);

        interp = ptr[u8]();
        old_head = ld_p(runtime + _PyRuntimeState_INTERPRETERS_HEAD);
        if not old_head {
            interp = ptr[u8](runtime + _PyRuntimeState_MAIN_INTERPRETER);
            st_p(runtime + _PyRuntimeState_INTERPRETERS_MAIN, interp);
        } else {
            interp = alloc_interpreter();
            if not interp {
                head_unlock(ptr[u8](runtime));
                return pystatus_error(
                    ptr[u8]("_PyInterpreterState_New"),
                    ptr[u8]("memory allocation failed")
                );
            }
            memcpy(
                ptr(interp),
                ptr[u8](initial_main_interpreter()),
                u64(PyInterpreterState_SIZE)
            );
            if id < 0 {
                head_unlock(ptr[u8](runtime));
                free_interpreter(interp);
                return pystatus_error(
                    ptr[u8]("_PyInterpreterState_New"),
                    ptr[u8]("failed to get an interpreter ID")
                );
            }
        }
        st_p(runtime + _PyRuntimeState_INTERPRETERS_HEAD, interp);

        status = init_interpreter(
            interp, runtime, id, old_head, _PyInterpreterState_WHENCE_UNKNOWN
        );
        if pystatus_failed(status) {
            head_unlock(ptr[u8](runtime));
            free_interpreter(interp);
            return status;
        }

        head_unlock(ptr[u8](runtime));

        pinterp.view(1)[0] = interp;
        return pystatus_ok();
    }  def PyInterpreterState_New -> ptr[u8] {
        tstate = current_fast_get();

        slot = ptr[ptr[u8]](PyMem_RawCalloc(u64(1), u64(WORD)));
        if not slot {
            Py_ExitStatusException(
                pystatus_error(
                    ptr[u8]("PyInterpreterState_New"),
                    ptr[u8]("memory allocation failed")
                )
            );
        }
        status = _PyInterpreterState_New(tstate, slot);
        interp = slot.view(1)[0];
        PyMem_RawFree(ptr(slot));
        if pystatus_failed(status) {
            Py_ExitStatusException(status);
        }
        return interp;
    }
}

def interpreter_clear(interp: ptr[u8], tstate: ptr[PyThreadState]);

import from c {
    def PyInterpreterState_Clear(interp: ptr[u8]) {
        current_tstate = current_fast_get();
        _PyImport_ClearCore(interp);
        interpreter_clear(interp, current_tstate);
    }  def _PyInterpreterState_Clear(tstate: ptr[PyThreadState]) {
        _PyImport_ClearCore(ts_interp(tstate));
        interpreter_clear(ts_interp(tstate), tstate);
    }  def PyInterpreterState_Delete(interp: ptr[u8]) {
        runtime = interp_runtime(interp);

        tcur = current_fast_get();
        if tcur and interp == ts_interp(tcur) {
            _PyThreadState_Detach(tcur);
        }

        zapthreads(interp);

        _PyInterpreterState_FinalizeAllocatedBlocks(interp);

        head_lock(ptr[u8](runtime));
        p = runtime + _PyRuntimeState_INTERPRETERS_HEAD;
        while True {
            current = ld_p(p);
            if not current {
                _Py_FatalErrorFunc(
                    ptr[u8]("PyInterpreterState_Delete"), ptr[u8]("NULL interpreter")
                );
            }
            if current == interp {
                break;
            }
            p = ptr[u8](current) + PyInterpreterState_NEXT;
        }
        if ld_t(ptr[u8](interp) + PyInterpreterState_THREADS_HEAD) {
            _Py_FatalErrorFunc(
                ptr[u8]("PyInterpreterState_Delete"), ptr[u8]("remaining threads")
            );
        }
        st_p(p, ld_p(ptr[u8](interp) + PyInterpreterState_NEXT));

        if ld_p(runtime + _PyRuntimeState_INTERPRETERS_MAIN) == interp {
            st_p(runtime + _PyRuntimeState_INTERPRETERS_MAIN, ptr[u8]());
            if ld_p(runtime + _PyRuntimeState_INTERPRETERS_HEAD) {
                _Py_FatalErrorFunc(
                    ptr[u8]("PyInterpreterState_Delete"),
                    ptr[u8]("remaining subinterpreters")
                );
            }
        }
        head_unlock(ptr[u8](runtime));

        _Py_qsbr_fini(interp);

        _PyObject_FiniState(interp);

        PyConfig_Clear(ptr[u8](ptr[u8](interp) + PyInterpreterState_CONFIG));

        free_interpreter(interp);
    }  def _PyInterpreterState_DeleteExceptMain(
        runtime_: ptr[_PyRuntimeState]
    ) -> PyStatus {
        runtime = ptr[u8](runtime_);

        tstate = _PyThreadState_Swap(runtime_, ptr[PyThreadState]());
        main_interp = ld_p(runtime + _PyRuntimeState_INTERPRETERS_MAIN);
        if tstate and ts_interp(tstate) != main_interp {
            return pystatus_error(
                ptr[u8]("_PyInterpreterState_DeleteExceptMain"),
                ptr[u8]("not main interpreter")
            );
        }

        head_lock(ptr[u8](runtime));
        interp = ld_p(runtime + _PyRuntimeState_INTERPRETERS_HEAD);
        st_p(runtime + _PyRuntimeState_INTERPRETERS_HEAD, ptr[u8]());
        while interp {
            main_interp = ld_p(runtime + _PyRuntimeState_INTERPRETERS_MAIN);
            if interp == main_interp {
                st_p(ptr[u8](main_interp) + PyInterpreterState_NEXT, ptr[u8]());
                st_p(runtime + _PyRuntimeState_INTERPRETERS_HEAD, interp);
                interp = ld_p(ptr[u8](interp) + PyInterpreterState_NEXT);
                continue;
            }

            PyInterpreterState_Clear(interp);
            zapthreads(interp);
            prev_interp = interp;
            interp = ld_p(ptr[u8](interp) + PyInterpreterState_NEXT);
            free_interpreter(prev_interp);
        }
        head_unlock(ptr[u8](runtime));

        if not ld_p(runtime + _PyRuntimeState_INTERPRETERS_HEAD) {
            return pystatus_error(
                ptr[u8]("_PyInterpreterState_DeleteExceptMain"),
                ptr[u8]("missing main interpreter")
            );
        }
        _PyThreadState_Swap(runtime_, tstate);
        return pystatus_ok();
    }
}

def set_main_thread(interp: ptr[u8], tstate: ptr[PyThreadState]);

def get_main_thread(interp: ptr[u8]) -> ptr[PyThreadState];

import from c {
    def _PyErr_SetInterpreterAlreadyRunning {
        PyErr_SetString(PyExc_InterpreterError, ptr[u8]("interpreter already running"));
    }  def _PyInterpreterState_SetRunningMain(interp: ptr[u8]) -> i32 {
        if get_main_thread(interp) {
            _PyErr_SetInterpreterAlreadyRunning();
            return -1;
        }
        tstate = current_fast_get();
        ensure_tstate_not_null(ptr[u8]("_PyInterpreterState_SetRunningMain"), tstate);
        if ts_interp(tstate) != interp {
            PyErr_SetString(
                PyExc_RuntimeError, ptr[u8]("current tstate has wrong interpreter")
            );
            return -1;
        }
        set_main_thread(interp, tstate);

        return 0;
    }  def _PyInterpreterState_SetNotRunningMain(interp: ptr[u8]) {
        set_main_thread(interp, ptr[PyThreadState]());
    }  def _PyInterpreterState_IsRunningMain(interp: ptr[u8]) -> i32 {
        if get_main_thread(interp) {
            return 1;
        }
        return 0;
    }  def _PyThreadState_IsRunningMain(tstate: ptr[PyThreadState]) -> i32 {
        if get_main_thread(ts_interp(tstate)) == tstate {
            return 1;
        }
        return 0;
    }  def _PyInterpreterState_ReinitRunningMain(tstate: ptr[PyThreadState]) {
        interp = ts_interp(tstate);
        if get_main_thread(interp) != tstate {
            set_main_thread(interp, ptr[PyThreadState]());
        }
    }  def _PyInterpreterState_IsReady(interp: ptr[u8]) -> i32 {
        return ld_i32(ptr[u8](interp) + PyInterpreterState__READY);
    }  def _PyInterpreterState_GetWhence(interp: ptr[u8]) -> i64 {
        return ld_i64(ptr[u8](interp) + PyInterpreterState__WHENCE);
    }  def _PyInterpreterState_SetWhence(interp: ptr[u8], whence: i64) {
        st_i64(ptr[u8](interp) + PyInterpreterState__WHENCE, whence);
    }  def _Py_GetMainModule(tstate: ptr[PyThreadState]) -> ptr[PyObject] {
        modules = _PyImport_GetModulesRef(ts_interp(tstate));
        if modules == py_none() {
            return modules;
        }
        module = NULL;
        PyMapping_GetOptionalItem(modules, py_id(_Py_ID___main__), &mut module);
        object_decref(modules);
        if not module and not PyErr_Occurred() {
            return object_new_ref(py_none());
        }
        return module;
    }  def _Py_CheckMainModule(module: ptr[PyObject]) -> i32 {
        if not module or module == py_none() {
            if not PyErr_Occurred() {
                _PyErr_SetModuleNotFoundError(py_id(_Py_ID___main__));
            }
            return -1;
        }
        if ptr[PyObject](object_type(module)) != addressof(PyModule_Type) {
            msg = PyUnicode_FromString(ptr[u8]("invalid __main__ module"));
            if msg {
                PyErr_SetImportError(msg, py_id(_Py_ID___main__), NULL);
                object_decref(msg);
            }
            return -1;
        }
        return 0;
    }  def PyInterpreterState_GetDict(interp: ptr[u8]) -> ptr[PyObject] {
        slot = ptr[u8](interp) + PyInterpreterState_DICT;
        if not ld_o(slot) {
            st_o(slot, PyDict_New());
            if not ld_o(slot) {
                PyErr_Clear();
            }
        }
        return ld_o(slot);
    }  def _PyInterpreterState_ObjectToID(idobj: ptr[PyObject]) -> i64 {
        if PyIndex_Check(idobj) == 0 {
            PyErr_Format(
                PyExc_TypeError,
                ptr[u8]("interpreter ID must be an int, got %.100s"),
                object_type(idobj).view(1)[0].tp_name
            );
            return -1;
        }

        id = PyLong_AsLongLong(idobj);
        if id == -1 and PyErr_Occurred() {
            return -1;
        }

        if id < 0 {
            PyErr_Format(
                PyExc_ValueError,
                ptr[u8]("interpreter ID must be a non-negative int, got %R"),
                idobj
            );
            return -1;
        }
        return id;
    }  def PyInterpreterState_GetID(interp: ptr[u8]) -> i64 {
        if not interp {
            PyErr_SetString(PyExc_RuntimeError, ptr[u8]("no interpreter provided"));
            return -1;
        }
        return ld_i64(ptr[u8](interp) + PyInterpreterState_ID);
    }  def _PyInterpreterState_GetIDObject(interp: ptr[u8]) -> ptr[PyObject] {
        interpid = ld_i64(ptr[u8](interp) + PyInterpreterState_ID);
        if interpid < 0 {
            return NULL;
        }
        return PyLong_FromLongLong(interpid);
    }  def _PyInterpreterState_IDIncref(interp: ptr[u8]) {
        __atomic_add_i64(int(ptr[u8](interp) + PyInterpreterState_ID_REFCOUNT), 1, 5);
    }  def _PyInterpreterState_IDDecref(interp: ptr[u8]) {
        runtime = interp_runtime(interp);

        refcount = __atomic_add_i64(
            int(ptr[u8](interp) + PyInterpreterState_ID_REFCOUNT), -1, 5
        );

        if refcount == 1
            and ld_i32(ptr[u8](interp) + PyInterpreterState_REQUIRES_IDREF) != 0 {
            tstate = _PyThreadState_NewBound(interp, _PyThreadState_WHENCE_FINI);

            save_tstate = _PyThreadState_Swap(ptr[_PyRuntimeState](runtime), tstate);
            Py_EndInterpreter(tstate);
            _PyThreadState_Swap(ptr[_PyRuntimeState](runtime), save_tstate);
        }
    }  def _PyInterpreterState_RequiresIDRef(interp: ptr[u8]) -> i32 {
        return ld_i32(ptr[u8](interp) + PyInterpreterState_REQUIRES_IDREF);
    }  def _PyInterpreterState_RequireIDRef(interp: ptr[u8], required: i32) {
        value = i32(0);
        if required != 0 {
            value = i32(1);
        }
        st_i32(ptr[u8](interp) + PyInterpreterState_REQUIRES_IDREF, value);
    }  def PyInterpreterState_Get -> ptr[u8] {
        tstate = current_fast_get();
        ensure_tstate_not_null(ptr[u8]("PyInterpreterState_Get"), tstate);
        interp = ts_interp(tstate);
        if not interp {
            _Py_FatalErrorFunc(
                ptr[u8]("PyInterpreterState_Get"), ptr[u8]("no current interpreter")
            );
        }
        return interp;
    }
}

def interp_look_up_id(runtime: ptr[u8], requested_id: i64) -> ptr[u8];

import from c {
    def _PyInterpreterState_LookUpID(requested_id: i64) -> ptr[u8] {
        interp = ptr[u8]();
        if requested_id >= 0 {
            runtime = runtime_addr();
            head_lock(ptr[u8](runtime));
            interp = interp_look_up_id(runtime, requested_id);
            head_unlock(ptr[u8](runtime));
        }
        if not interp and not PyErr_Occurred() {
            PyErr_Format(
                PyExc_InterpreterNotFoundError,
                ptr[u8]("unrecognized interpreter ID %lld"),
                requested_id
            );
        }
        return interp;
    }  def _PyInterpreterState_LookUpIDObject(requested_id: ptr[PyObject]) -> ptr[u8] {
        id = _PyInterpreterState_ObjectToID(requested_id);
        if id < 0 {
            return ptr[u8]();
        }
        return _PyInterpreterState_LookUpID(id);
    }
}

def allocate_chunk(size_in_bytes: i64, previous: ptr[u8]) -> ptr[u8];

def reset_threadstate(tstate: ptr[u8]);

def alloc_threadstate(interp: ptr[u8]) -> ptr[u8];

def free_threadstate(tstate: ptr[u8]);

def decref_threadstate(tstate: ptr[u8]);

def init_threadstate(raw: ptr[u8], interp: ptr[u8], id: u64, whence: i32);

def add_threadstate(
    interp: ptr[u8], tstate: ptr[PyThreadState], next: ptr[PyThreadState]
);

def new_threadstate(interp: ptr[u8], whence: i32) -> ptr[PyThreadState];

import from c {
    def PyThreadState_New(interp: ptr[u8]) -> ptr[PyThreadState] {
        return _PyThreadState_NewBound(interp, _PyThreadState_WHENCE_UNKNOWN);
    }  def _PyThreadState_NewBound(interp: ptr[u8], whence: i32) -> ptr[PyThreadState] {
        tstate = new_threadstate(interp, whence);
        if tstate {
            bind_tstate(tstate);
            if not gilstate_tss_get(ts_runtime(tstate)) {
                bind_gilstate_tstate(tstate);
            }
        }
        return tstate;
    }  def _PyThreadState_New(interp: ptr[u8], whence: i32) -> ptr[PyThreadState] {
        return new_threadstate(interp, whence);
    }  def _PyThreadState_Prealloc(interp: ptr[u8]) -> ptr[PyThreadState] {
        return _PyThreadState_New(interp, _PyThreadState_WHENCE_UNKNOWN);
    }  def _PyThreadState_Init(tstate: ptr[PyThreadState]) {
        _Py_FatalErrorFunc(
            ptr[u8]("_PyThreadState_Init"),
            ptr[u8]("_PyThreadState_Init() is for internal use only")
        );
    }
}

def clear_datastack(tstate: ptr[PyThreadState]);

def decrement_stoptheworld_countdown(stw: ptr[u8]);

import from c {
    def PyThreadState_Clear(tstate: ptr[PyThreadState]) {
        base = ptr[u8](tstate);
        status_set(tstate, STATUS_FINALIZING);

        interp = ts_interp(tstate);
        verbose = ld_i32(
            ptr[u8](interp) + PyInterpreterState_CONFIG + PyConfig_VERBOSE
        );

        if verbose != 0 and ld_p(base + PyThreadState_CURRENT_FRAME) {
            fputs(
                ptr[u8]("PyThreadState_Clear: warning: thread still has a frame\n"),
                jacpy_stdio_stream(i32(2))
            );
        }

        if verbose != 0 and ld_o(base + PyThreadState_CURRENT_EXCEPTION) {
            fputs(
                ptr[u8]("PyThreadState_Clear: warning: thread has an exception set\n"),
                jacpy_stdio_stream(i32(2))
            );
            _PyErr_Print(tstate);
        }

        clear_slot(base + PyThreadState_THREADING_LOCAL_KEY);
        clear_slot(base + PyThreadState_THREADING_LOCAL_SENTINEL);

        clear_slot(base + _PyThreadStateImpl_ASYNCIO_RUNNING_LOOP);
        clear_slot(base + _PyThreadStateImpl_ASYNCIO_RUNNING_TASK);

        lock = ptr[PyMutex](ptr[u8](interp) + PyInterpreterState_ASYNCIO_TASKS_LOCK);
        PyMutex_Lock(lock);
        llist_concat(
            ptr[u8](interp) + PyInterpreterState_ASYNCIO_TASKS_HEAD,
            base + _PyThreadStateImpl_ASYNCIO_TASKS_HEAD
        );
        PyMutex_Unlock(lock);

        clear_slot(base + PyThreadState_DICT);
        clear_slot(base + PyThreadState_ASYNC_EXC);

        clear_slot(base + PyThreadState_CURRENT_EXCEPTION);

        clear_slot(base + PyThreadState_EXC_STATE + _PyErr_StackItem_EXC_VALUE);

        if verbose != 0
            and ld_p(base + PyThreadState_EXC_INFO) != base + PyThreadState_EXC_STATE {
            fputs(
                ptr[u8]("PyThreadState_Clear: warning: thread still has a generator\n"),
                jacpy_stdio_stream(i32(2))
            );
        }

        if ld_p(base + PyThreadState_C_PROFILEFUNC) {
            slot = ptr[u8](interp) + PyInterpreterState_SYS_PROFILING_THREADS;
            st_i64(slot, ld_i64(slot) - 1);
            st_p(base + PyThreadState_C_PROFILEFUNC, ptr[u8]());
        }
        if ld_p(base + PyThreadState_C_TRACEFUNC) {
            slot = ptr[u8](interp) + PyInterpreterState_SYS_TRACING_THREADS;
            st_i64(slot, ld_i64(slot) - 1);
            st_p(base + PyThreadState_C_TRACEFUNC, ptr[u8]());
        }

        clear_slot(base + PyThreadState_C_PROFILEOBJ);
        clear_slot(base + PyThreadState_C_TRACEOBJ);

        clear_slot(base + PyThreadState_ASYNC_GEN_FIRSTITER);
        clear_slot(base + PyThreadState_ASYNC_GEN_FINALIZER);

        clear_slot(base + PyThreadState_CONTEXT);

        _PyMem_AbandonDelayed(tstate);

        _PyThreadState_ClearMimallocHeaps(tstate);

        status_set(tstate, STATUS_CLEARED);
    }
}

def tstate_delete_common(tstate: ptr[PyThreadState], release_gil: i32, func: ptr[u8]);

def zapthreads(interp: ptr[u8]);

import from c {
    def PyThreadState_Delete(tstate: ptr[PyThreadState]) {
        ensure_tstate_not_null(ptr[u8]("PyThreadState_Delete"), tstate);
        tstate_delete_common(tstate, 0, ptr[u8]("PyThreadState_Delete"));
        free_threadstate(ptr[u8](tstate));
    }  def _PyThreadState_DeleteCurrent(tstate: ptr[PyThreadState]) {
        ensure_tstate_not_null(ptr[u8]("_PyThreadState_DeleteCurrent"), tstate);
        current_fast_clear();
        tstate_delete_common(tstate, 1, ptr[u8]("_PyThreadState_DeleteCurrent"));
        free_threadstate(ptr[u8](tstate));
    }  def PyThreadState_DeleteCurrent {
        _PyThreadState_DeleteCurrent(current_fast_get());
    }  def _PyThreadState_RemoveExcept(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyThreadState] {
        interp = ts_interp(tstate);
        runtime = ptr[u8](interp_runtime(interp));

        head_lock(runtime);
        lst = ld_t(ptr[u8](interp) + PyInterpreterState_THREADS_HEAD);
        next = ld_t(ptr[u8](tstate) + PyThreadState_NEXT);
        prev = ld_t(ptr[u8](tstate) + PyThreadState_PREV);
        if lst == tstate {
            lst = next;
        }
        if prev {
            st_t(ptr[u8](prev) + PyThreadState_NEXT, next);
        }
        if next {
            st_t(ptr[u8](next) + PyThreadState_PREV, prev);
        }
        st_t(ptr[u8](tstate) + PyThreadState_PREV, ptr[PyThreadState]());
        st_t(ptr[u8](tstate) + PyThreadState_NEXT, ptr[PyThreadState]());
        st_t(ptr[u8](interp) + PyInterpreterState_THREADS_HEAD, tstate);
        head_unlock(runtime);

        return lst;
    }  def _PyThreadState_DeleteList(list_: ptr[PyThreadState], is_after_fork: i32) {
        p = list_;
        while p {
            next = ld_t(ptr[u8](p) + PyThreadState_NEXT);
            PyThreadState_Clear(p);
            if is_after_fork != 0 {
                free_threadstate(ptr[u8](p));
            } else {
                decref_threadstate(ptr[u8](p));
            }
            p = next;
        }
    }  def _PyThreadState_GetDict(tstate: ptr[PyThreadState]) -> ptr[PyObject] {
        slot = ptr[u8](tstate) + PyThreadState_DICT;
        if not ld_o(slot) {
            st_o(slot, PyDict_New());
            if not ld_o(slot) {
                _PyErr_Clear(tstate);
            }
        }
        return ld_o(slot);
    }  def PyThreadState_GetDict -> ptr[PyObject] {
        tstate = current_fast_get();
        if not tstate {
            return NULL;
        }
        return _PyThreadState_GetDict(tstate);
    }  def PyThreadState_GetInterpreter(tstate: ptr[PyThreadState]) -> ptr[u8] {
        return ts_interp(tstate);
    }  def PyThreadState_GetFrame(tstate: ptr[PyThreadState]) -> ptr[PyObject] {
        f = iframe_first_complete(ld_p(ptr[u8](tstate) + PyThreadState_CURRENT_FRAME));
        if not f {
            return NULL;
        }
        frame = frame_object_of(f);
        if not frame {
            PyErr_Clear();
            return NULL;
        }
        return object_new_ref(frame);
    }  def PyThreadState_GetID(tstate: ptr[PyThreadState]) -> u64 {
        return ld_u64(ptr[u8](tstate) + PyThreadState_ID);
    }
}

def frame_object_of(frame: ptr[u8]) -> ptr[PyObject];

def tstate_activate(tstate: ptr[PyThreadState]);

def tstate_deactivate(tstate: ptr[PyThreadState]);

def detach_thread(tstate: ptr[PyThreadState], detached_state: i32);

import from c {
    def _PyThreadState_Attach(tstate: ptr[PyThreadState]) {
        ensure_tstate_not_null(ptr[u8]("_PyThreadState_Attach"), tstate);
        if current_fast_get() {
            _Py_FatalErrorFunc(
                ptr[u8]("_PyThreadState_Attach"), ptr[u8]("non-NULL old thread state")
            );
        }
        if ld_u64(ptr[u8](tstate) + _PyThreadStateImpl_C_STACK_HARD_LIMIT) == u64(0) {
            _Py_InitializeRecursionLimits(tstate);
        }

        _PyEval_AcquireLock(tstate);

        current_fast_set(tstate);
        st_i32(ptr[u8](tstate) + PyThreadState_STATE, _Py_THREAD_ATTACHED);
        tstate_activate(tstate);

        if ld_u64(ptr[u8](tstate) + PyThreadState_CRITICAL_SECTION) != u64(0) {
            _PyCriticalSection_Resume(tstate);
        }
    }  def _PyThreadState_Detach(tstate: ptr[PyThreadState]) {
        detach_thread(tstate, _Py_THREAD_DETACHED);
    }  def _PyThreadState_Suspend(tstate: ptr[PyThreadState]) {
        runtime = runtime_addr();

        stw = ptr[u8]();
        head_lock(ptr[u8](runtime));
        runtime_stw = runtime + _PyRuntimeState_STOPTHEWORLD;
        interp_stw = ts_interp(tstate) + PyInterpreterState_STOPTHEWORLD;
        if ld_u8(runtime_stw + _stoptheworld_state_REQUESTED) != u8(0) {
            stw = runtime_stw;
        } elif ld_u8(interp_stw + _stoptheworld_state_REQUESTED) != u8(0) {
            stw = interp_stw;
        }
        head_unlock(ptr[u8](runtime));

        if not stw {
            detach_thread(tstate, _Py_THREAD_DETACHED);
            return;
        }

        detach_thread(tstate, _Py_THREAD_SUSPENDED);

        head_lock(ptr[u8](runtime));
        decrement_stoptheworld_countdown(stw);
        head_unlock(ptr[u8](runtime));
    }  def _PyThreadState_SetShuttingDown(tstate: ptr[PyThreadState]) {
        __atomic_store_i32(
            int(ptr[u8](tstate) + PyThreadState_STATE), _Py_THREAD_SHUTTING_DOWN, 5
        );
    }  def _PyEval_StopTheWorldAll(runtime: ptr[_PyRuntimeState]) {
        return;
    }  def _PyEval_StartTheWorldAll(runtime: ptr[_PyRuntimeState]) {
        return;
    }  def _PyEval_StopTheWorld(interp: ptr[u8]) {
        return;
    }  def _PyEval_StartTheWorld(interp: ptr[u8]) {
        return;
    }  def PyThreadState_SetAsyncExc(id: u64, exc: ptr[PyObject]) -> i32 {
        interp = ts_interp(current_fast_get());

        tstate = ptr[PyThreadState]();
        runtime = ptr[u8](interp_runtime(interp));
        head_lock(runtime);
        t = ld_t(ptr[u8](interp) + PyInterpreterState_THREADS_HEAD);
        while t {
            if ld_u64(ptr[u8](t) + PyThreadState_THREAD_ID) == id {
                tstate = t;
                break;
            }
            t = ld_t(ptr[u8](t) + PyThreadState_NEXT);
        }
        head_unlock(runtime);

        if tstate {
            if exc {
                object_incref(exc);
            }
            old_exc = ptr[PyObject](
                __atomic_swap_i64(
                    int(ptr[u8](tstate) + PyThreadState_ASYNC_EXC), int(exc), 5
                )
            );

            object_xdecref(old_exc);
            set_eval_breaker_bit(tstate, _PY_ASYNC_EXCEPTION_BIT);
            return 1;
        }

        return 0;
    }  def PyThreadState_GetUnchecked -> ptr[PyThreadState] {
        return current_fast_get();
    }  def PyThreadState_Get -> ptr[PyThreadState] {
        tstate = current_fast_get();
        ensure_tstate_not_null(ptr[u8]("PyThreadState_Get"), tstate);
        return tstate;
    }  def _PyThreadState_Swap(
        runtime: ptr[_PyRuntimeState], newts: ptr[PyThreadState]
    ) -> ptr[PyThreadState] {
        oldts = current_fast_get();
        if oldts {
            _PyThreadState_Detach(oldts);
        }
        if newts {
            _PyThreadState_Attach(newts);
        }
        return oldts;
    }  def PyThreadState_Swap(newts: ptr[PyThreadState]) -> ptr[PyThreadState] {
        return _PyThreadState_Swap(addressof(_PyRuntime), newts);
    }  def _PyThreadState_Bind(tstate: ptr[PyThreadState]) {
        bind_tstate(tstate);
        if not gilstate_tss_get(ts_runtime(tstate)) {
            bind_gilstate_tstate(tstate);
        }
    }  def PyInterpreterState_Head -> ptr[u8] {
        return ld_p(runtime_addr() + _PyRuntimeState_INTERPRETERS_HEAD);
    }  def PyInterpreterState_Main -> ptr[u8] {
        return _PyInterpreterState_Main();
    }  def PyInterpreterState_Next(interp: ptr[u8]) -> ptr[u8] {
        return ld_p(ptr[u8](interp) + PyInterpreterState_NEXT);
    }  def PyInterpreterState_ThreadHead(interp: ptr[u8]) -> ptr[PyThreadState] {
        return ld_t(ptr[u8](interp) + PyInterpreterState_THREADS_HEAD);
    }  def PyThreadState_Next(tstate: ptr[PyThreadState]) -> ptr[PyThreadState] {
        return ld_t(ptr[u8](tstate) + PyThreadState_NEXT);
    }  def _PyThread_CurrentFrames -> ptr[PyObject] {
        runtime_ = addressof(_PyRuntime);
        runtime = ptr[u8](runtime_);
        tstate = current_fast_get();
        if _PySys_Audit(tstate, ptr[u8]("sys._current_frames"), ptr[u8]()) < 0 {
            return NULL;
        }

        result = PyDict_New();
        if not result {
            return NULL;
        }

        _PyEval_StopTheWorldAll(runtime_);
        head_lock(runtime);
        failed = False;
        i = ld_p(ptr[u8](runtime) + _PyRuntimeState_INTERPRETERS_HEAD);
        while i and not failed {
            t = ld_t(ptr[u8](i) + PyInterpreterState_THREADS_HEAD);
            while t {
                frame = iframe_first_complete(
                    ld_p(ptr[u8](t) + PyThreadState_CURRENT_FRAME)
                );
                if frame {
                    id = PyLong_FromUnsignedLong(
                        ld_u64(ptr[u8](t) + PyThreadState_THREAD_ID)
                    );
                    if not id {
                        failed = True;
                        break;
                    }
                    frameobj = frame_object_of(frame);
                    if not frameobj {
                        object_decref(id);
                        failed = True;
                        break;
                    }
                    stat = PyDict_SetItem(result, id, frameobj);
                    object_decref(id);
                    if stat < 0 {
                        failed = True;
                        break;
                    }
                }
                t = ld_t(ptr[u8](t) + PyThreadState_NEXT);
            }
            i = ld_p(ptr[u8](i) + PyInterpreterState_NEXT);
        }
        if failed {
            object_decref(result);
            result = NULL;
        }

        head_unlock(runtime);
        _PyEval_StartTheWorldAll(runtime_);
        return result;
    }  def _PyThread_CurrentExceptions -> ptr[PyObject] {
        runtime_ = addressof(_PyRuntime);
        runtime = ptr[u8](runtime_);
        tstate = current_fast_get();

        ensure_tstate_not_null(ptr[u8]("_PyThread_CurrentExceptions"), tstate);

        if _PySys_Audit(tstate, ptr[u8]("sys._current_exceptions"), ptr[u8]()) < 0 {
            return NULL;
        }

        result = PyDict_New();
        if not result {
            return NULL;
        }

        _PyEval_StopTheWorldAll(runtime_);
        head_lock(runtime);
        failed = False;
        i = ld_p(ptr[u8](runtime) + _PyRuntimeState_INTERPRETERS_HEAD);
        while i and not failed {
            t = ld_t(ptr[u8](i) + PyInterpreterState_THREADS_HEAD);
            while t {
                err_info = _PyErr_GetTopmostException(t);
                if err_info {
                    id = PyLong_FromUnsignedLong(
                        ld_u64(ptr[u8](t) + PyThreadState_THREAD_ID)
                    );
                    if not id {
                        failed = True;
                        break;
                    }
                    exc = ld_o(ptr[u8](err_info) + _PyErr_StackItem_EXC_VALUE);
                    if not exc {
                        exc = py_none();
                    }
                    stat = PyDict_SetItem(result, id, exc);
                    object_decref(id);
                    if stat < 0 {
                        failed = True;
                        break;
                    }
                }
                t = ld_t(ptr[u8](t) + PyThreadState_NEXT);
            }
            i = ld_p(ptr[u8](i) + PyInterpreterState_NEXT);
        }
        if failed {
            object_decref(result);
            result = NULL;
        }

        head_unlock(runtime);
        _PyEval_StartTheWorldAll(runtime_);
        return result;
    }  def _PyGILState_Init(interp: ptr[u8]) -> PyStatus {
        if interp != _PyInterpreterState_Main() {
            return pystatus_ok();
        }
        runtime = interp_runtime(interp);
        st_p(runtime + _PyRuntimeState_GILSTATE_AUTOINTERPRETERSTATE, interp);
        return pystatus_ok();
    }  def _PyGILState_Fini(interp: ptr[u8]) {
        if interp != _PyInterpreterState_Main() {
            return;
        }
        st_p(
            interp_runtime(interp) + _PyRuntimeState_GILSTATE_AUTOINTERPRETERSTATE,
            ptr[u8]()
        );
    }  def _PyGILState_SetTstate(tstate: ptr[PyThreadState]) {
        return;
    }  def _PyGILState_GetInterpreterStateUnsafe -> ptr[u8] {
        return ld_p(runtime_addr() + _PyRuntimeState_GILSTATE_AUTOINTERPRETERSTATE);
    }  def PyGILState_GetThisThreadState -> ptr[PyThreadState] {
        runtime = runtime_addr();
        if PyThread_tss_is_created(gilstate_key(runtime)) == 0 {
            return ptr[PyThreadState]();
        }
        return gilstate_tss_get(runtime);
    }  def PyGILState_Check -> i32 {
        runtime = runtime_addr();
        if ld_i32(runtime + _PyRuntimeState_GILSTATE_CHECK_ENABLED) == 0 {
            return 1;
        }

        if PyThread_tss_is_created(gilstate_key(runtime)) == 0 {
            return 1;
        }

        tstate = current_fast_get();
        if not tstate {
            return 0;
        }

        if tstate == gilstate_tss_get(runtime) {
            return 1;
        }
        return 0;
    }  def PyGILState_Ensure -> i32 {
        runtime = runtime_addr();

        tcur = gilstate_tss_get(runtime);
        has_gil = False;
        if not tcur {
            tcur = new_threadstate(
                ld_p(runtime + _PyRuntimeState_GILSTATE_AUTOINTERPRETERSTATE),
                _PyThreadState_WHENCE_GILSTATE
            );
            if not tcur {
                _Py_FatalErrorFunc(
                    ptr[u8]("PyGILState_Ensure"),
                    ptr[u8]("Couldn't create thread-state for new thread")
                );
            }
            bind_tstate(tcur);
            bind_gilstate_tstate(tcur);

            st_i32(ptr[u8](tcur) + PyThreadState_GILSTATE_COUNTER, i32(0));
        } else {
            has_gil = holds_gil(tcur);
        }

        if not has_gil {
            PyEval_RestoreThread(tcur);
        }

        counter = ptr[u8](tcur) + PyThreadState_GILSTATE_COUNTER;
        st_i32(counter, ld_i32(counter) + i32(1));

        if has_gil {
            return PyGILState_LOCKED;
        }
        return PyGILState_UNLOCKED;
    }  def PyGILState_Release(oldstate: i32) {
        runtime = runtime_addr();
        tstate = gilstate_tss_get(runtime);
        if not tstate {
            _Py_FatalErrorFunc(
                ptr[u8]("PyGILState_Release"),
                ptr[u8](
                    "auto-releasing thread-state, but no thread-state for this thread"
                )
            );
        }

        if not holds_gil(tstate) {
            _Py_FatalErrorFormat(
                ptr[u8]("PyGILState_Release"),
                ptr[u8]("thread state %p must be current when releasing"),
                ptr[u8](tstate)
            );
        }
        counter = ptr[u8](tstate) + PyThreadState_GILSTATE_COUNTER;
        st_i32(counter, ld_i32(counter) - i32(1));

        if ld_i32(counter) == 0 {
            st_i32(counter, ld_i32(counter) + i32(1));
            PyThreadState_Clear(tstate);
            st_i32(counter, ld_i32(counter) - i32(1));
            _PyThreadState_DeleteCurrent(tstate);
        } elif oldstate == PyGILState_UNLOCKED {
            PyEval_SaveThread();
        }
    }  def _PyInterpreterState_GetEvalFrameFunc(interp: ptr[u8]) -> ptr {
        eval_frame = ld_p(ptr[u8](interp) + PyInterpreterState_EVAL_FRAME);
        if not eval_frame {
            return ptr(_PyEval_EvalFrameDefault);
        }
        return ptr(eval_frame);
    }  def _PyInterpreterState_SetEvalFrameFunc(interp: ptr[u8], eval_frame: ptr) {
        requested = int(eval_frame);
        if requested == int(ptr(_PyEval_EvalFrameDefault)) {
            requested = 0;
        }
        if requested == int(ld_p(ptr[u8](interp) + PyInterpreterState_EVAL_FRAME)) {
            return;
        }
        rare_event_set_eval_frame_func();
        _PyEval_StopTheWorld(interp);
        st_p(ptr[u8](interp) + PyInterpreterState_EVAL_FRAME, ptr[u8](requested));
        _PyEval_StartTheWorld(interp);
    }  def _PyInterpreterState_GetConfig(interp: ptr[u8]) -> ptr[u8] {
        return ptr[u8](ptr[u8](interp) + PyInterpreterState_CONFIG);
    }  def _Py_GetConfig -> ptr[u8] {
        tstate = current_fast_get();
        ensure_tstate_not_null(ptr[u8]("_Py_GetConfig"), tstate);
        return _PyInterpreterState_GetConfig(ts_interp(tstate));
    }  def _PyInterpreterState_HasFeature(interp: ptr[u8], feature: u64) -> i32 {
        if (ld_u64(ptr[u8](interp) + PyInterpreterState_FEATURE_FLAGS) & feature)
            != u64(0) {
            return 1;
        }
        return 0;
    }
}

def rare_event_set_eval_frame_func;

def push_chunk(tstate: ptr[PyThreadState], size: i64) -> ptr[u8];

import from c {
    def _PyThreadState_PushFrame(tstate: ptr[PyThreadState], size: u64) -> ptr[u8] {
        base = ptr[u8](tstate);
        n = i64.wrap(size);
        top = ld_p(base + PyThreadState_DATASTACK_TOP);
        if top
            and n
                < (int(ld_p(base + PyThreadState_DATASTACK_LIMIT)) - int(top))
                    // WORD {
            st_p(base + PyThreadState_DATASTACK_TOP, top + n * WORD);
            return top;
        }
        return push_chunk(tstate, n);
    }  def _PyThreadState_PopFrame(tstate: ptr[PyThreadState], frame: ptr[u8]) {
        base = ptr[u8](tstate);
        chunk = ld_p(base + PyThreadState_DATASTACK_CHUNK);
        if frame == chunk + _PyStackChunk_DATA {
            previous = ld_p(ptr[u8](chunk) + _PyStackChunk_PREVIOUS);
            cached = ld_p(base + PyThreadState_DATASTACK_CACHED_CHUNK);
            prev_top = i64(ld_u64(ptr[u8](previous) + _PyStackChunk_TOP));
            st_p(
                base + PyThreadState_DATASTACK_TOP,
                previous + _PyStackChunk_DATA + prev_top * WORD
            );
            st_p(base + PyThreadState_DATASTACK_CHUNK, previous);
            st_p(
                base + PyThreadState_DATASTACK_LIMIT,
                previous + i64(ld_u64(previous + _PyStackChunk_CHUNK_SIZE))
            );
            st_p(ptr[u8](chunk) + _PyStackChunk_PREVIOUS, ptr[u8]());
            if cached {
                _PyObject_VirtualFree(
                    ptr(cached), ld_u64(ptr[u8](cached) + _PyStackChunk_CHUNK_SIZE)
                );
            }
            st_p(base + PyThreadState_DATASTACK_CACHED_CHUNK, chunk);
        } else {
            st_p(base + PyThreadState_DATASTACK_TOP, frame);
        }
    }  def _PyThreadState_MustExit(tstate: ptr[PyThreadState]) -> i32 {
        state = __atomic_load_i32(int(ptr[u8](tstate) + PyThreadState_STATE), 0);
        if state == _Py_THREAD_SHUTTING_DOWN {
            return 1;
        }
        return 0;
    }  def _PyThreadState_HangThread(tstate: ptr[PyThreadState]) {
        decref_threadstate(ptr[u8](tstate));
        PyThread_hang_thread();
    }  def _PyThreadState_ClearMimallocHeaps(tstate: ptr[PyThreadState]) {
        return;
    }  def _Py_IsMainThread -> i32 {
        thread = PyThread_get_thread_ident();
        if thread == ld_u64(runtime_addr() + _PyRuntimeState_MAIN_THREAD) {
            return 1;
        }
        return 0;
    }  def _PyInterpreterState_Main -> ptr[u8] {
        return ld_p(runtime_addr() + _PyRuntimeState_INTERPRETERS_MAIN);
    }  def _Py_IsMainInterpreterFinalizing(interp: ptr[u8]) -> i32 {
        finalizing = __atomic_load_i64(
            int(runtime_addr() + _PyRuntimeState_FINALIZING), 0
        );
        if finalizing != 0 and interp == main_interpreter_addr() {
            return 1;
        }
        return 0;
    }  def _Py_GetMainConfig -> ptr[u8] {
        interp = _PyInterpreterState_Main();
        if not interp {
            return ptr[u8]();
        }
        return _PyInterpreterState_GetConfig(interp);
    }
}

impl ld_p(addr: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](addr).view(1)[0];
}

impl st_p(addr: ptr[u8], value: ptr[u8]) {
    ptr[ptr[u8]](addr).view(1)[0] = value;
}

impl ld_t(addr: ptr[u8]) -> ptr[PyThreadState] {
    return ptr[ptr[PyThreadState]](addr).view(1)[0];
}

impl st_t(addr: ptr[u8], value: ptr[PyThreadState]) {
    ptr[ptr[PyThreadState]](addr).view(1)[0] = value;
}

impl ld_o(addr: ptr[u8]) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](addr).view(1)[0];
}

impl st_o(addr: ptr[u8], value: ptr[PyObject]) {
    ptr[ptr[PyObject]](addr).view(1)[0] = value;
}

impl ld_i32(addr: ptr[u8]) -> i32 {
    return ptr[i32](addr).view(1)[0];
}

impl st_i32(addr: ptr[u8], value: i32) {
    ptr[i32](addr).view(1)[0] = value;
}

impl ld_i64(addr: ptr[u8]) -> i64 {
    return ptr[i64](addr).view(1)[0];
}

impl st_i64(addr: ptr[u8], value: i64) {
    ptr[i64](addr).view(1)[0] = value;
}

impl ld_u64(addr: ptr[u8]) -> u64 {
    return ptr[u64](addr).view(1)[0];
}

impl st_u64(addr: ptr[u8], value: u64) {
    ptr[u64](addr).view(1)[0] = value;
}

impl ld_u8(addr: ptr[u8]) -> u8 {
    return ptr[u8](addr).view(1)[0];
}

impl st_u8(addr: ptr[u8], value: u8) {
    ptr[u8](addr).view(1)[0] = value;
}

impl clear_slot(addr: ptr[u8]) {
    old = ld_o(addr);
    if old {
        st_o(addr, NULL);
        object_decref(old);
    }
}

impl runtime_addr -> ptr[u8] {
    return ptr[u8](addressof(_PyRuntime));
}

impl main_interpreter_addr -> ptr[u8] {
    return runtime_addr() + _PyRuntimeState_MAIN_INTERPRETER;
}

impl ts_interp(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return ld_p(ptr[u8](tstate) + PyThreadState_INTERP);
}

impl interp_runtime(interp: ptr[u8]) -> ptr[u8] {
    return ld_p(interp + PyInterpreterState_RUNTIME);
}

impl ts_runtime(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return interp_runtime(ts_interp(tstate));
}

impl status_has(tstate: ptr[PyThreadState], bit: u32) -> bool {
    return (ptr[u32](ptr[u8](tstate) + PyThreadState__STATUS).view(1)[0] & bit)
        != u32(0);
}

impl status_set(tstate: ptr[PyThreadState], bit: u32) {
    word = ptr[u32](ptr[u8](tstate) + PyThreadState__STATUS);
    word.view(1)[0] = word.view(1)[0] | bit;
}

impl status_unset(tstate: ptr[PyThreadState], bit: u32) {
    word = ptr[u32](ptr[u8](tstate) + PyThreadState__STATUS);
    word.view(1)[0] = word.view(1)[0] & ~bit;
}

impl pystatus_ok -> PyStatus {
    return PyStatus(
        _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
    );
}

impl pystatus_error(func: ptr[u8], msg: ptr[u8]) -> PyStatus {
    return PyStatus(_type=_PyStatus_TYPE_ERROR, func=func, err_msg=msg, exitcode=0);
}

impl pystatus_failed(status: PyStatus) -> bool {
    return status._type != _PyStatus_TYPE_OK;
}

impl llist_init(head: ptr[u8]) {
    st_p(head, head);
    st_p(head + WORD, head);
}

impl llist_concat(head1: ptr[u8], head2: ptr[u8]) {
    if ld_p(head2) != head2 {
        h1_prev = ld_p(head1 + WORD);
        h2_next = ld_p(head2);
        h2_prev = ld_p(head2 + WORD);
        st_p(h1_prev, h2_next);
        st_p(h2_next + WORD, h1_prev);
        st_p(head1 + WORD, h2_prev);
        st_p(h2_prev, head1);
        llist_init(head2);
    }
}

impl tss_slot -> ptr[ptr[PyThreadState]] {
    return ptr[ptr[PyThreadState]](__thread_local("_Py_tss_tstate"));
}

impl current_fast_get -> ptr[PyThreadState] {
    return tss_slot().view(1)[0];
}

impl current_fast_set(tstate: ptr[PyThreadState]) {
    tss_slot().view(1)[0] = tstate;
}

impl current_fast_clear {
    tss_slot().view(1)[0] = ptr[PyThreadState]();
}

impl tstate_verify_not_active(tstate: ptr[PyThreadState], func: ptr[u8]) {
    if tstate == current_fast_get() {
        _Py_FatalErrorFormat(
            func, ptr[u8]("tstate %p is still current"), ptr[u8](tstate)
        );
    }
}

impl gilstate_key(runtime: ptr[u8]) -> ptr[u8] {
    return ptr[u8](runtime + _PyRuntimeState_AUTOTSSKEY);
}

impl tstate_tss_reinit(key: ptr[u8]) -> PyStatus {
    if PyThread_tss_is_created(key) == 0 {
        return pystatus_ok();
    }
    tstate = PyThread_tss_get(key);

    PyThread_tss_delete(key);
    if PyThread_tss_create(key) != 0 {
        return pystatus_error(
            ptr[u8]("tstate_tss_reinit"), ptr[u8]("memory allocation failed")
        );
    }

    if tstate and PyThread_tss_set(key, tstate) != 0 {
        return pystatus_error(
            ptr[u8]("tstate_tss_reinit"), ptr[u8]("failed to re-set autoTSSkey")
        );
    }
    return pystatus_ok();
}

impl gilstate_tss_get(runtime: ptr[u8]) -> ptr[PyThreadState] {
    return ptr[PyThreadState](PyThread_tss_get(gilstate_key(runtime)));
}

impl gilstate_tss_set(runtime: ptr[u8], tstate: ptr[PyThreadState]) {
    if PyThread_tss_set(gilstate_key(runtime), ptr(tstate)) != 0 {
        _Py_FatalErrorFunc(
            ptr[u8]("gilstate_tss_set"), ptr[u8]("failed to set current tstate (TSS)")
        );
    }
}

impl gilstate_tss_clear(runtime: ptr[u8]) {
    if PyThread_tss_set(gilstate_key(runtime), ptr()) != 0 {
        _Py_FatalErrorFunc(
            ptr[u8]("gilstate_tss_clear"),
            ptr[u8]("failed to clear current tstate (TSS)")
        );
    }
}

impl bind_tstate(tstate: ptr[PyThreadState]) {
    st_u64(ptr[u8](tstate) + PyThreadState_THREAD_ID, PyThread_get_thread_ident());
    st_u64(
        ptr[u8](tstate) + PyThreadState_NATIVE_THREAD_ID,
        PyThread_get_thread_native_id()
    );
    status_set(tstate, STATUS_BOUND);
}

impl unbind_tstate(tstate: ptr[PyThreadState]) {
    status_set(tstate, STATUS_UNBOUND);
}

impl bind_gilstate_tstate(tstate: ptr[PyThreadState]) {
    runtime = ts_runtime(tstate);
    tcur = gilstate_tss_get(runtime);

    if tcur {
        status_unset(tcur, STATUS_BOUND_GILSTATE);
    }
    gilstate_tss_set(runtime, tstate);
    status_set(tstate, STATUS_BOUND_GILSTATE);
}

impl unbind_gilstate_tstate(tstate: ptr[PyThreadState]) {
    gilstate_tss_clear(ts_runtime(tstate));
    status_unset(tstate, STATUS_BOUND_GILSTATE);
}

impl holds_gil(tstate: ptr[PyThreadState]) -> bool {
    return tstate == current_fast_get();
}

impl init_runtime(
    runtime: ptr[u8],
    open_code_hook: ptr[u8],
    open_code_userdata: ptr[u8],
    audit_hook_head: ptr[u8],
    unicode_next_index: i64
) {
    st_p(runtime + _PyRuntimeState_OPEN_CODE_HOOK, open_code_hook);
    st_p(runtime + _PyRuntimeState_OPEN_CODE_USERDATA, open_code_userdata);
    st_p(runtime + _PyRuntimeState_AUDIT_HOOKS_HEAD, audit_hook_head);

    PyPreConfig_InitPythonConfig(ptr[u8](runtime + _PyRuntimeState_PRECONFIG));

    st_u64(runtime + _PyRuntimeState_MAIN_THREAD, PyThread_get_thread_ident());

    st_i64(runtime + _PyRuntimeState_UNICODE_IDS_NEXT_INDEX, unicode_next_index);
    st_i32(runtime + _PyRuntimeState__INITIALIZED, i32(1));
}

impl initial_image -> int {
    return __atomic_load_i64(int(addressof(runtime_initial_image)), 5);
}

impl initial_main_interpreter -> int {
    return initial_image() + _PyRuntimeState_MAIN_INTERPRETER;
}

impl runtime_fini(runtime: ptr[u8]) {
    if PyThread_tss_is_created(gilstate_key(runtime)) != 0 {
        PyThread_tss_delete(gilstate_key(runtime));
    }

    trash = ptr[u8](runtime + _PyRuntimeState_TRASHTSSKEY);
    if PyThread_tss_is_created(trash) != 0 {
        PyThread_tss_delete(trash);
    }
}

impl alloc_interpreter -> ptr[u8] {
    alignment = PyInterpreterState_ALIGN;
    allocsize = PyInterpreterState_SIZE + WORD + alignment - 1;
    mem = PyMem_RawCalloc(u64(1), u64(allocsize));
    if not mem {
        return ptr[u8]();
    }
    address = int(ptr[u8](mem)) + WORD;
    address = (address + alignment - 1) & ~(alignment - 1);
    st_p(ptr[u8](address - WORD), ptr[u8](mem));
    return ptr[u8](address);
}

impl free_interpreter(interp: ptr[u8]) {
    if interp != main_interpreter_addr() {
        if _PyMem_obmalloc_state_on_heap(interp) {
            PyMem_RawFree(ptr(ld_p(ptr[u8](interp) + PyInterpreterState_OBMALLOC)));
            st_p(ptr[u8](interp) + PyInterpreterState_OBMALLOC, ptr[u8]());
        }
        PyMem_RawFree(ptr(ld_p(interp - WORD)));
    }
}

impl init_interpreter(
    interp: ptr[u8], runtime: ptr[u8], id: i64, next: ptr[u8], whence: i64
) -> PyStatus {
    base = ptr[u8](interp);
    if ld_i32(base + PyInterpreterState__INITIALIZED) != 0 {
        return pystatus_error(
            ptr[u8]("init_interpreter"), ptr[u8]("interpreter already initialized")
        );
    }

    st_i64(base + PyInterpreterState__WHENCE, whence);
    st_p(base + PyInterpreterState_RUNTIME, ptr[u8](runtime));
    st_i64(base + PyInterpreterState_ID, id);
    st_i64(base + PyInterpreterState_ID_REFCOUNT, 0);
    st_p(base + PyInterpreterState_NEXT, next);

    st_p(
        base + PyInterpreterState_THREADS_PREALLOCATED,
        ptr[u8](base + PyInterpreterState__INITIAL_THREAD)
    );

    _PyEval_InitState(interp);
    _PyGC_InitState(ptr[u8](base + PyInterpreterState_GC));
    PyConfig_InitPythonConfig(ptr[u8](base + PyInterpreterState_CONFIG));
    _PyType_InitCache(interp);
    llist_init(base + PyInterpreterState_MEM_FREE_QUEUE_HEAD);
    llist_init(base + PyInterpreterState_ASYNCIO_TASKS_HEAD);
    st_u8(base + PyInterpreterState_ASYNCIO_TASKS_LOCK, u8(0));
    for i in range(i64(_PY_MONITORING_UNGROUPED_EVENTS)) {
        st_u8(base + PyInterpreterState_MONITORS_TOOLS + i, u8(0));
    }
    events = i64(_PY_MONITORING_EVENTS);
    for t in range(i64(PY_MONITORING_TOOL_IDS)) {
        for e in range(events) {
            st_o(
                base
                    + PyInterpreterState_MONITORING_CALLABLES
                    + (t * events + e) * WORD,
                NULL
            );
        }
        st_u64(base + PyInterpreterState_MONITORING_TOOL_VERSIONS + t * WORD, u64(0));
    }
    st_u64(base + PyInterpreterState_CODE_OBJECT_GENERATION, u64(0));
    st_u8(base + PyInterpreterState_JIT, u8(0));
    st_p(base + PyInterpreterState_EXECUTOR_LIST_HEAD, ptr[u8]());
    st_p(base + PyInterpreterState_EXECUTOR_DELETION_LIST_HEAD, ptr[u8]());
    st_i32(base + PyInterpreterState_EXECUTOR_DELETION_LIST_REMAINING_CAPACITY, i32(0));
    st_u64(base + PyInterpreterState_TRACE_RUN_COUNTER, JIT_CLEANUP_THRESHOLD);
    if base != runtime + _PyRuntimeState_MAIN_INTERPRETER {
        memset(ptr[u8](base + PyInterpreterState_DTOA), 0, u64(_dtoa_state_SIZE));
        st_p(
            base + PyInterpreterState_DTOA_PREALLOCATED_NEXT,
            ptr[u8](base + PyInterpreterState_DTOA_PREALLOCATED)
        );
    }

    st_i32(base + PyInterpreterState__INITIALIZED, i32(1));
    return pystatus_ok();
}

impl interpreter_clear(interp: ptr[u8], tstate: ptr[PyThreadState]) {
    base = ptr[u8](interp);
    runtime = ptr[u8](interp_runtime(interp));

    if _PySys_Audit(tstate, ptr[u8]("cpython.PyInterpreterState_Clear"), ptr[u8]())
        < 0 {
        _PyErr_Clear(tstate);
    }

    head_lock(runtime);
    p = ld_t(base + PyInterpreterState_THREADS_HEAD);
    while p {
        head_unlock(runtime);
        PyThreadState_Clear(p);
        head_lock(runtime);
        p = ld_t(ptr[u8](p) + PyThreadState_NEXT);
    }
    head_unlock(runtime);
    if ts_interp(tstate) == interp {
        status_unset(tstate, STATUS_CLEARED);
    }

    clear_slot(base + PyInterpreterState_AUDIT_HOOKS);

    st_u64(base + PyInterpreterState_CEVAL_INSTRUMENTATION_VERSION, u64(0));
    __atomic_store_i64(int(ptr[u8](tstate) + PyThreadState_EVAL_BREAKER), 0, 5);

    for i in range(i64(_PY_MONITORING_UNGROUPED_EVENTS)) {
        st_u8(base + PyInterpreterState_MONITORS_TOOLS + i, u8(0));
    }
    events = i64(_PY_MONITORING_EVENTS);
    for t in range(i64(PY_MONITORING_TOOL_IDS)) {
        for e in range(events) {
            clear_slot(
                base + PyInterpreterState_MONITORING_CALLABLES + (t * events + e) * WORD
            );
        }
    }
    for t in range(i64(PY_MONITORING_TOOL_IDS)) {
        clear_slot(base + PyInterpreterState_MONITORING_TOOL_NAMES + t * WORD);
    }
    st_u64(base + PyInterpreterState_CODE_OBJECT_GENERATION, u64(0));

    PyConfig_Clear(ptr[u8](base + PyInterpreterState_CONFIG));
    _PyCodec_Fini(interp);

    clear_slot(base + PyInterpreterState_SYSDICT_COPY);
    clear_slot(base + PyInterpreterState_BUILTINS_COPY);
    clear_slot(base + PyInterpreterState_DICT);
    clear_slot(base + PyInterpreterState_BEFORE_FORKERS);
    clear_slot(base + PyInterpreterState_AFTER_FORKERS_PARENT);
    clear_slot(base + PyInterpreterState_AFTER_FORKERS_CHILD);

    _PyAST_Fini(interp);
    _PyAtExit_Fini(interp);

    _PyGC_CollectNoFail(tstate);
    _PyGC_Fini(interp);

    _PyWarnings_Fini(interp);
    PyDict_Clear(ld_o(base + PyInterpreterState_SYSDICT));
    PyDict_Clear(ld_o(base + PyInterpreterState_BUILTINS));
    clear_slot(base + PyInterpreterState_SYSDICT);
    clear_slot(base + PyInterpreterState_BUILTINS);

    if ts_interp(tstate) == interp {
        status_set(tstate, STATUS_CLEARED);
    }

    for i in range(DICT_MAX_WATCHERS) {
        st_p(base + PyInterpreterState_DICT_WATCHERS + i * WORD, ptr[u8]());
    }

    for i in range(TYPE_MAX_WATCHERS) {
        st_p(base + PyInterpreterState_TYPE_WATCHERS + i * WORD, ptr[u8]());
    }

    for i in range(FUNC_MAX_WATCHERS) {
        st_p(base + PyInterpreterState_FUNC_WATCHERS + i * WORD, ptr[u8]());
    }
    st_u8(base + PyInterpreterState_ACTIVE_FUNC_WATCHERS, u8(0));

    for i in range(CODE_MAX_WATCHERS) {
        st_p(base + PyInterpreterState_CODE_WATCHERS + i * WORD, ptr[u8]());
    }
    st_u8(base + PyInterpreterState_ACTIVE_CODE_WATCHERS, u8(0));

    for i in range(CONTEXT_MAX_WATCHERS) {
        st_p(base + PyInterpreterState_CONTEXT_WATCHERS + i * WORD, ptr[u8]());
    }
    st_u8(base + PyInterpreterState_ACTIVE_CONTEXT_WATCHERS, u8(0));
}

impl set_main_thread(interp: ptr[u8], tstate: ptr[PyThreadState]) {
    __atomic_store_i64(
        int(ptr[u8](interp) + PyInterpreterState_THREADS_MAIN), int(tstate), 0
    );
}

impl get_main_thread(interp: ptr[u8]) -> ptr[PyThreadState] {
    return ptr[PyThreadState](
        __atomic_load_i64(int(ptr[u8](interp) + PyInterpreterState_THREADS_MAIN), 0)
    );
}

impl interp_look_up_id(runtime: ptr[u8], requested_id: i64) -> ptr[u8] {
    interp = ld_p(runtime + _PyRuntimeState_INTERPRETERS_HEAD);
    while interp {
        id = PyInterpreterState_GetID(interp);
        if id < 0 {
            return ptr[u8]();
        }
        if requested_id == id {
            return interp;
        }
        interp = PyInterpreterState_Next(interp);
    }
    return ptr[u8]();
}

impl allocate_chunk(size_in_bytes: i64, previous: ptr[u8]) -> ptr[u8] {
    res = ptr[u8](_PyObject_VirtualAlloc(u64(size_in_bytes)));
    if not res {
        return ptr[u8]();
    }
    st_p(ptr[u8](res) + _PyStackChunk_PREVIOUS, previous);
    st_u64(ptr[u8](res) + _PyStackChunk_CHUNK_SIZE, u64(size_in_bytes));
    st_u64(ptr[u8](res) + _PyStackChunk_TOP, u64(0));
    return res;
}

impl reset_threadstate(tstate: ptr[u8]) {
    memcpy(
        ptr(tstate),
        ptr[u8](initial_main_interpreter() + PyInterpreterState__INITIAL_THREAD),
        u64(_PyThreadStateImpl_SIZE)
    );
}

impl alloc_threadstate(interp: ptr[u8]) -> ptr[u8] {
    tstate = ptr[u8](
        __atomic_swap_i64(
            int(ptr[u8](interp) + PyInterpreterState_THREADS_PREALLOCATED), 0, 5
        )
    );

    if not tstate {
        tstate = ptr[u8](PyMem_RawCalloc(u64(1), u64(_PyThreadStateImpl_SIZE)));
        if not tstate {
            return ptr[u8]();
        }
        reset_threadstate(tstate);
    }
    return tstate;
}

impl free_threadstate(tstate: ptr[u8]) {
    interp = ld_p(ptr[u8](tstate) + PyThreadState_INTERP);
    if tstate == interp + PyInterpreterState__INITIAL_THREAD {
        reset_threadstate(tstate);
        __atomic_store_i64(
            int(ptr[u8](interp) + PyInterpreterState_THREADS_PREALLOCATED),
            int(tstate),
            5
        );
    } else {
        PyMem_RawFree(ptr(tstate));
    }
}

impl decref_threadstate(tstate: ptr[u8]) {
    if __atomic_add_i64(int(ptr[u8](tstate) + _PyThreadStateImpl_REFCOUNT), -1, 5)
        == 1 {
        free_threadstate(tstate);
    }
}

impl init_threadstate(raw: ptr[u8], interp: ptr[u8], id: u64, whence: i32) {
    tstate = ptr[PyThreadState](raw);
    base = ptr[u8](raw);
    if status_has(tstate, STATUS_INITIALIZED) {
        _Py_FatalErrorFunc(
            ptr[u8]("init_threadstate"), ptr[u8]("thread state already initialized")
        );
    }

    st_p(base + PyThreadState_INTERP, interp);
    st_i64(
        base + PyThreadState_EVAL_BREAKER,
        __atomic_load_i64(
            int(ptr[u8](interp) + PyInterpreterState_CEVAL_INSTRUMENTATION_VERSION), 0
        )
    );

    st_i32(base + PyThreadState__WHENCE, whence);

    st_u64(base + PyThreadState_ID, id);

    limit = ld_i32(ptr[u8](interp) + PyInterpreterState_CEVAL_RECURSION_LIMIT);
    st_i32(base + PyThreadState_PY_RECURSION_LIMIT, limit);
    st_i32(base + PyThreadState_PY_RECURSION_REMAINING, limit);
    st_p(base + PyThreadState_EXC_INFO, ptr[u8](base + PyThreadState_EXC_STATE));

    st_i32(base + PyThreadState_GILSTATE_COUNTER, i32(1));

    st_p(base + PyThreadState_CURRENT_FRAME, ptr[u8]());
    st_p(base + PyThreadState_DATASTACK_CHUNK, ptr[u8]());
    st_p(base + PyThreadState_DATASTACK_TOP, ptr[u8]());
    st_p(base + PyThreadState_DATASTACK_LIMIT, ptr[u8]());
    st_p(base + PyThreadState_DATASTACK_CACHED_CHUNK, ptr[u8]());
    st_i32(base + PyThreadState_WHAT_EVENT, i32(-1));
    st_p(base + PyThreadState_CURRENT_EXECUTOR, ptr[u8]());
    st_u64(base + PyThreadState_DICT_GLOBAL_VERSION, u64(0));

    st_u64(base + _PyThreadStateImpl_C_STACK_SOFT_LIMIT, ~u64(0));
    st_u64(base + _PyThreadStateImpl_C_STACK_TOP, u64(0));
    st_u64(base + _PyThreadStateImpl_C_STACK_HARD_LIMIT, u64(0));

    st_u64(base + _PyThreadStateImpl_C_STACK_INIT_BASE, u64(0));
    st_u64(base + _PyThreadStateImpl_C_STACK_INIT_TOP, u64(0));

    st_o(base + _PyThreadStateImpl_ASYNCIO_RUNNING_LOOP, NULL);
    st_o(base + _PyThreadStateImpl_ASYNCIO_RUNNING_TASK, NULL);

    st_o(base + PyThreadState_DELETE_LATER, NULL);

    llist_init(base + _PyThreadStateImpl_MEM_FREE_QUEUE);
    llist_init(base + _PyThreadStateImpl_ASYNCIO_TASKS_HEAD);
    if ld_u8(
        ptr[u8](interp)
            + PyInterpreterState_STOPTHEWORLD
            + _stoptheworld_state_REQUESTED
    )
        != u8(0)
        or ld_u8(
            runtime_addr()
                + _PyRuntimeState_STOPTHEWORLD
                + _stoptheworld_state_REQUESTED
        )
            != u8(0) {
        st_i32(base + PyThreadState_STATE, _Py_THREAD_SUSPENDED);
    }

    status_set(tstate, STATUS_INITIALIZED);
}

impl add_threadstate(
    interp: ptr[u8], tstate: ptr[PyThreadState], next: ptr[PyThreadState]
) {
    if next {
        st_t(ptr[u8](next) + PyThreadState_PREV, tstate);
    }
    st_t(ptr[u8](tstate) + PyThreadState_NEXT, next);
    st_t(ptr[u8](interp) + PyInterpreterState_THREADS_HEAD, tstate);
}

impl new_threadstate(interp: ptr[u8], whence: i32) -> ptr[PyThreadState] {
    raw = alloc_threadstate(interp);
    if not raw {
        return ptr[PyThreadState]();
    }

    runtime = ptr[u8](interp_runtime(interp));
    head_lock(runtime);

    id_slot = ptr[u8](interp) + PyInterpreterState_THREADS_NEXT_UNIQUE_ID;
    st_u64(id_slot, ld_u64(id_slot) + u64(1));
    id = ld_u64(id_slot);
    init_threadstate(raw, interp, id, whence);

    old_head = ld_t(ptr[u8](interp) + PyInterpreterState_THREADS_HEAD);
    add_threadstate(interp, ptr[PyThreadState](raw), old_head);

    head_unlock(runtime);

    return ptr[PyThreadState](raw);
}

impl clear_datastack(tstate: ptr[PyThreadState]) {
    base = ptr[u8](tstate);
    chunk = ld_p(base + PyThreadState_DATASTACK_CHUNK);
    st_p(base + PyThreadState_DATASTACK_CHUNK, ptr[u8]());
    while chunk {
        prev = ld_p(ptr[u8](chunk) + _PyStackChunk_PREVIOUS);
        _PyObject_VirtualFree(
            ptr(chunk), ld_u64(ptr[u8](chunk) + _PyStackChunk_CHUNK_SIZE)
        );
        chunk = prev;
    }
    cached = ld_p(base + PyThreadState_DATASTACK_CACHED_CHUNK);
    if cached {
        _PyObject_VirtualFree(
            ptr(cached), ld_u64(ptr[u8](cached) + _PyStackChunk_CHUNK_SIZE)
        );
        st_p(base + PyThreadState_DATASTACK_CACHED_CHUNK, ptr[u8]());
    }
}

impl decrement_stoptheworld_countdown(stw: ptr[u8]) {
    countdown = ld_i64(stw + _stoptheworld_state_THREAD_COUNTDOWN) - 1;
    st_i64(stw + _stoptheworld_state_THREAD_COUNTDOWN, countdown);
    if countdown == 0 {
        _PyEvent_Notify(ptr[u8](stw + _stoptheworld_state_STOP_EVENT));
    }
}

impl tstate_delete_common(tstate: ptr[PyThreadState], release_gil: i32, func: ptr[u8]) {
    tstate_verify_not_active(tstate, func);

    interp = ts_interp(tstate);
    if not interp {
        _Py_FatalErrorFunc(func, ptr[u8]("NULL interpreter"));
    }
    runtime = interp_runtime(interp);

    head_lock(ptr[u8](runtime));
    prev = ld_t(ptr[u8](tstate) + PyThreadState_PREV);
    next = ld_t(ptr[u8](tstate) + PyThreadState_NEXT);
    if prev {
        st_t(ptr[u8](prev) + PyThreadState_NEXT, next);
    } else {
        st_t(ptr[u8](interp) + PyInterpreterState_THREADS_HEAD, next);
    }
    if next {
        st_t(ptr[u8](next) + PyThreadState_PREV, prev);
    }
    if ld_i32(ptr[u8](tstate) + PyThreadState_STATE) != _Py_THREAD_SUSPENDED {
        interp_stw = ptr[u8](interp) + PyInterpreterState_STOPTHEWORLD;
        if ld_u8(interp_stw + _stoptheworld_state_REQUESTED) != u8(0) {
            decrement_stoptheworld_countdown(interp_stw);
        }
        runtime_stw = runtime + _PyRuntimeState_STOPTHEWORLD;
        if ld_u8(runtime_stw + _stoptheworld_state_REQUESTED) != u8(0) {
            decrement_stoptheworld_countdown(runtime_stw);
        }
    }

    head_unlock(ptr[u8](runtime));

    if status_has(tstate, STATUS_BOUND_GILSTATE) {
        unbind_gilstate_tstate(tstate);
    }
    if status_has(tstate, STATUS_BOUND) {
        unbind_tstate(tstate);
    }

    clear_datastack(tstate);

    if release_gil != 0 {
        _PyEval_ReleaseLock(ts_interp(tstate), tstate, 1);
    }

    status_set(tstate, STATUS_FINALIZED);
}

impl zapthreads(interp: ptr[u8]) {
    tstate = ld_t(ptr[u8](interp) + PyInterpreterState_THREADS_HEAD);
    while tstate {
        tstate_delete_common(tstate, 0, ptr[u8]("zapthreads"));
        free_threadstate(ptr[u8](tstate));
        tstate = ld_t(ptr[u8](interp) + PyInterpreterState_THREADS_HEAD);
    }
}

impl frame_object_of(frame: ptr[u8]) -> ptr[PyObject] {
    existing = ld_o(ptr[u8](frame) + _PyInterpreterFrame_FRAME_OBJ);
    if existing {
        return existing;
    }
    return _PyFrame_MakeAndSetFrameObject(frame);
}

impl tstate_activate(tstate: ptr[PyThreadState]) {
    if not status_has(tstate, STATUS_BOUND_GILSTATE) {
        bind_gilstate_tstate(tstate);
    }

    status_set(tstate, STATUS_ACTIVE);
}

impl tstate_deactivate(tstate: ptr[PyThreadState]) {
    status_unset(tstate, STATUS_ACTIVE);
}

impl detach_thread(tstate: ptr[PyThreadState], detached_state: i32) {
    if ld_u64(ptr[u8](tstate) + PyThreadState_CRITICAL_SECTION) != u64(0) {
        _PyCriticalSection_SuspendAll(tstate);
    }
    tstate_deactivate(tstate);
    st_i32(ptr[u8](tstate) + PyThreadState_STATE, detached_state);
    current_fast_clear();
    _PyEval_ReleaseLock(ts_interp(tstate), tstate, 0);
}

impl rare_event_set_eval_frame_func {
    interp = PyInterpreterState_Get();
    slot = ptr[u8](interp) + PyInterpreterState_RARE_SET_EVAL_FRAME_FUNC;
    val = ld_u8(slot);
    if val < u8(255) {
        st_u8(slot, val + u8(1));
    }
}

impl push_chunk(tstate: ptr[PyThreadState], size: i64) -> ptr[u8] {
    base = ptr[u8](tstate);
    allocate_size = _PY_DATA_STACK_CHUNK_SIZE;
    while allocate_size < WORD * (size + MINIMUM_OVERHEAD) {
        allocate_size = allocate_size * 2;
    }
    new = ptr[u8]();
    cached = ld_p(base + PyThreadState_DATASTACK_CACHED_CHUNK);
    chunk = ld_p(base + PyThreadState_DATASTACK_CHUNK);
    if cached
        and u64(allocate_size) <= ld_u64(ptr[u8](cached) + _PyStackChunk_CHUNK_SIZE) {
        new = cached;
        st_p(base + PyThreadState_DATASTACK_CACHED_CHUNK, ptr[u8]());
        st_p(ptr[u8](new) + _PyStackChunk_PREVIOUS, chunk);
        st_u64(ptr[u8](new) + _PyStackChunk_TOP, u64(0));
    } else {
        new = allocate_chunk(allocate_size, chunk);
        if not new {
            return ptr[u8]();
        }
    }
    if chunk {
        used = int(ld_p(base + PyThreadState_DATASTACK_TOP))
            - int(chunk + _PyStackChunk_DATA);
        st_u64(chunk + _PyStackChunk_TOP, u64(used // WORD));
    }
    st_p(base + PyThreadState_DATASTACK_CHUNK, new);
    st_p(base + PyThreadState_DATASTACK_LIMIT, new + allocate_size);
    res = ptr[u8](new) + _PyStackChunk_DATA;
    if not ld_p(ptr[u8](new) + _PyStackChunk_PREVIOUS) {
        res = res + WORD;
    }
    st_p(base + PyThreadState_DATASTACK_TOP, res + size * WORD);
    return res;
}
