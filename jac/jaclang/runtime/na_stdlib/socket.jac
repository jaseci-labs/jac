glob AF_UNSPEC: int = 0,
     AF_INET: int = 2,
     AF_INET6: int = IPV6_FAMILY;

glob SOCK_STREAM: int = 1,
     SOCK_DGRAM: int = 2;

glob IPPROTO_TCP: int = 6,
     IPPROTO_UDP: int = 17;

glob SHUT_RD: int = 0,
     SHUT_WR: int = 1,
     SHUT_RDWR: int = 2;


obj:pub socket {
    has family: int = 2,
        _socktype: int = 1,
        proto: int = 0,
        _fd: int = -1;

    def postinit;
    def fileno -> int;
    def _connect_sa(sa: bytes) -> bool;
    def connect(address: tuple[(str, int)]) -> None;
    def send(data: bytes) -> int;
    def sendall(data: bytes);
    def recv(bufsize: int) -> bytes;
    def close;
}


def:pub create_connection(address: tuple[(str, int)]) -> socket;
