obj Span {
    has mod_path: str = '',
        first_line: int = 0,
        last_line: int = 0,
        col_start: int = 0,
        col_end: int = 0,
        pos_start: int = 0,
        pos_end: int = 0,
        src_window: str = '',
        window_offset: int = 0,
        window_line: int = 0;

    static def make(
        mod_path: str,
        code: str,
        lines: tuple[int, int],
        cols: tuple[int, int],
        poss: tuple[int, int]
    ) -> Span {
        (win, win_off, win_line) = Span._capture_window(code, lines[0], poss[0]);
        return Span(
            mod_path=mod_path,
            first_line=lines[0],
            last_line=lines[1],
            col_start=cols[0],
            col_end=cols[1],
            pos_start=poss[0],
            pos_end=poss[1],
            src_window=win,
            window_offset=win_off,
            window_line=win_line
        );
    }

    static def _capture_window(
        code: str, first_line: int, pos_start: int
    ) -> tuple[str, int, int] {
        if code == '' {
            return ('', 0, 0);
        }
        fb = code.encode("utf-8");
        flen = len(fb);
        NL = 10;
        start_line = first_line - 2;
        if start_line < 1 {
            start_line = 1;
        }
        idx = pos_start;
        if idx > flen {
            idx = flen;
        }
        curr_line = first_line;
        while idx >= 0 and curr_line >= start_line {
            idx -= 1;
            if idx < 0 {
                break;
            }
            if fb[idx] == NL {
                curr_line -= 1;
            }
        }
        idx += 1;
        win_start = idx;
        end_line = start_line + 5;
        curr_line = start_line;
        while idx < flen and curr_line < end_line {
            if fb[idx] == NL {
                curr_line += 1;
            }
            idx += 1;
        }
        return (
            fb[win_start:idx].decode("utf-8", errors="replace"),
            win_start,
            start_line
        );
    }

    def __str__ -> str {
        return f"{self.first_line}:{self.col_start} - {self.last_line}:{self.col_end}";
    }
}
