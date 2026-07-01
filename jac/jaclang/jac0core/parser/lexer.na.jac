import from .tokens {
    Token,
    TokenKind,
    SourceLoc,
    LexDiag,
    CommentData,
    lookup_keyword,
    KEYWORDS
}

enum LexerMode {
    NORMAL = "normal",
    FSTRING_DQ = "fstring_dq",
    FSTRING_SQ = "fstring_sq",
    FSTRING_TDQ = "fstring_tdq",
    FSTRING_TSQ = "fstring_tsq",
    FSTRING_EXPR = "fstring_expr",
    JSX_TAG = "jsx_tag",
    JSX_CONTENT = "jsx_content"
}

obj Lexer {
    has source: str,
        file_path: str = "<input>",
        pos: int = 0,
        line: int = 1,
        col: int = 1,
        _source_len: int = 0,
        _enc: bytes = b"",
        _ascii: bool = True,
        error_count: int = 0,
        mode_stack: list[LexerMode] = [],
        fstring_brace_depth: int = 0,
        fstring_brace_depth_stack: list[int] = [],
        jsx_depth: int = 0,
        jsx_brace_depth: int = 0,
        jsx_brace_depth_stack: list[int] = [],
        jsx_closing_tag: bool = False,
        prev_token_kind: TokenKind | None = None,
        comments: list[CommentData] = [],
        diags: list[LexDiag] = [],
        _brace_depth: int = 0,
        _paren_depth: int = 0,
        _bracket_depth: int = 0,
        _view_body_depths: list[int] = [];

    def push_mode(mode: LexerMode);
    def pop_mode -> LexerMode | None;
    def current_mode -> LexerMode;
    def in_jsx -> bool;
    def prev_is_value -> bool;
    def in_view_body -> bool;
    def _track_view_context(tok: Token);
    def current -> str;
    def peek(offset: int = 1) -> str;
    def advance -> str;
    def at_end -> bool;
    def match_char(expected: str) -> bool;
    def match_string(expected: str) -> bool;
    def _char_at(byte_idx: int) -> str;
    def _rune_width(byte_idx: int) -> int;
    def _width_of(lead: int) -> int;
    def _slice(a: int, c: int) -> str;
    def make_loc(start_line: int, start_col: int, start_pos: int) -> SourceLoc;
    def make_token(
        kind: TokenKind, value: str, start_line: int, start_col: int, start_pos: int
    ) -> Token;

    def error(
        message: str,
        start_line: int,
        start_col: int,
        start_pos: int,
        code_str: str = ""
    );

    def warning(
        message: str,
        start_line: int,
        start_col: int,
        start_pos: int,
        code_str: str = ""
    );

    def is_digit(ch: str) -> bool;
    def is_hex_digit(ch: str) -> bool;
    def is_alpha(ch: str) -> bool;
    def is_alnum(ch: str) -> bool;
    def is_whitespace(ch: str) -> bool;
    def skip_whitespace;
    def skip_line_comment;
    def skip_block_comment -> bool;
    def skip_whitespace_and_comments;
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
    def scan_jsx_open_start -> Token;
    def scan_jsx_tag_token -> Token;
    def scan_jsx_content -> Token;
    def scan_regular_token -> Token;
    def scan_pynline -> Token;
    def scan_operator -> Token;
    def next_token -> Token;
    def tokenize -> list[Token];
}

def tokenize(source: str, file_path: str = "<input>") -> tuple[list[Token], int] {
    lexer = Lexer(source=source, file_path=file_path);
    tokens = lexer.tokenize();
    return (tokens, lexer.error_count);
}

def tokenize_full(
    source: str, file_path: str = "<input>"
) -> tuple[list[Token], list[CommentData], list[LexDiag], int] {
    lexer = Lexer(source=source, file_path=file_path);
    tokens = lexer.tokenize();
    return (tokens, lexer.comments, lexer.diags, lexer.error_count);
}
