"""POSIX syscall result helpers (WA-6.1-A sign-extension workaround).

C functions returning int -1 are zero-extended to a large positive i64 in Jac
Native FFI.  Use is_c_error() instead of comparing against -1 or fd < 0.
"""

import from engine.src.ffi.libc { get_errno }

glob C_ERR_THRESHOLD: int = 2147483647;

"""True if a C int return value indicates failure (-1 sign-extended to u64)."""
def:pub is_c_error(rc: int) -> bool {
    return rc > C_ERR_THRESHOLD;
}

"""Return errno from the last failed syscall."""
def:pub c_errno -> int {
    return get_errno();
}

"""True if fd is a valid non-error file descriptor."""
def:pub is_valid_fd(fd: int) -> bool {
    if fd == 0 {
        return False;
    }
    return not is_c_error(fd);
}

"""Return fd if valid, else 0."""
def:pub require_fd(fd: int) -> int {
    if is_valid_fd(fd) {
        return fd;
    }
    return 0;
}
