"""Shared machinery of the _socket module: module state, error reporting and
the blocking, timeout and signal-retry discipline of every socket call.

Derived from CPython 3.14.6 Modules/socketmodule.c; see ../LICENSE.cpython.
A socket object is a PySocketSockObject in place (layouts.jac), since _ssl.c
reads its descriptor and timeout. The C module's socket-function callbacks
(`int (*sock_func)(PySocketSockObject *, void *)`) are SocketCall records
here: sock_call_ex() runs one with the GIL released and retries it as the C
function does.
"""
import from jaclang.runtime.python.cpython_api {
    jacpy_errno,
    jacpy_release,
    jacpy_set_errno,
    NULL,
    Py_BuildValue,
    Py_None,
    PyErr_CheckSignals,
    PyErr_SetFromErrno,
    PyErr_SetObject,
    PyErr_SetString,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_OSError,
    PyExc_TimeoutError,
    PyExc_ValueError,
    PyObject,
    PyTime_AsSecondsDouble,
    PyFloat_FromDouble,
    Py_NewRef,
    _PyDeadline_Get,
    _PyDeadline_Init,
    _PyTime_AsMilliseconds,
    _PyTime_FromSecondsObject
}
import from jaclang.runtime.python.layouts {
    PySocketSockObject,
    PyTypeObject,
    _PyTime_ROUND_CEILING,
    _PyTime_ROUND_TIMEOUT,
    _socket_state
}
import from jaclang.runtime.python.object_model.header { object_type }
import from jaclang.runtime.python.bindings.state { NativeState }
import from jaclang.runtime.python.bindings.module {
    jacpy_binding_module_native_get,
    jacpy_binding_module_native_present,
    jacpy_binding_state_get
}
import from jaclang.runtime.python.bindings.type { jacpy_binding_owner }
import from jaclang.runtime.python.modules.errno_constants {
    EAGAIN,
    EINTR,
    EWOULDBLOCK
}
import from jaclang.runtime.python.modules.socket_constants {
    EAI_SYSTEM,
    FIONBIO,
    POLLERR,
    POLLIN,
    POLLOUT,
    SOCK_CLOEXEC,
    SOCK_NONBLOCK
}
import from jaclang.runtime.python.modules.socket_platform {
    HAS_SOCK_CLOEXEC,
    HAS_SOCK_NONBLOCK
}

import from c {
    obj pollfd {
        has fd: i32 = 0,
            events: i16 = 0,
            revents: i16 = 0;
    }  obj hostent {
        has h_name: ptr[u8] = ptr[u8](),
            h_aliases: ptr = ptr(),
            h_addrtype: i32 = 0,
            h_length: i32 = 0,
            h_addr_list: ptr = ptr();
    }  obj iovec {
        has iov_base: ptr = ptr(),
            iov_len: u64 = 0;
    }  obj if_nameindex_record {
        has if_index: u32 = 0,
            if_name: ptr[u8] = ptr[u8]();
    }  def poll(fds: &mut pollfd, nfds: u64, timeout: i32) -> i32;  def ioctl(
        fd: i32, request: u64, *args: any
    ) -> i32;  def close(fd: i32) -> i32;  def gai_strerror(error: i32) -> ptr[u8];  def hstrerror(
        error: i32
    ) -> ptr[u8];
}

# socket(), accept4() and socketpair() fail with EINVAL where the kernel
# predates SOCK_CLOEXEC; -1 until the first call finds out. accept4()
# fails with ENOSYS where the kernel predates it. Process-wide, as the C
# module's statics are.
import from c {
    glob sock_cloexec_works: i32 = -1,
         accept4_works: i32 = -1;
}

glob INVALID_SOCKET: i32 = -1,
     # SOCKLEN_T_LIMIT: the smaller of (2**31)-1 and INT_MAX.
     SOCKLEN_T_LIMIT: int = 0x7FFFFFFF,
     INT_MAX: int = 2147483647,
     # sizeof(sock_addr_t): struct sockaddr_storage is the largest member.
     SOCK_ADDR_SIZE: int = 128,
     # sizeof(struct sockaddr_in) and sizeof(struct sockaddr_in6).
     SOCKADDR_IN_SIZE: int = 16,
     SOCKADDR_IN6_SIZE: int = 28,
     # A PyTime_t second.
     SEC_TO_NS: int = 1000000000,
     # The module's state references.
     STATE_SOCK_TYPE: int = 0,
     STATE_HERROR: int = 1,
     STATE_GAIERROR: int = 2,
     STATE_COUNT: int = 3,
     # socket_parse_timeout()'s failure: no timeout is this negative.
     TIMEOUT_ERROR: int = -9223372036854775807 - 1;

# The ModuleDefinition handle of _socket, set when the module executes, for
# PyType_GetModuleByDef().
obj ModuleToken {
    has handle: ptr = ptr();
}

glob socket_module_token: ModuleToken = ModuleToken();

"""The module state that is not a reference: the default timeout of new
sockets (PyTime_t nanoseconds, negative for none)."""
obj SocketState(NativeState) {
    has defaulttimeout: int = -SEC_TO_NS;

    def traverse_refs(visitor: ptr, context: ptr) -> i32 {
        return i32(0);
    }

    def clear {}
}

# ---------------------------------------------------------------------------
# Module and object access.

def socket_state(module: ptr[PyObject]) -> SocketState {
    if jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        if isinstance(state, SocketState) {
            return state;
        }
    }
    return SocketState();
}

def state_ref(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    return jacpy_binding_state_get(module, i64(index));
}

def sock_type_of(module: ptr[PyObject]) -> ptr[PyTypeObject] {
    return ptr[PyTypeObject](state_ref(module, STATE_SOCK_TYPE));
}

"""find_module_state_by_def(): the _socket module of a socket type (borrowed)."""
def module_of_type(type: ptr[PyTypeObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(ptr[PyObject](type), socket_module_token.handle);
}

def sock_of(op: ptr[PyObject]) -> ptr[PySocketSockObject] {
    return ptr[PySocketSockObject](op);
}

"""s->state: the module a socket was initialized in (borrowed), else that
of its type."""
def module_of(s: ptr[PySocketSockObject]) -> ptr[PyObject] {
    module = ptr[PyObject](s.view(1)[0].state);
    if module {
        return module;
    }
    return module_of_type(object_type(ptr[PyObject](s)));
}

def get_sock_fd(s: ptr[PySocketSockObject]) -> i32 {
    return s.view(1)[0].sock_fd;
}

def set_sock_fd(s: ptr[PySocketSockObject], fd: i32) {
    s.view(1)[0].sock_fd = fd;
}

def sock_family(s: ptr[PySocketSockObject]) -> int {
    return int(s.view(1)[0].sock_family);
}

def sock_proto(s: ptr[PySocketSockObject]) -> int {
    return int(s.view(1)[0].sock_proto);
}

def sock_timeout(s: ptr[PySocketSockObject]) -> int {
    return int(s.view(1)[0].sock_timeout);
}

def set_sock_timeout(s: ptr[PySocketSockObject], timeout: int) {
    s.view(1)[0].sock_timeout = i64(timeout);
}

# ---------------------------------------------------------------------------
# Errors.

"""set_error(): OSError from errno; the socket error handler."""
def set_error -> ptr[PyObject] {
    return PyErr_SetFromErrno(PyExc_OSError);
}

"""set_error() for errno `code`, captured where the failing call returned."""
def socket_error(code: int) -> ptr[PyObject] {
    jacpy_set_errno(i64(code));
    return PyErr_SetFromErrno(PyExc_OSError);
}

def select_error -> ptr[PyObject] {
    PyErr_SetString(PyExc_OSError, "unable to select on socket");
    return NULL;
}

"""set_herror(): socket.herror((h_error, hstrerror(h_error)))."""
def set_herror(module: ptr[PyObject], h_error: int) -> ptr[PyObject] {
    v = Py_BuildValue("(is)", i32(h_error), hstrerror(i32(h_error)));
    if v {
        PyErr_SetObject(state_ref(module, STATE_HERROR), v);
        jacpy_release(v);
    }
    return NULL;
}

"""set_gaierror(): socket.gaierror((error, gai_strerror(error))), or the
errno error for EAI_SYSTEM."""
def set_gaierror(module: ptr[PyObject], error: int) -> ptr[PyObject] {
    if error == EAI_SYSTEM {
        return set_error();
    }
    v = Py_BuildValue("(is)", i32(error), gai_strerror(i32(error)));
    if v {
        PyErr_SetObject(state_ref(module, STATE_GAIERROR), v);
        jacpy_release(v);
    }
    return NULL;
}

# ---------------------------------------------------------------------------
# Byte order (every supported target is little-endian).

def htons(x: int) -> int {
    return ((x & 0xFF) << 8) | ((x >> 8) & 0xFF);
}

def htonl(x: int) -> int {
    return ((x & 0xFF) << 24)
        | ((x & 0xFF00) << 8)
        | ((x >> 8) & 0xFF00)
        | ((x >> 24) & 0xFF);
}

def ntohs(x: int) -> int {
    return htons(x);
}

def ntohl(x: int) -> int {
    return htonl(x);
}

# ---------------------------------------------------------------------------
# Blocking mode, readiness and the socket-call loop.

"""internal_setblocking(): ioctl(FIONBIO) with the GIL released; -1 with
OSError set on failure."""
def internal_setblocking(s: ptr[PySocketSockObject], block: bool) -> int {
    flag = i32(0) if block else i32(1);
    thread = PyEval_SaveThread();
    result = ioctl(get_sock_fd(s), u64(FIONBIO), &mut flag);
    error = jacpy_errno();
    PyEval_RestoreThread(thread);
    if result == -1 {
        socket_error(int(error));
        return -1;
    }
    return 0;
}

"""A socket function sock_call_ex() runs with the GIL released: run()
performs one system call, True on success; on failure it leaves errno for
`error`."""
obj SocketCall {
    has error: int = 0;

    def run(fd: i32) -> bool abst;
}

"""internal_select(): wait with poll() until the socket is readable (or
writable), at most `interval` (PyTime_t, negative for no limit). 0 when
ready, 1 on timeout, -1 on error with errno in `call.error`."""
def internal_select(
    s: ptr[PySocketSockObject],
    writing: bool,
    interval: int,
    connect: bool,
    call: SocketCall
) -> int {
    fd = get_sock_fd(s);
    # Guard against closed socket.
    if fd == INVALID_SOCKET {
        return 0;
    }
    events = POLLOUT if writing else POLLIN;
    if connect {
        # POSIX sockets become writable on connection success or failure.
        events = events | POLLERR;
    }
    record = pollfd(fd=fd, events=i16(events), revents=i16(0));
    ms = int(_PyTime_AsMilliseconds(i64(interval), _PyTime_ROUND_CEILING));
    if ms > INT_MAX {
        ms = INT_MAX;
    }
    # A negative poll() timeout must be exactly INFTIM (-1) on BSDs.
    if ms < 0 {
        ms = -1;
    }
    thread = PyEval_SaveThread();
    n = poll(&mut record, u64(1), i32(ms));
    error = jacpy_errno();
    PyEval_RestoreThread(thread);
    if n < 0 {
        call.error = int(error);
        return -1;
    }
    if n == 0 {
        return 1;
    }
    return 0;
}

"""sock_call_ex(): call `call` on the socket, waiting for readiness first
when the socket has a timeout (or `connect`), retrying on EINTR unless a
signal handler raised (PEP 475), and rechecking readiness on a spurious
EWOULDBLOCK. 0 on success. With `capture`, a failure of the socket
function (or a timeout) is left in `call.error` (-1 when a signal handler
raised) instead of raised; the result is still -1."""
def sock_call_ex(
    s: ptr[PySocketSockObject],
    writing: bool,
    call: SocketCall,
    connect: bool,
    capture: bool,
    timeout: int
) -> int {
    has_timeout = timeout > 0;
    deadline = 0;
    deadline_initialized = False;
    while True {
        # For connect(), poll even for blocking socket. The connection runs
        # asynchronously.
        if has_timeout or connect {
            res = 0;
            if has_timeout {
                interval = 0;
                if deadline_initialized {
                    # Recompute the timeout.
                    interval = int(_PyDeadline_Get(i64(deadline)));
                } else {
                    deadline_initialized = True;
                    deadline = int(_PyDeadline_Init(i64(timeout)));
                    interval = timeout;
                }
                if interval >= 0 {
                    res = internal_select(s, writing, interval, connect, call);
                } else {
                    res = 1;
                }
            } else {
                res = internal_select(s, writing, timeout, connect, call);
            }
            if res == -1 {
                if call.error == EINTR {
                    # select() was interrupted by a signal.
                    if PyErr_CheckSignals() != 0 {
                        if capture {
                            call.error = -1;
                        }
                        return -1;
                    }
                    # Retry select().
                    continue;
                }
                # select() failed.
                socket_error(call.error);
                return -1;
            }
            if res == 1 {
                if capture {
                    call.error = EWOULDBLOCK;
                } else {
                    PyErr_SetString(PyExc_TimeoutError, "timed out");
                }
                return -1;
            }
            # The socket is ready.
        }
        # Retry sock_func() when a signal interrupts it.
        failed_errno = 0;
        while True {
            thread = PyEval_SaveThread();
            ok = call.run(get_sock_fd(s));
            PyEval_RestoreThread(thread);
            if ok {
                if capture {
                    call.error = 0;
                }
                return 0;
            }
            failed_errno = call.error;
            if failed_errno != EINTR {
                break;
            }
            # sock_func() was interrupted by a signal.
            if PyErr_CheckSignals() != 0 {
                if capture {
                    call.error = -1;
                }
                return -1;
            }
        }
        if sock_timeout(s) > 0
            and (failed_errno == EWOULDBLOCK or failed_errno == EAGAIN) {
            # False positive: the socket was ready but the call would block
            # (a datagram dropped for a bad checksum); wait again.
            continue;
        }
        # sock_func() failed.
        if not capture {
            socket_error(failed_errno);
        }
        return -1;
    }
    return -1;
}

"""sock_call(): sock_call_ex() with the socket's timeout, raising."""
def sock_call(s: ptr[PySocketSockObject], writing: bool, call: SocketCall) -> int {
    return sock_call_ex(s, writing, call, False, False, sock_timeout(s));
}

# ---------------------------------------------------------------------------
# Timeouts.

"""socket_parse_timeout(): None is no timeout (-1 s), otherwise a
non-negative number of seconds rounded away from zero; TIMEOUT_ERROR with
the exception set."""
def socket_parse_timeout(timeout_obj: ptr[PyObject]) -> int {
    if timeout_obj == Py_None {
        return -SEC_TO_NS;
    }
    timeout: i64 = 0;
    if _PyTime_FromSecondsObject(&mut timeout, timeout_obj, _PyTime_ROUND_TIMEOUT)
        < 0 {
        return TIMEOUT_ERROR;
    }
    if timeout < 0 {
        PyErr_SetString(PyExc_ValueError, "Timeout value out of range");
        return TIMEOUT_ERROR;
    }
    return int(timeout);
}

"""A timeout as the float seconds gettimeout() returns, or None."""
def timeout_object(timeout: int) -> ptr[PyObject] {
    if timeout < 0 {
        return Py_NewRef(Py_None);
    }
    return PyFloat_FromDouble(PyTime_AsSecondsDouble(i64(timeout)));
}

# ---------------------------------------------------------------------------
# Socket initialization.

"""init_sockobject(): the descriptor, family, type (without SOCK_NONBLOCK
and SOCK_CLOEXEC) and protocol, the error handler, and the module's default
timeout, putting the descriptor in non-blocking mode for a timeout."""
def init_sockobject(
    module: ptr[PyObject],
    s: ptr[PySocketSockObject],
    fd: i32,
    family: int,
    type: int,
    proto: int
) -> int {
    set_sock_fd(s, fd);
    record = s.view(1);
    record[0].sock_family = i32(family);
    sock_type = type;
    if HAS_SOCK_NONBLOCK {
        sock_type = sock_type & ~SOCK_NONBLOCK;
    }
    if HAS_SOCK_CLOEXEC {
        sock_type = sock_type & ~SOCK_CLOEXEC;
    }
    record[0].sock_type = i32(sock_type);
    record[0].sock_proto = i32(proto);
    record[0].errorhandler = set_error;
    if HAS_SOCK_NONBLOCK and (type & SOCK_NONBLOCK) != 0 {
        set_sock_timeout(s, 0);
    } else {
        set_sock_timeout(s, socket_state(module).defaulttimeout);
        if sock_timeout(s) >= 0 and internal_setblocking(s, False) == -1 {
            return -1;
        }
    }
    record[0].state = ptr[_socket_state](module);
    return 0;
}

"""new_sockobject(): a new socket of the module's type over `fd`."""
def new_sockobject(
    module: ptr[PyObject], fd: i32, family: int, type: int, proto: int
) -> ptr[PyObject] {
    tp = sock_type_of(module);
    op = tp.view(1)[0].tp_alloc(tp, 0);
    if not op {
        return NULL;
    }
    if init_sockobject(module, sock_of(op), fd, family, type, proto) == -1 {
        jacpy_release(op);
        return NULL;
    }
    return op;
}
