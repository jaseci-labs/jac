"""Pytest configuration and shared fixtures for Jaseci tests."""

from __future__ import annotations

import contextlib
import glob
import inspect
import io
import os
from collections.abc import Callable, Generator
from contextlib import AbstractContextManager, contextmanager, redirect_stdout
from pathlib import Path

import pytest

import jaclang

# Import fixed file lists for deterministic test discovery
from jac.tests.fixtures_list import MICRO_JAC_FILES
from jaclang.runtimelib.utils import read_file_with_encoding

_JACLANG_DIR = Path(jaclang.__file__).parent
_PROJECT_ROOT = Path(__file__).parent


def _make_path_fn(*parts: str) -> Callable[[str], str]:
    """Create a path resolver function for the given subdirectory parts."""
    _jac_dir = _PROJECT_ROOT / "jac"
    base = (_jac_dir / "jaclang").joinpath(*parts) if parts else _jac_dir / "examples"
    return lambda f: str((base / f).resolve())


@pytest.fixture
def fixture_path(request: pytest.FixtureRequest) -> Callable[[str], str]:
    """Get absolute path to fixture file relative to test file."""
    test_dir = Path(request.fspath).parent  # type: ignore[arg-type]
    return lambda f: str((test_dir / "fixtures" / f).resolve())


@pytest.fixture
def load_fixture(request: pytest.FixtureRequest) -> Callable[[str], str]:
    """Load fixture content from fixtures directory relative to test file."""
    test_dir = Path(request.fspath).parent  # type: ignore[arg-type]
    return lambda f: read_file_with_encoding(str(test_dir / "fixtures" / f))


@pytest.fixture
def file_to_str() -> Callable[[str], str]:
    """Load content from any file path."""
    return read_file_with_encoding


@pytest.fixture
def examples_path() -> Callable[[str], str]:
    """Get absolute path to examples directory."""
    return _make_path_fn()


@pytest.fixture
def lang_fixture_path() -> Callable[[str], str]:
    """Get absolute path to language fixture files."""
    return _make_path_fn("tests", "fixtures")


@pytest.fixture
def passes_main_fixture_path() -> Callable[[str], str]:
    """Get absolute path to compiler passes main fixtures directory."""
    return _make_path_fn("compiler", "passes", "main", "tests", "fixtures")


@pytest.fixture
def jac_runtime():
    """Provide access to JacRuntime with automatic reset."""
    from jaclang import JacRuntime as Jac

    Jac.reset_machine()
    yield Jac
    Jac.reset_machine()


@pytest.fixture
def jac_program() -> jaclang.compiler.program.JacProgram:
    """Create a fresh JacProgram instance."""
    from jaclang.compiler.program import JacProgram

    return JacProgram()


@pytest.fixture
def capture_stdout() -> Callable[[], AbstractContextManager[io.StringIO]]:
    """Capture stdout during test execution."""

    @contextmanager
    def _capture() -> Generator[io.StringIO, None, None]:
        buffer = io.StringIO()
        with redirect_stdout(buffer):
            yield buffer

    return _capture


def get_micro_jac_files() -> list[str]:
    """Get all .jac files for micro suite testing.

    Uses a fixed list of files from fixtures_list.py for deterministic testing.
    To add new test files, update MICRO_JAC_FILES in jac/tests/fixtures_list.py.
    """
    base_dir = _PROJECT_ROOT / "jac"
    return [os.path.normpath(os.path.join(base_dir, f)) for f in MICRO_JAC_FILES]


_AST_EXCLUDED = {
    "uni_node",
    "uni_scope_node",
    "uni_c_f_g_node",
    "context_aware_node",
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
}


def get_ast_snake_case_names() -> list[str]:
    """Get AST node names in snake_case format."""
    from jaclang.pycore.helpers import get_uni_nodes_as_snake_case as ast_snakes

    return [x for x in ast_snakes() if x not in _AST_EXCLUDED]


def check_pass_ast_complete(target_pass: type) -> None:
    """Check that a pass has all required enter/exit methods for AST nodes."""
    ast_names = set(get_ast_snake_case_names())
    pass_names = {
        name.replace("enter_", "").replace("exit_", "")
        for name, fn in inspect.getmembers(target_pass, inspect.isfunction)
        if (name.startswith("enter_") or name.startswith("exit_"))
        and not getattr(target_pass.__base__, fn.__name__, False)
        and fn.__qualname__.split(".")[0]
        == target_pass.__name__.replace("enter_", "").replace("exit_", "")
    }
    for name in pass_names:
        assert name in ast_names, f"Pass method {name} not in AST nodes"
    for name in ast_names:
        assert name in pass_names, f"AST node {name} missing in pass"


@pytest.fixture(scope="session")
def jaclang_root() -> Path:
    """Get the root directory of jaclang package."""
    return _JACLANG_DIR


@pytest.fixture(scope="session")
def project_root() -> Path:
    """Get the root directory of the project."""
    return _PROJECT_ROOT


def _cleanup_db_files() -> None:
    """Remove database files that may be created by tests or plugins."""
    for pattern in [
        # SQLite files (WAL mode creates -wal and -shm files)
        "*.db",
        "*.db-wal",
        "*.db-shm",
        # Legacy shelf files
        "anchor_store.db.dat",
        "anchor_store.db.bak",
        "anchor_store.db.dir",
    ]:
        for file in glob.glob(pattern):
            with contextlib.suppress(Exception):
                Path(file).unlink()


@pytest.fixture(autouse=True)
def cleanup_plugin_artifacts():
    """Clean up files created by external plugins before and after each test."""
    _cleanup_db_files()
    yield
    _cleanup_db_files()


@pytest.fixture(autouse=True)
def isolate_jac_context(tmp_path: Path) -> Generator[Path, None, None]:
    """Ensure each test has its own isolated Jac context.

    Each test gets a unique temp directory to prevent parallel test
    interference. Tests that call proc_file or set_base_path will
    skip setting base_path if one is already set, so this provides
    default isolation.
    """
    from jaclang.pycore.runtime import JacRuntime as Jac

    original_base_path = Jac.base_path_dir
    original_exec_ctx = Jac.exec_ctx
    # Set base_path to unique temp directory for each test
    # This ensures parallel tests don't share database files
    Jac.set_base_path(str(tmp_path))
    Jac.exec_ctx = None  # Force new context creation
    yield tmp_path
    # Restore original state
    Jac.set_base_path(original_base_path)
    Jac.exec_ctx = original_exec_ctx
