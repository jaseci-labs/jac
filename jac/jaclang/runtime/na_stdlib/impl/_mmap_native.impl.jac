impl mm_map(length: int, prot: int, flags: int, fd: int, offset: int) -> int {
    return mmap(0, u64(length), i32(prot), i32(flags), i32(fd), i64(offset));
}


impl _stat_mode_pos -> tuple[int, int] {
    if _SM_OFF >= 0 {
        return (_SM_OFF, _SM_W);
    }
    pid = int(__jac_platform_id());
    if pid == 1 {
        _SM_OFF = 4;
        _SM_W = 2;
    } elif pid == 0 and plat_machine() == "x86_64" {
        _SM_OFF = 24;
        _SM_W = 4;
    } elif pid == 0 {
        _SM_OFF = 16;
        _SM_W = 4;
    }
    return (_SM_OFF, _SM_W);
}

impl mm_isreg(fd: int) -> bool {
    pos = _stat_mode_pos();
    if pos[0] < 0 {
        return False;
    }
    buf = b"\x00" * 256;
    if __jac_fstat_record(i32(fd), buf) != 0 {
        return False;
    }
    base = __bytes_data(buf);
    mode: int = 0;
    if pos[1] == 2 {
        mode = __mem_load_i16(base + pos[0]) & 0xFFFF;
    } else {
        mode = __mem_load_i32(base + pos[0]) & 0xFFFFFFFF;
    }
    return (mode & 0xF000) == 0x8000;
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


impl mm_dup_fd(fd: int) -> int {
    return int(fcntl(i32(fd), i32(mm_dupfd_cloexec_cmd()), i64(0)));
}


impl mm_close_fd(fd: int) -> int {
    return close(i32(fd));
}
