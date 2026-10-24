impl new_buf -> bytes {
    raise RuntimeError("termios is unavailable on this platform");
}

impl word_at(buf: bytes, off: int) -> int {
    raise RuntimeError("termios is unavailable on this platform");
}

impl put_word(buf: bytes, off: int, v: int) -> bytes {
    raise RuntimeError("termios is unavailable on this platform");
}

impl get_attrs(fd: int) -> tuple[(bytes, int)] {
    raise RuntimeError("termios is unavailable on this platform");
}

impl set_attrs(fd: int, when: int, blob: bytes) -> int {
    raise RuntimeError("termios is unavailable on this platform");
}

impl in_speed(buf: bytes) -> int {
    raise RuntimeError("termios is unavailable on this platform");
}

impl out_speed(buf: bytes) -> int {
    raise RuntimeError("termios is unavailable on this platform");
}

impl set_speeds(buf: bytes, ispeed: int, ospeed: int) -> int {
    raise RuntimeError("termios is unavailable on this platform");
}
