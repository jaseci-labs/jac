"""The socket layer for a target with no socket_platform.<os>.jac; the module rejects it."""

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
    }
}

glob PLATFORM: str = "",
     HAS_SA_LEN: bool = False,
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
     HAS_SYSTEM: bool = False,
     SOCKADDR_UN_SIZE: int = 110,
     SUN_PATH_SIZE: int = 108,
     MSGHDR_SIZE: int = 56,
     CMSGHDR_SIZE: int = 16;

def sockaddr_family(address: ptr[u8]) -> int {
    return 0;
}

def store_sa_family(address: ptr[u8], family: int) {}

def store_sa_len(address: ptr[u8], size: int) {}

def cmsg_align(length: int) -> int {
    return (length + 7) & ~7;
}

def cmsg_length(header: ptr[cmsghdr]) -> int {
    return 0;
}

def set_cmsg_length(header: ptr[cmsghdr], length: int) {}

def msg_controllen(message: ptr[msghdr]) -> int {
    return 0;
}

def set_msg_name(message: ptr[msghdr], name: ptr, length: int) {}

def set_msg_iov(message: ptr[msghdr], iov: ptr, count: int) {}

def set_msg_control(message: ptr[msghdr], control: ptr, length: int) {}

def cmsg_nxthdr(message: ptr[msghdr], header: ptr[cmsghdr]) -> ptr[cmsghdr] {
    return ptr[cmsghdr]();
}

def host_error -> i32 {
    return i32(0);
}

def host_by_name(
    name: ptr[u8], hostent_record: ptr, buffer: ptr[u8], size: int
) -> ptr {
    return ptr();
}

def host_by_addr(
    address: ptr,
    length: int,
    family: int,
    hostent_record: ptr,
    buffer: ptr[u8],
    size: int
) -> ptr {
    return ptr();
}

def accept_cloexec(fd: i32, address: ptr, length: ptr[u32], flags: i32) -> i32 {
    return i32(-1);
}

def set_host_name(name: ptr[u8], length: int) -> i32 {
    return i32(-1);
}
