"""The Linux side of the posix file descriptor area.

Derived from CPython 3.14.6 Modules/posixmodule.c and
Include/internal/pycore_fileutils.h; see ../LICENSE.cpython. pipe2, dup3,
splice, eventfd and timerfd come from glibc 2.17; its sendfile() takes an
optional offset pointer. memfd_create (glibc 2.27), copy_file_range (glibc
2.27), preadv2 and pwritev2 (glibc 2.26) are missing from the glibc the
target links against, and the Apple-only sendfile() record and fcopyfile()
are absent; those entries are never reached, since the binding installs only
the functions the target compiles.
"""

import from jaclang.runtime.python.cpython_api { jacpy_set_errno }
import from jaclang.runtime.python.modules.posix_constants { ENOSYS }
import from jaclang.runtime.python.modules.time_records { timespec }

import from c {
    obj iovec {
        has iov_base: ptr = ptr(),
            iov_len: u64 = 0;
    }  obj fd_pair {
        has fd0: i32 = 0,
            fd1: i32 = 0;
    }  obj itimerspec {
        has it_interval: timespec,
            it_value: timespec;
    }  def sendfile(
        out_fd: i32, in_fd: i32, offset: &mut i64 | None, count: u64
    ) -> i64;  def ctermid(buffer: ptr[u8]) -> ptr[u8];  def dup3(
        fd: i32, fd2: i32, flags: i32
    ) -> i32;  def pipe2(fds: &mut fd_pair, flags: i32) -> i32;  def splice(
        fd_in: i32,
        off_in: &mut i64 | None,
        fd_out: i32,
        off_out: &mut i64 | None,
        len: u64,
        flags: u32
    ) -> i64;  def eventfd(initval: u32, flags: i32) -> i32;  def eventfd_read(
        fd: i32, value: &mut u64
    ) -> i32;  def eventfd_write(fd: i32, value: u64) -> i32;  def timerfd_create(
        clockid: i32, flags: i32
    ) -> i32;  def timerfd_settime(
        fd: i32, flags: i32, new_value: &itimerspec, old_value: &mut itimerspec
    ) -> i32;  def timerfd_gettime(fd: i32, curr_value: &mut itimerspec) -> i32;
}

glob PLATFORM: str = "linux",
     PY_READ_MAX: i64 = 9223372036854775807;

def:priv unavailable -> i32 {
    jacpy_set_errno(ENOSYS);
    return i32(-1);
}

def ctermid_call(buffer: ptr[u8]) -> ptr[u8] {
    return ctermid(buffer);
}

def dup3_call(fd: i32, fd2: i32, flags: i32) -> i32 {
    return dup3(fd, fd2, flags);
}

def pipe2_call(fds: &mut fd_pair, flags: i32) -> i32 {
    return pipe2(fds, flags);
}

def preadv2_call(fd: i32, iov: ptr[iovec], cnt: i32, offset: i64, flags: i32) -> i64 {
    return i64(unavailable());
}

def pwritev2_call(fd: i32, iov: ptr[iovec], cnt: i32, offset: i64, flags: i32) -> i64 {
    return i64(unavailable());
}

def sendfile_darwin_call(
    fd: i32,
    s: i32,
    offset: i64,
    length: i64,
    headers: ptr[iovec],
    hdr_cnt: i32,
    trailers: ptr[iovec],
    trl_cnt: i32,
    flags: i32
) -> tuple[i64, i64] {
    return (i64(unavailable()), length);
}

def sendfile_linux_call(
    out_fd: i32, in_fd: i32, has_offset: bool, offset: i64, count: u64
) -> tuple[i64, i64] {
    if not has_offset {
        return (sendfile(out_fd, in_fd, None, count), offset);
    }
    current = offset;
    ret = sendfile(out_fd, in_fd, &mut current, count);
    return (ret, current);
}

def fcopyfile_call(in_fd: i32, out_fd: i32, flags: i32) -> i32 {
    return unavailable();
}

def copy_file_range_call(
    src: i32,
    has_src: bool,
    offset_src: i64,
    dst: i32,
    has_dst: bool,
    offset_dst: i64,
    count: u64,
    flags: u32
) -> tuple[i64, i64, i64] {
    return (i64(unavailable()), offset_src, offset_dst);
}

def splice_call(
    src: i32,
    has_src: bool,
    offset_src: i64,
    dst: i32,
    has_dst: bool,
    offset_dst: i64,
    count: u64,
    flags: u32
) -> tuple[i64, i64, i64] {
    src_value = offset_src;
    dst_value = offset_dst;
    ret = i64(0);
    if has_src and has_dst {
        ret = splice(src, &mut src_value, dst, &mut dst_value, count, flags);
    } elif has_src {
        ret = splice(src, &mut src_value, dst, None, count, flags);
    } elif has_dst {
        ret = splice(src, None, dst, &mut dst_value, count, flags);
    } else {
        ret = splice(src, None, dst, None, count, flags);
    }
    return (ret, src_value, dst_value);
}

def memfd_create_call(name: ptr[u8], flags: u32) -> i32 {
    return unavailable();
}

def eventfd_call(initval: u32, flags: i32) -> i32 {
    return eventfd(initval, flags);
}

def eventfd_read_call(fd: i32) -> tuple[i32, u64] {
    value = u64(0);
    result = eventfd_read(fd, &mut value);
    return (result, value);
}

def eventfd_write_call(fd: i32, value: u64) -> i32 {
    return eventfd_write(fd, value);
}

def timerfd_create_call(clockid: i32, flags: i32) -> i32 {
    return timerfd_create(clockid, flags);
}

def timerfd_settime_call(
    fd: i32, flags: i32, new_value: &itimerspec, old_value: &mut itimerspec
) -> i32 {
    return timerfd_settime(fd, flags, new_value, old_value);
}

def timerfd_gettime_call(fd: i32, curr_value: &mut itimerspec) -> i32 {
    return timerfd_gettime(fd, curr_value);
}
