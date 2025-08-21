"""Test case utils for Jaseci."""

import inspect
import os
from typing import Callable, Optional
from unittest import TestCase as _TestCase

from _pytest.logging import LogCaptureFixture

import jaclang
from jaclang.compiler.passes import UniPass
from jaclang.runtimelib.utils import read_file_with_encoding
from jaclang.utils.helpers import get_uni_nodes_as_snake_case as ast_snakes

import pytest


class TestCase(_TestCase):
    """Base test case for Jaseci."""

    # Reference: https://stackoverflow.com/a/50375022
    @pytest.fixture(autouse=True)
    def inject_fixtures(self, caplog: LogCaptureFixture) -> None:
        """Store the logger capture records within the tests."""
        self.caplog = caplog

    def setUp(self) -> None:
        """Set up test case."""
        return super().setUp()

    def tearDown(self) -> None:
        """Tear down test case."""
        return super().tearDown()

    def load_fixture(self, fixture: str) -> str:
        """Load fixture from fixtures directory."""
        frame = inspect.currentframe()
        if frame is None or frame.f_back is None:
            raise ValueError("Unable to get the previous stack frame.")
        module = inspect.getmodule(frame.f_back)
        if module is None or module.__file__ is None:
            raise ValueError("Unable to determine the file of the module.")
        fixture_src = module.__file__
        fixture_path = os.path.join(os.path.dirname(fixture_src), "fixtures", fixture)
        return read_file_with_encoding(fixture_path)

    def file_to_str(self, file_path: str) -> str:
        """Load fixture from fixtures directory."""
        return read_file_with_encoding(file_path)

    def fixture_abs_path(self, fixture: str) -> str:
        """Get absolute path of a fixture from fixtures directory."""
        frame = inspect.currentframe()
        if frame is None or frame.f_back is None:
            raise ValueError("Unable to get the previous stack frame.")
        module = inspect.getmodule(frame.f_back)
        if module is None or module.__file__ is None:
            raise ValueError("Unable to determine the file of the module.")
        fixture_src = module.__file__
        file_path = os.path.join(os.path.dirname(fixture_src), "fixtures", fixture)
        return os.path.abspath(file_path)

    def examples_abs_path(self, example: str) -> str:
        """Get absolute path of a example from examples directory."""
        fixture_src = jaclang.__file__
        file_path = os.path.join(
            os.path.dirname(os.path.dirname(fixture_src)), "examples", example
        )
        return os.path.abspath(file_path)


class TestCaseMicroSuite(TestCase):
    """Base test case for Jaseci."""

    test_micro_jac_files_fully_tested: Optional[Callable[[TestCase], None]] = None
    methods: list[str] = []

    @classmethod
    def self_attach_micro_tests(cls) -> None:
        """Attach micro tests."""
        for filename in [
            os.path.normpath(os.path.join(root, name))
            for root, _, files in os.walk(
                os.path.dirname(os.path.dirname(jaclang.__file__))
            )
            for name in files
            if name.endswith(".jac") and "err" not in name
        ]:
            method_name = (
                f"test_micro_{filename.replace('.jac', '').replace(os.sep, '_')}"
            )
            cls.methods.append(method_name)
            setattr(cls, method_name, lambda self, f=filename: self.micro_suite_test(f))

        def test_micro_jac_files_fully_tested(self: TestCase) -> None:  # noqa: ANN001
            """Test that all micro jac files are fully tested."""
            for filename in cls.methods:
                if os.path.isfile(filename):
                    method_name = f"test_micro_{filename.replace('.jac', '').replace(os.sep, '_')}"
                    self.assertIn(method_name, dir(self))

        cls.test_micro_jac_files_fully_tested = test_micro_jac_files_fully_tested

    def micro_suite_test(self, filename: str) -> None:
        """Test micro jac file."""
        pass


class AstSyncTestMixin:
    """Mixin for testing AST sync."""

    TargetPass: Optional[UniPass] = None

    def test_pass_ast_complete(self) -> None:
        """Test for enter/exit name diffs with parser."""
        ast_func_names = [
            x
            for x in ast_snakes()
            if x
            not in [
                "uni_node",
                "uni_scope_node",
                "uni_c_f_g_node",
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
            ]
        ]
        pygen_func_names = []
        for name, value in inspect.getmembers(self.TargetPass):
            if (
                (name.startswith("enter_") or name.startswith("exit_"))
                and inspect.isfunction(value)
                and not getattr(self.TargetPass.__base__, value.__name__, False)  # type: ignore
                and value.__qualname__.split(".")[0]
                == self.TargetPass.__name__.replace("enter_", "").replace("exit_", "")  # type: ignore
            ):
                pygen_func_names.append(name.replace("enter_", "").replace("exit_", ""))
        for name in pygen_func_names:
            self.assertIn(name, ast_func_names)  # type: ignore
        for name in ast_func_names:
            self.assertIn(name, pygen_func_names)  # type: ignore
