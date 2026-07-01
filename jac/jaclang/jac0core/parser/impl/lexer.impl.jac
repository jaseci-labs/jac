impl Lexer.push_mode(mode: LexerMode) {
    self.mode_stack.append(mode);
}

impl Lexer.pop_mode -> LexerMode | None {
    if len(self.mode_stack) > 0 {
        return self.mode_stack.pop();
    }
    return None;
}

impl Lexer.current_mode -> LexerMode {
    if len(self.mode_stack) > 0 {
        return self.mode_stack[-1];
    }
    return LexerMode.NORMAL;
}

impl Lexer.in_jsx -> bool {
    mode = self.current_mode();
    return mode in [LexerMode.JSX_TAG, LexerMode.JSX_CONTENT];
}

impl Lexer.in_view_body -> bool {
    return len(self._view_body_depths) > 0;
}

impl Lexer._track_view_context(tok: Token) {
    k = tok.kind;
    if k == TokenKind.LPAREN {
        self._paren_depth += 1;
    } elif k == TokenKind.RPAREN {
        if self._paren_depth > 0 {
            self._paren_depth -= 1;
        }
    } elif k == TokenKind.LSQUARE {
        self._bracket_depth += 1;
    } elif k == TokenKind.RSQUARE {
        if self._bracket_depth > 0 {
            self._bracket_depth -= 1;
        }
    } elif k == TokenKind.LBRACE {
        self._brace_depth += 1;
    } elif k == TokenKind.RBRACE {
        if len(self._view_body_depths) > 0
        and self._brace_depth == self._view_body_depths[-1] {
            self._view_body_depths.pop();
        }
        if self._brace_depth > 0 {
            self._brace_depth -= 1;
        }
    }
}

impl Lexer.prev_is_value -> bool {
    return self.prev_token_kind in [
        TokenKind.NAME,
        TokenKind.KWESC_NAME,
        TokenKind.INT,
        TokenKind.FLOAT,
        TokenKind.HEX,
        TokenKind.BIN,
        TokenKind.OCT,
        TokenKind.STRING,
        TokenKind.BOOL,
        TokenKind.NULL,
        TokenKind.ELLIPSIS,
        TokenKind.RPAREN,
        TokenKind.RSQUARE,
        TokenKind.RBRACE,
        TokenKind.KW_SELF,
        TokenKind.KW_SUPER,
        TokenKind.KW_HERE,
        TokenKind.KW_ROOT,
        TokenKind.F_DQ_END,
        TokenKind.F_SQ_END,
        TokenKind.F_TDQ_END,
        TokenKind.F_TSQ_END,
        TokenKind.JSX_SELF_CLOSE,
        TokenKind.JSX_TAG_END,
        TokenKind.JSX_FRAG_CLOSE
    ];
}

impl Lexer._width_of(lead: int) -> int {
    if lead < 0x80 {
        return 1;
    }
    if lead < 0xE0 {
        return 2;
    }
    if lead < 0xF0 {
        return 3;
    }
    return 4;
}

impl Lexer._rune_width(byte_idx: int) -> int {
    return self._width_of(int.from_bytes(self._enc[byte_idx:byte_idx + 1], "big"));
}

impl Lexer._char_at(byte_idx: int) -> str {
    if byte_idx < 0 or byte_idx >= self._source_len {
        return "";
    }
    if self._ascii {
        return self.source[byte_idx];
    }
    one = self._enc[byte_idx:byte_idx + 1];
    lead = int.from_bytes(one, "big");
    if lead < 0x80 {
        return one.decode("utf-8");
    }
    if lead < 0xC0 {
        return "";
    }
    w = self._width_of(lead);
    return self._enc[byte_idx:byte_idx + w].decode("utf-8", errors="replace");
}

impl Lexer._slice(a: int, c: int) -> str {
    if self._ascii {
        return self.source[a:c];
    }
    return self._enc[a:c].decode("utf-8");
}

impl Lexer.current -> str {
    if self.pos >= self._source_len {
        return "";
    }
    if self._ascii {
        return self.source[self.pos];
    }
    return self._char_at(self.pos);
}

impl Lexer.peek(offset: int = 1) -> str {
    if self._ascii {
        idx = self.pos + offset;
        if idx >= self._source_len {
            return "";
        }
        return self.source[idx];
    }

    bi = self.pos;
    k = 0;
    while k < offset and bi < self._source_len {
        bi += self._rune_width(bi);
        k += 1;
    }
    return self._char_at(bi);
}

impl Lexer.advance -> str {
    if self._ascii {
        ch = self.current();
        if ch == "\n" {
            self.line += 1;
            self.col = 1;
        } else {
            self.col += 1;
        }
        self.pos += 1;
        return ch;
    }

    if self.pos >= self._source_len {
        return "";
    }
    one = self._enc[self.pos:self.pos + 1];
    lead = int.from_bytes(one, "big");
    if lead < 0x80 {
        ch = one.decode("utf-8");
        w = 1;
    } else {
        w = self._width_of(lead);
        ch = self._enc[self.pos:self.pos + w].decode("utf-8", errors="replace");
    }
    if ch == "\n" {
        self.line += 1;
        self.col = 1;
    } else {
        self.col += 1;
    }
    self.pos += w;
    return ch;
}

impl Lexer.at_end -> bool {
    return self.pos >= self._source_len;
}

impl Lexer.match_char(expected: str) -> bool {
    if self.current() == expected {
        self.advance();
        return True;
    }
    return False;
}

impl Lexer.match_string(expected: str) -> bool {
    if self._ascii {
        if self.source[self.pos:self.pos + len(expected)] == expected {
            for _ in range(len(expected)) {
                self.advance();
            }
            return True;
        }
        return False;
    }

    exp = expected.encode("utf-8");
    exp_bytes = len(exp);
    if self.pos + exp_bytes <= self._source_len
    and self._enc[self.pos:self.pos + exp_bytes] == exp {
        for _ in range(len(expected)) {
            self.advance();
        }
        return True;
    }
    return False;
}

impl Lexer.make_loc(start_line: int, start_col: int, start_pos: int) -> SourceLoc {
    return SourceLoc(
        file_path=self.file_path,
        line=start_line,
        end_line=self.line,
        col_start=start_col,
        col_end=self.col,
        pos_start=start_pos,
        pos_end=self.pos
    );
}

impl Lexer.make_token(
    kind: TokenKind, value: str, start_line: int, start_col: int, start_pos: int
) -> Token {
    return Token(
        kind=kind, value=value, loc=self.make_loc(start_line, start_col, start_pos)
    );
}

impl Lexer.error(
    message: str, start_line: int, start_col: int, start_pos: int, code_str: str = ""
) {
    self.error_count += 1;
    self.diags.append(
        LexDiag(
            message=message,
            code_str=code_str,
            loc=self.make_loc(start_line, start_col, start_pos),
            is_error=True
        )
    );
}

impl Lexer.warning(
    message: str, start_line: int, start_col: int, start_pos: int, code_str: str = ""
) {
    self.diags.append(
        LexDiag(
            message=message,
            code_str=code_str,
            loc=self.make_loc(start_line, start_col, start_pos),
            is_error=False
        )
    );
}

impl Lexer.is_digit(ch: str) -> bool {
    return ch >= "0" and ch <= "9";
}

impl Lexer.is_hex_digit(ch: str) -> bool {
    return self.is_digit(ch) or (ch >= "a" and ch <= "f") or (ch >= "A" and ch <= "F");
}

impl Lexer.is_alpha(ch: str) -> bool {
    return (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or ch == "_";
}

impl Lexer.is_alnum(ch: str) -> bool {
    return self.is_alpha(ch) or self.is_digit(ch);
}

impl Lexer.is_whitespace(ch: str) -> bool {
    return ch == " " or ch == "\t" or ch == "\r" or ch == "\n";
}

impl Lexer.skip_whitespace{
    while not self.at_end() and self.is_whitespace(self.current()) {
        self.advance();
    }
}

impl Lexer.skip_line_comment{
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    while not self.at_end() and self.current() != "\n" {
        self.advance();
    }
    comment_text = self._slice(start_pos, self.pos);
    self.comments.append(
        CommentData(
            value=comment_text,
            line=start_line,
            end_line=start_line,
            col_start=start_col,
            col_end=self.col,
            pos_start=start_pos,
            pos_end=self.pos,
            is_block=False
        )
    );
}

impl Lexer.skip_block_comment -> bool {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;

    self.advance();
    self.advance();
    while not self.at_end() {
        if self.current() == "*" and self.peek() == "#" {
            self.advance();
            self.advance();
            comment_text = self._slice(start_pos, self.pos);
            self.comments.append(
                CommentData(
                    value=comment_text,
                    line=start_line,
                    end_line=self.line,
                    col_start=start_col,
                    col_end=self.col,
                    pos_start=start_pos,
                    pos_end=self.pos,
                    is_block=True
                )
            );
            return True;
        }
        self.advance();
    }
    self.error(
        "Unterminated block comment", start_line, start_col, start_pos, code_str="E0101"
    );
    return False;
}

impl Lexer.skip_whitespace_and_comments{
    while not self.at_end() {
        ch = self.current();

        if self.is_whitespace(ch) {
            self.skip_whitespace();
        } elif ch == "#" {
            if self.peek() == "*" {
                self.skip_block_comment();
            } else {
                self.skip_line_comment();
            }
        } else {
            break;
        }
    }
}

impl Lexer.scan_identifier -> Token {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    value = "";
    while not self.at_end() and self.is_alnum(self.current()) {
        value += self.advance();
    }

    if value == "not" {
        saved_pos = self.pos;
        saved_line = self.line;
        saved_col = self.col;

        while not self.at_end() and (self.current() == " " or self.current() == "\t") {
            self.advance();
        }

        if not self.at_end() and self.current() == "i" {
            if self._slice(self.pos, self.pos + 2) == "in"
            and (
                self.pos + 2 >= self._source_len
                or not self.is_alnum(self._char_at(self.pos + 2))
            ) {
                self.advance();
                self.advance();
                return self.make_token(
                    TokenKind.KW_NIN, "not in", start_line, start_col, start_pos
                );
            }
        }

        self.pos = saved_pos;
        self.line = saved_line;
        self.col = saved_col;
    }
    if value == "is" {
        saved_pos = self.pos;
        saved_line = self.line;
        saved_col = self.col;

        while not self.at_end() and (self.current() == " " or self.current() == "\t") {
            self.advance();
        }

        if not self.at_end() and self.current() == "n" {
            if self._slice(self.pos, self.pos + 3) == "not"
            and (
                self.pos + 3 >= self._source_len
                or not self.is_alnum(self._char_at(self.pos + 3))
            ) {
                self.advance();
                self.advance();
                self.advance();
                return self.make_token(
                    TokenKind.KW_ISN, "is not", start_line, start_col, start_pos
                );
            }
        }

        self.pos = saved_pos;
        self.line = saved_line;
        self.col = saved_col;
    }

    kind = lookup_keyword(value);
    if kind is not None {
        return self.make_token(kind, value, start_line, start_col, start_pos);
    }
    return self.make_token(TokenKind.NAME, value, start_line, start_col, start_pos);
}

impl Lexer.scan_kwesc_name -> Token {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;

    self.advance();
    value = "`";
    while not self.at_end() and self.is_alnum(self.current()) {
        value += self.advance();
    }
    return self.make_token(
        TokenKind.KWESC_NAME, value, start_line, start_col, start_pos
    );
}

impl Lexer.scan_number -> Token {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    value = "";
    kind = TokenKind.INT;

    if self.current() == "0" {
        value += self.advance();
        if self.current() == "x" or self.current() == "X" {
            value += self.advance();
            kind = TokenKind.HEX;
            while not self.at_end()
            and (self.is_hex_digit(self.current()) or self.current() == "_") {
                value += self.advance();
            }
            return self.make_token(kind, value, start_line, start_col, start_pos);
        } elif self.current() == "b" or self.current() == "B" {
            value += self.advance();
            kind = TokenKind.BIN;
            while not self.at_end()
            and (
                self.current() == "0" or self.current() == "1" or self.current() == "_"
            ) {
                value += self.advance();
            }
            return self.make_token(kind, value, start_line, start_col, start_pos);
        } elif self.current() == "o" or self.current() == "O" {
            value += self.advance();
            kind = TokenKind.OCT;
            while not self.at_end()
            and (
                self.current() >= "0" and self.current() <= "7" or self.current() == "_"
            ) {
                value += self.advance();
            }
            return self.make_token(kind, value, start_line, start_col, start_pos);
        }
    }

    while not self.at_end()
    and (self.is_digit(self.current()) or self.current() == "_") {
        value += self.advance();
    }

    if self.current() == "." and self.is_digit(self.peek()) {
        kind = TokenKind.FLOAT;
        value += self.advance();
        while not self.at_end()
        and (self.is_digit(self.current()) or self.current() == "_") {
            value += self.advance();
        }
    }

    if self.current() == "e" or self.current() == "E" {
        kind = TokenKind.FLOAT;
        value += self.advance();
        if self.current() == "+" or self.current() == "-" {
            value += self.advance();
        }
        while not self.at_end()
        and (self.is_digit(self.current()) or self.current() == "_") {
            value += self.advance();
        }
    }
    return self.make_token(kind, value, start_line, start_col, start_pos);
}

impl Lexer.scan_leading_dot_float -> Token {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    value = self.advance();
    while not self.at_end()
    and (self.is_digit(self.current()) or self.current() == "_") {
        value += self.advance();
    }

    if not self.at_end() and (self.current() == "e" or self.current() == "E") {
        value += self.advance();
        if not self.at_end() and (self.current() == "+" or self.current() == "-") {
            value += self.advance();
        }
        while not self.at_end()
        and (self.is_digit(self.current()) or self.current() == "_") {
            value += self.advance();
        }
    }
    return self.make_token(TokenKind.FLOAT, value, start_line, start_col, start_pos);
}

impl Lexer.scan_string(quote: str) -> Token {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    value = "";

    prefix = "";
    pp = start_pos - 1;
    while pp >= 0 and self.is_alnum(self._char_at(pp)) {
        prefix = self._char_at(pp) + prefix;
        pp -= 1;
    }
    is_raw = prefix.lower() in ["r", "rb", "br"];
    triple = False;

    if self.peek() == quote and self.peek(2) == quote {
        triple = True;
        value += self.advance();
        value += self.advance();
        value += self.advance();
    } else {
        value += self.advance();
    }
    while not self.at_end() {
        ch = self.current();

        if triple {
            if ch == quote and self.peek() == quote and self.peek(2) == quote {
                value += self.advance();
                value += self.advance();
                value += self.advance();
                return self.make_token(
                    TokenKind.STRING, value, start_line, start_col, start_pos
                );
            }
        } else {
            if ch == quote {
                value += self.advance();
                return self.make_token(
                    TokenKind.STRING, value, start_line, start_col, start_pos
                );
            }
            if ch == "\n" {
                self.error(
                    "Unterminated string literal",
                    start_line,
                    start_col,
                    start_pos,
                    code_str="E0100"
                );
                return self.make_token(
                    TokenKind.ERROR, value, start_line, start_col, start_pos
                );
            }
        }

        if ch == "\\" {
            esc_line = self.line;
            esc_col = self.col;
            esc_pos = self.pos;
            value += self.advance();
            if not self.at_end() {
                esc = self.current();
                value += self.advance();

                if (
                    not is_raw
                    and esc not in "nrtbfva01234567xNuU"
                    and esc != "\\"
                    and esc != "\""
                    and esc != "'"
                    and esc != "\n"
                    and esc != "\r"
                ) {
                    self.warning(
                        f"Invalid escape sequence '\\{esc}'",
                        esc_line,
                        esc_col,
                        esc_pos,
                        code_str="W0100"
                    );
                }
            }
        } else {
            value += self.advance();
        }
    }
    self.error(
        "Unterminated string literal",
        start_line,
        start_col,
        start_pos,
        code_str="E0100"
    );
    return self.make_token(TokenKind.ERROR, value, start_line, start_col, start_pos);
}

impl Lexer.scan_fstring(prefix: str) -> Token {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    value = prefix;

    quote = self.current();
    triple = self.peek() == quote and self.peek(2) == quote;
    if triple {
        value += self.advance();
        value += self.advance();
        value += self.advance();
        if quote == "\"" {
            self.push_mode(LexerMode.FSTRING_TDQ);
            if prefix == "f" {
                return self.make_token(
                    TokenKind.F_TDQ_START, value, start_line, start_col, start_pos
                );
            } else {
                return self.make_token(
                    TokenKind.RF_TDQ_START, value, start_line, start_col, start_pos
                );
            }
        } else {
            self.push_mode(LexerMode.FSTRING_TSQ);
            if prefix == "f" {
                return self.make_token(
                    TokenKind.F_TSQ_START, value, start_line, start_col, start_pos
                );
            } else {
                return self.make_token(
                    TokenKind.RF_TSQ_START, value, start_line, start_col, start_pos
                );
            }
        }
    } else {
        value += self.advance();
        if quote == "\"" {
            self.push_mode(LexerMode.FSTRING_DQ);
            if prefix == "f" {
                return self.make_token(
                    TokenKind.F_DQ_START, value, start_line, start_col, start_pos
                );
            } else {
                return self.make_token(
                    TokenKind.RF_DQ_START, value, start_line, start_col, start_pos
                );
            }
        } else {
            self.push_mode(LexerMode.FSTRING_SQ);
            if prefix == "f" {
                return self.make_token(
                    TokenKind.F_SQ_START, value, start_line, start_col, start_pos
                );
            } else {
                return self.make_token(
                    TokenKind.RF_SQ_START, value, start_line, start_col, start_pos
                );
            }
        }
    }
}

impl Lexer.scan_fstring_content -> Token {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    mode = self.current_mode();
    is_triple = mode in [LexerMode.FSTRING_TDQ, LexerMode.FSTRING_TSQ];
    quote = "\"" if mode in [LexerMode.FSTRING_DQ, LexerMode.FSTRING_TDQ] else "'";
    value = "";
    while not self.at_end() {
        ch = self.current();

        if is_triple {
            if ch == quote and self.peek() == quote and self.peek(2) == quote {
                if len(value) > 0 {
                    text_kind = self.get_fstring_text_kind(mode);
                    return self.make_token(
                        text_kind, value, start_line, start_col, start_pos
                    );
                }

                self.advance();
                self.advance();
                self.advance();
                self.pop_mode();
                end_kind = self.get_fstring_end_kind(mode);
                triple_quote = f"{quote}{quote}{quote}";
                return self.make_token(
                    end_kind, triple_quote, start_line, start_col, start_pos
                );
            }
        } else {
            if ch == quote {
                if len(value) > 0 {
                    text_kind = self.get_fstring_text_kind(mode);
                    return self.make_token(
                        text_kind, value, start_line, start_col, start_pos
                    );
                }
                self.advance();
                self.pop_mode();
                end_kind = self.get_fstring_end_kind(mode);
                return self.make_token(
                    end_kind, quote, start_line, start_col, start_pos
                );
            }
            if ch == "\n" {
                self.error(
                    "Unterminated f-string",
                    start_line,
                    start_col,
                    start_pos,
                    code_str="E0102"
                );
                return self.make_token(
                    TokenKind.ERROR, value, start_line, start_col, start_pos
                );
            }
        }

        if ch == "{" and self.peek() == "{" {
            if len(value) > 0 {
                text_kind = self.get_fstring_text_kind(mode);
                return self.make_token(
                    text_kind, value, start_line, start_col, start_pos
                );
            }
            self.advance();
            self.advance();
            return self.make_token(
                TokenKind.D_LBRACE, "{{", start_line, start_col, start_pos
            );
        }
        if ch == "}" and self.peek() == "}" {
            if len(value) > 0 {
                text_kind = self.get_fstring_text_kind(mode);
                return self.make_token(
                    text_kind, value, start_line, start_col, start_pos
                );
            }
            self.advance();
            self.advance();
            return self.make_token(
                TokenKind.D_RBRACE, "}}", start_line, start_col, start_pos
            );
        }

        if ch == "{" {
            if len(value) > 0 {
                text_kind = self.get_fstring_text_kind(mode);
                return self.make_token(
                    text_kind, value, start_line, start_col, start_pos
                );
            }
            self.advance();
            self.push_mode(LexerMode.FSTRING_EXPR);
            self.fstring_brace_depth_stack.append(self.fstring_brace_depth);
            self.fstring_brace_depth = 1;
            return self.make_token(
                TokenKind.LBRACE, "{", start_line, start_col, start_pos
            );
        }

        if ch == "\\" {
            value += self.advance();
            if not self.at_end() {
                value += self.advance();
            }
        } else {
            value += self.advance();
        }
    }
    self.error(
        "Unterminated f-string", start_line, start_col, start_pos, code_str="E0102"
    );
    return self.make_token(TokenKind.ERROR, value, start_line, start_col, start_pos);
}

impl Lexer.get_fstring_text_kind(mode: LexerMode) -> TokenKind {
    switch mode {
        case LexerMode.FSTRING_DQ:
            return TokenKind.F_TEXT_DQ;

        case LexerMode.FSTRING_SQ:
            return TokenKind.F_TEXT_SQ;

        case LexerMode.FSTRING_TDQ:
            return TokenKind.F_TEXT_TDQ;

        case LexerMode.FSTRING_TSQ:
            return TokenKind.F_TEXT_TSQ;

        default:
            return TokenKind.F_TEXT_DQ;

    }
}

impl Lexer.get_fstring_end_kind(mode: LexerMode) -> TokenKind {
    switch mode {
        case LexerMode.FSTRING_DQ:
            return TokenKind.F_DQ_END;

        case LexerMode.FSTRING_SQ:
            return TokenKind.F_SQ_END;

        case LexerMode.FSTRING_TDQ:
            return TokenKind.F_TDQ_END;

        case LexerMode.FSTRING_TSQ:
            return TokenKind.F_TSQ_END;

        default:
            return TokenKind.F_DQ_END;

    }
}

impl Lexer.scan_fstring_expr_token -> Token {
    self.skip_whitespace_and_comments();
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    ch = self.current();

    if ch == "{" {
        self.fstring_brace_depth += 1;
        self.advance();
        return self.make_token(TokenKind.LBRACE, "{", start_line, start_col, start_pos);
    }
    if ch == "}" {
        self.fstring_brace_depth -= 1;
        self.advance();
        if self.fstring_brace_depth == 0 {
            self.pop_mode();

            if self.fstring_brace_depth_stack {
                self.fstring_brace_depth = self.fstring_brace_depth_stack.pop();
            }
        }
        return self.make_token(TokenKind.RBRACE, "}", start_line, start_col, start_pos);
    }

    if ch == "!" and self.peek() in ["s", "r", "a", "S", "R", "A"] {
        self.advance();
        conv = self.advance();
        return self.make_token(
            TokenKind.CONV, "!" + conv, start_line, start_col, start_pos
        );
    }

    if ch == ":" and self.peek() != "=" {
        self.advance();
        return self.make_token(TokenKind.COLON, ":", start_line, start_col, start_pos);
    }

    return self.scan_regular_token();
}

impl Lexer.scan_jsx_open_start -> Token {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    self.advance();
    self.jsx_depth += 1;
    self.push_mode(LexerMode.JSX_TAG);
    return self.make_token(
        TokenKind.JSX_OPEN_START, "<", start_line, start_col, start_pos
    );
}

impl Lexer.scan_jsx_tag_token -> Token {
    self.skip_whitespace_and_comments();
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    ch = self.current();

    if ch == "/" and self.peek() == ">" {
        self.advance();
        self.advance();
        self.jsx_depth -= 1;
        self.pop_mode();
        return self.make_token(
            TokenKind.JSX_SELF_CLOSE, "/>", start_line, start_col, start_pos
        );
    }

    if ch == ">" {
        self.advance();
        self.pop_mode();
        if self.jsx_closing_tag {
            self.jsx_closing_tag = False;
            self.jsx_depth -= 1;
        } else {
            self.push_mode(LexerMode.JSX_CONTENT);
        }
        return self.make_token(
            TokenKind.JSX_TAG_END, ">", start_line, start_col, start_pos
        );
    }

    if ch == "{" {
        self.advance();
        self.jsx_brace_depth_stack.append(self.jsx_brace_depth);
        self.jsx_brace_depth = 1;
        self.push_mode(LexerMode.NORMAL);
        return self.make_token(TokenKind.LBRACE, "{", start_line, start_col, start_pos);
    }

    if self.is_alpha(ch) {
        value = "";
        while self.is_alnum(self.current())
        or self.current() == "-"
        or self.current() == "_" {
            value += self.advance();
        }
        return self.make_token(
            TokenKind.JSX_NAME, value, start_line, start_col, start_pos
        );
    }

    if ch == "=" {
        self.advance();
        return self.make_token(TokenKind.EQ, "=", start_line, start_col, start_pos);
    }

    if ch == "\"" or ch == "'" {
        return self.scan_string(ch);
    }

    if ch == "." {
        self.advance();
        return self.make_token(TokenKind.DOT, ".", start_line, start_col, start_pos);
    }

    if ch == "@" {
        self.advance();
        return self.make_token(
            TokenKind.DECOR_OP, "@", start_line, start_col, start_pos
        );
    }

    self.error(
        f"Unexpected character in JSX tag: '{ch}'",
        start_line,
        start_col,
        start_pos,
        code_str="E0106"
    );
    self.advance();
    return self.make_token(TokenKind.ERROR, ch, start_line, start_col, start_pos);
}

impl Lexer.scan_jsx_content -> Token {
    if self.at_end() {
        self.error(
            "Unexpected end of JSX content",
            self.line,
            self.col,
            self.pos,
            code_str="E0104"
        );
        return self.make_token(TokenKind.ERROR, "", self.line, self.col, self.pos);
    }
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    ch = self.current();

    if ch == "<" and self.peek() == "/" and self.peek(2) == ">" {
        self.advance();
        self.advance();
        self.advance();
        self.jsx_depth -= 1;
        self.pop_mode();
        return self.make_token(
            TokenKind.JSX_FRAG_CLOSE, "</>", start_line, start_col, start_pos
        );
    }

    if ch == "<" and self.peek() == "/" {
        self.advance();
        self.advance();
        self.pop_mode();
        self.push_mode(LexerMode.JSX_TAG);
        self.jsx_closing_tag = True;
        return self.make_token(
            TokenKind.JSX_CLOSE_START, "</", start_line, start_col, start_pos
        );
    }

    if ch == "<" and (self.is_alpha(self.peek()) or self.peek() == "@") {
        self.advance();
        self.jsx_depth += 1;

        self.push_mode(LexerMode.JSX_TAG);
        return self.make_token(
            TokenKind.JSX_OPEN_START, "<", start_line, start_col, start_pos
        );
    }

    if ch == "<" and self.peek() == ">" {
        self.advance();
        self.advance();
        self.jsx_depth += 1;
        self.push_mode(LexerMode.JSX_CONTENT);
        return self.make_token(
            TokenKind.JSX_FRAG_OPEN, "<>", start_line, start_col, start_pos
        );
    }

    if ch == "{" {
        saved_pos = self.pos;
        saved_line = self.line;
        saved_col = self.col;
        saved_comments_len = len(self.comments);
        self.advance();
        self.skip_whitespace();
        is_comment_slot = False;
        if (not self.at_end() and self.current() == "#" and self.peek() == "*") {
            if self.skip_block_comment() {
                self.skip_whitespace();
                if not self.at_end() and self.current() == "}" {
                    self.advance();
                    is_comment_slot = True;
                }
            }
        }
        if is_comment_slot {
            self.comments = self.comments[:saved_comments_len];
            value = self._slice(start_pos, self.pos);
            return self.make_token(
                TokenKind.JSX_COMMENT, value, start_line, start_col, start_pos
            );
        }

        self.pos = saved_pos;
        self.line = saved_line;
        self.col = saved_col;
        self.comments = self.comments[:saved_comments_len];
        self.advance();
        self.jsx_brace_depth_stack.append(self.jsx_brace_depth);
        self.jsx_brace_depth = 1;
        self.push_mode(LexerMode.NORMAL);

        self._view_body_depths.append(self._brace_depth + 1);
        return self.make_token(TokenKind.LBRACE, "{", start_line, start_col, start_pos);
    }

    value = "";
    while not self.at_end() {
        ch = self.current();
        if ch == "{" {
            break;
        }
        if ch == "<" {
            nxt = self.peek();

            if nxt == "/" or nxt == ">" or nxt == "@" or self.is_alpha(nxt) {
                break;
            }
        }

        value += self.advance();
    }
    if len(value) > 0 {
        return self.make_token(
            TokenKind.JSX_TEXT, value, start_line, start_col, start_pos
        );
    }

    self.error(
        "Unexpected end of JSX content",
        start_line,
        start_col,
        start_pos,
        code_str="E0104"
    );
    return self.make_token(TokenKind.ERROR, "", start_line, start_col, start_pos);
}

impl Lexer.scan_regular_token -> Token {
    self.skip_whitespace_and_comments();
    if self.at_end() {
        return Token(
            kind=TokenKind.EOF,
            value="",
            loc=SourceLoc(
                file_path=self.file_path,
                line=self.line,
                end_line=self.line,
                col_start=self.col,
                col_end=self.col,
                pos_start=self.pos,
                pos_end=self.pos
            )
        );
    }
    ch = self.current();

    if self.is_alpha(ch) {
        if ch == "f" and (self.peek() == "\"" or self.peek() == "'") {
            self.advance();
            return self.scan_fstring("f");
        }
        if ch == "r"
        and self.peek() == "f"
        and (self.peek(2) == "\"" or self.peek(2) == "'") {
            self.advance();
            self.advance();
            return self.scan_fstring("rf");
        }
        return self.scan_identifier();
    }

    if self.is_digit(ch) {
        return self.scan_number();
    }

    if ch == "." and not self.at_end() and self.is_digit(self.peek()) {
        return self.scan_leading_dot_float();
    }

    if ch == "\"" or ch == "'" {
        return self.scan_string(ch);
    }

    if ch == ":"
    and self.peek() == ":"
    and self.peek(2) == "p"
    and self.peek(3) == "y"
    and self.peek(4) == ":"
    and self.peek(5) == ":" {
        return self.scan_pynline();
    }

    if ch == "`" and self.is_alpha(self.peek()) {
        return self.scan_kwesc_name();
    }

    return self.scan_operator();
}

impl Lexer.scan_pynline -> Token {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;

    for _ in range(6) {
        self.advance();
    }

    code = "";
    while not self.at_end() {
        if self.current() == ":"
        and self.peek() == ":"
        and self.peek(2) == "p"
        and self.peek(3) == "y"
        and self.peek(4) == ":"
        and self.peek(5) == ":" {
            for _ in range(6) {
                self.advance();
            }
            return self.make_token(
                TokenKind.PYNLINE, code, start_line, start_col, start_pos
            );
        }
        code += self.advance();
    }
    self.error(
        "Unterminated inline Python block",
        start_line,
        start_col,
        start_pos,
        code_str="E0103"
    );
    return self.make_token(TokenKind.ERROR, code, start_line, start_col, start_pos);
}

impl Lexer.scan_operator -> Token {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    ch = self.current();

    if self.match_string("<-->") {
        return self.make_token(
            TokenKind.ARROW_BI, "<-->", start_line, start_col, start_pos
        );
    }
    if self.match_string("<++>") {
        return self.make_token(
            TokenKind.CARROW_BI, "<++>", start_line, start_col, start_pos
        );
    }
    if self.match_string(":nl:") {
        return self.make_token(
            TokenKind.NONLOCAL_OP, ":nl:", start_line, start_col, start_pos
        );
    }

    if self.match_string("<--") {
        return self.make_token(
            TokenKind.ARROW_L, "<--", start_line, start_col, start_pos
        );
    }
    if self.match_string("-->") {
        return self.make_token(
            TokenKind.ARROW_R, "-->", start_line, start_col, start_pos
        );
    }
    if self.match_string("<++") {
        return self.make_token(
            TokenKind.CARROW_L, "<++", start_line, start_col, start_pos
        );
    }
    if self.match_string("++>") {
        return self.make_token(
            TokenKind.CARROW_R, "++>", start_line, start_col, start_pos
        );
    }
    if self.match_string("<-:") {
        return self.make_token(
            TokenKind.ARROW_L_P1, "<-:", start_line, start_col, start_pos
        );
    }
    if self.match_string(":->") {
        return self.make_token(
            TokenKind.ARROW_R_P2, ":->", start_line, start_col, start_pos
        );
    }

    if self.match_string("->:") {
        return self.make_token(
            TokenKind.ARROW_R_P1, "->:", start_line, start_col, start_pos
        );
    }
    if self.match_string("<+:") {
        return self.make_token(
            TokenKind.CARROW_L_P1, "<+:", start_line, start_col, start_pos
        );
    }
    if self.match_string(":+>") {
        return self.make_token(
            TokenKind.CARROW_R_P2, ":+>", start_line, start_col, start_pos
        );
    }
    if self.match_string(":typ:") {
        return self.make_token(
            TokenKind.TYPE_OP_ALIAS, ":typ:", start_line, start_col, start_pos
        );
    }
    if self.match_string(":g:") {
        return self.make_token(
            TokenKind.GLOBAL_OP, ":g:", start_line, start_col, start_pos
        );
    }
    if self.match_string("...") {
        return self.make_token(
            TokenKind.ELLIPSIS, "...", start_line, start_col, start_pos
        );
    }
    if self.match_string("**=") {
        return self.make_token(
            TokenKind.STAR_POW_EQ, "**=", start_line, start_col, start_pos
        );
    }
    if self.match_string("//=") {
        return self.make_token(
            TokenKind.FLOOR_DIV_EQ, "//=", start_line, start_col, start_pos
        );
    }
    if self.match_string("<<=") {
        return self.make_token(
            TokenKind.LSHIFT_EQ, "<<=", start_line, start_col, start_pos
        );
    }
    if self.match_string(">>=") {
        return self.make_token(
            TokenKind.RSHIFT_EQ, ">>=", start_line, start_col, start_pos
        );
    }
    if self.match_string("</>") {
        self.jsx_depth -= 1;
        self.pop_mode();
        return self.make_token(
            TokenKind.JSX_FRAG_CLOSE, "</>", start_line, start_col, start_pos
        );
    }

    if self.match_string("**") {
        return self.make_token(
            TokenKind.STAR_POW, "**", start_line, start_col, start_pos
        );
    }
    if self.match_string("//") {
        return self.make_token(
            TokenKind.FLOOR_DIV, "//", start_line, start_col, start_pos
        );
    }
    if self.match_string("==") {
        return self.make_token(TokenKind.EE, "==", start_line, start_col, start_pos);
    }
    if self.match_string("!=") {
        return self.make_token(TokenKind.NE, "!=", start_line, start_col, start_pos);
    }
    if self.match_string("<=") {
        return self.make_token(TokenKind.LTE, "<=", start_line, start_col, start_pos);
    }
    if self.match_string(">=") {
        return self.make_token(TokenKind.GTE, ">=", start_line, start_col, start_pos);
    }
    if self.match_string("<<") {
        return self.make_token(
            TokenKind.LSHIFT, "<<", start_line, start_col, start_pos
        );
    }
    if self.match_string(">>") {
        return self.make_token(
            TokenKind.RSHIFT, ">>", start_line, start_col, start_pos
        );
    }
    if self.match_string("|>") {
        return self.make_token(
            TokenKind.PIPE_FWD, "|>", start_line, start_col, start_pos
        );
    }
    if self.match_string("<|") {
        return self.make_token(
            TokenKind.PIPE_BKWD, "<|", start_line, start_col, start_pos
        );
    }
    if self.match_string(":>") {
        return self.make_token(
            TokenKind.A_PIPE_FWD, ":>", start_line, start_col, start_pos
        );
    }
    if self.match_string("<:") {
        return self.make_token(
            TokenKind.A_PIPE_BKWD, "<:", start_line, start_col, start_pos
        );
    }
    if self.match_string(".>") {
        return self.make_token(
            TokenKind.DOT_FWD, ".>", start_line, start_col, start_pos
        );
    }
    if self.match_string("<.") {
        return self.make_token(
            TokenKind.DOT_BKWD, "<.", start_line, start_col, start_pos
        );
    }
    if self.match_string("->") {
        return self.make_token(
            TokenKind.RETURN_HINT, "->", start_line, start_col, start_pos
        );
    }
    if self.match_char("?") {
        return self.make_token(
            TokenKind.NULL_OK, "?", start_line, start_col, start_pos
        );
    }
    if self.match_string(":=") {
        return self.make_token(
            TokenKind.WALRUS_EQ, ":=", start_line, start_col, start_pos
        );
    }
    if self.match_string("+=") {
        return self.make_token(
            TokenKind.ADD_EQ, "+=", start_line, start_col, start_pos
        );
    }
    if self.match_string("-=") {
        return self.make_token(
            TokenKind.SUB_EQ, "-=", start_line, start_col, start_pos
        );
    }
    if self.match_string("*=") {
        return self.make_token(
            TokenKind.MUL_EQ, "*=", start_line, start_col, start_pos
        );
    }
    if self.match_string("/=") {
        return self.make_token(
            TokenKind.DIV_EQ, "/=", start_line, start_col, start_pos
        );
    }
    if self.match_string("%=") {
        return self.make_token(
            TokenKind.MOD_EQ, "%=", start_line, start_col, start_pos
        );
    }
    if self.match_string("&&") {
        return self.make_token(
            TokenKind.KW_AND, "&&", start_line, start_col, start_pos
        );
    }
    if self.match_string("||") {
        return self.make_token(TokenKind.KW_OR, "||", start_line, start_col, start_pos);
    }
    if self.match_string("&=") {
        return self.make_token(
            TokenKind.BW_AND_EQ, "&=", start_line, start_col, start_pos
        );
    }
    if self.match_string("|=") {
        return self.make_token(
            TokenKind.BW_OR_EQ, "|=", start_line, start_col, start_pos
        );
    }
    if self.match_string("^=") {
        return self.make_token(
            TokenKind.BW_XOR_EQ, "^=", start_line, start_col, start_pos
        );
    }
    if self.match_string("@=") {
        return self.make_token(
            TokenKind.MATMUL_EQ, "@=", start_line, start_col, start_pos
        );
    }

    if self.match_string(":<-") {
        return self.make_token(
            TokenKind.ARROW_L_P2, ":<-", start_line, start_col, start_pos
        );
    }
    if self.match_string("+>:") {
        return self.make_token(
            TokenKind.CARROW_R_P1, "+>:", start_line, start_col, start_pos
        );
    }
    if self.match_string(":<+") {
        return self.make_token(
            TokenKind.CARROW_L_P2, ":<+", start_line, start_col, start_pos
        );
    }
    if self.match_string("</") {
        return self.make_token(
            TokenKind.JSX_CLOSE_START, "</", start_line, start_col, start_pos
        );
    }
    if self.match_string("/>") {
        return self.make_token(
            TokenKind.JSX_SELF_CLOSE, "/>", start_line, start_col, start_pos
        );
    }
    if self.match_string("<>") {
        self.jsx_depth += 1;
        self.push_mode(LexerMode.JSX_CONTENT);
        return self.make_token(
            TokenKind.JSX_FRAG_OPEN, "<>", start_line, start_col, start_pos
        );
    }

    if self.in_jsx() and self.jsx_brace_depth == 0 {
        if self.match_string("{{") {
            return self.make_token(
                TokenKind.D_LBRACE, "{{", start_line, start_col, start_pos
            );
        }
        if self.match_string("}}") {
            return self.make_token(
                TokenKind.D_RBRACE, "}}", start_line, start_col, start_pos
            );
        }
    }

    self.advance();
    switch ch {
        case "(":
            return self.make_token(
                TokenKind.LPAREN, "(", start_line, start_col, start_pos
            );

        case ")":
            return self.make_token(
                TokenKind.RPAREN, ")", start_line, start_col, start_pos
            );

        case "{":
            if self.jsx_brace_depth > 0 {
                self.jsx_brace_depth += 1;
            }
            return self.make_token(
                TokenKind.LBRACE, "{", start_line, start_col, start_pos
            );

        case "}":
            if self.jsx_brace_depth > 0 {
                self.jsx_brace_depth -= 1;
                if self.jsx_brace_depth == 0 {
                    self.pop_mode();

                    if self.jsx_brace_depth_stack {
                        self.jsx_brace_depth = self.jsx_brace_depth_stack.pop();
                    }
                }
            }
            return self.make_token(
                TokenKind.RBRACE, "}", start_line, start_col, start_pos
            );

        case "[":
            return self.make_token(
                TokenKind.LSQUARE, "[", start_line, start_col, start_pos
            );

        case "]":
            return self.make_token(
                TokenKind.RSQUARE, "]", start_line, start_col, start_pos
            );

        case ",":
            return self.make_token(
                TokenKind.COMMA, ",", start_line, start_col, start_pos
            );

        case ":":
            return self.make_token(
                TokenKind.COLON, ":", start_line, start_col, start_pos
            );

        case ";":
            return self.make_token(
                TokenKind.SEMI, ";", start_line, start_col, start_pos
            );

        case ".":
            return self.make_token(
                TokenKind.DOT, ".", start_line, start_col, start_pos
            );

        case "+":
            return self.make_token(
                TokenKind.PLUS, "+", start_line, start_col, start_pos
            );

        case "-":
            return self.make_token(
                TokenKind.MINUS, "-", start_line, start_col, start_pos
            );

        case "*":
            return self.make_token(
                TokenKind.STAR_MUL, "*", start_line, start_col, start_pos
            );

        case "/":
            return self.make_token(
                TokenKind.DIV, "/", start_line, start_col, start_pos
            );

        case "%":
            return self.make_token(
                TokenKind.MOD, "%", start_line, start_col, start_pos
            );

        case "&":
            return self.make_token(
                TokenKind.BW_AND, "&", start_line, start_col, start_pos
            );

        case "|":
            return self.make_token(
                TokenKind.BW_OR, "|", start_line, start_col, start_pos
            );

        case "^":
            return self.make_token(
                TokenKind.BW_XOR, "^", start_line, start_col, start_pos
            );

        case "~":
            return self.make_token(
                TokenKind.BW_NOT, "~", start_line, start_col, start_pos
            );

        case "<":
            return self.make_token(TokenKind.LT, "<", start_line, start_col, start_pos);

        case ">":
            return self.make_token(TokenKind.GT, ">", start_line, start_col, start_pos);

        case "=":
            return self.make_token(TokenKind.EQ, "=", start_line, start_col, start_pos);

        case "@":
            return self.make_token(
                TokenKind.DECOR_OP, "@", start_line, start_col, start_pos
            );

    }

    self.error(
        f"Unexpected character: '{ch}'",
        start_line,
        start_col,
        start_pos,
        code_str="E0105"
    );
    return self.make_token(TokenKind.ERROR, ch, start_line, start_col, start_pos);
}

impl Lexer.next_token -> Token {
    mode = self.current_mode();

    if mode in [
        LexerMode.FSTRING_DQ,
        LexerMode.FSTRING_SQ,
        LexerMode.FSTRING_TDQ,
        LexerMode.FSTRING_TSQ
    ] {
        return self.scan_fstring_content();
    } elif mode == LexerMode.FSTRING_EXPR {
        return self.scan_fstring_expr_token();
    }

    if mode == LexerMode.JSX_TAG {
        return self.scan_jsx_tag_token();
    } elif mode == LexerMode.JSX_CONTENT {
        return self.scan_jsx_content();
    }

    self.skip_whitespace_and_comments();
    if self.at_end() {
        return Token(
            kind=TokenKind.EOF,
            value="",
            loc=SourceLoc(
                file_path=self.file_path,
                line=self.line,
                end_line=self.line,
                col_start=self.col,
                col_end=self.col,
                pos_start=self.pos,
                pos_end=self.pos
            )
        );
    }
    ch = self.current();

    if ch == "`" and self.is_alpha(self.peek()) {
        return self.scan_kwesc_name();
    }

    if ch == "<" and (self.is_alpha(self.peek()) or self.peek() == "@") {
        if not self.prev_is_value() {
            return self.scan_jsx_open_start();
        }
        if self.in_view_body()
        and self.prev_token_kind in [
            TokenKind.RBRACE,
            TokenKind.JSX_TAG_END,
            TokenKind.JSX_SELF_CLOSE,
            TokenKind.JSX_FRAG_CLOSE
        ] {
            return self.scan_jsx_open_start();
        }
    }

    if self.is_alpha(ch) {
        if ch == "f" and (self.peek() == "\"" or self.peek() == "'") {
            self.advance();
            return self.scan_fstring("f");
        }
        if ch == "r"
        and self.peek() == "f"
        and (self.peek(2) == "\"" or self.peek(2) == "'") {
            self.advance();
            self.advance();
            return self.scan_fstring("rf");
        }
        return self.scan_identifier();
    }

    if self.is_digit(ch) {
        return self.scan_number();
    }

    if ch == "." and not self.at_end() and self.is_digit(self.peek()) {
        return self.scan_leading_dot_float();
    }

    if ch == "\"" or ch == "'" {
        return self.scan_string(ch);
    }

    if ch == ":"
    and self.peek() == ":"
    and self.peek(2) == "p"
    and self.peek(3) == "y"
    and self.peek(4) == ":"
    and self.peek(5) == ":" {
        return self.scan_pynline();
    }

    return self.scan_operator();
}

impl Lexer.tokenize -> list[Token] {
    self._enc = self.source.encode("utf-8");
    self._source_len = len(self._enc);
    self._ascii = self.source.isascii();
    tokens: list[Token] = [];
    last_pos = -1;
    while True {
        token = self.next_token();
        tokens.append(token);
        self._track_view_context(token);
        self.prev_token_kind = token.kind;
        if token.kind == TokenKind.EOF {
            break;
        }

        if self.pos == last_pos or self.pos > self._source_len {
            mode = self.current_mode();
            self.error(
                f"Lexer stuck at EOF in mode {mode} (pos={self.pos})",
                self.line,
                self.col,
                self.pos,
                code_str="E0107"
            );
            tokens.append(
                Token(
                    kind=TokenKind.EOF,
                    value="",
                    loc=SourceLoc(
                        file_path=self.file_path,
                        line=self.line,
                        end_line=self.line,
                        col_start=self.col,
                        col_end=self.col,
                        pos_start=self.pos,
                        pos_end=self.pos
                    )
                )
            );
            break;
        }
        last_pos = self.pos;
    }
    return tokens;
}
