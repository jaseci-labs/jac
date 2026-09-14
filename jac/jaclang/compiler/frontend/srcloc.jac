import type from jaclang.compiler.frontend.unitree { Source, Token }

import from jaclang.project.span { Span }

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
        return Span.make(
            self.mod_path,
            self.orig_src.code,
            (self.first_line, self.last_line),
            (self.col_start, self.col_end),
            (self.pos_start, self.pos_end)
        );
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
