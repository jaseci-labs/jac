"""ANSI/DEC escape layer — the single home of every output escape byte.

Mode toggles write their sequences straight to the tty fd; the ansi_*
builders compose SGR/cursor strings for frame buffers. All escape bytes
here are frozen — siblings import these symbols instead of spelling
sequences themselves.

DEC private modes toggled below (CSI ? <mode> h to set, l to reset):
  1049  alternate screen buffer (saves/restores the shell's screen)
  25    DECTCEM cursor visibility
  1000  X11 mouse press/release reporting
  1006  SGR extended mouse coordinates (unambiguous past column 223)
  2026  synchronized output (terminal withholds paint until frame end)
"""

import from .libc_tty { tty_write }

# --- ANSI escape constants (single source for all output styling bytes) ---

glob ANSI_RESET: str = "\033[0m",
     ANSI_BOLD: str = "\033[1m",
     ANSI_ITALIC: str = "\033[3m",
     ANSI_INVERSE: str = "\033[7m",
     ANSI_STRIKE: str = "\033[9m",
     ANSI_FG_YELLOW: str = "\033[33m",
     ANSI_CLEAR_SCREEN: str = "\033[2J\033[H",
     ANSI_CLEAR_LINE: str = "\033[2K";

# --- terminal mode toggles ---

"""Switch to the alternate screen buffer (set DEC 1049)."""
def term_enter_alt_screen(fd: int) {
    tty_write(fd, "\033[?1049h");
}

"""Return to the primary screen buffer (reset DEC 1049)."""
def term_leave_alt_screen(fd: int) {
    tty_write(fd, "\033[?1049l");
}

"""Hide the text cursor (reset DEC 25 / DECTCEM)."""
def term_hide_cursor(fd: int) {
    tty_write(fd, "\033[?25l");
}

"""Show the text cursor (set DEC 25 / DECTCEM)."""
def term_show_cursor(fd: int) {
    tty_write(fd, "\033[?25h");
}

"""Enable mouse reporting: DEC 1000 press/release, DEC 1006 SGR coords."""
def term_enable_mouse(fd: int) {
    tty_write(fd, "\033[?1000h\033[?1006h");
}

"""Disable mouse reporting (DEC 1006 then 1000 — reverse of enable)."""
def term_disable_mouse(fd: int) {
    tty_write(fd, "\033[?1006l\033[?1000l");
}

"""Open a synchronized update (set DEC 2026): paint is deferred."""
def term_sync_start(fd: int) {
    tty_write(fd, "\033[?2026h");
}

"""Close a synchronized update (reset DEC 2026): frame paints at once."""
def term_sync_end(fd: int) {
    tty_write(fd, "\033[?2026l");
}

# --- color record ---

"""One 24-bit color channel triple; theme.na.jac holds the palette of these."""
obj Rgb {
    has r: int = 0,
        g: int = 0,
        b: int = 0;
}

# --- escape builders ---

"""Compose a cursor-move escape to 0-based cell (x, y); CSI rows/cols are 1-based."""
def ansi_move(x: int, y: int) -> str {
    return f"\033[{y + 1};{x + 1}H";
}

"""Return the SGR reset sequence (same bytes as ANSI_RESET)."""
def ansi_reset -> str {
    # Body must stay a literal (not ANSI_RESET): screen.na.jac calls this in a
    # glob initializer, and function-mediated glob reads during another
    # module's glob init segfault on na (init-order hazard).
    return "\033[0m";
}

"""Compose a 24-bit background-color SGR for one Rgb."""
def ansi_bg(c: Rgb) -> str {
    return f"\033[48;2;{c.r};{c.g};{c.b}m";
}

"""Repeat c n times; empty string for n <= 0."""
def term_repeat(c: str, n: int) -> str {
    # n <= 0 guard is load-bearing: negative repeat counts corrupt the heap on na.
    if n <= 0 {
        return "";
    }
    return c * n;
}

"""n spaces of padding (safe for n <= 0)."""
def term_spaces(n: int) -> str {
    return term_repeat(" ", n);
}

"""Horizontal rule of n box-drawing dashes (safe for n <= 0)."""
def term_dashes(n: int) -> str {
    return term_repeat("─", n);
}

"""Compose a full SGR: reset, attr bits, then 24-bit fg and bg colors.

attrs is a bitmask — 1 bold (;1), 2 dim (;2), 4 italic (;3) — whose named
forms (TH_BOLD etc.) live in theme.na.jac. The bit values stay literal
here: theme calls this from its own glob initializers, so this body must
stay glob-free (same na init-order hazard as ansi_reset).
"""
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
