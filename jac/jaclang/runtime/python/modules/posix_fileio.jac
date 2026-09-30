"""The posix file descriptor area: open/close/dup, read and write in all
their vector and positional forms, sendfile, pipes, pseudo-terminals, the
inheritable and blocking flags, eventfd, timerfd and os.terminal_size.

Derived from CPython 3.14.6 Modules/posixmodule.c; see ../LICENSE.cpython.
The descriptor helpers the C calls (_Py_read, _Py_write, _Py_dup,
_Py_set_inheritable, _Py_get_blocking, ...) are Python/fileutils.c's. A libc
function or record only one target has is reached through
posix_fileio_platform.<os>.jac. HAVE_OPENAT_RUNTIME and
HAVE_PTSNAME_R_RUNTIME are always true for the supported deployment targets.
"""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyBytes_AsString,
    PyBytes_FromStringAndSize,
    PyBuffer_Release,
    PyErr_CheckSignals,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetFromErrno,
    PyErr_SetFromErrnoWithFilenameObject,
    PyErr_SetString,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_OSError,
    PyExc_OverflowError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyFloat_FromDouble,
    PyLong_AsLong,
    PyLong_FromLong,
    PyLong_FromSsize_t,
    PyLong_FromUnsignedLongLong,
    PyMem_Free,
    PyMem_Malloc,
    PyMem_RawFree,
    PyMem_RawMalloc,
    PyObject,
    PyObject_GetBuffer,
    PySequence_Check,
    PySequence_GetItem,
    PySequence_Size,
    PySys_Audit,
    PyTuple_Pack,
    PyUnicode_DecodeFSDefault,
    Py_BuildValue,
    Py_NewRef,
    Py_None,
    Py_buffer,
    _PyBytes_Resize,
    _PyTime_AsTimespec,
    _PyTime_FromSecondsDouble,
    _PyTime_FromTimespec,
    _Py_closerange,
    _Py_device_encoding,
    _Py_dup,
    _Py_get_blocking,
    _Py_get_inheritable,
    _Py_read,
    _Py_set_blocking,
    _Py_set_inheritable,
    _Py_write,
    jacpy_errno,
    jacpy_release,
    jacpy_set_errno
}
import from jaclang.runtime.python.layouts { PY_BUFFER_SIZE }
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.bindings.module { add_state_owned }
import from jaclang.runtime.python.bindings.type { struct_sequence_type }
import from jaclang.runtime.python.object_model.structseq {
    PyStructSequence_New,
    PyStructSequence_SetItem
}
import from jaclang.runtime.python.modules.time_records { timespec }
import from jaclang.runtime.python.modules.posix_constants {
    EBUSY,
    SIGCHLD,
    _SC_TTY_NAME_MAX,
    EAGAIN,
    EINTR,
    EINVAL,
    ENOSYS,
    HAVE_DUP3,
    HAVE_LOGIN_TTY,
    HAVE_OPENAT,
    HAVE_PIPE2,
    HAVE_PREADV2,
    HAVE_PTSNAME_R,
    HAVE_PWRITEV2,
    L_ctermid,
    MAXPATHLEN,
    O_CLOEXEC,
    SEEK_CUR,
    SEEK_END,
    SEEK_SET,
    TFD_CLOEXEC,
    TIOCGWINSZ,
    TIOCSCTTY
}
import from jaclang.runtime.python.modules.posix_core {
    DEFAULT_DIR_FD,
    INT_MAX,
    STATE_TERMINAL_SIZE_TYPE,
    argument_unavailable_error,
    path_t,
    posix_error,
    state_object
}
import from jaclang.runtime.python.modules.posix_fileio_platform {
    PY_READ_MAX,
    copy_file_range_call,
    ctermid_call,
    dup3_call,
    eventfd_call,
    eventfd_read_call,
    eventfd_write_call,
    fcopyfile_call,
    fd_pair,
    iovec,
    itimerspec,
    memfd_create_call,
    pipe2_call,
    preadv2_call,
    pwritev2_call,
    sendfile_darwin_call,
    sendfile_linux_call,
    splice_call,
    timerfd_create_call,
    timerfd_gettime_call,
    timerfd_settime_call
}

import from c {
    obj winsize {
        has ws_row: u16 = 0,
            ws_col: u16 = 0,
            ws_xpixel: u16 = 0,
            ws_ypixel: u16 = 0;
    }
    # The fileutils.c flag os.open() lends _Py_set_inheritable().
    glob _Py_open_cloexec_works: i32;
    # PyOS_sighandler_t as an untyped function pointer.
    def PyOS_setsig(sig: i32, handler: ptr) -> ptr;  def open(
        path: ptr[u8], flags: i32, *args: any
    ) -> i32;  def openat(dir_fd: i32, path: ptr[u8], flags: i32, *args: any) -> i32;  def close(
        fd: i32
    ) -> i32;  def dup2(fd: i32, fd2: i32) -> i32;  def lseek(
        fd: i32, offset: i64, whence: i32
    ) -> i64;  def pread(fd: i32, buffer: ptr, count: u64, offset: i64) -> i64;  def pwrite(
        fd: i32, buffer: ptr, count: u64, offset: i64
    ) -> i64;  def readv(fd: i32, iov: ptr[iovec], count: i32) -> i64;  def writev(
        fd: i32, iov: ptr[iovec], count: i32
    ) -> i64;  def preadv(fd: i32, iov: ptr[iovec], count: i32, offset: i64) -> i64;  def pwritev(
        fd: i32, iov: ptr[iovec], count: i32, offset: i64
    ) -> i64;  def isatty(fd: i32) -> i32;  def pipe(fds: &mut fd_pair) -> i32;  def sysconf(
        name: i32
    ) -> i64;  def ttyname_r(fd: i32, buffer: ptr[u8], size: u64) -> i32;  def posix_openpt(
        oflag: i32
    ) -> i32;  def grantpt(fd: i32) -> i32;  def unlockpt(fd: i32) -> i32;  def ptsname(
        fd: i32
    ) -> ptr[u8];  def ptsname_r(fd: i32, buffer: ptr[u8], size: u64) -> i32;  def openpty(
        amaster: &mut i32, aslave: &mut i32, name: ptr, termp: ptr, winp: ptr
    ) -> i32;  def login_tty(fd: i32) -> i32;  def setsid -> i32;  def ioctl(
        fd: i32, request: u64, *args: any
    ) -> i32;
}

glob PyBUF_SIMPLE: i32 = 0,
     PyBUF_WRITABLE: i32 = 1,
     _PyTime_ROUND_FLOOR: i32 = 0,
     OFF_T_MAX: i64 = 0x7fffffffffffffff,
     # dup3() may be missing from the running kernel: -1 until known.
     DUP3_WORKS: i32 = -1;

# --- helpers -----------------------------------------------------------------

# Py_off_t_converter: off_t is a long on every supported target.
def:priv Py_off_t_converter(value: ptr[PyObject]) -> (i64 | None) {
    offset = PyLong_AsLong(value);
    if PyErr_Occurred() {
        return None;
    }
    return offset;
}

# The struct iovec array and the Py_buffer views behind it, both PyMem
# memory, as iov_setup() leaves them.
obj IoVectors {
    has iov: ptr[iovec] = ptr[iovec](),
        buf: ptr[Py_buffer] = ptr[Py_buffer]();
}

# iov_setup(): export a buffer from each of the `cnt` items of `seq` with the
# PyBUF_* `type`; None with the exception set on failure.
def iov_setup(seq: ptr[PyObject], cnt: i64, type_flags: i32) -> (IoVectors | None) {
    # PyMem_New() refuses a count whose byte size overflows Py_ssize_t.
    if u64(cnt) > u64(0x7fffffffffffffff) / u64(16) {
        PyErr_NoMemory();
        return None;
    }
    iov = ptr[iovec](PyMem_Malloc(u64(cnt) * u64(16)));
    if not iov {
        PyErr_NoMemory();
        return None;
    }
    if u64(cnt) > u64(0x7fffffffffffffff) / PY_BUFFER_SIZE {
        PyMem_Free(ptr(iov));
        PyErr_NoMemory();
        return None;
    }
    buf = ptr[Py_buffer](PyMem_Malloc(u64(cnt) * PY_BUFFER_SIZE));
    if not buf {
        PyMem_Free(ptr(iov));
        PyErr_NoMemory();
        return None;
    }
    i = i64(0);
    while i < cnt {
        item = PySequence_GetItem(seq, i);
        if not item {
            return iov_setup_failed(iov, buf, i);
        }
        if PyObject_GetBuffer(item, buf + i, type_flags) == -1 {
            jacpy_release(item);
            return iov_setup_failed(iov, buf, i);
        }
        jacpy_release(item);
        (iov + i).view(1)[0].iov_base = (buf + i).view(1)[0].buf;
        (iov + i).view(1)[0].iov_len = u64.wrap((buf + i).view(1)[0].length);
        i += 1;
    }
    return IoVectors(iov=iov, buf=buf);
}

def:priv iov_setup_failed(
    iov: ptr[iovec], buf: ptr[Py_buffer], filled: i64
) -> (IoVectors | None) {
    PyMem_Free(ptr(iov));
    for j in range(filled) {
        PyBuffer_Release(buf + j);
    }
    PyMem_Free(ptr(buf));
    return None;
}

def iov_cleanup(vectors: IoVectors, cnt: i32) {
    PyMem_Free(ptr(vectors.iov));
    for i in range(cnt) {
        PyBuffer_Release(vectors.buf + i);
    }
    PyMem_Free(ptr(vectors.buf));
}

# The `(ii)` tuple of two descriptors.
def:priv fd_tuple(first: i32, second: i32) -> ptr[PyObject] {
    return Py_BuildValue("(ii)", first, second);
}

# --- terminals ---------------------------------------------------------------

def os_ttyname_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    size = sysconf(i32(_SC_TTY_NAME_MAX));
    if size == -1 {
        return posix_error();
    }
    buffer = ptr[u8](PyMem_RawMalloc(u64(size)));
    if not buffer {
        return PyErr_NoMemory();
    }
    ret = ttyname_r(fd, buffer, u64(size));
    if ret != 0 {
        PyMem_RawFree(ptr(buffer));
        jacpy_set_errno(i64(ret));
        return posix_error();
    }
    res = PyUnicode_DecodeFSDefault(buffer);
    PyMem_RawFree(ptr(buffer));
    return res;
}

# ctermid() into the char buffer[L_ctermid] of the C, ctermid_r() on macOS.
def os_ctermid_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    buffer = ptr[u8](PyMem_RawMalloc(u64(L_ctermid)));
    if not buffer {
        return PyErr_NoMemory();
    }
    ret = ctermid_call(buffer);
    result = NULL;
    if not ret {
        result = posix_error();
    } else {
        result = PyUnicode_DecodeFSDefault(buffer);
    }
    PyMem_RawFree(ptr(buffer));
    return result;
}

def os_posix_openpt_impl(module: ptr[PyObject], oflag: i32) -> i32 {
    oflag |= i32(O_CLOEXEC);
    fd = posix_openpt(oflag);
    if fd == -1 {
        posix_error();
        return i32(-1);
    }
    # Just in case, likely a no-op given O_CLOEXEC above.
    no_atomic = i32(0);
    if _Py_set_inheritable(fd, 0, &mut no_atomic) < 0 {
        close(fd);
        return i32(-1);
    }
    return fd;
}

def os_grantpt_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    saved_errno = i64(0);
    sig_saved = PyOS_setsig(i32(SIGCHLD), ptr());
    ret = grantpt(fd);
    if ret == -1 {
        saved_errno = jacpy_errno();
    }
    PyOS_setsig(i32(SIGCHLD), sig_saved);
    if ret == -1 {
        jacpy_set_errno(saved_errno);
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

def os_unlockpt_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    if unlockpt(fd) == -1 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

def:priv py_ptsname(fd: i32) -> ptr[PyObject] {
    # ptsname() may fail without setting errno.
    jacpy_set_errno(0);
    name = ptsname(fd);
    if not name {
        return posix_error();
    }
    return PyUnicode_DecodeFSDefault(name);
}

def os_ptsname_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    if not HAVE_PTSNAME_R {
        return py_ptsname(fd);
    }
    size = u64(MAXPATHLEN + 1);
    name = ptr[u8](PyMem_RawMalloc(size));
    if not name {
        return PyErr_NoMemory();
    }
    ret = ptsname_r(fd, name, size);
    result = NULL;
    if ret != 0 {
        jacpy_set_errno(i64(ret));
        result = posix_error();
    } else {
        result = PyUnicode_DecodeFSDefault(name);
    }
    PyMem_RawFree(ptr(name));
    return result;
}

def os_openpty_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    master_fd = i32(-1);
    slave_fd = i32(-1);
    failed = False;
    if openpty(&mut master_fd, &mut slave_fd, ptr(), ptr(), ptr()) != 0 {
        posix_error();
        failed = True;
    } else {
        no_atomic = i32(0);
        if _Py_set_inheritable(master_fd, 0, &mut no_atomic) < 0
            or _Py_set_inheritable(slave_fd, 0, &mut no_atomic) < 0 {
            failed = True;
        }
    }
    if failed {
        if master_fd != -1 {
            close(master_fd);
        }
        if slave_fd != -1 {
            close(slave_fd);
        }
        return NULL;
    }
    return fd_tuple(master_fd, slave_fd);
}

def os_login_tty_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    if HAVE_LOGIN_TTY {
        if login_tty(fd) == -1 {
            return posix_error();
        }
        return Py_NewRef(Py_None);
    }
    # Establish a new session.
    if setsid() == -1 {
        return posix_error();
    }
    # The tty becomes the controlling terminal.
    if ioctl(fd, u64.wrap(TIOCSCTTY), ptr()) == -1 {
        return posix_error();
    }
    # The tty becomes stdin/stdout/stderr.
    if dup2(fd, 0) == -1 or dup2(fd, 1) == -1 or dup2(fd, 2) == -1 {
        return posix_error();
    }
    if fd > 2 {
        close(fd);
    }
    return Py_NewRef(Py_None);
}

# --- timerfd -----------------------------------------------------------------

def:priv build_itimerspec(curr_value: itimerspec) -> ptr[PyObject] {
    value = PyFloat_FromDouble(
        f64(curr_value.it_value.tv_sec) + f64(curr_value.it_value.tv_nsec) * 1e-9
    );
    if not value {
        return NULL;
    }
    interval = PyFloat_FromDouble(
        f64(curr_value.it_interval.tv_sec) + f64(curr_value.it_interval.tv_nsec) * 1e-9
    );
    if not interval {
        jacpy_release(value);
        return NULL;
    }
    tuple = PyTuple_Pack(2, value, interval);
    jacpy_release(interval);
    jacpy_release(value);
    return tuple;
}

def:priv build_itimerspec_ns(curr_value: itimerspec) -> ptr[PyObject] {
    value = i64(0);
    interval = i64(0);
    it_value = curr_value.it_value;
    if _PyTime_FromTimespec(&mut value, &it_value) < 0 {
        return NULL;
    }
    it_interval = curr_value.it_interval;
    if _PyTime_FromTimespec(&mut interval, &it_interval) < 0 {
        return NULL;
    }
    return Py_BuildValue("LL", value, interval);
}

# The new value of a timerfd_settime*() call from its nanosecond times; None
# with the ValueError set.
def:priv itimerspec_of(initial: i64, interval: i64) -> (itimerspec | None) {
    new_value = itimerspec();
    value_ts = timespec();
    if _PyTime_AsTimespec(initial, &mut value_ts) < 0 {
        PyErr_SetString(PyExc_ValueError, "invalid initial value");
        return None;
    }
    interval_ts = timespec();
    if _PyTime_AsTimespec(interval, &mut interval_ts) < 0 {
        PyErr_SetString(PyExc_ValueError, "invalid interval value");
        return None;
    }
    new_value.it_value = value_ts;
    new_value.it_interval = interval_ts;
    return new_value;
}

def os_timerfd_create_impl(
    module: ptr[PyObject], clockid: i32, flags: i32
) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    # PEP 446: always create non-inheritable FD
    flags |= i32(TFD_CLOEXEC);
    fd = timerfd_create_call(clockid, flags);
    PyEval_RestoreThread(thread);
    if fd == -1 {
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return PyLong_FromLong(i64(fd));
}

def:priv timerfd_settime_common(
    fd: i32, flags: i32, initial: i64, interval: i64
) -> (itimerspec | None) {
    new_value = itimerspec_of(initial, interval);
    if new_value is None {
        return None;
    }
    old_value = itimerspec();
    thread = PyEval_SaveThread();
    result = timerfd_settime_call(fd, flags, &new_value, &mut old_value);
    PyEval_RestoreThread(thread);
    if result == -1 {
        PyErr_SetFromErrno(PyExc_OSError);
        return None;
    }
    return old_value;
}

def os_timerfd_settime_impl(
    module: ptr[PyObject],
    fd: i32,
    flags: i32,
    initial_double: f64,
    interval_double: f64
) -> ptr[PyObject] {
    initial = i64(0);
    interval = i64(0);
    if _PyTime_FromSecondsDouble(initial_double, _PyTime_ROUND_FLOOR, &mut initial)
        < 0 {
        return NULL;
    }
    if _PyTime_FromSecondsDouble(interval_double, _PyTime_ROUND_FLOOR, &mut interval)
        < 0 {
        return NULL;
    }
    old_value = timerfd_settime_common(fd, flags, initial, interval);
    if old_value is None {
        return NULL;
    }
    return build_itimerspec(old_value);
}

def os_timerfd_settime_ns_impl(
    module: ptr[PyObject], fd: i32, flags: i32, initial: i64, interval: i64
) -> ptr[PyObject] {
    old_value = timerfd_settime_common(fd, flags, initial, interval);
    if old_value is None {
        return NULL;
    }
    return build_itimerspec_ns(old_value);
}

def:priv timerfd_gettime_common(fd: i32) -> (itimerspec | None) {
    curr_value = itimerspec();
    thread = PyEval_SaveThread();
    result = timerfd_gettime_call(fd, &mut curr_value);
    PyEval_RestoreThread(thread);
    if result == -1 {
        PyErr_SetFromErrno(PyExc_OSError);
        return None;
    }
    return curr_value;
}

def os_timerfd_gettime_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    curr_value = timerfd_gettime_common(fd);
    if curr_value is None {
        return NULL;
    }
    return build_itimerspec(curr_value);
}

def os_timerfd_gettime_ns_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    curr_value = timerfd_gettime_common(fd);
    if curr_value is None {
        return NULL;
    }
    return build_itimerspec_ns(curr_value);
}

# --- open, close, dup --------------------------------------------------------

def os_open_impl(
    module: ptr[PyObject], path: path_t, flags: i32, mode: i32, dir_fd: i32
) -> i32 {
    fd = i32(-1);
    async_err = False;
    flags |= i32(O_CLOEXEC);
    if PySys_Audit("open", "OOi", path.object, Py_None, flags) < 0 {
        return i32(-1);
    }
    while True {
        thread = PyEval_SaveThread();
        if HAVE_OPENAT and dir_fd != DEFAULT_DIR_FD {
            fd = openat(dir_fd, path.narrow, flags, mode);
        } else {
            fd = open(path.narrow, flags, mode);
        }
        PyEval_RestoreThread(thread);
        if not (fd < 0 and jacpy_errno() == EINTR) {
            break;
        }
        async_err = PyErr_CheckSignals() != 0;
        if async_err {
            break;
        }
    }
    if fd < 0 {
        if not async_err {
            PyErr_SetFromErrnoWithFilenameObject(PyExc_OSError, path.object);
        }
        return i32(-1);
    }
    if _Py_set_inheritable(fd, 0, &mut _Py_open_cloexec_works) < 0 {
        close(fd);
        return i32(-1);
    }
    return fd;
}

def os_close_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    # No retry on EINTR: see http://lwn.net/Articles/576478/.
    thread = PyEval_SaveThread();
    res = close(fd);
    PyEval_RestoreThread(thread);
    if res < 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

def os_closerange_impl(
    module: ptr[PyObject], fd_low: i32, fd_high: i32
) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    _Py_closerange(fd_low, i32.wrap(i64(fd_high) - 1));
    PyEval_RestoreThread(thread);
    return Py_NewRef(Py_None);
}

def os_dup_impl(module: ptr[PyObject], fd: i32) -> i32 {
    return _Py_dup(fd);
}

# dup2() then, for a non-inheritable copy, clearing the flag.
def:priv dup2_then_set_inheritable(fd: i32, fd2: i32, inheritable: bool) -> i32 {
    thread = PyEval_SaveThread();
    res = dup2(fd, fd2);
    PyEval_RestoreThread(thread);
    if res < 0 {
        posix_error();
        return i32(-1);
    }
    no_atomic = i32(0);
    if not inheritable and _Py_set_inheritable(fd2, 0, &mut no_atomic) < 0 {
        close(fd2);
        return i32(-1);
    }
    return res;
}

# dup2() can fail with EINTR if the target FD is already open, because it
# then has to be closed; like close(), EINTR is not retried.
def os_dup2_impl(module: ptr[PyObject], fd: i32, fd2: i32, inheritable: bool) -> i32 {
    if not HAVE_DUP3 {
        return dup2_then_set_inheritable(fd, fd2, inheritable);
    }
    res = i32(0);
    if not inheritable and DUP3_WORKS != 0 {
        thread = PyEval_SaveThread();
        res = dup3_call(fd, fd2, i32(O_CLOEXEC));
        PyEval_RestoreThread(thread);
        if res < 0 {
            if DUP3_WORKS == -1 {
                DUP3_WORKS = i32(1) if jacpy_errno() != ENOSYS else i32(0);
            }
            if DUP3_WORKS != 0 {
                posix_error();
                return i32(-1);
            }
        }
    }
    if inheritable or DUP3_WORKS == 0 {
        return dup2_then_set_inheritable(fd, fd2, inheritable);
    }
    return res;
}

# --- lseek, read, write ------------------------------------------------------

def os_lseek_impl(module: ptr[PyObject], fd: i32, position: i64, how: i32) -> i64 {
    # Turn 0, 1, 2 into SEEK_{SET,CUR,END}.
    if how == 0 {
        how = i32(SEEK_SET);
    } elif how == 1 {
        how = i32(SEEK_CUR);
    } elif how == 2 {
        how = i32(SEEK_END);
    }
    thread = PyEval_SaveThread();
    result = lseek(fd, position, how);
    PyEval_RestoreThread(thread);
    if result < 0 {
        posix_error();
    }
    return result;
}

def os_read_impl(module: ptr[PyObject], fd: i32, length: i64) -> ptr[PyObject] {
    if length < 0 {
        jacpy_set_errno(EINVAL);
        return posix_error();
    }
    if length > PY_READ_MAX {
        length = PY_READ_MAX;
    }
    buffer = PyBytes_FromStringAndSize(ptr[u8](), length);
    if not buffer {
        return NULL;
    }
    n = _Py_read(fd, ptr(PyBytes_AsString(buffer)), u64(length));
    if n == -1 {
        jacpy_release(buffer);
        return NULL;
    }
    if n != length {
        _PyBytes_Resize(&mut buffer, n);
    }
    return buffer;
}

def os_readinto_impl(module: ptr[PyObject], fd: i32, buffer: BufferArgument) -> i64 {
    return _Py_read(fd, buffer.address(), u64(buffer.size()));
}

# The PySequence_Check()/PySequence_Size() preamble of the vector calls: the
# count, or -1 with the exception set.
def:priv sequence_count(buffers: ptr[PyObject], message: str) -> i64 {
    if PySequence_Check(buffers) == 0 {
        PyErr_SetString(PyExc_TypeError, message);
        return -1;
    }
    return PySequence_Size(buffers);
}

def os_readv_impl(module: ptr[PyObject], fd: i32, buffers: ptr[PyObject]) -> i64 {
    cnt = sequence_count(buffers, "readv() arg 2 must be a sequence");
    if cnt < 0 {
        return -1;
    }
    vectors = iov_setup(buffers, cnt, PyBUF_WRITABLE);
    if vectors is None {
        return -1;
    }
    n = i64(0);
    async_err = False;
    while True {
        thread = PyEval_SaveThread();
        n = readv(fd, vectors.iov, i32.wrap(cnt));
        PyEval_RestoreThread(thread);
        if not (n < 0 and jacpy_errno() == EINTR) {
            break;
        }
        async_err = PyErr_CheckSignals() != 0;
        if async_err {
            break;
        }
    }
    saved_errno = jacpy_errno();
    iov_cleanup(vectors, i32.wrap(cnt));
    if n < 0 {
        if not async_err {
            jacpy_set_errno(saved_errno);
            posix_error();
        }
        return -1;
    }
    return n;
}

def os_pread_impl(
    module: ptr[PyObject], fd: i32, length: i64, offset: i64
) -> ptr[PyObject] {
    if length < 0 {
        jacpy_set_errno(EINVAL);
        return posix_error();
    }
    buffer = PyBytes_FromStringAndSize(ptr[u8](), length);
    if not buffer {
        return NULL;
    }
    n = i64(0);
    async_err = False;
    while True {
        thread = PyEval_SaveThread();
        n = pread(fd, ptr(PyBytes_AsString(buffer)), u64(length), offset);
        PyEval_RestoreThread(thread);
        if not (n < 0 and jacpy_errno() == EINTR) {
            break;
        }
        async_err = PyErr_CheckSignals() != 0;
        if async_err {
            break;
        }
    }
    if n < 0 {
        if not async_err {
            posix_error();
        }
        jacpy_release(buffer);
        return NULL;
    }
    if n != length {
        _PyBytes_Resize(&mut buffer, n);
    }
    return buffer;
}

def os_preadv_impl(
    module: ptr[PyObject], fd: i32, buffers: ptr[PyObject], offset: i64, flags: i32
) -> i64 {
    cnt = sequence_count(buffers, "preadv2() arg 2 must be a sequence");
    if cnt < 0 {
        return -1;
    }
    if not HAVE_PREADV2 and flags != 0 {
        argument_unavailable_error("preadv2", "flags");
        return -1;
    }
    vectors = iov_setup(buffers, cnt, PyBUF_WRITABLE);
    if vectors is None {
        return -1;
    }
    n = i64(0);
    async_err = False;
    while True {
        thread = PyEval_SaveThread();
        if HAVE_PREADV2 {
            n = preadv2_call(fd, vectors.iov, i32.wrap(cnt), offset, flags);
        } else {
            n = preadv(fd, vectors.iov, i32.wrap(cnt), offset);
        }
        PyEval_RestoreThread(thread);
        if not (n < 0 and jacpy_errno() == EINTR) {
            break;
        }
        async_err = PyErr_CheckSignals() != 0;
        if async_err {
            break;
        }
    }
    saved_errno = jacpy_errno();
    iov_cleanup(vectors, i32.wrap(cnt));
    if n < 0 {
        if not async_err {
            jacpy_set_errno(saved_errno);
            posix_error();
        }
        return -1;
    }
    return n;
}

def os_write_impl(module: ptr[PyObject], fd: i32, data: BufferArgument) -> i64 {
    return _Py_write(fd, data.address(), u64(data.size()));
}

# --- sendfile ----------------------------------------------------------------

# The headers or trailers of the BSD sendfile(): their iovec array and count,
# with `sbytes` grown by the headers' length.
obj:priv SendfileVectors {
    has iov: ptr[iovec] = ptr[iovec](),
        buf: ptr[Py_buffer] = ptr[Py_buffer](),
        count: i32 = 0,
        sbytes: i64 = 0;
}

def:priv sendfile_vectors(
    items: ptr[PyObject], what: str, sbytes: i64, counted: bool
) -> (SendfileVectors | None) {
    part = SendfileVectors(sbytes=sbytes);
    if not items {
        return part;
    }
    if PySequence_Check(items) == 0 {
        PyErr_SetString(PyExc_TypeError, "sendfile() " + what + "s must be a sequence");
        return None;
    }
    i = PySequence_Size(items);
    if i < 0 {
        return None;
    }
    if i > INT_MAX {
        PyErr_SetString(PyExc_OverflowError, "sendfile() " + what + " is too large");
        return None;
    }
    if i > 0 {
        part.count = i32(i);
        vectors = iov_setup(items, i64(part.count), PyBUF_SIMPLE);
        if vectors is None {
            return None;
        }
        part.iov = vectors.iov;
        part.buf = vectors.buf;
        if counted {
            for j in range(part.count) {
                blen = i64.wrap((part.iov + j).view(1)[0].iov_len);
                if part.sbytes >= OFF_T_MAX - blen {
                    PyErr_SetString(
                        PyExc_OverflowError, "sendfile() " + what + " is too large"
                    );
                    return None;
                }
                part.sbytes += blen;
            }
        }
    }
    return part;
}

def:priv sendfile_cleanup(part: SendfileVectors) {
    if part.iov {
        iov_cleanup(IoVectors(iov=part.iov, buf=part.buf), part.count);
    }
}

def os_sendfile_darwin_impl(
    module: ptr[PyObject],
    out_fd: i32,
    in_fd: i32,
    offset: i64,
    sbytes: i64,
    headers: ptr[PyObject],
    trailers: ptr[PyObject],
    flags: i32
) -> ptr[PyObject] {
    head = sendfile_vectors(headers, "header", sbytes, True);
    if head is None {
        return NULL;
    }
    tail = sendfile_vectors(trailers, "trailer", head.sbytes, False);
    if tail is None {
        return NULL;
    }
    total = tail.sbytes;
    ret = i64(0);
    async_err = False;
    while True {
        thread = PyEval_SaveThread();
        (sent, sent_total) = sendfile_darwin_call(
            in_fd,
            out_fd,
            offset,
            total,
            head.iov,
            head.count,
            tail.iov,
            tail.count,
            flags
        );
        ret = sent;
        total = sent_total;
        PyEval_RestoreThread(thread);
        if not (ret < 0 and jacpy_errno() == EINTR) {
            break;
        }
        async_err = PyErr_CheckSignals() != 0;
        if async_err {
            break;
        }
    }
    saved_errno = jacpy_errno();
    sendfile_cleanup(head);
    sendfile_cleanup(tail);
    if ret < 0 {
        if (saved_errno == EAGAIN or saved_errno == EBUSY) and total != 0 {
            # some data has been sent
            return PyLong_FromLong(total);
        }
        # no data has been sent; upper application is supposed
        # to retry on EAGAIN or EBUSY
        if not async_err {
            jacpy_set_errno(saved_errno);
            posix_error();
        }
        return NULL;
    }
    return PyLong_FromLong(total);
}

def os_sendfile_linux_impl(
    module: ptr[PyObject], out_fd: i32, in_fd: i32, offobj: ptr[PyObject], count: i64
) -> ptr[PyObject] {
    ret = i64(0);
    async_err = False;
    if offobj == Py_None {
        while True {
            thread = PyEval_SaveThread();
            (sent, _) = sendfile_linux_call(out_fd, in_fd, False, 0, u64.wrap(count));
            ret = sent;
            PyEval_RestoreThread(thread);
            if not (ret < 0 and jacpy_errno() == EINTR) {
                break;
            }
            async_err = PyErr_CheckSignals() != 0;
            if async_err {
                break;
            }
        }
        if ret < 0 {
            return NULL if async_err else posix_error();
        }
        return PyLong_FromSsize_t(ret);
    }
    converted = Py_off_t_converter(offobj);
    if converted is None {
        return NULL;
    }
    offset: i64 = converted;
    while True {
        thread = PyEval_SaveThread();
        (sent, moved) = sendfile_linux_call(
            out_fd, in_fd, True, offset, u64.wrap(count)
        );
        ret = sent;
        offset = moved;
        PyEval_RestoreThread(thread);
        if not (ret < 0 and jacpy_errno() == EINTR) {
            break;
        }
        async_err = PyErr_CheckSignals() != 0;
        if async_err {
            break;
        }
    }
    if ret < 0 {
        return NULL if async_err else posix_error();
    }
    return PyLong_FromSsize_t(ret);
}

def os__fcopyfile_impl(
    module: ptr[PyObject], in_fd: i32, out_fd: i32, flags: i32
) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    ret = fcopyfile_call(in_fd, out_fd, flags);
    PyEval_RestoreThread(thread);
    if ret < 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

# --- isatty, pipes -----------------------------------------------------------

def os_isatty_impl(module: ptr[PyObject], fd: i32) -> i32 {
    thread = PyEval_SaveThread();
    return_value = isatty(fd);
    PyEval_RestoreThread(thread);
    return return_value;
}

def os_pipe_impl(module: ptr[PyObject]) -> ptr[PyObject] {
    fds = fd_pair();
    res = i32(0);
    fallback = True;
    if HAVE_PIPE2 {
        thread = PyEval_SaveThread();
        res = pipe2_call(&mut fds, i32(O_CLOEXEC));
        PyEval_RestoreThread(thread);
        fallback = res != 0 and jacpy_errno() == ENOSYS;
    }
    if fallback {
        thread = PyEval_SaveThread();
        res = pipe(&mut fds);
        PyEval_RestoreThread(thread);
        if res == 0 {
            no_atomic = i32(0);
            if _Py_set_inheritable(fds.fd0, 0, &mut no_atomic) < 0
                or _Py_set_inheritable(fds.fd1, 0, &mut no_atomic) < 0 {
                close(fds.fd0);
                close(fds.fd1);
                return NULL;
            }
        }
    }
    if res != 0 {
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return fd_tuple(fds.fd0, fds.fd1);
}

def os_pipe2_impl(module: ptr[PyObject], flags: i32) -> ptr[PyObject] {
    fds = fd_pair();
    res = pipe2_call(&mut fds, flags);
    if res != 0 {
        return posix_error();
    }
    return fd_tuple(fds.fd0, fds.fd1);
}

# --- writev, pwrite, pwritev -------------------------------------------------

def os_writev_impl(module: ptr[PyObject], fd: i32, buffers: ptr[PyObject]) -> i64 {
    cnt = sequence_count(buffers, "writev() arg 2 must be a sequence");
    if cnt < 0 {
        return -1;
    }
    vectors = iov_setup(buffers, cnt, PyBUF_SIMPLE);
    if vectors is None {
        return -1;
    }
    result = i64(0);
    async_err = False;
    while True {
        thread = PyEval_SaveThread();
        result = writev(fd, vectors.iov, i32.wrap(cnt));
        PyEval_RestoreThread(thread);
        if not (result < 0 and jacpy_errno() == EINTR) {
            break;
        }
        async_err = PyErr_CheckSignals() != 0;
        if async_err {
            break;
        }
    }
    if result < 0 and not async_err {
        posix_error();
    }
    iov_cleanup(vectors, i32.wrap(cnt));
    return result;
}

def os_pwrite_impl(
    module: ptr[PyObject], fd: i32, buffer: BufferArgument, offset: i64
) -> i64 {
    size = i64(0);
    async_err = False;
    while True {
        thread = PyEval_SaveThread();
        size = pwrite(fd, buffer.address(), u64(buffer.size()), offset);
        PyEval_RestoreThread(thread);
        if not (size < 0 and jacpy_errno() == EINTR) {
            break;
        }
        async_err = PyErr_CheckSignals() != 0;
        if async_err {
            break;
        }
    }
    if size < 0 and not async_err {
        posix_error();
    }
    return size;
}

def os_pwritev_impl(
    module: ptr[PyObject], fd: i32, buffers: ptr[PyObject], offset: i64, flags: i32
) -> i64 {
    cnt = sequence_count(buffers, "pwritev() arg 2 must be a sequence");
    if cnt < 0 {
        return -1;
    }
    if not HAVE_PWRITEV2 and flags != 0 {
        argument_unavailable_error("pwritev2", "flags");
        return -1;
    }
    vectors = iov_setup(buffers, cnt, PyBUF_SIMPLE);
    if vectors is None {
        return -1;
    }
    result = i64(0);
    async_err = False;
    while True {
        thread = PyEval_SaveThread();
        if HAVE_PWRITEV2 {
            result = pwritev2_call(fd, vectors.iov, i32.wrap(cnt), offset, flags);
        } else {
            result = pwritev(fd, vectors.iov, i32.wrap(cnt), offset);
        }
        PyEval_RestoreThread(thread);
        if not (result < 0 and jacpy_errno() == EINTR) {
            break;
        }
        async_err = PyErr_CheckSignals() != 0;
        if async_err {
            break;
        }
    }
    if result < 0 {
        if not async_err {
            posix_error();
        }
        result = -1;
    }
    iov_cleanup(vectors, i32.wrap(cnt));
    return result;
}

# --- copy_file_range, splice -------------------------------------------------

# The optional offsets of copy_file_range() and splice(): a Py_off_t each,
# None standing for the current position.
obj:priv OffsetPair {
    has src: i64 = 0,
        dst: i64 = 0,
        has_src: bool = False,
        has_dst: bool = False;
}

def:priv offset_pair(
    count: i64, offset_src: ptr[PyObject], offset_dst: ptr[PyObject]
) -> (OffsetPair | None) {
    if count < 0 {
        PyErr_SetString(PyExc_ValueError, "negative value for 'count' not allowed");
        return None;
    }
    pair = OffsetPair();
    if offset_src != Py_None {
        value = Py_off_t_converter(offset_src);
        if value is None {
            return None;
        }
        pair.src = value;
        pair.has_src = True;
    }
    if offset_dst != Py_None {
        value = Py_off_t_converter(offset_dst);
        if value is None {
            return None;
        }
        pair.dst = value;
        pair.has_dst = True;
    }
    return pair;
}

# One copy_file_range() (`use_splice` False) or splice() call on `offsets`.
def:priv offset_copy_call(
    use_splice: bool, src: i32, dst: i32, count: i64, offsets: OffsetPair, flags: u32
) -> i64 {
    # The offsets the call moves persist across its EINTR retries.
    if use_splice {
        (ret, moved_src, moved_dst) = splice_call(
            src,
            offsets.has_src,
            offsets.src,
            dst,
            offsets.has_dst,
            offsets.dst,
            u64(count),
            flags
        );
        offsets.src = moved_src;
        offsets.dst = moved_dst;
        return ret;
    }
    (copied, copied_src, copied_dst) = copy_file_range_call(
        src,
        offsets.has_src,
        offsets.src,
        dst,
        offsets.has_dst,
        offsets.dst,
        u64(count),
        flags
    );
    offsets.src = copied_src;
    offsets.dst = copied_dst;
    return copied;
}

def:priv offset_copy(
    use_splice: bool,
    src: i32,
    dst: i32,
    count: i64,
    offset_src: ptr[PyObject],
    offset_dst: ptr[PyObject],
    flags: u32
) -> ptr[PyObject] {
    offsets = offset_pair(count, offset_src, offset_dst);
    if offsets is None {
        return NULL;
    }
    ret = i64(0);
    async_err = False;
    while True {
        thread = PyEval_SaveThread();
        ret = offset_copy_call(use_splice, src, dst, count, offsets, flags);
        PyEval_RestoreThread(thread);
        if not (ret < 0 and jacpy_errno() == EINTR) {
            break;
        }
        async_err = PyErr_CheckSignals() != 0;
        if async_err {
            break;
        }
    }
    if ret < 0 {
        return NULL if async_err else posix_error();
    }
    return PyLong_FromSsize_t(ret);
}

def os_copy_file_range_impl(
    module: ptr[PyObject],
    src: i32,
    dst: i32,
    count: i64,
    offset_src: ptr[PyObject],
    offset_dst: ptr[PyObject]
) -> ptr[PyObject] {
    # The flags argument is provided to allow for future extensions and
    # currently must be 0.
    return offset_copy(False, src, dst, count, offset_src, offset_dst, u32(0));
}

def os_splice_impl(
    module: ptr[PyObject],
    src: i32,
    dst: i32,
    count: i64,
    offset_src: ptr[PyObject],
    offset_dst: ptr[PyObject],
    flags: u32
) -> ptr[PyObject] {
    return offset_copy(True, src, dst, count, offset_src, offset_dst, flags);
}

# --- device_encoding, memfd, eventfd -----------------------------------------

def os_device_encoding_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    return _Py_device_encoding(fd);
}

def os_memfd_create_impl(
    module: ptr[PyObject], name: ptr[PyObject], flags: u32
) -> ptr[PyObject] {
    name_bytes = PyBytes_AsString(name);
    thread = PyEval_SaveThread();
    fd = memfd_create_call(name_bytes, flags);
    PyEval_RestoreThread(thread);
    if fd == -1 {
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return PyLong_FromLong(i64(fd));
}

def os_eventfd_impl(module: ptr[PyObject], initval: u32, flags: i32) -> ptr[PyObject] {
    # initval is limited to uint32_t, internal counter is uint64_t
    thread = PyEval_SaveThread();
    fd = eventfd_call(initval, flags);
    PyEval_RestoreThread(thread);
    if fd == -1 {
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return PyLong_FromLong(i64(fd));
}

def os_eventfd_read_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    (result, value) = eventfd_read_call(fd);
    PyEval_RestoreThread(thread);
    if result == -1 {
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return PyLong_FromUnsignedLongLong(value);
}

def os_eventfd_write_impl(module: ptr[PyObject], fd: i32, value: u64) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    result = eventfd_write_call(fd, value);
    PyEval_RestoreThread(thread);
    if result == -1 {
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return Py_NewRef(Py_None);
}

# --- terminal size -----------------------------------------------------------

glob TERMINAL_SIZE_DOC: str = "A tuple of (columns, lines) for holding terminal window size",
     TERMINAL_SIZE_FIELDS: list[tuple[str, str]] = [
         ("columns", "width of the terminal window in characters"),
         ("lines", "height of the terminal window in characters")
     ];

# Under some conditions stdout may not be connected and fileno(stdout) may
# point to an invalid file descriptor; the ioctl then fails with EBADF.
def os_get_terminal_size_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    # struct winsize w, in PyMem memory the variadic ioctl() gets the
    # address of.
    w = ptr[winsize](PyMem_Malloc(u64(8)));
    if not w {
        return PyErr_NoMemory();
    }
    if ioctl(fd, u64.wrap(TIOCGWINSZ), ptr(w)) != 0 {
        error = PyErr_SetFromErrno(PyExc_OSError);
        PyMem_Free(ptr(w));
        return error;
    }
    columns = i64(w.view(1)[0].ws_col);
    lines = i64(w.view(1)[0].ws_row);
    PyMem_Free(ptr(w));
    termsize = PyStructSequence_New(state_object(module, STATE_TERMINAL_SIZE_TYPE));
    if not termsize {
        return NULL;
    }
    item = PyLong_FromLong(columns);
    if not item {
        jacpy_release(termsize);
        return NULL;
    }
    PyStructSequence_SetItem(termsize, 0, item);
    item = PyLong_FromLong(lines);
    if not item {
        jacpy_release(termsize);
        return NULL;
    }
    PyStructSequence_SetItem(termsize, 1, item);
    return termsize;
}

# --- inheritable and blocking flags ------------------------------------------

def os_get_inheritable_impl(module: ptr[PyObject], fd: i32) -> i32 {
    return _Py_get_inheritable(fd);
}

def os_set_inheritable_impl(
    module: ptr[PyObject], fd: i32, inheritable: i32
) -> ptr[PyObject] {
    no_atomic = i32(0);
    if _Py_set_inheritable(fd, inheritable, &mut no_atomic) < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

def os_get_blocking_impl(module: ptr[PyObject], fd: i32) -> i32 {
    return _Py_get_blocking(fd);
}

def os_set_blocking_impl(
    module: ptr[PyObject], fd: i32, blocking: bool
) -> ptr[PyObject] {
    if _Py_set_blocking(fd, i32(1) if blocking else i32(0)) < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

# --- module exec -------------------------------------------------------------

def posix_fileio_exec(module: ptr[PyObject]) -> bool {
    terminal_size = struct_sequence_type(
        "os.terminal_size", TERMINAL_SIZE_DOC, TERMINAL_SIZE_FIELDS, 2
    );
    return add_state_owned(
        module, STATE_TERMINAL_SIZE_TYPE, "terminal_size", terminal_size
    );
}
