# P0.6 PEG runtime contract tests (PLAN.md).
#
# Exercises mark/reset, memoization, left-recursion growth, lookahead,
# cut, keywords, soft keywords, invalid-rule gating, and error locations
# using hand-written miniature rules (grammar2jac lands in P0.7).

import from token_model { ENDMARKER, NAME, NUMBER, PLUS, NT_OFFSET, tok_diag, }
import from peg_runtime {
    PEG_KEYWORD_TYPE_BASE,
    peg_parser,
    peg_parser_from_source,
    peg_set_keywords,
    peg_set_soft_keywords,
    peg_keyword_entry,
    peg_mark,
    peg_reset,
    peg_check_memo,
    peg_insert_memo,
    peg_update_memo,
    peg_expect_token,
    peg_expect_name,
    peg_expect_soft_keyword,
    peg_fill_token,
    peg_has_error,
    peg_raise_syntax_error,
    peg_reset_for_error_pass,
    peg_left_rec_finish,
    peg_token,
}

glob RULE_TERM: int = NT_OFFSET,
     RULE_LR_EXPR: int = NT_OFFSET + 2,
     KW_AND: int = PEG_KEYWORD_TYPE_BASE + 1,
     KW_OR: int = PEG_KEYWORD_TYPE_BASE + 2;

def _digit_val(c: str) -> int {
    digits = "0123456789";
    j = 0;
    while j < 10 {
        if digits[j] == c {
            return j;
        }
        j = j + 1;
    }
    return -1;
}

def _parse_int(tok: peg_token) -> int {
    n = 0;
    i = 0;
    while i < len(tok.spelling) {
        d = _digit_val(tok.spelling[i]);
        if d >= 0 {
            n = n * 10 + d;
        }
        i = i + 1;
    }
    return n;
}

def term_rule(p: peg_parser) -> int | None {
    hit = peg_check_memo(p, RULE_TERM);
    if hit.hit {
        return hit.result as int | None;
    }
    mark = peg_mark(p);
    tok = peg_expect_token(p, NUMBER);
    if tok is None {
        peg_insert_memo(p, mark, RULE_TERM, None);
        return None;
    }
    val = _parse_int(tok);
    peg_insert_memo(p, mark, RULE_TERM, val);
    return val;
}

def expr_rule_raw(p: peg_parser) -> int | None {
    left = term_rule(p);
    if left is None {
        return None;
    }
    while True {
        if peg_expect_token(p, PLUS) is None {
            break;
        }
        right = term_rule(p);
        if right is None {
            peg_raise_syntax_error(p, False, "invalid syntax");
            return None;
        }
        left = left + right;
    }
    return left;
}

def lr_expr_raw(p: peg_parser) -> int | None {
    left = lr_expr_rule(p);
    if left is not None {
        if peg_expect_token(p, PLUS) is not None {
            tok = peg_expect_token(p, NUMBER);
            if tok is not None {
                return left + _parse_int(tok);
            }
        }
    }
    tok = peg_expect_token(p, NUMBER);
    if tok is not None {
        return _parse_int(tok);
    }
    return None;
}

def lr_expr_rule(p: peg_parser) -> int | None {
    hit = peg_check_memo(p, RULE_LR_EXPR);
    if hit.hit {
        return hit.result as int | None;
    }
    mark = peg_mark(p);
    res: int | None = None;
    resmark = mark;
    while True {
        peg_update_memo(p, mark, RULE_LR_EXPR, res);
        peg_reset(p, mark);
        raw = lr_expr_raw(p);
        if peg_has_error(p) {
            return None;
        }
        if raw is None or peg_mark(p) <= resmark {
            break;
        }
        resmark = peg_mark(p);
        res = raw;
    }
    return peg_left_rec_finish(p, resmark, res) as int | None;
}

def parse_expr(source: str) -> int | None {
    p = peg_parser_from_source(source, "<peg-test>", True);
    val = expr_rule_raw(p);
    if val is None and not peg_has_error(p) {
        return None;
    }
    if peg_has_error(p) {
        return None;
    }
    peg_expect_token(p, ENDMARKER);
    return val;
}

def parse_lr(source: str) -> int | None {
    p = peg_parser_from_source(source, "<peg-test>", True);
    val = lr_expr_rule(p);
    if peg_has_error(p) {
        return None;
    }
    peg_expect_token(p, ENDMARKER);
    return val;
}

def setup_keyword_parser(source: str) -> peg_parser {
    p = peg_parser_from_source(source, "<peg-test>", True);
    lists: list[list[peg_keyword_entry]] = [
        [],
        [],
        [peg_keyword_entry(spelling="or", tok_type=KW_OR), ],
        [peg_keyword_entry(spelling="and", tok_type=KW_AND), ],

    ];
    peg_set_keywords(p, lists);
    peg_set_soft_keywords(p, ["case"]);
    return p;
}

test "peg runtime: mark reset preserves token position" {
    p = peg_parser_from_source("1+2", "<peg-test>", True);
    m0 = peg_mark(p);
    peg_fill_token(p);
    m1 = peg_mark(p);
    peg_fill_token(p);
    peg_reset(p, m0);
    assert peg_mark(p) == m0;
    peg_reset(p, m1);
    tok = peg_expect_token(p, NUMBER);
    assert tok is not None;
    assert tok.spelling == "1";
}

test "peg runtime: memoization skips reparse" {
    p = peg_parser_from_source("1+2", "<peg-test>", True);
    v1 = term_rule(p);
    assert v1 == 1;
    peg_reset(p, 0);
    v2 = term_rule(p);
    assert v2 == 1;
    assert peg_mark(p) == 1;
}

test "peg runtime: expression slice parses terms and sums" {
    assert parse_expr("1+1") == 2;
    assert parse_expr("a*b+c") is None;
    assert parse_expr("1+2+3") == 6;
}

test "peg runtime: left recursion growth" {
    assert parse_lr("1+2+3") == 6;
    assert parse_lr("42") == 42;
}

test "peg runtime: positive lookahead via mark reset" {
    p = peg_parser_from_source("1+2", "<peg-test>", True);
    mark = peg_mark(p);
    tok = peg_expect_token(p, NUMBER);
    assert tok is not None;
    saved = peg_mark(p);
    has_plus = peg_expect_token(p, PLUS) is not None;
    peg_reset(p, saved);
    assert has_plus;
    has_plus_again = peg_expect_token(p, PLUS) is not None;
    assert has_plus_again;
    peg_reset(p, mark);
    assert peg_expect_token(p, NUMBER) is not None;
}

test "peg runtime: negative lookahead via mark reset" {
    p = peg_parser_from_source("1", "<peg-test>", True);
    mark = peg_mark(p);
    tok = peg_expect_token(p, NUMBER);
    assert tok is not None;
    saved = peg_mark(p);
    has_plus = peg_expect_token(p, PLUS) is not None;
    peg_reset(p, saved);
    assert not has_plus;
}

test "peg runtime: cut stops alternate after committed prefix" {
    p = peg_parser_from_source("1", "<peg-test>", True);
    cut = False;
    mark = peg_mark(p);
    tok = peg_expect_token(p, NUMBER);
    if tok is not None {
        if peg_expect_token(p, PLUS) is None {
            cut = True;
        }
    }
    alt2 = False;
    if not cut {
        peg_reset(p, mark);
        alt2 = peg_expect_token(p, NUMBER) is not None;
    }
    assert cut;
    assert not alt2;
}

test "peg runtime: keyword promotion and name fallback" {
    p = setup_keyword_parser("and or xor");
    and_tok = peg_expect_token(p, KW_AND);
    assert and_tok is not None;
    assert and_tok.spelling == "and";
    or_kw = peg_expect_token(p, KW_OR);
    assert or_kw is not None;
    assert or_kw.spelling == "or";
    name_tok = peg_expect_name(p);
    assert name_tok is not None;
    assert name_tok.spelling == "xor";
    assert name_tok.tok_type == NAME;
}

test "peg runtime: soft keyword spelling match" {
    p = setup_keyword_parser("case");
    soft = peg_expect_soft_keyword(p, "case");
    assert soft is not None;
    assert soft.spelling == "case";
    bad = peg_expect_soft_keyword(p, "match");
    assert bad is None;
}

test "peg runtime: invalid rules gated by call_invalid_rules" {
    p = peg_parser_from_source("+", "<peg-test>", True);
    p.call_invalid_rules = False;
    assert term_rule(p) is None;
    assert not peg_has_error(p);
    peg_reset_for_error_pass(p);
    p.call_invalid_rules = True;
    assert peg_expect_token(p, PLUS) is not None;
}

test "peg runtime: syntax error location on forced failure" {
    p = peg_parser_from_source("1+", "<peg-test>", True);
    v = expr_rule_raw(p);
    assert v is None;
    assert peg_has_error(p);
    assert p.error is not None;
    diag = p.error as tok_diag;
    assert diag.kind == "SyntaxError";
    assert diag.loc.lineno == 1;
    assert diag.loc.col_offset == 1;
}
