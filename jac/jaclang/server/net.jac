import socket;

class PortInUseError(OSError) {
    def init(self: PortInUseError, port: int) {
        self.port = port;
        super.__init__(f"Port {port} is already in use");
    }
}


glob PORT_RETRY_LIMIT: int = 10,
     ERRNO_ADDR_IN_USE: tuple[int, int, int] = (98, 48, 10048);


def _address_in_use(e: OSError) -> bool {
    return e.errno in ERRNO_ADDR_IN_USE or "Address already in use" in str(e);
}


def bind_listener(
    host: str, port: int, backlog: int = 2048, port_retries: int = PORT_RETRY_LIMIT
) -> socket.socket {
    family = socket.AF_INET6 if ':' in host else socket.AF_INET;
    candidate = port;
    attempt = 0;
    while True {
        sock = socket.socket(family, socket.SOCK_STREAM);
        try {
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
            if family == socket.AF_INET6 and hasattr(socket, 'IPV6_V6ONLY') {
                sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0);
            }
            sock.bind((host, candidate));
            sock.listen(backlog);
            sock.setblocking(False);
            return sock;
        } except OSError as e {
            sock.close();
            if not _address_in_use(e) {
                raise;
            }
            if attempt >= port_retries {
                raise PortInUseError(candidate) from None;
            }
            attempt += 1;
            candidate += 1;
        }
    }
}


def find_available_port(
    start_port: int,
    max_retries: int = PORT_RETRY_LIMIT,
    skip_port: int = 0,
    strict: bool = False
) -> int {
    candidate = start_port;
    for _ in range(max_retries) {
        if candidate == skip_port {
            if strict {
                raise PortInUseError(start_port) from None;
            }
            candidate += 1;
            continue;
        }
        try {
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe {
                probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
                probe.bind(('0.0.0.0', candidate));
            }
            return candidate;
        } except OSError as e {
            if not _address_in_use(e) {
                raise;
            }
            if strict {
                raise PortInUseError(start_port) from None;
            }
            candidate += 1;
        }
    }
    raise OSError(
        f"Could not find an available port after trying {start_port}-{candidate}"
    );
}
