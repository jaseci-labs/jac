import type from jaclang.jac0core.unitree { Source, Token }

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

    def update_first_token(first_tok: Token) {
        self.first_tok = first_tok;
    }

    def update_last_token(last_tok: Token) {
        self.last_tok = last_tok;
    }

    def __str__ -> str {
        return f"{self.first_line}:{self.col_start} - {self.last_line}:{self.col_end}";
    }

    def snapshot -> CodeLocInfo;
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

impl CodeLocInfo.snapshot -> CodeLocInfo {
    import from jaclang.jac0core.unitree { Token }

    ft = self.first_tok;
    lt = self.last_tok;
    new_ft = Token(
        ft.orig_src,
        ft.name,
        ft.value,
        ft.line_no,
        ft.end_line,
        ft.c_start,
        ft.c_end,
        ft.pos_start,
        ft.pos_end
    );
    new_lt = Token(
        lt.orig_src,
        lt.name,
        lt.value,
        lt.line_no,
        lt.end_line,
        lt.c_start,
        lt.c_end,
        lt.pos_start,
        lt.pos_end
    );
    new_ft._is_synthetic = True;
    new_lt._is_synthetic = True;
    return CodeLocInfo(new_ft, new_lt);
}
