import fcntl;
import from _errno_native { last_errno }
import errno;
import select;


impl socket.postinit {
    self._fd = sock_open(self.family, self._socktype, self.proto);
}

impl socket.fileno -> int {
    return self._fd;
}

impl socket._connect_sa(sa: bytes) -> bool {
    return sock_connect(self._fd, sa) == 0;
}

def _connect_one(sock: socket, sa: bytes, timeout: (float | None)) -> bool {
    if timeout is None {
        return sock._connect_sa(sa);
    }
    flags = fcntl.fcntl(sock.fileno(), fcntl.F_GETFL);
    fcntl.fcntl(sock.fileno(), fcntl.F_SETFL, flags | fcntl.O_NONBLOCK);
    connected: bool = sock._connect_sa(sa);
    if not connected {
        err = last_errno();
        if err == errno.EINPROGRESS or err == errno.EALREADY
            or err == errno.EWOULDBLOCK {
            (_readable, writable, _exceptional) = select.select(
                [], [sock.fileno()], [], timeout
            );
            if sock.fileno() in writable {
                connected = sock_error(sock.fileno()) == 0;
            }
        }
    }
    fcntl.fcntl(sock.fileno(), fcntl.F_SETFL, flags);
    return connected;
}


impl socket.connect(
    address: tuple[(str, int)], timeout: (float | None)
) -> None {
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
        if fam == self.family and _connect_one(self, sa, timeout) {
            self._timeout = timeout;
            return;
        }
    }
    raise OSError("connect to " + host + ":" + service + " failed: " + errno_message());
}


impl socket.settimeout(timeout: (float | None)) -> None {
    if timeout is not None and timeout < 0.0 {
        raise ValueError("timeout value must be non-negative");
    }
    self._timeout = timeout;
}


impl socket.gettimeout -> (float | None) {
    return self._timeout;
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
        if self._timeout is not None {
            (_readable, writable, _exceptional) = select.select(
                [], [self._fd], [], self._timeout
            );
            if self._fd not in writable {
                raise TimeoutError("socket write timed out");
            }
        }
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
    if self._timeout is not None {
        (readable, _writable, _exceptional) = select.select(
            [self._fd], [], [], self._timeout
        );
        if self._fd not in readable {
            raise TimeoutError("socket read timed out");
        }
    }
    return sock_recv(self._fd, bufsize);
}

impl socket.close {
    if self._fd >= 0 {
        sock_close(self._fd);
        self._fd = -1;
    }
}

impl create_connection(
    address: tuple[(str, int)], timeout: (float | None)
) -> socket {
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
        if _connect_one(s, sa, timeout) {
            s._timeout = timeout;
            return s;
        }
        s.close();
    }
    raise OSError(
        "create_connection to " + host + ":" + service + " failed: " + errno_message()
    );
}
