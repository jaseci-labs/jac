"""Hand-written lexer for Jac.

This lexer converts source code into a stream of tokens. It is designed
to be native-compilation friendly with no runtime reflection.
"""

import from .tokens { Token, TokenKind, SourceLoc, lookup_keyword, KEYWORDS }

# =============================================================================
# Lexer Mode - For contextual lexing (f-strings, JSX)
# =============================================================================
enum LexerMode {
    NORMAL = "normal",
    FSTRING_DQ = "fstring_dq",  # Inside f"..."
    FSTRING_SQ = "fstring_sq",  # Inside f'...'
    FSTRING_TDQ = "fstring_tdq",  # Inside f"""..."""
    FSTRING_TSQ = "fstring_tsq",  # Inside f'''...'''
    FSTRING_EXPR = "fstring_expr",  # Inside {...} in f-string
    JSX_TAG = "jsx_tag",  # Inside <Tag ...>
    JSX_CONTENT = "jsx_content"  # Between JSX tags
}

# =============================================================================
# Lexer Error
# =============================================================================
obj LexerError {
    has message: str,
        loc: SourceLoc;

    def __str__ -> str {
        return f"LexerError at line {self.loc.line}, col {self.loc.col_start}: {self.message}";
    }
}

# =============================================================================
# Lexer
# =============================================================================
obj Lexer {
    has source: str,
        file_path: str = "<input>",
        pos: int = 0,
        line: int = 1,
        col: int = 1,
        errors: list[LexerError] = [],
        mode_stack: list[LexerMode] = [],
        fstring_brace_depth: int = 0;  # Track nested braces in f-string expressions

    def push_mode(mode: LexerMode) {
        self.mode_stack.append(mode);
    }

    def pop_mode -> LexerMode | None {
        if len(self.mode_stack) > 0 {
            return self.mode_stack.pop();
        }
        return None;
    }

    def current_mode -> LexerMode {
        if len(self.mode_stack) > 0 {
            return self.mode_stack[-1];
        }
        return LexerMode.NORMAL;
    }

    def in_fstring -> bool {
        mode = self.current_mode();
        return mode in [
            LexerMode.FSTRING_DQ,
            LexerMode.FSTRING_SQ,
            LexerMode.FSTRING_TDQ,
            LexerMode.FSTRING_TSQ,
            LexerMode.FSTRING_EXPR
        ];
    }

    # -------------------------------------------------------------------------
    # Character Access
    # -------------------------------------------------------------------------
    def current -> str {
        if self.pos >= len(self.source) {
            return "";
        }
        return self.source[self.pos];
    }

    def peek(offset: int = 1) -> str {
        idx = self.pos + offset;
        if idx >= len(self.source) {
            return "";
        }
        return self.source[idx];
    }

    def advance -> str {
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

    def at_end -> bool {
        return self.pos >= len(self.source);
    }

    def match_char(expected: str) -> bool {
        if self.current() == expected {
            self.advance();
            return True;
        }
        return False;
    }

    def match_string(expected: str) -> bool {
        if self.source[self.pos:self.pos + len(expected)] == expected {
            for _ in range(len(expected)) {
                self.advance();
            }
            return True;
        }
        return False;
    }

    # -------------------------------------------------------------------------
    # Location Tracking
    # -------------------------------------------------------------------------
    def make_loc(start_line: int, start_col: int, start_pos: int) -> SourceLoc {
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

    def make_token(
        kind: TokenKind, value: str, start_line: int, start_col: int, start_pos: int
    ) -> Token {
        return Token(
            kind=kind, value=value, loc=self.make_loc(start_line, start_col, start_pos)
        );
    }

    def error(message: str, start_line: int, start_col: int, start_pos: int) {
        self.errors.append(
            LexerError(
                message=message, loc=self.make_loc(start_line, start_col, start_pos)
            )
        );
    }

    # -------------------------------------------------------------------------
    # Character Classification
    # -------------------------------------------------------------------------
    def is_digit(ch: str) -> bool {
        return ch >= "0" and ch <= "9";
    }

    def is_hex_digit(ch: str) -> bool {
        return self.is_digit(ch)
        or (ch >= "a" and ch <= "f")
        or (ch >= "A" and ch <= "F");
    }

    def is_alpha(ch: str) -> bool {
        return (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or ch == "_";
    }

    def is_alnum(ch: str) -> bool {
        return self.is_alpha(ch) or self.is_digit(ch);
    }

    def is_whitespace(ch: str) -> bool {
        return ch == " " or ch == "\t" or ch == "\r" or ch == "\n";
    }

    # -------------------------------------------------------------------------
    # Skip Whitespace and Comments
    # -------------------------------------------------------------------------
    def skip_whitespace {
        while not self.at_end() and self.is_whitespace(self.current()) {
            self.advance();
        }
    }

    def skip_line_comment {
        while not self.at_end() and self.current() != "\n" {
            self.advance();
        }
    }

    def skip_block_comment -> bool {
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
                return True;
            }
            self.advance();
        }

        self.error("Unterminated block comment", start_line, start_col, start_pos);
        return False;
    }

    def skip_whitespace_and_comments {
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

    # -------------------------------------------------------------------------
    # Token Scanning
    # -------------------------------------------------------------------------
    def scan_identifier -> Token {
        start_line = self.line;
        start_col = self.col;
        start_pos = self.pos;

        value = "";
        while not self.at_end() and self.is_alnum(self.current()) {
            value += self.advance();
        }

        # Check for keyword
        kind = lookup_keyword(value);
        if kind is not None {
            return self.make_token(kind, value, start_line, start_col, start_pos);
        }

        return self.make_token(TokenKind.NAME, value, start_line, start_col, start_pos);
    }

    def scan_number -> Token {
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
                while not self.at_end() and self.is_hex_digit(self.current()) {
                    value += self.advance();
                }
                return self.make_token(kind, value, start_line, start_col, start_pos);
            } elif self.current() == "b" or self.current() == "B" {
                value += self.advance();
                kind = TokenKind.BIN;
                while not self.at_end()
                and (self.current() == "0" or self.current() == "1") {
                    value += self.advance();
                }
                return self.make_token(kind, value, start_line, start_col, start_pos);
            } elif self.current() == "o" or self.current() == "O" {
                value += self.advance();
                kind = TokenKind.OCT;
                while not self.at_end()
                and self.current() >= "0"
                and self.current() <= "7" {
                    value += self.advance();
                }
                return self.make_token(kind, value, start_line, start_col, start_pos);
            }
        }

        # Scan integer part
        while not self.at_end() and self.is_digit(self.current()) {
            value += self.advance();
        }

        # Check for decimal point
        if self.current() == "." and self.is_digit(self.peek()) {
            kind = TokenKind.FLOAT;
            value += self.advance();  # .
            while not self.at_end() and self.is_digit(self.current()) {
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
            while not self.at_end() and self.is_digit(self.current()) {
                value += self.advance();
            }
        }

        return self.make_token(kind, value, start_line, start_col, start_pos);
    }

    def scan_string(quote: str) -> Token {
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
        return self.make_token(
            TokenKind.ERROR, value, start_line, start_col, start_pos
        );
    }

    def scan_fstring(prefix: str) -> Token {
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

    def scan_fstring_content -> Token {
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
                    return self.make_token(
                        end_kind,
                        quote + quote + quote,
                        start_line,
                        start_col,
                        start_pos
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
                    self.error(
                        "Unterminated f-string", start_line, start_col, start_pos
                    );
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
        return self.make_token(
            TokenKind.ERROR, value, start_line, start_col, start_pos
        );
    }

    def get_fstring_text_kind(mode: LexerMode) -> TokenKind {
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

    def get_fstring_end_kind(mode: LexerMode) -> TokenKind {
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

    def scan_fstring_expr_token -> Token {
        self.skip_whitespace_and_comments();

        start_line = self.line;
        start_col = self.col;
        start_pos = self.pos;

        ch = self.current();

        # Track brace depth
        if ch == "{" {
            self.fstring_brace_depth += 1;
            self.advance();
            return self.make_token(
                TokenKind.LBRACE, "{", start_line, start_col, start_pos
            );
        }

        if ch == "}" {
            self.fstring_brace_depth -= 1;
            self.advance();
            if self.fstring_brace_depth == 0 {
                # End of f-string expression, pop back to f-string content mode
                self.pop_mode();
            }
            return self.make_token(
                TokenKind.RBRACE, "}", start_line, start_col, start_pos
            );
        }

        # Check for conversion specifier !s, !r, !a
        if ch == "!" and self.peek() in ["s", "r", "a", "S", "R", "A"] {
            self.advance();
            conv = self.advance();
            return self.make_token(
                TokenKind.CONV, "!" + conv, start_line, start_col, start_pos
            );
        }

        # Check for format spec colon
        if ch == ":" {
            self.advance();
            return self.make_token(
                TokenKind.COLON, ":", start_line, start_col, start_pos
            );
        }

        # Otherwise, scan a regular token
        return self.scan_regular_token();
    }

    def scan_regular_token -> Token {
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

    def scan_pynline -> Token {
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

        self.error(
            "Unterminated inline Python block", start_line, start_col, start_pos
        );
        return self.make_token(TokenKind.ERROR, code, start_line, start_col, start_pos);
    }

    def scan_operator -> Token {
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
            return self.make_token(
                TokenKind.EE, "==", start_line, start_col, start_pos
            );
        }
        if self.match_string("!=") {
            return self.make_token(
                TokenKind.NE, "!=", start_line, start_col, start_pos
            );
        }
        if self.match_string("<=") {
            return self.make_token(
                TokenKind.LTE, "<=", start_line, start_col, start_pos
            );
        }
        if self.match_string(">=") {
            return self.make_token(
                TokenKind.GTE, ">=", start_line, start_col, start_pos
            );
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
        if self.match_string("?.") {
            return self.make_token(
                TokenKind.NULL_OK, "?.", start_line, start_col, start_pos
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
        if self.match_string("-:") {
            return self.make_token(
                TokenKind.ARROW_R_P1, "-:", start_line, start_col, start_pos
            );
        }
        if self.match_string(":-") {
            return self.make_token(
                TokenKind.ARROW_L_P2, ":-", start_line, start_col, start_pos
            );
        }
        if self.match_string("+:") {
            return self.make_token(
                TokenKind.CARROW_R_P1, "+:", start_line, start_col, start_pos
            );
        }
        if self.match_string(":+") {
            return self.make_token(
                TokenKind.CARROW_L_P2, ":+", start_line, start_col, start_pos
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
            return self.make_token(
                TokenKind.JSX_FRAG_OPEN, "<>", start_line, start_col, start_pos
            );
        }
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
                return self.make_token(
                    TokenKind.LBRACE, "{", start_line, start_col, start_pos
                );

            case "}":
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
                return self.make_token(
                    TokenKind.LT, "<", start_line, start_col, start_pos
                );

            case ">":
                return self.make_token(
                    TokenKind.GT, ">", start_line, start_col, start_pos
                );

            case "=":
                return self.make_token(
                    TokenKind.EQ, "=", start_line, start_col, start_pos
                );

            case "@":
                return self.make_token(
                    TokenKind.DECOR_OP, "@", start_line, start_col, start_pos
                );

            case "`":
                return self.make_token(
                    TokenKind.TYPE_OP, "`", start_line, start_col, start_pos
                );

        }

        # Unknown character
        self.error(f"Unexpected character: '{ch}'", start_line, start_col, start_pos);
        return self.make_token(TokenKind.ERROR, ch, start_line, start_col, start_pos);
    }

    # -------------------------------------------------------------------------
    # Main Tokenization
    # -------------------------------------------------------------------------
    def next_token -> Token {
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

        # String
        if ch == "\"" or ch == "'" {
            return self.scan_string(ch);
        }

        # Operators and delimiters
        return self.scan_operator();
    }

    def tokenize -> list[Token] {
        tokens: list[Token] = [];

        while True {
            token = self.next_token();
            tokens.append(token);
            if token.kind == TokenKind.EOF {
                break;
            }
        }

        return tokens;
    }

    def has_errors -> bool {
        return len(self.errors) > 0;
    }
}

# =============================================================================
# Convenience Function
# =============================================================================
def tokenize(
    source: str, file_path: str = "<input>"
) -> tuple[list[Token], list[LexerError]] {
    lexer = Lexer(source=source, file_path=file_path);
    tokens = lexer.tokenize();
    return (tokens, lexer.errors);
}
