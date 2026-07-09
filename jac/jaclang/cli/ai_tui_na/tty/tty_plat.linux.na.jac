"""Linux libc bindings and termios/ioctl constants for the raw-tty layer.

Staged as tty_plat.na.jac by build_embed.sh / _golden_run.sh and imported
wholesale by libc_tty_base, so this file and tty_plat.darwin.na.jac must stay
field-for-field parallel: same names, same declaration order, values swapped
for the OS. Every constant value is OS ABI surface — frozen, never edit.
"""

# --- libc bindings (C ABI via the platform libc) ---
import from "libc.so.6" {
    # fd lifecycle + io
    def open(path: str, flags: i32, mode: i32) -> i32;
    def close(fd: i32) -> i32;
    def read(fd: i32, buf: str, count: i32) -> i32;
    def write(fd: i32, buf: str, count: i32) -> i32;
    def dup2(oldfd: i32, newfd: i32) -> i32;
    def fcntl(fd: i32, cmd: i32, arg: i32) -> i32;
    # terminal control
    def ioctl(fd: i32, request: i64, arg: str) -> i32;
    def tcgetattr(fd: i32, term: str) -> i32;
    def tcsetattr(fd: i32, opt: i32, term: str) -> i32;
    # readiness wait
    def poll(fds: str, nfds: i32, timeout: i32) -> i32;
    # raw buffers for the termios/pollfd byte surgery in libc_tty_base
    def calloc(n: int, sz: int) -> int;
    def free(p: int) -> None;
    def memset(s: int, c: i32, n: int) -> int;
    def memcpy(dst: int, src: str, n: int) -> int;
}

# TERMIOS_SZ / VMIN_OFF / VTIME_OFF encode the glibc termios layout that
# libc_tty_base byte-pokes: four 4-byte flag words = 16 bytes, c_line at 16,
# c_cc[32] from byte 17, pad, then two 4-byte speeds -> 60 bytes total.
# glibc orders VTIME = c_cc[5] (offset 22) before VMIN = c_cc[6] (offset 23),
# so the OFF/VAL names below are crossed relative to glibc's index names; the
# poked result is VMIN=1 / VTIME=0 — "block until one byte, no inter-byte
# timer", identical to darwin. Names and values are frozen ABI surface: do
# NOT "fix" by swapping.
glob O_NONBLOCK: int = 2048,
     TIOCGWINSZ: int = 0x5413,
     # c_iflag bit
     IXON: int = 0x00000400,
     # c_lflag bits
     ECHONL: int = 0x00000040,
     ICANON: int = 0x00000002,
     ISIG: int = 0x00000001,
     IEXTEN: int = 0x00008000,
     # c_cflag bits
     CSIZE: int = 0x00000030,
     PARENB: int = 0x00000100,
     CS8: int = 0x00000030,
     # termios snapshot layout (see block comment above)
     TERMIOS_SZ: int = 60,
     VMIN_OFF: int = 22,
     VMIN_VAL: int = 0,
     VTIME_OFF: int = 23,
     VTIME_VAL: int = 1;
