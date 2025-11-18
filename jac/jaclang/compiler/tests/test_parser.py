"""Tests for Jac parser."""

import inspect
import io
import os
import sys
from pathlib import Path

from jaclang.compiler import jac_lark as jl
from jaclang.compiler import unitree as uni
from jaclang.compiler.constant import Tokens
from jaclang.compiler.parser import JacParser
from jaclang.compiler.program import JacProgram
from jaclang.compiler.unitree import Source
from jaclang.utils.test import TestCaseMicroSuite


class TestLarkParser(TestCaseMicroSuite):
    """Test Jac self.prse."""

    def setUp(self) -> None:
        """Set up test."""
        return super().setUp()

    def test_fstring_escape_brace(self) -> None:
        """Test fstring escape brace."""
        source = Source('glob a=f"{{}}", not_b=4;', mod_path="")
        prse = JacParser(root_ir=source, prog=JacProgram())
        self.assertFalse(prse.errors_had)

    def micro_suite_test(self, filename: str) -> None:
        """Parse micro jac file."""
        prse = JacParser(
            root_ir=Source(self.file_to_str(filename), mod_path=filename),
            prog=JacProgram(),
        )
        # A list of files where the errors are expected.
        files_expected_errors = [
            "uninitialized_hasvars.jac",
        ]
        if os.path.basename(filename) not in files_expected_errors:
            self.assertFalse(prse.errors_had)

    def test_parser_fam(self) -> None:
        """Parse micro jac file."""
        prse = JacParser(
            root_ir=Source(self.load_fixture("fam.jac"), mod_path=""),
            prog=JacProgram(),
        )
        self.assertFalse(prse.errors_had)

    def test_staticmethod_checks_out(self) -> None:
        """Parse micro jac file."""
        prse = JacParser(
            root_ir=Source(
                self.load_fixture("staticcheck.jac"),
                mod_path="",
            ),
            prog=JacProgram(),
        )
        out = prse.ir_out.pp()
        self.assertFalse(prse.errors_had)
        self.assertNotIn("staticmethod", out)

    def test_parser_kwesc(self) -> None:
        """Parse micro jac file."""
        prse = JacParser(
            root_ir=Source(self.load_fixture("kwesc.jac"), mod_path=""),
            prog=JacProgram(),
        )
        self.assertFalse(prse.errors_had)

    def test_parser_mod_doc_test(self) -> None:
        """Parse micro jac file."""
        prse = JacParser(
            root_ir=Source(self.load_fixture("mod_doc_test.jac"), mod_path=""),
            prog=JacProgram(),
        )
        self.assertFalse(prse.errors_had)

    def test_enum_matches_lark_toks(self) -> None:
        """Test that enum stays synced with lexer."""
        tokens = [x.name for x in jl.Lark_StandAlone().parser.lexer_conf.terminals]
        for token in tokens:
            self.assertIn(token, Tokens.__members__)
        for token in Tokens:
            self.assertIn(token.name, tokens)
        for token in Tokens:
            self.assertIn(token.value, tokens)

    def test_parser_impl_all_rules(self) -> None:
        """Test that enum stays synced with lexer."""
        rules = {
            x.origin.name
            for x in jl.Lark_StandAlone().parser.parser_conf.rules
            if not x.origin.name.startswith("_")
        }
        parse_funcs = []
        for name, value in inspect.getmembers(JacParser.TreeToAST):
            if inspect.isfunction(value) and not getattr(
                JacParser.TreeToAST.__base__, value.__name__, False
            ):
                parse_funcs.append(name)
        for rule in rules:
            self.assertIn(rule, parse_funcs)
        for fn in parse_funcs:
            if fn.startswith("_") or fn in [
                "ice",
                "match",
                "consume",
                "match_token",
                "consume_token",
                "match_many",
                "consume_many",
                "extract_from_list",
            ]:
                continue
            self.assertIn(fn, rules)

    def test_all_ast_has_normalize(self) -> None:
        """Test for enter/exit name diffs with parser."""
        import jaclang.compiler.unitree as uni
        import inspect
        import sys

        exclude = [
            "UniNode",
            "UniScopeNode",
            "UniCFGNode",
            "ClientFacingNode",
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
        ]
        module_name = uni.__name__
        module = sys.modules[module_name]

        # Retrieve the source code of the module
        source_code = inspect.getsource(module)

        classes = inspect.getmembers(module, inspect.isclass)
        uni_node_classes = [
            cls
            for _, cls in classes
            if issubclass(cls, uni.UniNode) and not issubclass(cls, uni.Token)
        ]

        ordered_classes = sorted(
            uni_node_classes,
            key=lambda cls: source_code.find(f"class {cls.__name__}"),
        )
        for cls in ordered_classes:
            if cls.__name__ not in exclude:
                self.assertIn("normalize", cls.__dict__)

    def test_inner_mod_impl(self) -> None:
        """Parse micro jac file."""
        prog = JacProgram()
        prog.compile(self.fixture_abs_path("codegentext.jac"))
        self.assertFalse(prog.errors_had)

    def test_param_syntax(self) -> None:
        """Parse param syntax jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        prog = JacProgram()
        prog.compile(self.lang_fixture_abs_path("params/param_syntax_err.jac"))
        sys.stdout = sys.__stdout__
        self.assertEqual(len(prog.errors_had), 8)

    def test_multiple_syntax_errors(self) -> None:
        """Parse param syntax jac file."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        prog = JacProgram()
        prog.compile(self.fixture_abs_path("multiple_syntax_errors.jac"))
        sys.stdout = sys.__stdout__
        self.assertEqual(len(prog.errors_had), 3)
        expected_errors = [
            """
            Missing RPAREN
                with entry {
                    foo = Foo(;
                              ^
                    func(foo bar)
                    foo.bar;
            """,
            """
            Missing COMMA
                with entry {
                    foo = Foo(;
                    func(foo bar)
                             ^^^
                    foo.bar;
                }
            """,
            """
            Unexpected token 'bar'
                with entry {
                    foo = Foo(;
                    func(foo bar)
                             ^^^
                    foo.bar;
            """,
        ]
        for idx, alrt in enumerate(prog.errors_had):
            pretty = alrt.pretty_print()
            for line in expected_errors[idx].strip().split("\n"):
                line = line.strip()
                self.assertIn(line, pretty)

    def _load_combined_jsx_fixture(self) -> tuple[str, JacParser]:
        """Parse the consolidated JSX fixture once for downstream assertions."""
        fixture_path = (
            Path(__file__).resolve().parent.parent
            / "passes"
            / "ecmascript"
            / "tests"
            / "fixtures"
            / "client_jsx.jac"
        )
        source_text = fixture_path.read_text(encoding="utf-8")
        prse = JacParser(
            root_ir=Source(source_text, mod_path=str(fixture_path)),
            prog=JacProgram(),
        )
        self.assertFalse(
            prse.errors_had,
            f"Parser reported errors for JSX fixture: {[str(e) for e in prse.errors_had]}",
        )
        return source_text, prse

    def test_jsx_comprehensive_fixture(self) -> None:
        """Ensure the consolidated JSX fixture exercises varied grammar shapes."""
        source_text, prse = self._load_combined_jsx_fixture()
        tree_repr = prse.ir_out.pp()

        expected_snippets = {
            "self_closing": "<div />",
            "attribute_binding": "id={name}",
            "namespaced_component": "<Form.Input.Text />",
            "fragment": "<>",
            "spread_attribute": "{...props}",
            "expression_child": '{"Hello " + name + "!"}',
        }
        for label, snippet in expected_snippets.items():
            with self.subTest(label=label):
                self.assertIn(snippet, source_text)

        ast_markers = {
            "JsxElement": "JsxElement" in tree_repr,
            "FragmentTokens": "Token - <>" in tree_repr and "Token - </>" in tree_repr,
            "JsxSpreadAttribute": "JsxSpreadAttribute" in tree_repr,
        }
        for label, present in ast_markers.items():
            with self.subTest(node=label):
                self.assertTrue(present, f"{label} missing from AST pretty print")

    def test_client_keyword_tagging(self) -> None:
        """Test that cl keyword properly tags elements as client declarations.

        Tests:
        - Single statement with cl prefix
        - Statement without cl prefix
        - Block of statements with cl { }
        - Empty cl blocks
        - Multiple cl blocks at top level
        - Various statement types (import, let, obj, test)
        """
        # Test 1: Mixed single and block client markers
        source = """
cl let foo = 1;
let bar = 2;
cl {
    let baz = 3;
    test sample {}
}
"""
        module = JacProgram().parse_str(source, "test.jac")
        body = module.body

        # With ClientBlock, cl {} creates a single ClientBlock node
        self.assertEqual(
            [type(stmt).__name__ for stmt in body],
            ["GlobalVars", "GlobalVars", "ClientBlock"],
        )
        self.assertEqual(
            [getattr(stmt, "is_client_decl", False) for stmt in body],
            [True, False, False],  # cl let, let, ClientBlock (not ClientFacingNode)
        )
        # Check the ClientBlock's body
        client_block = body[2]
        self.assertIsInstance(client_block, uni.ClientBlock)
        self.assertEqual(len(client_block.body), 2)
        self.assertEqual(
            [type(stmt).__name__ for stmt in client_block.body],
            ["GlobalVars", "Test"],
        )
        self.assertTrue(
            all(
                getattr(stmt, "is_client_decl", False)
                for stmt in client_block.body
                if hasattr(stmt, "is_client_decl")
            )
        )

        # Test 2: Block with different statement types
        source = """
cl {
    import foo;
    let x = 1;
    obj MyClass {}
    test my_test {}
}
"""
        module = JacProgram().parse_str(source, "test.jac")
        body = module.body

        # With ClientBlock, all statements are wrapped in a single ClientBlock
        self.assertEqual(len(body), 1)
        self.assertIsInstance(body[0], uni.ClientBlock)
        # Check the ClientBlock's body has 4 statements
        self.assertEqual(len(body[0].body), 4)
        self.assertTrue(
            all(
                getattr(stmt, "is_client_decl", False)
                for stmt in body[0].body
                if hasattr(stmt, "is_client_decl")
            )
        )

        # Test 3: Multiple cl blocks at top level
        source = """
cl {
    let a = 1;
}
let b = 2;
cl {
    let c = 3;
}
"""
        module = JacProgram().parse_str(source, "test.jac")
        body = module.body

        # Now we have: ClientBlock, GlobalVars, ClientBlock
        self.assertEqual(len(body), 3)
        self.assertIsInstance(body[0], uni.ClientBlock)
        self.assertIsInstance(body[1], uni.GlobalVars)
        self.assertIsInstance(body[2], uni.ClientBlock)
        self.assertFalse(
            getattr(body[1], "is_client_decl", False)
        )  # let b is not client

        # Test 4: Empty client block
        source = """
cl {}
let x = 1;
"""
        module = JacProgram().parse_str(source, "test.jac")
        body = module.body

        # Empty ClientBlock followed by GlobalVars
        self.assertEqual(len(body), 2)
        self.assertIsInstance(body[0], uni.ClientBlock)
        self.assertEqual(len(body[0].body), 0)  # Empty
        self.assertIsInstance(body[1], uni.GlobalVars)
        self.assertFalse(getattr(body[1], "is_client_decl", False))

        # Test 5: Various statement types with single cl marker
        source = """
cl import foo;
cl obj MyClass {}
cl test my_test {}
"""
        module = JacProgram().parse_str(source, "test.jac")
        body = module.body

        self.assertEqual(len(body), 3)
        self.assertTrue(
            all(
                getattr(stmt, "is_client_decl", False)
                for stmt in body
                if hasattr(stmt, "is_client_decl")
            )
        )

    def test_anonymous_ability_decl(self) -> None:
        """Test that abilities can be declared without explicit names.

        Tests:
        - Anonymous ability with entry event
        - Anonymous ability with exit event
        - Named ability still works
        - Autogenerated names are unique based on location
        """
        # Test 1: Anonymous ability with entry event
        source = """
walker MyWalker {
    can with entry {
        print("hello");
    }
}
"""
        prog = JacProgram()
        module = prog.parse_str(source, "test.jac")
        self.assertFalse(prog.errors_had)

        # Find the walker and its ability
        walker = module.body[0]
        abilities = [stmt for stmt in walker.body if type(stmt).__name__ == "Ability"]
        self.assertEqual(len(abilities), 1)

        ability = abilities[0]
        self.assertIsNotNone(ability.name_ref)
        # Check that py_resolve_name generates a name
        resolved_name = ability.py_resolve_name()
        self.assertTrue(resolved_name.startswith("__ability_entry_"))
        self.assertTrue(resolved_name.endswith("__"))

        # Test 2: Anonymous ability with exit event
        source = """
walker MyWalker {
    can with exit {
        print("goodbye");
    }
}
"""
        prog = JacProgram()
        module = prog.parse_str(source, "test.jac")
        self.assertFalse(prog.errors_had)

        walker = module.body[0]
        abilities = [stmt for stmt in walker.body if type(stmt).__name__ == "Ability"]
        ability = abilities[0]
        resolved_name = ability.py_resolve_name()
        self.assertTrue(resolved_name.startswith("__ability_exit_"))

        # Test 3: Named ability still works
        source = """
walker MyWalker {
    can my_ability with entry {
        print("named");
    }
}
"""
        prog = JacProgram()
        module = prog.parse_str(source, "test.jac")
        self.assertFalse(prog.errors_had)

        walker = module.body[0]
        abilities = [stmt for stmt in walker.body if type(stmt).__name__ == "Ability"]
        ability = abilities[0]
        self.assertIsNotNone(ability.name_ref)
        self.assertEqual(ability.py_resolve_name(), "my_ability")

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
"""
        prog = JacProgram()
        module = prog.parse_str(source, "test.jac")
        self.assertFalse(prog.errors_had)

        walker = module.body[0]
        abilities = [stmt for stmt in walker.body if type(stmt).__name__ == "Ability"]
        self.assertEqual(len(abilities), 2)

        name1 = abilities[0].py_resolve_name()
        name2 = abilities[1].py_resolve_name()
        # Names should be different due to different locations
        self.assertNotEqual(name1, name2)

    def test_cl_import_with_prefix(self) -> None:
        """Test that cl import with jac: prefix is properly parsed.

        Tests:
        - cl import from jac:client_runtime syntax
        - Prefix field is captured in ModulePath
        - Import is marked as client-side
        """
        source = """
cl import from jac:client_runtime {
    jacLogin,
    jacLogout,
    renderJsxTree,
}
"""
        prog = JacProgram()
        module = prog.parse_str(source, "test.jac")
        self.assertFalse(prog.errors_had, f"Parser errors: {prog.errors_had}")

        # Find the import statement
        imports = [stmt for stmt in module.body if type(stmt).__name__ == "Import"]
        self.assertEqual(len(imports), 1, "Should have one import statement")

        import_stmt = imports[0]

        # Check that it's a client import
        self.assertTrue(
            getattr(import_stmt, "is_client_decl", False),
            "Import should be marked as client-side",
        )

        # Check the from_loc has the prefix
        self.assertIsNotNone(import_stmt.from_loc, "Import should have from_loc")
        self.assertIsNotNone(
            import_stmt.from_loc.prefix, "ModulePath should have prefix"
        )
        self.assertEqual(
            import_stmt.from_loc.prefix.value, "jac", "Prefix should be 'jac'"
        )

        # Check the module path
        self.assertEqual(
            import_stmt.from_loc.dot_path_str,
            "client_runtime",
            "Module path should be 'client_runtime'",
        )

        # Check the imported items
        self.assertEqual(len(import_stmt.items), 3, "Should have 3 imported items")
        item_names = [item.name.value for item in import_stmt.items]
        self.assertIn("jacLogin", item_names)
        self.assertIn("jacLogout", item_names)
        self.assertIn("renderJsxTree", item_names)


TestLarkParser.self_attach_micro_tests()
