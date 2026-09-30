"""The macOS side of the posix core.

Derived from CPython 3.14.6 Modules/posixmodule.c; see ../LICENSE.cpython.
The shared interpreter reaches the environment through _NSGetEnviron()
(USE_DARWIN_NS_GET_ENVIRON), dev_t is a signed 32-bit int, and there is no
fdatasync().
"""

import from c {
    def dlsym(handle: ptr, symbol: str) -> ptr;  def _NSGetEnviron -> ptr[
        ptr[ptr[u8]]
    ];  def fsync(fd: i32) -> i32;  def fchdir(fd: i32) -> i32;
}

glob PLATFORM: str = "darwin",
     DEV_T_SIGNED_32: bool = True;

def environment_table -> ptr[ptr[u8]] {
    return _NSGetEnviron().view(1)[0];
}

def fildes_call(fd: i32, operation: int) -> i32 {
    if operation == 0 {
        return fsync(fd);
    }
    if operation == 2 {
        return fchdir(fd);
    }
    return i32(-1);
}

# A function newer than the deployment target (mkfifoat and mknodat need
# macOS 13), looked up as a weak import is tested; RTLD_DEFAULT is -2.
def runtime_function(name: str) -> ptr {
    return dlsym(ptr(-2), name);
}
