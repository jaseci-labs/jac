"""Test ast build pass module."""

import io
import os
import sys

from jaclang.compiler.program import JacProgram, py_code_gen
from jaclang.utils.test import TestCase
from jaclang.settings import settings
from jaclang.compiler.passes.main import PreDynamoPass

class PreDynamoPassTests(TestCase):
    """Test pass module."""

    TargetPass = PreDynamoPass

    def setUp(self) -> None:
        """Set up test."""
        settings.predynamo_pass = True
        return super().setUp()

    def tearDown(self) -> None:
        """Tear down test."""
        settings.predynamo_pass = False
        # Remove PreDynamoPass from global py_code_gen list if it was added
        if PreDynamoPass in py_code_gen:
            py_code_gen.remove(PreDynamoPass)
        return super().tearDown()

    def test_predynamo_where_assign(self) -> None:
        """Test torch.where transformation."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        settings.predynamo_pass = True
        code_gen = JacProgram().compile(self.fixture_abs_path("predynamo_where_assign.jac"))
        sys.stdout = sys.__stdout__
        self.assertIn("torch.where", code_gen.unparse())
        
    def test_predynamo_where_return(self) -> None:
        """Test torch.where transformation."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        code_gen = JacProgram().compile(self.fixture_abs_path("predynamo_where_return.jac"))
        sys.stdout = sys.__stdout__
        self.assertIn("torch.where", code_gen.unparse())


    def test_predynamo_fix3(self) -> None:
        """Test torch.where transformation."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        code_gen = JacProgram().compile(self.fixture_abs_path("predynamo_fix3.jac"))
        sys.stdout = sys.__stdout__
        unparsed_code = code_gen.unparse()
        self.assertIn("__inv_freq = torch.where(", unparsed_code)
        self.assertIn("self.register_buffer('inv_freq', __inv_freq, persistent=False);", unparsed_code)
