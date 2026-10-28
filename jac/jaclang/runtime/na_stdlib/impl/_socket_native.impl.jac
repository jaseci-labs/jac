impl resolve_all(host: str, service: str) -> tuple[(list[bytes], int)] {
    out: list[bytes] = [];
    res_slot = b"\x00" * 8;
    rc = getaddrinfo(host, service, 0, res_slot);
    if rc != 0 {
        return (out, rc);
    }
    head = int.from_bytes(res_slot, "little");
    cur = head;
    while cur != 0 {
        ai = b"\x00" * ADDRINFO_SIZE;
        memcpy(ai, cur, u64(ADDRINFO_SIZE));
        addrlen = int.from_bytes(
            ai[ADDRINFO_ADDRLEN_OFFSET:ADDRINFO_ADDRLEN_OFFSET + 4], "little"
        );
        addr = int.from_bytes(
            ai[ADDRINFO_ADDR_OFFSET:ADDRINFO_ADDR_OFFSET + 8], "little"
        );
        if addr != 0 and addrlen > 0 and addrlen <= _SOCKADDR_MAX {
            sa = b"\x00" * addrlen;
            memcpy(sa, addr, u64(addrlen));
            out.append(sa);
        }
        cur = int.from_bytes(
            ai[ADDRINFO_NEXT_OFFSET:ADDRINFO_NEXT_OFFSET + 8], "little"
        );
    }
    if head != 0 {
        freeaddrinfo(head);
    }
    return (out, 0);
}

impl gai_str(rc: int) -> str {
    return gai_strerror(i32(rc));
}

impl sock_open(family: int, socktype: int, proto: int) -> int {
    return socket(i32(family), i32(socktype), i32(proto));
}

impl sock_connect(fd: int, sa: bytes) -> int {
    return __connect(i32(fd), sa, i32(len(sa)));
}

impl sock_send(fd: int, data: bytes, off: int) -> int {
    n = len(data);
    if off >= n {
        return 0;
    }
    chunk = data[off:n];
    sent = send(i32(fd), chunk, u64(len(chunk)), 0);
    return sent;
}

impl sock_recv(fd: int, bufsize: int) -> bytes {
    if bufsize <= 0 {
        return b"";
    }
    buf = b"\x00" * bufsize;
    got = recv(i32(fd), buf, u64(bufsize), 0);
    if got < 0 {
        raise OSError("recv failed: " + errno_message());
    }
    if got == 0 {
        return b"";
    }
    return buf[0:got];
}

impl sock_close(fd: int) {
    if fd >= 0 {
        close(i32(fd));
    }
}
