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
