"""An obj or str reinterpreted from an address is a view of foreign memory.

The shapes js_engine's fs builtins use with libuv: a buffer cast to str and
stored in a `uv_buf_t`-shaped obj that C reads into, and an obj cast over a
calloc'd cell to read a word back out of its str field. The memory has no
refcount header, so neither the local holding the view nor the field read
may touch one."""

import from "libc.so.6" {
    def calloc(n: int, size: int) -> int;  def memcpy(
        dst: int, src: int, n: int
    ) -> int;  def pipe(fds: int) -> i32;  def write(
        fd: i32, buf: int, n: int
    ) -> int;  def readv(fd: i32, iov: int, count: i32) -> int;  obj word_pair_t {
        has lo: int = 0,
            hi: int = 0;
    }  obj fd_pair_t {
        has rd: i32 = 0,
            wr: i32 = 0,
            pad: int = 0;
    }
}

"""Binary-compatible with struct iovec / uv_buf_t: { char* base; size_t len }."""
obj IoVec {
    has base: str = "",
        len: int = 0;
}

def raw_alloc(n: int) -> int {
    return calloc(1, n + 32) + 32;
}

def read_word(addr: int) -> int {
    tmp: int = calloc(1, 16);
    memcpy(tmp, addr, 8);
    reader: IoVec = tmp;  # jac:ignore[E1001] pointer reinterpret
    return reader.base;  # jac:ignore[E1002] pointer reinterpret
}

def read_into(fd: i32, n: int) -> int {
    buf_ptr: int = raw_alloc(n + 1);
    buf_str: str = buf_ptr;  # jac:ignore[E1001] pointer reinterpret
    vec: IoVec = IoVec(base=buf_str, len=n);
    got: int = readv(fd, vec, 1);
    if got != n {
        return 0;
    }
    return buf_ptr;
}

def copy_out(p: int) -> str {
    tmp: str = p;  # jac:ignore[E1001] pointer reinterpret
    return "" + tmp;
}

with entry {
    at: int = calloc(1, 16);
    cell: word_pair_t = at;
    cell.lo = 4096;
    print("word", read_word(at));
    fds_at: int = calloc(1, 16);
    fds: fd_pair_t = fds_at;
    if pipe(fds_at) == 0 {
        sent: str = "hello iov";
        write(fds.wr, sent, 9);
        got = read_into(fds.rd, 9);
        print("readv", got != 0, copy_out(got));
    }
}
