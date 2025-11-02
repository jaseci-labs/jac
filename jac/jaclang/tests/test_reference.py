"""Test Jac reference examples."""

import io
import os
from contextlib import redirect_stdout
import sys
from typing import Callable, Optional

import jaclang
from jaclang.compiler.program import JacProgram
from jaclang.runtimelib.machine import JacMachine as Jac
from jaclang.utils.test import TestCase


class JacReferenceTests(TestCase):
    """Test Reference examples."""

    test_ref_jac_files_fully_tested: Optional[Callable[[TestCase], None]] = None
    methods: list[str] = []

    @classmethod
    def self_attach_ref_tests(cls) -> None:
        """Attach micro tests."""
        for filename in [
            os.path.normpath(os.path.join(root, name))
            for root, _, files in os.walk(
                os.path.join(
                    os.path.dirname(os.path.dirname(jaclang.__file__)),
                    "examples/reference",
                )
            )
            for name in files
            if name.endswith(".jac") and not name.startswith("err")
        ]:
            method_name = (
                f"test_ref_{filename.replace('.jac', '').replace(os.sep, '_')}"
            )
            cls.methods.append(method_name)
            setattr(cls, method_name, lambda self, f=filename: self.micro_suite_test(f))

        def test_ref_jac_files_fully_tested(self: TestCase) -> None:  # noqa: ANN001
            """Test that all micro jac files are fully tested."""
            for filename in cls.methods:
                if os.path.isfile(filename):
                    method_name = (
                        f"test_ref_{filename.replace('.jac', '').replace(os.sep, '_')}"
                    )
                    self.assertIn(method_name, dir(self))

        cls.test_ref_jac_files_fully_tested = test_ref_jac_files_fully_tested

    def micro_suite_test(self, filename: str) -> None:
        """Test file."""
        # Reset machine at the start of each test to ensure clean state
        Jac.reset_machine()

        def execute_and_capture_output(code: str | bytes, filename: str = "") -> str:
            f = io.StringIO()
            with redirect_stdout(f):
                exec(
                    code,
                    {
                        "__file__": filename,
                        "__name__": "__main__",
                    },
                )
            return f.getvalue()

        def normalize_function_addresses(text: str) -> str:
            """Normalize function memory addresses in output for consistent comparison."""
            import re
            # Replace <function Name at 0xADDRESS> with <function Name at 0x...>
            return re.sub(r'<function (\w+) at 0x[0-9a-f]+>', r'<function \1 at 0x...>', text)

        try:
            if "tests.jac" in filename or "check_statements.jac" in filename:
                return
            jacast = JacProgram().compile(filename)
            code_content = compile(
                source=jacast.gen.py_ast[0],
                filename=jacast.loc.mod_path,
                mode="exec",
            )
            output_jac = execute_and_capture_output(code_content, filename=filename)
            Jac.reset_machine()
            # Clear byllm modules from cache to ensure consistent behavior between JAC and Python runs
            # when byllm is used
            sys.modules.pop("byllm", None)
            sys.modules.pop("byllm.lib", None)
            filename = filename.replace(".jac", ".py")
            with open(filename, "r") as file:
                code_content = file.read()
            output_py = execute_and_capture_output(code_content, filename=filename)

            # Normalize function addresses before comparison
            output_jac = normalize_function_addresses(output_jac)
            output_py = normalize_function_addresses(output_py)

            print(f"\nJAC Output:\n{output_jac}")
            print(f"\nPython Output:\n{output_py}")

            self.assertGreater(len(output_py), 0)
            # doing like below for concurrent_expressions.jac and other current tests
            for i in output_py.split("\n"):
                self.assertIn(i, output_jac)
            for i in output_jac.split("\n"):
                self.assertIn(i, output_py)
            self.assertEqual(len(output_jac.split("\n")), len(output_py.split("\n")))
            # self.assertEqual(output_py, output_jac)
        except Exception as e:
            # print(f"\nJAC Output:\n{output_jac}")
            # print(f"\nPython Output:\n{output_py}")
            raise e


JacReferenceTests.self_attach_ref_tests()
