"""PyAST build pass tests – migrated from test_pyast_build_pass.py.

Tests that Python source files are correctly converted to Jac AST via
the PyastBuildPass, and that specific conversions (docstrings, f-strings)
are handled properly.
"""

import ast as py_ast;
import inspect;
import os;
import sys;
import tempfile;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
import from jaclang.compiler.passes.tool.unparse_pass { unparse_module }
import from jaclang.jac0core.compiler { run_pass }
import from jaclang.jac0core.helpers { pascal_to_snake }
import from jaclang.jac0core.parser.lexer { tokenize_full }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.jac0core.unitree { PythonModuleAst, Source }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures"
     );

def read_fixture(name: str) -> str {
    with open(os.path.join(FIXTURES, name)) as f {
        return f.read();
    }
}

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
            ),
            prog=JacProgram()
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
            ),
            prog=JacProgram()
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
            ),
            prog=JacProgram()
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
            ),
            prog=JacProgram()
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
            ),
            prog=JacProgram()
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
            ),
            prog=JacProgram()
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

"""Complex number literals must emit a shadow-proof `<alias>.complex(re, im)`
qualified through a collision-free `import builtins as <alias>`, instead of a
bare (shadowable) `complex(...)` call or an ICE."""
test "py2jac complex literals" {
    file_source = read_fixture("py2jac_complex.py");
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=Source(file_source, "py2jac_complex.py")
            ),
            prog=JacProgram()
        ).ir_out
    );

    # Shadow-proof qualified reference: a single aliased builtins-module import
    # anchors `<alias>.complex(...)` so a source `def complex` cannot reach it.
    assert "import builtins as" in code , (
        f"Expected an aliased builtins import in:\n{code}"
    );
    assert "return complex(" not in code , (
        f"Must not emit a bare (shadowable) complex call in:\n{code}"
    );
    assert "_jac_py2jac_builtins.complex(0, 1)" in code , (
        f"Expected bare 1j as <alias>.complex(0, 1) in:\n{code}"
    );
    assert "_jac_py2jac_builtins.complex(0, 2)" in code , (
        f"Expected 2.0j conversion in:\n{code}"
    );
    assert "_jac_py2jac_builtins.complex(1, 2)" in code , (
        f"Expected 1+2j as <alias>.complex(1, 2) in:\n{code}"
    );
    assert "_jac_py2jac_builtins.complex(-1, -2)" in code , (
        f"Expected -1-2j as <alias>.complex(-1, -2) in:\n{code}"
    );
    assert "_jac_py2jac_builtins.complex(3, 0)" in code , (
        f"Expected 3+0j as <alias>.complex(3, 0) in:\n{code}"
    );
    assert "_jac_py2jac_builtins.complex(4, 2)" in code , (
        f"Expected 1+2j+3 as <alias>.complex(4, 2) in:\n{code}"
    );
    assert "_jac_py2jac_builtins.complex(-1, 2)" in code , (
        f"Expected 2j-1 as <alias>.complex(-1, 2) in:\n{code}"
    );
    assert ".complex(0, 2) + 1" not in code , (
        f"Reversed complex add must fold, got native-broken binop in:\n{code}"
    );
    assert ".complex(1, 2) + 3" not in code , (
        f"Nested complex add must fold, got native-broken binop in:\n{code}"
    );

    prog = JacProgram.jac_str_formatter(
        source_str=code, file_path="py2jac_complex.py", auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );
}

"""py2jac complex output must run in the server (Python) codespace.

The constructor is qualified as `<alias>.complex` through a real
`import builtins as <alias>`; the alias resolves to the builtins module in the
Python codespace, so the converted code runs instead of crashing with NameError
(the failure mode when the qualified ref had no import anchor). This test
imports and executes the converted module to guard against that regression.
"""
test "py2jac complex literals run in server codespace" {
    file_source = read_fixture("py2jac_complex.py");
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=Source(file_source, "py2jac_complex.py")
            ),
            prog=JacProgram()
        ).ir_out
    );

    tmp = tempfile.mkdtemp();
    mod_name = "py2jac_complex_rt";
    open(os.path.join(tmp, f"{mod_name}.jac"), "w").write(code);
    JacRuntime.jac_import(target=mod_name, base_path=tmp);
    mod = sys.modules[mod_name];

    assert mod.bare_j() == complex(0, 1) , f"bare_j: {mod.bare_j()}";
    assert mod.bare_float_j() == complex(0, 2) , f"bare_float_j: {mod.bare_float_j()}";
    assert mod.add_complex() == complex(1, 2) , f"add_complex: {mod.add_complex()}";
    assert mod.negative_complex() == complex(-1, -2) , (
        f"negative_complex: {mod.negative_complex()}"
    );
    assert mod.complex_real_only() == complex(3, 0) , (
        f"complex_real_only: {mod.complex_real_only()}"
    );
    assert mod.reversed_add_complex() == complex(1, 2) , (
        f"reversed_add_complex: {mod.reversed_add_complex()}"
    );
    assert mod.nested_add_complex() == complex(4, 2) , (
        f"nested_add_complex: {mod.nested_add_complex()}"
    );
    assert mod.reversed_sub_complex() == complex(-1, 2) , (
        f"reversed_sub_complex: {mod.reversed_sub_complex()}"
    );
}

"""None constants must emit NULL token, not NONETYPE."""
test "py2jac null constant" {
    source = "def f() -> None:\n    return None\n";
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(source), orig_src=Source(source, "py2jac_null.py")
            ),
            prog=JacProgram()
        ).ir_out
    );
    assert "return None" in code , f"Expected None literal in:\n{code}";
    prog = JacProgram.jac_str_formatter(
        source_str=code, file_path="py2jac_null.py", auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );
}

"""Complex py2jac output must lower to native without E1055 overload errors."""
test "py2jac complex literals native lowering" {
    import from jaclang.jac0core.compile_options { CompileOptions }
    import from jaclang.jac0core.compiler { native_pipeline_available }
    (pipeline_ok, pipeline_reason) = native_pipeline_available();
    if not pipeline_ok {
        testskip(pipeline_reason);
    }
    file_source = read_fixture("py2jac_complex.py");
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=Source(file_source, "py2jac_complex.py")
            ),
            prog=JacProgram()
        ).ir_out
    );
    prog = JacProgram();
    mod = prog.compile(
        file_path="py2jac_complex.jac",
        use_str=code,
        options=CompileOptions(
            type_check=False,
            force_codespace='native',
            force_target_program=True,
            skip_native_engine=True
        )
    );
    assert not prog.errors_had , (
        f"Native lowering errors: {[e.pretty_print() for e in prog.errors_had]}\n"
        f"code:\n{code}"
    );
    assert mod.gen.llvm_ir is not None , (
        "Expected native IR for folded complex literals"
    );
}

"""Source-name shadowing must not reach folded complex/float literals.

The source defines its own `complex`/`float` AND collides with the default
alias `_jac_py2jac_builtins`. py2jac must pick a fresh suffix, qualify the
constructors through the real builtins module, and the folded literal must still
produce the true complex value at runtime -- not the source's `EVIL` function.
"""
test "py2jac builtin shadowing is resolved through the alias" {
    source = (
        "_jac_py2jac_builtins = 1\n"
        "def complex(re, im):\n"
        "    return 'EVIL'\n"
        "def float(x):\n"
        "    return 'EVIL'\n"
        "def make():\n"
        "    return 1 + 2j\n"
    );
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(source), orig_src=Source(source, "py2jac_shadow.py")
            ),
            prog=JacProgram()
        ).ir_out
    );

    # Collision-free suffix: the source stole the base alias, so a fresh one is used.
    assert "import builtins as _jac_py2jac_builtins2;" in code , (
        f"Expected suffixed alias under collision in:\n{code}"
    );
    assert "as _jac_py2jac_builtins;" not in code , (
        f"Must not reuse the colliding alias in:\n{code}"
    );
    # The folded literal is qualified through the real builtins module, not bare.
    assert "_jac_py2jac_builtins2.complex(1, 2)" in code , (
        f"Expected <alias>.complex(1, 2) in:\n{code}"
    );
    assert "return complex(1, 2)" not in code , (
        f"Must not emit a bare (shadowable) complex call in:\n{code}"
    );
    # The source's own shadowing definitions are preserved verbatim.
    assert "def complex" in code and "'EVIL'" in code , (
        f"Source complex/float must be preserved in:\n{code}"
    );

    # Runtime proof: the folded literal yields the true complex value, not 'EVIL'.
    tmp = tempfile.mkdtemp();
    mod_name = "py2jac_shadow_rt";
    open(os.path.join(tmp, f"{mod_name}.jac"), "w").write(code);
    JacRuntime.jac_import(target=mod_name, base_path=tmp);
    mod = sys.modules[mod_name];
    result = mod.make();
    assert result == complex(1, 2) , (
        f"Shadowed complex leaked into folded literal; got {result!r}"
    );
}

"""Match captures and except targets must reserve the builtins alias.

`case x as _jac_py2jac_builtins:` and `except E as _jac_py2jac_builtins:` bind
their target without any py_ast.Name node, so the alias chooser must collect
them from MatchAs/MatchStar/MatchMapping.rest/ExceptHandler directly -- a miss
would inject an import that silently rebinds the capture inside its scope.
"""
test "py2jac alias avoids match and except bindings" {
    match_source = (
        "def make():\n"
        "    return 1 + 2j\n\n"
        "def grab(v):\n"
        "    match v:\n"
        "        case [_jac_py2jac_builtins]:\n"
        "            return _jac_py2jac_builtins\n"
    );
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(match_source),
                orig_src=Source(match_source, "py2jac_alias_match.py")
            ),
            prog=JacProgram()
        ).ir_out
    );
    assert "as _jac_py2jac_builtins;" not in code , (
        f"Must not collide with a match-captured name in:\n{code}"
    );
    assert "_jac_py2jac_builtins2.complex(1, 2)" in code , (
        f"Expected suffixed alias under match-capture collision in:\n{code}"
    );

    except_source = (
        "def make():\n"
        "    return 1 + 2j\n\n"
        "def risky():\n"
        "    try:\n"
        "        pass\n"
        "    except ValueError as _jac_py2jac_builtins:\n"
        "        return None\n"
    );
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(except_source),
                orig_src=Source(except_source, "py2jac_alias_except.py")
            ),
            prog=JacProgram()
        ).ir_out
    );
    assert "as _jac_py2jac_builtins;" not in code , (
        f"Must not collide with an except-bound name in:\n{code}"
    );
    assert "_jac_py2jac_builtins2.complex(1, 2)" in code , (
        f"Expected suffixed alias under except-binding collision in:\n{code}"
    );
}

"""NaN (unreachable from source literals) lowers to `<alias>.float('nan')`.

Python source cannot spell a NaN literal, so the non-finite branch of
_numeric_literal is exercised by mutating a Constant's value to float('nan').
The emitted call must be qualified through the alias and produce a real NaN.
"""
test "py2jac nan lowers to aliased float call" {
    tree = py_ast.parse("def f():\n    return 0.0\n");
    tree.body[0].body[0].value.value = float('nan');
    source = "def f():\n    return 0.0\n";
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(tree, orig_src=Source(source, "py2jac_nan.py")),
            prog=JacProgram()
        ).ir_out
    );

    assert "import builtins as" in code , (
        f"Expected an aliased builtins import for nan in:\n{code}"
    );
    assert "_jac_py2jac_builtins.float('nan')" in code , (
        f"Expected <alias>.float('nan') in:\n{code}"
    );
    assert "float('nan')" in code , f"Expected a nan construction in:\n{code}";

    tmp = tempfile.mkdtemp();
    mod_name = "py2jac_nan_rt";
    open(os.path.join(tmp, f"{mod_name}.jac"), "w").write(code);
    JacRuntime.jac_import(target=mod_name, base_path=tmp);
    mod = sys.modules[mod_name];
    nan_val = mod.f();
    assert nan_val != nan_val , (
        f"Expected a real NaN (self-inequality); got {nan_val!r}"
    );
}

"""Modules without complex/nan literals must not receive the builtins import."""
test "py2jac no builtins import for plain and inf numbers" {
    source = "def pos():\n    return 1e309\ndef neg():\n    return -1e309\ndef n():\n    return 7\n";
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(source), orig_src=Source(source, "py2jac_noinf.py")
            ),
            prog=JacProgram()
        ).ir_out
    );
    assert "import builtins" not in code , (
        f"Plain/inf-only module must not inject a builtins import in:\n{code}"
    );
}

"""qualified_builtin_name must use symbol identity, not the textual name.

A real `import builtins; builtins.len(...)` must classify as the builtin; a user
object that merely happens to be named `builtins` must NOT (it would mis-dispatch
native codegen onto a method). Compiled server-side so `.sym` is resolved; this
exercises the fix in symbol_utils directly without native execution.
"""
test "qualified builtin recognition is symbol-based" {
    import jaclang.jac0core.unitree as uni;
    import from jaclang.jac0core.compile_options { CompileOptions }
    import from jaclang.compiler.symbol_utils { qualified_builtin_name }

    def find_len_call(mod: uni.Module) -> (uni.FuncCall | None) {
        for fc in mod.get_all_sub_nodes(uni.FuncCall) {
            if (
                isinstance(fc.target, uni.AtomTrailer)
                and isinstance(fc.target.right, uni.Name)
                and fc.target.right.value == "len"
            ) {
                return fc;
            }
        }
        return None;
    }

    tmp = tempfile.mkdtemp();

    # Case A: a genuine `import builtins` -> the call is the builtin `len`.
    path_a = os.path.join(tmp, "real_builtins.jac");
    open(path_a, "w").write(
        "import builtins;\n" "def f(x: list[int]) -> int { return builtins.len(x); }\n"
    );
    mod_a = JacProgram().compile(
        file_path=path_a, options=CompileOptions(default_codespace='server')
    );
    fc_a = find_len_call(mod_a);
    assert fc_a is not None , "real-builtins case produced no builtins.len call";
    assert qualified_builtin_name(fc_a.target) == "len" , (
        f"Real `import builtins` must resolve to builtin len; target sym: "
        f"{fc_a.target.target.sym}"
    );
    assert fc_a.call_kind == "builtin" , (
        f"Real builtins.len must classify as BUILTIN, got {fc_a.call_kind}"
    );

    # Case B: a user object named `builtins` -> NOT the builtin module.
    path_b = os.path.join(tmp, "user_builtins.jac");
    open(path_b, "w").write(
        "obj Holder {\n"
        "    has n: int = 9;\n"
        "    def len(self) -> int { return self.n; }\n"
        "}\n"
        "def f() -> int {\n"
        "    builtins: Holder = Holder();\n"
        "    return builtins.len();\n"
        "}\n"
    );
    mod_b = JacProgram().compile(
        file_path=path_b, options=CompileOptions(default_codespace='server')
    );
    fc_b = find_len_call(mod_b);
    assert fc_b is not None , "user-object case produced no builtins.len call";
    assert qualified_builtin_name(fc_b.target) is None , (
        f"User object named builtins must NOT be treated as the builtin module"
    );
    assert fc_b.call_kind != "builtin" , (
        f"builtins.len() on a user object must not classify as BUILTIN, "
        f"got {fc_b.call_kind}"
    );
}

"""Adjacent f-strings folded by Python must emit valid Jac f-strings."""
test "py2jac fstring adjacent multiline" {
    file_source = read_fixture("py2jac_fstring_adjacent_multiline.py");
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=Source(file_source, "py2jac_fstring_adjacent_multiline.py")
            ),
            prog=JacProgram()
        ).ir_out,
        requires_format=False
    );

    assert 'f"A' not in code or 'f"Welcome aboard"' in code , (
        f"Mangled adjacent f-string quotes in:\n{code}"
    );
    assert 'f"B' not in code , f"Leaked f-string prefix in:\n{code}";

    prog = JacProgram.jac_str_formatter(
        source_str=code,
        file_path="py2jac_fstring_adjacent_multiline.py",
        auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );

    formatted = prog.mod.main.gen.jac;
    assert "Welcome aboard" in formatted , (
        f"Expected folded f-string content in:\n{formatted}"
    );
}

"""Single-line adjacent f-strings with mixed quotes must not mangle output."""
test "py2jac fstring adjacent singleline" {
    file_source = read_fixture("py2jac_fstring_adjacent_singleline.py");
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=Source(file_source, "py2jac_fstring_adjacent_singleline.py")
            ),
            prog=JacProgram()
        ).ir_out,
        requires_format=False
    );

    assert 'f"""A\' f"B"""' not in code , f"Mangled single-line f-string in:\n{code}";

    prog = JacProgram.jac_str_formatter(
        source_str=code,
        file_path="py2jac_fstring_adjacent_singleline.py",
        auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );

    formatted = prog.mod.main.gen.jac;
    assert "AB" in formatted , f"Expected folded 'AB' in:\n{formatted}";
}

"""Immediately-invoked lambda expressions must parenthesize the call target."""
test "py2jac lambda iife" {
    file_source = read_fixture("py2jac_lambda_iife.py");
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=Source(file_source, "py2jac_lambda_iife.py")
            ),
            prog=JacProgram()
        ).ir_out,
        requires_format=False
    );

    assert "lambda (x: Any) { (x + 1); }(10)" not in code , (
        f"Unparenthesized lambda call target in:\n{code}"
    );
    assert "(lambda (x: Any) { (x + 1); })(10)" in code , (
        f"Expected parenthesized lambda IIFE in:\n{code}"
    );

    prog = JacProgram.jac_str_formatter(
        source_str=code, file_path="py2jac_lambda_iife.py", auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );
}

"""Hash inside an f-string must survive the formatter intact (not escaped to \\#).

A regression that re-adds `#` -> `\\#` escaping in unitree.fstring_escape_interior
still re-parses cleanly (it is a wrong *value*, not a syntax error), so the
zero-error round-trip used elsewhere does NOT guard it. Inspect the formatted
text directly.
"""
test "py2jac fstring hash survives formatter" {
    file_source = read_fixture("py2jac_fstring_hash.py");
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=Source(file_source, "py2jac_fstring_hash.py")
            ),
            prog=JacProgram()
        ).ir_out
    );

    prog = JacProgram.jac_str_formatter(
        source_str=code, file_path="py2jac_fstring_hash.py", auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );

    formatted = prog.mod.main.gen.jac;
    assert "a # b" in formatted , (
        f"Hash inside f-string must survive formatting in:\n{formatted}"
    );
    assert "\\#" not in formatted , (
        f"Hash must not be escaped to backslash-hash in:\n{formatted}"
    );
}

"""Overflowed imaginary literals (1e999j) must not crash; isfinite guard emits inf.

Without the math.isfinite guard in _numeric_literal, the imaginary part of
`1e999j` overflows to inf and `inf == int(inf)` raises OverflowError. Infinity
is spelled as an overflowing float literal (`1e309`) so it stays a compile-time
constant rather than a shadowable `float('inf')` call.
"""
test "py2jac complex inf imaginary" {
    file_source = read_fixture("py2jac_complex_inf.py");
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=Source(file_source, "py2jac_complex_inf.py")
            ),
            prog=JacProgram()
        ).ir_out
    );

    assert "complex(0, 1e309)" in code , (
        f"Expected 1e999j to fold to complex(0, 1e309) in:\n{code}"
    );

    prog = JacProgram.jac_str_formatter(
        source_str=code, file_path="py2jac_complex_inf.py", auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );
}

"""Overflowed plain float literals must emit 1e309, not the `inf` identifier.

The same non-finite guard covers plain floats: `1e309` is a Python float
constant (value inf), but `str(float('inf'))` is `"inf"`, which Jac lexes as a
name -- producing an undefined-name error instead of preserving the value.
"""
test "py2jac plain float inf" {
    file_source = read_fixture("py2jac_float_inf.py");
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=Source(file_source, "py2jac_float_inf.py")
            ),
            prog=JacProgram()
        ).ir_out
    );

    assert "return 1e309" in code , f"Expected 1e309 literal in:\n{code}";
    assert "return -1e309" in code , f"Expected -1e309 literal in:\n{code}";
    assert "return inf" not in code , f"Bare `inf` identifier leaked in:\n{code}";

    prog = JacProgram.jac_str_formatter(
        source_str=code, file_path="py2jac_float_inf.py", auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );

    tmp = tempfile.mkdtemp();
    mod_name = "py2jac_float_inf_rt";
    open(os.path.join(tmp, f"{mod_name}.jac"), "w").write(code);
    JacRuntime.jac_import(target=mod_name, base_path=tmp);
    mod = sys.modules[mod_name];
    assert mod.pos() == float("inf") , f"pos: {mod.pos()}";
    assert mod.neg() == float("-inf") , f"neg: {mod.neg()}";
}

"""A complex literal in a match value pattern must emit E5044.

`case 1 + 2j:` folds to a complex value; Jac has no complex literal syntax and
would parse `complex(1, 2)` as a class pattern, so proc_match_value emits E5044.
"""
test "py2jac match complex value emits E5044" {
    file_source = read_fixture("py2jac_match_complex.py");
    prog = JacProgram();
    run_pass(
        PyastBuildPass,
        PythonModuleAst(
            py_ast.parse(file_source),
            orig_src=Source(file_source, "py2jac_match_complex.py")
        ),
        prog
    );

    assert any(
        (e.code is not None and e.code.code == "E5044") for e in prog.errors_had
    ) , (
        f"Expected E5044 for complex match value; got "
        f"{[e.code.code if e.code else None for e in prog.errors_had]}"
    );
}

"""A ternary expression as a call target must be parenthesized.

Generalizes the lambda-IIFE fix: `(a if c else b)(10)` must parenthesize the
ternary, otherwise it re-parses as `a if c else b(10)` -- valid Jac that calls
`b` instead of the chosen branch. The same rule now covers every compound
expression kind (BinOp, BoolOp, Compare, Unary, Await) as a call target.
"""
test "py2jac ternary call target" {
    file_source = read_fixture("py2jac_ternary_call.py");
    code = unparse_module(
        PyastBuildPass(
            ir_in=PythonModuleAst(
                py_ast.parse(file_source),
                orig_src=Source(file_source, "py2jac_ternary_call.py")
            ),
            prog=JacProgram()
        ).ir_out,
        requires_format=False
    );

    assert "a if c else b(10)" not in code , (
        f"Unparenthesized ternary call target in:\n{code}"
    );
    assert "(a if c else b)(10)" in code , (
        f"Expected parenthesized ternary call target in:\n{code}"
    );

    prog = JacProgram.jac_str_formatter(
        source_str=code, file_path="py2jac_ternary_call.py", auto_lint=False
    );
    assert len(prog.errors_had) == 0 , (
        f"Re-parse errors: {[str(e) for e in prog.errors_had]}\ncode:\n{code}"
    );
}
