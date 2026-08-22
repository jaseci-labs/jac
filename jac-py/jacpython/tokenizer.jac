# P0.5 source-string tokenizer (PLAN.md) — expression eval slice.
#
# Re-hosts the CPython 3.14 UTF-8 string tokenizer state machine for the P4
# expression fixtures. Full indentation/f-string/encoding coverage lands in
# follow-on slices; this module accepts UTF-8 source text directly (file I/O
# and decoding stay outside the scanner).
#
# Product module: imports token_model only.

import from token_model {
    ENDMARKER,
    NAME,
    NUMBER,
    STRING,
    NEWLINE,
    INDENT,
    DEDENT,
    ERRORTOKEN,
    LPAR,
    RPAR,
    LSQB,
    RSQB,
    LBRACE,
    RBRACE,
    COMMA,
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
obj tok_state {
    has source: str,
        pos: int = 0,
        lineno: int = 1,
        col_offset: int = 0,
        line_start: int = 0,
        filename: str = "<unknown>",
        exec_input: bool = False,
        done: bool = False,
        error: tok_diag | None = None,
        at_bol: bool = True,
        indent: int = 0,
        indstack: list[int] = [0],
        pending: int = 0,
        paren_level: int = 0;
}

def _indent_error(st: tok_state, msg: str) -> tok_diag {
    bad = mk_diag(
        "IndentationError",
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
            col_offset=TOK_NO_COLUMN,
            end_lineno=st.lineno,
            end_col_offset=TOK_NO_COLUMN
        );
    }
    if st.pending > 0 {
        st.pending = st.pending - 1;
        return tok_token(
            tok_type=INDENT,
            spelling="",
            lineno=st.lineno,
            col_offset=TOK_NO_COLUMN,
            end_lineno=st.lineno,
            end_col_offset=TOK_NO_COLUMN
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

def _measure_indent(st: tok_state) -> int {
    col = 0;
    while st.pos < len(st.source) {
        ch = st.source[st.pos];
        if ch == " " {
            col = col + 1;
            st.pos = st.pos + 1;
            st.col_offset = st.col_offset + 1;
            continue;
        }
        if ch == "\t" {
            col = (col // TABSIZE + 1) * TABSIZE;
            st.pos = st.pos + 1;
            st.col_offset = st.col_offset + 1;
            continue;
        }
        if ch == "\f" {
            col = 0;
            st.pos = st.pos + 1;
            st.col_offset = st.col_offset + 1;
            continue;
        }
        break;
    }
    return col;
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
    if not st.exec_input or st.paren_level > 0 {
        st.at_bol = False;
        return 0;
    }
    col = _measure_indent(st);
    if st.pos < len(st.source) {
        ch = st.source[st.pos];
        if ch == "#" {
            if _skip_comment_line(st) {
                _consume_bol_newline(st);
                return 1;
            }
        }
        if ch == "\n" or ch == "\r" {
            _consume_bol_newline(st);
            return 1;
        }
    }
    # EOF with only whitespace on this logical line.
    if st.pos >= len(st.source) {
        st.at_bol = False;
        return 0;
    }
    cur = st.indstack[st.indent];
    if col == cur {
        st.at_bol = False;
        return 0;
    }
    if col > cur {
        if st.indent + 1 >= MAXINDENT {
            _indent_error(st, "maximum indentation depth exceeded");
            return -1;
        }
        st.pending = st.pending + 1;
        st.indent = st.indent + 1;
        st.indstack.append(col);
        st.at_bol = False;
        return 0;
    }
    while st.indent > 0 and col < st.indstack[st.indent] {
        st.pending = st.pending - 1;
        st.indent = st.indent - 1;
        st.indstack.pop();
    }
    if col != st.indstack[st.indent] {
        _indent_error(st, "unindent does not match any outer indentation level");
        return -1;
    }
    st.at_bol = False;
    return 0;
}

def _begin_eof_dedents(st: tok_state) -> None {
    if not st.exec_input {
        return;
    }
    while st.indent > 0 {
        st.pending = st.pending - 1;
        st.indent = st.indent - 1;
        st.indstack.pop();
    }
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
    return False;
}

def _is_id_continue(ch: str) -> bool {
    if _is_id_start(ch) {
        return True;
    }
    if ch >= "0" and ch <= "9" {
        return True;
    }
    return False;
}

def _is_digit(ch: str) -> bool {
    return ch >= "0" and ch <= "9";
}

def _peek(st: tok_state) -> str {
    if st.pos >= len(st.source) {
        return "";
    }
    return st.source[st.pos];
}

def _advance(st: tok_state) -> str {
    if st.pos >= len(st.source) {
        return "";
    }
    ch = st.source[st.pos];
    st.pos = st.pos + 1;
    st.col_offset = st.col_offset + 1;
    return ch;
}

def _match_operator(st: tok_state) -> tok_token | None {
    rest = st.source[st.pos:];
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

def _read_number(st: tok_state) -> tok_token {
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
            while st.pos < len(st.source) {
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
            while st.pos < len(st.source) {
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
        while st.pos < len(st.source) {
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
            while st.pos < len(st.source) {
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
            while st.pos < len(st.source) {
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
    while st.pos < len(st.source) {
        c = _peek(st);
        if not _is_id_continue(c) {
            break;
        }
        _advance(st);
    }
    spell = st.source[start:st.pos];
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
    if ch == "u" or ch == "U" {
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
    bad = mk_diag(
        "SyntaxError",
        msg,
        tok_loc_span(st.lineno, st.lineno, start_col, st.col_offset),
        st.filename
    );
    st.error = bad;
    st.done = True;
    return bad;
}

def _read_string(st: tok_state) -> tok_token | tok_diag {
    start = st.pos;
    start_col = st.col_offset;
    raw = False;
    while st.pos < len(st.source) {
        c = _peek(st);
        if c == "r" or c == "R" {
            raw = True;
            _advance(st);
            continue;
        }
        if _is_string_prefix_char(c) {
            _advance(st);
            continue;
        }
        break;
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
    while st.pos < len(st.source) {
        ch = _peek(st);
        if qlen == 1 {
            if ch == quote {
                _advance(st);
                spell = st.source[start:st.pos];
                tok = tok_token(
                    tok_type=STRING,
                    spelling=spell,
                    lineno=st.lineno,
                    col_offset=start_col,
                    end_lineno=st.lineno,
                    end_col_offset=st.col_offset
                );
                st.paren_level = st.paren_level + _track_paren_delta(STRING);
                return tok;
            }
            if ch == "\n" or ch == "\r" {
                return _string_syntax_error(
                    st, "EOL while scanning string literal", start_col
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
                    lineno=st.lineno,
                    col_offset=start_col,
                    end_lineno=st.lineno,
                    end_col_offset=st.col_offset
                );
                st.paren_level = st.paren_level + _track_paren_delta(STRING);
                return tok;
            }
        }
        if ch == "\\" and not raw {
            _advance(st);
            if st.pos < len(st.source) {
                _advance(st);
            }
            continue;
        }
        _advance(st);
    }
    return _string_syntax_error(st, "EOL while scanning string literal", start_col);
}

def tokenizer_from_string(source: str, filename: str, exec_input: bool) -> tok_state {
    # Eval/single input: ensure a trailing newline like decode_str(single=1).
    buf = source;
    if not exec_input {
        if len(buf) == 0 or buf[len(buf) - 1] != "\n" {
            buf = buf + "\n";
        }
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

def tokenizer_next(st: tok_state) -> tok_token | tok_diag {
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
    while st.pos < len(st.source) {
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
        ch = _peek(st);
        if ch == " " or ch == "\t" or ch == "\f" {
            _advance(st);
            continue;
        }
        if ch == "#" {
            # Comment: consume to end of line (not the newline itself, which the
            # newline branch handles). Matches CPython's comment-then-NEWLINE.
            while st.pos < len(st.source) and _peek(st) != "\n" and _peek(st) != "\r" {
                _advance(st);
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
            st.line_start = st.pos;
            st.lineno = st.lineno + 1;
            st.col_offset = 0;
            continue;
        }
        if ch == "\n" {
            start_col = st.col_offset;
            _advance(st);
            st.line_start = st.pos;
            st.lineno = st.lineno + 1;
            st.col_offset = 0;
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
            st.line_start = st.pos;
            st.lineno = st.lineno + 1;
            st.col_offset = 0;
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
        if _is_digit(ch) {
            tok = _read_number(st);
            st.paren_level = st.paren_level + _track_paren_delta(tok.tok_type);
            return tok;
        }
        # String-start MUST precede identifier: a prefixed string (b'', r'', u'',
        # f'') begins with an id-start char; _is_string_start only matches when a
        # quote follows the prefix, so a plain identifier still falls through.
        if _is_string_start(st) {
            tok = _read_string(st);
            if isinstance(tok, tok_diag) {
                return tok;
            }
            return tok as tok_token;
        }
        if _is_id_start(ch) {
            tok = _read_name(st);
            st.paren_level = st.paren_level + _track_paren_delta(tok.tok_type);
            return tok;
        }
        op = _match_operator(st);
        if op is not None {
            st.paren_level = st.paren_level + _track_paren_delta(op.tok_type);
            return op;
        }
        bad = mk_diag(
            "SyntaxError",
            "invalid character in identifier",
            tok_loc_span(st.lineno, st.lineno, st.col_offset, st.col_offset + 1),
            st.filename
        );
        st.error = bad;
        st.done = True;
        return bad;
    }
    _begin_eof_dedents(st);
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
