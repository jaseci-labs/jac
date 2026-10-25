import from c {
    def socket(domain: i32, type: i32, protocol: i32) -> i32;  def bind(
        fd: i32, addr: ptr, len: u32
    ) -> i32;  def connect(fd: i32, addr: ptr, len: u32) -> i32;  def listen(
        fd: i32, backlog: i32
    ) -> i32;  def accept(fd: i32, addr: ptr, len: ptr[u32]) -> i32;  def getsockname(
        fd: i32, addr: ptr, len: ptr[u32]
    ) -> i32;  def getpeername(fd: i32, addr: ptr, len: ptr[u32]) -> i32;  def getsockopt(
        fd: i32, level: i32, name: i32, value: ptr, len: ptr[u32]
    ) -> i32;  def setsockopt(
        fd: i32, level: i32, name: i32, value: ptr, len: u32
    ) -> i32;  def recv(fd: i32, buf: ptr, len: u64, flags: i32) -> i64;  def recvfrom(
        fd: i32, buf: ptr, len: u64, flags: i32, addr: ptr, addrlen: ptr[u32]
    ) -> i64;  def recvmsg(fd: i32, msg: ptr, flags: i32) -> i64;  def send(
        fd: i32, buf: ptr, len: u64, flags: i32
    ) -> i64;  def sendto(
        fd: i32, buf: ptr, len: u64, flags: i32, addr: ptr, addrlen: u32
    ) -> i64;  def sendmsg(fd: i32, msg: ptr, flags: i32) -> i64;  def shutdown(
        fd: i32, how: i32
    ) -> i32;  glob PyLong_Type: PyTypeObject; glob:priv recv_into_keywords:
             list[ptr[u8]] = [
             ptr[u8]("buffer"),
             ptr[u8]("nbytes"),
             ptr[u8]("flags"),
             ptr[u8]()
         ],
         sendmsg_afalg_keywords: list[ptr[u8]] = [
             ptr[u8]("msg"),
             ptr[u8]("op"),
             ptr[u8]("iv"),
             ptr[u8]("assoclen"),
             ptr[u8]("flags"),
             ptr[u8]()
         ];
}

glob:priv SOCKLEN_SIZE: int = 8,
     IOVEC_SIZE: int = 16,
     CMSGINFO_SIZE: int = 88,
     SSIZE_MAX: int = 0x7FFFFFFFFFFFFFFF;

def new_address_space -> ptr[u8];

def length_cell(address: ptr[u8]) -> ptr[u32];

obj AcceptCall(SocketCall) {
    has address: ptr[u8],
        family: int,
        result: i32 = -1;

    def run(fd: i32) -> bool;
}

obj ConnectCall(SocketCall) {
    has scratch: ptr[u8];

    def run(fd: i32) -> bool;
}

obj RecvCall(SocketCall) {
    has buffer: ptr,
        length: int,
        flags: int,
        result: int = 0;

    def run(fd: i32) -> bool;
}

obj RecvFromCall(SocketCall) {
    has buffer: ptr,
        length: int,
        flags: int,
        address: ptr[u8],
        result: int = 0;

    def run(fd: i32) -> bool;
}

obj MessageCall(SocketCall) {
    has message: ptr[msghdr],
        flags: int,
        sending: bool,
        result: int = 0;

    def run(fd: i32) -> bool;
}

obj SendCall(SocketCall) {
    has buffer: ptr,
        length: int,
        flags: int,
        result: int = 0;

    def run(fd: i32) -> bool;
}

obj SendToCall(SocketCall) {
    has buffer: ptr,
        length: int,
        flags: int,
        address: ptr[u8],
        address_length: int,
        result: int = 0;

    def run(fd: i32) -> bool;
}

def cmsg_len_of(length: int) -> int;

def cmsg_space_of(length: int) -> int;

def cmsg_data(header: ptr[cmsghdr]) -> ptr[u8];

def cmsg_firsthdr(message: ptr[msghdr]) -> ptr[cmsghdr];

def get_CMSG_LEN(length: int) -> int;

def get_CMSG_SPACE(length: int) -> int;

def cmsg_min_space(message: ptr[msghdr], header: ptr[cmsghdr], space: int) -> bool;

def get_cmsg_data_space(message: ptr[msghdr], header: ptr[cmsghdr]) -> int;

obj CmsgData {
    has status: int = -1,
        length: int = 0;
}

def get_cmsg_data_len(message: ptr[msghdr], header: ptr[cmsghdr]) -> CmsgData;

def sock_accept(self: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def sock_setblocking(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def sock_getblocking(self: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def sock_settimeout(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def sock_gettimeout_method(
    self: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject];

def sock_gettimeout_getter(self: ptr[PyObject], closure: ptr) -> ptr[PyObject];

def sock_setsockopt(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv setsockopt_done(scratch: ptr[u8], res: i32) -> ptr[PyObject];

def sock_getsockopt(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def sock_bind(self: ptr[PyObject], addro: ptr[PyObject]) -> ptr[PyObject];

def sock_close(self: ptr[PyObject]) -> ptr[PyObject];

def sock_detach(self: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def internal_connect(
    s: ptr[PySocketSockObject], addr: ptr[u8], addrlen: int, raise_: bool
) -> int;

def sock_connect(self: ptr[PyObject], addro: ptr[PyObject]) -> ptr[PyObject];

def sock_connect_ex(self: ptr[PyObject], addro: ptr[PyObject]) -> ptr[PyObject];

def sock_fileno(self: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def:priv socket_name(self: ptr[PyObject], peer: bool) -> ptr[PyObject];

def sock_getsockname(self: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def sock_getpeername(self: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject];

def sock_listen(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def sock_recv_guts(
    s: ptr[PySocketSockObject], cbuf: ptr, length: int, flags: int
) -> int;

def sock_recv(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def sock_recv_into(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

obj RecvFromOutcome {
    has count: int = -1,
        address: ptr[PyObject] = NULL;
}

def sock_recvfrom_guts(
    s: ptr[PySocketSockObject], cbuf: ptr, length: int, flags: int
) -> RecvFromOutcome;

def sock_recvfrom(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def sock_recvfrom_into(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

obj ReceivedData {
    has into: bool = False,
        buffer: ptr[PyObject] = NULL;

    def value(received: int) -> ptr[PyObject];
}

def:priv close_received_fds(message: ptr[msghdr]);

def sock_recvmsg_guts(
    s: ptr[PySocketSockObject],
    iov: ptr,
    iovlen: int,
    flags: int,
    controllen: int,
    received: ReceivedData
) -> ptr[PyObject];

def:priv received_message(
    s: ptr[PySocketSockObject],
    message: ptr[msghdr],
    addrbuf: ptr[u8],
    addrbuflen: int,
    count: int,
    received: ReceivedData
) -> ptr[PyObject];

def sock_recvmsg(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv release_views(views: ptr[u8], count: int);

def sock_recvmsg_into(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def sock_send(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def sock_sendall(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def sock_sendto(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

obj DataBuffers {
    has iovs: ptr[u8] = ptr[u8](),
        views: ptr[u8] = ptr[u8](),
        count: int = 0;

    def close;
}

def sock_sendmsg_iovec(
    data_arg: ptr[PyObject], message: ptr[msghdr], buffers: DataBuffers
) -> bool;

def sock_sendmsg(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject];

def:priv sendmsg_finally(
    message: ptr[msghdr],
    addrbuf: ptr[u8],
    buffers: DataBuffers,
    cmsg_fast: ptr[PyObject],
    cmsgs: ptr[u8],
    ncmsgbufs: int,
    controlbuf: ptr,
    retval: ptr[PyObject]
) -> ptr[PyObject];

def sock_sendmsg_afalg(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def:priv afalg_finally(
    message: ptr[msghdr],
    buffers: DataBuffers,
    controlbuf: ptr,
    iv: ptr[Py_buffer],
    retval: ptr[PyObject]
) -> ptr[PyObject];

def sock_shutdown(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject];

def sock_finalize(self: ptr[PyObject]);

def sock_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32;

def sock_dealloc(self: ptr[PyObject]);

def sock_repr(self: ptr[PyObject]) -> ptr[PyObject];

def sock_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject];

def sock_init(
    self: ptr[PyObject], family: i32, type: i32, proto: i32, fdobj: ptr[PyObject]
) -> i32;

def set_inheritable_new(fd: i32) -> int;

impl new_address_space -> ptr[u8] {
    address = ptr[u8](PyMem_Calloc(1, u64(SOCK_ADDR_SIZE + SOCKLEN_SIZE)));
    if not address {
        PyErr_NoMemory();
    }
    return address;
}

impl length_cell(address: ptr[u8]) -> ptr[u32] {
    return ptr[u32](address + SOCK_ADDR_SIZE);
}

impl AcceptCall.run(fd: i32) -> bool {
    addr = ptr(self.address);
    paddrlen = length_cell(self.address);

    if HAS_ALG and self.family == AF_ALG {
        addr = ptr();
        paddrlen = ptr[u32]();
        length_cell(self.address).view(1)[0] = u32(0);
    }
    if HAS_ACCEPT4 and accept4_works != 0 {
        self.result = accept_cloexec(fd, addr, paddrlen, i32(SOCK_CLOEXEC));
        if self.result == INVALID_SOCKET and accept4_works == -1 {
            accept4_works = i32(1) if jacpy_errno() != ENOSYS else i32(0);
        }
    }
    if not HAS_ACCEPT4 or accept4_works == 0 {
        self.result = accept(fd, addr, paddrlen);
    }
    if self.result < 0 {
        self.error = int(jacpy_errno());
    }
    return self.result >= 0;
}

impl ConnectCall.run(fd: i32) -> bool {
    value = ptr[i32](self.scratch);
    size = ptr[u32](self.scratch + 4);
    value.view(1)[0] = i32(0);
    size.view(1)[0] = u32(4);
    if getsockopt(fd, i32(SOL_SOCKET), i32(SO_ERROR), ptr(value), size) != 0 {
        self.error = int(jacpy_errno());
        return False;
    }
    err = int(value.view(1)[0]);
    if err == EISCONN {
        return True;
    }
    if err != 0 {
        self.error = err;
        return False;
    }
    return True;
}

impl RecvCall.run(fd: i32) -> bool {
    self.result = int(recv(fd, self.buffer, u64(self.length), i32(self.flags)));
    if self.result < 0 {
        self.error = int(jacpy_errno());
    }
    return self.result >= 0;
}

impl RecvFromCall.run(fd: i32) -> bool {
    paddrlen = length_cell(self.address);
    jacpy_memory_zero(ptr(self.address), i64(paddrlen.view(1)[0]));
    self.result = int(
        recvfrom(
            fd,
            self.buffer,
            u64(self.length),
            i32(self.flags),
            ptr(self.address),
            paddrlen
        )
    );
    if self.result < 0 {
        self.error = int(jacpy_errno());
    }
    return self.result >= 0;
}

impl MessageCall.run(fd: i32) -> bool {
    if self.sending {
        self.result = int(sendmsg(fd, ptr(self.message), i32(self.flags)));
    } else {
        self.result = int(recvmsg(fd, ptr(self.message), i32(self.flags)));
    }
    if self.result < 0 {
        self.error = int(jacpy_errno());
    }
    return self.result >= 0;
}

impl SendCall.run(fd: i32) -> bool {
    self.result = int(send(fd, self.buffer, u64(self.length), i32(self.flags)));
    if self.result < 0 {
        self.error = int(jacpy_errno());
    }
    return self.result >= 0;
}

impl SendToCall.run(fd: i32) -> bool {
    self.result = int(
        sendto(
            fd,
            self.buffer,
            u64(self.length),
            i32(self.flags),
            ptr(self.address),
            u32(self.address_length)
        )
    );
    if self.result < 0 {
        self.error = int(jacpy_errno());
    }
    return self.result >= 0;
}

impl cmsg_len_of(length: int) -> int {
    return cmsg_align(CMSGHDR_SIZE) + length;
}

impl cmsg_space_of(length: int) -> int {
    return cmsg_align(CMSGHDR_SIZE) + cmsg_align(length);
}

impl cmsg_data(header: ptr[cmsghdr]) -> ptr[u8] {
    return ptr[u8](header) + cmsg_align(CMSGHDR_SIZE);
}

impl cmsg_firsthdr(message: ptr[msghdr]) -> ptr[cmsghdr] {
    if msg_controllen(message) >= CMSGHDR_SIZE {
        return ptr[cmsghdr](message.view(1)[0].msg_control);
    }
    return ptr[cmsghdr]();
}

impl get_CMSG_LEN(length: int) -> int {
    if length > SOCKLEN_T_LIMIT - cmsg_len_of(0) {
        return -1;
    }
    tmp = cmsg_len_of(length);
    if tmp > SOCKLEN_T_LIMIT or tmp < length {
        return -1;
    }
    return tmp;
}

impl get_CMSG_SPACE(length: int) -> int {
    if length > SOCKLEN_T_LIMIT - cmsg_space_of(1) {
        return -1;
    }
    tmp = cmsg_space_of(length);
    if tmp > SOCKLEN_T_LIMIT or tmp < length {
        return -1;
    }
    return tmp;
}

impl cmsg_min_space(message: ptr[msghdr], header: ptr[cmsghdr], space: int) -> bool {
    control = message.view(1)[0].msg_control;
    if not header or not control {
        return False;
    }

    cmsg_len_end = CMSGHDR_SIZE - 8;
    if space < cmsg_len_end {
        space = cmsg_len_end;
    }
    cmsg_offset = int(header) - int(control);
    return cmsg_offset >= 0 and cmsg_offset + space <= msg_controllen(message);
}

impl get_cmsg_data_space(message: ptr[msghdr], header: ptr[cmsghdr]) -> int {
    data_offset = int(cmsg_data(header)) - int(message.view(1)[0].msg_control);
    if data_offset > msg_controllen(message) {
        return -1;
    }
    return msg_controllen(message) - data_offset;
}

impl get_cmsg_data_len(message: ptr[msghdr], header: ptr[cmsghdr]) -> CmsgData {
    if not cmsg_min_space(message, header, cmsg_len_of(0))
        or cmsg_length(header) < cmsg_len_of(0) {
        return CmsgData();
    }
    cmsg_data_len = cmsg_length(header) - cmsg_len_of(0);
    space = get_cmsg_data_space(message, header);
    if space < 0 {
        return CmsgData();
    }
    if space >= cmsg_data_len {
        return CmsgData(status=0, length=cmsg_data_len);
    }
    return CmsgData(status=1, length=space);
}

impl sock_accept(self: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    addrlen = getsockaddrlen(s);
    if addrlen < 0 {
        return NULL;
    }
    space = new_address_space();
    if not space {
        return NULL;
    }
    length_cell(space).view(1)[0] = u32(addrlen);
    call = AcceptCall(address=space, family=sock_family(s));
    if sock_call(s, False, call) < 0 {
        free_addrbuf(space);
        return NULL;
    }
    newfd = call.result;
    if not HAS_ACCEPT4 or accept4_works == 0 {
        if _Py_set_inheritable(newfd, 0, None) < 0 {
            close(newfd);
            free_addrbuf(space);
            return NULL;
        }
    }
    sock = PyLong_FromLong(i64(newfd));
    if not sock {
        close(newfd);
        free_addrbuf(space);
        return NULL;
    }
    res = NULL;
    addr = makesockaddr(
        get_sock_fd(s), space, int(length_cell(space).view(1)[0]), sock_proto(s)
    );
    if addr {
        res = PyTuple_Pack(2, sock, addr);
        jacpy_release(addr);
    }
    jacpy_release(sock);
    free_addrbuf(space);
    return res;
}

impl sock_setblocking(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    block = PyObject_IsTrue(arg);
    if block < 0 {
        return NULL;
    }
    s = sock_of(self);
    set_sock_timeout(s, -SEC_TO_NS if block != 0 else 0);
    if internal_setblocking(s, block != 0) == -1 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

impl sock_getblocking(self: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    if sock_timeout(sock_of(self)) != 0 {
        return Py_NewRef(py_true());
    }
    return Py_NewRef(py_false());
}

impl sock_settimeout(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    timeout = socket_parse_timeout(arg);
    if timeout == TIMEOUT_ERROR {
        return NULL;
    }
    s = sock_of(self);
    set_sock_timeout(s, timeout);
    if internal_setblocking(s, timeout < 0) == -1 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

impl sock_gettimeout_method(
    self: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    return timeout_object(sock_timeout(sock_of(self)));
}

impl sock_gettimeout_getter(self: ptr[PyObject], closure: ptr) -> ptr[PyObject] {
    return timeout_object(sock_timeout(sock_of(self)));
}

impl sock_setsockopt(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    level = i32(0);
    optname = i32(0);
    scratch = ptr[u8](PyMem_Calloc(1, u64(8)));
    if not scratch {
        return PyErr_NoMemory();
    }
    res = i32(0);
    if HAS_VSOCK and sock_family(s) == AF_VSOCK {
        vflag = u64(0);
        if PyArg_ParseTuple(
            args, ptr[u8]("iiK:setsockopt"), &mut level, &mut optname, &mut vflag
        )
            == 0 {
            PyMem_Free(ptr(scratch));
            return NULL;
        }
        ptr[u64](scratch).view(1)[0] = vflag;
        res = setsockopt(get_sock_fd(s), level, optname, ptr(scratch), u32(8));
        return setsockopt_done(scratch, res);
    }
    flag = i32(0);
    if PyArg_ParseTuple(
        args, ptr[u8]("iii:setsockopt"), &mut level, &mut optname, &mut flag
    )
        != 0 {
        ptr[i32](scratch).view(1)[0] = flag;
        res = setsockopt(get_sock_fd(s), level, optname, ptr(scratch), u32(4));
        return setsockopt_done(scratch, res);
    }
    PyErr_Clear();
    none = NULL;
    optlen = u32(0);
    if PyArg_ParseTuple(
        args,
        ptr[u8]("iiO!I:setsockopt"),
        &mut level,
        &mut optname,
        ptr(object_type(Py_None)),
        &mut none,
        &mut optlen
    )
        != 0 {
        res = setsockopt(get_sock_fd(s), level, optname, ptr(), optlen);
        return setsockopt_done(scratch, res);
    }
    PyErr_Clear();
    optval = new_view();
    if not optval {
        PyMem_Free(ptr(scratch));
        return NULL;
    }
    if PyArg_ParseTuple(
        args, ptr[u8]("iiy*:setsockopt"), &mut level, &mut optname, optval
    )
        == 0 {
        jacpy_buffer_release(optval);
        PyMem_Free(ptr(scratch));
        return NULL;
    }
    view = optval.view(1);
    res = setsockopt(get_sock_fd(s), level, optname, view[0].buf, u32(view[0].length));
    error = jacpy_errno();
    jacpy_buffer_release(optval);
    jacpy_set_errno(error);
    return setsockopt_done(scratch, res);
}

impl setsockopt_done(scratch: ptr[u8], res: i32) -> ptr[PyObject] {
    error = jacpy_errno();
    PyMem_Free(ptr(scratch));
    if res < 0 {
        return socket_error(int(error));
    }
    return Py_NewRef(Py_None);
}

impl sock_getsockopt(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    level = i32(0);
    optname = i32(0);
    buflen = i32(0);
    if PyArg_ParseTuple(
        args, ptr[u8]("ii|i:getsockopt"), &mut level, &mut optname, &mut buflen
    )
        == 0 {
        return NULL;
    }
    scratch = ptr[u8](PyMem_Calloc(1, u64(16)));
    if not scratch {
        return PyErr_NoMemory();
    }
    size = ptr[u32](scratch + 8);
    if buflen == 0 {
        if HAS_VSOCK and sock_family(s) == AF_VSOCK {
            size.view(1)[0] = u32(8);
            res = getsockopt(get_sock_fd(s), level, optname, ptr(scratch), size);
            error = jacpy_errno();
            vflag = ptr[u64](scratch).view(1)[0];
            PyMem_Free(ptr(scratch));
            if res < 0 {
                return socket_error(int(error));
            }
            return PyLong_FromUnsignedLong(vflag);
        }
        size.view(1)[0] = u32(4);
        res = getsockopt(get_sock_fd(s), level, optname, ptr(scratch), size);
        error = jacpy_errno();
        flag = ptr[i32](scratch).view(1)[0];
        PyMem_Free(ptr(scratch));
        if res < 0 {
            return socket_error(int(error));
        }
        return PyLong_FromLong(i64(flag));
    }
    if HAS_VSOCK and sock_family(s) == AF_VSOCK {
        PyMem_Free(ptr(scratch));
        PyErr_SetString(PyExc_OSError, ptr[u8]("getsockopt string buffer not allowed"));
        return NULL;
    }
    if buflen <= 0 or buflen > 1024 {
        PyMem_Free(ptr(scratch));
        PyErr_SetString(PyExc_OSError, ptr[u8]("getsockopt buflen out of range"));
        return NULL;
    }
    buf = jacpy_bytes_from_memory(ptr(), i64(buflen));
    if not buf {
        PyMem_Free(ptr(scratch));
        return NULL;
    }
    size.view(1)[0] = u32(buflen);
    res = getsockopt(get_sock_fd(s), level, optname, jacpy_bytes_address(buf), size);
    error = jacpy_errno();
    length = int(size.view(1)[0]);
    PyMem_Free(ptr(scratch));
    if res < 0 {
        jacpy_release(buf);
        return socket_error(int(error));
    }
    _PyBytes_Resize(&mut buf, i64(length));
    return buf;
}

impl sock_bind(self: ptr[PyObject], addro: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    addrbuf = new_addrbuf();
    if not addrbuf {
        return NULL;
    }
    addrlen = getsockaddrarg(s, addro, addrbuf, "bind");
    if addrlen < 0 {
        free_addrbuf(addrbuf);
        return NULL;
    }
    if PySys_Audit("socket.bind", "OO", self, addro) < 0 {
        free_addrbuf(addrbuf);
        return NULL;
    }
    thread = PyEval_SaveThread();
    res = bind(get_sock_fd(s), ptr(addrbuf), u32(addrlen));
    error = jacpy_errno();
    PyEval_RestoreThread(thread);
    free_addrbuf(addrbuf);
    if res < 0 {
        return socket_error(int(error));
    }
    return Py_NewRef(Py_None);
}

impl sock_close(self: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    fd = get_sock_fd(s);
    if fd != INVALID_SOCKET {
        set_sock_fd(s, INVALID_SOCKET);
        thread = PyEval_SaveThread();
        res = close(fd);
        error = jacpy_errno();
        PyEval_RestoreThread(thread);
        if res < 0 and error != ECONNRESET {
            return socket_error(int(error));
        }
    }
    return Py_NewRef(Py_None);
}

impl sock_detach(self: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    fd = get_sock_fd(s);
    set_sock_fd(s, INVALID_SOCKET);
    return PyLong_FromLong(i64(fd));
}

impl internal_connect(
    s: ptr[PySocketSockObject], addr: ptr[u8], addrlen: int, raise_: bool
) -> int {
    thread = PyEval_SaveThread();
    res = connect(get_sock_fd(s), ptr(addr), u32(addrlen));
    err = int(jacpy_errno());
    PyEval_RestoreThread(thread);
    if res == 0 {
        return 0;
    }
    wait_connect = False;
    if err == EINTR {
        if PyErr_CheckSignals() != 0 {
            return -1;
        }

        wait_connect = sock_timeout(s) != 0;
    } else {
        wait_connect = sock_timeout(s) > 0 and err == EINPROGRESS;
    }
    if not wait_connect {
        if raise_ {
            socket_error(err);
            return -1;
        }
        return err;
    }
    scratch = ptr[u8](PyMem_Calloc(1, u64(8)));
    if not scratch {
        PyErr_NoMemory();
        return -1;
    }
    call = ConnectCall(scratch=scratch);
    status = sock_call_ex(s, True, call, True, not raise_, sock_timeout(s));
    PyMem_Free(ptr(scratch));
    if status < 0 {
        return -1 if raise_ else call.error;
    }
    return 0;
}

impl sock_connect(self: ptr[PyObject], addro: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    addrbuf = new_addrbuf();
    if not addrbuf {
        return NULL;
    }
    addrlen = getsockaddrarg(s, addro, addrbuf, "connect");
    if addrlen < 0 {
        free_addrbuf(addrbuf);
        return NULL;
    }
    if PySys_Audit("socket.connect", "OO", self, addro) < 0 {
        free_addrbuf(addrbuf);
        return NULL;
    }
    res = internal_connect(s, addrbuf, addrlen, True);
    free_addrbuf(addrbuf);
    if res < 0 {
        return NULL;
    }
    return Py_NewRef(Py_None);
}

impl sock_connect_ex(self: ptr[PyObject], addro: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    addrbuf = new_addrbuf();
    if not addrbuf {
        return NULL;
    }
    addrlen = getsockaddrarg(s, addro, addrbuf, "connect_ex");
    if addrlen < 0 {
        free_addrbuf(addrbuf);
        return NULL;
    }
    if PySys_Audit("socket.connect", "OO", self, addro) < 0 {
        free_addrbuf(addrbuf);
        return NULL;
    }
    res = internal_connect(s, addrbuf, addrlen, False);
    free_addrbuf(addrbuf);
    if res == -1 and PyErr_Occurred() {
        return NULL;
    }
    return PyLong_FromLong(i64(res));
}

impl sock_fileno(self: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return PyLong_FromLong(i64(get_sock_fd(sock_of(self))));
}

impl socket_name(self: ptr[PyObject], peer: bool) -> ptr[PyObject] {
    s = sock_of(self);
    addrlen = getsockaddrlen(s);
    if addrlen < 0 {
        return NULL;
    }
    space = new_address_space();
    if not space {
        return NULL;
    }
    length = length_cell(space);
    length.view(1)[0] = u32(addrlen);
    thread = PyEval_SaveThread();
    res = getpeername(get_sock_fd(s), ptr(space), length)
        if peer
        else getsockname(get_sock_fd(s), ptr(space), length);
    error = jacpy_errno();
    PyEval_RestoreThread(thread);
    if res < 0 {
        free_addrbuf(space);
        return socket_error(int(error));
    }
    result = makesockaddr(get_sock_fd(s), space, int(length.view(1)[0]), sock_proto(s));
    free_addrbuf(space);
    return result;
}

impl sock_getsockname(self: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return socket_name(self, False);
}

impl sock_getpeername(self: ptr[PyObject], ignored: ptr[PyObject]) -> ptr[PyObject] {
    return socket_name(self, True);
}

impl sock_listen(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    backlog = i32(SOMAXCONN if SOMAXCONN < 128 else 128);
    if PyArg_ParseTuple(args, ptr[u8]("|i:listen"), &mut backlog) == 0 {
        return NULL;
    }
    if backlog < 0 {
        backlog = i32(0);
    }
    thread = PyEval_SaveThread();
    res = listen(get_sock_fd(s), backlog);
    error = jacpy_errno();
    PyEval_RestoreThread(thread);
    if res < 0 {
        return socket_error(int(error));
    }
    return Py_NewRef(Py_None);
}

impl sock_recv_guts(
    s: ptr[PySocketSockObject], cbuf: ptr, length: int, flags: int
) -> int {
    if length == 0 {
        return 0;
    }
    call = RecvCall(buffer=cbuf, length=length, flags=flags);
    if sock_call(s, False, call) < 0 {
        return -1;
    }
    return call.result;
}

impl sock_recv(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    recvlen = i64(0);
    flags = i32(0);
    if PyArg_ParseTuple(args, ptr[u8]("n|i:recv"), &mut recvlen, &mut flags) == 0 {
        return NULL;
    }
    if recvlen < 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("negative buffersize in recv"));
        return NULL;
    }
    buf = jacpy_bytes_from_memory(ptr(), recvlen);
    if not buf {
        return NULL;
    }
    outlen = sock_recv_guts(s, jacpy_bytes_address(buf), int(recvlen), int(flags));
    if outlen < 0 {
        jacpy_release(buf);
        return NULL;
    }
    if outlen != recvlen {
        _PyBytes_Resize(&mut buf, i64(outlen));
    }
    return buf;
}

impl sock_recv_into(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    s = sock_of(self);
    flags = i32(0);
    recvlen = i64(0);
    pbuf = new_view();
    if not pbuf {
        return NULL;
    }
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("w*|ni:recv_into"),
        ptr(addressof(recv_into_keywords)),
        pbuf,
        &mut recvlen,
        &mut flags
    )
        == 0 {
        PyMem_Free(ptr(pbuf));
        return NULL;
    }
    buflen = pbuf.view(1)[0].length;
    if recvlen < 0 {
        jacpy_buffer_release(pbuf);
        PyErr_SetString(PyExc_ValueError, ptr[u8]("negative buffersize in recv_into"));
        return NULL;
    }
    if recvlen == 0 {
        recvlen = buflen;
    }
    if buflen < recvlen {
        jacpy_buffer_release(pbuf);
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("buffer too small for requested bytes")
        );
        return NULL;
    }
    readlen = sock_recv_guts(s, pbuf.view(1)[0].buf, int(recvlen), int(flags));
    jacpy_buffer_release(pbuf);
    if readlen < 0 {
        return NULL;
    }
    return PyLong_FromSsize_t(i64(readlen));
}

impl sock_recvfrom_guts(
    s: ptr[PySocketSockObject], cbuf: ptr, length: int, flags: int
) -> RecvFromOutcome {
    outcome = RecvFromOutcome();
    addrlen = getsockaddrlen(s);
    if addrlen < 0 {
        return outcome;
    }
    space = new_address_space();
    if not space {
        return outcome;
    }
    length_cell(space).view(1)[0] = u32(addrlen);
    call = RecvFromCall(buffer=cbuf, length=length, flags=flags, address=space);
    if sock_call(s, False, call) < 0 {
        free_addrbuf(space);
        return outcome;
    }
    outcome.address = makesockaddr(
        get_sock_fd(s), space, int(length_cell(space).view(1)[0]), sock_proto(s)
    );
    free_addrbuf(space);
    if outcome.address {
        outcome.count = call.result;
    }
    return outcome;
}

impl sock_recvfrom(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    recvlen = i64(0);
    flags = i32(0);
    if PyArg_ParseTuple(args, ptr[u8]("n|i:recvfrom"), &mut recvlen, &mut flags) == 0 {
        return NULL;
    }
    if recvlen < 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("negative buffersize in recvfrom"));
        return NULL;
    }
    buf = jacpy_bytes_from_memory(ptr(), recvlen);
    if not buf {
        return NULL;
    }
    outcome = sock_recvfrom_guts(s, jacpy_bytes_address(buf), int(recvlen), int(flags));
    ret = NULL;
    if outcome.count >= 0
        and (
            outcome.count == recvlen
            or _PyBytes_Resize(&mut buf, i64(outcome.count)) >= 0
        ) {
        ret = PyTuple_Pack(2, buf, outcome.address);
    }
    jacpy_release(buf);
    jacpy_release(outcome.address);
    return ret;
}

impl sock_recvfrom_into(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    s = sock_of(self);
    flags = i32(0);
    recvlen = i64(0);
    pbuf = new_view();
    if not pbuf {
        return NULL;
    }
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("w*|ni:recvfrom_into"),
        ptr(addressof(recv_into_keywords)),
        pbuf,
        &mut recvlen,
        &mut flags
    )
        == 0 {
        PyMem_Free(ptr(pbuf));
        return NULL;
    }
    buflen = pbuf.view(1)[0].length;
    if recvlen < 0 {
        jacpy_buffer_release(pbuf);
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("negative buffersize in recvfrom_into")
        );
        return NULL;
    }
    if recvlen == 0 {
        recvlen = buflen;
    } elif recvlen > buflen {
        jacpy_buffer_release(pbuf);
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("nbytes is greater than the length of the buffer")
        );
        return NULL;
    }
    outcome = sock_recvfrom_guts(s, pbuf.view(1)[0].buf, int(recvlen), int(flags));
    jacpy_buffer_release(pbuf);
    if outcome.count < 0 {
        jacpy_release(outcome.address);
        return NULL;
    }
    return Py_BuildValue(ptr[u8]("nN"), i64(outcome.count), outcome.address);
}

impl ReceivedData.value(received: int) -> ptr[PyObject] {
    if self.into {
        return PyLong_FromSsize_t(i64(received));
    }
    if received < int(jacpy_bytes_length(self.buffer)) {
        buffer = self.buffer;
        _PyBytes_Resize(&mut buffer, i64(received));
        self.buffer = buffer;
    }
    if not self.buffer {
        return NULL;
    }
    return Py_NewRef(self.buffer);
}

impl close_received_fds(message: ptr[msghdr]) {
    header = cmsg_firsthdr(message) if msg_controllen(message) > 0 else ptr[cmsghdr]();
    while header {
        data = get_cmsg_data_len(message, header);
        if data.status < 0 {
            break;
        }
        record = header.view(1);
        if record[0].cmsg_level == SOL_SOCKET and record[0].cmsg_type == SCM_RIGHTS {
            numfds = data.length // 4;
            fds = ptr[i32](cmsg_data(header));
            for i in range(numfds) {
                close((fds + i).view(1)[0]);
            }
        }
        if data.status != 0 {
            break;
        }
        header = cmsg_nxthdr(message, header);
    }
}

impl sock_recvmsg_guts(
    s: ptr[PySocketSockObject],
    iov: ptr,
    iovlen: int,
    flags: int,
    controllen: int,
    received: ReceivedData
) -> ptr[PyObject] {
    addrbuflen = getsockaddrlen(s);
    if addrbuflen < 0 {
        return NULL;
    }
    if controllen < 0 or controllen > SOCKLEN_T_LIMIT {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("invalid ancillary data buffer length")
        );
        return NULL;
    }
    addrbuf = new_addrbuf();
    if not addrbuf {
        return NULL;
    }
    store_sa_family(addrbuf, AF_UNSPEC);
    controlbuf = ptr();
    if controllen > 0 {
        controlbuf = PyMem_Malloc(u64(controllen));
        if not controlbuf {
            free_addrbuf(addrbuf);
            return PyErr_NoMemory();
        }
    }
    message = ptr[msghdr](PyMem_Calloc(1, u64(MSGHDR_SIZE)));
    if not message {
        PyMem_Free(controlbuf);
        free_addrbuf(addrbuf);
        return PyErr_NoMemory();
    }
    set_msg_name(message, ptr(addrbuf), addrbuflen);
    set_msg_iov(message, iov, iovlen);
    set_msg_control(message, controlbuf, controllen);
    retval = NULL;
    call = MessageCall(message=message, flags=flags, sending=False);
    if sock_call(s, False, call) >= 0 {
        retval = received_message(
            s, message, addrbuf, addrbuflen, call.result, received
        );
        if not retval {
            close_received_fds(message);
        }
    }
    PyMem_Free(ptr(message));
    PyMem_Free(controlbuf);
    free_addrbuf(addrbuf);
    return retval;
}

impl received_message(
    s: ptr[PySocketSockObject],
    message: ptr[msghdr],
    addrbuf: ptr[u8],
    addrbuflen: int,
    count: int,
    received: ReceivedData
) -> ptr[PyObject] {
    cmsg_list = PyList_New(0);
    if not cmsg_list {
        return NULL;
    }

    header = cmsg_firsthdr(message) if msg_controllen(message) > 0 else ptr[cmsghdr]();
    while header {
        data = get_cmsg_data_len(message, header);
        if data.status != 0
            and PyErr_WarnEx(
                PyExc_RuntimeWarning,
                ptr[u8]("received malformed or improperly-truncated ancillary data"),
                1
            )
                == -1 {
            jacpy_release(cmsg_list);
            return NULL;
        }
        if data.status < 0 {
            break;
        }
        if data.length > SSIZE_MAX {
            PyErr_SetString(PyExc_OSError, ptr[u8]("control message too long"));
            jacpy_release(cmsg_list);
            return NULL;
        }
        record = header.view(1);
        payload = jacpy_bytes_from_memory(ptr(cmsg_data(header)), i64(data.length));
        item = Py_BuildValue(
            ptr[u8]("iiN"), record[0].cmsg_level, record[0].cmsg_type, payload
        );
        if not item {
            jacpy_release(cmsg_list);
            return NULL;
        }
        status = PyList_Append(cmsg_list, item);
        jacpy_release(item);
        if status != 0 {
            jacpy_release(cmsg_list);
            return NULL;
        }
        if data.status != 0 {
            break;
        }
        header = cmsg_nxthdr(message, header);
    }
    value = received.value(count);
    namelen = int(message.view(1)[0].msg_namelen);
    address = makesockaddr(
        get_sock_fd(s),
        addrbuf,
        addrbuflen if namelen > addrbuflen else namelen,
        sock_proto(s)
    );
    retval = NULL;
    if value and address {
        retval = Py_BuildValue(
            ptr[u8]("NOiN"), value, cmsg_list, message.view(1)[0].msg_flags, address
        );
    } else {
        jacpy_release(value);
        jacpy_release(address);
    }
    jacpy_release(cmsg_list);
    return retval;
}

impl sock_recvmsg(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    bufsize = i64(0);
    ancbufsize = i64(0);
    flags = i32(0);
    if PyArg_ParseTuple(
        args, ptr[u8]("n|ni:recvmsg"), &mut bufsize, &mut ancbufsize, &mut flags
    )
        == 0 {
        return NULL;
    }
    if bufsize < 0 {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("negative buffer size in recvmsg()"));
        return NULL;
    }
    buf = jacpy_bytes_from_memory(ptr(), bufsize);
    if not buf {
        return NULL;
    }
    iov = ptr[u8](PyMem_Calloc(1, u64(IOVEC_SIZE)));
    if not iov {
        jacpy_release(buf);
        return PyErr_NoMemory();
    }
    ptr[ptr](iov).view(1)[0] = jacpy_bytes_address(buf);
    ptr[u64](iov + 8).view(1)[0] = u64(bufsize);

    received = ReceivedData(into=False, buffer=buf);
    retval = sock_recvmsg_guts(s, ptr(iov), 1, int(flags), int(ancbufsize), received);
    jacpy_release(received.buffer);
    PyMem_Free(ptr(iov));
    return retval;
}

impl release_views(views: ptr[u8], count: int) {
    if not views {
        return;
    }
    for i in range(count) {
        view = ptr[Py_buffer](views + i * int(PY_BUFFER_SIZE));

        PyBuffer_Release(view);
    }
    PyMem_Free(ptr(views));
}

impl sock_recvmsg_into(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    ancbufsize = i64(0);
    flags = i32(0);
    buffers_arg = NULL;
    if PyArg_ParseTuple(
        args,
        ptr[u8]("O|ni:recvmsg_into"),
        &mut buffers_arg,
        &mut ancbufsize,
        &mut flags
    )
        == 0 {
        return NULL;
    }
    fast = PySequence_Fast(
        buffers_arg, ptr[u8]("recvmsg_into() argument 1 must be an iterable")
    );
    if not fast {
        return NULL;
    }
    nitems = int(jacpy_fast_size(fast));
    retval = NULL;
    iovs = ptr[u8]();
    bufs = ptr[u8]();
    nbufs = 0;
    ok = True;
    if nitems > INT_MAX {
        PyErr_SetString(
            PyExc_OSError, ptr[u8]("recvmsg_into() argument 1 is too long")
        );
        ok = False;
    }

    if ok and nitems > 0 {
        iovs = ptr[u8](PyMem_Calloc(u64(nitems), u64(IOVEC_SIZE)));
        bufs = ptr[u8](PyMem_Calloc(u64(nitems), PY_BUFFER_SIZE));
        if not iovs or not bufs {
            PyErr_NoMemory();
            ok = False;
        }
    }
    while ok and nbufs < nitems {
        view = ptr[Py_buffer](bufs + nbufs * int(PY_BUFFER_SIZE));
        if PyArg_Parse(
            jacpy_fast_item(fast, i64(nbufs)),
            ptr[u8](
                "w*;recvmsg_into() argument 1 must be an iterable of single-segment read-write buffers"
            ),
            view
        )
            == 0 {
            ok = False;
            break;
        }
        ptr[ptr](iovs + nbufs * IOVEC_SIZE).view(1)[0] = view.view(1)[0].buf;
        ptr[u64](iovs + nbufs * IOVEC_SIZE + 8).view(1)[0] = u64(
            view.view(1)[0].length
        );
        nbufs += 1;
    }
    if ok {
        retval = sock_recvmsg_guts(
            s, ptr(iovs), nitems, int(flags), int(ancbufsize), ReceivedData(into=True)
        );
    }
    release_views(bufs, nbufs);
    PyMem_Free(ptr(iovs));
    jacpy_release(fast);
    return retval;
}

impl sock_send(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    flags = i32(0);
    pbuf = new_view();
    if not pbuf {
        return NULL;
    }
    if PyArg_ParseTuple(args, ptr[u8]("y*|i:send"), pbuf, &mut flags) == 0 {
        PyMem_Free(ptr(pbuf));
        return NULL;
    }
    view = pbuf.view(1);
    call = SendCall(buffer=view[0].buf, length=int(view[0].length), flags=int(flags));
    status = sock_call(s, True, call);
    jacpy_buffer_release(pbuf);
    if status < 0 {
        return NULL;
    }
    return PyLong_FromSsize_t(i64(call.result));
}

impl sock_sendall(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    flags = i32(0);
    pbuf = new_view();
    if not pbuf {
        return NULL;
    }
    if PyArg_ParseTuple(args, ptr[u8]("y*|i:sendall"), pbuf, &mut flags) == 0 {
        PyMem_Free(ptr(pbuf));
        return NULL;
    }
    has_timeout = sock_timeout(s) > 0;
    timeout = sock_timeout(s);
    deadline = 0;
    deadline_initialized = False;
    buf = ptr[u8](pbuf.view(1)[0].buf);
    length = int(pbuf.view(1)[0].length);
    res = NULL;
    while True {
        if has_timeout {
            if deadline_initialized {
                timeout = int(_PyDeadline_Get(i64(deadline)));
            } else {
                deadline_initialized = True;
                deadline = int(_PyDeadline_Init(i64(timeout)));
            }
            if timeout <= 0 {
                PyErr_SetString(PyExc_TimeoutError, ptr[u8]("timed out"));
                break;
            }
        }
        call = SendCall(buffer=ptr(buf), length=length, flags=int(flags));
        if sock_call_ex(s, True, call, False, False, timeout) < 0 {
            break;
        }
        n = call.result;
        buf = buf + n;
        length -= n;

        if PyErr_CheckSignals() != 0 {
            break;
        }
        if length <= 0 {
            res = Py_NewRef(Py_None);
            break;
        }
    }
    jacpy_buffer_release(pbuf);
    return res;
}

impl sock_sendto(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    flags = i32(0);
    addro = NULL;
    arglen = int(PyTuple_Size(args));
    pbuf = new_view();
    if not pbuf {
        return NULL;
    }
    parsed = 0;
    if arglen == 2 {
        parsed = PyArg_ParseTuple(args, ptr[u8]("y*O:sendto"), pbuf, &mut addro);
    } elif arglen == 3 {
        parsed = PyArg_ParseTuple(
            args, ptr[u8]("y*iO:sendto"), pbuf, &mut flags, &mut addro
        );
    } else {
        PyMem_Free(ptr(pbuf));
        object_error(
            PyExc_TypeError, f"sendto() takes 2 or 3 arguments ({arglen} given)"
        );
        return NULL;
    }
    if parsed == 0 {
        PyMem_Free(ptr(pbuf));
        return NULL;
    }
    addrbuf = new_addrbuf();
    if not addrbuf {
        jacpy_buffer_release(pbuf);
        return NULL;
    }
    addrlen = getsockaddrarg(s, addro, addrbuf, "sendto");
    if addrlen < 0 or PySys_Audit("socket.sendto", "OO", self, addro) < 0 {
        free_addrbuf(addrbuf);
        jacpy_buffer_release(pbuf);
        return NULL;
    }
    view = pbuf.view(1);
    call = SendToCall(
        buffer=view[0].buf,
        length=int(view[0].length),
        flags=int(flags),
        address=addrbuf,
        address_length=addrlen
    );
    status = sock_call(s, True, call);
    free_addrbuf(addrbuf);
    jacpy_buffer_release(pbuf);
    if status < 0 {
        return NULL;
    }
    return PyLong_FromSsize_t(i64(call.result));
}

impl DataBuffers.close {
    release_views(self.views, self.count);
    self.views = ptr[u8]();
    self.count = 0;
    PyMem_Free(ptr(self.iovs));
    self.iovs = ptr[u8]();
}

impl sock_sendmsg_iovec(
    data_arg: ptr[PyObject], message: ptr[msghdr], buffers: DataBuffers
) -> bool {
    data_fast = PySequence_Fast(
        data_arg, ptr[u8]("sendmsg() argument 1 must be an iterable")
    );
    if not data_fast {
        return False;
    }
    ndataparts = int(jacpy_fast_size(data_fast));
    result = True;
    if ndataparts > INT_MAX {
        PyErr_SetString(PyExc_OSError, ptr[u8]("sendmsg() argument 1 is too long"));
        result = False;
    }
    if result and ndataparts > 0 {
        buffers.iovs = ptr[u8](PyMem_Calloc(u64(ndataparts), u64(IOVEC_SIZE)));
        if not buffers.iovs {
            PyErr_NoMemory();
            result = False;
        } else {
            buffers.views = ptr[u8](PyMem_Calloc(u64(ndataparts), PY_BUFFER_SIZE));
            if not buffers.views {
                PyErr_NoMemory();
                result = False;
            }
        }
    }
    if result {
        set_msg_iov(message, ptr(buffers.iovs), ndataparts);
    }
    while result and buffers.count < ndataparts {
        index = buffers.count;
        view = ptr[Py_buffer](buffers.views + index * int(PY_BUFFER_SIZE));
        if PyArg_Parse(
            jacpy_fast_item(data_fast, i64(index)),
            ptr[u8](
                "y*;sendmsg() argument 1 must be an iterable of bytes-like objects"
            ),
            view
        )
            == 0 {
            result = False;
            break;
        }
        ptr[ptr](buffers.iovs + index * IOVEC_SIZE).view(1)[0] = view.view(1)[0].buf;
        ptr[u64](buffers.iovs + index * IOVEC_SIZE + 8).view(1)[0] = u64(
            view.view(1)[0].length
        );
        buffers.count += 1;
    }
    jacpy_release(data_fast);
    return result;
}

impl sock_sendmsg(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    data_arg = NULL;
    cmsg_arg = NULL;
    addr_arg = NULL;
    flags = i32(0);
    if PyArg_ParseTuple(
        args,
        ptr[u8]("O|OiO:sendmsg"),
        &mut data_arg,
        &mut cmsg_arg,
        &mut flags,
        &mut addr_arg
    )
        == 0 {
        return NULL;
    }
    message = ptr[msghdr](PyMem_Calloc(1, u64(MSGHDR_SIZE)));
    if not message {
        return PyErr_NoMemory();
    }
    addrbuf = new_addrbuf();
    if not addrbuf {
        PyMem_Free(ptr(message));
        return NULL;
    }
    buffers = DataBuffers();
    cmsg_fast = NULL;
    cmsgs = ptr[u8]();
    ncmsgbufs = 0;
    controlbuf = ptr();
    retval = NULL;

    if addr_arg and addr_arg != Py_None {
        addrlen = getsockaddrarg(s, addr_arg, addrbuf, "sendmsg");
        if addrlen < 0 {
            return sendmsg_finally(
                message, addrbuf, buffers, cmsg_fast, cmsgs, 0, controlbuf, NULL
            );
        }
        if PySys_Audit("socket.sendmsg", "OO", self, addr_arg) < 0 {
            return sendmsg_finally(
                message, addrbuf, buffers, cmsg_fast, cmsgs, 0, controlbuf, NULL
            );
        }
        set_msg_name(message, ptr(addrbuf), addrlen);
    } elif PySys_Audit("socket.sendmsg", "OO", self, Py_None) < 0 {
        return sendmsg_finally(
            message, addrbuf, buffers, cmsg_fast, cmsgs, 0, controlbuf, NULL
        );
    }

    if not sock_sendmsg_iovec(data_arg, message, buffers) {
        return sendmsg_finally(
            message, addrbuf, buffers, cmsg_fast, cmsgs, 0, controlbuf, NULL
        );
    }
    ncmsgs = 0;
    if cmsg_arg {
        cmsg_fast = PySequence_Tuple(cmsg_arg);
        if not cmsg_fast {
            PyErr_SetString(
                PyExc_TypeError, ptr[u8]("sendmsg() argument 2 must be an iterable")
            );
            return sendmsg_finally(
                message, addrbuf, buffers, cmsg_fast, cmsgs, 0, controlbuf, NULL
            );
        }
        ncmsgs = int(PyTuple_Size(cmsg_fast));
    }

    if ncmsgs > 0 {
        cmsgs = ptr[u8](PyMem_Calloc(u64(ncmsgs), u64(CMSGINFO_SIZE)));
        if not cmsgs {
            PyErr_NoMemory();
            return sendmsg_finally(
                message, addrbuf, buffers, cmsg_fast, cmsgs, 0, controlbuf, NULL
            );
        }
    }
    controllen = 0;
    controllen_last = 0;
    while ncmsgbufs < ncmsgs {
        info = cmsgs + ncmsgbufs * CMSGINFO_SIZE;
        if PyArg_Parse(
            PyTuple_GetItem(cmsg_fast, i64(ncmsgbufs)),
            ptr[u8]("(iiy*):[sendmsg() ancillary data items]"),
            ptr[i32](info),
            ptr[i32](info + 4),
            ptr[Py_buffer](info + 8)
        )
            == 0 {
            return sendmsg_finally(
                message, addrbuf, buffers, cmsg_fast, cmsgs, ncmsgbufs, controlbuf, NULL
            );
        }
        ncmsgbufs += 1;
        bufsize = int(ptr[Py_buffer](info + 8).view(1)[0].length);
        space = get_CMSG_SPACE(bufsize);
        if space < 0 {
            PyErr_SetString(PyExc_OSError, ptr[u8]("ancillary data item too large"));
            return sendmsg_finally(
                message, addrbuf, buffers, cmsg_fast, cmsgs, ncmsgbufs, controlbuf, NULL
            );
        }
        controllen += space;
        if controllen > SOCKLEN_T_LIMIT or controllen < controllen_last {
            PyErr_SetString(PyExc_OSError, ptr[u8]("too much ancillary data"));
            return sendmsg_finally(
                message, addrbuf, buffers, cmsg_fast, cmsgs, ncmsgbufs, controlbuf, NULL
            );
        }
        controllen_last = controllen;
    }

    if ncmsgbufs > 0 {
        controlbuf = PyMem_Malloc(u64(controllen));
        if not controlbuf {
            PyErr_NoMemory();
            return sendmsg_finally(
                message, addrbuf, buffers, cmsg_fast, cmsgs, ncmsgbufs, controlbuf, NULL
            );
        }
        set_msg_control(message, controlbuf, controllen);

        jacpy_memory_zero(controlbuf, i64(controllen));
        header = ptr[cmsghdr]();
        for i in range(ncmsgbufs) {
            info = cmsgs + i * CMSGINFO_SIZE;
            data = ptr[Py_buffer](info + 8).view(1);
            data_len = int(data[0].length);
            header = cmsg_firsthdr(message) if i == 0 else cmsg_nxthdr(message, header);
            if not header {
                macro = "CMSG_FIRSTHDR" if i == 0 else "CMSG_NXTHDR";
                object_error(
                    PyExc_RuntimeError, f"unexpected NULL result from {macro}()"
                );
                return sendmsg_finally(
                    message,
                    addrbuf,
                    buffers,
                    cmsg_fast,
                    cmsgs,
                    ncmsgbufs,
                    controlbuf,
                    NULL
                );
            }
            msg_len = get_CMSG_LEN(data_len);
            if msg_len < 0 {
                PyErr_SetString(
                    PyExc_RuntimeError, ptr[u8]("item size out of range for CMSG_LEN()")
                );
                return sendmsg_finally(
                    message,
                    addrbuf,
                    buffers,
                    cmsg_fast,
                    cmsgs,
                    ncmsgbufs,
                    controlbuf,
                    NULL
                );
            }
            enough_space = False;
            if cmsg_min_space(message, header, msg_len) {
                set_cmsg_length(header, msg_len);
                space = get_cmsg_data_space(message, header);
                if space >= 0 {
                    enough_space = space >= data_len;
                }
            }
            if not enough_space {
                PyErr_SetString(
                    PyExc_RuntimeError,
                    ptr[u8]("ancillary data does not fit in calculated space")
                );
                return sendmsg_finally(
                    message,
                    addrbuf,
                    buffers,
                    cmsg_fast,
                    cmsgs,
                    ncmsgbufs,
                    controlbuf,
                    NULL
                );
            }
            header.view(1)[0].cmsg_level = ptr[i32](info).view(1)[0];
            header.view(1)[0].cmsg_type = ptr[i32](info + 4).view(1)[0];
            jacpy_memory_copy(ptr(cmsg_data(header)), data[0].buf, i64(data_len));
        }
    }

    call = MessageCall(message=message, flags=int(flags), sending=True);
    if sock_call(s, True, call) >= 0 {
        retval = PyLong_FromSsize_t(i64(call.result));
    }
    return sendmsg_finally(
        message, addrbuf, buffers, cmsg_fast, cmsgs, ncmsgbufs, controlbuf, retval
    );
}

impl sendmsg_finally(
    message: ptr[msghdr],
    addrbuf: ptr[u8],
    buffers: DataBuffers,
    cmsg_fast: ptr[PyObject],
    cmsgs: ptr[u8],
    ncmsgbufs: int,
    controlbuf: ptr,
    retval: ptr[PyObject]
) -> ptr[PyObject] {
    PyMem_Free(controlbuf);
    for i in range(ncmsgbufs) {
        PyBuffer_Release(ptr[Py_buffer](cmsgs + i * CMSGINFO_SIZE + 8));
    }
    PyMem_Free(ptr(cmsgs));
    jacpy_release(cmsg_fast);
    buffers.close();
    free_addrbuf(addrbuf);
    PyMem_Free(ptr(message));
    return retval;
}

impl sock_sendmsg_afalg(
    self: ptr[PyObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    s = sock_of(self);
    if not HAS_ALG or sock_family(s) != AF_ALG {
        PyErr_SetString(PyExc_OSError, ptr[u8]("algset is only supported for AF_ALG"));
        return NULL;
    }
    data_arg = NULL;
    opobj = NULL;
    assoclenobj = NULL;
    flags = i32(0);
    iv = new_view();
    if not iv {
        return NULL;
    }
    if PyArg_ParseTupleAndKeywords(
        args,
        kwds,
        ptr[u8]("|O$O!y*O!i:sendmsg_afalg"),
        ptr(addressof(sendmsg_afalg_keywords)),
        &mut data_arg,
        ptr(addressof(PyLong_Type)),
        &mut opobj,
        iv,
        ptr(addressof(PyLong_Type)),
        &mut assoclenobj,
        &mut flags
    )
        == 0 {
        PyMem_Free(ptr(iv));
        return NULL;
    }
    message = ptr[msghdr](PyMem_Calloc(1, u64(MSGHDR_SIZE)));
    buffers = DataBuffers();
    controlbuf = ptr();
    retval = NULL;
    if not message {
        PyErr_NoMemory();
        return afalg_finally(message, buffers, controlbuf, iv, retval);
    }

    op = -1;
    if opobj {
        op = int(PyLong_AsInt(opobj));
    }
    if op < 0 {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("Invalid or missing argument 'op'"));
        return afalg_finally(message, buffers, controlbuf, iv, retval);
    }

    assoclen = -1;
    if assoclenobj {
        assoclen = int(PyLong_AsInt(assoclenobj));
        if assoclen == -1 and PyErr_Occurred() {
            return afalg_finally(message, buffers, controlbuf, iv, retval);
        }
        if assoclen < 0 {
            PyErr_SetString(PyExc_TypeError, ptr[u8]("assoclen must be positive"));
            return afalg_finally(message, buffers, controlbuf, iv, retval);
        }
    }
    iv_view = iv.view(1);
    controllen = cmsg_space_of(4);
    if iv_view[0].buf {
        controllen += cmsg_space_of(4 + int(iv_view[0].length));
    }
    if assoclen >= 0 {
        controllen += cmsg_space_of(4);
    }
    controlbuf = PyMem_Malloc(u64(controllen));
    if not controlbuf {
        PyErr_NoMemory();
        return afalg_finally(message, buffers, controlbuf, iv, retval);
    }
    jacpy_memory_zero(controlbuf, i64(controllen));
    set_msg_control(message, controlbuf, controllen);

    if data_arg and not sock_sendmsg_iovec(data_arg, message, buffers) {
        return afalg_finally(message, buffers, controlbuf, iv, retval);
    }

    header = cmsg_firsthdr(message);
    if not header {
        PyErr_SetString(
            PyExc_RuntimeError, ptr[u8]("unexpected NULL result from CMSG_FIRSTHDR")
        );
        return afalg_finally(message, buffers, controlbuf, iv, retval);
    }
    header.view(1)[0].cmsg_level = i32(SOL_ALG);
    header.view(1)[0].cmsg_type = i32(ALG_SET_OP);
    set_cmsg_length(header, cmsg_len_of(4));
    put_u32(cmsg_data(header), 0, op);

    if iv_view[0].buf {
        header = cmsg_nxthdr(message, header);
        if not header {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("unexpected NULL result from CMSG_NXTHDR(iv)")
            );
            return afalg_finally(message, buffers, controlbuf, iv, retval);
        }
        header.view(1)[0].cmsg_level = i32(SOL_ALG);
        header.view(1)[0].cmsg_type = i32(ALG_SET_IV);
        set_cmsg_length(header, cmsg_space_of(4 + int(iv_view[0].length)));
        alg_iv = cmsg_data(header);
        put_u32(alg_iv, 0, int(iv_view[0].length));
        jacpy_memory_copy(ptr(alg_iv + 4), iv_view[0].buf, iv_view[0].length);
    }

    if assoclen >= 0 {
        header = cmsg_nxthdr(message, header);
        if not header {
            PyErr_SetString(
                PyExc_RuntimeError,
                ptr[u8]("unexpected NULL result from CMSG_NXTHDR(assoc)")
            );
            return afalg_finally(message, buffers, controlbuf, iv, retval);
        }
        header.view(1)[0].cmsg_level = i32(SOL_ALG);
        header.view(1)[0].cmsg_type = i32(ALG_SET_AEAD_ASSOCLEN);
        set_cmsg_length(header, cmsg_len_of(4));
        put_u32(cmsg_data(header), 0, assoclen);
    }
    call = MessageCall(message=message, flags=int(flags), sending=True);
    if sock_call(s, True, call) >= 0 {
        retval = PyLong_FromSsize_t(i64(call.result));
    }
    return afalg_finally(message, buffers, controlbuf, iv, retval);
}

impl afalg_finally(
    message: ptr[msghdr],
    buffers: DataBuffers,
    controlbuf: ptr,
    iv: ptr[Py_buffer],
    retval: ptr[PyObject]
) -> ptr[PyObject] {
    PyMem_Free(controlbuf);
    jacpy_buffer_release(iv);
    buffers.close();
    PyMem_Free(ptr(message));
    return retval;
}

impl sock_shutdown(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    how = PyLong_AsInt(arg);
    if how == -1 and PyErr_Occurred() {
        return NULL;
    }
    thread = PyEval_SaveThread();
    res = shutdown(get_sock_fd(s), how);
    error = jacpy_errno();
    PyEval_RestoreThread(thread);
    if res < 0 {
        return socket_error(int(error));
    }
    return Py_NewRef(Py_None);
}

impl sock_finalize(self: ptr[PyObject]) {
    s = sock_of(self);

    exc = PyErr_GetRaisedException();
    if get_sock_fd(s) != INVALID_SOCKET {
        if PyErr_ResourceWarning(self, 1, ptr[u8]("unclosed %R"), self) != 0 {
            if PyErr_ExceptionMatches(PyExc_Warning) != 0 {
                PyErr_FormatUnraisable(
                    ptr[u8]("Exception ignored while finalizing socket %R"), self
                );
            }
        }
        fd = get_sock_fd(s);
        set_sock_fd(s, INVALID_SOCKET);

        thread = PyEval_SaveThread();
        close(fd);
        PyEval_RestoreThread(thread);
    }

    PyErr_SetRaisedException(exc);
}

impl sock_traverse(self: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    return visit_reference(ptr[PyObject](object_type(self)), visitor, arg);
}

impl sock_dealloc(self: ptr[PyObject]) {
    if PyObject_CallFinalizerFromDealloc(self) < 0 {
        return;
    }
    tp = object_type(self);
    PyObject_GC_UnTrack(ptr(self));
    tp.view(1)[0].tp_free(ptr(self));
    jacpy_release(ptr[PyObject](tp));
}

impl sock_repr(self: ptr[PyObject]) -> ptr[PyObject] {
    s = sock_of(self);
    record = s.view(1);
    return PyUnicode_FromFormat(
        "<socket object, fd=%ld, family=%d, type=%d, proto=%d>",
        i64(record[0].sock_fd),
        record[0].sock_family,
        record[0].sock_type,
        record[0].sock_proto
    );
}

impl sock_new(
    type: ptr[PyTypeObject], args: ptr[PyObject], kwds: ptr[PyObject]
) -> ptr[PyObject] {
    op = type.view(1)[0].tp_alloc(type, 0);
    if op {
        record = sock_of(op).view(1);
        record[0].sock_fd = INVALID_SOCKET;
        record[0].sock_timeout = i64(-SEC_TO_NS);
        record[0].errorhandler = set_error;
    }
    return op;
}

impl sock_init(
    self: ptr[PyObject], family: i32, type: i32, proto: i32, fdobj: ptr[PyObject]
) -> i32 {
    s = sock_of(self);
    module = module_of_type(object_type(self));
    if not module {
        return i32(-1);
    }
    if PySys_Audit("socket.__new__", "Oiii", self, family, type, proto) < 0 {
        return i32(-1);
    }
    fd = INVALID_SOCKET;
    fam = int(family);
    typ = int(type);
    pro = int(proto);
    if fdobj and fdobj != Py_None {
        value = PyLong_AsLong(fdobj);
        if value == -1 and PyErr_Occurred() {
            return i32(-1);
        }

        fd = c_int(int(value));
        if fd < 0 {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("negative file descriptor"));
            return i32(-1);
        }

        space = new_address_space();
        if not space {
            return i32(-1);
        }
        length_cell(space).view(1)[0] = u32(SOCK_ADDR_SIZE);
        if getsockname(fd, ptr(space), length_cell(space)) == 0 {
            if fam == -1 {
                fam = sockaddr_family(space);
            }
        } else {
            error = int(jacpy_errno());
            if fam == -1 or error == EBADF or error == ENOTSOCK {
                free_addrbuf(space);
                socket_error(error);
                return i32(-1);
            }
        }
        cell = ptr[i32](space);
        size = length_cell(space);
        if typ == -1 {
            size.view(1)[0] = u32(4);
            if getsockopt(fd, i32(SOL_SOCKET), i32(SO_TYPE), ptr(cell), size) == 0 {
                typ = int(cell.view(1)[0]);
            } else {
                error = int(jacpy_errno());
                free_addrbuf(space);
                socket_error(error);
                return i32(-1);
            }
        }
        if HAS_SO_PROTOCOL {
            if pro == -1 {
                size.view(1)[0] = u32(4);
                if getsockopt(fd, i32(SOL_SOCKET), i32(SO_PROTOCOL), ptr(cell), size)
                    == 0 {
                    pro = int(cell.view(1)[0]);
                } else {
                    error = int(jacpy_errno());
                    free_addrbuf(space);
                    socket_error(error);
                    return i32(-1);
                }
            }
        } else {
            pro = 0;
        }
        free_addrbuf(space);
    } else {
        if fam == -1 {
            fam = AF_INET;
        }
        if typ == -1 {
            typ = SOCK_STREAM;
        }
        if pro == -1 {
            pro = 0;
        }
        error = i64(0);
        thread = PyEval_SaveThread();
        if HAS_SOCK_CLOEXEC and sock_cloexec_works != 0 {
            fd = socket(i32(fam), i32(typ | SOCK_CLOEXEC), i32(pro));
            error = jacpy_errno();
            if sock_cloexec_works == -1 {
                if fd >= 0 {
                    sock_cloexec_works = i32(1);
                } elif error == EINVAL {
                    sock_cloexec_works = i32(0);
                    fd = socket(i32(fam), i32(typ), i32(pro));
                    error = jacpy_errno();
                }
            }
        } else {
            fd = socket(i32(fam), i32(typ), i32(pro));
            error = jacpy_errno();
        }
        PyEval_RestoreThread(thread);
        if fd == INVALID_SOCKET {
            socket_error(int(error));
            return i32(-1);
        }
        if set_inheritable_new(fd) < 0 {
            close(fd);
            return i32(-1);
        }
    }
    if init_sockobject(module, s, fd, fam, typ, pro) == -1 {
        close(fd);
        return i32(-1);
    }
    return i32(0);
}

impl set_inheritable_new(fd: i32) -> int {
    if HAS_SOCK_CLOEXEC {
        works = sock_cloexec_works;
        status = _Py_set_inheritable(fd, 0, &mut works);
        sock_cloexec_works = works;
        return int(status);
    }
    return int(_Py_set_inheritable(fd, 0, None));
}
