import from c {
    def pread(fd: i32, buf: bytes, n: int, off: int) -> int;  def close(
        fd: i32
    ) -> i32;  def getuid -> i32;  def opendir(path: str) -> int;  def readdir(
        dirp: int
    ) -> int;  def closedir(dirp: int) -> i32;  def malloc(size: int) -> int;  def free(
        ptr: int
    ) -> None;  def strcpy(dst: int, src: str) -> int;  def strdup(s: int) -> str;  def memcpy(
        dst: bytes, src: int, n: int
    ) -> int;  def memmove(dst: int, src: bytes, n: int) -> int;
}
import from _dirent_native { dirent_name }
import from _fd_native { open_readonly }

def:pub read_at(path: str, off: int, n: int) -> bytes {
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

def:pub listdir(path: str) -> list[str] {
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

def:pub c_string(ptr: int) -> str {
    return strdup(ptr);
}

def:pub c_alloc_string(s: str) -> int {
    p = malloc(len(s.encode()) + 1);
    strcpy(p, s);
    return p;
}

def:pub peek(ptr: int, n: int) -> bytes {
    buf = b"\x00" * n;
    memcpy(buf, ptr, n);
    return buf;
}

def:pub poke(ptr: int, data: bytes) {
    memmove(ptr, data, len(data));
}
