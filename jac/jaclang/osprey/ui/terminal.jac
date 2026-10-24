import sys;
import os;
import signal;
import select;
import termios;
import tty;
import fcntl;
import struct;


glob ENABLE_BRACKETED_PASTE: str = "\x1b[?2004h",
     DISABLE_BRACKETED_PASTE: str = "\x1b[?2004l",
     ENTER_ALT_SCREEN: str = "\x1b[?1049h",
     LEAVE_ALT_SCREEN: str = "\x1b[?1049l",
     SYNC_BEGIN: str = "\x1b[?2026h",
     SYNC_END: str = "\x1b[?2026l",
     HIDE_CURSOR: str = "\x1b[?25l",
     SHOW_CURSOR: str = "\x1b[?25h",
     CLEAR_SCREEN: str = "\x1b[2J\x1b[H",
     ENABLE_MOUSE: str = "\x1b[?1000h\x1b[?1002h\x1b[?1006h",
     DISABLE_MOUSE: str = "\x1b[?1006l\x1b[?1002l\x1b[?1000l";


obj Terminal {
    has columns: int = 80,
        rows: int = 24,
        started: bool = False,
        restored: bool = True,
        alternate_screen: bool = False,
        bracketed_paste: bool = False,
        cursor_visible: bool = True,
        sync_active: bool = False,
        mouse: bool = False;

    def size -> tuple[int, int];
    def write(data: str);
    def start;
    def stop;
    def enter_alternate_screen;
    def leave_alternate_screen;
    def begin_synchronized_update;
    def end_synchronized_update;
    def hide_cursor;
    def show_cursor;
    def clear_screen;
    def enable_bracketed_paste;
    def disable_bracketed_paste;
    def enable_mouse;
    def disable_mouse;
    def set_title(title: str);
    def move_cursor(row: int, col: int);
    def restore;
}


def _ioctl_winsize(fd: int) -> tuple[int, int] | None;


obj Utf8StreamDecoder {
    has _pending: bytes = b"";

    def init;
    def feed(data: bytes) -> str;
}


def read_terminal_size(
    fallback_cols: int = 80, fallback_rows: int = 24
) -> tuple[int, int];


obj ProcessTerminal(Terminal) {
    has _fd: int = -1,
        _old_attrs: any = None,
        _old_handler: any = None,
        _old_sigint: any = None,
        _old_sigterm: any = None,
        _old_sighup: any = None,
        _utf8: Utf8StreamDecoder postinit,
        _stdin_buf: str = "",
        eof: bool = False,
        on_resize: Callable[[int, int], None] | None = None,
        on_input: Callable[[str], None] | None = None,
        on_interrupt: Callable[[], None] | None = None,
        on_terminate: Callable[[], None] | None = None;

    def postinit;
    def write(data: str) -> None;
    def _refresh_size;
    def _on_sigwinch(signum: int, frame: any);
    def _on_terminate_signal(signum: int, frame: any);
    def _on_sigint(signum: int, frame: any);
    def start -> None;
    def stop -> None;
    def poll_input(timeout_s: float = 0.0) -> str;
}


def synchronized_write(term: Terminal, data: str);

impl Terminal.size -> tuple[int, int] {
    return (self.columns, self.rows);
}

impl Terminal.write(data: str) {
    raise NotImplementedError("Terminal.write");
}

impl Terminal.start {
    raise NotImplementedError("Terminal.start");
}

impl Terminal.stop {
    raise NotImplementedError("Terminal.stop");
}

impl Terminal.enter_alternate_screen {
    self.write(ENTER_ALT_SCREEN);
    self.alternate_screen = True;
}

impl Terminal.leave_alternate_screen {
    self.write(LEAVE_ALT_SCREEN);
    self.alternate_screen = False;
}

impl Terminal.begin_synchronized_update {
    self.write(SYNC_BEGIN);
    self.sync_active = True;
}

impl Terminal.end_synchronized_update {
    self.write(SYNC_END);
    self.sync_active = False;
}

impl Terminal.hide_cursor {
    self.write(HIDE_CURSOR);
    self.cursor_visible = False;
}

impl Terminal.show_cursor {
    self.write(SHOW_CURSOR);
    self.cursor_visible = True;
}

impl Terminal.clear_screen {
    self.write(CLEAR_SCREEN);
}

impl Terminal.enable_bracketed_paste {
    self.write(ENABLE_BRACKETED_PASTE);
    self.bracketed_paste = True;
}

impl Terminal.disable_bracketed_paste {
    self.write(DISABLE_BRACKETED_PASTE);
    self.bracketed_paste = False;
}

impl Terminal.enable_mouse {
    self.write(ENABLE_MOUSE);
    self.mouse = True;
}

impl Terminal.disable_mouse {
    self.write(DISABLE_MOUSE);
    self.mouse = False;
}

impl Terminal.set_title(title: str) {
    self.write(f"\x1b]0;{title}\x07");
}

impl Terminal.move_cursor(row: int, col: int) {
    self.write(f"\x1b[{row};{col}H");
}

impl Terminal.restore {
    self.stop();
}


impl _ioctl_winsize(fd: int) -> tuple[int, int] | None {
    try {
        packed = fcntl.ioctl(fd, termios.TIOCGWINSZ, struct.pack("HHHH", 0, 0, 0, 0));
        (rows, cols, _x, _y) = struct.unpack("HHHH", packed);
        if rows > 0 and cols > 0 {
            return (cols, rows);
        }
    } except Exception {}
    return None;
}


impl Utf8StreamDecoder.init {}

impl Utf8StreamDecoder.feed(data: bytes) -> str {
    buf: bytes = self._pending;
    if len(data) > 0 {
        if len(buf) == 0 {
            buf = data;
        } else {
            buf = buf + data;
        }
    }
    out: str = "";
    n: int = len(buf);
    i: int = 0;
    while i < n {
        b0: int = buf[i];
        need: int = 0;
        lo: int = 0x80;
        hi: int = 0xBF;
        cp: int = 0;
        ok: bool = True;
        if b0 < 0x80 {
            out += chr(b0);
            i += 1;
            continue;
        } elif b0 >= 0xC2 and b0 <= 0xDF {
            need = 1;
            cp = b0 - 0xC0;
        } elif b0 == 0xE0 {
            need = 2;
            lo = 0xA0;
            cp = b0 - 0xE0;
        } elif b0 >= 0xE1 and b0 <= 0xEC {
            need = 2;
            cp = b0 - 0xE0;
        } elif b0 == 0xED {
            need = 2;
            hi = 0x9F;
            cp = b0 - 0xE0;
        } elif b0 >= 0xEE and b0 <= 0xEF {
            need = 2;
            cp = b0 - 0xE0;
        } elif b0 == 0xF0 {
            need = 3;
            lo = 0x90;
            cp = b0 - 0xF0;
        } elif b0 >= 0xF1 and b0 <= 0xF3 {
            need = 3;
            cp = b0 - 0xF0;
        } elif b0 == 0xF4 {
            need = 3;
            hi = 0x8F;
            cp = b0 - 0xF0;
        } else {
            ok = False;
        }
        if not ok {
            out += "\uFFFD";
            i += 1;
            continue;
        }
        if i + need > n - 1 {
            break;
        }
        j: int = 1;
        good: bool = True;
        while j <= need {
            bj: int = buf[i + j];
            lim_lo: int = lo;
            lim_hi: int = hi;
            if j > 1 {
                lim_lo = 0x80;
                lim_hi = 0xBF;
            }
            if bj < lim_lo or bj > lim_hi {
                good = False;
                break;
            }
            cp = cp * 64 + (bj - 0x80);
            j += 1;
        }
        if not good {
            out += "\uFFFD";
            i += j;
            continue;
        }
        out += chr(cp);
        i += need + 1;
    }
    if i >= n {
        self._pending = b"";
    } else {
        self._pending = buf[i:n];
    }
    return out;
}


impl read_terminal_size(
    fallback_cols: int = 80, fallback_rows: int = 24
) -> tuple[int, int] {
    for fd in [1, 0, 2] {
        got = _ioctl_winsize(fd);
        if got is not None {
            return got;
        }
    }
    env_cols = os.environ.get("COLUMNS");
    env_rows = os.environ.get("LINES");
    cols = int(env_cols) if env_cols else fallback_cols;
    rows = int(env_rows) if env_rows else fallback_rows;
    if cols <= 0 {
        cols = fallback_cols;
    }
    if rows <= 0 {
        rows = fallback_rows;
    }
    return (cols, rows);
}


impl ProcessTerminal.postinit {
    self._utf8 = Utf8StreamDecoder();
}

impl ProcessTerminal.write(data: str) -> None {
    if not data {
        return;
    }
    sys.stdout.write(data);
    sys.stdout.flush();
}

impl ProcessTerminal._refresh_size {
    (cols, rows) = read_terminal_size(self.columns, self.rows);
    changed = cols != self.columns or rows != self.rows;
    self.columns = cols;
    self.rows = rows;
    resized = self.on_resize;
    if changed and resized is not None {
        resized(cols, rows);
    }
}

impl ProcessTerminal._on_sigwinch(signum: int, frame: any) {
    self._refresh_size();
}

impl ProcessTerminal._on_terminate_signal(signum: int, frame: any) {
    self.restore();
    terminated = self.on_terminate;
    if terminated is not None {
        terminated();
    } else {
        raise SystemExit(128 + signum);
    }
}

impl ProcessTerminal._on_sigint(signum: int, frame: any) {
    self.restore();
    interrupted = self.on_interrupt;
    if interrupted is not None {
        interrupted();
    } else {
        raise KeyboardInterrupt();
    }
}

impl ProcessTerminal.start -> None {
    if self.started {
        return;
    }
    if not os.isatty(0) {
        raise RuntimeError("ProcessTerminal requires a TTY stdin");
    }
    self._fd = 0;
    self._old_attrs = termios.tcgetattr(self._fd);
    tty.setraw(self._fd);

    self.started = True;
    self.restored = False;
    try {
        self._refresh_size();
        sigwinch = signal.SIGWINCH as int;
        sigint = signal.SIGINT as int;
        self._old_handler = signal.signal(sigwinch, self._on_sigwinch);
        self._old_sigint = signal.signal(sigint, self._on_sigint);
        self._old_sigterm = signal.signal(
            signal.SIGTERM as int, self._on_terminate_signal
        );
        self._old_sighup = signal.signal(
            signal.SIGHUP as int, self._on_terminate_signal
        );
        self.enable_bracketed_paste();
        self.enter_alternate_screen();
        self.hide_cursor();
    } except Exception {
        self.stop();
        raise;
    }
}

impl ProcessTerminal.stop -> None {
    if self.restored and not self.started {
        return;
    }
    try {
        if self.sync_active {
            self.end_synchronized_update();
        }
        if self.bracketed_paste {
            self.disable_bracketed_paste();
        }
        if self.mouse {
            self.disable_mouse();
        }
        if self.alternate_screen {
            self.leave_alternate_screen();
        }
        if not self.cursor_visible {
            self.show_cursor();
        }
    } except Exception {}
    if self._old_handler is not None {
        try {
            signal.signal(signal.SIGWINCH as int, self._old_handler);
        } except Exception {}
        self._old_handler = None;
    }
    if self._old_sigint is not None {
        try {
            signal.signal(signal.SIGINT as int, self._old_sigint);
        } except Exception {}
        self._old_sigint = None;
    }
    if self._old_sigterm is not None {
        try {
            signal.signal(signal.SIGTERM as int, self._old_sigterm);
        } except Exception {}
        self._old_sigterm = None;
    }
    if self._old_sighup is not None {
        try {
            signal.signal(signal.SIGHUP as int, self._old_sighup);
        } except Exception {}
        self._old_sighup = None;
    }
    if self._old_attrs is not None and self._fd >= 0 {
        try {
            termios.tcsetattr(self._fd, termios.TCSADRAIN, self._old_attrs);
        } except Exception {}
        self._old_attrs = None;
    }
    self.started = False;
    self.restored = True;
}

impl ProcessTerminal.poll_input(timeout_s: float = 0.0) -> str {
    if not self.started or self._fd < 0 {
        return "";
    }
    self._refresh_size();
    ready = select.select([self._fd], [], [], timeout_s);
    if not ready[0] {
        return "";
    }
    try {
        data = os.read(self._fd, 8192);
    } except BlockingIOError {
        return "";
    } except OSError {
        return "";
    }
    if not data {
        self.eof = True;
        return "";
    }
    text = self._utf8.feed(data);
    received = self.on_input;
    if received is not None {
        received(text);
    }
    return text;
}


impl synchronized_write(term: Terminal, data: str) {
    term.begin_synchronized_update();
    try {
        term.write(data);
    } finally {
        term.end_synchronized_update();
    }
}
