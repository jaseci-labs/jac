import from socket { socket as Socket }


def _tls_wait(fd: int, want_read: bool, timeout: float) -> bool;


obj:pub SSLError(Exception) {}


obj:pub SSLSocket {
    has _ssl: int,
        _ctx: int,
        _sock: Socket;

    def fileno -> int;
    def sendall(data: bytes);
    def send(data: bytes) -> int;
    def recv(bufsize: int) -> bytes;
    def settimeout(timeout: (float | None)) -> None;
    def gettimeout -> (float | None);
    def close;
}


obj:pub SSLContext {
    has check_hostname: bool = True,
        _cafile: str = "";

    def load_verify_locations(cafile: str);
    def wrap_socket(sock: Socket, server_hostname: str) -> SSLSocket;
}


def:pub create_default_context(cafile: str | None = None) -> SSLContext;
