import from c {
    def sigaction(sig: i32, action: ptr, old_action: ptr) -> i32;  def sigemptyset(
        mask: ptr
    ) -> i32;  def sigfillset(signals: ptr) -> i32;  def pthread_sigmask(
        how: i32, signals: ptr, old_signals: ptr
    ) -> i32;  def pthread_kill(thread: u64, sig: i32) -> i32;  def pthread_self -> u64;  def sigaltstack(
        stack: ptr, old_stack: ptr
    ) -> i32;  def strlen(text: ptr[u8]) -> u64;  def abort;  def _exit(status: i32);  def getrlimit(
        resource: i32, limit: &mut rlimit
    ) -> i32;  def setrlimit(resource: i32, limit: &mut rlimit) -> i32;  def memset(
        target: ptr, value: i32, size: u64
    ) -> ptr;  def memcpy(target: ptr, source: ptr, size: u64) -> ptr;  def Py_FatalError(
        message: ptr[u8]
    );  def _Py_write_noraise(fd: i32, buf: ptr, count: u64) -> i64;  def _Py_DumpTraceback(
        fd: i32, tstate: ptr[PyThreadState]
    );  def _Py_DumpTracebackThreads(
        fd: i32, interp: ptr[PyInterpreterState], current_tstate: ptr[PyThreadState]
    ) -> ptr[u8];  def _Py_DumpStack(fd: i32);  def _Py_InitDumpStack;  def _Py_DumpExtensionModules(
        fd: i32, interp: ptr[PyInterpreterState]
    );  def _Py_DumpDecimal(fd: i32, value: u64);  def PyGILState_GetThisThreadState -> ptr[
        PyThreadState
    ];  def _PySys_GetRequiredAttr(name: ptr[PyObject]) -> ptr[PyObject];  def _PyFile_Flush(
        file: ptr[PyObject]
    ) -> i32;  def _PyEval_StopTheWorld(interp: ptr[u8]);  def _PyEval_StartTheWorld(
        interp: ptr[u8]
    );  def PyThread_acquire_lock_timed(
        lock: ptr, microseconds: i64, intr_flag: i32
    ) -> i32;  def PyThread_start_new_thread(func: ptr, arg: ptr) -> u64;  def _PyTime_AsMicroseconds(
        t: i64, round: i32
    ) -> i64;  def PyOS_snprintf(
        buf: ptr[u8], size: u64, format: ptr[u8], *args: any
    ) -> i32;  def _PyMem_Strdup(str_: ptr[u8]) -> ptr[u8];  def jacpy_stack_address(
        slots: &mut SignalBuffer
    ) -> int;  glob PY_TIMEOUT_MAX: i64; obj FaultHandler {
        has signum: i32 = 0,
            enabled: i32 = 0,
            name: ptr[u8] = ptr[u8](),
            previous: SignalBuffer = SignalBuffer(),
            all_threads: i32 = 0;
    }  glob:priv faulthandler_handlers: list[FaultHandler] = [
             FaultHandler(name=ptr[u8]("Bus error")),
             FaultHandler(name=ptr[u8]("Illegal instruction")),
             FaultHandler(name=ptr[u8]("Floating-point exception")),
             FaultHandler(name=ptr[u8]("Aborted")),
             FaultHandler(name=ptr[u8]("Segmentation fault"))
         ],
         dump_traceback_reentrant: i32 = 0,
         dump_c_stack_reentrant: i32 = 0; def _PyFaulthandler_Init(
        enable: i32
    ) -> PyStatus {
        init_handler_signums();
        stack = runtime_at(_PyRuntimeState_FAULTHANDLER_STACK);
        memset(ptr(stack), 0, u64(stack_t_SIZE));
        ptr[i32](stack + stack_t_SS_FLAGS).view(1)[0] = 0;

        ss_size = u64(SIGSTKSZ * 2);

        at_minstack_size = min_signal_stack_size();
        if at_minstack_size != u64(0) {
            ss_size = u64(SIGSTKSZ) + at_minstack_size;
        }
        ptr[u64](stack + stack_t_SS_SIZE).view(1)[0] = ss_size;

        memset(
            ptr(runtime_at(_PyRuntimeState_FAULTHANDLER_THREAD)),
            0,
            u64(_PyRuntimeState_FAULTHANDLER_THREAD_SIZE)
        );

        if enable != 0 {
            if faulthandler_init_enable() < 0 {
                return PyStatus(
                    _type=_PyStatus_TYPE_ERROR,
                    func=ptr[u8]("_PyFaulthandler_Init"),
                    err_msg=ptr[u8]("failed to enable faulthandler"),
                    exitcode=0
                );
            }
        }
        return PyStatus(
            _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
        );
    }  def _PyFaulthandler_Fini {
        if thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_CANCEL_EVENT) {
            cancel_dump_traceback_later();
            PyThread_release_lock(
                thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_CANCEL_EVENT)
            );
            PyThread_free_lock(
                thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_CANCEL_EVENT)
            );
            set_thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_CANCEL_EVENT, ptr());
        }
        if thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_RUNNING) {
            PyThread_free_lock(thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_RUNNING));
            set_thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_RUNNING, ptr());
        }

        user_signals = user_signals_base();
        if user_signals {
            signum = i32(0);
            while i64(signum) < Py_NSIG {
                faulthandler_unregister(user_signal(signum), signum);
                signum += 1;
            }
            PyMem_Free(ptr(user_signals));
            set_user_signals_base(ptr[u8]());
        }

        faulthandler_disable();

        stack = runtime_at(_PyRuntimeState_FAULTHANDLER_STACK);
        stack_sp = ptr[ptr](stack + stack_t_SS_SP);
        if stack_sp.view(1)[0] {
            current_slots: own SignalBuffer = SignalBuffer();
            current_stack = ptr[u8](jacpy_stack_address(&mut current_slots));
            if sigaltstack(ptr(), ptr(current_stack)) == 0 {
                if ptr[ptr](current_stack + stack_t_SS_SP).view(1)[0]
                    == stack_sp.view(1)[0] {
                    sigaltstack(
                        ptr(runtime_at(_PyRuntimeState_FAULTHANDLER_OLD_STACK)), ptr()
                    );
                }
            }
            PyMem_Free(stack_sp.view(1)[0]);
            stack_sp.view(1)[0] = ptr();
        }
    }
}

glob:priv FT_IGNORE_ALL_THREADS: Final[i32] = 2,
     STACK_OVERFLOW_MAX_SIZE: Final[u64] = 104857600,
     SEC_TO_US: Final[i64] = 1000000,
     FAULTHANDLER_NSIGNALS: Final[i64] = 5,
     WAIT_LOCK: Final[i32] = 1,
     INT_MAX: Final[i64] = 2147483647,
     LONG_MAX: Final[i64] = 9223372036854775807,
     PYTHREAD_INVALID_THREAD_ID: Final[u64] = 18446744073709551615;

def:priv runtime_at(offset: i64) -> ptr[u8];

def:priv fatal_i32(offset: i64) -> i32;

def:priv set_fatal_i32(offset: i64, value: i32);

def:priv runtime_object(offset: i64) -> ptr[PyObject];

def:priv runtime_interp(offset: i64) -> ptr[PyInterpreterState];

def:priv thread_ptr(offset: i64) -> ptr;

def:priv set_thread_ptr(offset: i64, value: ptr);

def:priv runtime_xsetref(offset: i64, value: ptr[PyObject]);

def:priv user_signals_base -> ptr[u8];

def:priv set_user_signals_base(base: ptr[u8]);

def:priv user_signal(signum: i32) -> ptr[u8];

def:priv handler_at(i: i64) -> ptr[FaultHandler];

def:priv handler_previous(handler: ptr[FaultHandler]) -> ptr;

glob:priv FAULT_HANDLER_PREVIOUS: Final[i64] = 16;

def:priv init_handler_signums;

def:priv puts(fd: i32, text: ptr[u8]);

def:priv faulthandler_get_fileno(file_in: ptr[PyObject]) -> tuple[i32, ptr[PyObject]];

def:priv get_thread_state -> ptr[PyThreadState];

def:priv faulthandler_dump_traceback(
    fd: i32, all_threads: i32, interp: ptr[PyInterpreterState]
);

def:priv faulthandler_dump_c_stack(fd: i32);

def faulthandler_dump_traceback_py(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def faulthandler_dump_c_stack_py(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def:priv faulthandler_disable_fatal_handler(handler: ptr[FaultHandler]);

def:priv deduce_all_threads -> i32;

def faulthandler_fatal_error(signum: i32);

def:priv faulthandler_allocate_stack -> i32;

def:priv faulthandler_enable -> i32;

def faulthandler_py_enable(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def:priv faulthandler_disable;

def faulthandler_disable_py(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def faulthandler_is_enabled(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def faulthandler_thread(unused: ptr);

def:priv cancel_dump_traceback_later;

def:priv format_timeout(us_in: i64) -> ptr[u8];

def faulthandler_dump_traceback_later(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def faulthandler_cancel_dump_traceback_later_py(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def:priv faulthandler_register(signum: i32, chain: i32, previous_p: ptr) -> i32;

def:priv user_i32(user: ptr[u8], offset: i64) -> i32;

def:priv set_user_i32(user: ptr[u8], offset: i64, value: i32);

def faulthandler_user(signum: i32);

def:priv check_signum(signum: i32) -> bool;

def faulthandler_register_py(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject];

def:priv faulthandler_unregister(user: ptr[u8], signum: i32) -> i32;

def faulthandler_unregister_py(
    self_: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject];

def:priv faulthandler_suppress_crash_report;

def:priv opaque_null -> int;

def faulthandler_read_null(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv faulthandler_raise_sigsegv;

def faulthandler_sigsegv(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def faulthandler_fatal_error_thread(plock: ptr);

def faulthandler_fatal_error_c_thread(
    self_: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject];

def faulthandler_sigfpe(self_: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject];

def faulthandler_sigabrt(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv stack_overflow(min_sp: u64, max_sp: u64) -> tuple[u64, u64];

def faulthandler_stack_overflow(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def:priv faulthandler_init_enable -> i32;

def PyExec_faulthandler(module: ptr[PyObject]) -> i32;

impl runtime_at(offset: i64) -> ptr[u8] {
    return ptr[u8](addressof(_PyRuntime)) + offset;
}

impl fatal_i32(offset: i64) -> i32 {
    return ptr[i32](runtime_at(offset)).view(1)[0];
}

impl set_fatal_i32(offset: i64, value: i32) {
    ptr[i32](runtime_at(offset)).view(1)[0] = value;
}

impl runtime_object(offset: i64) -> ptr[PyObject] {
    return ptr[ptr[PyObject]](runtime_at(offset)).view(1)[0];
}

impl runtime_interp(offset: i64) -> ptr[PyInterpreterState] {
    return ptr[ptr[PyInterpreterState]](runtime_at(offset)).view(1)[0];
}

impl thread_ptr(offset: i64) -> ptr {
    return ptr[ptr](runtime_at(offset)).view(1)[0];
}

impl set_thread_ptr(offset: i64, value: ptr) {
    ptr[ptr](runtime_at(offset)).view(1)[0] = value;
}

impl runtime_xsetref(offset: i64, value: ptr[PyObject]) {
    slot = ptr[ptr[PyObject]](runtime_at(offset));
    old = slot.view(1)[0];
    slot.view(1)[0] = value;
    object_xdecref(old);
}

impl user_signals_base -> ptr[u8] {
    return ptr[ptr[u8]](runtime_at(_PyRuntimeState_FAULTHANDLER_USER_SIGNALS)).view(1)[
        0
    ];
}

impl set_user_signals_base(base: ptr[u8]) {
    ptr[ptr[u8]](runtime_at(_PyRuntimeState_FAULTHANDLER_USER_SIGNALS)).view(1)[0] = base;
}

impl user_signal(signum: i32) -> ptr[u8] {
    return user_signals_base() + i64(signum) * faulthandler_user_signal_SIZE;
}

impl handler_at(i: i64) -> ptr[FaultHandler] {
    return ptr[FaultHandler](addressof(faulthandler_handlers)) + i;
}

impl handler_previous(handler: ptr[FaultHandler]) -> ptr {
    return ptr(ptr[u8](handler) + FAULT_HANDLER_PREVIOUS);
}

impl init_handler_signums {
    handler_at(0).view(1)[0].signum = i32(SIGBUS);
    handler_at(1).view(1)[0].signum = i32(SIGILL);
    handler_at(2).view(1)[0].signum = i32(SIGFPE);
    handler_at(3).view(1)[0].signum = i32(SIGABRT);
    handler_at(4).view(1)[0].signum = i32(SIGSEGV);
}

impl puts(fd: i32, text: ptr[u8]) {
    _Py_write_noraise(fd, ptr(text), strlen(text));
}

impl faulthandler_get_fileno(file_in: ptr[PyObject]) -> tuple[i32, ptr[PyObject]] {
    file = file_in;
    if not file or file == Py_None {
        file = _PySys_GetRequiredAttr(py_id(_Py_ID_stderr));
        if not file {
            return (i32(-1), NULL);
        }
        if file == Py_None {
            PyErr_SetString(PyExc_RuntimeError, ptr[u8]("sys.stderr is None"));
            object_decref(file);
            return (i32(-1), NULL);
        }
    } elif long_check(file) {
        if object_type(file) == ptr[PyTypeObject](addressof(PyBool_Type)) {
            if PyErr_WarnEx(
                PyExc_RuntimeWarning, ptr[u8]("bool is used as a file descriptor"), 1
            )
                != 0 {
                return (i32(-1), NULL);
            }
        }
        fd = PyLong_AsInt(file);
        if fd == -1 and PyErr_Occurred() != NULL {
            return (i32(-1), NULL);
        }
        if fd < 0 {
            PyErr_SetString(
                PyExc_ValueError, ptr[u8]("file is not a valid file descriptor")
            );
            return (i32(-1), NULL);
        }
        return (fd, NULL);
    } else {
        object_incref(file);
    }

    result = call_method_no_args(file, py_id(_Py_ID_fileno));
    if not result {
        object_decref(file);
        return (i32(-1), NULL);
    }

    fd = i32(-1);
    if long_check(result) {
        fd_long = PyLong_AsLong(result);
        if 0 <= fd_long and fd_long < INT_MAX {
            fd = i32(fd_long);
        }
    }
    object_decref(result);

    if fd == -1 {
        PyErr_SetString(
            PyExc_RuntimeError, ptr[u8]("file.fileno() is not a valid file descriptor")
        );
        object_decref(file);
        return (i32(-1), NULL);
    }

    if _PyFile_Flush(file) < 0 {
        PyErr_Clear();
    }
    return (fd, file);
}

impl get_thread_state -> ptr[PyThreadState] {
    tstate = current_tstate();
    if not tstate {
        PyErr_SetString(
            PyExc_RuntimeError, ptr[u8]("unable to get the current thread state")
        );
        return ptr[PyThreadState]();
    }
    return tstate;
}

impl faulthandler_dump_traceback(
    fd: i32, all_threads: i32, interp: ptr[PyInterpreterState]
) {
    reentrant = int(addressof(dump_traceback_reentrant));
    if __atomic_load_i32(reentrant, 0) != i32(0) {
        return;
    }
    __atomic_store_i32(reentrant, i32(1), 0);

    tstate = PyGILState_GetThisThreadState();
    if all_threads == 1 {
        _Py_DumpTracebackThreads(fd, ptr[PyInterpreterState](), tstate);
    } else {
        if all_threads == FT_IGNORE_ALL_THREADS {
            puts(fd, ptr[u8]("<Cannot show all threads while the GIL is disabled>\n"));
        }
        if tstate {
            _Py_DumpTraceback(fd, tstate);
        }
    }

    __atomic_store_i32(reentrant, i32(0), 0);
}

impl faulthandler_dump_c_stack(fd: i32) {
    reentrant = int(addressof(dump_c_stack_reentrant));
    if __atomic_load_i32(reentrant, 0) != i32(0) {
        return;
    }
    __atomic_store_i32(reentrant, i32(1), 0);

    if fatal_i32(_PyRuntimeState_FAULTHANDLER_FATAL_ERROR_C_STACK) != 0 {
        puts(fd, ptr[u8]("\n"));
        _Py_DumpStack(fd);
    }

    __atomic_store_i32(reentrant, i32(0), 0);
}

impl faulthandler_dump_traceback_py(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(name="dump_traceback").parse_keywords(
            args, kwargs, "|Op", ["file", "all_threads"]
        );
    } except boundary_failure {
        return NULL;
    }
    file_arg = values[0].object if values[0].given else NULL;
    all_threads = i32(1);
    if values[1].given and not values[1].flag {
        all_threads = i32(0);
    }

    (fd, file) = faulthandler_get_fileno(file_arg);
    if fd < 0 {
        return NULL;
    }

    tstate = get_thread_state();
    if not tstate {
        object_xdecref(file);
        return NULL;
    }

    if all_threads != 0 {
        interp = current_interp();

        _PyEval_StopTheWorld(interp);
        errmsg = _Py_DumpTracebackThreads(fd, ptr[PyInterpreterState](), tstate);
        _PyEval_StartTheWorld(interp);
        if errmsg {
            PyErr_Format(PyExc_RuntimeError, ptr[u8]("%s"), errmsg);
            object_xdecref(file);
            return NULL;
        }
    } else {
        _Py_DumpTraceback(fd, tstate);
    }
    object_xdecref(file);

    if PyErr_CheckSignals() != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl faulthandler_dump_c_stack_py(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(name="dump_c_stack").parse_keywords(
            args, kwargs, "|O", ["file"]
        );
    } except boundary_failure {
        return NULL;
    }
    file_arg = values[0].object if values[0].given else NULL;

    (fd, file) = faulthandler_get_fileno(file_arg);
    if fd < 0 {
        return NULL;
    }

    _Py_DumpStack(fd);
    object_xdecref(file);

    if PyErr_CheckSignals() != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl faulthandler_disable_fatal_handler(handler: ptr[FaultHandler]) {
    if handler.view(1)[0].enabled == 0 {
        return;
    }
    handler.view(1)[0].enabled = 0;
    sigaction(handler.view(1)[0].signum, handler_previous(handler), ptr());
}

impl deduce_all_threads -> i32 {
    return fatal_i32(_PyRuntimeState_FAULTHANDLER_FATAL_ERROR_ALL_THREADS);
}

impl faulthandler_fatal_error(signum: i32) {
    fd = fatal_i32(_PyRuntimeState_FAULTHANDLER_FATAL_ERROR_FD);
    save_errno = jacpy_errno();

    if fatal_i32(_PyRuntimeState_FAULTHANDLER_FATAL_ERROR_ENABLED) == 0 {
        return;
    }

    found = False;
    handler = handler_at(0);
    i = i64(0);
    while i < FAULTHANDLER_NSIGNALS {
        handler = handler_at(i);
        if handler.view(1)[0].signum == signum {
            found = True;
            break;
        }
        i += 1;
    }

    faulthandler_disable_fatal_handler(handler);

    if found {
        puts(fd, ptr[u8]("Fatal Python error: "));
        puts(fd, handler.view(1)[0].name);
        puts(fd, ptr[u8]("\n\n"));
    } else {
        puts(fd, ptr[u8]("Fatal Python error from unexpected signum: "));
        _Py_DumpDecimal(fd, u64.wrap(i64(signum)));
        puts(fd, ptr[u8]("\n\n"));
    }

    interp = runtime_interp(_PyRuntimeState_FAULTHANDLER_FATAL_ERROR_INTERP);
    faulthandler_dump_traceback(fd, deduce_all_threads(), interp);
    faulthandler_dump_c_stack(fd);

    _Py_DumpExtensionModules(fd, interp);

    jacpy_set_errno(save_errno);

    pthread_kill(pthread_self(), signum);
}

impl faulthandler_allocate_stack -> i32 {
    stack = runtime_at(_PyRuntimeState_FAULTHANDLER_STACK);
    stack_sp = ptr[ptr](stack + stack_t_SS_SP);
    if stack_sp.view(1)[0] {
        return 0;
    }
    stack_sp.view(1)[0] = PyMem_Malloc(ptr[u64](stack + stack_t_SS_SIZE).view(1)[0]);
    if not stack_sp.view(1)[0] {
        PyErr_NoMemory();
        return -1;
    }

    err = sigaltstack(
        ptr(stack), ptr(runtime_at(_PyRuntimeState_FAULTHANDLER_OLD_STACK))
    );
    if err != 0 {
        PyErr_SetFromErrno(PyExc_OSError);

        PyMem_Free(stack_sp.view(1)[0]);
        stack_sp.view(1)[0] = ptr();
        return -1;
    }
    return 0;
}

impl faulthandler_enable -> i32 {
    if fatal_i32(_PyRuntimeState_FAULTHANDLER_FATAL_ERROR_ENABLED) != 0 {
        return 0;
    }
    set_fatal_i32(_PyRuntimeState_FAULTHANDLER_FATAL_ERROR_ENABLED, 1);
    init_handler_signums();

    if faulthandler_allocate_stack() < 0 {
        return -1;
    }

    _Py_InitDumpStack();

    action_slots: own SignalBuffer = SignalBuffer();
    action = ptr[u8](jacpy_stack_address(&mut action_slots));
    i = i64(0);
    while i < FAULTHANDLER_NSIGNALS {
        handler = handler_at(i);
        memset(ptr(action), 0, u64(sigaction_SIZE));
        ptr[ptr](action + sigaction_SA_HANDLER).view(1)[0] = ptr(
            faulthandler_fatal_error
        );
        sigemptyset(ptr(action + sigaction_SA_MASK));

        ptr[i32](action + sigaction_SA_FLAGS).view(1)[0] = i32(SA_NODEFER)
            | i32(SA_ONSTACK);
        err = sigaction(
            handler.view(1)[0].signum, ptr(action), handler_previous(handler)
        );
        if err != 0 {
            PyErr_SetFromErrno(PyExc_RuntimeError);
            return -1;
        }
        handler.view(1)[0].enabled = 1;
        i += 1;
    }
    return 0;
}

impl faulthandler_py_enable(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(name="enable").parse_keywords(
            args, kwargs, "|Opp", ["file", "all_threads", "c_stack"]
        );
    } except boundary_failure {
        return NULL;
    }
    file_arg = values[0].object if values[0].given else NULL;
    all_threads = i32(1);
    if values[1].given and not values[1].flag {
        all_threads = i32(0);
    }
    c_stack = i32(1);
    if values[2].given and not values[2].flag {
        c_stack = i32(0);
    }

    (fd, file) = faulthandler_get_fileno(file_arg);
    if fd < 0 {
        return NULL;
    }

    tstate = get_thread_state();
    if not tstate {
        object_xdecref(file);
        return NULL;
    }

    runtime_xsetref(_PyRuntimeState_FAULTHANDLER_FATAL_ERROR_FILE, file);
    set_fatal_i32(_PyRuntimeState_FAULTHANDLER_FATAL_ERROR_FD, fd);
    set_fatal_i32(_PyRuntimeState_FAULTHANDLER_FATAL_ERROR_ALL_THREADS, all_threads);
    ptr[ptr[PyInterpreterState]](
        runtime_at(_PyRuntimeState_FAULTHANDLER_FATAL_ERROR_INTERP)
    ).view(
        1
    )[0] = PyThreadState_GetInterpreter(tstate);
    set_fatal_i32(_PyRuntimeState_FAULTHANDLER_FATAL_ERROR_C_STACK, c_stack);

    if faulthandler_enable() < 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl faulthandler_disable {
    if fatal_i32(_PyRuntimeState_FAULTHANDLER_FATAL_ERROR_ENABLED) != 0 {
        set_fatal_i32(_PyRuntimeState_FAULTHANDLER_FATAL_ERROR_ENABLED, 0);
        i = i64(0);
        while i < FAULTHANDLER_NSIGNALS {
            faulthandler_disable_fatal_handler(handler_at(i));
            i += 1;
        }
    }
    runtime_xsetref(_PyRuntimeState_FAULTHANDLER_FATAL_ERROR_FILE, NULL);
}

impl faulthandler_disable_py(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    if fatal_i32(_PyRuntimeState_FAULTHANDLER_FATAL_ERROR_ENABLED) == 0 {
        return PyBool_FromLong(0);
    }
    faulthandler_disable();
    return PyBool_FromLong(1);
}

impl faulthandler_is_enabled(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    return PyBool_FromLong(
        i64(fatal_i32(_PyRuntimeState_FAULTHANDLER_FATAL_ERROR_ENABLED))
    );
}

impl faulthandler_thread(unused: ptr) {
    set_slots: own SignalBuffer = SignalBuffer();
    blocked = ptr(jacpy_stack_address(&mut set_slots));
    sigfillset(blocked);
    pthread_sigmask(i32(SIG_SETMASK), blocked, ptr());

    while True {
        st = PyThread_acquire_lock_timed(
            thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_CANCEL_EVENT),
            ptr[i64](runtime_at(_PyRuntimeState_FAULTHANDLER_THREAD_TIMEOUT_US)).view(1)[
                0
            ],
            0
        );
        if st == PY_LOCK_ACQUIRED {
            PyThread_release_lock(
                thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_CANCEL_EVENT)
            );
            break;
        }

        fd = fatal_i32(_PyRuntimeState_FAULTHANDLER_THREAD_FD);
        _Py_write_noraise(
            fd,
            thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_HEADER),
            ptr[u64](runtime_at(_PyRuntimeState_FAULTHANDLER_THREAD_HEADER_LEN)).view(1)[
                0
            ]
        );

        errmsg = _Py_DumpTracebackThreads(
            fd,
            runtime_interp(_PyRuntimeState_FAULTHANDLER_THREAD_INTERP),
            ptr[PyThreadState]()
        );
        ok = not errmsg;

        if fatal_i32(_PyRuntimeState_FAULTHANDLER_THREAD_EXIT) != 0 {
            _exit(1);
        }
        if not (ok and fatal_i32(_PyRuntimeState_FAULTHANDLER_THREAD_REPEAT) != 0) {
            break;
        }
    }

    PyThread_release_lock(thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_RUNNING));
}

impl cancel_dump_traceback_later {
    if not thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_CANCEL_EVENT) {
        return;
    }

    PyThread_release_lock(thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_CANCEL_EVENT));

    PyThread_acquire_lock(thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_RUNNING), 1);
    PyThread_release_lock(thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_RUNNING));

    PyThread_acquire_lock(
        thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_CANCEL_EVENT), 1
    );

    runtime_xsetref(_PyRuntimeState_FAULTHANDLER_THREAD_FILE, NULL);
    header = thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_HEADER);
    if header {
        PyMem_Free(header);
        set_thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_HEADER, ptr());
    }
}

impl format_timeout(us_in: i64) -> ptr[u8] {
    us = us_in;
    sec = u64(us // SEC_TO_US);
    us = us % SEC_TO_US;

    minute = sec // u64(60);
    sec = sec % u64(60);
    hour = minute // u64(60);
    minute = minute % u64(60);

    buffer_slots: own SignalBuffer = SignalBuffer();
    buffer = ptr[u8](jacpy_stack_address(&mut buffer_slots));
    if us != 0 {
        PyOS_snprintf(
            buffer,
            u64(100),
            ptr[u8]("Timeout (%lu:%02lu:%02lu.%06u)!\n"),
            hour,
            minute,
            sec,
            u32.wrap(us)
        );
    } else {
        PyOS_snprintf(
            buffer, u64(100), ptr[u8]("Timeout (%lu:%02lu:%02lu)!\n"), hour, minute, sec
        );
    }
    return _PyMem_Strdup(buffer);
}

impl faulthandler_dump_traceback_later(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(name="dump_traceback_later").parse_keywords(
            args, kwargs, "O|iOi", ["timeout", "repeat", "file", "exit"]
        );
    } except boundary_failure {
        return NULL;
    }
    timeout_obj = values[0].object;
    repeat = i32(values[1].signed) if values[1].given else i32(0);
    file_arg = values[2].object if values[2].given else NULL;
    exit_flag = i32(values[3].signed) if values[3].given else i32(0);

    timeout: i64 = 0;
    if _PyTime_FromSecondsObject(&mut timeout, timeout_obj, _PyTime_ROUND_TIMEOUT)
        < 0 {
        return NULL;
    }
    timeout_us = _PyTime_AsMicroseconds(timeout, _PyTime_ROUND_TIMEOUT);
    if timeout_us <= 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("timeout must be greater than 0"));
        return NULL;
    }

    if timeout_us > PY_TIMEOUT_MAX or timeout_us // SEC_TO_US > LONG_MAX {
        PyErr_SetString(PyExc_OverflowError, ptr[u8]("timeout value is too large"));
        return NULL;
    }

    tstate = get_thread_state();
    if not tstate {
        return NULL;
    }

    (fd, file) = faulthandler_get_fileno(file_arg);
    if fd < 0 {
        return NULL;
    }

    if not thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_RUNNING) {
        set_thread_ptr(
            _PyRuntimeState_FAULTHANDLER_THREAD_RUNNING, PyThread_allocate_lock()
        );
        if not thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_RUNNING) {
            object_xdecref(file);
            return PyErr_NoMemory();
        }
    }
    if not thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_CANCEL_EVENT) {
        set_thread_ptr(
            _PyRuntimeState_FAULTHANDLER_THREAD_CANCEL_EVENT, PyThread_allocate_lock()
        );
        if not thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_CANCEL_EVENT)
            or not thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_RUNNING) {
            object_xdecref(file);
            return PyErr_NoMemory();
        }

        PyThread_acquire_lock(
            thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_CANCEL_EVENT), 1
        );
    }

    header = format_timeout(timeout_us);
    if not header {
        object_xdecref(file);
        return PyErr_NoMemory();
    }
    header_len = strlen(header);

    cancel_dump_traceback_later();

    runtime_xsetref(_PyRuntimeState_FAULTHANDLER_THREAD_FILE, file);
    set_fatal_i32(_PyRuntimeState_FAULTHANDLER_THREAD_FD, fd);

    ptr[i64](runtime_at(_PyRuntimeState_FAULTHANDLER_THREAD_TIMEOUT_US)).view(1)[0] = timeout_us;
    set_fatal_i32(_PyRuntimeState_FAULTHANDLER_THREAD_REPEAT, repeat);
    ptr[ptr[PyInterpreterState]](
        runtime_at(_PyRuntimeState_FAULTHANDLER_THREAD_INTERP)
    ).view(
        1
    )[0] = PyThreadState_GetInterpreter(tstate);
    set_fatal_i32(_PyRuntimeState_FAULTHANDLER_THREAD_EXIT, exit_flag);
    set_thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_HEADER, ptr(header));
    ptr[u64](runtime_at(_PyRuntimeState_FAULTHANDLER_THREAD_HEADER_LEN)).view(1)[0] = header_len;

    PyThread_acquire_lock(thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_RUNNING), 1);

    if PyThread_start_new_thread(ptr(faulthandler_thread), ptr())
        == PYTHREAD_INVALID_THREAD_ID {
        PyThread_release_lock(thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_RUNNING));
        runtime_xsetref(_PyRuntimeState_FAULTHANDLER_THREAD_FILE, NULL);
        PyMem_Free(ptr(header));
        set_thread_ptr(_PyRuntimeState_FAULTHANDLER_THREAD_HEADER, ptr());
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("unable to start watchdog thread"));
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl faulthandler_cancel_dump_traceback_later_py(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    cancel_dump_traceback_later();
    return object_new_ref(Py_None);
}

impl faulthandler_register(signum: i32, chain: i32, previous_p: ptr) -> i32 {
    action_slots: own SignalBuffer = SignalBuffer();
    action = ptr[u8](jacpy_stack_address(&mut action_slots));
    ptr[ptr](action + sigaction_SA_HANDLER).view(1)[0] = ptr(faulthandler_user);
    sigemptyset(ptr(action + sigaction_SA_MASK));

    flags = i32(SA_RESTART);
    if chain != 0 {
        flags = i32(SA_NODEFER);
    }

    flags = flags | i32(SA_ONSTACK);
    ptr[i32](action + sigaction_SA_FLAGS).view(1)[0] = flags;
    return sigaction(signum, ptr(action), previous_p);
}

impl user_i32(user: ptr[u8], offset: i64) -> i32 {
    return ptr[i32](user + offset).view(1)[0];
}

impl set_user_i32(user: ptr[u8], offset: i64, value: i32) {
    ptr[i32](user + offset).view(1)[0] = value;
}

impl faulthandler_user(signum: i32) {
    save_errno = jacpy_errno();
    user = user_signal(signum);
    if user_i32(user, faulthandler_user_signal_ENABLED) == 0 {
        return;
    }

    faulthandler_dump_traceback(
        user_i32(user, faulthandler_user_signal_FD),
        user_i32(user, faulthandler_user_signal_ALL_THREADS),
        ptr[ptr[PyInterpreterState]](user + faulthandler_user_signal_INTERP).view(1)[0]
    );

    if user_i32(user, faulthandler_user_signal_CHAIN) != 0 {
        sigaction(signum, ptr(user + faulthandler_user_signal_PREVIOUS), ptr());
        jacpy_set_errno(save_errno);

        pthread_kill(pthread_self(), signum);

        save_errno = jacpy_errno();
        faulthandler_register(
            signum, user_i32(user, faulthandler_user_signal_CHAIN), ptr()
        );
        jacpy_set_errno(save_errno);
    }
}

impl check_signum(signum: i32) -> bool {
    init_handler_signums();
    i = i64(0);
    while i < FAULTHANDLER_NSIGNALS {
        if handler_at(i).view(1)[0].signum == signum {
            PyErr_Format(
                PyExc_RuntimeError,
                ptr[u8]("signal %i cannot be registered, use enable() instead"),
                signum
            );
            return False;
        }
        i += 1;
    }
    if signum < 1 or Py_NSIG <= i64(signum) {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("signal number out of range"));
        return False;
    }
    return True;
}

impl faulthandler_register_py(
    self_: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(name="register").parse_keywords(
            args, kwargs, "i|Opp", ["signum", "file", "all_threads", "chain"]
        );
    } except boundary_failure {
        return NULL;
    }
    signum = i32(values[0].signed);
    file_arg = values[1].object if values[1].given else NULL;
    all_threads = i32(1);
    if values[2].given and not values[2].flag {
        all_threads = i32(0);
    }
    chain = i32(0);
    if values[3].given and values[3].flag {
        chain = i32(1);
    }

    if not check_signum(signum) {
        return NULL;
    }

    tstate = get_thread_state();
    if not tstate {
        return NULL;
    }

    (fd, file) = faulthandler_get_fileno(file_arg);
    if fd < 0 {
        return NULL;
    }

    if not user_signals_base() {
        base = ptr[u8](PyMem_Calloc(u64(Py_NSIG), u64(faulthandler_user_signal_SIZE)));
        if not base {
            object_xdecref(file);
            return PyErr_NoMemory();
        }
        set_user_signals_base(base);
    }
    user = user_signal(signum);

    if user_i32(user, faulthandler_user_signal_ENABLED) == 0 {
        if faulthandler_allocate_stack() < 0 {
            object_xdecref(file);
            return NULL;
        }

        previous_slots: own SignalBuffer = SignalBuffer();
        previous = ptr[u8](jacpy_stack_address(&mut previous_slots));
        err = faulthandler_register(signum, chain, ptr(previous));
        if err != 0 {
            PyErr_SetFromErrno(PyExc_OSError);
            object_xdecref(file);
            return NULL;
        }

        memcpy(
            ptr(user + faulthandler_user_signal_PREVIOUS),
            ptr(previous),
            u64(sigaction_SIZE)
        );
    }

    file_slot = ptr[ptr[PyObject]](user + faulthandler_user_signal_FILE);
    old_file = file_slot.view(1)[0];
    file_slot.view(1)[0] = file;
    object_xdecref(old_file);
    set_user_i32(user, faulthandler_user_signal_FD, fd);
    set_user_i32(user, faulthandler_user_signal_ALL_THREADS, all_threads);
    set_user_i32(user, faulthandler_user_signal_CHAIN, chain);
    ptr[ptr[PyInterpreterState]](user + faulthandler_user_signal_INTERP).view(1)[0] = PyThreadState_GetInterpreter(
        tstate
    );
    set_user_i32(user, faulthandler_user_signal_ENABLED, 1);

    return object_new_ref(Py_None);
}

impl faulthandler_unregister(user: ptr[u8], signum: i32) -> i32 {
    if user_i32(user, faulthandler_user_signal_ENABLED) == 0 {
        return 0;
    }
    set_user_i32(user, faulthandler_user_signal_ENABLED, 0);
    sigaction(signum, ptr(user + faulthandler_user_signal_PREVIOUS), ptr());
    file_slot = ptr[ptr[PyObject]](user + faulthandler_user_signal_FILE);
    old_file = file_slot.view(1)[0];
    file_slot.view(1)[0] = NULL;
    object_xdecref(old_file);
    set_user_i32(user, faulthandler_user_signal_FD, -1);
    return 1;
}

impl faulthandler_unregister_py(
    self_: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(name="unregister").parse(args, "i");
    } except boundary_failure {
        return NULL;
    }
    signum = i32(values[0].signed);

    if not check_signum(signum) {
        return NULL;
    }

    if not user_signals_base() {
        return PyBool_FromLong(0);
    }

    change = faulthandler_unregister(user_signal(signum), signum);
    return PyBool_FromLong(i64(change));
}

impl faulthandler_suppress_crash_report {
    rl = rlimit();
    if getrlimit(i32(RLIMIT_CORE), &mut rl) == 0 {
        rl.rlim_cur = u64(0);
        setrlimit(i32(RLIMIT_CORE), &mut rl);
    }
}

impl opaque_null -> int {
    slots: own SignalBuffer = SignalBuffer();
    first = jacpy_stack_address(&mut slots);
    second = jacpy_stack_address(&mut slots);
    return first - second;
}

impl faulthandler_read_null(
    self_: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    faulthandler_suppress_crash_report();
    y = __atomic_load_i32(opaque_null(), 0);
    return PyLong_FromLong(i64(y));
}

impl faulthandler_raise_sigsegv {
    faulthandler_suppress_crash_report();
    pthread_kill(pthread_self(), i32(SIGSEGV));
}

impl faulthandler_sigsegv(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    try {
        values = ArgumentFormat(name="_sigsegv").parse(args, "|i");
    } except boundary_failure {
        return NULL;
    }
    release_gil = values[0].given and values[0].signed != 0;

    if release_gil {
        save = PyEval_SaveThread();
        faulthandler_raise_sigsegv();
        PyEval_RestoreThread(save);
    } else {
        faulthandler_raise_sigsegv();
    }
    return object_new_ref(Py_None);
}

impl faulthandler_fatal_error_thread(plock: ptr) {
    Py_FatalError(ptr[u8]("in new thread"));
}

impl faulthandler_fatal_error_c_thread(
    self_: ptr[PyObject], args: ptr[PyObject]
) -> ptr[PyObject] {
    faulthandler_suppress_crash_report();

    lock = PyThread_allocate_lock();
    if not lock {
        return PyErr_NoMemory();
    }

    PyThread_acquire_lock(lock, WAIT_LOCK);

    tid = PyThread_start_new_thread(ptr(faulthandler_fatal_error_thread), lock);
    if tid == PYTHREAD_INVALID_THREAD_ID {
        PyThread_free_lock(lock);
        PyErr_SetString(PyExc_RuntimeError, ptr[u8]("unable to start the thread"));
        return NULL;
    }

    PyThread_acquire_lock(lock, WAIT_LOCK);
    PyThread_release_lock(lock);
    PyThread_free_lock(lock);
    return object_new_ref(Py_None);
}

impl faulthandler_sigfpe(self_: ptr[PyObject], dummy: ptr[PyObject]) -> ptr[PyObject] {
    faulthandler_suppress_crash_report();

    pthread_kill(pthread_self(), i32(SIGFPE));
    return PyLong_FromLong(0);
}

impl faulthandler_sigabrt(self_: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    faulthandler_suppress_crash_report();
    abort();
    return object_new_ref(Py_None);
}

impl stack_overflow(min_sp: u64, max_sp: u64) -> tuple[u64, u64] {
    slots: own SignalBuffer = SignalBuffer();
    buffer = ptr[u8](jacpy_stack_address(&mut slots));
    sp = u64.wrap(int(buffer));
    if sp < min_sp or max_sp < sp {
        return (sp, u64(1));
    }
    buffer.view(160)[0] = u8(1);
    buffer.view(160)[159] = u8(0);
    (stop, depth) = stack_overflow(min_sp, max_sp);
    return (stop, depth + u64(1));
}

impl faulthandler_stack_overflow(
    self_: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    slots: own SignalBuffer = SignalBuffer();
    sp = u64.wrap(jacpy_stack_address(&mut slots));

    faulthandler_suppress_crash_report();

    lower_limit = u64(0);
    if STACK_OVERFLOW_MAX_SIZE <= sp {
        lower_limit = sp - STACK_OVERFLOW_MAX_SIZE;
    }

    upper_limit = u64(0xFFFFFFFFFFFFFFFF);
    if u64(0xFFFFFFFFFFFFFFFF) - STACK_OVERFLOW_MAX_SIZE >= sp {
        upper_limit = sp + STACK_OVERFLOW_MAX_SIZE;
    }

    (stop, depth) = stack_overflow(lower_limit, upper_limit);
    size = u64(0);
    if sp < stop {
        size = stop - sp;
    } else {
        size = sp - stop;
    }
    PyErr_Format(
        PyExc_RuntimeError,
        ptr[u8](
            "unable to raise a stack overflow (allocated %zu bytes on the stack, %zu recursive calls)"
        ),
        i64.wrap(size),
        i64.wrap(depth)
    );
    return NULL;
}

impl faulthandler_init_enable -> i32 {
    enable = PyImport_ImportModuleAttrString("faulthandler", "enable");
    if not enable {
        return -1;
    }
    res = PyObject_CallNoArgs(enable);
    object_decref(enable);
    if not res {
        return -1;
    }
    object_decref(res);
    return 0;
}

impl PyExec_faulthandler(module: ptr[PyObject]) -> i32 {
    return 0;
}
