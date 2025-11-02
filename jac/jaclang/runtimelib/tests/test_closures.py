"""Test closure support in Jac client code."""

from __future__ import annotations

from pathlib import Path

from jaclang.runtimelib.machine import JacMachine as Jac
from jaclang.utils.test import TestCase


class ClosureTests(TestCase):
    """Test closures in client-side Jac code."""

    def setUp(self) -> None:
        Jac.reset_machine()
        return super().setUp()

    def tearDown(self) -> None:
        Jac.reset_machine()
        return super().tearDown()

    def test_nested_function_closures(self) -> None:
        """Test that nested functions can access outer scope variables."""
        fixtures_dir = Path(__file__).parent / "fixtures"
        (module,) = Jac.jac_import("test_closures", str(fixtures_dir))

        builder = Jac.get_client_bundle_builder()
        bundle = builder.build(module)

        # Print the generated JavaScript for debugging
        print("\\n=== Generated JavaScript ===")
        print(bundle.code[:2000])  # Print first 2000 chars
        print("\\n=== Test Functions ===")

        # Check that functions are present
        self.assertIn("function make_counter()", bundle.code)
        self.assertIn("function create_signal_simple(", bundle.code)
        self.assertIn("function make_adder(", bundle.code)
        self.assertIn("function create_shared_counter()", bundle.code)

        # Check that inner functions are present
        self.assertIn("function increment()", bundle.code)
        self.assertIn("function getter()", bundle.code)
        self.assertIn("function setter(", bundle.code)
        self.assertIn("function get_value()", bundle.code)

        # Check that closures can access outer variables
        # The generated code should contain references to 'count' and 'value'
        self.assertIn("count", bundle.code)
        self.assertIn("value", bundle.code)

        # Ensure no import errors
        self.assertNotIn("ImportError", bundle.code)
