"""The macOS side of the posix file functions.

Derived from CPython 3.14.6 Modules/posixmodule.c; see ../LICENSE.cpython.
mode_t is 16 bits and dev_t a signed 32-bit int. lchmod(), chflags() and
lchflags() exist here only. mkfifoat() and mknodat() arrived in macOS 13, so
they are looked up at run time (HAVE_MKFIFOAT_RUNTIME, HAVE_MKNODAT_RUNTIME).
There are no Linux extended attributes, posix_fallocate() or posix_fadvise().
"""

import from c {
    def umask(mask: u16) -> u16;  obj MkfifoatFunction {
        has call: Callable[[i32, ptr[u8], u32], i32] = 0;
    }  obj MknodatFunction {
        has call: Callable[[i32, ptr[u8], u32, i32], i32] = 0;
    }  def lchmod(path: ptr[u8], mode: u32) -> i32;  def chflags(
        path: ptr[u8], flags: u32
    ) -> i32;  def lchflags(path: ptr[u8], flags: u32) -> i32;  def mknod(
        path: ptr[u8], mode: u32, device: i32
    ) -> i32;
}
import from jaclang.runtime.python.modules.posix_platform { runtime_function }

glob PLATFORM: str = "darwin",
     MODE_T_MASK: u32 = u32(0xFFFF);

def lchmod_call(path: ptr[u8], mode: u32) -> i32 {
    return lchmod(path, mode);
}

# chflags() takes a 32-bit flags word; C converts the unsigned long.
def chflags_call(path: ptr[u8], flags: u64) -> i32 {
    return chflags(path, u32.wrap(flags));
}

def lchflags_call(path: ptr[u8], flags: u64) -> i32 {
    return lchflags(path, u32.wrap(flags));
}

def mkfifoat_available -> bool {
    return bool(runtime_function("mkfifoat"));
}

def mkfifoat_call(dir_fd: i32, path: ptr[u8], mode: u32) -> i32 {
    function = MkfifoatFunction();
    function.call = int(runtime_function("mkfifoat"));
    return function.call(dir_fd, path, mode);
}

def mknod_call(path: ptr[u8], mode: u32, device: u64) -> i32 {
    return mknod(path, mode, i32.wrap(device));
}

def mknodat_available -> bool {
    return bool(runtime_function("mknodat"));
}

def mknodat_call(dir_fd: i32, path: ptr[u8], mode: u32, device: u64) -> i32 {
    function = MknodatFunction();
    function.call = int(runtime_function("mknodat"));
    return function.call(dir_fd, path, mode, i32.wrap(device));
}

# major(x): ((int32_t)(((u_int32_t)(x) >> 24) & 0xff)).
def dev_major(device: u64) -> u32 {
    return (u32.wrap(device) >> u32(24)) & u32(0xFF);
}

# minor(x): ((int32_t)((x) & 0xffffff)).
def dev_minor(device: u64) -> u32 {
    return u32.wrap(device) & u32(0xFFFFFF);
}

# makedev(x, y): ((dev_t)(((x) << 24) | (y))), in 32-bit arithmetic.
def dev_makedev(major: u64, minor: u64) -> u64 {
    composed = ((u64(u32.wrap(major)) << u64(24)) | u64(u32.wrap(minor)))
        & u64(0xFFFFFFFF);
    return composed;
}

def posix_fallocate_call(fd: i32, offset: i64, length: i64) -> i32 {
    return i32(-1);
}

def posix_fadvise_call(fd: i32, offset: i64, length: i64, advice: i32) -> i32 {
    return i32(-1);
}

def xattr_get(
    fd: i32, path: ptr[u8], follow_symlinks: bool, name: ptr[u8], value: ptr, size: u64
) -> i64 {
    return -1;
}

def xattr_set(
    fd: i32,
    path: ptr[u8],
    follow_symlinks: bool,
    name: ptr[u8],
    value: ptr,
    size: u64,
    flags: i32
) -> i32 {
    return i32(-1);
}

def xattr_remove(fd: i32, path: ptr[u8], follow_symlinks: bool, name: ptr[u8]) -> i32 {
    return i32(-1);
}

def xattr_list(
    fd: i32, path: ptr[u8], follow_symlinks: bool, buffer: ptr[u8], size: u64
) -> i64 {
    return -1;
}

# umask(); mode_t is 16 bits on macOS, as _posixsubprocess declares it.
def umask_call(mask: u32) -> u32 {
    return u32(umask(u16.wrap(mask)));
}
