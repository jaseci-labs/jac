"""Bundled native `tty` cross-backend equivalence fixture (Mechanism F).

`import from tty { setcbreak }` / `import from termios { ... }` bind CPython on
sv and bundled na_stdlib on na. Uses a pty pair (`os.openpty()` on sv, libc
`openpty(3)` on na; master held open until the end) since pipes are ENOTTY
for termios. `setcbreak` must clear ICANON and ECHO in `mode[3]`
(lflag), then original attrs are restored. ES/JS opts out (POSIX-only).
Buffers libc writes into are `b"\x00" * n` heap allocations -- a bytes
literal lives in .rodata and cannot be written.
"""

import os;
import termios;
import tty;
import from termios { tcgetattr, tcsetattr, TCSADRAIN, ICANON, ECHO }
import from tty { setcbreak }
import from c {
    def openpty(am: bytes, asl: bytes, name: bytes, t: bytes, w: bytes) -> i32;  def close(
        fd: i32
    ) -> i32;
}


def _pty_pair_na -> tuple[(int, int)] {
    am: bytes = b"\x00" * 4;
    asl: bytes = b"\x00" * 4;
    openpty(am, asl, b"\x00" * 64, b"\x00" * 60, b"\x00" * 8);
    return (int.from_bytes(am, "little"), int.from_bytes(asl, "little"));
}


def tty_py -> dict[str, any] {
    (mfd, sfd) = os.openpty();
    orig = tcgetattr(sfd);
    setcbreak(sfd);
    after = tcgetattr(sfd);
    lflag: int = after[3];
    icanon_off: int = 1 if (lflag & ICANON) == 0 else 0;
    echo_off: int = 1 if (lflag & ECHO) == 0 else 0;
    tcsetattr(sfd, TCSADRAIN, orig);
    os.close(sfd);
    os.close(mfd);
    return {"icanon_off": icanon_off, "echo_off": echo_off};
}


def tty_cl -> dict[str, any] {
    return {};
}


def _aint(v: any) -> int {
    if isinstance(v, int) {
        r: int = v;
        return r;
    }
    return -1;
}


def tty_na -> dict[str, any] {
    (mfd, sfd) = _pty_pair_na();
    orig = tcgetattr(sfd);
    setcbreak(sfd);
    after = tcgetattr(sfd);
    lflag: int = _aint(after[3]);
    icanon_off: int = 1 if (lflag & ICANON) == 0 else 0;
    echo_off: int = 1 if (lflag & ECHO) == 0 else 0;
    tcsetattr(sfd, TCSADRAIN, orig);
    close(i32(sfd));
    close(i32(mfd));
    return {"icanon_off": icanon_off, "echo_off": echo_off};
}
