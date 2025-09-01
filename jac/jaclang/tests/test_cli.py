"""Test Jac cli module."""

import contextlib
import inspect
import io
import os
import re
import subprocess
import sys
import traceback
import unittest
from jaclang.cli import cli
from jaclang.cli.cmdreg import cmd_registry, extract_param_descriptions
from jaclang.runtimelib.builtin import printgraph
from jaclang.utils.test import TestCase


class JacCliTests(TestCase):
    """Test pass module."""

    def setUp(self) -> None:
        """Set up test."""
        return super().setUp()

    def test_jac_cli_run(self) -> None:
        """Basic test for pass."""
        captured_output = io.StringIO()
        sys.stdout = captured_output

        # Execute the function
        cli.run(self.fixture_abs_path("hello.jac"))

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()

        self.assertIn("Hello World!", stdout_value)

    def test_jac_cli_run_python_file(self) -> None:
        """Test running Python files with jac run command."""
        captured_output = io.StringIO()
        sys.stdout = captured_output

        cli.run(self.fixture_abs_path("python_run_test.py"))

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()

        self.assertIn("Hello from Python!", stdout_value)
        self.assertIn("This is a test Python file.", stdout_value)
        self.assertIn("Result: 42", stdout_value)
        self.assertIn("Python execution completed.", stdout_value)
        self.assertIn("10", stdout_value)

    def test_jac_run_py_fstr(self) -> None:
        """Test running Python files with jac run command."""
        captured_output = io.StringIO()
        sys.stdout = captured_output

        cli.run(self.fixture_abs_path("pyfunc_fstr.py"))

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()

        self.assertIn("Hello Peter", stdout_value)
        self.assertIn("Hello Peter Peter", stdout_value)
        self.assertIn("Peter squared is Peter Peter", stdout_value)
        self.assertIn("PETER!  wrong poem", stdout_value)
        self.assertIn("Hello Peter , yoo mother is Mary. Myself, I am Peter.", stdout_value)
        self.assertIn("Left aligned: Apple | Price: 1.23", stdout_value)
        self.assertIn("name = Peter 🤔", stdout_value)

    def test_jac_run_py_fmt(self) -> None:
        """Test running Python files with jac run command."""
        captured_output = io.StringIO()
        sys.stdout = captured_output

        cli.run(self.fixture_abs_path("pyfunc_fmt.py"))

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()

        self.assertIn("One", stdout_value)
        self.assertIn("Two", stdout_value)
        self.assertIn("Three", stdout_value)
        self.assertIn("baz", stdout_value)
        self.assertIn("Processing...", stdout_value)
        self.assertIn("Four", stdout_value)
        self.assertIn("The End.", stdout_value)

    def test_jac_run_pyfunc_kwesc(self) -> None:
        """Test running Python files with jac run command."""
        captured_output = io.StringIO()
        sys.stdout = captured_output

        cli.run(self.fixture_abs_path("pyfunc_kwesc.py"))

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        out = stdout_value.split("\n")
        self.assertIn("89", out[0])
        self.assertIn("(13, (), {'a': 1, 'b': 2})", out[1])
        self.assertIn("Functions: [{'name': 'replace_lines'", out[2])
        self.assertIn("Dict: 90", out[3])

    def test_jac_cli_alert_based_err(self) -> None:
        """Basic test for pass."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        sys.stderr = captured_output

        try:
            cli.enter(self.fixture_abs_path("err2.jac"), entrypoint="speak", args=[])
        except Exception as e:
            print(f"Error: {e}")

        sys.stdout = sys.__stdout__
        sys.stderr = sys.__stderr__
        stdout_value = captured_output.getvalue()
        # print(stdout_value)
        self.assertIn("Error", stdout_value)

    def test_jac_cli_alert_based_runtime_err(self) -> None:
        """Basic test for pass."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        sys.stderr = captured_output

        with contextlib.suppress(Exception):
            cli.run(self.fixture_abs_path("err_runtime.jac"))

        sys.stdout = sys.__stdout__
        sys.stderr = sys.__stderr__

        expected_stdout_values = (
            "Error: list index out of range",
            "    print(some_list[invalid_index]);",
            "          ^^^^^^^^^^^^^^^^^^^^^^^^",
            "  at bar() ",
            "  at foo() ",
            "  at <module> ",
        )
        logger_capture = "\n".join([rec.message for rec in self.caplog.records])
        for exp in expected_stdout_values:
            self.assertIn(exp, logger_capture)

    def test_jac_impl_err(self) -> None:
        """Basic test for pass."""
        if "jaclang.tests.fixtures.err" in sys.modules:
            del sys.modules["jaclang.tests.fixtures.err"]
        captured_output = io.StringIO()
        sys.stdout = captured_output
        sys.stderr = captured_output

        try:
            cli.enter(self.fixture_abs_path("err.jac"), entrypoint="speak", args=[])
        except Exception:
            traceback.print_exc()

        sys.stdout = sys.__stdout__
        sys.stderr = sys.__stderr__
        stdout_value = captured_output.getvalue()
        # print(stdout_value)
        path_to_file = self.fixture_abs_path("err.impl.jac")
        self.assertIn(f'"{path_to_file}", line 2', stdout_value)

    def test_param_name_diff(self) -> None:
        """Test when parameter name from definitinon and declaration are mismatched."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        sys.stderr = captured_output
        with contextlib.suppress(Exception):
            cli.run(self.fixture_abs_path("decl_defn_param_name.jac"))
        sys.stdout = sys.__stdout__
        sys.stderr = sys.__stderr__

        expected_stdout_values = (
            "short_name = 42",
            "p1 = 64 , p2 = foobar",
        )
        output = captured_output.getvalue()
        for exp in expected_stdout_values:
            self.assertIn(exp, output)

    def test_jac_test_err(self) -> None:
        """Basic test for pass."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        sys.stderr = captured_output
        cli.test(self.fixture_abs_path("baddy.jac"))
        sys.stdout = sys.__stdout__
        sys.stderr = sys.__stderr__
        stdout_value = captured_output.getvalue()
        path_to_file = self.fixture_abs_path("baddy.test.jac")
        self.assertIn(f'"{path_to_file}", line 2,', stdout_value)

    def test_jac_ast_tool_pass_template(self) -> None:
        """Basic test for pass."""
        captured_output = io.StringIO()
        sys.stdout = captured_output

        cli.tool("pass_template")

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("Sub objects.", stdout_value)
        self.assertGreater(stdout_value.count("def exit_"), 10)

    def test_jac_cmd_line(self) -> None:
        """Basic test for pass."""
        process = subprocess.Popen(
            ["jac"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        stdout_value, _ = process.communicate(input="exit\n")
        self.assertEqual(process.returncode, 0, "Process did not exit successfully")
        self.assertIn("Welcome to the Jac CLI!", stdout_value)

    def test_ast_print(self) -> None:
        """Testing for print AstTool."""
        captured_output = io.StringIO()
        sys.stdout = captured_output

        cli.tool("ir", ["ast", f"{self.fixture_abs_path('hello.jac')}"])

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("+-- Token", stdout_value)

    @unittest.skip("Skipping builtins loading test")
    def test_builtins_loading(self) -> None:
        """Testing for print AstTool."""
        from jaclang.settings import settings

        settings.ast_symbol_info_detailed = True
        captured_output = io.StringIO()
        sys.stdout = captured_output

        cli.tool("ir", ["ast", f"{self.fixture_abs_path('builtins_test.jac')}"])

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        settings.ast_symbol_info_detailed = False

        self.assertRegex(
            stdout_value,
            r"2\:8 \- 2\:12.*BuiltinType - list - .*SymbolPath: builtins.list",
        )
        self.assertRegex(
            stdout_value,
            r"15\:5 \- 15\:8.*Name - dir - .*SymbolPath: builtins.dir",
        )
        self.assertRegex(
            stdout_value,
            r"13\:12 \- 13\:18.*Name - append - .*SymbolPath: builtins.list.append",
        )

    def test_ast_printgraph(self) -> None:
        """Testing for print AstTool."""
        captured_output = io.StringIO()
        sys.stdout = captured_output

        cli.tool("ir", ["ast.", f"{self.fixture_abs_path('hello.jac')}"])

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn(
            '[label="MultiString" shape="oval" style="filled" fillcolor="#fccca4"]',
            stdout_value,
        )
    
    def test_cfg_printgraph(self) -> None:
        """Testing for print CFG."""
        captured_output = io.StringIO()
        sys.stdout = captured_output

        cli.tool("ir", ["cfg.", f"{self.fixture_abs_path('hello.jac')}"])

        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        correct_graph = (
            "digraph G {\n"
            '  0 [label="BB0\\n\\nprint ( \\"im still here\\" ) ;\", shape=box];\n'
            '  1 [label="BB1\\n\\"Hello World!\\" |> print ;\", shape=box];\n'
            "}\n\n"
        )

        self.assertEqual(
            correct_graph,
            stdout_value,
        )

    def test_del_clean(self) -> None:
        """Testing for print AstTool."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.check(f"{self.fixture_abs_path('del_clean.jac')}")
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("Errors: 0, Warnings: 0", stdout_value)

    def test_build_and_run(self) -> None:
        """Testing for print AstTool."""
        if os.path.exists(f"{self.fixture_abs_path('needs_import.jir')}"):
            os.remove(f"{self.fixture_abs_path('needs_import.jir')}")
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.build(f"{self.fixture_abs_path('needs_import.jac')}")
        cli.run(f"{self.fixture_abs_path('needs_import.jir')}")
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("Errors: 0, Warnings: 0", stdout_value)
        self.assertIn("<module 'pyfunc' from", stdout_value)

    def test_run_test(self) -> None:
        """Basic test for pass."""
        process = subprocess.Popen(
            ["jac", "test", f"{self.fixture_abs_path('run_test.jac')}", "-m 2"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        stdout, stderr = process.communicate()
        self.assertIn("Ran 3 tests", stderr)
        self.assertIn("FAILED (failures=2)", stderr)
        self.assertIn("F.F", stderr)

        process = subprocess.Popen(
            [
                "jac",
                "test",
                "-d" + f"{self.fixture_abs_path('../../../')}",
                "-f" + "circle*",
                "-x",
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        stdout, stderr = process.communicate()
        self.assertIn("circle", stdout)
        self.assertNotIn("circle_purfe.test", stdout)
        self.assertNotIn("circle_pure.impl", stdout)

        process = subprocess.Popen(
            ["jac", "test", "-f" + "*run_test.jac", "-m 3"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        stdout, stderr = process.communicate()
        self.assertIn("...F", stderr)
        self.assertIn("F.F", stderr)

    def test_run_specific_test_only(self) -> None:
        """Test a specific test case."""
        process = subprocess.Popen(
            [
                "jac",
                "test",
                "-t",
                "from_2_to_10",
                self.fixture_abs_path("jactest_main.jac"),
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        stdout, stderr = process.communicate()
        self.assertIn("Ran 1 test", stderr)
        self.assertIn("Testing fibonacci numbers from 2 to 10.", stdout)
        self.assertNotIn("Testing first 2 fibonacci numbers.", stdout)
        self.assertNotIn("This test should not run after import.", stdout)

    def test_graph_coverage(self) -> None:
        """Test for coverage of graph cmd."""
        graph_params = set(inspect.signature(cli.dot).parameters.keys())
        printgraph_params = set(inspect.signature(printgraph).parameters.keys())
        printgraph_params = printgraph_params - {
            "node",
            "file",
            "edge_type",
            "format",
        }
        printgraph_params.update({"initial", "saveto", "connection", "session"})
        self.assertTrue(printgraph_params.issubset(graph_params))
        self.assertEqual(len(printgraph_params) + 1, len(graph_params))

    def test_graph(self) -> None:
        """Test for graph CLI cmd."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.dot(f"{self.examples_abs_path('reference/connect_expressions.jac')}")
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        if os.path.exists("connect_expressions.dot"):
            os.remove("connect_expressions.dot")
        self.assertIn("11\n13\n15\n>>> Graph content saved to", stdout_value)
        self.assertIn("connect_expressions.dot\n", stdout_value)

    def test_py_to_jac(self) -> None:
        """Test for graph CLI cmd."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        cli.py2jac(f"{self.fixture_abs_path('../../tests/fixtures/pyfunc.py')}")
        sys.stdout = sys.__stdout__
        stdout_value = captured_output.getvalue()
        self.assertIn("def my_print(x: object) -> None", stdout_value)
        self.assertIn("class MyClass {", stdout_value)
        self.assertIn('"""Print function."""', stdout_value)

    def test_caching_issue(self) -> None:
        """Test for Caching Issue."""
        test_file = self.fixture_abs_path("test_caching_issue.jac")
        test_cases = [(10, True), (11, False)]
        for x, is_passed in test_cases:
            with open(test_file, "w") as f:
                f.write(
                    f"""
                test mytest{{
                    check 10 == {x};
                }}
                """
                )
            process = subprocess.Popen(
                ["jac", "test", test_file],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            stdout, stderr = process.communicate()
            if is_passed:
                self.assertIn("Passed successfully.", stdout)
                self.assertIn(".", stderr)
            else:
                self.assertNotIn("Passed successfully.", stdout)
                self.assertIn("F", stderr)
        os.remove(test_file)

    def test_cli_docstring_parameters(self) -> None:
        """Test that all CLI command parameters are documented in their docstrings."""
        # Get all registered CLI commands
        commands = {}
        for name, _ in cmd_registry.registry.items():
            # Skip commands that might be registered from outside cli.py
            if hasattr(cli, name):
                commands[name] = getattr(cli, name)

        missing_params = {}

        for cmd_name, cmd_func in commands.items():
            # Get function parameters from signature
            signature_params = set(inspect.signature(cmd_func).parameters.keys())

            # Parse docstring to extract documented parameters
            docstring = cmd_func.__doc__ or ""

            # Check if the docstring has an Args section
            args_match = re.search(r"Args:(.*?)(?:\n\n|\Z)", docstring, re.DOTALL)
            if not args_match:
                missing_params[cmd_name] = list(signature_params)
                continue

            args_section = args_match.group(1)

            # Extract parameter names from the Args section
            # Looking for patterns like "param_name: Description" or "param_name (type): Description"
            doc_params = set()
            for line in args_section.strip().split("\n"):
                line = line.strip()
                if not line:
                    continue

                # Match parameter name at the beginning of the line
                param_match = re.match(r"\s*([a-zA-Z0-9_]+)(?:\s*\([^)]*\))?:\s*", line)
                if param_match:
                    doc_params.add(param_match.group(1))

            # Find parameters that are in the signature but not in the docstring
            undocumented_params = signature_params - doc_params
            if undocumented_params:
                missing_params[cmd_name] = list(undocumented_params)

        # Assert that there are no missing parameters
        self.assertEqual(
            missing_params,
            {},
            f"The following CLI commands have undocumented parameters: {missing_params}",
        )

    def test_cli_help_uses_docstring_descriptions(self) -> None:
        """Test that CLI help text uses parameter descriptions from docstrings."""
        # Get a command with well-documented parameters
        test_commands = ["run", "dot", "test"]

        for cmd_name in test_commands:
            # Skip if command doesn't exist
            if not hasattr(cli, cmd_name):
                continue

            cmd_func = getattr(cli, cmd_name)
            docstring = cmd_func.__doc__ or ""

            # Extract parameter descriptions from docstring
            docstring_param_descriptions = extract_param_descriptions(docstring)

            # Skip if no parameters are documented
            if not docstring_param_descriptions:
                continue

            # Get help text for the command
            captured_output = io.StringIO()
            sys.stdout = captured_output

            # Use subprocess to get the help text to ensure we're testing the actual CLI output
            process = subprocess.Popen(
                ["jac", cmd_name, "--help"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            help_text, _ = process.communicate()

            sys.stdout = sys.__stdout__

            # Check that each documented parameter description appears in the help text
            for param_name, description in docstring_param_descriptions.items():
                # The description might be truncated or formatted differently in the help text,
                # so we'll just check for the first few words
                description_start = description.split()[:3]
                description_pattern = r"\s+".join(
                    re.escape(word) for word in description_start
                )
                # Check if the description appears in the help text
                self.assertRegex(
                    help_text,
                    description_pattern,
                    f"Parameter description for '{param_name}' not found in help text for '{cmd_name}'",
                )

    def test_run_jac_name_py(self) -> None:
        """Test a specific test case."""
        process = subprocess.Popen(
            [
                "jac",
                "run",
                self.fixture_abs_path("py_run.py"),
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        stdout, stderr = process.communicate()
        self.assertIn("Hello, World!", stdout)
        self.assertIn("Sum: 8", stdout)
