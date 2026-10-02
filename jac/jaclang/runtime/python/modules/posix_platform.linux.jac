"""The Linux side of the posix core.

Derived from CPython 3.14.6 Modules/posixmodule.c; see ../LICENSE.cpython.
dev_t is an unsigned 64-bit integer.
"""

import from c {
    glob environ: ptr[ptr[u8]]; def dlsym(handle: ptr, symbol: str) -> ptr;  def fsync(
        fd: i32
    ) -> i32;  def fdatasync(fd: i32) -> i32;  def fchdir(fd: i32) -> i32;
}

glob PLATFORM: str = "linux",
     DEV_T_SIGNED_32: bool = False;

def environment_table -> ptr[ptr[u8]] {
    return environ;
}

def fildes_call(fd: i32, operation: int) -> i32 {
    if operation == 0 {
        return fsync(fd);
    }
    if operation == 1 {
        return fdatasync(fd);
    }
    return fchdir(fd);
}

# A C library function looked up at run time; RTLD_DEFAULT is NULL.
def runtime_function(name: str) -> ptr {
    return dlsym(ptr(), name);
}
