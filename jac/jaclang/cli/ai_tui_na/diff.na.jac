"""Differential ANSI renderer — pi-tui doRender ported to Jac NA.

paint(lines, width, fd):
  - Full redraw when width changes or on first render.
  - Otherwise: find first/last changed row, move cursor via absolute
    addressing (ESC[row;1H), clear the line, write new content.

Row strings must contain ANSI SGR codes only — no cursor-move sequences.
The diff engine owns all cursor movement.
"""

import from .libc_tty { tty_write }
import from .terminal { term_sync_start, term_sync_end }

# Background fill used when clearing lines so erased areas match the TUI bg.
glob _BG: str = "\033[48;2;18;18;28m",
     _RESET: str = "\033[0m";

# Headless render sink (Decision C, plan §15-C): when paint() is called with
# fd < 0 the byte stream is appended here instead of written to a tty, so the
# in-process host can render into memory for tests (tui_render_buf) with no TTY.
# Must be an `obj` glob with a string FIELD -- a bare scalar glob would not
# persist writes across :pub calls in NA codegen (jaseci-labs/jaseci#6816).
obj PaintBuf {
    has text: str = "";

    def append(s: str) {
        self.text = self.text + s;
    }

    def take -> str {
        t = self.text;
        self.text = "";
        return t;
    }
}

glob _paint_buf: PaintBuf = PaintBuf();

# Read and clear the headless paint buffer (the bytes produced by the last
# paint(..., fd=-1)). Returns "" when nothing was buffered.
def diff_take_buf -> str {
    return _paint_buf.take();
}

# Single write sink: real tty fd, or the in-memory buffer when fd < 0.
def _emit(fd: int, text: str) {
    if fd < 0 {
        _paint_buf.append(text);
        return;
    }
    tty_write(fd, text);
}

def _abs_move(row: int) -> str {
    r: int = row + 1;
    return f"\033[{r};1H";
}

def _full_paint(lines: list[str], fd: int) {
    if fd >= 0 {
        term_sync_start(fd);
    }
    # Clear full screen with TUI background, then home cursor.
    _emit(fd, _BG + "\033[2J\033[H");
    i: int = 0;
    n = len(lines);
    while i < n {
        if i > 0 {
            _emit(fd, "\r\n");
        }
        _emit(fd, lines[i]);
        i = i + 1;
    }
    _emit(fd, _RESET);
    if fd >= 0 {
        term_sync_end(fd);
    }
}

def _diff_paint(lines: list[str], first: int, last: int, fd: int) {
    if fd >= 0 {
        term_sync_start(fd);
    }
    # Set background so \033[2K fills with TUI bg color.
    _emit(fd, _BG);
    i: int = first;
    nl = len(lines);
    while i <= last {
        # Move to absolute row, clear entire line, write new content.
        _emit(fd, _abs_move(i) + "\033[2K");
        if i < nl {
            _emit(fd, lines[i]);
        }
        i = i + 1;
    }
    _emit(fd, _RESET);
    if fd >= 0 {
        term_sync_end(fd);
    }
}

obj DiffEngine {
    has prev_lines: list[str] = [],
        prev_width: int = 0;

    def invalidate {
        # Force a full redraw on the next paint call.
        self.prev_lines = [];
    }

    def paint(lines: list[str], width: int, fd: int) {
        # Full render when width changed (wrapping shifts all rows) or first frame.
        if width != self.prev_width or len(self.prev_lines) == 0 {
            _full_paint(lines, fd);
            self.prev_lines = lines;
            self.prev_width = width;
            return;
        }

        # Find the first and last changed row by string comparison.
        first_changed: int = -1;
        last_changed: int = -1;
        nl = len(lines);
        pl = len(self.prev_lines);
        max_l: int = nl;
        if pl > max_l {
            max_l = pl;
        }

        i: int = 0;
        while i < max_l {
            old_line: str = "";
            new_line: str = "";
            if i < pl {
                old_line = self.prev_lines[i];
            }
            if i < nl {
                new_line = lines[i];
            }
            if old_line != new_line {
                if first_changed < 0 {
                    first_changed = i;
                }
                last_changed = i;
            }
            i = i + 1;
        }

        if first_changed >= 0 {
            _diff_paint(lines, first_changed, last_changed, fd);
        }

        # Cache current frame for next comparison.
        self.prev_lines = lines;
    }
}
