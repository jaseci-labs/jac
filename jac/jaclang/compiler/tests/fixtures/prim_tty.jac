"""Bundled native `tty` cross-backend equivalence fixture.

`import from tty { setcbreak, setraw }` binds CPython's `tty` on sv and the
bundled `na_stdlib/tty.jac` on na. Uses a pty slave fd (pipes are ENOTTY
for termios): `os.openpty()` on sv, libc `openpty(3)` on na, master kept
open until the end. The pty is first seeded with VMIN=7/VTIME=3 and with
NOFLSH|TOSTOP set in lflag, so every write the modes make is observable.
`setcbreak` must clear ICANON and ECHO in `mode[3]` (lflag) and set cc
VMIN=1/VTIME=0 on its OWN copy of the cc list, so the returned
original-mode list still reports the seeded VMIN=7/VTIME=3 -- CPython
3.12+'s behavior, pinned here. `setraw` must mask each flag word exactly
by CPython's formula (clearing the seeded NOFLSH/TOSTOP), computed from
each lane's own saved attrs. Original attrs are restored and the restore
is verified. ES/JS opts out (POSIX-only).
"""

import os;
import termios;
import from termios {
    TCSADRAIN,
    ICANON,
    ECHO,
    BRKINT,
    ICRNL,
    INPCK,
    ISTRIP,
    IXON,
    OPOST,
    CSIZE,
    PARENB,
    CS8,
    IEXTEN,
    ISIG,
    VMIN,
    VTIME,
    IGNBRK,
    IGNPAR,
    PARMRK,
    INLCR,
    IGNCR,
    IXANY,
    IXOFF,
    ECHOE,
    ECHOK,
    ECHONL,
    NOFLSH,
    TOSTOP
}
import from tty { setcbreak, setraw }
import from c {
    def openpty(am: bytes, asl: bytes, name: int, t: int, w: int) -> i32;  def close(
        fd: i32
    ) -> i32;
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


def tty_py -> dict[any, any] {
    d: dict[any, any] = {};
    (m, s) = os.openpty();
    seed = termios.tcgetattr(s);
    seed[6][VMIN] = 7;
    seed[6][VTIME] = 3;
    seed[3] = seed[3] | NOFLSH | TOSTOP;
    termios.tcsetattr(s, TCSADRAIN, seed);
    orig = termios.tcgetattr(s);
    d["seed_noflsh_tostop"] = 1
        if (orig[3] & (NOFLSH | TOSTOP)) == (NOFLSH | TOSTOP)
        else 0;
    got = setcbreak(s);
    after = termios.tcgetattr(s);
    lflag = after[3];
    d["cbreak_icanon_off"] = 1 if (lflag & ICANON) == 0 else 0;
    d["cbreak_echo_off"] = 1 if (lflag & ECHO) == 0 else 0;
    cc = after[6];
    d["cbreak_vmin"] = _cc_int(cc[VMIN]);
    d["cbreak_vtime"] = _cc_int(cc[VTIME]);
    got_cc = got[6];
    d["cbreak_orig_cc_vmin"] = _cc_int(got_cc[VMIN]);
    d["cbreak_orig_cc_vtime"] = _cc_int(got_cc[VTIME]);
    termios.tcsetattr(s, TCSADRAIN, orig);
    restored = termios.tcgetattr(s);
    d["cbreak_restored"] = 1 if restored[3] == orig[3] else 0;

    orig2 = termios.tcgetattr(s);
    got2 = setraw(s);
    raw = termios.tcgetattr(s);
    exp_iflag = orig2[0]
        & ~(
            IGNBRK
            | BRKINT
            | IGNPAR
            | PARMRK
            | INPCK
            | ISTRIP
            | INLCR
            | IGNCR
            | ICRNL
            | IXON
            | IXANY
            | IXOFF
        );
    exp_oflag = orig2[1] & ~OPOST;
    exp_cflag = (orig2[2] & ~(PARENB | CSIZE)) | CS8;
    exp_lflag = orig2[3]
        & ~(ECHO | ECHOE | ECHOK | ECHONL | ICANON | IEXTEN | ISIG | NOFLSH | TOSTOP);

    d["raw_iflag_ok"] = 1 if raw[0] == exp_iflag else 0;
    d["raw_oflag_ok"] = 1 if raw[1] == exp_oflag else 0;
    d["raw_cflag_ok"] = 1 if raw[2] == exp_cflag else 0;
    d["raw_lflag_ok"] = 1 if raw[3] == exp_lflag else 0;
    raw_cc = raw[6];
    d["raw_vmin"] = _cc_int(raw_cc[VMIN]);
    d["raw_vtime"] = _cc_int(raw_cc[VTIME]);
    got2_cc = got2[6];
    d["raw_orig_cc_vmin"] = _cc_int(got2_cc[VMIN]);
    d["raw_len"] = len(got2);
    termios.tcsetattr(s, TCSADRAIN, orig2);
    restored2 = termios.tcgetattr(s);
    d["raw_restored"] = 1 if restored2[3] == orig2[3] else 0;
    os.close(s);
    os.close(m);
    return d;
}


def tty_cl -> dict[any, any] {
    return {};
}


def tty_na -> dict[str, any] {
    d: dict[str, any] = {};
    (m, s) = _pty_pair_na();
    seed = termios.tcgetattr(s);
    seed_cc = seed[6];
    if isinstance(seed_cc, list) {
        seed_cc[VMIN] = 7;
        seed_cc[VTIME] = 3;
    }
    seed_lflag: int = seed[3];
    seed[3] = seed_lflag | NOFLSH | TOSTOP;
    termios.tcsetattr(s, TCSADRAIN, seed);
    orig = termios.tcgetattr(s);
    orig_lflag: int = orig[3];
    d["seed_noflsh_tostop"] = 1
        if (orig_lflag & (NOFLSH | TOSTOP)) == (NOFLSH | TOSTOP)
        else 0;
    got = setcbreak(s);
    after = termios.tcgetattr(s);
    lflag: int = after[3];
    d["cbreak_icanon_off"] = 1 if (lflag & ICANON) == 0 else 0;
    d["cbreak_echo_off"] = 1 if (lflag & ECHO) == 0 else 0;
    cc = after[6];
    cbreak_vmin: int = 0;
    cbreak_vtime: int = 0;
    if isinstance(cc, list) {
        v1 = cc[VMIN];
        cbreak_vmin = v1;
        v2 = cc[VTIME];
        cbreak_vtime = v2;
    }
    d["cbreak_vmin"] = cbreak_vmin;
    d["cbreak_vtime"] = cbreak_vtime;
    got_cc = got[6];
    orig_vmin: int = 0;
    orig_vtime: int = 0;
    if isinstance(got_cc, list) {
        v3 = got_cc[VMIN];
        orig_vmin = v3;
        v3t = got_cc[VTIME];
        orig_vtime = v3t;
    }
    d["cbreak_orig_cc_vmin"] = orig_vmin;
    d["cbreak_orig_cc_vtime"] = orig_vtime;
    termios.tcsetattr(s, TCSADRAIN, orig);
    restored = termios.tcgetattr(s);
    rlflag: int = restored[3];
    olflag: int = orig[3];
    d["cbreak_restored"] = 1 if rlflag == olflag else 0;

    orig2 = termios.tcgetattr(s);
    got2 = setraw(s);
    raw = termios.tcgetattr(s);
    oiflag: int = orig2[0];
    ooflag: int = orig2[1];
    ocflag: int = orig2[2];
    olflag2: int = orig2[3];
    exp_iflag: int = oiflag
        & ~(
            IGNBRK
            | BRKINT
            | IGNPAR
            | PARMRK
            | INPCK
            | ISTRIP
            | INLCR
            | IGNCR
            | ICRNL
            | IXON
            | IXANY
            | IXOFF
        );
    exp_oflag: int = ooflag & ~OPOST;
    exp_cflag: int = (ocflag & ~(PARENB | CSIZE)) | CS8;
    exp_lflag: int = olflag2
        & ~(ECHO | ECHOE | ECHOK | ECHONL | ICANON | IEXTEN | ISIG | NOFLSH | TOSTOP);
    riflag: int = raw[0];
    roflag: int = raw[1];
    rcflag: int = raw[2];
    rlflag2: int = raw[3];

    d["raw_iflag_ok"] = 1 if riflag == exp_iflag else 0;
    d["raw_oflag_ok"] = 1 if roflag == exp_oflag else 0;
    d["raw_cflag_ok"] = 1 if rcflag == exp_cflag else 0;
    d["raw_lflag_ok"] = 1 if rlflag2 == exp_lflag else 0;
    raw_cc = raw[6];
    raw_vmin: int = 0;
    raw_vtime: int = 0;
    if isinstance(raw_cc, list) {
        v4 = raw_cc[VMIN];
        raw_vmin = v4;
        v5 = raw_cc[VTIME];
        raw_vtime = v5;
    }
    d["raw_vmin"] = raw_vmin;
    d["raw_vtime"] = raw_vtime;
    got2_cc = got2[6];
    raw_orig_vmin: int = 0;
    if isinstance(got2_cc, list) {
        v6 = got2_cc[VMIN];
        raw_orig_vmin = v6;
    }
    d["raw_orig_cc_vmin"] = raw_orig_vmin;
    d["raw_len"] = len(got2);
    termios.tcsetattr(s, TCSADRAIN, orig2);
    restored2 = termios.tcgetattr(s);
    rlflag3: int = restored2[3];
    d["raw_restored"] = 1 if rlflag3 == olflag2 else 0;
    close(i32(s));
    close(i32(m));
    return d;
}

def _cc_int(value: any) -> int {
    if isinstance(value, int) {
        return value;
    }
    if isinstance(value, bytes) {
        return int.from_bytes(value, "little");
    }
    return 0;
}
