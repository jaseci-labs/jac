# P0.5 tokenizer differential tests (PLAN.md) — expression eval slice.
#
# Compares native tokenizer output against the C tokenizer via host_oracle.
# Test harness only.

import from token_model { ENDMARKER, tok_token, tok_diag }
import from tokenizer { tokenize_all }
import from host_oracle { host_c_tokenize }

def tokens_equal(actual: list[tok_token | tok_diag], expected: list[dict]) -> bool {
    ai = 0;
    ei = 0;
    while ai < len(actual) and ei < len(expected) {
        a = actual[ai];
        e = expected[ei];
        if isinstance(a, tok_diag) {
            return False;
        }
        tok = a as tok_token;
        if tok.tok_type != e["type"] {
            return False;
        }
        if tok.spelling != e["spelling"] {
            return False;
        }
        if tok.lineno != e["lineno"] {
            return False;
        }
        if tok.col_offset != e["col_offset"] {
            return False;
        }
        if tok.end_lineno != e["end_lineno"] {
            return False;
        }
        if tok.end_col_offset != e["end_col_offset"] {
            return False;
        }
        ai = ai + 1;
        ei = ei + 1;
    }
    return ai == len(actual) and ei == len(expected);
}

def assert_tokenize_matches(source: str) {
    actual = tokenize_all(source, "<tok-test>", False);
    expected = host_c_tokenize(source);
    assert tokens_equal(actual, expected);
}

test "tokenizer: 1+1 matches C tokenizer" {
    assert_tokenize_matches("1+1");
}

test "tokenizer: -x matches C tokenizer" {
    assert_tokenize_matches("-x");
}

test "tokenizer: a*b+c matches C tokenizer" {
    assert_tokenize_matches("a*b+c");
}

test "tokenizer: f(x,1) matches C tokenizer" {
    assert_tokenize_matches("f(x,1)");
}

test "tokenizer: x<y<z matches C tokenizer" {
    assert_tokenize_matches("x<y<z");
}

test "tokenizer: ends with ENDMARKER" {
    tokens = tokenize_all("1+1", "<tok-test>", False);
    last = tokens[len(tokens) - 1];
    assert isinstance(last, tok_token);
    assert (last as tok_token).tok_type == ENDMARKER;
}

test "tokenizer: exec blank line between stmts does not hang" {
    src = "def f(x):\n    return x + 1\n\nresult = f(2)\n";
    tokens = tokenize_all(src, "<tok-test>", True);
    assert len(tokens) > 0;
    last = tokens[len(tokens) - 1];
    assert isinstance(last, tok_token);
    assert (last as tok_token).tok_type == ENDMARKER;
}
