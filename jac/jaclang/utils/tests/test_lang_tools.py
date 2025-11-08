"""Test ast build pass module."""

import os

import jaclang
from jaclang.utils.helpers import extract_headings, heading_to_snake
from jaclang.utils.lang_tools import AstTool
from jaclang.utils.test import TestCase


class JacAstToolTests(TestCase):
    """Test pass module."""

    def setUp(self) -> None:
        """Set up test."""
        self.tool = AstTool()
        return super().setUp()

    def test_pass_template(self) -> None:
        """Basic test for pass."""
        out = self.tool.pass_template()
        self.assertIn("target: Expr,", out)
        self.assertIn("self, node: ast.ReturnStmt", out)
        self.assertIn("exprs: Sequence[ExprAsItem],", out)
        self.assertIn("path: Optional[Sequence[Name]],", out)
        self.assertIn("value: str,", out)
        self.assertIn("def exit_module(self, node: ast.Module)", out)
        self.assertGreater(out.count("def exit_"), 20)

    def test_gendotfile(self) -> None:
        """Testing for HTML entity."""
        jac_file_path = os.path.join(
            os.path.dirname(jaclang.__file__), "../examples/reference/edges_walk.jac"
        )
        out = self.tool.ir(["ast.", jac_file_path])
        forbidden_strings = ["<<", ">>", "init", "super"]
        for i in forbidden_strings:
            self.assertNotIn(i, out)

    def test_print(self) -> None:
        """Testing for print AstTool."""
        jac_file = os.path.join(
            os.path.dirname(jaclang.__file__),
            "../examples/reference/names_and_references.jac",
        )
        msg = "error in " + jac_file
        out = self.tool.ir(["ast", jac_file])
        self.assertIn("+-- Token", out, msg)
        self.assertIsNotNone(out, msg=msg)

    def test_print_py(self) -> None:
        """Testing for print_py AstTool."""
        jac_py_directory = os.path.join(
            os.path.dirname(jaclang.__file__), "../examples/reference/"
        )
        jac_py_files = [
            f
            for f in os.listdir(jac_py_directory)
            if f.endswith(("names_and_references.jac", "names_and_references.py"))
        ]

        for file in jac_py_files:
            msg = "error in " + file
            out = self.tool.ir(["pyast", jac_py_directory + file])
            if file.endswith(".jac"):
                self.assertIn("Module(", out, msg)
                self.assertIsNotNone(out, msg=msg)
            elif file.endswith(".py"):
                if len(out.splitlines()) <= 4:
                    continue
                self.assertIn("Module(", out, msg)
                self.assertIsNotNone(out, msg=msg)

    def test_automated(self) -> None:
        """Testing for py, jac, md files for each content in Jac Grammer."""
        lark_path = os.path.join(os.path.dirname(jaclang.__file__), "compiler/jac.lark")
        headings_ = extract_headings(lark_path)
        snake_case_headings = [heading_to_snake(key) for key in headings_.keys()]
        refr_path = os.path.join(
            os.path.dirname(jaclang.__file__), "../examples/reference"
        )
        file_extensions = [".py", ".jac", ".md"]
        created_files = [f"{os.path.join(refr_path, 'introduction.md')}"]
        for heading_name in snake_case_headings:
            for extension in file_extensions:
                file_name = heading_name + extension
                file_path = os.path.join(refr_path, file_name)
                self.assertTrue(
                    os.path.exists(file_path), f"File '{file_path}' does not exist."
                )
                created_files.append(file_path)
        all_reference_files = [
            os.path.join(refr_path, file)
            for file in os.listdir(refr_path)
            if os.path.isfile(os.path.join(refr_path, file))
        ]
        other_reference_files = [
            os.path.basename(file)
            for file in all_reference_files
            if file not in created_files
        ]
        print(other_reference_files)
        self.assertEqual(len(other_reference_files), 0)

    def test_py_jac_mode(self) -> None:
        """Testing for py_jac_mode support."""
        file = self.fixture_abs_path("../../../tests/fixtures/pyfunc.py")
        out = self.tool.ir(["unparse", file])
        self.assertIn("def my_print(x: object) -> None", out)

    def test_sym_sym_dot(self) -> None:
        """Testing for sym, sym. AstTool."""
        jac_file = os.path.normpath(
            os.path.join(
                os.path.dirname(jaclang.__file__), "../examples/reference/atom.jac"
            )
        )
        out = self.tool.ir(["sym", jac_file])
        self.assertNotIn(
            "\n|   +-- ConnectionAbortedError\n|   |   +-- public var\n|   +-- ConnectionError\n|",
            out,
        )
        check_list = [
            "########",
            "# atom #",
            "########",
            "SymTable::Module(atom)",
            "|   +-- list1",
            "|   +-- x",
            "|   +-- impl.x",
            "|   +-- c",
            "|   +-- d",
            "|   +-- a",
            "|   +-- b",
            "+-- SymTable::ImplDef(impl.x)",
            " SymTable::Enum(x)",
            "+-- line 19, col 13",
        ]
        for i in check_list:
            self.assertIn(i, out)
        out = self.tool.ir(["sym.", jac_file])
        self.assertIn('[label="impl.x"];', out)
        self.assertNotIn('[label="str"];', out)

    def test_uninode_doc(self) -> None:
        """Testing for Autodoc for Uninodes."""
        auto_uni = self.tool.autodoc_uninode()
        self.assertIn(
            "## LambdaExpr\n```mermaid\nflowchart LR\nLambdaExpr -->|Expr| body",
            auto_uni,
        )
