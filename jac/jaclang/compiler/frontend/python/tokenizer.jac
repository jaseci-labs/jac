"""Python scanner shared by the parser and public tokenization adapter.

Source decoding stays outside the scanner. An optional refill callback supplies
decoded lines for streaming tokenization; parsing uses an existing source string.
"""

import from jaclang.compiler.frontend.python.token_model {
    ENDMARKER,
    NAME,
    NUMBER,
    STRING,
    NEWLINE,
    INDENT,
    DEDENT,
    COMMENT,
    NL,
    ERRORTOKEN,
    TYPE_COMMENT,
    TYPE_IGNORE,
    LPAR,
    RPAR,
    LSQB,
    RSQB,
    LBRACE,
    RBRACE,
    COMMA,
    COLON,
    FSTRING_START,
    FSTRING_MIDDLE,
    FSTRING_END,
    TSTRING_START,
    TSTRING_MIDDLE,
    TSTRING_END,
    TOK_NO_COLUMN,
    EXACT_TOKEN_TYPES,
    exact_token_type,
    tok_token,
    tok_diag,
    mk_diag,
    tok_loc_span,
    tok_no_loc,
}

import from jaclang.runtime.python.characters {
    point_width,
    point_at,
    unicode_start,
    unicode_continue,
    unicode_printable
}

glob TABSIZE: int = 8,
     MAXINDENT: int = 100,
     # The scanner reads code points, as CPython's tok_nextc reads ints. This
     # one stands for "no more input" and matches no character.
     EOF_POINT: int = -1;

# Operator spellings packed into one int key, a byte per character, the way
# CPython's _PyToken_ThreeChars switches on (c1, c2, c3). Derived from
# EXACT_TOKEN_TYPES so the two tables cannot drift; the spellings are kept so
# an operator token reuses one string instead of decoding its bytes each time.
def _pack_operator(spelling: str) -> int {
    key = 0;
    shift = 0;
    for ch in spelling {
        key = key | (ord(ch) << shift);
        shift += 8;
    }
    return key;
}

glob OPERATOR_TYPES: dict[int, int] = {
         _pack_operator(spelling): kind
         for (spelling, kind) in EXACT_TOKEN_TYPES.items()
     },
     OPERATOR_SPELLINGS: dict[int, str] = {
         _pack_operator(spelling): spelling for spelling in EXACT_TOKEN_TYPES
     };

# Streaming input is supplied by the API boundary. The scanner itself calls a
# typed virtual method, rather than retaining a Python callable.
obj token_input {}

obj token_source(token_input) {
    def refill -> bool {
        return False;
    }
}

# ---------------- tokenizer state ----------------
obj string_field {
    has paren: int,
        in_spec: bool = False,
        spec_started: bool = False;
}

obj string_mode {
    has quote: int,
        qlen: int,
        raw: bool,
        template: bool = False,
        lineno: int = 1,
        col_offset: int = 0,
        resume: bool = True,
        fields: list[string_field] = [];
}

obj tok_state {
    has data: bytes,
        pos: int = 0,
        lineno: int = 1,
        col_offset: int = 0,
        line_start: int = 0,
        filename: str = "<unknown>",
        exec_input: bool = False,
        single_input: bool = False,
        type_comments: bool = False,
        extra_tokens: bool = False,
        input: token_source | None = None,
        blankline: bool = False,
        done: bool = False,
        eof_reached: bool = False,
        error: tok_diag | None = None,
        warnings: list[tok_diag] = [],
        at_bol: bool = True,
        indent: int = 0,
        indstack: list[int] = [0],
        altindstack: list[int] = [0],
        pending: int = 0,
        paren_level: int = 0,
        paren_stack: list[str] = [],
        comments: dict[int, list[tuple[int, int]]] = {},
        string_modes: list[string_mode] = [];

    # Streaming input releases the lines behind the scan between tokens. Only
    # the scan position and the current line start index into the buffer, and
    # an open string keeps its prefix for the fields it still has to resume.
    def discard_consumed {
        consumed = self.line_start;
        if consumed == 0 or self.string_modes {
            return;
        }
        self.data = self.data[consumed:];
        self.pos -= consumed;
        self.line_start = 0;
    }
}

# The byte `offset` places past the scan position, or EOF_POINT past the end.
def _byte_at(st: tok_state, offset: int) -> int {
    at = st.pos + offset;
    return st.data[at] if at < len(st.data) else EOF_POINT;
}

# Whether the next `count` bytes all equal `point`: a closing quote run.
def _at_run(st: tok_state, point: int, count: int) -> bool {
    i = 0;
    while i < count {
        if _byte_at(st, i) != point {
            return False;
        }
        i += 1;
    }
    return True;
}

def _indent_error(st: tok_state, msg: str, kind: str = "IndentationError") -> tok_diag {
    st.eof_reached = False;
    bad = mk_diag(
        kind,
        msg,
        tok_loc_span(st.lineno, st.lineno, st.col_offset, st.col_offset),
        st.filename
    );
    st.error = bad;
    st.done = True;
    return bad;
}

def _flush_pending_indent(st: tok_state) -> tok_token | None {
    if st.pending < 0 {
        st.pending = st.pending + 1;
        return tok_token(
            tok_type=DEDENT,
            spelling="",
            lineno=st.lineno,
            col_offset=st.col_offset if st.extra_tokens else TOK_NO_COLUMN,
            end_lineno=st.lineno,
            end_col_offset=st.col_offset if st.extra_tokens else TOK_NO_COLUMN
        );
    }
    if st.pending > 0 {
        st.pending = st.pending - 1;
        return tok_token(
            tok_type=INDENT,
            spelling=st.data[st.line_start:st.pos].decode("utf-8")
                if st.extra_tokens
                else "",
            lineno=st.lineno,
            col_offset=0 if st.extra_tokens else TOK_NO_COLUMN,
            end_lineno=st.lineno,
            end_col_offset=st.col_offset if st.extra_tokens else TOK_NO_COLUMN
        );
    }
    return None;
}

def _skip_comment_line(st: tok_state) -> bool {
    i = st.pos;
    while i < len(st.data) {
        c = st.data[i];
        if c == ord("\n") or c == ord("\r") {
            return False;
        }
        if c == ord("#") {
            while i < len(st.data) {
                c2 = st.data[i];
                if c2 == ord("\n") or c2 == ord("\r") {
                    break;
                }
                i = i + 1;
            }
            st.pos = i;
            return True;
        }
        if c != ord(" ") and c != ord("\t") and c != ord("\f") {
            return False;
        }
        i = i + 1;
    }
    return False;
}

# Spaces in the prefix match zero or more ASCII spaces/tabs, as in CPython.
def _type_comment_start(st: tok_state) -> int {
    if not st.type_comments {
        return -1;
    }
    pos = st.pos;
    for ch in "# type: " {
        if ch == " " {
            while pos < len(st.data)
                and (st.data[pos] == ord(" ") or st.data[pos] == ord("\t")) {
                pos += 1;
            }
        } elif pos < len(st.data) and st.data[pos] == ord(ch) {
            pos += 1;
        } else {
            return -1;
        }
    }
    return pos;
}

def _measure_indent(st: tok_state) -> tuple[int, int] {
    col = 0;
    altcol = 0;
    continuation_col = 0;
    while _has_source(st) {
        c = st.data[st.pos];
        if c == ord(" ") {
            col = col + 1;
            altcol += 1;
            st.pos = st.pos + 1;
            st.col_offset = st.col_offset + 1;
            continue;
        }
        if c == ord("\t") {
            col = (col // TABSIZE + 1) * TABSIZE;
            altcol += 1;
            st.pos = st.pos + 1;
            st.col_offset = st.col_offset + 1;
            continue;
        }
        if c == ord("\f") {
            col = 0;
            altcol = 0;
            st.pos = st.pos + 1;
            st.col_offset = st.col_offset + 1;
            continue;
        }
        if c == ord("\\") and _byte_at(st, 1) == ord("\n") {
            # The first nonzero indentation before a continuation determines
            # the logical line's indentation. Blank continuations stay blank.
            continuation_col = continuation_col or col;
            _advance(st);
            _advance(st);
            if not _has_source(st) {
                _string_syntax_error(st, "unexpected EOF while parsing", st.col_offset);
                st.eof_reached = True;
                break;
            }
            continue;
        }
        break;
    }
    return (continuation_col or col, continuation_col or altcol);
}

def _consume_bol_newline(st: tok_state) -> None {
    if st.pos >= len(st.data) {
        return;
    }
    c = st.data[st.pos];
    if c == ord("\r") {
        st.pos = st.pos + 1;
        if st.pos < len(st.data) and st.data[st.pos] == ord("\n") {
            st.pos = st.pos + 1;
        }
    } elif c == ord("\n") {
        st.pos = st.pos + 1;
    } else {
        return;
    }
    st.lineno = st.lineno + 1;
    st.col_offset = 0;
    st.line_start = st.pos;
    st.at_bol = True;
}

def _process_bol_indent(st: tok_state) -> int {
    # Returns 0 ok, 1 blank line consumed, -1 error.
    st.blankline = False;
    if st.paren_level > 0 {
        st.at_bol = False;
        return 0;
    }
    (col, altcol) = _measure_indent(st);
    if st.error is not None {
        return -1;
    }
    if st.pos < len(st.data) {
        c = st.data[st.pos];
        if c == ord("#") {
            if st.extra_tokens or _type_comment_start(st) >= 0 {
                st.at_bol = False;
                st.blankline = True;
                return 0;
            }
            if _skip_comment_line(st) {
                _consume_bol_newline(st);
                return 1;
            }
        }
        if c == ord("\n") or c == ord("\r") {
            if st.extra_tokens {
                st.at_bol = False;
                st.blankline = True;
                return 0;
            }
            _consume_bol_newline(st);
            return 1;
        }
    }
    _peek(st);
    cur = st.indstack[st.indent];
    if col == cur {
        if altcol != st.altindstack[st.indent] {
            _indent_error(
                st, "inconsistent use of tabs and spaces in indentation", "TabError"
            );
            return -1;
        }
        st.at_bol = False;
        return 0;
    }
    if col > cur {
        if st.indent + 1 >= MAXINDENT {
            _indent_error(st, "too many levels of indentation");
            return -1;
        }
        if altcol <= st.altindstack[st.indent] {
            _indent_error(
                st, "inconsistent use of tabs and spaces in indentation", "TabError"
            );
            return -1;
        }
        st.pending = st.pending + 1;
        st.indent = st.indent + 1;
        st.indstack.append(col);
        st.altindstack.append(altcol);
        st.at_bol = False;
        return 0;
    }
    while st.indent > 0 and col < st.indstack[st.indent] {
        st.pending = st.pending - 1;
        st.indent = st.indent - 1;
        st.indstack.pop();
        st.altindstack.pop();
    }
    if col != st.indstack[st.indent] {
        _indent_error(st, "unindent does not match any outer indentation level");
        return -1;
    }
    if altcol != st.altindstack[st.indent] {
        _indent_error(
            st, "inconsistent use of tabs and spaces in indentation", "TabError"
        );
        return -1;
    }
    st.at_bol = False;
    return 0;
}

def _track_paren_delta(tok_type: int) -> int {
    if tok_type == LPAR or tok_type == LSQB or tok_type == LBRACE {
        return 1;
    }
    if tok_type == RPAR or tok_type == RSQB or tok_type == RBRACE {
        return -1;
    }
    return 0;
}

def _is_id_start(c: int) -> bool {
    if c >= ord("a") and c <= ord("z") {
        return True;
    }
    if c >= ord("A") and c <= ord("Z") {
        return True;
    }
    if c == ord("_") {
        return True;
    }
    # XID_Start holds no other ASCII character, and EOF_POINT is none.
    return c >= 128 and unicode_start(c);
}

def _is_id_continue(c: int) -> bool {
    if _is_id_start(c) or _is_digit(c) {
        return True;
    }
    return c >= 128 and unicode_continue(c);
}

def:priv _is_digit(c: int) -> bool {
    return c >= ord("0") and c <= ord("9");
}

def _has_source(st: tok_state) -> bool {
    if st.pos < len(st.data) {
        return True;
    }
    return st.input is not None and st.input.refill();
}

def _peek(st: tok_state) -> int {
    if not _has_source(st) {
        st.eof_reached = True;
        return EOF_POINT;
    }
    return point_at(st.data, st.pos);
}

def _advance(st: tok_state) -> int {
    if not _has_source(st) {
        return EOF_POINT;
    }
    c = point_at(st.data, st.pos);
    width = point_width(st.data, st.pos);
    st.pos += width;
    if c == ord("\n") {
        st.lineno += 1;
        st.col_offset = 0;
        st.line_start = st.pos;
    } else {
        st.col_offset += width;
    }
    return c;
}

def _match_operator(st: tok_state) -> tok_token | None {
    c1 = _peek(st);
    if c1 >= 128 {
        return None;
    }
    if st.pos + 1 >= len(st.data) {
        st.eof_reached = True;
    }
    c2 = _byte_at(st, 1);
    c3 = _byte_at(st, 2);
    longest = 3;
    if st.string_modes and st.string_modes[-1].fields {
        field = st.string_modes[-1].fields[-1];
        if st.paren_level == field.paren and c1 == ord(":") and c2 == ord("=") {
            # At the field boundary ':' begins a format specifier; a walrus
            # expression needs its own parentheses.
            longest = 1;
        }
    }
    # Longest match first (CPython _PyToken_ThreeChars / TwoChars / OneChar).
    # Every operator is ASCII, so a following byte of 128 or more, or
    # EOF_POINT, can only fail to match.
    if longest >= 3 and c2 > 0 and c2 < 128 and c3 > 0 and c3 < 128 {
        key = c1 | (c2 << 8) | (c3 << 16);
        if key in OPERATOR_TYPES {
            return _operator_token(st, key, 3);
        }
    }
    if longest >= 2 and c2 > 0 and c2 < 128 {
        key = c1 | (c2 << 8);
        if key in OPERATOR_TYPES {
            if st.pos + 2 >= len(st.data) {
                st.eof_reached = True;
            }
            return _operator_token(st, key, 2);
        }
    }
    if c1 < 0 {
        return None;
    }
    if c1 in OPERATOR_TYPES {
        return _operator_token(st, c1, 1);
    }
    if c1 == ord("\\") or not unicode_printable(c1) {
        return None;
    }
    start_col = st.col_offset;
    st.pos = st.pos + 1;
    st.col_offset = st.col_offset + 1;
    return tok_token(
        tok_type=exact_token_type(chr(c1)),
        spelling=chr(c1),
        lineno=st.lineno,
        col_offset=start_col,
        end_lineno=st.lineno,
        end_col_offset=st.col_offset
    );
}

def _operator_token(st: tok_state, key: int, width: int) -> tok_token {
    start_col = st.col_offset;
    st.pos = st.pos + width;
    st.col_offset = st.col_offset + width;
    return tok_token(
        tok_type=OPERATOR_TYPES[key],
        spelling=OPERATOR_SPELLINGS[key],
        lineno=st.lineno,
        col_offset=start_col,
        end_lineno=st.lineno,
        end_col_offset=st.col_offset
    );
}

def _read_number(st: tok_state) -> tok_token | tok_diag {
    start = st.pos;
    start_col = st.col_offset;
    based = False;
    ch = _peek(st);
    if ch == ord("0") {
        _advance(st);
        nxt = _peek(st);
        if nxt == ord("x")
            or nxt == ord("X")
            or nxt == ord("b")
            or nxt == ord("B")
            or nxt == ord("o")
            or nxt == ord("O") {
            based = True;
            _advance(st);
            while _has_source(st) {
                c = _peek(st);
                if c == ord("_") {
                    _advance(st);
                    continue;
                }
                if _is_digit(c)
                    or c >= ord("a")
                    and c <= ord("f")
                    or c >= ord("A")
                    and c <= ord("F") {
                    _advance(st);
                    continue;
                }
                break;
            }
        } else {
            while _has_source(st) {
                c = _peek(st);
                if c == ord("_") {
                    _advance(st);
                    continue;
                }
                if _is_digit(c) {
                    _advance(st);
                    continue;
                }
                break;
            }
        }
    } else {
        while _has_source(st) {
            c = _peek(st);
            if c == ord("_") {
                _advance(st);
                continue;
            }
            if _is_digit(c) {
                _advance(st);
                continue;
            }
            break;
        }
    }
    if not based {
        # Fractional/exponent/imaginary apply to ANY decimal literal, including
        # zero-leading floats (0.0, 0.5, 0e10) — the '0' integer branch above only
        # reads the integer part.
        if _peek(st) == ord(".") {
            _advance(st);
            while _has_source(st) {
                c = _peek(st);
                if c == ord("_") {
                    _advance(st);
                    continue;
                }
                if _is_digit(c) {
                    _advance(st);
                    continue;
                }
                break;
            }
        }
        c = _peek(st);
        if c == ord("e") or c == ord("E") {
            _advance(st);
            c2 = _peek(st);
            if c2 == ord("+") or c2 == ord("-") {
                _advance(st);
            }
            while _has_source(st) {
                c3 = _peek(st);
                if c3 == ord("_") {
                    _advance(st);
                    continue;
                }
                if _is_digit(c3) {
                    _advance(st);
                    continue;
                }
                break;
            }
        }
        # Imaginary suffix on a decimal int/float (3j, 3.5j, 1e10j, 0.5j).
        jc = _peek(st);
        if jc == ord("j") or jc == ord("J") {
            _advance(st);
        }
    }
    spell = st.data[start:st.pos].decode("utf-8");
    if _is_id_start(_peek(st)) and not st.extra_tokens {
        kind = "decimal";
        if spell.lower().startswith("0x") {
            kind = "hexadecimal";
        } elif spell.lower().startswith("0o") {
            kind = "octal";
        } elif spell.lower().startswith("0b") {
            kind = "binary";
        } elif spell.endswith(("j", "J")) {
            kind = "imaginary";
        }
        keyword_boundary = False;
        for keyword in ("and", "else", "for", "if", "in", "is", "or", "not") {
            end = st.pos + len(keyword);
            if st.data[st.pos:end].decode("utf-8") == keyword
                and (
                    end == len(st.data) or not _is_id_continue(point_at(st.data, end))
                ) {
                keyword_boundary = True;
                st.warnings.append(
                    mk_diag(
                        "SyntaxWarning",
                        f"invalid {kind} literal",
                        tok_loc_span(st.lineno, st.lineno, start_col, st.col_offset),
                        st.filename
                    )
                );
                break;
            }
        }
        if not keyword_boundary {
            return _string_syntax_error(st, f"invalid {kind} literal", start_col);
        }
    }
    return tok_token(
        tok_type=NUMBER,
        spelling=spell,
        lineno=st.lineno,
        col_offset=start_col,
        end_lineno=st.lineno,
        end_col_offset=st.col_offset
    );
}

def _read_name(st: tok_state) -> tok_token {
    start = st.pos;
    start_col = st.col_offset;
    _advance(st);
    while _has_source(st) {
        c = _peek(st);
        if not _is_id_continue(c) and not (st.extra_tokens and c >= 128) {
            break;
        }
        _advance(st);
    }
    spell = st.data[start:st.pos].decode("utf-8");
    _peek(st);
    return tok_token(
        tok_type=NAME,
        spelling=spell,
        lineno=st.lineno,
        col_offset=start_col,
        end_lineno=st.lineno,
        end_col_offset=st.col_offset
    );
}

def _is_string_prefix_char(ch: int) -> bool {
    if ch == ord("b") or ch == ord("B") {
        return True;
    }
    if ch == ord("r") or ch == ord("R") {
        return True;
    }
    if ch == ord("f") or ch == ord("F") {
        return True;
    }
    if ch == ord("t") or ch == ord("T") or ch == ord("u") or ch == ord("U") {
        return True;
    }
    return False;
}

def _is_string_start(st: tok_state) -> bool {
    ch = _peek(st);
    if ch == ord("'") or ch == ord("\"") {
        return True;
    }
    if not _is_string_prefix_char(ch) {
        return False;
    }
    p = st.pos + 1;
    while p < len(st.data) {
        c = st.data[p];
        if _is_string_prefix_char(c) {
            p = p + 1;
            continue;
        }
        return c == ord("'") or c == ord("\"");
    }
    return False;
}

def _string_syntax_error(st: tok_state, msg: str, start_col: int) -> tok_diag {
    st.eof_reached = st.pos >= len(st.data)
        and (
            msg.startswith("unterminated")
            or msg == "EOL while scanning string literal"
            or "expecting '}'" in msg
            or "was never closed" in msg
        );
    line = st.lineno;
    if msg == "EOL while scanning string literal" and st.string_modes {
        mode = st.string_modes[-1];
        kind = "t-string" if mode.template else "f-string";
        if mode.fields {
            msg = kind + ": expecting '}'";
        } else {
            line = mode.lineno;
            start_col = mode.col_offset;
            msg = "unterminated "
                + ("triple-quoted " if mode.qlen == 3 else "")
                + kind
                + " literal";
        }
    }
    bad = mk_diag(
        "SyntaxError",
        msg,
        tok_loc_span(line, line, start_col, start_col + 1),
        st.filename
    );
    st.error = bad;
    st.done = True;
    return bad;
}

def _fstring_emit_middle(
    st: tok_state, text: str, lineno: int, col_offset: int, end_col_offset: int
) -> tok_token {
    mode = st.string_modes[-1];
    metadata = "raw" if mode.raw else "";
    following = _peek(st);
    if not mode.raw
        and (following == ord("{") or following == ord("}"))
        and (len(text) - len(text.rstrip("\\"))) % 2 {
        metadata = "escape:" + chr(following);
    }
    return tok_token(
        tok_type=TSTRING_MIDDLE if mode.template else FSTRING_MIDDLE,
        metadata=metadata,
        spelling=text,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=st.lineno,
        end_col_offset=end_col_offset
    );
}

# The source text from `start` to the scan position. A string middle is always
# one contiguous run of source, so it is read as a slice rather than rebuilt a
# character at a time.
def _source_text(st: tok_state, start: int) -> str {
    return st.data[start:st.pos].decode("utf-8");
}

def _fstring_emit_end(
    st: tok_state, spelling: str, lineno: int, col_offset: int
) -> tok_token {
    mode = st.string_modes.pop();
    tok = tok_token(
        tok_type=TSTRING_END if mode.template else FSTRING_END,
        spelling=spelling,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=st.lineno,
        end_col_offset=st.col_offset
    );
    st.paren_level = st.paren_level + _track_paren_delta(FSTRING_END);
    return tok;
}

def _fstring_scan_format_spec(st: tok_state) -> tok_token | tok_diag | None {
    # Format-spec mode (PEP 701): after the terminating ':' of a replacement
    # field, text up to a brace scans as a string middle. Braces begin/end
    # nested fields; literal brace doubling applies outside format specs.
    mode = st.string_modes[-1];
    quote = mode.quote;
    qlen = mode.qlen;
    start_lineno = st.lineno;
    start_col = st.col_offset;
    seg = st.pos;
    while _has_source(st) {
        ch = _peek(st);
        if ch == quote {
            return _string_syntax_error(
                st,
                ("t-string" if mode.template else "f-string")
                    + ": expecting '}', or format specs",
                start_col
            );
        }
        if qlen == 1 and (ch == ord("\n") or ch == ord("\r")) {
            return _string_syntax_error(
                st,
                ("t-string" if mode.template else "f-string")
                    + ": newlines are not allowed in format specifiers",
                start_col
            );
        }
        if ch == ord("{") or ch == ord("}") {
            if st.pos > seg or (ch == ord("}") and not mode.fields[-1].spec_started) {
                mode.fields[-1].spec_started = True;
                mode.resume = True;
                return _fstring_emit_middle(
                    st, _source_text(st, seg), start_lineno, start_col, st.col_offset
                );
            }
            # Let the operator path emit LBRACE (nested field) or RBRACE
            # (field terminator) so the field stack tracks nested format specs.
            return None;
        }
        if ch == ord("\\") {
            _escape_in_fstring(st, mode);
            continue;
        }
        _advance(st);
    }
    return _string_syntax_error(
        st, ("t-string" if mode.template else "f-string") + ": expecting '}'", start_col
    );
}

# Step over a backslash escape inside an f-string or t-string middle. A named
# escape runs to its closing brace, stopping short of the closing quote; any
# other escape takes one more character, except a brace, which stays for the
# field scanner.
def _escape_in_fstring(st: tok_state, mode: string_mode) {
    _advance(st);
    if not mode.raw and _byte_at(st, 0) == ord("N") and _byte_at(st, 1) == ord("{") {
        while _has_source(st) {
            if _at_run(st, mode.quote, mode.qlen) {
                break;
            }
            if _advance(st) == ord("}") {
                break;
            }
        }
    } elif st.pos < len(st.data) {
        following = _peek(st);
        if following != ord("{") and following != ord("}") {
            _advance(st);
        }
    }
}

def _fstring_next_segment(st: tok_state) -> tok_token | tok_diag | None {
    mode = st.string_modes[-1];
    mode.resume = False;
    if mode.fields and mode.fields[-1].in_spec {
        return _fstring_scan_format_spec(st);
    }
    quote = mode.quote;
    qlen = mode.qlen;
    start_lineno = st.lineno;
    start_col = st.col_offset;
    seg = st.pos;
    while _has_source(st) {
        ch = _peek(st);
        if qlen == 1 {
            if ch == quote {
                end_col = st.col_offset;
                if st.pos > seg {
                    mode.resume = True;
                    return _fstring_emit_middle(
                        st, _source_text(st, seg), start_lineno, start_col, end_col
                    );
                }
                _advance(st);
                return _fstring_emit_end(st, chr(quote), start_lineno, start_col);
            }
            if ch == ord("\n") or ch == ord("\r") {
                return _string_syntax_error(
                    st, "EOL while scanning string literal", start_col
                );
            }
        } elif ch == quote and _byte_at(st, 1) == quote and _byte_at(st, 2) == quote {
            end_col = st.col_offset;
            if st.pos > seg {
                mode.resume = True;
                return _fstring_emit_middle(
                    st, _source_text(st, seg), start_lineno, start_col, end_col
                );
            }
            j = 0;
            while j < qlen {
                _advance(st);
                j = j + 1;
            }
            return _fstring_emit_end(st, chr(quote) * 3, start_lineno, start_col);
        }
        if (ch == ord("{") or ch == ord("}")) and _byte_at(st, 1) == ch {
            # A doubled brace is one literal brace: the middle ends after the
            # first, and the second is consumed with it.
            _advance(st);
            text = _source_text(st, seg);
            end_col = st.col_offset;
            _advance(st);
            mode.resume = True;
            return _fstring_emit_middle(st, text, start_lineno, start_col, end_col);
        }
        if ch == ord("}") {
            return _string_syntax_error(
                st,
                ("t-string" if mode.template else "f-string")
                    + ": single '}' is not allowed",
                start_col
            );
        }
        if ch == ord("{") {
            if st.pos > seg {
                end_col = st.col_offset;
                return _fstring_emit_middle(
                    st, _source_text(st, seg), start_lineno, start_col, end_col
                );
            }
            return None;
        }
        if ch == ord("\\") {
            _escape_in_fstring(st, mode);
            continue;
        }
        _advance(st);
    }
    return _string_syntax_error(st, "EOL while scanning string literal", start_col);
}

def _read_fstring_start(
    st: tok_state, start: int, start_col: int, raw: bool, quote: int, qlen: int
) -> tok_token | tok_diag {
    spell = st.data[start:st.pos].decode("utf-8");
    if len(st.string_modes) >= 150 {
        return _string_syntax_error(st, "too many nested f-strings", start_col);
    }
    mode = string_mode(
        quote=quote,
        qlen=qlen,
        raw=raw,
        template="t" in spell.lower(),
        lineno=st.lineno,
        col_offset=start_col
    );
    st.string_modes.append(mode);
    tok = tok_token(
        tok_type=TSTRING_START if mode.template else FSTRING_START,
        spelling=spell,
        lineno=st.lineno,
        col_offset=start_col,
        end_lineno=st.lineno,
        end_col_offset=st.col_offset
    );
    st.paren_level = st.paren_level + _track_paren_delta(FSTRING_START);
    return tok;
}

def _read_string(st: tok_state) -> tok_token | tok_diag {
    start = st.pos;
    start_lineno = st.lineno;
    start_col = st.col_offset;
    raw = False;
    has_f = False;
    while _has_source(st) {
        c = _peek(st);
        if c == ord("r") or c == ord("R") {
            raw = True;
            _advance(st);
            continue;
        }
        if c == ord("f") or c == ord("F") {
            has_f = True;
            _advance(st);
            continue;
        }
        if _is_string_prefix_char(c) {
            _advance(st);
            continue;
        }
        break;
    }
    prefix = st.data[start:st.pos].decode("utf-8").lower();
    if prefix
        not in ("", "u", "r", "b", "br", "rb", "f", "fr", "rf", "t", "tr", "rt") {
        return _string_syntax_error(st, "string prefixes are incompatible", start_col);
    }
    quote = _peek(st);
    if quote != ord("'") and quote != ord("\"") {
        return _string_syntax_error(st, "invalid syntax", start_col);
    }
    qlen = 1;
    _advance(st);
    # Triple-quote only when the NEXT TWO chars are both the quote. For `''`/`""`
    # the second quote is the CLOSING quote of an empty single-quoted string, not
    # part of a 2-char opener (Python has no 2-quote delimiter).
    if _peek(st) == quote and _byte_at(st, 1) == quote {
        _advance(st);
        _advance(st);
        qlen = 3;
    }
    if has_f or "t" in st.data[start:st.pos].decode("utf-8").lower() {
        return _read_fstring_start(st, start, start_col, raw, quote, qlen);
    }
    while _has_source(st) {
        ch = _peek(st);
        if qlen == 1 {
            if ch == quote {
                _advance(st);
                spell = st.data[start:st.pos].decode("utf-8");
                tok = tok_token(
                    tok_type=STRING,
                    spelling=spell,
                    lineno=start_lineno,
                    col_offset=start_col,
                    end_lineno=st.lineno,
                    end_col_offset=st.col_offset
                );
                st.paren_level = st.paren_level + _track_paren_delta(STRING);
                return tok;
            }
            if ch == ord("\n") or ch == ord("\r") {
                return _string_syntax_error(
                    st,
                    "EOL while scanning string literal"
                        if st.string_modes and quote == st.string_modes[-1].quote
                        else "unterminated string literal",
                    start_col
                );
            }
            if ch == ord("\\") {
                # Backslash escapes the next char for TERMINATION scanning in raw
                # strings too (r'\'' is not closed by the escaped quote); the raw
                # flag only affects decoding, handled later.
                _advance(st);
                if st.pos < len(st.data) {
                    _advance(st);
                }
                continue;
            }
            _advance(st);
            continue;
        }
        if ch == quote {
            matched = 1;
            i = 1;
            while i < qlen {
                if _byte_at(st, i) != quote {
                    matched = 0;
                    break;
                }
                i = i + 1;
            }
            if matched {
                j = 0;
                while j < qlen {
                    _advance(st);
                    j = j + 1;
                }
                spell = st.data[start:st.pos].decode("utf-8");
                tok = tok_token(
                    tok_type=STRING,
                    spelling=spell,
                    lineno=start_lineno,
                    col_offset=start_col,
                    end_lineno=st.lineno,
                    end_col_offset=st.col_offset
                );
                st.paren_level = st.paren_level + _track_paren_delta(STRING);
                return tok;
            }
        }
        # Raw strings preserve escapes in the value, but an escaped quote still
        # cannot begin the closing delimiter, including for triple quotes.
        if ch == ord("\\") {
            _advance(st);
            if st.pos < len(st.data) {
                _advance(st);
            }
            continue;
        }
        _advance(st);
    }
    return _string_syntax_error(
        st,
        "EOL while scanning string literal"
            if st.string_modes and quote == st.string_modes[-1].quote
            else "unterminated string literal",
        start_col
    );
}

def tokenizer_from_string(source: str, filename: str, exec_input: bool) -> tok_state {
    # File input gets a terminal newline before scanning; eval/single input
    # must retain physical EOF so incomplete-input flags can distinguish it.
    buf = source.replace("\r\n", "\n").replace("\r", "\n");
    if exec_input and buf and not buf.endswith("\n") {
        buf += "\n";
    }
    return tok_state(
        data=buf.encode("utf-8"), filename=filename, exec_input=exec_input
    );
}

def _endmarker_lineno(st: tok_state) -> int {
    lineno = st.lineno;
    if st.col_offset == 0 and lineno > 1 {
        return lineno - 1;
    }
    return lineno;
}

def _tokenizer_next(st: tok_state) -> tok_token | tok_diag {
    if st.done {
        em = _endmarker_lineno(st);
        return tok_token(
            tok_type=ENDMARKER,
            spelling="",
            lineno=em,
            col_offset=TOK_NO_COLUMN,
            end_lineno=em,
            end_col_offset=TOK_NO_COLUMN
        );
    }
    if st.error is not None {
        return st.error;
    }
    pending = _flush_pending_indent(st);
    if pending is not None {
        return pending;
    }
    if st.string_modes and st.string_modes[-1].resume {
        fseg = _fstring_next_segment(st);
        if fseg is not None {
            if isinstance(fseg, tok_diag) {
                return fseg;
            }
            return fseg as tok_token;
        }
    }
    while _has_source(st) {
        if st.at_bol {
            bol = _process_bol_indent(st);
            if bol < 0 {
                return st.error as tok_diag;
            }
            if bol > 0 {
                pending = _flush_pending_indent(st);
                if pending is not None {
                    return pending;
                }
                continue;
            }
            pending = _flush_pending_indent(st);
            if pending is not None {
                return pending;
            }
        }
        if st.pos >= len(st.data) {
            break;
        }
        ch = _peek(st);
        if ch == ord(" ") or ch == ord("\t") or ch == ord("\f") {
            _advance(st);
            continue;
        }
        if ch == ord("#") {
            # Comment: consume to end of line (not the newline itself, which the
            # newline branch handles). Matches CPython's comment-then-NEWLINE.
            comment_start = st.col_offset;
            start_pos = st.pos;
            type_start = _type_comment_start(st);
            blankline = not st.data[st.line_start:st.pos].decode("utf-8").strip();
            while _has_source(st)
                and _peek(st) != ord("\n")
                and _peek(st) != ord("\r") {
                _advance(st);
            }
            st.comments.setdefault(st.lineno, []).append(
                (comment_start, st.col_offset)
            );
            if st.extra_tokens {
                return tok_token(
                    tok_type=COMMENT,
                    spelling=st.data[start_pos:st.pos].decode("utf-8"),
                    lineno=st.lineno,
                    col_offset=comment_start,
                    end_lineno=st.lineno,
                    end_col_offset=st.col_offset
                );
            }
            if type_start >= 0 {
                payload = st.data[type_start:st.pos].decode("utf-8");
                kind = TYPE_COMMENT;
                if payload.startswith("ignore")
                    and (
                        len(payload) == 6
                        or (ord(payload[6]) < 128 and not payload[6].isalnum())
                    ) {
                    kind = TYPE_IGNORE;
                    payload = payload[6:];
                    type_start += 6;
                }
                token = tok_token(
                    tok_type=kind,
                    spelling=payload,
                    lineno=st.lineno,
                    col_offset=comment_start + type_start - start_pos,
                    end_lineno=st.lineno,
                    end_col_offset=st.col_offset
                );
                if kind == TYPE_IGNORE and blankline {
                    # The tokenizer includes the consumed (or implicit final)
                    # newline in standalone ignore tags.
                    token.spelling += "\n";
                    _consume_bol_newline(st);
                }
                return token;
            }
            continue;
        }
        if ch == ord("\\")
            and (_byte_at(st, 1) == ord("\n") or _byte_at(st, 1) == ord("\r")) {
            # Explicit line continuation: backslash-newline joins physical lines,
            # emitting no NEWLINE and doing no indentation processing.
            _advance(st);
            if _peek(st) == ord("\r") {
                _advance(st);
                if _peek(st) == ord("\n") {
                    _advance(st);
                }
            } else {
                _advance(st);
            }
            if not _has_source(st) {
                bad = _string_syntax_error(
                    st, "unexpected EOF while parsing", st.col_offset
                );
                st.eof_reached = True;
                return bad;
            }
            continue;
        }
        if ch == ord("\n") {
            start_col = st.col_offset;
            _advance(st);
            if st.extra_tokens {
                st.at_bol = True;
                return tok_token(
                    tok_type=NL if st.blankline or st.paren_level > 0 else NEWLINE,
                    spelling="\n",
                    lineno=st.lineno - 1,
                    col_offset=start_col,
                    end_lineno=st.lineno - 1,
                    end_col_offset=start_col + 1
                );
            }
            if st.paren_level > 0 {
                # Implicit line join inside (), [], {}: newline is non-significant
                # (NL), no NEWLINE token and no indentation processing.
                continue;
            }
            st.at_bol = True;
            return tok_token(
                tok_type=NEWLINE,
                spelling="",
                lineno=st.lineno - 1,
                col_offset=start_col,
                end_lineno=st.lineno - 1,
                end_col_offset=start_col
            );
        }
        if ch == ord("\r") {
            start_col = st.col_offset;
            _advance(st);
            if _peek(st) == ord("\n") {
                _advance(st);
            }
            if st.paren_level > 0 {
                continue;
            }
            st.at_bol = True;
            return tok_token(
                tok_type=NEWLINE,
                spelling="",
                lineno=st.lineno - 1,
                col_offset=start_col,
                end_lineno=st.lineno - 1,
                end_col_offset=start_col
            );
        }
        # CPython tokenizes '.' as NUMBER when digits follow (.5 == 0.5);
        # anything else ('.', '..', '...') falls through to the operator path.
        if ch == ord(".") {
            nxt = st.pos + 1;
            if nxt < len(st.data) and _is_digit(st.data[nxt]) {
                return _read_number(st);
            }
        }
        if _is_digit(ch) {
            return _read_number(st);
        }
        # String-start MUST precede identifier: a prefixed string (b'', r'', u'',
        # f'') begins with an id-start char; _is_string_start only matches when a
        # quote follows the prefix, so a plain identifier still falls through.
        if _is_string_start(st) {
            str_tok = _read_string(st);
            if isinstance(str_tok, tok_diag) {
                return str_tok;
            }
            return str_tok as tok_token;
        }
        if _is_id_start(ch) or (st.extra_tokens and ch >= 128) {
            tok = _read_name(st);
            st.paren_level = st.paren_level + _track_paren_delta(tok.tok_type);
            return tok;
        }
        op = _match_operator(st);
        if op is not None {
            if op.tok_type == LPAR or op.tok_type == LSQB or op.tok_type == LBRACE {
                if len(st.paren_stack) >= 200 {
                    return _string_syntax_error(
                        st, "too many nested parentheses", op.col_offset
                    );
                }
                st.paren_stack.append(op.spelling);
            } elif op.tok_type == RPAR
                or op.tok_type == RSQB
                or op.tok_type == RBRACE {
                opener = {")": "(", "]": "[", "}": "{"}[op.spelling];
                if (not st.paren_stack or st.paren_stack[-1] != opener)
                    and not st.extra_tokens {
                    at_field = st.string_modes
                        and st.string_modes[-1].fields
                        and st.paren_level == st.string_modes[-1].fields[-1].paren;
                    message = "unmatched '" + op.spelling + "'";
                    if st.paren_stack and not at_field {
                        message = "closing parenthesis '"
                            + op.spelling
                            + "' does not match opening parenthesis '"
                            + st.paren_stack[-1]
                            + "'";
                    } elif at_field {
                        message = (
                            "t-string" if st.string_modes[-1].template else "f-string"
                        )
                            + ": "
                            + message;
                    }
                    return _string_syntax_error(st, message, op.col_offset);
                }
                if st.paren_stack {
                    st.paren_stack.pop();
                }
            }

            if st.string_modes {
                mode = st.string_modes[-1];
                op.metadata = "t-string" if mode.template else "f-string";
                literal = not mode.fields or mode.fields[-1].in_spec;
                if op.tok_type == LBRACE and literal {
                    if len(mode.fields) >= 3 {
                        return _string_syntax_error(
                            st, "f-string: expressions nested too deeply", op.col_offset
                        );
                    }
                    mode.fields.append(string_field(paren=st.paren_level + 1));
                } elif mode.fields and st.paren_level == mode.fields[-1].paren {
                    if op.tok_type == COLON {
                        mode.fields[-1].in_spec = True;
                        mode.resume = True;
                    } elif op.tok_type == RBRACE {
                        mode.fields.pop();
                        mode.resume = not mode.fields or mode.fields[-1].in_spec;
                        if mode.fields and mode.fields[-1].in_spec {
                            # A nested field starts a new format-spec segment.
                            # Preserve its empty trailing middle token so
                            # untokenize does not insert text between `}}`.
                            mode.fields[-1].spec_started = False;
                        }
                    }
                }
            }
            st.paren_level = st.paren_level + _track_paren_delta(op.tok_type);
            return op;
        }
        bad = mk_diag(
            "SyntaxError",
            "unexpected character after line continuation character"
                if ch == ord("\\")
                else "invalid non-printable character U+" + format(ch, "04X")
                    if not unicode_printable(ch)
                    else "invalid character in identifier",
            tok_loc_span(st.lineno, st.lineno, st.col_offset, st.col_offset + 1),
            st.filename
        );
        st.error = bad;
        st.done = True;
        st.eof_reached = unicode_printable(ch)
            and ch != ord("\\")
            and st.pos + 1 == len(st.data);
        return bad;
    }
    st.eof_reached = True;
    if st.string_modes and st.string_modes[-1].fields {
        return _string_syntax_error(st, "'{' was never closed", st.col_offset);
    }
    if st.at_bol {
        if _process_bol_indent(st) < 0 {
            return st.error as tok_diag;
        }
    }
    pending = _flush_pending_indent(st);
    if pending is not None {
        return pending;
    }
    st.done = True;
    em = _endmarker_lineno(st);
    return tok_token(
        tok_type=ENDMARKER,
        spelling="",
        lineno=em,
        col_offset=TOK_NO_COLUMN,
        end_lineno=em,
        end_col_offset=TOK_NO_COLUMN
    );
}

def tokenizer_next(st: tok_state) -> tok_token | tok_diag {
    token = _tokenizer_next(st);
    if isinstance(token, tok_token) {
        token.level = st.paren_level;
    }
    return token;
}

def tokenize_all(
    source: str, filename: str, exec_input: bool
) -> list[tok_token | tok_diag] {
    st = tokenizer_from_string(source, filename, exec_input);
    out: list[tok_token | tok_diag] = [];
    while True {
        tok = tokenizer_next(st);
        out.append(tok);
        if isinstance(tok, tok_diag) {
            break;
        }
        if tok.tok_type == ENDMARKER {
            break;
        }
    }
    return out;
}
