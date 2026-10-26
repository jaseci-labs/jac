impl open_readonly(path: str) -> i32 {
    return openat(i32(AT_FDCWD), path, 0);
}

impl open_writetrunc(path: str) -> i32 {
    return creat(path, i32(420));
}
