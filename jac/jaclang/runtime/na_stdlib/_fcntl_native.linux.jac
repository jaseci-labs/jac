import from c { def fcntl(fd: i32, cmd: i32, *args: VaList) -> i32;  }
import from c { def ioctl(fd: i32, req: u64, *args: VaList) -> i32;  }

glob _F_GETFL: int = 3,
     _F_SETFL: int = 4,
     _F_GETFD: int = 1,
     _F_SETFD: int = 2,
     _F_SETOWN: int = 8,
     _O_NONBLOCK: int = 2048,
     _O_APPEND: int = 1024,
     _O_ASYNC: int = 8192;

def:pub do_fcntl(fd: int, cmd: int, arg: int) -> int;

def:pub do_ioctl(fd: int, request: int, arg: bytes) -> int;
