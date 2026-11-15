import from c { def __jac_errno -> int;  }
import from c { def __jac_addrinfo_layout(which: i32) -> int;  }
import from c { def __jac_sockaddr_family(address: bytes) -> i32;  }

glob ADDRINFO_ADDRLEN_OFFSET: int = __jac_addrinfo_layout(i32(0)),
     ADDRINFO_ADDR_OFFSET: int = __jac_addrinfo_layout(i32(1)),
     ADDRINFO_NEXT_OFFSET: int = __jac_addrinfo_layout(i32(2)),
     ADDRINFO_SIZE: int = __jac_addrinfo_layout(i32(3)),
     IPV6_FAMILY: int = __jac_addrinfo_layout(i32(4));

def:pub errno_pointer -> int;

def:pub address_family(address: bytes) -> int;
