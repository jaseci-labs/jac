def:pub do_fcntl(fd: int, cmd: int, arg: int) -> int;

def:pub do_ioctl(fd: int, request: int, arg: bytes) -> int;

glob _F_GETFD: int,
     _F_GETFL: int,
     _F_SETFD: int,
     _F_SETFL: int,
     _F_SETOWN: int,
     _O_APPEND: int,
     _O_ASYNC: int,
     _O_NONBLOCK: int;
