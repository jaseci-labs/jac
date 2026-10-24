glob F_GETFL: int = _F_GETFL,
     F_SETFL: int = _F_SETFL,
     F_GETFD: int = _F_GETFD,
     F_SETFD: int = _F_SETFD,
     F_SETOWN: int = _F_SETOWN;

glob O_NONBLOCK: int = _O_NONBLOCK,
     O_APPEND: int = _O_APPEND,
     O_ASYNC: int = _O_ASYNC;

glob _IOCTL_BUFSZ: int = 1024;

glob _IOCTL_GUARD: bytes = b"\x00\xfa\x69\xc4\x67\xa3\x6c\x58",
     _IOCTL_GUARDSZ: int = 8;

def:pub fcntl(fd: int, cmd: int, arg: int = 0) -> int;

def:pub ioctl(fd: int, request: int, arg: bytes) -> bytes;

impl fcntl(fd: int, cmd: int, arg: int = 0) -> int {
    rc: int = do_fcntl(fd, cmd, arg);
    while rc < 0 and last_errno() == EINTR {
        rc = do_fcntl(fd, cmd, arg);
    }
    if rc < 0 {
        raise ValueError(
            "fcntl failed: [Errno " + str(last_errno()) + "] " + errno_message()
        );
    }
    return rc;
}

impl ioctl(fd: int, request: int, arg: bytes) -> bytes {
    n: int = len(arg);
    if n > _IOCTL_BUFSZ {
        raise ValueError("ioctl argument 3 is too long");
    }
    buf: bytes = arg + _IOCTL_GUARD + b"\x00" * (_IOCTL_BUFSZ - n);
    rc: int = do_ioctl(fd, request, buf);
    while rc < 0 and last_errno() == EINTR {
        rc = do_ioctl(fd, request, buf);
    }
    if rc < 0 {
        raise ValueError(
            "ioctl failed: [Errno " + str(last_errno()) + "] " + errno_message()
        );
    }
    if buf[n:n + _IOCTL_GUARDSZ] != _IOCTL_GUARD {
        raise RuntimeError("buffer overflow");
    }
    return buf[:n];
}
