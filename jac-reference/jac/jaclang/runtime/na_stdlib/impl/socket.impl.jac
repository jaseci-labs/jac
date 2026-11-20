impl socket.postinit {
    self._fd = sock_open(self.family, self._socktype, self.proto);
}

impl socket.fileno -> int {
    return self._fd;
}

impl socket._connect_sa(sa: bytes) -> bool {
    return sock_connect(self._fd, sa) == 0;
}

impl socket.connect(address: tuple[(str, int)]) -> None {
    if self._fd < 0 {
        raise OSError("socket() failed: " + errno_message());
    }
    host = address[0];
    port = address[1];
    service = str(port);
    (addrs, rc) = resolve_all(host, service);
    if len(addrs) == 0 {
        raise OSError(
            "getaddrinfo failed for " + host + ":" + service + ": " + gai_str(rc)
        );
    }
    for sa in addrs {
        fam = address_family(sa);
        if fam == self.family and self._connect_sa(sa) {
            return;
        }
    }
    raise OSError("connect to " + host + ":" + service + " failed: " + errno_message());
}

impl socket.send(data: bytes) -> int {
    sent = sock_send(self._fd, data, 0);
    if sent < 0 {
        raise OSError("send failed: " + errno_message());
    }
    return sent;
}

impl socket.sendall(data: bytes) {
    total = len(data);
    off = 0;
    while off < total {
        sent = sock_send(self._fd, data, off);
        if sent < 0 {
            raise OSError("send failed: " + errno_message());
        }
        if sent == 0 {
            raise OSError("send returned 0 (peer closed the connection)");
        }
        off += sent;
    }
}

impl socket.recv(bufsize: int) -> bytes {
    return sock_recv(self._fd, bufsize);
}

impl socket.close {
    if self._fd >= 0 {
        sock_close(self._fd);
        self._fd = -1;
    }
}

impl create_connection(address: tuple[(str, int)]) -> socket {
    host = address[0];
    port = address[1];
    service = str(port);
    (addrs, rc) = resolve_all(host, service);
    if len(addrs) == 0 {
        raise OSError(
            "getaddrinfo failed for " + host + ":" + service + ": " + gai_str(rc)
        );
    }
    for sa in addrs {
        fam = address_family(sa);
        s = socket(family=fam, _socktype=1, proto=0);
        if s.fileno() < 0 {
            continue;
        }
        if s._connect_sa(sa) {
            return s;
        }
        s.close();
    }
    raise OSError(
        "create_connection to " + host + ":" + service + " failed: " + errno_message()
    );
}
