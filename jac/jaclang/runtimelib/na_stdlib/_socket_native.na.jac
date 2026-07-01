import from c { def socket(domain: i32, socktype: i32, protocol: i32) -> i32;  }
import from c { def connect(fd: i32, addr: bytes, addrlen: i32) -> i32;  }
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
import from c { def __errno_location -> int;  }
import from c { def strerror(errnum: i32) -> str;  }

glob _AI_ADDRLEN_OFF: int = 16,
     _AI_ADDR_OFF: int = 24,
     _AI_NEXT_OFF: int = 40,
     _AI_SIZE: int = 48;

glob _SOCKADDR_MAX: int = 128;


def:pub last_errno -> int {
    p = __errno_location();
    b4 = b"\x00" * 4;
    memcpy(b4, p, 4);
    return int.from_bytes(b4, "little");
}


def:pub errno_message -> str {
    return strerror(last_errno());
}


def:pub resolve_all(host: str, service: str) -> tuple[(list[bytes], int)] {
    out: list[bytes] = [];
    res_slot = b"\x00" * 8;
    rc = getaddrinfo(host, service, 0, res_slot);
    if rc != 0 {
        return (out, rc);
    }
    head = int.from_bytes(res_slot, "little");
    cur = head;
    while cur != 0 {
        ai = b"\x00" * _AI_SIZE;
        memcpy(ai, cur, _AI_SIZE);
        addrlen = int.from_bytes(ai[_AI_ADDRLEN_OFF:_AI_ADDRLEN_OFF + 4], "little");
        addr = int.from_bytes(ai[_AI_ADDR_OFF:_AI_ADDR_OFF + 8], "little");
        if addr != 0 and addrlen > 0 and addrlen <= _SOCKADDR_MAX {
            sa = b"\x00" * addrlen;
            memcpy(sa, addr, addrlen);
            out.append(sa);
        }
        cur = int.from_bytes(ai[_AI_NEXT_OFF:_AI_NEXT_OFF + 8], "little");
    }
    if head != 0 {
        freeaddrinfo(head);
    }
    return (out, 0);
}


def:pub gai_str(rc: int) -> str {
    return gai_strerror(rc);
}


def:pub sock_open(family: int, socktype: int, proto: int) -> int {
    return socket(family, socktype, proto);
}


def:pub sock_connect(fd: int, sa: bytes) -> int {
    return connect(fd, sa, len(sa));
}


def:pub sock_send(fd: int, data: bytes, off: int) -> int {
    n = len(data);
    if off >= n {
        return 0;
    }
    chunk = data[off:n];
    sent = send(fd, chunk, len(chunk), 0);
    return sent;
}


def:pub sock_recv(fd: int, bufsize: int) -> bytes {
    if bufsize <= 0 {
        return b"";
    }
    buf = b"\x00" * bufsize;
    got = recv(fd, buf, bufsize, 0);
    if got < 0 {
        raise OSError("recv failed: " + errno_message());
    }
    if got == 0 {
        return b"";
    }
    return buf[0:got];
}


def:pub sock_close(fd: int) {
    if fd >= 0 {
        close(fd);
    }
}
