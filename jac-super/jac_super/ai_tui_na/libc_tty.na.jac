"""Pure-Jac terminal helpers — direct libc FFI, zero custom .c files.

Requires a controlling terminal (/dev/tty). Uses:
  - scalar libc calls (open, read, write, dup2, fcntl, poll, …)
  - calloc-backed str buffers for ioctl / tcgetattr / tcsetattr
  - packed 8-byte strings for struct pollfd arrays

Type rule: Jac `int` for locals; `i32`/`i64` only in libc FFI decl slots.
"""

import from "/usr/lib/libc.so.6" {
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
    ) -> int;  def free(p: int) -> None;
}

# Both tcgetattr and tcsetattr take a 60-byte glibc-termios buffer via an i8*
# (a calloc'd `str`). Passing a by-value `Termios` struct through NA FFI
# mis-marshals the 60-byte aggregate and segfaults inside libc tcsetattr, so we
# never pass structs by value -- only pointer buffers built as fresh strings.
glob O_RDWR: int = 2,
     O_NONBLOCK: int = 2048,
     F_GETFL: int = 3,
     F_SETFL: int = 4,
     F_DUPFD: int = 10,
     TCSANOW: int = 0,
     TIOCGWINSZ: int = 0x5413,
     POLLIN: int = 1,
     IGNBRK: int = 0x00000001,
     BRKINT: int = 0x00000002,
     PARMRK: int = 0x00000008,
     ISTRIP: int = 0x00000020,
     INLCR: int = 0x00000100,
     IGNCR: int = 0x00000080,
     ICRNL: int = 0x00000400,
     IXON: int = 0x00000400,
     OPOST: int = 0x00000001,
     ECHO: int = 0x00000008,
     ECHONL: int = 0x00000040,
     ICANON: int = 0x00000002,
     ISIG: int = 0x00000001,
     IEXTEN: int = 0x00008000,
     CSIZE: int = 0x00000300,
     PARENB: int = 0x00000100,
     CS8: int = 0x00000060,
     TERMIOS_SZ: int = 60;

obj TtyCtx {
    has fd: int = -1,
        saved_term: str = "",
        rows: int = 24,
        cols: int = 80,
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

def pack_pollfd(fd: int, events: int) -> str {
    b0: str = chr(fd & 0xFF);
    b1: str = chr((fd >> 8) & 0xFF);
    b2: str = chr((fd >> 16) & 0xFF);
    b3: str = chr((fd >> 24) & 0xFF);
    b4: str = chr(events & 0xFF);
    b5: str = chr((events >> 8) & 0xFF);
    z: str = chr(0);
    return b0 + b1 + b2 + b3 + b4 + b5 + z + z;
}

def u32_bytes(val: int) -> str {
    b0: str = chr(val & 0xFF);
    b1: str = chr((val >> 8) & 0xFF);
    b2: str = chr((val >> 16) & 0xFF);
    b3: str = chr((val >> 24) & 0xFF);
    return b0 + b1 + b2 + b3;
}

# Build a fresh 60-byte termios buffer with raw-mode flags applied. Bytes
# 0..15 are the four rewritten flag words; bytes 16..59 (c_line, c_cc[], speeds)
# are copied verbatim from the saved buffer. Returned as a `str` so it can be
# handed to tcsetattr as an i8* without any by-value struct marshaling.
def build_raw_termios(saved: str) -> str {
    iflag: int = read_u32(saved, 0) & ~(
        IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON
    );
    oflag: int = read_u32(saved, 4) & ~OPOST;
    cflag: int = (read_u32(saved, 8) & ~(CSIZE | PARENB)) | CS8;
    lflag: int = read_u32(saved, 12) & ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
    out: str = u32_bytes(iflag) + u32_bytes(oflag) + u32_bytes(cflag) + u32_bytes(
        lflag
    );
    i: int = 16;
    while i < TERMIOS_SZ {
        out = out + chr(ord(saved[i]));
        i = i + 1;
    }
    return out;
}

def tty_open -> int {
    fd: int = open("/dev/tty", O_RDWR, 0);
    if fd < 0 {
        return -1;
    }
    if fd < 10 {
        safe: int = fcntl(fd, F_DUPFD, 10);
        close(fd);
        if safe < 0 {
            return -1;
        }
        fd = safe;
    }
    saved: str = calloc(TERMIOS_SZ, 1);
    if tcgetattr(fd, saved) != 0 {
        free(saved);
        close(fd);
        return -1;
    }
    g_tty.saved_term = saved;
    raw_buf: str = build_raw_termios(saved);
    if tcsetattr(fd, TCSANOW, raw_buf) != 0 {
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
            # `saved` already holds the original 60-byte termios; restore it
            # directly as an i8* -- no struct round-trip needed.
            tcsetattr(fd, TCSANOW, saved);
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
        if row > 0 {
            if col > 0 {
                g_tty.rows = row;
                g_tty.cols = col;
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

def tty_poll(timeout_ms: int) {
    g_tty.stdin_ready = 0;
    g_tty.key_ready = 0;
    fd: int = g_tty.fd;
    if fd < 0 {
        return;
    }
    fds: str = pack_pollfd(0, POLLIN) + pack_pollfd(fd, POLLIN);
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
    if c2 == 91 or c2 == 79 {
        c3: int = tty_read_byte(fd);
        if c3 >= 0 {
            seq = seq + chr(c3);
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
