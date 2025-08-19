"""Test type checker."""

from pathlib import Path
from jaclang.compiler.program import JacProgram
from jaclang.compiler.typecheck.analysis import JacTypeAnalyzer
from jaclang.compiler.typecheck.diagnostic_rules import DiagnosticRule
from jaclang.utils.test import TestCase

class TestTypeCheck(TestCase):
    """Base class for type checking tests."""

    def test_binder_diagnostics(self):
        """Test the binder diagnostics."""

        file_path = self.fixture_abs_path("type_check_1.jac")
        program = JacProgram()
        program.build(file_path=file_path, no_cgen=True)
        analyzer = JacTypeAnalyzer()
        analyzer.analyze_program(program)

        diags = analyzer.diagnostics[Path(file_path).resolve()]
        self.assertEqual(len(diags), 1)
        self.assertEqual(diags[0].rule, DiagnosticRule.REPORT_MISSING_IMPORTS)
