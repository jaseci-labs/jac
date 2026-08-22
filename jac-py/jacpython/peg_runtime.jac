# P0.6 na-clean PEG runtime (PLAN.md).
#
# Token mark/reset, per-position memoization, left-recursion growth hooks,
# keyword/soft-keyword promotion, invalid-rule two-pass gating, and stable
# syntax-error locations. Generated parsers (grammar2jac, P0.7) call these
# primitives with explicit rule dispatch — no lambdas or function-value tables.
#
# Product module: imports token_model + tokenizer only.

import from token_model {
    ENDMARKER,
    NAME,
    NUMBER,
    NEWLINE,
    INDENT,
    DEDENT,
    NL,
    COMMENT,
    ERRORTOKEN,
    NT_OFFSET,
    TOK_NO_LINE,
    TOK_NO_COLUMN,
    is_whitespace_token,
    tok_diag,
    mk_diag,
    tok_loc_span,
    tok_no_loc,
    tok_token,
}
import from tokenizer { tok_state, tokenizer_from_string, tokenizer_next }

# Keyword token ids start at 500 in CPython's pegen generator (parser_generator.py).
glob PEG_KEYWORD_TYPE_BASE: int = 500;

# ---------------- parser token + memo ----------------
obj peg_memo {
    has rule_type: int,
        end_mark: int,
        result: object | None = None,
        next: peg_memo | None = None;
}

obj peg_token {
    has tok_type: int,
        spelling: str,
        lineno: int,
        col_offset: int,
        end_lineno: int,
        end_col_offset: int,
        level: int = 0,
        metadata: str | None = None,
        memo_head: peg_memo | None = None;
}

obj peg_keyword_entry {
    has spelling: str,
        tok_type: int;
}

obj peg_memo_hit {
    has hit: bool = False,
        result: object | None = None;
}

# ---------------- parser state ----------------
obj peg_parser {
    has tok: tok_state,
        tokens: list[peg_token] = [],
        mark: int = 0,
        keyword_lists: list[list[peg_keyword_entry]] = [],
        soft_keywords: list[str] = [],
        call_invalid_rules: bool = False,
        error_indicator: bool = False,
        error: tok_diag | None = None,
        known_err_token: peg_token | None = None,
        filename: str = "<unknown>",
        parsing_started: bool = False;
}

def peg_token_from_tok(tok: tok_token) -> peg_token {
    return peg_token(
        tok_type=tok.tok_type,
        spelling=tok.spelling,
        lineno=tok.lineno,
        col_offset=tok.col_offset,
        end_lineno=tok.end_lineno,
        end_col_offset=tok.end_col_offset,
        level=tok.level,
        metadata=tok.metadata
    );
}

def peg_token_loc(tok: peg_token) -> tok_loc {
    return tok_loc_span(tok.lineno, tok.end_lineno, tok.col_offset, tok.end_col_offset);
}

def _keyword_type_for(p: peg_parser, spelling: str) -> int {
    n = len(spelling);
    if n >= len(p.keyword_lists) {
        return NAME;
    }
    entries = p.keyword_lists[n];
    i = 0;
    while i < len(entries) {
        e = entries[i];
        if e.spelling == spelling {
            return e.tok_type;
        }
        i = i + 1;
    }
    return NAME;
}

def _is_soft_keyword(p: peg_parser, spelling: str) -> bool {
    i = 0;
    while i < len(p.soft_keywords) {
        if p.soft_keywords[i] == spelling {
            return True;
        }
        i = i + 1;
    }
    return False;
}

def peg_parser_from_source(source: str, filename: str, exec_input: bool) -> peg_parser {
    st = tokenizer_from_string(source, filename, exec_input);
    return peg_parser(tok=st, filename=filename);
}

def peg_set_keywords(p: peg_parser, lists: list[list[peg_keyword_entry]]) {
    p.keyword_lists = lists;
}

def peg_set_soft_keywords(p: peg_parser, words: list[str]) {
    p.soft_keywords = words;
}

def peg_mark(p: peg_parser) -> int {
    return p.mark;
}

def peg_reset(p: peg_parser, mark: int) {
    p.mark = mark;
}

def peg_has_error(p: peg_parser) -> bool {
    return p.error_indicator;
}

def peg_fill_token(p: peg_parser) -> bool {
    if peg_has_error(p) {
        return False;
    }
    if p.mark < len(p.tokens) {
        return True;
    }
    raw = tokenizer_next(p.tok);
    if isinstance(raw, tok_diag) {
        p.error = raw;
        p.error_indicator = True;
        return False;
    }
    tok = raw as tok_token;
    tok_type = tok.tok_type;
    if tok_type == NAME {
        tok_type = _keyword_type_for(p, tok.spelling);
    }
    pt = peg_token_from_tok(tok);
    pt.tok_type = tok_type;
    p.tokens.append(pt);
    p.parsing_started = True;
    return True;
}

def peg_ensure_token(p: peg_parser) -> bool {
    if p.mark < len(p.tokens) {
        return True;
    }
    return peg_fill_token(p);
}

def peg_peek_type(p: peg_parser) -> int {
    if not peg_ensure_token(p) {
        return ERRORTOKEN;
    }
    return p.tokens[p.mark].tok_type;
}

def peg_check_memo(p: peg_parser, rule_type: int) -> peg_memo_hit {
    if not peg_ensure_token(p) {
        return peg_memo_hit(hit=False);
    }
    head = p.tokens[p.mark].memo_head;
    while head is not None {
        if head.rule_type == rule_type {
            p.mark = head.end_mark;
            return peg_memo_hit(hit=True, result=head.result);
        }
        head = head.next;
    }
    return peg_memo_hit(hit=False);
}

def peg_insert_memo(
    p: peg_parser, start_mark: int, rule_type: int, result: object | None
) -> None {
    if start_mark < 0 or start_mark >= len(p.tokens) {
        return;
    }
    m = peg_memo(
        rule_type=rule_type,
        result=result,
        end_mark=p.mark,
        next=p.tokens[start_mark].memo_head
    );
    p.tokens[start_mark].memo_head = m;
}

def peg_update_memo(
    p: peg_parser, start_mark: int, rule_type: int, result: object | None
) -> None {
    if start_mark < 0 or start_mark >= len(p.tokens) {
        peg_insert_memo(p, start_mark, rule_type, result);
        return;
    }
    head = p.tokens[start_mark].memo_head;
    while head is not None {
        if head.rule_type == rule_type {
            head.result = result;
            head.end_mark = p.mark;
            return;
        }
        head = head.next;
    }
    peg_insert_memo(p, start_mark, rule_type, result);
}

def peg_expect_token(p: peg_parser, tok_type: int) -> peg_token | None {
    if peg_has_error(p) {
        return None;
    }
    if not peg_ensure_token(p) {
        return None;
    }
    t = p.tokens[p.mark];
    if t.tok_type != tok_type {
        return None;
    }
    p.mark = p.mark + 1;
    return t;
}

def peg_expect_forced_token(
    p: peg_parser, tok_type: int, expected: str
) -> peg_token | None {
    if peg_has_error(p) {
        return None;
    }
    tok = peg_expect_token(p, tok_type);
    if tok is not None {
        return tok;
    }
    peg_raise_syntax_error_on_token(p, None, f"expected '{expected}'");
    return None;
}

def peg_expect_name(p: peg_parser) -> peg_token | None {
    return peg_expect_token(p, NAME);
}

def peg_expect_soft_keyword(p: peg_parser, spelling: str) -> peg_token | None {
    if peg_has_error(p) {
        return None;
    }
    if not peg_ensure_token(p) {
        return None;
    }
    t = p.tokens[p.mark];
    if t.tok_type != NAME {
        return None;
    }
    if t.spelling != spelling {
        return None;
    }
    if not _is_soft_keyword(p, spelling) {
        return None;
    }
    p.mark = p.mark + 1;
    return t;
}

def peg_get_last_nonnwhitespace_token(p: peg_parser) -> peg_token | None {
    m = p.mark - 1;
    while m >= 0 {
        t = p.tokens[m];
        if not is_whitespace_token(t.tok_type) {
            if t.tok_type != NL and t.tok_type != COMMENT {
                return t;
            }
        }
        m = m - 1;
    }
    return None;
}

def peg_raise_syntax_error(p: peg_parser, on_next: bool, message: str) -> None {
    if peg_has_error(p) {
        return;
    }
    tok: peg_token | None = p.known_err_token;
    if tok is None {
        if on_next {
            peg_ensure_token(p);
            if p.mark < len(p.tokens) {
                tok = p.tokens[p.mark];
            }
        } else {
            tok = peg_get_last_nonnwhitespace_token(p);
        }
    }
    if tok is None {
        p.error = mk_diag("SyntaxError", message, tok_no_loc(), p.filename);
    } else {
        p.error = mk_diag("SyntaxError", message, peg_token_loc(tok), p.filename);
    }
    p.error_indicator = True;
}

def peg_raise_syntax_error_on_token(
    p: peg_parser, tok: peg_token | None, message: str
) -> None {
    if peg_has_error(p) {
        return;
    }
    if tok is None {
        peg_raise_syntax_error(p, False, message);
        return;
    }
    p.error = mk_diag("SyntaxError", message, peg_token_loc(tok), p.filename);
    p.error_indicator = True;
}

def peg_reset_for_error_pass(p: peg_parser) {
    i = 0;
    while i < len(p.tokens) {
        p.tokens[i].memo_head = None;
        i = i + 1;
    }
    p.mark = 0;
    p.call_invalid_rules = True;
    p.error_indicator = False;
    p.error = None;
    p.known_err_token = None;
}

def peg_left_rec_finish(
    p: peg_parser, resmark: int, result: object | None
) -> object | None {
    p.mark = resmark;
    return result;
}

def peg_positive_lookahead_token(p: peg_parser, tok_type: int) -> bool {
    mark = peg_mark(p);
    ok = peg_expect_token(p, tok_type) is not None;
    peg_reset(p, mark);
    return ok;
}

def peg_negative_lookahead_token(p: peg_parser, tok_type: int) -> bool {
    mark = peg_mark(p);
    ok = peg_expect_token(p, tok_type) is None;
    peg_reset(p, mark);
    return ok;
}

def peg_expect_forced_result(
    p: peg_parser, result: object | None, expected: str
) -> object | None {
    if result is not None {
        return result;
    }
    peg_raise_syntax_error(p, False, f"expected {expected}");
    return None;
}
