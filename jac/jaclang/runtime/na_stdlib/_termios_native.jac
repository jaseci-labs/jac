def:pub new_buf -> bytes;

def:pub word_at(buf: bytes, off: int) -> int;

def:pub put_word(buf: bytes, off: int, v: int) -> bytes;

def:pub get_attrs(fd: int) -> tuple[(bytes, int)];

def:pub set_attrs(fd: int, when: int, blob: bytes) -> int;

def:pub in_speed(buf: bytes) -> int;

def:pub out_speed(buf: bytes) -> int;

def:pub set_speeds(buf: bytes, ispeed: int, ospeed: int) -> int;

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
