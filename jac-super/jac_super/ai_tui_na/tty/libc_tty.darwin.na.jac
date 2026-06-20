"""Pure-Jac terminal helpers — direct libSystem FFI, zero custom .c files.

Opens the terminal device passed as JAC_AI_TUI_TTY by the control plane
(typically /dev/ttys003), falling back to /dev/tty. Uses:
  - scalar libSystem calls (open, read, write, dup2, fcntl, poll, …)
  - calloc-backed str buffers for ioctl / tcgetattr / tcsetattr / poll

Every binary struct handed to an FFI call (termios, struct pollfd[]) MUST live in
calloc'd memory and be filled with memcpy/memset -- never built by `chr()` + `+`
concatenation. NA strings are NUL-terminated, so concatenating any chr(0) byte
silently truncates the buffer (a struct pollfd for fd 0 collapses to 0 bytes,
poll then reports POLLNVAL and no keystroke or stdin frame is ever read).

Type rule: Jac `int` for locals; `i32`/`i64` only in libSystem FFI decl slots.

xnu struct termios layout (44 bytes, NCCS=20, no c_line field):
  offset 0   c_iflag  (4 bytes)
  offset 4   c_oflag  (4 bytes)
  offset 8   c_cflag  (4 bytes)
  offset 12  c_lflag  (4 bytes)
  offset 16  c_cc[20] (20 bytes) -- VMIN=c_cc[16]@32, VTIME=c_cc[17]@33
  offset 36  c_ispeed (4 bytes)
  offset 40  c_ospeed (4 bytes)
"""

import os;

import from "/usr/lib/libSystem.B.dylib" {
    def open(path: str, flags: i32, mode: i32) -> i32;  def close(fd: i32) -> i32;  def read(
        fd: i32, buf: str, count: i32
    ) -> i32;  def write(fd: i32, buf: str, count: i32) -> i32;  def dup2(
        oldfd: i32, newfd: i32
    ) -> i32;  def fcntl(fd: i32, cmd: i32, arg: i32) -> i32;  def ioctl(
        fd: i32, request: i64, arg: str
    ) -> i32;  def tcgetattr(fd: i32, term: str) -> i32;  def tcsetattr(
        fd: i32, opt: i32, term: str
    ) -> i32;  def poll(fds: str, nfds: i32, timeout: i32) -> i32;  def calloc(
        n: int, sz: int
    ) -> int;  def free(p: int) -> None;  def memset(s: int, c: i32, n: int) -> int;  def memcpy(
        dst: int, src: str, n: int
    ) -> int;
}

# Both tcgetattr and tcsetattr take a 44-byte xnu-termios buffer via an i8*
# (a calloc'd `str`). Passing a by-value `Termios` struct through NA FFI
# mis-marshals the 44-byte aggregate and segfaults inside libSystem tcsetattr, so
# we never pass structs by value -- only pointer buffers built as fresh strings.
#
# Constants that differ from Linux/glibc are annotated with the glibc value for
# reference (see PLAN-tui-macos.md §"The real crux is the flag table").
glob O_RDWR: int = 2,
     O_NONBLOCK: int = 4,  # xnu: 0x4    (linux glibc: 0x800)
     F_GETFL: int = 3,
     F_SETFL: int = 4,
     F_DUPFD: int = 10,
     TCSANOW: int = 0,
     TIOCGWINSZ: int = 0x40087468,  # xnu _IOR('t',104,winsize) (linux: 0x5413)
     POLLIN: int = 1,
     IGNBRK: int = 0x00000001,
     BRKINT: int = 0x00000002,
     PARMRK: int = 0x00000008,
     ISTRIP: int = 0x00000020,
     INLCR: int = 0x00000040,
     IGNCR: int = 0x00000080,
     ICRNL: int = 0x00000100,
     IXON: int = 0x00000200,  # xnu: 0x200  (linux glibc: 0x400) -- 0x400 is IXOFF
     OPOST: int = 0x00000001,
     ECHO: int = 0x00000008,
     ECHONL: int = 0x00000010,  # xnu: 0x10   (linux glibc: 0x40)
     ICANON: int = 0x00000100,  # xnu: 0x100  (linux glibc: 0x02)
     ISIG: int = 0x00000080,  # xnu: 0x80   (linux glibc: 0x01)
     IEXTEN: int = 0x00000400,  # xnu: 0x400  (linux glibc: 0x8000)
     CSIZE: int = 0x00000300,  # xnu: 0x300  (linux glibc: 0x30)
     PARENB: int = 0x00001000,  # xnu: 0x1000 (linux glibc: 0x100)
     CS8: int = 0x00000300,  # xnu: 0x300  (linux glibc: 0x30)
     TERMIOS_SZ: int = 44;  # xnu: 44 bytes (linux glibc: 60)

obj TtyCtx {
    has fd: int = -1,
        saved_term: str = "",
        rows: int = 24,
        cols: int = 80,
        x_pixels: int = 0,
        y_pixels: int = 0,
        stdin_ready: int = 0,
        key_ready: int = 0,
        fd_saved: int = 0;
}

glob g_tty: TtyCtx = TtyCtx();

def read_u32(buf: str, off: int) -> int {
    b0: int = ord(buf[off]);
    b1: int = ord(buf[off + 1]);
    b2: int = ord(buf[off + 2]);
    b3: int = ord(buf[off + 3]);
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
}

def u16le(buf: str, off: int) -> int {
    lo: int = ord(buf[off]);
    hi: int = ord(buf[off + 1]);
    return lo | (hi << 8);
}

def poke_u32(p: int, off: int, val: int) {
    # Write a 32-bit little-endian word into calloc'd memory one byte at a time.
    # memset (not chr()+concat) so embedded NUL bytes survive.
    memset(p + off, val & 0xFF, 1);
    memset(p + off + 1, (val >> 8) & 0xFF, 1);
    memset(p + off + 2, (val >> 16) & 0xFF, 1);
    memset(p + off + 3, (val >> 24) & 0xFF, 1);
}

# Build a fresh 44-byte termios buffer with raw-mode flags applied, in calloc'd
# memory so NUL bytes in the flag words and c_cc[] survive (chr()+concat would
# truncate at the first NUL, leaving tcsetattr a garbage struct -> the terminal
# never actually enters raw mode). c_cc[] and speeds (bytes 16..43) are copied
# verbatim from `saved` via memcpy; the four flag words are then poked in.
# Returns the calloc pointer as a `str`; the caller MUST free() it.
def build_raw_termios(saved: str) -> str {
    iflag: int = read_u32(saved, 0) & ~(
        IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON
    );
    oflag: int = read_u32(saved, 4) & ~OPOST;
    cflag: int = (read_u32(saved, 8) & ~(CSIZE | PARENB)) | CS8;
    lflag: int = read_u32(saved, 12) & ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
    p: int = calloc(TERMIOS_SZ, 1);
    memcpy(p, saved, TERMIOS_SZ);
    poke_u32(p, 0, iflag);
    poke_u32(p, 4, oflag);
    poke_u32(p, 8, cflag);
    poke_u32(p, 12, lflag);
    # Non-canonical byte-at-a-time reads: VMIN=1 (c_cc[16]@32), VTIME=0 (c_cc[17]@33).
    # xnu c_cc base offset is 16 (no c_line field); VMIN=16, VTIME=17 in <sys/termios.h>.
    memset(p + 32, 1, 1);
    memset(p + 33, 0, 1);
    out: str = p;
    return out;
}

def _tty_device_path -> str {
    # Control plane sets JAC_AI_TUI_TTY to the parent's terminal (e.g. /dev/ttys003).
    # open("/dev/tty") fails after setsid() (no controlling tty), so we need the
    # explicit path when the sidecar runs in its own session.
    p = os.getenv("JAC_AI_TUI_TTY");
    if p is not None {
        if len(p) > 0 {
            return p;
        }
    }
    return "/dev/tty";
}

def tty_open -> int {
    # Subprocess entry: device chosen by JAC_AI_TUI_TTY / /dev/tty fallback.
    return tty_open_dev("");
}

def tty_fd -> int {
    # The opened tty fd (>= 10 after relocation), or -1 if not open. Lets the
    # in-process host (host.na.jac) render/poll against the tty it owns rather
    # than fd 1, which in-process is the sv process's real stdout (see plan §2).
    return g_tty.fd;
}

def tty_open_dev(dev: str) -> int {
    # Open an explicit tty device, or "" to use _tty_device_path(). The
    # in-process host passes its foreground tty here; the subprocess passes "".
    path: str = dev;
    if len(path) == 0 {
        path = _tty_device_path();
    }
    fd: int = open(path, O_RDWR, 0);
    if fd < 0 {
        return -1;
    }
    # Relocate the tty fd above the stdio-remap range. open() hands back the lowest
    # free fd -- typically 3, since the sidecar's 0/1/2 are pipes -- but
    # tty_init_stdio_remap reuses fd 3 for the IPC channel (dup2(1, 3)) and would
    # clobber the tty. Move it with dup2, NOT fcntl(F_DUPFD): fcntl is variadic and
    # its min-fd arg is mis-marshaled through NA FFI (returns fd 0), which silently
    # rebinds every subsequent tcgetattr/tcsetattr to stdin -- so the TTY only works
    # by accident when stdin is itself a terminal, and fails under a piped stdin
    # (exactly how `jac ai --tui` spawns this sidecar).
    if fd < 10 {
        if dup2(fd, 10) < 0 {
            close(fd);
            return -1;
        }
        close(fd);
        fd = 10;
    }
    saved: str = calloc(TERMIOS_SZ, 1);
    if tcgetattr(fd, saved) != 0 {
        free(saved);
        close(fd);
        return -1;
    }
    g_tty.saved_term = saved;
    raw_buf: str = build_raw_termios(saved);
    rc: int = tcsetattr(fd, TCSANOW, raw_buf);
    free(raw_buf);
    if rc != 0 {
        free(saved);
        close(fd);
        return -1;
    }
    fl: int = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, fl | O_NONBLOCK);
    g_tty.fd = fd;
    tty_update_size();
    return fd;
}

def tty_close {
    fd: int = g_tty.fd;
    saved: str = g_tty.saved_term;
    if fd >= 0 {
        if len(saved) > 0 {
            # `saved` already holds the original 44-byte termios; restore it
            # directly as an i8* -- no struct round-trip needed.
            rc: int = tcsetattr(fd, TCSANOW, saved);
            if rc != 0 {
                # If restoring the exact saved termios fails, try to at least
                # restore canonical mode and signal handling so the terminal
                # is usable after exit. This is a fallback to prevent leaving
                # the terminal in a broken raw state.
                fallback: str = calloc(TERMIOS_SZ, 1);
                if tcgetattr(fd, fallback) == 0 {
                    # Re-enable canonical mode, signals, and echo
                    lflag: int = read_u32(fallback, 12) | (ICANON | ISIG | ECHO);
                    poke_u32(fallback, 12, lflag);
                    tcsetattr(fd, TCSANOW, fallback);
                }
                free(fallback);
            }
            free(saved);
            g_tty.saved_term = "";
        }
        close(fd);
        g_tty.fd = -1;
    }
}

def tty_update_size {
    fd: int = g_tty.fd;
    if fd < 0 {
        return;
    }
    ws: str = calloc(8, 1);
    if ioctl(fd, TIOCGWINSZ, ws) == 0 {
        row: int = u16le(ws, 0);
        col: int = u16le(ws, 2);
        xpx: int = u16le(ws, 4);
        ypx: int = u16le(ws, 6);
        if row > 0 {
            if col > 0 {
                g_tty.rows = row;
                g_tty.cols = col;
                g_tty.x_pixels = xpx;
                g_tty.y_pixels = ypx;
            }
        }
    }
    free(ws);
}

def tty_rows -> int {
    return g_tty.rows;
}

def tty_cols -> int {
    return g_tty.cols;
}

def tty_x_pixels -> int {
    # Total terminal pixel width (ws_xpixel from TIOCGWINSZ). 0 if not reported.
    return g_tty.x_pixels;
}

def tty_y_pixels -> int {
    # Total terminal pixel height (ws_ypixel from TIOCGWINSZ). 0 if not reported.
    return g_tty.y_pixels;
}

def tty_poll(timeout_ms: int) {
    g_tty.stdin_ready = 0;
    g_tty.key_ready = 0;
    fd: int = g_tty.fd;
    if fd < 0 {
        return;
    }
    # struct pollfd[2] in calloc'd (NUL-safe) memory. Each entry is 8 bytes:
    # { int fd; short events; short revents }. calloc zeroes fd-high bytes and
    # revents; we poke in fd low bytes and events=POLLIN. Slot 0 = stdin (fd 0,
    # already zeroed), slot 1 = the tty fd.
    p: int = calloc(16, 1);
    memset(p + 4, POLLIN, 1);
    memset(p + 8, fd & 0xFF, 1);
    memset(p + 9, (fd >> 8) & 0xFF, 1);
    memset(p + 12, POLLIN, 1);
    fds: str = p;
    r: int = poll(fds, 2, timeout_ms);
    if r > 0 {
        rev0: int = u16le(fds, 6);
        rev1: int = u16le(fds, 14);
        if rev0 & POLLIN != 0 {
            g_tty.stdin_ready = 1;
        }
        if rev1 & POLLIN != 0 {
            g_tty.key_ready = 1;
        }
    }
    free(p);
}

def tty_stdin_ready -> int {
    return g_tty.stdin_ready;
}

def tty_key_ready -> int {
    return g_tty.key_ready;
}

def tty_write(fd: int, text: str) {
    n: int = len(text);
    if n <= 0 {
        return;
    }
    write(fd, text, n);
}

def tty_read_byte(fd: int) -> int {
    buf: str = calloc(2, 1);
    n: int = read(fd, buf, 1);
    if n <= 0 {
        free(buf);
        return -1;
    }
    c: int = ord(buf[0]);
    free(buf);
    return c;
}

def tty_read_line -> str {
    out: str = "";
    while True {
        c: int = tty_read_byte(0);
        if c < 0 {
            break;
        }
        if c == 10 {
            break;
        }
        if c != 13 {
            out = out + chr(c);
        }
    }
    return out;
}

def tty_read_key -> str {
    fd: int = g_tty.fd;
    if fd < 0 {
        return "";
    }
    c: int = tty_read_byte(fd);
    if c < 0 {
        return "";
    }
    if c != 27 {
        return chr(c);
    }
    seq: str = chr(27);
    c2: int = tty_read_byte(fd);
    if c2 < 0 {
        return seq;
    }
    seq = seq + chr(c2);
    if c2 == 79 {
        c3: int = tty_read_byte(fd);
        if c3 >= 0 {
            seq = seq + chr(c3);
        }
        return seq;
    }
    if c2 == 91 {
        # CSI: read parameter/intermediate bytes until a final byte in
        # 0x40-0x7E (@-~). Cap the run to bound a malformed stream. This
        # captures 4-byte (\033[5~) and mouse (\033[<b;x;yM) sequences.
        while len(seq) < 32 {
            cn: int = tty_read_byte(fd);
            if cn < 0 {
                break;
            }
            seq = seq + chr(cn);
            if cn >= 64 and cn <= 126 {
                break;
            }
        }
    }
    return seq;
}

def tty_init_stdio_remap -> int {
    if dup2(1, 3) < 0 {
        return -1;
    }
    if dup2(2, 1) < 0 {
        dup2(3, 1);
        return -1;
    }
    g_tty.fd_saved = 1;
    return 0;
}

def tty_restore_stdio {
    if g_tty.fd_saved != 0 {
        dup2(3, 1);
        g_tty.fd_saved = 0;
    }
}

def tty_ipc_fd -> int {
    return 3;
}
