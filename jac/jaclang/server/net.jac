import socket;

class PortInUseError(OSError) {
    def init(self: PortInUseError, port: int);
}


glob PORT_RETRY_LIMIT: int = 10,
     ERRNO_ADDR_IN_USE: tuple[int, int, int] = (98, 48, 10048);


def _address_in_use(e: OSError) -> bool;


def bind_listener(
    host: str, port: int, backlog: int = 2048, port_retries: int = PORT_RETRY_LIMIT
) -> socket.socket;


def find_available_port(
    start_port: int,
    max_retries: int = PORT_RETRY_LIMIT,
    skip_port: int = 0,
    strict: bool = False
) -> int;
