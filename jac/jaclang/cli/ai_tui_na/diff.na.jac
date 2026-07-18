import from .libc_tty { tty_write }
import from .terminal {
    ANSI_CLEAR_LINE,
    ANSI_CLEAR_SCREEN,
    ANSI_RESET,
    ansi_move,
    term_sync_start,
    term_sync_end
}

import from .theme { TH_SGR_BG }

glob _NO_CHANGE: int = -1;

obj PaintBuf {
    has parts: list[str] = [];

    def append(s: str) {
        self.parts.append(s);
    }
}

def _emit(fd: int, text: str, paint_buf: PaintBuf) {
    if fd < 0 {
        paint_buf.append(text);
        return;
    }
    tty_write(fd, text);
}

def _begin_frame(fd: int, prelude: str, paint_buf: PaintBuf) {
    if fd >= 0 {
        term_sync_start(fd);
    }
    _emit(fd, prelude, paint_buf);
}

def _end_frame(fd: int, paint_buf: PaintBuf) {
    _emit(fd, ANSI_RESET, paint_buf);
    if fd >= 0 {
        term_sync_end(fd);
    }
}

def _full_paint(lines: list[str], fd: int, paint_buf: PaintBuf) {
    _begin_frame(fd, TH_SGR_BG + ANSI_CLEAR_SCREEN, paint_buf);
    _emit(fd, "\r\n".join(lines), paint_buf);
    _end_frame(fd, paint_buf);
}

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

obj DiffEngine {
    has prev_lines: list[str] = [],
        prev_width: int = 0;

    def invalidate {
        self.prev_lines = [];
    }

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
