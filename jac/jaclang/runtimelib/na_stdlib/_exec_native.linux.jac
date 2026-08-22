import from c { def readlink(path: str, buf: bytes, bufsiz: int) -> int;  }

def:pub executable_path -> str {
    buf = b"\x00" * 4096;
    n = readlink("/proc/self/exe", buf, 4095);
    if n <= 0 {
        return "";
    }
    return buf[0:n].decode();
}
