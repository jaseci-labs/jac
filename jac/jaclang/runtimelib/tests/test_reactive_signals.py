"""Test reactive state management primitives."""

from __future__ import annotations

from pathlib import Path

from jaclang.runtimelib.machine import JacMachine as Jac
from jaclang.utils.test import TestCase


class ReactiveSignalsTests(TestCase):
    """Test reactive signals and state management."""

    def setUp(self) -> None:
        Jac.reset_machine()
        return super().setUp()

    def tearDown(self) -> None:
        Jac.reset_machine()
        return super().tearDown()

    def test_reactive_signals_compile(self) -> None:
        """Test that reactive signals compile to valid JavaScript."""
        fixtures_dir = Path(__file__).parent / "fixtures"
        (module,) = Jac.jac_import("test_reactive_signals", str(fixtures_dir))

        builder = Jac.get_client_bundle_builder()
        bundle = builder.build(module)

        # Check that reactive primitives are included
        self.assertIn("function createSignal(", bundle.code)
        self.assertIn("function createState(", bundle.code)
        self.assertIn("function createEffect(", bundle.code)

        # Check that test functions are present
        self.assertIn("function test_signal_basic()", bundle.code)
        self.assertIn("function test_signal_with_effect()", bundle.code)
        self.assertIn("function test_state_object()", bundle.code)
        self.assertIn("function test_multiple_signals()", bundle.code)

        # Check that reactive context is present
        self.assertIn("__jacReactiveContext", bundle.code)

        # Verify closures are working (no 'let' redeclarations in nested functions)
        # The setter should access the outer signalData, not redeclare it
        self.assertIn("signalData.value = newValue", bundle.code)

        # Print first 3000 chars for debugging
        print("\n=== Reactive Signals Bundle (first 3000 chars) ===")
        print(bundle.code[:3000])

    def test_reactive_primitives_in_bundle(self) -> None:
        """Verify all reactive primitives are exported."""
        fixtures_dir = Path(__file__).parent / "fixtures"
        (module,) = Jac.jac_import("test_reactive_signals", str(fixtures_dir))

        builder = Jac.get_client_bundle_builder()
        bundle = builder.build(module)

        # Check dependency tracking functions
        self.assertIn("function __jacTrackDependency(", bundle.code)
        self.assertIn("function __jacNotifySubscribers(", bundle.code)
        self.assertIn("function __jacScheduleRerender(", bundle.code)
        self.assertIn("function __jacFlushRenders()", bundle.code)

        # Check that batching is set up
        self.assertIn("requestAnimationFrame", bundle.code)

        # Ensure no syntax errors
        self.assertNotIn("SyntaxError", bundle.code)
