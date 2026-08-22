import from c { def _NSGetExecutablePath(buf: bytes, bufsize: bytes) -> i32;  }

def:pub executable_path -> str {
    buf = b"\x00" * 4096;
    size = (4096).to_bytes(4, "little");
    if _NSGetExecutablePath(buf, size) != 0 {
        return "";
    }
    n = 0;
    while n < 4096 and buf[n] != 0 {
        n += 1;
    }
    return buf[0:n].decode();
}
