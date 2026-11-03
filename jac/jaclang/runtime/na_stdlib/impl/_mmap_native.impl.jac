impl mm_map(length: int, prot: int, flags: int, fd: int, offset: int) -> int {
    return mmap(0, u64(length), i32(prot), i32(flags), i32(fd), i64(offset));
}


impl mm_unmap(addr: int, length: int) -> int {
    return munmap(addr, u64(length));
}


impl mm_sync(addr: int, length: int) -> int {
    return msync(addr, u64(length), i32(mm_sync_flag()));
}


impl mm_filesize(fd: int) -> int {
    cur = lseek(i32(fd), 0, 1);
    end = lseek(i32(fd), 0, 2);
    if cur >= 0 {
        lseek(i32(fd), i64(cur), 0);
    }
    return int(end);
}


impl mm_read(addr: int, n: int) -> bytes {
    if n <= 0 {
        return b"";
    }
    buf = b"\x00" * n;
    memcpy(buf, addr, u64(n));
    return buf;
}


impl mm_write(addr: int, data: bytes) -> int {
    n = len(data);
    if n == 0 {
        return 0;
    }
    memmove(addr, data, u64(n));
    return n;
}


impl mm_copy(dst_addr: int, src_addr: int, n: int) {
    if n <= 0 {
        return;
    }
    buf = b"\x00" * n;
    memcpy(buf, src_addr, u64(n));
    memmove(dst_addr, buf, u64(n));
}


impl mm_errno -> int {
    return last_errno();
}


impl mm_errstr -> str {
    return errno_message();
}
