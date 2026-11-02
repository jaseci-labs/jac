impl errno_pointer -> int {
    return __jac_errno();
}

impl address_family(address: bytes) -> int {
    return int(__jac_sockaddr_family(address));
}
