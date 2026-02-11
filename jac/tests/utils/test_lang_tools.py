"""Test ast build pass module."""

import inspect
import os
from collections.abc import Callable

import pytest

from jaclang.runtimelib.utils import read_file_with_encoding
from jaclang.utils.lang_tools import AstTool


@pytest.fixture
def fixture_path() -> Callable[[str], str]:
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
def load_fixture() -> Callable[[str], str]:
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
def tool() -> AstTool:
    """Create AstTool instance for tests."""
    return AstTool()


def test_pass_template(tool: AstTool) -> None:
    """Basic test for pass."""
    out = tool.pass_template()
    assert "target: Expr," in out
    assert "self, node: ast.ReturnStmt" in out
    assert "exprs: Sequence[ExprAsItem]," in out
    assert "path: Sequence[Name | String] | None," in out
    assert "value: str," in out
    assert "def exit_module(self, node: ast.Module)" in out
    assert out.count("def exit_") > 20


def test_gendotfile(tool: AstTool) -> None:
    """Testing for HTML entity."""
    from pathlib import Path

    jac_file_path = str(
        Path(__file__).parent.parent / "language" / "fixtures" / "simple_walk.jac"
    )
    out = tool.ir(["ast.", jac_file_path])
    forbidden_strings = ["<<", ">>", "init", "super"]
    for i in forbidden_strings:
        assert i not in out


def test_print(tool: AstTool) -> None:
    """Testing for print AstTool."""
    from pathlib import Path

    jac_file = str(Path(__file__).parent.parent / "language" / "fixtures" / "hello.jac")
    msg = "error in " + jac_file
    out = tool.ir(["ast", jac_file])
    assert "+-- Token" in out, msg
    assert out is not None, msg


def test_print_py(tool: AstTool) -> None:
    """Testing for print_py AstTool."""
    from pathlib import Path

    jac_file = str(Path(__file__).parent.parent / "language" / "fixtures" / "hello.jac")
    msg = "error in " + jac_file
    out = tool.ir(["pyast", jac_file])
    assert "Module(" in out, msg
    assert out is not None, msg


def test_py_jac_mode(tool: AstTool) -> None:
    """Testing for py_jac_mode support."""
    from pathlib import Path

    file = str(Path(__file__).parent.parent / "language" / "fixtures" / "pyfunc.py")
    out = tool.ir(["unparse", file])
    assert "def my_print(x: object) -> None" in out


def test_sym_sym_dot(tool: AstTool) -> None:
    """Testing for sym, sym. AstTool."""
    from pathlib import Path

    jac_file = str(Path(__file__).parent.parent / "language" / "fixtures" / "hello.jac")
    out = tool.ir(["sym", jac_file])
    assert (
        "\n|   +-- ConnectionAbortedError\n|   |   +-- public var\n|   +-- ConnectionError\n|"
        not in out
    )
    check_list = [
        "######",
        "# hello #",
        "######",
        "SymTable::Module(hello)",
    ]
    for i in check_list:
        assert i in out
    out = tool.ir(["sym.", jac_file])
    assert '[label="' in out


def test_uninode_doc(tool: AstTool) -> None:
    """Testing for Autodoc for Uninodes."""
    auto_uni = tool.autodoc_uninode()
    assert (
        "## LambdaExpr\n```mermaid\nflowchart LR\nLambdaExpr -->|Expr , CodeBlockStmt| body"
        in auto_uni
    )
