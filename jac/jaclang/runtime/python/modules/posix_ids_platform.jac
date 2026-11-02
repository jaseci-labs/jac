"""posix process identity calls for a target with no posix_ids_platform.<os>.jac; the binding rejects it."""

glob PLATFORM: str = "",
     # sizeof(struct utsname) and the length of each of its char fields.
     UTSNAME_SIZE: i64 = 0,
     UTSNAME_FIELD_SIZE: i64 = 0,
     # The name buffer os.getlogin() hands getlogin_r().
     LOGIN_NAME_SIZE: i64 = 0;

# getgrouplist() and the group count it leaves, which on failure may be the
# total the list needs.
def getgrouplist_darwin(
    user: str, basegid: i32, groups: ptr[i32], ngroups: i32
) -> tuple[i32, i32] {
    return (i32(-1), ngroups);
}

def getgrouplist_linux(
    user: str, basegid: u32, groups: ptr[u32], ngroups: i32
) -> tuple[i32, i32] {
    return (i32(-1), ngroups);
}

def initgroups_darwin(user: ptr[u8], group: i32) -> i32 {
    return i32(-1);
}

def initgroups_linux(user: ptr[u8], group: u32) -> i32 {
    return i32(-1);
}

# setgroups(): the count is an int on macOS and a size_t on Linux.
def set_groups(count: i64, groups: ptr[u32]) -> i32 {
    return i32(-1);
}

def setresuid(ruid: u32, euid: u32, suid: u32) -> i32 {
    return i32(-1);
}

def setresgid(rgid: u32, egid: u32, sgid: u32) -> i32 {
    return i32(-1);
}

# getresuid() and getresgid(): the result and the real, effective and saved ids.
def get_res_uid -> tuple[i32, u32, u32, u32] {
    return (i32(-1), u32(0), u32(0), u32(0));
}

def get_res_gid -> tuple[i32, u32, u32, u32] {
    return (i32(-1), u32(0), u32(0), u32(0));
}

# syscall(SYS_getrandom, buffer, size, flags).
def getrandom_syscall(buffer: ptr, size: i64, flags: i32) -> i64 {
    return -1;
}
