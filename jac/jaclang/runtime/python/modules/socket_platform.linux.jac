"""The socket layer of Linux (glibc): address records without a length byte,
size_t-wide ancillary-data fields, gethostbyname_r() and accept4().

Derived from CPython 3.14.6 Modules/socketmodule.c and socketmodule.h; see
../LICENSE.cpython. The records are laid out as <sys/socket.h> and <netdb.h>
declare them; CMSG_NXTHDR() follows glibc's __cmsg_nxthdr(), which a static
musl link does not have, so it is computed here.
"""
import from c {
    obj msghdr {
        has msg_name: ptr = ptr(),
            msg_namelen: u32 = 0,
            msg_iov: ptr = ptr(),
            msg_iovlen: u64 = 0,
            msg_control: ptr = ptr(),
            msg_controllen: u64 = 0,
            msg_flags: i32 = 0;
    }  obj cmsghdr {
        has cmsg_len: u64 = 0,
            cmsg_level: i32 = 0,
            cmsg_type: i32 = 0;
    }  obj addrinfo {
        has ai_flags: i32 = 0,
            ai_family: i32 = 0,
            ai_socktype: i32 = 0,
            ai_protocol: i32 = 0,
            ai_addrlen: u32 = 0,
            ai_addr: ptr = ptr(),
            ai_canonname: ptr[u8] = ptr[u8](),
            ai_next: ptr = ptr();
    }  def gethostbyname_r(
        name: ptr[u8],
        result_buf: ptr,
        buf: ptr[u8],
        buflen: u64,
        result: &mut ptr,
        h_errnop: &mut i32
    ) -> i32;  def gethostbyaddr_r(
        addr: ptr,
        len: u32,
        type: i32,
        result_buf: ptr,
        buf: ptr[u8],
        buflen: u64,
        result: &mut ptr,
        h_errnop: &mut i32
    ) -> i32;  def __h_errno_location -> ptr[i32];  def accept4(
        fd: i32, addr: ptr, addrlen: ptr[u32], flags: i32
    ) -> i32;  def sethostname(name: ptr[u8], len: u64) -> i32;
}

glob PLATFORM: str = "linux",
     # struct sockaddr has no sa_len member.
     HAS_SA_LEN: bool = False,
     # accept4() and SOCK_CLOEXEC / SOCK_NONBLOCK (Linux 2.6.27+, glibc 2.10+).
     HAS_ACCEPT4: bool = True,
     HAS_SOCK_CLOEXEC: bool = True,
     HAS_SOCK_NONBLOCK: bool = True,
     HAS_SO_PROTOCOL: bool = True,
     # The reentrant netdb lookups; without them a lock serializes the calls.
     HAS_GETHOSTBYNAME_R: bool = True,
     # The Linux abstract namespace of AF_UNIX addresses.
     HAS_ABSTRACT_UNIX: bool = True,
     # The address families with configure-detected headers.
     HAS_NETLINK: bool = True,
     HAS_QIPCRTR: bool = True,
     HAS_VSOCK: bool = True,
     HAS_RDS: bool = True,
     HAS_PACKET: bool = True,
     HAS_TIPC: bool = True,
     HAS_CAN: bool = True,
     HAS_CAN_RAW: bool = True,
     HAS_CAN_BCM: bool = True,
     HAS_CAN_ISOTP: bool = True,
     HAS_CAN_J1939: bool = True,
     HAS_ALG: bool = True,
     HAS_SYSTEM: bool = False,
     # sizeof(struct sockaddr_un) and its sun_path.
     SOCKADDR_UN_SIZE: int = 110,
     SUN_PATH_SIZE: int = 108,
     # sizeof(struct msghdr) and sizeof(struct cmsghdr).
     MSGHDR_SIZE: int = 56,
     CMSGHDR_SIZE: int = 16;

"""sa_family of a struct sockaddr."""
def sockaddr_family(address: ptr[u8]) -> int {
    return int(ptr[u16](address).view(1)[0]);
}

"""Store sa_family."""
def store_sa_family(address: ptr[u8], family: int) {
    ptr[u16](address).view(1)[0] = u16(family);
}

"""Store sa_len; Linux records have none."""
def store_sa_len(address: ptr[u8], size: int) {}

"""CMSG_ALIGN(): the size_t alignment of <bits/socket.h>."""
def cmsg_align(length: int) -> int {
    return (length + 7) & ~7;
}

def cmsg_length(header: ptr[cmsghdr]) -> int {
    return int(header.view(1)[0].cmsg_len);
}

def set_cmsg_length(header: ptr[cmsghdr], length: int) {
    header.view(1)[0].cmsg_len = u64(length);
}

def msg_controllen(message: ptr[msghdr]) -> int {
    return int(message.view(1)[0].msg_controllen);
}

def set_msg_name(message: ptr[msghdr], name: ptr, length: int) {
    message.view(1)[0].msg_name = name;
    message.view(1)[0].msg_namelen = u32(length);
}

def set_msg_iov(message: ptr[msghdr], iov: ptr, count: int) {
    message.view(1)[0].msg_iov = iov;
    message.view(1)[0].msg_iovlen = u64(count);
}

def set_msg_control(message: ptr[msghdr], control: ptr, length: int) {
    message.view(1)[0].msg_control = control;
    message.view(1)[0].msg_controllen = u64(length);
}

"""CMSG_NXTHDR() as glibc's __cmsg_nxthdr() computes it."""
def cmsg_nxthdr(message: ptr[msghdr], header: ptr[cmsghdr]) -> ptr[cmsghdr] {
    length = cmsg_length(header);
    if length < CMSGHDR_SIZE {
        return ptr[cmsghdr]();
    }
    next = ptr[u8](header) + cmsg_align(length);
    end = ptr[u8](message.view(1)[0].msg_control) + msg_controllen(message);
    if int(next) + CMSGHDR_SIZE > int(end)
        or int(next) + cmsg_align(cmsg_length(ptr[cmsghdr](next))) > int(end) {
        return ptr[cmsghdr]();
    }
    return ptr[cmsghdr](next);
}

"""h_errno, the resolver's thread-local error."""
def host_error -> i32 {
    return __h_errno_location().view(1)[0];
}

"""gethostbyname_r() (the 6-argument glibc form) into `hostent_record`, a struct
hostent, with `buffer` as its storage; NULL when the name is not found."""
def host_by_name(
    name: ptr[u8], hostent_record: ptr, buffer: ptr[u8], size: int
) -> ptr {
    result = ptr();
    error: i32 = 0;
    gethostbyname_r(name, hostent_record, buffer, u64(size), &mut result, &mut error);
    return result;
}

"""gethostbyaddr_r() into `hostent_record`; NULL when the address is not found."""
def host_by_addr(
    address: ptr,
    length: int,
    family: int,
    hostent_record: ptr,
    buffer: ptr[u8],
    size: int
) -> ptr {
    result = ptr();
    error: i32 = 0;
    gethostbyaddr_r(
        address,
        u32(length),
        i32(family),
        hostent_record,
        buffer,
        u64(size),
        &mut result,
        &mut error
    );
    return result;
}

def accept_cloexec(fd: i32, address: ptr, length: ptr[u32], flags: i32) -> i32 {
    return accept4(fd, address, length, flags);
}

def set_host_name(name: ptr[u8], length: int) -> i32 {
    return sethostname(name, u64(length));
}
