"""Implementation blocks for the Jac lexer.

This file contains the method implementations for the Lexer class.
The signatures are defined in lexer.jac.
"""

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

impl Lexer.in_fstring -> bool {
    mode = self.current_mode();
    return mode in [
        LexerMode.FSTRING_DQ,
        LexerMode.FSTRING_SQ,
        LexerMode.FSTRING_TDQ,
        LexerMode.FSTRING_TSQ,
        LexerMode.FSTRING_EXPR
    ];
}

impl Lexer.in_jsx -> bool {
    mode = self.current_mode();
    return mode in [LexerMode.JSX_TAG, LexerMode.JSX_CONTENT];
}

impl Lexer.prev_is_value -> bool {
    # Returns True when the previous token ends a value-producing expression.
    # Used to disambiguate `<` as comparison (after values) vs JSX tag opener.
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

impl Lexer.current -> str {
    if self.pos >= self._source_len {
        return "";
    }
    return self.source[self.pos];
}

impl Lexer.peek(offset: int = 1) -> str {
    idx = self.pos + offset;
    if idx >= self._source_len {
        return "";
    }
    return self.source[idx];
}

impl Lexer.advance -> str {
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
    if self.source[self.pos:self.pos + len(expected)] == expected {
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

impl Lexer.error(message: str, start_line: int, start_col: int, start_pos: int) {
    self.errors.append(
        LexerError(
            message=message, loc=self.make_loc(start_line, start_col, start_pos)
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
    comment_text = self.source[start_pos:self.pos];
    self.comments.append(
        (
            comment_text,
            start_line,
            start_line,
            start_col,
            self.col,
            start_pos,
            self.pos,
            False
        )
    );
}

impl Lexer.skip_block_comment -> bool {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    # Skip the opening #*
    self.advance();  # #
    self.advance();  # *
    while not self.at_end() {
        if self.current() == "*" and self.peek() == "#" {
            self.advance();  # *
            self.advance();  # #
            comment_text = self.source[start_pos:self.pos];
            self.comments.append(
                (
                    comment_text,
                    start_line,
                    self.line,
                    start_col,
                    self.col,
                    start_pos,
                    self.pos,
                    True
                )
            );
            return True;
        }
        self.advance();
    }
    self.error("Unterminated block comment", start_line, start_col, start_pos);
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
    # Check for multi-word keywords: "not in" and "is not"
    if value == "not" {
        # Save state for potential rollback
        saved_pos = self.pos;
        saved_line = self.line;
        saved_col = self.col;
        # Skip whitespace (but not newlines for safety)
        while not self.at_end() and (self.current() == " " or self.current() == "\t") {
            self.advance();
        }
        # Check for "in" - making it "not in"
        if not self.at_end() and self.current() == "i" {
            if self.source[self.pos:self.pos + 2] == "in"
            and (
                self.pos + 2 >= self._source_len
                or not self.is_alnum(self.source[self.pos + 2])
            ) {
                self.advance();  # i
                self.advance();  # n
                return self.make_token(
                    TokenKind.KW_NIN, "not in", start_line, start_col, start_pos
                );
            }
        }
        # Rollback if not "not in"
        self.pos = saved_pos;
        self.line = saved_line;
        self.col = saved_col;
    }
    if value == "is" {
        # Save state for potential rollback
        saved_pos = self.pos;
        saved_line = self.line;
        saved_col = self.col;
        # Skip whitespace (but not newlines for safety)
        while not self.at_end() and (self.current() == " " or self.current() == "\t") {
            self.advance();
        }
        # Check for "not" - making it "is not"
        if not self.at_end() and self.current() == "n" {
            if self.source[self.pos:self.pos + 3] == "not"
            and (
                self.pos + 3 >= self._source_len
                or not self.is_alnum(self.source[self.pos + 3])
            ) {
                self.advance();  # n
                self.advance();  # o
                self.advance();  # t
                return self.make_token(
                    TokenKind.KW_ISN, "is not", start_line, start_col, start_pos
                );
            }
        }
        # Rollback if not "is not"
        self.pos = saved_pos;
        self.line = saved_line;
        self.col = saved_col;
    }
    # Check for keyword
    kind = lookup_keyword(value);
    if kind is not None {
        return self.make_token(kind, value, start_line, start_col, start_pos);
    }
    return self.make_token(TokenKind.NAME, value, start_line, start_col, start_pos);
}

impl Lexer.scan_kwesc_name -> Token {
    # Scan keyword-escaped name: KWESC_NAME token (backtick prefix)
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    # Skip the backtick prefix
    self.advance();  # `
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
    # Check for hex, binary, or octal prefix
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
                self.current() >= "0"
                and self.current() <= "7"
                or self.current() == "_"
            ) {
                value += self.advance();
            }
            return self.make_token(kind, value, start_line, start_col, start_pos);
        }
    }
    # Scan integer part (with underscore separators)
    while not self.at_end()
    and (self.is_digit(self.current()) or self.current() == "_") {
        value += self.advance();
    }
    # Check for decimal point
    if self.current() == "." and self.is_digit(self.peek()) {
        kind = TokenKind.FLOAT;
        value += self.advance();  # .
        while not self.at_end()
        and (self.is_digit(self.current()) or self.current() == "_") {
            value += self.advance();
        }
    }
    # Check for exponent
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
    value = self.advance();  # consume the '.'
    while not self.at_end()
    and (self.is_digit(self.current()) or self.current() == "_") {
        value += self.advance();
    }
    # Check for exponent
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
    triple = False;
    # Check for triple-quoted string
    if self.peek() == quote and self.peek(2) == quote {
        triple = True;
        value += self.advance();  # First quote
        value += self.advance();  # Second quote
        value += self.advance();  # Third quote
    } else {
        value += self.advance();  # Opening quote
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
                    "Unterminated string literal", start_line, start_col, start_pos
                );
                return self.make_token(
                    TokenKind.ERROR, value, start_line, start_col, start_pos
                );
            }
        }

        # Handle escape sequences
        if ch == "\\" {
            value += self.advance();
            if not self.at_end() {
                value += self.advance();
            }
        } else {
            value += self.advance();
        }
    }
    self.error("Unterminated string literal", start_line, start_col, start_pos);
    return self.make_token(TokenKind.ERROR, value, start_line, start_col, start_pos);
}

impl Lexer.scan_fstring(prefix: str) -> Token {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    value = prefix;
    # Determine quote style
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

        # Check for closing quote(s)
        if is_triple {
            if ch == quote and self.peek() == quote and self.peek(2) == quote {
                # End of f-string
                if len(value) > 0 {
                    # Return accumulated text first
                    text_kind = self.get_fstring_text_kind(mode);
                    return self.make_token(
                        text_kind, value, start_line, start_col, start_pos
                    );
                }
                # Return end token
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
            # Non-triple f-strings can't have newlines
            if ch == "\n" {
                self.error("Unterminated f-string", start_line, start_col, start_pos);
                return self.make_token(
                    TokenKind.ERROR, value, start_line, start_col, start_pos
                );
            }
        }

        # Check for escaped brace {{ or }}
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

        # Check for expression start
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

        # Handle escape sequences (for non-raw f-strings)
        if ch == "\\" {
            value += self.advance();
            if not self.at_end() {
                value += self.advance();
            }
        } else {
            value += self.advance();
        }
    }
    self.error("Unterminated f-string", start_line, start_col, start_pos);
    return self.make_token(TokenKind.ERROR, value, start_line, start_col, start_pos);
}

impl Lexer.get_fstring_text_kind(mode: LexerMode) -> TokenKind {
    match mode {
        case LexerMode.FSTRING_DQ:
            return TokenKind.F_TEXT_DQ;

        case LexerMode.FSTRING_SQ:
            return TokenKind.F_TEXT_SQ;

        case LexerMode.FSTRING_TDQ:
            return TokenKind.F_TEXT_TDQ;

        case LexerMode.FSTRING_TSQ:
            return TokenKind.F_TEXT_TSQ;

        case _:
            return TokenKind.F_TEXT_DQ;  # Fallback


    }
}

impl Lexer.get_fstring_end_kind(mode: LexerMode) -> TokenKind {
    match mode {
        case LexerMode.FSTRING_DQ:
            return TokenKind.F_DQ_END;

        case LexerMode.FSTRING_SQ:
            return TokenKind.F_SQ_END;

        case LexerMode.FSTRING_TDQ:
            return TokenKind.F_TDQ_END;

        case LexerMode.FSTRING_TSQ:
            return TokenKind.F_TSQ_END;

        case _:
            return TokenKind.F_DQ_END;  # Fallback


    }
}

impl Lexer.scan_fstring_expr_token -> Token {
    self.skip_whitespace_and_comments();
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    ch = self.current();
    # Track brace depth
    if ch == "{" {
        self.fstring_brace_depth += 1;
        self.advance();
        return self.make_token(TokenKind.LBRACE, "{", start_line, start_col, start_pos);
    }
    if ch == "}" {
        self.fstring_brace_depth -= 1;
        self.advance();
        if self.fstring_brace_depth == 0 {
            # End of f-string expression, pop back to f-string content mode
            self.pop_mode();
            # Restore previous fstring_brace_depth from stack
            if self.fstring_brace_depth_stack {
                self.fstring_brace_depth = self.fstring_brace_depth_stack.pop();
            }
        }
        return self.make_token(TokenKind.RBRACE, "}", start_line, start_col, start_pos);
    }
    # Check for conversion specifier !s, !r, !a
    if ch == "!" and self.peek() in ["s", "r", "a", "S", "R", "A"] {
        self.advance();
        conv = self.advance();
        return self.make_token(
            TokenKind.CONV, "!" + conv, start_line, start_col, start_pos
        );
    }
    # Check for format spec colon (but not walrus := operator)
    if ch == ":" and self.peek() != "=" {
        self.advance();
        return self.make_token(TokenKind.COLON, ":", start_line, start_col, start_pos);
    }
    # Otherwise, scan a regular token
    return self.scan_regular_token();
}

"""Scan JSX opening tag start: consume < and enter tag mode."""
impl Lexer.scan_jsx_open_start -> Token {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    self.advance();  # consume <
    self.jsx_depth += 1;
    self.push_mode(LexerMode.JSX_TAG);
    return self.make_token(
        TokenKind.JSX_OPEN_START, "<", start_line, start_col, start_pos
    );
}

"""Scan the next token inside a JSX tag (name, attribute, =, >, />)."""
impl Lexer.scan_jsx_tag_token -> Token {
    self.skip_whitespace_and_comments();
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    ch = self.current();
    # Self-closing: />
    if ch == "/" and self.peek() == ">" {
        self.advance();
        self.advance();
        self.jsx_depth -= 1;
        self.pop_mode();
        return self.make_token(
            TokenKind.JSX_SELF_CLOSE, "/>", start_line, start_col, start_pos
        );
    }
    # Tag end: > - switch to JSX_CONTENT mode or finish closing tag
    if ch == ">" {
        self.advance();
        self.pop_mode();  # Pop JSX_TAG
        if self.jsx_closing_tag {
            # End of closing tag - decrement depth and return to parent context
            self.jsx_closing_tag = False;
            self.jsx_depth -= 1;
            # Don't push JSX_CONTENT - we're done with this element
        } else {
            # End of opening tag - switch to content mode
            self.push_mode(LexerMode.JSX_CONTENT);
        }
        return self.make_token(
            TokenKind.JSX_TAG_END, ">", start_line, start_col, start_pos
        );
    }
    # Opening brace for expression attribute: {expr}
    if ch == "{" {
        self.advance();
        self.jsx_brace_depth_stack.append(self.jsx_brace_depth);
        self.jsx_brace_depth = 1;
        self.push_mode(LexerMode.NORMAL);  # Parse expression in normal mode
        return self.make_token(TokenKind.LBRACE, "{", start_line, start_col, start_pos);
    }
    # Attribute name (JSX identifiers can contain hyphens)
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
    # Equals sign for attribute
    if ch == "=" {
        self.advance();
        return self.make_token(TokenKind.EQ, "=", start_line, start_col, start_pos);
    }
    # String attribute value
    if ch == "\"" or ch == "'" {
        return self.scan_string(ch);
    }
    # Dot for namespaced JSX names like <UI.Button />
    if ch == "." {
        self.advance();
        return self.make_token(TokenKind.DOT, ".", start_line, start_col, start_pos);
    }
    # Unknown - return error token
    self.error(
        f"Unexpected character in JSX tag: '{ch}'", start_line, start_col, start_pos
    );
    self.advance();
    return self.make_token(TokenKind.ERROR, ch, start_line, start_col, start_pos);
}

"""Scan JSX content between tags."""
impl Lexer.scan_jsx_content -> Token {
    # Do NOT skip whitespace here — whitespace in JSX content is significant
    # for same-line spacing (e.g., "{expr}  text"). Whitespace normalization
    # is handled downstream by JsxText.get_normalized_text(). Whitespace-only
    # text nodes are filtered by the parser.
    if self.at_end() {
        self.error("Unexpected end of JSX content", self.line, self.col, self.pos);
        return self.make_token(TokenKind.ERROR, "", self.line, self.col, self.pos);
    }
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    ch = self.current();
    # Check for JSX fragment close: </> (must come before </identifier check)
    if ch == "<" and self.peek() == "/" and self.peek(2) == ">" {
        self.advance();
        self.advance();
        self.advance();
        self.jsx_depth -= 1;
        self.pop_mode();  # Pop JSX_CONTENT pushed by matching <>
        return self.make_token(
            TokenKind.JSX_FRAG_CLOSE, "</>", start_line, start_col, start_pos
        );
    }
    # Check for closing tag: </
    if ch == "<" and self.peek() == "/" {
        self.advance();
        self.advance();
        self.pop_mode();  # Pop JSX_CONTENT
        self.push_mode(LexerMode.JSX_TAG);  # For scanning closing tag name
        self.jsx_closing_tag = True;  # Mark that we're in a closing tag
        return self.make_token(
            TokenKind.JSX_CLOSE_START, "</", start_line, start_col, start_pos
        );
    }
    # Check for nested JSX element: <identifier
    if ch == "<" and self.is_alpha(self.peek()) {
        self.advance();  # consume <
        self.jsx_depth += 1;
        # Push JSX_TAG on top of current JSX_CONTENT
        self.push_mode(LexerMode.JSX_TAG);
        return self.make_token(
            TokenKind.JSX_OPEN_START, "<", start_line, start_col, start_pos
        );
    }
    # Check for JSX fragment: <>
    if ch == "<" and self.peek() == ">" {
        self.advance();
        self.advance();
        self.jsx_depth += 1;
        self.push_mode(LexerMode.JSX_CONTENT);  # Fragment content mode (popped by </>)
        return self.make_token(
            TokenKind.JSX_FRAG_OPEN, "<>", start_line, start_col, start_pos
        );
    }
    # Opening brace for expression: {expr}
    if ch == "{" {
        self.advance();
        self.jsx_brace_depth_stack.append(self.jsx_brace_depth);
        self.jsx_brace_depth = 1;
        self.push_mode(LexerMode.NORMAL);  # Parse expression in normal mode
        return self.make_token(TokenKind.LBRACE, "{", start_line, start_col, start_pos);
    }
    # Text content - collect until we hit a meaningful JSX delimiter or end.
    # Only break on `<` when it starts a valid JSX construct (tag, closing
    # tag, or fragment).  A bare `<` (e.g. `<--`) is consumed as text,
    # matching TSX behaviour where bare `<` in content is invalid and must
    # be written as `{"<"}`.
    value = "";
    while not self.at_end() {
        ch = self.current();
        if ch == "{" {
            break;
        }
        if ch == "<" {
            nxt = self.peek();
            # Only break when `<` begins a real JSX token:
            #   </  (closing tag / fragment close)
            #   <>  (fragment open)
            #   <A  (nested element — alpha means tag name)
            if nxt == "/" or nxt == ">" or self.is_alpha(nxt) {
                break;
            }
        }
        # Note: # is NOT treated as a comment inside JSX children.
        # JSX text content is like HTML — # is a regular text character.
        # Use {#* ... *#} style in JSX expressions for comments if needed.
        value += self.advance();
    }
    if len(value) > 0 {
        return self.make_token(
            TokenKind.JSX_TEXT, value, start_line, start_col, start_pos
        );
    }
    # Empty - shouldn't happen
    self.error("Unexpected end of JSX content", start_line, start_col, start_pos);
    return self.make_token(TokenKind.ERROR, "", start_line, start_col, start_pos);
}

"""Scan next token inside a JSX expression ({expr}), tracking brace depth."""
impl Lexer.scan_jsx_expr_token -> Token {
    # Normal token scanning applies, but we track brace depth
    # to know when to return to JSX content mode
    self.skip_whitespace_and_comments();
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    ch = self.current();
    if ch == "{" {
        self.jsx_brace_depth += 1;
        self.advance();
        return self.make_token(TokenKind.LBRACE, "{", start_line, start_col, start_pos);
    }
    if ch == "}" {
        self.jsx_brace_depth -= 1;
        self.advance();
        if self.jsx_brace_depth == 0 {
            # End of JSX expression, pop back to previous mode
            self.pop_mode();
            # Restore previous jsx_brace_depth from stack
            if self.jsx_brace_depth_stack {
                self.jsx_brace_depth = self.jsx_brace_depth_stack.pop();
            }
        }
        return self.make_token(TokenKind.RBRACE, "}", start_line, start_col, start_pos);
    }
    return self.scan_regular_token();
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
    # Identifier or keyword
    if self.is_alpha(ch) {
        # Check for f-string prefix
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
    # Number
    if self.is_digit(ch) {
        return self.scan_number();
    }
    # Leading-dot float (e.g. .5, .435e-2)
    if ch == "." and not self.at_end() and self.is_digit(self.peek()) {
        return self.scan_leading_dot_float();
    }
    # String
    if ch == "\"" or ch == "'" {
        return self.scan_string(ch);
    }
    # Check for inline Python block ::py::
    if ch == ":"
    and self.peek() == ":"
    and self.peek(2) == "p"
    and self.peek(3) == "y"
    and self.peek(4) == ":"
    and self.peek(5) == ":" {
        return self.scan_pynline();
    }
    # Check for keyword-escaped name: `identifier (backtick prefix)
    if ch == "`" and self.is_alpha(self.peek()) {
        return self.scan_kwesc_name();
    }
    # Operators and delimiters
    return self.scan_operator();
}

impl Lexer.scan_pynline -> Token {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    # Skip opening ::py::
    for _ in range(6) {
        self.advance();
    }
    # Collect all content until closing ::py::
    code = "";
    while not self.at_end() {
        if self.current() == ":"
        and self.peek() == ":"
        and self.peek(2) == "p"
        and self.peek(3) == "y"
        and self.peek(4) == ":"
        and self.peek(5) == ":" {
            # Skip closing ::py::
            for _ in range(6) {
                self.advance();
            }
            return self.make_token(
                TokenKind.PYNLINE, code, start_line, start_col, start_pos
            );
        }
        code += self.advance();
    }
    self.error("Unterminated inline Python block", start_line, start_col, start_pos);
    return self.make_token(TokenKind.ERROR, code, start_line, start_col, start_pos);
}

impl Lexer.scan_operator -> Token {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    ch = self.current();
    # Try multi-character operators first (longest match)

    # 4-character operators
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
    # 3-character operators
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
        self.pop_mode();  # Pop JSX_CONTENT pushed by matching <>
        return self.make_token(
            TokenKind.JSX_FRAG_CLOSE, "</>", start_line, start_col, start_pos
        );
    }
    # 2-character operators
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
    if self.match_string("->:") {
        return self.make_token(
            TokenKind.ARROW_R_P1, "->:", start_line, start_col, start_pos
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
    # Only match {{ and }} as single tokens in JSX content mode
    # where they represent literal brace escape sequences.
    # In normal code, }} should be two separate RBRACE tokens.
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
    # Single-character operators and delimiters
    self.advance();
    match ch {
        case "(":
            return self.make_token(
                TokenKind.LPAREN, "(", start_line, start_col, start_pos
            );

        case ")":
            return self.make_token(
                TokenKind.RPAREN, ")", start_line, start_col, start_pos
            );

        case "{":
            # Track nested braces inside JSX expressions
            if self.jsx_brace_depth > 0 {
                self.jsx_brace_depth += 1;
            }
            return self.make_token(
                TokenKind.LBRACE, "{", start_line, start_col, start_pos
            );

        case "}":
            # Check if we're closing a JSX expression
            if self.jsx_brace_depth > 0 {
                self.jsx_brace_depth -= 1;
                if self.jsx_brace_depth == 0 {
                    # End of JSX expression, pop back to previous JSX mode
                    self.pop_mode();
                    # Restore previous jsx_brace_depth from stack
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
    # Unknown character
    self.error(f"Unexpected character: '{ch}'", start_line, start_col, start_pos);
    return self.make_token(TokenKind.ERROR, ch, start_line, start_col, start_pos);
}

impl Lexer.next_token -> Token {
    mode = self.current_mode();
    # Handle f-string modes
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
    # Handle JSX modes
    if mode == LexerMode.JSX_TAG {
        return self.scan_jsx_tag_token();
    } elif mode == LexerMode.JSX_CONTENT {
        return self.scan_jsx_content();
    }
    # Normal mode - continue to regular scanning
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
    # Check for keyword-escaped name: `identifier (backtick prefix)
    if ch == "`" and self.is_alpha(self.peek()) {
        return self.scan_kwesc_name();
    }
    # Check for JSX opening tag: <identifier
    # Only if the previous token is NOT a value (otherwise < is a comparison operator).
    if ch == "<" and self.is_alpha(self.peek()) and not self.prev_is_value() {
        return self.scan_jsx_open_start();
    }
    # Identifier or keyword
    if self.is_alpha(ch) {
        # Check for f-string prefix
        if ch == "f" and (self.peek() == "\"" or self.peek() == "'") {
            self.advance();  # Skip 'f'
            return self.scan_fstring("f");
        }
        if ch == "r"
        and self.peek() == "f"
        and (self.peek(2) == "\"" or self.peek(2) == "'") {
            self.advance();  # Skip 'r'
            self.advance();  # Skip 'f'
            return self.scan_fstring("rf");
        }
        return self.scan_identifier();
    }
    # Number
    if self.is_digit(ch) {
        return self.scan_number();
    }
    # Leading-dot float (e.g. .5, .435e-2)
    if ch == "." and not self.at_end() and self.is_digit(self.peek()) {
        return self.scan_leading_dot_float();
    }
    # String
    if ch == "\"" or ch == "'" {
        return self.scan_string(ch);
    }
    # Check for inline Python block ::py::
    if ch == ":"
    and self.peek() == ":"
    and self.peek(2) == "p"
    and self.peek(3) == "y"
    and self.peek(4) == ":"
    and self.peek(5) == ":" {
        return self.scan_pynline();
    }
    # Operators and delimiters
    return self.scan_operator();
}

impl Lexer.tokenize -> list[Token] {
    self._source_len = len(self.source);
    tokens: list[Token] = [];
    last_pos = -1;
    while True {
        token = self.next_token();
        tokens.append(token);
        self.prev_token_kind = token.kind;
        if token.kind == TokenKind.EOF {
            break;
        }
        # Stuck detector: catch infinite loops when EOF is hit inside
        # non-NORMAL modes (JSX_CONTENT, JSX_TAG, f-string) that return
        # ERROR tokens without producing EOF or advancing the position.
        if self.pos == last_pos or self.pos > self._source_len {
            mode = self.current_mode();
            self.error(
                f"Lexer stuck at EOF in mode {mode} (pos={self.pos})",
                self.line,
                self.col,
                self.pos
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

impl Lexer.has_errors -> bool {
    return len(self.errors) > 0;
}

impl tokenize(
    source: str, file_path: str = "<input>"
) -> tuple[list[Token], list[LexerError]] {
    lexer = Lexer(source=source, file_path=file_path);
    tokens = lexer.tokenize();
    return (tokens, lexer.errors);
}
