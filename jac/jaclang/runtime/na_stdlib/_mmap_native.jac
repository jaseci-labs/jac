import from c {
    def mmap(
        addr: int, length: u64, prot: i32, flags: i32, fd: i32, offset: i64
    ) -> int;
}
import from c { def munmap(addr: int, length: u64) -> i32;  }
import from c { def msync(addr: int, length: u64, flags: i32) -> i32;  }
import from c { def lseek(fd: i32, off: i64, whence: i32) -> i64;  }
import from c { def fcntl(fd: i32, cmd: i32, *args: VaList) -> i32;  }
import from c { def close(fd: i32) -> i32;  }
import from c { def memcpy(dst: bytes, src: int, n: u64) -> int;  }
import from c { def memmove(dst: int, src: bytes, n: u64) -> int;  }
import from _errno_native { last_errno, errno_message }
import from _mmap_platform { mm_sync_flag, mm_dupfd_cloexec_cmd }


def:pub mm_map(length: int, prot: int, flags: int, fd: int, offset: int) -> int;


def:pub mm_unmap(addr: int, length: int) -> int;


def:pub mm_sync(addr: int, length: int) -> int;


def:pub mm_filesize(fd: int) -> int;


def:pub mm_read(addr: int, n: int) -> bytes;


def:pub mm_write(addr: int, data: bytes) -> int;


def:pub mm_copy(dst_addr: int, src_addr: int, n: int);


def:pub mm_errno -> int;


def:pub mm_errstr -> str;


def:pub mm_dup_fd(fd: int) -> int;


def:pub mm_close_fd(fd: int) -> int;
