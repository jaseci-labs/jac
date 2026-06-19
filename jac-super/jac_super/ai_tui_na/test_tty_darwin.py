#!/usr/bin/env python3
# ruff: noqa: T201, SIM105
"""Phase 4 PTY termios harness — validates the Darwin raw-mode flag table.

Two checks, both macOS-only (exits 0 immediately on Linux):

1. Constant probe: Python's termios module reports the same numeric values that
   are baked into tty/libc_tty.darwin.na.jac. Any mismatch means a wrong baked
   constant that would silently break raw mode (e.g. echo left on, ICANON not
   cleared). Also verifies VMIN/VTIME c_cc indices match xnu's layout.

2. PTY raw-mode gate: allocate a PTY, apply raw mode using Python's own
   tcsetattr (which uses the real system constants, never our baked ones), read
   the termios back with tcgetattr, and assert every mask the Darwin module
   applies. Proves the flag combination is coherent on the live xnu kernel.

Run by build.sh; exits non-zero on any failure.
"""

import os
import sys
import termios

# ── Darwin constants baked in tty/libc_tty.darwin.na.jac ─────────────────────
# Every ✗ row from the glibc-vs-xnu table in PLAN-tui-macos.md, plus the ✓
# rows that are worth sanity-checking (same on both platforms). The probe
# compares these against the live Python termios attributes on the runner.
_BAKED: dict = {
    # name         baked value    termios attr     notes
    "ECHO": (0x00000008, "ECHO"),
    "ECHONL": (0x00000010, "ECHONL"),  # ✗ linux=0x40
    "ICANON": (0x00000100, "ICANON"),  # ✗ linux=0x02
    "ISIG": (0x00000080, "ISIG"),  # ✗ linux=0x01
    "IEXTEN": (0x00000400, "IEXTEN"),  # ✗ linux=0x8000
    "CSIZE": (0x00003000, "CSIZE"),  # ✗ linux=0x30
    "CS8": (0x00003000, "CS8"),  # ✗ linux=0x30
    "PARENB": (0x00000100, "PARENB"),
    "ICRNL": (0x00000100, "ICRNL"),
    "IXON": (0x00000400, "IXON"),
    "OPOST": (0x00000001, "OPOST"),
    "IGNBRK": (0x00000001, "IGNBRK"),
    "BRKINT": (0x00000002, "BRKINT"),
    "PARMRK": (0x00000008, "PARMRK"),
    "ISTRIP": (0x00000020, "ISTRIP"),
    "INLCR": (0x00000040, "INLCR"),
    "IGNCR": (0x00000080, "IGNCR"),
}

# xnu c_cc indices for VMIN and VTIME (baked in build_raw_termios as offsets
# 32 and 33 — c_cc base = 16, VMIN=cc[16], VTIME=cc[17]).
_BAKED_VMIN_IDX = 16  # c_cc[16] → byte offset 32 in the 44-byte xnu struct
_BAKED_VTIME_IDX = 17  # c_cc[17] → byte offset 33


def _cc_val(cc_list: list, idx: int) -> int:
    """Extract a c_cc element as int; handles both bytes and int Python returns."""
    v = cc_list[idx]
    return ord(v) if isinstance(v, (bytes, bytearray)) else int(v)


def check_constant_probe() -> list:
    """Compare baked constants against the live Python termios attributes."""
    errors = []
    for name, (our_val, attr) in _BAKED.items():
        sys_val = getattr(termios, attr, None)
        if sys_val is None:
            errors.append(f"  {name}: missing from Python termios (unexpected)")
            continue
        if sys_val != our_val:
            errors.append(
                f"  {name}: baked=0x{our_val:08x}  sys=0x{sys_val:08x}  TABLE WRONG"
            )
        else:
            print(f"  ok {name} = 0x{our_val:08x}")

    # Verify VMIN/VTIME c_cc indices match xnu layout
    for attr, baked_idx in (("VMIN", _BAKED_VMIN_IDX), ("VTIME", _BAKED_VTIME_IDX)):
        sys_idx = getattr(termios, attr, None)
        if sys_idx is None:
            errors.append(f"  {attr}: missing from Python termios")
            continue
        if sys_idx != baked_idx:
            errors.append(
                f"  {attr} index: baked={baked_idx}  sys={sys_idx}  VMIN/VTIME OFFSETS WRONG"
            )
        else:
            print(f"  ok {attr} index = {baked_idx}")

    # Verify O_NONBLOCK (from os module, not termios)
    sys_onb = getattr(os, "O_NONBLOCK", None)
    if sys_onb is None:
        errors.append("  O_NONBLOCK: missing from os module (unexpected)")
    elif sys_onb != 0x4:
        errors.append(f"  O_NONBLOCK: baked=0x4  sys=0x{sys_onb:x}  TABLE WRONG")
    else:
        print("  ok O_NONBLOCK = 0x4")

    # Verify TIOCGWINSZ
    sys_tig = getattr(termios, "TIOCGWINSZ", None)
    if sys_tig is None:
        print("  skip TIOCGWINSZ (not in Python termios on this build)")
    elif sys_tig != 0x40087468:
        errors.append(f"  TIOCGWINSZ: baked=0x40087468  sys=0x{sys_tig:x}  TABLE WRONG")
    else:
        print("  ok TIOCGWINSZ = 0x40087468")

    return errors


def check_pty_raw_mode() -> list:
    """Allocate a PTY, apply raw mode, read back termios, assert all raw masks."""
    errors = []
    master_fd, slave_fd = os.openpty()
    try:
        # Read original termios before applying raw mode
        orig = termios.tcgetattr(slave_fd)

        # Build raw termios using the *system* constants (termios.*), not our
        # baked values — this verifies the masks are semantically correct on xnu.
        raw = list(orig)
        cc = list(raw[6])

        # iflag: clear IGNBRK|BRKINT|PARMRK|ISTRIP|INLCR|IGNCR|ICRNL|IXON
        raw[0] &= ~(
            termios.IGNBRK
            | termios.BRKINT
            | termios.PARMRK
            | termios.ISTRIP
            | termios.INLCR
            | termios.IGNCR
            | termios.ICRNL
            | termios.IXON
        )
        # oflag: clear OPOST
        raw[1] &= ~termios.OPOST
        # cflag: CS8 set, PARENB clear
        raw[2] = (raw[2] & ~termios.CSIZE) | termios.CS8
        raw[2] &= ~termios.PARENB
        # lflag: clear ECHO|ECHONL|ICANON|ISIG|IEXTEN
        raw[3] &= ~(
            termios.ECHO
            | termios.ECHONL
            | termios.ICANON
            | termios.ISIG
            | termios.IEXTEN
        )
        # cc: VMIN=1, VTIME=0 at xnu indices
        cc[termios.VMIN] = bytes([1])
        cc[termios.VTIME] = bytes([0])
        raw[6] = cc

        termios.tcsetattr(slave_fd, termios.TCSANOW, raw)

        # Read back and assert
        got = termios.tcgetattr(slave_fd)
        iflag, oflag, cflag, lflag = got[0], got[1], got[2], got[3]
        cc_got = got[6]

        # c_lflag: ECHO, ECHONL, ICANON, ISIG, IEXTEN must be cleared
        for name in ("ECHO", "ECHONL", "ICANON", "ISIG", "IEXTEN"):
            bit = getattr(termios, name)
            if lflag & bit:
                errors.append(
                    f"  c_lflag {name} (0x{bit:x}) NOT cleared; lflag=0x{lflag:x}"
                )
            else:
                print(f"  ok c_lflag {name} cleared")

        # c_iflag: ICRNL, IXON must be cleared
        for name in ("ICRNL", "IXON"):
            bit = getattr(termios, name)
            if iflag & bit:
                errors.append(
                    f"  c_iflag {name} (0x{bit:x}) NOT cleared; iflag=0x{iflag:x}"
                )
            else:
                print(f"  ok c_iflag {name} cleared")

        # c_oflag: OPOST must be cleared
        if oflag & termios.OPOST:
            errors.append(f"  c_oflag OPOST NOT cleared; oflag=0x{oflag:x}")
        else:
            print("  ok c_oflag OPOST cleared")

        # c_cflag: CS8 set, PARENB clear
        if (cflag & termios.CSIZE) != termios.CS8:
            errors.append(
                f"  c_cflag CS8 NOT set; cflag=0x{cflag:x} (CSIZE bits=0x{cflag & termios.CSIZE:x})"
            )
        else:
            print("  ok c_cflag CS8 set")

        if cflag & termios.PARENB:
            errors.append(f"  c_cflag PARENB NOT cleared; cflag=0x{cflag:x}")
        else:
            print("  ok c_cflag PARENB cleared")

        # c_cc: VMIN=1 at xnu index 16, VTIME=0 at xnu index 17
        vmin_val = _cc_val(cc_got, termios.VMIN)
        vtime_val = _cc_val(cc_got, termios.VTIME)

        if vmin_val != 1:
            errors.append(f"  c_cc[VMIN={termios.VMIN}] expected 1, got {vmin_val}")
        else:
            print(f"  ok c_cc[VMIN={termios.VMIN}] == 1")

        if vtime_val != 0:
            errors.append(f"  c_cc[VTIME={termios.VTIME}] expected 0, got {vtime_val}")
        else:
            print(f"  ok c_cc[VTIME={termios.VTIME}] == 0")

    finally:
        for fd in (slave_fd, master_fd):
            try:
                os.close(fd)
            except OSError:
                pass

    return errors


def main() -> int:
    if sys.platform != "darwin":
        print(f"SKIP: test_tty_darwin.py is macOS-only (platform={sys.platform!r})")
        return 0

    all_errors: list = []

    print("\n── constant probe (baked values vs live Python termios / os) ──")
    all_errors.extend(check_constant_probe())

    print("\n── PTY raw-mode gate (tcsetattr + tcgetattr on slave) ──")
    all_errors.extend(check_pty_raw_mode())

    if all_errors:
        print("\nFAIL:", file=sys.stderr)
        for e in all_errors:
            print(e, file=sys.stderr)
        return 1

    print("\n==> test_tty_darwin passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
