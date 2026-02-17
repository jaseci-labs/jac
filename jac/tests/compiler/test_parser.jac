"""Parser tests – migrated from test_parser.py.

Tests for the Jac RD parser: fstring escapes, fixtures, AST normalize
coverage, syntax error handling, JSX, client keyword, anonymous abilities,
and micro suite.
"""

import inspect;
import io;
import os;
import re;
import sys;
import from pathlib { Path }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { CodeContext }
import from jaclang.jac0core.parser { parse as rd_parse }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.runtimelib.utils { read_file_with_encoding }
import from jaclang.runtimelib.test { parametrize }
import from tests.fixtures_list { MICRO_JAC_FILES }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "fixtures"),
     LANG_FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures");

def load_fixture(fixture: str) -> str {
    return read_file_with_encoding(os.path.join(FIXTURES, fixture));
}

def file_to_str(file_path: str) -> str {
    return read_file_with_encoding(file_path);
}

test "fstring escape brace" {
    (module, parse_errors, lex_errors) = rd_parse('glob a=f"{{}}", not_b=4;', "");
    assert not parse_errors and not lex_errors;
}

test "parser fam" {
    (module, parse_errors, lex_errors) = rd_parse(load_fixture("fam.jac"), "");
    assert not parse_errors and not lex_errors;
}

test "staticmethod checks out" {
    (module, parse_errors, lex_errors) = rd_parse(load_fixture("staticcheck.jac"), "");
    out = module.pp();
    assert not parse_errors and not lex_errors;
    assert "staticmethod" not in out;
}

test "parser kwesc" {
    (module, parse_errors, lex_errors) = rd_parse(load_fixture("kwesc.jac"), "");
    assert not parse_errors and not lex_errors;
}

test "parser mod doc test" {
    (module, parse_errors, lex_errors) = rd_parse(load_fixture("mod_doc_test.jac"), "");
    assert not parse_errors and not lex_errors;
}

test "all ast has normalize" {
    import from jaclang.compiler.passes.tool.normalize_pass { NormalizePass }
    import from jaclang.jac0core.helpers { pascal_to_snake }

    exclude = [
        "UniNode",
        "UniScopeNode",
        "UniCFGNode",
        "ContextAwareNode",
        "ProgramModule",
        "WalkerStmtOnlyNode",
        "Source",
        "EmptyToken",
        "AstSymbolNode",
        "AstSymbolStubNode",
        "AstImplNeedingNode",
        "AstAccessNode",
        "Literal",
        "AstDocNode",
        "AstSemStrNode",
        "PythonModuleAst",
        "AstAsyncNode",
        "AstElseBodyNode",
        "AstTypedVarNode",
        "AstImplOnlyNode",
        "Expr",
        "AtomExpr",
        "ElementStmt",
        "ArchBlockStmt",
        "EnumBlockStmt",
        "CodeBlockStmt",
        "NameAtom",
        "ArchSpec",
        "MatchPattern",

    ];
    module_name = uni.__name__;
    module = sys.modules[module_name];
    source_code = inspect.getsource(module);
    classes = inspect.getmembers(module, inspect.isclass);
    uni_node_classes = [
        cls
        for (_, cls) in classes
        if issubclass(cls, uni.UniNode) and not issubclass(cls, uni.Token)
    ];
    ordered_classes = sorted(
        uni_node_classes, key=lambda cls : source_code.find(f"class {cls.__name__}"),
    );
    for cls in ordered_classes {
        if cls.__name__ not in exclude {
            method_name = f"enter_{pascal_to_snake(cls.__name__)}";
            assert hasattr(NormalizePass, method_name) , (
                f"NormalizePass missing {method_name} for {cls.__name__}"
            );
        }
    }
}

test "inner mod impl" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "codegentext.jac"));
    assert not prog.errors_had;
}

test "param syntax" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    prog = JacProgram();
    prog.compile(os.path.join(LANG_FIXTURES, "params", "param_syntax_err.jac"));
    sys.stdout = sys.__stdout__;
    assert len(prog.errors_had) == 8;
}

test "new keyword errors" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "new_keyword_errors.jac"));
    sys.stdout = sys.__stdout__;
    assert len(prog.errors_had) == 4;
    expected_substrings = [
        "The 'new' keyword is not supported in Jac",
        "Use `Reflect.construct(target, argumentsList)` method to create new instances",
        "The 'new' keyword is not supported in Jac",
        "Use `Reflect.construct(target, argumentsList)` method to create new instances",

    ];
    for (alrt, expected) in zip(prog.errors_had, expected_substrings, strict=True) {
        pretty = alrt.pretty_print();
        assert expected in pretty;
    }
}

test "pass keyword errors" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "pass_keyword_errors.jac"));
    sys.stdout = sys.__stdout__;
    assert len(prog.errors_had) == 34;
    expected_substrings = 17 * [
        "'pass' keyword is not allowed in Jac",
        "Jac does not allow this keyword in any syntactic position",

    ];
    for (alrt, expected) in zip(prog.errors_had, expected_substrings, strict=True) {
        pretty = alrt.pretty_print();
        assert expected in pretty;
    }
}

test "multiple syntax errors" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "multiple_syntax_errors.jac"));
    sys.stdout = sys.__stdout__;
    assert len(prog.errors_had) == 3;
    expected_substrings = ["Missing RPAREN", "Missing COMMA", "Unexpected token", ];
    for (alrt, expected) in zip(prog.errors_had, expected_substrings, strict=True) {
        pretty = alrt.pretty_print();
        assert expected in pretty;
    }
}

test "jsx comprehensive fixture" {
    fixture_path = os.path.join(
        JAC_ROOT,
        "tests",
        "compiler",
        "passes",
        "ecmascript",
        "fixtures",
        "client_jsx.jac"
    );
    source_text = Path(fixture_path).read_text(encoding="utf-8");
    (module, parse_errors, lex_errors) = rd_parse(source_text, str(fixture_path));
    combined_errors = parse_errors + lex_errors;
    all_errors = [str(e) for e in combined_errors];
    assert not parse_errors and not lex_errors , (
        f"Parser reported errors for JSX fixture: {all_errors}"
    );
    tree_repr = module.pp();

    expected_snippets = {
        "self_closing": "<div />",
        "attribute_binding": "id={name}",
        "namespaced_component": "<Form.Input.Text />",
        "fragment": "<>",
        "spread_attribute": "{...props}",
        "expression_child": '{"Hello " + name + "!"}',

    };
    for (label, snippet) in expected_snippets.items() {
        assert snippet in source_text , f"{label}: {snippet} not found in source";
    }

    ast_markers = {
        "JsxElement": "JsxElement" in tree_repr,
        "FragmentTokens": "Token - <>" in tree_repr and "Token - </>" in tree_repr,
        "JsxSpreadAttribute": "JsxSpreadAttribute" in tree_repr,

    };
    for (label, present) in ast_markers.items() {
        assert present , f"{label} missing from AST pretty print";
    }
}

test "client keyword tagging" {
    # Test 1: Mixed single and block client markers
    source = """
cl glob foo = 1;
glob bar = 2;
cl {
    glob baz = 3;
    test sample {}
}
""";
    mod = JacProgram().parse_str(source, "test.jac");
    bd = mod.body;
    assert [type(stmt).__name__ for stmt in bd] == [
        "GlobalVars",
        "GlobalVars",
        "ClientBlock",

    ];
    assert [
        isinstance(stmt, uni.ContextAwareNode)
        and stmt.code_context == CodeContext.CLIENT for stmt in bd
    ] == [True, False, False, ];
    client_block = bd[2];
    assert isinstance(client_block, uni.ClientBlock);
    assert len(client_block.body) == 2;
    assert [type(stmt).__name__ for stmt in client_block.body] == [
        "GlobalVars",
        "Test"
    ];
    assert all(
        stmt.code_context == CodeContext.CLIENT
        for stmt in client_block.body
        if isinstance(stmt, uni.ContextAwareNode)
    );

    # Test 2: Block with different statement types
    source = """
cl {
    import foo;
    glob x = 1;
    obj MyClass {}
    test my_test {}
}
""";
    mod = JacProgram().parse_str(source, "test.jac");
    bd = mod.body;
    assert len(bd) == 1;
    assert isinstance(bd[0], uni.ClientBlock);
    assert len(bd[0].body) == 4;
    assert all(
        stmt.code_context == CodeContext.CLIENT
        for stmt in bd[0].body
        if isinstance(stmt, uni.ContextAwareNode)
    );

    # Test 3: Multiple cl blocks at top level
    source = """
cl {
    glob a = 1;
}
glob b = 2;
cl {
    glob c = 3;
}
""";
    mod = JacProgram().parse_str(source, "test.jac");
    bd = mod.body;
    assert len(bd) == 3;
    assert isinstance(bd[0], uni.ClientBlock);
    assert isinstance(bd[1], uni.GlobalVars);
    assert isinstance(bd[2], uni.ClientBlock);
    assert not (
        isinstance(bd[1], uni.ContextAwareNode)
        and bd[1].code_context == CodeContext.CLIENT
    );

    # Test 4: Empty client block
    source = """
cl {}
glob x = 1;
""";
    mod = JacProgram().parse_str(source, "test.jac");
    bd = mod.body;
    assert len(bd) == 2;
    assert isinstance(bd[0], uni.ClientBlock);
    assert len(bd[0].body) == 0;
    assert isinstance(bd[1], uni.GlobalVars);
    assert not (
        isinstance(bd[1], uni.ContextAwareNode)
        and bd[1].code_context == CodeContext.CLIENT
    );

    # Test 5: Various statement types with single cl marker
    source = """
cl import foo;
cl obj MyClass {}
cl test my_test {}
""";
    mod = JacProgram().parse_str(source, "test.jac");
    bd = mod.body;
    assert len(bd) == 3;
    assert all(
        stmt.code_context == CodeContext.CLIENT
        for stmt in bd
        if isinstance(stmt, uni.ContextAwareNode)
    );
}

test "anonymous ability decl" {
    # Test 1: Anonymous ability with entry event
    source = """
walker MyWalker {
    can with entry {
        print("hello");
    }
}
""";
    prog = JacProgram();
    mod = prog.parse_str(source, "test.jac");
    assert not prog.errors_had;
    wlk = mod.body[0];
    assert isinstance(wlk, uni.Archetype);
    assert wlk.body is not None;
    abls = [
        stmt
        for stmt in wlk.body
        if type(stmt).__name__ == "Ability"
    ];
    assert len(abls) == 1;
    abl = abls[0];
    assert isinstance(abl, uni.Ability);
    assert abl.name_ref is not None;
    resolved_name = abl.py_resolve_name();
    assert resolved_name.startswith("__ability_entry_");
    assert resolved_name.endswith("__");

    # Test 2: Anonymous ability with exit event
    source = """
walker MyWalker {
    can with exit {
        print("goodbye");
    }
}
""";
    prog = JacProgram();
    mod = prog.parse_str(source, "test.jac");
    assert not prog.errors_had;
    wlk = mod.body[0];
    assert isinstance(wlk, uni.Archetype);
    assert wlk.body is not None;
    abls = [
        stmt
        for stmt in wlk.body
        if type(stmt).__name__ == "Ability"
    ];
    abl = abls[0];
    assert isinstance(abl, uni.Ability);
    resolved_name = abl.py_resolve_name();
    assert resolved_name.startswith("__ability_exit_");

    # Test 3: Named ability still works
    source = """
walker MyWalker {
    can my_ability with entry {
        print("named");
    }
}
""";
    prog = JacProgram();
    mod = prog.parse_str(source, "test.jac");
    assert not prog.errors_had;
    wlk = mod.body[0];
    assert isinstance(wlk, uni.Archetype);
    assert wlk.body is not None;
    abls = [
        stmt
        for stmt in wlk.body
        if type(stmt).__name__ == "Ability"
    ];
    abl = abls[0];
    assert isinstance(abl, uni.Ability);
    assert abl.name_ref is not None;
    assert abl.py_resolve_name() == "my_ability";

    # Test 4: Multiple anonymous abilities generate unique names
    source = """
walker MyWalker {
    can with entry {
        print("first");
    }
    can with entry {
        print("second");
    }
}
""";
    prog = JacProgram();
    mod = prog.parse_str(source, "test.jac");
    assert not prog.errors_had;
    wlk = mod.body[0];
    assert isinstance(wlk, uni.Archetype);
    assert wlk.body is not None;
    abls = [
        stmt
        for stmt in wlk.body
        if type(stmt).__name__ == "Ability"
    ];
    assert len(abls) == 2;
    abl0 = abls[0];
    abl1 = abls[1];
    assert isinstance(abl0, uni.Ability);
    assert isinstance(abl1, uni.Ability);
    name1 = abl0.py_resolve_name();
    name2 = abl1.py_resolve_name();
    assert name1 != name2;
}

test "cl import with jac runtime" {
    source = """
cl import from "@jac/runtime" {
    jacLogin,
    jacLogout,
    renderJsxTree,
}
""";
    prog = JacProgram();
    mod = prog.parse_str(source, "test.jac");
    assert not prog.errors_had , f"Parser errors: {prog.errors_had}";

    imports = [
        stmt
        for stmt in mod.body
        if type(stmt).__name__ == "Import"
    ];
    assert len(imports) == 1 , "Should have one import statement";

    import_stmt = imports[0];
    assert isinstance(import_stmt, uni.Import);
    assert import_stmt.code_context == CodeContext.CLIENT , (
        "Import should be marked as client-side"
    );
    assert import_stmt.from_loc is not None , "Import should have from_loc";
    assert import_stmt.from_loc.dot_path_str == "@jac/runtime" , (
        "Module path should be '@jac/runtime'"
    );
    assert len(import_stmt.items) == 3 , "Should have 3 imported items";
    item_names = [
        item.name.value
        for item in import_stmt.items
        if isinstance(item, uni.ModuleItem)
    ];
    assert "jacLogin" in item_names;
    assert "jacLogout" in item_names;
    assert "renderJsxTree" in item_names;
}

glob FILES_EXPECTED_ERRORS = ["uninitialized_hasvars.jac"];

def parser_file_test(rel_path: str) -> None {
    filename = os.path.normpath(os.path.join(JAC_ROOT, rel_path));
    if not os.path.exists(filename) {
        return;
    }
    source = file_to_str(filename);
    (module, parse_errors, lex_errors) = rd_parse(source, filename);
    if os.path.basename(filename) not in FILES_EXPECTED_ERRORS {
        assert not parse_errors and not lex_errors , (
            f"{filename}: parse_errors={len(parse_errors)}, lex_errors={len(lex_errors)}"
        );
    }
}

with entry {
    parametrize(
        "parser", MICRO_JAC_FILES, parser_file_test, id_fn=lambda f : Path(f).stem
    );
}
