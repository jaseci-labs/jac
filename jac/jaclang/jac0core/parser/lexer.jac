"""Hand-written lexer for Jac.

This lexer converts source code into a stream of tokens. It is designed
to be native-compilation friendly with no runtime reflection.
"""

import from .tokens { Token, TokenKind, SourceLoc, lookup_keyword, KEYWORDS }

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

obj LexerError {
    has message: str,
        loc: SourceLoc;

    def __str__ -> str {
        return f"LexerError at line {self.loc.line}, col {self.loc.col_start}: {self.message}";
    }
}

obj Lexer {
    has source: str,
        file_path: str = "<input>",
        pos: int = 0,
        line: int = 1,
        col: int = 1,
        _source_len: int = 0,
        errors: list[LexerError] = [],
        mode_stack: list[LexerMode] = [],
        fstring_brace_depth: int = 0,  # Track nested braces in f-string expressions
        fstring_brace_depth_stack: list[int] = [],  # Stack for nested f-string brace depth
        jsx_depth: int = 0,  # Track nested JSX elements
        jsx_brace_depth: int = 0,  # Track nested braces in JSX expressions
        jsx_brace_depth_stack: list[int] = [],  # Stack for nested JSX brace depth
        jsx_closing_tag: bool = False,  # True when scanning a closing tag </...>
        comments: list[tuple] = [];  # Captured comments: (value, line, end_line, col_start, col_end, pos_start, pos_end, is_block)

    # Mode management
    def push_mode(mode: LexerMode);
    def pop_mode -> LexerMode | None;
    def current_mode -> LexerMode;
    def in_fstring -> bool;
    def in_jsx -> bool;
    # Character access
    def current -> str;
    def peek(offset: int = 1) -> str;
    def advance -> str;
    def at_end -> bool;
    def match_char(expected: str) -> bool;
    def match_string(expected: str) -> bool;
    # Location tracking
    def make_loc(start_line: int, start_col: int, start_pos: int) -> SourceLoc;
    def make_token(
        kind: TokenKind, value: str, start_line: int, start_col: int, start_pos: int
    ) -> Token;

    def error(message: str, start_line: int, start_col: int, start_pos: int);
    # Character classification
    def is_digit(ch: str) -> bool;
    def is_hex_digit(ch: str) -> bool;
    def is_alpha(ch: str) -> bool;
    def is_alnum(ch: str) -> bool;
    def is_whitespace(ch: str) -> bool;
    # Skip whitespace and comments
    def skip_whitespace;
    def skip_line_comment;
    def skip_block_comment -> bool;
    def skip_whitespace_and_comments;
    # Token scanning
    def scan_identifier -> Token;
    def scan_kwesc_name -> Token;
    def scan_number -> Token;
    def scan_leading_dot_float -> Token;
    def scan_string(quote: str) -> Token;
    def scan_fstring(prefix: str) -> Token;
    def scan_fstring_content -> Token;
    def get_fstring_text_kind(mode: LexerMode) -> TokenKind;
    def get_fstring_end_kind(mode: LexerMode) -> TokenKind;
    def scan_fstring_expr_token -> Token;
    # JSX scanning
    def scan_jsx_open_start -> Token;
    def scan_jsx_tag_token -> Token;
    def scan_jsx_content -> Token;
    def scan_jsx_expr_token -> Token;
    def scan_regular_token -> Token;
    def scan_pynline -> Token;
    def scan_operator -> Token;
    # Main tokenization
    def next_token -> Token;
    def tokenize -> list[Token];
    def has_errors -> bool;
}

def tokenize(
    source: str, file_path: str = "<input>"
) -> tuple[list[Token], list[LexerError]] {
    lexer = Lexer(source=source, file_path=file_path);
    tokens = lexer.tokenize();
    return (tokens, lexer.errors);
}
