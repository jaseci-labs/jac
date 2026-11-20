import from c { def socket(domain: i32, socktype: i32, protocol: i32) -> i32;  }
import from c { def __connect(fd: i32, addr: bytes, addrlen: i32) -> i32;  }
import from c { def send(fd: i32, buf: bytes, n: u64, flags: i32) -> i64;  }
import from c { def recv(fd: i32, buf: bytes, n: u64, flags: i32) -> i64;  }
import from c { def close(fd: i32) -> i32;  }
import from c { def shutdown(fd: i32, how: i32) -> i32;  }
import from c {
    def getaddrinfo(hostname: str, service: str, hints: int, res: bytes) -> i32;
}
import from c { def freeaddrinfo(res: int) -> None;  }
import from c { def gai_strerror(errcode: i32) -> str;  }
import from c { def memcpy(dst: bytes, src: int, n: u64) -> int;  }

glob _SOCKADDR_MAX: int = 128;


def:pub resolve_all(host: str, service: str) -> tuple[(list[bytes], int)];


def:pub gai_str(rc: int) -> str;


def:pub sock_open(family: int, socktype: int, proto: int) -> int;


def:pub sock_connect(fd: int, sa: bytes) -> int;


def:pub sock_send(fd: int, data: bytes, off: int) -> int;


def:pub sock_recv(fd: int, bufsize: int) -> bytes;


def:pub sock_close(fd: int);
