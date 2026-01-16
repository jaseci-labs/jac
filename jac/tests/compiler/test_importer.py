"""Tests for Jac Loader."""

import io
import os
import sys
from collections.abc import Callable, Generator
from pathlib import Path

import pytest

from jaclang import JacRuntime as Jac
from jaclang import JacRuntimeInterface
from jaclang.cli.commands import execution  # type: ignore[attr-defined]
from jaclang.pycore.program import JacProgram


@pytest.fixture
def fixture_abs_path() -> Callable[[str], str]:
    """Get absolute path to fixture file."""
    import inspect

    def _fixture_abs_path(fixture: str) -> str:
        frame = inspect.currentframe()
        if frame is None or frame.f_back is None:
            raise ValueError("Unable to get the previous stack frame.")
        module = inspect.getmodule(frame.f_back)
        if module is None or module.__file__ is None:
            raise ValueError("Unable to determine the file of the module.")
        fixture_src = module.__file__
        file_path = os.path.join(os.path.dirname(fixture_src), "fixtures", fixture)
        return os.path.abspath(file_path)

    return _fixture_abs_path


@pytest.fixture(autouse=True)
def reset_jac_machine(tmp_path: Path) -> Generator[None, None, None]:
    """Reset Jac machine before each test."""
    # Use tmp_path for session isolation in parallel tests
    Jac.reset_machine(base_path=str(tmp_path))
    yield
    # Optional cleanup after test
    Jac.reset_machine(base_path=str(tmp_path))


def test_import_basic_python(fixture_abs_path: Callable[[str], str]) -> None:
    """Test basic self loading."""
    sys.modules.pop("fixtures", None)
    sys.modules.pop("fixtures.hello_world", None)
    Jac.set_base_path(fixture_abs_path(__file__))
    JacRuntimeInterface.attach_program(
        JacProgram(),
    )
    (h,) = Jac.jac_import("fixtures.hello_world", base_path=__file__)
    assert h.hello() == "Hello World!"  # type: ignore


def test_modules_correct(fixture_abs_path: Callable[[str], str]) -> None:
    """Test basic self loading."""
    sys.modules.pop("fixtures", None)
    sys.modules.pop("fixtures.hello_world", None)
    Jac.set_base_path(fixture_abs_path(__file__))
    JacRuntimeInterface.attach_program(
        JacProgram(),
    )
    Jac.jac_import("fixtures.hello_world", base_path=__file__)
    assert "module 'fixtures.hello_world'" in str(Jac.loaded_modules)
    assert "/tests/compiler/fixtures/hello_world.jac" in str(
        Jac.loaded_modules
    ).replace("\\\\", "/")


def test_jac_py_import() -> None:
    """Basic test for pass."""
    from pathlib import Path

    fixture_file = str(
        Path(__file__).parent.parent / "language" / "fixtures" / "jp_importer.jac"
    )
    captured_output = io.StringIO()
    sys.stdout = captured_output
    execution.run(fixture_file)
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert "Hello World!" in stdout_value
    assert (
        "{SomeObj(a=10): 'check'} [MyObj(apple=5, banana=7), MyObj(apple=5, banana=7)]"
        in stdout_value
    )


def test_jac_py_import_auto() -> None:
    """Basic test for pass."""
    from pathlib import Path

    fixture_file = str(
        Path(__file__).parent.parent / "language" / "fixtures" / "jp_importer_auto.jac"
    )
    captured_output = io.StringIO()
    sys.stdout = captured_output
    execution.run(fixture_file)
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert "Hello World!" in stdout_value
    assert (
        "{SomeObj(a=10): 'check'} [MyObj(apple=5, banana=7), MyObj(apple=5, banana=7)]"
        in stdout_value
    )


def test_import_with_jacpath(fixture_abs_path: Callable[[str], str]) -> None:
    """Test module import using JACPATH."""
    # Set up a temporary JACPATH environment variable
    import os
    import tempfile

    jacpath_dir = tempfile.TemporaryDirectory()
    os.environ["JACPATH"] = jacpath_dir.name

    # Create a mock Jac file in the JACPATH directory
    module_name = "test_module"
    jac_file_path = os.path.join(jacpath_dir.name, f"{module_name}.jac")
    with open(jac_file_path, "w") as f:
        f.write(
            """
            with entry {
                "Hello from JACPATH!" :> print;
            }
            """
        )

    # Capture the output
    captured_output = io.StringIO()
    sys.stdout = captured_output

    try:
        Jac.set_base_path(fixture_abs_path(__file__))
        JacRuntimeInterface.attach_program(
            JacProgram(),
        )
        Jac.jac_import(module_name, base_path=__file__)
        execution.run(jac_file_path)

        # Reset stdout and get the output
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()

        assert "Hello from JACPATH!" in stdout_value

    finally:
        captured_output.close()

        os.environ.pop("JACPATH", None)
        jacpath_dir.cleanup()


def test_importer_with_submodule_jac(fixture_abs_path: Callable[[str], str]) -> None:
    """Test basic self loading."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    execution.run(fixture_abs_path("pkg_import_main.jac"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert "Helper function called" in stdout_value
    assert "Tool function executed" in stdout_value


def test_importer_with_submodule_py(fixture_abs_path: Callable[[str], str]) -> None:
    captured_output = io.StringIO()
    sys.stdout = captured_output
    execution.run(fixture_abs_path("pkg_import_main_py.jac"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert "Helper function called" in stdout_value
    assert "Tool function executed" in stdout_value
    assert "pkg_import_lib_py.glob_var_lib" in stdout_value


def test_python_dash_m_jac_module(fixture_abs_path: Callable[[str], str]) -> None:
    """Test running a Jac module using 'python -m module_name'.

    This tests that the JacMetaImporter.get_code() method works correctly
    when runpy needs to execute a Jac module. Requires jaclang to be
    auto-imported via a .pth file (e.g., jaclang_hook.pth with 'import jaclang').
    """
    import subprocess
    import tempfile

    # Create a temporary directory with a Jac module
    with tempfile.TemporaryDirectory() as tmpdir:
        # Ensure JacMetaImporter is registered in the subprocess.
        #
        # In some environments (e.g., CI), jaclang may be installed without a
        # startup hook (.pth) that imports jaclang automatically. Creating a
        # `sitecustomize.py` in the subprocess working directory guarantees the
        # importer is registered before `python -m ...` executes.
        sitecustomize_file = os.path.join(tmpdir, "sitecustomize.py")
        with open(sitecustomize_file, "w") as f:
            f.write("import jaclang\n")

        # Create a simple Jac module
        module_name = "test_dash_m_module"
        jac_file = os.path.join(tmpdir, f"{module_name}.jac")
        with open(jac_file, "w") as f:
            f.write('with entry { "python -m works" :> print; }\n')

        # Run using python -m directly (requires JacMetaImporter to be registered)
        env = os.environ.copy()
        env["PYTHONPATH"] = os.pathsep.join(
            p for p in [tmpdir, env.get("PYTHONPATH")] if p
        )
        result = subprocess.run(
            [sys.executable, "-m", module_name],
            capture_output=True,
            text=True,
            cwd=tmpdir,
            env=env,
        )

        # Check that it executed successfully
        assert result.returncode == 0, f"Failed with stderr: {result.stderr}"
        assert "python -m works" in result.stdout


def test_python_dash_m_jac_package(fixture_abs_path: Callable[[str], str]) -> None:
    """Test running a Jac package using 'python -m package_name'.

    This tests that the JacMetaImporter.get_code() method works correctly
    when runpy needs to execute a Jac package's __main__.jac. Requires jaclang
    to be auto-imported via a .pth file (e.g., jaclang_hook.pth with 'import jaclang').
    """
    import subprocess
    import tempfile

    # Create a temporary directory with a Jac package
    with tempfile.TemporaryDirectory() as tmpdir:
        # Ensure JacMetaImporter is registered in the subprocess; see
        # `test_python_dash_m_jac_module` for details.
        sitecustomize_file = os.path.join(tmpdir, "sitecustomize.py")
        with open(sitecustomize_file, "w") as f:
            f.write("import jaclang\n")

        # Create a package directory with __init__.jac and __main__.jac
        pkg_name = "test_pkg"
        pkg_dir = os.path.join(tmpdir, pkg_name)
        os.makedirs(pkg_dir)

        init_file = os.path.join(pkg_dir, "__init__.jac")
        with open(init_file, "w") as f:
            f.write("# Package init\n")

        # __main__.jac is needed for `python -m package_name` to work
        main_file = os.path.join(pkg_dir, "__main__.jac")
        with open(main_file, "w") as f:
            f.write('with entry { "package main works" :> print; }\n')

        # Run using python -m directly (requires JacMetaImporter to be registered)
        env = os.environ.copy()
        env["PYTHONPATH"] = os.pathsep.join(
            p for p in [tmpdir, env.get("PYTHONPATH")] if p
        )
        result = subprocess.run(
            [sys.executable, "-m", pkg_name],
            capture_output=True,
            text=True,
            cwd=tmpdir,
            env=env,
        )

        # Check that it executed successfully
        assert result.returncode == 0, f"Failed with stderr: {result.stderr}"
        assert "package main works" in result.stdout


def test_compiler_separates_internal_from_user_modules() -> None:
    """Test that jaclang.* modules go to compiler's hub, not user's program hub.

    This integration test runs a jac file and verifies that:
    1. User modules end up in the user program's module hub
    2. Internal jaclang modules end up in the compiler's internal hub
    """
    import tempfile

    # Create a user jac file that uses jaclang runtime features
    with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as tmp_file:
        tmp_file.write('with entry { "hello" :> print; }\n')
        user_file = tmp_file.name

    try:
        # Capture output and run the file
        captured_output = io.StringIO()
        sys.stdout = captured_output
        execution.run(user_file)
        sys.stdout = sys.__stdout__

        # Verify output worked
        assert "hello" in captured_output.getvalue()

        # Now verify the module hub separation
        compiler = Jac.get_compiler()
        user_program = Jac.get_program()
        jaclang_root = compiler._get_jaclang_root()

        # Get the hub paths
        internal_hub_paths = list(compiler.internal_program.mod.hub.keys())
        user_hub_paths = list(user_program.mod.hub.keys())

        # User hub must be non-empty (the test file was compiled)
        assert len(user_hub_paths) > 0, "User program hub should not be empty"
        # Note: internal hub may be empty if jaclang modules came from disk cache

        # All paths in compiler's internal hub must be jaclang paths
        for path in internal_hub_paths:
            assert path.startswith(jaclang_root), (
                f"Non-jaclang path {path} found in compiler's internal hub"
            )

        # No jaclang paths should be in user's program hub
        for path in user_hub_paths:
            assert not path.startswith(jaclang_root), (
                f"Jaclang internal path {path} found in user's program hub"
            )

    finally:
        os.unlink(user_file)
