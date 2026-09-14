"""Generator diagnostics cross the shipped native Python compiler boundary."""
import from builtins { compile as pycompile }

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
