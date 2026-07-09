"""Libc-backed TTY layer: raw-mode setup, window size, polling, and key input.

FFI conventions (frozen): na has no bytes/buffer type, so `str` doubles as
char* — calloc() hands back an int pointer that is re-typed via an annotated
local (`out: str = p`), byte pokes are memset-of-one-byte at struct offsets
imported from tty_plat, and every calloc is paired with a free on all paths.
"""
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

# Shared libc constants (values identical on the supported platforms).
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

# Named bytes and buffer sizes for the pure-logic sections below.
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

"""Process-wide terminal state: the raw-mode fd, the saved termios image for
restore on exit, the last known window size, and poll/stdio bookkeeping."""
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

# Single shared terminal context (one controlling tty per process).
glob g_tty: TtyCtx = TtyCtx();

# --- little-endian struct peeks/pokes ---

"""Assemble an unsigned little-endian integer from nbytes bytes at buf[off]."""
def _read_le(buf: str, off: int, nbytes: int) -> int {
    val: int = 0;
    for i in range(nbytes) {
        val |= ord(buf[off + i]) << (8 * i);
    }
    return val;
}

"""Read a little-endian u32 struct field at byte offset off."""
def read_u32(buf: str, off: int) -> int {
    return _read_le(buf, off, 4);
}

"""Read a little-endian u16 struct field at byte offset off."""
def u16le(buf: str, off: int) -> int {
    return _read_le(buf, off, 2);
}

"""Write val as a little-endian u32 at pointer p + off, one byte per poke."""
def poke_u32(p: int, off: int, val: int) {
    memset(p + off, val & 0xFF, 1);
    memset(p + off + 1, (val >> 8) & 0xFF, 1);
    memset(p + off + 2, (val >> 16) & 0xFF, 1);
    memset(p + off + 3, (val >> 24) & 0xFF, 1);
}

# --- open/close + raw mode ---

"""Build a raw-mode termios image from the saved one (the cfmakeraw recipe):
strip input translation and flow control (iflag), output post-processing
(oflag), force 8-bit chars with no parity (cflag), and disable echo /
canonical mode / signals (lflag); VMIN/VTIME come from tty_plat. The u32
flag fields sit at offsets 0/4/8/12 on both platforms. Returns a calloc'd
buffer the caller must free."""
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

"""Terminal device path: $JAC_AI_TUI_TTY when set and non-empty, else /dev/tty."""
def _tty_device_path -> str {
    override = os.getenv("JAC_AI_TUI_TTY");
    if override is not None and len(override) > 0 {
        return override;
    }
    return "/dev/tty";
}

"""Open the default terminal device in raw mode (see tty_open_dev)."""
def tty_open -> int {
    return tty_open_dev("");
}

"""The raw-mode tty fd, or -1 when closed."""
def tty_fd -> int {
    return g_tty.fd;
}

"""Open the terminal device (empty dev = default path), save its termios,
switch it to raw mode, and make it non-blocking.

A low fd is dup2'd up to 10 so the stdio rewiring in tty_setup_stdio_contract
(which dup2's over fds 1-3) can never clobber the terminal handle. Returns
the fd, or -1 with fd and termios buffer released on failure."""
def tty_open_dev(dev: str) -> int {
    path: str = dev if len(dev) > 0 else _tty_device_path();
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

"""Restore the saved termios and close the tty fd. If the full restore fails,
fall back to re-enabling ICANON/ISIG/ECHO on the terminal's current state so
the shell is not left in raw mode. Safe to call when already closed."""
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

# --- window size ---

"""Refresh g_tty's window size via TIOCGWINSZ. struct winsize is four u16s
(ws_row, ws_col, ws_xpixel, ws_ypixel) at offsets 0/2/4/6; zero-sized
reports are ignored so the last good size sticks."""
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

"""Last known terminal height in rows."""
def tty_rows -> int {
    return g_tty.rows;
}

"""Last known terminal width in columns."""
def tty_cols -> int {
    return g_tty.cols;
}

"""Last known terminal width in pixels (0 when the terminal does not report it)."""
def tty_x_pixels -> int {
    return g_tty.x_pixels;
}

"""Last known terminal height in pixels (0 when the terminal does not report it)."""
def tty_y_pixels -> int {
    return g_tty.y_pixels;
}

# --- polling ---

"""Poll stdin (fd 0) and the tty fd for readability, updating the
stdin_ready/key_ready flags. The buffer holds two struct pollfd
{ i32 fd; u16 events; u16 revents; }: entry 0 at offset 0 watches stdin
(fd field stays 0 from calloc), entry 1 at offset 8 watches the tty;
revents land at offsets 6 and 14."""
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

"""Did the last tty_poll see stdin (fd 0) readable?"""
def tty_stdin_ready -> bool {
    return g_tty.stdin_ready;
}

"""Did the last tty_poll see the tty fd readable?"""
def tty_key_ready -> bool {
    return g_tty.key_ready;
}

# --- reading and writing ---

"""Write text bytes to fd verbatim; no-op for empty text."""
def tty_write(fd: int, text: str) {
    n: int = len(text);
    if n <= 0 {
        return;
    }
    write(fd, text, n);
}

"""Read one byte from fd: 0-255 on data, -1 otherwise. The tty fd is
non-blocking, so EOF and nothing-pending both surface as -1."""
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

"""Read one line from stdin: bytes up to LF, with CRs stripped. An immediate
EOF and a bare newline both return "" — the line channel never needs to
distinguish the two."""
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

"""Read one key from the raw tty. Tri-state result: "" when the tty is closed
or no byte is pending, a single char for plain keys, or a full escape
sequence. After ESC: 'O' (SS3) takes exactly one more byte; '[' (CSI)
collects bytes until a final byte in 0x40-0x7E, capped at _KEY_SEQ_CAP to
bound malformed input. A lone ESC (nothing follows) is returned as-is."""
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

# --- stdio contract (host embed) ---

# Post-contract fd meanings for both sides of the embed: fd 1 renders to the
# terminal (alias of the original stderr), fd 3 carries IPC (alias of the
# original stdout).
glob RENDER_FD: int = 1,
     IPC_FD: int = 3;

"""Result of tty_setup_stdio_contract. ok=False means stdio was left
untouched (or rolled back) and the fd-3 contract must not be assumed."""
obj TtyStdioContract {
    has ok: bool = False,
        render_fd: int = RENDER_FD,
        ipc_fd: int = IPC_FD;
}

"""Rewire stdio for TUI hosting: park the original stdout (the IPC pipe) on
fd 3, then alias fd 1 to stderr so stray prints hit the terminal instead of
corrupting the IPC stream. Rolls the first dup2 back if the second fails."""
def tty_setup_stdio_contract -> TtyStdioContract {
    contract = TtyStdioContract();
    if dup2(1, contract.ipc_fd) < 0 {
        return contract;
    }
    if dup2(2, contract.render_fd) < 0 {
        dup2(contract.ipc_fd, 1);
        return contract;
    }
    g_tty.fd_saved = True;
    contract.ok = True;
    return contract;
}

"""Undo tty_setup_stdio_contract: point fd 1 back at the parked IPC fd."""
def tty_restore_stdio {
    if g_tty.fd_saved {
        dup2(IPC_FD, 1);
        g_tty.fd_saved = False;
    }
}
