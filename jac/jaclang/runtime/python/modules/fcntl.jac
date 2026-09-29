"""File control and I/O control on file descriptors.

Derived from CPython 3.14.6 Modules/fcntlmodule.c; see ../LICENSE.cpython.
fcntl(2) and ioctl(2) are variadic; the third argument is an int or a
pointer, depending on the command. The struct flock layout comes from
fcntl_records.<os>.jac and the command constants from fcntl_constants.<os>.jac.
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_bytes_from_memory,
    jacpy_errno,
    jacpy_is_bytes,
    jacpy_is_long,
    jacpy_is_unicode,
    jacpy_memory_copy,
    NULL,
    Py_NewRef,
    PyErr_CheckSignals,
    PyErr_Clear,
    PyErr_ExceptionMatches,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetFromErrno,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_BufferError,
    PyExc_OSError,
    PyExc_OverflowError,
    PyExc_SystemError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyIndex_Check,
    PyLong_AsLong,
    PyLong_AsLongLong,
    PyLong_AsUnsignedLongMask,
    PyLong_FromLong,
    PyLong_FromUnsignedLong,
    PyMem_Calloc,
    PyMem_Free,
    PyMem_Malloc,
    PyObject,
    PyObject_CheckBuffer
}
import from jaclang.runtime.python.capi { audit_event, object_error, type_name }
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.bindings.converters { borrowed_none }
import from jaclang.runtime.python.modules.fcntl_records { flock_record }
import from jaclang.runtime.python.modules.fcntl_constants {
    F_RDLCK,
    F_SETLK,
    F_SETLKW,
    F_UNLCK,
    F_WRLCK,
    LOCK_EX,
    LOCK_NB,
    LOCK_SH,
    LOCK_UN
}
import from c {
    def flock(fd: i32, operation: i32) -> i32;  def fcntl(
        fd: i32, cmd: i32, *args: any
    ) -> i32;  def ioctl(fd: i32, request: u64, *args: any) -> i32;
}

# Argument plus NUL byte plus a guard that detects a buffer overflow.
glob:priv BUFFER_SIZE: i64 = 1024,
     GUARD: list[u8] = [
         u8(0x00),
         u8(0xfa),
         u8(0x69),
         u8(0xc4),
         u8(0x67),
         u8(0xa3),
         u8(0x6c),
         u8(0x58)
     ],
     EINTR: i64 = 4,
     PyBUF_WRITABLE: i64 = 1;

def:priv os_error -> ptr[PyObject] {
    PyErr_SetFromErrno(PyExc_OSError);
    return NULL;
}

# The failure of a call retried on EINTR: NULL, with OSError unless a signal
# handler already raised.
def:priv call_failed(async_err: bool) -> ptr[PyObject] {
    return NULL if async_err else os_error();
}

def:priv interrupted -> bool {
    return jacpy_errno() == EINTR;
}

def:priv none -> ptr[PyObject] {
    return Py_NewRef(borrowed_none());
}

def:priv guard_write(buffer: ptr[u8], length: i64) {
    tail = (buffer + length).view(8);
    for index in range(8) {
        tail[index] = GUARD[index];
    }
}

def:priv guard_intact(buffer: ptr[u8], length: i64) -> bool {
    tail = (buffer + length).view(8);
    for index in range(8) {
        if tail[index] != GUARD[index] {
            return False;
        }
    }
    return True;
}

def:priv new_buffer -> ptr[u8] {
    memory = PyMem_Malloc(u64(BUFFER_SIZE + 8));
    if not memory {
        PyErr_NoMemory();
    }
    return ptr[u8](memory);
}

# PyArg_Parse's "i": a C int with the range checked.
def:priv parse_int(value: ptr[PyObject]) -> tuple[bool, i32] {
    wide = PyLong_AsLong(value);
    if wide == -1 and PyErr_Occurred() {
        return (False, i32(0));
    }
    if wide > 2147483647 {
        object_error(PyExc_OverflowError, "signed integer is greater than maximum");
        return (False, i32(0));
    }
    if wide < -2147483648 {
        object_error(PyExc_OverflowError, "signed integer is less than minimum");
        return (False, i32(0));
    }
    return (True, i32(wide));
}

def:priv argument_shown(arg: ptr[PyObject]) -> ptr[PyObject] {
    return Py_NewRef(arg or borrowed_none());
}

def fcntl_fcntl_impl(
    module: ptr[PyObject], fd: i32, code: i32, arg: ptr[PyObject]
) -> ptr[PyObject] {
    if not audit_event(
        "fcntl.fcntl",
        [PyLong_FromLong(i64(fd)), PyLong_FromLong(i64(code)), argument_shown(arg)]
    ) {
        return NULL;
    }
    ret = i32(0);
    async_err = False;
    if not arg or PyIndex_Check(arg) != 0 {
        # PyArg_Parse's "I": an int-sized bit field, not range checked.
        int_arg = u32(0);
        if arg {
            mask = PyLong_AsUnsignedLongMask(arg);
            if mask == u64(0xFFFFFFFFFFFFFFFF) and PyErr_Occurred() {
                return NULL;
            }
            int_arg = u32.wrap(mask);
        }
        while True {
            thread = PyEval_SaveThread();
            ret = fcntl(fd, code, i32.wrap(int_arg));
            PyEval_RestoreThread(thread);
            if ret != -1 or not interrupted() {
                break;
            }
            async_err = PyErr_CheckSignals() != 0;
            if async_err {
                break;
            }
        }
        if ret < 0 {
            return call_failed(async_err);
        }
        return PyLong_FromLong(i64(ret));
    }
    if jacpy_is_unicode(arg) != 0 or PyObject_CheckBuffer(arg) != 0 {
        view = BufferArgument();
        if not view.acquire_string(arg) {
            return NULL;
        }
        length = view.size();
        if length > BUFFER_SIZE {
            object_error(PyExc_ValueError, "fcntl argument 3 is too long");
            view.close();
            return NULL;
        }
        buffer = new_buffer();
        if buffer.is_null() {
            view.close();
            return NULL;
        }
        jacpy_memory_copy(buffer, view.address(), length);
        guard_write(buffer, length);
        view.close();
        while True {
            thread = PyEval_SaveThread();
            ret = fcntl(fd, code, buffer);
            PyEval_RestoreThread(thread);
            if ret != -1 or not interrupted() {
                break;
            }
            async_err = PyErr_CheckSignals() != 0;
            if async_err {
                break;
            }
        }
        result = NULL;
        if ret < 0 {
            result = call_failed(async_err);
        } elif not guard_intact(buffer, length) {
            object_error(PyExc_SystemError, "buffer overflow");
        } else {
            result = jacpy_bytes_from_memory(buffer, length);
        }
        PyMem_Free(buffer);
        return result;
    }
    object_error(
        PyExc_TypeError,
        f"fcntl() argument 3 must be an integer, a bytes-like object, or a string, not {type_name(
            arg, True
        )}"
    );
    return NULL;
}

# The retried ioctl() over a buffer; the call's result and whether a signal
# handler raised.
def:priv ioctl_buffer(fd: i32, code: u64, address: ptr) -> tuple[i32, bool] {
    ret = i32(0);
    async_err = False;
    while True {
        thread = PyEval_SaveThread();
        ret = ioctl(fd, code, address);
        PyEval_RestoreThread(thread);
        if ret != -1 or not interrupted() {
            break;
        }
        async_err = PyErr_CheckSignals() != 0;
        if async_err {
            break;
        }
    }
    return (ret, async_err);
}

def fcntl_ioctl_impl(
    module: ptr[PyObject], fd: i32, code: u64, arg: ptr[PyObject], mutate_arg: bool
) -> ptr[PyObject] {
    # The request is an unsigned, non-checked 32-bit field on every platform
    # (see termios.TIOCSWINSZ); the audit event reports it as an unsigned long.
    if not audit_event(
        "fcntl.ioctl",
        [PyLong_FromLong(i64(fd)), PyLong_FromUnsignedLong(code), argument_shown(arg)]
    ) {
        return NULL;
    }
    ret = i32(0);
    async_err = False;
    if not arg or PyIndex_Check(arg) != 0 {
        int_arg = i32(0);
        if arg {
            (parsed, value) = parse_int(arg);
            if not parsed {
                return NULL;
            }
            int_arg = value;
        }
        while True {
            thread = PyEval_SaveThread();
            ret = ioctl(fd, code, int_arg);
            PyEval_RestoreThread(thread);
            if ret != -1 or not interrupted() {
                break;
            }
            async_err = PyErr_CheckSignals() != 0;
            if async_err {
                break;
            }
        }
        if ret < 0 {
            return call_failed(async_err);
        }
        return PyLong_FromLong(i64(ret));
    }
    if jacpy_is_unicode(arg) == 0 and PyObject_CheckBuffer(arg) == 0 {
        object_error(
            PyExc_TypeError,
            f"ioctl() argument 3 must be an integer, a bytes-like object, or a string, not {type_name(
                arg, True
            )}"
        );
        return NULL;
    }
    view = BufferArgument();
    if mutate_arg and jacpy_is_bytes(arg) == 0 and jacpy_is_unicode(arg) == 0 {
        if view.export(arg, PyBUF_WRITABLE) {
            length = view.size();
            target = ptr[u8](view.address());
            buffer = ptr[u8]();
            if length <= BUFFER_SIZE {
                buffer = new_buffer();
                if buffer.is_null() {
                    view.close();
                    return NULL;
                }
                jacpy_memory_copy(buffer, target, length);
                guard_write(buffer, length);
            }
            (ret, async_err) = ioctl_buffer(
                fd, code, target if buffer.is_null() else buffer
            );
            if ret < 0 {
                if not async_err {
                    os_error();
                }
                PyMem_Free(buffer);
                view.close();
                return NULL;
            }
            if not buffer.is_null() {
                jacpy_memory_copy(target, buffer, length);
            }
            view.close();
            overflow = not buffer.is_null() and not guard_intact(buffer, length);
            PyMem_Free(buffer);
            if overflow {
                object_error(PyExc_SystemError, "buffer overflow");
                return NULL;
            }
            return PyLong_FromLong(i64(ret));
        }
        if PyErr_ExceptionMatches(PyExc_BufferError) == 0 {
            return NULL;
        }
        PyErr_Clear();
    }
    if not view.acquire_string(arg) {
        return NULL;
    }
    length = view.size();
    if length > BUFFER_SIZE {
        object_error(PyExc_ValueError, "ioctl argument 3 is too long");
        view.close();
        return NULL;
    }
    buffer = new_buffer();
    if buffer.is_null() {
        view.close();
        return NULL;
    }
    jacpy_memory_copy(buffer, view.address(), length);
    guard_write(buffer, length);
    view.close();
    (ret, async_err) = ioctl_buffer(fd, code, buffer);
    result = NULL;
    if ret < 0 {
        result = call_failed(async_err);
    } elif not guard_intact(buffer, length) {
        object_error(PyExc_SystemError, "buffer overflow");
    } else {
        result = jacpy_bytes_from_memory(buffer, length);
    }
    PyMem_Free(buffer);
    return result;
}

def fcntl_flock_impl(module: ptr[PyObject], fd: i32, code: i32) -> ptr[PyObject] {
    if not audit_event(
        "fcntl.flock", [PyLong_FromLong(i64(fd)), PyLong_FromLong(i64(code))]
    ) {
        return NULL;
    }
    ret = i32(0);
    async_err = False;
    while True {
        thread = PyEval_SaveThread();
        ret = flock(fd, code);
        PyEval_RestoreThread(thread);
        if ret != -1 or not interrupted() {
            break;
        }
        async_err = PyErr_CheckSignals() != 0;
        if async_err {
            break;
        }
    }
    if ret < 0 {
        return call_failed(async_err);
    }
    return none();
}

# PyLong_AsLongLong for ints, PyLong_AsLong (through __index__) otherwise.
def:priv offset_of(value: ptr[PyObject]) -> tuple[bool, i64] {
    number = PyLong_AsLongLong(value)
        if jacpy_is_long(value) != 0
        else PyLong_AsLong(value);
    if PyErr_Occurred() {
        return (False, i64(0));
    }
    return (True, number);
}

def fcntl_lockf_impl(
    module: ptr[PyObject],
    fd: i32,
    code: i32,
    lenobj: ptr[PyObject],
    startobj: ptr[PyObject],
    whence: i32
) -> ptr[PyObject] {
    if not audit_event(
        "fcntl.lockf",
        [
            PyLong_FromLong(i64(fd)),
            PyLong_FromLong(i64(code)),
            argument_shown(lenobj),
            argument_shown(startobj),
            PyLong_FromLong(i64(whence))
        ]
    ) {
        return NULL;
    }
    lock_type = i64(0);
    if i64(code) == LOCK_UN {
        lock_type = F_UNLCK;
    } elif (i64(code) & LOCK_SH) != 0 {
        lock_type = F_RDLCK;
    } elif (i64(code) & LOCK_EX) != 0 {
        lock_type = F_WRLCK;
    } else {
        object_error(PyExc_ValueError, "unrecognized lockf argument");
        return NULL;
    }
    start = i64(0);
    length = i64(0);
    if startobj {
        (ok, value) = offset_of(startobj);
        if not ok {
            return NULL;
        }
        start = value;
    }
    if lenobj {
        (ok, value) = offset_of(lenobj);
        if not ok {
            return NULL;
        }
        length = value;
    }
    memory = PyMem_Calloc(u64(1), u64(64));
    if not memory {
        PyErr_NoMemory();
        return NULL;
    }
    lock = ptr[flock_record](memory).view(1);
    lock[0].l_type = i16(lock_type);
    lock[0].l_start = start;
    lock[0].l_len = length;
    lock[0].l_whence = i16.wrap(whence);
    command = i32(F_SETLK if (i64(code) & LOCK_NB) != 0 else F_SETLKW);
    ret = i32(0);
    async_err = False;
    while True {
        thread = PyEval_SaveThread();
        ret = fcntl(fd, command, memory);
        PyEval_RestoreThread(thread);
        if ret != -1 or not interrupted() {
            break;
        }
        async_err = PyErr_CheckSignals() != 0;
        if async_err {
            break;
        }
    }
    result = call_failed(async_err) if ret < 0 else none();
    PyMem_Free(memory);
    return result;
}
