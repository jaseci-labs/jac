"""The macOS side of the _posixsubprocess child.

Derived from CPython 3.14.6 Modules/_posixsubprocess.c; see ../LICENSE.cpython.
There is no vfork() path (VFORK_USABLE is Linux-only), and open descriptors
are listed with opendir() on /dev/fd, which the C module also accepts as not
strictly async-signal-safe (_close_open_fds_maybe_unsafe).
"""

import from jaclang.runtime.python.cpython_api {
    jacpy_closedir,
    jacpy_dirfd,
    jacpy_errno,
    jacpy_opendir,
    jacpy_readdir_name,
    jacpy_set_errno
}
import from jaclang.runtime.python.modules.posixsubprocess_fds {
    CLOSE_RANGE,
    close_range_except,
    fd_in_sorted_fd_sequence,
    pos_int_from_ascii
}
import from c {
    def close(fd: i32) -> i32;  def umask(mask: u16) -> u16;  def setgroups(
        count: i32, groups: ptr
    ) -> i32;
}

glob PLATFORM: str = "darwin",
     FD_DIR: str = "/dev/fd",
     VFORK_USABLE: bool = False,
     # sigset_t and struct sigaction are only used on the vfork() path.
     SIGSET_SIZE: i64 = 4,
     SIGACTION_SIZE: i64 = 16,
     # The Linux getdents64() buffer; opendir() allocates its own here.
     DIRENT_BUFFER_SIZE: i64 = 0;

def set_umask(mask: i32) {
    umask(u16.wrap(mask));
}

def set_groups(count: i64, groups: ptr) -> i32 {
    return setgroups(i32(count), groups);
}

# Close every open descriptor from start_fd up, except the sorted
# fds_to_keep. `fd_dir` is FD_DIR as a C string; `buffer` is unused here.
def close_open_fds(
    start_fd: i32, fds_to_keep: ptr[i32], count: i64, fd_dir: ptr[u8], buffer: ptr
) {
    directory = jacpy_opendir(fd_dir);
    if not directory {
        # No way to get a list of open fds.
        close_range_except(start_fd, i32(-1), fds_to_keep, count, CLOSE_RANGE);
        return;
    }
    fd_used_by_opendir = jacpy_dirfd(directory);
    jacpy_set_errno(0);
    while True {
        name = jacpy_readdir_name(directory);
        if name.is_null() {
            break;
        }
        fd = pos_int_from_ascii(name);
        if fd >= 0
            and fd != fd_used_by_opendir
            and fd >= start_fd
            and not fd_in_sorted_fd_sequence(fd, fds_to_keep, count) {
            close(fd);
        }
        jacpy_set_errno(0);
    }
    if jacpy_errno() != 0 {
        # readdir error, revert behavior. Highly unlikely.
        close_range_except(start_fd, i32(-1), fds_to_keep, count, CLOSE_RANGE);
    }
    jacpy_closedir(directory);
}

# Only the Linux vfork() child resets signal dispositions.
def reset_signal_handlers(
    child_sigmask: ptr, current_action: ptr, default_action: ptr
) {}

def block_signals(all_signals: ptr, old_signals: ptr) -> i32 {
    return i32(0);
}

def set_signal_mask(signals: ptr) -> i32 {
    return i32(0);
}
