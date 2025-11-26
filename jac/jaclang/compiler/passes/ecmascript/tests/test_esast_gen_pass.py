"""Test ECMAScript AST generation using consolidated Jac fixtures."""

import json
from pathlib import Path
from typing import Iterable

from jaclang.compiler.passes.ecmascript import EsastGenPass, es_node_to_dict
from jaclang.compiler.passes.ecmascript import estree as es
from jaclang.compiler.passes.ecmascript.es_unparse import es_to_js
from jaclang.compiler.program import JacProgram
from jaclang.utils.test import TestCase


def walk_es_nodes(node: es.Node) -> Iterable[es.Node]:
    """Yield every ESTree node in a depth-first traversal."""
    yield node
    for value in vars(node).values():
        if isinstance(value, es.Node):
            yield from walk_es_nodes(value)
        elif isinstance(value, list):
            for item in value:
                if isinstance(item, es.Node):
                    yield from walk_es_nodes(item)


class EsastGenPassTests(TestCase):
    """Validate ECMAScript AST output from consolidated fixtures."""

    CORE_FIXTURE = "core_language_features.jac"
    ADVANCED_FIXTURE = "advanced_language_features.jac"
    CLIENT_FIXTURE = "client_jsx.jac"

    TargetPass = EsastGenPass

    def get_fixture_path(self, filename: str) -> str:
        """Return absolute path to a fixture file."""
        fixtures_dir = Path(__file__).parent / "fixtures"
        return str(fixtures_dir / filename)

    def compile_to_esast(self, filename: str) -> es.Program:
        """Compile Jac source to an ESTree program."""
        prog = JacProgram()
        ir = prog.compile(file_path=filename, no_cgen=True)

        self.assertFalse(
            prog.errors_had,
            f"Compilation errors in {filename}: {[str(e) for e in prog.errors_had]}",
        )

        es_pass = EsastGenPass(ir, prog)
        es_ir = es_pass.ir_out

        self.assertTrue(hasattr(es_ir.gen, "es_ast"), "es_ast attribute missing")
        self.assertIsInstance(es_ir.gen.es_ast, es.Program)
        return es_ir.gen.es_ast

    def test_core_fixture_ast_shape(self) -> None:
        """Core fixture should expose fundamental declarations in the ESTree."""
        es_ast = self.compile_to_esast(self.get_fixture_path(self.CORE_FIXTURE))

        func_decls = [
            node for node in es_ast.body if isinstance(node, es.FunctionDeclaration)
        ]
        func_names = {func.id.name for func in func_decls if func.id}
        self.assertTrue({"add", "greet", "fibonacci"}.issubset(func_names))

        class_decls = [
            node for node in es_ast.body if isinstance(node, es.ClassDeclaration)
        ]
        class_names = {cls.id.name for cls in class_decls if cls.id}
        self.assertIn("Person", class_names)
        self.assertIn("Employee", class_names)

        var_decls = [
            node for node in es_ast.body if isinstance(node, es.VariableDeclaration)
        ]
        self.assertGreaterEqual(len(var_decls), 2, "Expected const enums and globals")

        ast_json = json.dumps(es_node_to_dict(es_ast))
        self.assertIn("TryStatement", ast_json, "Expected try/except in core fixture")
        self.assertIn(
            "BinaryExpression",
            ast_json,
            "Binary expressions should appear in core fixture",
        )

    def test_advanced_fixture_contains_async_and_spread_nodes(self) -> None:
        """Advanced fixture should surface async, await, and spread constructs."""
        es_ast = self.compile_to_esast(self.get_fixture_path(self.ADVANCED_FIXTURE))

        func_names = {
            node.id.name
            for node in es_ast.body
            if isinstance(node, es.FunctionDeclaration) and node.id
        }
        self.assertIn("lambda_examples", func_names)
        self.assertIn("build_advanced_report", func_names)

        node_types = {type(node).__name__ for node in walk_es_nodes(es_ast)}
        self.assertIn("AwaitExpression", node_types)
        self.assertIn("SpreadElement", node_types)
        self.assertIn("ConditionalExpression", node_types)

        ast_json = json.dumps(es_node_to_dict(es_ast))
        self.assertIn("CallExpression", ast_json)
        self.assertIn("ReturnStatement", ast_json)

    def test_client_fixture_generates_client_bundle(self) -> None:
        """Client fixture should retain JSX lowering behaviour."""
        es_ast = self.compile_to_esast(self.get_fixture_path(self.CLIENT_FIXTURE))
        js_code = es_to_js(es_ast)

        self.assertIn(
            'const API_URL = "https://api.example.com";',
            js_code,
            "Client global should remain const.",
        )
        self.assertIn("function component()", js_code)
        self.assertIn("__jacJsx", js_code)
        self.assertNotIn("server_only", js_code)

    def test_es_ast_serializes_to_json(self) -> None:
        """ESTree should serialize cleanly to JSON for downstream tooling."""
        es_ast = self.compile_to_esast(self.get_fixture_path(self.CORE_FIXTURE))
        ast_dict = es_node_to_dict(es_ast)

        serialized = json.dumps(ast_dict)
        self.assertIn('"type": "Program"', serialized)
        self.assertGreater(len(serialized), 1000)

    def test_class_separate_impl_file(self) -> None:
        """Test that separate impl files work correctly for class archetypes."""
        es_ast = self.compile_to_esast(self.get_fixture_path("class_separate_impl.jac"))
        js_code = es_to_js(es_ast)

        # Check that the Calculator class exists
        class_decls = [
            node for node in es_ast.body if isinstance(node, es.ClassDeclaration)
        ]
        class_names = {cls.id.name for cls in class_decls if cls.id}
        self.assertIn("Calculator", class_names)
        self.assertIn("ScientificCalculator", class_names)

        # Check that methods from impl file are present
        calculator_class = next(
            (cls for cls in class_decls if cls.id and cls.id.name == "Calculator"),
            None,
        )
        self.assertIsNotNone(calculator_class)
        if calculator_class:
            method_names = {
                m.key.name
                for m in calculator_class.body.body
                if isinstance(m, es.MethodDefinition)
                and isinstance(m.key, es.Identifier)
            }
            self.assertIn("add", method_names)
            self.assertIn("multiply", method_names)
            self.assertIn("get_value", method_names)

        # Check JavaScript output contains the methods
        self.assertIn("class Calculator", js_code)
        self.assertIn("class ScientificCalculator", js_code)
        self.assertIn("add(", js_code)
        self.assertIn("multiply(", js_code)
        self.assertIn("power(", js_code)

    def test_fstring_generates_template_literal(self) -> None:
        """Test that f-strings are converted to JavaScript template literals."""
        es_ast = self.compile_to_esast(self.get_fixture_path(self.ADVANCED_FIXTURE))
        js_code = es_to_js(es_ast)

        # Check that template_literal_examples function exists
        func_names = {
            node.id.name
            for node in es_ast.body
            if isinstance(node, es.FunctionDeclaration) and node.id
        }
        self.assertIn("template_literal_examples", func_names)

        # Verify TemplateLiteral nodes are present in the AST
        node_types = {type(node).__name__ for node in walk_es_nodes(es_ast)}
        self.assertIn(
            "TemplateLiteral",
            node_types,
            "F-strings should be converted to TemplateLiteral nodes",
        )
        self.assertIn(
            "TemplateElement",
            node_types,
            "TemplateLiteral should contain TemplateElement nodes",
        )

        # Check that the JavaScript output contains template literal syntax
        self.assertIn(
            "`",
            js_code,
            "JavaScript output should contain backtick for template literals",
        )

        # Verify that the f-string variables are interpolated correctly
        # f"{user} scored {score} which is a {status}"
        # Should become something like: `${user} scored ${score} which is a ${status}`
        self.assertIn("${", js_code, "Template literal should contain ${} syntax")
