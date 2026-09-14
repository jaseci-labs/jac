"""Parser memoization owns results without making tokens own themselves."""
import gc;
import weakref;
import from jaclang.compiler.frontend.python.peg_runtime {
    peg_parser_from_source,
    peg_token,
    peg_ensure_token,
    peg_check_memo,
    peg_insert_memo,
    peg_update_memo,
    peg_reset_for_error_pass
}

test "parser memo results release tokens without cyclic collection" {
    def memoized_token -> any {
        parser = peg_parser_from_source("value", "memo.py", False);
        parser.tokens.append(peg_token(1, "value", 1, 0, 1, 5));
        assert peg_ensure_token(parser);
        token = parser.tokens[0];
        observed = weakref.ref(token);
        parser.mark = 1;
        peg_insert_memo(parser, 0, 7, token);
        parser.mark = 0;
        hit = peg_check_memo(parser, 7);
        assert hit.hit and hit.result is token;
        assert parser.mark == 1;
        return observed;
    }
    was_enabled = gc.isenabled();
    gc.disable();
    try {
        observed = memoized_token();
        assert observed() is None , "a token retained itself through its parser memo";
    } finally {
        if was_enabled {
            gc.enable();
        }
        gc.collect();
    }
}

test "parser memo replacement and error reset preserve token positions" {
    parser = peg_parser_from_source("left right", "memo.py", False);
    parser.tokens = [
        peg_token(1, "left", 1, 0, 1, 4),
        peg_token(1, "right", 1, 5, 1, 10)
    ];
    assert peg_ensure_token(parser);
    first = parser.tokens[0];
    parser.mark = 1;
    assert peg_ensure_token(parser);
    second = parser.tokens[1];
    parser.mark = 2;
    peg_insert_memo(parser, 0, 7, first);
    peg_insert_memo(parser, 0, 8, second);
    parser.mark = 1;
    peg_update_memo(parser, 0, 7, second);
    parser.mark = 0;
    hit = peg_check_memo(parser, 7);
    assert hit.hit and hit.result is second and parser.mark == 1;
    parser.mark = 0;
    hit = peg_check_memo(parser, 8);
    assert hit.hit and hit.result is second and parser.mark == 2;
    peg_reset_for_error_pass(parser);
    assert parser.mark == 0 and parser.call_invalid_rules;
    assert not peg_check_memo(parser, 7).hit;
    assert parser.tokens == [first, second];
}
