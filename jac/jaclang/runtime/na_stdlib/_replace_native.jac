import from c { def renameat(src_fd: i32, src: str, dst_fd: i32, dst: str) -> i32;  }

def:pub replace_file(
    src: str, dst: str, src_dir_fd: int | None, dst_dir_fd: int | None
);
