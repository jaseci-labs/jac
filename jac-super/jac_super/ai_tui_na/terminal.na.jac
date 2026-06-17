"""ANSI terminal escape sequence helpers — no custom C, pure string building."""

import from .libc_tty { tty_write }

def term_enter_alt_screen(fd: int) {
    tty_write(fd, "\033[?1049h");
}

def term_leave_alt_screen(fd: int) {
    tty_write(fd, "\033[?1049l");
}

def term_hide_cursor(fd: int) {
    tty_write(fd, "\033[?25l");
}

def term_show_cursor(fd: int) {
    tty_write(fd, "\033[?25h");
}

def term_sync_start(fd: int) {
    tty_write(fd, "\033[?2026h");
}

def term_sync_end(fd: int) {
    tty_write(fd, "\033[?2026l");
}

def ansi_move(x: int, y: int) -> str {
    row: int = y + 1;
    col: int = x + 1;
    return f"\033[{row};{col}H";
}

def ansi_reset -> str {
    return "\033[0m";
}

def ansi_sgr(
    fg_r: int, fg_g: int, fg_b: int, bg_r: int, bg_g: int, bg_b: int, attrs: int
) -> str {
    s: str = "\033[0";
    if attrs & 1 != 0 {
        s = s + ";1";
    }
    if attrs & 2 != 0 {
        s = s + ";2";
    }
    if attrs & 4 != 0 {
        s = s + ";3";
    }
    return s + f";38;2;{fg_r};{fg_g};{fg_b};48;2;{bg_r};{bg_g};{bg_b}m";
}
