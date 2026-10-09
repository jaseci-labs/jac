"""Bundled native `fcntl` cross-backend equivalence fixture (Mechanism F).

`import fcntl` binds CPython's `fcntl` on sv and bundled na_stdlib on na.
Pipe fds: `os.pipe()` on sv, libc `pipe(2)` on na. `ioctl(TIOCGWINSZ)` on
stdin fd 0 is attempted; on failure `ws_ok=0` marks skip. ES/JS opts out
(POSIX-only). Buffers C writes into are `b"\\x00" * n` heap allocations --
a bytes literal lives in .rodata and cannot be written.
"""

import os;
import fcntl;
import from fcntl { ioctl }
import from termios { TIOCGWINSZ }
import from c { def pipe(fds: bytes) -> i32;  def close(fd: i32) -> i32;  }


def _pipe_na -> tuple[(int, int)] {
    fds: bytes = b"\x00" * 8;
    pipe(fds);
    return (int.from_bytes(fds[0:4], "little"), int.from_bytes(fds[4:8], "little"));
}


def _i16_le(buf: bytes, off: int) -> int {
    v: int = int.from_bytes(buf[off:off + 2], "little");
    if v >= 32768 {
        v = v - 65536;
    }
    return v;
}


def fcntl_py -> dict[str, any] {
    (rfd, wfd) = os.pipe();
    flags0: int = fcntl.fcntl(rfd, fcntl.F_GETFL);
    nb_on: int = flags0 | os.O_NONBLOCK;
    fcntl.fcntl(rfd, fcntl.F_SETFL, nb_on);
    flags1: int = fcntl.fcntl(rfd, fcntl.F_GETFL);
    fcntl.fcntl(rfd, fcntl.F_SETFL, flags0);
    flags2: int = fcntl.fcntl(rfd, fcntl.F_GETFL);
    nb_toggled: int = 1 if (flags1 & os.O_NONBLOCK) != 0 else 0;
    restored: int = 1 if flags2 == flags0 else 0;
    os.close(rfd);
    os.close(wfd);

    ws_ok: int = 0;
    ws_rows: int = 0;
    ws_cols: int = 0;
    ws_bytes: int = 0;
    try {
        buf: bytes = b"\x00" * 8;
        buf = fcntl.ioctl(0, TIOCGWINSZ, buf);
        ws_ok = 1;
        ws_bytes = len(buf);
        ws_rows = _i16_le(buf, 0);
        ws_cols = _i16_le(buf, 2);
    } except OSError {
        ws_rows = 0;
    }
    return {
        "nb_toggled": nb_toggled,
        "restored": restored,
        "ws_ok": ws_ok,
        "ws_rows": ws_rows,
        "ws_cols": ws_cols,
        "ws_bytes": ws_bytes,
        "O_NONBLOCK": os.O_NONBLOCK
    };
}


def fcntl_cl -> dict[str, any] {
    return {};
}


def fcntl_na -> dict[str, any] {
    (rfd, wfd) = _pipe_na();
    flags0: int = fcntl.fcntl(rfd, fcntl.F_GETFL);
    nb_on: int = flags0 | fcntl.O_NONBLOCK;
    fcntl.fcntl(rfd, fcntl.F_SETFL, nb_on);
    flags1: int = fcntl.fcntl(rfd, fcntl.F_GETFL);
    fcntl.fcntl(rfd, fcntl.F_SETFL, flags0);
    flags2: int = fcntl.fcntl(rfd, fcntl.F_GETFL);
    nb_toggled: int = 1 if (flags1 & fcntl.O_NONBLOCK) != 0 else 0;
    restored: int = 1 if flags2 == flags0 else 0;
    close(i32(rfd));
    close(i32(wfd));

    ws_ok: int = 0;
    ws_rows: int = 0;
    ws_cols: int = 0;
    ws_bytes: int = 0;
    try {
        buf: bytes = b"\x00" * 8;
        buf = ioctl(0, TIOCGWINSZ, buf);
        ws_ok = 1;
        ws_bytes = len(buf);
        ws_rows = _i16_le(buf, 0);
        ws_cols = _i16_le(buf, 2);
    } except ValueError {
        ws_rows = 0;
    }
    return {
        "nb_toggled": nb_toggled,
        "restored": restored,
        "ws_ok": ws_ok,
        "ws_rows": ws_rows,
        "ws_cols": ws_cols,
        "ws_bytes": ws_bytes,
        "O_NONBLOCK": fcntl.O_NONBLOCK
    };
}
