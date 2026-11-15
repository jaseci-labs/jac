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
