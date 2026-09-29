"""Named POSIX semaphores for multiprocessing: SemLock and sem_unlink().

Derived from CPython 3.14.6 Modules/_multiprocessing/multiprocessing.c and
semaphore.c; see ../LICENSE.cpython. A SemLock wraps a sem_t that
synchronize.py shares between processes, either by name or, after fork(), by
handle. semaphore_platform.<os>.jac says what the C library offers: a target
without sem_timedwait() polls, and one whose sem_getvalue() is broken checks
a lock's state with sem_trywait() instead.
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_errno,
    jacpy_release,
    jacpy_set_errno,
    NULL,
    Py_NewRef,
    Py_None,
    PyErr_CheckSignals,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetFromErrno,
    PyErr_SetNone,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_AssertionError,
    PyExc_NotImplementedError,
    PyExc_OSError,
    PyExc_RuntimeError,
    PyExc_SystemError,
    PyExc_ValueError,
    PyFloat_AsDouble,
    PyLong_FromLong,
    PyLong_FromVoidPtr,
    PyObject,
    PyThread_get_thread_ident,
    PyThreadState
}
import from jaclang.runtime.python.object_model.bool { PyBool_FromLong }
import from jaclang.runtime.python.capi {
    boundary_failure,
    c_string_text,
    object_error,
    text_object,
    text_value
}
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.type { jacpy_binding_allocate }
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_present,
    jacpy_binding_native_set
}
import from jaclang.runtime.python.bindings.converters {
    ClassToken,
    convert_unsigned_long_long,
    borrowed_false,
    borrowed_none,
    borrowed_true
}
import from jaclang.runtime.python.modules.errno_constants { EAGAIN, EINTR, ETIMEDOUT }
import from jaclang.runtime.python.modules.multiprocessing_constants { O_CREAT, O_EXCL }
import from jaclang.runtime.python.modules.semaphore_platform {
    HAVE_BROKEN_SEM_GETVALUE,
    HAVE_SEM_TIMEDWAIT,
    SEM_FAILED,
    timed_wait,
    timespec,
    timeval,
    timeval_from,
    timeval_usec
}
import from c {
    def sem_close(semaphore: ptr) -> i32;  def sem_getvalue(
        semaphore: ptr, value: &mut i32
    ) -> i32;  def sem_post(semaphore: ptr) -> i32;  def sem_trywait(
        semaphore: ptr
    ) -> i32;  def sem_open(name: str, flags: i32, *args: any) -> ptr;  def sem_unlink(
        name: str
    ) -> i32;  def sem_wait(semaphore: ptr) -> i32;  def gettimeofday(
        now: &mut timeval, zone: ptr
    ) -> i32;  def select(
        count: i32, read: ptr, write: ptr, error: ptr, timeout: &mut timeval
    ) -> i32;
}

glob SemLock_token = ClassToken();

# These match the values in Lib/multiprocessing/synchronize.py.
glob:priv RECURSIVE_MUTEX: int = 0,
     SEMAPHORE: int = 1,
     # Error codes of the calls made without the GIL.
     MP_STANDARD_ERROR: i32 = -1,
     MP_MEMORY_ERROR: i32 = -1001,
     MP_SOCKET_ERROR: i32 = -1002,
     MP_EXCEPTION_HAS_BEEN_SET: i32 = -1003,
     # Timeouts beyond this (about 146 billion years) wait as long as it.
     TIMEOUT_MAX: f64 = 4.6e18;

# SEM_HANDLE_converter: a sem_t address, format unit K (an unsigned long long
# bit field, taken from any __index__ without a range check).
def convert_SEM_HANDLE(value: ptr[PyObject], fname: str, label: str) -> u64 {
    return convert_unsigned_long_long(value, True, fname, label);
}

# _PyMp_SetError(): raise the error a code stands for; always NULL.
def mp_set_error(kind: ptr[PyObject], code: i32) -> ptr[PyObject] {
    if code == MP_STANDARD_ERROR or code == MP_SOCKET_ERROR {
        PyErr_SetFromErrno(kind or PyExc_OSError);
    } elif code == MP_MEMORY_ERROR {
        PyErr_NoMemory();
    } elif code != MP_EXCEPTION_HAS_BEEN_SET {
        object_error(PyExc_RuntimeError, f"unknown error number {code}");
    }
    return NULL;
}

obj SemLockState(NativeState) {
    has handle: ptr = ptr(),
        last_tid: u64 = 0,
        count: int = 0,
        maxvalue: int = 0,
        kind: int = 0,
        name: str | None = None;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
    def drop {
        if self.handle != ptr(SEM_FAILED) {
            sem_close(self.handle);
        }
    }
}

def semlock_of(instance: ptr[PyObject]) -> SemLockState | None {
    if jacpy_binding_native_present(instance, SemLock_token.handle) != 0 {
        state = jacpy_binding_native_get(instance, SemLock_token.handle);
        if isinstance(state, SemLockState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "SemLock state is unavailable");
    return None;
}

# ISMINE(): the calling thread holds the lock.
def:priv is_mine(state: SemLockState) -> bool {
    return state.count > 0 and PyThread_get_thread_ident() == state.last_tid;
}

def:priv oserror -> ptr[PyObject] {
    return PyErr_SetFromErrno(PyExc_OSError);
}

# sem_timedwait() for a C library without it: poll with a growing delay of at
# most 20 ms, checking for signals with the GIL held between polls. Called
# with the GIL released through thread.
def:priv sem_timedwait_save(
    handle: ptr, deadline: timespec, thread: ptr[PyThreadState]
) -> i32 {
    jacpy_set_errno(0);
    delay = 0;
    while True {
        if sem_trywait(handle) == 0 {
            return i32(0);
        } elif jacpy_errno() != EAGAIN {
            return MP_STANDARD_ERROR;
        }
        now = timeval();
        if gettimeofday(&mut now, ptr()) < 0 {
            return MP_STANDARD_ERROR;
        }
        deadline_usec = deadline.tv_nsec // 1000;
        now_usec = timeval_usec(now);
        if deadline.tv_sec < now.tv_sec
            or (deadline.tv_sec == now.tv_sec and deadline_usec <= now_usec) {
            jacpy_set_errno(ETIMEDOUT);
            return MP_STANDARD_ERROR;
        }
        # How much time is left, and a delay no longer than it or 20 ms.
        difference = (deadline.tv_sec - now.tv_sec) * 1000000
            + (deadline_usec - now_usec);
        if delay > 20000 {
            delay = 20000;
        }
        if delay > difference {
            delay = difference;
        }
        pause = timeval_from(delay // 1000000, delay % 1000000);
        if select(i32(0), ptr(), ptr(), ptr(), &mut pause) < 0 {
            return MP_STANDARD_ERROR;
        }
        PyEval_RestoreThread(thread);
        interrupted = PyErr_CheckSignals();
        thread = PyEval_SaveThread();
        if interrupted != 0 {
            jacpy_set_errno(EINTR);
            return MP_EXCEPTION_HAS_BEEN_SET;
        }
        delay += 1000;
    }
}

def:priv acquire(
    state: SemLockState, blocking: bool, timeout_obj: ptr[PyObject]
) -> ptr[PyObject] {
    if state.kind == RECURSIVE_MUTEX and is_mine(state) {
        state.count += 1;
        return Py_NewRef(borrowed_true());
    }
    deadline = timespec();
    use_deadline = timeout_obj != Py_None;
    if use_deadline {
        timeout = PyFloat_AsDouble(timeout_obj);
        if PyErr_Occurred() {
            return NULL;
        }
        if timeout < 0.0 {
            timeout = 0.0;
        }
        # C converts the seconds with a bare cast; keep the conversions in
        # range (a NaN reads as 0, as that cast yields on arm64).
        if timeout != timeout {
            timeout = 0.0;
        } elif timeout > TIMEOUT_MAX {
            timeout = TIMEOUT_MAX;
        }
        now = timeval();
        if gettimeofday(&mut now, ptr()) < 0 {
            return oserror();
        }
        sec = i64(timeout);
        nsec = i64(1e9 * (timeout - f64(sec)) + 0.5);
        deadline.tv_sec = now.tv_sec + sec;
        deadline.tv_nsec = timeval_usec(now) * 1000 + nsec;
        deadline.tv_sec += deadline.tv_nsec // 1000000000;
        deadline.tv_nsec %= 1000000000;
    }
    # Check whether the lock can be taken without releasing the GIL.
    result = i32(0);
    error = 0;
    while True {
        result = sem_trywait(state.handle);
        error = jacpy_errno();
        if not (result < 0 and error == EINTR and PyErr_CheckSignals() == 0) {
            break;
        }
    }
    if result < 0 and error == EAGAIN and blocking {
        # It could not; block with the GIL released.
        while True {
            thread = PyEval_SaveThread();
            if not use_deadline {
                result = sem_wait(state.handle);
            } elif HAVE_SEM_TIMEDWAIT {
                result = timed_wait(state.handle, deadline);
            } else {
                result = sem_timedwait_save(state.handle, deadline, thread);
            }
            PyEval_RestoreThread(thread);
            error = jacpy_errno();
            if result == MP_EXCEPTION_HAS_BEEN_SET {
                break;
            }
            if not (result < 0 and error == EINTR and PyErr_CheckSignals() == 0) {
                break;
            }
        }
    }
    if result < 0 {
        jacpy_set_errno(error);
        if error == EAGAIN or error == ETIMEDOUT {
            return Py_NewRef(borrowed_false());
        } elif error == EINTR {
            return NULL;
        }
        return oserror();
    }
    state.count += 1;
    state.last_tid = PyThread_get_thread_ident();
    return Py_NewRef(borrowed_true());
}

def _multiprocessing_SemLock_acquire_impl(
    receiver: ptr[PyObject], blocking: bool, timeout_obj: ptr[PyObject]
) -> ptr[PyObject] {
    state = semlock_of(receiver);
    if state is None {
        return NULL;
    }
    return acquire(state, blocking, timeout_obj);
}

def:priv release(state: SemLockState) -> ptr[PyObject] {
    if state.kind == RECURSIVE_MUTEX {
        if not is_mine(state) {
            object_error(
                PyExc_AssertionError,
                "attempt to release recursive lock not owned by thread"
            );
            return NULL;
        }
        if state.count > 1 {
            state.count -= 1;
            return Py_NewRef(borrowed_none());
        }
    } elif HAVE_BROKEN_SEM_GETVALUE {
        # Only the maxvalue == 1 case can be checked properly.
        if state.maxvalue == 1 {
            # Make sure that it is already locked.
            if sem_trywait(state.handle) < 0 {
                if jacpy_errno() != EAGAIN {
                    return oserror();
                }
            } else {
                # It was not locked, so undo the wait and raise.
                if sem_post(state.handle) < 0 {
                    return oserror();
                }
                object_error(
                    PyExc_ValueError, "semaphore or lock released too many times"
                );
                return NULL;
            }
        }
    } else {
        # Not an absolute guarantee that the value stays within maxvalue.
        value = i32(0);
        if sem_getvalue(state.handle, &mut value) < 0 {
            return oserror();
        } elif value >= state.maxvalue {
            object_error(PyExc_ValueError, "semaphore or lock released too many times");
            return NULL;
        }
    }
    if sem_post(state.handle) < 0 {
        return oserror();
    }
    state.count -= 1;
    return Py_NewRef(borrowed_none());
}

def _multiprocessing_SemLock_release_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = semlock_of(receiver);
    if state is None {
        return NULL;
    }
    return release(state);
}

# newsemlockobject()
def:priv new_semlock(
    type: ptr[PyObject], handle: ptr, kind: int, maxvalue: int, name: str | None
) -> ptr[PyObject] {
    instance = jacpy_binding_allocate(type);
    if not instance {
        return NULL;
    }
    state = SemLockState(handle=handle, kind=kind, maxvalue=maxvalue, name=name);
    if jacpy_binding_native_set(instance, SemLock_token.handle, state) < 0 {
        # The instance does not own the handle yet.
        state.handle = ptr(SEM_FAILED);
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

def _multiprocessing_SemLock_impl(
    type: ptr[PyObject], kind: i32, value: i32, maxvalue: i32, name: str, unlink: bool
) -> ptr[PyObject] {
    if kind != RECURSIVE_MUTEX and kind != SEMAPHORE {
        object_error(PyExc_ValueError, "unrecognized kind");
        return NULL;
    }
    handle = sem_open(name, i32(O_CREAT | O_EXCL), i32(0o600), value);
    if handle != ptr(SEM_FAILED) and (not unlink or sem_unlink(name) >= 0) {
        result = new_semlock(
            type, handle, int(kind), int(maxvalue), None if unlink else name
        );
        if result {
            return result;
        }
    }
    if not PyErr_Occurred() {
        mp_set_error(NULL, MP_STANDARD_ERROR);
    }
    if handle != ptr(SEM_FAILED) {
        sem_close(handle);
    }
    return NULL;
}

def _multiprocessing_SemLock__rebuild_impl(
    type: ptr[PyObject], handle: u64, kind: i32, maxvalue: i32, name: ptr[u8]
) -> ptr[PyObject] {
    semaphore = ptr(int(handle));
    text: str | None = None;
    if name {
        decoded = c_string_text(name);
        if not decoded {
            return NULL;
        }
        text = text_value(decoded);
        jacpy_release(decoded);
        semaphore = sem_open(text, i32(0));
        if semaphore == ptr(SEM_FAILED) {
            return oserror();
        }
    }
    return new_semlock(type, semaphore, int(kind), int(maxvalue), text);
}

def _multiprocessing_SemLock__count_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = semlock_of(receiver);
    if state is None {
        return NULL;
    }
    return PyLong_FromLong(i64(state.count));
}

def _multiprocessing_SemLock__is_mine_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = semlock_of(receiver);
    if state is None {
        return NULL;
    }
    # Only meaningful for a lock.
    return PyBool_FromLong(i64(is_mine(state)));
}

def _multiprocessing_SemLock__get_value_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = semlock_of(receiver);
    if state is None {
        return NULL;
    }
    if HAVE_BROKEN_SEM_GETVALUE {
        PyErr_SetNone(PyExc_NotImplementedError);
        return NULL;
    }
    value = i32(0);
    if sem_getvalue(state.handle, &mut value) < 0 {
        return mp_set_error(NULL, MP_STANDARD_ERROR);
    }
    # Some implementations count waiting threads as negative values.
    if value < 0 {
        value = i32(0);
    }
    return PyLong_FromLong(i64(value));
}

def _multiprocessing_SemLock__is_zero_impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = semlock_of(receiver);
    if state is None {
        return NULL;
    }
    if HAVE_BROKEN_SEM_GETVALUE {
        if sem_trywait(state.handle) < 0 {
            if jacpy_errno() == EAGAIN {
                return Py_NewRef(borrowed_true());
            }
            return mp_set_error(NULL, MP_STANDARD_ERROR);
        }
        if sem_post(state.handle) < 0 {
            return mp_set_error(NULL, MP_STANDARD_ERROR);
        }
        return Py_NewRef(borrowed_false());
    }
    value = i32(0);
    if sem_getvalue(state.handle, &mut value) < 0 {
        return mp_set_error(NULL, MP_STANDARD_ERROR);
    }
    return PyBool_FromLong(i64(value == 0));
}

def _multiprocessing_SemLock__after_fork_impl(
    receiver: ptr[PyObject]
) -> ptr[PyObject] {
    state = semlock_of(receiver);
    if state is None {
        return NULL;
    }
    state.count = 0;
    return Py_NewRef(borrowed_none());
}

def _multiprocessing_SemLock___enter___impl(receiver: ptr[PyObject]) -> ptr[PyObject] {
    state = semlock_of(receiver);
    if state is None {
        return NULL;
    }
    return acquire(state, True, borrowed_none());
}

def _multiprocessing_SemLock___exit___impl(
    receiver: ptr[PyObject],
    exc_type: ptr[PyObject],
    exc_value: ptr[PyObject],
    exc_tb: ptr[PyObject]
) -> ptr[PyObject] {
    state = semlock_of(receiver);
    if state is None {
        return NULL;
    }
    return release(state);
}

def _multiprocessing_sem_unlink_impl(
    module: ptr[PyObject], name: str
) -> ptr[PyObject] {
    if sem_unlink(name) < 0 {
        return mp_set_error(NULL, MP_STANDARD_ERROR);
    }
    return Py_NewRef(borrowed_none());
}

# The SemLock members: handle, kind, maxvalue and name, read-only.
def semlock_handle(state: SemLockState) -> ptr[PyObject] {
    return PyLong_FromVoidPtr(state.handle);
}

def semlock_name(state: SemLockState) -> ptr[PyObject] {
    if state.name is None {
        return Py_NewRef(borrowed_none());
    }
    try {
        return text_object(state.name);
    } except boundary_failure {
        return NULL;
    }
}
