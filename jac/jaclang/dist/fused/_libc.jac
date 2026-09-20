import from c {
    def getuid -> i32;  def malloc(size: int) -> int;  def free(ptr: int) -> None;  def strcpy(
        dst: int, src: str
    ) -> int;  def memcpy(dst: bytes, src: int, n: int) -> int;  def memmove(
        dst: int, src: bytes, n: int
    ) -> int;
}
import from jacbootstrap {
    def jac_boot_string(address: int) -> str;  def jac_boot_read(
        path: str, offset: int, buffer: bytes, length: int
    ) -> int;  def jac_boot_write(path: str, data: bytes, length: int) -> bool;  def jac_boot_directory(
        path: str
    ) -> int;  def jac_boot_directory_next(cursor: int) -> int;  def jac_boot_directory_close(
        cursor: int
    ) -> None;
}

def:pub write_file(path: str, data: bytes) -> bool {
    return jac_boot_write(path, data, len(data));
}

def:pub read_at(path: str, off: int, n: int) -> bytes {
    buf = b"\x00" * n;
    got = jac_boot_read(path, off, buf, n);
    return buf[0:got] if got >= 0 else b"";
}

def:pub listdir(path: str) -> list[str] {
    names: list[str] = [];
    cursor = jac_boot_directory(path);
    if cursor == 0 {
        return names;
    }
    name = jac_boot_directory_next(cursor);
    while name != 0 {
        names.append(c_string(name));
        name = jac_boot_directory_next(cursor);
    }
    jac_boot_directory_close(cursor);
    return names;
}

def:pub c_string(ptr: int) -> str {
    return jac_boot_string(ptr);
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
