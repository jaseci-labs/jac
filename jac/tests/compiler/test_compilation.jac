"""Compilation tests – migrated from test_pyast_gen_pass.py and test_language.py.

These tests verify that the Jac compiler can successfully compile various
fixture files without errors, and test compilation-level behaviour.
"""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     EXAMPLES = os.path.join(JAC_ROOT, "examples"),
     FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures"
     ),
     LANG_FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures");

test "compile hodge podge" {
    out = JacProgram();
    out.compile(os.path.join(EXAMPLES, "micro", "hodge_podge.jac"));
    assert len(out.errors_had) == 0;
}

test "compile fstrings" {
    out = JacProgram();
    out.compile(os.path.join(FIXTURES, "fstrings.jac"));
    assert len(out.errors_had) == 0;
}

test "compile from string" {
    code = "with entry { p1, p2 = (10, 20); }";
    out = JacProgram();
    result = out.compile(use_str=code, file_path="test.jac");
    assert result is not None;
}

test "arith precedence" {
    import from builtins { compile as pycompile, exec as pyexec }
    import io;
    import sys;
    prog = JacProgram().compile(
        use_str="with entry {print(4-5-4);}", file_path="test.jac"
    );
    old = sys.stdout;
    buf = io.StringIO();
    sys.stdout = buf;
    try {
        pyexec(pycompile(prog.gen.py_ast[0], "test.jac", "exec"));
    } finally {
        sys.stdout = old;
    }
    assert buf.getvalue() == "-5\n";
}

test "double format issue" {
    prog = JacProgram().compile("with entry {print(hello);}", "test.jac");
    prog.unparse();
    before = prog.format();
    prog.format();
    prog.format();
    after = prog.format();
    assert before == after;
}

test "multiline single tok" {
    mypass = JacProgram().compile(os.path.join(LANG_FIXTURES, "byllmissue.jac"));
    assert "2:5 - 4:8" in mypass.pp();
}

test "annotation tuple issue" {
    mypass = JacProgram().compile(os.path.join(LANG_FIXTURES, "slice_vals.jac"));
    assert "Annotated[Str, INT, BLAH]" in mypass.gen.py;
    assert "tuple[int, Optional[type], Optional[tuple]]" in mypass.gen.py;
}

test "obj hasvar initialization" {
    out = JacProgram();
    out.compile(os.path.join(LANG_FIXTURES, "uninitialized_hasvars.jac"));
    assert out.errors_had;

    errors_output = "";
    for error in out.errors_had {
        errors_output += error.pretty_print() + "\n";
    }

    for exp in [
        "Non default attribute 'var3' follows default attribute",
        "    3 |     has var1: int;",
        "    4 |     has var2: int = 42;",
        "    5 |     has var3: int;  # <-- This should be syntax error.",
        "      |         ^^^^",
        "    6 | }",
        'Missing "postinit" method required by un initialized attribute(s).',
        "    9 | obj Test2 {",
        "   10 |     has var1: str;",
        "   11 |     has var2: int by postinit;",
        "      |         ^^^^",
        "   12 | }",
        "Non default attribute 'var4' follows default attribute",
        "   17 |     has var2: int = 42;",
        "   18 |     has var3: int by postinit;  # <-- This is fine.",
        "   19 |     has var4: int;  # <-- This should be syntax error.",
        "      |         ^^^^",
        "   20 |",
        "   21 |     def postinit() {"
    ] {
        assert exp in errors_output;
    }
}
