"""Phase 4 PTY termios harness — validates the Darwin raw-mode flag table.

macOS-only (exits 0 immediately on other platforms). Two checks:

1. Constant probe: compare baked values in tty/libc_tty.darwin.na.jac against
   the live Python termios attributes on the runner.

2. PTY raw-mode gate: allocate a PTY, apply raw mode via tcsetattr, read back
   with tcgetattr, and assert every mask the Darwin module applies.

Run by build.sh; exits non-zero on any failure.
"""

import os;
import sys;

def _cc_val(cc_list: list, idx: int) -> int {
    v = cc_list[idx];
    if isinstance(v, (bytes, bytearray)) {
        return ord(v);
    }
    return int(v);
}

def check_constant_probe(termios: object) -> list {
    errors: list = [];

    baked = [
        ("ECHO", 0x00000008, "ECHO"),
        ("ECHONL", 0x00000010, "ECHONL"),
        ("ICANON", 0x00000100, "ICANON"),
        ("ISIG", 0x00000080, "ISIG"),
        ("IEXTEN", 0x00000400, "IEXTEN"),
        ("CSIZE", 0x00000300, "CSIZE"),
        ("CS8", 0x00000300, "CS8"),
        ("PARENB", 0x00001000, "PARENB"),
        ("ICRNL", 0x00000100, "ICRNL"),
        ("IXON", 0x00000200, "IXON"),
        ("OPOST", 0x00000001, "OPOST"),
        ("IGNBRK", 0x00000001, "IGNBRK"),
        ("BRKINT", 0x00000002, "BRKINT"),
        ("PARMRK", 0x00000008, "PARMRK"),
        ("ISTRIP", 0x00000020, "ISTRIP"),
        ("INLCR", 0x00000040, "INLCR"),
        ("IGNCR", 0x00000080, "IGNCR"),

    ];

    for row in baked {
        name = row[0];
        our_val = row[1];
        attr = row[2];
        sys_val = getattr(termios, attr, None);
        if sys_val is None {
            errors.append(f"  {name}: missing from Python termios (unexpected)");
        } elif sys_val != our_val {
            errors.append(
                f"  {name}: baked=0x{our_val:08x}  sys=0x{sys_val:08x}  TABLE WRONG"
            );
        } else {
            sys.stdout.write(f"  ok {name} = 0x{our_val:08x}\n");
        }
    }

    baked_vmin_idx = 16;
    baked_vtime_idx = 17;
    for (attr, baked_idx) in [("VMIN", baked_vmin_idx), ("VTIME", baked_vtime_idx)] {
        sys_idx = getattr(termios, attr, None);
        if sys_idx is None {
            errors.append(f"  {attr}: missing from Python termios");
        } elif sys_idx != baked_idx {
            errors.append(
                f"  {attr} index: baked={baked_idx}  sys={sys_idx}  VMIN/VTIME OFFSETS WRONG"
            );
        } else {
            sys.stdout.write(f"  ok {attr} index = {baked_idx}\n");
        }
    }

    sys_onb = os?.O_NONBLOCK;
    if sys_onb is None {
        errors.append("  O_NONBLOCK: missing from os module (unexpected)");
    } elif sys_onb != 0x4 {
        errors.append(f"  O_NONBLOCK: baked=0x4  sys=0x{sys_onb:x}  TABLE WRONG");
    } else {
        sys.stdout.write("  ok O_NONBLOCK = 0x4\n");
    }

    sys_tig = termios?.TIOCGWINSZ;
    if sys_tig is None {
        sys.stdout.write("  skip TIOCGWINSZ (not in Python termios on this build)\n");
    } elif sys_tig != 0x40087468 {
        errors.append(
            f"  TIOCGWINSZ: baked=0x40087468  sys=0x{sys_tig:x}  TABLE WRONG"
        );
    } else {
        sys.stdout.write("  ok TIOCGWINSZ = 0x40087468\n");
    }

    return errors;
}

def check_pty_raw_mode(termios: object) -> list {
    errors: list = [];
    (master_fd, slave_fd) = os.openpty();
    try {
        orig = termios.tcgetattr(slave_fd);
        raw = list(orig);
        cc = list(raw[6]);

        raw[0] = raw[0] & ~(
            termios.IGNBRK | termios.BRKINT | termios.PARMRK | termios.ISTRIP | termios.INLCR | termios.IGNCR | termios.ICRNL | termios.IXON
        );
        raw[1] = raw[1] & ~termios.OPOST;
        raw[2] = (raw[2] & ~termios.CSIZE) | termios.CS8;
        raw[2] = raw[2] & ~termios.PARENB;
        raw[3] = raw[3] & ~(
            termios.ECHO | termios.ECHONL | termios.ICANON | termios.ISIG | termios.IEXTEN
        );
        cc[termios.VMIN] = bytes([1]);
        cc[termios.VTIME] = bytes([0]);
        raw[6] = cc;

        termios.tcsetattr(slave_fd, termios.TCSANOW, raw);
        got = termios.tcgetattr(slave_fd);
        iflag = got[0];
        oflag = got[1];
        cflag = got[2];
        lflag = got[3];
        cc_got = got[6];

        for name in ["ECHO", "ECHONL", "ICANON", "ISIG", "IEXTEN"] {
            bit = getattr(termios, name);
            if lflag & bit {
                errors.append(
                    f"  c_lflag {name} (0x{bit:x}) NOT cleared; lflag=0x{lflag:x}"
                );
            } else {
                sys.stdout.write(f"  ok c_lflag {name} cleared\n");
            }
        }

        for name in ["ICRNL", "IXON"] {
            bit = getattr(termios, name);
            if iflag & bit {
                errors.append(
                    f"  c_iflag {name} (0x{bit:x}) NOT cleared; iflag=0x{iflag:x}"
                );
            } else {
                sys.stdout.write(f"  ok c_iflag {name} cleared\n");
            }
        }

        if oflag & termios.OPOST {
            errors.append(f"  c_oflag OPOST NOT cleared; oflag=0x{oflag:x}");
        } else {
            sys.stdout.write("  ok c_oflag OPOST cleared\n");
        }

        if (cflag & termios.CSIZE) != termios.CS8 {
            errors.append(
                f"  c_cflag CS8 NOT set; cflag=0x{cflag:x} (CSIZE bits=0x{cflag & termios.CSIZE:x})"
            );
        } else {
            sys.stdout.write("  ok c_cflag CS8 set\n");
        }

        if cflag & termios.PARENB {
            errors.append(f"  c_cflag PARENB NOT cleared; cflag=0x{cflag:x}");
        } else {
            sys.stdout.write("  ok c_cflag PARENB cleared\n");
        }

        vmin_val = _cc_val(cc_got, termios.VMIN);
        vtime_val = _cc_val(cc_got, termios.VTIME);

        if vmin_val != 1 {
            errors.append(f"  c_cc[VMIN={termios.VMIN}] expected 1, got {vmin_val}");
        } else {
            sys.stdout.write(f"  ok c_cc[VMIN={termios.VMIN}] == 1\n");
        }

        if vtime_val != 0 {
            errors.append(f"  c_cc[VTIME={termios.VTIME}] expected 0, got {vtime_val}");
        } else {
            sys.stdout.write(f"  ok c_cc[VTIME={termios.VTIME}] == 0\n");
        }
    } finally {
        for fd in [slave_fd, master_fd] {
            try {
                os.close(fd);
            } except OSError { }
        }
    }

    return errors;
}

def main -> int {
    if sys.platform != "darwin" {
        sys.stdout.write(
            f"SKIP: test_tty_darwin.jac is macOS-only (platform={repr(sys.platform)})\n"
        );
        return 0;
    }

    import termios;

    all_errors: list = [];

    sys.stdout.write(
        "\n── constant probe (baked values vs live Python termios / os) ──\n"
    );
    all_errors += check_constant_probe(termios);

    sys.stdout.write("\n── PTY raw-mode gate (tcsetattr + tcgetattr on slave) ──\n");
    all_errors += check_pty_raw_mode(termios);

    if all_errors {
        sys.stderr.write("\nFAIL:\n");
        for e in all_errors {
            sys.stderr.write(e + "\n");
        }
        return 1;
    }

    sys.stdout.write("\n==> test_tty_darwin passed.\n");
    return 0;
}

with entry {
    sys.exit(main());
}
