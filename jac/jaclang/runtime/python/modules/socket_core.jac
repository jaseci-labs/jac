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

import from c {
    glob sock_cloexec_works: i32 = -1,
         accept4_works: i32 = -1;
}

glob INVALID_SOCKET: i32 = -1,
     SOCKLEN_T_LIMIT: int = 0x7FFFFFFF,
     INT_MAX: int = 2147483647,
     SOCK_ADDR_SIZE: int = 128,
     SOCKADDR_IN_SIZE: int = 16,
     SOCKADDR_IN6_SIZE: int = 28,
     SEC_TO_NS: int = 1000000000,
     STATE_SOCK_TYPE: int = 0,
     STATE_HERROR: int = 1,
     STATE_GAIERROR: int = 2,
     STATE_COUNT: int = 3,
     TIMEOUT_ERROR: int = -9223372036854775807 - 1;

obj ModuleToken {
    has handle: ptr = ptr();
}

glob socket_module_token: ModuleToken = ModuleToken();

obj SocketState(NativeState) {
    has defaulttimeout: int = -SEC_TO_NS;

    def traverse_refs(visitor: ptr, context: ptr) -> i32;
    def clear;
}

def socket_state(module: ptr[PyObject]) -> SocketState;

def state_ref(module: ptr[PyObject], index: int) -> ptr[PyObject];

def sock_type_of(module: ptr[PyObject]) -> ptr[PyTypeObject];

def module_of_type(type: ptr[PyTypeObject]) -> ptr[PyObject];

def sock_of(op: ptr[PyObject]) -> ptr[PySocketSockObject];

def module_of(s: ptr[PySocketSockObject]) -> ptr[PyObject];

def get_sock_fd(s: ptr[PySocketSockObject]) -> i32;

def set_sock_fd(s: ptr[PySocketSockObject], fd: i32);

def sock_family(s: ptr[PySocketSockObject]) -> int;

def sock_proto(s: ptr[PySocketSockObject]) -> int;

def sock_timeout(s: ptr[PySocketSockObject]) -> int;

def set_sock_timeout(s: ptr[PySocketSockObject], timeout: int);

def set_error -> ptr[PyObject];

def socket_error(code: int) -> ptr[PyObject];

def select_error -> ptr[PyObject];

def set_herror(module: ptr[PyObject], h_error: int) -> ptr[PyObject];

def set_gaierror(module: ptr[PyObject], error: int) -> ptr[PyObject];

def htons(x: int) -> int;

def htonl(x: int) -> int;

def ntohs(x: int) -> int;

def ntohl(x: int) -> int;

def internal_setblocking(s: ptr[PySocketSockObject], block: bool) -> int;

obj SocketCall {
    has error: int = 0;

    def run(fd: i32) -> bool abst;
}

def internal_select(
    s: ptr[PySocketSockObject],
    writing: bool,
    interval: int,
    connect: bool,
    call: SocketCall
) -> int;

def sock_call_ex(
    s: ptr[PySocketSockObject],
    writing: bool,
    call: SocketCall,
    connect: bool,
    capture: bool,
    timeout: int
) -> int;

def sock_call(s: ptr[PySocketSockObject], writing: bool, call: SocketCall) -> int;

def socket_parse_timeout(timeout_obj: ptr[PyObject]) -> int;

def timeout_object(timeout: int) -> ptr[PyObject];

def init_sockobject(
    module: ptr[PyObject],
    s: ptr[PySocketSockObject],
    fd: i32,
    family: int,
    type: int,
    proto: int
) -> int;

def new_sockobject(
    module: ptr[PyObject], fd: i32, family: int, type: int, proto: int
) -> ptr[PyObject];

impl SocketState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return i32(0);
}

impl SocketState.clear {}

impl socket_state(module: ptr[PyObject]) -> SocketState {
    if jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        if isinstance(state, SocketState) {
            return state;
        }
    }
    return SocketState();
}

impl state_ref(module: ptr[PyObject], index: int) -> ptr[PyObject] {
    return jacpy_binding_state_get(module, i64(index));
}

impl sock_type_of(module: ptr[PyObject]) -> ptr[PyTypeObject] {
    return ptr[PyTypeObject](state_ref(module, STATE_SOCK_TYPE));
}

impl module_of_type(type: ptr[PyTypeObject]) -> ptr[PyObject] {
    return jacpy_binding_owner(ptr[PyObject](type), socket_module_token.handle);
}

impl sock_of(op: ptr[PyObject]) -> ptr[PySocketSockObject] {
    return ptr[PySocketSockObject](op);
}

impl module_of(s: ptr[PySocketSockObject]) -> ptr[PyObject] {
    module = ptr[PyObject](s.view(1)[0].state);
    if module {
        return module;
    }
    return module_of_type(object_type(ptr[PyObject](s)));
}

impl get_sock_fd(s: ptr[PySocketSockObject]) -> i32 {
    return s.view(1)[0].sock_fd;
}

impl set_sock_fd(s: ptr[PySocketSockObject], fd: i32) {
    s.view(1)[0].sock_fd = fd;
}

impl sock_family(s: ptr[PySocketSockObject]) -> int {
    return int(s.view(1)[0].sock_family);
}

impl sock_proto(s: ptr[PySocketSockObject]) -> int {
    return int(s.view(1)[0].sock_proto);
}

impl sock_timeout(s: ptr[PySocketSockObject]) -> int {
    return int(s.view(1)[0].sock_timeout);
}

impl set_sock_timeout(s: ptr[PySocketSockObject], timeout: int) {
    s.view(1)[0].sock_timeout = i64(timeout);
}

impl set_error -> ptr[PyObject] {
    return PyErr_SetFromErrno(PyExc_OSError);
}

impl socket_error(code: int) -> ptr[PyObject] {
    jacpy_set_errno(i64(code));
    return PyErr_SetFromErrno(PyExc_OSError);
}

impl select_error -> ptr[PyObject] {
    PyErr_SetString(PyExc_OSError, ptr[u8]("unable to select on socket"));
    return NULL;
}

impl set_herror(module: ptr[PyObject], h_error: int) -> ptr[PyObject] {
    v = Py_BuildValue(ptr[u8]("(is)"), i32(h_error), hstrerror(i32(h_error)));
    if v {
        PyErr_SetObject(state_ref(module, STATE_HERROR), v);
        jacpy_release(v);
    }
    return NULL;
}

impl set_gaierror(module: ptr[PyObject], error: int) -> ptr[PyObject] {
    if error == EAI_SYSTEM {
        return set_error();
    }
    v = Py_BuildValue(ptr[u8]("(is)"), i32(error), gai_strerror(i32(error)));
    if v {
        PyErr_SetObject(state_ref(module, STATE_GAIERROR), v);
        jacpy_release(v);
    }
    return NULL;
}

impl htons(x: int) -> int {
    return ((x & 0xFF) << 8) | ((x >> 8) & 0xFF);
}

impl htonl(x: int) -> int {
    return ((x & 0xFF) << 24)
        | ((x & 0xFF00) << 8)
        | ((x >> 8) & 0xFF00)
        | ((x >> 24) & 0xFF);
}

impl ntohs(x: int) -> int {
    return htons(x);
}

impl ntohl(x: int) -> int {
    return htonl(x);
}

impl internal_setblocking(s: ptr[PySocketSockObject], block: bool) -> int {
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

impl internal_select(
    s: ptr[PySocketSockObject],
    writing: bool,
    interval: int,
    connect: bool,
    call: SocketCall
) -> int {
    fd = get_sock_fd(s);

    if fd == INVALID_SOCKET {
        return 0;
    }
    events = POLLOUT if writing else POLLIN;
    if connect {
        events = events | POLLERR;
    }
    record = pollfd(fd=fd, events=i16(events), revents=i16(0));
    ms = int(_PyTime_AsMilliseconds(i64(interval), _PyTime_ROUND_CEILING));
    if ms > INT_MAX {
        ms = INT_MAX;
    }

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

impl sock_call_ex(
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
        if has_timeout or connect {
            res = 0;
            if has_timeout {
                interval = 0;
                if deadline_initialized {
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
                    if PyErr_CheckSignals() != 0 {
                        if capture {
                            call.error = -1;
                        }
                        return -1;
                    }

                    continue;
                }

                socket_error(call.error);
                return -1;
            }
            if res == 1 {
                if capture {
                    call.error = EWOULDBLOCK;
                } else {
                    PyErr_SetString(PyExc_TimeoutError, ptr[u8]("timed out"));
                }
                return -1;
            }
        }

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

            if PyErr_CheckSignals() != 0 {
                if capture {
                    call.error = -1;
                }
                return -1;
            }
        }
        if sock_timeout(s) > 0
            and (failed_errno == EWOULDBLOCK or failed_errno == EAGAIN) {
            continue;
        }

        if not capture {
            socket_error(failed_errno);
        }
        return -1;
    }
    return -1;
}

impl sock_call(s: ptr[PySocketSockObject], writing: bool, call: SocketCall) -> int {
    return sock_call_ex(s, writing, call, False, False, sock_timeout(s));
}

impl socket_parse_timeout(timeout_obj: ptr[PyObject]) -> int {
    if timeout_obj == Py_None {
        return -SEC_TO_NS;
    }
    timeout: i64 = 0;
    if _PyTime_FromSecondsObject(&mut timeout, timeout_obj, _PyTime_ROUND_TIMEOUT)
        < 0 {
        return TIMEOUT_ERROR;
    }
    if timeout < 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("Timeout value out of range"));
        return TIMEOUT_ERROR;
    }
    return int(timeout);
}

impl timeout_object(timeout: int) -> ptr[PyObject] {
    if timeout < 0 {
        return Py_NewRef(Py_None);
    }
    return PyFloat_FromDouble(PyTime_AsSecondsDouble(i64(timeout)));
}

impl init_sockobject(
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

impl new_sockobject(
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
