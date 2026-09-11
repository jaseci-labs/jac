import type from jaclang.compiler.ir.schema { Source, Token }

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

    static def from_loc(loc: CodeLocInfo) -> Span {
        code = loc.orig_src.code;
        (win, win_off, win_line) = Span._capture_window(
            code, loc.first_line, loc.pos_start
        );
        return Span(
            mod_path=loc.mod_path,
            first_line=loc.first_line,
            last_line=loc.last_line,
            col_start=loc.col_start,
            col_end=loc.col_end,
            pos_start=loc.pos_start,
            pos_end=loc.pos_end,
            src_window=win,
            window_offset=win_off,
            window_line=win_line
        );
    }

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

obj CodeLocInfo {
    has first_tok: Token,
        last_tok: Token;

    has orig_src: Source { getter; }
    has mod_path: str { getter; }
    has first_line: int { getter; }
    has last_line: int { getter; }
    has col_start: int { getter; }
    has col_end: int { getter; }
    has pos_start: int { getter; }
    has pos_end: int { getter; }

    def update_token_range(first_tok: Token, last_tok: Token) {
        self.first_tok = first_tok;
        self.last_tok = last_tok;
    }

    def __str__ -> str {
        return f"{self.first_line}:{self.col_start} - {self.last_line}:{self.col_end}";
    }

    def span -> Span {
        return Span.from_loc(self);
    }
}

impl CodeLocInfo.orig_src.getter -> Source {
    return self.first_tok.orig_src;
}

impl CodeLocInfo.mod_path.getter -> str {
    return self.first_tok.orig_src.file_path;
}

impl CodeLocInfo.first_line.getter -> int {
    return self.first_tok.line_no;
}

impl CodeLocInfo.last_line.getter -> int {
    return self.last_tok.end_line;
}

impl CodeLocInfo.col_start.getter -> int {
    return self.first_tok.c_start;
}

impl CodeLocInfo.col_end.getter -> int {
    return self.last_tok.c_end;
}

impl CodeLocInfo.pos_start.getter -> int {
    return self.first_tok.pos_start;
}

impl CodeLocInfo.pos_end.getter -> int {
    return self.last_tok.pos_end;
}
