"""The macOS side of the posix file descriptor area.

Derived from CPython 3.14.6 Modules/posixmodule.c and
Include/internal/pycore_fileutils.h; see ../LICENSE.cpython. sendfile() takes
the BSD headers/trailers record, fcopyfile() and ctermid_r() are
Apple-only, and read() is capped at INT_MAX bytes (_PY_READ_MAX). pipe2,
dup3, splice, eventfd and timerfd are Linux-only; memfd_create,
copy_file_range, preadv2 and pwritev2 are on neither target. Their entries
here are never reached, since the binding installs only the functions the
target compiles.
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
    }  obj sf_hdtr {
        has headers: ptr[iovec] = ptr[iovec](),
            hdr_cnt: i32 = 0,
            trailers: ptr[iovec] = ptr[iovec](),
            trl_cnt: i32 = 0;
    }  def sendfile(
        fd: i32, s: i32, offset: i64, len: &mut i64, hdtr: &mut sf_hdtr, flags: i32
    ) -> i32;  def fcopyfile(from_fd: i32, to_fd: i32, state: ptr, flags: u32) -> i32;  def ctermid_r(
        buffer: ptr[u8]
    ) -> ptr[u8];
}

glob PLATFORM: str = "darwin",
     PY_READ_MAX: i64 = 2147483647;

def:priv unavailable -> i32 {
    jacpy_set_errno(ENOSYS);
    return i32(-1);
}

def ctermid_call(buffer: ptr[u8]) -> ptr[u8] {
    return ctermid_r(buffer);
}

def dup3_call(fd: i32, fd2: i32, flags: i32) -> i32 {
    return unavailable();
}

def pipe2_call(fds: &mut fd_pair, flags: i32) -> i32 {
    return unavailable();
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
    sf = sf_hdtr(headers=headers, hdr_cnt=hdr_cnt, trailers=trailers, trl_cnt=trl_cnt);
    sbytes = length;
    ret = i64(sendfile(fd, s, offset, &mut sbytes, &mut sf, flags));
    return (ret, sbytes);
}

def sendfile_linux_call(
    out_fd: i32, in_fd: i32, has_offset: bool, offset: i64, count: u64
) -> tuple[i64, i64] {
    return (i64(unavailable()), offset);
}

def fcopyfile_call(in_fd: i32, out_fd: i32, flags: i32) -> i32 {
    return fcopyfile(in_fd, out_fd, ptr(), u32.wrap(flags));
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
    return (i64(unavailable()), offset_src, offset_dst);
}

def memfd_create_call(name: ptr[u8], flags: u32) -> i32 {
    return unavailable();
}

def eventfd_call(initval: u32, flags: i32) -> i32 {
    return unavailable();
}

def eventfd_read_call(fd: i32) -> tuple[i32, u64] {
    return (unavailable(), u64(0));
}

def eventfd_write_call(fd: i32, value: u64) -> i32 {
    return unavailable();
}

def timerfd_create_call(clockid: i32, flags: i32) -> i32 {
    return unavailable();
}

def timerfd_settime_call(
    fd: i32, flags: i32, new_value: &itimerspec, old_value: &mut itimerspec
) -> i32 {
    return unavailable();
}

def timerfd_gettime_call(fd: i32, curr_value: &mut itimerspec) -> i32 {
    return unavailable();
}
