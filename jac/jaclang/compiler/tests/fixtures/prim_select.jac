"""Bundled native `select` cross-backend equivalence fixture (Mechanism F).

`import select` binds CPython's `select` on sv and `na_stdlib/select.jac` on na.
Pipe fds: `os.pipe()` on sv, libc `pipe(2)` on na. ES/JS opts out (POSIX-only).
Buffers libc writes into are `b"\x00" * n` heap allocations -- a bytes
literal lives in .rodata and cannot be written.

DIVERGENCE: na uses `-1.0` as the block-forever sentinel (not `None`); this
fixture sticks to `timeout=0.0` probes only.
"""

import os;
import select;
import from c {
    def pipe(fds: bytes) -> i32;  def write(fd: i32, buf: bytes, n: u64) -> i64;  def close(
        fd: i32
    ) -> i32;
}


def _pipe_na -> tuple[(int, int)] {
    fds: bytes = b"\x00" * 8;
    pipe(fds);
    return (int.from_bytes(fds[0:4], "little"), int.from_bytes(fds[4:8], "little"));
}


def _w_ready(wfd: int) -> int {
    (_r, wlist, _x) = select.select([], [wfd], [], 0.0);
    return 1 if len(wlist) > 0 else 0;
}


def select_py -> dict[str, any] {
    (rfd, wfd) = os.pipe();
    os.write(wfd, b"x");
    write_ready: int = _w_ready(wfd);
    (er, ew, ex) = select.select([], [], [], 0.0);
    empty_ok: int = 1 if len(er) == 0 and len(ew) == 0 and len(ex) == 0 else 0;
    os.close(rfd);
    os.close(wfd);
    return {"write_ready": write_ready, "empty_ok": empty_ok};
}


def select_cl -> dict[str, any] {
    return {};
}


def select_na -> dict[str, any] {
    (rfd, wfd) = _pipe_na();
    write(i32(wfd), b"x", u64(1));
    write_ready: int = _w_ready(wfd);
    (er, ew, ex) = select.select([], [], [], 0.0);
    empty_ok: int = 1 if len(er) == 0 and len(ew) == 0 and len(ex) == 0 else 0;
    close(i32(rfd));
    close(i32(wfd));
    return {"write_ready": write_ready, "empty_ok": empty_ok};
}
