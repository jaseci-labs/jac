# P0.4 token model contract tests (PLAN.md).
#
# Validates generated token ids, operator mappings, location helpers, and
# diagnostic objects against the pinned CPython 3.14.6 Grammar/Tokens table.

import from token_model {
    ENDMARKER,
    NAME,
    NUMBER,
    STRING,
    NEWLINE,
    INDENT,
    DEDENT,
    PLUS,
    OP,
    EXCLAMATION,
    EQEQUAL,
    COLONEQUAL,
    FSTRING_START,
    FSTRING_MIDDLE,
    TSTRING_MIDDLE,
    SOFT_KEYWORD,
    TYPE_COMMENT,
    TYPE_IGNORE,
    ENCODING,
    ERRORTOKEN,
    N_TOKENS,
    NT_OFFSET,
    EXACT_TOKEN_TYPES,
    is_terminal,
    is_nonterminal,
    is_eof,
    is_whitespace_token,
    is_stringlit_token,
    exact_token_type,
    token_name,
    tok_loc_span,
    tok_no_loc,
    same_tok_loc,
    tok_token,
    token_loc,
    mk_diag,
    TOK_NO_LINE,
    TOK_NO_COLUMN,
}

test "token model: ids match Lib/token.py pin" {
    assert ENDMARKER == 0;
    assert NAME == 1;
    assert NUMBER == 2;
    assert STRING == 3;
    assert NEWLINE == 4;
    assert INDENT == 5;
    assert DEDENT == 6;
    assert PLUS == 14;
    assert OP == 55;
    assert SOFT_KEYWORD == 58;
    assert FSTRING_START == 59;
    assert TSTRING_MIDDLE == 63;
    assert ENCODING == 68;
    assert ERRORTOKEN == 67;
    assert N_TOKENS == 69;
    assert NT_OFFSET == 256;
}

test "token model: terminal predicates" {
    assert is_terminal(PLUS);
    assert is_terminal(ENDMARKER);
    assert not is_nonterminal(PLUS);
    assert is_nonterminal(NT_OFFSET);
    assert is_eof(ENDMARKER);
    assert not is_eof(PLUS);
    assert is_whitespace_token(NEWLINE);
    assert is_whitespace_token(INDENT);
    assert not is_whitespace_token(PLUS);
    assert is_stringlit_token(STRING);
    assert is_stringlit_token(FSTRING_MIDDLE);
    assert is_stringlit_token(TSTRING_MIDDLE);
    assert not is_stringlit_token(NAME);
}

test "token model: exact operator spellings" {
    assert EXACT_TOKEN_TYPES["+"] == PLUS;
    assert EXACT_TOKEN_TYPES["=="] == EQEQUAL;
    assert EXACT_TOKEN_TYPES[":="] == COLONEQUAL;
    assert EXACT_TOKEN_TYPES["!"] == EXCLAMATION;
    assert exact_token_type("+") == PLUS;
    assert exact_token_type("==") == EQEQUAL;
    assert exact_token_type("??") == OP;
}

test "token model: token names for diagnostics" {
    assert token_name(PLUS) == "PLUS";
    assert token_name(ENDMARKER) == "ENDMARKER";
    assert token_name(TYPE_COMMENT) == "TYPE_COMMENT";
    assert token_name(TYPE_IGNORE) == "TYPE_IGNORE";
    assert token_name(ERRORTOKEN) == "<ERRORTOKEN>";
    assert token_name(ENCODING) == "<ENCODING>";
    assert token_name(-1) == "<invalid>";
}

test "token model: location and token objects" {
    loc = tok_loc_span(1, 1, 0, 3);
    assert loc.lineno == 1;
    assert loc.end_lineno == 1;
    assert loc.col_offset == 0;
    assert loc.end_col_offset == 3;
    sentinel = tok_no_loc();
    assert sentinel.lineno == TOK_NO_LINE;
    assert sentinel.col_offset == TOK_NO_COLUMN;
    assert same_tok_loc(loc, tok_loc_span(1, 1, 0, 3));
    assert not same_tok_loc(loc, tok_loc_span(1, 1, 1, 3));

    tok = tok_token(
        tok_type=PLUS,
        spelling="+",
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=1
    );
    assert tok.tok_type == PLUS;
    assert tok.spelling == "+";
    assert token_loc(tok).col_offset == 0;
    assert token_loc(tok).end_col_offset == 1;

    diag = mk_diag("SyntaxError", "invalid syntax", loc, "<test>");
    assert diag.kind == "SyntaxError";
    assert diag.filename == "<test>";
    assert same_tok_loc(diag.loc, loc);
}
