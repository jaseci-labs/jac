import from engine.src.parser.lexer { TokenType, Token, Lexer, make_lexer }

# ══════════════════════════════════════════════════════════════════════════════
# Smoke tests
# ══════════════════════════════════════════════════════════════════════════════

glob _smoke_ok: int = 0,
     _smoke_err: int = 0;

"""Pass/fail helper — compares two string values."""
def _check(label: str, got: str, want: str) {
    if got == want {
        print("OK  ", label);
        _smoke_ok = _smoke_ok + 1;
    } else {
        print("FAIL", label, "— got:", got, "want:", want);
        _smoke_err = _smoke_err + 1;
    }
}

"""Pass/fail helper — compares two boolean values."""
def _checkb(label: str, got: bool, want: bool) {
    if got == want {
        print("OK  ", label);
        _smoke_ok = _smoke_ok + 1;
    } else {
        print("FAIL", label, "— expected:", want, "got:", got);
        _smoke_err = _smoke_err + 1;
    }
}

"""Pass/fail helper — compares two int values."""
def _checki(label: str, got: int, want: int) {
    if got == want {
        print("OK  ", label);
        _smoke_ok = _smoke_ok + 1;
    } else {
        print("FAIL", label, "— got:", got, "want:", want);
        _smoke_err = _smoke_err + 1;
    }
}

with entry {
    # ── 1: empty source → EOF ───────────────────────────────────────────────
    lx1: Lexer = make_lexer("");
    t1: Token = lx1.next_token();
    _checkb("empty → EOF", t1.ttype == TokenType.EOF, True);

    # ── 2: single identifier ────────────────────────────────────────────────
    lx2: Lexer = make_lexer("hello");
    t2: Token = lx2.next_token();
    _checkb("identifier is Identifier", t2.ttype == TokenType.Identifier, True);
    _check("identifier value", t2.value, "hello");

    # ── 3: keyword recognition ──────────────────────────────────────────────
    lx3: Lexer = make_lexer("return");
    t3: Token = lx3.next_token();
    _checkb("keyword 'return'", t3.ttype == TokenType.KwReturn, True);

    # ── 4: keyword vs identifier prefix ─────────────────────────────────────
    lx4: Lexer = make_lexer("returns");
    t4: Token = lx4.next_token();
    _checkb("'returns' is Identifier", t4.ttype == TokenType.Identifier, True);

    # ── 5: decimal integer ──────────────────────────────────────────────────
    lx5: Lexer = make_lexer("42");
    t5: Token = lx5.next_token();
    _check("decimal value", t5.value, "42");
    _checkb("decimal is NumericLiteral", t5.ttype == TokenType.NumericLiteral, True);

    # ── 6: float ────────────────────────────────────────────────────────────
    lx6: Lexer = make_lexer("3.14");
    t6: Token = lx6.next_token();
    _check("float value", t6.value, "3.14");

    # ── 7: hex literal ──────────────────────────────────────────────────────
    lx7: Lexer = make_lexer("0xFF");
    t7: Token = lx7.next_token();
    _check("hex value", t7.value, "0xFF");

    # ── 8: binary literal ───────────────────────────────────────────────────
    lx8: Lexer = make_lexer("0b1010");
    t8: Token = lx8.next_token();
    _check("binary value", t8.value, "0b1010");

    # ── 9: octal literal ────────────────────────────────────────────────────
    lx9: Lexer = make_lexer("0o755");
    t9: Token = lx9.next_token();
    _check("octal value", t9.value, "0o755");

    # ── 10: BigInt ──────────────────────────────────────────────────────────
    lx10: Lexer = make_lexer("100n");
    t10: Token = lx10.next_token();
    _checkb("BigInt is BigIntLiteral", t10.ttype == TokenType.BigIntLiteral, True);
    _check("BigInt value", t10.value, "100n");

    # ── 11: double-quoted string ─────────────────────────────────────────────
    lx11: Lexer = make_lexer("\"hello world\"");
    t11: Token = lx11.next_token();
    _checkb("string is StringLiteral", t11.ttype == TokenType.StringLiteral, True);
    _check("string value", t11.value, "hello world");

    # ── 12: single-quoted string ─────────────────────────────────────────────
    lx12: Lexer = make_lexer("'abc'");
    t12: Token = lx12.next_token();
    _check("single-quote value", t12.value, "abc");

    # ── 13: string with escape sequences stored raw ───────────────────────────
    lx13: Lexer = make_lexer("\"a\\nb\"");
    t13: Token = lx13.next_token();
    _check("string-escape raw", t13.value, "a\\nb");

    # ── 14: template literal (no interpolation) ──────────────────────────────
    lx14: Lexer = make_lexer("`simple`");
    t14: Token = lx14.next_token();
    _checkb(
        "template is TemplateLiteral", t14.ttype == TokenType.TemplateLiteral, True
    );
    _check("template value", t14.value, "simple");

    # ── 15: template head (with interpolation) ───────────────────────────────
    lx15: Lexer = make_lexer("`hello ${");
    t15: Token = lx15.next_token();
    _checkb("template head is TemplateHead", t15.ttype == TokenType.TemplateHead, True);
    _check("template head value", t15.value, "hello ");

    # ── 16: strict equality operator ─────────────────────────────────────────
    lx16: Lexer = make_lexer("===");
    t16: Token = lx16.next_token();
    _checkb("=== is EqEqEq", t16.ttype == TokenType.EqEqEq, True);

    # ── 17: unsigned-right-shift assignment ───────────────────────────────────
    lx17: Lexer = make_lexer(">>>=");
    t17: Token = lx17.next_token();
    _checkb(">>>= is GtGtGtEq", t17.ttype == TokenType.GtGtGtEq, True);

    # ── 18: arrow ────────────────────────────────────────────────────────────
    lx18: Lexer = make_lexer("=>");
    t18: Token = lx18.next_token();
    _checkb("=> is Arrow", t18.ttype == TokenType.Arrow, True);

    # ── 19: optional chaining ────────────────────────────────────────────────
    lx19: Lexer = make_lexer("?.");
    t19: Token = lx19.next_token();
    _checkb("?. is QuestionDot", t19.ttype == TokenType.QuestionDot, True);

    # ── 20: nullish coalescing ───────────────────────────────────────────────
    lx20: Lexer = make_lexer("??");
    t20: Token = lx20.next_token();
    _checkb("?? is QuestionQuestion", t20.ttype == TokenType.QuestionQuestion, True);

    # ── 21: spread / rest ────────────────────────────────────────────────────
    lx21: Lexer = make_lexer("...");
    t21: Token = lx21.next_token();
    _checkb("... is DotDotDot", t21.ttype == TokenType.DotDotDot, True);

    # ── 22: line comment is skipped ──────────────────────────────────────────
    lx22: Lexer = make_lexer("// comment\nfoo");
    t22: Token = lx22.next_token();
    _check("after line comment is foo", t22.value, "foo");
    _checkb("newline_before after line comment", t22.has_newline_before, True);

    # ── 23: block comment is skipped ─────────────────────────────────────────
    lx23: Lexer = make_lexer("/* hi */ bar");
    t23: Token = lx23.next_token();
    _check("after block comment is bar", t23.value, "bar");

    # ── 24: newline sets has_newline_before ───────────────────────────────────
    lx24: Lexer = make_lexer("a\nb");
    lx24.next_token();
    t24: Token = lx24.next_token();
    _checkb("newline_before is True after newline", t24.has_newline_before, True);

    # ── 25: same line clears has_newline_before ───────────────────────────────
    lx25: Lexer = make_lexer("a b");
    lx25.next_token();
    t25: Token = lx25.next_token();
    _checkb("newline_before is False on same line", t25.has_newline_before, False);

    # ── 26: tokenize() returns full list including EOF ────────────────────────
    lx26: Lexer = make_lexer("x + 1");
    toks26: list[Token] = lx26.tokenize();
    _checki("tokenize length is 4", len(toks26), 4);
    _check("tok[0] is x", toks26[0].value, "x");
    _checkb("tok[1] is Plus", toks26[1].ttype == TokenType.Plus, True);
    _check("tok[2] is 1", toks26[2].value, "1");
    _checkb("tok[3] is EOF", toks26[3].ttype == TokenType.EOF, True);

    # ── 27: peek_token does not advance ──────────────────────────────────────
    lx27: Lexer = make_lexer("abc");
    pk27: Token = lx27.peek_token();
    nx27: Token = lx27.next_token();
    _check("peek same value as next", pk27.value, nx27.value);

    # ── 28: line and column tracking ─────────────────────────────────────────
    lx28: Lexer = make_lexer("a\nbc");
    lx28.next_token();
    t28: Token = lx28.next_token();
    _checkb("line 2 after newline", t28.line == 2, True);
    _checki("col 1 at start of line 2", t28.col, 1);

    # ── 29: major keyword set ─────────────────────────────────────────────────
    lx29: Lexer = make_lexer("var let const function class if else for while do");
    toks29: list[Token] = lx29.tokenize();
    _checkb("kw var", toks29[0].ttype == TokenType.KwVar, True);
    _checkb("kw let", toks29[1].ttype == TokenType.KwLet, True);
    _checkb("kw const", toks29[2].ttype == TokenType.KwConst, True);
    _checkb("kw function", toks29[3].ttype == TokenType.KwFunction, True);
    _checkb("kw class", toks29[4].ttype == TokenType.KwClass, True);
    _checkb("kw if", toks29[5].ttype == TokenType.KwIf, True);
    _checkb("kw else", toks29[6].ttype == TokenType.KwElse, True);
    _checkb("kw for", toks29[7].ttype == TokenType.KwFor, True);
    _checkb("kw while", toks29[8].ttype == TokenType.KwWhile, True);
    _checkb("kw do", toks29[9].ttype == TokenType.KwDo, True);

    # ── 30: boolean & null keywords ──────────────────────────────────────────
    lx30: Lexer = make_lexer("true false null undefined");
    toks30: list[Token] = lx30.tokenize();
    _checkb("kw true", toks30[0].ttype == TokenType.KwTrue, True);
    _checkb("kw false", toks30[1].ttype == TokenType.KwFalse, True);
    _checkb("kw null", toks30[2].ttype == TokenType.KwNull, True);
    _checkb("kw undefined", toks30[3].ttype == TokenType.KwUndefined, True);

    # ── 31: logical assignment operators ─────────────────────────────────────
    lx31: Lexer = make_lexer("&&= ||= ??=");
    toks31: list[Token] = lx31.tokenize();
    _checkb("&&= is AmpAmpEq", toks31[0].ttype == TokenType.AmpAmpEq, True);
    _checkb("||= is PipePipeEq", toks31[1].ttype == TokenType.PipePipeEq, True);
    _checkb(
        "??= is QuestionQuestionEq",
        toks31[2].ttype == TokenType.QuestionQuestionEq,
        True
    );

    # ── 32: exponentiation ────────────────────────────────────────────────────
    lx32: Lexer = make_lexer("** **=");
    toks32: list[Token] = lx32.tokenize();
    _checkb("** is StarStar", toks32[0].ttype == TokenType.StarStar, True);
    _checkb("**= is StarStarEq", toks32[1].ttype == TokenType.StarStarEq, True);

    # ── 33: numeric separator ─────────────────────────────────────────────────
    lx33: Lexer = make_lexer("1_000_000");
    t33: Token = lx33.next_token();
    _check("numeric sep value", t33.value, "1_000_000");

    # ── 34: @ decorator token ─────────────────────────────────────────────────
    lx34: Lexer = make_lexer("@decorator");
    t34a: Token = lx34.next_token();
    t34b: Token = lx34.next_token();
    _checkb("@ is At", t34a.ttype == TokenType.At, True);
    _check("decorator identifier", t34b.value, "decorator");

    # ── 35: dot before digit is a number ──────────────────────────────────────
    lx35: Lexer = make_lexer(".5");
    t35: Token = lx35.next_token();
    _checkb(".5 is NumericLiteral", t35.ttype == TokenType.NumericLiteral, True);
    _check(".5 value", t35.value, ".5");

    # ── 36: single dot tokens ─────────────────────────────────────────────────
    lx36: Lexer = make_lexer(". ..");
    toks36: list[Token] = lx36.tokenize();
    _checkb("first . is Dot", toks36[0].ttype == TokenType.Dot, True);
    _checkb("second . is Dot", toks36[1].ttype == TokenType.Dot, True);
    _checkb("third . is Dot", toks36[2].ttype == TokenType.Dot, True);

    # ── 37: complex expression ────────────────────────────────────────────────
    lx37: Lexer = make_lexer("const x = a?.b ?? 0;");
    toks37: list[Token] = lx37.tokenize();
    _checkb("complex[0] is KwConst", toks37[0].ttype == TokenType.KwConst, True);
    _check("complex[1] value x", toks37[1].value, "x");
    _checkb("complex[2] is Eq", toks37[2].ttype == TokenType.Eq, True);
    _check("complex[3] value a", toks37[3].value, "a");
    _checkb(
        "complex[4] is QuestionDot", toks37[4].ttype == TokenType.QuestionDot, True
    );
    _check("complex[5] value b", toks37[5].value, "b");
    _checkb(
        "complex[6] is QuestionQuestion",
        toks37[6].ttype == TokenType.QuestionQuestion,
        True
    );
    _check("complex[7] value 0", toks37[7].value, "0");
    _checkb("complex[8] is Semicolon", toks37[8].ttype == TokenType.Semicolon, True);

    print("lexer smoke:", _smoke_ok, "passed,", _smoke_err, "failed");
}
