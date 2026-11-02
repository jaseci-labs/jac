impl executable_path -> str {
    buf = b"\x00" * 4096;
    n = __jac_executable_path(buf, 4096);
    if n <= 0 {
        return "";
    }
    return buf[0:n].decode();
}
