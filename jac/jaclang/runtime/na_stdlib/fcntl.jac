import from _fcntl_native { do_fcntl, do_ioctl }

glob F_GETFL: int = 3,
     F_SETFL: int = 4,
     F_GETFD: int = 1,
     F_SETFD: int = 2;

glob F_SETOWN: int = 8;

glob O_NONBLOCK: int = 2048,
     O_APPEND: int = 1024,
     O_ASYNC: int = 8192,
     O_NDELAY: int = 2048;


def:pub ioctl(fd: int, request: int, arg: bytes) -> bytes {
    rc: int = do_ioctl(fd, request, arg);
    if rc < 0 {
        raise ValueError("ioctl failed");
    }
    return arg;
}


def:pub fcntl(fd: int, cmd: int, arg: int = 0) -> int {
    rc: int = do_fcntl(fd, cmd, arg);
    if rc < 0 {
        raise ValueError("fcntl failed");
    }
    return rc;
}
