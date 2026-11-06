"""Generator diagnostics cross the shipped native Python compiler boundary."""
import from builtins { compile as pycompile }
import warnings;

test "yield and yield-from diagnostics preserve expression identity" {
    cases = [
        ("yield 1", "'yield' outside function"),
        ("yield from [1, 2]", "'yield from' outside function"),
        (
            "f=lambda: (yield from (1,2)), (yield from (3,4))",
            "'yield from' outside function"
        ),
        (
            "def f(): (yield bar) = y",
            "cannot assign to yield expression here. Maybe you meant '==' instead of '='?"
        ),
        (
            "def f(): (yield bar) += y",
            "'yield expression' is an illegal expression for augmented assignment"
        )
    ];
    for (source, expected) in cases {
        caught = False;
        try {
            pycompile(source, "generator_diagnostic.py", "exec");
        } except SyntaxError as error {
            caught = True;
            assert error.msg == expected , error.msg;
            assert error.filename == "generator_diagnostic.py";
            assert error.lineno == 1;
        }
        assert caught , source;
    }
}

test "invalid augmented targets identify the expression and its source span" {
    for (source, description, end) in [
        ("f() += 1", "function call", 4),
        ("(a + b) += 1", "expression", 7),
        ("[a, b] += [1]", "list", 7),
        ("(yield value) += 1", "yield expression", 13)
    ] {
        caught = False;
        try {
            pycompile(source, "target.py", "exec");
        } except SyntaxError as error {
            caught = True;
            assert error.msg
                == f"'{description}' is an illegal expression for augmented assignment" , error.msg;
            assert error.end_offset == end;
        }
        assert caught , source;
    }
}

test "EOF diagnostics keep the opening token's line and column" {
    cases = [
        (
            "value = '''first line\nsecond line",
            "unterminated triple-quoted string literal (detected at line 2)",
            1,
            9,
            "value = '''first line"
        ),
        ("value = 1\\", "unexpected EOF while parsing", 1, 11, "value = 1\\\n")
    ];
    for (source, message, line, offset, text) in cases {
        caught = False;
        try {
            pycompile(source, "eof.py", "exec");
        } except SyntaxError as error {
            caught = True;
            assert error.msg == message , error.msg;
            assert error.filename == "eof.py";
            assert error.lineno == line , error.lineno;
            assert error.offset == offset , f"{source!r}: offset {error.offset}";
            assert error.text == text , error.text;
        }
        assert caught , source;
    }
}

test "unclosed delimiters take priority over the later syntax error" {
    source = "a = ( 1, 2, 3\nb=3";
    caught = False;
    try {
        pycompile(source, "paren.py", "exec");
    } except SyntaxError as error {
        caught = True;
        assert error.msg == "'(' was never closed" , error.msg;
        assert error.filename == "paren.py";
        assert error.lineno == 1 , error.lineno;
        assert error.offset == 5 , error.offset;
        assert (error.text or "").rstrip("\n") == "a = ( 1, 2, 3" , error.text;
    }
    assert caught;
}

test "missing indented blocks interpolate the header line" {
    caught = False;
    try {
        pycompile("if True:\nprint('missing')", "indent.py", "exec");
    } except IndentationError as error {
        caught = True;
        assert error.msg
            == "expected an indented block after 'if' statement on line 1" , error.msg;
        assert error.lineno == 2 , error.lineno;
    }
    assert caught;
}

test "turning an invalid escape warning into an error drops the warning lead-in" {
    with warnings.catch_warnings() {
        warnings.simplefilter("error", SyntaxWarning);
        caught = False;
        try {
            pycompile("value = '\\z'", "escape.py", "exec");
        } except SyntaxError as error {
            caught = True;
            assert error.msg
                == r'"\z" is an invalid escape sequence. Did you mean "\\z"? A raw string is also an option.' , error.msg;
        }
        assert caught;
    }
}
