import from c {
    obj winsize {
        has ws_row: u16 = 0,
            ws_col: u16 = 0,
            ws_xpixel: u16 = 0,
            ws_ypixel: u16 = 0;
    }  glob _Py_open_cloexec_works: i32; def PyOS_setsig(
        sig: i32, handler: ptr
    ) -> ptr;  def open(path: ptr[u8], flags: i32, *args: any) -> i32;  def openat(
        dir_fd: i32, path: ptr[u8], flags: i32, *args: any
    ) -> i32;  def close(fd: i32) -> i32;  def dup2(fd: i32, fd2: i32) -> i32;  def lseek(
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
     DUP3_WORKS: i32 = -1;

def:priv Py_off_t_converter(value: ptr[PyObject]) -> (i64 | None);

obj IoVectors {
    has iov: ptr[iovec] = ptr[iovec](),
        buf: ptr[Py_buffer] = ptr[Py_buffer]();
}

def iov_setup(seq: ptr[PyObject], cnt: i64, type_flags: i32) -> (IoVectors | None);

def:priv iov_setup_failed(
    iov: ptr[iovec], buf: ptr[Py_buffer], filled: i64
) -> (IoVectors | None);

def iov_cleanup(vectors: IoVectors, cnt: i32);

def:priv fd_tuple(first: i32, second: i32) -> ptr[PyObject];

def os_ttyname_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject];

def os_ctermid_impl(module: ptr[PyObject]) -> ptr[PyObject];

def os_posix_openpt_impl(module: ptr[PyObject], oflag: i32) -> i32;

def os_grantpt_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject];

def os_unlockpt_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject];

def:priv py_ptsname(fd: i32) -> ptr[PyObject];

def os_ptsname_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject];

def os_openpty_impl(module: ptr[PyObject]) -> ptr[PyObject];

def os_login_tty_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject];

def:priv build_itimerspec(curr_value: itimerspec) -> ptr[PyObject];

def:priv build_itimerspec_ns(curr_value: itimerspec) -> ptr[PyObject];

def:priv itimerspec_of(initial: i64, interval: i64) -> (itimerspec | None);

def os_timerfd_create_impl(
    module: ptr[PyObject], clockid: i32, flags: i32
) -> ptr[PyObject];

def:priv timerfd_settime_common(
    fd: i32, flags: i32, initial: i64, interval: i64
) -> (itimerspec | None);

def os_timerfd_settime_impl(
    module: ptr[PyObject],
    fd: i32,
    flags: i32,
    initial_double: f64,
    interval_double: f64
) -> ptr[PyObject];

def os_timerfd_settime_ns_impl(
    module: ptr[PyObject], fd: i32, flags: i32, initial: i64, interval: i64
) -> ptr[PyObject];

def:priv timerfd_gettime_common(fd: i32) -> (itimerspec | None);

def os_timerfd_gettime_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject];

def os_timerfd_gettime_ns_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject];

def os_open_impl(
    module: ptr[PyObject], path: path_t, flags: i32, mode: i32, dir_fd: i32
) -> i32;

def os_close_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject];

def os_closerange_impl(
    module: ptr[PyObject], fd_low: i32, fd_high: i32
) -> ptr[PyObject];

def os_dup_impl(module: ptr[PyObject], fd: i32) -> i32;

def:priv dup2_then_set_inheritable(fd: i32, fd2: i32, inheritable: bool) -> i32;

def os_dup2_impl(module: ptr[PyObject], fd: i32, fd2: i32, inheritable: bool) -> i32;

def os_lseek_impl(module: ptr[PyObject], fd: i32, position: i64, how: i32) -> i64;

def os_read_impl(module: ptr[PyObject], fd: i32, length: i64) -> ptr[PyObject];

def os_readinto_impl(module: ptr[PyObject], fd: i32, buffer: BufferArgument) -> i64;

def:priv sequence_count(buffers: ptr[PyObject], message: str) -> i64;

def os_readv_impl(module: ptr[PyObject], fd: i32, buffers: ptr[PyObject]) -> i64;

def os_pread_impl(
    module: ptr[PyObject], fd: i32, length: i64, offset: i64
) -> ptr[PyObject];

def os_preadv_impl(
    module: ptr[PyObject], fd: i32, buffers: ptr[PyObject], offset: i64, flags: i32
) -> i64;

def os_write_impl(module: ptr[PyObject], fd: i32, data: BufferArgument) -> i64;

obj:priv SendfileVectors {
    has iov: ptr[iovec] = ptr[iovec](),
        buf: ptr[Py_buffer] = ptr[Py_buffer](),
        count: i32 = 0,
        sbytes: i64 = 0;
}

def:priv sendfile_vectors(
    items: ptr[PyObject], what: str, sbytes: i64, counted: bool
) -> (SendfileVectors | None);

def:priv sendfile_cleanup(part: SendfileVectors);

def os_sendfile_darwin_impl(
    module: ptr[PyObject],
    out_fd: i32,
    in_fd: i32,
    offset: i64,
    sbytes: i64,
    headers: ptr[PyObject],
    trailers: ptr[PyObject],
    flags: i32
) -> ptr[PyObject];

def os_sendfile_linux_impl(
    module: ptr[PyObject], out_fd: i32, in_fd: i32, offobj: ptr[PyObject], count: i64
) -> ptr[PyObject];

def os__fcopyfile_impl(
    module: ptr[PyObject], in_fd: i32, out_fd: i32, flags: i32
) -> ptr[PyObject];

def os_isatty_impl(module: ptr[PyObject], fd: i32) -> i32;

def os_pipe_impl(module: ptr[PyObject]) -> ptr[PyObject];

def os_pipe2_impl(module: ptr[PyObject], flags: i32) -> ptr[PyObject];

def os_writev_impl(module: ptr[PyObject], fd: i32, buffers: ptr[PyObject]) -> i64;

def os_pwrite_impl(
    module: ptr[PyObject], fd: i32, buffer: BufferArgument, offset: i64
) -> i64;

def os_pwritev_impl(
    module: ptr[PyObject], fd: i32, buffers: ptr[PyObject], offset: i64, flags: i32
) -> i64;

obj:priv OffsetPair {
    has src: i64 = 0,
        dst: i64 = 0,
        has_src: bool = False,
        has_dst: bool = False;
}

def:priv offset_pair(
    count: i64, offset_src: ptr[PyObject], offset_dst: ptr[PyObject]
) -> (OffsetPair | None);

def:priv offset_copy_call(
    use_splice: bool, src: i32, dst: i32, count: i64, offsets: OffsetPair, flags: u32
) -> i64;

def:priv offset_copy(
    use_splice: bool,
    src: i32,
    dst: i32,
    count: i64,
    offset_src: ptr[PyObject],
    offset_dst: ptr[PyObject],
    flags: u32
) -> ptr[PyObject];

def os_copy_file_range_impl(
    module: ptr[PyObject],
    src: i32,
    dst: i32,
    count: i64,
    offset_src: ptr[PyObject],
    offset_dst: ptr[PyObject]
) -> ptr[PyObject];

def os_splice_impl(
    module: ptr[PyObject],
    src: i32,
    dst: i32,
    count: i64,
    offset_src: ptr[PyObject],
    offset_dst: ptr[PyObject],
    flags: u32
) -> ptr[PyObject];

def os_device_encoding_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject];

def os_memfd_create_impl(
    module: ptr[PyObject], name: ptr[PyObject], flags: u32
) -> ptr[PyObject];

def os_eventfd_impl(module: ptr[PyObject], initval: u32, flags: i32) -> ptr[PyObject];

def os_eventfd_read_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject];

def os_eventfd_write_impl(module: ptr[PyObject], fd: i32, value: u64) -> ptr[PyObject];

glob TERMINAL_SIZE_DOC: str = "A tuple of (columns, lines) for holding terminal window size",
     TERMINAL_SIZE_FIELDS: list[tuple[str, str]] = [
         ("columns", "width of the terminal window in characters"),
         ("lines", "height of the terminal window in characters")
     ];

def os_get_terminal_size_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject];

def os_get_inheritable_impl(module: ptr[PyObject], fd: i32) -> i32;

def os_set_inheritable_impl(
    module: ptr[PyObject], fd: i32, inheritable: i32
) -> ptr[PyObject];

def os_get_blocking_impl(module: ptr[PyObject], fd: i32) -> i32;

def os_set_blocking_impl(
    module: ptr[PyObject], fd: i32, blocking: bool
) -> ptr[PyObject];

def posix_fileio_exec(module: ptr[PyObject]) -> bool;

impl Py_off_t_converter(value: ptr[PyObject]) -> (i64 | None) {
    offset = PyLong_AsLong(value);
    if PyErr_Occurred() {
        return None;
    }
    return offset;
}

impl iov_setup(seq: ptr[PyObject], cnt: i64, type_flags: i32) -> (IoVectors | None) {
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

impl iov_setup_failed(
    iov: ptr[iovec], buf: ptr[Py_buffer], filled: i64
) -> (IoVectors | None) {
    PyMem_Free(ptr(iov));
    for j in range(filled) {
        PyBuffer_Release(buf + j);
    }
    PyMem_Free(ptr(buf));
    return None;
}

impl iov_cleanup(vectors: IoVectors, cnt: i32) {
    PyMem_Free(ptr(vectors.iov));
    for i in range(cnt) {
        PyBuffer_Release(vectors.buf + i);
    }
    PyMem_Free(ptr(vectors.buf));
}

impl fd_tuple(first: i32, second: i32) -> ptr[PyObject] {
    return Py_BuildValue(ptr[u8]("(ii)"), first, second);
}

impl os_ttyname_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
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

impl os_ctermid_impl(module: ptr[PyObject]) -> ptr[PyObject] {
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

impl os_posix_openpt_impl(module: ptr[PyObject], oflag: i32) -> i32 {
    oflag |= i32(O_CLOEXEC);
    fd = posix_openpt(oflag);
    if fd == -1 {
        posix_error();
        return i32(-1);
    }

    no_atomic = i32(0);
    if _Py_set_inheritable(fd, 0, &mut no_atomic) < 0 {
        close(fd);
        return i32(-1);
    }
    return fd;
}

impl os_grantpt_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
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

impl os_unlockpt_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    if unlockpt(fd) == -1 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

impl py_ptsname(fd: i32) -> ptr[PyObject] {
    jacpy_set_errno(0);
    name = ptsname(fd);
    if not name {
        return posix_error();
    }
    return PyUnicode_DecodeFSDefault(name);
}

impl os_ptsname_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
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

impl os_openpty_impl(module: ptr[PyObject]) -> ptr[PyObject] {
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

impl os_login_tty_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    if HAVE_LOGIN_TTY {
        if login_tty(fd) == -1 {
            return posix_error();
        }
        return Py_NewRef(Py_None);
    }

    if setsid() == -1 {
        return posix_error();
    }

    if ioctl(fd, u64.wrap(TIOCSCTTY), ptr()) == -1 {
        return posix_error();
    }

    if dup2(fd, 0) == -1 or dup2(fd, 1) == -1 or dup2(fd, 2) == -1 {
        return posix_error();
    }
    if fd > 2 {
        close(fd);
    }
    return Py_NewRef(Py_None);
}

impl build_itimerspec(curr_value: itimerspec) -> ptr[PyObject] {
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

impl build_itimerspec_ns(curr_value: itimerspec) -> ptr[PyObject] {
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
    return Py_BuildValue(ptr[u8]("LL"), value, interval);
}

impl itimerspec_of(initial: i64, interval: i64) -> (itimerspec | None) {
    new_value = itimerspec();
    value_ts = timespec();
    if _PyTime_AsTimespec(initial, &mut value_ts) < 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("invalid initial value"));
        return None;
    }
    interval_ts = timespec();
    if _PyTime_AsTimespec(interval, &mut interval_ts) < 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("invalid interval value"));
        return None;
    }
    new_value.it_value = value_ts;
    new_value.it_interval = interval_ts;
    return new_value;
}

impl os_timerfd_create_impl(
    module: ptr[PyObject], clockid: i32, flags: i32
) -> ptr[PyObject] {
    thread = PyEval_SaveThread();

    flags |= i32(TFD_CLOEXEC);
    fd = timerfd_create_call(clockid, flags);
    PyEval_RestoreThread(thread);
    if fd == -1 {
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return PyLong_FromLong(i64(fd));
}

impl timerfd_settime_common(
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

impl os_timerfd_settime_impl(
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

impl os_timerfd_settime_ns_impl(
    module: ptr[PyObject], fd: i32, flags: i32, initial: i64, interval: i64
) -> ptr[PyObject] {
    old_value = timerfd_settime_common(fd, flags, initial, interval);
    if old_value is None {
        return NULL;
    }
    return build_itimerspec_ns(old_value);
}

impl timerfd_gettime_common(fd: i32) -> (itimerspec | None) {
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

impl os_timerfd_gettime_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    curr_value = timerfd_gettime_common(fd);
    if curr_value is None {
        return NULL;
    }
    return build_itimerspec(curr_value);
}

impl os_timerfd_gettime_ns_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    curr_value = timerfd_gettime_common(fd);
    if curr_value is None {
        return NULL;
    }
    return build_itimerspec_ns(curr_value);
}

impl os_open_impl(
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

impl os_close_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    res = close(fd);
    PyEval_RestoreThread(thread);
    if res < 0 {
        return posix_error();
    }
    return Py_NewRef(Py_None);
}

impl os_closerange_impl(
    module: ptr[PyObject], fd_low: i32, fd_high: i32
) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    _Py_closerange(fd_low, i32.wrap(i64(fd_high) - 1));
    PyEval_RestoreThread(thread);
    return Py_NewRef(Py_None);
}

impl os_dup_impl(module: ptr[PyObject], fd: i32) -> i32 {
    return _Py_dup(fd);
}

impl dup2_then_set_inheritable(fd: i32, fd2: i32, inheritable: bool) -> i32 {
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

impl os_dup2_impl(module: ptr[PyObject], fd: i32, fd2: i32, inheritable: bool) -> i32 {
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

impl os_lseek_impl(module: ptr[PyObject], fd: i32, position: i64, how: i32) -> i64 {
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

impl os_read_impl(module: ptr[PyObject], fd: i32, length: i64) -> ptr[PyObject] {
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

impl os_readinto_impl(module: ptr[PyObject], fd: i32, buffer: BufferArgument) -> i64 {
    return _Py_read(fd, buffer.address(), u64(buffer.size()));
}

impl sequence_count(buffers: ptr[PyObject], message: str) -> i64 {
    if PySequence_Check(buffers) == 0 {
        object_error(PyExc_TypeError, message);
        return -1;
    }
    return PySequence_Size(buffers);
}

impl os_readv_impl(module: ptr[PyObject], fd: i32, buffers: ptr[PyObject]) -> i64 {
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

impl os_pread_impl(
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

impl os_preadv_impl(
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

impl os_write_impl(module: ptr[PyObject], fd: i32, data: BufferArgument) -> i64 {
    return _Py_write(fd, data.address(), u64(data.size()));
}

impl sendfile_vectors(
    items: ptr[PyObject], what: str, sbytes: i64, counted: bool
) -> (SendfileVectors | None) {
    part = SendfileVectors(sbytes=sbytes);
    if not items {
        return part;
    }
    if PySequence_Check(items) == 0 {
        object_error(PyExc_TypeError, "sendfile() " + what + "s must be a sequence");
        return None;
    }
    i = PySequence_Size(items);
    if i < 0 {
        return None;
    }
    if i > INT_MAX {
        object_error(PyExc_OverflowError, "sendfile() " + what + " is too large");
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
                    object_error(
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

impl sendfile_cleanup(part: SendfileVectors) {
    if part.iov {
        iov_cleanup(IoVectors(iov=part.iov, buf=part.buf), part.count);
    }
}

impl os_sendfile_darwin_impl(
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
            return PyLong_FromLong(total);
        }

        if not async_err {
            jacpy_set_errno(saved_errno);
            posix_error();
        }
        return NULL;
    }
    return PyLong_FromLong(total);
}

impl os_sendfile_linux_impl(
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

impl os__fcopyfile_impl(
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

impl os_isatty_impl(module: ptr[PyObject], fd: i32) -> i32 {
    thread = PyEval_SaveThread();
    return_value = isatty(fd);
    PyEval_RestoreThread(thread);
    return return_value;
}

impl os_pipe_impl(module: ptr[PyObject]) -> ptr[PyObject] {
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

impl os_pipe2_impl(module: ptr[PyObject], flags: i32) -> ptr[PyObject] {
    fds = fd_pair();
    res = pipe2_call(&mut fds, flags);
    if res != 0 {
        return posix_error();
    }
    return fd_tuple(fds.fd0, fds.fd1);
}

impl os_writev_impl(module: ptr[PyObject], fd: i32, buffers: ptr[PyObject]) -> i64 {
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

impl os_pwrite_impl(
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

impl os_pwritev_impl(
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

impl offset_pair(
    count: i64, offset_src: ptr[PyObject], offset_dst: ptr[PyObject]
) -> (OffsetPair | None) {
    if count < 0 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("negative value for 'count' not allowed")
        );
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

impl offset_copy_call(
    use_splice: bool, src: i32, dst: i32, count: i64, offsets: OffsetPair, flags: u32
) -> i64 {
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

impl offset_copy(
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

impl os_copy_file_range_impl(
    module: ptr[PyObject],
    src: i32,
    dst: i32,
    count: i64,
    offset_src: ptr[PyObject],
    offset_dst: ptr[PyObject]
) -> ptr[PyObject] {
    return offset_copy(False, src, dst, count, offset_src, offset_dst, u32(0));
}

impl os_splice_impl(
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

impl os_device_encoding_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    return _Py_device_encoding(fd);
}

impl os_memfd_create_impl(
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

impl os_eventfd_impl(module: ptr[PyObject], initval: u32, flags: i32) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    fd = eventfd_call(initval, flags);
    PyEval_RestoreThread(thread);
    if fd == -1 {
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return PyLong_FromLong(i64(fd));
}

impl os_eventfd_read_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    (result, value) = eventfd_read_call(fd);
    PyEval_RestoreThread(thread);
    if result == -1 {
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return PyLong_FromUnsignedLongLong(value);
}

impl os_eventfd_write_impl(
    module: ptr[PyObject], fd: i32, value: u64
) -> ptr[PyObject] {
    thread = PyEval_SaveThread();
    result = eventfd_write_call(fd, value);
    PyEval_RestoreThread(thread);
    if result == -1 {
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    return Py_NewRef(Py_None);
}

impl os_get_terminal_size_impl(module: ptr[PyObject], fd: i32) -> ptr[PyObject] {
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

impl os_get_inheritable_impl(module: ptr[PyObject], fd: i32) -> i32 {
    return _Py_get_inheritable(fd);
}

impl os_set_inheritable_impl(
    module: ptr[PyObject], fd: i32, inheritable: i32
) -> ptr[PyObject] {
    no_atomic = i32(0);
    if _Py_set_inheritable(fd, inheritable, &mut no_atomic) < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

impl os_get_blocking_impl(module: ptr[PyObject], fd: i32) -> i32 {
    return _Py_get_blocking(fd);
}

impl os_set_blocking_impl(
    module: ptr[PyObject], fd: i32, blocking: bool
) -> ptr[PyObject] {
    if _Py_set_blocking(fd, i32(1) if blocking else i32(0)) < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

impl posix_fileio_exec(module: ptr[PyObject]) -> bool {
    terminal_size = struct_sequence_type(
        "os.terminal_size", TERMINAL_SIZE_DOC, TERMINAL_SIZE_FIELDS, 2
    );
    return add_state_owned(
        module, STATE_TERMINAL_SIZE_TYPE, "terminal_size", terminal_size
    );
}
