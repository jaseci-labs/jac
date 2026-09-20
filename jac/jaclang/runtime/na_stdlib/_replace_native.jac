import from c { def renameat(src_fd: i32, src: str, dst_fd: i32, dst: str) -> i32;  }
import from _fd_native { AT_FDCWD }
import from _errno_native { last_errno, raise_os_error }

def:pub replace_file(
    src: str, dst: str, src_dir_fd: int | None, dst_dir_fd: int | None
) {
    if "\x00" in src or "\x00" in dst {
        raise ValueError("embedded null byte");
    }
    source_fd = AT_FDCWD if src_dir_fd is None else src_dir_fd;
    destination_fd = AT_FDCWD if dst_dir_fd is None else dst_dir_fd;
    if source_fd < -2147483648
        or source_fd > 2147483647
        or destination_fd < -2147483648
        or destination_fd > 2147483647 {
        raise OverflowError("file descriptor out of range");
    }
    if renameat(i32(source_fd), src, i32(destination_fd), dst) != i32(0) {
        code = last_errno();
        raise_os_error("replace", src + " -> " + dst, code);
    }
}
