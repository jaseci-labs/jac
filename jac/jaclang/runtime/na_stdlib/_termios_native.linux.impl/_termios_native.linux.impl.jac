impl new_buf -> bytes {
    return b"\x00" * _T_SIZE;
}

impl word_at(buf: bytes, off: int) -> int {
    return int.from_bytes(buf[off:off + _FLAG_BYTES], "little");
}

impl put_word(buf: bytes, off: int, v: int) -> bytes {
    return buf[:off] + v.to_bytes(_FLAG_BYTES, "little") + buf[off + _FLAG_BYTES:];
}

impl get_attrs(fd: int) -> tuple[(bytes, int)] {
    buf: bytes = new_buf();
    rc: int = int(tcgetattr(i32(fd), buf));
    return (buf, rc);
}

impl set_attrs(fd: int, when: int, blob: bytes) -> int {
    return int(tcsetattr(i32(fd), i32(when), blob));
}

impl in_speed(buf: bytes) -> int {
    return int(cfgetispeed(buf));
}

impl out_speed(buf: bytes) -> int {
    return int(cfgetospeed(buf));
}

impl set_speeds(buf: bytes, ispeed: int, ospeed: int) -> int {
    rc: int = int(cfsetispeed(buf, u32(ispeed)));
    if rc != 0 {
        return rc;
    }
    return int(cfsetospeed(buf, u32(ospeed)));
}
