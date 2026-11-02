"""The Linux side of posix's process identity calls.

Derived from CPython 3.14.6 Modules/posixmodule.c; see ../LICENSE.cpython.
getgrouplist() and initgroups() take a gid_t, setgroups() counts with a
size_t, struct utsname is six 65-byte fields (x86_64 and aarch64 alike),
getlogin_r() fills a UT_NAMESIZE + 1 buffer, and os.getrandom() calls
syscall(SYS_getrandom) (HAVE_GETRANDOM_SYSCALL).
"""

import from jaclang.runtime.python.modules.posix_constants { SYS_getrandom }

import from c {
    def getgrouplist(
        user: str, basegid: u32, groups: ptr[u32], ngroups: &mut i32
    ) -> i32;  def initgroups(user: ptr[u8], group: u32) -> i32;  def setgroups(
        count: u64, groups: ptr[u32]
    ) -> i32;  def setresuid(ruid: u32, euid: u32, suid: u32) -> i32;  def setresgid(
        rgid: u32, egid: u32, sgid: u32
    ) -> i32;  def getresuid(ruid: &mut u32, euid: &mut u32, suid: &mut u32) -> i32;  def getresgid(
        rgid: &mut u32, egid: &mut u32, sgid: &mut u32
    ) -> i32;  def syscall(number: i64, *args: any) -> i64;
}

glob PLATFORM: str = "linux",
     UTSNAME_SIZE: i64 = 390,
     UTSNAME_FIELD_SIZE: i64 = 65,
     LOGIN_NAME_SIZE: i64 = 33;

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
    count = ngroups;
    result = getgrouplist(user, basegid, groups, &mut count);
    return (result, count);
}

def initgroups_darwin(user: ptr[u8], group: i32) -> i32 {
    return i32(-1);
}

def initgroups_linux(user: ptr[u8], group: u32) -> i32 {
    return initgroups(user, group);
}

def set_groups(count: i64, groups: ptr[u32]) -> i32 {
    return setgroups(u64(count), groups);
}

def getrandom_syscall(buffer: ptr, size: i64, flags: i32) -> i64 {
    return syscall(SYS_getrandom, buffer, size, flags);
}

# getresuid() and getresgid(): the result and the real, effective and saved ids.
def get_res_uid -> tuple[i32, u32, u32, u32] {
    ruid = u32(0);
    euid = u32(0);
    suid = u32(0);
    result = getresuid(&mut ruid, &mut euid, &mut suid);
    return (result, ruid, euid, suid);
}

def get_res_gid -> tuple[i32, u32, u32, u32] {
    rgid = u32(0);
    egid = u32(0);
    sgid = u32(0);
    result = getresgid(&mut rgid, &mut egid, &mut sgid);
    return (result, rgid, egid, sgid);
}
