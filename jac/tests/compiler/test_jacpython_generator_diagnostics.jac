"""Generator diagnostics cross the shipped native Python compiler boundary."""
import from builtins { compile as pycompile }
import ast;
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

test "null-byte errors are rejected before the source reaches the tokenizer" {
    caught = False;
    try {
        pycompile("x = '\x00' trailing", "null_byte.py", "exec");
    } except SyntaxError as error {
        caught = True;
        assert error.msg == "source code string cannot contain null bytes" , error.msg;
        assert error.lineno is None , error.lineno;
        assert error.text is None , repr(error.text);
    }
    assert caught;
}

test "unparenthesized generator diagnostics span the generator expression" {
    caught = False;
    try {
        pycompile("f(4, x for x in range(1))", "generator.py", "exec");
    } except SyntaxError as error {
        caught = True;
        assert error.msg == "Generator expression must be parenthesized" , error.msg;
        assert error.offset == 6 , error.offset;
        assert error.end_offset == 25 , error.end_offset;
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
            assert error.offset == 10 , error.offset;
            assert error.end_offset == 12 , error.end_offset;
        }
        assert caught;
    }
}

test "invalid escape warnings match CPython's suggestion text" {
    with warnings.catch_warnings(record=True) as recorded {
        warnings.simplefilter("always", SyntaxWarning);
        pycompile("value = '\\z'", "escape_warning.py", "exec");
        assert len(recorded) == 1 , len(recorded);
        assert str(recorded[0].message)
            == r'"\z" is an invalid escape sequence. Such sequences will not work in the future. Did you mean "\\z"? A raw string is also an option.';
    }
}

test "deep expressions parse or report recursion without exhausting the stack" {
    # CPython builds these 5000-deep chains iteratively and accepts them, so
    # either outcome is correct here; what the AST output guard must never do is
    # take the process down with the C stack.
    for suffix in ["()", ".b", "[0]", "*a"] {
        assert ast.parse("a" + suffix * 200, mode="eval") is not None;
        try {
            assert ast.parse("a" + suffix * 5000, mode="eval") is not None;
        } except RecursionError {
            continue;
        }
    }
}
