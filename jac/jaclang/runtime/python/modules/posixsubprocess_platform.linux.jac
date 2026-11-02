"""The Linux side of the _posixsubprocess child.

Derived from CPython 3.14.6 Modules/_posixsubprocess.c; see ../LICENSE.cpython.
Linux may start the child with vfork() (VFORK_USABLE), resetting handled
signals to SIG_DFL before unblocking them, and lists open descriptors with
getdents64() on /proc/self/fd into a buffer the parent allocated
(_close_open_fds_safe). JacPython links glibc 2.17, which has no
close_range(), so the C module's close_range() path is not taken either.
Layouts are glibc's on x86_64 and aarch64: sigset_t is 128 bytes, struct
sigaction 152 with the handler first, and struct linux_dirent64 has d_reclen
at byte 16 and d_name at byte 19.
"""

import from jaclang.runtime.python.cpython_api { _Py_open_noraise }
import from jaclang.runtime.python.modules.posixsubprocess_constants {
    O_RDONLY,
    SIGKILL,
    SIGSTOP,
    SIG_BLOCK,
    SIG_SETMASK,
    NSIG,
    SYS_getdents64
}
import from jaclang.runtime.python.modules.posixsubprocess_fds {
    CLOSE_EACH,
    close_range_except,
    fd_in_sorted_fd_sequence,
    pos_int_from_ascii
}
import from c {
    def close(fd: i32) -> i32;  def umask(mask: u32) -> u32;  def setgroups(
        count: u64, groups: ptr
    ) -> i32;  def sigismember(signals: ptr, sig: i32) -> i32;  def sigaction(
        sig: i32, action: ptr, old_action: ptr
    ) -> i32;  def sigfillset(signals: ptr) -> i32;  def pthread_sigmask(
        how: i32, signals: ptr, old_signals: ptr
    ) -> i32;
    # getdents64() through syscall(), which glibc before 2.30 has no wrapper for.
    def syscall(number: i64, *args: any) -> i64;
}

glob PLATFORM: str = "linux",
     FD_DIR: str = "/proc/self/fd",
     VFORK_USABLE: bool = True,
     SIGSET_SIZE: i64 = 128,
     SIGACTION_SIZE: i64 = 152,
     DIRENT_BUFFER_SIZE: i64 = 280,
     DIRENT_RECLEN: i64 = 16,
     DIRENT_NAME: i64 = 19,
     SIG_DFL: u64 = 0,
     SIG_IGN: u64 = 1;

def set_umask(mask: i32) {
    umask(u32.wrap(mask));
}

def set_groups(count: i64, groups: ptr) -> i32 {
    return setgroups(u64(count), groups);
}

# Close every open descriptor from start_fd up, except the sorted
# fds_to_keep, without allocating: `fd_dir` is FD_DIR as a C string and
# `buffer` holds DIRENT_BUFFER_SIZE bytes for getdents64().
def close_open_fds(
    start_fd: i32, fds_to_keep: ptr[i32], count: i64, fd_dir: ptr[u8], buffer: ptr
) {
    fd_dir_fd = _Py_open_noraise(fd_dir, i32(O_RDONLY));
    if fd_dir_fd == -1 {
        # No way to get a list of open fds.
        close_range_except(start_fd, i32(-1), fds_to_keep, count, CLOSE_EACH);
        return;
    }
    entries = ptr[u8](buffer);
    while True {
        size = syscall(SYS_getdents64, fd_dir_fd, buffer, u64(DIRENT_BUFFER_SIZE));
        if size <= 0 {
            break;
        }
        offset = i64(0);
        while offset < size {
            record = entries + offset;
            fd = pos_int_from_ascii(record + DIRENT_NAME);
            if fd >= 0
                and fd != fd_dir_fd
                and fd >= start_fd
                and not fd_in_sorted_fd_sequence(fd, fds_to_keep, count) {
                close(fd);
            }
            offset += i64(ptr[u16](record + DIRENT_RECLEN).view(1)[0]);
        }
    }
    close(fd_dir_fd);
}

# Reset every handled signal that execve() will not reset (it is not blocked
# in child_sigmask) to SIG_DFL, so no handler runs in a vfork() child once
# signals are unblocked. `current_action` and `default_action` are
# SIGACTION_SIZE-byte buffers; `default_action` is zeroed (SIG_DFL).
def reset_signal_handlers(
    child_sigmask: ptr, current_action: ptr, default_action: ptr
) {
    handler = ptr[u64](current_action);
    sig = i32(1);
    while i64(sig) < NSIG {
        # SIGKILL and SIGSTOP dispositions cannot be changed, and C libraries
        # reject the signals they use internally.
        if i64(sig) != SIGKILL
            and i64(sig) != SIGSTOP
            and sigismember(child_sigmask, sig) != 1
            and sigaction(sig, ptr(), current_action) != -1 {
            # sa_handler and sa_sigaction share the first word.
            current = handler.view(1)[0];
            if current != SIG_IGN and current != SIG_DFL {
                sigaction(sig, default_action, ptr());
            }
        }
        sig += 1;
    }
}

# Block every signal in the parent before vfork(); the error number or 0.
def block_signals(all_signals: ptr, old_signals: ptr) -> i32 {
    sigfillset(all_signals);
    return pthread_sigmask(i32(SIG_BLOCK), all_signals, old_signals);
}

def set_signal_mask(signals: ptr) -> i32 {
    return pthread_sigmask(i32(SIG_SETMASK), signals, ptr());
}
