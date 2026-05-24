"""Hand-written lexer for Jac.

This lexer converts source code into a stream of tokens. It is designed
to be native-compilation friendly with no runtime reflection.
"""

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
    FSTRING_DQ = "fstring_dq",  # Inside f"..."
    FSTRING_SQ = "fstring_sq",  # Inside f'...'
    FSTRING_TDQ = "fstring_tdq",  # Inside f"""..."""
    FSTRING_TSQ = "fstring_tsq",  # Inside f'''...'''
    FSTRING_EXPR = "fstring_expr",  # Inside {...} in f-string
    JSX_TAG = "jsx_tag",  # Inside <Tag ...>
    JSX_CONTENT = "jsx_content"  # Between JSX tags
}

obj Lexer {
    has source: str,
        file_path: str = "<input>",
        pos: int = 0,  # byte offset into the UTF-8 source (Rust/Go/Zig model)
        line: int = 1,
        col: int = 1,  # 1-based code-point column
        _source_len: int = 0,  # byte length of the source
        # UTF-8 byte view + a pure-ASCII fast-path flag. For ASCII source
        # (the entire compiler bootstrap and ~all real code) byte offset ==
        # code-point index, so scanning stays on the plain str path with zero
        # overhead. Only non-ASCII source takes the rune-aware byte path.
        #
        # `_enc` is typed `str` because `str.encode()` is typed as returning
        # `str` (native strings are already a UTF-8 i8* buffer; the Python
        # backend holds the real `bytes` object). Both backends index, slice
        # and decode it as raw UTF-8 bytes identically.
        _enc: str = "",
        _ascii: bool = True,
        error_count: int = 0,
        mode_stack: list[LexerMode] = [],
        fstring_brace_depth: int = 0,  # Track nested braces in f-string expressions
        fstring_brace_depth_stack: list[int] = [],  # Stack for nested f-string brace depth
        jsx_depth: int = 0,  # Track nested JSX elements
        jsx_brace_depth: int = 0,  # Track nested braces in JSX expressions
        jsx_brace_depth_stack: list[int] = [],  # Stack for nested JSX brace depth
        jsx_closing_tag: bool = False,  # True when scanning a closing tag </...>
        prev_token_kind:
            TokenKind | None = None,  # Previous token kind for JSX disambiguation
        comments: list[CommentData] = [],
        # Structured lexer diagnostics (errors + warnings), marshal-safe so the
        # native lexer can surface them; replayed into `prog` by parser.parse().
        diags: list[LexDiag] = [],
        # JSX `{...}` slot tracking (statement-position JSX disambiguation).
        # A slot body is a statement region: a bare `<Tag>` after `}` or a
        # sibling JSX close tag must lex as JSX, not as a `<` comparison.
        _brace_depth: int = 0,  # running { } nesting depth
        _paren_depth: int = 0,  # running ( ) nesting depth
        _bracket_depth: int = 0,  # running [ ] nesting depth
        _view_body_depths: list[int] = [];  # brace depths at which slot bodies open

    # Mode management
    def push_mode(mode: LexerMode);
    def pop_mode -> LexerMode | None;
    def current_mode -> LexerMode;
    def in_fstring -> bool;
    def in_jsx -> bool;
    def prev_is_value -> bool;
    def in_view_body -> bool;
    def _track_view_context(tok: Token);
    # Character access
    def current -> str;
    def peek(offset: int = 1) -> str;
    def advance -> str;
    def at_end -> bool;
    def match_char(expected: str) -> bool;
    def match_string(expected: str) -> bool;
    # UTF-8 helpers (byte-offset, rune-aware). Identical results in the Python
    # and native backends; see field docs above.
    def _char_at(byte_idx: int) -> str;
    def _rune_width(byte_idx: int) -> int;
    def _width_of(lead: int) -> int;
    def _slice(a: int, c: int) -> str;
    # Location tracking
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

def tokenize(source: str, file_path: str = "<input>") -> tuple[list[Token], int] {
    lexer = Lexer(source=source, file_path=file_path);
    tokens = lexer.tokenize();
    return (tokens, lexer.error_count);
}

# Full tokenization surface used by parser.parse(): returns the captured
# comments and structured diagnostics in addition to tokens, so the entire
# lex result crosses the native boundary as marshal-safe data (no reliance on
# reading lexer instance state, which is unavailable for the native engine).
def tokenize_full(
    source: str, file_path: str = "<input>"
) -> tuple[list[Token], list[CommentData], list[LexDiag], int] {
    lexer = Lexer(source=source, file_path=file_path);
    tokens = lexer.tokenize();
    return (tokens, lexer.comments, lexer.diags, lexer.error_count);
}
