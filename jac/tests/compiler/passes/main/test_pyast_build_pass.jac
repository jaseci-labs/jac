"""PyAST build pass tests – migrated from test_pyast_build_pass.py.

Tests that Python source files are correctly converted to Jac AST via
the PyastBuildPass, and that specific conversions (docstrings, f-strings)
are handled properly.
"""

import ast as py_ast;
import inspect;
import os;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
import from jaclang.jac0core.helpers { pascal_to_snake }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.unitree { PythonModuleAst, Source }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures"
     );

test "synced to latest py ast" {
    # Python 3.14 moved the unparser to `_ast_unparse` and binds
    # `ast._Unparser` lazily on the first `unparse()` call; trigger that so the
    # introspection works on 3.13 and 3.14+ alike.
    py_ast.unparse(py_ast.parse(""));
    unparser_cls = py_ast._Unparser;
    visit_methods = (
        [
            method
            for method in dir(unparser_cls)
            if method.startswith("visit_")
        ] + list(unparser_cls.binop.keys()) + list(unparser_cls.unop.keys()) + list(
            unparser_cls.boolops.keys()
        ) + list(unparser_cls.cmpops.keys())
    );
    node_names = [
        pascal_to_snake(method.replace("visit_", "")) for method in visit_methods
    ];
    pass_func_names = [];
    for (name, value) in inspect.getmembers(PyastBuildPass) {
        if name.startswith("proc_") and inspect.isfunction(value) {
            pass_func_names.append(name.replace("proc_", ""));
        }
    }
    # Handlers for ast nodes introduced in a newer Python than the one running
    # this test are forward-compatible, not stale -- exempt them from the
    # "extra handler" direction. (e.g. interactive + PEP 750 t-strings are 3.14.)
    forward_compat = {"interactive", "template_str", "interpolation"};
    for name in pass_func_names {
        if name in forward_compat {
            continue;
        }
        assert name in node_names , f"Pass func {name} not in py_ast nodes";
    }
    for name in node_names {
        assert name in pass_func_names , f"py_ast node {name} not in pass funcs";
    }
}

test "str2doc" {
    with open(os.path.join(FIXTURES, "str2doc.py")) as f {
        file_source = f.read();
    }
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source), orig_src=Source(file_source, "str2doc.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse();
    assert '"""This is a test function."""\ndef foo()' in code;
    # \n and \t must remain as escape sequences, not real control characters
    assert '"""hello\\nworld"""' in code;
    assert '"""line1\\ttabbed"""' in code;
}

test "fstring triple quotes" {
    with open(os.path.join(FIXTURES, "py2jac_fstrings.py")) as f {
        file_source = f.read();
    }
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source),
            orig_src=Source(file_source, "py2jac_fstrings.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse();
    assert 'f"""Hello\n{name}"""' in code;
    assert "f'''Hello\n{name}'''''''" not in code;
    assert 'f"""Hello\n{name}"""""""' not in code;
}

"""Test that escape sequences are preserved when converting Python to Jac."""
test "py2jac escape sequences" {
    with open(os.path.join(FIXTURES, "py2jac_escape_sequences.py")) as f {
        file_source = f.read();
    }
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source),
            orig_src=Source(file_source, "py2jac_escape_sequences.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse();

    # No actual ESC character (0x1b) should leak into output
    assert chr(0x1b) not in code;

    # Hex/octal/standard escapes preserved
    assert "\\x1b[31m" in code and "\\x1b[0m" in code;
    assert "\\x1b[32m" in code or "\\033[32m" in code;
    assert "\\n" in code and "\\t" in code;

    # F-strings, raw strings, triple-quoted
    assert "f\"\\x1b[" in code or "f'\\x1b[" in code;
    assert 'r"\\x1b[31m' in code or "r'\\x1b[31m" in code;
    assert 'f"""Hello {name}' in code or "f'''Hello {name}" in code;

    # Backslashes, quotes, unicode, braces, hash
    assert "path\\\\to\\\\file" in code;
    assert "\\u0041" in code or "A" in code;
    assert "{{literal braces}}" in code;
    assert "# not a comment" in code;
    assert "\\x00" in code;
}

"""Implicit string concat across a backslash line-continuation must emit valid Jac (#6928)."""
test "py2jac line continuation string concat" {
    with open(os.path.join(FIXTURES, "py2jac_line_continuation.py")) as f {
        file_source = f.read();
    }
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source),
            orig_src=Source(file_source, "py2jac_line_continuation.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse(
        requires_format=False
    );

    # The source `\` line-continuation must not leak into the emitted Jac: a
    # backslash immediately followed by a newline is only valid *inside* a string
    # literal, and this fixture deliberately has none of those.
    assert "\\\n" not in code , f"Stray line-continuation leaked into:\n{code}";

    # The emitted Jac must round-trip: re-parsing it produces no errors. This is
    # the layer where the leaked `\` surfaced as "Unexpected character: '\'".
    prog = JacProgram.jac_str_formatter(
        source_str=code, file_path="py2jac_line_continuation.py", auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );

    # The folded literals survive as adjacent Jac strings with escapes intact.
    formatted = prog.mod.main.gen.jac;
    assert '"abc" "def"' in formatted , f"Expected folded concat in:\n{formatted}";
    assert "line two\\n" in formatted , f"Expected preserved \\n escape in:\n{formatted}";
}

"""Test BinOp chain flattening and mixed-precedence grouping."""
test "py2jac binop operator precedence" {
    with open(os.path.join(FIXTURES, "py2jac_binop.py")) as f {
        file_source = f.read();
    }
    code = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(file_source), orig_src=Source(file_source, "py2jac_binop.py")
        ),
        prog=JacProgram()
    ).ir_out.unparse();

    assert "((a + b) + c)" not in code , f"Same-op chain not flattened in: {code}";
    assert "((a - b) - c)" not in code , f"Same-op chain not flattened in: {code}";
    assert "a + b + c" in code , f"Expected flat add chain in: {code}";
    assert "a - b - c" in code , f"Expected flat sub chain in: {code}";
    assert "w - title_len - 2 // 2" not in code , f"Mixed-precedence bug in: {code}";
    assert "(w - title_len - 2) // 2" in code , f"Expected correct floor-div grouping in: {code}";
    assert "(w - title_len - 1) // 2" in code , f"Expected correct floor-div grouping in: {code}";
}
