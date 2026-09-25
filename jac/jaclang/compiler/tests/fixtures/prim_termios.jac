"""Bundled native `termios` cross-backend equivalence fixture (Mechanism F).

`import from termios { ... }` binds CPython's `termios` on sv and
`na_stdlib/termios.jac` on na. A pseudo-terminal pair is used because
`tcgetattr` requires a tty (pipes return ENOTTY): `os.openpty()` on sv, libc
`openpty(3)` on na; the master stays open until the end (closing it early makes
slave termios calls fail with EIO). ES/JS opts out (POSIX-only). Buffers libc
writes into are `b"\x00" * n` heap allocations -- a bytes literal lives in
.rodata and cannot be written; the name/termp/winp out/in params are sized to
what `openpty` touches.
"""

import os;
import termios;
import from termios { tcgetattr, tcsetattr, TCSADRAIN, ECHO, ICANON, VMIN }
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


def termios_py -> dict[str, any] {
    (mfd, sfd) = os.openpty();
    attrs = tcgetattr(sfd);
    alen: int = len(attrs);
    cclen: int = len(attrs[6]);
    cc_is_bytes: int = 1 if isinstance(attrs[6][0], bytes) else 0;
    saved_iflag: int = attrs[0];
    tcsetattr(sfd, TCSADRAIN, attrs);
    attrs2 = tcgetattr(sfd);
    iflag_match: int = 1 if attrs2[0] == saved_iflag else 0;
    os.close(sfd);
    os.close(mfd);
    return {
        "attrs_len": alen,
        "cc_len": cclen,
        "cc_bytes": cc_is_bytes,
        "iflag_roundtrip": iflag_match,
        "TCSADRAIN": TCSADRAIN,
        "ECHO": ECHO,
        "ICANON": ICANON,
        "VMIN": VMIN
    };
}


def termios_cl -> dict[str, any] {
    return {};
}


def _aint(v: any) -> int {
    if isinstance(v, int) {
        r: int = v;
        return r;
    }
    return -1;
}


def termios_na -> dict[str, any] {
    (mfd, sfd) = _pty_pair_na();
    attrs = tcgetattr(sfd);
    alen: int = len(attrs);
    cca = attrs[6];
    cclen: int = len(cca) if isinstance(cca, list) else 0;
    cc_is_bytes: int = 1 if isinstance(cca[0], bytes) else 0;
    saved_iflag: int = _aint(attrs[0]);
    tcsetattr(sfd, TCSADRAIN, attrs);
    attrs2 = tcgetattr(sfd);
    iflag_match: int = 1 if _aint(attrs2[0]) == saved_iflag else 0;
    close(i32(sfd));
    close(i32(mfd));
    return {
        "attrs_len": alen,
        "cc_len": cclen,
        "cc_bytes": cc_is_bytes,
        "iflag_roundtrip": iflag_match,
        "TCSADRAIN": TCSADRAIN,
        "ECHO": ECHO,
        "ICANON": ICANON,
        "VMIN": VMIN
    };
}
