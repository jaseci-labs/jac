"""The macOS side of posix's process identity calls.

Derived from CPython 3.14.6 Modules/posixmodule.c; see ../LICENSE.cpython.
getgrouplist() and initgroups() take the group as an int (__APPLE__),
setgroups() counts with an int, struct utsname is five 256-byte fields and
getlogin_r() fills a MAXLOGNAME + 1 buffer. There is no setresuid() family
and no getrandom system call; those stand-ins are never called.
"""

import from c {
    def getgrouplist(
        user: str, basegid: i32, groups: ptr[i32], ngroups: &mut i32
    ) -> i32;  def initgroups(user: ptr[u8], group: i32) -> i32;  def setgroups(
        count: i32, groups: ptr[u32]
    ) -> i32;
}

glob PLATFORM: str = "darwin",
     UTSNAME_SIZE: i64 = 1280,
     UTSNAME_FIELD_SIZE: i64 = 256,
     LOGIN_NAME_SIZE: i64 = 256;

# getgrouplist() and the group count it leaves, which on failure may be the
# total the list needs.
def getgrouplist_darwin(
    user: str, basegid: i32, groups: ptr[i32], ngroups: i32
) -> tuple[i32, i32] {
    count = ngroups;
    result = getgrouplist(user, basegid, groups, &mut count);
    return (result, count);
}

def getgrouplist_linux(
    user: str, basegid: u32, groups: ptr[u32], ngroups: i32
) -> tuple[i32, i32] {
    return (i32(-1), ngroups);
}

def initgroups_darwin(user: ptr[u8], group: i32) -> i32 {
    return initgroups(user, group);
}

def initgroups_linux(user: ptr[u8], group: u32) -> i32 {
    return i32(-1);
}

def set_groups(count: i64, groups: ptr[u32]) -> i32 {
    return setgroups(i32(count), groups);
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

def getrandom_syscall(buffer: ptr, size: i64, flags: i32) -> i64 {
    return -1;
}
