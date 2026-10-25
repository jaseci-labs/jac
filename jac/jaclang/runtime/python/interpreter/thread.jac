import from c {
    def pthread_create(thread: ptr[u64], attr: ptr[u8], start: ptr, arg: ptr) -> i32;  def pthread_join(
        thread: u64, retval: ptr
    ) -> i32;  def pthread_detach(thread: u64) -> i32;  def pthread_exit(retval: ptr);  def pthread_self -> u64;  def pthread_attr_init(
        attr: ptr[u8]
    ) -> i32;  def pthread_attr_destroy(attr: ptr[u8]) -> i32;  def pthread_attr_setstacksize(
        attr: ptr[u8], size: u64
    ) -> i32;  def pthread_attr_setscope(attr: ptr[u8], scope: i32) -> i32;  def pthread_mutex_init(
        mutex: ptr[u8], attr: ptr[u8]
    ) -> i32;  def pthread_mutex_destroy(mutex: ptr[u8]) -> i32;  def pthread_mutex_lock(
        mutex: ptr[u8]
    ) -> i32;  def pthread_mutex_trylock(mutex: ptr[u8]) -> i32;  def pthread_mutex_unlock(
        mutex: ptr[u8]
    ) -> i32;  def pthread_cond_init(cond: ptr[u8], attr: ptr[u8]) -> i32;  def pthread_cond_destroy(
        cond: ptr[u8]
    ) -> i32;  def pthread_cond_signal(cond: ptr[u8]) -> i32;  def pthread_cond_wait(
        cond: ptr[u8], mutex: ptr[u8]
    ) -> i32;  def pthread_cond_timedwait(
        cond: ptr[u8], mutex: ptr[u8], abstime: ptr[timespec]
    ) -> i32;  def pthread_condattr_init(attr: ptr[u8]) -> i32;  def pthread_key_create(
        key: ptr[u64], destructor: ptr
    ) -> i32;  def pthread_key_delete(key: u64) -> i32;  def pthread_setspecific(
        key: u64, value: ptr
    ) -> i32;  def pthread_getspecific(key: u64) -> ptr;  def sem_init(
        sema: ptr, pshared: i32, value: u32
    ) -> i32;  def sem_destroy(sema: ptr) -> i32;  def sem_wait(sema: ptr) -> i32;  def sem_trywait(
        sema: ptr
    ) -> i32;  def sem_post(sema: ptr) -> i32;  def perror(text: ptr[u8]);  def strerror(
        code: i32
    ) -> ptr[u8];  def fprintf(stream: ptr, format: ptr[u8], *args: any) -> i32;  def jacpy_stdio_stream(
        stream: i32
    ) -> ptr;  def sysconf(name: i32) -> i64;  def confstr(
        name: i32, buffer: ptr[u8], size: u64
    ) -> u64;  def pause -> i32;  def `exit(status: i32);  obj ThreadCall {
        has call: Callable[[ptr], None] = 0;
    }  obj PythreadCallback {
        has func: ptr = ptr(),
            arg: ptr = ptr();
    }  glob PY_TIMEOUT_MAX: i64 = 9223372036854775; glob:priv threadinfo_fields:
             list[PyStructSequence_Field] = [
             PyStructSequence_Field(
                 name=ptr[u8]("name"), doc=ptr[u8]("name of the thread implementation")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("lock"), doc=ptr[u8]("name of the lock implementation")
             ),
             PyStructSequence_Field(
                 name=ptr[u8]("version"),
                 doc=ptr[u8]("name and version of the thread library")
             ),
             PyStructSequence_Field()
         ],
         threadinfo_desc: PyStructSequence_Desc = PyStructSequence_Desc(
             name=ptr[u8]("sys.thread_info"),
             doc=ptr[u8](
                 "sys.thread_info\n\n"
                 "A named tuple holding information about the thread implementation."
             ),
             fields=addressof(threadinfo_fields),
             n_in_sequence=3
         ),
         ThreadInfoType: PyTypeObject = PyTypeObject();
}

glob:priv PYTHREAD_INVALID_THREAD_ID: Final[u64] = 18446744073709551615,
     PyThread_UNSET_TIMEOUT: Final[i64] = -1000000000,
     THREAD_STACK_MIN: Final[u64] = 0x8000,
     INT_MAX: Final[u64] = 2147483647,
     SEC_TO_NS: Final[i64] = 1000000000;

def runtime_field(offset: i64) -> ptr[u8];

def threads_initialized -> ptr[i32];

def condattr_monotonic -> ptr[ptr[u8]];

def interp_stacksize(interp: ptr[u8]) -> ptr[u64];

def init_condattr;

def pythread_init_thread_impl;

def init_thread;

def ensure_initialized;

def cond_init(cond: ptr[u8]) -> i32;

def cond_after(us: i64, abs_time: ptr[timespec]);

def pythread_wrapper(arg: ptr) -> ptr;

def do_start_joinable_thread(func: ptr, arg: ptr) -> tuple[i32, u64];

def check_status_pthread(status: i32, name: ptr[u8]) -> i32;

def check_status(status: i32, name: ptr[u8]);

def fix_status(status: i32) -> i32;

def lock_cond(lock: ptr) -> ptr[u8];

def lock_mutex(lock: ptr) -> ptr[u8];

def lock_locked(lock: ptr) -> ptr[u8];

def allocate_lock -> ptr;

def free_lock(lock: ptr);

def semaphore_acquire_timed(lock: ptr, microseconds: i64, intr_flag: i32) -> i32;

def mutex_acquire_timed(lock: ptr, microseconds: i64, intr_flag: i32) -> i32;

def acquire_lock_timed(lock: ptr, microseconds: i64, intr_flag: i32) -> i32;

def release_lock(lock: ptr);

def pythread_pthread_set_stacksize(size: u64) -> i32;

def load_key(slot: ptr[u8]) -> u64;

def tss_key_slot(key: ptr[u8]) -> ptr[u8];

def tss_is_initialized(key: ptr[u8]) -> ptr[i32];

def tss_delete(key: ptr[u8]);

import from c {
    def PyThread_init_thread {
        init_thread();
        return;
    }  def PyThread_get_stacksize -> u64 {
        return interp_stacksize(current_interp()).view(1)[0];
    }  def PyThread_set_stacksize(size: u64) -> i32 {
        return pythread_pthread_set_stacksize(size);
    }  def PyThread_ParseTimeoutArg(
        arg: ptr[PyObject], blocking: i32, timeout_p: ptr[i64]
    ) -> i32 {
        if not arg or arg == Py_None {
            if blocking != 0 {
                timeout_p.view(1)[0] = PyThread_UNSET_TIMEOUT;
            } else {
                timeout_p.view(1)[0] = 0;
            }
            return 0;
        }
        if blocking == 0 {
            PyErr_SetString(
                PyExc_ValueError, "can't specify a timeout for a non-blocking call"
            );
            return -1;
        }

        slot = ptr[i64](__alloca(8));
        slot.view(1)[0] = 0;
        if pytime_from_object(slot, arg, _PyTime_ROUND_TIMEOUT, SEC_TO_NS) < 0 {
            return -1;
        }
        timeout = slot.view(1)[0];
        if timeout < 0 {
            PyErr_SetString(
                PyExc_ValueError, "timeout value must be a non-negative number"
            );
            return -1;
        }

        if pytime_as_microseconds(timeout, _PyTime_ROUND_TIMEOUT) > PY_TIMEOUT_MAX {
            PyErr_SetString(PyExc_OverflowError, "timeout value is too large");
            return -1;
        }
        timeout_p.view(1)[0] = timeout;
        return 0;
    }  def PyThread_acquire_lock_timed_with_retries(lock: ptr, timeout: i64) -> i32 {
        tstate = current_tstate();
        endtime: i64 = 0;
        if timeout > 0 {
            endtime = pytime_deadline_init(timeout);
        }

        r = PY_LOCK_FAILURE;
        while True {
            microseconds = pytime_as_microseconds(timeout, _PyTime_ROUND_CEILING);

            r = acquire_lock_timed(lock, 0, 0);
            if r == PY_LOCK_FAILURE and microseconds != 0 {
                save = PyEval_SaveThread();
                r = acquire_lock_timed(lock, microseconds, 1);
                PyEval_RestoreThread(save);
            }

            if r == PY_LOCK_INTR {
                if _PyEval_MakePendingCalls(tstate) < 0 {
                    return PY_LOCK_INTR;
                }

                if timeout > 0 {
                    timeout = pytime_deadline_get(endtime);

                    if timeout < 0 {
                        r = PY_LOCK_FAILURE;
                    }
                }
            }

            if r != PY_LOCK_INTR {
                break;
            }
        }
        return r;
    }  def PyThread_tss_alloc -> ptr[u8] {
        new_key = ptr[u8](PyMem_RawMalloc(u64(Py_tss_t_SIZE)));
        if not new_key {
            return ptr[u8]();
        }
        tss_is_initialized(new_key).view(1)[0] = 0;
        return new_key;
    }  def PyThread_tss_free(key: ptr[u8]) {
        if key {
            tss_delete(key);
            PyMem_RawFree(ptr(key));
        }
        return;
    }  def PyThread_tss_is_created(key: ptr[u8]) -> i32 {
        return tss_is_initialized(key).view(1)[0];
    }  def PyThread_GetInfo -> ptr[PyObject] {
        pos: i64 = 0;
        info_type = ptr[PyObject](addressof(ThreadInfoType));

        interp = current_interp();
        if _PyStructSequence_InitBuiltinWithFlags(
            ptr[PyInterpreterState](interp),
            info_type,
            addressof(threadinfo_desc),
            u64(0)
        )
            < 0 {
            return NULL;
        }

        threadinfo = PyStructSequence_New(info_type);
        if not threadinfo {
            return NULL;
        }

        value = PyUnicode_FromString(ptr[u8]("pthread"));
        if not value {
            object_decref(threadinfo);
            return NULL;
        }
        tuple_set_item(threadinfo, pos, value);
        pos = pos + 1;

        if PYTHREAD_USE_SEMAPHORES != 0 {
            value = PyUnicode_FromString(ptr[u8]("semaphore"));
        } else {
            value = PyUnicode_FromString(ptr[u8]("mutex+cond"));
        }
        if not value {
            object_decref(threadinfo);
            return NULL;
        }
        tuple_set_item(threadinfo, pos, value);
        pos = pos + 1;

        value = NULL;
        if PYTHREAD_CS_GNU_LIBPTHREAD_VERSION >= 0 {
            buffer = ptr[u8](__alloca(255));
            length = i32.wrap(
                i64(confstr(PYTHREAD_CS_GNU_LIBPTHREAD_VERSION, buffer, u64(255)))
            );
            if 1 < length and length < 255 {
                value = PyUnicode_DecodeFSDefaultAndSize(buffer, i64(length - 1));
                if not value {
                    PyErr_Clear();
                }
            }
        }
        if not value {
            value = object_new_ref(Py_None);
        }
        tuple_set_item(threadinfo, pos, value);
        return threadinfo;
    }  def _PyThread_FiniType(interp: ptr[u8]) {
        _PyStructSequence_FiniBuiltin(
            ptr[PyInterpreterState](interp), ptr[PyObject](addressof(ThreadInfoType))
        );
        return;
    }  def _PyThread_cond_init(cond: ptr[u8]) -> i32 {
        return cond_init(cond);
    }  def _PyThread_cond_after(us: i64, abs_time: ptr[timespec]) {
        cond_after(us, abs_time);
        return;
    }  def PyThread_start_joinable_thread(
        func: ptr, arg: ptr, ident: ptr[u64], handle: ptr[u64]
    ) -> i32 {
        (status, th) = do_start_joinable_thread(func, arg);
        if status != 0 {
            return -1;
        }

        ident.view(1)[0] = th;
        handle.view(1)[0] = th;
        return 0;
    }  def PyThread_start_new_thread(func: ptr, arg: ptr) -> u64 {
        (status, th) = do_start_joinable_thread(func, arg);
        if status != 0 {
            return PYTHREAD_INVALID_THREAD_ID;
        }
        pthread_detach(th);
        return th;
    }  def PyThread_join_thread(th: u64) -> i32 {
        return pthread_join(th, ptr());
    }  def PyThread_detach_thread(th: u64) -> i32 {
        return pthread_detach(th);
    }  def PyThread_get_thread_ident_ex -> u64 {
        ensure_initialized();
        return pthread_self();
    }  def PyThread_get_thread_ident -> u64 {
        ensure_initialized();
        return pthread_self();
    }  def PyThread_get_thread_native_id -> u64 {
        ensure_initialized();
        return native_thread_id();
    }  def PyThread_exit_thread {
        if threads_initialized().view(1)[0] == 0 {
            `exit(0);
        }
        pthread_exit(ptr());
        return;
    }  def PyThread_hang_thread {
        while True {
            pause();
        }
    }  def PyThread_allocate_lock -> ptr {
        return allocate_lock();
    }  def PyThread_free_lock(lock: ptr) {
        free_lock(lock);
        return;
    }  def PyThread_acquire_lock_timed(
        lock: ptr, microseconds: i64, intr_flag: i32
    ) -> i32 {
        return acquire_lock_timed(lock, microseconds, intr_flag);
    }  def PyThread_release_lock(lock: ptr) {
        release_lock(lock);
        return;
    }  def _PyThread_at_fork_reinit(lock: ptr[ptr]) -> i32 {
        new_lock = allocate_lock();
        if not new_lock {
            return -1;
        }

        lock.view(1)[0] = new_lock;
        return 0;
    }  def PyThread_acquire_lock(lock: ptr, waitflag: i32) -> i32 {
        microseconds: i64 = 0;
        if waitflag != 0 {
            microseconds = -1;
        }
        return acquire_lock_timed(lock, microseconds, 0);
    }  def PyThread_create_key -> i32 {
        if PTHREAD_KEY_T_IS_COMPATIBLE_WITH_INT == 0 {
            return -1;
        }
        slot = ptr[u64](__alloca(8));
        slot.view(1)[0] = 0;
        fail = pthread_key_create(slot, ptr());
        if fail != 0 {
            return -1;
        }
        key = load_key(ptr[u8](slot));
        if key > INT_MAX {
            pthread_key_delete(key);
            jacpy_set_errno(i64(ENOMEM));
            return -1;
        }
        return i32(key);
    }  def PyThread_delete_key(key: i32) {
        if PTHREAD_KEY_T_IS_COMPATIBLE_WITH_INT != 0 {
            pthread_key_delete(u64.wrap(i64(key)));
        }
        return;
    }  def PyThread_delete_key_value(key: i32) {
        if PTHREAD_KEY_T_IS_COMPATIBLE_WITH_INT != 0 {
            pthread_setspecific(u64.wrap(i64(key)), ptr());
        }
        return;
    }  def PyThread_set_key_value(key: i32, value: ptr) -> i32 {
        if PTHREAD_KEY_T_IS_COMPATIBLE_WITH_INT == 0 {
            return -1;
        }
        fail = pthread_setspecific(u64.wrap(i64(key)), value);
        if fail != 0 {
            return -1;
        }
        return 0;
    }  def PyThread_get_key_value(key: i32) -> ptr {
        if PTHREAD_KEY_T_IS_COMPATIBLE_WITH_INT == 0 {
            return ptr();
        }
        return pthread_getspecific(u64.wrap(i64(key)));
    }  def PyThread_ReInitTLS {
        return;
    }  def PyThread_tss_create(key: ptr[u8]) -> i32 {
        if tss_is_initialized(key).view(1)[0] != 0 {
            return 0;
        }

        fail = pthread_key_create(ptr[u64](tss_key_slot(key)), ptr());
        if fail != 0 {
            return -1;
        }
        tss_is_initialized(key).view(1)[0] = 1;
        return 0;
    }  def PyThread_tss_delete(key: ptr[u8]) {
        tss_delete(key);
        return;
    }  def PyThread_tss_set(key: ptr[u8], value: ptr) -> i32 {
        fail = pthread_setspecific(load_key(tss_key_slot(key)), value);
        if fail != 0 {
            return -1;
        }
        return 0;
    }  def PyThread_tss_get(key: ptr[u8]) -> ptr {
        return pthread_getspecific(load_key(tss_key_slot(key)));
    }
}

impl runtime_field(offset: i64) -> ptr[u8] {
    return ptr[u8](addressof(_PyRuntime)) + offset;
}

impl threads_initialized -> ptr[i32] {
    return ptr[i32](runtime_field(_PyRuntimeState_THREADS_INITIALIZED));
}

impl condattr_monotonic -> ptr[ptr[u8]] {
    return ptr[ptr[u8]](runtime_field(_PyRuntimeState_THREADS_CONDATTR_PTR));
}

impl interp_stacksize(interp: ptr[u8]) -> ptr[u64] {
    return ptr[u64](interp + PyInterpreterState_THREADS_STACKSIZE);
}

impl init_condattr {
    if PYTHREAD_CONDATTR_MONOTONIC != 0 {
        ca = runtime_field(_PyRuntimeState_THREADS_CONDATTR_VAL);

        pthread_condattr_init(ca);

        if condattr_set_monotonic(ca) == 0 {
            condattr_monotonic().view(1)[0] = ca;
        }
    }
}

impl pythread_init_thread_impl {
    init_condattr();
}

impl init_thread {
    initialized = threads_initialized();
    if initialized.view(1)[0] != 0 {
        return;
    }
    initialized.view(1)[0] = 1;
    pythread_init_thread_impl();
}

impl ensure_initialized {
    if threads_initialized().view(1)[0] == 0 {
        init_thread();
    }
}

impl cond_init(cond: ptr[u8]) -> i32 {
    return pthread_cond_init(cond, condattr_monotonic().view(1)[0]);
}

impl cond_after(us: i64, abs_time: ptr[timespec]) {
    timeout = pytime_from_microseconds_clamp(us);
    t: i64 = 0;
    if condattr_monotonic().view(1)[0] {
        (status, now) = pytime_monotonic(0);
        t = now;
    } else {
        (sys_status, sys_now) = pytime_system(0);
        t = sys_now;
    }
    (overflow, deadline) = pytime_add(t, timeout);
    pytime_as_timespec(deadline, abs_time, 0);
}

impl pythread_wrapper(arg: ptr) -> ptr {
    callback = ptr[PythreadCallback](arg);
    func = callback.view(1)[0].func;
    func_arg = callback.view(1)[0].arg;
    PyMem_RawFree(arg);

    calls = ptr[ThreadCall](__thread_local_block("jac_interpreter_thread_call", 8));
    calls.view(1)[0].call = int(func);
    calls.view(1)[0].call(func_arg);
    return ptr();
}

impl do_start_joinable_thread(func: ptr, arg: ptr) -> tuple[i32, u64] {
    ensure_initialized();

    attrs = ptr[u8](__alloca(PTHREAD_ATTR_SIZE));
    if pthread_attr_init(attrs) != 0 {
        return (i32(-1), u64(0));
    }
    tstate = current_tstate();
    stacksize: u64 = 0;
    if tstate {
        stacksize = interp_stacksize(current_interp()).view(1)[0];
    }
    tss = u64(THREAD_STACK_SIZE);
    if stacksize != 0 {
        tss = stacksize;
    }
    if tss != 0 {
        if pthread_attr_setstacksize(attrs, tss) != 0 {
            pthread_attr_destroy(attrs);
            return (i32(-1), u64(0));
        }
    }
    pthread_attr_setscope(attrs, PTHREAD_SCOPE_SYSTEM);

    callback = ptr[PythreadCallback](PyMem_RawMalloc(u64(16)));
    if not callback {
        pthread_attr_destroy(attrs);
        return (i32(-1), u64(0));
    }
    callback.view(1)[0].func = func;
    callback.view(1)[0].arg = arg;

    th = ptr[u64](__alloca(8));
    th.view(1)[0] = 0;
    status = pthread_create(th, attrs, ptr(pythread_wrapper), ptr(callback));

    pthread_attr_destroy(attrs);

    if status != 0 {
        PyMem_RawFree(ptr(callback));
        return (i32(-1), u64(0));
    }
    return (i32(0), th.view(1)[0]);
}

impl check_status_pthread(status: i32, name: ptr[u8]) -> i32 {
    if status != 0 {
        fprintf(
            jacpy_stdio_stream(i32(2)), ptr[u8]("%s: %s\n"), name, strerror(status)
        );
        return 1;
    }
    return 0;
}

impl check_status(status: i32, name: ptr[u8]) {
    if status != 0 {
        perror(name);
    }
}

impl fix_status(status: i32) -> i32 {
    if status == -1 {
        return i32(jacpy_errno());
    }
    return status;
}

impl lock_cond(lock: ptr) -> ptr[u8] {
    return ptr[u8](lock) + PTHREAD_LOCK_COND;
}

impl lock_mutex(lock: ptr) -> ptr[u8] {
    return ptr[u8](lock) + PTHREAD_LOCK_MUTEX;
}

impl lock_locked(lock: ptr) -> ptr[u8] {
    return ptr[u8](lock);
}

impl allocate_lock -> ptr {
    ensure_initialized();

    if PYTHREAD_USE_SEMAPHORES != 0 {
        sema = PyMem_RawMalloc(u64(SEM_T_SIZE));
        if sema {
            status = sem_init(sema, i32(0), u32(1));
            if status != 0 {
                perror(ptr[u8]("sem_init"));
                PyMem_RawFree(sema);
                return ptr();
            }
        }
        return sema;
    }

    lock = PyMem_RawCalloc(u64(1), u64(PTHREAD_LOCK_SIZE));
    if lock {
        error: i32 = 0;
        lock_locked(lock).view(1)[0] = u8(0);

        status = pthread_mutex_init(lock_mutex(lock), ptr[u8]());
        error = error | check_status_pthread(status, ptr[u8]("pthread_mutex_init"));

        status = cond_init(lock_cond(lock));
        error = error | check_status_pthread(status, ptr[u8]("pthread_cond_init"));

        if error != 0 {
            PyMem_RawFree(lock);
            return ptr();
        }
    }
    return lock;
}

impl free_lock(lock: ptr) {
    if PYTHREAD_USE_SEMAPHORES != 0 {
        if not lock {
            return;
        }
        status = sem_destroy(lock);
        check_status(status, ptr[u8]("sem_destroy"));
        PyMem_RawFree(lock);
        return;
    }

    status = pthread_cond_destroy(lock_cond(lock));
    check_status_pthread(status, ptr[u8]("pthread_cond_destroy"));

    status = pthread_mutex_destroy(lock_mutex(lock));
    check_status_pthread(status, ptr[u8]("pthread_mutex_destroy"));

    PyMem_RawFree(lock);
}

impl semaphore_acquire_timed(lock: ptr, microseconds: i64, intr_flag: i32) -> i32 {
    status: i32 = 0;

    timeout: i64 = -1;
    if microseconds >= 0 {
        timeout = pytime_from_microseconds_clamp(microseconds);
    }

    deadline: i64 = 0;
    if timeout > 0 and intr_flag == 0 {
        deadline = pytime_deadline_init(timeout);
    }

    ts = ptr[timespec](__alloca(16));
    while True {
        if timeout > 0 {
            (now_status, now) = pytime_system(0);
            (overflow, abs_time) = pytime_add(now, timeout);
            pytime_as_timespec(abs_time, ts, 0);
            status = fix_status(semaphore_timedwait(lock, ts));
        } elif timeout == 0 {
            status = fix_status(sem_trywait(lock));
        } else {
            status = fix_status(sem_wait(lock));
        }

        if intr_flag != 0 or status != EINTR {
            break;
        }

        if timeout > 0 {
            timeout = pytime_deadline_get(deadline);
            if timeout < 0 {
                status = ETIMEDOUT;
                break;
            }
        }
    }

    if not (intr_flag != 0 and status == EINTR) {
        if timeout > 0 {
            if status != ETIMEDOUT {
                check_status(status, ptr[u8]("sem_timedwait"));
            }
        } elif timeout == 0 {
            if status != EAGAIN {
                check_status(status, ptr[u8]("sem_trywait"));
            }
        } else {
            check_status(status, ptr[u8]("sem_wait"));
        }
    }

    if status == 0 {
        return PY_LOCK_ACQUIRED;
    }
    if intr_flag != 0 and status == EINTR {
        return PY_LOCK_INTR;
    }
    return PY_LOCK_FAILURE;
}

impl mutex_acquire_timed(lock: ptr, microseconds: i64, intr_flag: i32) -> i32 {
    success = PY_LOCK_FAILURE;
    error: i32 = 0;
    status: i32 = 0;
    mutex_p = lock_mutex(lock);
    cond = lock_cond(lock);
    locked = lock_locked(lock);

    if microseconds == 0 {
        status = pthread_mutex_trylock(mutex_p);
        if status != EBUSY {
            error = error
                | check_status_pthread(status, ptr[u8]("pthread_mutex_trylock[1]"));
        }
    } else {
        status = pthread_mutex_lock(mutex_p);
        error = error | check_status_pthread(status, ptr[u8]("pthread_mutex_lock[1]"));
    }
    if status != 0 {
        return PY_LOCK_FAILURE;
    }

    if locked.view(1)[0] == u8(0) {
        success = PY_LOCK_ACQUIRED;
    } elif microseconds != 0 {
        abs_timeout = ptr[timespec](__alloca(16));
        if microseconds > 0 {
            cond_after(microseconds, abs_timeout);
        }
        while True {
            if microseconds > 0 {
                status = pthread_cond_timedwait(cond, mutex_p, abs_timeout);
                if status == 1 {
                    break;
                }
                if status == ETIMEDOUT {
                    break;
                }
                error = error
                    | check_status_pthread(status, ptr[u8]("pthread_cond_timedwait"));
            } else {
                status = pthread_cond_wait(cond, mutex_p);
                error = error
                    | check_status_pthread(status, ptr[u8]("pthread_cond_wait"));
            }

            if intr_flag != 0 and status == 0 and locked.view(1)[0] != u8(0) {
                success = PY_LOCK_INTR;
                break;
            }

            if status == 0 and locked.view(1)[0] == u8(0) {
                success = PY_LOCK_ACQUIRED;
                break;
            }
        }
    }

    if success == PY_LOCK_ACQUIRED {
        locked.view(1)[0] = u8(1);
    }
    status = pthread_mutex_unlock(mutex_p);
    error = error | check_status_pthread(status, ptr[u8]("pthread_mutex_unlock[1]"));

    if error != 0 {
        success = PY_LOCK_FAILURE;
    }
    return success;
}

impl acquire_lock_timed(lock: ptr, microseconds: i64, intr_flag: i32) -> i32 {
    if PYTHREAD_USE_SEMAPHORES != 0 {
        return semaphore_acquire_timed(lock, microseconds, intr_flag);
    }
    return mutex_acquire_timed(lock, microseconds, intr_flag);
}

impl release_lock(lock: ptr) {
    if PYTHREAD_USE_SEMAPHORES != 0 {
        status = sem_post(lock);
        check_status(status, ptr[u8]("sem_post"));
        return;
    }

    status = pthread_mutex_lock(lock_mutex(lock));
    check_status_pthread(status, ptr[u8]("pthread_mutex_lock[3]"));

    lock_locked(lock).view(1)[0] = u8(0);

    status = pthread_cond_signal(lock_cond(lock));
    check_status_pthread(status, ptr[u8]("pthread_cond_signal"));

    status = pthread_mutex_unlock(lock_mutex(lock));
    check_status_pthread(status, ptr[u8]("pthread_mutex_unlock[3]"));
}

impl pythread_pthread_set_stacksize(size: u64) -> i32 {
    if size == 0 {
        interp_stacksize(current_interp()).view(1)[0] = 0;
        return 0;
    }

    tss_min = THREAD_STACK_MIN;
    pthread_stack_min = sysconf(_SC_THREAD_STACK_MIN);
    if pthread_stack_min > 0 and u64(pthread_stack_min) > tss_min {
        tss_min = u64(pthread_stack_min);
    }
    if size >= tss_min {
        attrs = ptr[u8](__alloca(PTHREAD_ATTR_SIZE));
        if pthread_attr_init(attrs) == 0 {
            rc = pthread_attr_setstacksize(attrs, size);
            pthread_attr_destroy(attrs);
            if rc == 0 {
                interp_stacksize(current_interp()).view(1)[0] = size;
                return 0;
            }
        }
    }
    return -1;
}

impl load_key(slot: ptr[u8]) -> u64 {
    if SIZEOF_PTHREAD_KEY_T == 4 {
        return u64(ptr[u32](slot).view(1)[0]);
    }
    return ptr[u64](slot).view(1)[0];
}

impl tss_key_slot(key: ptr[u8]) -> ptr[u8] {
    return key + Py_tss_t__KEY;
}

impl tss_is_initialized(key: ptr[u8]) -> ptr[i32] {
    return ptr[i32](key);
}

impl tss_delete(key: ptr[u8]) {
    if tss_is_initialized(key).view(1)[0] == 0 {
        return;
    }
    pthread_key_delete(load_key(tss_key_slot(key)));

    tss_is_initialized(key).view(1)[0] = 0;
}
