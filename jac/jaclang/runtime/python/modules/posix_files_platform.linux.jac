"""The Linux side of the posix file functions.

Derived from CPython 3.14.6 Modules/posixmodule.c; see ../LICENSE.cpython.
mode_t is 32 bits and dev_t an unsigned 64-bit integer, split by glibc's
gnu_dev_major/gnu_dev_minor/gnu_dev_makedev. The extended attribute calls
(USE_XATTRS), posix_fallocate() and posix_fadvise() exist here only; there
is no lchmod(), chflags() or lchflags().
"""

import from c {
    def umask(mask: u32) -> u32;  def mkfifoat(
        dir_fd: i32, path: ptr[u8], mode: u32
    ) -> i32;  def mknod(path: ptr[u8], mode: u32, device: u64) -> i32;  def mknodat(
        dir_fd: i32, path: ptr[u8], mode: u32, device: u64
    ) -> i32;  def posix_fallocate(fd: i32, offset: i64, length: i64) -> i32;  def posix_fadvise(
        fd: i32, offset: i64, length: i64, advice: i32
    ) -> i32;  def getxattr(
        path: ptr[u8], name: ptr[u8], value: ptr, size: u64
    ) -> i64;  def lgetxattr(
        path: ptr[u8], name: ptr[u8], value: ptr, size: u64
    ) -> i64;  def fgetxattr(fd: i32, name: ptr[u8], value: ptr, size: u64) -> i64;  def setxattr(
        path: ptr[u8], name: ptr[u8], value: ptr, size: u64, flags: i32
    ) -> i32;  def lsetxattr(
        path: ptr[u8], name: ptr[u8], value: ptr, size: u64, flags: i32
    ) -> i32;  def fsetxattr(
        fd: i32, name: ptr[u8], value: ptr, size: u64, flags: i32
    ) -> i32;  def removexattr(path: ptr[u8], name: ptr[u8]) -> i32;  def lremovexattr(
        path: ptr[u8], name: ptr[u8]
    ) -> i32;  def fremovexattr(fd: i32, name: ptr[u8]) -> i32;  def listxattr(
        path: ptr[u8], buffer: ptr[u8], size: u64
    ) -> i64;  def llistxattr(path: ptr[u8], buffer: ptr[u8], size: u64) -> i64;  def flistxattr(
        fd: i32, buffer: ptr[u8], size: u64
    ) -> i64;
}

glob PLATFORM: str = "linux",
     MODE_T_MASK: u32 = u32(0xFFFFFFFF);

def lchmod_call(path: ptr[u8], mode: u32) -> i32 {
    return i32(-1);
}

def chflags_call(path: ptr[u8], flags: u64) -> i32 {
    return i32(-1);
}

def lchflags_call(path: ptr[u8], flags: u64) -> i32 {
    return i32(-1);
}

def mkfifoat_available -> bool {
    return True;
}

def mkfifoat_call(dir_fd: i32, path: ptr[u8], mode: u32) -> i32 {
    return mkfifoat(dir_fd, path, mode);
}

def mknod_call(path: ptr[u8], mode: u32, device: u64) -> i32 {
    return mknod(path, mode, device);
}

def mknodat_available -> bool {
    return True;
}

def mknodat_call(dir_fd: i32, path: ptr[u8], mode: u32, device: u64) -> i32 {
    return mknodat(dir_fd, path, mode, device);
}

# gnu_dev_major: ((dev >> 8) & 0xfff) | ((unsigned int)(dev >> 32) & ~0xfff).
def dev_major(device: u64) -> u32 {
    return u32.wrap((device >> u64(8)) & u64(0xFFF))
        | (u32.wrap(device >> u64(32)) & u32(0xFFFFF000));
}

# gnu_dev_minor: (dev & 0xff) | ((unsigned int)(dev >> 12) & ~0xff).
def dev_minor(device: u64) -> u32 {
    return u32.wrap(device & u64(0xFF))
        | (u32.wrap(device >> u64(12)) & u32(0xFFFFFF00));
}

# gnu_dev_makedev over the unsigned int major and minor.
def dev_makedev(major: u64, minor: u64) -> u64 {
    high = u64(u32.wrap(major));
    low = u64(u32.wrap(minor));
    return (low & u64(0xFF))
        | ((high & u64(0xFFF)) << u64(8))
        | ((low & u64(0xFFFFFF00)) << u64(12))
        | ((high & u64(0xFFFFF000)) << u64(32));
}

def posix_fallocate_call(fd: i32, offset: i64, length: i64) -> i32 {
    return posix_fallocate(fd, offset, length);
}

def posix_fadvise_call(fd: i32, offset: i64, length: i64, advice: i32) -> i32 {
    return posix_fadvise(fd, offset, length, advice);
}

def xattr_get(
    fd: i32, path: ptr[u8], follow_symlinks: bool, name: ptr[u8], value: ptr, size: u64
) -> i64 {
    if fd >= 0 {
        return fgetxattr(fd, name, value, size);
    }
    if follow_symlinks {
        return getxattr(path, name, value, size);
    }
    return lgetxattr(path, name, value, size);
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
    if fd > -1 {
        return fsetxattr(fd, name, value, size, flags);
    }
    if follow_symlinks {
        return setxattr(path, name, value, size, flags);
    }
    return lsetxattr(path, name, value, size, flags);
}

def xattr_remove(fd: i32, path: ptr[u8], follow_symlinks: bool, name: ptr[u8]) -> i32 {
    if fd > -1 {
        return fremovexattr(fd, name);
    }
    if follow_symlinks {
        return removexattr(path, name);
    }
    return lremovexattr(path, name);
}

def xattr_list(
    fd: i32, path: ptr[u8], follow_symlinks: bool, buffer: ptr[u8], size: u64
) -> i64 {
    if fd > -1 {
        return flistxattr(fd, buffer, size);
    }
    if follow_symlinks {
        return listxattr(path, buffer, size);
    }
    return llistxattr(path, buffer, size);
}

# umask().
def umask_call(mask: u32) -> u32 {
    return umask(mask);
}
