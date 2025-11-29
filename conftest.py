"""Pytest configuration and shared fixtures for Jaseci tests."""

from __future__ import annotations

import inspect
import os
from collections.abc import Callable, Generator
from pathlib import Path
from typing import TYPE_CHECKING

import pytest

import jaclang
from jaclang.runtimelib.utils import read_file_with_encoding

if TYPE_CHECKING:
    import io
    from contextlib import AbstractContextManager

    from jaclang.compiler.program import JacProgram


# ============================================================================
# Core Fixtures (replacements for TestCase methods)
# ============================================================================


@pytest.fixture
def fixture_path(request: pytest.FixtureRequest) -> Callable[[str], str]:
    """Get absolute path of a fixture from fixtures directory relative to test file.

    Usage:
        def test_something(fixture_path):
            path = fixture_path("my_fixture.jac")
    """
    test_file = Path(request.fspath)  # type: ignore[arg-type]

    def _fixture_path(fixture: str) -> str:
        file_path = test_file.parent / "fixtures" / fixture
        return str(file_path.resolve())

    return _fixture_path


@pytest.fixture
def load_fixture(request: pytest.FixtureRequest) -> Callable[[str], str]:
    """Load fixture content from fixtures directory relative to test file.

    Usage:
        def test_something(load_fixture):
            content = load_fixture("my_fixture.jac")
    """
    test_file = Path(request.fspath)  # type: ignore[arg-type]

    def _load_fixture(fixture: str) -> str:
        fixture_path = test_file.parent / "fixtures" / fixture
        return read_file_with_encoding(str(fixture_path))

    return _load_fixture


@pytest.fixture
def file_to_str() -> Callable[[str], str]:
    """Load content from any file path.

    Usage:
        def test_something(file_to_str):
            content = file_to_str("/path/to/file.txt")
    """

    def _file_to_str(file_path: str) -> str:
        return read_file_with_encoding(file_path)

    return _file_to_str


@pytest.fixture
def examples_path() -> Callable[[str], str]:
    """Get absolute path to examples directory.

    Usage:
        def test_something(examples_path):
            path = examples_path("micro/simple.jac")
    """

    def _examples_path(example: str) -> str:
        fixture_src = jaclang.__file__
        file_path = os.path.join(
            os.path.dirname(os.path.dirname(fixture_src)), "examples", example
        )
        return os.path.abspath(file_path)

    return _examples_path


@pytest.fixture
def lang_fixture_path() -> Callable[[str], str]:
    """Get absolute path to language fixture files.

    Usage:
        def test_something(lang_fixture_path):
            path = lang_fixture_path("some_test.jac")
    """

    def _lang_fixture_path(file: str) -> str:
        fixture_src = jaclang.__file__
        file_path = os.path.join(
            os.path.dirname(fixture_src), "tests", "fixtures", file
        )
        return os.path.abspath(file_path)

    return _lang_fixture_path


@pytest.fixture
def passes_main_fixture_path() -> Callable[[str], str]:
    """Get absolute path to compiler passes main fixtures directory.

    Usage:
        def test_something(passes_main_fixture_path):
            path = passes_main_fixture_path("test.jac")
    """

    def _passes_main_fixture_path(file: str) -> str:
        fixture_src = jaclang.__file__
        file_path = os.path.join(
            os.path.dirname(fixture_src),
            "compiler",
            "passes",
            "main",
            "tests",
            "fixtures",
            file,
        )
        return os.path.abspath(file_path)

    return _passes_main_fixture_path


# ============================================================================
# Jac Runtime Fixtures
# ============================================================================


@pytest.fixture
def jac_runtime():
    """Provide access to JacRuntime with automatic reset.

    Usage:
        def test_something(jac_runtime, fixture_path):
            jac_runtime.reset_machine()
            jac_runtime.jac_import("module", base_path=fixture_path("./"))
    """
    from jaclang import JacRuntime as Jac

    Jac.reset_machine()
    yield Jac
    Jac.reset_machine()


@pytest.fixture
def jac_program() -> JacProgram:
    """Create a fresh JacProgram instance.

    Usage:
        def test_something(jac_program):
            result = jac_program.compile("test.jac")
    """
    from jaclang.compiler.program import JacProgram

    return JacProgram()


# ============================================================================
# Output Capture Fixtures
# ============================================================================


@pytest.fixture
def capture_stdout() -> Callable[[], AbstractContextManager[io.StringIO]]:
    """Capture stdout during test execution.

    Usage:
        def test_something(capture_stdout, jac_runtime, fixture_path):
            with capture_stdout() as output:
                jac_runtime.jac_import("module", base_path=fixture_path("./"))
            assert "expected" in output.getvalue()
    """
    import io
    import sys
    from contextlib import contextmanager

    @contextmanager
    def _capture_stdout() -> Generator[io.StringIO, None, None]:
        captured = io.StringIO()
        old_stdout = sys.stdout
        sys.stdout = captured
        try:
            yield captured
        finally:
            sys.stdout = old_stdout

    return _capture_stdout


# ============================================================================
# MicroSuite Support
# ============================================================================


def get_micro_jac_files() -> list[str]:
    """Get all .jac files for micro suite testing."""
    files = []
    base_dir = os.path.dirname(os.path.dirname(jaclang.__file__))
    for root, _, filenames in os.walk(base_dir):
        for name in filenames:
            if name.endswith(".jac") and "err" not in name:
                files.append(os.path.normpath(os.path.join(root, name)))
    return files


# ============================================================================
# AST Sync Test Helpers
# ============================================================================


def get_ast_snake_case_names() -> list[str]:
    """Get AST node names in snake_case format."""
    from jaclang.utils.helpers import get_uni_nodes_as_snake_case as ast_snakes

    excluded = [
        "uni_node",
        "uni_scope_node",
        "uni_c_f_g_node",
        "client_facing_node",
        "program_module",
        "walker_stmt_only_node",
        "source",
        "empty_token",
        "ast_symbol_node",
        "ast_symbol_stub_node",
        "ast_impl_needing_node",
        "ast_access_node",
        "token_symbol",
        "literal",
        "ast_doc_node",
        "ast_sem_str_node",
        "python_module_ast",
        "ast_async_node",
        "ast_else_body_node",
        "ast_typed_var_node",
        "ast_impl_only_node",
        "expr",
        "atom_expr",
        "element_stmt",
        "arch_block_stmt",
        "enum_block_stmt",
        "code_block_stmt",
        "name_atom",
        "arch_spec",
        "match_pattern",
        "switch_stmt",
        "switch_case",
    ]
    return [x for x in ast_snakes() if x not in excluded]


def check_pass_ast_complete(target_pass: type) -> None:
    """Check that a pass has all required enter/exit methods for AST nodes.

    Usage in test:
        def test_pass_ast_complete():
            from jaclang.compiler.passes.main import SomePass
            check_pass_ast_complete(SomePass)
    """
    ast_func_names = get_ast_snake_case_names()
    pygen_func_names = []

    for name, value in inspect.getmembers(target_pass):
        if (
            (name.startswith("enter_") or name.startswith("exit_"))
            and inspect.isfunction(value)
            and not getattr(target_pass.__base__, value.__name__, False)
            and value.__qualname__.split(".")[0]
            == target_pass.__name__.replace("enter_", "").replace("exit_", "")
        ):
            pygen_func_names.append(name.replace("enter_", "").replace("exit_", ""))

    for name in pygen_func_names:
        assert name in ast_func_names, f"Pass method {name} not in AST nodes"
    for name in ast_func_names:
        assert name in pygen_func_names, f"AST node {name} missing in pass"


# ============================================================================
# Test Collection Hooks
# ============================================================================


def pytest_collection_modifyitems(
    session: pytest.Session, config: pytest.Config, items: list[pytest.Item]
) -> None:
    """Modify test collection to handle any special cases."""
    pass


# ============================================================================
# Session-Scoped Fixtures
# ============================================================================


@pytest.fixture(scope="session")
def jaclang_root() -> Path:
    """Get the root directory of jaclang package."""
    return Path(jaclang.__file__).parent


@pytest.fixture(scope="session")
def project_root() -> Path:
    """Get the root directory of the project."""
    return Path(__file__).parent
