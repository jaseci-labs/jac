import from c {
    def mmap(
        addr: int, length: u64, prot: i32, flags: i32, fd: i32, offset: i64
    ) -> int;
}
import from c { def munmap(addr: int, length: u64) -> i32;  }
import from c { def msync(addr: int, length: u64, flags: i32) -> i32;  }
import from c { def lseek(fd: i32, off: i64, whence: i32) -> i64;  }
import from c { def memcpy(dst: bytes, src: int, n: u64) -> int;  }
import from c { def memmove(dst: int, src: bytes, n: u64) -> int;  }
import from _errno_native { last_errno, errno_message }
import from _mmap_platform { mm_sync_flag }


def:pub mm_map(length: int, prot: int, flags: int, fd: int, offset: int) -> int {
    return mmap(0, u64(length), i32(prot), i32(flags), i32(fd), i64(offset));
}


def:pub mm_unmap(addr: int, length: int) -> int {
    return munmap(addr, u64(length));
}


def:pub mm_sync(addr: int, length: int) -> int {
    return msync(addr, u64(length), i32(mm_sync_flag()));
}


def:pub mm_filesize(fd: int) -> int {
    cur = lseek(i32(fd), 0, 1);
    end = lseek(i32(fd), 0, 2);
    if cur >= 0 {
        lseek(i32(fd), i64(cur), 0);
    }
    return int(end);
}


def:pub mm_read(addr: int, n: int) -> bytes {
    if n <= 0 {
        return b"";
    }
    buf = b"\x00" * n;
    memcpy(buf, addr, u64(n));
    return buf;
}


def:pub mm_write(addr: int, data: bytes) -> int {
    n = len(data);
    if n == 0 {
        return 0;
    }
    memmove(addr, data, u64(n));
    return n;
}


def:pub mm_copy(dst_addr: int, src_addr: int, n: int) {
    if n <= 0 {
        return;
    }
    buf = b"\x00" * n;
    memcpy(buf, src_addr, u64(n));
    memmove(dst_addr, buf, u64(n));
}


def:pub mm_errno -> int {
    return last_errno();
}


def:pub mm_errstr -> str {
    return errno_message();
}
