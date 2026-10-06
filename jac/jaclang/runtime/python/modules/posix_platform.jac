"""posix core primitives for a target with no posix_platform.<os>.jac; the binding rejects it."""

glob PLATFORM: str = "",
     DEV_T_SIGNED_32: bool = False;

# The C library's environment block (char **environ), NULL when absent.
def environment_table -> ptr[ptr[u8]] {
    return ptr[ptr[u8]]();
}

# posix_fildes_fd()'s call: 0 fsync, 1 fdatasync, 2 fchdir.
def fildes_call(fd: i32, operation: int) -> i32 {
    return i32(-1);
}

# The address of a C library function the target may lack at run time,
# NULL when it does.
def runtime_function(name: str) -> ptr {
    return ptr();
}
