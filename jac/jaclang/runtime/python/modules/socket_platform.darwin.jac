"""The socket layer of macOS: BSD address records with a length byte, 32-bit
aligned ancillary data, the non-reentrant netdb lookups and PF_SYSTEM.

Derived from CPython 3.14.6 Modules/socketmodule.c and socketmodule.h; see
../LICENSE.cpython. The records are laid out as <sys/socket.h> and <netdb.h>
declare them, and CMSG_NXTHDR() as the <sys/socket.h> macro computes it.
There is no gethostbyname_r(), so the module serializes the lookups under
its netdb lock, as the C module does on this platform.
"""
import from c {
    obj msghdr {
        has msg_name: ptr = ptr(),
            msg_namelen: u32 = 0,
            msg_iov: ptr = ptr(),
            msg_iovlen: i32 = 0,
            msg_control: ptr = ptr(),
            msg_controllen: u32 = 0,
            msg_flags: i32 = 0;
    }  obj cmsghdr {
        has cmsg_len: u32 = 0,
            cmsg_level: i32 = 0,
            cmsg_type: i32 = 0;
    }  obj addrinfo {
        has ai_flags: i32 = 0,
            ai_family: i32 = 0,
            ai_socktype: i32 = 0,
            ai_protocol: i32 = 0,
            ai_addrlen: u32 = 0,
            ai_canonname: ptr[u8] = ptr[u8](),
            ai_addr: ptr = ptr(),
            ai_next: ptr = ptr();
    }  def gethostbyname(name: ptr[u8]) -> ptr;  def gethostbyaddr(
        addr: ptr, len: u32, type: i32
    ) -> ptr;  glob h_errno: i32; def sethostname(name: ptr[u8], len: i32) -> i32;
}

glob PLATFORM: str = "darwin",
     # struct sockaddr starts with its length (HAVE_SOCKADDR_SA_LEN).
     HAS_SA_LEN: bool = True,
     HAS_ACCEPT4: bool = False,
     HAS_SOCK_CLOEXEC: bool = False,
     HAS_SOCK_NONBLOCK: bool = False,
     HAS_SO_PROTOCOL: bool = False,
     HAS_GETHOSTBYNAME_R: bool = False,
     HAS_ABSTRACT_UNIX: bool = False,
     HAS_NETLINK: bool = False,
     HAS_QIPCRTR: bool = False,
     HAS_VSOCK: bool = False,
     HAS_RDS: bool = False,
     HAS_PACKET: bool = False,
     HAS_TIPC: bool = False,
     HAS_CAN: bool = False,
     HAS_CAN_RAW: bool = False,
     HAS_CAN_BCM: bool = False,
     HAS_CAN_ISOTP: bool = False,
     HAS_CAN_J1939: bool = False,
     HAS_ALG: bool = False,
     # PF_SYSTEM kernel control sockets (<sys/kern_control.h>).
     HAS_SYSTEM: bool = True,
     SOCKADDR_UN_SIZE: int = 106,
     SUN_PATH_SIZE: int = 104,
     MSGHDR_SIZE: int = 48,
     CMSGHDR_SIZE: int = 12;

def sockaddr_family(address: ptr[u8]) -> int {
    return int(address.view(2)[1]);
}

"""Store sa_family."""
def store_sa_family(address: ptr[u8], family: int) {
    address.view(2)[1] = u8(family);
}

"""Store sa_len (HAVE_SOCKADDR_SA_LEN)."""
def store_sa_len(address: ptr[u8], size: int) {
    address.view(2)[0] = u8(size);
}

"""CMSG_ALIGN(): __DARWIN_ALIGN32."""
def cmsg_align(length: int) -> int {
    return (length + 3) & ~3;
}

def cmsg_length(header: ptr[cmsghdr]) -> int {
    return int(header.view(1)[0].cmsg_len);
}

def set_cmsg_length(header: ptr[cmsghdr], length: int) {
    header.view(1)[0].cmsg_len = u32(length);
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
    message.view(1)[0].msg_iovlen = i32(count);
}

def set_msg_control(message: ptr[msghdr], control: ptr, length: int) {
    message.view(1)[0].msg_control = control;
    message.view(1)[0].msg_controllen = u32(length);
}

"""CMSG_NXTHDR() of <sys/socket.h>."""
def cmsg_nxthdr(message: ptr[msghdr], header: ptr[cmsghdr]) -> ptr[cmsghdr] {
    if not header {
        if msg_controllen(message) >= CMSGHDR_SIZE {
            return ptr[cmsghdr](message.view(1)[0].msg_control);
        }
        return ptr[cmsghdr]();
    }
    step = cmsg_align(cmsg_length(header) & 0xFFFFFFFF);
    end = int(message.view(1)[0].msg_control) + msg_controllen(message);
    if int(header) + step + cmsg_align(CMSGHDR_SIZE) > end {
        return ptr[cmsghdr]();
    }
    return ptr[cmsghdr](ptr[u8](header) + step);
}

def host_error -> i32 {
    return h_errno;
}

"""gethostbyname(): a static struct hostent; `hostent_record` and `buffer` are unused."""
def host_by_name(
    name: ptr[u8], hostent_record: ptr, buffer: ptr[u8], size: int
) -> ptr {
    return gethostbyname(name);
}

"""gethostbyaddr(): a static struct hostent."""
def host_by_addr(
    address: ptr,
    length: int,
    family: int,
    hostent_record: ptr,
    buffer: ptr[u8],
    size: int
) -> ptr {
    return gethostbyaddr(address, u32(length), i32(family));
}

def accept_cloexec(fd: i32, address: ptr, length: ptr[u32], flags: i32) -> i32 {
    return i32(-1);
}

def set_host_name(name: ptr[u8], length: int) -> i32 {
    return sethostname(name, i32(length));
}
