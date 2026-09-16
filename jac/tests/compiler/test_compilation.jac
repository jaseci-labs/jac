"""Compilation tests – migrated from the emitter and language suites.

These tests verify that the Jac compiler can successfully compile various
fixture files without errors, and test compilation-level behaviour.
"""

import os;
import from jaclang.compiler.tools.treeprinter { print_ast_tree }
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.tools.jac_formatter_pass { format_module }
import from jaclang.compiler.tools.unparse_pass { unparse_module }
import from jaclang.cli.commands { analysis }

glob EXAMPLES = os.path.join(JAC_ROOT, "examples"),
     FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "passes", "fixtures"),
     COMPILER_FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "fixtures"),
     LANG_FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures");

test "inverted isinstance guard narrows type" {
    result = analysis.check(
        [os.path.join(COMPILER_FIXTURES, "isinstance_narrowing_guard.jac")]
    );
    assert result == 0;
}

test "compile hodge podge" {
    out = JacProgram();
    out.compile(os.path.join(COMPILER_FIXTURES, "micro", "hodge_podge.jac"));
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
    import from jaclang.project.config {
        JacConfig,
        CheckConfig,
        LintConfig,
        set_config
    }
    # Isolate from the repo jac.toml (`select = ["all"]`), which enables the
    # opt-in no-print rule (E3012) that would reject the print used below.
    set_config(JacConfig(check=CheckConfig(lint=LintConfig(select=["default"]))));
    try {
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
    } finally {
        set_config(None);
    }
}

test "double format issue" {
    prog = JacProgram().compile("with entry {print(hello);}", "test.jac");
    unparse_module(prog);
    before = format_module(prog);
    format_module(prog);
    format_module(prog);
    after = format_module(prog);
    assert before == after;
}

test "format keeps section docstring above its import" {
    prog = JacProgram();
    mod = prog.compile(os.path.join(COMPILER_FIXTURES, "docstring_before_import.jac"));
    assert len(prog.errors_had) == 0 , (
        "docstring-before-import fixture must compile cleanly, got: "
        + "".join([e.pretty_print() for e in prog.errors_had])
    );

    formatted = format_module(mod);
    lines = formatted.split("\n");

    found_doc_line = False;
    for k in range(len(lines)) {
        ln = lines[k];
        if '"""Helpers for registration."""' in ln {
            found_doc_line = True;
            assert k + 1 < len(lines) , "section docstring is the last line";
            nxt = lines[k + 1];
            assert ("import from" in nxt) and ('"""' not in nxt) , (
                "section docstring must sit on its own line directly above "
                f"its import; got next line {nxt!r}"
            );
        }
    }
    assert found_doc_line , (
        f"formatted output lost the section docstring; got {formatted!r}"
    );

    before = format_module(mod);
    after = format_module(mod);
    assert before == after;
}

test "multiline single tok" {
    mypass = JacProgram().compile(os.path.join(LANG_FIXTURES, "byllmissue.jac"));
    assert "2:5 - 4:8" in print_ast_tree(mypass);
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
        'Missing "postinit" method required by uninitialized attribute(s).',
        "    9 | obj Test2 {",
        "   10 |     has var1: str;",
        "   11 |     has var2: int postinit;",
        "      |         ^^^^",
        "   12 | }",
        "Non default attribute 'var4' follows default attribute",
        "   17 |     has var2: int = 42;",
        "   18 |     has var3: int postinit;  # <-- This is fine.",
        "   19 |     has var4: int;  # <-- This should be syntax error.",
        "      |         ^^^^",
        "   20 |",
        "   21 |     def postinit() {"
    ] {
        assert exp in errors_output;
    }
}
