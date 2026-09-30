"""The _socket module: the socket type, its CAPI capsule for _ssl, the lookup
and conversion functions, and the platform's constants.

Derived from CPython 3.14.6 Modules/socketmodule.c; see ../LICENSE.cpython.
The socket type is a heap type from a C-data PyType_Spec whose objects are
PySocketSockObject records, the layout Modules/socketmodule.h gives _ssl.c.
"""
import from jaclang.runtime.python.cpython_api {
    jacpy_release,
    NULL,
    Py_NewRef,
    PyErr_NewException,
    PyErr_NoMemory,
    PyExc_ImportError,
    PyExc_OSError,
    PyExc_TimeoutError,
    PyMem_Free,
    PyMem_Malloc,
    PyMethodDef,
    PyMemberDef,
    PyModule_Add,
    PyModule_AddIntConstant,
    PyModule_AddObjectRef,
    PyModule_AddType,
    PyObject,
    PyThread_allocate_lock,
    PyType_FromMetaclass,
    PyType_Slot,
    PyType_Spec
}
import from jaclang.runtime.python.capi { object_error }
import from jaclang.runtime.python.object_model.bool { py_true }
import from jaclang.runtime.python.layouts {
    PY_SOCKET_API_SIZE,
    PY_SOCKET_FAMILY_OFFSET,
    PY_SOCKET_OBJECT_SIZE,
    PY_SOCKET_PROTO_OFFSET,
    PY_SOCKET_TYPE_OFFSET,
    PyGetSetDef,
    PySocketModule_APIObject,
    PyTypeObject,
    Py_READONLY,
    Py_T_INT,
    Py_TPFLAGS_BASETYPE,
    Py_TPFLAGS_DEFAULT,
    Py_TPFLAGS_HAVE_GC,
    Py_TPFLAGS_IMMUTABLETYPE,
    Py_tp_dealloc,
    Py_tp_doc,
    Py_tp_finalize,
    Py_tp_getset,
    Py_tp_init,
    Py_tp_members,
    Py_tp_methods,
    Py_tp_new,
    Py_tp_repr,
    Py_tp_traverse
}
import from jaclang.runtime.python.object_model.capsule {
    PyCapsule_GetPointer,
    PyCapsule_New,
    _PyCapsule_SetTraverse
}
import from jaclang.runtime.python.bindings.module {
    MethodCallbacks,
    MethodDefinition,
    ModuleDefinition,
    ModuleHooks,
    jacpy_binding_module_native_set,
    jacpy_binding_state_set,
    method_table,
    visit_reference
}
import from jaclang.runtime.python.bindings.clinic.socket {
    module_methods,
    sock_initobj_init,
    socket_methods
}
import from jaclang.runtime.python.modules.socket_constants { CONSTANTS }
import from jaclang.runtime.python.modules.socket_platform {
    HAS_ALG,
    HAS_GETHOSTBYNAME_R,
    HAS_VSOCK,
    PLATFORM
}
import from jaclang.runtime.python.modules.socket_core {
    STATE_COUNT,
    STATE_GAIERROR,
    STATE_HERROR,
    STATE_SOCK_TYPE,
    SocketState,
    socket_module_token
}
import from jaclang.runtime.python.modules.socket_object {
    sock_accept,
    sock_bind,
    sock_connect,
    sock_connect_ex,
    sock_dealloc,
    sock_detach,
    sock_fileno,
    sock_finalize,
    sock_getblocking,
    sock_getpeername,
    sock_getsockname,
    sock_getsockopt,
    sock_gettimeout_getter,
    sock_gettimeout_method,
    sock_listen,
    sock_new,
    sock_recv,
    sock_recv_into,
    sock_recvfrom,
    sock_recvfrom_into,
    sock_recvmsg,
    sock_recvmsg_into,
    sock_repr,
    sock_send,
    sock_sendall,
    sock_sendmsg,
    sock_sendmsg_afalg,
    sock_sendto,
    sock_setblocking,
    sock_setsockopt,
    sock_settimeout,
    sock_shutdown,
    sock_traverse
}
import from jaclang.runtime.python.modules.socket {
    socket_CMSG_LEN,
    socket_CMSG_SPACE,
    socket_close,
    socket_dup,
    socket_getaddrinfo,
    socket_getdefaulttimeout,
    socket_gethostbyaddr,
    socket_gethostbyname,
    socket_gethostbyname_ex,
    socket_gethostname,
    socket_getnameinfo,
    socket_getprotobyname,
    socket_getservbyname,
    socket_getservbyport,
    socket_if_nameindex,
    socket_inet_ntop,
    socket_inet_pton,
    socket_setdefaulttimeout,
    socket_sethostname,
    socket_socketpair
}

import from c {
    glob:priv sock_members: list[PyMemberDef] = [
             PyMemberDef(
                 name=ptr[u8]("family"),
                 type_=Py_T_INT,
                 offset=PY_SOCKET_FAMILY_OFFSET,
                 flags=Py_READONLY,
                 doc=ptr[u8]("the socket family")
             ),
             PyMemberDef(
                 name=ptr[u8]("type"),
                 type_=Py_T_INT,
                 offset=PY_SOCKET_TYPE_OFFSET,
                 flags=Py_READONLY,
                 doc=ptr[u8]("the socket type")
             ),
             PyMemberDef(
                 name=ptr[u8]("proto"),
                 type_=Py_T_INT,
                 offset=PY_SOCKET_PROTO_OFFSET,
                 flags=Py_READONLY,
                 doc=ptr[u8]("the socket protocol")
             ),
             PyMemberDef()
         ],
         sock_getsets: list[PyGetSetDef] = [
             PyGetSetDef(
                 name=ptr[u8]("timeout"),
                 get=sock_gettimeout_getter,
                 doc=ptr[u8]("the socket timeout")
             ),
             PyGetSetDef()
         ],
         # Py_tp_methods (SOCK_METHODS_SLOT) is filled once per process from
         # type_methods(), clinic glue included, before the first type is made.
         sock_slots: list[PyType_Slot] = [
             PyType_Slot(slot=Py_tp_dealloc, pfunc=ptr(sock_dealloc)),
             PyType_Slot(slot=Py_tp_traverse, pfunc=ptr(sock_traverse)),
             PyType_Slot(slot=Py_tp_repr, pfunc=ptr(sock_repr)),
             PyType_Slot(
                 slot=Py_tp_doc,
                 pfunc=ptr[u8](
                     "socket(family=AF_INET, type=SOCK_STREAM, proto=0) -> socket object\nsocket(family=-1, type=-1, proto=-1, fileno=None) -> socket object\n\nOpen a socket of the given type.  The family argument specifies the\naddress family; it defaults to AF_INET.  The type argument specifies\nwhether this is a stream (SOCK_STREAM, this is the default)\nor datagram (SOCK_DGRAM) socket.  The protocol argument defaults to 0,\nspecifying the default protocol.  Keyword arguments are accepted.\nThe socket is created as non-inheritable.\n\nWhen a fileno is passed in, family, type and proto are auto-detected,\nunless they are explicitly set.\n\nA socket object represents one endpoint of a network connection.\n\nMethods of socket objects (keyword arguments not allowed):\n\n_accept() -- accept connection, returning new socket fd and client address\nbind(addr) -- bind the socket to a local address\nclose() -- close the socket\nconnect(addr) -- connect the socket to a remote address\nconnect_ex(addr) -- connect, return an error code instead of an exception\ndup() -- return a new socket fd duplicated from fileno()\nfileno() -- return underlying file descriptor\ngetpeername() -- return remote address [*]\ngetsockname() -- return local address\ngetsockopt(level, optname[, buflen]) -- get socket options\ngettimeout() -- return timeout or None\nlisten([n]) -- start listening for incoming connections\nrecv(buflen[, flags]) -- receive data\nrecv_into(buffer[, nbytes[, flags]]) -- receive data (into a buffer)\nrecvfrom(buflen[, flags]) -- receive data and sender's address\nrecvfrom_into(buffer[, nbytes, [, flags]])\n  -- receive data and sender's address (into a buffer)\nsendall(data[, flags]) -- send all data\nsend(data[, flags]) -- send data, may not send all of it\nsendto(data[, flags], addr) -- send data to a given address\nsetblocking(bool) -- set or clear the blocking I/O flag\ngetblocking() -- return True if socket is blocking, False if non-blocking\nsetsockopt(level, optname, value[, optlen]) -- set socket options\nsettimeout(None | float) -- set or clear the timeout\nshutdown(how) -- shut down traffic in one or both directions\n\n [*] not available on all platforms!"
                 )
             ),
             PyType_Slot(slot=Py_tp_methods, pfunc=ptr()),
             PyType_Slot(slot=Py_tp_members, pfunc=ptr(addressof(sock_members))),
             PyType_Slot(slot=Py_tp_getset, pfunc=ptr(addressof(sock_getsets))),
             PyType_Slot(slot=Py_tp_init, pfunc=ptr(sock_initobj_init)),
             PyType_Slot(slot=Py_tp_new, pfunc=ptr(sock_new)),
             PyType_Slot(slot=Py_tp_finalize, pfunc=ptr(sock_finalize)),
             PyType_Slot(slot=0, pfunc=ptr())
         ]; glob sock_spec: PyType_Spec = PyType_Spec(
             name=ptr[u8]("_socket.socket"),
             basicsize=i32(PY_SOCKET_OBJECT_SIZE),
             itemsize=0,
             flags=u32(
                 Py_TPFLAGS_DEFAULT
                     | Py_TPFLAGS_BASETYPE
                     | Py_TPFLAGS_HAVE_GC
                     | Py_TPFLAGS_IMMUTABLETYPE
             ),
             slots=addressof(sock_slots)
         );
    # The netdb lock modules/socket.jac defines.
    glob netdb_lock: ptr;
    # PySocket_CAPSULE_NAME, which the capsule keeps pointing at.
    glob:priv capsule_name: ptr[u8] = ptr[u8]("_socket.CAPI");
}

glob:priv SOCK_METHODS_SLOT: int = 4,
     MODULE_DOC: str = "Implementation module for socket operations.\n\nSee the socket module for documentation.",
     # Constants the module reads without publishing them.
     INTERNAL: list[str] = [
         "FIONBIO",
         "POLLIN",
         "POLLOUT",
         "POLLERR",
         "IF_NAMESIZE",
         "INET_ADDRSTRLEN",
         "INET6_ADDRSTRLEN",
         "SIOCGIFINDEX",
         "SIOCGIFNAME",
         "CTLIOCGINFO",
         "AF_SYS_CONTROL"
     ],
     # The values the C module publishes where the headers lack a macro.
     FALLBACKS: list[tuple[str, int]] = [
         ("SOMAXCONN", 5),
         ("SOL_IP", 0),
         ("SOL_TCP", 6),
         ("SOL_UDP", 17),
         ("IPPROTO_IP", 0),
         ("IPPROTO_ICMP", 1),
         ("IPPROTO_TCP", 6),
         ("IPPROTO_UDP", 17),
         ("IPPROTO_RAW", 255),
         ("IPPORT_RESERVED", 1024),
         ("IPPORT_USERRESERVED", 5000),
         ("INADDR_ANY", 0x00000000),
         ("INADDR_BROADCAST", 0xFFFFFFFF),
         ("INADDR_LOOPBACK", 0x7F000001),
         ("INADDR_UNSPEC_GROUP", 0xE0000000),
         ("INADDR_ALLHOSTS_GROUP", 0xE0000001),
         ("INADDR_MAX_LOCAL_GROUP", 0xE00000FF),
         ("INADDR_NONE", 0xFFFFFFFF),
         ("SHUT_RD", 0),
         ("SHUT_WR", 1),
         ("SHUT_RDWR", 2)
     ],
     # The VSOCK values the C module publishes as literals with AF_VSOCK;
     # IOCTL_VM_SOCKETS_GET_LOCAL_CID is _IO(7, 0xb9).
     VSOCK_CONSTANTS: list[tuple[str, int]] = [
         ("SO_VM_SOCKETS_BUFFER_SIZE", 0),
         ("SO_VM_SOCKETS_BUFFER_MIN_SIZE", 1),
         ("SO_VM_SOCKETS_BUFFER_MAX_SIZE", 2),
         ("VMADDR_CID_ANY", 0xFFFFFFFF),
         ("VMADDR_PORT_ANY", 0xFFFFFFFF),
         ("VMADDR_CID_LOCAL", 1),
         ("VMADDR_CID_HOST", 2),
         ("VM_SOCKETS_INVALID_VERSION", 0xFFFFFFFF),
         ("IOCTL_VM_SOCKETS_GET_LOCAL_CID", 0x7B9)
     ];

# ---------------------------------------------------------------------------
# The CAPI capsule.

def:priv sock_capi_of(capsule: ptr[PyObject]) -> ptr[PySocketModule_APIObject] {
    return ptr[PySocketModule_APIObject](PyCapsule_GetPointer(capsule, capsule_name));
}

def:priv sock_capi_traverse(capsule: ptr[PyObject], visitor: ptr, arg: ptr) -> i32 {
    capi = sock_capi_of(capsule);
    return visit_reference(ptr[PyObject](capi.view(1)[0].Sock_Type), visitor, arg);
}

def:priv sock_capi_clear(capsule: ptr[PyObject]) -> i32 {
    capi = sock_capi_of(capsule).view(1);
    sock_type = ptr[PyObject](capi[0].Sock_Type);
    capi[0].Sock_Type = ptr[PyTypeObject]();
    jacpy_release(sock_type);
    return i32(0);
}

def:priv sock_capi_free(capi: ptr[PySocketModule_APIObject]) {
    record = capi.view(1);
    # sock_capi_clear() can have cleared the type.
    jacpy_release(ptr[PyObject](record[0].Sock_Type));
    jacpy_release(record[0].error);
    jacpy_release(record[0].timeout_error);
    PyMem_Free(ptr(capi));
}

def:priv sock_capi_destroy(capsule: ptr[PyObject]) {
    sock_capi_free(sock_capi_of(capsule));
}

"""sock_get_api(): the type and the error classes _ssl reads."""
def:priv sock_get_api(sock_type: ptr[PyObject]) -> ptr[PySocketModule_APIObject] {
    capi = ptr[PySocketModule_APIObject](PyMem_Malloc(u64(PY_SOCKET_API_SIZE)));
    if not capi {
        PyErr_NoMemory();
        return capi;
    }
    record = capi.view(1);
    record[0].Sock_Type = ptr[PyTypeObject](Py_NewRef(sock_type));
    record[0].error = Py_NewRef(PyExc_OSError);
    record[0].timeout_error = Py_NewRef(PyExc_TimeoutError);
    return capi;
}

# ---------------------------------------------------------------------------
# Module execution.

"""A list of the clinic glue's method definitions named in `names`."""
def:priv clinic_methods(
    methods: list[MethodDefinition], names: list[str]
) -> list[MethodDefinition] {
    selected: list[MethodDefinition] = [];
    for name in names {
        for method in methods {
            if method.name == name {
                selected.append(method);
            }
        }
    }
    return selected;
}

"""Fill the type's method table once; the table lives for the process, as
the C module's static sock_methods[] does."""
def:priv install_sock_methods -> bool {
    slot = (addressof(sock_slots) + SOCK_METHODS_SLOT).view(1);
    if slot[0].pfunc {
        return True;
    }
    table = method_table(type_methods());
    if not table {
        return False;
    }
    slot[0].pfunc = ptr(table);
    return True;
}

"""A new reference stored in state slot `index` and published as `name`."""
def:priv add_state(
    module: ptr[PyObject], index: int, name: str, value: ptr[PyObject]
) -> bool {
    if not value {
        return False;
    }
    jacpy_binding_state_set(module, i64(index), value);
    status = PyModule_AddObjectRef(module, name, value);
    jacpy_release(value);
    return status >= 0;
}

"""The platform's constants, the C module's fallbacks for the ones the
headers lack, and the VSOCK literals."""
def:priv add_constants(module: ptr[PyObject]) -> bool {
    published: set[str] = set();
    for (name, value) in CONSTANTS {
        if name in INTERNAL {
            continue;
        }
        if PyModule_AddIntConstant(module, name, value) < 0 {
            return False;
        }
        published.add(name);
    }
    for (name, value) in FALLBACKS {
        if name not in published
            and PyModule_AddIntConstant(module, name, i64(value)) < 0 {
            return False;
        }
    }
    if HAS_VSOCK {
        for (name, value) in VSOCK_CONSTANTS {
            if PyModule_AddIntConstant(module, name, i64(value)) < 0 {
                return False;
            }
        }
    }
    return True;
}

def:priv socket_exec(module: ptr[PyObject]) -> i32 {
    if PLATFORM == "" {
        object_error(
            PyExc_ImportError,
            "_socket has no socket_platform.<os>.jac for this target platform"
        );
        return i32(-1);
    }
    socket_module_token.handle = definition.handle;
    jacpy_binding_module_native_set(module, SocketState());
    if not add_state(
        module,
        STATE_HERROR,
        "herror",
        PyErr_NewException("socket.herror", PyExc_OSError, NULL)
    )
        or not add_state(
            module,
            STATE_GAIERROR,
            "gaierror",
            PyErr_NewException("socket.gaierror", PyExc_OSError, NULL)
        ) {
        return i32(-1);
    }
    if PyModule_AddObjectRef(module, "error", PyExc_OSError) < 0
        or PyModule_AddObjectRef(module, "timeout", PyExc_TimeoutError) < 0 {
        return i32(-1);
    }
    if not install_sock_methods() {
        return i32(-1);
    }
    sock_type = PyType_FromMetaclass(NULL, module, addressof(sock_spec), NULL);
    if not add_state(module, STATE_SOCK_TYPE, "SocketType", sock_type)
        or PyModule_AddType(module, sock_type) < 0 {
        return i32(-1);
    }
    if PyModule_AddObjectRef(module, "has_ipv6", py_true()) < 0 {
        return i32(-1);
    }
    # Export the C API.
    capi = sock_get_api(sock_type);
    if not capi {
        return i32(-1);
    }
    capsule = PyCapsule_New(ptr(capi), capsule_name, ptr(sock_capi_destroy));
    if not capsule {
        sock_capi_free(capi);
        return i32(-1);
    }
    if _PyCapsule_SetTraverse(capsule, ptr(sock_capi_traverse), ptr(sock_capi_clear))
        < 0 {
        sock_capi_free(capi);
        return i32(-1);
    }
    if PyModule_Add(module, "CAPI", capsule) < 0 {
        return i32(-1);
    }
    if not add_constants(module) {
        return i32(-1);
    }
    # The gethostbyname lock of a C library without gethostbyname_r().
    if not HAS_GETHOSTBYNAME_R and not netdb_lock {
        netdb_lock = PyThread_allocate_lock();
        if not netdb_lock {
            return i32(-1);
        }
    }
    return i32(0);
}

"""The socket type's methods, in sock_methods[] order; the clinic glue
supplies close()."""
def:priv type_methods -> list[MethodDefinition] {
    methods: list[MethodDefinition] = [];
    methods.append(
        MethodDefinition(
            "_accept",
            MethodCallbacks(positional=sock_accept),
            "_accept() -> (integer, address info)\n\nWait for an incoming connection.  Return a new socket file descriptor\nrepresenting the connection, and the address of the client.\nFor IP sockets, the address info is a pair (hostaddr, port).",
            4
        )
    );
    methods.append(
        MethodDefinition(
            "bind",
            MethodCallbacks(positional=sock_bind),
            "bind(address)\n\nBind the socket to a local address.  For IP sockets, the address is a\npair (host, port); the host must refer to the local host. For raw packet\nsockets the address is a tuple (ifname, proto [,pkttype [,hatype [,addr]]])",
            8
        )
    );
    methods += clinic_methods(socket_methods, ["close"]);
    methods.append(
        MethodDefinition(
            "connect",
            MethodCallbacks(positional=sock_connect),
            "connect(address)\n\nConnect the socket to a remote address.  For IP sockets, the address\nis a pair (host, port).",
            8
        )
    );
    methods.append(
        MethodDefinition(
            "connect_ex",
            MethodCallbacks(positional=sock_connect_ex),
            "connect_ex(address) -> errno\n\nThis is like connect(address), but returns an error code (the errno value)\ninstead of raising an exception when an error occurs.",
            8
        )
    );
    methods.append(
        MethodDefinition(
            "detach",
            MethodCallbacks(positional=sock_detach),
            "detach()\n\nClose the socket object without closing the underlying file descriptor.\nThe object cannot be used after this call, but the file descriptor\ncan be reused for other purposes.  The file descriptor is returned.",
            4
        )
    );
    methods.append(
        MethodDefinition(
            "fileno",
            MethodCallbacks(positional=sock_fileno),
            "fileno() -> integer\n\nReturn the integer file descriptor of the socket.",
            4
        )
    );
    methods.append(
        MethodDefinition(
            "getpeername",
            MethodCallbacks(positional=sock_getpeername),
            "getpeername() -> address info\n\nReturn the address of the remote endpoint.  For IP sockets, the address\ninfo is a pair (hostaddr, port).",
            4
        )
    );
    methods.append(
        MethodDefinition(
            "getsockname",
            MethodCallbacks(positional=sock_getsockname),
            "getsockname() -> address info\n\nReturn the address of the local endpoint. The format depends on the\naddress family. For IPv4 sockets, the address info is a pair\n(hostaddr, port). For IPv6 sockets, the address info is a 4-tuple\n(hostaddr, port, flowinfo, scope_id).",
            4
        )
    );
    methods.append(
        MethodDefinition(
            "getsockopt",
            MethodCallbacks(positional=sock_getsockopt),
            "getsockopt(level, option[, buffersize]) -> value\n\nGet a socket option.  See the Unix manual for level and option.\nIf a nonzero buffersize argument is given, the return value is a\nstring of that length; otherwise it is an integer.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "listen",
            MethodCallbacks(positional=sock_listen),
            "listen([backlog])\n\nEnable a server to accept connections.  If backlog is specified, it must be\nat least 0 (if it is lower, it is set to 0); it specifies the number of\nunaccepted connections that the system will allow before refusing new\nconnections. If not specified, a default reasonable value is chosen.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "recv",
            MethodCallbacks(positional=sock_recv),
            "recv(buffersize[, flags]) -> data\n\nReceive up to buffersize bytes from the socket.  For the optional flags\nargument, see the Unix manual.  When no data is available, block until\nat least one byte is available or until the remote end is closed.  When\nthe remote end is closed and all data is read, return the empty string.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "recv_into",
            MethodCallbacks(keywords=sock_recv_into),
            "recv_into(buffer, [nbytes[, flags]]) -> nbytes_read\n\nA version of recv() that stores its data into a buffer rather than creating\na new string.  Receive up to buffersize bytes from the socket.  If buffersize\nis not specified (or 0), receive up to the size available in the given buffer.\n\nSee recv() for documentation about the flags.",
            3
        )
    );
    methods.append(
        MethodDefinition(
            "recvfrom",
            MethodCallbacks(positional=sock_recvfrom),
            "recvfrom(buffersize[, flags]) -> (data, address info)\n\nLike recv(buffersize, flags) but also return the sender's address info.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "recvfrom_into",
            MethodCallbacks(keywords=sock_recvfrom_into),
            "recvfrom_into(buffer[, nbytes[, flags]]) -> (nbytes, address info)\n\nLike recv_into(buffer[, nbytes[, flags]]) but also return the sender's address info.",
            3
        )
    );
    methods.append(
        MethodDefinition(
            "send",
            MethodCallbacks(positional=sock_send),
            "send(data[, flags]) -> count\n\nSend a data string to the socket.  For the optional flags\nargument, see the Unix manual.  Return the number of bytes\nsent; this may be less than len(data) if the network is busy.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "sendall",
            MethodCallbacks(positional=sock_sendall),
            "sendall(data[, flags])\n\nSend a data string to the socket.  For the optional flags\nargument, see the Unix manual.  This calls send() repeatedly\nuntil all data is sent.  If an error occurs, it's impossible\nto tell how much data has been sent.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "sendto",
            MethodCallbacks(positional=sock_sendto),
            "sendto(data[, flags], address) -> count\n\nLike send(data, flags) but allows specifying the destination address.\nFor IP sockets, the address is a pair (hostaddr, port).",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "setblocking",
            MethodCallbacks(positional=sock_setblocking),
            "setblocking(flag)\n\nSet the socket to blocking (flag is true) or non-blocking (false).\nsetblocking(True) is equivalent to settimeout(None);\nsetblocking(False) is equivalent to settimeout(0.0).",
            8
        )
    );
    methods.append(
        MethodDefinition(
            "getblocking",
            MethodCallbacks(positional=sock_getblocking),
            "getblocking()\n\nReturns True if socket is in blocking mode, or False if it\nis in non-blocking mode.",
            4
        )
    );
    methods.append(
        MethodDefinition(
            "settimeout",
            MethodCallbacks(positional=sock_settimeout),
            "settimeout(timeout)\n\nSet a timeout on socket operations.  'timeout' can be a float,\ngiving in seconds, or None.  Setting a timeout of None disables\nthe timeout feature and is equivalent to setblocking(1).\nSetting a timeout of zero is the same as setblocking(0).",
            8
        )
    );
    methods.append(
        MethodDefinition(
            "gettimeout",
            MethodCallbacks(positional=sock_gettimeout_method),
            "gettimeout() -> timeout\n\nReturns the timeout in seconds (float) associated with socket\noperations. A timeout of None indicates that timeouts on socket\noperations are disabled.",
            4
        )
    );
    methods.append(
        MethodDefinition(
            "setsockopt",
            MethodCallbacks(positional=sock_setsockopt),
            "setsockopt(level, option, value: int)\nsetsockopt(level, option, value: buffer)\nsetsockopt(level, option, None, optlen: int)\n\nSet a socket option.  See the Unix manual for level and option.\nThe value argument can either be an integer, a string buffer, or\nNone, optlen.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "shutdown",
            MethodCallbacks(positional=sock_shutdown),
            "shutdown(flag)\n\nShut down the reading side of the socket (flag == SHUT_RD), the writing side\nof the socket (flag == SHUT_WR), or both ends (flag == SHUT_RDWR).",
            8
        )
    );
    methods.append(
        MethodDefinition(
            "recvmsg",
            MethodCallbacks(positional=sock_recvmsg),
            "recvmsg(bufsize[, ancbufsize[, flags]]) -> (data, ancdata, msg_flags, address)\n\nReceive normal data (up to bufsize bytes) and ancillary data from the\nsocket.  The ancbufsize argument sets the size in bytes of the\ninternal buffer used to receive the ancillary data; it defaults to 0,\nmeaning that no ancillary data will be received.  Appropriate buffer\nsizes for ancillary data can be calculated using CMSG_SPACE() or\nCMSG_LEN(), and items which do not fit into the buffer might be\ntruncated or discarded.  The flags argument defaults to 0 and has the\nsame meaning as for recv().\n\nThe return value is a 4-tuple: (data, ancdata, msg_flags, address).\nThe data item is a bytes object holding the non-ancillary data\nreceived.  The ancdata item is a list of zero or more tuples\n(cmsg_level, cmsg_type, cmsg_data) representing the ancillary data\n(control messages) received: cmsg_level and cmsg_type are integers\nspecifying the protocol level and protocol-specific type respectively,\nand cmsg_data is a bytes object holding the associated data.  The\nmsg_flags item is the bitwise OR of various flags indicating\nconditions on the received message; see your system documentation for\ndetails.  If the receiving socket is unconnected, address is the\naddress of the sending socket, if available; otherwise, its value is\nunspecified.\n\nIf recvmsg() raises an exception after the system call returns, it\nwill first attempt to close any file descriptors received via the\nSCM_RIGHTS mechanism.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "recvmsg_into",
            MethodCallbacks(positional=sock_recvmsg_into),
            "recvmsg_into(buffers[, ancbufsize[, flags]]) -> (nbytes, ancdata, msg_flags, address)\n\nReceive normal data and ancillary data from the socket, scattering the\nnon-ancillary data into a series of buffers.  The buffers argument\nmust be an iterable of objects that export writable buffers\n(e.g. bytearray objects); these will be filled with successive chunks\nof the non-ancillary data until it has all been written or there are\nno more buffers.  The ancbufsize argument sets the size in bytes of\nthe internal buffer used to receive the ancillary data; it defaults to\n0, meaning that no ancillary data will be received.  Appropriate\nbuffer sizes for ancillary data can be calculated using CMSG_SPACE()\nor CMSG_LEN(), and items which do not fit into the buffer might be\ntruncated or discarded.  The flags argument defaults to 0 and has the\nsame meaning as for recv().\n\nThe return value is a 4-tuple: (nbytes, ancdata, msg_flags, address).\nThe nbytes item is the total number of bytes of non-ancillary data\nwritten into the buffers.  The ancdata item is a list of zero or more\ntuples (cmsg_level, cmsg_type, cmsg_data) representing the ancillary\ndata (control messages) received: cmsg_level and cmsg_type are\nintegers specifying the protocol level and protocol-specific type\nrespectively, and cmsg_data is a bytes object holding the associated\ndata.  The msg_flags item is the bitwise OR of various flags\nindicating conditions on the received message; see your system\ndocumentation for details.  If the receiving socket is unconnected,\naddress is the address of the sending socket, if available; otherwise,\nits value is unspecified.\n\nIf recvmsg_into() raises an exception after the system call returns,\nit will first attempt to close any file descriptors received via the\nSCM_RIGHTS mechanism.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "sendmsg",
            MethodCallbacks(positional=sock_sendmsg),
            "sendmsg(buffers[, ancdata[, flags[, address]]]) -> count\n\nSend normal and ancillary data to the socket, gathering the\nnon-ancillary data from a series of buffers and concatenating it into\na single message.  The buffers argument specifies the non-ancillary\ndata as an iterable of bytes-like objects (e.g. bytes objects).\nThe ancdata argument specifies the ancillary data (control messages)\nas an iterable of zero or more tuples (cmsg_level, cmsg_type,\ncmsg_data), where cmsg_level and cmsg_type are integers specifying the\nprotocol level and protocol-specific type respectively, and cmsg_data\nis a bytes-like object holding the associated data.  The flags\nargument defaults to 0 and has the same meaning as for send().  If\naddress is supplied and not None, it sets a destination address for\nthe message.  The return value is the number of bytes of non-ancillary\ndata sent.",
            1
        )
    );
    # sendmsg_afalg() exists where the headers have AF_ALG.
    if HAS_ALG {
        methods.append(
            MethodDefinition(
                "sendmsg_afalg",
                MethodCallbacks(keywords=sock_sendmsg_afalg),
                "sendmsg_afalg([msg], *, op[, iv[, assoclen[, flags=MSG_MORE]]])\n\nSet operation mode, IV and length of associated data for an AF_ALG\noperation socket.",
                3
            )
        );
    }
    return methods;
}

"""The module's functions, in socket_methods[] order; the clinic glue
supplies the Argument Clinic ones."""
def:priv module_functions -> list[MethodDefinition] {
    methods: list[MethodDefinition] = [];
    methods.append(
        MethodDefinition(
            "gethostbyname",
            MethodCallbacks(positional=socket_gethostbyname),
            "gethostbyname(host) -> address\n\nReturn the IP address (a string of the form '255.255.255.255') for a host.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "gethostbyname_ex",
            MethodCallbacks(positional=socket_gethostbyname_ex),
            "gethostbyname_ex(host) -> (name, aliaslist, addresslist)\n\nReturn the true host name, a list of aliases, and a list of IP addresses,\nfor a host.  The host argument is a string giving a host name or IP number.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "gethostbyaddr",
            MethodCallbacks(positional=socket_gethostbyaddr),
            "gethostbyaddr(host) -> (name, aliaslist, addresslist)\n\nReturn the true host name, a list of aliases, and a list of IP addresses,\nfor a host.  The host argument is a string giving a host name or IP number.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "gethostname",
            MethodCallbacks(positional=socket_gethostname),
            "gethostname() -> string\n\nReturn the current host name.",
            4
        )
    );
    methods.append(
        MethodDefinition(
            "sethostname",
            MethodCallbacks(positional=socket_sethostname),
            "sethostname(name)\n\nSets the hostname to name.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "getservbyname",
            MethodCallbacks(positional=socket_getservbyname),
            "getservbyname(servicename[, protocolname]) -> integer\n\nReturn a port number from a service name and protocol name.\nThe optional protocol name, if given, should be 'tcp' or 'udp',\notherwise any protocol will match.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "getservbyport",
            MethodCallbacks(positional=socket_getservbyport),
            "getservbyport(port[, protocolname]) -> string\n\nReturn the service name from a port number and protocol name.\nThe optional protocol name, if given, should be 'tcp' or 'udp',\notherwise any protocol will match.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "getprotobyname",
            MethodCallbacks(positional=socket_getprotobyname),
            "getprotobyname(name) -> integer\n\nReturn the protocol number for the named protocol.  (Rarely used.)",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "close",
            MethodCallbacks(positional=socket_close),
            "close(integer) -> None\n\nClose an integer socket file descriptor.  This is like os.close(), but for\nsockets; on some platforms os.close() won't work for socket file descriptors.",
            8
        )
    );
    methods.append(
        MethodDefinition(
            "dup",
            MethodCallbacks(positional=socket_dup),
            "dup(integer) -> integer\n\nDuplicate an integer socket file descriptor.  This is like os.dup(), but for\nsockets; on some platforms os.dup() won't work for socket file descriptors.",
            8
        )
    );
    methods.append(
        MethodDefinition(
            "socketpair",
            MethodCallbacks(positional=socket_socketpair),
            "socketpair([family[, type [, proto]]]) -> (socket object, socket object)\n\nCreate a pair of socket objects from the sockets returned by the platform\nsocketpair() function.\nThe arguments are the same as for socket() except the default family is\nAF_UNIX if defined on the platform; otherwise, the default is AF_INET.",
            1
        )
    );
    methods += clinic_methods(
        module_methods, ["ntohs", "ntohl", "htons", "htonl", "inet_aton", "inet_ntoa"]
    );
    methods.append(
        MethodDefinition(
            "inet_pton",
            MethodCallbacks(positional=socket_inet_pton),
            "inet_pton(af, ip) -> packed IP address string\n\nConvert an IP address from string format to a packed string suitable\nfor use with low-level network functions.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "inet_ntop",
            MethodCallbacks(positional=socket_inet_ntop),
            "inet_ntop(af, packed_ip) -> string formatted IP address\n\nConvert a packed IP address of the given family to string format.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "getaddrinfo",
            MethodCallbacks(keywords=socket_getaddrinfo),
            "getaddrinfo(host, port [, family, type, proto, flags])\n    -> list of (family, type, proto, canonname, sockaddr)\n\nResolve host and port into addrinfo struct.",
            3
        )
    );
    methods.append(
        MethodDefinition(
            "getnameinfo",
            MethodCallbacks(positional=socket_getnameinfo),
            "getnameinfo(sockaddr, flags) --> (host, port)\n\nGet host and port for a sockaddr.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "getdefaulttimeout",
            MethodCallbacks(positional=socket_getdefaulttimeout),
            "getdefaulttimeout() -> timeout\n\nReturns the default timeout in seconds (float) for new socket objects.\nA value of None indicates that new socket objects have no timeout.\nWhen the socket module is first imported, the default is None.",
            4
        )
    );
    methods.append(
        MethodDefinition(
            "setdefaulttimeout",
            MethodCallbacks(positional=socket_setdefaulttimeout),
            "setdefaulttimeout(timeout)\n\nSet the default timeout in seconds (float) for new socket objects.\nA value of None indicates that new socket objects have no timeout.\nWhen the socket module is first imported, the default is None.",
            8
        )
    );
    methods.append(
        MethodDefinition(
            "if_nameindex",
            MethodCallbacks(positional=socket_if_nameindex),
            "if_nameindex()\n\nReturns a list of network interface information (index, name) tuples.",
            4
        )
    );
    methods += clinic_methods(module_methods, ["if_nametoindex", "if_indextoname"]);
    methods.append(
        MethodDefinition(
            "CMSG_LEN",
            MethodCallbacks(positional=socket_CMSG_LEN),
            "CMSG_LEN(length) -> control message length\n\nReturn the total length, without trailing padding, of an ancillary\ndata item with associated data of the given length.  This value can\noften be used as the buffer size for recvmsg() to receive a single\nitem of ancillary data, but RFC 3542 requires portable applications to\nuse CMSG_SPACE() and thus include space for padding, even when the\nitem will be the last in the buffer.  Raises OverflowError if length\nis outside the permissible range of values.",
            1
        )
    );
    methods.append(
        MethodDefinition(
            "CMSG_SPACE",
            MethodCallbacks(positional=socket_CMSG_SPACE),
            "CMSG_SPACE(length) -> buffer size\n\nReturn the buffer size needed for recvmsg() to receive an ancillary\ndata item with associated data of the given length, along with any\ntrailing padding.  The buffer space needed to receive multiple items\nis the sum of the CMSG_SPACE() values for their associated data\nlengths.  Raises OverflowError if length is outside the permissible\nrange of values.",
            1
        )
    );
    return methods;
}

glob:priv definition = ModuleDefinition(
         "_socket",
         MODULE_DOC,
         module_functions(),
         ModuleHooks(execute=socket_exec),
         STATE_COUNT
     );

def:pub PyInit__socket -> ptr[PyObject] {
    return definition.initialize();
}
