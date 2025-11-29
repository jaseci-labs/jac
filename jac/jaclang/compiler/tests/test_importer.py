"""Tests for Jac Loader."""

import io
import os
import sys

import pytest

from jaclang import JacRuntime as Jac
from jaclang.cli import cli
from jaclang.compiler.program import JacProgram
from jaclang.runtimelib.runtime import JacRuntimeInterface
from jaclang.settings import settings


@pytest.fixture
def fixture_abs_path():
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
def reset_jac_machine():
    """Reset Jac machine before each test."""
    Jac.reset_machine()
    yield
    # Optional cleanup after test
    Jac.reset_machine()


def test_import_basic_python(fixture_abs_path) -> None:
    """Test basic self loading."""
    sys.modules.pop("fixtures", None)
    sys.modules.pop("fixtures.hello_world", None)
    Jac.set_base_path(fixture_abs_path(__file__))
    JacRuntimeInterface.attach_program(
        JacProgram(),
    )
    (h,) = Jac.jac_import("fixtures.hello_world", base_path=__file__)
    assert h.hello() == "Hello World!"  # type: ignore


def test_modules_correct(fixture_abs_path) -> None:
    """Test basic self loading."""
    sys.modules.pop("fixtures", None)
    sys.modules.pop("fixtures.hello_world", None)
    Jac.set_base_path(fixture_abs_path(__file__))
    JacRuntimeInterface.attach_program(
        JacProgram(),
    )
    Jac.jac_import("fixtures.hello_world", base_path=__file__)
    assert "module 'fixtures.hello_world'" in str(Jac.loaded_modules)
    assert "/tests/fixtures/hello_world.jac" in str(Jac.loaded_modules).replace(
        "\\\\", "/"
    )


def test_jac_py_import(fixture_abs_path) -> None:
    """Basic test for pass."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    cli.run(fixture_abs_path("../../../tests/fixtures/jp_importer.jac"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert "Hello World!" in stdout_value
    assert (
        "{SomeObj(a=10): 'check'} [MyObj(apple=5, banana=7), MyObj(apple=5, banana=7)]"
        in stdout_value
    )


def test_jac_py_import_auto(fixture_abs_path) -> None:
    """Basic test for pass."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    cli.run(fixture_abs_path("../../../tests/fixtures/jp_importer_auto.jac"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert "Hello World!" in stdout_value
    assert (
        "{SomeObj(a=10): 'check'} [MyObj(apple=5, banana=7), MyObj(apple=5, banana=7)]"
        in stdout_value
    )


def test_import_with_jacpath(fixture_abs_path) -> None:
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
        cli.run(jac_file_path)

        # Reset stdout and get the output
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()

        assert "Hello from JACPATH!" in stdout_value

    finally:
        captured_output.close()

        os.environ.pop("JACPATH", None)
        jacpath_dir.cleanup()


def test_importer_with_submodule_jac(fixture_abs_path) -> None:
    """Test basic self loading."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    cli.run(fixture_abs_path("pkg_import_main.jac"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert "Helper function called" in stdout_value
    assert "Tool function executed" in stdout_value


def test_importer_with_submodule_py(fixture_abs_path) -> None:
    captured_output = io.StringIO()
    sys.stdout = captured_output
    cli.run(fixture_abs_path("pkg_import_main_py.jac"))
    sys.stdout = sys.__stdout__
    stdout_value = captured_output.getvalue()
    assert "Helper function called" in stdout_value
    assert "Tool function executed" in stdout_value
    assert "pkg_import_lib_py.glob_var_lib" in stdout_value


def test_jac_import_py_files(fixture_abs_path) -> None:
    """Test importing Python files using Jac import system."""
    captured_output = io.StringIO()
    sys.stdout = captured_output
    os.environ["JAC_PYFILE_RAISE"] = "True"
    settings.load_env_vars()
    original_cwd = os.getcwd()
    try:
        os.chdir(os.path.dirname(fixture_abs_path("jac_import_py_files.py")))
        Jac.set_base_path(fixture_abs_path("jac_import_py_files.py"))
        JacRuntimeInterface.attach_program(JacProgram())
        Jac.jac_import(
            "jac_import_py_files",
            base_path=fixture_abs_path("jac_import_py_files.py"),
            lng="py",
        )
        cli.run(fixture_abs_path("jac_import_py_files.py"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        assert "This is main test file for jac import of python files" in stdout_value
        assert "python_module <jaclang.compiler.unitree.Module object" in str(
            Jac.program.mod.hub
        )
        assert "jac_module <jaclang.compiler.unitree.Module object" in str(
            Jac.program.mod.hub
        )
        os.environ["JAC_PYFILE_RAISE"] = "false"
        settings.load_env_vars()
        os.chdir(os.path.dirname(fixture_abs_path("jac_import_py_files.py")))
        Jac.reset_machine()
        Jac.set_base_path(fixture_abs_path("jac_import_py_files.py"))
        JacRuntimeInterface.attach_program(JacProgram())
        Jac.jac_import(
            "jac_import_py_files",
            base_path=fixture_abs_path("jac_import_py_files.py"),
            lng="py",
        )
        cli.run(fixture_abs_path("jac_import_py_files.py"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        assert "This is main test file for jac import of python files" in stdout_value
        assert "python_module <jaclang.compiler.unitree.Module object" not in str(
            Jac.program.mod.hub
        )
        assert "jac_module <jaclang.compiler.unitree.Module object" in str(
            Jac.program.mod.hub
        )
    finally:
        os.chdir(original_cwd)
