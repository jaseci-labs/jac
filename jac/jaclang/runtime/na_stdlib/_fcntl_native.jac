import from c { def fcntl(fd: i32, cmd: i32, arg: i64) -> i32;  }
import from c { def ioctl(fd: i32, req: u64, arg: bytes) -> i32;  }


def:pub do_fcntl(fd: int, cmd: int, arg: int) -> int {
    return fcntl(i32(fd), i32(cmd), i64(arg));
}


def:pub do_ioctl(fd: int, request: int, arg: bytes) -> int {
    return ioctl(i32(fd), u64(request), arg);
}
