import from c { def __errno_location -> int;  }

glob ADDRINFO_ADDRLEN_OFFSET: int = 16,
     ADDRINFO_ADDR_OFFSET: int = 24,
     ADDRINFO_NEXT_OFFSET: int = 40,
     ADDRINFO_SIZE: int = 48,
     IPV6_FAMILY: int = 10;

def:pub errno_pointer -> int {
    return __errno_location();
}

def:pub address_family(address: bytes) -> int {
    return address[0] + address[1] * 256;
}
