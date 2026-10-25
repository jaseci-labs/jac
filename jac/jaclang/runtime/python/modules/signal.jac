import from c {
    def sigaction(sig: i32, action: ptr, old_action: ptr) -> i32;  def sigemptyset(
        mask: ptr
    ) -> i32;  def sigfillset(signals: ptr) -> i32;  def sigismember(
        signals: ptr, sig: i32
    ) -> i32;  def sigpending(mask: ptr) -> i32;  def sigwait(
        mask: ptr, signum: &mut i32
    ) -> i32;  def pthread_sigmask(how: i32, signals: ptr, old_signals: ptr) -> i32;  def pthread_kill(
        thread: u64, sig: i32
    ) -> i32;  def pthread_self -> u64;  def alarm(seconds: u32) -> u32;  def pause -> i32;  def strsignal(
        sig: i32
    ) -> ptr[u8];  def strstr(haystack: ptr[u8], needle: ptr[u8]) -> ptr[u8];  def setitimer(
        which: i32, new_value: ptr, old_value: ptr
    ) -> i32;  def getitimer(which: i32, value: ptr) -> i32;  def PyOS_setsig(
        sig: i32, handler: ptr
    ) -> ptr;  def PyOS_getsig(sig: i32) -> ptr;  def _Py_write_noraise(
        fd: i32, buf: ptr, count: u64
    ) -> i64;  def _PyEval_SignalReceived;  def _PyEval_AddPendingCall(
        interp: ptr[u8], func: ptr, arg: ptr, flags: i32
    ) -> i32;  def _PyInterpreterState_Main -> ptr[PyInterpreterState];  def _Py_RunGC(
        tstate: ptr[PyThreadState]
    );  def _PyObject_Call(
        tstate: ptr[PyThreadState],
        callable: ptr[PyObject],
        args: ptr[PyObject],
        kwargs: ptr[PyObject]
    ) -> ptr[PyObject];  def jacpy_stack_address(slots: &mut SignalBuffer) -> int;  def _Py_Sigset_Converter(
        value: ptr[PyObject], address: ptr
    ) -> i32;  def _PyLong_FromUid(uid: u32) -> ptr[PyObject];  def PyModule_GetState(
        m: ptr[PyObject]
    ) -> ptr;  obj SignalBuffer {
        has w0: u64 = u64(0),
            w1: u64 = u64(0),
            w2: u64 = u64(0),
            w3: u64 = u64(0),
            w4: u64 = u64(0),
            w5: u64 = u64(0),
            w6: u64 = u64(0),
            w7: u64 = u64(0),
            w8: u64 = u64(0),
            w9: u64 = u64(0),
            w10: u64 = u64(0),
            w11: u64 = u64(0),
            w12: u64 = u64(0),
            w13: u64 = u64(0),
            w14: u64 = u64(0),
            w15: u64 = u64(0),
            w16: u64 = u64(0),
            w17: u64 = u64(0),
            w18: u64 = u64(0),
            w19: u64 = u64(0);
    }  obj itimerval {
        has it_interval: timeval = timeval(),
            it_value: timeval = timeval();
    }  obj SignalModuleState {
        has default_handler: ptr[PyObject] = ptr[PyObject](),
            ignore_handler: ptr[PyObject] = ptr[PyObject](),
            itimer_error: ptr[PyObject] = ptr[PyObject](),
            siginfo_type: ptr[PyTypeObject] = ptr[PyTypeObject]();
    }  def PyErr_CheckSignals -> i32 {
        tstate = current_tstate();

        if eval_breaker_bit_is_set(tstate, _PY_GC_SCHEDULED_BIT) {
            unset_eval_breaker_bit(tstate, _PY_GC_SCHEDULED_BIT);
            _Py_RunGC(tstate);
        }

        if not thread_can_handle_signals(tstate_interp(tstate)) {
            return 0;
        }
        return _PyErr_CheckSignalsTstate(tstate);
    }  def _PyErr_CheckSignalsTstate(tstate: ptr[PyThreadState]) -> i32 {
        if __atomic_load_i32(is_tripped_addr(), 5) == i32(0) {
            return 0;
        }

        __atomic_store_i32(is_tripped_addr(), i32(0), 5);

        frame = thread_state_get_frame(tstate);
        i = i32(1);
        while i64(i) < Py_NSIG {
            if __atomic_load_i32(handler_tripped_addr(i), 0) == i32(0) {
                i += 1;
                continue;
            }
            __atomic_store_i32(handler_tripped_addr(i), i32(0), 0);

            func = get_handler(i);
            if not func
                or func == Py_None
                or compare_handler(func, ignore_handler())
                or compare_handler(func, default_handler()) {
                PyErr_Format(
                    PyExc_OSError, "Signal %i ignored due to race condition", i
                );
                PyErr_FormatUnraisable(
                    "Exception ignored while calling signal handler"
                );
                i += 1;
                continue;
            }
            arglist = NULL;
            if not frame {
                arglist = Py_BuildValue(ptr[u8]("(iO)"), i, Py_None);
            } else {
                f = frame_get_frame_object(frame);
                if f {
                    arglist = Py_BuildValue(ptr[u8]("(iO)"), i, f);
                }
            }
            result = NULL;
            if arglist {
                result = _PyObject_Call(tstate, func, arglist, NULL);
                object_decref(arglist);
            }
            if not result {
                __atomic_store_i32(is_tripped_addr(), i32(1), 5);
                return -1;
            }
            object_decref(result);
            i += 1;
        }
        return 0;
    }  def _PyErr_CheckSignals -> i32 {
        return _PyErr_CheckSignalsTstate(current_tstate());
    }  def PyErr_SetInterruptEx(signum: i32) -> i32 {
        if signum < 1 or i64(signum) >= Py_NSIG {
            return -1;
        }
        func = get_handler(signum);
        if not compare_handler(func, ignore_handler())
            and not compare_handler(func, default_handler()) {
            trip_signal(signum);
        }
        return 0;
    }  def PyErr_SetInterrupt {
        PyErr_SetInterruptEx(i32(SIGINT));
    }  def _Py_RestoreSignals {
        PyOS_setsig(i32(SIGPIPE), ptr(SIG_DFL));
        PyOS_setsig(i32(SIGXFSZ), ptr(SIG_DFL));
    }  def _PySignal_Init(install_signal_handlers: i32) -> i32 {
        dflt = PyLong_FromVoidPtr(ptr(SIG_DFL));
        runtime_slot(_PyRuntimeState_SIGNALS_DEFAULT_HANDLER).view(1)[0] = dflt;
        if not dflt {
            return -1;
        }
        ignore = PyLong_FromVoidPtr(ptr(SIG_IGN));
        runtime_slot(_PyRuntimeState_SIGNALS_IGNORE_HANDLER).view(1)[0] = ignore;
        if not ignore {
            return -1;
        }

        signum = i32(1);
        while i64(signum) < Py_NSIG {
            __atomic_store_i32(handler_tripped_addr(signum), i32(0), 0);
            signum += 1;
        }

        if install_signal_handlers != 0 {
            if signal_install_handlers() < 0 {
                return -1;
            }
        }
        return 0;
    }  def _PySignal_Fini {
        signum = i32(1);
        while i64(signum) < Py_NSIG {
            func = get_handler(signum);
            __atomic_store_i32(handler_tripped_addr(signum), i32(0), 0);
            set_handler(signum, NULL);
            if func
                and func != Py_None
                and not compare_handler(func, default_handler())
                and not compare_handler(func, ignore_handler()) {
                PyOS_setsig(signum, ptr(SIG_DFL));
            }
            object_xdecref(func);
            signum += 1;
        }
        dflt_slot = runtime_slot(_PyRuntimeState_SIGNALS_DEFAULT_HANDLER);
        dflt = dflt_slot.view(1)[0];
        dflt_slot.view(1)[0] = NULL;
        object_xdecref(dflt);
        ignore_slot = runtime_slot(_PyRuntimeState_SIGNALS_IGNORE_HANDLER);
        ignore = ignore_slot.view(1)[0];
        ignore_slot.view(1)[0] = NULL;
        object_xdecref(ignore);
    }  def _PyOS_InterruptOccurred(tstate: ptr[PyThreadState]) -> i32 {
        ensure_tstate_not_null(ptr[u8]("_PyOS_InterruptOccurred"), tstate);
        if not thread_can_handle_signals(tstate_interp(tstate)) {
            return 0;
        }
        if __atomic_load_i32(handler_tripped_addr(i32(SIGINT)), 0) == i32(0) {
            return 0;
        }
        __atomic_store_i32(handler_tripped_addr(i32(SIGINT)), i32(0), 0);
        return 1;
    }  def PyOS_InterruptOccurred -> i32 {
        return _PyOS_InterruptOccurred(current_tstate());
    }  def _PySignal_AfterFork {
        clear_pending_signals();
    }  def _PyOS_IsMainThread -> i32 {
        return i32(1) if thread_can_handle_signals(current_interp()) else i32(0);
    }  def PySignal_SetWakeupFd(fd: i32) -> i32 {
        if fd < 0 {
            fd = -1;
        }
        old_fd = ptr[i32](wakeup_fd_addr()).view(1)[0];
        ptr[i32](wakeup_fd_addr()).view(1)[0] = fd;
        ptr[i32](wakeup_warn_addr()).view(1)[0] = 1;
        return old_fd;
    }
}

glob:priv SIG_DFL: Final[int] = 0,
     ITIMERVAL_VALUE: Final[i64] = 16,
     SIG_IGN: Final[int] = 1,
     SIG_ERR: Final[int] = -1,
     INVALID_FD: Final[i32] = -1;

def:priv runtime_addr(offset: i64) -> int;

def:priv runtime_slot(offset: i64) -> ptr[ptr[PyObject]];

def:priv handler_tripped_addr(i: i32) -> int;

def:priv handler_func_addr(i: i32) -> int;

def:priv is_tripped_addr -> int;

def:priv wakeup_fd_addr -> int;

def:priv wakeup_warn_addr -> int;

def default_handler -> ptr[PyObject];

def ignore_handler -> ptr[PyObject];

def get_handler(i: i32) -> ptr[PyObject];

def set_handler(i: i32, func: ptr[PyObject]);

def compare_handler(func: ptr[PyObject], dfl_ign_handler: ptr[PyObject]) -> bool;

def:priv long_check_exact(op: ptr[PyObject]) -> bool;

def:priv timeval_from_double(obj_: ptr[PyObject], tv: ptr[timeval]) -> i32;

def:priv double_from_timeval(tv: timeval) -> f64;

def:priv itimer_retval(iv: itimerval) -> ptr[PyObject];

def signal_default_int_handler_impl(
    module: ptr[PyObject], signalnum: i32, frame: ptr[PyObject]
) -> ptr[PyObject];

def:priv report_wakeup_write_error(data: ptr) -> i32;

def:priv trip_signal(sig_num: i32);

def signal_handler(sig_num: i32);

def signal_alarm_impl(module: ptr[PyObject], seconds: i32) -> i64;

def signal_pause_impl(module: ptr[PyObject]) -> ptr[PyObject];

def signal_raise_signal_impl(module: ptr[PyObject], signalnum: i32) -> ptr[PyObject];

def signal_signal_impl(
    module: ptr[PyObject], signalnum: i32, handler: ptr[PyObject]
) -> ptr[PyObject];

def signal_getsignal_impl(module: ptr[PyObject], signalnum: i32) -> ptr[PyObject];

def signal_strsignal_impl(module: ptr[PyObject], signalnum: i32) -> ptr[PyObject];

def signal_siginterrupt_impl(
    module: ptr[PyObject], signalnum: i32, flag: i32
) -> ptr[PyObject];

def signal_set_wakeup_fd_impl(
    module: ptr[PyObject], fdobj: ptr[PyObject], warn_on_full_buffer: bool
) -> ptr[PyObject];

def signal_setitimer_impl(
    module: ptr[PyObject], which: i32, seconds: ptr[PyObject], interval: ptr[PyObject]
) -> ptr[PyObject];

def signal_getitimer_impl(module: ptr[PyObject], which: i32) -> ptr[PyObject];

def:priv sigset_to_set(mask: ptr) -> ptr[PyObject];

def convert__Py_Sigset_Converter(value: ptr[PyObject], fname: str, label: str) -> ptr;

def signal_pthread_sigmask_impl(
    module: ptr[PyObject], how: i32, mask: ptr
) -> ptr[PyObject];

def signal_sigpending_impl(module: ptr[PyObject]) -> ptr[PyObject];

def signal_sigwait_impl(module: ptr[PyObject], sigset: ptr) -> ptr[PyObject];

def signal_valid_signals_impl(module: ptr[PyObject]) -> ptr[PyObject];

def:priv fill_siginfo(state: ptr[SignalModuleState], si: ptr[u8]) -> ptr[PyObject];

def signal_sigwaitinfo_impl(module: ptr[PyObject], sigset: ptr) -> ptr[PyObject];

def signal_sigtimedwait_impl(
    module: ptr[PyObject], sigset: ptr, timeout_obj: ptr[PyObject]
) -> ptr[PyObject];

def signal_pthread_kill_impl(
    module: ptr[PyObject], thread_id: u64, signalnum: i32
) -> ptr[PyObject];

def signal_pidfd_send_signal_impl(
    module: ptr[PyObject],
    pidfd: i32,
    signalnum: i32,
    siginfo: ptr[PyObject],
    flags: i32
) -> ptr[PyObject];

def get_signal_state(module: ptr[PyObject]) -> ptr[SignalModuleState];

def:priv signal_install_handlers -> i32;

def:priv clear_pending_signals;

impl runtime_addr(offset: i64) -> int {
    return int(ptr[u8](addressof(_PyRuntime))) + offset;
}

impl runtime_slot(offset: i64) -> ptr[ptr[PyObject]] {
    return ptr[ptr[PyObject]](ptr[u8](addressof(_PyRuntime)) + offset);
}

impl handler_tripped_addr(i: i32) -> int {
    return runtime_addr(_PyRuntimeState_SIGNALS_HANDLERS)
        + i64(i) * _signals_handler_SIZE;
}

impl handler_func_addr(i: i32) -> int {
    return handler_tripped_addr(i) + _signals_handler_FUNC;
}

impl is_tripped_addr -> int {
    return runtime_addr(_PyRuntimeState_SIGNALS_IS_TRIPPED);
}

impl wakeup_fd_addr -> int {
    return runtime_addr(_PyRuntimeState_SIGNALS_WAKEUP_FD);
}

impl wakeup_warn_addr -> int {
    return runtime_addr(_PyRuntimeState_SIGNALS_WAKEUP_WARN_ON_FULL_BUFFER);
}

impl default_handler -> ptr[PyObject] {
    return runtime_slot(_PyRuntimeState_SIGNALS_DEFAULT_HANDLER).view(1)[0];
}

impl ignore_handler -> ptr[PyObject] {
    return runtime_slot(_PyRuntimeState_SIGNALS_IGNORE_HANDLER).view(1)[0];
}

impl get_handler(i: i32) -> ptr[PyObject] {
    return ptr[PyObject](__atomic_load_i64(handler_func_addr(i), 5));
}

impl set_handler(i: i32, func: ptr[PyObject]) {
    __atomic_store_i64(handler_func_addr(i), int(func), 5);
}

impl compare_handler(func: ptr[PyObject], dfl_ign_handler: ptr[PyObject]) -> bool {
    if not func or not dfl_ign_handler {
        return False;
    }
    if not long_check_exact(func) {
        return False;
    }

    return PyObject_RichCompareBool(func, dfl_ign_handler, Py_EQ) == 1;
}

impl long_check_exact(op: ptr[PyObject]) -> bool {
    return object_type(op) == ptr[PyTypeObject](addressof(PyLong_Type));
}

impl timeval_from_double(obj_: ptr[PyObject], tv: ptr[timeval]) -> i32 {
    if not obj_ {
        tv.view(1)[0] = timeval();
        return 0;
    }
    t: i64 = 0;
    if _PyTime_FromSecondsObject(&mut t, obj_, _PyTime_ROUND_CEILING) < 0 {
        return -1;
    }
    value = timeval();
    status = _PyTime_AsTimeval(t, &mut value, _PyTime_ROUND_CEILING);
    tv.view(1)[0] = value;
    return status;
}

impl double_from_timeval(tv: timeval) -> f64 {
    return f64(tv.tv_sec) + f64(i64(tv.tv_usec)) / 1000000.0;
}

impl itimer_retval(iv: itimerval) -> ptr[PyObject] {
    r = PyTuple_New(2);
    if not r {
        return NULL;
    }
    v = PyFloat_FromDouble(double_from_timeval(iv.it_value));
    if not v {
        object_decref(r);
        return NULL;
    }
    tuple_set_item(r, 0, v);
    v = PyFloat_FromDouble(double_from_timeval(iv.it_interval));
    if not v {
        object_decref(r);
        return NULL;
    }
    tuple_set_item(r, 1, v);
    return r;
}

impl signal_default_int_handler_impl(
    module: ptr[PyObject], signalnum: i32, frame: ptr[PyObject]
) -> ptr[PyObject] {
    PyErr_SetNone(PyExc_KeyboardInterrupt);
    return NULL;
}

impl report_wakeup_write_error(data: ptr) -> i32 {
    save_errno = jacpy_errno();
    jacpy_set_errno(i64(int(data)));
    exc = PyErr_GetRaisedException();
    PyErr_SetFromErrno(PyExc_OSError);
    PyErr_FormatUnraisable(
        "Exception ignored while trying to write to the signal wakeup fd"
    );
    PyErr_SetRaisedException(exc);
    jacpy_set_errno(save_errno);
    return 0;
}

impl trip_signal(sig_num: i32) {
    __atomic_store_i32(handler_tripped_addr(sig_num), i32(1), 5);

    __atomic_store_i32(is_tripped_addr(), i32(1), 5);

    _PyEval_SignalReceived();

    fd = ptr[i32](wakeup_fd_addr()).view(1)[0];
    if fd != INVALID_FD {
        interp = _PyInterpreterState_Main();
        byte_slots: own SignalBuffer = SignalBuffer();
        byte = ptr[u8](jacpy_stack_address(&mut byte_slots));
        byte.view(1)[0] = u8.wrap(i64(sig_num));

        rc = _Py_write_noraise(fd, ptr(byte), u64(1));
        if rc < 0 {
            error = jacpy_errno();
            if ptr[i32](wakeup_warn_addr()).view(1)[0] != 0
                or (error != EWOULDBLOCK and error != EAGAIN) {
                _PyEval_AddPendingCall(
                    ptr[u8](interp),
                    ptr(report_wakeup_write_error),
                    ptr(error),
                    _Py_PENDING_MAINTHREADONLY
                );
            }
        }
    }
}

impl signal_handler(sig_num: i32) {
    save_errno = jacpy_errno();
    trip_signal(sig_num);

    jacpy_set_errno(save_errno);
}

impl signal_alarm_impl(module: ptr[PyObject], seconds: i32) -> i64 {
    return i64(alarm(u32.wrap(i64(seconds))));
}

impl signal_pause_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    save = PyEval_SaveThread();
    pause();
    PyEval_RestoreThread(save);

    if PyErr_CheckSignals() != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl signal_raise_signal_impl(module: ptr[PyObject], signalnum: i32) -> ptr[PyObject] {
    save = PyEval_SaveThread();
    err = pthread_kill(pthread_self(), signalnum);
    PyEval_RestoreThread(save);

    if err != 0 {
        jacpy_set_errno(i64(err));
        return PyErr_SetFromErrno(PyExc_OSError);
    }

    if PyErr_CheckSignals() != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl signal_signal_impl(
    module: ptr[PyObject], signalnum: i32, handler: ptr[PyObject]
) -> ptr[PyObject] {
    modstate = get_signal_state(module);
    tstate = current_tstate();
    if not thread_can_handle_signals(tstate_interp(tstate)) {
        PyErr_SetString(
            PyExc_ValueError, "signal only works in main thread of the main interpreter"
        );
        return NULL;
    }
    if signalnum < 1 or i64(signalnum) >= Py_NSIG {
        PyErr_SetString(PyExc_ValueError, "signal number out of range");
        return NULL;
    }
    func = ptr();
    if PyCallable_Check(handler) != 0 {
        func = ptr(signal_handler);
    } elif compare_handler(handler, modstate.view(1)[0].ignore_handler) {
        func = ptr(SIG_IGN);
    } elif compare_handler(handler, modstate.view(1)[0].default_handler) {
        func = ptr(SIG_DFL);
    } else {
        PyErr_SetString(
            PyExc_TypeError,
            "signal handler must be signal.SIG_IGN, signal.SIG_DFL, or a callable object"
        );
        return NULL;
    }

    if _PyErr_CheckSignalsTstate(tstate) != 0 {
        return NULL;
    }
    if u64.wrap(int(PyOS_setsig(signalnum, func))) == u64.wrap(SIG_ERR) {
        PyErr_SetFromErrno(PyExc_OSError);
        return NULL;
    }

    old_handler = get_handler(signalnum);
    set_handler(signalnum, object_new_ref(handler));
    if old_handler {
        return old_handler;
    }
    return object_new_ref(Py_None);
}

impl signal_getsignal_impl(module: ptr[PyObject], signalnum: i32) -> ptr[PyObject] {
    if signalnum < 1 or i64(signalnum) >= Py_NSIG {
        PyErr_SetString(PyExc_ValueError, "signal number out of range");
        return NULL;
    }
    old_handler = get_handler(signalnum);
    if old_handler {
        return object_new_ref(old_handler);
    }
    return object_new_ref(Py_None);
}

impl signal_strsignal_impl(module: ptr[PyObject], signalnum: i32) -> ptr[PyObject] {
    if signalnum < 1 or i64(signalnum) >= Py_NSIG {
        PyErr_SetString(PyExc_ValueError, "signal number out of range");
        return NULL;
    }
    jacpy_set_errno(0);
    res = strsignal(signalnum);
    if jacpy_errno() != 0
        or not res
        or int(strstr(res, ptr[u8]("Unknown signal"))) != 0 {
        return object_new_ref(Py_None);
    }
    return PyUnicode_FromString(res);
}

impl signal_siginterrupt_impl(
    module: ptr[PyObject], signalnum: i32, flag: i32
) -> ptr[PyObject] {
    if signalnum < 1 or i64(signalnum) >= Py_NSIG {
        PyErr_SetString(PyExc_ValueError, "signal number out of range");
        return NULL;
    }
    act_slots: own SignalBuffer = SignalBuffer();
    act = ptr[u8](jacpy_stack_address(&mut act_slots));
    sigaction(signalnum, ptr(), ptr(act));
    flags = ptr[i32](act + sigaction_SA_FLAGS);
    if flag != 0 {
        flags.view(1)[0] = flags.view(1)[0] & ~i32(SA_RESTART);
    } else {
        flags.view(1)[0] = flags.view(1)[0] | i32(SA_RESTART);
    }
    if sigaction(signalnum, ptr(act), ptr()) < 0 {
        PyErr_SetFromErrno(PyExc_OSError);
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl signal_set_wakeup_fd_impl(
    module: ptr[PyObject], fdobj: ptr[PyObject], warn_on_full_buffer: bool
) -> ptr[PyObject] {
    fd = PyLong_AsInt(fdobj);
    if fd == -1 and PyErr_Occurred() != NULL {
        return NULL;
    }

    if not thread_can_handle_signals(current_interp()) {
        PyErr_SetString(
            PyExc_ValueError,
            "set_wakeup_fd only works in main thread of the main interpreter"
        );
        return NULL;
    }

    if fd != -1 {
        status = _Py_stat_struct();
        if _Py_fstat(fd, &mut status) != 0 {
            return NULL;
        }
        blocking = _Py_get_blocking(fd);
        if blocking < 0 {
            return NULL;
        }
        if blocking != 0 {
            PyErr_Format(
                PyExc_ValueError, "the fd %i must be in non-blocking mode", fd
            );
            return NULL;
        }
    }

    old_fd = ptr[i32](wakeup_fd_addr()).view(1)[0];
    ptr[i32](wakeup_fd_addr()).view(1)[0] = fd;
    ptr[i32](wakeup_warn_addr()).view(1)[0] = i32(1) if warn_on_full_buffer else i32(0);
    return PyLong_FromLong(i64(old_fd));
}

impl signal_setitimer_impl(
    module: ptr[PyObject], which: i32, seconds: ptr[PyObject], interval: ptr[PyObject]
) -> ptr[PyObject] {
    modstate = get_signal_state(module);
    new_slots: own SignalBuffer = SignalBuffer();
    new_value = ptr[itimerval](jacpy_stack_address(&mut new_slots));
    if timeval_from_double(seconds, ptr[timeval](ptr[u8](new_value) + ITIMERVAL_VALUE))
        < 0 {
        return NULL;
    }
    if timeval_from_double(interval, ptr[timeval](new_value)) < 0 {
        return NULL;
    }

    old_slots: own SignalBuffer = SignalBuffer();
    old = ptr[itimerval](jacpy_stack_address(&mut old_slots));
    if setitimer(which, ptr(new_value), ptr(old)) != 0 {
        PyErr_SetFromErrno(modstate.view(1)[0].itimer_error);
        return NULL;
    }
    return itimer_retval(old.view(1)[0]);
}

impl signal_getitimer_impl(module: ptr[PyObject], which: i32) -> ptr[PyObject] {
    modstate = get_signal_state(module);
    old_slots: own SignalBuffer = SignalBuffer();
    old = ptr[itimerval](jacpy_stack_address(&mut old_slots));
    if getitimer(which, ptr(old)) != 0 {
        PyErr_SetFromErrno(modstate.view(1)[0].itimer_error);
        return NULL;
    }
    return itimer_retval(old.view(1)[0]);
}

impl sigset_to_set(mask: ptr) -> ptr[PyObject] {
    result = PySet_New(NULL);
    if not result {
        return NULL;
    }
    sig = i32(1);
    while i64(sig) < Py_NSIG {
        if sigismember(mask, sig) != 1 {
            sig += 1;
            continue;
        }
        signum = PyLong_FromLong(i64(sig));
        if not signum {
            object_decref(result);
            return NULL;
        }
        if PySet_Add(result, signum) == -1 {
            object_decref(signum);
            object_decref(result);
            return NULL;
        }
        object_decref(signum);
        sig += 1;
    }
    return result;
}

impl convert__Py_Sigset_Converter(value: ptr[PyObject], fname: str, label: str) -> ptr {
    mask = PyMem_Malloc(u64(sigset_t_SIZE));
    if not mask {
        PyErr_NoMemory();
        raise boundary_failure();
    }
    if _Py_Sigset_Converter(value, mask) == 0 {
        PyMem_Free(mask);
        raise boundary_failure();
    }
    return mask;
}

impl signal_pthread_sigmask_impl(
    module: ptr[PyObject], how: i32, mask: ptr
) -> ptr[PyObject] {
    previous_slots: own SignalBuffer = SignalBuffer();
    previous = ptr(jacpy_stack_address(&mut previous_slots));
    err = pthread_sigmask(how, mask, previous);
    PyMem_Free(mask);
    if err != 0 {
        jacpy_set_errno(i64(err));
        PyErr_SetFromErrno(PyExc_OSError);
        return NULL;
    }

    if PyErr_CheckSignals() != 0 {
        return NULL;
    }
    return sigset_to_set(previous);
}

impl signal_sigpending_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    mask_slots: own SignalBuffer = SignalBuffer();
    mask = ptr(jacpy_stack_address(&mut mask_slots));
    if sigpending(mask) != 0 {
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return sigset_to_set(mask);
}

impl signal_sigwait_impl(module: ptr[PyObject], sigset: ptr) -> ptr[PyObject] {
    signum: i32 = 0;
    save = PyEval_SaveThread();
    err = sigwait(sigset, &mut signum);
    PyEval_RestoreThread(save);
    PyMem_Free(sigset);
    if err != 0 {
        jacpy_set_errno(i64(err));
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return PyLong_FromLong(i64(signum));
}

impl signal_valid_signals_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    mask_slots: own SignalBuffer = SignalBuffer();
    mask = ptr(jacpy_stack_address(&mut mask_slots));
    if sigemptyset(mask) != 0 or sigfillset(mask) != 0 {
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return sigset_to_set(mask);
}

impl fill_siginfo(state: ptr[SignalModuleState], si: ptr[u8]) -> ptr[PyObject] {
    result = PyStructSequence_New(ptr[PyObject](state.view(1)[0].siginfo_type));
    if not result {
        return NULL;
    }
    PyStructSequence_SetItem(
        result, 0, PyLong_FromLong(i64(ptr[i32](si + siginfo_t_SI_SIGNO).view(1)[0]))
    );
    PyStructSequence_SetItem(
        result, 1, PyLong_FromLong(i64(ptr[i32](si + siginfo_t_SI_CODE).view(1)[0]))
    );
    PyStructSequence_SetItem(
        result, 2, PyLong_FromLong(i64(ptr[i32](si + siginfo_t_SI_ERRNO).view(1)[0]))
    );
    PyStructSequence_SetItem(
        result, 3, PyLong_FromLong(i64(ptr[i32](si + siginfo_t_SI_PID).view(1)[0]))
    );
    PyStructSequence_SetItem(
        result, 4, _PyLong_FromUid(ptr[u32](si + siginfo_t_SI_UID).view(1)[0])
    );
    PyStructSequence_SetItem(
        result, 5, PyLong_FromLong(i64(ptr[i32](si + siginfo_t_SI_STATUS).view(1)[0]))
    );
    PyStructSequence_SetItem(
        result, 6, PyLong_FromLong(ptr[i64](si + siginfo_t_SI_BAND).view(1)[0])
    );
    if PyErr_Occurred() != NULL {
        object_decref(result);
        return NULL;
    }
    return result;
}

impl signal_sigwaitinfo_impl(module: ptr[PyObject], sigset: ptr) -> ptr[PyObject] {
    si_slots: own SignalBuffer = SignalBuffer();
    si = ptr[u8](jacpy_stack_address(&mut si_slots));
    err = i32(0);
    async_err = i32(0);
    while True {
        save = PyEval_SaveThread();
        err = wait_info(sigset, ptr(si));
        PyEval_RestoreThread(save);
        if not (err == -1 and jacpy_errno() == EINTR) {
            break;
        }
        async_err = PyErr_CheckSignals();
        if async_err != 0 {
            break;
        }
    }
    PyMem_Free(sigset);
    if err == -1 {
        if async_err == 0 {
            return PyErr_SetFromErrno(PyExc_OSError);
        }
        return NULL;
    }
    return fill_siginfo(get_signal_state(module), si);
}

impl signal_sigtimedwait_impl(
    module: ptr[PyObject], sigset: ptr, timeout_obj: ptr[PyObject]
) -> ptr[PyObject] {
    timeout: i64 = 0;
    if _PyTime_FromSecondsObject(&mut timeout, timeout_obj, _PyTime_ROUND_CEILING)
        < 0 {
        PyMem_Free(sigset);
        return NULL;
    }

    if timeout < 0 {
        PyMem_Free(sigset);
        PyErr_SetString(PyExc_ValueError, "timeout must be non-negative");
        return NULL;
    }

    deadline = _PyDeadline_Init(timeout);
    si_slots: own SignalBuffer = SignalBuffer();
    si = ptr[u8](jacpy_stack_address(&mut si_slots));
    request_slots: own SignalBuffer = SignalBuffer();
    request = ptr[i64](jacpy_stack_address(&mut request_slots));

    while True {
        ts = timespec();
        if _PyTime_AsTimespec(timeout, &mut ts) < 0 {
            PyMem_Free(sigset);
            return NULL;
        }
        request.view(2)[0] = ts.tv_sec;
        request.view(2)[1] = ts.tv_nsec;

        save = PyEval_SaveThread();
        res = timed_wait(sigset, ptr(si), ptr(request));
        PyEval_RestoreThread(save);

        if res != -1 {
            break;
        }

        error = jacpy_errno();
        if error != EINTR {
            PyMem_Free(sigset);
            if error == EAGAIN {
                return object_new_ref(Py_None);
            }
            return PyErr_SetFromErrno(PyExc_OSError);
        }

        if PyErr_CheckSignals() != 0 {
            PyMem_Free(sigset);
            return NULL;
        }

        timeout = _PyDeadline_Get(deadline);
        if timeout < 0 {
            break;
        }
    }
    PyMem_Free(sigset);
    return fill_siginfo(get_signal_state(module), si);
}

impl signal_pthread_kill_impl(
    module: ptr[PyObject], thread_id: u64, signalnum: i32
) -> ptr[PyObject] {
    if PySys_Audit("signal.pthread_kill", "ki", thread_id, signalnum) < 0 {
        return NULL;
    }

    err = pthread_kill(thread_id, signalnum);
    if err != 0 {
        jacpy_set_errno(i64(err));
        PyErr_SetFromErrno(PyExc_OSError);
        return NULL;
    }

    if PyErr_CheckSignals() != 0 {
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl signal_pidfd_send_signal_impl(
    module: ptr[PyObject],
    pidfd: i32,
    signalnum: i32,
    siginfo: ptr[PyObject],
    flags: i32
) -> ptr[PyObject] {
    if siginfo != Py_None {
        PyErr_SetString(PyExc_TypeError, "siginfo must be None");
        return NULL;
    }
    if pidfd_send_signal(pidfd, signalnum, flags) < 0 {
        PyErr_SetFromErrno(PyExc_OSError);
        return NULL;
    }
    return object_new_ref(Py_None);
}

impl get_signal_state(module: ptr[PyObject]) -> ptr[SignalModuleState] {
    return ptr[SignalModuleState](PyModule_GetState(module));
}

impl signal_install_handlers -> i32 {
    PyOS_setsig(i32(SIGPIPE), ptr(SIG_IGN));
    PyOS_setsig(i32(SIGXFSZ), ptr(SIG_IGN));

    module = PyImport_ImportModule("_signal");
    if not module {
        return -1;
    }
    object_decref(module);
    return 0;
}

impl clear_pending_signals {
    if __atomic_load_i32(is_tripped_addr(), 5) == i32(0) {
        return;
    }
    __atomic_store_i32(is_tripped_addr(), i32(0), 5);
    i = i32(1);
    while i64(i) < Py_NSIG {
        __atomic_store_i32(handler_tripped_addr(i), i32(0), 0);
        i += 1;
    }
}
