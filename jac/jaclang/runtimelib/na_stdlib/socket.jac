import from _socket_native {
    resolve_all,
    gai_str,
    sock_open,
    sock_connect,
    sock_send,
    sock_recv,
    sock_close,
    errno_message
}

glob AF_UNSPEC: int = 0,
     AF_INET: int = 2,
     AF_INET6: int = 10;

glob SOCK_STREAM: int = 1,
     SOCK_DGRAM: int = 2;

glob IPPROTO_TCP: int = 6,
     IPPROTO_UDP: int = 17;

glob SHUT_RD: int = 0,
     SHUT_WR: int = 1,
     SHUT_RDWR: int = 2;


obj:pub socket {
    has family: int = 2,
        socktype: int = 1,
        proto: int = 0,
        _fd: int = -1;

    def postinit {
        self._fd = sock_open(self.family, self.socktype, self.proto);
    }

    def fileno -> int {
        return self._fd;
    }

    def _connect_sa(sa: bytes) -> bool {
        return sock_connect(self._fd, sa) == 0;
    }

    def connect(address: tuple[(str, int)]) -> None {
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
            fam = sa[0] + sa[1] * 256;
            if fam == self.family and self._connect_sa(sa) {
                return;
            }
        }
        raise OSError(
            "connect to " + host + ":" + service + " failed: " + errno_message()
        );
    }

    def send(data: bytes) -> int {
        sent = sock_send(self._fd, data, 0);
        if sent < 0 {
            raise OSError("send failed: " + errno_message());
        }
        return sent;
    }

    def sendall(data: bytes) {
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

    def recv(bufsize: int) -> bytes {
        return sock_recv(self._fd, bufsize);
    }

    def close {
        if self._fd >= 0 {
            sock_close(self._fd);
            self._fd = -1;
        }
    }
}


def:pub create_connection(address: tuple[(str, int)]) -> socket {
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
        fam = sa[0] + sa[1] * 256;
        s = socket(family=fam, socktype=1, proto=0);
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
