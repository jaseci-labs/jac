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

    static def from_loc(loc: CodeLocInfo) -> Span;
    static def make(
        mod_path: str,
        code: str,
        lines: tuple[int, int],
        cols: tuple[int, int],
        poss: tuple[int, int]
    ) -> Span;

    static def _capture_window(
        code: str, first_line: int, pos_start: int
    ) -> tuple[str, int, int];

    def __str__ -> str;
}

obj CodeLocInfo {
    has first_tok: Token,
        last_tok: Token;

    static has __slots__: tuple[str, ...] = ("first_tok", "last_tok");
    has orig_src: Source { getter; }
    has mod_path: str { getter; }
    has first_line: int { getter; }
    has last_line: int { getter; }
    has col_start: int { getter; }
    has col_end: int { getter; }
    has pos_start: int { getter; }
    has pos_end: int { getter; }

    def update_token_range(first_tok: Token, last_tok: Token);
    def __str__ -> str;
    def span -> Span;
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
