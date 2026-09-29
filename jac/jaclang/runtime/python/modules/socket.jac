"""The functions of the _socket module: host, service and protocol lookups,
getaddrinfo() and getnameinfo(), address conversions, byte order, network
interfaces, ancillary-data sizes and the default timeout.

Derived from CPython 3.14.6 Modules/socketmodule.c; see ../LICENSE.cpython.
The Argument Clinic functions (ntohs ... if_indextoname, socket.close and
socket.__init__) have their _impl functions here and in socket_object; the
glue in bindings/clinic/socket.jac parses their arguments. Where the C
library has no gethostbyname_r() (macOS), the netdb lookups run under the
module's lock, as USE_GETHOSTBYNAME_LOCK has them.
"""
import from jaclang.runtime.python.cpython_api {
    jacpy_buffer_release,
    jacpy_bytes_address,
    jacpy_bytes_from_memory,
    jacpy_errno,
    jacpy_fs_text,
    jacpy_is_bytes,
    jacpy_is_tuple,
    jacpy_is_unicode,
    jacpy_memory_copy,
    jacpy_memory_zero,
    jacpy_release,
    jacpy_set_errno,
    NULL,
    Py_buffer,
    Py_BuildValue,
    Py_NewRef,
    Py_None,
    PyArg_ParseTuple,
    PyArg_ParseTupleAndKeywords,
    PyErr_Clear,
    PyErr_NoMemory,
    PyErr_Occurred,
    PyErr_SetFromErrno,
    PyErr_SetString,
    PyEval_RestoreThread,
    PyEval_SaveThread,
    PyExc_OSError,
    PyExc_OverflowError,
    PyExc_TypeError,
    PyExc_ValueError,
    PyIndex_Check,
    PyList_Append,
    PyList_New,
    PyLong_AsLong,
    PyLong_FromLong,
    PyLong_FromSize_t,
    PyLong_FromUnsignedLong,
    PyMem_Calloc,
    PyMem_Free,
    PyNumber_Index,
    PyObject,
    PyObject_GetBuffer,
    PyObject_Str,
    PySys_Audit,
    PySys_AuditTuple,
    PyThread_acquire_lock,
    PyThread_release_lock,
    PyTuple_Pack,
    PyTuple_Size,
    PyUnicode_AsEncodedString,
    PyUnicode_AsUTF8,
    PyUnicode_FSConverter,
    _Py_dup
}
import from jaclang.runtime.python.capi {
    boundary_failure,
    c_string_text,
    object_error
}
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.bindings.converters { convert_unsigned_int }
import from jaclang.runtime.python.modules.errno_constants {
    EAFNOSUPPORT,
    ECONNRESET,
    EINVAL,
    ENODEV,
    ENXIO
}
import from jaclang.runtime.python.modules.socket_constants {
    AF_INET,
    AF_INET6,
    AF_UNIX,
    AF_UNSPEC,
    AI_NUMERICHOST,
    AI_NUMERICSERV,
    IF_NAMESIZE,
    INET6_ADDRSTRLEN,
    NI_MAXHOST,
    NI_MAXSERV,
    SOCK_CLOEXEC,
    SOCK_DGRAM,
    SOCK_STREAM
}
import from jaclang.runtime.python.modules.socket_platform {
    HAS_GETHOSTBYNAME_R,
    HAS_SA_LEN,
    HAS_SOCK_CLOEXEC,
    PLATFORM,
    addrinfo,
    host_by_addr,
    host_by_name,
    host_error,
    set_host_name,
    sockaddr_family,
    store_sa_family,
    store_sa_len
}
import from jaclang.runtime.python.modules.socket_core {
    INT_MAX,
    INVALID_SOCKET,
    SOCK_ADDR_SIZE,
    SOCKADDR_IN6_SIZE,
    SOCKADDR_IN_SIZE,
    TIMEOUT_ERROR,
    close,
    hostent,
    htonl,
    htons,
    if_nameindex_record,
    new_sockobject,
    ntohl,
    ntohs,
    set_error,
    set_gaierror,
    set_herror,
    socket_error,
    socket_parse_timeout,
    socket_state,
    timeout_object
}
import from jaclang.runtime.python.modules.socket_address {
    free_addrbuf,
    freeaddrinfo,
    getaddrinfo,
    get_u16,
    make_ipv4_addr,
    make_ipv6_addr,
    makesockaddr,
    new_addrbuf,
    new_view,
    put_u32,
    setipaddr
}
import from jaclang.runtime.python.modules.socket_object {
    c_int,
    get_CMSG_LEN,
    get_CMSG_SPACE,
    set_inheritable_new,
    sock_close,
    sock_init
}

import from c {
    obj servent {
        has s_name: ptr[u8] = ptr[u8](),
            s_aliases: ptr = ptr(),
            s_port: i32 = 0,
            s_proto: ptr[u8] = ptr[u8]();
    }  obj protoent {
        has p_name: ptr[u8] = ptr[u8](),
            p_aliases: ptr = ptr(),
            p_proto: i32 = 0;
    }  def gethostname(name: ptr[u8], len: u64) -> i32;  def getservbyname(
        name: ptr[u8], proto: ptr[u8]
    ) -> ptr[servent];  def getservbyport(port: i32, proto: ptr[u8]) -> ptr[servent];  def getprotobyname(
        name: ptr[u8]
    ) -> ptr[protoent];  def socketpair(
        domain: i32, type: i32, protocol: i32, sv: ptr[i32]
    ) -> i32;  def inet_aton(cp: str, inp: ptr) -> i32;  def inet_ntoa(
        address: u32
    ) -> ptr[u8];  def inet_pton(af: i32, src: ptr[u8], dst: ptr) -> i32;  def inet_ntop(
        af: i32, src: ptr, dst: ptr[u8], size: u32
    ) -> ptr[u8];  def getnameinfo(
        addr: ptr,
        addrlen: u32,
        host: ptr[u8],
        hostlen: u32,
        serv: ptr[u8],
        servlen: u32,
        flags: i32
    ) -> i32;  def if_nameindex -> ptr[if_nameindex_record];  def if_freenameindex(
        ptr_: ptr[if_nameindex_record]
    );  def if_nametoindex(ifname: ptr[u8]) -> u32;  def if_indextoname(
        ifindex: u32, ifname: ptr[u8]
    ) -> ptr[u8];
    # Serializes the non-reentrant netdb lookups where the C library has no
    # gethostbyname_r(); process-wide, as the C module's netdb_lock is.
    glob netdb_lock: ptr = ptr();
    # socket_core's flag of the kernel's SOCK_CLOEXEC support.
    glob sock_cloexec_works: i32; glob:priv getaddrinfo_keywords: list[ptr[u8]] = [
             ptr[u8]("host"),
             ptr[u8]("port"),
             ptr[u8]("family"),
             ptr[u8]("type"),
             ptr[u8]("proto"),
             ptr[u8]("flags"),
             ptr[u8]()
         ];
}

glob:priv
     # The gethostbyname_r() buffer: its size, and the size of the struct
     # hostent it fills.
     HOST_BUFFER_SIZE: int = 16384,
     HOSTENT_SIZE: int = 32;

# ---------------------------------------------------------------------------
# Clinic converters of this module.

"""unicode_fs_encoded (PyUnicode_FSConverter): the bytes of a str encoded
with the filesystem encoding, or of a bytes-like object; a new reference
the _impl function releases."""
def convert_PyUnicode_FSConverter(
    value: ptr[PyObject], fname: str, label: str
) -> ptr[PyObject] {
    result = NULL;
    if PyUnicode_FSConverter(value, &mut result) == 0 {
        raise boundary_failure();
    }
    return result;
}

"""NET_IFINDEX: an unsigned int (_PyLong_UnsignedInt_Converter) outside
Windows."""
def convert__PyLong_NetIfindex_Converter(
    value: ptr[PyObject], fname: str, label: str
) -> u32 {
    return convert_unsigned_int(value);
}

# ---------------------------------------------------------------------------
# The Argument Clinic methods of the socket type.

"""socket.close()."""
def _socket_socket_close_impl(s: ptr[PyObject]) -> ptr[PyObject] {
    return sock_close(s);
}

"""socket.__init__(family=-1, type=-1, proto=-1, fileno=None)."""
def sock_initobj_impl(
    self: ptr[PyObject], family: i32, type: i32, proto: i32, fdobj: ptr[PyObject]
) -> i32 {
    return sock_init(self, family, type, proto, fdobj);
}

# ---------------------------------------------------------------------------
# Host names.

"""gethostname() -> string."""
def socket_gethostname(self: ptr[PyObject], unused: ptr[PyObject]) -> ptr[PyObject] {
    if PySys_AuditTuple("socket.gethostname", NULL) < 0 {
        return NULL;
    }
    buf = ptr[u8](PyMem_Calloc(1, u64(1024)));
    if not buf {
        return PyErr_NoMemory();
    }
    thread = PyEval_SaveThread();
    res = gethostname(buf, u64(1023));
    error = jacpy_errno();
    PyEval_RestoreThread(thread);
    result = NULL;
    if res < 0 {
        socket_error(int(error));
    } else {
        (buf + 1023).view(1)[0] = u8(0);
        result = jacpy_fs_text(ptr(buf));
    }
    PyMem_Free(ptr(buf));
    return result;
}

"""sethostname(name): a str (encoded with the filesystem encoding) or a
bytes object."""
def socket_sethostname(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    hnobj = NULL;
    flag = False;
    if PyArg_ParseTuple(args, "S:sethostname", &mut hnobj) == 0 {
        PyErr_Clear();
        if PyArg_ParseTuple(
            args, "O&:sethostname", ptr(PyUnicode_FSConverter), &mut hnobj
        )
            == 0 {
            return NULL;
        }
        flag = True;
    }
    if PySys_Audit("socket.sethostname", "(O)", hnobj) < 0 {
        if flag {
            jacpy_release(hnobj);
        }
        return NULL;
    }
    buf = new_view();
    res = -1;
    if buf {
        res = int(PyObject_GetBuffer(hnobj, buf, 0));
        if res == 0 {
            view = buf.view(1);
            res = int(set_host_name(ptr[u8](view[0].buf), int(view[0].length)));
        }
    }
    error = jacpy_errno();
    jacpy_buffer_release(buf);
    if flag {
        jacpy_release(hnobj);
    }
    if not buf {
        return NULL;
    }
    if res != 0 {
        return socket_error(int(error));
    }
    return Py_NewRef(Py_None);
}

"""gethostbyname(host) -> address: the IPv4 address of a host."""
def socket_gethostbyname(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    name = ptr[u8]();
    if PyArg_ParseTuple(args, "et:gethostbyname", ptr[u8]("idna"), &mut name) == 0 {
        return NULL;
    }
    ret = NULL;
    if PySys_Audit("socket.gethostbyname", "O", args) >= 0 {
        addrbuf = new_addrbuf();
        if addrbuf {
            if setipaddr(self, name, addrbuf, SOCKADDR_IN_SIZE, AF_INET) >= 0 {
                ret = make_ipv4_addr(addrbuf);
            }
            free_addrbuf(addrbuf);
        }
    }
    PyMem_Free(ptr(name));
    return ret;
}

"""gethost_common(): the (name, aliases, addresses) tuple of a lookup's
struct hostent, storing its first address in `addr` (of `alen` bytes)."""
def gethost_common(
    module: ptr[PyObject], h: ptr[hostent], addr: ptr[u8], alen: int, af: int
) -> ptr[PyObject] {
    if not h {
        # Let's get real error message to return.
        return set_herror(module, int(host_error()));
    }
    record = h.view(1);
    if int(record[0].h_addrtype) != af {
        jacpy_set_errno(i64(EAFNOSUPPORT));
        return PyErr_SetFromErrno(PyExc_OSError);
    }
    if af == AF_INET and alen < SOCKADDR_IN_SIZE {
        return NULL;
    }
    if af == AF_INET6 and alen < SOCKADDR_IN6_SIZE {
        return NULL;
    }
    name_list = PyList_New(0);
    if not name_list {
        return NULL;
    }
    addr_list = PyList_New(0);
    if not addr_list {
        jacpy_release(name_list);
        return NULL;
    }
    ok = True;
    # h_aliases can be NULL (SF #1511317).
    aliases = ptr[ptr[u8]](record[0].h_aliases);
    if aliases {
        index = 0;
        while ok {
            host_alias = (aliases + index).view(1)[0];
            if not host_alias {
                break;
            }
            tmp = c_string_text(host_alias);
            ok = bool(tmp) and PyList_Append(name_list, tmp) == 0;
            jacpy_release(tmp);
            index += 1;
        }
    }
    addresses = ptr[ptr[u8]](record[0].h_addr_list);
    sin = ptr[u8](PyMem_Calloc(1, u64(SOCKADDR_IN6_SIZE)));
    if not sin {
        PyErr_NoMemory();
        ok = False;
    }
    index = 0;
    while ok {
        host_address = (addresses + index).view(1)[0];
        if not host_address {
            break;
        }
        tmp = NULL;
        if af == AF_INET {
            jacpy_memory_zero(ptr(sin), i64(SOCKADDR_IN_SIZE));
            store_sa_family(sin, af);
            store_sa_len(sin, SOCKADDR_IN_SIZE);
            jacpy_memory_copy(ptr(sin + 4), ptr(host_address), 4);
            tmp = make_ipv4_addr(sin);
            if index == 0 and alen >= SOCKADDR_IN_SIZE {
                jacpy_memory_copy(ptr(addr), ptr(sin), i64(SOCKADDR_IN_SIZE));
            }
        } elif af == AF_INET6 {
            jacpy_memory_zero(ptr(sin), i64(SOCKADDR_IN6_SIZE));
            store_sa_family(sin, af);
            store_sa_len(sin, SOCKADDR_IN6_SIZE);
            jacpy_memory_copy(ptr(sin + 8), ptr(host_address), 16);
            tmp = make_ipv6_addr(sin);
            if index == 0 and alen >= SOCKADDR_IN6_SIZE {
                jacpy_memory_copy(ptr(addr), ptr(sin), i64(SOCKADDR_IN6_SIZE));
            }
        } else {
            # Can't happen.
            PyErr_SetString(PyExc_OSError, "unsupported address family");
            ok = False;
            break;
        }
        ok = bool(tmp) and PyList_Append(addr_list, tmp) == 0;
        jacpy_release(tmp);
        index += 1;
    }
    PyMem_Free(ptr(sin));
    rtn_tuple = NULL;
    if ok {
        name = c_string_text(record[0].h_name);
        if name {
            rtn_tuple = Py_BuildValue("NOO", name, name_list, addr_list);
        }
    }
    jacpy_release(name_list);
    jacpy_release(addr_list);
    return rtn_tuple;
}

"""A struct hostent and the buffer gethostbyname_r() fills it from; unused
by the non-reentrant lookups."""
def:priv new_host_space -> ptr[u8] {
    space = ptr[u8](PyMem_Calloc(1, u64(HOSTENT_SIZE + HOST_BUFFER_SIZE)));
    if not space {
        PyErr_NoMemory();
    }
    return space;
}

"""gethostbyname_ex(host) -> (name, aliaslist, addresslist)."""
def socket_gethostbyname_ex(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    name = ptr[u8]();
    if PyArg_ParseTuple(args, "et:gethostbyname_ex", ptr[u8]("idna"), &mut name) == 0 {
        return NULL;
    }
    ret = NULL;
    addr = new_addrbuf();
    space = new_host_space();
    if addr
        and space
        and PySys_Audit("socket.gethostbyname", "O", args) >= 0
        and setipaddr(self, name, addr, SOCK_ADDR_SIZE, AF_INET) >= 0 {
        thread = PyEval_SaveThread();
        if not HAS_GETHOSTBYNAME_R {
            PyThread_acquire_lock(netdb_lock, 1);
        }
        h = host_by_name(name, ptr(space), space + HOSTENT_SIZE, HOST_BUFFER_SIZE - 1);
        PyEval_RestoreThread(thread);
        # sockaddr_storage's family, read as a struct sockaddr's.
        ret = gethost_common(
            self, ptr[hostent](h), addr, SOCK_ADDR_SIZE, sockaddr_family(addr)
        );
        if not HAS_GETHOSTBYNAME_R {
            PyThread_release_lock(netdb_lock);
        }
    }
    PyMem_Free(ptr(space));
    free_addrbuf(addr);
    PyMem_Free(ptr(name));
    return ret;
}

"""gethostbyaddr(host) -> (name, aliaslist, addresslist)."""
def socket_gethostbyaddr(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    ip_num = ptr[u8]();
    if PyArg_ParseTuple(args, "et:gethostbyaddr", ptr[u8]("idna"), &mut ip_num) == 0 {
        return NULL;
    }
    ret = NULL;
    sa = new_addrbuf();
    space = new_host_space();
    if sa
        and space
        and PySys_Audit("socket.gethostbyaddr", "O", args) >= 0
        and setipaddr(self, ip_num, sa, SOCK_ADDR_SIZE, AF_UNSPEC) >= 0 {
        af = sockaddr_family(sa);
        ap = ptr[u8]();
        al = 0;
        if af == AF_INET {
            ap = sa + 4;
            al = 4;
        } elif af == AF_INET6 {
            ap = sa + 8;
            al = 16;
        } else {
            PyErr_SetString(PyExc_OSError, "unsupported address family");
        }
        if ap {
            thread = PyEval_SaveThread();
            if not HAS_GETHOSTBYNAME_R {
                PyThread_acquire_lock(netdb_lock, 1);
            }
            h = host_by_addr(
                ptr(ap), al, af, ptr(space), space + HOSTENT_SIZE, HOST_BUFFER_SIZE - 1
            );
            PyEval_RestoreThread(thread);
            ret = gethost_common(self, ptr[hostent](h), sa, SOCK_ADDR_SIZE, af);
            if not HAS_GETHOSTBYNAME_R {
                PyThread_release_lock(netdb_lock);
            }
        }
    }
    PyMem_Free(ptr(space));
    free_addrbuf(sa);
    PyMem_Free(ptr(ip_num));
    return ret;
}

# ---------------------------------------------------------------------------
# Services and protocols.

"""getservbyname(servicename[, protocolname]) -> port."""
def socket_getservbyname(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    name = ptr[u8]();
    proto = ptr[u8]();
    if PyArg_ParseTuple(args, "s|s:getservbyname", &mut name, &mut proto) == 0 {
        return NULL;
    }
    if PySys_Audit("socket.getservbyname", "ss", name, proto) < 0 {
        return NULL;
    }
    thread = PyEval_SaveThread();
    sp = getservbyname(name, proto);
    PyEval_RestoreThread(thread);
    if not sp {
        PyErr_SetString(PyExc_OSError, "service/proto not found");
        return NULL;
    }
    return PyLong_FromLong(i64(ntohs(int(sp.view(1)[0].s_port) & 0xFFFF)));
}

"""getservbyport(port[, protocolname]) -> service name."""
def socket_getservbyport(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    port = i32(0);
    proto = ptr[u8]();
    if PyArg_ParseTuple(args, "i|s:getservbyport", &mut port, &mut proto) == 0 {
        return NULL;
    }
    if port < 0 or port > 0xFFFF {
        PyErr_SetString(PyExc_OverflowError, "getservbyport: port must be 0-65535.");
        return NULL;
    }
    if PySys_Audit("socket.getservbyport", "is", port, proto) < 0 {
        return NULL;
    }
    thread = PyEval_SaveThread();
    sp = getservbyport(i32(htons(int(port))), proto);
    PyEval_RestoreThread(thread);
    if not sp {
        PyErr_SetString(PyExc_OSError, "port/proto not found");
        return NULL;
    }
    return c_string_text(sp.view(1)[0].s_name);
}

"""getprotobyname(name) -> protocol number."""
def socket_getprotobyname(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    name = ptr[u8]();
    if PyArg_ParseTuple(args, "s:getprotobyname", &mut name) == 0 {
        return NULL;
    }
    thread = PyEval_SaveThread();
    sp = getprotobyname(name);
    PyEval_RestoreThread(thread);
    if not sp {
        PyErr_SetString(PyExc_OSError, "protocol not found");
        return NULL;
    }
    return PyLong_FromLong(i64(sp.view(1)[0].p_proto));
}

# ---------------------------------------------------------------------------
# Descriptors.

"""A socket descriptor argument: PyLong_AsSocket_t(), a C int."""
def:priv socket_fd_of(value: ptr[PyObject]) -> int {
    fd = PyLong_AsLong(value);
    if fd == -1 {
        return -1;
    }
    return int(c_int(int(fd)));
}

"""close(fd): close a socket descriptor; ECONNRESET is not an error."""
def socket_close(self: ptr[PyObject], fdobj: ptr[PyObject]) -> ptr[PyObject] {
    fd = socket_fd_of(fdobj);
    if fd == -1 and PyErr_Occurred() {
        return NULL;
    }
    thread = PyEval_SaveThread();
    res = close(i32(fd));
    error = jacpy_errno();
    PyEval_RestoreThread(thread);
    # bpo-30319: the peer can already have closed the connection.
    if res < 0 and error != ECONNRESET {
        return socket_error(int(error));
    }
    return Py_NewRef(Py_None);
}

"""dup(fd) -> fd: a non-inheritable duplicate of a socket descriptor."""
def socket_dup(self: ptr[PyObject], fdobj: ptr[PyObject]) -> ptr[PyObject] {
    fd = socket_fd_of(fdobj);
    if fd == -1 and PyErr_Occurred() {
        return NULL;
    }
    newfd = _Py_dup(i32(fd));
    if newfd == INVALID_SOCKET {
        return NULL;
    }
    newfdobj = PyLong_FromLong(i64(newfd));
    if not newfdobj {
        close(newfd);
    }
    return newfdobj;
}

"""socketpair([family[, type[, proto]]]) -> (socket, socket); AF_UNIX by
default."""
def socket_socketpair(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    family = i32(AF_UNIX);
    type = i32(SOCK_STREAM);
    proto = i32(0);
    if PyArg_ParseTuple(args, "|iii:socketpair", &mut family, &mut type, &mut proto)
        == 0 {
        return NULL;
    }
    sv = ptr[i32](PyMem_Calloc(2, u64(4)));
    if not sv {
        return PyErr_NoMemory();
    }
    # Create a pair of socket descriptors.
    thread = PyEval_SaveThread();
    ret = i32(0);
    error = i64(0);
    if HAS_SOCK_CLOEXEC and sock_cloexec_works != 0 {
        ret = socketpair(family, i32(int(type) | SOCK_CLOEXEC), proto, sv);
        error = jacpy_errno();
        if sock_cloexec_works == -1 {
            if ret >= 0 {
                sock_cloexec_works = i32(1);
            } elif error == EINVAL {
                # Linux older than 2.6.27 does not support SOCK_CLOEXEC.
                sock_cloexec_works = i32(0);
                ret = socketpair(family, type, proto, sv);
                error = jacpy_errno();
            }
        }
    } else {
        ret = socketpair(family, type, proto, sv);
        error = jacpy_errno();
    }
    PyEval_RestoreThread(thread);
    if ret < 0 {
        PyMem_Free(ptr(sv));
        return socket_error(int(error));
    }
    fd0 = sv.view(2)[0];
    fd1 = sv.view(2)[1];
    PyMem_Free(ptr(sv));
    s0 = NULL;
    s1 = NULL;
    res = NULL;
    if set_inheritable_new(fd0) >= 0 and set_inheritable_new(fd1) >= 0 {
        s0 = new_sockobject(self, fd0, int(family), int(type), int(proto));
        if s0 {
            s1 = new_sockobject(self, fd1, int(family), int(type), int(proto));
            if s1 {
                res = PyTuple_Pack(2, s0, s1);
            }
        }
    }
    if not res {
        if not s0 {
            close(fd0);
        }
        if not s1 {
            close(fd1);
        }
    }
    jacpy_release(s0);
    jacpy_release(s1);
    return res;
}

# ---------------------------------------------------------------------------
# Byte order.

def _socket_ntohs_impl(module: ptr[PyObject], x: u16) -> ptr[PyObject] {
    return PyLong_FromUnsignedLong(u64(ntohs(int(x))));
}

def _socket_ntohl_impl(module: ptr[PyObject], x: u32) -> ptr[PyObject] {
    return PyLong_FromUnsignedLong(u64(ntohl(int(x))));
}

def _socket_htons_impl(module: ptr[PyObject], x: u16) -> ptr[PyObject] {
    return PyLong_FromUnsignedLong(u64(htons(int(x))));
}

def _socket_htonl_impl(module: ptr[PyObject], x: u32) -> ptr[PyObject] {
    return PyLong_FromUnsignedLong(u64(htonl(int(x))));
}

# ---------------------------------------------------------------------------
# Address conversions.

"""inet_aton(ip_addr): the 32-bit packed form of a dotted IPv4 address."""
def _socket_inet_aton_impl(module: ptr[PyObject], ip_addr: str) -> ptr[PyObject] {
    buf = PyMem_Calloc(1, u64(4));
    if not buf {
        return PyErr_NoMemory();
    }
    result = NULL;
    if inet_aton(ip_addr, buf) != 0 {
        result = jacpy_bytes_from_memory(buf, 4);
    } else {
        PyErr_SetString(PyExc_OSError, "illegal IP address string passed to inet_aton");
    }
    PyMem_Free(buf);
    return result;
}

"""inet_ntoa(packed_ip): the dotted form of a 32-bit packed IPv4 address."""
def _socket_inet_ntoa_impl(
    module: ptr[PyObject], packed_ip: BufferArgument
) -> ptr[PyObject] {
    if packed_ip.size() != 4 {
        PyErr_SetString(PyExc_OSError, "packed IP wrong length for inet_ntoa");
        packed_ip.close();
        return NULL;
    }
    packed_addr = ptr[u32](packed_ip.address()).view(1)[0];
    packed_ip.close();
    return c_string_text(inet_ntoa(packed_addr));
}

"""inet_pton(af, ip) -> packed IP address string."""
def socket_inet_pton(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    af = i32(0);
    ip = ptr[u8]();
    if PyArg_ParseTuple(args, "is:inet_pton", &mut af, &mut ip) == 0 {
        return NULL;
    }
    packed = PyMem_Calloc(1, u64(16));
    if not packed {
        return PyErr_NoMemory();
    }
    retval = inet_pton(af, ip, packed);
    error = jacpy_errno();
    result = NULL;
    if retval < 0 {
        socket_error(int(error));
    } elif retval == 0 {
        PyErr_SetString(PyExc_OSError, "illegal IP address string passed to inet_pton");
    } elif af == AF_INET {
        result = jacpy_bytes_from_memory(packed, 4);
    } elif af == AF_INET6 {
        result = jacpy_bytes_from_memory(packed, 16);
    } else {
        PyErr_SetString(PyExc_OSError, "unknown address family");
    }
    PyMem_Free(packed);
    return result;
}

"""inet_ntop(af, packed_ip) -> string formatted IP address."""
def socket_inet_ntop(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    af = i32(0);
    packed_ip = new_view();
    if not packed_ip {
        return NULL;
    }
    if PyArg_ParseTuple(args, "iy*:inet_ntop", &mut af, packed_ip) == 0 {
        PyMem_Free(ptr(packed_ip));
        return NULL;
    }
    view = packed_ip.view(1);
    if af == AF_INET {
        if view[0].length != 4 {
            PyErr_SetString(
                PyExc_ValueError, "invalid length of packed IP address string"
            );
            jacpy_buffer_release(packed_ip);
            return NULL;
        }
    } elif af == AF_INET6 {
        if view[0].length != 16 {
            PyErr_SetString(
                PyExc_ValueError, "invalid length of packed IP address string"
            );
            jacpy_buffer_release(packed_ip);
            return NULL;
        }
    } else {
        object_error(PyExc_ValueError, f"unknown address family {af}");
        jacpy_buffer_release(packed_ip);
        return NULL;
    }
    ip = ptr[u8](PyMem_Calloc(1, u64(INET6_ADDRSTRLEN)));
    if not ip {
        jacpy_buffer_release(packed_ip);
        return PyErr_NoMemory();
    }
    # inet_ntop() NUL-terminates the result.
    retval = inet_ntop(af, view[0].buf, ip, u32(INET6_ADDRSTRLEN));
    error = jacpy_errno();
    jacpy_buffer_release(packed_ip);
    result = NULL;
    if not retval {
        socket_error(int(error));
    } else {
        result = c_string_text(retval);
    }
    PyMem_Free(ptr(ip));
    return result;
}

# ---------------------------------------------------------------------------
# getaddrinfo() and getnameinfo().

"""getaddrinfo(host, port[, family, type, proto, flags]) -> list of
(family, type, proto, canonname, sockaddr)."""
def socket_getaddrinfo(
    self: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    hobj = NULL;
    pobj = NULL;
    family = i32(AF_UNSPEC);
    socktype = i32(0);
    protocol = i32(0);
    flags = i32(0);
    if PyArg_ParseTupleAndKeywords(
        args,
        kwargs,
        "OO|iiii:getaddrinfo",
        ptr(addressof(getaddrinfo_keywords)),
        &mut hobj,
        &mut pobj,
        &mut family,
        &mut socktype,
        &mut protocol,
        &mut flags
    )
        == 0 {
        return NULL;
    }
    idna = NULL;
    hptr = ptr[u8]();
    if hobj == Py_None {
        hptr = ptr[u8]();
    } elif jacpy_is_unicode(hobj) != 0 {
        idna = PyUnicode_AsEncodedString(hobj, "idna", ptr[u8]());
        if not idna {
            return NULL;
        }
        hptr = ptr[u8](jacpy_bytes_address(idna));
    } elif jacpy_is_bytes(hobj) != 0 {
        hptr = ptr[u8](jacpy_bytes_address(hobj));
    } else {
        PyErr_SetString(
            PyExc_TypeError, "getaddrinfo() argument 1 must be string or None"
        );
        return NULL;
    }
    pstr = NULL;
    pptr = ptr[u8]();
    failed = False;
    if PyIndex_Check(pobj) != 0 {
        index = PyNumber_Index(pobj);
        if index {
            pstr = PyObject_Str(index);
            jacpy_release(index);
        }
        if pstr {
            pptr = PyUnicode_AsUTF8(pstr);
        }
        failed = not pptr;
    } elif jacpy_is_unicode(pobj) != 0 {
        pptr = PyUnicode_AsUTF8(pobj);
        failed = not pptr;
    } elif jacpy_is_bytes(pobj) != 0 {
        pptr = ptr[u8](jacpy_bytes_address(pobj));
    } elif pobj == Py_None {
        pptr = ptr[u8]();
    } else {
        PyErr_SetString(PyExc_OSError, "Int or String expected");
        failed = True;
    }
    # On OS X up to at least 10.8 getaddrinfo() crashes with AI_NUMERICSERV
    # and a NULL or "0" service.
    if not failed
        and PLATFORM == "darwin"
        and (int(flags) & AI_NUMERICSERV) != 0
        and (not pptr or (int(pptr.view(2)[0]) == 48 and int(pptr.view(2)[1]) == 0)) {
        pptr = ptr[u8]("00");
    }
    if not failed
        and PySys_Audit(
            "socket.getaddrinfo", "OOiii", hobj, pobj, family, socktype, protocol
        )
            < 0 {
        failed = True;
    }
    all = NULL;
    if not failed {
        hints = addrinfo(
            ai_family=family, ai_socktype=socktype, ai_protocol=protocol, ai_flags=flags
        );
        res0 = ptr();
        thread = PyEval_SaveThread();
        error = getaddrinfo(hptr, pptr, &mut hints, &mut res0);
        PyEval_RestoreThread(thread);
        if error != 0 {
            set_gaierror(self, int(error));
        } else {
            all = addrinfo_list(res0, int(protocol));
            freeaddrinfo(res0);
        }
    }
    jacpy_release(idna);
    jacpy_release(pstr);
    return all;
}

"""The (family, type, proto, canonname, sockaddr) list of an addrinfo chain."""
def:priv addrinfo_list(res0: ptr, protocol: int) -> ptr[PyObject] {
    all = PyList_New(0);
    if not all {
        return NULL;
    }
    res = res0;
    while res {
        record = ptr[addrinfo](res).view(1);
        addr = makesockaddr(
            i32(-1), ptr[u8](record[0].ai_addr), int(record[0].ai_addrlen), protocol
        );
        if not addr {
            jacpy_release(all);
            return NULL;
        }
        canonname = record[0].ai_canonname if record[0].ai_canonname else ptr[u8]("");
        single = Py_BuildValue(
            "iiisO",
            record[0].ai_family,
            record[0].ai_socktype,
            record[0].ai_protocol,
            canonname,
            addr
        );
        jacpy_release(addr);
        if not single {
            jacpy_release(all);
            return NULL;
        }
        status = PyList_Append(all, single);
        jacpy_release(single);
        if status != 0 {
            jacpy_release(all);
            return NULL;
        }
        res = record[0].ai_next;
    }
    return all;
}

"""getnameinfo(sockaddr, flags) -> (host, port)."""
def socket_getnameinfo(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    sa = NULL;
    flags = i32(0);
    if PyArg_ParseTuple(args, "Oi:getnameinfo", &mut sa, &mut flags) == 0 {
        return NULL;
    }
    if jacpy_is_tuple(sa) == 0 {
        PyErr_SetString(PyExc_TypeError, "getnameinfo() argument 1 must be a tuple");
        return NULL;
    }
    hostp = ptr[u8]();
    port = i32(0);
    flowinfo = u32(0);
    scope_id = u32(0);
    if PyArg_ParseTuple(
        sa,
        "si|II;getnameinfo(): illegal sockaddr argument",
        &mut hostp,
        &mut port,
        &mut flowinfo,
        &mut scope_id
    )
        == 0 {
        return NULL;
    }
    if flowinfo > u32(0xFFFFF) {
        PyErr_SetString(
            PyExc_OverflowError, "getnameinfo(): flowinfo must be 0-1048575."
        );
        return NULL;
    }
    if PySys_Audit("socket.getnameinfo", "(O)", sa) < 0 {
        return NULL;
    }
    buffers = ptr[u8](PyMem_Calloc(1, u64(NI_MAXHOST + NI_MAXSERV)));
    if not buffers {
        return PyErr_NoMemory();
    }
    hbuf = buffers;
    pbuf = buffers + NI_MAXHOST;
    # PyOS_snprintf(pbuf, sizeof(pbuf), "%d", port).
    digits = str(int(port)).encode("ascii");
    for i in range(len(digits)) {
        (pbuf + i).view(1)[0] = u8(digits[i]);
    }
    hints = addrinfo(
        ai_family=i32(AF_UNSPEC),
        ai_socktype=i32(SOCK_DGRAM),
        ai_flags=i32(AI_NUMERICHOST)
    );
    res = ptr();
    thread = PyEval_SaveThread();
    error = getaddrinfo(hostp, pbuf, &mut hints, &mut res);
    PyEval_RestoreThread(thread);
    ret = NULL;
    if error != 0 {
        res = ptr();
        set_gaierror(self, int(error));
    } else {
        ret = name_of_address(self, res, sa, flowinfo, scope_id, flags, hbuf, pbuf);
    }
    if res {
        freeaddrinfo(res);
    }
    PyMem_Free(ptr(buffers));
    return ret;
}

def:priv name_of_address(
    module: ptr[PyObject],
    res: ptr,
    sa: ptr[PyObject],
    flowinfo: u32,
    scope_id: u32,
    flags: i32,
    hbuf: ptr[u8],
    pbuf: ptr[u8]
) -> ptr[PyObject] {
    record = ptr[addrinfo](res).view(1);
    if record[0].ai_next {
        PyErr_SetString(PyExc_OSError, "sockaddr resolved to multiple addresses");
        return NULL;
    }
    if record[0].ai_family == AF_INET {
        if PyTuple_Size(sa) != 2 {
            PyErr_SetString(PyExc_OSError, "IPv4 sockaddr must be 2 tuple");
            return NULL;
        }
    } elif record[0].ai_family == AF_INET6 {
        sin6 = ptr[u8](record[0].ai_addr);
        put_u32(sin6, 4, htonl(int(flowinfo)));
        put_u32(sin6, 24, int(scope_id));
    }
    thread = PyEval_SaveThread();
    error = getnameinfo(
        record[0].ai_addr,
        record[0].ai_addrlen,
        hbuf,
        u32(NI_MAXHOST),
        pbuf,
        u32(NI_MAXSERV),
        flags
    );
    PyEval_RestoreThread(thread);
    if error != 0 {
        return set_gaierror(module, int(error));
    }
    name = c_string_text(hbuf);
    if not name {
        return NULL;
    }
    return Py_BuildValue("Ns", name, pbuf);
}

# ---------------------------------------------------------------------------
# The default timeout.

"""getdefaulttimeout() -> the default timeout of new sockets, or None."""
def socket_getdefaulttimeout(
    self: ptr[PyObject], ignored: ptr[PyObject]
) -> ptr[PyObject] {
    return timeout_object(socket_state(self).defaulttimeout);
}

"""setdefaulttimeout(timeout): the default timeout of new sockets."""
def socket_setdefaulttimeout(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    timeout = socket_parse_timeout(arg);
    if timeout == TIMEOUT_ERROR {
        return NULL;
    }
    socket_state(self).defaulttimeout = timeout;
    return Py_NewRef(Py_None);
}

# ---------------------------------------------------------------------------
# Network interfaces.

"""if_nameindex() -> [(index, name), ...]."""
def socket_if_nameindex(self: ptr[PyObject], arg: ptr[PyObject]) -> ptr[PyObject] {
    list = PyList_New(0);
    if not list {
        return NULL;
    }
    ni = if_nameindex();
    if not ni {
        PyErr_SetFromErrno(PyExc_OSError);
        jacpy_release(list);
        return NULL;
    }
    i = 0;
    while i < INT_MAX {
        record = (ni + i).view(1);
        if record[0].if_index == 0 {
            break;
        }
        name = jacpy_fs_text(ptr(record[0].if_name));
        ni_tuple = NULL;
        if name {
            ni_tuple = Py_BuildValue("IN", record[0].if_index, name);
        }
        if not ni_tuple or PyList_Append(list, ni_tuple) == -1 {
            jacpy_release(ni_tuple);
            jacpy_release(list);
            if_freenameindex(ni);
            return NULL;
        }
        jacpy_release(ni_tuple);
        i += 1;
    }
    if_freenameindex(ni);
    return list;
}

"""if_nametoindex(if_name) -> the interface's index."""
def _socket_if_nametoindex_impl(
    module: ptr[PyObject], oname: ptr[PyObject]
) -> ptr[PyObject] {
    # In case if_nametoindex() does not set errno.
    jacpy_set_errno(i64(ENODEV));
    index = if_nametoindex(ptr[u8](jacpy_bytes_address(oname)));
    error = jacpy_errno();
    jacpy_release(oname);
    if index == 0 {
        return socket_error(int(error));
    }
    return PyLong_FromUnsignedLong(u64(index));
}

"""if_indextoname(if_index) -> the interface's name."""
def _socket_if_indextoname_impl(module: ptr[PyObject], index: u32) -> ptr[PyObject] {
    name = ptr[u8](PyMem_Calloc(1, u64(IF_NAMESIZE + 1)));
    if not name {
        return PyErr_NoMemory();
    }
    # In case if_indextoname() does not set errno.
    jacpy_set_errno(i64(ENXIO));
    result = NULL;
    if not if_indextoname(index, name) {
        socket_error(int(jacpy_errno()));
    } else {
        result = jacpy_fs_text(ptr(name));
    }
    PyMem_Free(ptr(name));
    return result;
}

# ---------------------------------------------------------------------------
# Ancillary-data sizes.

"""CMSG_LEN(length) -> control message length."""
def socket_CMSG_LEN(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    length = i64(0);
    if PyArg_ParseTuple(args, "n:CMSG_LEN", &mut length) == 0 {
        return NULL;
    }
    result = get_CMSG_LEN(int(length)) if length >= 0 else -1;
    if result < 0 {
        PyErr_SetString(PyExc_OverflowError, "CMSG_LEN() argument out of range");
        return NULL;
    }
    return PyLong_FromSize_t(u64(result));
}

"""CMSG_SPACE(length) -> buffer size."""
def socket_CMSG_SPACE(self: ptr[PyObject], args: ptr[PyObject]) -> ptr[PyObject] {
    length = i64(0);
    if PyArg_ParseTuple(args, "n:CMSG_SPACE", &mut length) == 0 {
        return NULL;
    }
    result = get_CMSG_SPACE(int(length)) if length >= 0 else -1;
    if result < 0 {
        PyErr_SetString(PyExc_OverflowError, "CMSG_SPACE() argument out of range");
        return NULL;
    }
    return PyLong_FromSize_t(u64(result));
}
