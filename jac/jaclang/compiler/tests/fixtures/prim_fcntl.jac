"""Bundled native `fcntl` cross-backend equivalence fixture.

The SAME `import fcntl` binds CPython's `fcntl` on the sv (Python) backend
and the bundled `na_stdlib/fcntl.jac` on the na (native LLVM) backend. Pipe
fds: `os.pipe()` on sv, libc `pipe(2)` on na. Pins the F_GETFL/F_SETFL
O_NONBLOCK round trip (toggle on, read back, restore, read back), the
per-OS constant values (sv reads O_NONBLOCK from `os`, na from the `fcntl`
floor -- same value on the host), an EBADF raise as raised/did-not-raise
(the error TYPE diverges: OSError vs ValueError), and an
`ioctl(TIOCGWINSZ)` probe on stdin fd 0 that degrades to zeros when fd 0
is not a terminal (CI), so the key set never drifts. A pty slave (always a
terminal) then pins CPython's `ioctl` buffer contract: the answer is fresh
`bytes` of `len(arg)` and the caller's `arg` is never written, a request
that writes past a short `arg` raises (SystemError on sv, RuntimeError on
na: raised/did-not-raise only), an `arg` over 1024 bytes raises
`ValueError`, and a 1024-byte `arg` is accepted. ES/JS opts out
(POSIX-only).
"""

import os;
import fcntl;
import from termios { TIOCGWINSZ }
import from c {
    def pipe(fds: bytes) -> i32;  def close(fd: i32) -> i32;  def openpty(
        am: bytes, asl: bytes, name: int, t: int, w: int
    ) -> i32;
}


def _pipe_na -> tuple[(int, int)] {
    fds: bytes = b"\x00" * 8;
    pipe(fds);
    r: int = int.from_bytes(fds[0:4], "little");
    w: int = int.from_bytes(fds[4:8], "little");
    return (r, w);
}


"""A pty pair from libc openpty(3); NULL name/termios/winsize out-params."""
def _pty_pair_na -> tuple[(int, int)] {
    am: bytes = b"\x00" * 4;
    asl: bytes = b"\x00" * 4;
    openpty(am, asl, 0, 0, 0);
    m: int = int.from_bytes(am[0:4], "little");
    s: int = int.from_bytes(asl[0:4], "little");
    return (m, s);
}


"""2 when `ioctl(fd, TIOCGWINSZ, arg)` raises ValueError, 1 for another
exception, 0 when it answers."""
def _ioctl_kind_py(fd: int, arg: bytes) -> int {
    try {
        fcntl.ioctl(fd, TIOCGWINSZ, arg);
    } except ValueError {
        return 2;
    } except Exception {
        return 1;
    }
    return 0;
}


"""2 when `ioctl(fd, TIOCGWINSZ, arg)` raises ValueError, 1 for another
exception, 0 when it answers."""
def _ioctl_kind_na(fd: int, arg: bytes) -> int {
    try {
        fcntl.ioctl(fd, TIOCGWINSZ, arg);
    } except ValueError {
        return 2;
    } except Exception {
        return 1;
    }
    return 0;
}


def fcntl_py -> dict[any, any] {
    d: dict[any, any] = {};
    (rfd, wfd) = os.pipe();
    flags0 = fcntl.fcntl(rfd, fcntl.F_GETFL);
    nb_on = flags0 | os.O_NONBLOCK;
    fcntl.fcntl(rfd, fcntl.F_SETFL, nb_on);
    flags1 = fcntl.fcntl(rfd, fcntl.F_GETFL);

    fcntl.fcntl(rfd, fcntl.F_SETFL, flags0);
    flags2 = fcntl.fcntl(rfd, fcntl.F_GETFL);
    d["nb_toggled"] = 1 if (flags1 & os.O_NONBLOCK) != 0 else 0;
    d["restored"] = 1 if flags2 == flags0 else 0;
    raised = 0;
    try {
        fcntl.fcntl(9999, fcntl.F_GETFL);
    } except Exception {
        raised = 1;
    }
    d["ebadf_raised"] = raised;
    d["c_f_getfl"] = fcntl.F_GETFL;
    d["c_f_setfl"] = fcntl.F_SETFL;
    d["c_o_nonblock"] = os.O_NONBLOCK;

    ws_ok = 0;
    ws_rows = 0;
    ws_cols = 0;
    ws_bytes = 0;
    try {
        buf = b"\x00" * 8;
        buf = fcntl.ioctl(0, TIOCGWINSZ, buf);
        ws_ok = 1;
        ws_bytes = len(buf);
        ws_rows = int.from_bytes(buf[0:2], "little");
        ws_cols = int.from_bytes(buf[2:4], "little");
    } except Exception {
        ws_rows = 0;
    }
    d["ws_ok"] = ws_ok;
    d["ws_rows"] = ws_rows;
    d["ws_cols"] = ws_cols;
    d["ws_bytes"] = ws_bytes;
    (m, s) = os.openpty();
    arg: bytes = b"\x01" * 8;
    got: bytes = fcntl.ioctl(s, TIOCGWINSZ, arg);
    d["ioctl_len"] = len(got);
    d["ioctl_arg_untouched"] = 1 if arg == b"\x01" * 8 else 0;
    d["ioctl_winsize_zero"] = 1 if got == b"\x00" * 8 else 0;
    d["ioctl_short_kind"] = 1 if _ioctl_kind_py(s, b"\x00") != 0 else 0;
    d["ioctl_too_long_kind"] = _ioctl_kind_py(s, b"\x00" * 1025);
    big: bytes = fcntl.ioctl(s, TIOCGWINSZ, b"\x07" * 1024);
    d["ioctl_max_len"] = len(big);
    d["ioctl_max_tail"] = big[1023];
    os.close(s);
    os.close(m);
    os.close(rfd);
    os.close(wfd);
    return d;
}


def fcntl_cl -> dict[any, any] {
    return {};
}


def fcntl_na -> dict[str, any] {
    d: dict[str, any] = {};
    (rfd, wfd) = _pipe_na();
    flags0: int = fcntl.fcntl(rfd, fcntl.F_GETFL);
    nb_on: int = flags0 | os.O_NONBLOCK;
    fcntl.fcntl(rfd, fcntl.F_SETFL, nb_on);
    flags1: int = fcntl.fcntl(rfd, fcntl.F_GETFL);

    fcntl.fcntl(rfd, fcntl.F_SETFL, flags0);
    flags2: int = fcntl.fcntl(rfd, fcntl.F_GETFL);
    d["nb_toggled"] = 1 if (flags1 & os.O_NONBLOCK) != 0 else 0;
    d["restored"] = 1 if flags2 == flags0 else 0;
    raised: int = 0;
    try {
        fcntl.fcntl(9999, fcntl.F_GETFL);
    } except Exception {
        raised = 1;
    }
    d["ebadf_raised"] = raised;
    d["c_f_getfl"] = fcntl.F_GETFL;
    d["c_f_setfl"] = fcntl.F_SETFL;
    d["c_o_nonblock"] = fcntl.O_NONBLOCK;

    ws_ok: int = 0;
    ws_rows: int = 0;
    ws_cols: int = 0;
    ws_bytes: int = 0;
    try {
        buf: bytes = b"\x00" * 8;
        buf = fcntl.ioctl(0, TIOCGWINSZ, buf);
        ws_ok = 1;
        ws_bytes = len(buf);
        ws_rows = int.from_bytes(buf[0:2], "little");
        ws_cols = int.from_bytes(buf[2:4], "little");
    } except Exception {
        ws_rows = 0;
    }
    d["ws_ok"] = ws_ok;
    d["ws_rows"] = ws_rows;
    d["ws_cols"] = ws_cols;
    d["ws_bytes"] = ws_bytes;
    (m, s) = _pty_pair_na();
    arg: bytes = b"\x01" * 8;
    got: bytes = fcntl.ioctl(s, TIOCGWINSZ, arg);
    d["ioctl_len"] = len(got);
    d["ioctl_arg_untouched"] = 1 if arg == b"\x01" * 8 else 0;
    d["ioctl_winsize_zero"] = 1 if got == b"\x00" * 8 else 0;
    d["ioctl_short_kind"] = 1 if _ioctl_kind_na(s, b"\x00") != 0 else 0;
    d["ioctl_too_long_kind"] = _ioctl_kind_na(s, b"\x00" * 1025);
    big: bytes = fcntl.ioctl(s, TIOCGWINSZ, b"\x07" * 1024);
    d["ioctl_max_len"] = len(big);
    d["ioctl_max_tail"] = big[1023];
    close(i32(s));
    close(i32(m));
    close(i32(rfd));
    close(i32(wfd));
    return d;
}
