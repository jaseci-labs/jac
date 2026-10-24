impl do_fcntl(fd: int, cmd: int, arg: int) -> int {
    return int(fcntl(i32(fd), i32(cmd), i64(arg)));
}

impl do_ioctl(fd: int, request: int, arg: bytes) -> int {
    return int(ioctl(i32(fd), u64(request), arg));
}
