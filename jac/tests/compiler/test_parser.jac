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
    (module, had_error) = rd_parse('glob a=f"{{}}", not_b=4;', "");
    assert not had_error;
}

test "parser fam" {
    (module, had_error) = rd_parse(load_fixture("fam.jac"), "");
    assert not had_error;
}

test "staticmethod checks out" {
    (module, had_error) = rd_parse(load_fixture("staticcheck.jac"), "");
    out = module.pp();
    assert not had_error;
    assert "staticmethod" not in out;
}

test "parser kwesc" {
    (module, had_error) = rd_parse(load_fixture("kwesc.jac"), "");
    assert not had_error;
}

test "parser mod doc test" {
    (module, had_error) = rd_parse(load_fixture("mod_doc_test.jac"), "");
    assert not had_error;
}

test "all ast has normalize" {
    import from jaclang.compiler.passes.tool.normalize_pass { NormalizePass }
    import from jaclang.jac0core.helpers { pascal_to_snake }

    exclude = [
        "UniNode",
        "UniScopeNode",
        "UniCFGNode",
        "ConditionalNode",
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
    # Parser emits 'Missing ;' (treats 'new' as identifier, so 'new car(...)' is
    # two expressions). ASTValidationPass then catches 'new' as a banned keyword.
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "new_keyword_err.jac"));
    sys.stdout = sys.__stdout__;
    assert len(prog.errors_had) == 4;
    expected_substrings = [
        "Missing ';'",
        "Missing ';'",
        "'new' is not supported in Jac",
        "'new' is not supported in Jac",

    ];
    for (alrt, expected) in zip(prog.errors_had, expected_substrings, strict=True) {
        pretty = alrt.pretty_print();
        assert expected in pretty;
    }
}

test "pass keyword errors" {
    # ASTValidationPass catches all 17 occurrences of 'pass' with the same
    # message. The 5 archetype body usages also produce 'Missing ;' from the
    # parser (fixture omits semicolons for those, mimicking Python style).
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "pass_keyword_err.jac"));
    sys.stdout = sys.__stdout__;
    assert len(prog.errors_had) == 22;
    keyword_errors = 0;
    missing_semi = 0;
    for alrt in prog.errors_had {
        pretty = alrt.pretty_print();
        if "'pass' is not supported in Jac" in pretty {
            keyword_errors += 1;
        } elif "Missing ';'" in pretty {
            missing_semi += 1;
        }
    }
    assert keyword_errors == 17;
    assert missing_semi == 5;
}

test "multiple syntax errors" {
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "multiple_syntax_err.jac"));
    sys.stdout = sys.__stdout__;
    assert len(prog.errors_had) == 4;
    expected_substrings = [
        "Missing ')'",
        "Missing ','",
        "Unexpected token",
        "Missing ';'"
    ];
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
    (module, had_error) = rd_parse(source_text, str(fixture_path));
    assert not had_error , "Parser reported errors for JSX fixture";
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

test "jsx star_pow spread attribute" {
    source = 'with entry { x = <div {**props} title="hi"/>; }';
    (module, had_error) = rd_parse(source, "test_spread.jac");
    assert not had_error , "Parser rejected {**props} spread syntax";
    tree_repr = module.pp();
    assert "JsxSpreadAttribute" in tree_repr , "Missing JsxSpreadAttribute node";
    assert "Token - **" in tree_repr , "Missing ** token in spread";
    # Ellipsis form should warn but still parse
    source2 = 'with entry { x = <div {...props}/>; }';
    (module2, had_error2) = rd_parse(source2, "test_spread2.jac");
    assert not had_error2 , "Parser rejected {...props} spread syntax";
    assert "Ellipsis" in module2.pp() , "Missing Ellipsis node for ... spread";
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

test "to section headers" {
    # Basic: each 'to X:' produces an implicit XBlock whose body contains
    # all statements until the next header or EOF.
    source = """
to sv:
def sv_fn() -> int { return 1; }
to cl:
def cl_fn() -> int { return 2; }
to na:
def na_fn() -> int { return 3; }
to sv:
def sv_fn2() -> int { return 4; }
""";
    prog = JacProgram();
    mod = prog.parse_str(source, "test.jac");
    assert not prog.errors_had;
    bd = mod.body;
    assert len(bd) == 4;
    assert isinstance(bd[0], uni.ServerBlock) and bd[0].implicit;
    assert isinstance(bd[1], uni.ClientBlock) and bd[1].implicit;
    assert isinstance(bd[2], uni.NativeBlock) and bd[2].implicit;
    assert isinstance(bd[3], uni.ServerBlock) and bd[3].implicit;
    expected_ctxs = [
        CodeContext.SERVER,
        CodeContext.CLIENT,
        CodeContext.NATIVE,
        CodeContext.SERVER
    ];
    for (blk, expected) in zip(bd, expected_ctxs) {
        inner = [
            stmt
            for stmt in blk.body
            if isinstance(stmt, uni.ContextAwareNode)
        ];
        assert len(inner) == 1;
        assert inner[0].code_context == expected;
    }

    # Explicit cl/sv/na single-stmt prefix inside a 'to X:' section overrides
    # the active section's tagging for that one statement.
    source = """
to cl:
def cl_a() -> int { return 1; }
sv def sv_b() -> int { return 2; }
def cl_c() -> int { return 3; }
""";
    prog = JacProgram();
    mod = prog.parse_str(source, "test.jac");
    assert not prog.errors_had;
    assert len(mod.body) == 1;
    block = mod.body[0];
    assert isinstance(block, uni.ClientBlock) and block.implicit;
    ctxs = [
        s.code_context
        for s in block.body
        if isinstance(s, uni.ContextAwareNode)
    ];
    assert ctxs == [CodeContext.CLIENT, CodeContext.SERVER, CodeContext.CLIENT];

    # A braced 'cl { ... }' block nested inside a 'to sv:' section is itself
    # an element of that section's body — the braced block's own stmts are
    # tagged CLIENT, and a later plain def resumes the surrounding SERVER.
    source = """
to sv:
def sv_a() -> int { return 1; }
cl {
    def cl_b() -> int { return 2; }
}
def sv_c() -> int { return 3; }
""";
    prog = JacProgram();
    mod = prog.parse_str(source, "test.jac");
    assert not prog.errors_had;
    assert len(mod.body) == 1;
    outer = mod.body[0];
    assert isinstance(outer, uni.ServerBlock) and outer.implicit;
    assert len(outer.body) == 3;
    assert isinstance(outer.body[0], uni.Ability);
    assert outer.body[0].code_context == CodeContext.SERVER;
    assert isinstance(outer.body[1], uni.ClientBlock);
    assert not outer.body[1].implicit;
    assert all(
        s.code_context == CodeContext.CLIENT
        for s in outer.body[1].body
        if isinstance(s, uni.ContextAwareNode)
    );
    assert isinstance(outer.body[2], uni.Ability);
    assert outer.body[2].code_context == CodeContext.SERVER;

    # A 'to X:' header at EOF with no following stmt still parses as an empty
    # implicit XBlock; earlier statements stay at module scope.
    source = """
def a() -> int { return 1; }
to cl:
""";
    prog = JacProgram();
    mod = prog.parse_str(source, "test.jac");
    assert not prog.errors_had;
    assert mod.body[0].code_context == CodeContext.SERVER;
    assert isinstance(mod.body[1], uni.ClientBlock);
    assert mod.body[1].implicit;
    assert len(mod.body[1].body) == 0;
}

test "cl/sv/na braced-block deprecation warning" {
    # Braced block form emits W0064 for each block
    source = """
cl { def a() -> int { return 1; } }
sv { def b() -> int { return 2; } }
na { def c() -> int { return 3; } }
""";
    prog = JacProgram();
    prog.parse_str(source, "test.jac");
    assert not prog.errors_had;
    w_codes: list[str] = [];
    for w in prog.warnings_had {
        c = w.code;
        if c is not None {
            w_codes.append(c.code);
        }
    }
    assert w_codes.count("W0064") == 3;

    # Section headers and single-statement prefix forms do not warn
    source = """
to cl:
def a() -> int { return 1; }
to sv:
def b() -> int { return 2; }
to na:
def c() -> int { return 3; }
cl def d() -> int { return 4; }
sv def e() -> int { return 5; }
na def f() -> int { return 6; }
""";
    prog = JacProgram();
    prog.parse_str(source, "test.jac");
    assert not prog.errors_had;
    w_codes: list[str] = [];
    for w in prog.warnings_had {
        c = w.code;
        if c is not None {
            w_codes.append(c.code);
        }
    }
    assert "W0064" not in w_codes;
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
    (module, had_error) = rd_parse(source, filename);
    if os.path.basename(filename) not in FILES_EXPECTED_ERRORS {
        assert not had_error , f"{filename}: parse errors detected";
    }
}

test "decorated test blocks" {
    # Single decorator on test
    source = '@my_dec\ntest "decorated" { assert True; }';
    mod = JacProgram().parse_str(source, "test.jac");
    t = mod.body[0];
    assert isinstance(t, uni.Test);
    assert t.decorators is not None;
    assert len(t.decorators) == 1;
    assert t.description is not None;

    # Multiple decorators on test
    source = '@dec1\n@dec2(42)\ntest "multi" { assert True; }';
    mod = JacProgram().parse_str(source, "test.jac");
    t = mod.body[0];
    assert isinstance(t, uni.Test);
    assert len(t.decorators) == 2;

    # No decorator still works
    source = 'test "plain" { assert True; }';
    mod = JacProgram().parse_str(source, "test.jac");
    t = mod.body[0];
    assert isinstance(t, uni.Test);
    assert not t.decorators;
}

test "bracket filter after edge ref" {
    (mod, err) = rd_parse('walker W { can go with entry { visit [-->][?:Foo]; } }', "");
    assert not err , "Failed to parse [-->][?:Foo]";
}

test "bracket filter with conditions" {
    (mod, err) = rd_parse(
        'walker W { can go with entry { visit [-->][?:Foo, bar==5]; } }', ""
    );
    assert not err , "Failed to parse [-->][?:Foo, bar==5]";
}

test "bracket filter no type" {
    (mod, err) = rd_parse(
        'walker W { can go with entry { visit [-->][?bar==5]; } }', ""
    );
    assert not err , "Failed to parse [-->][?bar==5]";
}

test "chained bracket filters" {
    (mod, err) = rd_parse(
        'walker W { can go with entry { x = [root-->][?:Foo][?val==10]; } }', ""
    );
    assert not err , "Failed to parse chained bracket filters";
}

test "standalone bracket filter expr" {
    (mod, err) = rd_parse('with entry { x = [?:Foo, a<3]; }', "");
    assert not err , "Failed to parse standalone [?:Foo, a<3]";
}

test "bracket vs paren filter produce same AST" {
    (mod_old, _) = rd_parse('with entry { x(?:Foo, a==5); }', "");
    (mod_new, _) = rd_parse('with entry { x[?:Foo, a==5]; }', "");
    # Find FilterCompr nodes in both trees
    def find_fc(nd: object) -> object {
        if isinstance(nd, uni.FilterCompr) {
            return nd;
        }
        if hasattr(nd, "kid") {
            for k in nd.kid {
                if k is not None {
                    result = find_fc(k);
                    if result is not None {
                        return result;
                    }
                }
            }
        }
        return None;
    }
    old_fc = find_fc(mod_old);
    new_fc = find_fc(mod_new);
    assert old_fc is not None , "Old syntax should produce FilterCompr";
    assert new_fc is not None , "New syntax should produce FilterCompr";
    assert len(old_fc.compares) == len(new_fc.compares) , "Both syntaxes should have same number of compares";
}

test "bracket filter on list" {
    (mod, err) = rd_parse('with entry { print(my_list[?:MyObj, a<4]); }', "");
    assert not err , "Failed to parse list bracket filter";
}

test "typed edge ref after start expr - no filter" {
    # BUG: `[root()->:Type:->]` failed to parse because parse_list_or_compr
    # only checked for ARROW_R/ARROW_L/ARROW_BI/ARROW_R_P1/ARROW_L_P1 after
    # the first expression, missing the (RETURN_HINT, COLON, ...) form the
    # lexer actually produces for `->:`. The bare-start form `[->:Type:->]`
    # already parsed because that path went through parse_edge_ref_chain
    # directly. (Reproduces the docs example in the Part 2 'Advanced:
    # Custom Edges' section of the AI day planner tutorial.)
    src = (
        'edge Scheduled { has time: str; }'
        'node Task { has title: str; }'
        'with entry {'
        '    root() +>: Scheduled(time="9:00am") :+> Task(title="Run");'
        '    x = [root()->:Scheduled:->];'
        '}'
    );
    (mod, err) = rd_parse(src, "");
    assert not err , (
        "Failed to parse [root()->:Scheduled:->] (typed edge ref after "
        "explicit start expression)"
    );
}

test "typed edge ref after start expr - with filter condition" {
    # Same root cause as the test above, plus continue_edge_ref_chain
    # was using a stripped-down inline branch that did not accept the
    # `:cond` filter clause that parse_edge_op_ref already supports.
    src = (
        'edge Scheduled { has priority: int = 1; }'
        'node Task { has title: str; }'
        'with entry {'
        '    root() +>: Scheduled(priority=3) :+> Task(title="A");'
        '    urgent = [root()->:Scheduled:priority>=3:->];'
        '}'
    );
    (mod, err) = rd_parse(src, "");
    assert not err , (
        "Failed to parse [root()->:Scheduled:priority>=3:->] (typed edge "
        "ref with a filter condition after an explicit start expression)"
    );
}

test "typed edge ref bare start with filter still parses" {
    # Sanity check: the bare-start form (no explicit start expression)
    # was already parsing before the fix and must keep working — the
    # parser routes it through parse_edge_ref_chain which uses the rich
    # parse_edge_op_ref helper.
    src = (
        'edge Scheduled { has priority: int = 1; }'
        'node Task { has title: str; }'
        'walker W { can go with entry { '
        '    visit [->:Scheduled:priority>=3:->]; '
        '} }'
    );
    (mod, err) = rd_parse(src, "");
    assert not err , ("Failed to parse bare-start [->:Scheduled:priority>=3:->]");
}

test "typed edge ref produces FilterCompr with compares" {
    # Structural check: the AST produced for the fixed form must include
    # a FilterCompr that actually carries the filter compare conditions
    # (otherwise downstream traversal cannot evaluate the filter).
    src = (
        'edge Scheduled { has priority: int = 1; }'
        'node Task { has title: str; }'
        'with entry {'
        '    urgent = [root()->:Scheduled:priority>=3:->];'
        '}'
    );
    (mod, err) = rd_parse(src, "");
    assert not err;

    def find_filter_compr_with_compares(nd: object) -> object {
        if isinstance(nd, uni.FilterCompr) and nd.compares {
            return nd;
        }
        if hasattr(nd, "kid") {
            for k in nd.kid {
                if k is not None {
                    result = find_filter_compr_with_compares(k);
                    if result is not None {
                        return result;
                    }
                }
            }
        }
        return None;
    }
    fc = find_filter_compr_with_compares(mod);
    assert fc is not None , (
        "Typed edge ref `[root()->:Scheduled:priority>=3:->]` must produce "
        "a FilterCompr carrying the `priority>=3` condition; an EdgeOpRef "
        "with an empty FilterCompr means the filter clause was silently "
        "dropped."
    );
}

test "decorated class in code block parses as archetype" {
    (mod, err) = rd_parse(load_fixture("decorated_decl_in_code_block.jac"), "");
    assert not err , "Parser reported errors for decorated declarations in code blocks";

    def collect(nd: uni.UniNode) -> list {
        results: list = [];
        if isinstance(nd, uni.Archetype) {
            results.append(nd);
        }
        for k in (nd.kid) {
            results.extend(collect(k));
        }
        return results;
    }

    archetype_names = [a.name.sym_name for a in collect(mod)];

    for name in [
        "A_TopClass",
        "A_InEntryClass",
        "A_InEntryObj",
        "A_StackedDec",
        "A_InDefBodyClass",
        "A_InDefBodyObj",
        "A_Container",
        "A_InMethodClass"
    ] {
        assert name in archetype_names , f"{name} should be Archetype but was not found";
    }
}

with entry {
    parametrize(
        "parser", MICRO_JAC_FILES, parser_file_test, id_fn=lambda f : Path(f).stem
    );
}
