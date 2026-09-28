"""_posixsubprocess child primitives for a target with no posixsubprocess_platform.<os>.jac; the binding rejects it."""

glob PLATFORM: str = "",
     FD_DIR: str = "",
     VFORK_USABLE: bool = False,
     SIGSET_SIZE: i64 = 0,
     SIGACTION_SIZE: i64 = 0,
     DIRENT_BUFFER_SIZE: i64 = 0;

def set_umask(mask: i32) {}

def set_groups(count: i64, groups: ptr) -> i32 {
    return i32(-1);
}

def close_open_fds(
    start_fd: i32, fds_to_keep: ptr[i32], count: i64, fd_dir: ptr[u8], buffer: ptr
) {}

def reset_signal_handlers(
    child_sigmask: ptr, current_action: ptr, default_action: ptr
) {}

def block_signals(all_signals: ptr, old_signals: ptr) -> i32 {
    return i32(0);
}

def set_signal_mask(signals: ptr) -> i32 {
    return i32(0);
}
