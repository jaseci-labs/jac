import from .libc_tty { tty_write }

glob ANSI_RESET: str = "\033[0m",
     ANSI_BOLD: str = "\033[1m",
     ANSI_ITALIC: str = "\033[3m",
     ANSI_INVERSE: str = "\033[7m",
     ANSI_STRIKE: str = "\033[9m",
     ANSI_FG_YELLOW: str = "\033[33m",
     ANSI_CLEAR_SCREEN: str = "\033[2J\033[H",
     ANSI_CLEAR_LINE: str = "\033[2K";

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

def term_enable_mouse(fd: int) {
    tty_write(fd, "\033[?1000h\033[?1006h");
}

def term_disable_mouse(fd: int) {
    tty_write(fd, "\033[?1006l\033[?1000l");
}

def term_sync_start(fd: int) {
    tty_write(fd, "\033[?2026h");
}

def term_sync_end(fd: int) {
    tty_write(fd, "\033[?2026l");
}

obj Rgb {
    has r: int = 0,
        g: int = 0,
        b: int = 0;
}

def ansi_move(x: int, y: int) -> str {
    return f"\033[{y + 1};{x + 1}H";
}

def ansi_bg(c: Rgb) -> str {
    return f"\033[48;2;{c.r};{c.g};{c.b}m";
}

def term_repeat(c: str, n: int) -> str {
    if n <= 0 {
        return "";
    }
    return c * n;
}

def term_spaces(n: int) -> str {
    return term_repeat(" ", n);
}

def term_dashes(n: int) -> str {
    return term_repeat("─", n);
}

def ansi_sgr(fg: Rgb, bg: Rgb, attrs: int) -> str {
    parts: list[str] = ["\033[0"];
    if attrs & 1 != 0 {
        parts.append(";1");
    }
    if attrs & 2 != 0 {
        parts.append(";2");
    }
    if attrs & 4 != 0 {
        parts.append(";3");
    }
    parts.append(f";38;2;{fg.r};{fg.g};{fg.b};48;2;{bg.r};{bg.g};{bg.b}m");
    return "".join(parts);
}
