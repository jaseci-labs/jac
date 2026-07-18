import os;

import from .tty_plat {
    open,
    close,
    read,
    write,
    dup2,
    fcntl,
    ioctl,
    tcgetattr,
    tcsetattr,
    poll,
    calloc,
    free,
    memset,
    memcpy,
    O_NONBLOCK,
    TIOCGWINSZ,
    IXON,
    ECHONL,
    ICANON,
    ISIG,
    IEXTEN,
    CSIZE,
    PARENB,
    CS8,
    TERMIOS_SZ,
    VMIN_OFF,
    VMIN_VAL,
    VTIME_OFF,
    VTIME_VAL
}

glob O_RDWR: int = 2,
     F_GETFL: int = 3,
     F_SETFL: int = 4,
     TCSANOW: int = 0,
     POLLIN: int = 1,
     IGNBRK: int = 0x00000001,
     BRKINT: int = 0x00000002,
     PARMRK: int = 0x00000008,
     ISTRIP: int = 0x00000020,
     INLCR: int = 0x00000040,
     IGNCR: int = 0x00000080,
     ICRNL: int = 0x00000100,
     OPOST: int = 0x00000001,
     ECHO: int = 0x00000008;

glob _TTY_BYTE_LF: int = 10,
     _TTY_BYTE_CR: int = 13,
     _TTY_BYTE_ESC: int = 27,
     _BYTE_SS3: int = 79,
     _BYTE_CSI: int = 91,
     _TTY_CSI_FINAL_LO: int = 64,
     _TTY_CSI_FINAL_HI: int = 126,
     _KEY_SEQ_CAP: int = 32,
     _WINSIZE_SZ: int = 8,
     _POLLFDS_SZ: int = 16;

obj TtyCtx {
    has fd: int = -1,
        saved_term: str = "",
        term_saved: bool = False,
        rows: int = 24,
        cols: int = 80,
        x_pixels: int = 0,
        y_pixels: int = 0,
        stdin_ready: bool = False,
        key_ready: bool = False,
        fd_saved: bool = False;
}

glob g_tty: TtyCtx = TtyCtx();

def _read_le(buf: str, off: int, nbytes: int) -> int {
    val: int = 0;
    for i in range(nbytes) {
        val |= ord(buf[off + i]) << (8 * i);
    }
    return val;
}

def read_u32(buf: str, off: int) -> int {
    return _read_le(buf, off, 4);
}

def u16le(buf: str, off: int) -> int {
    return _read_le(buf, off, 2);
}

def poke_u32(p: int, off: int, val: int) {
    memset(p + off, val & 0xFF, 1);
    memset(p + off + 1, (val >> 8) & 0xFF, 1);
    memset(p + off + 2, (val >> 16) & 0xFF, 1);
    memset(p + off + 3, (val >> 24) & 0xFF, 1);
}

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
    memset(p + VMIN_OFF, VMIN_VAL, 1);
    memset(p + VTIME_OFF, VTIME_VAL, 1);
    out: str = p;
    return out;
}

def _tty_device_path -> str {
    override = os.getenv("JAC_AI_TUI_TTY");
    if override is not None and len(override) > 0 {
        return override;
    }
    return "/dev/tty";
}

def tty_open -> int {
    path: str = _tty_device_path();
    fd: int = open(path, O_RDWR, 0);
    if fd < 0 {
        return -1;
    }
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
    g_tty.term_saved = True;
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
    if fd < 0 {
        return;
    }
    saved: str = g_tty.saved_term;
    if g_tty.term_saved {
        rc: int = tcsetattr(fd, TCSANOW, saved);
        if rc != 0 {
            fallback: str = calloc(TERMIOS_SZ, 1);
            if tcgetattr(fd, fallback) == 0 {
                lflag: int = read_u32(fallback, 12) | (ICANON | ISIG | ECHO);
                poke_u32(fallback, 12, lflag);
                tcsetattr(fd, TCSANOW, fallback);
            }
            free(fallback);
        }
        free(saved);
        g_tty.saved_term = "";
        g_tty.term_saved = False;
    }
    close(fd);
    g_tty.fd = -1;
}

def tty_update_size {
    fd: int = g_tty.fd;
    if fd < 0 {
        return;
    }
    ws: str = calloc(_WINSIZE_SZ, 1);
    if ioctl(fd, TIOCGWINSZ, ws) == 0 {
        row: int = u16le(ws, 0);
        col: int = u16le(ws, 2);
        if row > 0 and col > 0 {
            g_tty.rows = row;
            g_tty.cols = col;
            g_tty.x_pixels = u16le(ws, 4);
            g_tty.y_pixels = u16le(ws, 6);
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
    return g_tty.x_pixels;
}

def tty_y_pixels -> int {
    return g_tty.y_pixels;
}

def tty_poll(timeout_ms: int) {
    g_tty.stdin_ready = False;
    g_tty.key_ready = False;
    fd: int = g_tty.fd;
    if fd < 0 {
        return;
    }
    p: int = calloc(_POLLFDS_SZ, 1);
    memset(p + 4, POLLIN, 1);
    poke_u32(p, 8, fd);
    memset(p + 12, POLLIN, 1);
    fds: str = p;
    r: int = poll(fds, 2, timeout_ms);
    if r > 0 {
        rev0: int = u16le(fds, 6);
        rev1: int = u16le(fds, 14);
        if rev0 & POLLIN != 0 {
            g_tty.stdin_ready = True;
        }
        if rev1 & POLLIN != 0 {
            g_tty.key_ready = True;
        }
    }
    free(p);
}

def tty_stdin_ready -> bool {
    return g_tty.stdin_ready;
}

def tty_key_ready -> bool {
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
    chars: list[str] = [];
    while True {
        c: int = tty_read_byte(0);
        if c < 0 or c == _TTY_BYTE_LF {
            break;
        }
        if c != _TTY_BYTE_CR {
            chars.append(chr(c));
        }
    }
    return "".join(chars);
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
    if c != _TTY_BYTE_ESC {
        return chr(c);
    }
    seq: str = chr(_TTY_BYTE_ESC);
    c2: int = tty_read_byte(fd);
    if c2 < 0 {
        return seq;
    }
    seq += chr(c2);
    if c2 == _BYTE_SS3 {
        c3: int = tty_read_byte(fd);
        if c3 >= 0 {
            seq += chr(c3);
        }
        return seq;
    }
    if c2 == _BYTE_CSI {
        while len(seq) < _KEY_SEQ_CAP {
            cn: int = tty_read_byte(fd);
            if cn < 0 {
                break;
            }
            seq += chr(cn);
            if cn >= _TTY_CSI_FINAL_LO and cn <= _TTY_CSI_FINAL_HI {
                break;
            }
        }
    }
    return seq;
}
