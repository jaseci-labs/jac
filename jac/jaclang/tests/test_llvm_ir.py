"""Comprehensive tests for LLVM IR generation."""

import importlib.util
import io
import sys
import unittest

from jaclang.compiler.program import JacProgram
from jaclang.utils.test import TestCase


class LlvmIrGenerationTests(TestCase):
    """Test LLVM IR generation functionality."""

    def setUp(self) -> None:
        """Set up test - skip if llvmlite not installed."""
        if importlib.util.find_spec("llvmlite") is None:
            self.skipTest("llvmlite is not installed")
        return super().setUp()

    def test_simple_add_ir_generation(self) -> None:
        """Test that simple addition generates valid LLVM IR."""
        prog = JacProgram()
        module = prog.compile_to_llvm(self.fixture_abs_path("native_simple.jac"))

        # Check that IR was generated
        self.assertIsNotNone(module.gen.llvm_ir)
        self.assertGreater(len(module.gen.llvm_ir), 0)

        # Check IR contains the function (may be @add or @"add")
        self.assertIn("define", module.gen.llvm_ir)
        self.assertTrue("@add" in module.gen.llvm_ir or '@"add"' in module.gen.llvm_ir)

        # Check metadata was populated
        self.assertIn("add", module.gen.llvm_metadata)
        metadata = module.gen.llvm_metadata["add"]
        self.assertEqual(metadata["return"], "i64")
        self.assertEqual(len(metadata["args"]), 2)
        self.assertEqual(metadata["args"][0], "i64")
        self.assertEqual(metadata["args"][1], "i64")

    def test_type_coercion_ir(self) -> None:
        """Test that type coercion generates appropriate LLVM instructions."""
        prog = JacProgram()
        module = prog.compile_to_llvm(self.fixture_abs_path("llvm_type_coercion.jac"))

        self.assertIsNotNone(module.gen.llvm_ir)
        ir_text = module.gen.llvm_ir

        # Check for sitofp (signed int to float) instruction
        self.assertIn("sitofp", ir_text)

        # Check for fptosi (float to signed int) instruction
        self.assertIn("fptosi", ir_text)

    def test_comparison_operations_ir(self) -> None:
        """Test that comparison operations generate correct LLVM IR."""
        prog = JacProgram()
        module = prog.compile_to_llvm(self.fixture_abs_path("llvm_comparisons.jac"))

        self.assertIsNotNone(module.gen.llvm_ir)
        ir_text = module.gen.llvm_ir

        # Integer comparisons use icmp
        self.assertIn("icmp", ir_text)

        # Float comparisons use fcmp
        self.assertIn("fcmp", ir_text)

        # Check specific comparison predicates
        self.assertIn("eq", ir_text)  # equals

    def test_unary_operations_ir(self) -> None:
        """Test that unary operations generate correct LLVM IR."""
        prog = JacProgram()
        module = prog.compile_to_llvm(self.fixture_abs_path("llvm_unary_ops.jac"))

        self.assertIsNotNone(module.gen.llvm_ir)
        ir_text = module.gen.llvm_ir

        # Negation uses sub from zero
        self.assertIn("sub", ir_text)

        # Float negation uses fsub
        self.assertIn("fsub", ir_text)

    def test_llvm_triple_and_layout(self) -> None:
        """Test that target triple and data layout are set."""
        prog = JacProgram()
        module = prog.compile_to_llvm(self.fixture_abs_path("native_simple.jac"))

        self.assertIsNotNone(module.gen.llvm_triple)
        self.assertGreater(len(module.gen.llvm_triple), 0)

        self.assertIsNotNone(module.gen.llvm_data_layout)
        self.assertGreater(len(module.gen.llvm_data_layout), 0)

    def test_multiple_functions(self) -> None:
        """Test that multiple functions are generated correctly."""
        prog = JacProgram()
        module = prog.compile_to_llvm(self.fixture_abs_path("llvm_comparisons.jac"))

        metadata = module.gen.llvm_metadata

        # Check that all functions are present
        self.assertIn("int_equals", metadata)
        self.assertIn("int_not_equals", metadata)
        self.assertIn("int_less_than", metadata)
        self.assertIn("int_greater_than", metadata)
        self.assertIn("float_equals", metadata)

        # Check return types
        for func_name in ["int_equals", "int_not_equals", "int_less_than"]:
            self.assertEqual(metadata[func_name]["return"], "i1")

    def test_ir_tool_llvmir(self) -> None:
        """Test that jac tool ir llvmir command works."""
        from jaclang.utils.lang_tools import AstTool

        tool = AstTool()
        result = tool.ir(["llvmir", self.fixture_abs_path("native_simple.jac")])

        # Should not be an error message
        self.assertNotIn("Error", result)
        self.assertNotIn("failed", result)

        # Should contain LLVM IR (function name may be @add or @"add")
        self.assertIn("define", result)
        self.assertTrue("@add" in result or '@"add"' in result)

    def test_ir_tool_llvmir_opt(self) -> None:
        """Test that jac tool ir llvmir-opt command works."""
        from jaclang.utils.lang_tools import AstTool

        tool = AstTool()
        result = tool.ir(["llvmir-opt", self.fixture_abs_path("native_simple.jac")])

        # Should not be an error message
        self.assertNotIn("Error", result)

        # Should contain optimized LLVM IR
        self.assertIn("define", result)

    def test_ir_tool_asm(self) -> None:
        """Test that jac tool ir asm command works."""
        from jaclang.utils.lang_tools import AstTool

        tool = AstTool()
        result = tool.ir(["asm", self.fixture_abs_path("native_simple.jac")])

        # Should not be an error message
        self.assertNotIn("Error", result)

        # Should contain assembly directives
        # The exact format depends on the target, but these are common
        self.assertTrue(
            any(
                marker in result
                for marker in [".text", ".globl", ".type", "ret", "add"]
            ),
            f"Assembly output doesn't contain expected markers. Output: {result[:200]}",
        )

    def test_error_handling_invalid_code(self) -> None:
        """Test that errors are properly reported for invalid code."""
        # Create a temporary file with invalid Jac code
        import tempfile

        with tempfile.NamedTemporaryFile(mode="w", suffix=".jac", delete=False) as f:
            f.write("def bad_func(x: int, *args) -> int { return x; }")
            temp_file = f.name

        try:
            prog = JacProgram()
            module = prog.compile_to_llvm(temp_file)

            # Should have errors about variadic parameters
            self.assertGreater(len(prog.errors_had), 0)
        finally:
            import os

            os.unlink(temp_file)

    def test_ir_verification(self) -> None:
        """Test that generated IR can be parsed and verified by LLVM."""
        import llvmlite.binding as llvm

        # Note: llvm.initialize() is deprecated in newer llvmlite versions
        # LLVM initialization is now handled automatically
        try:
            llvm.initialize_all_targets()
            llvm.initialize_all_asmprinters()
        except AttributeError:
            # Older llvmlite versions
            llvm.initialize()
            llvm.initialize_native_target()
            llvm.initialize_native_asmprinter()

        prog = JacProgram()
        module = prog.compile_to_llvm(self.fixture_abs_path("native_simple.jac"))

        # Parse the generated IR
        llvm_module = llvm.parse_assembly(module.gen.llvm_ir)

        # Verify it (should not raise)
        llvm_module.verify()

if __name__ == "__main__":
    unittest.main()
