"""Tests for Jac Loader."""

import io
import os
import sys

from jaclang import JacMachine as Jac
from jaclang.cli import cli
from jaclang.compiler.program import JacProgram
from jaclang.runtimelib.machine import JacMachineInterface
from jaclang.utils.test import TestCase
from jaclang.settings import settings


class TestLoader(TestCase):
    """Test Jac self.prse."""

    def test_import_basic_python(self) -> None:
        """Test basic self loading."""
        Jac.reset_machine()
        sys.modules.pop("fixtures", None)
        sys.modules.pop("fixtures.hello_world", None)
        Jac.set_base_path(self.fixture_abs_path(__file__))
        JacMachineInterface.attach_program(
            JacProgram(),
        )
        (h,) = Jac.jac_import("fixtures.hello_world", base_path=__file__)
        self.assertEqual(h.hello(), "Hello World!")  # type: ignore

    def test_modules_correct(self) -> None:
        """Test basic self loading."""
        Jac.reset_machine()
        sys.modules.pop("fixtures", None)
        sys.modules.pop("fixtures.hello_world", None)
        Jac.set_base_path(self.fixture_abs_path(__file__))
        JacMachineInterface.attach_program(
            JacProgram(),
        )
        Jac.jac_import("fixtures.hello_world", base_path=__file__)
        self.assertIn(
            "module 'fixtures.hello_world'",
            str(Jac.loaded_modules),
        )
        self.assertIn(
            "/tests/fixtures/hello_world.jac",
            str(Jac.loaded_modules).replace("\\\\", "/"),
        )

    def test_jac_py_import(self) -> None:
        """Basic test for pass."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.run(self.fixture_abs_path("../../../tests/fixtures/jp_importer.jac"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("Hello World!", stdout_value)
        self.assertIn(
            "{SomeObj(a=10): 'check'} [MyObj(apple=5, banana=7), MyObj(apple=5, banana=7)]",
            stdout_value,
        )

    def test_jac_py_import_auto(self) -> None:
        """Basic test for pass."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.run(self.fixture_abs_path("../../../tests/fixtures/jp_importer_auto.jac"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("Hello World!", stdout_value)
        self.assertIn(
            "{SomeObj(a=10): 'check'} [MyObj(apple=5, banana=7), MyObj(apple=5, banana=7)]",
            stdout_value,
        )

    def test_import_with_jacpath(self) -> None:
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
            Jac.set_base_path(self.fixture_abs_path(__file__))
            JacMachineInterface.attach_program(
                JacProgram(),
            )
            Jac.jac_import(module_name, base_path=__file__)
            cli.run(jac_file_path)

            # Reset stdout and get the output
            sys.stdout = sys.__stdout__
            stdout_value = captured_output.getvalue()

            self.assertIn("Hello from JACPATH!", stdout_value)

        finally:
            captured_output.close()

            os.environ.pop("JACPATH", None)
            jacpath_dir.cleanup()

    def test_importer_with_submodule_jac(self) -> None:
        """Test basic self loading."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.run(self.fixture_abs_path("pkg_import_main.jac"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("Helper function called", stdout_value)
        self.assertIn("Tool function executed", stdout_value)

    def test_importer_with_submodule_py(self) -> None:
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.run(self.fixture_abs_path("pkg_import_main_py.jac"))
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("Helper function called", stdout_value)
        self.assertIn("Tool function executed", stdout_value)
        self.assertIn("pkg_import_lib_py.glob_var_lib", stdout_value)

    def test_jac_import_py_files(self) -> None:
        """Test importing Python files using Jac import system."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        os.environ["JAC_PYFILE_RAISE"] = "True"
        settings.load_env_vars()
        original_cwd = os.getcwd()
        try:
            os.chdir(os.path.dirname(self.fixture_abs_path("jac_import_py_files.py")))
            Jac.set_base_path(self.fixture_abs_path("jac_import_py_files.py"))
            JacMachineInterface.attach_program(JacProgram())
            Jac.jac_import(
                "jac_import_py_files",
                base_path=self.fixture_abs_path("jac_import_py_files.py"),
                lng="py",
            )
            cli.run(self.fixture_abs_path("jac_import_py_files.py"))
            sys.stdout = sys.__stdout__
            stdout_value = captured_output.getvalue()
            self.assertIn(
                "This is main test file for jac import of python files", stdout_value
            )
            self.assertIn(
                "python_module <jaclang.compiler.unitree.Module object",
                str(Jac.program.mod.hub),
            )
            self.assertIn(
                "jac_module <jaclang.compiler.unitree.Module object",
                str(Jac.program.mod.hub),
            )
            os.environ["JAC_PYFILE_RAISE"] = "false"
            settings.load_env_vars()
            os.chdir(os.path.dirname(self.fixture_abs_path("jac_import_py_files.py")))
            Jac.reset_machine()
            Jac.set_base_path(self.fixture_abs_path("jac_import_py_files.py"))
            JacMachineInterface.attach_program(JacProgram())
            Jac.jac_import(
                "jac_import_py_files",
                base_path=self.fixture_abs_path("jac_import_py_files.py"),
                lng="py",
            )
            cli.run(self.fixture_abs_path("jac_import_py_files.py"))
            sys.stdout = sys.__stdout__
            stdout_value = captured_output.getvalue()
            self.assertIn(
                "This is main test file for jac import of python files", stdout_value
            )
            self.assertNotIn(
                "python_module <jaclang.compiler.unitree.Module object",
                str(Jac.program.mod.hub),
            )
            self.assertIn(
                "jac_module <jaclang.compiler.unitree.Module object",
                str(Jac.program.mod.hub),
            )
        finally:
            os.chdir(original_cwd)
