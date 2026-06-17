"""Pure-Jac terminal helpers — direct libc FFI, zero custom .c files.

Requires a controlling terminal (/dev/tty). Uses:
  - scalar libc calls (open, read, write, dup2, fcntl, poll, …)
  - calloc-backed str buffers for ioctl / tcgetattr / tcsetattr
  - packed 8-byte strings for struct pollfd arrays

Type rule: Jac `int` for locals; `i32`/`i64` only in libc FFI decl slots.
"""

import from "/usr/lib/libc.so.6" {
    obj Termios {
        has c_iflag: u32,
            c_oflag: u32,
            c_cflag: u32,
            c_lflag: u32,
            c_line: u8,
            c_cc0: u8,
            c_cc1: u8,
            c_cc2: u8,
            c_cc3: u8,
            c_cc4: u8,
            c_cc5: u8,
            c_cc6: u8,
            c_cc7: u8,
            c_cc8: u8,
            c_cc9: u8,
            c_cc10: u8,
            c_cc11: u8,
            c_cc12: u8,
            c_cc13: u8,
            c_cc14: u8,
            c_cc15: u8,
            c_cc16: u8,
            c_cc17: u8,
            c_cc18: u8,
            c_cc19: u8,
            c_cc20: u8,
            c_cc21: u8,
            c_cc22: u8,
            c_cc23: u8,
            c_cc24: u8,
            c_cc25: u8,
            c_cc26: u8,
            c_cc27: u8,
            c_cc28: u8,
            c_cc29: u8,
            c_cc30: u8,
            c_cc31: u8,
            c_ispeed: u32,
            c_ospeed: u32;
    }  def open(path: str, flags: i32, mode: i32) -> i32;  def close(fd: i32) -> i32;  def read(
        fd: i32, buf: str, count: i32
    ) -> i32;  def write(fd: i32, buf: str, count: i32) -> i32;  def dup2(
        oldfd: i32, newfd: i32
    ) -> i32;  def fcntl(fd: i32, cmd: i32, arg: i32) -> i32;  def ioctl(
        fd: i32, request: i64, arg: str
    ) -> i32;  def tcgetattr(fd: i32, term: str) -> i32;  def tcsetattr(
        fd: i32, opt: i32, term: Termios
    ) -> i32;  def poll(fds: str, nfds: i32, timeout: i32) -> i32;  def calloc(
        n: int, sz: int
    ) -> int;  def free(p: int) -> None;
}

# tcsetattr takes Termios (input). tcgetattr fills a calloc str (output).
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

def blank_termios -> Termios {
    return Termios(
        c_iflag=0,
        c_oflag=0,
        c_cflag=0,
        c_lflag=0,
        c_line=0,
        c_cc0=0,
        c_cc1=0,
        c_cc2=0,
        c_cc3=0,
        c_cc4=0,
        c_cc5=0,
        c_cc6=0,
        c_cc7=0,
        c_cc8=0,
        c_cc9=0,
        c_cc10=0,
        c_cc11=0,
        c_cc12=0,
        c_cc13=0,
        c_cc14=0,
        c_cc15=0,
        c_cc16=0,
        c_cc17=0,
        c_cc18=0,
        c_cc19=0,
        c_cc20=0,
        c_cc21=0,
        c_cc22=0,
        c_cc23=0,
        c_cc24=0,
        c_cc25=0,
        c_cc26=0,
        c_cc27=0,
        c_cc28=0,
        c_cc29=0,
        c_cc30=0,
        c_cc31=0,
        c_ispeed=0,
        c_ospeed=0
    );
}

def termios_from_buf(buf: str) -> Termios {
    t: Termios = blank_termios();
    t.c_iflag = read_u32(buf, 0);
    t.c_oflag = read_u32(buf, 4);
    t.c_cflag = read_u32(buf, 8);
    t.c_lflag = read_u32(buf, 12);
    t.c_line = ord(buf[16]);
    t.c_cc0 = ord(buf[17]);
    t.c_cc1 = ord(buf[18]);
    t.c_cc2 = ord(buf[19]);
    t.c_cc3 = ord(buf[20]);
    t.c_cc4 = ord(buf[21]);
    t.c_cc5 = ord(buf[22]);
    t.c_cc6 = ord(buf[23]);
    t.c_cc7 = ord(buf[24]);
    t.c_cc8 = ord(buf[25]);
    t.c_cc9 = ord(buf[26]);
    t.c_cc10 = ord(buf[27]);
    t.c_cc11 = ord(buf[28]);
    t.c_cc12 = ord(buf[29]);
    t.c_cc13 = ord(buf[30]);
    t.c_cc14 = ord(buf[31]);
    t.c_cc15 = ord(buf[32]);
    t.c_cc16 = ord(buf[33]);
    t.c_cc17 = ord(buf[34]);
    t.c_cc18 = ord(buf[35]);
    t.c_cc19 = ord(buf[36]);
    t.c_cc20 = ord(buf[37]);
    t.c_cc21 = ord(buf[38]);
    t.c_cc22 = ord(buf[39]);
    t.c_cc23 = ord(buf[40]);
    t.c_cc24 = ord(buf[41]);
    t.c_cc25 = ord(buf[42]);
    t.c_cc26 = ord(buf[43]);
    t.c_cc27 = ord(buf[44]);
    t.c_cc28 = ord(buf[45]);
    t.c_cc29 = ord(buf[46]);
    t.c_cc30 = ord(buf[47]);
    t.c_cc31 = ord(buf[48]);
    t.c_ispeed = read_u32(buf, 52);
    t.c_ospeed = read_u32(buf, 56);
    return t;
}

def _makeraw(t: Termios) -> Termios {
    iflag: int = t.c_iflag;
    oflag: int = t.c_oflag;
    lflag: int = t.c_lflag;
    cflag: int = t.c_cflag;
    t.c_iflag = iflag & ~(
        IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON
    );
    t.c_oflag = oflag & ~OPOST;
    t.c_lflag = lflag & ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
    t.c_cflag = (cflag & ~(CSIZE | PARENB)) | CS8;
    return t;
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
    cur: Termios = termios_from_buf(saved);
    raw: Termios = _makeraw(cur);
    if tcsetattr(fd, TCSANOW, raw) != 0 {
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
            restore: Termios = termios_from_buf(saved);
            tcsetattr(fd, TCSANOW, restore);
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
