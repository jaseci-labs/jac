import from c {
    obj maybe_idna {
        has obj_: ptr[PyObject] = NULL,
            buf: ptr[u8] = ptr[u8]();
    }  def inet_pton(af: i32, src: ptr[u8], dst: ptr) -> i32;  def inet_ntop(
        af: i32, src: ptr, dst: ptr[u8], size: u32
    ) -> ptr[u8];  def getaddrinfo(
        host: ptr[u8], service: ptr[u8], hints: &mut addrinfo, res: &mut ptr
    ) -> i32;  def freeaddrinfo(res: ptr);
}

glob:priv SA_DATA_OFFSET: int = 2,
     SA_DATA_SIZE: int = 14,
     SUN_PATH_OFFSET: int = 2,
     IFREQ_SIZE: int = 40,
     IFNAMSIZ: int = 16,
     IFR_IFINDEX_OFFSET: int = 16,
     SOCKADDR_NL_SIZE: int = 12,
     SOCKADDR_QRTR_SIZE: int = 12,
     SOCKADDR_VM_SIZE: int = 16,
     SOCKADDR_LL_SIZE: int = 20,
     SOCKADDR_TIPC_SIZE: int = 16,
     SOCKADDR_CAN_SIZE: int = 24,
     SOCKADDR_ALG_SIZE: int = 88,
     SALG_TYPE_SIZE: int = 14,
     SALG_NAME_SIZE: int = 64,
     SOCKADDR_CTL_SIZE: int = 32,
     CTL_INFO_SIZE: int = 100,
     MAX_KCTL_NAME: int = 96;

def put_u8(address: ptr[u8], offset: int, value: int);

def get_u8(address: ptr[u8], offset: int) -> int;

def put_u16(address: ptr[u8], offset: int, value: int);

def get_u16(address: ptr[u8], offset: int) -> int;

def put_u32(address: ptr[u8], offset: int, value: int);

def get_u32(address: ptr[u8], offset: int) -> int;

def get_i32(address: ptr[u8], offset: int) -> int;

def put_u64(address: ptr[u8], offset: int, value: int);

def get_u64(address: ptr[u8], offset: int) -> int;

def new_addrbuf -> ptr[u8];

def free_addrbuf(address: ptr[u8]);

def new_view -> ptr[Py_buffer];

def c_string_is(address: ptr[u8], text: str) -> bool;

def c_string_has(address: ptr[u8], character: int) -> bool;

def copy_name(target: ptr[u8], source: ptr[u8], size: int);

def type_name_500(value: ptr[PyObject]) -> str;

def setipaddr(
    module: ptr[PyObject], name: ptr[u8], addr_ret: ptr[u8], addr_ret_size: int, af: int
) -> int;

def format_address(family: int, source: ptr, size: int) -> ptr[PyObject];

def make_ipv4_addr(addr: ptr[u8]) -> ptr[PyObject];

def make_ipv6_addr(addr: ptr[u8]) -> ptr[PyObject];

def interface_name_of(sockfd: i32, index: int, ifr: ptr[u8]) -> ptr[u8];

def makesockaddr(
    sockfd: i32, addr: ptr[u8], addrlen: int, proto: int
) -> ptr[PyObject];

def idna_converter(value: ptr[PyObject], arg: ptr) -> i32;

def new_idna -> ptr[maybe_idna];

def free_idna(record: ptr[maybe_idna]);

def require_tuple(args: ptr[PyObject], message: str) -> bool;

def overflow_message(message: str);

def interface_index(s: ptr[PySocketSockObject], name: ptr[u8]) -> int;

def can_interface_index(s: ptr[PySocketSockObject], interface: ptr[PyObject]) -> int;

def getsockaddrarg(
    s: ptr[PySocketSockObject], args: ptr[PyObject], addrbuf: ptr[u8], caller: str
) -> int;

def:priv unix_address(
    s: ptr[PySocketSockObject], args: ptr[PyObject], addrbuf: ptr[u8]
) -> int;

def:priv inet_address(
    s: ptr[PySocketSockObject], args: ptr[PyObject], addrbuf: ptr[u8], caller: str
) -> int;

def:priv inet6_address(
    s: ptr[PySocketSockObject], args: ptr[PyObject], addrbuf: ptr[u8], caller: str
) -> int;

def:priv packet_address(
    s: ptr[PySocketSockObject], args: ptr[PyObject], addrbuf: ptr[u8], caller: str
) -> int;

def:priv tipc_address(args: ptr[PyObject], addrbuf: ptr[u8], caller: str) -> int;

def:priv can_address(
    s: ptr[PySocketSockObject], args: ptr[PyObject], addrbuf: ptr[u8], caller: str
) -> int;

def:priv system_address(
    s: ptr[PySocketSockObject], args: ptr[PyObject], addrbuf: ptr[u8], caller: str
) -> int;

def:priv alg_address(args: ptr[PyObject], addrbuf: ptr[u8], caller: str) -> int;

def getsockaddrlen(s: ptr[PySocketSockObject]) -> int;

impl put_u8(address: ptr[u8], offset: int, value: int) {
    (address + offset).view(1)[0] = u8(value & 0xFF);
}

impl get_u8(address: ptr[u8], offset: int) -> int {
    return int((address + offset).view(1)[0]);
}

impl put_u16(address: ptr[u8], offset: int, value: int) {
    ptr[u16](address + offset).view(1)[0] = u16(value & 0xFFFF);
}

impl get_u16(address: ptr[u8], offset: int) -> int {
    return int(ptr[u16](address + offset).view(1)[0]);
}

impl put_u32(address: ptr[u8], offset: int, value: int) {
    ptr[u32](address + offset).view(1)[0] = u32(value & 0xFFFFFFFF);
}

impl get_u32(address: ptr[u8], offset: int) -> int {
    return int(ptr[u32](address + offset).view(1)[0]);
}

impl get_i32(address: ptr[u8], offset: int) -> int {
    return int(ptr[i32](address + offset).view(1)[0]);
}

impl put_u64(address: ptr[u8], offset: int, value: int) {
    ptr[u64](address + offset).view(1)[0] = u64(value);
}

impl get_u64(address: ptr[u8], offset: int) -> int {
    return int(ptr[u64](address + offset).view(1)[0]);
}

impl new_addrbuf -> ptr[u8] {
    address = ptr[u8](PyMem_Calloc(1, u64(SOCK_ADDR_SIZE)));
    if not address {
        PyErr_NoMemory();
    }
    return address;
}

impl free_addrbuf(address: ptr[u8]) {
    PyMem_Free(ptr(address));
}

impl new_view -> ptr[Py_buffer] {
    view = ptr[Py_buffer](PyMem_Calloc(1, PY_BUFFER_SIZE));
    if not view {
        PyErr_NoMemory();
    }
    return view;
}

impl c_string_is(address: ptr[u8], text: str) -> bool {
    length = len(text);
    characters = address.view(length + 1);
    for i in range(length) {
        if int(characters[i]) != ord(text[i]) {
            return False;
        }
    }
    return int(characters[length]) == 0;
}

impl c_string_has(address: ptr[u8], character: int) -> bool {
    index = 0;
    while True {
        byte = int((address + index).view(1)[0]);
        if byte == 0 {
            return False;
        }
        if byte == character {
            return True;
        }
        index += 1;
    }
    return False;
}

impl copy_name(target: ptr[u8], source: ptr[u8], size: int) {
    length = c_string_length(source, size);
    jacpy_memory_copy(ptr(target), ptr(source), i64(length));
    jacpy_memory_zero(ptr(target + length), i64(size - length));
    (target + (size - 1)).view(1)[0] = u8(0);
}

impl type_name_500(value: ptr[PyObject]) -> str {
    name = c_string_text(object_type(value).view(1)[0].tp_name, 500);
    if not name {
        return "";
    }
    text = text_value(name);
    jacpy_release(name);
    return text;
}

impl setipaddr(
    module: ptr[PyObject], name: ptr[u8], addr_ret: ptr[u8], addr_ret_size: int, af: int
) -> int {
    res = ptr();
    jacpy_memory_zero(ptr(addr_ret), i64(SA_DATA_OFFSET + SA_DATA_SIZE));
    if int(name.view(1)[0]) == 0 {
        hints = addrinfo(
            ai_family=i32(af), ai_socktype=i32(SOCK_DGRAM), ai_flags=i32(AI_PASSIVE)
        );
        thread = PyEval_SaveThread();
        error = getaddrinfo(ptr[u8](), ptr[u8]("0"), &mut hints, &mut res);
        PyEval_RestoreThread(thread);

        if error != 0 {
            set_gaierror(module, int(error));
            return -1;
        }
        record = ptr[addrinfo](res).view(1);
        siz = 0;
        if record[0].ai_family == AF_INET {
            siz = 4;
        } elif record[0].ai_family == AF_INET6 {
            siz = 16;
        } else {
            freeaddrinfo(res);
            PyErr_SetString(PyExc_OSError, ptr[u8]("unsupported address family"));
            return -1;
        }
        if record[0].ai_next {
            freeaddrinfo(res);
            PyErr_SetString(
                PyExc_OSError, ptr[u8]("wildcard resolved to multiple address")
            );
            return -1;
        }
        size = addr_ret_size;
        if int(record[0].ai_addrlen) < size {
            size = int(record[0].ai_addrlen);
        }
        jacpy_memory_copy(ptr(addr_ret), record[0].ai_addr, i64(size));
        freeaddrinfo(res);
        return siz;
    }

    if c_string_is(name, "255.255.255.255") or c_string_is(name, "<broadcast>") {
        if af != AF_INET and af != AF_UNSPEC {
            PyErr_SetString(PyExc_OSError, ptr[u8]("address family mismatched"));
            return -1;
        }
        jacpy_memory_zero(ptr(addr_ret), i64(SOCKADDR_IN_SIZE));
        store_sa_family(addr_ret, AF_INET);
        store_sa_len(addr_ret, SOCKADDR_IN_SIZE);
        put_u32(addr_ret, 4, INADDR_BROADCAST);
        return 4;
    }

    if af == AF_UNSPEC or af == AF_INET {
        jacpy_memory_zero(ptr(addr_ret), i64(SOCKADDR_IN_SIZE));
        if inet_pton(i32(AF_INET), name, ptr(addr_ret + 4)) > 0 {
            store_sa_family(addr_ret, AF_INET);
            store_sa_len(addr_ret, SOCKADDR_IN_SIZE);
            return 4;
        }
    }

    if (af == AF_UNSPEC or af == AF_INET6) and not c_string_has(name, 37) {
        jacpy_memory_zero(ptr(addr_ret), i64(SOCKADDR_IN6_SIZE));
        if inet_pton(i32(AF_INET6), name, ptr(addr_ret + 8)) > 0 {
            store_sa_family(addr_ret, AF_INET6);
            store_sa_len(addr_ret, SOCKADDR_IN6_SIZE);
            return 16;
        }
    }

    hints = addrinfo(ai_family=i32(af));
    thread = PyEval_SaveThread();
    error = getaddrinfo(name, ptr[u8](), &mut hints, &mut res);
    PyEval_RestoreThread(thread);
    if error != 0 {
        set_gaierror(module, int(error));
        return -1;
    }
    record = ptr[addrinfo](res).view(1);
    size = addr_ret_size;
    if int(record[0].ai_addrlen) < size {
        size = int(record[0].ai_addrlen);
    }
    jacpy_memory_copy(ptr(addr_ret), record[0].ai_addr, i64(size));
    freeaddrinfo(res);
    family = sockaddr_family(addr_ret);
    if family == AF_INET {
        return 4;
    }
    if family == AF_INET6 {
        return 16;
    }
    PyErr_SetString(PyExc_OSError, ptr[u8]("unknown address family"));
    return -1;
}

impl format_address(family: int, source: ptr, size: int) -> ptr[PyObject] {
    buffer = ptr[u8](PyMem_Calloc(1, u64(size)));
    if not buffer {
        return PyErr_NoMemory();
    }
    result = NULL;
    if inet_ntop(i32(family), source, buffer, u32(size)) {
        result = c_string_text(buffer);
    } else {
        socket_error(int(jacpy_errno()));
    }
    PyMem_Free(ptr(buffer));
    return result;
}

impl make_ipv4_addr(addr: ptr[u8]) -> ptr[PyObject] {
    return format_address(AF_INET, ptr(addr + 4), INET_ADDRSTRLEN);
}

impl make_ipv6_addr(addr: ptr[u8]) -> ptr[PyObject] {
    return format_address(AF_INET6, ptr(addr + 8), INET6_ADDRSTRLEN);
}

impl interface_name_of(sockfd: i32, index: int, ifr: ptr[u8]) -> ptr[u8] {
    if index != 0 {
        ptr[i32](ifr + IFR_IFINDEX_OFFSET).view(1)[0] = i32(index);
        if ioctl(sockfd, u64(SIOCGIFNAME), ifr) == 0 {
            return ifr;
        }
    }
    return ptr[u8]("");
}

impl makesockaddr(
    sockfd: i32, addr: ptr[u8], addrlen: int, proto: int
) -> ptr[PyObject] {
    if addrlen == 0 {
        return Py_NewRef(Py_None);
    }
    family = sockaddr_family(addr);
    if family == AF_INET {
        addrobj = make_ipv4_addr(addr);
        if not addrobj {
            return NULL;
        }
        ret = Py_BuildValue(ptr[u8]("Oi"), addrobj, i32(ntohs(get_u16(addr, 2))));
        jacpy_release(addrobj);
        return ret;
    }
    if family == AF_UNIX {
        path = addr + SUN_PATH_OFFSET;
        linuxaddrlen = addrlen - SUN_PATH_OFFSET;
        if HAS_ABSTRACT_UNIX and linuxaddrlen > 0 and int(path.view(1)[0]) == 0 {
            return jacpy_bytes_from_memory(ptr(path), i64(linuxaddrlen));
        }

        return jacpy_fs_text(ptr(path));
    }
    if HAS_NETLINK and family == AF_NETLINK {
        return Py_BuildValue(
            ptr[u8]("II"), u32(get_u32(addr, 4)), u32(get_u32(addr, 8))
        );
    }
    if HAS_QIPCRTR and family == AF_QIPCRTR {
        return Py_BuildValue(
            ptr[u8]("II"), u32(get_u32(addr, 4)), u32(get_u32(addr, 8))
        );
    }
    if HAS_VSOCK and family == AF_VSOCK {
        return Py_BuildValue(
            ptr[u8]("II"), u32(get_u32(addr, 8)), u32(get_u32(addr, 4))
        );
    }
    if family == AF_INET6 {
        addrobj = make_ipv6_addr(addr);
        if not addrobj {
            return NULL;
        }
        ret = Py_BuildValue(
            ptr[u8]("OiII"),
            addrobj,
            i32(ntohs(get_u16(addr, 2))),
            u32(ntohl(get_u32(addr, 4))),
            u32(get_u32(addr, 24))
        );
        jacpy_release(addrobj);
        return ret;
    }
    if HAS_PACKET and family == AF_PACKET {
        ifr = ptr[u8](PyMem_Calloc(1, u64(IFREQ_SIZE)));
        if not ifr {
            return PyErr_NoMemory();
        }

        ifname = interface_name_of(sockfd, get_i32(addr, 4), ifr);
        ret = Py_BuildValue(
            ptr[u8]("shbhy#"),
            ifname,
            i32(ntohs(get_u16(addr, 2))),
            i32(get_u8(addr, 10)),
            i32(get_u16(addr, 8)),
            ptr(addr + 12),
            i64(get_u8(addr, 11))
        );
        PyMem_Free(ptr(ifr));
        return ret;
    }
    if HAS_TIPC and family == AF_TIPC {
        addrtype = get_u8(addr, 2);

        scope = get_u8(addr, 3);
        if scope >= 128 {
            scope = scope - 256;
        }
        scope_bits = u32(scope & 0xFFFFFFFF);
        if addrtype == TIPC_ADDR_NAMESEQ {
            return Py_BuildValue(
                ptr[u8]("IIIII"),
                u32(addrtype),
                u32(get_u32(addr, 4)),
                u32(get_u32(addr, 8)),
                u32(get_u32(addr, 12)),
                scope_bits
            );
        }
        if addrtype == TIPC_ADDR_NAME {
            return Py_BuildValue(
                ptr[u8]("IIIII"),
                u32(addrtype),
                u32(get_u32(addr, 4)),
                u32(get_u32(addr, 8)),
                u32(get_u32(addr, 8)),
                scope_bits
            );
        }
        if addrtype == TIPC_ADDR_ID {
            return Py_BuildValue(
                ptr[u8]("IIIII"),
                u32(addrtype),
                u32(get_u32(addr, 8)),
                u32(get_u32(addr, 4)),
                u32(0),
                scope_bits
            );
        }
        PyErr_SetString(PyExc_ValueError, ptr[u8]("Invalid address type"));
        return NULL;
    }
    if HAS_CAN and family == AF_CAN {
        ifr = ptr[u8](PyMem_Calloc(1, u64(IFREQ_SIZE)));
        if not ifr {
            return PyErr_NoMemory();
        }

        name = jacpy_fs_text(ptr(interface_name_of(sockfd, get_i32(addr, 4), ifr)));
        PyMem_Free(ptr(ifr));
        if not name {
            return NULL;
        }
        ret = NULL;
        if HAS_CAN_ISOTP and proto == CAN_ISOTP {
            ret = Py_BuildValue(
                ptr[u8]("Okk"), name, u64(get_u32(addr, 8)), u64(get_u32(addr, 12))
            );
        } elif HAS_CAN_J1939 and proto == CAN_J1939 {
            ret = Py_BuildValue(
                ptr[u8]("OKIB"),
                name,
                u64(get_u64(addr, 8)),
                u32(get_u32(addr, 16)),
                i32(get_u8(addr, 20))
            );
        } else {
            ret = Py_BuildValue(ptr[u8]("(O)"), name);
        }
        jacpy_release(name);
        return ret;
    }
    if HAS_SYSTEM and family == PF_SYSTEM {
        if proto == SYSPROTO_CONTROL {
            return Py_BuildValue(
                ptr[u8]("(II)"), u32(get_u32(addr, 4)), u32(get_u32(addr, 8))
            );
        }
        PyErr_SetString(PyExc_ValueError, ptr[u8]("Invalid address type"));
        return NULL;
    }
    if HAS_ALG and family == AF_ALG {
        salg_type = addr + 2;
        salg_name = addr + 24;
        return Py_BuildValue(
            ptr[u8]("s#s#HH"),
            salg_type,
            i64(c_string_length(salg_type, SALG_TYPE_SIZE)),
            salg_name,
            i64(c_string_length(salg_name, SALG_NAME_SIZE)),
            i32(get_u32(addr, 16) & 0xFFFF),
            i32(get_u32(addr, 20) & 0xFFFF)
        );
    }

    return Py_BuildValue(
        ptr[u8]("iy#"), i32(family), ptr(addr + SA_DATA_OFFSET), i64(SA_DATA_SIZE)
    );
}

impl idna_converter(value: ptr[PyObject], arg: ptr) -> i32 {
    data = ptr[maybe_idna](arg).view(1);
    if not value {
        jacpy_release(data[0].obj_);
        data[0].obj_ = NULL;
        return i32(1);
    }
    data[0].obj_ = NULL;
    length = -1;
    if jacpy_is_bytes(value) != 0 or jacpy_is_bytearray(value) != 0 {
        data[0].buf = ptr[u8](jacpy_bytes_address(value));
        length = int(jacpy_bytes_length(value));
    } elif jacpy_is_unicode(value) != 0 {
        if jacpy_unicode_ascii(value) != 0 {
            data[0].buf = ptr[u8](jacpy_unicode_data(value));
            length = int(jacpy_unicode_size(value));
        } else {
            obj2 = PyUnicode_AsEncodedString(value, ptr[u8]("idna"), ptr[u8]());
            if not obj2 {
                PyErr_SetString(
                    PyExc_TypeError, ptr[u8]("encoding of hostname failed")
                );
                return i32(0);
            }
            data[0].obj_ = obj2;
            data[0].buf = ptr[u8](jacpy_bytes_address(obj2));
            length = int(jacpy_bytes_length(obj2));
        }
    } else {
        type_name = c_string_text(object_type(value).view(1)[0].tp_name);
        if type_name {
            object_error(
                PyExc_TypeError,
                f"str, bytes or bytearray expected, not {text_value(type_name)}"
            );
            jacpy_release(type_name);
        }
        return i32(0);
    }
    if c_string_length(data[0].buf) != length {
        jacpy_release(data[0].obj_);
        data[0].obj_ = NULL;
        PyErr_SetString(
            PyExc_TypeError, ptr[u8]("host name must not contain null character")
        );
        return i32(0);
    }
    return Py_CLEANUP_SUPPORTED;
}

impl new_idna -> ptr[maybe_idna] {
    record = ptr[maybe_idna](PyMem_Calloc(1, u64(16)));
    if not record {
        PyErr_NoMemory();
    }
    return record;
}

impl free_idna(record: ptr[maybe_idna]) {
    if record {
        jacpy_release(record.view(1)[0].obj_);
        PyMem_Free(ptr(record));
    }
}

impl require_tuple(args: ptr[PyObject], message: str) -> bool {
    if jacpy_is_tuple(args) != 0 {
        return True;
    }
    object_error(PyExc_TypeError, f"{message}, not {type_name_500(args)}");
    return False;
}

impl overflow_message(message: str) {
    if PyErr_ExceptionMatches(PyExc_OverflowError) != 0 {
        object_error(PyExc_OverflowError, message);
    }
}

impl interface_index(s: ptr[PySocketSockObject], name: ptr[u8]) -> int {
    ifr = ptr[u8](PyMem_Calloc(1, u64(IFREQ_SIZE)));
    if not ifr {
        PyErr_NoMemory();
        return -1;
    }
    copy_name(ifr, name, IFNAMSIZ);
    index = -1;
    if ioctl(get_sock_fd(s), u64(SIOCGIFINDEX), ifr) < 0 {
        set_error();
    } else {
        index = get_i32(ifr, IFR_IFINDEX_OFFSET);
    }
    PyMem_Free(ptr(ifr));
    return index;
}

impl can_interface_index(s: ptr[PySocketSockObject], interface: ptr[PyObject]) -> int {
    length = int(jacpy_bytes_length(interface));
    if length == 0 {
        return 0;
    }
    if length < IFNAMSIZ {
        return interface_index(s, ptr[u8](jacpy_bytes_address(interface)));
    }
    PyErr_SetString(PyExc_OSError, ptr[u8]("AF_CAN interface name too long"));
    return -1;
}

impl getsockaddrarg(
    s: ptr[PySocketSockObject], args: ptr[PyObject], addrbuf: ptr[u8], caller: str
) -> int {
    family = sock_family(s);
    if family == AF_UNIX {
        return unix_address(s, args, addrbuf);
    }
    if HAS_NETLINK and family == AF_NETLINK {
        jacpy_memory_zero(ptr(addrbuf), i64(SOCKADDR_NL_SIZE));
        if not require_tuple(args, f"{caller}(): AF_NETLINK address must be tuple") {
            return -1;
        }
        pid = u32(0);
        groups = u32(0);
        if PyArg_ParseTuple(
            args,
            ptr[u8]("II;AF_NETLINK address must be a pair (pid, groups)"),
            &mut pid,
            &mut groups
        )
            == 0 {
            return -1;
        }
        put_u16(addrbuf, 0, AF_NETLINK);
        put_u32(addrbuf, 4, int(pid));
        put_u32(addrbuf, 8, int(groups));
        return SOCKADDR_NL_SIZE;
    }
    if HAS_QIPCRTR and family == AF_QIPCRTR {
        jacpy_memory_zero(ptr(addrbuf), i64(SOCKADDR_QRTR_SIZE));
        if not require_tuple(
            args, "getsockaddrarg: AF_QIPCRTR address must be tuple"
        ) {
            return -1;
        }
        node_id = u32(0);
        port = u32(0);
        if PyArg_ParseTuple(args, ptr[u8]("II:getsockaddrarg"), &mut node_id, &mut port)
            == 0 {
            return -1;
        }
        put_u16(addrbuf, 0, AF_QIPCRTR);
        put_u32(addrbuf, 4, int(node_id));
        put_u32(addrbuf, 8, int(port));
        return SOCKADDR_QRTR_SIZE;
    }
    if HAS_VSOCK and family == AF_VSOCK {
        jacpy_memory_zero(ptr(addrbuf), i64(SOCKADDR_VM_SIZE));
        if not require_tuple(args, "getsockaddrarg: AF_VSOCK address must be tuple") {
            return -1;
        }
        cid = u32(0);
        port = u32(0);
        if PyArg_ParseTuple(args, ptr[u8]("II:getsockaddrarg"), &mut cid, &mut port)
            == 0 {
            return -1;
        }
        put_u16(addrbuf, 0, family);
        put_u32(addrbuf, 4, int(port));
        put_u32(addrbuf, 8, int(cid));
        return SOCKADDR_VM_SIZE;
    }
    if family == AF_INET or (HAS_RDS and family == AF_RDS) {
        return inet_address(s, args, addrbuf, caller);
    }
    if family == AF_INET6 {
        return inet6_address(s, args, addrbuf, caller);
    }
    if HAS_PACKET and family == AF_PACKET {
        return packet_address(s, args, addrbuf, caller);
    }
    if HAS_TIPC and family == AF_TIPC {
        return tipc_address(args, addrbuf, caller);
    }
    if HAS_CAN and family == AF_CAN {
        return can_address(s, args, addrbuf, caller);
    }
    if HAS_SYSTEM and family == PF_SYSTEM {
        return system_address(s, args, addrbuf, caller);
    }
    if HAS_ALG and family == AF_ALG {
        return alg_address(args, addrbuf, caller);
    }
    object_error(PyExc_OSError, f"{caller}(): bad family");
    return -1;
}

impl unix_address(
    s: ptr[PySocketSockObject], args: ptr[PyObject], addrbuf: ptr[u8]
) -> int {
    path_obj = NULL;
    if jacpy_is_unicode(args) != 0 {
        path_obj = PyUnicode_EncodeFSDefault(args);
        if not path_obj {
            return -1;
        }
    } else {
        path_obj = Py_NewRef(args);
    }
    path = new_view();
    if not path {
        jacpy_release(path_obj);
        return -1;
    }
    retval = -1;
    if PyArg_Parse(path_obj, ptr[u8]("y*"), path) != 0 {
        length = int(path.view(1)[0].length);
        source = ptr[u8](path.view(1)[0].buf);
        jacpy_memory_zero(ptr(addrbuf), i64(SOCKADDR_UN_SIZE));
        sun_path = addrbuf + SUN_PATH_OFFSET;
        if HAS_ABSTRACT_UNIX and (length == 0 or int(source.view(1)[0]) == 0) {
            if length > SUN_PATH_SIZE {
                PyErr_SetString(PyExc_OSError, ptr[u8]("AF_UNIX path too long"));
            } else {
                retval = length + SUN_PATH_OFFSET;
            }
        } elif length >= SUN_PATH_SIZE {
            PyErr_SetString(PyExc_OSError, ptr[u8]("AF_UNIX path too long"));
        } else {
            (sun_path + length).view(1)[0] = u8(0);
            retval = length + SUN_PATH_OFFSET + 1;
        }
        if retval >= 0 {
            store_sa_family(addrbuf, sock_family(s));
            jacpy_memory_copy(ptr(sun_path), ptr(source), i64(length));
        }
    }
    jacpy_buffer_release(path);
    jacpy_release(path_obj);
    return retval;
}

impl inet_address(
    s: ptr[PySocketSockObject], args: ptr[PyObject], addrbuf: ptr[u8], caller: str
) -> int {
    if not require_tuple(args, f"{caller}(): AF_INET address must be tuple") {
        return -1;
    }
    host = new_idna();
    if not host {
        return -1;
    }
    port = i32(0);
    if PyArg_ParseTuple(
        args,
        ptr[u8]("O&i;AF_INET address must be a pair (host, port)"),
        ptr(idna_converter),
        ptr(host),
        &mut port
    )
        == 0 {
        overflow_message(f"{caller}(): port must be 0-65535.");
        free_idna(host);
        return -1;
    }
    jacpy_memory_zero(ptr(addrbuf), i64(SOCKADDR_IN_SIZE));
    result = setipaddr(
        module_of(s), host.view(1)[0].buf, addrbuf, SOCKADDR_IN_SIZE, AF_INET
    );
    free_idna(host);
    if result < 0 {
        return -1;
    }
    if port < 0 or port > 0xFFFF {
        object_error(PyExc_OverflowError, f"{caller}(): port must be 0-65535.");
        return -1;
    }
    store_sa_family(addrbuf, AF_INET);
    put_u16(addrbuf, 2, htons(int(port)));
    return SOCKADDR_IN_SIZE;
}

impl inet6_address(
    s: ptr[PySocketSockObject], args: ptr[PyObject], addrbuf: ptr[u8], caller: str
) -> int {
    if not require_tuple(args, f"{caller}(): AF_INET6 address must be tuple") {
        return -1;
    }
    host = new_idna();
    if not host {
        return -1;
    }
    port = i32(0);
    flowinfo = u32(0);
    scope_id = u32(0);
    if PyArg_ParseTuple(
        args,
        ptr[u8](
            "O&i|II;AF_INET6 address must be a tuple (host, port[, flowinfo[, scopeid]])"
        ),
        ptr(idna_converter),
        ptr(host),
        &mut port,
        &mut flowinfo,
        &mut scope_id
    )
        == 0 {
        overflow_message(f"{caller}(): port must be 0-65535.");
        free_idna(host);
        return -1;
    }
    jacpy_memory_zero(ptr(addrbuf), i64(SOCKADDR_IN6_SIZE));
    result = setipaddr(
        module_of(s), host.view(1)[0].buf, addrbuf, SOCKADDR_IN6_SIZE, AF_INET6
    );
    free_idna(host);
    if result < 0 {
        return -1;
    }
    if port < 0 or port > 0xFFFF {
        object_error(PyExc_OverflowError, f"{caller}(): port must be 0-65535.");
        return -1;
    }
    if flowinfo > u32(0xFFFFF) {
        object_error(PyExc_OverflowError, f"{caller}(): flowinfo must be 0-1048575.");
        return -1;
    }
    store_sa_family(addrbuf, sock_family(s));
    put_u16(addrbuf, 2, htons(int(port)));
    put_u32(addrbuf, 4, htonl(int(flowinfo)));
    put_u32(addrbuf, 24, int(scope_id));
    return SOCKADDR_IN6_SIZE;
}

impl packet_address(
    s: ptr[PySocketSockObject], args: ptr[PyObject], addrbuf: ptr[u8], caller: str
) -> int {
    if not require_tuple(args, f"{caller}(): AF_PACKET address must be tuple") {
        return -1;
    }
    haddr = new_view();
    if not haddr {
        return -1;
    }
    interface_name = ptr[u8]();
    proto_number = i32(0);
    pkttype = i32(PACKET_HOST);
    hatype = i32(0);
    if PyArg_ParseTuple(
        args,
        ptr[u8]("si|iiy*;AF_PACKET address must be a tuple of two to five elements"),
        &mut interface_name,
        &mut proto_number,
        &mut pkttype,
        &mut hatype,
        haddr
    )
        == 0 {
        overflow_message(f"{caller}(): address argument out of range");
        jacpy_buffer_release(haddr);
        return -1;
    }
    index = interface_index(s, interface_name);
    if index < 0 {
        jacpy_buffer_release(haddr);
        return -1;
    }
    view = haddr.view(1);
    if view[0].buf and view[0].length > 8 {
        PyErr_SetString(
            PyExc_ValueError, ptr[u8]("Hardware address must be 8 bytes or less")
        );
        jacpy_buffer_release(haddr);
        return -1;
    }
    if proto_number < 0 or proto_number > 0xFFFF {
        object_error(PyExc_OverflowError, f"{caller}(): proto must be 0-65535.");
        jacpy_buffer_release(haddr);
        return -1;
    }
    jacpy_memory_zero(ptr(addrbuf), i64(SOCKADDR_LL_SIZE));
    put_u16(addrbuf, 0, AF_PACKET);
    put_u16(addrbuf, 2, htons(int(proto_number)));
    ptr[i32](addrbuf + 4).view(1)[0] = i32(index);
    put_u8(addrbuf, 10, int(pkttype));
    put_u16(addrbuf, 8, int(hatype));
    if view[0].buf {
        jacpy_memory_copy(ptr(addrbuf + 12), view[0].buf, view[0].length);
        put_u8(addrbuf, 11, int(view[0].length));
    }
    jacpy_buffer_release(haddr);
    return SOCKADDR_LL_SIZE;
}

impl tipc_address(args: ptr[PyObject], addrbuf: ptr[u8], caller: str) -> int {
    if not require_tuple(args, f"{caller}(): AF_TIPC address must be tuple") {
        return -1;
    }
    atype = u32(0);
    v1 = u32(0);
    v2 = u32(0);
    v3 = u32(0);
    scope = u32(TIPC_CLUSTER_SCOPE);
    if PyArg_ParseTuple(
        args,
        ptr[u8](
            "IIII|I;AF_TIPC address must be a tuple (addr_type, v1, v2, v3[, scope])"
        ),
        &mut atype,
        &mut v1,
        &mut v2,
        &mut v3,
        &mut scope
    )
        == 0 {
        return -1;
    }
    jacpy_memory_zero(ptr(addrbuf), i64(SOCKADDR_TIPC_SIZE));
    put_u16(addrbuf, 0, AF_TIPC);
    put_u8(addrbuf, 3, int(scope));
    put_u8(addrbuf, 2, int(atype));
    if int(atype) == TIPC_ADDR_NAMESEQ {
        put_u32(addrbuf, 4, int(v1));
        put_u32(addrbuf, 8, int(v2));
        put_u32(addrbuf, 12, int(v3));
    } elif int(atype) == TIPC_ADDR_NAME {
        put_u32(addrbuf, 4, int(v1));
        put_u32(addrbuf, 8, int(v2));
    } elif int(atype) == TIPC_ADDR_ID {
        put_u32(addrbuf, 8, int(v1));
        put_u32(addrbuf, 4, int(v2));
    } else {
        PyErr_SetString(PyExc_TypeError, ptr[u8]("Invalid address type"));
        return -1;
    }
    return SOCKADDR_TIPC_SIZE;
}

impl can_address(
    s: ptr[PySocketSockObject], args: ptr[PyObject], addrbuf: ptr[u8], caller: str
) -> int {
    proto = sock_proto(s);
    jacpy_memory_zero(ptr(addrbuf), i64(SOCKADDR_CAN_SIZE));
    interface = NULL;
    if (HAS_CAN_RAW and proto == CAN_RAW) or (HAS_CAN_BCM and proto == CAN_BCM) {
        if not require_tuple(args, f"{caller}(): AF_CAN address must be tuple") {
            return -1;
        }
        if PyArg_ParseTuple(
            args,
            ptr[u8]("O&;AF_CAN address must be a tuple (interface, )"),
            ptr(PyUnicode_FSConverter),
            &mut interface
        )
            == 0 {
            return -1;
        }
        index = can_interface_index(s, interface);
        jacpy_release(interface);
        if index < 0 {
            return -1;
        }
        put_u16(addrbuf, 0, AF_CAN);
        ptr[i32](addrbuf + 4).view(1)[0] = i32(index);
        return SOCKADDR_CAN_SIZE;
    }
    if HAS_CAN_ISOTP and proto == CAN_ISOTP {
        rx_id = u64(0);
        tx_id = u64(0);
        if PyArg_ParseTuple(
            args,
            ptr[u8]("O&kk"),
            ptr(PyUnicode_FSConverter),
            &mut interface,
            &mut rx_id,
            &mut tx_id
        )
            == 0 {
            return -1;
        }
        index = can_interface_index(s, interface);
        jacpy_release(interface);
        if index < 0 {
            return -1;
        }
        put_u16(addrbuf, 0, AF_CAN);
        ptr[i32](addrbuf + 4).view(1)[0] = i32(index);
        put_u32(addrbuf, 8, int(rx_id));
        put_u32(addrbuf, 12, int(tx_id));
        return SOCKADDR_CAN_SIZE;
    }
    if HAS_CAN_J1939 and proto == CAN_J1939 {
        j1939_name = u64(0);
        j1939_pgn = u32(0);
        j1939_addr = u8(0);
        if PyArg_ParseTuple(
            args,
            ptr[u8]("O&KIB"),
            ptr(PyUnicode_FSConverter),
            &mut interface,
            &mut j1939_name,
            &mut j1939_pgn,
            &mut j1939_addr
        )
            == 0 {
            return -1;
        }
        index = can_interface_index(s, interface);
        jacpy_release(interface);
        if index < 0 {
            return -1;
        }
        put_u16(addrbuf, 0, AF_CAN);
        ptr[i32](addrbuf + 4).view(1)[0] = i32(index);
        put_u64(addrbuf, 8, int(j1939_name));
        put_u32(addrbuf, 16, int(j1939_pgn));
        put_u8(addrbuf, 20, int(j1939_addr));
        return SOCKADDR_CAN_SIZE;
    }
    object_error(PyExc_OSError, f"{caller}(): unsupported CAN protocol");
    return -1;
}

impl system_address(
    s: ptr[PySocketSockObject], args: ptr[PyObject], addrbuf: ptr[u8], caller: str
) -> int {
    if sock_proto(s) != SYSPROTO_CONTROL {
        object_error(PyExc_OSError, f"{caller}(): unsupported PF_SYSTEM protocol");
        return -1;
    }
    jacpy_memory_zero(ptr(addrbuf), i64(SOCKADDR_CTL_SIZE));
    store_sa_family(addrbuf, AF_SYSTEM);
    put_u16(addrbuf, 2, AF_SYS_CONTROL);
    if jacpy_is_unicode(args) != 0 {
        ctl_name = NULL;
        if PyArg_Parse(args, ptr[u8]("O&"), ptr(PyUnicode_FSConverter), &mut ctl_name)
            == 0 {
            return -1;
        }
        if jacpy_bytes_length(ctl_name) > MAX_KCTL_NAME {
            PyErr_SetString(PyExc_ValueError, ptr[u8]("provided string is too long"));
            jacpy_release(ctl_name);
            return -1;
        }
        info = ptr[u8](PyMem_Calloc(1, u64(CTL_INFO_SIZE)));
        if not info {
            jacpy_release(ctl_name);
            PyErr_NoMemory();
            return -1;
        }
        name = ptr[u8](jacpy_bytes_address(ctl_name));
        length = c_string_length(name, MAX_KCTL_NAME);
        jacpy_memory_copy(ptr(info + 4), ptr(name), i64(length));
        jacpy_release(ctl_name);
        if ioctl(get_sock_fd(s), u64(CTLIOCGINFO), info) != 0 {
            PyMem_Free(ptr(info));
            PyErr_SetString(
                PyExc_OSError, ptr[u8]("cannot find kernel control with provided name")
            );
            return -1;
        }
        put_u32(addrbuf, 4, get_u32(info, 0));
        put_u32(addrbuf, 8, 0);
        PyMem_Free(ptr(info));
    } else {
        sc_id = u32(0);
        sc_unit = u32(0);
        if PyArg_ParseTuple(args, ptr[u8]("II"), &mut sc_id, &mut sc_unit) == 0 {
            object_error(
                PyExc_TypeError,
                f"{caller}(): PF_SYSTEM address must be a str or a pair (id, unit)"
            );
            return -1;
        }
        put_u32(addrbuf, 4, int(sc_id));
        put_u32(addrbuf, 8, int(sc_unit));
    }
    return SOCKADDR_CTL_SIZE;
}

impl alg_address(args: ptr[PyObject], addrbuf: ptr[u8], caller: str) -> int {
    jacpy_memory_zero(ptr(addrbuf), i64(SOCKADDR_ALG_SIZE));
    put_u16(addrbuf, 0, AF_ALG);
    if not require_tuple(args, f"{caller}(): AF_ALG address must be tuple") {
        return -1;
    }
    alg_type = ptr[u8]();
    alg_name = ptr[u8]();
    feat = u16(0);
    mask = u16(0);
    if PyArg_ParseTuple(
        args,
        ptr[u8]("ss|HH;AF_ALG address must be a tuple (type, name[, feat[, mask]])"),
        &mut alg_type,
        &mut alg_name,
        &mut feat,
        &mut mask
    )
        == 0 {
        return -1;
    }
    put_u32(addrbuf, 16, int(feat));
    put_u32(addrbuf, 20, int(mask));

    type_length = c_string_length(alg_type);
    if type_length >= SALG_TYPE_SIZE {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("AF_ALG type too long."));
        return -1;
    }
    jacpy_memory_copy(ptr(addrbuf + 2), ptr(alg_type), i64(type_length));
    name_length = c_string_length(alg_name);
    if name_length >= SALG_NAME_SIZE {
        PyErr_SetString(PyExc_ValueError, ptr[u8]("AF_ALG name too long."));
        return -1;
    }
    jacpy_memory_copy(ptr(addrbuf + 24), ptr(alg_name), i64(name_length));
    return SOCKADDR_ALG_SIZE;
}

impl getsockaddrlen(s: ptr[PySocketSockObject]) -> int {
    family = sock_family(s);
    if family == AF_UNIX {
        return SOCKADDR_UN_SIZE;
    }
    if HAS_NETLINK and family == AF_NETLINK {
        return SOCKADDR_NL_SIZE;
    }
    if HAS_QIPCRTR and family == AF_QIPCRTR {
        return SOCKADDR_QRTR_SIZE;
    }
    if HAS_VSOCK and family == AF_VSOCK {
        return SOCKADDR_VM_SIZE;
    }
    if family == AF_INET or (HAS_RDS and family == AF_RDS) {
        return SOCKADDR_IN_SIZE;
    }
    if family == AF_INET6 {
        return SOCKADDR_IN6_SIZE;
    }
    if HAS_PACKET and family == AF_PACKET {
        return SOCKADDR_LL_SIZE;
    }
    if HAS_TIPC and family == AF_TIPC {
        return SOCKADDR_TIPC_SIZE;
    }
    if HAS_CAN and family == AF_CAN {
        return SOCKADDR_CAN_SIZE;
    }
    if HAS_SYSTEM and family == PF_SYSTEM {
        if sock_proto(s) == SYSPROTO_CONTROL {
            return SOCKADDR_CTL_SIZE;
        }
        PyErr_SetString(
            PyExc_OSError, ptr[u8]("getsockaddrlen: unknown PF_SYSTEM protocol")
        );
        return -1;
    }
    if HAS_ALG and family == AF_ALG {
        return SOCKADDR_ALG_SIZE;
    }
    PyErr_SetString(PyExc_OSError, ptr[u8]("getsockaddrlen: bad family"));
    return -1;
}
