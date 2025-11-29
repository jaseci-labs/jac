"""Test ast build pass module."""

import inspect
import os

import pytest

import jaclang
from jaclang.runtimelib.utils import read_file_with_encoding
from jaclang.utils.helpers import extract_headings, heading_to_snake
from jaclang.utils.lang_tools import AstTool


@pytest.fixture
def fixture_path():
    """Get absolute path to fixture file."""

    def _fixture_path(fixture: str) -> str:
        frame = inspect.currentframe()
        if frame is None or frame.f_back is None:
            raise ValueError("Unable to get the previous stack frame.")
        module = inspect.getmodule(frame.f_back)
        if module is None or module.__file__ is None:
            raise ValueError("Unable to determine the file of the module.")
        fixture_src = module.__file__
        file_path = os.path.join(os.path.dirname(fixture_src), "fixtures", fixture)
        return os.path.abspath(file_path)

    return _fixture_path


@pytest.fixture
def load_fixture():
    """Load fixture from fixtures directory."""

    def _load_fixture(fixture: str) -> str:
        frame = inspect.currentframe()
        if frame is None or frame.f_back is None:
            raise ValueError("Unable to get the previous stack frame.")
        module = inspect.getmodule(frame.f_back)
        if module is None or module.__file__ is None:
            raise ValueError("Unable to determine the file of the module.")
        fixture_src = module.__file__
        fixture_path = os.path.join(os.path.dirname(fixture_src), "fixtures", fixture)
        return read_file_with_encoding(fixture_path)

    return _load_fixture


@pytest.fixture
def tool():
    """Create AstTool instance for tests."""
    return AstTool()


def test_pass_template(tool) -> None:
    """Basic test for pass."""
    out = tool.pass_template()
    assert "target: Expr," in out
    assert "self, node: ast.ReturnStmt" in out
    assert "exprs: Sequence[ExprAsItem]," in out
    assert "path: Sequence[Name | String] | None," in out
    assert "value: str," in out
    assert "def exit_module(self, node: ast.Module)" in out
    assert out.count("def exit_") > 20


def test_gendotfile(tool) -> None:
    """Testing for HTML entity."""
    jac_file_path = os.path.join(
        os.path.dirname(jaclang.__file__), "../examples/reference/edges_walk.jac"
    )
    out = tool.ir(["ast.", jac_file_path])
    forbidden_strings = ["<<", ">>", "init", "super"]
    for i in forbidden_strings:
        assert i not in out


def test_print(tool) -> None:
    """Testing for print AstTool."""
    jac_file = os.path.join(
        os.path.dirname(jaclang.__file__),
        "../examples/reference/names_and_references.jac",
    )
    msg = "error in " + jac_file
    out = tool.ir(["ast", jac_file])
    assert "+-- Token" in out, msg
    assert out is not None, msg


def test_print_py(tool) -> None:
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
        out = tool.ir(["pyast", jac_py_directory + file])
        if file.endswith(".jac"):
            assert "Module(" in out, msg
            assert out is not None, msg
        elif file.endswith(".py"):
            if len(out.splitlines()) <= 4:
                continue
            assert "Module(" in out, msg
            assert out is not None, msg


def test_automated() -> None:
    """Testing for py, jac, md files for each content in Jac Grammer."""
    lark_path = os.path.join(os.path.dirname(jaclang.__file__), "compiler/jac.lark")
    headings_ = extract_headings(lark_path)
    snake_case_headings = [heading_to_snake(key) for key in headings_]
    refr_path = os.path.join(os.path.dirname(jaclang.__file__), "../examples/reference")
    file_extensions = [".py", ".jac", ".md"]
    created_files = [f"{os.path.join(refr_path, 'introduction.md')}"]
    for heading_name in snake_case_headings:
        for extension in file_extensions:
            file_name = heading_name + extension
            file_path = os.path.join(refr_path, file_name)
            assert os.path.exists(file_path), f"File '{file_path}' does not exist."
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
    assert len(other_reference_files) == 0


def test_py_jac_mode(tool, fixture_path) -> None:
    """Testing for py_jac_mode support."""
    file = fixture_path("../../../tests/fixtures/pyfunc.py")
    out = tool.ir(["unparse", file])
    assert "def my_print(x: object) -> None" in out


def test_sym_sym_dot(tool) -> None:
    """Testing for sym, sym. AstTool."""
    jac_file = os.path.normpath(
        os.path.join(
            os.path.dirname(jaclang.__file__),
            "../examples/reference/while_statements.jac",
        )
    )
    out = tool.ir(["sym", jac_file])
    assert (
        "\n|   +-- ConnectionAbortedError\n|   |   +-- public var\n|   +-- ConnectionError\n|"
        not in out
    )
    check_list = [
        "########",
        "# while_statements #",
        "########",
        "SymTable::Module(while_statements)",
    ]
    for i in check_list:
        assert i in out
    out = tool.ir(["sym.", jac_file])
    assert '[label="' in out


def test_uninode_doc(tool) -> None:
    """Testing for Autodoc for Uninodes."""
    auto_uni = tool.autodoc_uninode()
    assert (
        "## LambdaExpr\n```mermaid\nflowchart LR\nLambdaExpr -->|Expr , CodeBlockStmt| body"
        in auto_uni
    )
