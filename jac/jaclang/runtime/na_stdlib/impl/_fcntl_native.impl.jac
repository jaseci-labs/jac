impl do_fcntl(fd: int, cmd: int, arg: int) -> int {
    raise RuntimeError("fcntl is unavailable on this platform");
}

impl do_ioctl(fd: int, request: int, arg: bytes) -> int {
    raise RuntimeError("ioctl is unavailable on this platform");
}
