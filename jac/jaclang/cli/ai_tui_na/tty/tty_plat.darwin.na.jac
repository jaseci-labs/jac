"""Darwin libc bindings and termios/ioctl constants for the raw-tty layer.

Staged as tty_plat.na.jac by build_embed.sh / _golden_run.sh and imported
wholesale by libc_tty_base, so this file and tty_plat.linux.na.jac must stay
field-for-field parallel: same names, same declaration order, values swapped
for the OS. Every constant value is OS ABI surface — frozen, never edit.
"""

# --- libc bindings (C ABI via the platform libc) ---
import from "/usr/lib/libSystem.B.dylib" {
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

# TERMIOS_SZ / VMIN_OFF / VTIME_OFF encode the termios snapshot layout that
# libc_tty_base byte-pokes: four 4-byte flag words (c_iflag..c_lflag) = 16
# bytes, then c_cc[20], then two 4-byte speeds -> 44 bytes total; darwin has
# VMIN = c_cc[16] (offset 32) and VTIME = c_cc[17] (offset 33). The poked
# pair VMIN=1 / VTIME=0 means "block until one byte, no inter-byte timer".
glob O_NONBLOCK: int = 4,
     TIOCGWINSZ: int = 0x40087468,
     # c_iflag bit
     IXON: int = 0x00000200,
     # c_lflag bits
     ECHONL: int = 0x00000010,
     ICANON: int = 0x00000100,
     ISIG: int = 0x00000080,
     IEXTEN: int = 0x00000400,
     # c_cflag bits
     CSIZE: int = 0x00000300,
     PARENB: int = 0x00001000,
     CS8: int = 0x00000300,
     # termios snapshot layout (see block comment above)
     TERMIOS_SZ: int = 44,
     VMIN_OFF: int = 32,
     VMIN_VAL: int = 1,
     VTIME_OFF: int = 33,
     VTIME_VAL: int = 0;
