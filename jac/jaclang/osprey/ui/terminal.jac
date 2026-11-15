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
