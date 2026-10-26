impl write_file(path: str, data: bytes) -> bool {
    fd = open_writetrunc(path);
    if fd < 0 {
        return False;
    }
    wrote = write(fd, data, len(data));
    close(fd);
    return wrote == len(data);
}

impl read_at(path: str, off: int, n: int) -> bytes {
    fd = open_readonly(path);
    if fd < 0 {
        return b"";
    }
    buf = b"\x00" * n;
    got = pread(fd, buf, n, off);
    close(fd);
    if got < 0 {
        return b"";
    }
    return buf[0:got];
}

impl listdir(path: str) -> list[str] {
    names: list[str] = [];
    dirp = opendir(path);
    if dirp == 0 {
        return names;
    }
    ent = readdir(dirp);
    while ent != 0 {
        name = dirent_name(ent);
        if name != "." and name != ".." {
            names.append(name);
        }
        ent = readdir(dirp);
    }
    closedir(dirp);
    return names;
}

impl c_string(ptr: int) -> str {
    return strdup(ptr);
}

impl c_alloc_string(s: str) -> int {
    p = malloc(len(s.encode()) + 1);
    strcpy(p, s);
    return p;
}

impl peek(ptr: int, n: int) -> bytes {
    buf = b"\x00" * n;
    memcpy(buf, ptr, n);
    return buf;
}

impl poke(ptr: int, data: bytes) {
    memmove(ptr, data, len(data));
}
