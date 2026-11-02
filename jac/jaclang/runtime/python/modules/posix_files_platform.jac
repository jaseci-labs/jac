"""posix file primitives for a target with no posix_files_platform.<os>.jac; the binding rejects it."""

glob PLATFORM: str = "",
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
    return False;
}

def mkfifoat_call(dir_fd: i32, path: ptr[u8], mode: u32) -> i32 {
    return i32(-1);
}

def mknod_call(path: ptr[u8], mode: u32, device: u64) -> i32 {
    return i32(-1);
}

def mknodat_available -> bool {
    return False;
}

def mknodat_call(dir_fd: i32, path: ptr[u8], mode: u32, device: u64) -> i32 {
    return i32(-1);
}

def dev_major(device: u64) -> u32 {
    return u32(0);
}

def dev_minor(device: u64) -> u32 {
    return u32(0);
}

def dev_makedev(major: u64, minor: u64) -> u64 {
    return u64(0);
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

# umask().
def umask_call(mask: u32) -> u32 {
    return 0;
}
