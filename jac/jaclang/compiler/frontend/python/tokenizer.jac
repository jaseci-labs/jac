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

glob TABSIZE: int = 8,
     MAXINDENT: int = 100;

# ---------------- tokenizer state ----------------
obj string_field {
    has paren: int,
        in_spec: bool = False,
        spec_started: bool = False;
}

obj string_mode {
    has quote: str,
        qlen: int,
        raw: bool,
        template: bool = False,
        lineno: int = 1,
        col_offset: int = 0,
        resume: bool = True,
        fields: list[string_field] = [];
}

obj tok_state {
    has source: str,
        pos: int = 0,
        lineno: int = 1,
        col_offset: int = 0,
        line_start: int = 0,
        filename: str = "<unknown>",
        exec_input: bool = False,
        single_input: bool = False,
        type_comments: bool = False,
        extra_tokens: bool = False,
        refill: any = None,
        blankline: bool = False,
        done: bool = False,
        eof_reached: bool = False,
        error: tok_diag | None = None,
        at_bol: bool = True,
        indent: int = 0,
        indstack: list[int] = [0],
        altindstack: list[int] = [0],
        pending: int = 0,
        paren_level: int = 0,
        paren_stack: list[str] = [],
        comments: dict[int, list[tuple[int, int]]] = {},
        string_modes: list[string_mode] = [];
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
            spelling=st.source[st.line_start:st.pos] if st.extra_tokens else "",
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
    while i < len(st.source) {
        ch = st.source[i];
        if ch == "\n" or ch == "\r" {
            return False;
        }
        if ch == "#" {
            while i < len(st.source) {
                ch2 = st.source[i];
                if ch2 == "\n" or ch2 == "\r" {
                    break;
                }
                i = i + 1;
            }
            st.pos = i;
            return True;
        }
        if ch != " " and ch != "\t" and ch != "\f" {
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
            while pos < len(st.source) and st.source[pos] in " \t" {
                pos += 1;
            }
        } elif pos < len(st.source) and st.source[pos] == ch {
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
        ch = st.source[st.pos];
        if ch == " " {
            col = col + 1;
            altcol += 1;
            st.pos = st.pos + 1;
            st.col_offset = st.col_offset + 1;
            continue;
        }
        if ch == "\t" {
            col = (col // TABSIZE + 1) * TABSIZE;
            altcol += 1;
            st.pos = st.pos + 1;
            st.col_offset = st.col_offset + 1;
            continue;
        }
        if ch == "\f" {
            col = 0;
            altcol = 0;
            st.pos = st.pos + 1;
            st.col_offset = st.col_offset + 1;
            continue;
        }
        if st.source.startswith("\\\n", st.pos) {
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
    if st.pos >= len(st.source) {
        return;
    }
    ch = st.source[st.pos];
    if ch == "\r" {
        st.pos = st.pos + 1;
        if st.pos < len(st.source) and st.source[st.pos] == "\n" {
            st.pos = st.pos + 1;
        }
    } elif ch == "\n" {
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
    if st.pos < len(st.source) {
        ch = st.source[st.pos];
        if ch == "#" {
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
        if ch == "\n" or ch == "\r" {
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

def _is_id_start(ch: str) -> bool {
    if ch >= "a" and ch <= "z" {
        return True;
    }
    if ch >= "A" and ch <= "Z" {
        return True;
    }
    if ch == "_" {
        return True;
    }
    return ch.isidentifier();
}

def _is_id_continue(ch: str) -> bool {
    if _is_id_start(ch) {
        return True;
    }
    if ch >= "0" and ch <= "9" {
        return True;
    }
    return ch != "" and ("_" + ch).isidentifier();
}

def:priv _is_digit(ch: str) -> bool {
    return ch >= "0" and ch <= "9";
}

def _has_source(st: tok_state) -> bool {
    if st.pos < len(st.source) {
        return True;
    }
    return st.refill is not None and bool(st.refill());
}

def _peek(st: tok_state) -> str {
    if not _has_source(st) {
        st.eof_reached = True;
        return "";
    }
    return st.source[st.pos];
}

def _advance(st: tok_state) -> str {
    if not _has_source(st) {
        return "";
    }
    ch = st.source[st.pos];
    st.pos = st.pos + 1;
    if ch == "\n" {
        st.lineno += 1;
        st.col_offset = 0;
        st.line_start = st.pos;
    } else {
        # Python AST columns are UTF-8 byte offsets, even for decoded source.
        point = ord(ch);
        st.col_offset += 1
            if point < 128
            else (2 if point < 2048 else (3 if point < 65536 else 4));
    }
    return ch;
}

def _match_operator(st: tok_state) -> tok_token | None {
    rest = st.source[st.pos:st.pos + 3];
    if st.pos + 1 >= len(st.source) {
        st.eof_reached = True;
    }
    if st.string_modes and st.string_modes[-1].fields {
        field = st.string_modes[-1].fields[-1];
        if st.paren_level == field.paren and rest.startswith(":=") {
            # At the field boundary ':' begins a format specifier; a walrus
            # expression needs its own parentheses.
            rest = ":";
        }
    }
    # Longest match first (CPython _PyToken_ThreeChars / TwoChars / OneChar).
    if len(rest) >= 3 {
        spell = rest[0:3];
        if spell in EXACT_TOKEN_TYPES {
            start_col = st.col_offset;
            st.pos = st.pos + 3;
            st.col_offset = st.col_offset + 3;
            return tok_token(
                tok_type=EXACT_TOKEN_TYPES[spell],
                spelling=spell,
                lineno=st.lineno,
                col_offset=start_col,
                end_lineno=st.lineno,
                end_col_offset=st.col_offset
            );
        }
    }
    if len(rest) >= 2 {
        spell = rest[0:2];
        if spell in EXACT_TOKEN_TYPES {
            if st.pos + 2 >= len(st.source) {
                st.eof_reached = True;
            }
            start_col = st.col_offset;
            st.pos = st.pos + 2;
            st.col_offset = st.col_offset + 2;
            return tok_token(
                tok_type=EXACT_TOKEN_TYPES[spell],
                spelling=spell,
                lineno=st.lineno,
                col_offset=start_col,
                end_lineno=st.lineno,
                end_col_offset=st.col_offset
            );
        }
    }
    if len(rest) >= 1 {
        spell = rest[0:1];
        if spell not in EXACT_TOKEN_TYPES
            and (spell == "\\" or not spell.isprintable() or ord(spell) >= 128) {
            return None;
        }
        typ = exact_token_type(spell);
        start_col = st.col_offset;
        st.pos = st.pos + 1;
        st.col_offset = st.col_offset + 1;
        return tok_token(
            tok_type=typ,
            spelling=spell,
            lineno=st.lineno,
            col_offset=start_col,
            end_lineno=st.lineno,
            end_col_offset=st.col_offset
        );
    }
    return None;
}

def _read_number(st: tok_state) -> tok_token | tok_diag {
    start = st.pos;
    start_col = st.col_offset;
    based = False;
    ch = _peek(st);
    if ch == "0" {
        _advance(st);
        nxt = _peek(st);
        if nxt == "x"
            or nxt == "X"
            or nxt == "b"
            or nxt == "B"
            or nxt == "o"
            or nxt == "O" {
            based = True;
            _advance(st);
            while _has_source(st) {
                c = _peek(st);
                if c == "_" {
                    _advance(st);
                    continue;
                }
                if _is_digit(c) or c >= "a" and c <= "f" or c >= "A" and c <= "F" {
                    _advance(st);
                    continue;
                }
                break;
            }
        } else {
            while _has_source(st) {
                c = _peek(st);
                if c == "_" {
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
            if c == "_" {
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
        if _peek(st) == "." {
            _advance(st);
            while _has_source(st) {
                c = _peek(st);
                if c == "_" {
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
        if c == "e" or c == "E" {
            _advance(st);
            c2 = _peek(st);
            if c2 == "+" or c2 == "-" {
                _advance(st);
            }
            while _has_source(st) {
                c3 = _peek(st);
                if c3 == "_" {
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
        if jc == "j" or jc == "J" {
            _advance(st);
        }
    }
    spell = st.source[start:st.pos];
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
            if st.source[st.pos:end] == keyword
                and (end == len(st.source) or not _is_id_continue(st.source[end])) {
                import from jaclang.compiler.frontend.python.compiler_diagnostics {
                    syntax_warning
                }
                keyword_boundary = True;
                syntax_warning(
                    f"invalid {kind} literal", st.filename, st.lineno, start_col
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
        if not _is_id_continue(c) and not (st.extra_tokens and ord(c) >= 128) {
            break;
        }
        _advance(st);
    }
    spell = st.source[start:st.pos];
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

def _is_string_prefix_char(ch: str) -> bool {
    if ch == "b" or ch == "B" {
        return True;
    }
    if ch == "r" or ch == "R" {
        return True;
    }
    if ch == "f" or ch == "F" {
        return True;
    }
    if ch in ("t", "T", "u", "U") {
        return True;
    }
    return False;
}

def _is_string_start(st: tok_state) -> bool {
    ch = _peek(st);
    if ch == "'" or ch == "\"" {
        return True;
    }
    if not _is_string_prefix_char(ch) {
        return False;
    }
    p = st.pos + 1;
    while p < len(st.source) {
        c = st.source[p];
        if _is_string_prefix_char(c) {
            p = p + 1;
            continue;
        }
        return c == "'" or c == "\"";
    }
    return False;
}

def _string_syntax_error(st: tok_state, msg: str, start_col: int) -> tok_diag {
    st.eof_reached = st.pos >= len(st.source)
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
    if not mode.raw
        and _peek(st) in ("{", "}")
        and (len(text) - len(text.rstrip("\\"))) % 2 {
        metadata = "escape:" + _peek(st);
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
    buf = "";
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
        if qlen == 1 and ch in ("\n", "\r") {
            return _string_syntax_error(
                st,
                ("t-string" if mode.template else "f-string")
                    + ": newlines are not allowed in format specifiers",
                start_col
            );
        }
        if ch == "{" or ch == "}" {
            if len(buf) > 0 or (ch == "}" and not mode.fields[-1].spec_started) {
                mode.fields[-1].spec_started = True;
                mode.resume = True;
                return _fstring_emit_middle(
                    st, buf, start_lineno, start_col, st.col_offset
                );
            }
            # Let the operator path emit LBRACE (nested field) or RBRACE
            # (field terminator) so the field stack tracks nested format specs.
            return None;
        }
        if ch == "\\" {
            buf += _advance(st);
            if not mode.raw and st.source.startswith("N{", st.pos) {
                while _has_source(st) {
                    if st.source.startswith(mode.quote * mode.qlen, st.pos) {
                        break;
                    }
                    escaped = _advance(st);
                    buf += escaped;
                    if escaped == "}" {
                        break;
                    }
                }
            } elif st.pos < len(st.source) and _peek(st) not in ("{", "}") {
                buf += _advance(st);
            }
            continue;
        }
        buf = buf + ch;
        _advance(st);
    }
    return _string_syntax_error(
        st, ("t-string" if mode.template else "f-string") + ": expecting '}'", start_col
    );
}

def _fstring_next_segment(st: tok_state) -> tok_token | tok_diag | None {
    mode = st.string_modes[-1];
    mode.resume = False;
    if mode.fields and mode.fields[-1].in_spec {
        return _fstring_scan_format_spec(st);
    }
    quote = mode.quote;
    qlen = mode.qlen;
    raw = mode.raw;
    start_lineno = st.lineno;
    start_col = st.col_offset;
    buf = "";
    while _has_source(st) {
        ch = _peek(st);
        if qlen == 1 {
            if ch == quote {
                end_col = st.col_offset;
                if len(buf) > 0 {
                    mode.resume = True;
                    return _fstring_emit_middle(
                        st, buf, start_lineno, start_col, end_col
                    );
                }
                _advance(st);
                return _fstring_emit_end(st, quote, start_lineno, start_col);
            }
            if ch == "\n" or ch == "\r" {
                return _string_syntax_error(
                    st, "EOL while scanning string literal", start_col
                );
            }
        } else {
            if ch == quote
                and st.pos + 1 < len(st.source)
                and st.source[st.pos + 1] == quote
                and st.pos + 2 < len(st.source)
                and st.source[st.pos + 2] == quote {
                end_col = st.col_offset;
                if len(buf) > 0 {
                    mode.resume = True;
                    return _fstring_emit_middle(
                        st, buf, start_lineno, start_col, end_col
                    );
                }
                j = 0;
                while j < qlen {
                    _advance(st);
                    j = j + 1;
                }
                triple = quote + quote + quote;
                return _fstring_emit_end(st, triple, start_lineno, start_col);
            }
        }
        if ch == "{" and st.pos + 1 < len(st.source) and st.source[st.pos + 1] == "{" {
            buf = buf + "{";
            _advance(st);
            end_col = st.col_offset;
            _advance(st);
            mode.resume = True;
            return _fstring_emit_middle(st, buf, start_lineno, start_col, end_col);
        }
        if ch == "}" and st.pos + 1 < len(st.source) and st.source[st.pos + 1] == "}" {
            buf = buf + "}";
            _advance(st);
            end_col = st.col_offset;
            _advance(st);
            mode.resume = True;
            return _fstring_emit_middle(st, buf, start_lineno, start_col, end_col);
        }
        if ch == "}" {
            return _string_syntax_error(
                st,
                ("t-string" if mode.template else "f-string")
                    + ": single '}' is not allowed",
                start_col
            );
        }
        if ch == "{" {
            if len(buf) > 0 {
                end_col = st.col_offset;
                return _fstring_emit_middle(st, buf, start_lineno, start_col, end_col);
            }
            return None;
        }
        if ch == "\\" {
            buf += _advance(st);
            if not mode.raw and st.source.startswith("N{", st.pos) {
                while _has_source(st) {
                    if st.source.startswith(mode.quote * mode.qlen, st.pos) {
                        break;
                    }
                    escaped = _advance(st);
                    buf += escaped;
                    if escaped == "}" {
                        break;
                    }
                }
            } elif st.pos < len(st.source) and _peek(st) not in ("{", "}") {
                buf += _advance(st);
            }
            continue;
        }
        buf = buf + ch;
        _advance(st);
    }
    return _string_syntax_error(st, "EOL while scanning string literal", start_col);
}

def _read_fstring_start(
    st: tok_state, start: int, start_col: int, raw: bool, quote: str, qlen: int
) -> tok_token | tok_diag {
    spell = st.source[start:st.pos];
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
        if c == "r" or c == "R" {
            raw = True;
            _advance(st);
            continue;
        }
        if c == "f" or c == "F" {
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
    prefix = st.source[start:st.pos].lower();
    if prefix
        not in ("", "u", "r", "b", "br", "rb", "f", "fr", "rf", "t", "tr", "rt") {
        return _string_syntax_error(st, "string prefixes are incompatible", start_col);
    }
    quote = _peek(st);
    if quote != "'" and quote != "\"" {
        return _string_syntax_error(st, "invalid syntax", start_col);
    }
    qlen = 1;
    _advance(st);
    # Triple-quote only when the NEXT TWO chars are both the quote. For `''`/`""`
    # the second quote is the CLOSING quote of an empty single-quoted string, not
    # part of a 2-char opener (Python has no 2-quote delimiter).
    if _peek(st) == quote
        and st.pos + 1 < len(st.source)
        and st.source[st.pos + 1] == quote {
        _advance(st);
        _advance(st);
        qlen = 3;
    }
    if has_f or "t" in st.source[start:st.pos].lower() {
        return _read_fstring_start(st, start, start_col, raw, quote, qlen);
    }
    while _has_source(st) {
        ch = _peek(st);
        if qlen == 1 {
            if ch == quote {
                _advance(st);
                spell = st.source[start:st.pos];
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
            if ch == "\n" or ch == "\r" {
                return _string_syntax_error(
                    st,
                    "EOL while scanning string literal"
                        if st.string_modes and quote == st.string_modes[-1].quote
                        else "unterminated string literal",
                    start_col
                );
            }
            if ch == "\\" {
                # Backslash escapes the next char for TERMINATION scanning in raw
                # strings too (r'\'' is not closed by the escaped quote); the raw
                # flag only affects decoding, handled later.
                _advance(st);
                if st.pos < len(st.source) {
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
                if st.pos + i >= len(st.source) or st.source[st.pos + i] != quote {
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
                spell = st.source[start:st.pos];
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
        if ch == "\\" {
            _advance(st);
            if st.pos < len(st.source) {
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
    return tok_state(source=buf, filename=filename, exec_input=exec_input);
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
        if st.pos >= len(st.source) {
            break;
        }
        ch = _peek(st);
        if ch == " " or ch == "\t" or ch == "\f" {
            _advance(st);
            continue;
        }
        if ch == "#" {
            # Comment: consume to end of line (not the newline itself, which the
            # newline branch handles). Matches CPython's comment-then-NEWLINE.
            comment_start = st.col_offset;
            start_pos = st.pos;
            type_start = _type_comment_start(st);
            blankline = not st.source[st.line_start:st.pos].strip();
            while _has_source(st) and _peek(st) != "\n" and _peek(st) != "\r" {
                _advance(st);
            }
            st.comments.setdefault(st.lineno, []).append(
                (comment_start, st.col_offset)
            );
            if st.extra_tokens {
                return tok_token(
                    tok_type=COMMENT,
                    spelling=st.source[start_pos:st.pos],
                    lineno=st.lineno,
                    col_offset=comment_start,
                    end_lineno=st.lineno,
                    end_col_offset=st.col_offset
                );
            }
            if type_start >= 0 {
                payload = st.source[type_start:st.pos];
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
        if ch == "\\"
            and st.pos + 1 < len(st.source)
            and (st.source[st.pos + 1] == "\n" or st.source[st.pos + 1] == "\r") {
            # Explicit line continuation: backslash-newline joins physical lines,
            # emitting no NEWLINE and doing no indentation processing.
            _advance(st);
            if _peek(st) == "\r" {
                _advance(st);
                if _peek(st) == "\n" {
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
        if ch == "\n" {
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
        if ch == "\r" {
            start_col = st.col_offset;
            _advance(st);
            if _peek(st) == "\n" {
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
        if ch == "." {
            nxt = st.pos + 1;
            if nxt < len(st.source) and _is_digit(st.source[nxt]) {
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
        if _is_id_start(ch) or (st.extra_tokens and ord(ch) >= 128) {
            tok = _read_name(st);
            st.paren_level = st.paren_level + _track_paren_delta(tok.tok_type);
            return tok;
        }
        op = _match_operator(st);
        if op is not None {
            if op.spelling in ("(", "[", "{") {
                if len(st.paren_stack) >= 200 {
                    return _string_syntax_error(
                        st, "too many nested parentheses", op.col_offset
                    );
                }
                st.paren_stack.append(op.spelling);
            } elif op.spelling in (")", "]", "}") {
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
                if ch == "\\"
                else "invalid non-printable character U+" + format(ord(ch), "04X")
                    if not ch.isprintable()
                    else "invalid character in identifier",
            tok_loc_span(st.lineno, st.lineno, st.col_offset, st.col_offset + 1),
            st.filename
        );
        st.error = bad;
        st.done = True;
        st.eof_reached = ch.isprintable()
            and ch != "\\"
            and st.pos + 1 == len(st.source);
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
