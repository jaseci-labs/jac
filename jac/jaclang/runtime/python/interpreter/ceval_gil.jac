import from c {
    obj GilTimespec {
        has tv_sec: i64 = 0,
            tv_nsec: i64 = 0;
    }  obj PendingCall {
        has func: ptr = ptr(),
            arg: ptr = ptr(),
            flags: i32 = 0;
    }  obj PendingCallFn {
        has call: Callable[[ptr], i32] = 0;
    }  def pthread_mutex_init(mutex: ptr[u8], attr: ptr[u8]) -> i32;  def pthread_mutex_destroy(
        mutex: ptr[u8]
    ) -> i32;  def pthread_mutex_lock(mutex: ptr[u8]) -> i32;  def pthread_mutex_unlock(
        mutex: ptr[u8]
    ) -> i32;  def pthread_cond_destroy(cond: ptr[u8]) -> i32;  def pthread_cond_signal(
        cond: ptr[u8]
    ) -> i32;  def pthread_cond_wait(cond: ptr[u8], mutex: ptr[u8]) -> i32;  def pthread_cond_timedwait(
        cond: ptr[u8], mutex: ptr[u8], abstime: &GilTimespec
    ) -> i32;  def _PyThread_cond_init(cond: ptr[u8]) -> i32;  def _PyThread_cond_after(
        us: i64, abs_time: &mut GilTimespec
    );  def _Py_FatalErrorFunc(func: ptr[u8], message: ptr[u8]);  def _PyMutex_LockTimed(
        m: ptr[PyMutex], timeout_ns: i64, flags: i32
    ) -> i32;  def _PyThreadState_Attach(tstate: ptr[PyThreadState]);  def _PyThreadState_Detach(
        tstate: ptr[PyThreadState]
    );  def _PyThreadState_Suspend(tstate: ptr[PyThreadState]);  def _PyThreadState_MustExit(
        tstate: ptr[PyThreadState]
    ) -> i32;  def _PyThreadState_HangThread(tstate: ptr[PyThreadState]);  def _Py_IsMainThread -> i32;  def PyThread_init_thread;  def _PyErr_CheckSignalsTstate(
        tstate: ptr[PyThreadState]
    ) -> i32;  def _PyErr_GetRaisedException(
        tstate: ptr[PyThreadState]
    ) -> ptr[PyObject];  def _PyErr_Print(tstate: ptr[PyThreadState]);  def _PyErr_SetNone(
        tstate: ptr[PyThreadState], exception: ptr[PyObject]
    );  def _Py_RunGC(tstate: ptr[PyThreadState]);
}

glob:priv DEFAULT_INTERVAL: Final[u64] = 5000;

def tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8];

def tstate_next(tstate: ptr[PyThreadState]) -> ptr[PyThreadState];

def interp_gil(interp: ptr[u8]) -> ptr[u8];

def interp_pending(interp: ptr[u8]) -> ptr[u8];

def runtime_pending_mainthread -> ptr[u8];

def runtime_main_tstate -> ptr[PyThreadState];

def is_main_interpreter(interp: ptr[u8]) -> bool;

def thread_can_handle_signals(interp: ptr[u8]) -> bool;

def ensure_tstate_not_null(func: ptr[u8], tstate: ptr[PyThreadState]);

def set_eval_breaker_bit(tstate: ptr[PyThreadState], bit: u64);

def unset_eval_breaker_bit(tstate: ptr[PyThreadState], bit: u64);

def eval_breaker_bit_is_set(tstate: ptr[PyThreadState], bit: u64) -> bool;

def pymutex_lock(m: ptr[PyMutex]);

def pymutex_unlock(m: ptr[PyMutex]);

def pymutex_lock_flags(m: ptr[PyMutex], flags: i32);

def head_lock(runtime: ptr[u8]);

def head_unlock(runtime: ptr[u8]);

def mutex_init(mtx: ptr[u8], func: ptr[u8], message: ptr[u8]);

def mutex_fini(mtx: ptr[u8], func: ptr[u8], message: ptr[u8]);

def mutex_lock(mtx: ptr[u8], func: ptr[u8], message: ptr[u8]);

def mutex_unlock(mtx: ptr[u8], func: ptr[u8], message: ptr[u8]);

def cond_init(cond: ptr[u8], func: ptr[u8], message: ptr[u8]);

def cond_fini(cond: ptr[u8], func: ptr[u8], message: ptr[u8]);

def cond_signal(cond: ptr[u8], func: ptr[u8], message: ptr[u8]);

def cond_wait(cond: ptr[u8], mtx: ptr[u8], func: ptr[u8], message: ptr[u8]);

def cond_timedwait(cond: ptr[u8], mtx: ptr[u8], us: i64) -> i32;

def cond_timed_wait(
    cond: ptr[u8], mtx: ptr[u8], us: i64, func: ptr[u8], message: ptr[u8]
) -> i32;

def copy_eval_breaker_bits(from_addr: int, to_addr: int, mask: u64);

def update_eval_breaker_for_thread(interp: ptr[u8], tstate: ptr[PyThreadState]);

def _gil_initialize(gil: ptr[u8]);

def gil_created(gil: ptr[u8]) -> i32;

def create_gil(gil: ptr[u8]);

def destroy_gil(gil: ptr[u8]);

def recreate_gil(gil: ptr[u8]);

def drop_gil_impl(tstate: ptr[PyThreadState], gil: ptr[u8]);

def drop_gil(interp: ptr[u8], tstate: ptr[PyThreadState], final_release: i32);

def take_gil(tstate: ptr[PyThreadState]);

import from c {
    def _PyEval_SetSwitchInterval(microseconds: u64) {
        gil = interp_gil(current_interp());
        __atomic_store_i64(
            int(gil) + _gil_runtime_state_INTERVAL, i64.wrap(microseconds), 0
        );
    }  def _PyEval_GetSwitchInterval -> u64 {
        gil = interp_gil(current_interp());
        return u64.wrap(__atomic_load_i64(int(gil) + _gil_runtime_state_INTERVAL, 0));
    }  def _PyEval_ThreadsInitialized -> i32 {
        interp = ptr[u8](_PyInterpreterState_Main());
        if not interp {
            return i32(0);
        }
        return gil_created(interp_gil(interp));
    }  def PyEval_ThreadsInitialized -> i32 {
        return _PyEval_ThreadsInitialized();
    }
}

def init_shared_gil(interp: ptr[u8], gil: ptr[u8]);

def init_own_gil(interp: ptr[u8], gil: ptr[u8]);

import from c {
    def _PyEval_InitGIL(tstate: ptr[PyThreadState], own_gil: i32) {
        if own_gil == 0 {
            main_interp = ptr[u8](_PyInterpreterState_Main());
            init_shared_gil(tstate_interp(tstate), interp_gil(main_interp));
        } else {
            PyThread_init_thread();
            interp = tstate_interp(tstate);
            init_own_gil(interp, interp + PyInterpreterState__GIL);
        }

        _PyThreadState_Attach(tstate);
    }  def _PyEval_FiniGIL(interp: ptr[u8]) {
        gil = interp_gil(interp);
        if not gil {
            return;
        } elif ptr[i32](interp + PyInterpreterState_CEVAL_OWN_GIL).view(1)[0] == 0 {
            ptr[ptr[u8]](interp + PyInterpreterState_CEVAL_GIL).view(1)[0] = ptr[u8]();
            return;
        }
        if gil_created(gil) == 0 {
            return;
        }
        destroy_gil(gil);
        ptr[ptr[u8]](interp + PyInterpreterState_CEVAL_GIL).view(1)[0] = ptr[u8]();
    }  def PyEval_InitThreads {
        return;
    }  def _PyEval_Fini {
        return;
    }  def PyEval_AcquireLock {
        tstate = current_tstate();
        ensure_tstate_not_null(ptr[u8]("PyEval_AcquireLock"), tstate);
        take_gil(tstate);
    }  def PyEval_ReleaseLock {
        tstate = current_tstate();
        drop_gil(tstate_interp(tstate), tstate, i32(0));
    }  def _PyEval_AcquireLock(tstate: ptr[PyThreadState]) {
        ensure_tstate_not_null(ptr[u8]("_PyEval_AcquireLock"), tstate);
        take_gil(tstate);
    }  def _PyEval_ReleaseLock(
        interp: ptr[u8], tstate: ptr[PyThreadState], final_release: i32
    ) {
        drop_gil(interp, tstate, final_release);
    }  def PyEval_AcquireThread(tstate: ptr[PyThreadState]) {
        ensure_tstate_not_null(ptr[u8]("PyEval_AcquireThread"), tstate);
        _PyThreadState_Attach(tstate);
    }  def PyEval_ReleaseThread(tstate: ptr[PyThreadState]) {
        _PyThreadState_Detach(tstate);
    }  def _PyEval_ReInitThreads(tstate: ptr[PyThreadState]) -> PyStatus {
        interp = tstate_interp(tstate);
        gil = interp_gil(interp);
        if gil_created(gil) == 0 {
            return PyStatus(
                _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
            );
        }
        recreate_gil(gil);
        take_gil(tstate);

        ptr[u8](interp_pending(interp) + _pending_calls_MUTEX).view(1)[0] = u8(0);
        return PyStatus(
            _type=_PyStatus_TYPE_OK, func=ptr[u8](), err_msg=ptr[u8](), exitcode=0
        );
    }  def PyEval_SaveThread -> ptr[PyThreadState] {
        tstate = current_tstate();
        _PyThreadState_Detach(tstate);
        return tstate;
    }  def PyEval_RestoreThread(tstate: ptr[PyThreadState]) {
        ensure_tstate_not_null(ptr[u8]("PyEval_RestoreThread"), tstate);
        _PyThreadState_Attach(tstate);
    }  def _PyEval_SignalReceived {
        set_eval_breaker_bit(runtime_main_tstate(), _PY_SIGNALS_PENDING_BIT);
    }
}

def signal_active_thread(interp: ptr[u8], bit: u64);

def pending_slot(pending: ptr[u8], i: i32) -> ptr[PendingCall];

def _push_pending_call(pending: ptr[u8], func: ptr, arg: ptr, flags: i32) -> i32;

def _next_pending_call(pending: ptr[u8]) -> tuple[i32, ptr, ptr, i32];

def _pop_pending_call(pending: ptr[u8]) -> tuple[ptr, ptr, i32];

import from c {
    def _PyEval_AddPendingCall(
        interp: ptr[u8], func: ptr, arg: ptr, flags: i32
    ) -> i32 {
        pending = interp_pending(interp);
        main_only = (flags & _Py_PENDING_MAINTHREADONLY) != 0;
        if main_only {
            pending = runtime_pending_mainthread();
        }
        mutex = ptr[PyMutex](pending + _pending_calls_MUTEX);
        pymutex_lock(mutex);
        result = _push_pending_call(pending, func, arg, flags);
        pymutex_unlock(mutex);
        if main_only {
            set_eval_breaker_bit(runtime_main_tstate(), _PY_CALLS_TO_DO_BIT);
        } else {
            signal_active_thread(interp, _PY_CALLS_TO_DO_BIT);
        }
        return result;
    }  def Py_AddPendingCall(func: ptr, arg: ptr) -> i32 {
        interp = ptr[u8](_PyInterpreterState_Main());
        r = _PyEval_AddPendingCall(interp, func, arg, _Py_PENDING_MAINTHREADONLY);
        if r == _Py_ADD_PENDING_FULL {
            return i32(-1);
        }
        return i32(0);
    }
}

def handle_signals(tstate: ptr[PyThreadState]) -> i32;

def _make_pending_calls(pending: ptr[u8]) -> tuple[i32, i32];

def signal_pending_calls(tstate: ptr[PyThreadState], interp: ptr[u8]);

def unsignal_pending_calls(tstate: ptr[PyThreadState], interp: ptr[u8]);

def clear_pending_handling_thread(pending: ptr[u8]);

def make_pending_calls(tstate: ptr[PyThreadState]) -> i32;

import from c {
    def _Py_set_eval_breaker_bit_all(interp: ptr[u8], bit: u64) {
        runtime = ptr[ptr[u8]](interp + PyInterpreterState_RUNTIME).view(1)[0];
        head_lock(runtime);
        tstate = ptr[ptr[PyThreadState]](interp + PyInterpreterState_THREADS_HEAD).view(
            1
        )[0];
        while tstate {
            set_eval_breaker_bit(tstate, bit);
            tstate = tstate_next(tstate);
        }
        head_unlock(runtime);
    }  def _Py_unset_eval_breaker_bit_all(interp: ptr[u8], bit: u64) {
        runtime = ptr[ptr[u8]](interp + PyInterpreterState_RUNTIME).view(1)[0];
        head_lock(runtime);
        tstate = ptr[ptr[PyThreadState]](interp + PyInterpreterState_THREADS_HEAD).view(
            1
        )[0];
        while tstate {
            unset_eval_breaker_bit(tstate, bit);
            tstate = tstate_next(tstate);
        }
        head_unlock(runtime);
    }  def _Py_FinishPendingCalls(tstate: ptr[PyThreadState]) {
        interp = tstate_interp(tstate);
        pending = interp_pending(interp);
        pending_main = ptr[u8]();
        if _Py_IsMainThread() != 0 and is_main_interpreter(interp) {
            pending_main = runtime_pending_mainthread();
        }

        npending: i32 = 0;
        while True {
            if make_pending_calls(tstate) < 0 {
                exc = _PyErr_GetRaisedException(tstate);
                PyErr_BadInternalCall();
                _PyErr_ChainExceptions1(exc);
                _PyErr_Print(tstate);
            }
            npending = __atomic_load_i32(int(pending) + _pending_calls_NPENDING, 0);
            if pending_main {
                npending = npending
                    + __atomic_load_i32(int(pending_main) + _pending_calls_NPENDING, 0);
            }
            if npending <= 0 {
                break;
            }
        }
    }  def _PyEval_MakePendingCalls(tstate: ptr[PyThreadState]) -> i32 {
        res: i32 = 0;
        if _Py_IsMainThread() != 0 and is_main_interpreter(tstate_interp(tstate)) {
            res = handle_signals(tstate);
            if res != 0 {
                return res;
            }
        }
        res = make_pending_calls(tstate);
        if res != 0 {
            return res;
        }
        return i32(0);
    }  def Py_MakePendingCalls -> i32 {
        tstate = current_tstate();

        if _Py_IsMainThread() == 0 or not is_main_interpreter(tstate_interp(tstate)) {
            return i32(0);
        }
        return _PyEval_MakePendingCalls(tstate);
    }  def _PyEval_InitState(interp: ptr[u8]) {
        _gil_initialize(interp + PyInterpreterState__GIL);
    }  def _Py_HandlePending(tstate: ptr[PyThreadState]) -> i32 {
        breaker = u64.wrap(
            __atomic_load_i64(int(tstate) + PyThreadState_EVAL_BREAKER, 0)
        );

        if (breaker & _PY_EVAL_PLEASE_STOP_BIT) != u64(0) {
            unset_eval_breaker_bit(tstate, _PY_EVAL_PLEASE_STOP_BIT);
            _PyThreadState_Suspend(tstate);

            _PyThreadState_Attach(tstate);
        }

        if (breaker & _PY_SIGNALS_PENDING_BIT) != u64(0) {
            if handle_signals(tstate) != 0 {
                return i32(-1);
            }
        }

        if (breaker & _PY_CALLS_TO_DO_BIT) != u64(0) {
            if make_pending_calls(tstate) != 0 {
                return i32(-1);
            }
        }

        if (breaker & _PY_GC_SCHEDULED_BIT) != u64(0) {
            unset_eval_breaker_bit(tstate, _PY_GC_SCHEDULED_BIT);
            _Py_RunGC(tstate);
        }

        if (breaker & _PY_EVAL_JIT_INVALIDATE_COLD_BIT) != u64(0) {
            unset_eval_breaker_bit(tstate, _PY_EVAL_JIT_INVALIDATE_COLD_BIT);
            ptr[u64](tstate_interp(tstate) + PyInterpreterState_TRACE_RUN_COUNTER).view(
                1
            )[0] = JIT_CLEANUP_THRESHOLD;
        }

        if (breaker & _PY_GIL_DROP_REQUEST_BIT) != u64(0) {
            _PyThreadState_Detach(tstate);

            _PyThreadState_Attach(tstate);
        }

        if (breaker & _PY_ASYNC_EXCEPTION_BIT) != u64(0) {
            unset_eval_breaker_bit(tstate, _PY_ASYNC_EXCEPTION_BIT);
            exc = ptr[PyObject](
                __atomic_swap_i64(int(tstate) + PyThreadState_ASYNC_EXC, i64(0), 5)
            );
            if exc {
                _PyErr_SetNone(tstate, exc);
                object_decref(exc);
                return i32(-1);
            }
        }
        return i32(0);
    }
}

impl tstate_interp(tstate: ptr[PyThreadState]) -> ptr[u8] {
    return ptr[ptr[u8]](ptr[u8](tstate) + PyThreadState_INTERP).view(1)[0];
}

impl tstate_next(tstate: ptr[PyThreadState]) -> ptr[PyThreadState] {
    return ptr[ptr[PyThreadState]](ptr[u8](tstate) + PyThreadState_NEXT).view(1)[0];
}

impl interp_gil(interp: ptr[u8]) -> ptr[u8] {
    return ptr[ptr[u8]](interp + PyInterpreterState_CEVAL_GIL).view(1)[0];
}

impl interp_pending(interp: ptr[u8]) -> ptr[u8] {
    return interp + PyInterpreterState_CEVAL_PENDING;
}

impl runtime_pending_mainthread -> ptr[u8] {
    return ptr[u8](addressof(_PyRuntime)) + _PyRuntimeState_CEVAL_PENDING_MAINTHREAD;
}

impl runtime_main_tstate -> ptr[PyThreadState] {
    return ptr[ptr[PyThreadState]](
        ptr[u8](addressof(_PyRuntime)) + _PyRuntimeState_MAIN_TSTATE
    ).view(
        1
    )[0];
}

impl is_main_interpreter(interp: ptr[u8]) -> bool {
    return interp == ptr[u8](_PyInterpreterState_Main());
}

impl thread_can_handle_signals(interp: ptr[u8]) -> bool {
    return _Py_IsMainThread() != 0 and is_main_interpreter(interp);
}

impl ensure_tstate_not_null(func: ptr[u8], tstate: ptr[PyThreadState]) {
    if not tstate {
        _Py_FatalErrorFunc(
            func,
            ptr[u8](
                "the function must be called with the GIL held, "
                "after Python initialization and before Python finalization, "
                "but the GIL is released (the current Python thread state is NULL)"
            )
        );
    }
}

impl set_eval_breaker_bit(tstate: ptr[PyThreadState], bit: u64) {
    __atomic_or_i64(int(tstate) + PyThreadState_EVAL_BREAKER, i64.wrap(bit), 5);
}

impl unset_eval_breaker_bit(tstate: ptr[PyThreadState], bit: u64) {
    __atomic_and_i64(int(tstate) + PyThreadState_EVAL_BREAKER, i64.wrap(~bit), 5);
}

impl eval_breaker_bit_is_set(tstate: ptr[PyThreadState], bit: u64) -> bool {
    b = u64.wrap(__atomic_load_i64(int(tstate) + PyThreadState_EVAL_BREAKER, 0));
    return (b & bit) != u64(0);
}

impl pymutex_lock(m: ptr[PyMutex]) {
    if __atomic_cas_i8(int(m), i8(0), i8(1), 5) != i8(0) {
        PyMutex_Lock(m);
    }
}

impl pymutex_unlock(m: ptr[PyMutex]) {
    if __atomic_cas_i8(int(m), i8(1), i8(0), 5) != i8(1) {
        PyMutex_Unlock(m);
    }
}

impl pymutex_lock_flags(m: ptr[PyMutex], flags: i32) {
    if __atomic_cas_i8(int(m), i8(0), i8(1), 5) != i8(0) {
        _PyMutex_LockTimed(m, i64(-1), flags);
    }
}

impl head_lock(runtime: ptr[u8]) {
    pymutex_lock_flags(
        ptr[PyMutex](runtime + _PyRuntimeState_INTERPRETERS_MUTEX), _Py_LOCK_DONT_DETACH
    );
}

impl head_unlock(runtime: ptr[u8]) {
    pymutex_unlock(ptr[PyMutex](runtime + _PyRuntimeState_INTERPRETERS_MUTEX));
}

impl mutex_init(mtx: ptr[u8], func: ptr[u8], message: ptr[u8]) {
    if pthread_mutex_init(mtx, ptr[u8]()) != 0 {
        _Py_FatalErrorFunc(func, message);
    }
}

impl mutex_fini(mtx: ptr[u8], func: ptr[u8], message: ptr[u8]) {
    if pthread_mutex_destroy(mtx) != 0 {
        _Py_FatalErrorFunc(func, message);
    }
}

impl mutex_lock(mtx: ptr[u8], func: ptr[u8], message: ptr[u8]) {
    if pthread_mutex_lock(mtx) != 0 {
        _Py_FatalErrorFunc(func, message);
    }
}

impl mutex_unlock(mtx: ptr[u8], func: ptr[u8], message: ptr[u8]) {
    if pthread_mutex_unlock(mtx) != 0 {
        _Py_FatalErrorFunc(func, message);
    }
}

impl cond_init(cond: ptr[u8], func: ptr[u8], message: ptr[u8]) {
    if _PyThread_cond_init(cond) != 0 {
        _Py_FatalErrorFunc(func, message);
    }
}

impl cond_fini(cond: ptr[u8], func: ptr[u8], message: ptr[u8]) {
    if pthread_cond_destroy(cond) != 0 {
        _Py_FatalErrorFunc(func, message);
    }
}

impl cond_signal(cond: ptr[u8], func: ptr[u8], message: ptr[u8]) {
    if pthread_cond_signal(cond) != 0 {
        _Py_FatalErrorFunc(func, message);
    }
}

impl cond_wait(cond: ptr[u8], mtx: ptr[u8], func: ptr[u8], message: ptr[u8]) {
    if pthread_cond_wait(cond, mtx) != 0 {
        _Py_FatalErrorFunc(func, message);
    }
}

impl cond_timedwait(cond: ptr[u8], mtx: ptr[u8], us: i64) -> i32 {
    abs_timeout: own GilTimespec = GilTimespec();
    _PyThread_cond_after(us, &mut abs_timeout);
    ret = pthread_cond_timedwait(cond, mtx, &abs_timeout);
    if ret == ETIMEDOUT {
        return i32(1);
    }
    if ret != 0 {
        return i32(-1);
    }
    return i32(0);
}

impl cond_timed_wait(
    cond: ptr[u8], mtx: ptr[u8], us: i64, func: ptr[u8], message: ptr[u8]
) -> i32 {
    r = cond_timedwait(cond, mtx, us);
    if r < 0 {
        _Py_FatalErrorFunc(func, message);
    }
    if r != 0 {
        return i32(1);
    }
    return i32(0);
}

impl copy_eval_breaker_bits(from_addr: int, to_addr: int, mask: u64) {
    from_bits = u64.wrap(__atomic_load_i64(from_addr, 0)) & mask;
    old_value = u64.wrap(__atomic_load_i64(to_addr, 0));
    to_bits = old_value & mask;
    if from_bits == to_bits {
        return;
    }
    while True {
        new_value = (old_value & ~mask) | from_bits;
        seen = u64.wrap(
            __atomic_cas_i64(to_addr, i64.wrap(old_value), i64.wrap(new_value), 5)
        );
        if seen == old_value {
            return;
        }
        old_value = seen;
    }
}

impl update_eval_breaker_for_thread(interp: ptr[u8], tstate: ptr[PyThreadState]) {
    npending = __atomic_load_i32(
        int(interp_pending(interp)) + _pending_calls_NPENDING, 0
    );
    if npending != 0 {
        set_eval_breaker_bit(tstate, _PY_CALLS_TO_DO_BIT);
    } elif _Py_IsMainThread() != 0 {
        npending = __atomic_load_i32(
            int(runtime_pending_mainthread()) + _pending_calls_NPENDING, 0
        );
        if npending != 0 {
            set_eval_breaker_bit(tstate, _PY_CALLS_TO_DO_BIT);
        }
    }

    copy_eval_breaker_bits(
        int(interp) + PyInterpreterState_CEVAL_INSTRUMENTATION_VERSION,
        int(tstate) + PyThreadState_EVAL_BREAKER,
        ~_PY_EVAL_EVENTS_MASK
    );
}

impl _gil_initialize(gil: ptr[u8]) {
    ptr[i32](gil + _gil_runtime_state_LOCKED).view(1)[0] = i32(-1);
    ptr[u64](gil + _gil_runtime_state_INTERVAL).view(1)[0] = DEFAULT_INTERVAL;
}

impl gil_created(gil: ptr[u8]) -> i32 {
    if not gil {
        return i32(0);
    }
    if __atomic_load_i32(int(gil) + _gil_runtime_state_LOCKED, 2) >= 0 {
        return i32(1);
    }
    return i32(0);
}

impl create_gil(gil: ptr[u8]) {
    mutex_init(
        gil + _gil_runtime_state_MUTEX,
        ptr[u8]("create_gil"),
        ptr[u8]("PyMUTEX_INIT(gil->mutex) failed")
    );
    mutex_init(
        gil + _gil_runtime_state_SWITCH_MUTEX,
        ptr[u8]("create_gil"),
        ptr[u8]("PyMUTEX_INIT(gil->switch_mutex) failed")
    );
    cond_init(
        gil + _gil_runtime_state_COND,
        ptr[u8]("create_gil"),
        ptr[u8]("PyCOND_INIT(gil->cond) failed")
    );
    cond_init(
        gil + _gil_runtime_state_SWITCH_COND,
        ptr[u8]("create_gil"),
        ptr[u8]("PyCOND_INIT(gil->switch_cond) failed")
    );
    __atomic_store_i64(int(gil) + _gil_runtime_state_LAST_HOLDER, i64(0), 0);
    __atomic_store_i32(int(gil) + _gil_runtime_state_LOCKED, i32(0), 3);
}

impl destroy_gil(gil: ptr[u8]) {
    cond_fini(
        gil + _gil_runtime_state_COND,
        ptr[u8]("destroy_gil"),
        ptr[u8]("PyCOND_FINI(gil->cond) failed")
    );
    mutex_fini(
        gil + _gil_runtime_state_MUTEX,
        ptr[u8]("destroy_gil"),
        ptr[u8]("PyMUTEX_FINI(gil->mutex) failed")
    );
    cond_fini(
        gil + _gil_runtime_state_SWITCH_COND,
        ptr[u8]("destroy_gil"),
        ptr[u8]("PyCOND_FINI(gil->switch_cond) failed")
    );
    mutex_fini(
        gil + _gil_runtime_state_SWITCH_MUTEX,
        ptr[u8]("destroy_gil"),
        ptr[u8]("PyMUTEX_FINI(gil->switch_mutex) failed")
    );
    __atomic_store_i32(int(gil) + _gil_runtime_state_LOCKED, i32(-1), 3);
}

impl recreate_gil(gil: ptr[u8]) {
    create_gil(gil);
}

impl drop_gil_impl(tstate: ptr[PyThreadState], gil: ptr[u8]) {
    mutex_lock(
        gil + _gil_runtime_state_MUTEX,
        ptr[u8]("drop_gil_impl"),
        ptr[u8]("PyMUTEX_LOCK(gil->mutex) failed")
    );
    __atomic_store_i32(int(gil) + _gil_runtime_state_LOCKED, i32(0), 0);
    if tstate {
        ptr[i32](ptr[u8](tstate) + PyThreadState_HOLDS_GIL).view(1)[0] = i32(0);
    }
    cond_signal(
        gil + _gil_runtime_state_COND,
        ptr[u8]("drop_gil_impl"),
        ptr[u8]("PyCOND_SIGNAL(gil->cond) failed")
    );
    mutex_unlock(
        gil + _gil_runtime_state_MUTEX,
        ptr[u8]("drop_gil_impl"),
        ptr[u8]("PyMUTEX_UNLOCK(gil->mutex) failed")
    );
}

impl drop_gil(interp: ptr[u8], tstate: ptr[PyThreadState], final_release: i32) {
    gil = interp_gil(interp);
    if __atomic_load_i32(int(gil) + _gil_runtime_state_LOCKED, 0) == 0 {
        _Py_FatalErrorFunc(ptr[u8]("drop_gil"), ptr[u8]("drop_gil: GIL is not locked"));
    }
    if final_release == 0 {
        __atomic_store_i64(int(gil) + _gil_runtime_state_LAST_HOLDER, int(tstate), 0);
    }
    drop_gil_impl(tstate, gil);

    if final_release == 0
        and eval_breaker_bit_is_set(tstate, _PY_GIL_DROP_REQUEST_BIT) {
        mutex_lock(
            gil + _gil_runtime_state_SWITCH_MUTEX,
            ptr[u8]("drop_gil"),
            ptr[u8]("PyMUTEX_LOCK(gil->switch_mutex) failed")
        );

        holder = ptr[PyThreadState](
            __atomic_load_i64(int(gil) + _gil_runtime_state_LAST_HOLDER, 0)
        );
        if holder == tstate {
            unset_eval_breaker_bit(tstate, _PY_GIL_DROP_REQUEST_BIT);

            cond_wait(
                gil + _gil_runtime_state_SWITCH_COND,
                gil + _gil_runtime_state_SWITCH_MUTEX,
                ptr[u8]("drop_gil"),
                ptr[u8]("PyCOND_WAIT(gil->switch_cond) failed")
            );
        }
        mutex_unlock(
            gil + _gil_runtime_state_SWITCH_MUTEX,
            ptr[u8]("drop_gil"),
            ptr[u8]("PyMUTEX_UNLOCK(gil->switch_mutex) failed")
        );
    }
}

impl take_gil(tstate: ptr[PyThreadState]) {
    err = jacpy_errno();
    if _PyThreadState_MustExit(tstate) != 0 {
        _PyThreadState_HangThread(tstate);
    }
    interp = tstate_interp(tstate);
    gil = interp_gil(interp);
    mutex_lock(
        gil + _gil_runtime_state_MUTEX,
        ptr[u8]("take_gil"),
        ptr[u8]("PyMUTEX_LOCK(gil->mutex) failed")
    );
    drop_requested = False;
    while __atomic_load_i32(int(gil) + _gil_runtime_state_LOCKED, 0) != 0 {
        saved_switchnum = ptr[u64](gil + _gil_runtime_state_SWITCH_NUMBER).view(1)[0];
        interval = u64.wrap(
            __atomic_load_i64(int(gil) + _gil_runtime_state_INTERVAL, 0)
        );
        if interval < u64(1) {
            interval = u64(1);
        }
        timed_out = cond_timed_wait(
            gil + _gil_runtime_state_COND,
            gil + _gil_runtime_state_MUTEX,
            i64.wrap(interval),
            ptr[u8]("take_gil"),
            ptr[u8]("PyCOND_WAIT(gil->cond) failed")
        );

        if timed_out != 0
            and __atomic_load_i32(int(gil) + _gil_runtime_state_LOCKED, 0) != 0
            and ptr[u64](gil + _gil_runtime_state_SWITCH_NUMBER).view(1)[0]
                == saved_switchnum {
            holder_tstate = ptr[PyThreadState](
                __atomic_load_i64(int(gil) + _gil_runtime_state_LAST_HOLDER, 0)
            );
            if _PyThreadState_MustExit(tstate) != 0 {
                mutex_unlock(
                    gil + _gil_runtime_state_MUTEX,
                    ptr[u8]("take_gil"),
                    ptr[u8]("PyMUTEX_UNLOCK(gil->mutex) failed")
                );

                if drop_requested {
                    unset_eval_breaker_bit(holder_tstate, _PY_GIL_DROP_REQUEST_BIT);
                }
                _PyThreadState_HangThread(tstate);
            }
            set_eval_breaker_bit(holder_tstate, _PY_GIL_DROP_REQUEST_BIT);
            drop_requested = True;
        }
    }

    mutex_lock(
        gil + _gil_runtime_state_SWITCH_MUTEX,
        ptr[u8]("take_gil"),
        ptr[u8]("PyMUTEX_LOCK(gil->switch_mutex) failed")
    );

    __atomic_store_i32(int(gil) + _gil_runtime_state_LOCKED, i32(1), 0);
    last_holder = ptr[PyThreadState](
        __atomic_load_i64(int(gil) + _gil_runtime_state_LAST_HOLDER, 0)
    );
    if tstate != last_holder {
        __atomic_store_i64(int(gil) + _gil_runtime_state_LAST_HOLDER, int(tstate), 0);
        switch_number = ptr[u64](gil + _gil_runtime_state_SWITCH_NUMBER);
        switch_number.view(1)[0] = wrapping_add(switch_number.view(1)[0], u64(1));
    }
    cond_signal(
        gil + _gil_runtime_state_SWITCH_COND,
        ptr[u8]("take_gil"),
        ptr[u8]("PyCOND_SIGNAL(gil->switch_cond) failed")
    );
    mutex_unlock(
        gil + _gil_runtime_state_SWITCH_MUTEX,
        ptr[u8]("take_gil"),
        ptr[u8]("PyMUTEX_UNLOCK(gil->switch_mutex) failed")
    );
    if _PyThreadState_MustExit(tstate) != 0 {
        mutex_unlock(
            gil + _gil_runtime_state_MUTEX,
            ptr[u8]("take_gil"),
            ptr[u8]("PyMUTEX_UNLOCK(gil->mutex) failed")
        );

        drop_gil(interp, ptr[PyThreadState](), i32(1));
        _PyThreadState_HangThread(tstate);
    }
    ptr[i32](ptr[u8](tstate) + PyThreadState_HOLDS_GIL).view(1)[0] = i32(1);
    unset_eval_breaker_bit(tstate, _PY_GIL_DROP_REQUEST_BIT);
    update_eval_breaker_for_thread(interp, tstate);
    mutex_unlock(
        gil + _gil_runtime_state_MUTEX,
        ptr[u8]("take_gil"),
        ptr[u8]("PyMUTEX_UNLOCK(gil->mutex) failed")
    );
    jacpy_set_errno(err);
}

impl init_shared_gil(interp: ptr[u8], gil: ptr[u8]) {
    ptr[ptr[u8]](interp + PyInterpreterState_CEVAL_GIL).view(1)[0] = gil;
    ptr[i32](interp + PyInterpreterState_CEVAL_OWN_GIL).view(1)[0] = i32(0);
}

impl init_own_gil(interp: ptr[u8], gil: ptr[u8]) {
    create_gil(gil);
    ptr[ptr[u8]](interp + PyInterpreterState_CEVAL_GIL).view(1)[0] = gil;
    ptr[i32](interp + PyInterpreterState_CEVAL_OWN_GIL).view(1)[0] = i32(1);
}

impl signal_active_thread(interp: ptr[u8], bit: u64) {
    gil = interp_gil(interp);
    mutex_lock(
        gil + _gil_runtime_state_MUTEX,
        ptr[u8]("signal_active_thread"),
        ptr[u8]("PyMUTEX_LOCK(gil->mutex) failed")
    );
    if __atomic_load_i32(int(gil) + _gil_runtime_state_LOCKED, 0) != 0 {
        holder = ptr[PyThreadState](
            __atomic_load_i64(int(gil) + _gil_runtime_state_LAST_HOLDER, 0)
        );
        if tstate_interp(holder) == interp {
            set_eval_breaker_bit(holder, bit);
        }
    }
    mutex_unlock(
        gil + _gil_runtime_state_MUTEX,
        ptr[u8]("signal_active_thread"),
        ptr[u8]("PyMUTEX_UNLOCK(gil->mutex) failed")
    );
}

impl pending_slot(pending: ptr[u8], i: i32) -> ptr[PendingCall] {
    return ptr[PendingCall](
        pending + _pending_calls_CALLS + i64(i) * _pending_call_SIZE
    );
}

impl _push_pending_call(pending: ptr[u8], func: ptr, arg: ptr, flags: i32) -> i32 {
    if ptr[i32](pending + _pending_calls_NPENDING).view(1)[0]
        == ptr[i32](pending + _pending_calls_MAX).view(1)[0] {
        return _Py_ADD_PENDING_FULL;
    }
    i = ptr[i32](pending + _pending_calls_NEXT).view(1)[0];
    slot = pending_slot(pending, i);
    slot.view(1)[0].func = func;
    slot.view(1)[0].arg = arg;
    slot.view(1)[0].flags = flags;
    __atomic_add_i32(int(pending) + _pending_calls_NPENDING, i32(1), 5);
    ptr[i32](pending + _pending_calls_NEXT).view(1)[0] = (i + 1)
        % PENDINGCALLSARRAYSIZE;
    return _Py_ADD_PENDING_SUCCESS;
}

impl _next_pending_call(pending: ptr[u8]) -> tuple[i32, ptr, ptr, i32] {
    i = ptr[i32](pending + _pending_calls_FIRST).view(1)[0];
    if ptr[i32](pending + _pending_calls_NPENDING).view(1)[0] == 0 {
        return (i32(-1), ptr(), ptr(), i32(0));
    }
    slot = pending_slot(pending, i);
    return (i, slot.view(1)[0].func, slot.view(1)[0].arg, slot.view(1)[0].flags);
}

impl _pop_pending_call(pending: ptr[u8]) -> tuple[ptr, ptr, i32] {
    (i, func, arg, flags) = _next_pending_call(pending);
    if i >= 0 {
        slot = pending_slot(pending, i);
        slot.view(1)[0].func = ptr();
        slot.view(1)[0].arg = ptr();
        slot.view(1)[0].flags = i32(0);
        ptr[i32](pending + _pending_calls_FIRST).view(1)[0] = (i + 1)
            % PENDINGCALLSARRAYSIZE;
        __atomic_add_i32(int(pending) + _pending_calls_NPENDING, i32(-1), 5);
    }
    return (func, arg, flags);
}

impl handle_signals(tstate: ptr[PyThreadState]) -> i32 {
    unset_eval_breaker_bit(tstate, _PY_SIGNALS_PENDING_BIT);
    if not thread_can_handle_signals(tstate_interp(tstate)) {
        return i32(0);
    }
    if _PyErr_CheckSignalsTstate(tstate) < 0 {
        set_eval_breaker_bit(tstate, _PY_SIGNALS_PENDING_BIT);
        return i32(-1);
    }
    return i32(0);
}

impl _make_pending_calls(pending: ptr[u8]) -> tuple[i32, i32] {
    res: i32 = 0;
    npending: i32 = -1;
    maxloop = ptr[i32](pending + _pending_calls_MAXLOOP).view(1)[0];
    if maxloop == 0 {
        maxloop = ptr[i32](pending + _pending_calls_MAX).view(1)[0];
    }
    mutex = ptr[PyMutex](pending + _pending_calls_MUTEX);

    i: i32 = 0;
    while i < maxloop {
        pymutex_lock(mutex);
        (func, arg, flags) = _pop_pending_call(pending);
        npending = ptr[i32](pending + _pending_calls_NPENDING).view(1)[0];
        pymutex_unlock(mutex);

        if not func {
            break;
        }

        slot = ptr[PendingCallFn](__thread_local("jac_ceval_pending_call"));
        slot.view(1)[0].call = int(func);
        res = slot.view(1)[0].call(arg);
        if (flags & _Py_PENDING_RAWFREE) != 0 and arg {
            PyMem_RawFree(arg);
        }
        if res != 0 {
            return (i32(-1), npending);
        }
        i += 1;
    }
    return (res, npending);
}

impl signal_pending_calls(tstate: ptr[PyThreadState], interp: ptr[u8]) {
    set_eval_breaker_bit(tstate, _PY_CALLS_TO_DO_BIT);
}

impl unsignal_pending_calls(tstate: ptr[PyThreadState], interp: ptr[u8]) {
    unset_eval_breaker_bit(tstate, _PY_CALLS_TO_DO_BIT);
}

impl clear_pending_handling_thread(pending: ptr[u8]) {
    ptr[ptr[PyThreadState]](pending + _pending_calls_HANDLING_THREAD).view(1)[0] = ptr[
        PyThreadState
    ]();
}

impl make_pending_calls(tstate: ptr[PyThreadState]) -> i32 {
    interp = tstate_interp(tstate);
    pending = interp_pending(interp);
    pending_main = runtime_pending_mainthread();
    mutex = ptr[PyMutex](pending + _pending_calls_MUTEX);
    handling = ptr[ptr[PyThreadState]](pending + _pending_calls_HANDLING_THREAD);

    pymutex_lock(mutex);
    if handling.view(1)[0] {
        set_eval_breaker_bit(handling.view(1)[0], _PY_CALLS_TO_DO_BIT);
        unset_eval_breaker_bit(tstate, _PY_CALLS_TO_DO_BIT);
        pymutex_unlock(mutex);
        return i32(0);
    }
    handling.view(1)[0] = tstate;
    pymutex_unlock(mutex);

    unsignal_pending_calls(tstate, interp);
    (status, npending) = _make_pending_calls(pending);
    if status != 0 {
        clear_pending_handling_thread(pending);

        signal_pending_calls(tstate, interp);
        return i32(-1);
    }
    if npending > 0 {
        signal_pending_calls(tstate, interp);
    }
    if _Py_IsMainThread() != 0 and is_main_interpreter(interp) {
        (status_main, npending_main) = _make_pending_calls(pending_main);
        if status_main != 0 {
            clear_pending_handling_thread(pending);

            signal_pending_calls(tstate, interp);
            return i32(-1);
        }
        if npending_main > 0 {
            signal_pending_calls(tstate, interp);
        }
    }
    clear_pending_handling_thread(pending);
    return i32(0);
}
