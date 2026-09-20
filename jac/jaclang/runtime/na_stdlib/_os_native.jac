import from _replace_native { replace_file }

def:pub replace(
    src: str, dst: str, *, src_dir_fd: int | None = None, dst_dir_fd: int | None = None
) {
    replace_file(src, dst, src_dir_fd, dst_dir_fd);
}
