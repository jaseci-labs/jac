impl tar_read_file(path: str) -> bytes {
    f = open(path, "rb");
    data = f.read();
    f.close();
    return data;
}

impl tar_create(path: str) -> int {
    return creat(path, 0o666);
}

impl tar_write(fd: int, data: bytes) -> int {
    total: int = len(data);
    off: int = 0;
    while off < total {
        chunk = data[off:total];
        n: int = write(i32(fd), chunk, u64(len(chunk)));
        if n <= 0 {
            return -1;
        }
        off += n;
    }
    return 0;
}

impl tar_close(fd: int) -> int {
    return close(i32(fd));
}

impl tar_chmod(path: str, mode: int) -> int {
    return chmod(path, i32(mode));
}

impl tar_symlink(target: str, linkpath: str) -> int {
    unlink(linkpath);
    return symlink(target, linkpath);
}

impl tar_link(src: str, dst: str) -> int {
    unlink(dst);
    return link(src, dst);
}

impl tar_utime(path: str, mtime: int) -> int {
    t: int = mtime;
    if t < 0 {
        t = 0;
    }
    times = t.to_bytes(8, "little") + t.to_bytes(8, "little");
    return utime(path, times);
}
