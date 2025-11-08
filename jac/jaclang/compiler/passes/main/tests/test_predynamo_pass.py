"""Test ast build pass module."""

import io
import os
import sys

from jaclang.compiler.program import JacProgram
from jaclang.utils.test import TestCase
from jaclang.settings import settings
from jaclang.compiler.passes.main import PreDynamoPass

class PreDynamoPassTests(TestCase):
    """Test pass module."""

    TargetPass = PreDynamoPass

    def setUp(self) -> None:
        """Set up test."""
        return super().setUp()
    
    def test_predynamo_where_assign(self) -> None:
        """Test torch.where transformation."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        os.environ["JAC_PREDYNAMO_PASS"] = "True"
        settings.load_env_vars()
        code_gen = JacProgram().compile(self.fixture_abs_path("predynamo_where_assign.jac"))
        sys.stdout = sys.__stdout__
        self.assertIn("torch.where", code_gen.unparse())
        os.environ["JAC_PREDYNAMO_PASS"] = "false"
        settings.load_env_vars()
        
    def test_predynamo_where_return(self) -> None:
        """Test torch.where transformation."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        os.environ["JAC_PREDYNAMO_PASS"] = "True"
        settings.load_env_vars()
        code_gen = JacProgram().compile(self.fixture_abs_path("predynamo_where_return.jac"))
        sys.stdout = sys.__stdout__
        self.assertIn("torch.where", code_gen.unparse())
        os.environ["JAC_PREDYNAMO_PASS"] = "false"
        settings.load_env_vars()

    def test_predynamo_fix3(self) -> None:
        """Test torch.where transformation."""
        captured_output = io.StringIO()
        sys.stdout = captured_output
        os.environ["JAC_PREDYNAMO_PASS"] = "True"
        settings.load_env_vars()
        code_gen = JacProgram().compile(self.fixture_abs_path("predynamo_fix3.jac"))
        sys.stdout = sys.__stdout__
        unparsed_code = code_gen.unparse()
        self.assertIn("__inv_freq = torch.where(", unparsed_code)
        self.assertIn("self.register_buffer('inv_freq', __inv_freq, persistent=False);", unparsed_code)
        os.environ["JAC_PREDYNAMO_PASS"] = "false"
        settings.load_env_vars()