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
import from jaclang.compiler.passes.pyast_load_pass { PyastBuildPass }
import from jaclang.compiler.tools.unparse_pass { unparse_module }
import from jaclang.compiler.frontend.helpers { pascal_to_snake }
import from jaclang.compiler.frontend.parser.lexer { tokenize_full }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.unitree { PythonModuleAst, Source }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "passes", "fixtures");

test "synced to latest py ast" {
    # Python 3.14 moved the unparser to `_ast_unparse` and binds
    # `ast._Unparser` lazily on the first `unparse()` call; trigger that so the
    # introspection works on 3.13 and 3.14+ alike.
    py_ast.unparse(py_ast.parse(""));
    unparser_cls: any = py_ast._Unparser;
    visit_methods = (
        [
            method
            for method in dir(unparser_cls)
            if method.startswith("visit_")
        ]
        + list(unparser_cls.binop.keys())
        + list(unparser_cls.unop.keys())
        + list(unparser_cls.boolops.keys())
        + list(unparser_cls.cmpops.keys())
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
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(file_source), orig_src=Source(file_source, "str2doc.py")
            )
        ).ir_out
    );
    assert '"""This is a test function."""\ndef foo()' in code;
    # \n and \t must remain as escape sequences, not real control characters
    assert '"""hello\\nworld"""' in code;
    assert '"""line1\\ttabbed"""' in code;
}

test "fstring triple quotes" {
    with open(os.path.join(FIXTURES, "py2jac_fstrings.py")) as f {
        file_source = f.read();
    }
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=Source(file_source, "py2jac_fstrings.py")
            )
        ).ir_out
    );
    assert 'f"""Hello\n{name}"""' in code;
    assert "f'''Hello\n{name}'''''''" not in code;
    assert 'f"""Hello\n{name}"""""""' not in code;
}

"""Test that escape sequences are preserved when converting Python to Jac."""
test "py2jac escape sequences" {
    with open(os.path.join(FIXTURES, "py2jac_escape_sequences.py")) as f {
        file_source = f.read();
    }
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=Source(file_source, "py2jac_escape_sequences.py")
            )
        ).ir_out
    );

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

"""`\\N{name}` is the one escape Jac cannot render, so converted code refuses."""
test "py2jac named unicode escape stays loud" {
    file_source = "unicode_named = \"\\N{LATIN SMALL LETTER A}\"\n";
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=Source(file_source, "py2jac_named_unicode.py")
            )
        ).ir_out,
        requires_format=False
    );
    assert "\\N{LATIN SMALL LETTER A}" in code , (
        f"the escape was rewritten on the way out, into:\n{code}"
    );

    # Resolving a character name needs the Unicode name database, which the
    # compiler does not carry, so Jac has no exact rendering for this escape.
    # The emitted code therefore has to refuse at E0110 rather than compile to
    # a string that silently differs from the Python original.
    (_toks, _comments, diags, errs) = tokenize_full(code, "py2jac_named_unicode.jac");
    assert errs , f"the converted Jac lexes clean, so the escape went silent:\n{code}";
    codes = {
        d.code_str
        for d in diags
        if d.is_error
    };
    assert "E0110" in codes , f"refused with {sorted(codes)}, not E0110";
}

"""Implicit string concat across a backslash line-continuation must emit valid Jac (#6928)."""
test "py2jac line continuation string concat" {
    with open(os.path.join(FIXTURES, "py2jac_line_continuation.py")) as f {
        file_source = f.read();
    }
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=Source(file_source, "py2jac_line_continuation.py")
            )
        ).ir_out,
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
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=Source(file_source, "py2jac_binop.py")
            )
        ).ir_out
    );

    assert "((a + b) + c)" not in code , f"Same-op chain not flattened in: {code}";
    assert "((a - b) - c)" not in code , f"Same-op chain not flattened in: {code}";
    assert "a + b + c" in code , f"Expected flat add chain in: {code}";
    assert "a - b - c" in code , f"Expected flat sub chain in: {code}";
    assert "w - title_len - 2 // 2" not in code , f"Mixed-precedence bug in: {code}";
    assert "(w - title_len - 2) // 2" in code , f"Expected correct floor-div grouping in: {code}";
    assert "(w - title_len - 1) // 2" in code , f"Expected correct floor-div grouping in: {code}";
}

"""Mapping star patterns (PEP 634 `{k: v, **rest}`) must unparse with a `**`
rest marker so the emitted Jac re-parses. #8641: UnparsePass emitted `*` for
both MatchStar flavors, and the mapping rest pattern failed to re-parse with
cascading E0045 errors."""
test "py2jac mapping star pattern round-trips" {
    file_source = (
        "def handle(d):\n"
        "    match d:\n"
        "        case {\"k\": key, **rest}:\n"
        "            return key, rest\n"
        "        case {1: first, **others}:\n"
        "            return first, others\n"
        "    return None\n"
    );
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=Source(file_source, "py2jac_match_mapping_star.py")
            )
        ).ir_out,
        requires_format=False
    );

    assert "**rest" in code , f"Expected '**rest' mapping rest marker in:\n{code}";

    # The emitted Jac must round-trip: re-parsing it produces no errors.
    prog = JacProgram.jac_str_formatter(
        source_str=code, file_path="py2jac_match_mapping_star.py", auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );
}
