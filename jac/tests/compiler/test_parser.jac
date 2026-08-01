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
import from tests.support { JAC_ROOT }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { CodeContext }
import from jaclang.jac0core.parser { parse as rd_parse }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.helpers { read_file_with_encoding }
import from jaclang.runtimelib.test { parametrize }
import from tests.fixtures_list { MICRO_JAC_FILES }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "fixtures"),
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
        uni_node_classes,
        key=lambda (cls) { source_code.find(f"class {cls.__name__}"); },
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
    # `new` is an ambient builtin in Jac (callable as `new(Cls, ...args)`),
    # so JS-style `new Cls(args)` usage no longer parses. The parser detects
    # the offending shape ("bare `new` followed by another atom in
    # statement-terminator position") and emits the migration-friendly
    # `E0012` instead of the cascade of `Missing ';'` errors users used to
    # see. Each of the two offending lines in the fixture should produce
    # one `E0012`.
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "new_keyword_err.jac"));
    sys.stdout = sys.__stdout__;
    assert len(prog.errors_had) == 2;
    for alrt in prog.errors_had {
        assert alrt.code is not None and alrt.code.code == "E0012";
        pretty = alrt.pretty_print();
        assert "`new(target, ...args)`" in pretty;
    }
}

test "pass keyword errors" {
    # ASTValidationPass catches all 17 occurrences of 'pass' with the same
    # message. The 5 archetype body usages (fixture omits semicolons for
    # those, mimicking Python style) parse as semicolon-less tail
    # expressions and are rejected with E2084 (implicit return is only
    # valid at the end of a function body). The parameter named 'pass'
    # additionally emits E0067 (Python reserved word as parameter name).
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "pass_keyword_err.jac"));
    sys.stdout = sys.__stdout__;
    assert len(prog.errors_had) == 23;
    keyword_errors = 0;
    misplaced_tail_expr = 0;
    reserved_param = 0;
    for alrt in prog.errors_had {
        pretty = alrt.pretty_print();
        if "'pass' is not supported in Jac" in pretty {
            keyword_errors += 1;
        } elif "implicit return" in pretty {
            misplaced_tail_expr += 1;
        } elif "Python reserved word" in pretty {
            reserved_param += 1;
        }
    }
    assert keyword_errors == 17;
    assert misplaced_tail_expr == 5;
    assert reserved_param == 1;
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

test "connect_disconnect_missing_rhs" {
    # Issue #5885 gap 10: connect/disconnect operators that are missing the
    # right operand previously surfaced a misleading 'Unexpected token' or
    # 'Missing ;' chain. The fixture has 5 such positions; each should emit
    # exactly one E0026, and all of them must point at the operator span.
    captured_output = io.StringIO();
    sys.stdout = captured_output;
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "connect_disconnect_missing_rhs.jac"));
    sys.stdout = sys.__stdout__;
    e0026 = [
        e
        for e in prog.errors_had
        if e.code and e.code.code == "E0026"
    ];
    assert len(e0026) == 5 , f"Expected 5 E0026 (missing RHS), got {len(e0026)}:\n"
        + "\n---\n".join(e.pretty_print() for e in e0026);
    # Sanity: the misleading "Unexpected token in expression" diagnostic
    # must no longer appear for these inputs.
    bad = [
        e
        for e in prog.errors_had
        if e.code and e.code.code == "E0004"
    ];
    assert len(bad) == 0 , "E0004 leaked through after E0026 fix:\n"
        + "\n---\n".join(e.pretty_print() for e in bad);
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
        "self_closing": "<div/>",
        "attribute_binding": "id={name}",
        "namespaced_component": "<Form.Input.Text/>",
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

test "removed sv/cl/na markers produce the migration error" {
    import tempfile;
    with tempfile.TemporaryDirectory() as tmpdir {
        path = os.path.join(tmpdir, "legacy.jac");
        with open(path, "w") as f {
            f.write("sv def f -> int {\n    return 1;\n}\n");
        }
        prog = JacProgram();
        prog.compile(path);
        assert prog.errors_had , "a marker must be a hard error";
        pretty = prog.errors_had[0].pretty_print();
        assert "placement markers were removed" in pretty , pretty;
        assert "jac fix placement" in pretty , pretty;
    }
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

test "string-path import with jac runtime" {
    source = """
import from "@jac/runtime" {
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

test "extensionless logical clib import parses as clib decls (issue #6387)" {
    # A native C-FFI import may name the library by a dotted, extensionless logical
    # name instead of a string-literal path. The brace block opening with a `def`
    # is what marks it as a clib block, so the from-path is parsed as Name nodes
    # and the declarations land in clib_decls (not items).
    source = """
import from raylib {
    def InitWindow(width: i32, height: i32, title: str) -> None;
    def CloseWindow -> None;
}
""";
    prog = JacProgram();
    mod = prog.parse_str(source, "test_logical_clib.jac");
    assert not prog.errors_had , f"Parser errors: {prog.errors_had}";
    imports = [
        stmt
        for stmt in mod.body
        if type(stmt).__name__ == "Import"
    ];
    assert len(imports) == 1 , "Should have one import statement";
    import_stmt = imports[0];
    assert isinstance(import_stmt, uni.Import);
    # Library named by a bare Name (not a String literal), no extension.
    assert import_stmt.from_loc is not None , "Import should have from_loc";
    assert import_stmt.from_loc.dot_path_str == "raylib" , "logical name should be 'raylib'";
    assert import_stmt.from_loc.path is not None;
    assert isinstance(import_stmt.from_loc.path[0], uni.Name) , "path must be a Name, not String";
    # The extern declarations land in clib_decls, and there are no import items.
    assert import_stmt.clib_decls is not None and len(import_stmt.clib_decls) == 2 , (
        f"expected 2 clib decls, got {import_stmt.clib_decls}"
    );
    assert len(import_stmt.items) == 0 , "clib import must not produce import items";
}

test "dotted logical clib import parses with sub-path (issue #6387)" {
    source = """
import from libs.raylib {
    def CloseWindow -> None;
}
""";
    prog = JacProgram();
    mod = prog.parse_str(source, "test_dotted_clib.jac");
    assert not prog.errors_had , f"Parser errors: {prog.errors_had}";
    imports = [
        stmt
        for stmt in mod.body
        if type(stmt).__name__ == "Import"
    ];
    assert len(imports) == 1;
    import_stmt = imports[0];
    assert import_stmt.from_loc.dot_path_str == "libs.raylib";
    assert import_stmt.clib_decls is not None and len(import_stmt.clib_decls) == 1;
    assert len(import_stmt.items) == 0;
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

test "bracket filter trailer produces FilterCompr AST" {
    (mod_new, err) = rd_parse('with entry { x[?:Foo, a==5]; }', "");
    assert not err , "Failed to parse x[?:Foo, a==5]";
    # Find the FilterCompr node in the tree
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
    new_fc = find_fc(mod_new);
    assert new_fc is not None , "Bracket filter trailer should produce FilterCompr";
    assert len(new_fc.compares) == 1 , "Filter should carry exactly the a==5 compare";
}

test "bracket filter on list" {
    (mod, err) = rd_parse('with entry { print(my_list[?:MyObj, a<4]); }', "");
    assert not err , "Failed to parse list bracket filter";
}

test "typed edge ref after start expr - no filter" {
    # BUG: `[root->:Type:->]` failed to parse because parse_list_or_compr
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
        '    root +>: Scheduled(time="9:00am") :+> Task(title="Run");'
        '    x = [root->:Scheduled:->];'
        '}'
    );
    (mod, err) = rd_parse(src, "");
    assert not err , (
        "Failed to parse [root->:Scheduled:->] (typed edge ref after "
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
        '    root +>: Scheduled(priority=3) :+> Task(title="A");'
        '    urgent = [root->:Scheduled:priority>=3:->];'
        '}'
    );
    (mod, err) = rd_parse(src, "");
    assert not err , (
        "Failed to parse [root->:Scheduled:priority>=3:->] (typed edge "
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
        '    urgent = [root->:Scheduled:priority>=3:->];'
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
        "Typed edge ref `[root->:Scheduled:priority>=3:->]` must produce "
        "a FilterCompr carrying the `priority>=3` condition; an EdgeOpRef "
        "with an empty FilterCompr means the filter clause was silently "
        "dropped."
    );
}

test "decorated class in code block parses as archetype" {
    (mod, err) = rd_parse(load_fixture("decorated_decl_in_code_block.jac"), "");
    assert not err , "Parser reported errors for decorated declarations in code blocks";

    def collect(nd: uni.UniNode) -> list[uni.Archetype] {
        results: list[uni.Archetype] = [];
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

test "docstring attaches to all member types inside archetype body" {
    (mod, err) = rd_parse(load_fixture("docstring_with_entry.jac"), "");
    assert not err , "Parser reported errors for docstrings on archetype members";

    def collect_doc_nodes(nd: uni.UniNode) -> list {
        results: list = [];
        if isinstance(nd, (uni.ArchHas, uni.Ability, uni.ModuleCode, uni.Archetype))
            and nd.doc is not None {
            results.append(nd);
        }
        for k in nd.kid {
            results.extend(collect_doc_nodes(k));
        }
        return results;
    }

    doc_nodes = collect_doc_nodes(mod);
    assert len(doc_nodes) == 4 , (
        f"Expected 4 doc-carrying members (has, def, with entry, nested obj) "
        f"but got {len(doc_nodes)}: {[type(n).__name__ for n in doc_nodes]}"
    );

    for nd in doc_nodes {
        assert nd.doc is not None , (
            f"{type(nd).__name__}.doc must be set when preceded by a docstring"
        );
    }
}

with entry {
    parametrize(
        "parser", MICRO_JAC_FILES, parser_file_test, id_fn=lambda (f) { Path(f).stem; }
    );
}
