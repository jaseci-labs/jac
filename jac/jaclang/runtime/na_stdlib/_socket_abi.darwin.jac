import from c { def __error -> int;  }

glob ADDRINFO_ADDRLEN_OFFSET: int = 16,
     ADDRINFO_ADDR_OFFSET: int = 32,
     ADDRINFO_NEXT_OFFSET: int = 40,
     ADDRINFO_SIZE: int = 48,
     IPV6_FAMILY: int = 30;

def:pub errno_pointer -> int {
    return __error();
}

def:pub address_family(address: bytes) -> int {
    return address[1];
}
