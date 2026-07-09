"""Damage-tracked frame painter.

Repaints the whole screen when the terminal width changes (every row
reflows), otherwise rewrites only the contiguous row range that differs
from the previously painted frame. Every paint is bracketed in the
terminal's synchronized-update escapes (?2026) so partial frames never
flash. When no tty fd is available (fd < 0) the bytes are captured in a
PaintBuf instead of written."""

import from .libc_tty { tty_write }
import from .terminal {
    ANSI_CLEAR_LINE,
    ANSI_CLEAR_SCREEN,
    ANSI_RESET,
    ansi_move,
    term_sync_start,
    term_sync_end
}
# TH_SGR_BG bytes are frozen ("\033[48;2;18;18;28m") — the paint prelude below
# must emit exactly them.
import from .theme { TH_SGR_BG }

glob _NO_CHANGE: int = -1;

"""Captures paint bytes when no tty fd is available (the fd < 0 sink)."""
obj PaintBuf {
    has parts: list[str] = [];

    def append(s: str) {
        self.parts.append(s);
    }

    """Return everything buffered so far and reset to empty."""
    def take -> str {
        buffered: str = "".join(self.parts);
        self.parts = [];
        return buffered;
    }
}

"""Drain a PaintBuf; free-function form for callers holding only the buf."""
def diff_take_buf(paint_buf: PaintBuf) -> str {
    return paint_buf.take();
}

"""Route paint bytes: fd >= 0 writes to the tty, otherwise buffers."""
def _emit(fd: int, text: str, paint_buf: PaintBuf) {
    if fd < 0 {
        paint_buf.append(text);
        return;
    }
    tty_write(fd, text);
}

"""Open a synchronized-update bracket on real ttys, then emit the prelude."""
def _begin_frame(fd: int, prelude: str, paint_buf: PaintBuf) {
    if fd >= 0 {
        term_sync_start(fd);
    }
    _emit(fd, prelude, paint_buf);
}

"""Reset colors, then close the synchronized-update bracket on real ttys."""
def _end_frame(fd: int, paint_buf: PaintBuf) {
    _emit(fd, ANSI_RESET, paint_buf);
    if fd >= 0 {
        term_sync_end(fd);
    }
}

"""Repaint the entire screen: clear, then all rows joined by CRLF."""
def _full_paint(lines: list[str], fd: int, paint_buf: PaintBuf) {
    _begin_frame(fd, TH_SGR_BG + ANSI_CLEAR_SCREEN, paint_buf);
    _emit(fd, "\r\n".join(lines), paint_buf);
    _end_frame(fd, paint_buf);
}

"""Rewrite rows first..last inclusive: move, clear, repaint each row
(rows past the end of the new frame are left cleared)."""
def _diff_paint(lines: list[str], first: int, last: int, fd: int, paint_buf: PaintBuf) {
    _begin_frame(fd, TH_SGR_BG, paint_buf);
    row_count = len(lines);
    for row in range(first, last + 1) {
        _emit(fd, ansi_move(0, row) + ANSI_CLEAR_LINE, paint_buf);
        if row < row_count {
            _emit(fd, lines[row], paint_buf);
        }
    }
    _end_frame(fd, paint_buf);
}

"""Frame differ: remembers the last painted frame and repaints only the
changed row range. A width change (or invalidate) forces a full repaint.
NOTE: callers hand over `lines` by reference — screen_render must return
a fresh list every call so prev_lines never aliases a mutated frame."""
obj DiffEngine {
    has prev_lines: list[str] = [],
        prev_width: int = 0;

    """Forget the previous frame so the next paint repaints everything."""
    def invalidate {
        self.prev_lines = [];
    }

    """Return (first, last) rows differing from the previous frame, or
    (_NO_CHANGE, _NO_CHANGE) when the frames are identical."""
    def _changed_range(lines: list[str]) -> tuple[int, int] {
        new_count = len(lines);
        prev_count = len(self.prev_lines);
        row_total = max(new_count, prev_count);
        first_changed: int = _NO_CHANGE;
        last_changed: int = _NO_CHANGE;
        for row in range(row_total) {
            old_line: str = self.prev_lines[row] if row < prev_count else "";
            new_line: str = lines[row] if row < new_count else "";
            if old_line != new_line {
                if first_changed == _NO_CHANGE {
                    first_changed = row;
                }
                last_changed = row;
            }
        }
        return (first_changed, last_changed);
    }

    """Paint `lines` to fd (or into paint_buf when fd < 0), minimally."""
    def paint(lines: list[str], width: int, fd: int, paint_buf: PaintBuf) {
        if width != self.prev_width or not self.prev_lines {
            _full_paint(lines, fd, paint_buf);
            self.prev_lines = lines;
            self.prev_width = width;
            return;
        }

        (first_changed, last_changed) = self._changed_range(lines);
        if first_changed != _NO_CHANGE {
            _diff_paint(lines, first_changed, last_changed, fd, paint_buf);
        }
        self.prev_lines = lines;
    }
}
